# Famille ECO : économétrie et identification ---------------------------------
#
# Contrôles sur des analyses déjà réalisées ; aucune règle ne remplace le
# raisonnement d'identification. Les règles statiques lisent le script sans
# l'exécuter et ne voient que ce qui y est écrit.

ECO_REGRESSIONS <- c("lm", "glm", "plm", "ivreg", "lm_robust", "feols", "felm",
                     "feglm", "fepois")
CLUSTER_FUNCTIONS <- c("vcovCL", "vcovCR", "vcovBS", "vcovPL", "cluster.vcov",
                       "cluster_vcov", "svydesign", "as_survey_design")
CLUSTER_ARGUMENTS <- c("cluster", "clusters", "cluster_id", "clustervar",
                       "vcov")
HETEROGENEITY_ROBUST <- c("att_gt", "aggte", "did_imputation", "did2s",
                          "eventstudyinteract", "sunab", "bacon",
                          "did_multiplegt", "did_multiplegt_dyn", "csdid",
                          "etwfe", "fect", "synthdid", "staggered")
PRETREND_FUNCTIONS <- c("sunab", "att_gt", "aggte", "ggdid", "HonestDiD",
                        "pretrends", "event_study", "did_imputation",
                        "eventstudyinteract", "did_multiplegt", "csdid")
DENSITY_TESTS <- c("rddensity", "DCdensity", "rdplotdensity")

script_tokens <- function(script) {
  unlist(lapply(script$exprs, expr_tokens), use.names = FALSE)
}

#' ECO-01 : erreurs standards non robustes à la structure de grappes
#'
#' Quand une variable de grappe est déclarée (panel, observations groupées),
#' signale les régressions `lm()`, `glm()`, `plm()` et `ivreg()` si aucun
#' ajustement des erreurs standards pour les grappes n'apparaît dans le
#' script (`vcovCL()`, `vcovCR()`, argument `cluster`, `clusters` ou `vcov`,
#' plan de sondage). Une correction robuste à l'hétéroscédasticité seule
#' (`vcovHC()`) ne tient pas compte des grappes.
#'
#' La nécessité de regrouper dépend du plan d'échantillonnage et de
#' l'assignation du traitement : la règle demande une justification, elle ne
#' tranche pas. Limite connue : un seul ajustement en grappes n'importe où dans
#' le script suffit à la faire taire. Les régressions `feols()` et `felm()`
#' ne sont pas signalées : leurs erreurs standards par défaut dépendent de
#' la version et des effets fixes.
#'
#' @param script Objet issu de [parse_script()].
#' @param cluster Nom de la variable de grappe déclarée.
#' @return Liste de constats (confiance : risque probable).
#' @export
eco01_cluster_se <- function(script, cluster) {
  calls <- collect_calls(script)
  handled <- vapply(calls, function(r) {
    (!is.na(r$name) && r$name %in% CLUSTER_FUNCTIONS) ||
      any(CLUSTER_ARGUMENTS %in% names(r$call))
  }, logical(1))
  if (any(handled)) return(list())
  out <- list()
  for (rec in calls) {
    if (is.na(rec$name) || !rec$name %in% c("lm", "glm", "plm", "ivreg")) next
    out[[length(out) + 1L]] <- new_finding(
      "ECO-01", "risque_probable",
      sprintf(paste0("`%s()` est estim\u00e9 sans erreurs standards robustes aux ",
                     "grappes (`%s`). Si les observations sont corr\u00e9l\u00e9es au ",
                     "sein des grappes, les erreurs standards sont ",
                     "sous-estim\u00e9es."), rec$name, cluster),
      location = call_location(rec), details = list(cluster = cluster))
  }
  out
}

# Date d'adoption (rang de la période) de chaque unité ; NA pour les unités
# jamais traitées. Le traitement doit être codé 0/1 (ou logique).
adoption_ranks <- function(data, unit, time, treat) {
  d <- as.numeric(data[[treat]])
  if (!all(d %in% c(0, 1, NA))) {
    stop(sprintf("Le traitement `%s` doit \u00eatre cod\u00e9 0/1.", treat), call. = FALSE)
  }
  u <- data[[unit]]
  t <- data[[time]]
  keep <- !is.na(d) & !is.na(t) & !is.na(u)
  rank_t <- match(t[keep], sort(unique(t[keep])))
  d <- d[keep]
  u <- u[keep]
  first <- as.vector(tapply(ifelse(d == 1, rank_t, NA_integer_), u, function(z) {
    if (all(is.na(z))) NA_integer_ else min(z, na.rm = TRUE)
  }))
  list(first = first, periods = sort(unique(t[keep])))
}

