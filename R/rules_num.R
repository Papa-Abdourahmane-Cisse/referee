# Famille NUM : cohérence numérique ------------------------------------------

#' NUM-01 : bornes et échelles
#'
#' Pour chaque colonne de `scales`, signale les valeurs hors de [0 ; 1]
#' (`"proportion"`) ou de [0 ; 100] (`"percent"` et `"auto"`). Constat de
#' certitude.
#'
#' Pour une colonne déclarée `"auto"`, signale aussi un mélange probable de
#' proportions et de pourcentages : des valeurs inférieures ou égales à 1 et
#' des valeurs supérieures à 1 présentes en nombre et en part notables. Ce
#' second constat n'est qu'un risque probable : un pourcentage faible et un
#' pourcentage élevé peuvent coexister légitimement. Les seuils
#' `mixed_min_n` et `mixed_min_share` sont des conventions de pratique à
#' calibrer.
#'
#' @param data Data frame.
#' @param scales Vecteur nommé des échelles déclarées (voir [referee_meta()]).
#' @param tol Tolérance numérique sur les bornes.
#' @param mixed_min_n,mixed_min_share Effectif et part minimaux de chaque
#'   côté de 1 pour déclarer un mélange d'échelles.
#' @return Liste de constats.
#' @export
num01_bounds <- function(data, scales, tol = 1e-9, mixed_min_n = 5L,
                         mixed_min_share = 0.05) {
  out <- list()
  for (col in names(scales)) {
    x <- data[[col]]
    if (!is.numeric(x)) {
      stop(sprintf("La colonne `%s` n'est pas num\u00e9rique.", col), call. = FALSE)
    }
    scale <- scales[[col]]
    upper <- if (scale == "proportion") 1 else 100
    bad <- !is.na(x) & (x < -tol | x > upper + tol)
    if (any(bad)) {
      out[[length(out) + 1L]] <- new_finding(
        "NUM-01", "certitude",
        sprintf(paste0("%d valeur(s) de `%s` hors de [0 ; %s] (minimum ",
                       "observ\u00e9 : %s, maximum observ\u00e9 : %s)."),
                sum(bad), col, fr_num(upper), fr_num(min(x, na.rm = TRUE)),
                fr_num(max(x, na.rm = TRUE))),
        location = col, details = list(n = sum(bad), upper = upper)
      )
    }
    if (scale == "auto") {
      v <- x[!is.na(x) & x >= -tol & x <= 100 + tol]
      low <- sum(v <= 1 + tol)
      high <- sum(v > 1 + tol)
      if (low >= mixed_min_n && high >= mixed_min_n &&
            low / length(v) >= mixed_min_share &&
            high / length(v) >= mixed_min_share) {
        out[[length(out) + 1L]] <- new_finding(
          "NUM-01", "risque_probable",
          sprintf(paste0("\u00c9chelles probablement m\u00e9lang\u00e9es dans `%s` : %d ",
                         "valeur(s) inf\u00e9rieure(s) ou \u00e9gale(s) \u00e0 1 et %d ",
                         "sup\u00e9rieure(s) \u00e0 1 (proportions et pourcentages ?)."),
                  col, low, high),
          location = col, details = list(low = low, high = high)
        )
      }
    }
  }
  out
}

#' NUM-02 : sommes et parts
#'
#' Pour chaque contrôle de `sums`, compare la somme ligne à ligne des colonnes
#' `parts` au total déclaré (colonne `total`) ou à une valeur attendue
#' (`target`), avec une tolérance d'arrondi absolue. Constat de certitude.
#'
#' @param data Data frame.
#' @param sums Liste de contrôles (voir [referee_meta()]).
#' @return Liste de constats.
#' @export
num02_sums <- function(data, sums) {
  out <- list()
  for (s in sums) {
    tol <- if (is.null(s$tol)) 0.5 else s$tol
    total <- rowSums(data[s$parts])
    reference <- if (is.null(s$total)) s$target else data[[s$total]]
    diff <- abs(total - reference)
    bad <- !is.na(diff) & diff > tol
    if (any(bad)) {
      label <- if (is.null(s$total)) {
        sprintf("la valeur attendue %s", fr_num(s$target))
      } else {
        sprintf("le total `%s`", s$total)
      }
      out[[length(out) + 1L]] <- new_finding(
        "NUM-02", "certitude",
        sprintf(paste0("%d ligne(s) o\u00f9 la somme de %s s'\u00e9carte de %s de plus ",
                       "de %s (\u00e9cart maximal : %s)."),
                sum(bad), paste0("`", s$parts, "`", collapse = ", "), label,
                fr_num(tol), fr_num(max(diff[bad]))),
        location = paste(s$parts, collapse = ", "),
        details = list(n = sum(bad), max_diff = max(diff[bad]))
      )
    }
  }
  out
}

