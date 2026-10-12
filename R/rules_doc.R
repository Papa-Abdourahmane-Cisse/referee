# Famille DOC : cohérence documentaire ----------------------------------------
#
# Contrôles lexicaux sur le texte d'un rapport ou d'un mémoire. Ils reposent
# sur des motifs d'écriture et sur ce que l'utilisateur déclare : ils ne
# comprennent pas le texte. Une alerte désigne un passage à relire, jamais une
# erreur établie sans lecture.

#' Lire un document texte pour les contrôles DOC
#'
#' @param text Contenu du document (vecteur de caractères, un élément par
#'   ligne ou par paragraphe), ou
#' @param path chemin d'un fichier texte (UTF-8). Exactement l'un des deux.
#' @return Un objet de classe `referee_document`.
#' @export
read_document <- function(text = NULL, path = NULL) {
  if (!xor(is.null(text), is.null(path))) {
    stop("Fournir exactement l'un de `text` ou `path`.", call. = FALSE)
  }
  if (!is.null(path)) {
    if (!file.exists(path)) {
      stop(sprintf("Fichier introuvable : %s", path), call. = FALSE)
    }
    text <- readLines(path, encoding = "UTF-8", warn = FALSE)
    source <- path
  } else {
    if (!is.character(text)) {
      stop("`text` doit \u00eatre un vecteur de cha\u00eenes.", call. = FALSE)
    }
    text <- unlist(strsplit(text, "\n", fixed = TRUE), use.names = FALSE)
    source <- "<texte>"
  }
  structure(list(lines = text, source = source), class = "referee_document")
}

# Phrases du document : (ligne, texte).
doc_sentences <- function(doc) {
  out_line <- integer()
  out_text <- character()
  for (i in seq_along(doc$lines)) {
    parts <- unlist(strsplit(doc$lines[i], "(?<=[.!?;])\\s+", perl = TRUE))
    parts <- parts[nzchar(trimws(parts))]
    out_line <- c(out_line, rep(i, length(parts)))
    out_text <- c(out_text, parts)
  }
  data.frame(line = out_line, text = out_text, stringsAsFactors = FALSE)
}

NUMBER_REGEX <- "[0-9]+(?:[ \u00a0][0-9]{3})*(?:[,.][0-9]+)?"

# Premier nombre qui suit `from` (position de caractère) dans `s`, hors années
# isolées (entiers de 1900 à 2100 sans décimale). Renvoie la valeur et le
# nombre de décimales affichées, ou NULL.
number_after <- function(s, from = 1L) {
  tail <- substring(s, from)
  m <- gregexpr(NUMBER_REGEX, tail, perl = TRUE)[[1L]]
  if (m[1L] == -1L) return(NULL)
  raw <- regmatches(tail, list(m))[[1L]]
  for (r in raw) {
    clean <- gsub("[ \u00a0]", "", r)
    dec <- if (grepl("[,.]", clean)) nchar(sub("^.*[,.]", "", clean)) else 0L
    val <- as.numeric(sub(",", ".", clean, fixed = TRUE))
    if (dec == 0L && val >= 1900 && val <= 2100) next
    return(list(value = val, decimals = dec, raw = r))
  }
  NULL
}

# Occurrences d'un motif : phrases qui le contiennent, avec le premier nombre
# qui le suit.
find_figures <- function(sentences, pattern) {
  out <- list()
  for (i in seq_len(nrow(sentences))) {
    m <- regexpr(pattern, sentences$text[i], ignore.case = TRUE, perl = TRUE)
    if (m[1L] == -1L) next
    num <- number_after(sentences$text[i], m[1L] + attr(m, "match.length"))
    out[[length(out) + 1L]] <- list(line = sentences$line[i],
                                    sentence = sentences$text[i], number = num)
  }
  out
}

shorten_text <- function(x, width = 100L) {
  x <- gsub("\\s+", " ", trimws(x))
  if (nchar(x) > width) paste0(substr(x, 1L, width - 3L), "...") else x
}

