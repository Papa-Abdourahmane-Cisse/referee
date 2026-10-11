# Famille VAL : validation en apprentissage automatique -----------------------
#
# Les règles VAL-01 à VAL-04 et VAL-06 lisent le script sans l'exécuter. Elles
# repèrent des appels, jamais un flux de données : une alerte signale un motif
# suspect, et l'absence d'alerte ne garantit pas que la validation est correcte.
# Les listes de fonctions ci-dessous couvrent des paquets courants (rsample,
# caret, spatialsample, forecast) ; elles ne sont pas exhaustives.

RANDOM_SPLITTERS <- c("vfold_cv", "initial_split", "mc_cv", "bootstraps",
                      "loo_cv", "validation_split", "createFolds",
                      "createDataPartition", "createResample",
                      "createMultiFolds")
GROUPED_SPLITTERS <- c("group_vfold_cv", "group_initial_split", "group_mc_cv",
                       "group_bootstraps", "groupKFold", "spatial_block_cv",
                       "spatial_clustering_cv", "spatial_leave_location_out_cv")
TIME_SPLITTERS <- c("rolling_origin", "sliding_window", "sliding_index",
                    "sliding_period", "initial_time_split",
                    "createTimeSlices", "tsCV", "time_series_split")
RANDOM_TRAINCONTROL_METHODS <- c("cv", "repeatedcv", "boot", "boot632",
                                 "optimism_boot", "boot_all", "LGOCV", "LOOCV")

# Appels de découpage aléatoire : fonctions de la liste, et `trainControl()`
# dont la méthode est un rééchantillonnage aléatoire, sauf si des plis
# personnalisés (`index`) sont fournis.
random_split_calls <- function(calls, splitters = RANDOM_SPLITTERS) {
  Filter(function(rec) {
    if (is.na(rec$name)) return(FALSE)
    if (rec$name %in% splitters) return(TRUE)
    if (rec$name == "trainControl") {
      cl <- rec$call
      if ("index" %in% names(cl)) return(FALSE)
      method <- if ("method" %in% names(cl)) cl[["method"]] else NULL
      return(is.character(method) && method %in% RANDOM_TRAINCONTROL_METHODS)
    }
    FALSE
  }, calls)
}

has_call <- function(calls, names_) {
  any(vapply(calls, function(r) !is.na(r$name) && r$name %in% names_,
             logical(1)))
}

#' VAL-01 : validation aléatoire alors que les observations sont groupées
#'
#' Quand une variable de groupe est déclarée (région, grappe, commune), signale
#' les découpages aléatoires (`vfold_cv()`, `initial_split()`,
#' `createFolds()`, `trainControl(method = "cv")`, etc.) en l'absence de tout
#' découpage groupé ou spatial dans le script. Avec des observations
#' corrélées au sein d'un groupe, un découpage aléatoire place des
#' observations d'un même groupe dans l'apprentissage et dans le test : la
#' performance estimée risque d'être optimiste. L'ampleur de l'écart dépend
#' des données et ne peut être établie que par comparaison avec une
#' validation groupée.
#'
#' Limite connue : un seul découpage groupé n'importe où dans le script
#' suffit à faire taire la règle, même s'il ne concerne pas le modèle
#' principal.
#'
#' @param script Objet issu de [parse_script()].
#' @param group Nom de la variable de groupe déclarée.
#' @return Liste de constats (confiance : risque probable).
#' @export
val01_random_cv_grouped <- function(script, group) {
  calls <- collect_calls(script)
  if (has_call(calls, GROUPED_SPLITTERS)) return(list())
  out <- list()
  for (rec in random_split_calls(calls)) {
    out[[length(out) + 1L]] <- new_finding(
      "VAL-01", "risque_probable",
      sprintf(paste0("`%s()` d\u00e9coupe au hasard alors que les observations ",
                     "sont group\u00e9es (`%s`). La performance estim\u00e9e risque ",
                     "d'\u00eatre optimiste ; comparer \u00e0 une validation group\u00e9e ",
                     "(`group_vfold_cv()`, `groupKFold()`, validation ",
                     "spatiale)."), rec$name, group),
      location = call_location(rec), details = list(group = group))
  }
  out
}

#' VAL-06 : validation aléatoire sur des données ordonnées dans le temps
#'
#' Quand une variable temporelle est déclarée, signale les découpages
#' aléatoires en l'absence de tout découpage temporel (`rolling_origin()`,
#' `initial_time_split()`, `createTimeSlices()`, `tsCV()`, etc.) dans le
#' script. Un découpage aléatoire utilise des observations futures pour
#' prédire des observations passées.
#'
#' @inheritParams val01_random_cv_grouped
#' @param time Nom de la variable temporelle déclarée.
#' @return Liste de constats (confiance : risque probable).
#' @export
val06_random_cv_time <- function(script, time) {
  calls <- collect_calls(script)
  if (has_call(calls, TIME_SPLITTERS)) return(list())
  timeslice <- Filter(function(r) {
    identical(r$name, "trainControl") && identical(r$call[["method"]], "timeslice")
  }, calls)
  if (length(timeslice) > 0L) return(list())
  out <- list()
  for (rec in random_split_calls(calls)) {
    out[[length(out) + 1L]] <- new_finding(
      "VAL-06", "risque_probable",
      sprintf(paste0("`%s()` d\u00e9coupe au hasard des donn\u00e9es ordonn\u00e9es dans le ",
                     "temps (`%s`) : des observations futures peuvent servir ",
                     "\u00e0 pr\u00e9dire le pass\u00e9. Utiliser un d\u00e9coupage temporel ",
                     "(`rolling_origin()`, `initial_time_split()`, ",
                     "`createTimeSlices()`)."), rec$name, time),
      location = call_location(rec), details = list(time = time))
  }
  out
}

