doc <- function(...) read_document(text = c(...))

# DOC-01 -----------------------------------------------------------------------

fig_taux <- function(value, factor = 100) {
  list(list(name = "taux de pauvreté", value = value,
            pattern = "taux de pauvreté", factor = factor))
}

test_that("DOC-01 signale un texte à 37,5 % quand la sortie donne 37,2 %", {
  skip_si_pas_utf8()
  d <- doc("En 2021, le taux de pauvreté atteint 37,5 % au niveau national.")
  res <- doc01_text_vs_output(d, fig_taux(0.372))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_match(res[[1]]$message, "37,5", fixed = TRUE)
  expect_match(res[[1]]$message, "37,2", fixed = TRUE)
  expect_equal(res[[1]]$location, "ligne 1")
})

test_that("DOC-01 ne signale pas un chiffre cohérent avec l'arrondi affiché (jumelle négative)", {
  skip_si_pas_utf8()
  d <- doc("Le taux de pauvreté atteint 37,2 %.")
  expect_length(doc01_text_vs_output(d, fig_taux(0.37249)), 0L)
  d2 <- doc("Le taux de pauvreté atteint 37 %.") # précision affichée : l'unité
  expect_length(doc01_text_vs_output(d2, fig_taux(0.372)), 0L)
})

test_that("DOC-01 ignore l'année placée avant ou après le motif", {
  skip_si_pas_utf8()
  d <- doc("Le taux de pauvreté de 2021 est de 37,2 %.")
  expect_length(doc01_text_vs_output(d, fig_taux(0.372)), 0L)
})

test_that("DOC-01 lit les nombres à espace de milliers et virgule décimale", {
  skip_si_pas_utf8()
  d <- doc("Le total de dépenses est de 1 250 000,5 francs.")
  fig <- list(list(name = "dépenses", value = 1250000.5,
                   pattern = "total de dépenses", factor = 1))
  expect_length(doc01_text_vs_output(d, fig), 0L)
  fig2 <- list(list(name = "dépenses", value = 1260000.5,
                    pattern = "total de dépenses"))
  expect_length(doc01_text_vs_output(d, fig2), 1L)
})

test_that("DOC-01 signale une confusion d'échelle", {
  skip_si_pas_utf8()
  d <- doc("Le taux de pauvreté atteint 0,372.")
  res <- doc01_text_vs_output(d, fig_taux(0.372))
  expect_length(res, 1L)
  expect_match(res[[1]]$message, "facteur 100", fixed = TRUE)
})

test_that("DOC-01 contrôle toutes les phrases qui correspondent au motif", {
  skip_si_pas_utf8()
  d <- doc("Le taux de pauvreté est de 37,2 %. Le taux de pauvreté atteint 38,1 %.")
  res <- doc01_text_vs_output(d, fig_taux(0.372))
  expect_length(res, 1L)
  expect_match(res[[1]]$message, "38,1", fixed = TRUE)
})

test_that("DOC-01 signale un chiffre non localisé, sans conclure", {
  skip_si_pas_utf8()
  d <- doc("Le chômage est élevé.")
  res <- doc01_text_vs_output(d, fig_taux(0.372))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_match(res[[1]]$message, "non localisé")
})

# DOC-02 -----------------------------------------------------------------------

ind_taux <- list(list(name = "taux de pauvreté régional",
                      pattern = "taux de pauvreté"))

