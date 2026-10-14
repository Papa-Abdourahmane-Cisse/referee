# Suivi du pipe, plan sans grappe, chemins en variable, inférence ------------

test_that("SUR-01 suit le pipe et rattache summarise() à sa table de départ", {
  s <- parse_script(text = paste(
    "res <- enes %>%",
    "  dplyr::group_by(dept) %>%",
    "  dplyr::summarise(m = mean(emploi, na.rm = TRUE))",
    "mean(autre$x)", sep = "\n"))
  f <- sur01_unweighted_estimators(s, weights = "w", data_objects = "enes")
  expect_length(f, 1L)
  expect_match(f[[1L]]$location, "mean\\(emploi")
})

test_that("SUR-01 (jumelle négative) : table non déclarée comme enquête, ou poids cité", {
  s <- parse_script(text = paste(
    "rgph %>% dplyr::summarise(m = mean(age))",
    "enes %>% dplyr::summarise(m = weighted.mean(emploi, w))",
    "enes %>% dplyr::summarise(m = mean(emploi * w))", sep = "\n"))
  expect_length(sur01_unweighted_estimators(s, "w", data_objects = "enes"), 0L)
})

test_that("un pipe avec `.` n'ajoute pas lhs en première position", {
  s <- parse_script(text = "d %>% lm(y ~ x, data = .)")
  noms <- vapply(collect_calls(s), function(r) r$name, character(1))
  expect_true("lm" %in% noms)
  expect_false(any(duplicated(noms[noms == "lm"])))
})

test_that("SUR-03 signale un plan sans grappe, sans métadonnée", {
  s <- parse_script(text = "svydesign(ids = ~1, weights = ~w, data = d)")
  f <- sur03_design_ignored(s)
  expect_length(f, 1L)
  expect_equal(f[[1L]]$severity, "a_justifier")
})

test_that("SUR-03 passe en risque probable si une grappe est déclarée", {
  s <- parse_script(text = "svydesign(ids = ~0, weights = ~w, data = d)")
  f <- sur03_design_ignored(s, psu = "zd")
  expect_equal(f[[1L]]$severity, "risque_probable")
})

test_that("SUR-03 (jumelle négative) : plan avec grappe, ou aucun plan", {
  s <- parse_script(text = "svydesign(ids = ~zd, strata = ~st, weights = ~w, data = d)")
  expect_length(sur03_design_ignored(s), 0L)
  expect_false(is.null(attr(sur03_design_ignored(parse_script(text = "x <- 1")),
                            "not_evaluated")))
})

test_that("REP-01 reconstitue un chemin absolu passé par une variable", {
  s <- parse_script(text = paste(
    "chemin <- \"C:/Users/moi/data/\"",
    "d <- read.csv(paste0(chemin, \"a.csv\"))",
    "write.csv(d, file.path(chemin, \"b.csv\"))", sep = "\n"))
  f <- rep01_paths(s)
  expect_length(f, 2L)
  expect_match(f[[1L]]$message, "variable `chemin`")
})

test_that("REP-01 (jumelle négative) : chemin relatif en variable, fonction inconnue", {
  s <- parse_script(text = paste(
    "dossier <- \"data/\"",
    "a <- read.csv(paste0(dossier, \"a.csv\"))",
    "b <- read.csv(here::here(\"b.csv\"))",
    "c <- read.csv(paste0(inconnue, \"c.csv\"))", sep = "\n"))
  expect_length(rep01_paths(s), 0L)
})

test_that("infer_meta lit poids, grappes, strates et table d'enquête", {
  s <- parse_script(text = paste(
    "plan <- svydesign(ids = ~zd, strata = ~st, weights = ~pond,",
    "                  data = enes %>% dplyr::filter(age >= 15))", sep = "\n"))
  m <- infer_meta(s)
  expect_equal(m$weights, "pond")
  expect_equal(m$psu, "zd")
  expect_equal(m$strata, "st")
  expect_equal(m$data_objects, "enes")
})

test_that("infer_meta n'infère pas un poids ambigu et ignore ids = ~1", {
  s <- parse_script(text = paste(
    "svydesign(ids = ~1, weights = ~w1, data = a)",
    "svydesign(ids = ~1, weights = ~w2, data = b)", sep = "\n"))
  m <- infer_meta(s)
  expect_null(m$weights)
  expect_null(m$psu)
})

test_that("audit(infer = TRUE) complète sans écraser la déclaration de l'utilisateur", {
  f <- tempfile(fileext = ".R")
  writeLines(c("svydesign(ids = ~1, weights = ~w, data = enes)",
               "mean(enes$x)"), f)
  r <- audit(script = f, infer = TRUE)
  expect_equal(r$inferred$weights, "w")
  expect_true("SUR-01" %in% r$rules$rule_id[r$rules$status == "evaluee"])
  r2 <- audit(script = f, meta = referee_meta(weights = "autre"), infer = TRUE)
  expect_null(r2$inferred$weights)
  expect_output(print(r), "inf\u00e9r\u00e9es")
})

test_that("audit_script lit le plan du script et explain_rule affiche une fiche", {
  ex <- system.file("examples", "enquete_fautive.R", package = "referee")
  skip_if(!nzchar(ex), "exemples non installés")
  r <- audit_script(ex)
  expect_true("SUR-01" %in% r$rules$rule_id[r$rules$status == "evaluee"])
  expect_gte(sum(as.data.frame(r)$rule_id == "SUR-01"), 3L)
  expect_output(explain_rule("SUR-01"), "SUR-01")
  expect_error(explain_rule("XXX-99"), "rule_ids")
})

test_that("les scripts d'exemple se comportent comme annoncé", {
  d <- system.file("examples", package = "referee")
  skip_if(!nzchar(d), "exemples non installés")
  propre <- audit_script(file.path(d, "enquete_propre.R"))
  expect_equal(nrow(as.data.frame(propre)), 0L)
  fautive <- as.data.frame(audit_script(file.path(d, "enquete_fautive.R")))
  # le recensement (ligne `age_moyen`) ne doit pas être signalé
  expect_false(any(grepl("mean\\(age", fautive$location)))
  expect_equal(sum(fautive$rule_id == "SUR-01"), 3L)
  expect_setequal(unique(fautive$rule_id), c("SUR-01", "SUR-03", "REP-01"))
})
