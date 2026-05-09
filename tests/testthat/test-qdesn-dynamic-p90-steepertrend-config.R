test_that("p90 steepertrend defaults encode the promoted dynamic surface", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"
  ))

  expect_identical(
    as.character(defaults$source_materialization$scenarios),
    "dlm_constV_p90_m0amp_highnoise_steepertrend_v1"
  )
  expect_identical(as.integer(defaults$study_contract$budget$posterior_metric_draws), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_sampling_nd_draws), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$vb_synthesis_n_samp), 20000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$max_iter), 300L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$rhs$freeze_tau_iters), 50L)
  expect_identical(as.integer(defaults$pipeline$inference$mcmc$rhs$freeze_tau_burnin_iters), 500L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_identical(as.integer(defaults$source_materialization$windows[[1L]]$source_total_size), 813L)
  expect_identical(as.integer(defaults$source_materialization$windows[[2L]]$source_total_size), 5313L)
})

test_that("MCMC VB warm-start artifacts can be pruned without dropping metadata", {
  obj <- list(
    fits_fc = list(
      list(
        fit_train = list(
          fit = list(
            control = list(
              init_from_vb = TRUE,
              vb_warm_start_seed = 1777L,
              vb_warm_start_control = list(max_iter = 20L)
            ),
            diagnostics = list(warm_start = "ldvb"),
            misc = list(
              vb_warm = list(heavy = stats::rnorm(4)),
              nested = list(vb_init_fit = list(heavy = stats::rnorm(3)))
            )
          )
        )
      )
    ),
    cfg = list(outputs = list(keep_mcmc_vb_init = FALSE))
  )

  pruned <- exdqlm:::qdesn_prune_mcmc_vb_init_artifacts(obj)
  fit <- pruned$fits_fc[[1L]]$fit_train$fit

  expect_true(isTRUE(fit$control$init_from_vb))
  expect_equal(fit$control$vb_warm_start_seed, 1777L)
  expect_equal(fit$control$vb_warm_start_control$max_iter, 20L)
  expect_identical(fit$diagnostics$warm_start, "ldvb")
  expect_null(fit$misc$vb_warm)
  expect_null(fit$misc$nested$vb_init_fit)
})

test_that("MCMC VB warm-start pruning preserves fit classes", {
  obj <- list(
    fits_fc = list(
      list(
        fit_train = list(
          fit = structure(
            list(
              control = list(init_from_vb = TRUE),
              misc = list(vb_warm = list(heavy = stats::rnorm(2)))
            ),
            class = c("exal_mcmc", "exalStaticMCMC")
          )
        )
      )
    )
  )

  pruned <- exdqlm:::qdesn_prune_mcmc_vb_init_artifacts(obj)
  fit <- pruned$fits_fc[[1L]]$fit_train$fit

  expect_s3_class(fit, "exal_mcmc")
  expect_null(fit$misc$vb_warm)
})

