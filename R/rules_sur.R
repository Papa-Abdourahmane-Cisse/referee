# Famille SUR : plan de sondage et pondération -------------------------------

#' SUR-01 : estimateur sans poids alors qu'une variable de poids est déclarée
#'
#' Signale les appels à des estimateurs usuels (`mean`, `lm`, etc.) dont les
#' arguments ne citent ni la variable de poids ni un argument `weights`. Les
#' variantes pondérées (`weighted.mean`, `svymean`) ne sont pas concernées.
#'
#' Les pipes magrittr (`%>%`) sont dépliés et les appels situés dans un verbe
#' de manipulation de table (`summarise()`, `mutate()`, etc.) sont rattachés à
#' la table de départ : `enes %>% summarise(m = mean(x))` est reconnu comme un
#' calcul sur `enes`.
#'
#' Limite connue : un appel qui cite la variable de poids sans l'utiliser
#' comme poids (par exemple pour filtrer) échappe à la règle. Un objet
#' intermédiaire (`d2 <- enes %>% filter(...)`, puis `mean(d2$x)`) n'est pas
#' relié à `enes`.
#'
#' @param script Objet issu de [parse_script()].
#' @param weights Nom de la variable de poids.
#' @param data_objects Noms des objets de données du script. Si fourni, seuls
#'   les appels qui citent l'un d'eux sont examinés.
#' @param estimators Noms des fonctions considérées comme des estimateurs.
#' @return Liste de constats (confiance : risque probable).
#' @export
sur01_unweighted_estimators <- function(
    script, weights, data_objects = NULL,
    estimators = c("mean", "median", "quantile", "var", "sd", "lm", "glm",
                   "t.test", "cor")) {
  out <- list()
  for (rec in collect_calls(script)) {
    if (is.na(rec$name) || !rec$name %in% estimators) next
    tokens <- expr_tokens(rec$call)
    if (!is.null(data_objects) &&
          !any(data_objects %in% c(tokens, rec$ctx))) next
    if (weights %in% tokens) next
    if ("weights" %in% names(rec$call)) next
    out[[length(out) + 1L]] <- new_finding(
      "SUR-01", "risque_probable",
      sprintf(paste0("`%s()` est appel\u00e9 sans la variable de poids `%s` ",
                     "d\u00e9clar\u00e9e. Si ces donn\u00e9es sont issues d'une enqu\u00eate, ",
                     "l'estimation n'est pas pond\u00e9r\u00e9e."),
              rec$name, weights),
      location = call_location(rec)
    )
  }
  out
}

#' SUR-02 : poids ménage divisé par la taille du ménage
#'
#' Détecte l'expression `poids / taille`. Pour un indicateur individuel
#' calculé sur une enquête ménages, le poids individuel est généralement le
#' poids du ménage multiplié par sa taille (chaque ménage répliqué autant de
#' fois que de membres, avec son poids complet). La convention exacte dépend
#' de la documentation de chaque enquête : la règle alerte, elle ne tranche pas.
#'
#' Limite connue : seule la division écrite dans le script est détectée, pas
#' l'usage du poids ménage tel quel sur un indicateur individuel.
#'
#' @inheritParams sur01_unweighted_estimators
#' @param size Nom de la variable de taille du ménage.
#' @return Liste de constats (confiance : risque probable).
#' @export
sur02_weight_divided_by_size <- function(script, weights, size) {
  out <- list()
  for (rec in collect_calls(script)) {
    if (!identical(rec$name, "/") || length(rec$call) != 3L) next
    numerator <- expr_tokens(rec$call[[2L]])
    denominator <- expr_tokens(rec$call[[3L]])
    if (weights %in% numerator && size %in% denominator) {
      out[[length(out) + 1L]] <- new_finding(
        "SUR-02", "risque_probable",
        sprintf(paste0("Le poids `%s` est divis\u00e9 par `%s`. Pour un indicateur ",
                       "individuel, le poids individuel est en g\u00e9n\u00e9ral le ",
                       "produit de ces deux variables (\u00e0 confirmer dans la ",
                       "documentation de l'enqu\u00eate)."), weights, size),
        location = call_location(rec)
      )
    }
  }
  out
}

