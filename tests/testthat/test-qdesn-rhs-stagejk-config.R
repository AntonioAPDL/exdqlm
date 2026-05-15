test_that("Stage-J/K/L/M manifest and profiles are well formed", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageJ_K_manifest.yaml")
  profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageK_profiles.yaml")
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageJ_K_L_M_wave.R")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(script_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest$inputs))
  expect_true(is.character(manifest$inputs$candidate_defaults))
  expect_true(is.character(manifest$inputs$broader_grid))
  expect_true(is.character(manifest$inputs$stagek_profiles))
  expect_true(is.list(manifest$gates))
  expect_true(is.list(manifest$gates$stageJ))
  expect_true(is.list(manifest$gates$stageK))
  expect_true(is.list(manifest$gates$stageL))
  expect_true(isTRUE(manifest$gates$stageJ$require_zero_fail))
  expect_true(isTRUE(manifest$gates$stageJ$require_all_eligible))
  expect_true(isTRUE(manifest$gates$stageJ$require_all_finite_domain))
  expect_true(isTRUE(manifest$gates$stageJ$require_zero_trace_unavailable))
  expect_true(is.list(manifest$stageM))
  expect_true(length(manifest$stageM$scenario) >= 1L)
  expect_true(length(manifest$stageM$tau) >= 1L)
  expect_true(length(manifest$stageM$seed) >= 1L)
  expect_true(length(manifest$stageM$reservoir_profile) >= 1L)
  expect_true(is.list(manifest$outputs))
  expect_true(is.character(manifest$outputs$promotion_defaults))
  expect_true(is.character(manifest$outputs$stagem_defaults_template))
  expect_true(is.character(manifest$outputs$stagem_grid))
  expect_true(is.character(manifest$outputs$tracker_doc))

  profiles <- yaml::read_yaml(profiles_path)
  expect_true(is.list(profiles$profiles))
  ids <- vapply(profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  expect_setequal(
    ids,
    c(
      "K0_failed_roots_baseline",
      "K1_failed_roots_longer_chain",
      "K2_failed_roots_taufreeze_extended",
      "K3_failed_roots_adapt_longer",
      "K4_failed_roots_taufreeze_plus_adapt"
    )
  )
})
