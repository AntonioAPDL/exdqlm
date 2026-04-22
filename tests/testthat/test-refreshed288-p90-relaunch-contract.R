registry_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_dataset_registry_20260422_p90_full288_baseline_v1.csv"
)
method_registry_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_method_registry_20260422_p90_full288_baseline_v1.csv"
)
full_manifest_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_full_manifest_20260422_p90_full288_baseline_v1.csv"
)
smoke_manifest_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_smoke_manifest_20260422_p90_full288_baseline_v1.csv"
)
run_contract_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_run_contract_20260422_p90_full288_baseline_v1.csv"
)

testthat::skip_if_not(file.exists(registry_path), "prepared refreshed288 p90 registry unavailable in test sandbox")
testthat::skip_if_not(file.exists(method_registry_path), "prepared refreshed288 p90 method registry unavailable in test sandbox")
testthat::skip_if_not(file.exists(full_manifest_path), "prepared refreshed288 p90 full manifest unavailable in test sandbox")
testthat::skip_if_not(file.exists(smoke_manifest_path), "prepared refreshed288 p90 smoke manifest unavailable in test sandbox")
testthat::skip_if_not(file.exists(run_contract_path), "prepared refreshed288 p90 run contract unavailable in test sandbox")

test_that("prepared refreshed288 p90 dataset registry keeps the 54-entry geometry", {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  counts <- with(registry, table(block, root_kind))

  expect_equal(nrow(registry), 54L)
  expect_equal(unname(counts["dynamic", "dynamic"]), 18L)
  expect_equal(unname(counts["static", "static_paper"]), 18L)
  expect_equal(unname(counts["static", "static_shrink"]), 18L)
  expect_equal(sum(registry$block == "dynamic"), 18L)
  expect_true(all(grepl("dlm_constV_p90_m0amp_highnoise_steepertrend_v1", registry$source_root[registry$block == "dynamic"], fixed = TRUE)))
  expect_true(all(registry$missing_inputs == FALSE))
})

test_that("prepared refreshed288 p90 method registry keeps the 16-profile matrix", {
  method_registry <- utils::read.csv(method_registry_path, stringsAsFactors = FALSE, check.names = FALSE)

  expect_equal(nrow(method_registry), 16L)
  expect_true(all(method_registry$posterior_metric_draws == 20000L))
  expect_true(all(method_registry$vb_sampling_nd_draws == 20000L))
  expect_true(all(method_registry$vb_synthesis_n_samp == 20000L))
})

test_that("prepared refreshed288 p90 manifests preserve the 288/full and 48/smoke contracts", {
  full_manifest <- utils::read.csv(full_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  smoke_manifest <- utils::read.csv(smoke_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  full_phase_counts <- sort(as.integer(with(full_manifest, table(phase))))
  smoke_phase_counts <- sort(as.integer(with(smoke_manifest, table(phase))))

  expect_equal(nrow(full_manifest), 288L)
  expect_equal(nrow(smoke_manifest), 48L)
  expect_equal(full_phase_counts, c(36L, 36L, 108L, 108L))
  expect_equal(smoke_phase_counts, c(12L, 12L, 12L, 12L))
})

test_that("prepared refreshed288 p90 run contract points at the active p90 scenario", {
  contract <- utils::read.csv(run_contract_path, stringsAsFactors = FALSE, check.names = FALSE)

  expect_equal(contract$active_dynamic_scenario[[1L]], "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")
  expect_equal(contract$mcmc_n_burn[[1L]], 5000L)
  expect_equal(contract$mcmc_n_mcmc[[1L]], 20000L)
  expect_equal(contract$vb_max_iter[[1L]], 300L)
})
