sc <- function(...) parse_script(text = paste(c(...), collapse = "\n"))

make_panel <- function(adoption, n_unit = 12L, n_t = 8L) {
  # `adoption` : vecteur (longueur n_unit) de la période d'adoption, NA = jamais.
  d <- expand.grid(unit = seq_len(n_unit), annee = 2010 + seq_len(n_t) - 1L)
  d$adopt <- adoption[d$unit]
  d$traite <- as.integer(!is.na(d$adopt) & d$annee >= 2010 + d$adopt - 1L)
  d
}

# ECO-01 -----------------------------------------------------------------------

test_that("ECO-01 signale lm() sans erreurs standards en grappes", {
  s <- sc("fit <- lm(y ~ x, data = d)", "summary(fit)")
  res <- eco01_cluster_se(s, "village")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("ECO-01 ne signale pas des erreurs standards en grappes (jumelle négative)", {
  corrects <- c(
    "fit <- lm(y ~ x, data = d)\nlmtest::coeftest(fit, vcov = sandwich::vcovCL(fit, cluster = d$village))",
    "fit <- estimatr::lm_robust(y ~ x, data = d, clusters = village)",
    "fit <- lm(y ~ x, data = d)\nlmtest::coeftest(fit, vcov = vcovCR(fit, cluster = d$village, type = 'CR2'))"
  )
  for (code in corrects) {
    expect_length(eco01_cluster_se(sc(code), "village"), 0L)
  }
})

test_that("ECO-01 : une correction d'hétéroscédasticité ne tient pas compte des grappes", {
  s <- sc("fit <- lm(y ~ x, data = d)",
          "lmtest::coeftest(fit, vcov = sandwich::vcovHC(fit, type = 'HC1'))")
  # L'argument `vcov` est présent : limite documentée (il ne distingue pas
  # l'estimateur). Le test enregistre ce comportement.
  expect_length(eco01_cluster_se(s, "village"), 0L)
  s2 <- sc("fit <- lm(y ~ x, data = d)", "se <- sqrt(diag(sandwich::vcovHC(fit)))")
  expect_length(eco01_cluster_se(s2, "village"), 1L)
})

test_that("ECO-01 ne signale pas feols() (non évalué par construction)", {
  expect_length(eco01_cluster_se(sc("m <- fixest::feols(y ~ x | unit, d)"),
                                 "village"), 0L)
})

# ECO-02 -----------------------------------------------------------------------

test_that("ECO-02 signale une double différence bidirectionnelle à adoption échelonnée", {
  d <- make_panel(c(rep(3, 4), rep(5, 4), rep(NA, 4)))
  s <- sc("m <- fixest::feols(y ~ traite | unit + annee, data = d)")
  res <- eco02_staggered_twfe(d, s, "unit", "annee", "traite")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_equal(res[[1]]$details$n_cohorts, 2L)
  expect_match(res[[1]]$message, "2012, 2014", fixed = TRUE)
})

test_that("ECO-02 ne signale pas une adoption simultanée (jumelle négative)", {
  d <- make_panel(c(rep(4, 6), rep(NA, 6)))
  s <- sc("m <- fixest::feols(y ~ traite | unit + annee, data = d)")
  expect_length(eco02_staggered_twfe(d, s, "unit", "annee", "traite"), 0L)
})

test_that("ECO-02 ne signale pas en présence d'un estimateur robuste", {
  d <- make_panel(c(rep(3, 4), rep(5, 4), rep(NA, 4)))
  s <- sc("m <- fixest::feols(y ~ traite | unit + annee, data = d)",
          "cs <- did::att_gt(yname = 'y', tname = 'annee', idname = 'unit', gname = 'g', data = d)")
  expect_length(eco02_staggered_twfe(d, s, "unit", "annee", "traite"), 0L)
})

test_that("ECO-02 ignore une régression qui ne cite pas unité et temps", {
  d <- make_panel(c(rep(3, 4), rep(5, 4), rep(NA, 4)))
  s <- sc("m <- lm(y ~ traite, data = d)")
  expect_length(eco02_staggered_twfe(d, s, "unit", "annee", "traite"), 0L)
})

test_that("ECO-02 : les unités traitées dès la première période ne comptent pas comme cohorte", {
  d <- make_panel(c(rep(1, 4), rep(5, 4), rep(NA, 4)))
  s <- sc("m <- fixest::feols(y ~ traite | unit + annee, data = d)")
  expect_length(eco02_staggered_twfe(d, s, "unit", "annee", "traite"), 0L)
})

test_that("ECO-02 refuse un traitement non codé 0/1", {
  d <- make_panel(c(rep(3, 4), rep(5, 4), rep(NA, 4)))
  d$traite <- d$traite * 2
  expect_error(eco02_staggered_twfe(d, sc("a <- 1"), "unit", "annee", "traite"),
               "0/1")
})

# ECO-03 -----------------------------------------------------------------------

test_that("ECO-03 signale une double différence sans examen des tendances", {
  s <- sc("m <- lm(y ~ traite * post, data = d)")
  res <- eco03_pretrends(s, "traite")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
})

test_that("ECO-03 ne signale pas quand une étude d'événement est présente (jumelle négative)", {
  corrects <- c(
    "m <- fixest::feols(y ~ i(rel_time, traite, ref = -1) | unit + annee, d)",
    "m <- fixest::feols(y ~ sunab(cohorte, annee) | unit + annee, d)\nlm(y ~ traite, d)",
    "d$lead1 <- 1\nm <- lm(y ~ traite + lead1, d)"
  )
  for (code in corrects) {
    expect_length(eco03_pretrends(sc(code), "traite"), 0L)
  }
})

test_that("ECO-03 ne signale rien si le traitement n'est jamais régressé", {
  expect_length(eco03_pretrends(sc("m <- lm(y ~ x, d)"), "traite"), 0L)
})

# ECO-04 -----------------------------------------------------------------------

test_that("ECO-04 signale un instrument faiblement corrélé au régresseur", {
  set.seed(21)
  z <- rnorm(300)
  d <- data.frame(z = z, x = 0.05 * z + rnorm(300), w = rnorm(300))
  res <- eco04_weak_instrument(d, "x", "z")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_lt(res[[1]]$details$F, 10)
})

test_that("ECO-04 ne signale pas un instrument fort (jumelle négative)", {
  set.seed(22)
  z <- rnorm(300)
  d <- data.frame(z = z, x = 0.8 * z + rnorm(300))
  expect_length(eco04_weak_instrument(d, "x", "z"), 0L)
})

test_that("ECO-04 : le F calculé correspond à t^2 pour un instrument unique", {
  set.seed(23)
  z <- rnorm(200)
  d <- data.frame(z = z, x = 0.1 * z + rnorm(200))
  t_val <- summary(lm(x ~ z, d))$coefficients["z", "t value"]
  res <- eco04_weak_instrument(d, "x", "z", threshold = Inf)
  expect_equal(res[[1]]$details$F, unname(t_val^2), tolerance = 1e-8)
})

test_that("ECO-04 retire l'effet des contrôles et ignore les lignes incomplètes", {
  set.seed(24)
  w <- rnorm(300)
  z <- rnorm(300)
  x <- 0.9 * w + 0.02 * z + rnorm(300, 0, 0.5)
  d <- data.frame(x = x, z = z, w = w)
  d$z[1:5] <- NA
  res <- eco04_weak_instrument(d, "x", "z", controls = "w")
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$n, 295L)
  expect_equal(res[[1]]$details$df2, 292L)
})

test_that("ECO-04 est non évaluée si la première étape n'est pas estimable", {
  d <- data.frame(x = rnorm(10), z = 1, z2 = 1)
  res <- eco04_weak_instrument(d, "x", c("z", "z2"))
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "colin")
})

