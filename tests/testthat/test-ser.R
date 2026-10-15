sc <- function(...) parse_script(text = paste(c(...), collapse = "\n"))

# SER-01 -----------------------------------------------------------------------

test_that("SER-01 signale adf.test() sur les résidus d'un lm() de niveaux", {
  skip_si_pas_utf8()
  s <- sc("reg = lm(Xt ~ Yt)", "res = reg$residuals", "adf.test(res)")
  res <- ser01_residual_unit_root(s)
  expect_length(res, 1L)
  expect_equal(res[[1]]$rule_id, "SER-01")
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$message, "adf.test", fixed = TRUE)
  expect_match(res[[1]]$message, "Xt ~ Yt", fixed = TRUE)
  expect_match(res[[1]]$location, "ligne 3")
})

test_that("SER-01 reconnaît les formes usuelles d'accès aux résidus", {
  skip_si_pas_utf8()
  formes <- c("adf.test(residuals(reg))", "adf.test(resid(reg))",
              "adf.test(reg$resid)", "adf.test(reg[['residuals']])",
              "adf.test(as.numeric(reg$residuals))",
              "adf.test(lm(a ~ b)$residuals)",
              "reg$residuals |> adf.test()")
  for (f in formes) {
    s <- sc("reg <- lm(a ~ b)", f)
    expect_length(ser01_residual_unit_root(s), 1L)
  }
})

test_that("SER-01 suit un modèle passé par summary() et par un pipe", {
  skip_si_pas_utf8()
  s <- sc("m <- summary(lm(r10 ~ Tbill, data = q))", "e <- m$residuals",
          "ur.df(e, type = 'drift', lag = 1)")
  res <- ser01_residual_unit_root(s)
  expect_length(res, 1L)
  expect_match(res[[1]]$message, "termes déterministes")
  s2 <- sc("m <- q %>% lm(y ~ x)", "adf.test(m$residuals)")
  expect_length(ser01_residual_unit_root(s2), 1L)
})

test_that("SER-01 regroupe par fonction et compte les appels", {
  skip_si_pas_utf8()
  s <- sc("m1 <- lm(a ~ b)", "m2 <- lm(b ~ a)",
          "adf.test(m1$residuals)", "adf.test(m2$residuals)",
          "kpss.test(m1$residuals)")
  res <- ser01_residual_unit_root(s)
  expect_length(res, 2L)
  n <- setNames(vapply(res, function(r) r$details$n_calls, integer(1)),
                vapply(res, function(r) sub("^`([^`]+)\\(\\).*", "\\1", r$message),
                       character(1)))
  expect_equal(n[["adf.test"]], 2L)
})

test_that("SER-01 ne signale pas un test sur une série observée (jumelle négative)", {
  skip_si_pas_utf8()
  s <- sc("reg <- lm(a ~ b)", "adf.test(x)", "kpss.test(diff(y))",
          "adf.test(reg$fitted.values)")
  res <- ser01_residual_unit_root(s)
  expect_length(res, 0L)
  expect_null(attr(res, "not_evaluated"))
})

test_that("SER-01 ignore les résidus d'un modèle qui n'est pas une régression de niveaux", {
  skip_si_pas_utf8()
  s <- sc("fit <- arima(y, order = c(1, 0, 0))", "adf.test(fit$residuals)",
          "d1 <- lm(y ~ t)", "adf.test(d1$residuals)",
          "d2 <- lm(y ~ 1)", "adf.test(d2$residuals)")
  expect_length(ser01_residual_unit_root(s), 0L)
})

test_that("SER-01 tient compte de la réaffectation de la variable", {
  skip_si_pas_utf8()
  s <- sc("reg <- lm(a ~ b)", "res <- reg$residuals", "res <- diff(a)",
          "adf.test(res)")
  expect_length(ser01_residual_unit_root(s), 0L)
})

test_that("SER-01 est non évaluée sans test de racine unitaire", {
  skip_si_pas_utf8()
  s <- sc("reg <- lm(a ~ b)", "summary(reg)")
  res <- ser01_residual_unit_root(s)
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "aucun test de racine unitaire")
})

# REP-04 -----------------------------------------------------------------------

test_that("REP-04 signale ca.jo() sans library(urca)", {
  skip_si_pas_utf8()
  s <- sc("library(readxl)", "x <- ca.jo(d)")
  res <- rep04_unattached_package(s)
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$package, "urca")
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$message, "La fonction `ca.jo()`", fixed = TRUE)
})

