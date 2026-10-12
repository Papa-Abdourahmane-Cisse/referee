# Registre des règles, exécution et rapport -----------------------------------

# Chaque entrée décrit une règle : son identifiant, sa famille, ce dont elle a
# besoin (données et/ou script), les métadonnées obligatoires, la fonction qui
# l'implémente et la manière de construire ses arguments depuis le contexte.
rule_registry <- function() {
  list(
    list(id = "SUR-01", family = "SUR", needs = "script", meta = "weights",
         fun = sur01_unweighted_estimators,
         args = function(ctx) {
           list(script = ctx$script, weights = ctx$meta$weights,
                data_objects = ctx$meta$data_objects)
         }),
    list(id = "SUR-02", family = "SUR", needs = "script",
         meta = c("weights", "size"),
         fun = sur02_weight_divided_by_size,
         args = function(ctx) {
           list(script = ctx$script, weights = ctx$meta$weights,
                size = ctx$meta$size)
         }),
    list(id = "SUR-03", family = "SUR", needs = "script", meta = character(),
         fun = sur03_design_ignored,
         args = function(ctx) {
           list(script = ctx$script, strata = ctx$meta$strata,
                psu = ctx$meta$psu)
         }),
    list(id = "SUR-04", family = "SUR", needs = "data", meta = "weights",
         fun = sur04_weights_valid,
         args = function(ctx) {
           list(data = ctx$data, weights = ctx$meta$weights)
         }),
    list(id = "LVL-01", family = "LVL", needs = "data",
         meta = c("group", "group_vars"),
         fun = lvl01_artificial_disaggregation,
         args = function(ctx) {
           list(data = ctx$data, group = ctx$meta$group,
                vars = ctx$meta$group_vars)
         }),
    list(id = "LVL-02", family = "LVL", needs = "script",
         meta = "aggregated_vars",
         fun = lvl02_unweighted_mean_of_aggregates,
         args = function(ctx) {
           list(script = ctx$script, aggregated_vars = ctx$meta$aggregated_vars)
         }),
    list(id = "LVL-03", family = "LVL", needs = "data", meta = "key",
         fun = lvl03_duplicate_keys,
         args = function(ctx) list(data = ctx$data, key = ctx$meta$key)),
    list(id = "NUM-01", family = "NUM", needs = "data", meta = "scales",
         fun = num01_bounds,
         args = function(ctx) list(data = ctx$data, scales = ctx$meta$scales)),
    list(id = "NUM-02", family = "NUM", needs = "data", meta = "sums",
         fun = num02_sums,
         args = function(ctx) list(data = ctx$data, sums = ctx$meta$sums)),
    list(id = "NUM-03", family = "NUM", needs = "data", meta = "fgt_cols",
         fun = num03_fgt_order,
         args = function(ctx) {
           list(data = ctx$data, cols = ctx$meta$fgt_cols)
         }),
    list(id = "NUM-04", family = "NUM", needs = "data", meta = character(),
         fun = num04_missing_codes,
         args = function(ctx) list(data = ctx$data)),
    list(id = "VAL-01", family = "VAL", needs = "script", meta = "group",
         fun = val01_random_cv_grouped,
         args = function(ctx) list(script = ctx$script, group = ctx$meta$group)),
    list(id = "VAL-02", family = "VAL", needs = "script", meta = character(),
         fun = val02_transform_before_split,
         args = function(ctx) {
           list(script = ctx$script, data_objects = ctx$meta$data_objects)
         }),
    list(id = "VAL-03", family = "VAL", needs = "script",
         meta = "train_objects",
         fun = val03_training_performance,
         args = function(ctx) {
           list(script = ctx$script, train_objects = ctx$meta$train_objects,
                test_objects = ctx$meta$test_objects)
         }),
    list(id = "VAL-04", family = "VAL", needs = "script", meta = "test_objects",
         fun = val04_test_set_tuning,
         args = function(ctx) {
           list(script = ctx$script, test_objects = ctx$meta$test_objects)
         }),
    list(id = "VAL-05", family = "VAL", needs = "data", meta = "target",
         fun = val05_target_proxy,
         args = function(ctx) list(data = ctx$data, target = ctx$meta$target)),
    list(id = "VAL-06", family = "VAL", needs = "script", meta = "time",
         fun = val06_random_cv_time,
         args = function(ctx) list(script = ctx$script, time = ctx$meta$time)),
    list(id = "ECO-01", family = "ECO", needs = "script", meta = "cluster",
         fun = eco01_cluster_se,
         args = function(ctx) {
           list(script = ctx$script, cluster = ctx$meta$cluster)
         }),
    list(id = "ECO-02", family = "ECO", needs = c("data", "script"),
         meta = c("unit", "time", "treat"),
         fun = eco02_staggered_twfe,
         args = function(ctx) {
           list(data = ctx$data, script = ctx$script, unit = ctx$meta$unit,
                time = ctx$meta$time, treat = ctx$meta$treat)
         }),
    list(id = "ECO-03", family = "ECO", needs = "script", meta = "treat",
         fun = eco03_pretrends,
         args = function(ctx) list(script = ctx$script, treat = ctx$meta$treat)),
    list(id = "ECO-04", family = "ECO", needs = "data",
         meta = c("endog", "instruments"),
         fun = eco04_weak_instrument,
         args = function(ctx) {
           list(data = ctx$data, endog = ctx$meta$endog,
                instruments = ctx$meta$instruments,
                controls = ctx$meta$controls)
         }),
    list(id = "ECO-05", family = "ECO", needs = "data",
         meta = c("score", "cutoff"),
         fun = eco05_rdd_manipulation,
         args = function(ctx) {
           list(data = ctx$data, score = ctx$meta$score,
                cutoff = ctx$meta$cutoff, script = ctx$script)
         }),
    list(id = "EXT-01", family = "EXT", needs = character(),
         meta = "references",
         fun = ext01_reference_gap,
         args = function(ctx) {
           list(data = ctx$data, references = ctx$meta$references,
                weights = ctx$meta$weights)
         }),
    list(id = "EXT-02", family = "EXT", needs = character(), meta = "poverty",
         fun = ext02_poverty_line_consistency,
         args = function(ctx) list(poverty = ctx$meta$poverty)),
    list(id = "REP-01", family = "REP", needs = "script", meta = character(),
         fun = rep01_paths,
         args = function(ctx) {
           list(script = ctx$script, project_dir = ctx$project_dir)
         }),
    list(id = "REP-02", family = "REP", needs = "script", meta = character(),
         fun = rep02_seed,
         args = function(ctx) list(script = ctx$script)),
    list(id = "REP-03", family = "REP", needs = "project_dir",
         meta = character(),
         fun = rep03_environment,
         args = function(ctx) list(project_dir = ctx$project_dir)),
    list(id = "DOC-01", family = "DOC", needs = "document", meta = "figures",
         fun = doc01_text_vs_output,
         args = function(ctx) {
           list(document = ctx$document, figures = ctx$meta$figures)
         }),
    list(id = "DOC-02", family = "DOC", needs = "document",
         meta = "indicators",
         fun = doc02_indicator_consistency,
         args = function(ctx) {
           list(document = ctx$document, indicators = ctx$meta$indicators,
                geo_terms = ctx$meta$geo_terms)
         }),
    list(id = "DOC-03", family = "DOC", needs = "document", meta = "design",
         fun = doc03_causal_language,
         args = function(ctx) {
           list(document = ctx$document, design = ctx$meta$design)
         }),
    list(id = "DEM-01", family = "DEM", needs = "data", meta = "age",
         fun = dem01_age_heaping,
         args = function(ctx) {
           list(data = ctx$data, age = ctx$meta$age, weights = ctx$meta$weights)
         }),
    list(id = "DEM-02", family = "DEM", needs = "data", meta = "balance",
         fun = dem02_balancing_equation,
         args = function(ctx) list(data = ctx$data, balance = ctx$meta$balance)),
    list(id = "DEM-03", family = "DEM", needs = "data", meta = "lifetable",
         fun = dem03_life_table,
         args = function(ctx) list(data = ctx$data, lifetable = ctx$meta$lifetable)),
    list(id = "DEM-04", family = "DEM", needs = "data", meta = "sexratio",
         fun = dem04_sex_ratio,
         args = function(ctx) {
           list(data = ctx$data, sexratio = ctx$meta$sexratio,
                weights = ctx$meta$weights)
         })
  )
}

