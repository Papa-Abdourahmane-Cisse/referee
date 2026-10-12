make_ages <- function(n = 20000L, heap = 0, seed = 61L) {
  set.seed(seed)
  age <- sample(0:90, n, replace = TRUE, prob = exp(-(0:90) / 40))
  # Une part `heap` des personnes de 23 à 62 ans arrondit son âge au multiple de 5.
  idx <- which(age >= 23 & age <= 62 & runif(n) < heap)
  age[idx] <- 5 * round(age[idx] / 5)
  data.frame(age = age)
}

whipple <- function(a) {
  a <- a[a >= 23 & a <= 62]
  500 * mean(a %% 5 == 0)
}

# DEM-01 -----------------------------------------------------------------------

test_that("DEM-01 signale des âges arrondis à 0 ou 5", {
  d <- make_ages(heap = 0.4)
  res <- dem01_age_heaping(d, "age")
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_equal(res[[1]]$details$index, whipple(d$age), tolerance = 1e-12)
  expect_gt(res[[1]]$details$index, 125)
})

test_that("DEM-01 ne signale pas des âges sans préférence de chiffre (jumelle négative)", {
  d <- make_ages(heap = 0)
  expect_length(dem01_age_heaping(d, "age"), 0L)
  expect_lt(whipple(d$age), 125)
})

test_that("DEM-01 applique les poids quand ils sont déclarés", {
  d <- make_ages(heap = 0)
  d$poids <- ifelse(d$age %% 5 == 0, 3, 1)
  expect_length(dem01_age_heaping(d, "age"), 0L)
  res <- dem01_age_heaping(d, "age", weights = "poids")
  expect_length(res, 1L)
  w <- d$poids[d$age >= 23 & d$age <= 62]
  a <- d$age[d$age >= 23 & d$age <= 62]
  expect_equal(res[[1]]$details$index, 500 * sum(w[a %% 5 == 0]) / sum(w),
               tolerance = 1e-12)
})

test_that("DEM-01 ignore les âges hors de 23-62 ans", {
  d <- make_ages(heap = 0)
  idx <- which(d$age > 62 & runif(nrow(d)) < 0.9)
  d$age[idx] <- 5 * round(d$age[idx] / 5)
  expect_length(dem01_age_heaping(d, "age"), 0L)
})

test_that("DEM-01 respecte le seuil paramétré", {
  d <- make_ages(heap = 0.4)
  expect_length(dem01_age_heaping(d, "age", threshold = 1000), 0L)
})

test_that("DEM-01 est non évaluée sur âges non entiers ou effectif trop faible", {
  d <- make_ages(heap = 0.4)
  dec <- data.frame(age = d$age + 0.5)
  res <- dem01_age_heaping(dec, "age")
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "non entiers")
  petit <- d[1:200, , drop = FALSE]
  expect_match(attr(dem01_age_heaping(petit, "age"), "not_evaluated"),
               "moins de 500")
})

test_that("DEM-01 refuse un âge non numérique", {
  expect_error(dem01_age_heaping(data.frame(age = c("a", "b")), "age"), "num")
})

# DEM-02 -----------------------------------------------------------------------

make_balance <- function() {
  data.frame(zone = c("A", "B", "C"),
             p0 = c(1000, 2000, 3000), nais = c(30, 60, 90),
             deces = c(10, 20, 30), imm = c(5, 10, 15), emi = c(2, 4, 6),
             p1 = c(1023, 2046, 3069))
}
bal <- list(p0 = "p0", p1 = "p1", births = "nais", deaths = "deces",
            immigrants = "imm", emigrants = "emi")

test_that("DEM-02 signale une population finale qui ne boucle pas", {
  d <- make_balance()
  d$p1[2] <- 2100
  res <- dem02_balancing_equation(d, bal)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_equal(res[[1]]$details$n, 1L)
  expect_equal(res[[1]]$details$max_gap, 54)
  expect_equal(res[[1]]$details$rows, 2L)
})

test_that("DEM-02 ne signale pas une équation respectée (jumelle négative)", {
  expect_length(dem02_balancing_equation(make_balance(), bal), 0L)
})

test_that("DEM-02 tolère l'arrondi mais pas un écart plus grand", {
  d <- make_balance()
  d$p1[1] <- d$p1[1] + 0.4
  expect_length(dem02_balancing_equation(d, bal), 0L)
  d$p1[1] <- d$p1[1] + 0.2
  expect_length(dem02_balancing_equation(d, bal), 1L)
})