#' VAL-02 : transformation apprise avant la séparation des données
#'
#' Signale une transformation dont les paramètres sont estimés sur les
#' données (`scale()`, `prcomp()`, `preProcess()`, imputation par `mice()`,
#' etc.) lorsqu'elle apparaît dans une instruction de premier niveau
#' antérieure au premier découpage des données. L'ordre est établi par le
#' script ; l'effet sur la performance reste à mesurer, d'où un risque
#' probable.
#'
#' Limites connues : seules les instructions de premier niveau sont
#' comparées (deux appels dans une même instruction ne sont pas ordonnés) ;
#' les définitions de fonctions sont ignorées ; la sélection de variables
#' n'est pas détectée. Sans aucun découpage reconnu dans le script, la règle
#' est non évaluée.
#'
#' @param script Objet issu de [parse_script()].
#' @param data_objects Noms des objets de données. Si fourni, seules les
#'   transformations qui citent l'un d'eux sont examinées.
#' @param transforms Noms des fonctions considérées comme apprenant leurs
#'   paramètres sur les données.
#' @return Liste de constats (confiance : risque probable).
#' @export
val02_transform_before_split <- function(
    script, data_objects = NULL,
    transforms = c("scale", "prcomp", "princomp", "preProcess", "mice",
                   "missForest", "knnImputation")) {
  splitters <- c(RANDOM_SPLITTERS, GROUPED_SPLITTERS, TIME_SPLITTERS)
  exprs <- script$exprs
  refs <- attr(exprs, "srcref")
  calls <- list()
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    is_def <- is.call(e) && as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") &&
      length(e) == 3L && is.call(e[[3L]]) &&
      identical(e[[3L]][[1L]], as.name("function"))
    if (is_def) next
    line <- if (is.null(refs)) i else as.integer(refs[[i]][1L])
    calls <- c(calls, walk_calls(e, line))
  }
  split_lines <- vapply(Filter(function(r) !is.na(r$name) && r$name %in% splitters,
                               calls), function(r) r$line, integer(1))
  if (length(split_lines) == 0L) {
    return(not_evaluated("aucun d\u00e9coupage des donn\u00e9es reconnu dans le script"))
  }
  first_split <- min(split_lines)
  out <- list()
  for (rec in calls) {
    if (is.na(rec$name) || !rec$name %in% transforms) next
    if (is.na(rec$line) || rec$line >= first_split) next
    if (!is.null(data_objects) &&
          !any(data_objects %in% expr_tokens(rec$call))) next
    out[[length(out) + 1L]] <- new_finding(
      "VAL-02", "risque_probable",
      sprintf(paste0("`%s()` est appliqu\u00e9 avant le premier d\u00e9coupage des ",
                     "donn\u00e9es (ligne %d) : ses param\u00e8tres sont estim\u00e9s ",
                     "aussi sur les observations de test. Apprendre la ",
                     "transformation sur l'apprentissage seul, puis ",
                     "l'appliquer au test."), rec$name, first_split),
      location = call_location(rec))
  }
  out
}

#' VAL-03 : performance calculée sur les données d'apprentissage
#'
#' Signale les prédictions (`predict()`, `augment()`) et les métriques
#' (`rmse()`, `RMSE()`, `cor()`, etc.) qui citent un objet d'apprentissage
#' déclaré, lorsqu'aucun appel d'évaluation ne cite un jeu de test déclaré.
#' Rapporter une performance d'apprentissage à côté d'une performance de test
#' est légitime : si `test_objects` est fourni et qu'une évaluation sur le test
#' existe, la règle ne signale rien. Elle ne peut pas savoir comment le
#' résultat est présenté dans le rapport.
#'
#' @param script Objet issu de [parse_script()].
#' @param train_objects Noms des objets d'apprentissage.
#' @param test_objects Noms des objets de test, ou `NULL`.
#' @param predictors,metrics Noms des fonctions de prédiction et de métrique.
#' @return Liste de constats (confiance : risque probable).
#' @export
val03_training_performance <- function(
    script, train_objects, test_objects = NULL,
    predictors = c("predict", "augment"),
    metrics = c("rmse", "mae", "rsq", "rsq_trad", "mape", "accuracy",
                "roc_auc", "RMSE", "MAE", "R2", "MSE", "postResample",
                "defaultSummary", "cor")) {
  calls <- Filter(function(r) !is.na(r$name) &&
                    r$name %in% c(predictors, metrics), collect_calls(script))
  cites <- function(rec, objs) any(objs %in% expr_tokens(rec$call))
  if (!is.null(test_objects) && any(vapply(calls, cites, logical(1), test_objects))) {
    return(list())
  }
  out <- list()
  seen <- integer()
  for (rec in calls) {
    if (!cites(rec, train_objects)) next
    if (!is.na(rec$line) && rec$line %in% seen) next
    seen <- c(seen, rec$line)
    out[[length(out) + 1L]] <- new_finding(
      "VAL-03", "risque_probable",
      sprintf(paste0("`%s()` est \u00e9valu\u00e9 sur un jeu d'apprentissage (%s) et ",
                     "aucune \u00e9valuation sur un jeu de test d\u00e9clar\u00e9 n'a ",
                     "\u00e9t\u00e9 trouv\u00e9e. Une performance d'apprentissage n'est pas ",
                     "une performance pr\u00e9dictive."),
              rec$name, paste(train_objects, collapse = ", ")),
      location = call_location(rec))
  }
  out
}