#' Identifiants des règles implémentées
#' @return Vecteur de caractères.
#' @export
rule_ids <- function() {
  vapply(rule_registry(), function(r) r$id, character(1))
}

#' Auditer des données et/ou un script R
#'
#' Exécute toutes les règles dont les entrées sont disponibles. Une règle
#' dont les données, le script ou les métadonnées manquent est rapportée comme
#' non évaluée : elle n'est jamais comptée comme passée sans alerte.
#'
#' @param data Data frame ou `NULL`.
#' @param script Chemin d'un script R, objet issu de [parse_script()] ou
#'   `NULL`.
#' @param meta Métadonnées, voir [referee_meta()].
#' @param document Chemin d'un fichier texte, objet issu de [read_document()]
#'   ou `NULL` (famille DOC).
#' @param project_dir Racine du projet (dossier) ou `NULL` (règles REP).
#' @param params Liste nommée par identifiant de règle, qui surcharge les
#'   paramètres d'une règle, par exemple
#'   `list("SUR-04" = list(ratio_max_median = 50))`.
#' @return Un objet de classe `referee_report`.
#' @export
audit <- function(data = NULL, script = NULL, meta = referee_meta(),
                  params = list(), document = NULL, project_dir = NULL) {
  if (!inherits(meta, "referee_meta")) {
    stop("`meta` doit \u00eatre cr\u00e9\u00e9 par `referee_meta()`.", call. = FALSE)
  }
  if (!is.null(data) && !is.data.frame(data)) {
    stop("`data` doit \u00eatre un data frame.", call. = FALSE)
  }
  if (is.character(script)) {
    script <- parse_script(path = script)
  }
  if (!is.null(script) && !inherits(script, "referee_script")) {
    stop("`script` doit \u00eatre un chemin ou un objet de `parse_script()`.",
         call. = FALSE)
  }
  if (is.character(document)) {
    document <- read_document(path = document)
  }
  if (!is.null(document) && !inherits(document, "referee_document")) {
    stop("`document` doit \u00eatre un chemin ou un objet de `read_document()`.",
         call. = FALSE)
  }
  if (!is.null(project_dir) &&
        !(is.character(project_dir) && length(project_dir) == 1L &&
            dir.exists(project_dir))) {
    stop("`project_dir` doit \u00eatre un dossier existant.", call. = FALSE)
  }
  if (!is.null(data)) {
    check_meta_columns(meta, data)
  }
  ctx <- list(data = data, script = script, meta = meta, document = document,
              project_dir = project_dir)

  findings <- list()
  rows <- list()
  for (spec in rule_registry()) {
    reason <- NULL
    if ("data" %in% spec$needs && is.null(data)) {
      reason <- "donn\u00e9es non fournies"
    } else if ("script" %in% spec$needs && is.null(script)) {
      reason <- "script non fourni"
    } else if ("document" %in% spec$needs && is.null(document)) {
      reason <- "document non fourni"
    } else if ("project_dir" %in% spec$needs && is.null(project_dir)) {
      reason <- "dossier du projet non fourni"
    } else {
      absent <- spec$meta[vapply(spec$meta, function(f) is.null(meta[[f]]),
                                 logical(1))]
      if (length(absent) > 0L) {
        reason <- paste0("m\u00e9tadonn\u00e9es manquantes : ",
                         paste(absent, collapse = ", "))
      }
    }
    result <- list()
    if (is.null(reason)) {
      extra <- params[[spec$id]]
      if (is.null(extra)) extra <- list()
      result <- do.call(spec$fun, utils::modifyList(spec$args(ctx), extra))
      reason <- attr(result, "not_evaluated")
    }
    evaluated <- is.null(reason)
    findings <- c(findings, if (evaluated) result else list())
    rows[[length(rows) + 1L]] <- data.frame(
      rule_id = spec$id, family = spec$family,
      status = if (evaluated) "evaluee" else "non_evaluee",
      n_findings = if (evaluated) length(result) else NA_integer_,
      reason = if (evaluated) NA_character_ else reason,
      stringsAsFactors = FALSE
    )
  }
  structure(
    list(findings = findings, rules = do.call(rbind, rows)),
    class = "referee_report"
  )
}