check_figures <- function(figures) {
  ok <- is.list(figures) && length(figures) > 0L &&
    all(vapply(figures, function(f) {
      is.list(f) && is.character(f$name) && length(f$name) == 1L &&
        is.numeric(f$value) && length(f$value) == 1L && is.finite(f$value) &&
        is.character(f$pattern) && length(f$pattern) == 1L &&
        (is.null(f$factor) || (is.numeric(f$factor) && length(f$factor) == 1L))
    }, logical(1)))
  if (!ok) {
    stop("Chaque \u00e9l\u00e9ment de `figures` doit contenir `name`, `value` (nombre ",
         "issu de la sortie), `pattern` (expression qui rep\u00e8re la phrase) et ",
         "\u00e9ventuellement `factor` (par exemple 100 pour une proportion ",
         "affich\u00e9e en pourcentage).", call. = FALSE)
  }
  invisible(figures)
}

#' DOC-01 : chiffre du texte différent de celui de la sortie qui l'a produit
#'
#' Pour chaque chiffre déclaré (`figures`), repère les phrases du document qui
#' correspondent au motif, lit le premier nombre qui suit le motif et le
#' compare à la valeur de la sortie (multipliée par `factor`, 1 par défaut). La
#' tolérance est l'arrondi implicite de la précision affichée dans le texte :
#' « 37,5 » tolère un écart de 0,05. Un écart est un constat de certitude :
#' le chiffre est relié à sa source par déclaration. Un chiffre dont le motif
#' ne correspond à aucune phrase est signalé à justifier (la règle ne peut pas
#' conclure).
#'
#' Limites : le lien entre le texte et la sortie est celui que l'utilisateur
#' déclare ; un motif trop large peut rattacher le mauvais nombre ; les
#' chiffres non déclarés ne sont pas examinés. Un écart d'un facteur 100 est
#' signalé comme possible confusion d'échelle.
#'
#' @param document Objet issu de [read_document()].
#' @param figures Liste de chiffres déclarés (voir [referee_meta()]).
#' @return Liste de constats.
#' @export
doc01_text_vs_output <- function(document, figures) {
  check_figures(figures)
  sentences <- doc_sentences(document)
  out <- list()
  for (fig in figures) {
    factor <- if (is.null(fig$factor)) 1 else fig$factor
    expected <- fig$value * factor
    hits <- Filter(function(h) !is.null(h$number),
                   find_figures(sentences, fig$pattern))
    if (length(hits) == 0L) {
      out[[length(out) + 1L]] <- new_finding(
        "DOC-01", "a_justifier",
        sprintf(paste0("Chiffre `%s` non localis\u00e9 dans le texte (motif \u00ab %s \u00bb, ",
                       "valeur attendue : %s). Le lien entre le texte et la ",
                       "sortie n'est pas v\u00e9rifi\u00e9."),
                fig$name, fig$pattern, fr_num(expected, 6)),
        location = fig$name)
      next
    }
    for (h in hits) {
      tol <- 0.5 * 10^(-h$number$decimals) + 1e-9
      if (abs(h$number$value - expected) <= tol) next
      hint <- ""
      if (any(abs(c(h$number$value * 100, h$number$value / 100) - expected) <= tol)) {
        hint <- " L'\u00e9cart dispara\u00eet \u00e0 un facteur 100 pr\u00e8s : v\u00e9rifier l'\u00e9chelle."
      }
      out[[length(out) + 1L]] <- new_finding(
        "DOC-01", "certitude",
        sprintf(paste0("`%s` : le texte indique %s, la sortie donne %s (ligne %d : ",
                       "\u00ab %s \u00bb).%s"),
                fig$name, h$number$raw, fr_num(expected, 6), h$line,
                shorten_text(h$sentence), hint),
        location = sprintf("ligne %d", h$line),
        details = list(text = h$number$value, output = expected))
    }
  }
  out
}

