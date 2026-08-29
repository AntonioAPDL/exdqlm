test_that("rolling-state repair selects the intended sentinel and full surfaces", {
  audit <- data.frame(
    job_id = paste0("job", seq_len(27)),
    model_variant = "exdqlm",
    inference = "mcmc",
    family = rep(c("gausmix", "laplace", "normal"), each = 9),
    tau = rep(rep(c(0.05, 0.25, 0.50), each = 3), 3),
    chain_id = rep(1:3, 9),
    stringsAsFactors = FALSE
  )
  sentinel <- iems_v1_select_source_jobs(audit, "sentinel")
  full <- iems_v1_select_source_jobs(audit, "full")
  expect_equal(nrow(sentinel), 3L)
  expect_equal(nrow(full), 27L)
  expect_true(any(sentinel$family == "normal" & sentinel$tau == 0.05))
  expect_true(any(sentinel$family == "gausmix" & sentinel$tau == 0.25))
  expect_true(any(sentinel$family == "normal" & sentinel$tau == 0.50))
  expect_true(all(sentinel$chain_id == 1L))
})

test_that("rolling-state repair enforces the generic launcher schema", {
  config_path <- tempfile(fileext = ".json")
  writeLines("{}", config_path)
  manifest <- data.frame(
    row_id = 1L, row_key = "row_0001", spec_id = "spec", family = "normal",
    tau = 0.05, fit_size = 500L, model_variant = "exdqlm",
    inference = "mcmc", phase = "mcmc_tt500", chain_id = 1L,
    row_config_path = config_path, row_status_path = tempfile(fileext = ".csv"),
    stringsAsFactors = FALSE
  )
  expect_true(iems_v1_validate_launcher_manifest(manifest))
  expect_error(
    iems_v1_validate_launcher_manifest(manifest[, setdiff(names(manifest), "row_status_path")]),
    "row_status_path"
  )
})

test_that("rolling-state repair remaps only generated output paths", {
  source_config <- tempfile(fileext = ".json")
  writeLines("{}", source_config)
  config <- list(
    family = "normal", tau = 0.05, chain_id = 1L,
    run_root = "/old/run",
    row_config_path = "/old/run/configs/row_0002_config.json",
    row_metrics_path = "/old/run/metrics/row_0002_metrics.csv",
    series_wide_path = "/shared/source/series_wide.csv",
    true_quantile_grid_path = "/shared/source/true_quantile_grid.csv",
    sim_output_path = "/shared/source/sim_output.rds",
    meta_path = "/shared/source/meta.txt",
    row_id = 2L, row_key = "row_0002", spec_id = "spec",
    fit_size = 500L, model_variant = "exdqlm", inference = "mcmc",
    phase = "mcmc_tt500", status = "pending",
    handoff = list(prune_fit_on_success = TRUE),
    retention = list(allow_success_binary_payloads = FALSE)
  )
  out <- iems_v1_remap_config(
    config, "/repo", "run1", source_config, "sha"
  )
  expect_true(startsWith(out$row_metrics_path, "/repo/results/"))
  expect_identical(out$series_wide_path, config$series_wide_path)
  expect_identical(
    out$state_update_method,
    ffv2_exdqlm_mcmc_predictive_state_update_method()
  )
  expect_identical(out$package_contract$authority, "CRAN")
  audit <- iems_v1_config_contract_audit(config, out)
  expect_true(audit$scientific_contract_equal)
  expect_length(audit$unexpected_fields, 0L)

  bad <- out
  bad$tau <- 0.25
  expect_error(
    iems_v1_config_contract_audit(config, bad),
    "Unexpected scientific config changes: tau"
  )
})
