# Catalogue des règles

Chaque fiche décrit ce que la règle détecte, pourquoi, que faire en cas d'alerte, ses limites et un exemple d'utilisation.

| Règle | Titre | Entrées | Confiance |
|---|---|---|---|
| [SUR-01](SUR-01.md) | Estimateur sans poids alors qu'une variable de poids est déclarée | script + méta | risque probable |
| [SUR-02](SUR-02.md) | Poids ménage divisé par la taille du ménage | script + méta | risque probable |
| [SUR-03](SUR-03.md) | Variance estimée sans le plan de sondage (strates, grappes) ou plan sans grappe | script | risque probable, à justifier |
| [SUR-04](SUR-04.md) | Poids invalides (manquants, négatifs, nuls, dispersion extrême) | data + méta | certitude, à justifier |
| [LVL-01](LVL-01.md) | Désagrégation artificielle d'une valeur de niveau supérieur | data + méta | certitude |
| [LVL-02](LVL-02.md) | Moyenne simple d'unités agrégées | script + méta | risque probable |
| [LVL-03](LVL-03.md) | Clé censée être unique présente en double | data + méta | certitude |
| [NUM-01](NUM-01.md) | Proportion ou taux hors bornes, échelles mélangées | data + méta | certitude, risque probable |
| [NUM-02](NUM-02.md) | Parts ou sous-totaux qui ne somment pas au total attendu | data + méta | certitude |
| [NUM-03](NUM-03.md) | Ordre des indices FGT violé (FGT2 <= FGT1 <= FGT0) | data + méta | certitude |
| [NUM-04](NUM-04.md) | Codes de valeurs manquantes traités comme des valeurs | data | risque probable |
| [VAL-01](VAL-01.md) | Validation croisée aléatoire alors que les observations sont groupées | script + méta | risque probable |
| [VAL-02](VAL-02.md) | Transformation apprise sur l'ensemble des données avant la séparation | script | risque probable |
| [VAL-03](VAL-03.md) | Performance calculée sur les données d'apprentissage | script + méta | risque probable |
| [VAL-04](VAL-04.md) | Jeu de test utilisé pour choisir les hyperparamètres ou le modèle | script + méta | risque probable |
| [VAL-05](VAL-05.md) | Prédicteur quasi déterministe de la cible | data + méta | risque probable |
| [VAL-06](VAL-06.md) | Validation aléatoire sur des données ordonnées dans le temps | script + méta | risque probable |
| [ECO-01](ECO-01.md) | Erreurs standards non robustes à la structure de grappes | script + méta | risque probable |
| [ECO-02](ECO-02.md) | Double différence à effets fixes bidirectionnels avec adoption échelonnée | data + script + méta | risque probable |
| [ECO-03](ECO-03.md) | Double différence sans examen des tendances pré-traitement | script + méta | à justifier |
| [ECO-04](ECO-04.md) | Instrument faible : statistique F de première étape sous le seuil indicatif | data + méta | risque probable |
| [ECO-05](ECO-05.md) | Discontinuité de régression : accumulation au seuil ou absence de test de manipulation | data + méta | risque probable, à justifier |
| [SER-01](SER-01.md) | Test de racine unitaire appliqué aux résidus d'une régression de niveaux (valeurs critiques inadaptées) | script | risque probable |
| [EXT-01](EXT-01.md) | Écart non expliqué avec une valeur de référence déclarée | méta | à justifier |
| [EXT-02](EXT-02.md) | Ligne de pauvreté, année, unité ou période incohérentes avec l'agrégat de bien-être déclaré | méta | risque probable |
| [REP-01](REP-01.md) | Chemin absolu propre à une machine, ou fichier d'entrée introuvable | script | certitude, risque probable |
| [REP-02](REP-02.md) | Procédure stochastique sans graine aléatoire | script | certitude, risque probable |
| [REP-03](REP-03.md) | Environnement logiciel non documenté (ni renv.lock, ni Dockerfile, ni sessionInfo) | project_dir | à justifier |
| [REP-04](REP-04.md) | Fonction d'un paquet appelée sans que le paquet soit chargé | script | risque probable |
| [DOC-01](DOC-01.md) | Chiffre du texte différent de celui de la sortie qui l'a produit | document + méta | certitude, à justifier |
| [DOC-02](DOC-02.md) | Indicateur chiffré de deux façons, ou sans niveau géographique ni période | document + méta | risque probable, à justifier |
| [DOC-03](DOC-03.md) | Langage causal sans design d'identification déclaré | document + méta | à justifier |
| [DEM-01](DEM-01.md) | Préférence pour les âges se terminant par 0 ou 5 (indice de Whipple) | data + méta | à justifier |
| [DEM-02](DEM-02.md) | Équation compensatrice non respectée | data + méta | certitude |
| [DEM-03](DEM-03.md) | Table de mortalité incohérente (qx hors de [0 ; 1], lx croissant) | data + méta | certitude |
| [DEM-04](DEM-04.md) | Rapport de masculinité hors d'une plage plausible | data + méta | à justifier |
