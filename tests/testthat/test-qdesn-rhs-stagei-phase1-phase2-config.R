test_that("Stage-I manifest and profile configs are well formed", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageI_manifest.yaml")
  phase1_profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageI_phase1_profiles.yaml")
  phase2_profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageI_phase2_profiles.yaml")
  blocker_grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageI_blocker_grid.csv")
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageI_phase1_phase2_wave.R")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(phase1_profiles_path))
  expect_true(file.exists(phase2_profiles_path))
  expect_true(file.exists(blocker_grid_path))
  expect_true(file.exists(script_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest$inputs))
  expect_true(is.character(manifest$inputs$base_defaults))
  expect_true(is.character(manifest$inputs$blocker_grid))
  expect_true(is.list(manifest$baseline_patch))
  expect_true(is.list(manifest$phase1))
  expect_true(is.list(manifest$phase2))
  expect_true(is.character(manifest$phase1$profiles))
  expect_true(is.character(manifest$phase2$profiles))
  expect_true(is.list(manifest$phase1$strict_gate))
  expect_true(is.list(manifest$phase2$strict_gate))
  expect_true(isTRUE(manifest$phase1$strict_gate$require_zero_fail))
  expect_true(isTRUE(manifest$phase2$strict_gate$require_improved_vs_baseline))

  phase1_profiles <- yaml::read_yaml(phase1_profiles_path)
  phase2_profiles <- yaml::read_yaml(phase2_profiles_path)
  expect_true(is.list(phase1_profiles$profiles))
  expect_true(is.list(phase2_profiles$profiles))
  expect_equal(length(phase1_profiles$profiles), 3L)
  expect_equal(length(phase2_profiles$profiles), 4L)

  phase1_ids <- vapply(phase1_profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  phase2_ids <- vapply(phase2_profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  expect_setequal(
    phase1_ids,
    c("P1_baseline", "P1_chain_2200_4400", "P1_chain_3200_6400_burn45")
  )
  expect_setequal(
    phase2_ids,
    c("P2_baseline_from_phase1", "P2_core_extra_passes", "P2_rhs_transformed_block", "P2_combined_core_and_transformed")
  )

  blocker_grid <- utils::read.csv(blocker_grid_path, stringsAsFactors = FALSE)
  expect_true(nrow(blocker_grid) >= 1L)
  expect_true(all(blocker_grid$beta_prior_type == "rhs"))
  expect_true(all(blocker_grid$enabled))
})
