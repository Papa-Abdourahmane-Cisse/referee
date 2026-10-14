# DOC-01 : Chiffre du texte différent de celui de la sortie qui l'a produit

**Famille** : DOC (Cohérence documentaire)  
**Niveaux de confiance** : certitude, à justifier  
**Détection** : texte, métadonnées  
**Entrées requises** : un document texte ; métadonnées : `figures`

## Ce que la règle détecte

Pour chaque chiffre déclaré (`figures`), repère les phrases du document qui correspondent au motif, lit le premier nombre qui suit le motif et le compare à la valeur de la sortie (multipliée par `factor`, 1 par défaut). La tolérance est l'arrondi implicite de la précision affichée dans le texte : « 37,5 » tolère un écart de 0,05. Un écart est un constat de certitude : le chiffre est relié à sa source par déclaration. Un chiffre dont le motif ne correspond à aucune phrase est signalé à justifier (la règle ne peut pas conclure).

## Pourquoi c'est un problème

Un chiffre recopié à la main dans le texte peut différer de celui de la sortie après une mise à jour du calcul.

## Que faire en cas d'alerte

Générer le texte depuis les sorties (R Markdown, Quarto) ou relire chaque chiffre contre sa source.

## Exemple

```r
referee_meta(figures = list(list(name = 'taux', value = 37.5, pattern = 'taux de pauvreté')))
```

## Utilisation

```r
library(referee)
rapport <- audit(document = "rapport.md",
                  meta = referee_meta(figures = list(list(name = "taux", value = 37.5, pattern = "taux de pauvreté"))))
rapport
```

## Limites connues

Limites : le lien entre le texte et la sortie est celui que l'utilisateur déclare ; un motif trop large peut rattacher le mauvais nombre ; les chiffres non déclarés ne sont pas examinés. Un écart d'un facteur 100 est signalé comme possible confusion d'échelle.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