test_that("validation health recognizes classless saved exAL fit payloads", {
  summary_row <- data.frame(
    status = "SUCCESS",
    wall_seconds = 1,
    total_stage_seconds = 1,
    forecast_CRPS_mean = NA_real_,
    forecast_PinballMean_mean = NA_real_,
    forecast_S_mean = NA_real_,
    rhs_diag_available = FALSE,
    rhs_collapse_flag_any = FALSE,
    rhs_collapse_flag_bound_any = FALSE,
    rhs_collapse_flag_shrink_any = FALSE,
    rhs_unhealthy_any = FALSE,
    rhs_unhealthy_reason = NA_character_,
    rhs_root_cause_context = NA_character_,
    rhs_tau_last = NA_real_,
    rhs_E_invV_med_last = NA_real_,
    rhs_beta_l2_last = NA_real_,
    rhs_beta_small_frac_1e4_last = NA_real_,
    stringsAsFactors = FALSE
  )
  root_spec <- list(
    root_id = "classless-fit",
    scenario = "unit",
    tau = 0.5,
    likelihood_family = "exal",
    beta_prior_type = "ridge",
    seed = 1L,
    reservoir_profile = "unit"
  )
  wrap_summary <- function(fit) {
    list(
      summary = summary_row,
      forecast_objects = list(
        fits_fc = list(
          list(
            fit_train = list(fit = fit),
            df_pred_fc = data.frame(q_pred = 1, q_true = 1, y = 1)
          )
        )
      )
    )
  }

  vb_fit <- list(
    qbeta = list(m = c(3, 4)),
    qsiggam = list(gamma_mean = 0.2, sigma_mean = 1.1),
    converged = TRUE,
    iter = 5L,
    run.time = 1.25,
    misc = list(
      gamma_trace = rep(0.2, 5),
      sigma_trace = rep(1.1, 5),
      elbo_trace = seq_len(5)
    )
  )
  vb_summary <- wrap_summary(vb_fit)
  vb_health <- exdqlm:::.qdesn_validation_method_health("vb", root_spec, vb_summary)
  vb_trace <- exdqlm:::.qdesn_validation_method_progress_trace("vb", vb_summary)

  expect_identical(vb_health$fit_class, "exal_vb")
  expect_true(isTRUE(vb_health$finite_ok))
  expect_true(isTRUE(vb_health$domain_ok))
  expect_equal(nrow(vb_trace), 5L)

  mcmc_fit <- list(
    run.time = 2.5,
    samp.beta = matrix(c(1, 2, 2, 3, 3, 4), ncol = 2),
    samp.sigma = c(1.0, 1.1, 1.2),
    samp.gamma = c(0.1, 0.2, 0.3),
    bounds = c(L = -1, U = 1),
    control = list(n_burn = 1L),
    diagnostics = list()
  )
  mcmc_summary <- wrap_summary(mcmc_fit)
  mcmc_health <- exdqlm:::.qdesn_validation_method_health("mcmc", root_spec, mcmc_summary)
  mcmc_trace <- exdqlm:::.qdesn_validation_method_progress_trace("mcmc", mcmc_summary)

  expect_identical(mcmc_health$fit_class, "exal_mcmc")
  expect_true(isTRUE(mcmc_health$finite_ok))
  expect_true(isTRUE(mcmc_health$domain_ok))
  expect_equal(mcmc_health$mcmc_n_keep, 3L)
  expect_equal(nrow(mcmc_trace), 3L)
})

test_that("pipeline summary infers success from readable saved forecast objects", {
  out_dir <- file.path(tempdir(), paste0("qdesn-summary-status-", Sys.getpid()))
  dir.create(file.path(out_dir, "models"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(
    list(
      fits_fc = list(),
      cfg = list(
        pipeline = list(mode = "real"),
        inference = list(
          method = "vb",
          likelihood_family = "al",
          beta_prior = list(type = "ridge")
        ),
        split = list(T_use = 10L, n_train = 9L),
        forecast = list(H_forecast = 1L),
        p_vec = 0.5
      )
    ),
    file.path(out_dir, "models", "forecast_objects.rds")
  )

  summary_obj <- exdqlm:::collect_pipeline_run_summary(out_dir)

  expect_identical(summary_obj$status, "SUCCESS")
  expect_identical(summary_obj$summary$status, "SUCCESS")
})

test_that("p90 steepertrend full and subset grids stay coherent", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_defaults.yaml"
  ))
  full_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_full_grid.csv"
  ))

  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(full_grid, defaults)
  expect_identical(as.integer(validation$enabled_roots), 36L)
  expect_identical(as.integer(validation$unique_dataset_cells), 18L)
  expect_identical(sort(as.character(validation$priors)), c("rhs_ns", "ridge"))
  expect_equal(as.numeric(validation$taus), c(0.05, 0.25, 0.50))

  subset_specs <- list(
    smoke = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_smoke_grid.csv", rows = 6L),
    ridge = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_ridge_full_grid.csv", rows = 18L),
    rhsns = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_rhsns_full_grid.csv", rows = 18L),
    mcmc_ridge_tt500 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt500_grid.csv", rows = 9L),
    mcmc_ridge_tt5000 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_ridge_tt5000_grid.csv", rows = 9L),
    mcmc_rhsns_tt500 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt500_grid.csv", rows = 9L),
    mcmc_rhsns_tt5000 = list(path = "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_mcmc_rhsns_tt5000_grid.csv", rows = 9L)
  )

  for (spec in subset_specs) {
    subset_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
      repo_root,
      "config",
      "validation",
      spec$path
    ))
    exdqlm:::qdesn_dynamic_crossstudy_validate_grid(subset_grid, defaults, allow_subset = TRUE)
    expect_identical(as.integer(nrow(subset_grid)), spec$rows)
    expect_identical(length(unique(subset_grid$root_id)), nrow(subset_grid))
    expect_true(all(as.character(subset_grid$source_scenario) == "dlm_constV_p90_m0amp_highnoise_steepertrend_v1"))
    expect_true(all(as.integer(subset_grid$source_total_size) %in% c(813L, 5313L)))
  }
})

