# NUM-01 -----------------------------------------------------------------------

test_that("NUM-01 signale une proportion supérieure à 1", {
  d <- data.frame(taux = c(0.2, 0.5, 1.37))
  res <- num01_bounds(d, c(taux = "proportion"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_equal(res[[1]]$details$n, 1L)
  # Convention francophone : virgule décimale dans les messages.
  expect_match(res[[1]]$message, "maximum observé : 1,37", fixed = TRUE)
})

test_that("NUM-01 ne signale pas des valeurs dans les bornes (jumelle négative)", {
  d <- data.frame(taux = c(0, 0.2, 1), pct = c(0, 55, 100))
  expect_length(num01_bounds(d, c(taux = "proportion", pct = "percent")), 0L)
})

test_that("NUM-01 signale un pourcentage supérieur à 100 ou négatif", {
  d <- data.frame(pct = c(10, 104, -3))
  res <- num01_bounds(d, c(pct = "percent"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$n, 2L)
})

test_that("NUM-01 détecte un mélange d'échelles seulement si l'échelle est 'auto'", {
  set.seed(7)
  mixte <- data.frame(x = c(runif(20, 0, 1), runif(20, 5, 60)))
  res <- num01_bounds(mixte, c(x = "auto"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")

  seulement_pct <- data.frame(x = runif(40, 5, 60))
  expect_length(num01_bounds(seulement_pct, c(x = "auto")), 0L)
  seulement_prop <- data.frame(x = runif(40, 0, 1))
  expect_length(num01_bounds(seulement_prop, c(x = "auto")), 0L)
})

# NUM-02 -----------------------------------------------------------------------

test_that("NUM-02 signale des parts qui ne somment pas à la cible", {
  d <- data.frame(a = c(40, 50), b = c(30, 30), c = c(30, 24))
  res <- num02_sums(d, list(list(parts = c("a", "b", "c"), target = 100)))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_equal(res[[1]]$details$n, 1L)
  expect_equal(res[[1]]$details$max_diff, 4)
})

test_that("NUM-02 tolère l'arrondi et ignore les lignes incomplètes", {
  d <- data.frame(a = c(33.4, NA), b = c(33.3, 10), c = c(33.2, 10))
  res <- num02_sums(d, list(list(parts = c("a", "b", "c"), target = 100)))
  expect_length(res, 0L) # écart de 0,1 <= 0,5 ; ligne 2 incomplète
})

test_that("NUM-02 compare à un total déclaré", {
  d <- data.frame(a = c(10, 20), b = c(5, 5), total = c(15, 30))
  res <- num02_sums(d, list(list(parts = c("a", "b"), total = "total")))
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$n, 1L)
})

# NUM-03 -----------------------------------------------------------------------

test_that("NUM-03 signale FGT1 > FGT0 et FGT2 > FGT1", {
  d <- data.frame(f0 = c(0.40, 0.30, 0.20),
                  f1 = c(0.10, 0.35, 0.10),
                  f2 = c(0.02, 0.01, 0.15))
  res <- num03_fgt_order(d, c("f0", "f1", "f2"))
  expect_length(res, 2L)
  expect_true(all(severities(res) == "certitude"))
})

test_that("NUM-03 ne signale pas une chaîne FGT cohérente (jumelle négative)", {
  d <- data.frame(f0 = c(0.40, 0.30), f1 = c(0.10, 0.08), f2 = c(0.04, 0.03))
  expect_length(num03_fgt_order(d, c("f0", "f1", "f2")), 0L)
})

# NUM-04 -----------------------------------------------------------------------

test_that("NUM-04 signale des 999 dans une colonne d'âges", {
  set.seed(3)
  d <- data.frame(age = c(sample(18:80, 40, replace = TRUE), 999, 999))
  res <- num04_missing_codes(d)
  expect_length(res, 1L)
  expect_equal(res[[1]]$location, "age")
  expect_match(res[[1]]$message, "999 \\(2 fois\\)")
})

test_that("NUM-04 ne signale pas un 99 qui prolonge la distribution (jumelle négative)", {
  d <- data.frame(age = c(20:97, 99))
  expect_length(num04_missing_codes(d), 0L)
})

test_that("NUM-04 signale un code négatif quand toutes les autres valeurs sont positives", {
  d <- data.frame(x = c(1:20, -99))
  expect_length(num04_missing_codes(d), 1L)
  # Température : des valeurs négatives légitimes coexistent avec -99.
  t <- data.frame(x = c(-5:15, -99))
  expect_length(num04_missing_codes(t), 0L)
})

test_that("NUM-04 ignore les colonnes non numériques", {
  d <- data.frame(id = rep("999", 10), stringsAsFactors = FALSE)
  expect_length(num04_missing_codes(d), 0L)
})
