test_that("GIG helper retries invalid draws and repairs the batch", {
  calls <- 0L
  sampler <- function(n_samples, p, a, b_vec) {
    calls <<- calls + 1L
    out <- matrix(rep(2, as.integer(n_samples) * length(b_vec)), nrow = as.integer(n_samples))
    if (calls == 1L) {
      out[1L, 1L] <- NA_real_
    }
    out
  }

  draws <- exdqlm:::.sample_gig_devroye_required(
    1L,
    p = 0.5,
    a = 1,
    b_vec = c(1, 2),
    context = "test_retry",
    sampler = sampler
  )

  expect_equal(calls, 2L)
  expect_equal(dim(draws), c(1L, 2L))
  expect_true(all(is.finite(draws)))
  expect_true(all(draws > 0))
})

test_that("failed fit path still writes fit_summary_row for downstream aggregation", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml"
  ))

  root_dir <- withr::local_tempdir()
  observed_path <- file.path(root_dir, "observed.csv")
  utils::write.csv(data.frame(y = stats::rnorm(40), stringsAsFactors = FALSE), observed_path, row.names = FALSE)

  staged_data <- list(
    observed_path = observed_path,
    q_true = rep(0, 40),
    x_cols = character(0),
    n_obs = 40L
  )

  root_spec <- list(
    root_id = "root__test__gausmix__tau_0p25__lasttt_40__qdesn_ridge",
    dataset_cell_id = "dynamic__test__gausmix__tau_0p25__efftt_40",
    scenario = "test_scenario",
    source_root_kind = "dynamic",
    source_family = "gausmix",
    tau = 0.25,
    fit_size = 40L,
    effective_fit_size = 40L,
    source_total_size = 40L,
    source_window_label = "effTT40_totalTT40",
    beta_prior_type = "ridge",
    source_reference_priors = "default",
    source_current_rhsns_member = FALSE,
    source_legacy_rhs_member = FALSE,
    reservoir_profile = "tiny_d1_n8_w300",
    seed = 123L
  )

  testthat::local_mocked_bindings(
    run_esn_pipeline_from_cfg = function(...) {
      stop("synthetic pipeline failure")
    },
    .package = "exdqlm"
  )

  res <- exdqlm:::.qdesn_static_crossstudy_run_one_fit(
    root_spec = root_spec,
    defaults = defaults,
    staged_data = staged_data,
    root_dir = root_dir,
    method = "mcmc",
    likelihood_family = "al"
  )

  fit_summary_path <- file.path(root_dir, "fits", "mcmc_al", "fit_summary_row.csv")
  expect_identical(as.character(res$status), "FAIL")
  expect_true(file.exists(fit_summary_path))

  fit_summary <- utils::read.csv(fit_summary_path, stringsAsFactors = FALSE)
  expect_equal(nrow(fit_summary), 1L)
  expect_identical(as.character(fit_summary$status[[1L]]), "FAIL")
  expect_identical(as.character(fit_summary$signoff_grade[[1L]]), "FAIL")
})

test_that("dynamic source sim fallback reconstructs from truth grid when sim_output is absent", {
  family_root <- withr::local_tempdir()

  series_df <- data.frame(
    t = 1:4,
    y = c(10, 11, 12, 13),
    q_target = c(9.5, 10.5, 11.5, 12.5),
    stringsAsFactors = FALSE
  )
  truth_df <- data.frame(
    t = 1:4,
    tau = rep(0.50, 4),
    q_true = c(9.5, 10.5, 11.5, 12.5),
    stringsAsFactors = FALSE
  )

  utils::write.csv(series_df, file.path(family_root, "series_wide.csv"), row.names = FALSE)
  utils::write.csv(truth_df, file.path(family_root, "true_quantile_grid.csv"), row.names = FALSE)

  sim_obj <- exdqlm:::.qdesn_dynamic_crossstudy_load_source_sim_object(
    family_root = family_root,
    tau = 0.50
  )

  expect_equal(sim_obj$p, 0.50)
  expect_equal(as.numeric(sim_obj$y), series_df$y)
  expect_equal(as.numeric(sim_obj$q[, 1L]), truth_df$q_true)
  expect_identical(
    as.character(sim_obj$info$quantile_truth_method),
    "true_quantile_grid_csv_fallback"
  )
  expect_identical(
    as.character(sim_obj$extras$reconstructed_from),
    "series_wide_and_true_quantile_grid"
  )
})
