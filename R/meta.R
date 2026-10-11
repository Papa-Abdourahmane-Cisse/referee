# Métadonnées d'enquête déclarées par l'utilisateur -------------------------

#' Déclarer les métadonnées d'une enquête ou d'une analyse
#'
#' Le Référé ne devine jamais le rôle d'une variable : il le lit ici. Une
#' règle dont les métadonnées requises manquent est signalée comme non
#' évaluée dans le rapport.
#'
#' @param weights Nom de la variable de poids d'échantillonnage.
#' @param size Nom de la variable de taille du ménage.
#' @param strata,psu Noms des variables de strate et de grappe (unité primaire
#'   de sondage).
#' @param group Nom de la variable de niveau supérieur (par exemple la région).
#' @param group_vars Variables à vérifier contre une désagrégation artificielle
#'   par rapport à `group`.
#' @param key Nom(s) de la ou des colonnes qui doivent identifier une unité
#'   de manière unique.
#' @param aggregated_vars Variables déjà agrégées à un niveau (par exemple des
#'   taux communaux) dont la moyenne simple est suspecte.
#' @param data_objects Noms des objets du script qui contiennent les données
#'   d'enquête ; restreint les règles statiques aux appels qui les citent.
#' @param scales Vecteur nommé : échelle déclarée de chaque colonne, parmi
#'   `"proportion"` (0 à 1), `"percent"` (0 à 100) ou `"auto"` (échelle
#'   inconnue, détection d'échelles mélangées).
#' @param fgt_cols Vecteur de trois noms de colonnes, dans l'ordre FGT0, FGT1,
#'   FGT2.
#' @param sums Liste de contrôles de somme. Chaque élément est une liste avec
#'   `parts` (colonnes à sommer), soit `total` (colonne du total déclaré), soit
#'   `target` (valeur attendue, par exemple 100), et `tol` (tolérance
#'   d'arrondi absolue, 0,5 par défaut).
#'
#' @return Un objet de classe `referee_meta`.
#' @export
referee_meta <- function(weights = NULL, size = NULL, strata = NULL,
                         psu = NULL, group = NULL, group_vars = NULL,
                         key = NULL, aggregated_vars = NULL,
                         data_objects = NULL, scales = NULL,
                         fgt_cols = NULL, sums = NULL) {
  one <- function(x, nm) {
    if (!is.null(x) && !(is.character(x) && length(x) == 1L && !is.na(x))) {
      stop(sprintf("`%s` doit \u00eatre un nom de variable (cha\u00eene de longueur 1).",
                   nm), call. = FALSE)
    }
    x
  }
  many <- function(x, nm) {
    if (!is.null(x) && !(is.character(x) && length(x) >= 1L && !anyNA(x))) {
      stop(sprintf("`%s` doit \u00eatre un vecteur de noms de variables.", nm),
           call. = FALSE)
    }
    x
  }
  if (!is.null(scales)) {
    valid <- c("proportion", "percent", "auto")
    if (!is.character(scales) || is.null(names(scales)) ||
          !all(scales %in% valid)) {
      stop("`scales` doit \u00eatre un vecteur nomm\u00e9 dont les valeurs sont : ",
           paste(valid, collapse = ", "), ".", call. = FALSE)
    }
  }
  if (!is.null(fgt_cols) &&
        !(is.character(fgt_cols) && length(fgt_cols) == 3L)) {
    stop("`fgt_cols` doit contenir trois noms de colonnes (FGT0, FGT1, FGT2).",
         call. = FALSE)
  }
  if (!is.null(sums)) {
    ok <- is.list(sums) && all(vapply(sums, function(s) {
      is.list(s) && is.character(s$parts) &&
        xor(is.null(s$total), is.null(s$target))
    }, logical(1)))
    if (!ok) {
      stop("Chaque \u00e9l\u00e9ment de `sums` doit contenir `parts` et exactement l'un ",
           "de `total` ou `target`.", call. = FALSE)
    }
  }
  structure(
    list(
      weights = one(weights, "weights"), size = one(size, "size"),
      strata = one(strata, "strata"), psu = one(psu, "psu"),
      group = one(group, "group"), group_vars = many(group_vars, "group_vars"),
      key = many(key, "key"),
      aggregated_vars = many(aggregated_vars, "aggregated_vars"),
      data_objects = many(data_objects, "data_objects"),
      scales = scales, fgt_cols = fgt_cols, sums = sums
    ),
    class = "referee_meta"
  )
}

# Liste des colonnes que les métadonnées réclament dans les données.
meta_columns <- function(meta) {
  cols <- c(meta$weights, meta$size, meta$strata, meta$psu, meta$group,
            meta$group_vars, meta$key, names(meta$scales), meta$fgt_cols)
  for (s in meta$sums) cols <- c(cols, s$parts, s$total)
  unique(cols)
}

# Arrêt net si une variable déclarée n'existe pas dans les données : mieux
# vaut une erreur explicite qu'un contrôle silencieusement vide.
check_meta_columns <- function(meta, data) {
  missing_cols <- setdiff(meta_columns(meta), names(data))
  if (length(missing_cols) > 0L) {
    stop("Variables d\u00e9clar\u00e9es dans les m\u00e9tadonn\u00e9es mais absentes des donn\u00e9es : ",
         paste(missing_cols, collapse = ", "), ".", call. = FALSE)
  }
  invisible(TRUE)
}
