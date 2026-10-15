# Références

Les fiches de règles (`docs/regles/`) ne citent aucune référence
bibliographique. Cette page liste celles qui fondent les règles et le statut
de leur vérification. **Une entrée « à vérifier » ne doit pas être citée
telle quelle.**

Niveaux de vérification :

- **vérifiée (Crossref)** : titre, auteurs, année, revue et DOI lus dans la base
  Crossref (14 octobre 2026).
- **corroborée** : l'existence et la référence de la publication ressortent d'une
  recherche web (page de l'éditeur ou fiche IDEAS/RePEc), sans lecture du DOI.
  À contrôler par le DOI avant toute citation.
- **à vérifier** : non retrouvée, ou retrouvée seulement sous une autre forme
  (document de travail).

Une requête a pu échouer (limite de débit, résultat hors sujet) : l'échec ne
dit rien de l'existence de la référence.

| Règle(s) | Référence | Statut |
|---|---|---|
| NUM-03 | Foster, J., Greer, J., Thorbecke, E. (1984). A class of decomposable poverty measures. *Econometrica*. DOI 10.2307/1913475 | **vérifiée** (Crossref) |
| VAL-02, VAL-05 | Kaufman, S., Rosset, S., Perlich, C. (2011). Leakage in data mining. *Proceedings of the 17th ACM SIGKDD*. DOI 10.1145/2020408.2020496 | **vérifiée** (Crossref) pour la version de congrès ; une version de revue (*ACM TKDD*, 2012) est possible, non vérifiée |
| ECO-02 | Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing. *Journal of Econometrics*, 225(2), 254-277 | **corroborée** (fiche IDEAS ; document de travail NBER w25018 confirmé par Crossref, DOI 10.3386/w25018) |
| ECO-01 | Bertrand, M., Duflo, E., Mullainathan, S. (2004). How much should we trust differences-in-differences estimates? *Quarterly Journal of Economics*, 119(1), 249-275 | **corroborée** (fiche IDEAS ; document de travail NBER w8841) |
| SUR-01 | Solon, G., Haider, S. J., Wooldridge, J. M. (2015). What are we weighting for? *Journal of Human Resources*, 50(2), 301-316 | **corroborée** (page de l'éditeur pour le volume et le numéro ; pages à contrôler) |
| VAL-01, VAL-06 | Roberts, D. R. et al. (2017). Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure. *Ecography*. DOI 10.1111/ecog.02881 | **corroborée** (DOI apparu dans les résultats ; volume et pages à contrôler) |
| ECO-01 | Abadie, A., Athey, S., Imbens, G., Wooldridge, J. When should you adjust standard errors for clustering? | document de travail NBER w24003 (2017) confirmé par Crossref ; la publication en revue (*Quarterly Journal of Economics*, 2023) est **à vérifier** |
| ECO-05 | McCrary, J. Manipulation of the running variable in the regression discontinuity design: a density test. | document technique NBER t0334 (2007) confirmé par Crossref ; la publication en revue (*Journal of Econometrics*, 2008) est **à vérifier** |
| ECO-02, ECO-03 | Callaway, B., Sant'Anna, P. H. C. Difference-in-differences with multiple time periods (*Journal of Econometrics*, 2021) | **à vérifier** (la citation officielle du paquet R `did` existe ; volume, pages et DOI non lus) |
| ECO-04 | Stock, J., Yogo, M. Testing for weak instruments in linear IV regression (2005) | **à vérifier** (non recherchée) |
| DEM-01 à 04 | références de démographie (indice de Whipple, équation compensatrice, tables de mortalité, rapport de masculinité) | **à compléter avec un démographe** |
| SER-01 | Engle, R. F., Granger, C. W. J. (1987). Co-integration and error correction: representation, estimation, and testing. *Econometrica*, 55(2), 251-276 | **à vérifier** (non retrouvée dans cette session) |
| SER-01 | MacKinnon, J. G. (1996). Numerical distribution functions for unit root and cointegration tests. *Journal of Applied Econometrics*, 11(6), 601-618 ; MacKinnon, J. G. (2010). Critical values for cointegration tests. Queen's Economics Department Working Paper No. 1227 | **à vérifier** (non retrouvées) ; l'idée que les valeurs critiques d'Engle-Granger sont tabulées pour une étape 2 sans termes déterministes ressort d'une documentation tierce (statspai), non d'une lecture du texte de MacKinnon |
| SER-01 | Phillips, P. C. B., Ouliaris, S. (1990). Asymptotic properties of residual based tests for cointegration. *Econometrica*, 58(1), 165-193 ; Shin, Y. (1994). A residual-based test of the null of cointegration against the alternative of no cointegration. *Econometric Theory*, 10(1), 91-115 | **à vérifier** (non retrouvées) |
| REP-04 | Champ `Depends` de `vars` 1.6-1 (MASS, strucchange, urca, lmtest, sandwich) et de `strucchange` 1.6-0 (zoo, sandwich), pages CRAN consultées le 15 octobre 2026 | **vérifiée** (pages CRAN) pour ces deux paquets seulement ; les autres lignes de la table `ATTACH_CASCADE` ne sont pas vérifiées une à une |

Les seuils conventionnels (F > 10, rapport maximum/médiane des poids de 100,
plage de masculinité de 80 à 120, etc.) sont des conventions de pratique, pas
des résultats établis : ils sont paramétrables et décrits comme tels dans les
fiches.
