# Exemple AVEC erreurs de validation en apprentissage automatique.
library(rsample)
library(ranger)
library(recipes)

donnees <- readRDS("data/communes.rds")

# Erreur : transformation apprise sur toutes les données avant la séparation
donnees$x1 <- scale(donnees$x1)

# Erreur : découpage aléatoire alors que les communes sont groupées par région
plis <- vfold_cv(donnees, v = 5)
separation <- initial_split(donnees, prop = 0.8)
train <- training(separation)
test <- testing(separation)

modele <- ranger(y ~ ., data = train, num.trees = 500)

# Erreur : performance rapportée sur l'apprentissage
pred_train <- predict(modele, data = train)$predictions
rmse_train <- sqrt(mean((train$y - pred_train)^2))
