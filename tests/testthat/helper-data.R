# Données simulées partagées par les tests. Une graine fixe garantit la
# reproductibilité ; aucune donnée réelle n'est utilisée.

make_survey <- function(n_regions = 5L, communes_per_region = 6L, seed = 2026L) {
  set.seed(seed)
  n <- n_regions * communes_per_region
  region <- rep(paste0("R", seq_len(n_regions)), each = communes_per_region)
  commune <- paste0(region, "-C",
                    rep(seq_len(communes_per_region), times = n_regions))
  taux <- runif(n, 0.10, 0.70)
  data.frame(
    commune = commune,
    region = region,
    hhweight = runif(n, 0.5, 3),
    hhsize = sample(2:9, n, replace = TRUE),
    taux_commune = taux,
    # Valeur régionale dupliquée sur les communes de la région.
    taux_region = ave(taux, region),
    stringsAsFactors = FALSE
  )
}

severities <- function(findings) {
  vapply(findings, function(f) f$severity, character(1))
}

# Les messages et le catalogue sont en français : certains tests comparent du
# texte accentué et ne sont pas significatifs dans une locale non UTF-8.
skip_si_pas_utf8 <- function() {
  testthat::skip_if_not(l10n_info()[["UTF-8"]], "locale non UTF-8")
}