test_that("p90 steepertrend n300m50 relaunch spec encodes the larger DESN", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml"
  ))
  full_grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_full_grid.csv"
  ))

  profile_id <- "deep_d3_n300x3_skip100_w300_m50"
  profile <- defaults$reservoir_profiles[[profile_id]]
  validation <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(full_grid, defaults)

  expect_identical(defaults$campaign$name, "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation")
  expect_identical(defaults$pilot$reservoir_profile, profile_id)
  expect_identical(unique(as.character(full_grid$reservoir_profile)), profile_id)
  expect_identical(as.integer(validation$enabled_roots), 36L)
  expect_identical(as.integer(validation$unique_dataset_cells), 18L)
  expect_identical(as.integer(nrow(full_grid) * 4L), 144L)

  expect_identical(as.integer(profile$D), 3L)
  expect_identical(as.integer(profile$n), c(300L, 300L, 300L))
  expect_identical(as.integer(profile$n_tilde), c(300L, 300L))
  expect_identical(as.integer(profile$m), 50L)
  expect_equal(as.numeric(profile$alpha), c(0.25, 0.25, 0.25))
  expect_equal(as.numeric(profile$rho), c(0.95, 0.95, 0.95))
  expect_identical(as.character(profile$act_f), c("tanh", "tanh", "tanh"))
  expect_identical(as.character(profile$act_k), c("identity", "identity", "identity"))
  expect_equal(as.numeric(profile$pi_w), c(0.1, 0.1, 0.1))
  expect_equal(as.numeric(profile$pi_in), c(1.0, 1.0, 1.0))
  expect_identical(as.integer(profile$washout), 300L)
  expect_true(isTRUE(profile$add_bias))
  expect_identical(as.integer(profile$seed), 123L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_false(isTRUE(defaults$pipeline$outputs$keep_mcmc_vb_init))
  expect_identical(as.character(defaults$pipeline$outputs$retention_profile), "analysis")
  expect_false(isTRUE(defaults$pipeline$outputs$save_forecast_objects))
  expect_true(isTRUE(defaults$pipeline$outputs$save_compact_fit_paths))
  expect_true(isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure))
  expect_identical(as.integer(defaults$runtime$workers), 16L)
  expect_identical(as.character(defaults$runtime$root_scheduler), "load_balanced")
})

test_that("dynamic cross-study keeps explicit DESN seed separate from root metadata seed", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_micro_smoke_grid.csv"
  ))
  root_spec <- as.list(grid[1L, , drop = FALSE])
  root_spec <- lapply(root_spec, function(x) x[[1L]])

  enriched <- exdqlm:::qdesn_dynamic_crossstudy_enrich_root_spec(root_spec, defaults)

  expect_identical(as.integer(root_spec$seed), 62000L)
  expect_identical(as.integer(root_spec$desn_seed), 123L)
  expect_identical(as.integer(enriched$seed), 62000L)
  expect_identical(as.integer(enriched$desn_seed), 123L)
})

test_that("n400m60 testing smoke uses a fast infrastructure-only MCMC budget", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_testing_smoke_defaults.yaml"
  ))
  grid <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_micro_smoke_grid.csv"
  ))
  root_spec <- as.list(grid[1L, , drop = FALSE])
  root_spec <- lapply(root_spec, function(x) x[[1L]])

  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_burn), 100L)
  expect_identical(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 200L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$max_iter), 80L)
  expect_identical(as.integer(defaults$pipeline$inference$vb$n_samp_xi), 300L)
  expect_identical(as.integer(defaults$signoff$mcmc$min_keep_pass), 120L)

  vb_cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "vb",
    likelihood_family = "exal",
    x_cols = character(),
    T_use = as.integer(root_spec$source_total_size)
  )
  mcmc_cfg <- exdqlm:::qdesn_static_crossstudy_build_pipeline_cfg(
    root_spec = root_spec,
    defaults = defaults,
    method = "mcmc",
    likelihood_family = "exal",
    x_cols = character(),
    T_use = as.integer(root_spec$source_total_size)
  )

  expect_identical(as.integer(vb_cfg$desn$seed), 123L)
  expect_identical(as.integer(vb_cfg$inference$vb$max_iter), 80L)
  expect_identical(as.integer(vb_cfg$inference$vb$n_samp_xi), 300L)
  expect_identical(as.integer(mcmc_cfg$desn$seed), 123L)
  expect_identical(as.integer(mcmc_cfg$inference$mcmc$n_burn), 100L)
  expect_identical(as.integer(mcmc_cfg$inference$mcmc$n_mcmc), 200L)
  expect_identical(as.integer(mcmc_cfg$inference$mcmc$progress_every), 50L)
  expect_identical(as.integer(mcmc_cfg$inference$mcmc$vb_warm_start_control$max_iter), 80L)
})

