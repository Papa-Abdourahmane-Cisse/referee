# Famille DEM : démographie ---------------------------------------------------
#
# Règles candidates : elles viennent de la méthodologie démographique générale
# et n'ont pas été relues par un praticien du domaine. Les seuils sont des
# conventions à calibrer selon le contexte (pays, source, groupe d'âge).

# Classes de qualité usuelles de l'indice de Whipple (page « Whipple's index »
# de Wikipédia, qui reproduit le classement des Nations unies ; à confirmer
# dans la source primaire).
whipple_class <- function(index) {
  if (index < 105) "tr\u00e8s exacte" else if (index < 110) "assez exacte" else
    if (index < 125) "approximative" else if (index < 175) "grossi\u00e8re" else
      "tr\u00e8s grossi\u00e8re"
}

#' DEM-01 : préférence pour les âges se terminant par 0 ou 5
#'
#' Calcule l'indice de Whipple : 100 fois le rapport entre l'effectif des
#' personnes de 23 à 62 ans dont l'âge déclaré se termine par 0 ou 5 et le
#' cinquième de l'effectif total de cette tranche d'âges (soit 500 fois la
#' part des âges terminant par 0 ou 5). Il vaut 100 sans préférence pour ces
#' chiffres et 500 si tout le monde les déclare. Les âges sont comptés
#' avec les poids si une variable de poids est fournie ; le contrôle de
#' l'effectif minimal porte sur les observations non pondérées. Un indice
#' supérieur ou égal au seuil est un constat à justifier.
#'
#' Limites : l'indice suppose une distribution des âges assez régulière entre
#' 23 et 62 ans ; une pyramide très décroissante ou des migrations sélectives
#' le déforment. Il ne détecte que la préférence pour 0 et 5, pas les autres
#' attractions. L'indice de Myers n'est pas implémenté. Le seuil par défaut
#' (125) est celui où l'échelle usuelle passe à une qualité « grossière » ;
#' c'est une convention. Le contrôle s'applique à des âges en années
#' révolues, saisis en entiers : sinon, la règle est non évaluée.
#'
#' @param data Data frame d'individus.
#' @param age Nom de la variable d'âge (années révolues).
#' @param weights Nom de la variable de poids, ou `NULL`.
#' @param threshold Seuil de l'indice de Whipple.
#' @param min_n Effectif non pondéré minimal entre 23 et 62 ans.
#' @return Liste de constats (confiance : à justifier), ou une règle non
#'   évaluée.
#' @export
dem01_age_heaping <- function(data, age, weights = NULL, threshold = 125,
                              min_n = 500L) {
  a <- data[[age]]
  if (!is.numeric(a)) {
    stop(sprintf("L'\u00e2ge `%s` n'est pas num\u00e9rique.", age), call. = FALSE)
  }
  w <- if (is.null(weights)) rep(1, length(a)) else data[[weights]]
  keep <- !is.na(a) & !is.na(w) & a >= 23 & a <= 62
  a <- a[keep]
  w <- w[keep]
  if (length(a) < min_n) {
    return(not_evaluated(sprintf(
      "moins de %d observations de 23 \u00e0 62 ans (%d)", min_n, length(a))))
  }
  if (mean(a != round(a)) > 0.01) {
    return(not_evaluated(
      "\u00e2ges non entiers : l'indice de Whipple suppose des \u00e2ges en ann\u00e9es r\u00e9volues"))
  }
  index <- 100 * sum(w[a %% 5 == 0]) / (sum(w) / 5)
  if (index < threshold) return(list())
  list(new_finding(
    "DEM-01", "a_justifier",
    sprintf(paste0("Indice de Whipple de %s sur %d personnes de 23 \u00e0 62 ans ",
                   "(seuil : %s ; qualit\u00e9 %s dans l'\u00e9chelle usuelle). Les \u00e2ges ",
                   "se terminant par 0 ou 5 sont sur-repr\u00e9sent\u00e9s : \u00e0 justifier ou ",
                   "\u00e0 lisser avant tout calcul par groupe d'\u00e2ges."),
            fr_num(index, 4), length(a), fr_num(threshold),
            whipple_class(index)),
    location = age, details = list(index = index, n = length(a))))
}