# ECO-05 -----------------------------------------------------------------------

make_score <- function(manipule, n = 4000L, seed = 31L) {
  set.seed(seed)
  x <- rnorm(n)
  if (manipule) {
    # 60 % des unités juste sous le seuil sont déplacées juste au-dessus.
    idx <- which(x > -0.15 & x < 0)
    moved <- idx[seq_len(floor(0.6 * length(idx)))]
    x[moved] <- runif(length(moved), 0, 0.05)
  }
  data.frame(score = x)
}

test_that("ECO-05 signale une accumulation d'observations juste au-dessus du seuil", {
  res <- eco05_rdd_manipulation(make_score(TRUE), "score", 0)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_gt(res[[1]]$details$right, res[[1]]$details$left)
})

test_that("ECO-05 ne signale pas un score sans manipulation (jumelle négative)", {
  expect_length(eco05_rdd_manipulation(make_score(FALSE), "score", 0), 0L)
})

test_that("ECO-05 signale l'absence de test de densité dans le script", {
  d <- make_score(FALSE)
  res <- eco05_rdd_manipulation(d, "score", 0, script = sc("m <- rdrobust::rdrobust(y, x)"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  ok <- eco05_rdd_manipulation(d, "score", 0,
                               script = sc("t <- rddensity::rddensity(d$score, c = 0)"))
  expect_length(ok, 0L)
})

test_that("ECO-05 est non évaluée avec trop peu d'observations et sans script", {
  d <- data.frame(score = c(-1, -0.5, 0.2, 0.9))
  res <- eco05_rdd_manipulation(d, "score", 0)
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "trop peu")
})

test_that("ECO-05 respecte la largeur de fenêtre paramétrée", {
  d <- make_score(TRUE)
  expect_length(eco05_rdd_manipulation(d, "score", 0, bandwidth = 0.1), 1L)
  expect_length(eco05_rdd_manipulation(d, "score", 0, alpha = 1e-300), 0L)
})

test_that("ECO-05 refuse un score non numérique", {
  expect_error(eco05_rdd_manipulation(data.frame(s = c("a", "b")), "s", 0),
               "num")
})

test_that("ECO-05 compte les scores égaux au seuil du côté traité", {
  d <- data.frame(score = c(rep(-0.05, 10), rep(0, 30), rep(0.05, 10)))
  res <- eco05_rdd_manipulation(d, "score", 0, bandwidth = 0.1)
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$right, 40L)
})
