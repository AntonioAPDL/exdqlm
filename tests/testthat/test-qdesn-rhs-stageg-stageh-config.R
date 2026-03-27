test_that("rhs Stage-G/H manifest and profile matrix are well formed", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageG_H_manifest.yaml")
  profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageG_profiles.yaml")
  target_grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageG_target_grid.csv")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(target_grid_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest))
  expect_true(is.list(manifest$inputs))
  expect_true(is.character(manifest$inputs$base_defaults))
  expect_true(is.character(manifest$inputs$profiles))
  expect_true(is.character(manifest$inputs$target_grid))
  expect_true(is.character(manifest$inputs$broader_grid))
  expect_true(is.list(manifest$stage_g))
  expect_true(is.character(manifest$stage_g$baseline_profile_id))
  expect_true(is.list(manifest$stage_g$strict_gate))
  expect_true(isTRUE(manifest$stage_g$strict_gate$require_zero_fail))
  expect_true(isTRUE(manifest$stage_g$strict_gate$require_eligible_true))
  expect_true(isTRUE(manifest$stage_g$strict_gate$require_non_degraded_finite_domain))
  expect_true(isTRUE(manifest$stage_g$strict_gate$require_improved_geweke_half_drift))
  expect_true(is.list(manifest$stage_h))
  expect_true(isTRUE(manifest$stage_h$require_zero_fail))
  expect_true(isTRUE(manifest$stage_h$require_all_eligible))
  expect_true(isTRUE(manifest$stage_h$require_all_finite_domain))

  profiles <- yaml::read_yaml(profiles_path)
  expect_true(is.list(profiles))
  expect_true(is.list(profiles$base_patch))
  expect_true(is.list(profiles$profiles))
  expect_equal(length(profiles$profiles), 5L)
  ids <- vapply(profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  expect_setequal(
    ids,
    c("G0_baseline", "G1_transformed_block_only", "G2_adaptation_only", "G3_multistart_only", "G4_combined")
  )

  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageG_stageH_wave.R")
  expect_true(file.exists(script_path))
  script_lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("--reuse-stageg-table", script_lines, fixed = TRUE)))
  expect_true(any(grepl("--reuse-stageg-trace", script_lines, fixed = TRUE)))
})
