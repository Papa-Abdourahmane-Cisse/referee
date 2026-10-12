# Les tests EXT, REP et DOC comparent du texte accentué.
# EXT-01 -----------------------------------------------------------------------

ref_taux <- function(reference, tol = 0.01, ...) {
  list(c(list(name = "taux de pauvreté", reference = reference, tol = tol,
              var = "pauvre"), list(...)))
}

make_pauvrete <- function(n = 2000L, seed = 51L) {
  set.seed(seed)
  data.frame(pauvre = rbinom(n, 1, 0.375), poids = runif(n, 0.5, 3))
}

test_that("EXT-01 signale un écart au-delà de la tolérance et liste les causes", {
  skip_si_pas_utf8()
  d <- make_pauvrete()
  est <- weighted.mean(d$pauvre, d$poids)
  res <- ext01_reference_gap(d, ref_taux(est + 0.03), weights = "poids")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_match(res[[1]]$message, "pondérée par `poids`", fixed = TRUE)
  expect_match(res[[1]]$message, "couverture géographique", fixed = TRUE)
  expect_equal(res[[1]]$details$gap, 0.03, tolerance = 1e-8)
})

test_that("EXT-01 ne signale pas un écart dans la tolérance (jumelle négative)", {
  skip_si_pas_utf8()
  d <- make_pauvrete()
  est <- weighted.mean(d$pauvre, d$poids)
  expect_length(ext01_reference_gap(d, ref_taux(est + 0.005), weights = "poids"), 0L)
})

test_that("EXT-01 distingue moyenne pondérée et moyenne simple", {
  skip_si_pas_utf8()
  d <- make_pauvrete()
  d$poids <- ifelse(d$pauvre == 1, 3, 0.5)
  simple <- mean(d$pauvre)
  res_w <- ext01_reference_gap(d, ref_taux(simple), weights = "poids")
  expect_length(res_w, 1L) # la pondération déplace l'estimation
  res_s <- ext01_reference_gap(d, ref_taux(simple))
  expect_length(res_s, 0L)
  res_msg <- ext01_reference_gap(d, ref_taux(simple + 0.2))
  expect_match(res_msg[[1]]$message, "moyenne simple", fixed = TRUE)
  expect_match(res_msg[[1]]$message, "aucun poids déclaré", fixed = TRUE)
})

test_that("EXT-01 gère la tolérance relative", {
  skip_si_pas_utf8()
  d <- make_pauvrete()
  est <- mean(d$pauvre)
  r <- ref_taux(est * 1.05, tol = 0.1, tol_type = "relative")
  expect_length(ext01_reference_gap(d, r), 0L)
  r2 <- ref_taux(est * 1.25, tol = 0.1, tol_type = "relative")
  expect_length(ext01_reference_gap(d, r2), 1L)
})

test_that("EXT-01 signale un possible écart d'échelle (proportion et pourcentage)", {
  skip_si_pas_utf8()
  d <- make_pauvrete()
  est <- mean(d$pauvre)
  res <- ext01_reference_gap(d, ref_taux(est * 100, tol = 0.5))
  expect_length(res, 1L)
  expect_match(res[[1]]$message, "facteur 100", fixed = TRUE)
})

test_that("EXT-01 accepte une estimation fournie et se passe des données", {
  skip_si_pas_utf8()
  r <- list(list(name = "taux", reference = 0.40, tol = 0.01, estimate = 0.43))
  expect_length(ext01_reference_gap(NULL, r), 1L)
  r2 <- list(list(name = "taux", reference = 0.40, tol = 0.01, estimate = 0.405))
  expect_length(ext01_reference_gap(NULL, r2), 0L)
})

test_that("EXT-01 est non évaluée sans données quand il faut les calculer", {
  skip_si_pas_utf8()
  res <- ext01_reference_gap(NULL, ref_taux(0.4))
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "données non fournies")
})

test_that("EXT-01 refuse une référence mal formée", {
  skip_si_pas_utf8()
  expect_error(ext01_reference_gap(NULL, list(list(name = "x"))), "references")
  expect_error(referee_meta(references = list(list(name = "x", reference = 1,
                                                    tol = 0.1))), "references")
})

# EXT-02 -----------------------------------------------------------------------

test_that("EXT-02 signale une ligne d'une année appliquée à une consommation d'une autre", {
  skip_si_pas_utf8()
  res <- ext02_poverty_line_consistency(
    list(line_year = 2018, welfare_year = 2021))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$message, "2018")
})

test_that("EXT-02 ne signale pas années différentes avec ajustement des prix (jumelle négative)", {
  skip_si_pas_utf8()
  res <- ext02_poverty_line_consistency(
    list(line_year = 2018, welfare_year = 2021, price_adjusted = TRUE))
  expect_length(res, 0L)
  expect_null(attr(res, "not_evaluated"))
  expect_length(ext02_poverty_line_consistency(
    list(line_year = 2021, welfare_year = 2021)), 0L)
})

test_that("EXT-02 signale une unité ou une période différentes", {
  skip_si_pas_utf8()
  res <- ext02_poverty_line_consistency(list(
    line_unit = "par tête", welfare_unit = "par équivalent adulte",
    line_period = "jour", welfare_period = "an"))
  expect_length(res, 2L)
  ok <- ext02_poverty_line_consistency(list(
    line_unit = "Par tête", welfare_unit = "par tête ",
    line_period = "jour", welfare_period = "jour"))
  expect_length(ok, 0L)
})

test_that("EXT-02 est non évaluée sans paire comparable", {
  skip_si_pas_utf8()
  res <- ext02_poverty_line_consistency(list(line_year = 2018))
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "aucune paire")
})

test_that("referee_meta contrôle `poverty`", {
  skip_si_pas_utf8()
  expect_error(referee_meta(poverty = list(ligne = 1)), "poverty")
})
