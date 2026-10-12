meta_complete <- function() {
  referee_meta(
    weights = "hhweight", size = "hhsize", group = "region",
    group_vars = "taux_region", key = "commune",
    aggregated_vars = "taux_commune", data_objects = "df",
    scales = c(taux_commune = "proportion")
  )
}

test_that("audit sur données seules : les règles sans entrée sont non évaluées", {
  rapport <- audit(data = make_survey(), meta = meta_complete())
  expect_s3_class(rapport, "referee_report")
  statut <- setNames(rapport$rules$status, rapport$rules$rule_id)
  expect_equal(statut[["SUR-04"]], "evaluee")
  expect_equal(statut[["LVL-01"]], "evaluee")
  expect_equal(statut[["SUR-01"]], "non_evaluee")
  expect_equal(statut[["NUM-02"]], "non_evaluee") # métadonnée `sums` absente
  raison <- setNames(rapport$rules$reason, rapport$rules$rule_id)
  expect_match(raison[["SUR-01"]], "script non fourni")
  expect_match(raison[["NUM-02"]], "métadonnées manquantes : sums")
})

test_that("audit remonte les erreurs injectées et leur confiance", {
  d <- make_survey()
  d$hhweight[2] <- -1 # SUR-04 certitude
  d <- rbind(d, d[5, ]) # LVL-03 certitude
  d$taux_commune[1] <- 1.4 # NUM-01 certitude
  script <- parse_script(text = paste(
    "m <- mean(df$taux_commune)", # SUR-01 et LVL-02
    "w <- df$hhweight / df$hhsize", # SUR-02
    sep = "\n"))
  rapport <- audit(data = d, script = script, meta = meta_complete())
  tab <- as.data.frame(rapport)
  expect_setequal(unique(tab$rule_id),
                  c("SUR-01", "SUR-02", "SUR-04", "LVL-01", "LVL-02",
                    "LVL-03", "NUM-01"))
  # LVL-01 : taux_region est constante par région dans make_survey().
  expect_equal(tab$severity[tab$rule_id == "SUR-04"], "certitude")
  expect_equal(tab$severity[tab$rule_id == "SUR-01"], "risque_probable")
})

test_that("audit accepte un chemin de script", {
  f <- tempfile(fileext = ".R")
  writeLines("w <- df$hhweight / df$hhsize", f)
  rapport <- audit(script = f, meta = meta_complete())
  expect_equal(as.data.frame(rapport)$rule_id, "SUR-02")
})

test_that("audit refuse une variable déclarée absente des données", {
  skip_si_pas_utf8()
  expect_error(
    audit(data = make_survey(), meta = referee_meta(weights = "poids_inconnu")),
    "absentes des données")
})

test_that("audit refuse des arguments mal typés", {
  expect_error(audit(meta = list()), "referee_meta")
  expect_error(audit(data = 1:3), "data frame")
  expect_error(audit(script = 3), "parse_script")
})

test_that("params surcharge le paramètre d'une règle", {
  d <- make_survey()
  d$hhweight[1] <- 30 # ratio max/médiane ~ 20 à 30 : sous le seuil par défaut
  m <- referee_meta(weights = "hhweight")
  defaut <- audit(data = d, meta = m)
  strict <- audit(data = d, meta = m,
                  params = list("SUR-04" = list(ratio_max_median = 5)))
  expect_equal(nrow(as.data.frame(defaut)), 0L)
  expect_equal(nrow(as.data.frame(strict)), 1L)
})

test_that("le rapport s'imprime et rappelle qu'aucune alerte ne vaut validation", {
  skip_si_pas_utf8()
  vide <- audit(data = make_survey(), meta = referee_meta(weights = "hhweight"))
  expect_output(print(vide), "Rapport d'audit du Référé")
  expect_output(print(vide), "ne vaut pas validation")
  expect_output(print(vide), "Règles non évaluées")

  d <- make_survey()
  d$hhweight[2] <- -1
  expect_output(print(audit(data = d, meta = referee_meta(weights = "hhweight"))),
                "Certitude \\(1\\)")
})

test_that("referee_meta valide ses arguments", {
  expect_error(referee_meta(weights = c("a", "b")), "nom de variable")
  expect_error(referee_meta(scales = c(x = "autre")), "scales")
  expect_error(referee_meta(fgt_cols = c("a", "b")), "trois noms")
  expect_error(referee_meta(sums = list(list(parts = "a"))), "exactement")
})

