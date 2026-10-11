# LVL-01 -----------------------------------------------------------------------

test_that("LVL-01 signale une valeur régionale dupliquée sur les communes", {
  d <- make_survey()
  res <- lvl01_artificial_disaggregation(d, group = "region",
                                         vars = "taux_region")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_equal(res[[1]]$location, "taux_region")
})

test_that("LVL-01 ne signale pas une variable qui varie dans les groupes", {
  d <- make_survey()
  res <- lvl01_artificial_disaggregation(d, group = "region",
                                         vars = "taux_commune")
  expect_length(res, 0L)
  expect_null(attr(res, "not_evaluated"))
})

test_that("LVL-01 ne signale pas une variable constante dans une partie seulement des groupes", {
  d <- make_survey()
  d$x <- d$taux_commune
  d$x[d$region == "R1"] <- 0.5 # constante dans R1 uniquement
  expect_length(lvl01_artificial_disaggregation(d, "region", "x"), 0L)
})

test_that("LVL-01 ne signale pas une constante globale", {
  d <- make_survey()
  d$cst <- 1
  expect_length(lvl01_artificial_disaggregation(d, "region", "cst"), 0L)
})

test_that("LVL-01 est non évaluée si aucun groupe n'a assez d'observations", {
  d <- data.frame(region = c("A", "B", "C"), x = c(1, 2, 3))
  res <- lvl01_artificial_disaggregation(d, "region", "x")
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "aucune variable")
})

# LVL-02 -----------------------------------------------------------------------

test_that("LVL-02 signale la moyenne simple d'une variable agrégée", {
  s <- parse_script(text = "national <- mean(communes$taux_commune)")
  res <- lvl02_unweighted_mean_of_aggregates(s, "taux_commune")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
})

test_that("LVL-02 ne signale pas la moyenne pondérée ni une autre variable", {
  corrects <- c(
    "national <- weighted.mean(communes$taux_commune, communes$pop)",
    "m <- mean(menages$pcexp)"
  )
  for (code in corrects) {
    res <- lvl02_unweighted_mean_of_aggregates(parse_script(text = code),
                                               "taux_commune")
    expect_length(res, 0L)
  }
})

# LVL-03 -----------------------------------------------------------------------

test_that("LVL-03 signale une clé dupliquée", {
  d <- make_survey()
  d <- rbind(d, d[3, ])
  res <- lvl03_duplicate_keys(d, "commune")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_equal(res[[1]]$details$rows, 2L)
  expect_equal(res[[1]]$details$keys, 1L)
})

test_that("LVL-03 ne signale pas des clés uniques (jumelle négative)", {
  expect_length(lvl03_duplicate_keys(make_survey(), "commune"), 0L)
})

test_that("LVL-03 gère une clé composite", {
  d <- data.frame(a = c(1, 1, 2), b = c("x", "y", "x"))
  expect_length(lvl03_duplicate_keys(d, c("a", "b")), 0L)
  d2 <- rbind(d, d[1, ])
  expect_length(lvl03_duplicate_keys(d2, c("a", "b")), 1L)
})