#' VAL-04 : jeu de test utilisé pour choisir les hyperparamètres
#'
#' Signale les fonctions de réglage (`tune_grid()`, `train()`, `cv.glmnet()`,
#' etc.) ou de rééchantillonnage (`vfold_cv()`, `bootstraps()`, etc.) dont les
#' arguments citent un objet de test déclaré. Le test doit rester intact
#' jusqu'à l'évaluation finale. Les boucles de réglage écrites à la main ne
#' sont pas détectées.
#'
#' @param script Objet issu de [parse_script()].
#' @param test_objects Noms des objets de test.
#' @param tuners Noms des fonctions de réglage ou de rééchantillonnage.
#' @return Liste de constats (confiance : risque probable).
#' @export
val04_test_set_tuning <- function(
    script, test_objects,
    tuners = c("tune_grid", "tune_bayes", "tune_race_anova",
               "tune_race_win_loss", "tune_sim_anneal", "train", "cv.glmnet",
               "tuneRF", "fit_resamples", RANDOM_SPLITTERS, GROUPED_SPLITTERS,
               TIME_SPLITTERS)) {
  out <- list()
  for (rec in collect_calls(script)) {
    if (is.na(rec$name) || !rec$name %in% tuners) next
    hit <- intersect(test_objects, expr_tokens(rec$call))
    if (length(hit) == 0L) next
    out[[length(out) + 1L]] <- new_finding(
      "VAL-04", "risque_probable",
      sprintf(paste0("`%s()` utilise le jeu de test `%s` pour le r\u00e9glage ",
                     "ou le r\u00e9\u00e9chantillonnage. Choisir hyperparam\u00e8tres et ",
                     "mod\u00e8le sans toucher au test ; ne l'\u00e9valuer qu'une fois, ",
                     "\u00e0 la fin."), rec$name, hit[1L]),
      location = call_location(rec))
  }
  out
}

#' VAL-05 : prédicteur quasi déterministe de la cible
#'
#' Signale les variables numériques dont la corrélation avec la cible, en
#' valeur absolue (maximum de la corrélation de Pearson et de celle de
#' Spearman, sur les paires complètes), atteint le seuil. Une telle variable
#' est souvent dérivée de la cible ou issue de la même source (fuite
#' d'information). Une variable légitime très prédictive peut aussi
#' dépasser le seuil : la règle demande une justification, pas une
#' suppression. Seuil indicatif, à calibrer.
#'
#' Limites connues : les prédicteurs non numériques et les relations non
#' monotones ne sont pas examinés.
#'
#' @param data Data frame.
#' @param target Nom de la variable cible (numérique).
#' @param threshold Seuil de corrélation absolue (0,99 par défaut).
#' @param min_n Nombre minimal de paires complètes.
#' @return Liste de constats (confiance : risque probable).
#' @export
val05_target_proxy <- function(data, target, threshold = 0.99, min_n = 10L) {
  y <- data[[target]]
  if (!is.numeric(y)) {
    stop(sprintf("La cible `%s` n'est pas num\u00e9rique.", target), call. = FALSE)
  }
  out <- list()
  for (col in setdiff(names(data), target)) {
    x <- data[[col]]
    if (!is.numeric(x)) next
    ok <- stats::complete.cases(x, y)
    if (sum(ok) < min_n) next
    if (stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) next
    r <- max(abs(stats::cor(x[ok], y[ok])),
             abs(stats::cor(x[ok], y[ok], method = "spearman")))
    if (r >= threshold) {
      out[[length(out) + 1L]] <- new_finding(
        "VAL-05", "risque_probable",
        sprintf(paste0("`%s` est quasi d\u00e9terministe de la cible `%s` ",
                       "(corr\u00e9lation absolue : %s, sur %d paires). V\u00e9rifier ",
                       "qu'elle n'est pas d\u00e9riv\u00e9e de la cible ni issue de la m\u00eame ",
                       "source."), col, target, fr_num(r, 4), sum(ok)),
        location = col, details = list(cor = r, n = sum(ok)))
    }
  }
  out
}
