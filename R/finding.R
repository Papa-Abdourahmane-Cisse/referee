# Constats : unité de sortie de toutes les règles ---------------------------

# Niveaux de confiance, dans l'ordre d'affichage (voir le catalogue v0).
SEVERITIES <- c("certitude", "risque_probable", "a_justifier")

SEVERITY_LABELS <- c(
  certitude = "Certitude",
  risque_probable = "Risque probable",
  a_justifier = "\u00c0 justifier"
)

# Crée un constat. Une règle renvoie une liste de constats (vide si aucune
# alerte). `location` désigne la variable, la ligne de code ou le fichier
# concerné ; `details` garde les valeurs chiffrées utiles à l'audit.
new_finding <- function(rule_id, severity, message,
                        location = NA_character_, details = list()) {
  if (!is.character(rule_id) || length(rule_id) != 1L) {
    stop("`rule_id` doit \u00eatre une cha\u00eene de longueur 1.", call. = FALSE)
  }
  if (!is.character(severity) || length(severity) != 1L ||
        !severity %in% SEVERITIES) {
    stop("`severity` doit \u00eatre l'une des valeurs : ",
         paste(SEVERITIES, collapse = ", "), ".", call. = FALSE)
  }
  structure(
    list(rule_id = rule_id, severity = severity, message = message,
         location = as.character(location), details = details),
    class = "referee_finding"
  )
}

# Formate un nombre avec la virgule décimale (convention francophone).
fr_num <- function(x, digits = 6) {
  format(signif(x, digits), decimal.mark = ",", trim = TRUE,
         scientific = FALSE)
}

# Marque le résultat d'une règle qui n'a pas pu être évaluée (données
# insuffisantes, par exemple). Le runner l'affiche : une règle non évaluée
# n'est jamais comptée comme une règle passée sans alerte.
not_evaluated <- function(reason) {
  structure(list(), not_evaluated = reason)
}

#' @export
print.referee_finding <- function(x, ...) {
  loc <- if (is.na(x$location)) "" else paste0(" [", x$location, "]")
  cat(sprintf("%s (%s)%s\n  %s\n", x$rule_id,
              SEVERITY_LABELS[[x$severity]], loc, x$message))
  invisible(x)
}
