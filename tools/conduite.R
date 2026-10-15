# Conduite à tenir et exemple d'erreur, par règle. Texte rédigé à la main :
# le reste de la fiche est généré depuis le code et le catalogue.
conduite <- list(
  "SUR-01" = list(
    pourquoi = "Une enquête par sondage sur-représente ou sous-représente certaines unités ; une moyenne non pondérée estime la population de l'échantillon, pas celle du pays. Le biais dépend de la corrélation entre le poids et la variable étudiée.",
    conduite = "Si la table est une enquête : utiliser `survey::svymean()`, `weighted.mean()` ou `srvyr::summarise()` sur un plan déclaré. Si la moyenne non pondérée est voulue (contrôle de qualité de l'échantillon, par exemple), la libeller comme telle. Si la table n'est pas une enquête (recensement, table agrégée), déclarer `data_objects` pour que la règle ne l'examine pas.",
    exemple = "mean(enq$emploi)   # alerte\nsurvey::svymean(~emploi, plan)   # correct"),
  "SUR-02" = list(
    pourquoi = "Dans plusieurs enquêtes ménages, le poids individuel s'obtient en multipliant le poids du ménage par sa taille. Le diviser par la taille donne des effectifs et des taux faux pour les indicateurs individuels.",
    conduite = "Consulter la documentation de l'enquête pour la convention exacte du poids. La règle alerte sur la division `poids / taille` ; elle ne dit pas que la convention de votre enquête est l'inverse.",
    exemple = "poids_ind <- poids_men / taille_men   # alerte"),
  "SUR-03" = list(
    pourquoi = "Les erreurs standards d'un tirage en grappes ou stratifié diffèrent de celles d'un tirage aléatoire simple. Ignorer les grappes sous-estime en général la variance, donc surestime la précision et le nombre de résultats « significatifs ». Un plan construit avec `ids = ~1` traite chaque unité comme indépendante.",
    conduite = "Déclarer les grappes et les strates dans `svydesign(ids = ~grappe, strata = ~strate, ...)`. Si le tirage est réellement sans grappe, ou si les grappes ne figurent pas dans la base publiée, le justifier dans le texte (avec une mention de l'effet de plan attendu).",
    exemple = "svydesign(ids = ~1, weights = ~poids, data = d)   # alerte (à justifier)\nsvydesign(ids = ~grappe, strata = ~strate, weights = ~poids, data = d, nest = TRUE)"),
  "SUR-04" = list(
    pourquoi = "Des poids manquants, négatifs ou infinis rendent les estimations pondérées indéfinies ou fausses ; des poids très dispersés rendent les estimations instables (effet de plan élevé).",
    conduite = "Rechercher l'origine des poids invalides (jointure incomplète, calage non fait). Pour la dispersion, comparer à la distribution des poids de la documentation de l'enquête et examiner l'effet sur l'estimation (avec/sans troncature).",
    exemple = "summary(d$poids)   # contrôler min, max, NA"),
  "LVL-01" = list(
    pourquoi = "Une valeur régionale répétée sur des communes n'est pas une observation communale indépendante : la taille d'échantillon apparente est surestimée et un modèle peut « apprendre » la région plutôt que la commune.",
    conduite = "Distinguer la variable utilisée comme prédicteur contextuel (défendable, avec erreurs standards groupées au niveau régional) de la variable utilisée comme cible (à éviter). Documenter l'hypothèse de désagrégation.",
    exemple = "# taux_region identique pour toutes les communes d'une région : alerte"),
  "LVL-02" = list(
    pourquoi = "La moyenne simple de taux communaux n'est pas le taux du niveau supérieur : elle donne le même poids à une commune de 500 et à une commune de 500 000 habitants.",
    conduite = "Pondérer par la population de chaque commune, ou recalculer le taux à partir des effectifs agrégés (numérateurs et dénominateurs).",
    exemple = "mean(communes$taux)   # alerte\nweighted.mean(communes$taux, communes$pop)"),
  "LVL-03" = list(
    pourquoi = "Une clé en double dans une base censée avoir une ligne par unité fausse les effectifs, les moyennes et les jointures.",
    conduite = "Identifier les doublons (`duplicated()`), déterminer s'il s'agit d'une saisie répétée ou d'une clé mal définie, et corriger avant toute estimation.",
    exemple = "d[duplicated(d$id) | duplicated(d$id, fromLast = TRUE), ]"),
  "NUM-01" = list(
    pourquoi = "Une proportion hors de [0 ; 1] ou un pourcentage hors de [0 ; 100] est impossible ; des échelles mélangées dans une même colonne rendent toute moyenne ininterprétable.",
    conduite = "Retrouver l'origine des valeurs (saisie, conversion) et homogénéiser l'échelle. Pour le mélange probable (`auto`), vérifier dans la documentation si la colonne est en pourcentage ou en proportion.",
    exemple = "range(d$taux, na.rm = TRUE)"),
  "NUM-02" = list(
    pourquoi = "Des parts qui ne somment pas à 100 % (ou au total déclaré) signalent une catégorie manquante, un doublon ou une erreur de calcul.",
    conduite = "Vérifier les catégories omises et la tolérance d'arrondi (`tol`) ; corriger la source de l'écart.",
    exemple = "rowSums(d[, c('part_a', 'part_b', 'part_c')])"),
  "NUM-03" = list(
    pourquoi = "Pour tout seuil, FGT2 ≤ FGT1 ≤ FGT0 : le carré de l'écart relatif normalisé est inférieur à l'écart, lui-même inférieur à l'indicatrice de pauvreté. Une violation est une erreur de calcul.",
    conduite = "Contrôler la formule des indices (valeur de α, traitement des non-pauvres, normalisation par la ligne de pauvreté) et l'ordre des colonnes déclarées.",
    exemple = "all(d$fgt2 <= d$fgt1 & d$fgt1 <= d$fgt0)"),
  "NUM-04" = list(
    pourquoi = "Un code comme 99 ou 9999 traité comme une valeur fausse moyennes, variances et régressions.",
    conduite = "Consulter le questionnaire et le dictionnaire de variables ; recoder en `NA` les codes de non-réponse avant calcul. Un code qui est une valeur réelle (âge 99) se justifie.",
    exemple = "d$age[d$age == 99] <- NA   # si 99 est un code de non-réponse"),
  "VAL-01" = list(
    pourquoi = "Quand des observations d'un même groupe (région, grappe) sont corrélées, un découpage aléatoire place des voisines dans l'apprentissage et le test : la performance mesurée est optimiste pour la prédiction de nouveaux groupes.",
    conduite = "Utiliser un découpage groupé (`group_vfold_cv()`, `spatial_block_cv()`) si le modèle doit prédire pour des groupes non vus, et comparer avec le découpage aléatoire pour mesurer l'écart.",
    exemple = "vfold_cv(d, v = 5)   # alerte\ngroup_vfold_cv(d, group = region, v = 5)"),
  "VAL-02" = list(
    pourquoi = "Une transformation dont les paramètres sont appris (moyenne et écart-type d'une standardisation, ACP, imputation) avant le découpage transmet de l'information du jeu de test au jeu d'apprentissage (fuite d'information).",
    conduite = "Apprendre la transformation sur l'apprentissage seulement, à l'intérieur de chaque pli de validation (`recipes`, `caret::preProcess` dans `train`, pipeline `sklearn`).",
    exemple = "d$x <- scale(d$x); initial_split(d)   # alerte\ninitial_split(d); recipe(...) %>% step_normalize(x)"),
  "VAL-03" = list(
    pourquoi = "La performance sur les données qui ont servi à ajuster le modèle mesure la capacité d'ajustement, pas de prédiction.",
    conduite = "Rapporter la performance de validation croisée ou sur un test indépendant ; si la performance d'apprentissage est donnée, la présenter comme telle, à côté de la précédente.",
    exemple = "rmse(train$y, predict(m, train))   # alerte (si rien sur le test)"),
  "VAL-04" = list(
    pourquoi = "Choisir hyperparamètres ou modèle d'après le test rend la performance finale optimiste : le test a participé à la sélection.",
    conduite = "Réserver le test à l'évaluation finale ; régler par validation croisée dans l'apprentissage.",
    exemple = "tune_grid(wf, resamples = vfold_cv(test))   # alerte"),
  "VAL-05" = list(
    pourquoi = "Une variable presque parfaitement corrélée à la cible est souvent dérivée de la cible ou issue de la même source : elle ne sera pas disponible au moment de la prédiction.",
    conduite = "Déterminer l'origine de la variable ; l'exclure si elle contient l'information de la cible, la conserver et le justifier si elle est une cause légitime très prédictive.",
    exemple = "cor(d$x, d$y)   # |r| proche de 1 : examiner"),
  "VAL-06" = list(
    pourquoi = "Un découpage aléatoire d'une série temporelle utilise le futur pour prédire le passé : la performance est optimiste pour une prévision réelle.",
    conduite = "Utiliser un découpage temporel (`rolling_origin()`, `initial_time_split()`, `createTimeSlices()`).",
    exemple = "initial_split(d)   # alerte\ninitial_time_split(d)"),
  "ECO-01" = list(
    pourquoi = "Les erreurs d'observations corrélées au sein d'une grappe (village, individu suivi dans le temps) sous-estiment la variance si elles sont traitées comme indépendantes.",
    conduite = "Regrouper les erreurs standards au niveau où le traitement est assigné ou échantillonné (`vcovCL()`, `lm_robust(clusters = )`, `feols(cluster = )`) ; justifier le niveau de regroupement. Note : la règle n'examine pas `feols()` ni `felm()`, et le traitement par défaut des erreurs standards de `feols()` dépend de la version de `fixest` : déclarer explicitement `vcov = ~village` plutôt que de s'en remettre au défaut.",
    exemple = "lm(y ~ x, data = d)   # alerte\nestimatr::lm_robust(y ~ x, data = d, clusters = village)"),
  "ECO-02" = list(
    pourquoi = "Avec adoption échelonnée du traitement et effets hétérogènes, l'estimateur à effets fixes bidirectionnels combine des comparaisons dont certaines utilisent des unités déjà traitées comme contrôle, et peut être biaisé, y compris de signe inverse.",
    conduite = "Utiliser un estimateur robuste à l'hétérogénéité (`did::att_gt()`, `did2s`, `sunab()`, `did_imputation`) et présenter l'étude d'événement.",
    exemple = "feols(y ~ traite | unite + annee, data = d)   # alerte si adoption échelonnée"),
  "ECO-03" = list(
    pourquoi = "L'hypothèse de tendances parallèles ne se prouve pas, mais son examen sur les périodes pré-traitement est la pratique attendue.",
    conduite = "Présenter une étude d'événement avec leads et lags (`i(temps_relatif, traite, ref = -1)`), et envisager une analyse de sensibilité (`HonestDiD`).",
    exemple = "feols(y ~ i(t_rel, traite, ref = -1) | unite + annee, data = d)"),
  "ECO-04" = list(
    pourquoi = "Un instrument faiblement corrélé au régresseur endogène produit un estimateur biaisé vers MCO et des tests déformés.",
    conduite = "Rapporter le F de première étape adapté à la structure d'erreurs (F robuste ou F effectif en cas d'hétéroscédasticité ou de grappes) et des intervalles de confiance robustes à un instrument faible (Anderson-Rubin).",
    exemple = "# F de première étape inférieur au seuil indicatif : alerte"),
  "ECO-05" = list(
    pourquoi = "Si des unités peuvent manipuler leur score autour du seuil, l'hypothèse d'assignation quasi aléatoire de la discontinuité tombe.",
    conduite = "Réaliser le test de densité dédié (`rddensity::rddensity()`), examiner l'histogramme du score et justifier l'absence de manipulation par les institutions.",
    exemple = "rddensity::rddensity(X = d$score, c = seuil)"),
  "EXT-01" = list(
    pourquoi = "Un écart avec une valeur officielle publiée peut venir d'une différence de définition, de période, de population, de seuil, de pondération ou de méthode ; il peut aussi venir d'une erreur. La statistique officielle n'est pas automatiquement la bonne.",
    conduite = "Passer en revue les causes listées par le rapport, en commençant par l'échelle (proportion ou pourcentage) et la pondération, puis documenter l'écart résiduel.",
    exemple = "referee_meta(weights = 'poids', references = list(list(name = 'taux emploi', reference = 0.42, tol = 0.02, var = 'emploi')))"),
  "EXT-02" = list(
    pourquoi = "Comparer une ligne de pauvreté et un agrégat de consommation qui n'ont pas la même année de prix, la même unité (par tête, par équivalent adulte) ou la même période (jour, an) donne un taux de pauvreté faux.",
    conduite = "Harmoniser l'année (déflateur), l'unité et la période, ou justifier la correspondance dans la méthodologie.",
    exemple = "referee_meta(poverty = list(line_year = 2018, welfare_year = 2021, price_adjusted = FALSE))"),
  "REP-01" = list(
    pourquoi = "Un chemin absolu (`C:/Users/...`) ne fonctionne que sur la machine de l'auteur : le script n'est pas reproductible par un tiers.",
    conduite = "Utiliser des chemins relatifs à la racine du projet (`here::here('data', 'a.csv')`, projet RStudio) et regrouper les chemins en tête de script.",
    exemple = "read.csv('C:/Users/moi/a.csv')   # alerte\nread.csv(here::here('data', 'a.csv'))"),
  "REP-02" = list(
    pourquoi = "Sans graine, un échantillonnage, un découpage ou un modèle aléatoire donne des résultats différents à chaque exécution : les chiffres du rapport ne sont pas reproductibles.",
    conduite = "Appeler `set.seed()` en début de script (et par flux pour un calcul parallèle) et noter la graine dans le rapport.",
    exemple = "set.seed(2024)"),
  "REP-03" = list(
    pourquoi = "Sans trace des versions de R et des paquets, les résultats peuvent changer d'une machine ou d'une date à l'autre.",
    conduite = "Verrouiller l'environnement (`renv::init()`, `renv.lock`), ou fournir un `Dockerfile`, ou enregistrer `sessionInfo()`.",
    exemple = "renv::init(); renv::snapshot()"),
  "SER-01" = list(
    pourquoi = "Le test de cointégration d'Engle-Granger applique un test de racine unitaire aux résidus d'une régression de niveaux. Ces résidus sont estimés : leur distribution sous l'hypothèse nulle diffère de celle d'une série observée, et les valeurs critiques usuelles du test de Dickey-Fuller ne conviennent pas. Les p-values affichées ne sont alors pas interprétables comme un test de cointégration.",
    conduite = "Comparer la statistique aux valeurs critiques d'Engle-Granger (MacKinnon), ou utiliser un test conçu pour ce cas (`tseries::po.test()`, `urca::ca.po()`), ou la procédure de Johansen. Vérifier d'abord que les deux séries sont intégrées du même ordre (tests sur les niveaux et sur les différences) et justifier la spécification déterministe. Si la régression n'a pas pour objet la cointégration, écarter le constat.",
    exemple = "reg <- lm(x ~ y)\nadf.test(residuals(reg))   # alerte\ntseries::po.test(cbind(x, y))"),
  "REP-04" = list(
    pourquoi = "Un script qui appelle `ca.jo()` sans charger `urca` s'arrête sur « could not find function » chez un tiers, et parfois chez son auteur dès qu'une session est redémarrée : il dépendait d'un paquet chargé auparavant à la main.",
    conduite = "Charger chaque paquet utilisé en tête de script (`library(urca)`), ou préfixer l'appel (`urca::ca.jo()`). Documenter l'environnement (REP-03).",
    exemple = "ca.jo(d)            # alerte\nlibrary(urca)\nca.jo(d)"),
  "DOC-01" = list(
    pourquoi = "Un chiffre recopié à la main dans le texte peut différer de celui de la sortie après une mise à jour du calcul.",
    conduite = "Générer le texte depuis les sorties (R Markdown, Quarto) ou relire chaque chiffre contre sa source.",
    exemple = "referee_meta(figures = list(list(name = 'taux', value = 37.5, pattern = 'taux de pauvreté')))"),
  "DOC-02" = list(
    pourquoi = "Un même indicateur chiffré de deux façons pour la même population et la même période, ou sans niveau géographique ni période, est ambigu pour le lecteur.",
    conduite = "Conserver une seule valeur de référence par indicateur ; préciser systématiquement le niveau géographique et la période.",
    exemple = "referee_meta(indicators = list(list(name = 'pauvreté', pattern = 'pauvret')), geo_terms = c('national', 'Dakar'))"),
  "DOC-03" = list(
    pourquoi = "Un vocabulaire causal (« l'effet de », « grâce à ») sans design d'identification confond association et causalité.",
    conduite = "Reformuler (« est associé à ») ou déclarer et justifier un design d'identification (expérience, DID, RDD, VI, appariement, contrôle synthétique).",
    exemple = "'L'effet du programme est de +5 points'   # alerte sans design"),
  "DEM-01" = list(
    pourquoi = "L'attraction pour les âges se terminant par 0 ou 5 trahit des déclarations d'âge arrondies, qui faussent pyramides, taux par âge et projections.",
    conduite = "Si l'indice est élevé, utiliser des groupes d'âges quinquennaux ou lisser (méthodes de la littérature démographique) et le signaler. Règle candidate : à faire relire par un démographe.",
    exemple = "referee_meta(age = 'age')"),
  "DEM-02" = list(
    pourquoi = "La population finale doit égaler la population initiale plus les naissances moins les décès plus le solde migratoire ; un écart indique une erreur de saisie, de calcul ou une composante mal estimée.",
    conduite = "Rechercher la composante en cause ; si l'écart est un résidu de mesure légitime, régler la tolérance et le documenter. Règle candidate : à faire relire.",
    exemple = "referee_meta(balance = list(p0 = 'pop0', p1 = 'pop1', births = 'nais', deaths = 'deces'))"),
  "DEM-03" = list(
    pourquoi = "Une probabilité de décès hors de [0 ; 1] ou des survivants qui augmentent avec l'âge sont impossibles dans une table de mortalité.",
    conduite = "Contrôler la saisie, l'ordre des âges et le groupe de table. Règle candidate : à faire relire.",
    exemple = "referee_meta(lifetable = list(age = 'age', qx = 'qx', lx = 'lx'))"),
  "DEM-04" = list(
    pourquoi = "Un rapport de masculinité très éloigné de 100 dans un groupe d'âges peut indiquer une omission sélective au recensement ou à l'enquête, ou un biais de déclaration ; il peut aussi refléter des migrations de travail.",
    conduite = "Justifier ou corriger selon le contexte ; la plage par défaut (80 à 120) est indicative. Règle candidate : à faire relire.",
    exemple = "referee_meta(sexratio = list(group = 'groupe_age', males = 'hommes', females = 'femmes'))")
)
