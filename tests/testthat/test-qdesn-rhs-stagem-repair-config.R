test_that("Stage-M repair manifest and profile matrix are well formed", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageM_repair_manifest.yaml")
  profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageM_repair_profiles.yaml")
  failed_grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageM_failed_roots_seed123.csv")
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageM_repair_wave.R")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(failed_grid_path))
  expect_true(file.exists(script_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest$inputs))
  expect_true(is.character(manifest$inputs$promoted_defaults))
  expect_true(is.character(manifest$inputs$guardrail_lock))
  expect_true(is.character(manifest$inputs$failed_grid))
  expect_true(is.character(manifest$inputs$canary_grid))
  expect_true(is.character(manifest$inputs$full_grid))
  expect_true(is.character(manifest$inputs$mr1_profiles))

  expect_true(is.list(manifest$gates$mr1))
  expect_true(is.list(manifest$gates$mr2))
  expect_true(is.list(manifest$gates$mr3))
  expect_true(isTRUE(manifest$gates$mr1$require_zero_fail))
  expect_true(isTRUE(manifest$gates$mr1$require_all_eligible))
  expect_true(isTRUE(manifest$gates$mr1$require_all_finite_domain))
  expect_true(isTRUE(manifest$gates$mr1$require_zero_trace_unavailable))

  expect_true(is.list(manifest$outputs))
  expect_true(is.character(manifest$outputs$winner_defaults))
  expect_true(is.character(manifest$outputs$promoted_defaults))
  expect_true(is.character(manifest$outputs$tracker_doc))

  profiles <- yaml::read_yaml(profiles_path)
  expect_true(is.list(profiles$profiles))
  expect_equal(length(profiles$profiles), 4L)
  ids <- vapply(profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  expect_setequal(
    ids,
    c(
      "MR1_base_replay",
      "MR1_longer_chain",
      "MR1_longer_chain_plus_mixing",
      "MR1_longer_chain_plus_adapt"
    )
  )

  grid <- utils::read.csv(failed_grid_path, stringsAsFactors = FALSE)
  expect_true(nrow(grid) >= 1L)
  expect_true(all(grid$beta_prior_type == "rhs"))
  expect_true(all(grid$enabled))

  script_lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("--manifest", script_lines, fixed = TRUE)))
  expect_true(any(grepl("--run-tag", script_lines, fixed = TRUE)))
})
