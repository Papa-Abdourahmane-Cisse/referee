# Exemple AVEC erreurs d'identification : double différence échelonnée.
library(fixest)

panel <- readRDS("data/panel_villages.rds")

# Erreur : effets fixes bidirectionnels, adoption échelonnée, sans estimateur
# robuste à l'hétérogénéité, et sans examen des tendances pré-traitement.
modele <- feols(revenu ~ traite | village + annee, data = panel)
summary(modele)
