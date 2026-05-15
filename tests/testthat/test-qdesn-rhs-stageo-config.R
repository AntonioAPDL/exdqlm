test_that("Stage-O manifest, grids, profiles, and runner are well formed", {
  `%||%` <- function(a, b) if (is.null(a)) b else a
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageO_manifest.yaml")
  o1_profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageO_o1_profiles.yaml")
  o2_profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageO_o2_profiles.yaml")
  blocker_grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageO_blocker_grid.csv")
  stress_grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageO_stress6_grid.csv")
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageO_wave.R")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(o1_profiles_path))
  expect_true(file.exists(o2_profiles_path))
  expect_true(file.exists(blocker_grid_path))
  expect_true(file.exists(stress_grid_path))
  expect_true(file.exists(script_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest$meta))
  expect_true(is.character(manifest$meta$tracker_title))
  expect_true(is.character(manifest$meta$stage_label))
  expect_true(is.character(manifest$inputs$base_defaults))
  expect_true(is.character(manifest$inputs$guardrail_lock))
  expect_true(is.character(manifest$inputs$blocker_grid))
  expect_true(is.character(manifest$inputs$stress_grid))
  expect_true(is.character(manifest$inputs$full_grid))
  expect_true(is.character(manifest$inputs$o1_profiles))
  expect_true(is.character(manifest$inputs$o2_profiles))
  expect_true(isTRUE(manifest$gates$o1$require_zero_fail))
  expect_true(isTRUE(manifest$gates$o3$require_all_eligible))
  expect_true(isTRUE(manifest$gates$o4$require_all_finite_domain))
  expect_true(isTRUE(manifest$gates$o4$require_zero_trace_unavailable))
  expect_true(isTRUE(manifest$controls$skip_o2_if_o1_clean))
  expect_true(as.integer(manifest$controls$outer_workers) >= 1L)
  expect_true(as.integer(manifest$controls$profile_workers) >= 1L)
  expect_true(as.integer(manifest$controls$threads_per_worker) >= 1L)
  expect_true(is.character(manifest$outputs$winner_defaults))
  expect_true(is.character(manifest$outputs$promoted_defaults))
  expect_true(is.character(manifest$outputs$tracker_doc))

  o1_profiles <- yaml::read_yaml(o1_profiles_path)
  o1_ids <- vapply(o1_profiles$profiles, function(x) as.character(x$id %||% "")[1L], character(1))
  expect_setequal(
    o1_ids,
    c("O1_probe_seedA", "O1_probe_seedB", "O1_probe_seedC")
  )

  o2_profiles <- yaml::read_yaml(o2_profiles_path)
  o2_ids <- vapply(o2_profiles$profiles, function(x) as.character(x$id %||% "")[1L], character(1))
  expect_setequal(
    o2_ids,
    c(
      "O2_A_baseline_replay",
      "O2_B_adapt_heavier",
      "O2_C_block_conservative",
      "O2_D_long_chain_fallback",
      "O2_E_multistart_plus_C"
    )
  )

  blocker <- utils::read.csv(blocker_grid_path, stringsAsFactors = FALSE)
  expect_equal(nrow(blocker), 1L)
  expect_true(all(blocker$beta_prior_type == "rhs"))
  expect_true(all(blocker$enabled))

  stress <- utils::read.csv(stress_grid_path, stringsAsFactors = FALSE)
  expect_equal(nrow(stress), 6L)
  expect_true(all(stress$scenario == "sin_asym_small"))
  expect_true(all(stress$beta_prior_type == "rhs"))
  expect_true(all(stress$enabled))

  lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("qdesn_rhs_stageO_manifest.yaml", lines, fixed = TRUE)))
  expect_true(any(grepl("--run-tag", lines, fixed = TRUE)))
  expect_true(any(grepl("skip_o2_if_o1_clean", lines, fixed = TRUE)))
})
