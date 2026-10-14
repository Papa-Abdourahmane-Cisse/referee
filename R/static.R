# Analyse statique de scripts R -----------------------------------------------
#
# Le script n'est jamais exécuté : il est analysé comme un arbre syntaxique.
# Cette analyse ne voit que ce qui est écrit dans le code. Un appel construit
# dynamiquement (do.call, eval, noms de variables calculés) lui échappe, et une
# règle statique ne peut donc produire que des alertes, jamais une garantie.

#' Lire un script R pour l'analyse statique
#'
#' @param text Contenu du script (chaîne de caractères), ou
#' @param path chemin d'un fichier de script. Exactement l'un des deux.
#' @return Un objet de classe `referee_script`.
#' @export
parse_script <- function(text = NULL, path = NULL) {
  if (!xor(is.null(text), is.null(path))) {
    stop("Fournir exactement l'un de `text` ou `path`.", call. = FALSE)
  }
  if (!is.null(path)) {
    if (!file.exists(path)) {
      stop(sprintf("Fichier introuvable : %s", path), call. = FALSE)
    }
    exprs <- parse(file = path, keep.source = TRUE, encoding = "UTF-8")
    source <- path
  } else {
    exprs <- parse(text = text, keep.source = TRUE)
    source <- "<texte>"
  }
  structure(list(exprs = exprs, source = source), class = "referee_script")
}

# Nom de la fonction appelée ; `pkg::f(...)` donne "f". NA si l'appel porte
# sur une expression (par exemple `f(x)(y)`).
call_name <- function(cl) {
  head <- cl[[1L]]
  if (is.name(head)) {
    return(as.character(head))
  }
  if (is.call(head) && length(head) == 3L && is.name(head[[1L]]) &&
        as.character(head[[1L]]) %in% c("::", ":::")) {
    return(as.character(head[[3L]]))
  }
  NA_character_
}

# Opérateurs de pipe magrittr : `lhs %>% f(x)` équivaut à `f(lhs, x)`.
PIPE_OPERATORS <- c("%>%", "%<>%", "%T>%")

# Verbes qui reçoivent une table comme premier argument : les appels situés
# dans leurs autres arguments (`mean(x)` dans `summarise(d, m = mean(x))`)
# portent donc sur cette table.
DATA_VERBS <- c("summarise", "summarize", "mutate", "transmute", "filter",
                "group_by", "ungroup", "select", "arrange", "slice", "reframe",
                "rename", "distinct", "with", "within", "subset", "transform",
                "count", "tally", "left_join", "inner_join", "right_join",
                "full_join", "drop_na", "as_tibble", "as.data.frame", "head")

# Objet de départ d'une chaîne de transformations : `enes %>% filter(a)`
# donne "enes". NULL si la source n'est pas un simple nom d'objet.
data_root <- function(e) {
  if (is.name(e)) {
    return(as.character(e))
  }
  if (!is.call(e)) {
    return(NULL)
  }
  nm <- call_name(e)
  if (!is.na(nm) && nm %in% c("$", "[[", "[", "@") && length(e) >= 2L) {
    return(data_root(e[[2L]]))
  }
  if (!is.na(nm) && nm %in% c(DATA_VERBS, PIPE_OPERATORS) && length(e) >= 2L) {
    return(data_root(e[[2L]]))
  }
  NULL
}

# Réécrit `lhs %>% f(args)` en `f(lhs, args)` (sauf si `.` figure déjà parmi
# les arguments, auquel cas la position de lhs est choisie par l'auteur).
expand_pipe <- function(x) {
  lhs <- x[[2L]]
  rhs <- x[[3L]]
  if (is.name(rhs)) {
    return(as.call(list(rhs, lhs)))
  }
  if (!is.call(rhs)) {
    return(NULL)
  }
  has_dot <- any(vapply(as.list(rhs)[-1L], function(a) identical(a, quote(.)),
                        logical(1)))
  if (has_dot) {
    return(rhs)
  }
  as.call(c(list(rhs[[1L]]), list(lhs), as.list(rhs)[-1L]))
}

# Parcourt récursivement une expression et renvoie tous les appels de
# fonction, avec la ligne de l'instruction de premier niveau qui les contient
# et `ctx`, les objets de données des verbes englobants (voir DATA_VERBS).
# Les pipes magrittr sont dépliés : `d %>% lm(y ~ x)` est lu comme `lm(d, ...)`.
walk_calls <- function(x, line, ctx = character()) {
  out <- list()
  if (is.call(x)) {
    nm <- call_name(x)
    if (!is.na(nm) && nm %in% PIPE_OPERATORS && length(x) == 3L) {
      out[[1L]] <- list(name = nm, call = x, line = line, ctx = ctx)
      expanded <- expand_pipe(x)
      if (!is.null(expanded)) {
        out <- c(out, walk_calls(expanded, line, ctx))
      }
      return(out)
    }
    out[[1L]] <- list(name = nm, call = x, line = line, ctx = ctx)
    inner_ctx <- ctx
    if (!is.na(nm) && nm %in% DATA_VERBS && length(x) >= 2L) {
      root <- data_root(x[[2L]])
      if (!is.null(root)) inner_ctx <- unique(c(ctx, root))
    }
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next # argument vide, ex. df[, 1]
      out <- c(out, walk_calls(x[[i]], line, if (i == 1L) ctx else inner_ctx))
    }
  } else if (is.pairlist(x)) {
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next # paramètre sans défaut
      out <- c(out, walk_calls(x[[i]], line, ctx))
    }
  }
  out
}

# Tous les appels du script, dans l'ordre d'apparition.
collect_calls <- function(script) {
  exprs <- script$exprs
  refs <- attr(exprs, "srcref")
  out <- list()
  for (i in seq_along(exprs)) {
    line <- if (is.null(refs)) NA_integer_ else as.integer(refs[[i]][1L])
    out <- c(out, walk_calls(exprs[[i]], line))
  }
  out
}

# Symboles et constantes de type chaîne présents dans une expression : permet
# de reconnaître `df$hhweight` comme `df[["hhweight"]]`.
expr_tokens <- function(x) {
  if (is.name(x)) {
    return(as.character(x))
  }
  if (is.character(x)) {
    return(x)
  }
  if (is.call(x) || is.pairlist(x)) {
    out <- character()
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next
      out <- c(out, expr_tokens(x[[i]]))
    }
    return(out)
  }
  character()
}

# Texte court d'un appel pour l'affichage.
shorten_call <- function(cl, width = 90L) {
  txt <- paste(deparse(cl, width.cutoff = 500L), collapse = " ")
  txt <- gsub("\\s+", " ", txt)
  if (nchar(txt) > width) paste0(substr(txt, 1L, width - 3L), "...") else txt
}

# Localisation lisible : « ligne 12 : mean(df$x) ».
call_location <- function(rec) {
  sprintf("ligne %s : %s",
          ifelse(is.na(rec$line), "?", rec$line), shorten_call(rec$call))
}