#' @export
as.data.frame.referee_report <- function(x, ...) {
  if (length(x$findings) == 0L) {
    return(data.frame(rule_id = character(), severity = character(),
                      location = character(), message = character(),
                      stringsAsFactors = FALSE))
  }
  data.frame(
    rule_id = vapply(x$findings, function(f) f$rule_id, character(1)),
    severity = vapply(x$findings, function(f) f$severity, character(1)),
    location = vapply(x$findings, function(f) f$location, character(1)),
    message = vapply(x$findings, function(f) f$message, character(1)),
    stringsAsFactors = FALSE
  )
}

#' @export
print.referee_report <- function(x, ...) {
  rules <- x$rules
  n_eval <- sum(rules$status == "evaluee")
  cat("Rapport d'audit du R\u00e9f\u00e9r\u00e9\n")
  cat(sprintf("%d r\u00e8gle(s) \u00e9valu\u00e9e(s) sur %d ; %d non \u00e9valu\u00e9e(s).\n",
              n_eval, nrow(rules), nrow(rules) - n_eval))
  if (length(x$findings) == 0L) {
    cat("\nAucune alerte parmi les r\u00e8gles \u00e9valu\u00e9es. Cela ne vaut pas validation",
        "de l'analyse.\n")
  } else {
    for (sev in SEVERITIES) {
      sel <- Filter(function(f) f$severity == sev, x$findings)
      if (length(sel) == 0L) next
      cat(sprintf("\n== %s (%d) ==\n", SEVERITY_LABELS[[sev]], length(sel)))
      for (f in sel) print(f)
    }
    cat("\nL'absence d'alerte sur une r\u00e8gle ne vaut pas validation.\n")
  }
  skipped <- rules[rules$status == "non_evaluee", , drop = FALSE]
  if (nrow(skipped) > 0L) {
    cat("\nR\u00e8gles non \u00e9valu\u00e9es :\n")
    for (i in seq_len(nrow(skipped))) {
      cat(sprintf("  %s : %s\n", skipped$rule_id[i], skipped$reason[i]))
    }
  }
  invisible(x)
}