#' ECO-02 : double différence à effets fixes bidirectionnels, adoption échelonnée
#'
#' Établit à partir des données que les unités adoptent le traitement à des
#' dates différentes (au moins deux dates d'adoption distinctes, hors unités
#' traitées dès la première période), puis signale les régressions à effets
#' fixes d'unité et de période (`feols()`, `felm()`, `plm()`, `lm()` avec
#' facteurs) qui citent le traitement, l'unité et le temps, en l'absence
#' d'estimateur robuste à l'hétérogénéité des effets dans le script
#' (`att_gt()`, `did_imputation()`, `sunab()`, etc.).
#'
#' Le fait (adoption échelonnée) est établi par les données ; le biais ne
#' l'est pas : il suppose des effets de traitement hétérogènes dans le temps
#' ou entre cohortes. D'où un risque probable. Limites : un traitement qui
#' s'arrête puis reprend n'est pas traité spécifiquement ; une régression
#' qui cite les trois variables sans être à effets fixes bidirectionnels
#' peut être signalée à tort ; le temps est ordonné par ses valeurs
#' (une période codée en texte est ordonnée alphabétiquement).
#'
#' @param data Data frame (panel).
#' @param script Objet issu de [parse_script()].
#' @param unit,time,treat Noms des variables d'unité, de période et de
#'   traitement (0/1, absorbant).
#' @return Liste de constats (confiance : risque probable).
#' @export
eco02_staggered_twfe <- function(data, script, unit, time, treat) {
  a <- adoption_ranks(data, unit, time, treat)
  cohorts <- sort(unique(stats::na.omit(a$first)))
  cohorts <- cohorts[cohorts > 1L] # trait\u00e9s d\u00e8s la premi\u00e8re p\u00e9riode exclus
  if (length(cohorts) < 2L) return(list())
  calls <- collect_calls(script)
  if (has_call(calls, HETEROGENEITY_ROBUST)) return(list())
  out <- list()
  for (rec in calls) {
    if (is.na(rec$name) || !rec$name %in% ECO_REGRESSIONS) next
    if (!all(c(treat, unit, time) %in% expr_tokens(rec$call))) next
    dates <- as.character(a$periods[cohorts])
    shown <- paste(utils::head(dates, 5L), collapse = ", ")
    if (length(dates) > 5L) shown <- paste0(shown, ", ...")
    out[[length(out) + 1L]] <- new_finding(
      "ECO-02", "risque_probable",
      sprintf(paste0("`%s()` estime un effet moyen par double diff\u00e9rence \u00e0 ",
                     "effets fixes `%s` et `%s`, alors que le traitement `%s` ",
                     "est adopt\u00e9 \u00e0 %d dates diff\u00e9rentes (%s). Avec des effets ",
                     "h\u00e9t\u00e9rog\u00e8nes, l'estimateur peut \u00eatre biais\u00e9 ; ",
                     "comparer \u00e0 un estimateur robuste (`att_gt()`, ",
                     "`did_imputation()`, `sunab()`)."),
              rec$name, unit, time, treat, length(cohorts), shown),
      location = call_location(rec),
      details = list(n_cohorts = length(cohorts)))
  }
  out
}

