testthat::test_that("recovery config changes execution paths but preserves the fit handoff", {
  source_job_root <- tempfile("failed_job_")
  recovery_root <- tempfile("recovery_")
  dir.create(file.path(source_job_root, "configs"), recursive = TRUE)
  scientific <- tempfile(fileext = ".json")
  failed <- tempfile(fileext = ".json")
  writeLines("{}", scientific)
  writeLines("{}", failed)
  source_config <- list(
    run_root = source_job_root,
    run_tag = "failed",
    row_id = 1L,
    row_key = "row_0001",
    spec_id = "fixed-spec",
    source_authority = "frozen-authority",
    source_job_id = "source-job",
    source_config_path = scientific,
    source_config_sha256 = iqfc_v1_sha256(scientific),
    row_config_path = file.path(source_job_root, "configs", "row_0001.json"),
    row_status_path = file.path(source_job_root, "rows", "row_0001.csv"),
    row_progress_path = file.path(source_job_root, "progress", "row_0001.csv"),
    fit_handoff_path = file.path(source_job_root, "handoff", "fit.ffv2handoff"),
    fit_handoff_manifest_path = file.path(source_job_root, "handoff", "fit.json"),
    inference_diagnostics_path = file.path(source_job_root, "metrics", "diagnostics.json"),
    series_wide_path = "/frozen/series.csv",
    true_quantile_grid_path = "/frozen/truth.csv",
    sim_output_path = "/frozen/sim.rds",
    meta_path = "/frozen/meta.txt",
    model_variant = "dqlm", family = "normal", tau = 0.25,
    chain_id = 1L, handoff = list(prune_fit_on_success = TRUE)
  )
  source_row <- data.frame(
    source_config_path = file.path(
      dirname(source_job_root), "jobs", "job", "configs", "row.json"
    ),
    source_handoff_path = "/frozen/handoff.ffv2handoff",
    source_handoff_manifest_path = "/frozen/handoff.json",
    source_handoff_sha256 = paste(rep("a", 64L), collapse = ""),
    source_handoff_bytes = 123,
    stringsAsFactors = FALSE
  )
  config <- iqfcr_v1_recovery_config(
    source_config, repo_root, recovery_root, "dqlm__normal__0p25__c01",
    scientific, failed, source_row
  )

  testthat::expect_identical(config$validation_stage, "forecast-only")
  testthat::expect_identical(
    config$state_update_strategy, "incremental_teacher_forced"
  )
  testthat::expect_identical(
    config$fit_handoff_path, source_row$source_handoff_path[[1L]]
  )
  testthat::expect_false(config$handoff$prune_fit_on_success)
  testthat::expect_identical(config$series_wide_path, "/frozen/series.csv")
  testthat::expect_true(startsWith(config$row_config_path, recovery_root))
  testthat::expect_identical(config$spec_id, "fixed-spec")
})

testthat::test_that("fit completion gate requires the full 25000-iteration event", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(
    stage = c("fit", "fit"), substage = c("mcmc", "mcmc"),
    event = c("progress", "complete"),
    current_iter = c(24950L, 25000L), total_iter = c(25000L, 25000L)
  ), path, row.names = FALSE)
  testthat::expect_true(iqfcr_v1_fit_completed(path))
  x <- utils::read.csv(path)
  x$current_iter[[2L]] <- 24999L
  utils::write.csv(x, path, row.names = FALSE)
  testthat::expect_false(iqfcr_v1_fit_completed(path))
})

testthat::test_that("recovery pipeline is forecast-only, lane-scoped, and non-pruning", {
  scripts <- file.path(harness_root, "scripts", c(
    "manage_independent_qdesn_fixed_comparator_forecast_recovery_v1.R",
    "smoke_independent_qdesn_fixed_comparator_forecast_recovery_v1.R",
    "run_independent_qdesn_fixed_comparator_forecast_recovery_v1_pipeline.sh",
    "launch_independent_qdesn_fixed_comparator_forecast_recovery_v1.sh"
  ))
  testthat::expect_true(all(file.exists(scripts)))
  text <- paste(unlist(lapply(scripts, readLines, warn = FALSE)), collapse = "\n")
  testthat::expect_match(text, "--validation-stage forecast-only", fixed = TRUE)
  testthat::expect_match(text, "refits=0", fixed = TRUE)
  testthat::expect_match(text, "source_handoffs_retained=54", fixed = TRUE)
  testthat::expect_match(text, "workers=15", fixed = TRUE)
  testthat::expect_false(grepl("overleaf-direct", text, fixed = TRUE))
  testthat::expect_false(grepl("Article-Q-DESN---Version-2/main.tex", text,
                              fixed = TRUE))
})

testthat::test_that("rolling-state code has no bare make_df_mat call", {
  text <- paste(readLines(
    file.path(harness_root, "R", "exdqlm_rolling_state.R"), warn = FALSE
  ), collapse = "\n")
  stripped <- gsub("ffv2_make_df_mat", "", text, fixed = TRUE)
  testthat::expect_false(grepl("make_df_mat\\s*\\(", stripped, perl = TRUE))
  testthat::expect_match(text, 'ffv2_pkg_internal("make_df_mat")', fixed = TRUE)
})

testthat::test_that("storage audit ignores only isolated package metadata", {
  root <- tempfile("iqfcr_storage_")
  package_meta <- file.path(root, "runtime", "Rlib", "exdqlm", "Meta")
  job_payload <- file.path(root, "jobs", "job_01", "fit.rds")
  dir.create(package_meta, recursive = TRUE)
  saveRDS(list(package = "metadata"), file.path(package_meta, "package.rds"))

  testthat::expect_length(iqfc_v1_scientific_binary_payloads(root), 0L)

  dir.create(dirname(job_payload), recursive = TRUE)
  saveRDS(list(scientific = "payload"), job_payload)
  testthat::expect_identical(
    iqfc_v1_scientific_binary_payloads(root),
    normalizePath(job_payload, winslash = "/", mustWork = TRUE)
  )
})
