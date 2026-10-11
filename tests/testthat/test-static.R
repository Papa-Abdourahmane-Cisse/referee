test_that("parse_script exige exactement text ou path", {
  expect_error(parse_script(), "exactement")
  expect_error(parse_script(text = "1", path = "a.R"), "exactement")
  expect_error(parse_script(path = "inexistant.R"), "introuvable")
})

test_that("collect_calls retrouve les appels imbriqués et leur ligne", {
  s <- parse_script(text = "a <- 1\nb <- sqrt(mean(c(1, 2)))\n")
  calls <- collect_calls(s)
  noms <- vapply(calls, function(r) r$name, character(1))
  expect_true(all(c("sqrt", "mean", "c") %in% noms))
  mean_call <- Filter(function(r) identical(r$name, "mean"), calls)[[1]]
  expect_equal(mean_call$line, 2L)
})

test_that("l'analyse supporte arguments vides, fonctions anonymes et pkg::f", {
  s <- parse_script(text = paste(
    "x <- df[, 1]",
    "f <- function(a, b = 2) a + b",
    "m <- stats::median(x)",
    sep = "\n"))
  noms <- vapply(collect_calls(s), function(r) r$name, character(1))
  expect_true("median" %in% noms)
})

test_that("expr_tokens reconnait df$w comme df[['w']]", {
  expect_true("hhweight" %in% expr_tokens(quote(mean(df$hhweight))))
  expect_true("hhweight" %in% expr_tokens(quote(mean(df[["hhweight"]]))))
})

test_that("parse_script lit un fichier", {
  f <- tempfile(fileext = ".R")
  writeLines("m <- mean(x)", f)
  s <- parse_script(path = f)
  expect_s3_class(s, "referee_script")
  expect_length(collect_calls(s), 2L) # `<-` et `mean`
})