test_that("DEM-02 respecte la tolérance relative", {
  d <- make_balance()
  d$p1[1] <- d$p1[1] + 10 # 1 % de 1033
  expect_length(dem02_balancing_equation(d, bal, tol_rel = 0.02), 0L)
  expect_length(dem02_balancing_equation(d, bal, tol_rel = 0.005), 1L)
})

test_that("DEM-02 suppose une population fermée sans migration déclarée et le dit", {
  d <- make_balance()
  fermee <- list(p0 = "p0", p1 = "p1", births = "nais", deaths = "deces")
  res <- dem02_balancing_equation(d, fermee)
  expect_length(res, 1L) # les migrations des données ne sont pas prises en compte
  expect_match(res[[1]]$message, "population supposée fermée", fixed = TRUE)
  expect_false(grepl("fermée", dem02_balancing_equation(
    transform(d, p1 = 0), bal)[[1]]$message))
})

test_that("DEM-02 ignore les lignes incomplètes et est non évaluée si aucune n'est complète", {
  d <- make_balance()
  d$deces[1] <- NA
  d$p1[2] <- 2100
  res <- dem02_balancing_equation(d, bal)
  expect_equal(res[[1]]$details$n, 1L)
  d$nais <- NA_real_
  res2 <- dem02_balancing_equation(d, bal)
  expect_length(res2, 0L)
  expect_match(attr(res2, "not_evaluated"), "aucune ligne")
})

test_that("DEM-02 refuse une déclaration incomplète", {
  expect_error(dem02_balancing_equation(make_balance(), list(p0 = "p0")), "balance")
  expect_error(referee_meta(balance = list(p0 = "p0", p1 = "p1")), "balance")
})

# DEM-03 -----------------------------------------------------------------------

make_lt <- function() {
  data.frame(age = c(0, 1, 5, 10, 15),
             qx = c(0.05, 0.02, 0.01, 0.005, 0.004),
             lx = c(100000, 95000, 93100, 92169, 91708))
}
lt <- list(age = "age", qx = "qx", lx = "lx")

test_that("DEM-03 signale un lx supérieur à celui de l'âge précédent", {
  d <- make_lt()
  d$lx[4] <- 93500
  res <- dem03_life_table(d, lt)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "certitude")
  expect_match(res[[1]]$message, "l'âge 10", fixed = TRUE)
})

test_that("DEM-03 signale un qx hors de [0 ; 1]", {
  d <- make_lt()
  d$qx[2] <- 1.2
  d$qx[3] <- -0.01
  res <- dem03_life_table(d, lt)
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$n, 2L)
})

test_that("DEM-03 ne signale pas une table cohérente (jumelle négative)", {
  expect_length(dem03_life_table(make_lt(), lt), 0L)
  # lx constant entre deux âges (aucun décès) n'est pas une hausse.
  d <- make_lt()
  d$lx[3] <- d$lx[2]
  expect_length(dem03_life_table(d, lt), 0L)
})

test_that("DEM-03 ordonne les lignes par âge avant de comparer", {
  d <- make_lt()[c(4, 1, 5, 3, 2), ]
  expect_length(dem03_life_table(d, lt), 0L)
})

test_that("DEM-03 ignore les valeurs manquantes", {
  d <- make_lt()
  d$lx[3] <- NA
  d$qx[1] <- NA
  expect_length(dem03_life_table(d, lt), 0L)
})

test_that("DEM-03 traite chaque table séparément quand `by` est fourni", {
  a <- make_lt(); a$sexe <- "F"
  b <- make_lt(); b$sexe <- "M"
  b$lx[5] <- 95000
  d <- rbind(a, b)
  res <- dem03_life_table(d, c(lt, by = "sexe"))
  expect_length(res, 1L)
  expect_match(res[[1]]$message, "table : M", fixed = TRUE)
  # Sans `by`, deux tables empilées font apparaître une fausse hausse.
  expect_length(dem03_life_table(d, lt), 1L)
})

test_that("DEM-03 accepte une table réduite à qx ou à lx", {
  expect_length(dem03_life_table(make_lt(), list(age = "age", qx = "qx")), 0L)
  expect_length(dem03_life_table(make_lt(), list(age = "age", lx = "lx")), 0L)
  expect_error(dem03_life_table(make_lt(), list(age = "age")), "lifetable")
})

# DEM-04 -----------------------------------------------------------------------

make_pop <- function(ratio_by_group, n_per_sex = 400L, seed = 71L) {
  set.seed(seed)
  do.call(rbind, lapply(names(ratio_by_group), function(g) {
    r <- ratio_by_group[[g]]
    n_m <- round(n_per_sex * r / 100)
    data.frame(groupe = g, sexe = c(rep("M", n_m), rep("F", n_per_sex)),
               stringsAsFactors = FALSE)
  }))
}
sr <- list(group = "groupe", sex = "sexe", male = "M")

