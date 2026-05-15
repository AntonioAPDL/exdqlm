test_that("rhs drift rescue wave config has required staged structure", {
  repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  cfg_path <- file.path(repo_root, "config", "validation", "qdesn_rhs_drift_rescue_wave.yaml")
  expect_true(file.exists(cfg_path))

  cfg <- yaml::read_yaml(cfg_path)
  expect_true(is.list(cfg))

  expect_true(is.list(cfg$inputs))
  expect_true(is.character(cfg$inputs$base_defaults))
  expect_true(is.character(cfg$inputs$failing_root_grid))
  expect_true(is.character(cfg$inputs$broader_grid))

  expect_true(is.list(cfg$stages))
  for (stage_id in c("A", "B", "C")) {
    stage_cfg <- cfg$stages[[stage_id]]
    expect_true(is.list(stage_cfg), info = paste("missing stage", stage_id))
    expect_true(length(stage_cfg$profiles) >= 2L, info = paste("insufficient profiles in stage", stage_id))
    ids <- vapply(stage_cfg$profiles, function(x) {
      if (is.null(x$id) || !length(x$id)) "" else as.character(x$id)[1L]
    }, character(1))
    expect_true(all(nzchar(ids)), info = paste("empty profile id in stage", stage_id))
  }

  seeds <- as.integer(unlist(cfg$replicate$seeds, use.names = FALSE))
  expect_true(length(seeds) >= 3L)
  expect_true(all(is.finite(seeds)))

  expect_true(isTRUE(cfg$gates$require_zero_fail_stageD))
  expect_true(isTRUE(cfg$gates$require_all_eligible_stageD))
  expect_true(isTRUE(cfg$gates$require_zero_fail_stageE))
  expect_true(isTRUE(cfg$gates$require_all_eligible_stageE))
  expect_true(isTRUE(cfg$gates$require_zero_trace_unavailable_stageE))
})