test_that("DOC-02 signale le même indicateur sous deux valeurs pour la même région et année", {
  skip_si_pas_utf8()
  d <- doc("En 2021, le taux de pauvreté à Kolda est de 55,3 %.",
           "Plus loin : en 2021, le taux de pauvreté à Kolda atteint 58,9 %.")
  res <- doc02_indicator_consistency(d, ind_taux, geo_terms = c("Kolda", "Dakar"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "risque_probable")
  expect_match(res[[1]]$message, "55,3 ; 58,9", fixed = TRUE)
})

test_that("DOC-02 ne signale pas des régions ou années différentes (jumelle négative)", {
  skip_si_pas_utf8()
  d <- doc("En 2021, le taux de pauvreté à Kolda est de 55,3 %.",
           "En 2021, le taux de pauvreté à Dakar est de 20,1 %.",
           "En 2018, le taux de pauvreté à Kolda était de 58,9 %.")
  res <- doc02_indicator_consistency(d, ind_taux, geo_terms = c("Kolda", "Dakar"))
  expect_length(res, 0L)
})

test_that("DOC-02 tolère l'arrondi d'une même valeur", {
  skip_si_pas_utf8()
  d <- doc("En 2021, le taux de pauvreté à Kolda est de 55,3 %.",
           "En 2021, le taux de pauvreté à Kolda est de 55 %.")
  expect_length(doc02_indicator_consistency(d, ind_taux, c("Kolda")), 0L)
})

test_that("DOC-02 signale un indicateur chiffré sans niveau ni période (à justifier)", {
  skip_si_pas_utf8()
  d <- doc("Le taux de pauvreté est de 37,5 %.")
  res <- doc02_indicator_consistency(d, ind_taux, geo_terms = "Kolda")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_equal(res[[1]]$details$n, 1L)
})

test_that("DOC-02 ne compare pas des phrases sans année ni lieu entre elles comme un doublon", {
  skip_si_pas_utf8()
  # Deux chiffres sans qualificatif : un seul constat « sans niveau ni période ».
  d <- doc("Le taux de pauvreté est de 37,5 %.", "Le taux de pauvreté est de 40,0 %.")
  res <- doc02_indicator_consistency(d, ind_taux)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_equal(res[[1]]$details$n, 2L)
})

# DOC-03 -----------------------------------------------------------------------

test_that("DOC-03 signale le langage causal d'un résultat observationnel", {
  skip_si_pas_utf8()
  d <- doc("Le programme réduit la pauvreté de 4 points.",
           "L'impact du programme sur la consommation est de 12 %.",
           "La pauvreté est associée à la taille du ménage.")
  res <- doc03_causal_language(d, "observationnel")
  expect_length(res, 1L) # « réduit » n'est pas dans la liste ; « L'impact du » oui
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_equal(res[[1]]$location, "ligne 2")
})

test_that("DOC-03 reconnaît plusieurs formulations causales", {
  skip_si_pas_utf8()
  d <- doc("La mesure entraîne une hausse des prix.",
           "Cette baisse est due à la sécheresse.",
           "Grâce au programme, les ménages épargnent.",
           "On observe un effet causal du transfert.",
           "Les prix sont corrélés à la pluviométrie.")
  res <- doc03_causal_language(d, "aucun")
  expect_length(res, 4L)
})

test_that("DOC-03 se tait quand un design d'identification est déclaré (jumelle négative)", {
  skip_si_pas_utf8()
  d <- doc("L'impact du programme sur la consommation est de 12 %.")
  for (design in c("Double différence", "expérience aléatoire (RCT)",
                   "discontinuité de régression", "Variables instrumentales",
                   "appariement (PSM)")) {
    expect_length(doc03_causal_language(d, design), 0L)
  }
})

test_that("DOC-03 ne confond pas un design avec un mot qui le contient", {
  skip_si_pas_utf8()
  d <- doc("L'impact du programme est de 12 %.")
  # « ivoire » commence par « iv » ; « candidat » contient « did ».
  expect_length(doc03_causal_language(d, "ivoire candidat"), 1L)
  expect_length(doc03_causal_language(d, "IV"), 0L)
})

# read_document ----------------------------------------------------------------

test_that("read_document lit un fichier et refuse des arguments ambigus", {
  skip_si_pas_utf8()
  f <- tempfile(fileext = ".txt")
  writeLines(c("Ligne un.", "Ligne deux."), f)
  d <- read_document(path = f)
  expect_equal(length(d$lines), 2L)
  expect_error(read_document(), "exactement")
  expect_error(read_document(text = "a", path = f), "exactement")
  expect_error(read_document(path = file.path(tempdir(), "absent.txt")), "introuvable")
})
