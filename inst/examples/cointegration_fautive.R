# Exemple pédagogique : cointégration d'Engle-Granger mal conduite.
# Écrit pour la documentation de `referee` ; il ne s'appuie sur aucune donnée réelle.
library(readxl)
library(tseries)

donnees <- read_excel("data/series.xlsx")
x <- ts(donnees$x, start = 1994)
y <- ts(donnees$y, start = 1994)

adf.test(x)
adf.test(y)

reg <- lm(x ~ y)
res <- residuals(reg)
adf.test(res)          # SER-01 : valeurs critiques de Dickey-Fuller sur résidus estimés
kpss.test(res)         # SER-01

jo <- ca.jo(cbind(x, y))   # REP-04 : `urca` n'est pas chargé
summary(jo)