test_that("audit exécute la famille VAL quand script et métadonnées sont fournis", {
  d <- make_survey()
  d$cible <- d$taux_commune
  d$proxy <- d$cible + 1e-4 * seq_len(nrow(d))
  script <- parse_script(text = paste(
    "df$x <- scale(df$x)",
    "sp <- initial_split(df)",
    "folds <- vfold_cv(training(sp), v = 5)",
    "p <- predict(fit, newdata = train)",
    sep = "\n"))
  meta <- referee_meta(group = "region", target = "cible",
                       train_objects = "train", test_objects = "test",
                       time = "commune")
  rapport <- audit(data = d, script = script, meta = meta)
  tab <- as.data.frame(rapport)
  expect_true(all(c("VAL-01", "VAL-02", "VAL-03", "VAL-05", "VAL-06") %in% tab$rule_id))
  statut <- setNames(rapport$rules$status, rapport$rules$rule_id)
  expect_equal(statut[["VAL-04"]], "evaluee") # test_objects déclaré, aucun constat
  expect_false("VAL-04" %in% tab$rule_id)
})

test_that("referee_meta contrôle les nouvelles métadonnées", {
  expect_error(referee_meta(target = c("a", "b")), "target")
  expect_error(audit(data = make_survey(), meta = referee_meta(target = "absente")),
               "absentes")
})

test_that("audit exécute la famille ECO quand script, données et métadonnées sont fournis", {
  set.seed(41)
  d <- expand.grid(unit = 1:12, annee = 2010:2017)
  adopt <- rep(c(2012, 2014, NA), each = 4)
  d$traite <- as.integer(!is.na(adopt[d$unit]) & d$annee >= adopt[d$unit])
  z <- rnorm(nrow(d))
  d$z <- z
  d$x <- 0.02 * z + rnorm(nrow(d))
  d$village <- d$unit %% 4
  d$score <- rnorm(nrow(d))
  script <- parse_script(text = paste(
    "m <- fixest::feols(y ~ traite | unit + annee, data = d)",
    "f <- lm(y ~ traite, data = d)", sep = "\n"))
  meta <- referee_meta(cluster = "village", unit = "unit", time = "annee",
                       treat = "traite", endog = "x", instruments = "z",
                       score = "score", cutoff = 0)
  rapport <- audit(data = d, script = script, meta = meta)
  tab <- as.data.frame(rapport)
  expect_true(all(c("ECO-01", "ECO-02", "ECO-03", "ECO-04") %in% tab$rule_id))
  statut <- setNames(rapport$rules$status, rapport$rules$rule_id)
  expect_equal(statut[["ECO-05"]], "evaluee")
})

test_that("audit exécute les familles EXT, REP et DOC avec document et dossier de projet", {
  skip_si_pas_utf8()
  dir <- tempfile("projet")
  dir.create(dir)
  d <- data.frame(pauvre = c(rep(1, 40), rep(0, 60)), poids = rep(1, 100))
  script <- parse_script(text = "x <- rnorm(5)\nd <- read.csv('/home/abdou/base.csv')")
  doc <- read_document(text = c("Le taux de pauvreté atteint 41,0 %.",
                                "L'impact du programme est de 3 points."))
  meta <- referee_meta(
    weights = "poids",
    references = list(list(name = "taux", reference = 0.30, tol = 0.01, var = "pauvre")),
    poverty = list(line_year = 2018, welfare_year = 2021),
    figures = list(list(name = "taux", value = 0.40, pattern = "taux de pauvreté",
                        factor = 100)),
    indicators = list(list(name = "taux", pattern = "taux de pauvreté")),
    design = "observationnel")
  rapport <- audit(data = d, script = script, meta = meta, document = doc,
                   project_dir = dir)
  tab <- as.data.frame(rapport)
  attendu <- c("EXT-01", "EXT-02", "REP-01", "REP-02", "REP-03", "DOC-01",
               "DOC-02", "DOC-03")
  expect_true(all(attendu %in% tab$rule_id))
  expect_equal(tab$severity[tab$rule_id == "DOC-01"], "certitude")
  # Sans document ni dossier, ces règles sont non évaluées, jamais « passées ».
  sans <- audit(data = d, script = script, meta = meta)
  statut <- setNames(sans$rules$status, sans$rules$rule_id)
  expect_equal(statut[["REP-03"]], "non_evaluee")
  expect_equal(statut[["DOC-01"]], "non_evaluee")
  raison <- setNames(sans$rules$reason, sans$rules$rule_id)
  expect_match(raison[["DOC-03"]], "document non fourni")
  expect_match(raison[["REP-03"]], "dossier du projet non fourni")
  expect_error(audit(document = 1, meta = meta), "document")
  expect_error(audit(project_dir = file.path(tempdir(), "nulle part")), "project_dir")
})
