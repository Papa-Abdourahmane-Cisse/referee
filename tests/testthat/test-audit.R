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