test_that("REP-04 ne signale pas quand le paquet est chargé avant l'appel", {
  skip_si_pas_utf8()
  expect_length(rep04_unattached_package(sc("library(urca)", "ca.jo(d)")), 0L)
  expect_length(rep04_unattached_package(sc("library('urca')", "ca.jo(d)")), 0L)
  expect_length(rep04_unattached_package(sc("require(urca)", "ca.jo(d)")), 0L)
  expect_length(rep04_unattached_package(
    sc("pacman::p_load(readxl, urca)", "ca.jo(d)")), 0L)
  expect_length(rep04_unattached_package(sc("urca::ca.jo(d)")), 0L)
})

test_that("REP-04 signale un chargement placé après l'appel", {
  skip_si_pas_utf8()
  res <- rep04_unattached_package(sc("ca.jo(d)", "library(urca)"))
  expect_length(res, 1L)
})

test_that("REP-04 tient compte des paquets attachés en cascade", {
  skip_si_pas_utf8()
  expect_length(rep04_unattached_package(sc("library(vars)", "ca.jo(d)")), 0L)
  expect_length(rep04_unattached_package(sc("library(vars)", "as.yearqtr(x)")), 0L)
  expect_length(rep04_unattached_package(
    sc("library(tidyverse)", "ggplot(d)")), 0L)
  # tidyverse n'attache ni zoo ni readxl : un constat par paquet manquant
  res <- rep04_unattached_package(
    sc("library(tidyverse)", "as.yearqtr(x)", "read_excel('a.xlsx')"))
  expect_setequal(vapply(res, function(r) r$details$package, character(1)),
                  c("zoo", "readxl"))
})

test_that("REP-04 ne signale pas une fonction définie dans le script", {
  skip_si_pas_utf8()
  s <- sc("ca.jo <- function(x) x", "ca.jo(d)")
  expect_length(rep04_unattached_package(s), 0L)
})

test_that("REP-04 regroupe les fonctions d'un même paquet", {
  skip_si_pas_utf8()
  res <- rep04_unattached_package(sc("ur.df(x)", "ca.jo(d)", "ur.kpss(x)"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$n_calls, 3L)
  expect_match(res[[1]]$message, "Les fonctions", fixed = TRUE)
})

test_that("REP-04 est non évaluée si les paquets sont chargés dynamiquement", {
  skip_si_pas_utf8()
  s <- sc("pk <- c('urca')", "for (p in pk) library(p, character.only = TRUE)",
          "ca.jo(d)")
  res <- rep04_unattached_package(s)
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "dynamique")
  s2 <- sc("lapply(c('urca'), library, character.only = TRUE)", "ca.jo(d)")
  expect_match(attr(rep04_unattached_package(s2), "not_evaluated"), "dynamique")
})

test_that("REP-04 le mentionne quand le script appelle source()", {
  skip_si_pas_utf8()
  res <- rep04_unattached_package(sc("source('outils.R')", "ca.jo(d)"))
  expect_match(res[[1]]$message, "source()", fixed = TRUE)
})

# Exemple et intégration ---------------------------------------------------------

test_that("l'exemple cointegration_fautive.R déclenche SER-01 et REP-04", {
  skip_si_pas_utf8()
  chemin <- system.file("examples", "cointegration_fautive.R", package = "referee")
  skip_if(!nzchar(chemin))
  rapport <- audit_script(chemin)
  tab <- as.data.frame(rapport)
  expect_equal(sort(tab$rule_id[tab$rule_id %in% c("SER-01", "REP-04")]),
               c("REP-04", "SER-01", "SER-01"))
  st <- setNames(rapport$rules$status, rapport$rules$rule_id)
  expect_equal(st[["SER-01"]], "evaluee")
})

test_that("SER-01 précise le cas du KPSS (valeurs critiques propres)", {
  skip_si_pas_utf8()
  s <- sc("reg <- lm(a ~ b)", "kpss.test(reg$residuals)")
  res <- ser01_residual_unit_root(s)
  expect_match(res[[1]]$message, "test de Shin", fixed = TRUE)
  s2 <- sc("reg <- lm(a ~ b)", "adf.test(reg$residuals)")
  expect_false(grepl("Shin", ser01_residual_unit_root(s2)[[1]]$message))
})
