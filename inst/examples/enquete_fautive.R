# Exemple AVEC erreurs : enquête pondérée analysée comme un échantillon simple.
library(dplyr)
library(survey)

chemin <- "C:/Users/moi/Documents/projet/"
set.seed(1)
enq <- readRDS(paste0(chemin, "enquete.rds"))
recensement <- readRDS(paste0(chemin, "recensement.rds"))

plan <- svydesign(ids = ~1, weights = ~poids, data = enq)

# Erreur : moyenne non pondérée de microdonnées d'enquête
taux <- mean(enq$emploi, na.rm = TRUE)

# Erreur : même chose dans un summarise (via le pipe)
par_dept <- enq %>%
  group_by(dept) %>%
  summarise(taux = mean(emploi, na.rm = TRUE))

# Pas une erreur : le recensement n'est pas pondéré par le poids de l'enquête
age_moyen <- recensement %>% summarise(m = mean(age, na.rm = TRUE))

# Erreur : régression sans le plan ni les poids
reg <- lm(emploi ~ urbain + age, data = enq)