#' NUM-03 : ordre des indices FGT
#'
#' Pour tout seuil et tout agrégat, FGT2 <= FGT1 <= FGT0 (l'écart relatif
#' normalisé est compris entre 0 et 1, donc son carré est inférieur à
#' l'écart, lui-même inférieur à l'indicatrice de pauvreté). Une violation
#' est un constat de certitude.
#'
#' @param data Data frame.
#' @param cols Trois noms de colonnes, dans l'ordre FGT0, FGT1, FGT2.
#' @param tol Tolérance numérique.
#' @return Liste de constats.
#' @export
num03_fgt_order <- function(data, cols, tol = 1e-9) {
  f0 <- data[[cols[1L]]]
  f1 <- data[[cols[2L]]]
  f2 <- data[[cols[3L]]]
  out <- list()
  v01 <- !is.na(f0) & !is.na(f1) & f1 > f0 + tol
  v12 <- !is.na(f1) & !is.na(f2) & f2 > f1 + tol
  if (any(v01)) {
    out[[length(out) + 1L]] <- new_finding(
      "NUM-03", "certitude",
      sprintf("%d ligne(s) o\u00f9 `%s` d\u00e9passe `%s`, ce qui est impossible.",
              sum(v01), cols[2L], cols[1L]),
      location = paste(cols[1:2], collapse = ", "), details = list(n = sum(v01)))
  }
  if (any(v12)) {
    out[[length(out) + 1L]] <- new_finding(
      "NUM-03", "certitude",
      sprintf("%d ligne(s) o\u00f9 `%s` d\u00e9passe `%s`, ce qui est impossible.",
              sum(v12), cols[3L], cols[2L]),
      location = paste(cols[2:3], collapse = ", "), details = list(n = sum(v12)))
  }
  out
}

#' NUM-04 : codes de valeurs manquantes traités comme des valeurs
#'
#' Pour chaque colonne numérique, signale la présence d'un code usuel de
#' valeur manquante (99, 999, 9999, ... ou leurs opposés) lorsqu'il se
#' détache nettement des autres valeurs : supérieur ou égal à `factor` fois
#' le maximum des autres valeurs, ou négatif alors que toutes les autres
#' sont positives ou nulles. Un 99 dans une colonne d'âges qui monte
#' légitimement à 98 n'est donc pas signalé. Risque probable : seule la
#' documentation du questionnaire tranche.
#'
#' @param data Data frame.
#' @param sentinels Codes à rechercher.
#' @param min_other Nombre minimal d'autres valeurs pour juger.
#' @param factor Facteur de détachement pour les codes positifs.
#' @return Liste de constats.
#' @export
num04_missing_codes <- function(
    data,
    sentinels = c(99, 999, 9999, 99999, -99, -999, -9999, -99999),
    min_other = 5L, factor = 2) {
  out <- list()
  for (col in names(data)) {
    x <- data[[col]]
    if (!is.numeric(x)) next
    others <- x[!is.na(x) & !(x %in% sentinels)]
    if (length(others) < min_other) next
    found <- character()
    for (s in sentinels) {
      n_s <- sum(x == s, na.rm = TRUE)
      if (n_s == 0L) next
      detached <- if (s > 0) {
        max(others) > 0 && s >= factor * max(others)
      } else {
        min(others) >= 0
      }
      if (detached) found <- c(found, sprintf("%g (%d fois)", s, n_s))
    }
    if (length(found) > 0L) {
      out[[length(out) + 1L]] <- new_finding(
        "NUM-04", "risque_probable",
        sprintf(paste0("`%s` contient des valeurs qui ressemblent \u00e0 des ",
                       "codes de valeur manquante : %s. Utilis\u00e9es telles ",
                       "quelles dans un calcul, elles faussent moyennes et ",
                       "totaux."), col, paste(found, collapse = ", ")),
        location = col
      )
    }
  }
  out
}
