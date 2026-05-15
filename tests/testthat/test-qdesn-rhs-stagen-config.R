test_that("Stage-N manifest, blocker grid, profiles, and runner are well formed", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  manifest_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageN_manifest.yaml")
  profiles_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageN_profiles.yaml")
  grid_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_stageN_blocker_grid.csv")
  script_path <- file.path(repo_root, "scripts", "run_qdesn_rhs_stageN_wave.R")

  expect_true(file.exists(manifest_path))
  expect_true(file.exists(profiles_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(script_path))

  manifest <- yaml::read_yaml(manifest_path)
  expect_true(is.list(manifest$meta))
  expect_true(is.character(manifest$meta$tracker_title))
  expect_true(is.character(manifest$meta$stage_label))
  expect_true(is.character(manifest$inputs$promoted_defaults))
  expect_true(is.character(manifest$inputs$guardrail_lock))
  expect_true(is.character(manifest$inputs$failed_grid))
  expect_true(is.character(manifest$inputs$canary_grid))
  expect_true(is.character(manifest$inputs$full_grid))
  expect_true(is.character(manifest$inputs$mr1_profiles))
  expect_true(isTRUE(manifest$gates$mr1$require_zero_fail))
  expect_true(isTRUE(manifest$gates$mr2$require_all_eligible))
  expect_true(isTRUE(manifest$gates$mr3$require_all_finite_domain))
  expect_true(isTRUE(manifest$gates$mr3$require_zero_trace_unavailable))
  expect_true(is.character(manifest$outputs$winner_defaults))
  expect_true(is.character(manifest$outputs$promoted_defaults))
  expect_true(is.character(manifest$outputs$tracker_doc))

  profiles <- yaml::read_yaml(profiles_path)
  expect_true(is.list(profiles$profiles))
  ids <- vapply(profiles$profiles, function(x) {
    if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
  }, character(1))
  expect_setequal(
    ids,
    c(
      "NR1_base_replay",
      "NR1_longer_chain",
      "NR1_longer_chain_plus_adapt",
      "NR1_longer_chain_plus_adapt_blocktight"
    )
  )

  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  expect_equal(nrow(grid), 2L)
  expect_true(all(grid$beta_prior_type == "rhs"))
  expect_true(all(grid$enabled))

  lines <- readLines(script_path, warn = FALSE)
  expect_true(any(grepl("qdesn_rhs_stageN_manifest.yaml", lines, fixed = TRUE)))
  expect_true(any(grepl("--run-tag", lines, fixed = TRUE)))
})