#' DOC-02 : indicateur chiffré de deux façons, ou sans niveau ni période
#'
#' Pour chaque indicateur déclaré (`indicators`, avec un motif qui le repère),
#' relève les chiffres qui le suivent dans le texte. Deux contrôles.
#' (1) Des chiffres différents pour le même indicateur dans des phrases qui
#' partagent les mêmes années et les mêmes termes géographiques déclarés
#' (`geo_terms`) : risque probable, car le texte désigne alors la même
#' population et la même période. (2) Un indicateur chiffré dans une phrase
#' sans année ni terme géographique : constat à justifier.
#'
#' Limites : la règle ne compare pas les définitions ; elle ne reconnaît que
#' les années et les termes géographiques déclarés ; les périodes autres que
#' des années (« premier semestre ») ne sont pas vues ; le contrôle (2) est
#' bruyant dans une introduction ou un résumé.
#'
#' @param document Objet issu de [read_document()].
#' @param indicators Liste d'indicateurs, chacun avec `name` et `pattern`.
#' @param geo_terms Termes géographiques à reconnaître (régions, « national »,
#'   « Dakar »...), ou `NULL`.
#' @return Liste de constats.
#' @export
doc02_indicator_consistency <- function(document, indicators, geo_terms = NULL) {
  ok <- is.list(indicators) && length(indicators) > 0L &&
    all(vapply(indicators, function(i) {
      is.list(i) && is.character(i$name) && is.character(i$pattern) &&
        length(i$name) == 1L && length(i$pattern) == 1L
    }, logical(1)))
  if (!ok) {
    stop("Chaque \u00e9l\u00e9ment de `indicators` doit contenir `name` et `pattern`.",
         call. = FALSE)
  }
  sentences <- doc_sentences(document)
  years_of <- function(s) {
    unique(unlist(regmatches(s, gregexpr("\\b(19|20)[0-9]{2}\\b", s, perl = TRUE))))
  }
  geo_of <- function(s) {
    if (length(geo_terms) == 0L) return(character())
    geo_terms[vapply(geo_terms, function(g) grepl(tolower(g), tolower(s),
                                                  fixed = TRUE), logical(1))]
  }
  out <- list()
  for (ind in indicators) {
    hits <- Filter(function(h) !is.null(h$number),
                   find_figures(sentences, ind$pattern))
    if (length(hits) == 0L) next
    keys <- vapply(hits, function(h) {
      paste(paste(sort(years_of(h$sentence)), collapse = ","),
            paste(sort(geo_of(h$sentence)), collapse = ","), sep = "|")
    }, character(1))
    for (k in unique(keys)) {
      grp <- hits[keys == k]
      if (length(grp) < 2L || k == "|") next
      vals <- vapply(grp, function(h) h$number$value, numeric(1))
      decs <- vapply(grp, function(h) h$number$decimals, numeric(1))
      tol <- 0.5 * 10^(-min(decs)) + 1e-9
      if (diff(range(vals)) > tol) {
        lines <- vapply(grp, function(h) h$line, integer(1))
        out[[length(out) + 1L]] <- new_finding(
          "DOC-02", "risque_probable",
          sprintf(paste0("`%s` est chiffr\u00e9 de plusieurs fa\u00e7ons pour la m\u00eame ",
                         "p\u00e9riode et le m\u00eame niveau g\u00e9ographique (%s) : %s (lignes ",
                         "%s)."),
                  ind$name, if (k == "|") "non pr\u00e9cis\u00e9s" else k,
                  paste(vapply(grp, function(h) h$number$raw, character(1)),
                        collapse = " ; "),
                  paste(lines, collapse = ", ")),
          location = ind$name,
          details = list(values = vals, lines = lines))
      }
    }
    bare <- hits[keys == "|"]
    if (length(bare) > 0L) {
      out[[length(out) + 1L]] <- new_finding(
        "DOC-02", "a_justifier",
        sprintf(paste0("`%s` est chiffr\u00e9 %d fois sans ann\u00e9e ni niveau g\u00e9ographique ",
                       "d\u00e9clar\u00e9 dans la phrase (premi\u00e8re occurrence : ligne %d)."),
                ind$name, length(bare), bare[[1L]]$line),
        location = ind$name, details = list(n = length(bare)))
    }
  }
  out
}

