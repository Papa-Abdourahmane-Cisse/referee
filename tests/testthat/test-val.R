sc <- function(...) parse_script(text = paste(c(...), collapse = "\n"))

# VAL-01 -----------------------------------------------------------------------

test_that("VAL-01 signale vfold_cv() sur des données groupées", {
  s <- sc("folds <- rsample::vfold_cv(df, v = 5)")
  res <- val01_random_cv_grouped(s, "region")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("VAL-01 signale aussi caret::trainControl(method = 'cv') et initial_split()", {
  s <- sc("ctrl <- caret::trainControl(method = 'cv', number = 5)",
          "sp <- initial_split(df)")
  expect_length(val01_random_cv_grouped(s, "region"), 2L)
})

test_that("VAL-01 ne signale pas un découpage groupé (jumelle négative)", {
  s <- sc("folds <- group_vfold_cv(df, group = region)")
  expect_length(val01_random_cv_grouped(s, "region"), 0L)
  s2 <- sc("ctrl <- trainControl(method = 'cv', index = groupKFold(df$region))")
  expect_length(val01_random_cv_grouped(s2, "region"), 0L)
})

test_that("VAL-01 ne signale pas un découpage groupé placé à côté d'un aléatoire", {
  # Limite documentée : un seul découpage groupé suffit à faire taire la règle.
  s <- sc("a <- vfold_cv(df)", "b <- group_vfold_cv(df, group = region)")
  expect_length(val01_random_cv_grouped(s, "region"), 0L)
})

test_that("VAL-01 ignore trainControl hors rééchantillonnage aléatoire", {
  s <- sc("ctrl <- trainControl(method = 'none')")
  expect_length(val01_random_cv_grouped(s, "region"), 0L)
})

# VAL-06 -----------------------------------------------------------------------

test_that("VAL-06 signale vfold_cv() sur une série temporelle", {
  s <- sc("folds <- vfold_cv(serie, v = 10)")
  res <- val06_random_cv_time(s, "mois")
  expect_length(res, 1L)
  expect_equal(res[[1]]$rule_id, "VAL-06")
})

test_that("VAL-06 ne signale pas un découpage temporel (jumelle négative)", {
  expect_length(val06_random_cv_time(sc("f <- rolling_origin(serie, initial = 36)"),
                                     "mois"), 0L)
  expect_length(val06_random_cv_time(
    sc("ctrl <- trainControl(method = 'timeslice', initialWindow = 36, horizon = 6)"),
    "mois"), 0L)
})

# VAL-02 -----------------------------------------------------------------------

test_that("VAL-02 signale scale() appliqué avant initial_split()", {
  s <- sc("df$x <- scale(df$x)", "sp <- initial_split(df)")
  res <- val02_transform_before_split(s)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("VAL-02 ne signale pas une transformation après le découpage (jumelle négative)", {
  s <- sc("sp <- initial_split(df)", "train <- training(sp)",
          "train$x <- scale(train$x)")
  expect_length(val02_transform_before_split(s), 0L)
})

test_that("VAL-02 est non évaluée sans découpage reconnu", {
  res <- val02_transform_before_split(sc("df$x <- scale(df$x)"))
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "aucun découpage")
})

test_that("VAL-02 se limite aux objets de données déclarés", {
  s <- sc("a <- scale(autre$x)", "b <- scale(df$x)", "sp <- initial_split(df)")
  expect_length(val02_transform_before_split(s), 2L)
  expect_length(val02_transform_before_split(s, data_objects = "df"), 1L)
})

test_that("VAL-02 ignore une fonction définie avant le découpage", {
  s <- sc("norm <- function(x) scale(x)", "sp <- initial_split(df)")
  expect_length(val02_transform_before_split(s), 0L)
})

# VAL-03 -----------------------------------------------------------------------

test_that("VAL-03 signale une performance calculée sur l'apprentissage seul", {
  s <- sc("p <- predict(fit, newdata = train)",
          "r <- yardstick::rmse(train, truth = y, estimate = .pred)")
  res <- val03_training_performance(s, train_objects = "train")
  expect_length(res, 2L)
  expect_equal(res[[1]]$severity, "risque_probable")
})

test_that("VAL-03 ne signale pas si une évaluation sur le test existe (jumelle négative)", {
  s <- sc("p1 <- predict(fit, newdata = train)",
          "p2 <- predict(fit, newdata = test)")
  expect_length(val03_training_performance(s, "train", test_objects = "test"), 0L)
})

test_that("VAL-03 signale quand le test est déclaré mais jamais évalué", {
  s <- sc("p1 <- predict(fit, newdata = train)")
  expect_length(val03_training_performance(s, "train", test_objects = "test"), 1L)
})

test_that("VAL-03 ne signale pas une évaluation sur le test seul", {
  s <- sc("p <- predict(fit, newdata = test)")
  expect_length(val03_training_performance(s, "train"), 0L)
})

# VAL-04 -----------------------------------------------------------------------

test_that("VAL-04 signale un réglage qui utilise le jeu de test", {
  s <- sc("res <- tune_grid(wf, resamples = vfold_cv(test), grid = 10)")
  res <- val04_test_set_tuning(s, "test")
  expect_length(res, 2L) # tune_grid et vfold_cv citent tous deux `test`
  expect_true(all(severities(res) == "risque_probable"))
})

test_that("VAL-04 ne signale pas un réglage sur l'apprentissage (jumelle négative)", {
  s <- sc("res <- tune_grid(wf, resamples = vfold_cv(train), grid = 10)",
          "p <- predict(fit, newdata = test)")
  expect_length(val04_test_set_tuning(s, "test"), 0L)
})

test_that("VAL-04 signale caret::train() entraîné sur le test", {
  s <- sc("m <- caret::train(y ~ ., data = test, method = 'rf')")
  expect_length(val04_test_set_tuning(s, "test"), 1L)
})

# VAL-05 -----------------------------------------------------------------------

test_that("VAL-05 signale un prédicteur égal à la cible à un bruit près", {
  set.seed(11)
  y <- rnorm(100, 10, 2)
  d <- data.frame(y = y, proxy = y + rnorm(100, 0, 0.01), x = rnorm(100))
  res <- val05_target_proxy(d, "y")
  expect_length(res, 1L)
  expect_equal(res[[1]]$location, "proxy")
  expect_equal(res[[1]]$severity, "risque_probable")
})

test_that("VAL-05 détecte une transformation monotone de la cible (Spearman)", {
  set.seed(12)
  y <- runif(100, 1, 100)
  d <- data.frame(y = y, ly = exp(y / 10))
  expect_length(val05_target_proxy(d, "y"), 1L)
})

test_that("VAL-05 ne signale pas des prédicteurs ordinaires (jumelle négative)", {
  set.seed(13)
  x <- rnorm(200)
  d <- data.frame(y = 2 * x + rnorm(200, 0, 2), x = x, z = rnorm(200))
  expect_length(val05_target_proxy(d, "y"), 0L)
})

test_that("VAL-05 ignore colonnes constantes, non numériques ou trop courtes", {
  d <- data.frame(y = 1:20, cst = 1, txt = as.character(1:20),
                  stringsAsFactors = FALSE)
  expect_length(val05_target_proxy(d, "y"), 0L)
  court <- data.frame(y = 1:5, x = 1:5)
  expect_length(val05_target_proxy(court, "y"), 0L)
})

test_that("VAL-05 refuse une cible non numérique", {
  expect_error(val05_target_proxy(data.frame(y = c("a", "b"), x = 1:2), "y"),
               "num")
})

test_that("VAL-02 ne tranche pas quand transformation et découpage sont dans la même instruction", {
  # Deux appels d'une même instruction ne sont pas ordonnés par la règle.
  s <- sc("sp <- initial_split(transform(df, z = scale(x)))")
  expect_length(val02_transform_before_split(s), 0L)
})

test_that("VAL-02 compare au premier découpage, pas au dernier", {
  s <- sc("a <- scale(df$x)", "s1 <- initial_split(df)",
          "b <- scale(train$x)", "s2 <- vfold_cv(train)")
  res <- val02_transform_before_split(s)
  expect_length(res, 1L)
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("VAL-01 ne signale pas un trainControl avec plis personnalisés", {
  s <- sc("ctrl <- trainControl(method = 'cv', index = mes_plis)")
  expect_length(val01_random_cv_grouped(s, "region"), 0L)
})

test_that("VAL-06 se tait si un découpage temporel coexiste avec un aléatoire", {
  # Limite documentée, comme pour VAL-01.
  s <- sc("a <- vfold_cv(serie)", "b <- rolling_origin(serie, initial = 36)")
  expect_length(val06_random_cv_time(s, "mois"), 0L)
  s2 <- sc("a <- vfold_cv(serie)",
           "ctrl <- trainControl(method = 'timeslice', initialWindow = 36, horizon = 6)")
  expect_length(val06_random_cv_time(s2, "mois"), 0L)
})

test_that("VAL-03 ne produit qu'un constat par ligne", {
  s <- sc("r <- rmse(train, truth = y, estimate = predict(fit, newdata = train))")
  expect_length(val03_training_performance(s, "train"), 1L)
})
