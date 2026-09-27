testthat::test_that("fixed comparator registry is complete and immutable", {
  registry <- iqfc_v1_source_registry(repo_root)
  testthat::expect_equal(nrow(registry), 54L)
  testthat::expect_equal(as.integer(table(registry$model_variant)), c(27L, 27L))
  testthat::expect_equal(length(unique(paste(
    registry$model_variant, registry$family, registry$tau, registry$chain_id
  ))), 54L)
  testthat::expect_true(all(file.exists(registry$source_config_path)))
})

testthat::test_that("fixed comparator sources equal the completed Q-DESN DGP windows", {
  registry <- iqfc_v1_source_registry(repo_root)
  equality <- iqfc_v1_source_equality(repo_root, registry)
  testthat::expect_equal(nrow(equality), 9L)
  testthat::expect_true(all(equality$exact_equal))
  testthat::expect_true(all(equality$frozen_rows > 1000L))
})

testthat::test_that("completed Q-DESN authority is hash-verified before comparison", {
  authority <- iqfc_v1_qdesn_authority(repo_root)
  testthat::expect_true(all(unlist(authority$checks)))
  testthat::expect_identical(
    authority$closeout_sha256,
    "ba5b99c538c00564149d49246f9cee26268973ee10464f0e2082788de632aa72"
  )
})

testthat::test_that("stride-one replay changes only predeclared protocol fields", {
  registry <- iqfc_v1_source_registry(repo_root)
  source <- ffv2_read_json(registry$source_config_path[[1L]])
  frozen <- tempfile(fileext = ".json")
  file.copy(registry$source_config_path[[1L]], frozen)
  target <- iqfc_v1_remap_config(
    source, repo_root, tempfile("iqfc_run_"), registry[1L, , drop = FALSE], frozen
  )
  audit <- iqfc_v1_config_audit(source, target)
  testthat::expect_true(audit$pass)
  testthat::expect_length(audit$unexpected, 0L)
  testthat::expect_true(all(audit$invariant))
  testthat::expect_identical(target$origin_stride, 1L)
  testthat::expect_true(target$require_full_horizon)
  testthat::expect_identical(target$metric_intervals$forecast_rows, 29130L)
  testthat::expect_identical(target$metric_intervals$draws, 300L)
  testthat::expect_identical(target$package_runtime_mode, "installed_namespace")
  testthat::expect_identical(target$budget$mcmc, source$budget$mcmc)
})

testthat::test_that("stride-one grid is the exact common comparison lattice", {
  grid <- ffv2_rolling_grid(
    9000L, 9001L, 10000L, hmax = 30L, origin_stride = 1L,
    forecast_protocol = "rolling_origin_no_refit_state_update",
    require_full_horizon = TRUE
  )
  testthat::expect_equal(nrow(grid), 29130L)
  testthat::expect_equal(length(unique(grid$forecast_origin_source_index)), 971L)
  testthat::expect_equal(range(grid$forecast_lead), c(1L, 30L))
})

testthat::test_that("pipeline is lane-scoped, storage-light, and uses 15 workers", {
  scripts <- file.path(harness_root, "scripts", c(
    "manage_independent_qdesn_fixed_comparator_stride1_v1.R",
    "build_independent_qdesn_fixed_comparator_stride1_v1_diagnostics.R",
    "run_independent_qdesn_fixed_comparator_stride1_v1_pipeline.sh",
    "launch_independent_qdesn_fixed_comparator_stride1_v1.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_match(text, "workers=15", fixed = TRUE)
  testthat::expect_match(text, "OMP_NUM_THREADS=1", fixed = TRUE)
  testthat::expect_match(text, iqfc_v1_tarball_sha256, fixed = TRUE)
  testthat::expect_match(text, "fitted_model_binaries=0", fixed = TRUE)
  testthat::expect_false(grepl("overleaf-direct", text, fixed = TRUE))
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text,
                              fixed = TRUE))
})

testthat::test_that("row runner supports exact installed-package execution", {
  text <- paste(readLines(file.path(harness_root, "R", "row_runner.R"),
                          warn = FALSE), collapse = "\n")
  testthat::expect_match(text, "installed_namespace", fixed = TRUE)
  testthat::expect_match(text, "Installed exdqlm version mismatch", fixed = TRUE)
  testthat::expect_match(text, "worktree_load_all", fixed = TRUE)
})
