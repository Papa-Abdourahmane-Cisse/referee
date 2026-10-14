# Fonctions d'entrée pour l'utilisateur ---------------------------------------

#' Auditer un script R en une commande
#'
#' Raccourci de [audit()] pour un script seul : les métadonnées que le script
#' déclare déjà (variable de poids, grappes, strates, table d'enquête dans
#' `svydesign()`) sont lues automatiquement, voir [infer_meta()]. Les règles
#' qui ont besoin de données ou de métadonnées supplémentaires sont rapportées
#' « non évaluées » avec la raison.
#'
#' @param script Chemin du script R.
#' @param meta Métadonnées facultatives, voir [referee_meta()] ; elles ont la
#'   priorité sur celles inférées.
#' @param project_dir Racine du projet, ou `NULL`.
#' @return Un objet de classe `referee_report`.
#' @examples
#' exemple <- system.file("examples", "enquete_fautive.R", package = "referee")
#' audit_script(exemple)
#' @export
audit_script <- function(script, meta = referee_meta(), project_dir = NULL) {
  audit(script = script, meta = meta, project_dir = project_dir, infer = TRUE)
}

#' Afficher la fiche d'une règle
#'
#' Affiche la fiche de la règle : ce qu'elle détecte, pourquoi, que faire en
#' cas d'alerte, ses limites et un exemple d'utilisation.
#'
#' @param id Identifiant de la règle, par exemple `"SUR-01"`.
#' @return Le texte de la fiche, de manière invisible.
#' @examples
#' explain_rule("SUR-01")
#' @export
explain_rule <- function(id) {
  if (!is.character(id) || length(id) != 1L || !id %in% rule_ids()) {
    stop("`id` doit \u00eatre un identifiant de r\u00e8gle : voir `rule_ids()`.",
         call. = FALSE)
  }
  path <- system.file("regles", paste0(id, ".md"), package = "referee")
  if (!nzchar(path)) {
    stop("Fiche introuvable pour ", id, ".", call. = FALSE)
  }
  txt <- readLines(path, encoding = "UTF-8")
  writeLines(txt)
  invisible(txt)
}
