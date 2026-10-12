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
#' @param time Nom de la variable temporelle (règle VAL-06).
#' @param target Nom de la variable cible d'un modèle prédictif (règle VAL-05).
#' @param cluster Nom de la variable de grappe d'estimation (règle ECO-01).
#' @param unit Nom de la variable d'unité d'un panel (règle ECO-02).
#' @param treat Nom de la variable de traitement 0/1 (règles ECO-02 et ECO-03).
#' @param endog,instruments,controls Régresseur endogène, instruments et
#'   contrôles exogènes (règle ECO-04).
#' @param score,cutoff Variable de score et seuil d'une discontinuité de
#'   régression (règle ECO-05).
#' @param references Liste de valeurs de référence (règle EXT-01). Chaque
#'   élément : `name`, `reference` (valeur de référence), `tol` (tolérance),
#'   exactement l'un de `var` (colonne dont la moyenne, pondérée si `weights`
#'   est déclaré, est comparée) ou `estimate` (estimation fournie), et
#'   éventuellement `tol_type` (`"absolute"` ou `"relative"`).
#' @param poverty Liste nommée de déclarations sur la ligne de pauvreté et
#'   l'agrégat de bien-être (règle EXT-02) : `line_year`, `welfare_year`,
#'   `price_adjusted`, `line_unit`, `welfare_unit`, `line_period`,
#'   `welfare_period`.
#' @param figures Liste de chiffres du texte reliés à leur source (règle
#'   DOC-01). Chaque élément : `name`, `value` (nombre issu de la sortie),
#'   `pattern` (expression régulière repérant la phrase), et éventuellement
#'   `factor` (100 pour une proportion affichée en pourcentage).
#' @param indicators Liste d'indicateurs (règle DOC-02), chacun avec `name` et
#'   `pattern`.
#' @param geo_terms Termes géographiques reconnus dans le texte (règle DOC-02).
#' @param design Design d'identification déclaré, en texte libre (règle
#'   DOC-03).
#' @param age Nom de la variable d'âge en années révolues (règle DEM-01).
#' @param balance Liste de noms de colonnes de l'équation compensatrice (règle
#'   DEM-02) : `p0`, `p1`, `births`, `deaths`, et éventuellement `immigrants`,
#'   `emigrants`.
#' @param lifetable Liste de noms de colonnes d'une table de mortalité (règle
#'   DEM-03) : `age`, `qx` et/ou `lx`, éventuellement `by`.
#' @param sexratio Liste de noms de colonnes du rapport de masculinité (règle
#'   DEM-04) : `group` et, soit `sex` et `male`, soit `males` et `females`.
#' @param train_objects,test_objects Noms des objets du script qui contiennent
#'   les données d'apprentissage et de test (règles VAL-03 et VAL-04).
#'
#' @return Un objet de classe `referee_meta`.
#' @export
referee_meta <- function(weights = NULL, size = NULL, strata = NULL,
                         psu = NULL, group = NULL, group_vars = NULL,
                         key = NULL, aggregated_vars = NULL,
                         data_objects = NULL, scales = NULL,
                         fgt_cols = NULL, sums = NULL, time = NULL,
                         target = NULL, train_objects = NULL,
                         test_objects = NULL, cluster = NULL, unit = NULL,
                         treat = NULL, endog = NULL, instruments = NULL,
                         controls = NULL, score = NULL, cutoff = NULL,
                         references = NULL, poverty = NULL, figures = NULL,
                         indicators = NULL, geo_terms = NULL,
                         design = NULL, age = NULL, balance = NULL,
                         lifetable = NULL, sexratio = NULL) {
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
  if (!is.null(cutoff) && !(is.numeric(cutoff) && length(cutoff) == 1L &&
                              is.finite(cutoff))) {
    stop("`cutoff` doit \u00eatre un nombre.", call. = FALSE)
  }
  if (!is.null(balance)) check_balance(balance)
  if (!is.null(lifetable)) check_lifetable(lifetable)
  if (!is.null(sexratio)) check_sexratio(sexratio)
  if (!is.null(references)) check_references(references)
  if (!is.null(figures)) check_figures(figures)
  if (!is.null(poverty)) {
    valid_p <- c("line_year", "welfare_year", "price_adjusted", "line_unit",
                 "welfare_unit", "line_period", "welfare_period")
    if (!is.list(poverty) || is.null(names(poverty)) ||
          !all(names(poverty) %in% valid_p)) {
      stop("`poverty` doit \u00eatre une liste nomm\u00e9e parmi : ",
           paste(valid_p, collapse = ", "), ".", call. = FALSE)
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
      scales = scales, fgt_cols = fgt_cols, sums = sums,
      time = one(time, "time"), target = one(target, "target"),
      train_objects = many(train_objects, "train_objects"),
      test_objects = many(test_objects, "test_objects"),
      cluster = one(cluster, "cluster"), unit = one(unit, "unit"),
      treat = one(treat, "treat"), endog = one(endog, "endog"),
      instruments = many(instruments, "instruments"),
      controls = many(controls, "controls"), score = one(score, "score"),
      cutoff = cutoff, references = references, poverty = poverty,
      figures = figures, indicators = indicators,
      geo_terms = many(geo_terms, "geo_terms"), design = one(design, "design"), age = one(age, "age"),
      balance = balance, lifetable = lifetable, sexratio = sexratio
    ),
    class = "referee_meta"
  )
}

# Liste des colonnes que les métadonnées réclament dans les données.
meta_columns <- function(meta) {
  cols <- c(meta$weights, meta$size, meta$strata, meta$psu, meta$group,
            meta$group_vars, meta$key, names(meta$scales), meta$fgt_cols,
            meta$time, meta$target, meta$cluster, meta$unit, meta$treat,
            meta$endog, meta$instruments, meta$controls, meta$score)
  for (s in meta$sums) cols <- c(cols, s$parts, s$total)
  for (r in meta$references) cols <- c(cols, r$var)
  cols <- c(cols, meta$age, unlist(meta$balance), unlist(meta$lifetable))
  if (!is.null(meta$sexratio)) {
    cols <- c(cols, meta$sexratio$group, meta$sexratio$sex,
              meta$sexratio$males, meta$sexratio$females)
  }
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
