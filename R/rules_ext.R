# Famille EXT : cohérence externe ---------------------------------------------
#
# Ces règles comparent le travail à une référence que l'utilisateur déclare. Un
# écart n'est pas une erreur en soi : la statistique officielle n'est pas
# supérieure par principe à une estimation de recherche, et un écart peut venir
# de la période, de la population, de la définition, du seuil, de la
# pondération, de la méthode ou de la couverture géographique.

GAP_CAUSES <- paste0("p\u00e9riode, population, d\u00e9finition de l'indicateur, seuil, ",
                     "pond\u00e9ration, m\u00e9thode d'estimation, couverture g\u00e9ographique")

# Valide une liste de références (voir `referee_meta()`).
check_references <- function(references) {
  ok <- is.list(references) && length(references) > 0L &&
    all(vapply(references, function(r) {
      is.list(r) && is.character(r$name) && length(r$name) == 1L &&
        is.numeric(r$reference) && length(r$reference) == 1L &&
        is.finite(r$reference) &&
        xor(is.null(r$var), is.null(r$estimate)) &&
        is.numeric(r$tol) && length(r$tol) == 1L && r$tol >= 0 &&
        (is.null(r$tol_type) || r$tol_type %in% c("absolute", "relative"))
    }, logical(1)))
  if (!ok) {
    stop("Chaque \u00e9l\u00e9ment de `references` doit contenir `name`, `reference` ",
         "(nombre), `tol` (tol\u00e9rance), exactement l'un de `var` ou ",
         "`estimate`, et \u00e9ventuellement `tol_type` (\"absolute\" ou \"relative\").",
         call. = FALSE)
  }
  invisible(references)
}

#' EXT-01 : écart avec une valeur de référence déclarée
#'
#' Pour chaque référence déclarée (valeur officielle ou publiée), compare
#' l'estimation du travail à cette valeur. L'estimation est soit fournie
#' (`estimate`), soit calculée comme la moyenne d'une variable (`var`),
#' pondérée si une variable de poids est déclarée, simple sinon (le message le
#' précise). Un écart supérieur à la tolérance est un constat à justifier : le
#' rapport liste les causes à examiner. La règle ne dit pas laquelle des deux
#' valeurs est la bonne.
#'
#' Si l'estimation, multipliée ou divisée par 100, se rapproche de la
#' référence, le message signale un possible écart d'échelle (proportion et
#' pourcentage). La moyenne d'une variable 0/1 est une proportion d'unités
#' (ménages ou individus selon les lignes) : c'est à l'utilisateur de vérifier
#' que l'unité d'analyse est celle de la référence.
#'
#' @param data Data frame, ou `NULL` si toutes les références fournissent
#'   `estimate`.
#' @param references Liste de références (voir [referee_meta()]).
#' @param weights Nom de la variable de poids, ou `NULL`.
#' @return Liste de constats (confiance : à justifier), ou une règle non
#'   évaluée si aucune référence n'a pu être calculée.
#' @export
ext01_reference_gap <- function(data = NULL, references, weights = NULL) {
  check_references(references)
  out <- list()
  evaluated <- 0L
  for (ref in references) {
    how <- NULL
    if (!is.null(ref$estimate)) {
      est <- ref$estimate
      how <- "estimation fournie"
    } else {
      if (is.null(data)) next
      x <- data[[ref$var]]
      if (!is.numeric(x)) {
        stop(sprintf("La variable `%s` n'est pas num\u00e9rique.", ref$var),
             call. = FALSE)
      }
      if (!is.null(weights)) {
        w <- data[[weights]]
        ok <- !is.na(x) & !is.na(w)
        est <- stats::weighted.mean(x[ok], w[ok])
        how <- sprintf("moyenne de `%s` pond\u00e9r\u00e9e par `%s`", ref$var, weights)
      } else {
        est <- mean(x, na.rm = TRUE)
        how <- sprintf("moyenne simple de `%s` (aucun poids d\u00e9clar\u00e9)", ref$var)
      }
    }
    evaluated <- evaluated + 1L
    tol_type <- if (is.null(ref$tol_type)) "absolute" else ref$tol_type
    gap <- abs(est - ref$reference)
    exceeds <- if (tol_type == "relative") {
      ref$reference != 0 && gap / abs(ref$reference) > ref$tol
    } else {
      gap > ref$tol
    }
    if (!exceeds) next
    hint <- ""
    scaled <- c(est * 100, est / 100)
    if (any(abs(scaled - ref$reference) <= max(ref$tol, 1e-12))) {
      hint <- paste0(" L'\u00e9cart dispara\u00eet \u00e0 un facteur 100 pr\u00e8s : v\u00e9rifier ",
                     "l'\u00e9chelle (proportion ou pourcentage).")
    }
    out[[length(out) + 1L]] <- new_finding(
      "EXT-01", "a_justifier",
      sprintf(paste0("`%s` : estimation %s (%s), r\u00e9f\u00e9rence %s, \u00e9cart %s, au-del\u00e0 ",
                     "de la tol\u00e9rance (%s, %s). Causes \u00e0 examiner : %s.%s"),
              ref$name, fr_num(est, 5), how, fr_num(ref$reference, 5),
              fr_num(gap, 3), fr_num(ref$tol),
              if (tol_type == "relative") "relative" else "absolue",
              GAP_CAUSES, hint),
      location = ref$name,
      details = list(estimate = est, reference = ref$reference, gap = gap))
  }
  if (evaluated == 0L) {
    return(not_evaluated(
      "donn\u00e9es non fournies pour calculer les estimations des r\u00e9f\u00e9rences"))
  }
  out
}