test_that("analysis retention writes compact fit paths before pruning full forecast objects", {
  tmp <- tempfile("qdesn-retention-")
  source_path <- file.path(tmp, "series_wide.csv")
  method_dir <- file.path(tmp, "root", "fits", "vb_exal")
  dir.create(dirname(source_path), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(method_dir, "models"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(
      t = 301:306,
      source_index = 901:906,
      y = 101:106,
      q_target = 201:206,
      stringsAsFactors = FALSE
    ),
    source_path,
    row.names = FALSE
  )
  saveRDS(list(large = TRUE), file.path(method_dir, "models", "forecast_objects.rds"))

  root_spec <- list(
    root_id = "unit-root",
    dataset_cell_id = "unit-cell",
    scenario = "unit-scenario",
    source_family = "normal",
    tau = 0.25,
    fit_size = 3L,
    source_total_size = 6L,
    beta_prior_type = "ridge",
    likelihood_family = "exal",
    source_series_wide_path = source_path
  )
  summary_obj <- list(
    summary = data.frame(
      inference_method = "vb",
      likelihood_family = "exal",
      n_train = 5L,
      stringsAsFactors = FALSE
    ),
    forecast_objects = list(
      fits_fc = list(
        list(
          df_mu_tr = data.frame(
            h = 1:3,
            p0 = 0.25,
            mu = c(203.1, 204.1, 205.1),
            lo = c(202, 203, 204),
            hi = c(204, 205, 206),
            stringsAsFactors = FALSE
          ),
          df_pred_tr = data.frame(q_pred = c(203.2, 204.2, 205.2), stringsAsFactors = FALSE),
          df_mu_fc = data.frame(h = 1L, p0 = 0.25, mu = 206.1, lo = 205, hi = 207, stringsAsFactors = FALSE),
          df_pred_fc = data.frame(q_pred = 206.2, y = 106, stringsAsFactors = FALSE),
          fit_train = list(meta = list(keep_idx = 3:5), fit = list())
        )
      )
    )
  )
  defaults <- list(
    pipeline = list(
      outputs = list(
        retention_profile = "analysis",
        save_forecast_objects = FALSE,
        save_compact_fit_paths = TRUE,
        retain_full_rds_on_failure = TRUE
      )
    )
  )

  manifest <- exdqlm:::.qdesn_validation_apply_output_retention(
    method_dir = method_dir,
    status = "SUCCESS",
    defaults = defaults,
    root_spec = root_spec,
    summary_obj = summary_obj
  )
  train_path <- file.path(method_dir, "tables", "fit_quantile_path_train.csv")
  holdout_path <- file.path(method_dir, "tables", "fit_quantile_path_holdout.csv")
  train_df <- utils::read.csv(train_path, stringsAsFactors = FALSE)
  holdout_df <- utils::read.csv(holdout_path, stringsAsFactors = FALSE)

  expect_false(file.exists(file.path(method_dir, "models", "forecast_objects.rds")))
  expect_true(isTRUE(manifest$forecast_objects_pruned))
  expect_equal(nrow(train_df), 3L)
  expect_equal(train_df$source_t, 303:305)
  expect_equal(train_df$source_index, 903:905)
  expect_equal(train_df$q_true, 203:205)
  expect_equal(train_df$y, 103:105)
  expect_equal(holdout_df$q_true, 206)
  expect_true(file.exists(file.path(method_dir, "manifest", "output_retention.json")))
})

test_that("analysis retention keeps full forecast objects for failed fits by default", {
  tmp <- tempfile("qdesn-retention-fail-")
  method_dir <- file.path(tmp, "root", "fits", "mcmc_exal")
  dir.create(file.path(method_dir, "models"), recursive = TRUE, showWarnings = FALSE)
  forecast_path <- file.path(method_dir, "models", "forecast_objects.rds")
  saveRDS(list(large = TRUE), forecast_path)

  manifest <- exdqlm:::.qdesn_validation_apply_output_retention(
    method_dir = method_dir,
    status = "FAIL",
    defaults = list(pipeline = list(outputs = list(retention_profile = "analysis", save_forecast_objects = FALSE))),
    root_spec = list(root_id = "failed-root"),
    summary_obj = NULL
  )

  expect_true(file.exists(forecast_path))
  expect_false(isTRUE(manifest$forecast_objects_pruned))
  expect_true(isTRUE(manifest$forecast_objects_exists_after))
})

test_that("p90 steepertrend n300m50 closeout manifest targets one full campaign", {
  repo_root <- normalizePath(pkgload::pkg_path(), winslash = "/", mustWork = TRUE)
  exdqlm:::.qdesn_validation_require_namespace("yaml")
  manifest <- yaml::read_yaml(file.path(
    repo_root,
    "config",
    "validation",
    "qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis_manifest.yaml"
  ))

  expect_identical(
    manifest$analysis$id,
    "qdesn_dynamic_p90_steepertrend_n300m50_closeout_analysis"
  )
  expect_named(manifest$runs, "n300m50_full")
  expect_identical(as.integer(manifest$expected$roots_per_prior), 18L)
  expect_identical(as.integer(manifest$expected$fits_per_prior), 72L)
  expect_identical(sort(as.character(manifest$expected$priors)), c("rhs_ns", "ridge"))
  expect_identical(sort(as.character(manifest$expected$methods)), c("mcmc", "vb"))
  expect_identical(sort(as.character(manifest$expected$models)), c("al", "exal"))
})

test_that("p90 closeout loader supports single-campaign root summary globs", {
  tmp <- file.path(tempdir(), paste0("qdesn-closeout-loader-", Sys.getpid()))
  dir.create(file.path(tmp, "roots", "root_a", "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(tmp, "roots", "root_b", "tables"), recursive = TRUE, showWarnings = FALSE)

  make_row <- function(root_id, prior, inference, model) {
    data.frame(
      root_id = root_id,
      scenario = "unit_scenario",
      family = "normal",
      tau = 0.25,
      fit_size = 500L,
      prior = prior,
      inference = inference,
      model = model,
      status = "SUCCESS",
      finite_ok = TRUE,
      domain_ok = TRUE,
      signoff_grade = "PASS",
      comparison_eligible = TRUE,
      fit_file = file.path(tmp, root_id, inference, model, "forecast_objects.rds"),
      stringsAsFactors = FALSE
    )
  }

  utils::write.csv(
    make_row("root_a", "ridge", "vb", "al"),
    file.path(tmp, "roots", "root_a", "tables", "fit_summary.csv"),
    row.names = FALSE
  )
  utils::write.csv(
    make_row("root_b", "rhs_ns", "mcmc", "exal"),
    file.path(tmp, "roots", "root_b", "tables", "fit_summary.csv"),
    row.names = FALSE
  )

  manifest <- list(
    runs = list(
      single = list(
        run_tag = "unit-single",
        root_fit_summary_glob = file.path(tmp, "roots", "*", "tables", "fit_summary.csv")
      )
    )
  )

  out <- exdqlm:::.qdesn_p90_closeout_load_fit_summary(manifest, repo_root = tmp)

  expect_equal(nrow(out), 2L)
  expect_identical(sort(as.character(out$source_run_tag)), c("unit-single", "unit-single"))
  expect_true(all(as.character(out$source_run_part) == "single_root_summaries"))
  expect_identical(sort(as.character(out$canonical_model)), c("al", "exal"))
  expect_true(all(nzchar(as.character(out$fit_case_id))))
})

test_that("p90 fit overlay data can be read from compact paths without full RDS", {
  tmp <- tempfile("qdesn-compact-overlay-")
  compact_path <- file.path(tmp, "root", "fits", "vb_al", "tables", "fit_quantile_path_train.csv")
  dir.create(dirname(compact_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(
      h = 1:4,
      source_t = 11:14,
      y = c(5, 6, 7, 8),
      q_true = c(4.5, 5.5, 6.5, 7.5),
      mu = c(4.6, 5.6, 6.6, 7.6),
      lo = c(4, 5, 6, 7),
      hi = c(5, 6, 7, 8),
      stringsAsFactors = FALSE
    ),
    compact_path,
    row.names = FALSE
  )
  fit_row <- data.frame(
    fit_file = file.path(tmp, "root", "fits", "vb_al", "models", "forecast_objects.rds"),
    fit_quantile_path_train_file = compact_path,
    inference = "vb",
    canonical_model = "al",
    signoff_grade = "PASS",
    signoff_reason = "unit",
    stringsAsFactors = FALSE
  )

  out <- exdqlm:::.qdesn_p90_closeout_fit_plot_df(fit_row, last_n = 2L)

  expect_equal(nrow(out), 2L)
  expect_equal(out$source_t, 13:14)
  expect_equal(out$q_true, c(6.5, 7.5))
  expect_identical(as.character(unique(out$panel)), "VB / AL")
})