#' DEM-02 : équation compensatrice non respectée
#'
#' Pour chaque ligne (zone, période), vérifie
#' `P1 = P0 + naissances - décès + immigrants - émigrants`, à une tolérance
#' près. Si les migrations ne sont pas déclarées, la population est supposée
#' fermée, et le message le dit. Les lignes où une composante manque sont
#' ignorées. Un écart au-delà de la tolérance est un constat de certitude :
#' l'identité déclarée n'est pas satisfaite.
#'
#' Ce que la règle ne dit pas : si l'écart vient d'une erreur de saisie, d'un
#' calcul ou d'un résidu de mesure légitime (composantes estimées
#' séparément). La tolérance est donc à choisir selon la source.
#'
#' @param data Data frame (une ligne par zone et période).
#' @param balance Liste de noms de colonnes : `p0`, `p1`, `births`, `deaths`,
#'   et éventuellement `immigrants`, `emigrants`.
#' @param tol Tolérance absolue (0,5 par défaut : arrondi à l'unité).
#' @param tol_rel Tolérance relative à `P1` (0 par défaut).
#' @return Liste de constats, ou une règle non évaluée si aucune ligne n'est
#'   complète.
#' @export
dem02_balancing_equation <- function(data, balance, tol = 0.5, tol_rel = 0) {
  check_balance(balance)
  col <- function(nm) if (is.null(balance[[nm]])) 0 else data[[balance[[nm]]]]
  p0 <- data[[balance$p0]]
  p1 <- data[[balance$p1]]
  expected <- p0 + col("births") - col("deaths") + col("immigrants") -
    col("emigrants")
  gap <- p1 - expected
  complete <- !is.na(gap)
  if (!any(complete)) {
    return(not_evaluated("aucune ligne compl\u00e8te pour l'\u00e9quation compensatrice"))
  }
  bad <- complete & abs(gap) > tol + tol_rel * abs(p1)
  if (!any(bad)) return(list())
  closed <- is.null(balance$immigrants) && is.null(balance$emigrants)
  list(new_finding(
    "DEM-02", "certitude",
    sprintf(paste0("%d ligne(s) sur %d o\u00f9 P1 s'\u00e9carte de P0 + N - D + I - E ",
                   "de plus de %s (\u00e9cart maximal : %s)%s. Erreur de saisie, de ",
                   "calcul ou r\u00e9sidu de mesure : \u00e0 trancher selon la source."),
            sum(bad), sum(complete), fr_num(tol), fr_num(max(abs(gap[bad]))),
            if (closed) " ; population suppos\u00e9e ferm\u00e9e, aucune migration d\u00e9clar\u00e9e" else ""),
    location = paste(balance$p0, balance$p1, sep = ", "),
    details = list(n = sum(bad), rows = utils::head(which(bad), 10L),
                   max_gap = max(abs(gap[bad])))))
}

check_balance <- function(balance) {
  required <- c("p0", "p1", "births", "deaths")
  valid <- c(required, "immigrants", "emigrants")
  ok <- is.list(balance) && !is.null(names(balance)) &&
    all(required %in% names(balance)) && all(names(balance) %in% valid) &&
    all(vapply(balance, function(x) is.character(x) && length(x) == 1L,
               logical(1)))
  if (!ok) {
    stop("`balance` doit nommer les colonnes `p0`, `p1`, `births`, `deaths` ",
         "et, facultativement, `immigrants` et `emigrants`.", call. = FALSE)
  }
  invisible(balance)
}

