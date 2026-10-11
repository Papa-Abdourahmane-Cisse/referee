# SUR-01 -----------------------------------------------------------------------

test_that("SUR-01 signale un estimateur sans poids", {
  s <- parse_script(text = "df <- read.csv('a.csv')\nm <- mean(df$pcexp, na.rm = TRUE)\n")
  res <- sur01_unweighted_estimators(s, weights = "hhweight")
  expect_length(res, 1L)
  expect_equal(res[[1]]$rule_id, "SUR-01")
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$location, "ligne 2")
})

test_that("SUR-01 ne signale pas les variantes pondérées (jumelle négative)", {
  corrects <- c(
    "m <- weighted.mean(df$pcexp, df$hhweight)",
    "m <- survey::svymean(~pcexp, design)",
    "fit <- lm(y ~ x, data = df, weights = hhweight)",
    "fit <- lm(y ~ x, data = df, weights = w_calibre)"
  )
  for (code in corrects) {
    res <- sur01_unweighted_estimators(parse_script(text = code), "hhweight")
    expect_length(res, 0L)
    expect_null(attr(res, "not_evaluated"))
  }
})

test_that("SUR-01 ne signale pas un estimateur qui utilise la variable de poids", {
  # Médiane pondérée par réplication : le poids est utilisé sans argument `weights`.
  s <- parse_script(text = "m <- median(rep(df$pcexp, times = df$hhweight))")
  expect_length(sur01_unweighted_estimators(s, "hhweight"), 0L)
})

test_that("SUR-01 se limite aux objets de données déclarés", {
  s <- parse_script(text = "a <- mean(autre$x)\nb <- mean(df$x)\n")
  tous <- sur01_unweighted_estimators(s, "hhweight")
  restreint <- sur01_unweighted_estimators(s, "hhweight", data_objects = "df")
  expect_length(tous, 2L)
  expect_length(restreint, 1L)
  expect_match(restreint[[1]]$location, "ligne 2")
})

# SUR-02 -----------------------------------------------------------------------

test_that("SUR-02 signale poids / taille", {
  s <- parse_script(text = "df$w_ind <- df$hhweight / df$hhsize")
  res <- sur02_weight_divided_by_size(s, "hhweight", "hhsize")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
})

test_that("SUR-02 ne signale ni le produit ni d'autres divisions (jumelle négative)", {
  corrects <- c(
    "df$w_ind <- df$hhweight * df$hhsize",
    "r <- a / b",
    "p <- df$hhweight / sum(df$hhweight)"
  )
  for (code in corrects) {
    res <- sur02_weight_divided_by_size(parse_script(text = code),
                                        "hhweight", "hhsize")
    expect_length(res, 0L)
  }
})

# SUR-03 -----------------------------------------------------------------------

test_that("SUR-03 signale une régression sans plan de sondage", {
  s <- parse_script(text = "fit <- lm(y ~ x, data = d)\ntt <- t.test(y ~ g, data = d)")
  res <- sur03_design_ignored(s, psu = "grappe")
  expect_length(res, 2L)
  expect_true(all(severities(res) == "risque_probable"))
})

test_that("SUR-03 ne signale rien quand un plan est déclaré (jumelle négative)", {
  s <- parse_script(text = paste(
    "des <- survey::svydesign(ids = ~grappe, strata = ~strate, data = d)",
    "fit <- lm(y ~ x, data = d)", sep = "\n"))
  res <- sur03_design_ignored(s, strata = "strate", psu = "grappe")
  expect_length(res, 0L)
  expect_null(attr(res, "not_evaluated"))
})

test_that("SUR-03 est non évaluée sans strate ni grappe déclarée", {
  res <- sur03_design_ignored(parse_script(text = "lm(y ~ x, d)"))
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "ni strate ni grappe")
})

# SUR-04 -----------------------------------------------------------------------

test_that("SUR-04 classe chaque problème de poids selon sa confiance", {
  d <- data.frame(w = c(rep(1, 50), NA, -2, 0, 5000))
  res <- sur04_weights_valid(d, "w")
  expect_length(res, 4L)
  expect_equal(sum(severities(res) == "certitude"), 2L) # manquant, négatif
  expect_equal(sum(severities(res) == "a_justifier"), 2L) # nul, dispersion
})

test_that("SUR-04 ne signale rien sur des poids sains (jumelle négative)", {
  set.seed(1)
  d <- data.frame(w = runif(200, 0.5, 3))
  expect_length(sur04_weights_valid(d, "w"), 0L)
})

test_that("SUR-04 respecte le seuil de dispersion paramétré", {
  d <- data.frame(w = c(rep(1, 20), 30))
  expect_length(sur04_weights_valid(d, "w"), 0L) # 30 < 100
  expect_length(sur04_weights_valid(d, "w", ratio_max_median = 10), 1L)
})

test_that("SUR-04 refuse un poids non numérique", {
  skip_si_pas_utf8()
  expect_error(sur04_weights_valid(data.frame(w = c("a", "b")), "w"),
               "numérique")
})