#' SUR-03 : plan de sondage ignoré dans l'estimation de la variance
#'
#' Quand des strates ou des grappes sont déclarées, signale les régressions et
#' tests de base R appelés sans qu'aucun plan de sondage (`svydesign`,
#' `as_survey_design`, etc.) ne soit défini dans le script.
#'
#' Indépendamment des métadonnées, signale aussi un plan construit sans grappe
#' (`svydesign(ids = ~1, ...)`) : confiance « à justifier » (le tirage peut
#' réellement être sans grappe, ou les grappes peuvent être absentes de la
#' base), et « risque probable » si une grappe est déclarée dans `psu`.
#'
#' @param script Objet issu de [parse_script()].
#' @param strata,psu Noms des variables de strate et de grappe (facultatifs ;
#'   sans eux, seul le contrôle d'un plan sans grappe s'applique).
#' @param tests Noms des fonctions considérées comme ignorant le plan.
#' @param design_constructors Noms des fonctions qui déclarent un plan.
#' @return Liste de constats, ou une règle non évaluée si ni strate ni grappe
#'   n'est déclarée et qu'aucun plan de sondage ne figure dans le script.
#' @export
sur03_design_ignored <- function(
    script, strata = NULL, psu = NULL,
    tests = c("lm", "glm", "t.test", "chisq.test", "wilcox.test", "aov",
              "cor.test"),
    design_constructors = c("svydesign", "as_survey_design", "svrepdesign",
                            "as_survey_rep", "as_survey")) {
  calls <- collect_calls(script)
  names_called <- vapply(calls, function(r) r$name, character(1))
  constructors <- Filter(function(r) !is.na(r$name) &&
                           r$name %in% design_constructors, calls)
  out <- list()
  # (a) plan déclaré sans grappe : `svydesign(ids = ~1, ...)`
  for (rec in constructors) {
    ids <- design_ids(rec$call)
    if (is.null(ids) || !ids$none) next
    declared <- !is.null(psu)
    out[[length(out) + 1L]] <- new_finding(
      "SUR-03", if (declared) "risque_probable" else "a_justifier",
      sprintf(paste0("`%s()` est construit sans grappe (`ids = %s`)%s. Les ",
                     "erreurs standards supposent alors des unit\u00e9s ind\u00e9pendantes ",
                     ": elles sont sous-estim\u00e9es si le tirage est en grappes ",
                     "(zones de d\u00e9nombrement, villages). \u00c0 justifier par le plan ",
                     "de l'enqu\u00eate."),
              rec$name, ids$text,
              if (declared) sprintf(" alors que la grappe `%s` est d\u00e9clar\u00e9e", psu) else ""),
      location = call_location(rec))
  }
  # (b) tests de base R sans plan, quand strates ou grappes sont déclarées
  if (is.null(strata) && is.null(psu)) {
    if (length(constructors) == 0L) {
      return(not_evaluated(paste0("ni strate ni grappe d\u00e9clar\u00e9e, et ",
                                  "aucun plan de sondage dans le script")))
    }
    return(out)
  }
  if (length(constructors) > 0L) {
    return(out)
  }
  declared <- paste(c(strata, psu), collapse = ", ")
  for (rec in calls) {
    if (is.na(rec$name) || !rec$name %in% tests) next
    out[[length(out) + 1L]] <- new_finding(
      "SUR-03", "risque_probable",
      sprintf(paste0("`%s()` est appel\u00e9 sans plan de sondage (strates ou ",
                     "grappes d\u00e9clar\u00e9es : %s). Erreurs standards et ",
                     "intervalles de confiance supposent un tirage al\u00e9atoire ",
                     "simple."), rec$name, declared),
      location = call_location(rec))
  }
  out
}

# Argument de grappes d'un appel `svydesign()` : `ids`/`id`, ou le premier
# argument positionnel. Renvoie list(text, none) ; `none` vaut TRUE pour
# `~1` ou `~0` (aucune grappe), NULL si l'argument est absent.
design_ids <- function(cl) {
  nms <- names(cl)
  if (is.null(nms)) nms <- rep("", length(cl))
  idx <- which(nms %in% c("ids", "id"))
  if (length(idx) == 0L) {
    pos <- which(nms[-1L] == "") + 1L
    if (length(pos) == 0L) return(NULL)
    idx <- pos[[1L]]
  }
  e <- cl[[idx[[1L]]]]
  txt <- paste(deparse(e), collapse = "")
  none <- (is.call(e) && identical(e[[1L]], as.name("~")) && length(e) == 2L &&
             (identical(e[[2L]], 1) || identical(e[[2L]], 0))) ||
    identical(e, 1) || identical(e, 0)
  list(text = txt, none = none)
}

#' SUR-04 : poids invalides
#'
#' Constats de certitude : poids manquants, infinis ou négatifs. Constats à
#' justifier : poids nuls (observations exclues de toute estimation pondérée)
#' et dispersion extrême, mesurée par le rapport du maximum à la médiane des
#' poids strictement positifs. Le seuil de dispersion est une convention de
#' pratique, pas un résultat établi : à calibrer selon l'enquête.
#'
#' @param data Data frame.
#' @param weights Nom de la variable de poids.
#' @param ratio_max_median Seuil de dispersion (100 par défaut).
#' @return Liste de constats.
#' @export
sur04_weights_valid <- function(data, weights, ratio_max_median = 100) {
  w <- data[[weights]]
  if (!is.numeric(w)) {
    stop(sprintf("La variable de poids `%s` n'est pas num\u00e9rique.", weights),
         call. = FALSE)
  }
  out <- list()
  add <- function(severity, message, details) {
    out[[length(out) + 1L]] <<- new_finding(
      "SUR-04", severity, message, location = weights, details = details)
  }
  n <- length(w)
  n_na <- sum(is.na(w))
  n_inf <- sum(is.infinite(w))
  n_neg <- sum(w < 0, na.rm = TRUE)
  n_zero <- sum(w == 0, na.rm = TRUE)
  if (n_na > 0L) {
    add("certitude", sprintf("%d poids manquant(s) sur %d observations.",
                             n_na, n), list(n = n_na))
  }
  if (n_inf > 0L) {
    add("certitude", sprintf("%d poids infini(s) sur %d observations.",
                             n_inf, n), list(n = n_inf))
  }
  if (n_neg > 0L) {
    add("certitude", sprintf("%d poids n\u00e9gatif(s) sur %d observations.",
                             n_neg, n), list(n = n_neg))
  }
  if (n_zero > 0L) {
    add("a_justifier",
        sprintf(paste0("%d poids nul(s) sur %d observations : ces ",
                       "observations n'entrent dans aucune estimation ",
                       "pond\u00e9r\u00e9e."), n_zero, n),
        list(n = n_zero))
  }
  positive <- w[is.finite(w) & w > 0]
  if (length(positive) > 0L) {
    ratio <- max(positive) / stats::median(positive)
    if (ratio > ratio_max_median) {
      add("a_justifier",
          sprintf(paste0("Dispersion extr\u00eame des poids : le maximum vaut %s ",
                         "fois la m\u00e9diane (seuil indicatif : %s)."),
                  fr_num(ratio, 3), fr_num(ratio_max_median)),
          list(ratio = ratio, seuil = ratio_max_median))
    }
  }
  out
}