check_lifetable <- function(lifetable) {
  ok <- is.list(lifetable) && !is.null(names(lifetable)) &&
    all(names(lifetable) %in% c("age", "qx", "lx", "by")) &&
    is.character(lifetable$age) && length(lifetable$age) == 1L &&
    (!is.null(lifetable$qx) || !is.null(lifetable$lx))
  if (!ok) {
    stop("`lifetable` doit nommer la colonne `age` et au moins l'une de `qx` ",
         "ou `lx` (et facultativement `by`).", call. = FALSE)
  }
  invisible(lifetable)
}

#' DEM-03 : table de mortalité incohérente
#'
#' Deux contrôles de certitude : une probabilité de décès `qx` hors de
#' [0 ; 1], et un nombre de survivants `lx` qui augmente avec l'âge. Les
#' lignes sont ordonnées par âge, par table si `by` est fourni ; les valeurs
#' manquantes sont ignorées. La règle ne contrôle ni l'égalité
#' `l(x+n) = l(x) (1 - nqx)` ni le niveau des espérances de vie.
#'
#' @param data Data frame (une ligne par âge ou groupe d'âges).
#' @param lifetable Liste de noms de colonnes : `age`, au moins l'une de `qx`
#'   ou `lx`, et éventuellement `by` (une table par modalité).
#' @param tol Tolérance numérique.
#' @return Liste de constats (confiance : certitude).
#' @export
dem03_life_table <- function(data, lifetable, tol = 1e-9) {
  check_lifetable(lifetable)
  groups <- if (is.null(lifetable$by)) rep("table", nrow(data)) else
    as.character(data[[lifetable$by]])
  out <- list()
  for (g in unique(groups)) {
    d <- data[groups == g, , drop = FALSE]
    d <- d[order(d[[lifetable$age]]), , drop = FALSE]
    label <- if (is.null(lifetable$by)) "" else sprintf(" (table : %s)", g)
    if (!is.null(lifetable$qx)) {
      q <- d[[lifetable$qx]]
      bad <- !is.na(q) & (q < -tol | q > 1 + tol)
      if (any(bad)) {
        out[[length(out) + 1L]] <- new_finding(
          "DEM-03", "certitude",
          sprintf(paste0("%d probabilit\u00e9(s) de d\u00e9c\u00e8s `%s` hors de [0 ; 1]%s ",
                         "(minimum : %s, maximum : %s)."),
                  sum(bad), lifetable$qx, label, fr_num(min(q, na.rm = TRUE)),
                  fr_num(max(q, na.rm = TRUE))),
          location = lifetable$qx, details = list(n = sum(bad)))
      }
    }
    if (!is.null(lifetable$lx)) {
      l <- d[[lifetable$lx]]
      ages <- d[[lifetable$age]][!is.na(l)]
      l <- l[!is.na(l)]
      up <- if (length(l) > 1L) which(diff(l) > tol) + 1L else integer()
      if (length(up) > 0L) {
        out[[length(out) + 1L]] <- new_finding(
          "DEM-03", "certitude",
          sprintf(paste0("`%s` augmente avec l'\u00e2ge%s : %d hausse(s), la premi\u00e8re ",
                         "\u00e0 l'\u00e2ge %s (de %s \u00e0 %s). Les survivants ne peuvent ",
                         "que diminuer."),
                  lifetable$lx, label, length(up), ages[up[1L]], fr_num(l[up[1L] - 1L]),
                  fr_num(l[up[1L]])),
          location = lifetable$lx, details = list(n = length(up)))
      }
    }
  }
  out
}

check_sexratio <- function(sexratio) {
  micro <- c("group", "sex", "male")
  agg <- c("group", "males", "females")
  nm <- names(sexratio)
  ok <- is.list(sexratio) && !is.null(nm) &&
    (setequal(nm, micro) || setequal(nm, agg)) &&
    all(vapply(sexratio, function(x) length(x) == 1L, logical(1)))
  if (!ok) {
    stop("`sexratio` doit contenir `group`, `sex` et `male` (microdonn\u00e9es) ",
         "ou `group`, `males` et `females` (effectifs agr\u00e9g\u00e9s).", call. = FALSE)
  }
  invisible(sexratio)
}

