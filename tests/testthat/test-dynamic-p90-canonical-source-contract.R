bundle_root <- testthat::test_path(
  "..", "..", "results", "function_testing_20260309_dynamic_dlm_family_qspec",
  "dlm_constV_p90_m0amp_highnoise_steepertrend_v1"
)
registry_path <- testthat::test_path(
  "..", "..", "tools", "merge_reports",
  "LOCAL_refreshed288_dataset_registry_20260422_dynamic_p90_steepertrend_v1.csv"
)
selection_manifest_path <- testthat::test_path(
  "..", "..", "config", "validation",
  "refreshed288_dynamic_exdqlm_crossstudy_active_dataset_selection.yaml"
)

testthat::skip_if_not(dir.exists(bundle_root), "canonical dynamic p90 bundle unavailable in test sandbox")
testthat::skip_if_not(file.exists(registry_path), "dynamic dataset registry unavailable in test sandbox")
testthat::skip_if_not(file.exists(selection_manifest_path), "dynamic selection manifest unavailable in test sandbox")

read_bundle_csv <- function(...) {
  utils::read.csv(file.path(...), stringsAsFactors = FALSE)
}

test_that("dynamic p90 canonical bundle inventories match the selected 9-root/18-slice contract", {
  full_inventory <- read_bundle_csv(bundle_root, "000__full_root_inventory.csv")
  slice_inventory <- read_bundle_csv(bundle_root, "000__canonical_slice_inventory.csv")

  expect_equal(nrow(full_inventory), 9L)
  expect_equal(nrow(slice_inventory), 18L)
  expect_equal(sort(unique(full_inventory$family)), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(full_inventory$tau)), c(0.05, 0.25, 0.5))
  expect_equal(sort(unique(slice_inventory$fit_size)), c(500L, 5000L))
  expect_true(all(file.exists(full_inventory$root_dir)))
  expect_true(all(file.exists(slice_inventory$slice_dir)))
  expect_false(any(grepl("effTT500_totalTT813|effTT5000_totalTT5313", slice_inventory$slice_dir)))
})

test_that("dynamic p90 canonical roots preserve q_true = mu and tau-shared latent paths within family", {
  families <- c("gausmix", "laplace", "normal")
  tau_labels <- c("0p05", "0p25", "0p50")

  for (family in families) {
    root_paths <- file.path(bundle_root, family, paste0("tau_", tau_labels), "series_wide.csv")
    root_tables <- lapply(root_paths, utils::read.csv, stringsAsFactors = FALSE)

    expect_equal(length(unique(vapply(root_tables, nrow, integer(1)))), 1L)
    ref_mu <- root_tables[[1L]]$mu
    for (tbl in root_tables) {
      expect_equal(tbl$q_target, tbl$mu)
      expect_equal(tbl$mu, ref_mu)
    }

    truth_paths <- file.path(bundle_root, family, paste0("tau_", tau_labels), "true_quantile_grid.csv")
    truth_tables <- lapply(truth_paths, utils::read.csv, stringsAsFactors = FALSE)
    for (ii in seq_along(truth_tables)) {
      expect_equal(truth_tables[[ii]]$q_true, root_tables[[ii]]$mu)
    }
  }
})

test_that("dynamic p90 canonical slices use the expected lastTT500 and lastTT5000 windows", {
  root_wide <- read_bundle_csv(bundle_root, "normal", "tau_0p25", "series_wide.csv")
  slice_500_idx <- read_bundle_csv(bundle_root, "normal", "tau_0p25", "fit_input_lastTT500", "selection_indices.csv")
  slice_5000_idx <- read_bundle_csv(bundle_root, "normal", "tau_0p25", "fit_input_lastTT5000", "selection_indices.csv")
  slice_500_wide <- read_bundle_csv(bundle_root, "normal", "tau_0p25", "fit_input_lastTT500", "series_wide.csv")
  slice_5000_wide <- read_bundle_csv(bundle_root, "normal", "tau_0p25", "fit_input_lastTT5000", "series_wide.csv")

  expect_equal(nrow(root_wide), 7000L)
  expect_equal(nrow(slice_500_wide), 500L)
  expect_equal(nrow(slice_5000_wide), 5000L)
  expect_equal(slice_500_idx$source_index, 6501:7000)
  expect_equal(slice_5000_idx$source_index, 2001:7000)
  expect_equal(slice_500_wide$mu, root_wide$mu[6501:7000])
  expect_equal(slice_5000_wide$mu, root_wide$mu[2001:7000])
})

test_that("dynamic p90 refreshed registry and selection manifest point to the local canonical surface", {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
  dynamic_rows <- registry[registry$block == "dynamic", , drop = FALSE]
  selection_lines <- readLines(selection_manifest_path, warn = FALSE)

  expect_equal(nrow(dynamic_rows), 18L)
  expect_true(all(grepl("dlm_constV_p90_m0amp_highnoise_steepertrend_v1", dynamic_rows$source_root, fixed = TRUE)))
  expect_true(all(grepl("fit_input_lastTT(500|5000)$", dynamic_rows$input_dir)))
  expect_true(any(grepl("selected_scenario_id: dlm_constV_p90_m0amp_highnoise_steepertrend_v1", selection_lines, fixed = TRUE)))
  expect_true(any(grepl("single_prior_fit_count: 72", selection_lines, fixed = TRUE)))
  expect_true(any(grepl("dual_prior_fit_count: 144", selection_lines, fixed = TRUE)))
})
