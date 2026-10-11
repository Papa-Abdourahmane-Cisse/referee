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

# Parcourt récursivement une expression et renvoie tous les appels de
# fonction, avec la ligne de l'instruction de premier niveau qui les contient.
walk_calls <- function(x, line) {
  out <- list()
  if (is.call(x)) {
    out[[1L]] <- list(name = call_name(x), call = x, line = line)
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next # argument vide, ex. df[, 1]
      out <- c(out, walk_calls(x[[i]], line))
    }
  } else if (is.pairlist(x)) {
    for (i in seq_along(x)) {
      if (identical(x[[i]], quote(expr = ))) next # paramètre sans défaut
      out <- c(out, walk_calls(x[[i]], line))
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