#' ECO-03 : double différence sans examen des tendances pré-traitement
#'
#' Signale une régression qui cite la variable de traitement déclarée lorsque
#' le script ne contient aucune trace d'examen des tendances pré-traitement :
#' étude d'événement (`i(..., ref = )`, `sunab()`, `att_gt()`), retards et
#' avances (`lead`), `HonestDiD`, etc. Des tendances parallèles ne se prouvent
#' pas ; leur examen reste attendu. La règle exige une justification.
#'
#' Limite connue : la reconnaissance repose sur des noms de fonctions et de
#' variables courants ; un test de tendances écrit autrement échappe à la
#' règle, qui peut alors signaler à tort. Elle ne distingue pas une
#' double différence d'une autre régression qui cite le traitement.
#'
#' @param script Objet issu de [parse_script()].
#' @param treat Nom de la variable de traitement.
#' @return Liste d'au plus un constat (confiance : à justifier).
#' @export
eco03_pretrends <- function(script, treat) {
  calls <- collect_calls(script)
  reg <- Filter(function(r) !is.na(r$name) && r$name %in% ECO_REGRESSIONS &&
                  treat %in% expr_tokens(r$call), calls)
  if (length(reg) == 0L) return(list())
  event_i <- any(vapply(calls, function(r) {
    identical(r$name, "i") && "ref" %in% names(r$call)
  }, logical(1)))
  tokens <- script_tokens(script)
  named <- any(grepl("(^|[._])leads?([._0-9]|$)|pre[._]?trend|event[._]?stud",
                     tokens, ignore.case = TRUE))
  if (has_call(calls, PRETREND_FUNCTIONS) || event_i || named) return(list())
  list(new_finding(
    "ECO-03", "a_justifier",
    sprintf(paste0("Le traitement `%s` est r\u00e9gress\u00e9 sans trace d'examen des ",
                   "tendances pr\u00e9-traitement (ni \u00e9tude d'\u00e9v\u00e9nement, ni avances, ",
                   "ni test). \u00c0 justifier ou \u00e0 compl\u00e9ter."), treat),
    location = call_location(reg[[1L]])))
}

#' ECO-04 : instrument faible
#'
#' Calcule la statistique F de première étape : test de Fisher de la nullité
#' conjointe des coefficients des instruments dans la régression de la
#' variable endogène sur les instruments et les contrôles (mêmes lignes
#' complètes). Signale un F inférieur au seuil.
#'
#' Le calcul est exact ; sa lecture ne l'est pas. Le seuil de 10 est une
#' règle empirique à réexaminer, pas un critère universel. Ce F suppose des
#' erreurs homoscédastiques et indépendantes : avec grappes ou
#' hétéroscédasticité, un F robuste (par exemple le F effectif) est plus
#' approprié. Avec plusieurs instruments ou plusieurs régresseurs endogènes,
#' le seuil de 10 n'est pas un critère adéquat. Les pondérations ne sont pas
#' appliquées. Cette règle ne teste ni la validité (exclusion) ni
#' l'exogénéité de l'instrument. Le catalogue v0 la classe « certitude
#' (calcul) » ; le paquet retient « risque probable », car la faiblesse de
#' l'instrument est une conclusion, pas le calcul.
#'
#' @param data Data frame.
#' @param endog Nom du régresseur endogène (numérique).
#' @param instruments Noms des instruments.
#' @param controls Noms des contrôles exogènes inclus, ou `NULL`.
#' @param threshold Seuil indicatif de la statistique F.
#' @return Liste de constats, ou une règle non évaluée si le calcul est
#'   impossible.
#' @export
eco04_weak_instrument <- function(data, endog, instruments, controls = NULL,
                                  threshold = 10) {
  vars <- c(endog, instruments, controls)
  d <- data[stats::complete.cases(data[vars]), vars, drop = FALSE]
  q <- function(x) paste0("`", x, "`")
  full <- stats::lm(stats::reformulate(q(c(instruments, controls)), q(endog)), d)
  restricted <- if (length(controls) > 0L) {
    stats::lm(stats::reformulate(q(controls), q(endog)), d)
  } else {
    stats::lm(stats::as.formula(paste(q(endog), "~ 1")), d)
  }
  df1 <- restricted$df.residual - full$df.residual
  if (df1 < 1L || full$df.residual < 1L) {
    return(not_evaluated(
      "premi\u00e8re \u00e9tape non estimable (instruments colin\u00e9aires ou trop peu de lignes)"))
  }
  f <- stats::anova(restricted, full)[["F"]][2L]
  if (is.na(f)) {
    return(not_evaluated("statistique F de premi\u00e8re \u00e9tape non calculable"))
  }
  if (f >= threshold) return(list())
  list(new_finding(
    "ECO-04", "risque_probable",
    sprintf(paste0("F de premi\u00e8re \u00e9tape = %s (%d instrument(s), %d lignes ",
                   "compl\u00e8tes), inf\u00e9rieur au seuil indicatif de %s : ",
                   "l'instrument est probablement faible. F classique, ",
                   "ni robuste ni pond\u00e9r\u00e9."),
            fr_num(f, 4), df1, nrow(d), fr_num(threshold)),
    location = paste(instruments, collapse = ", "),
    details = list(F = f, df1 = df1, df2 = full$df.residual, n = nrow(d))))
}

