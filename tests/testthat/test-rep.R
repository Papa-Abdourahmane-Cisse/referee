sc <- function(...) parse_script(text = paste(c(...), collapse = "\n"))

# REP-01 -----------------------------------------------------------------------

test_that("REP-01 signale un chemin absolu (risque probable)", {
  skip_si_pas_utf8()
  s <- sc("d <- readr::read_csv(\"D:/projet/base.csv\")",
          "e <- read.csv('/home/abdou/data.csv')",
          "setwd('C:\\\\Users\\\\abdou')",
          "f <- readRDS('~/base.rds')")
  res <- rep01_paths(s)
  expect_length(res, 4L)
  expect_true(all(severities(res) == "risque_probable"))
})

test_that("REP-01 ne signale pas un chemin relatif, une URL ou un chemin construit (jumelle négative)", {
  skip_si_pas_utf8()
  s <- sc("d <- read.csv('data/base.csv')",
          "u <- read.csv('https://exemple.org/base.csv')",
          "p <- read.csv(file.path('data', 'base.csv'))",
          "q <- read.csv(here::here('data', 'base.csv'))")
  expect_length(rep01_paths(s), 0L)
})

test_that("REP-01 lit le chemin positionnel des fonctions d'écriture", {
  skip_si_pas_utf8()
  s <- sc("write.csv(d, '/tmp/sortie.csv')", "ggsave('/tmp/fig.png', g)",
          "writeLines('texte', '/tmp/log.txt')", "write.csv(d, 'sortie.csv')")
  expect_length(rep01_paths(s), 3L)
})

test_that("REP-01 lit l'argument nommé file", {
  skip_si_pas_utf8()
  s <- sc("save(d, file = '/data/x.RData')")
  expect_length(rep01_paths(s), 1L)
})

test_that("REP-01 signale un fichier d'entrée relatif introuvable (certitude)", {
  skip_si_pas_utf8()
  dir <- tempfile("projet")
  dir.create(file.path(dir, "data"), recursive = TRUE)
  writeLines("a,b", file.path(dir, "data", "present.csv"))
  s <- sc("a <- read.csv('data/present.csv')", "b <- read.csv('data/absent.csv')",
          "write.csv(a, 'sortie/pas_encore.csv')")
  res <- rep01_paths(s, project_dir = dir)
  expect_length(res, 1L) # l'écriture n'exige pas que le fichier existe
  expect_equal(res[[1]]$severity, "certitude")
  expect_match(res[[1]]$message, "data/absent.csv", fixed = TRUE)
  expect_length(rep01_paths(s), 0L) # sans project_dir : existence non contrôlée
})

# REP-02 -----------------------------------------------------------------------

test_that("REP-02 signale ranger() sans set.seed() (certitude)", {
  skip_si_pas_utf8()
  s <- sc("fit <- ranger::ranger(y ~ ., data = d)")
  res <- rep02_seed(s)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("REP-02 ne signale pas quand la graine précède l'appel (jumelle négative)", {
  skip_si_pas_utf8()
  s <- sc("set.seed(2026)", "fit <- ranger::ranger(y ~ ., data = d)",
          "x <- rnorm(10)")
  expect_length(rep02_seed(s), 0L)
})

test_that("REP-02 signale un appel placé avant la graine", {
  skip_si_pas_utf8()
  s <- sc("x <- rnorm(10)", "set.seed(1)", "y <- rnorm(10)")
  res <- rep02_seed(s)
  expect_length(res, 1L)
  expect_match(res[[1]]$location, "ligne 1")
})

test_that("REP-02 regroupe par fonction et compte les appels", {
  skip_si_pas_utf8()
  s <- sc("a <- sample(10)", "b <- sample(5)", "c <- runif(3)")
  res <- rep02_seed(s)
  expect_length(res, 2L)
  n <- vapply(res, function(f) f$details$n_calls, integer(1))
  expect_setequal(n, c(2L, 1L))
})

test_that("REP-02 accepte un argument seed et ignore les définitions de fonctions", {
  skip_si_pas_utf8()
  expect_length(rep02_seed(sc("m <- mice::mice(d, seed = 12)")), 0L)
  expect_length(rep02_seed(sc("simuler <- function(n) rnorm(n)")), 0L)
})

test_that("REP-02 devient un risque probable si le script appelle source()", {
  skip_si_pas_utf8()
  s <- sc("source('00_parametres.R')", "x <- rnorm(10)")
  res <- rep02_seed(s)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
})

# REP-03 -----------------------------------------------------------------------

test_that("REP-03 signale un projet sans fichier d'environnement", {
  skip_si_pas_utf8()
  dir <- tempfile("projet")
  dir.create(dir)
  writeLines("1", file.path(dir, "analyse.R"))
  res <- rep03_environment(dir)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
})

test_that("REP-03 ne signale pas un projet avec renv.lock, Dockerfile ou sessionInfo (jumelle négative)", {
  skip_si_pas_utf8()
  for (nom in c("renv.lock", "Dockerfile", "sessionInfo.txt", "session_info.md")) {
    dir <- tempfile("projet")
    dir.create(dir)
    writeLines("x", file.path(dir, nom))
    expect_length(rep03_environment(dir), 0L)
  }
})

test_that("REP-03 trouve un fichier dans un sous-dossier mais ignore .git", {
  skip_si_pas_utf8()
  dir <- tempfile("projet")
  dir.create(file.path(dir, "docs"), recursive = TRUE)
  writeLines("x", file.path(dir, "docs", "sessionInfo.txt"))
  expect_length(rep03_environment(dir), 0L)
  dir2 <- tempfile("projet")
  dir.create(file.path(dir2, ".git"), recursive = TRUE)
  writeLines("x", file.path(dir2, ".git", "renv.lock"))
  expect_length(rep03_environment(dir2), 1L)
})

test_that("REP-03 refuse un dossier inexistant", {
  skip_si_pas_utf8()
  expect_error(rep03_environment(file.path(tempdir(), "inexistant")), "introuvable")
})

test_that("REP-01 ne confond pas une URL avec un fichier introuvable", {
  skip_si_pas_utf8()
  dir <- tempfile("projet")
  dir.create(dir)
  s <- sc("u <- read.csv('https://exemple.org/base.csv')")
  expect_length(rep01_paths(s, project_dir = dir), 0L)
})
