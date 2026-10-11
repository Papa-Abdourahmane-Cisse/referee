test_that("le catalogue YAML et le registre du code contiennent les mêmes règles", {
  skip_si_pas_utf8()
  skip_if_not_installed("yaml")
  chemin <- system.file("catalogue", "rules.yml", package = "referee")
  expect_true(nzchar(chemin))
  catalogue <- yaml::read_yaml(chemin)
  ids_yaml <- vapply(catalogue, function(r) r$id, character(1))
  expect_setequal(ids_yaml, rule_ids())
  expect_false(anyDuplicated(ids_yaml) > 0L)
})

test_that("chaque entrée du catalogue est cohérente avec son identifiant", {
  skip_si_pas_utf8()
  skip_if_not_installed("yaml")
  catalogue <- yaml::read_yaml(system.file("catalogue", "rules.yml",
                                           package = "referee"))
  for (r in catalogue) {
    expect_equal(sub("-.*$", "", r$id), r$famille)
    expect_true(all(unlist(r$confiance) %in% SEVERITIES))
  }
})

test_that("les identifiants du registre sont uniques et bien formés", {
  ids <- rule_ids()
  expect_false(anyDuplicated(ids) > 0L)
  expect_true(all(grepl("^[A-Z]{3}-[0-9]{2}$", ids)))
})