#' EXT-02 : ligne de pauvreté et agrégat de bien-être incohérents
#'
#' Contrôle uniquement des métadonnées déclarées : année de la ligne de
#' pauvreté (`line_year`) et de l'agrégat de bien-être (`welfare_year`), si
#' l'agrégat a été ajusté des prix à l'année de la ligne (`price_adjusted`),
#' unité de comptage (`line_unit` et `welfare_unit`, par exemple « par tête »
#' ou « par équivalent adulte ») et période (`line_period` et
#' `welfare_period`, par exemple « jour » ou « an »). Une incohérence entre
#' deux déclarations est un risque probable ; la règle ne vérifie ni la
#' valeur de la ligne ni la qualité du déflateur, et elle n'est pas évaluée
#' si aucune paire de déclarations n'est comparable.
#'
#' @param poverty Liste nommée des éléments ci-dessus (voir [referee_meta()]).
#' @return Liste de constats (confiance : risque probable).
#' @export
ext02_poverty_line_consistency <- function(poverty) {
  out <- list()
  comparable <- 0L
  add <- function(msg, loc) {
    out[[length(out) + 1L]] <<- new_finding("EXT-02", "risque_probable", msg,
                                            location = loc)
  }
  norm <- function(x) tolower(trimws(as.character(x)))
  ly <- poverty$line_year
  wy <- poverty$welfare_year
  if (!is.null(ly) && !is.null(wy)) {
    comparable <- comparable + 1L
    if (!identical(as.character(ly), as.character(wy)) &&
          !isTRUE(poverty$price_adjusted)) {
      add(sprintf(paste0("La ligne de pauvret\u00e9 date de %s et l'agr\u00e9gat de ",
                         "bien-\u00eatre de %s, sans ajustement des prix d\u00e9clar\u00e9 ",
                         "(`price_adjusted`). Appliquer le seuil d'une ann\u00e9e \u00e0 une ",
                         "consommation d'une autre ann\u00e9e sans d\u00e9flateur fausse ",
                         "les indices de pauvret\u00e9."), ly, wy),
          "line_year, welfare_year")
    }
  }
  for (pair in list(c("line_unit", "welfare_unit", "unit\u00e9"),
                    c("line_period", "welfare_period", "p\u00e9riode"))) {
    a <- poverty[[pair[1L]]]
    b <- poverty[[pair[2L]]]
    if (is.null(a) || is.null(b)) next
    comparable <- comparable + 1L
    if (!identical(norm(a), norm(b))) {
      add(sprintf(paste0("%s de la ligne de pauvret\u00e9 (\u00ab %s \u00bb) diff\u00e9rente de ",
                         "celle de l'agr\u00e9gat de bien-\u00eatre (\u00ab %s \u00bb)."),
                  tools::toTitleCase(pair[3L]), a, b),
          paste(pair[1:2], collapse = ", "))
    }
  }
  if (comparable == 0L) {
    return(not_evaluated(
      "aucune paire de d\u00e9clarations comparable (ann\u00e9es, unit\u00e9s ou p\u00e9riodes)"))
  }
  out
}
