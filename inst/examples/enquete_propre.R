# Exemple SANS erreur détectable : enquête ménages analysée avec son plan.
library(dplyr)
library(survey)
library(here)

set.seed(2024)
menages <- readRDS(here("data", "menages.rds"))

plan <- svydesign(ids = ~grappe, strata = ~strate,
                  weights = ~poids_men, data = menages, nest = TRUE)

taux_pauvrete <- svymean(~pauvre, plan, na.rm = TRUE)
par_region <- svyby(~pauvre, ~region, plan, svymean, na.rm = TRUE)

modele <- svyglm(pauvre ~ urbain + taille_men, design = plan,
                 family = quasibinomial())
