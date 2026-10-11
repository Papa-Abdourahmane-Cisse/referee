# Famille LVL : niveaux d'analyse ------------------------------------------

#' LVL-01 : désagrégation artificielle
#'
#' Pour chaque variable de `vars`, vérifie si elle est constante au sein de
#' chaque unité de `group` alors qu'elle varie entre unités : c'est la
#' signature d'une valeur de niveau supérieur dupliquée sur des unités plus
#' fines (une valeur régionale répétée sur les communes, par exemple).
#'
#' Le constat est certain (les valeurs sont identiques), sa gravité ne l'est
#' pas : une variable contextuelle régionale utilisée comme prédicteur est
#' défendable, la même variable utilisée comme cible ne l'est pas. L'égalité
#' est exacte : une valeur dupliquée puis arrondie différemment n'est pas vue.
#'
#' @param data Data frame.
#' @param group Nom de la variable de niveau supérieur.
#' @param vars Variables à examiner.
#' @param min_group_size Taille minimale d'un groupe pour qu'il soit examiné.
#' @param min_groups Nombre minimal de groupes examinables.
#' @return Liste de constats (confiance : certitude), ou une règle non
#'   évaluée si aucune variable n'a pu être examinée.
#' @export
lvl01_artificial_disaggregation <- function(data, group, vars,
                                            min_group_size = 2L,
                                            min_groups = 2L) {
  g <- data[[group]]
  out <- list()
  evaluated <- 0L
  for (v in vars) {
    x <- data[[v]]
    ok <- !is.na(x) & !is.na(g)
    groups <- split(which(ok), g[ok])
    eligible <- groups[lengths(groups) >= min_group_size]
    if (length(eligible) < min_groups) next
    evaluated <- evaluated + 1L
    constant <- vapply(eligible, function(i) length(unique(x[i])) == 1L,
                       logical(1))
    varies_between <- length(unique(x[ok])) > 1L
    if (all(constant) && varies_between) {
      out[[length(out) + 1L]] <- new_finding(
        "LVL-01", "certitude",
        sprintf(paste0("`%s` est constante au sein de chacun des %d groupes ",
                       "de `%s` examin\u00e9s alors qu'elle varie entre groupes : ",
                       "valeur de niveau sup\u00e9rieur dupliqu\u00e9e sur des unit\u00e9s ",
                       "plus fines. Acceptable comme pr\u00e9dicteur contextuel, ",
                       "pas comme cible."),
                v, length(eligible), group),
        location = v,
        details = list(groups = length(eligible))
      )
    }
  }
  if (evaluated == 0L) {
    return(not_evaluated(sprintf(
      "aucune variable n'a au moins %d groupes de `%s` d'au moins %d observations",
      min_groups, group, min_group_size)))
  }
  out
}

#' LVL-02 : moyenne simple d'unités agrégées
#'
#' Signale `mean()` appelée sur une variable déclarée comme agrégée (un taux
#' communal, par exemple). Si le résultat est présenté comme valeur d'un
#' niveau supérieur, il faut pondérer par la population de chaque unité.
#'
#' @param script Objet issu de [parse_script()].
#' @param aggregated_vars Noms des variables déjà agrégées.
#' @return Liste de constats (confiance : risque probable).
#' @export
lvl02_unweighted_mean_of_aggregates <- function(script, aggregated_vars) {
  out <- list()
  for (rec in collect_calls(script)) {
    if (!identical(rec$name, "mean")) next
    hit <- intersect(aggregated_vars, expr_tokens(rec$call))
    if (length(hit) == 0L) next
    out[[length(out) + 1L]] <- new_finding(
      "LVL-02", "risque_probable",
      sprintf(paste0("Moyenne simple de `%s`, variable d\u00e9j\u00e0 agr\u00e9g\u00e9e. Si le ",
                     "r\u00e9sultat est pr\u00e9sent\u00e9 comme valeur du niveau sup\u00e9rieur ",
                     "(r\u00e9gional, national), une moyenne pond\u00e9r\u00e9e par la ",
                     "population est n\u00e9cessaire."), paste(hit, collapse = ", ")),
      location = call_location(rec)
    )
  }
  out
}

#' LVL-03 : unités dupliquées
#'
#' Une clé censée identifier une unité de manière unique apparaît plusieurs
#' fois. Seul le constat sur les données est couvert ici : l'augmentation du
#' nombre de lignes après une jointure suppose de comparer deux états de la
#' base, ce que la règle ne fait pas.
#'
#' @param data Data frame.
#' @param key Nom(s) de la ou des colonnes qui forment la clé.
#' @return Liste de constats (confiance : certitude).
#' @export
lvl03_duplicate_keys <- function(data, key) {
  keys <- data[key]
  dup <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  n_rows <- sum(dup)
  if (n_rows == 0L) {
    return(list())
  }
  distinct <- unique(keys[dup, , drop = FALSE])
  example <- utils::head(distinct, 3L)
  example_txt <- paste(
    apply(example, 1L, function(r) paste(trimws(r), collapse = "/")),
    collapse = ", ")
  list(new_finding(
    "LVL-03", "certitude",
    sprintf(paste0("%d ligne(s) partagent une cl\u00e9 dupliqu\u00e9e (%d cl\u00e9(s) ",
                   "distincte(s), par exemple : %s)."),
            n_rows, nrow(distinct), example_txt),
    location = paste(key, collapse = ", "),
    details = list(rows = n_rows, keys = nrow(distinct))
  ))
}