#' DEM-04 : rapport de masculinité hors d'une plage plausible
#'
#' Calcule, par groupe d'âges, le nombre d'hommes pour 100 femmes, soit à
#' partir de microdonnées (variable de sexe et modalité masculine, avec poids
#' si fournis), soit à partir d'effectifs agrégés. Signale les groupes dont le
#' rapport sort de `range`. Les groupes comptant moins de `min_n`
#' observations (non pondérées, par sexe) sont ignorés.
#'
#' La plage par défaut (80 à 120) est indicative et à calibrer : des
#' migrations de travail, des conflits ou des décalages de couverture
#' produisent des rapports atypiques légitimes. Un rapport atypique n'est
#' pas une erreur en soi : il est à justifier.
#'
#' @param data Data frame.
#' @param sexratio Liste de noms de colonnes : `group` et, soit `sex` et
#'   `male` (modalité masculine), soit `males` et `females`.
#' @param weights Nom de la variable de poids (microdonnées), ou `NULL`.
#' @param range Plage plausible (bornes inférieure et supérieure).
#' @param min_n Effectif minimal par sexe et par groupe.
#' @return Liste d'au plus un constat (confiance : à justifier), ou une règle
#'   non évaluée si aucun groupe n'a l'effectif minimal.
#' @export
dem04_sex_ratio <- function(data, sexratio, weights = NULL, range = c(80, 120),
                            min_n = 50L) {
  check_sexratio(sexratio)
  g <- as.character(data[[sexratio$group]])
  if (!is.null(sexratio$sex)) {
    s <- data[[sexratio$sex]] == sexratio$male
    w <- if (is.null(weights)) rep(1, nrow(data)) else data[[weights]]
    ok <- !is.na(g) & !is.na(s) & !is.na(w)
    male_w <- tapply(ifelse(s[ok], w[ok], 0), g[ok], sum)
    fem_w <- tapply(ifelse(s[ok], 0, w[ok]), g[ok], sum)
    male_n <- tapply(as.integer(s[ok]), g[ok], sum)
    fem_n <- tapply(as.integer(!s[ok]), g[ok], sum)
  } else {
    ok <- !is.na(g)
    male_w <- male_n <- tapply(data[[sexratio$males]][ok], g[ok], sum)
    fem_w <- fem_n <- tapply(data[[sexratio$females]][ok], g[ok], sum)
  }
  usable <- male_n >= min_n & fem_n >= min_n & fem_w > 0
  if (!any(usable)) {
    return(not_evaluated(sprintf(
      "aucun groupe de %d observations au moins par sexe", min_n)))
  }
  ratio <- 100 * male_w[usable] / fem_w[usable]
  outside <- ratio < range[1L] | ratio > range[2L]
  if (!any(outside)) return(list())
  shown <- utils::head(names(ratio)[outside], 8L)
  txt <- paste0(shown, " : ", vapply(ratio[shown], fr_num, character(1), 4),
                collapse = " ; ")
  if (sum(outside) > 8L) txt <- paste0(txt, " ; ...")
  list(new_finding(
    "DEM-04", "a_justifier",
    sprintf(paste0("%d groupe(s) d'\u00e2ges dont le rapport de masculinit\u00e9 sort de ",
                   "[%s ; %s] pour 100 femmes : %s. Migrations, couverture ou ",
                   "d\u00e9claration : \u00e0 justifier."),
            sum(outside), fr_num(range[1L]), fr_num(range[2L]), txt),
    location = sexratio$group,
    details = list(groups = names(ratio)[outside], ratios = ratio[outside],
                   n_skipped = sum(!usable))))
}