#' ECO-05 : discontinuité de régression et manipulation du score
#'
#' Deux contrôles. (1) À partir des données : test binomial bilatéral de
#' l'égalité des effectifs dans deux fenêtres de même largeur de part et
#' d'autre du seuil (sous continuité de la densité, ils sont voisins). Un
#' rejet au niveau `alpha` signale une accumulation d'un côté du seuil. C'est
#' un criblage grossier, pas un test de manipulation : une densité de pente
#' marquée au seuil, ou des scores arrondis qui s'accumulent sur le seuil
#' lui-même, peuvent le déclencher sans manipulation. Le test de densité
#' dédié (`rddensity`) fait référence. (2) Si un script est fourni, signale
#' l'absence de tout appel à un test de densité (`rddensity()`,
#' `DCdensity()`).
#'
#' @param data Data frame.
#' @param score Nom de la variable de score (numérique).
#' @param cutoff Valeur du seuil ; le traitement est supposé attribué pour
#'   `score >= cutoff`.
#' @param script Objet issu de [parse_script()], ou `NULL`.
#' @param bandwidth Demi-largeur de la fenêtre ; 0,1 fois l'écart-type du
#'   score par défaut (convention de criblage, à calibrer).
#' @param alpha Niveau du test binomial (0,01 par défaut).
#' @param min_n Effectif minimal dans la fenêtre pour tester.
#' @return Liste de constats, ou une règle non évaluée si ni le test binomial
#'   ni le contrôle du script ne sont possibles.
#' @export
eco05_rdd_manipulation <- function(data, score, cutoff, script = NULL,
                                   bandwidth = NULL, alpha = 0.01,
                                   min_n = 20L) {
  x <- data[[score]]
  if (!is.numeric(x)) {
    stop(sprintf("Le score `%s` n'est pas num\u00e9rique.", score), call. = FALSE)
  }
  x <- x[!is.na(x)]
  out <- list()
  h <- if (is.null(bandwidth)) 0.1 * stats::sd(x) else bandwidth
  tested <- FALSE
  if (is.finite(h) && h > 0) {
    left <- sum(x >= cutoff - h & x < cutoff)
    right <- sum(x >= cutoff & x <= cutoff + h)
    n <- left + right
    if (n >= min_n) {
      tested <- TRUE
      p <- stats::binom.test(right, n, 0.5)$p.value
      if (p < alpha) {
        out[[length(out) + 1L]] <- new_finding(
          "ECO-05", "risque_probable",
          sprintf(paste0("Effectifs d\u00e9s\u00e9quilibr\u00e9s autour du seuil %s de `%s` ",
                         "(fen\u00eatre \u00b1 %s) : %d observations en dessous, %d \u00e0 ",
                         "partir du seuil (p = %s). Possible manipulation du ",
                         "score ; confirmer par un test de densit\u00e9 d\u00e9di\u00e9."),
                  fr_num(cutoff), score, fr_num(h, 3), left, right,
                  fr_num(p, 3)),
          location = score,
          details = list(left = left, right = right, p = p, h = h))
      }
    }
  }
  if (!is.null(script)) {
    if (!has_call(collect_calls(script), DENSITY_TESTS)) {
      out[[length(out) + 1L]] <- new_finding(
        "ECO-05", "a_justifier",
        paste0("Discontinuit\u00e9 de r\u00e9gression sur `", score, "` sans test ",
               "de manipulation du score dans le script (`rddensity()`, ",
               "`DCdensity()`). \u00c0 justifier ou \u00e0 compl\u00e9ter."),
        location = score)
    }
  } else if (!tested) {
    return(not_evaluated(
      "trop peu d'observations autour du seuil et aucun script fourni"))
  }
  out
}