test_that("DEM-04 signale un groupe d'âges à 140 hommes pour 100 femmes", {
  d <- make_pop(list("20-24" = 140, "25-29" = 100, "30-34" = 95))
  res <- dem04_sex_ratio(d, sr)
  expect_length(res, 1L)
  expect_equal(res[[1]]$severity, "a_justifier")
  expect_equal(res[[1]]$details$groups, "20-24")
  expect_equal(unname(res[[1]]$details$ratios), 140)
})

test_that("DEM-04 ne signale pas des rapports dans la plage (jumelle négative)", {
  d <- make_pop(list("20-24" = 105, "25-29" = 100, "30-34" = 85, "35-39" = 118))
  expect_length(dem04_sex_ratio(d, sr), 0L)
})

test_that("DEM-04 respecte la plage paramétrée", {
  d <- make_pop(list("20-24" = 140, "25-29" = 100))
  expect_length(dem04_sex_ratio(d, sr, range = c(80, 150)), 0L)
  res <- dem04_sex_ratio(d, sr, range = c(105, 120)) # 100 < 105 et 140 > 120
  expect_setequal(res[[1]]$details$groups, c("20-24", "25-29"))
})

test_that("DEM-04 applique les poids", {
  d <- make_pop(list("20-24" = 100, "25-29" = 100))
  d$poids <- ifelse(d$sexe == "M", 1.5, 1)
  expect_length(dem04_sex_ratio(d, sr), 0L) # 100 sans poids... mais 150 avec
  res <- dem04_sex_ratio(d, sr, weights = "poids")
  expect_length(res, 1L)
  expect_equal(sort(res[[1]]$details$groups), c("20-24", "25-29"))
})

test_that("DEM-04 ignore les groupes de trop faible effectif", {
  d <- make_pop(list("20-24" = 140, "25-29" = 100), n_per_sex = 40)
  res <- dem04_sex_ratio(d, sr)
  expect_length(res, 0L)
  expect_match(attr(res, "not_evaluated"), "aucun groupe")
  d2 <- rbind(make_pop(list("20-24" = 100)), 
              make_pop(list("30-34" = 150), n_per_sex = 20))
  expect_length(dem04_sex_ratio(d2, sr), 0L) # le groupe atypique est trop petit
})

test_that("DEM-04 accepte des effectifs agrégés", {
  agg <- data.frame(tranche = c("20-24", "25-29", "30-34"),
                    h = c(560, 400, 380), f = c(400, 400, 400))
  res <- dem04_sex_ratio(agg, list(group = "tranche", males = "h", females = "f"))
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$groups, "20-24")
})

test_that("DEM-04 refuse une déclaration invalide", {
  expect_error(dem04_sex_ratio(data.frame(a = 1), list(group = "a")), "sexratio")
  expect_error(referee_meta(sexratio = list(group = "g", sex = "s")), "sexratio")
})

test_that("DEM-01 : valeurs de référence de l'indice de Whipple (calcul à la main)", {
  # Chaque âge de 23 à 62 ans une fois : 8 âges sur 40 se terminent par 0 ou 5,
  # soit un cinquième : indice = 100.
  uniforme <- data.frame(age = rep(23:62, each = 15))
  res <- dem01_age_heaping(uniforme, "age", threshold = 0)
  expect_equal(res[[1]]$details$index, 100)
  # Seuls les multiples de 5 : tout le monde se termine par 0 ou 5, indice = 500.
  arrondi <- data.frame(age = rep(seq(25, 60, by = 5), each = 100))
  expect_equal(dem01_age_heaping(arrondi, "age")[[1]]$details$index, 500)
  expect_match(dem01_age_heaping(arrondi, "age")[[1]]$message, "très grossière")
  # Moitié des personnes aux multiples de 5, moitié répartie uniformément.
  mixte <- data.frame(age = c(rep(25, 400), rep(23:62, each = 10)))
  attendu <- 100 * (400 + 80) / (800 / 5)
  expect_equal(dem01_age_heaping(mixte, "age", threshold = 0)[[1]]$details$index,
               attendu)
})

test_that("DEM-04 signale aussi un déficit d'hommes (borne inférieure)", {
  d <- make_pop(list("20-24" = 70, "25-29" = 100))
  res <- dem04_sex_ratio(d, sr)
  expect_length(res, 1L)
  expect_equal(res[[1]]$details$groups, "20-24")
  expect_equal(unname(res[[1]]$details$ratios), 70)
})