CAUSAL_PATTERNS <- c(
  "effet causal",
  "l[\u2019']effet (de|du|des|d[\u2019'])",
  "l[\u2019']impact (de|du|des|d[\u2019'])",
  "entra[i\u00ee]n(e|ent|ant|\u00e9)\\b",
  "provoqu(e|ent|ant|\u00e9)\\b",
  "est d\u00fb|sont dus|est due|sont dues",
  "gr\u00e2ce (\u00e0|au|aux)\\b",
  "a permis (de|d[\u2019'])",
  "fait (baisser|augmenter|reculer|progresser)"
)
# Radicaux (reconnus en début de mot) et sigles (reconnus comme mots entiers).
IDENTIFIED_STEMS <- c("randomis", "experimental", "experience",
                      "double difference", "discontinuit",
                      "variable instrumentale", "instrument", "appariement",
                      "controle synthetique", "synthetic control")
IDENTIFIED_ACRONYMS <- c("rct", "did", "rdd", "iv", "psm")

# Minuscules sans accents, pour comparer des déclarations libres.
plain_text <- function(x) {
  chartr("\u00e0\u00e2\u00e4\u00e9\u00e8\u00ea\u00eb\u00ee\u00ef\u00f4\u00f6\u00f9\u00fb\u00fc\u00e7",
         "aaaeeeeiioouuuc", tolower(x))
}

#' DOC-03 : langage causal sans design d'identification déclaré
#'
#' Si le design déclaré (`design`) n'est pas un design d'identification
#' reconnu (expérience aléatoire, double différence, discontinuité de
#' régression, variables instrumentales, appariement, contrôle synthétique),
#' signale les lignes du texte qui emploient un vocabulaire causal (« l'effet
#' de », « l'impact de », « entraîne », « grâce à », « a permis de »,
#' etc.). La règle ne vérifie pas que le design déclaré est valide : un design
#' déclaré suffit à la faire taire. Un vocabulaire causal sans design
#' d'identification est à justifier ou à reformuler (« est associé à »).
#'
#' Limites : détection purement lexicale. « L'impact de la sécheresse » dans
#' un contexte descriptif est signalé ; une formulation causale sans ces mots
#' échappe à la règle.
#'
#' @param document Objet issu de [read_document()].
#' @param design Design déclaré (texte libre, par exemple « observationnel »,
#'   « double différence »).
#' @return Liste de constats (confiance : à justifier), un par ligne.
#' @export
doc03_causal_language <- function(document, design) {
  d <- plain_text(design)
  has_stem <- any(vapply(IDENTIFIED_STEMS, function(p) {
    grepl(paste0("(^|[^a-z])", p), d, perl = TRUE)
  }, logical(1)))
  has_acronym <- any(vapply(IDENTIFIED_ACRONYMS, function(p) {
    grepl(paste0("(^|[^a-z])", p, "($|[^a-z])"), d, perl = TRUE)
  }, logical(1)))
  if (has_stem || has_acronym) return(list())
  out <- list()
  for (i in seq_along(document$lines)) {
    line <- document$lines[i]
    hits <- character()
    for (p in CAUSAL_PATTERNS) {
      m <- regmatches(line, regexpr(p, line, ignore.case = TRUE, perl = TRUE))
      if (length(m) > 0L) hits <- c(hits, m)
    }
    if (length(hits) == 0L) next
    out[[length(out) + 1L]] <- new_finding(
      "DOC-03", "a_justifier",
      sprintf(paste0("Vocabulaire causal (\u00ab %s \u00bb) alors que le design ",
                     "d\u00e9clar\u00e9 (\u00ab %s \u00bb) n'est pas un design d'identification ",
                     "reconnu. Justifier ou reformuler (\u00ab est associ\u00e9 \u00e0 \u00bb) : ",
                     "\u00ab %s \u00bb"),
              paste(unique(hits), collapse = " \u00bb, \u00ab "), design,
              shorten_text(line)),
      location = sprintf("ligne %d", i))
  }
  out
}
