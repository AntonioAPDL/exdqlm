test_that("high-alpha design is broad, deterministic, and bounded", {
  design <- qdesn_hacv1_alpha_rho_design()

  expect_equal(qdesn_hacv1_alpha_levels(), c(0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.95, 0.99))
  expect_equal(qdesn_hacv1_rho_levels(), c(0.35, 0.45, 0.60, 0.75, 0.85, 0.93, 0.97, 0.99))
  expect_equal(nrow(design), 20L)
  expect_equal(anyDuplicated(paste(design$alpha, design$rho, sep = "\r")), 0L)
  expect_true(all(design$alpha >= 0.40 & design$alpha <= 0.99))
  expect_true(all(design$rho >= 0.35 & design$rho <= 0.99))
  expect_true(all(c("0.4\r0.35", "0.4\r0.99", "0.99\r0.35", "0.99\r0.99") %in%
    paste(design$alpha, design$rho, sep = "\r")))
})

test_that("authority extraction is exact and case-specific", {
  interface <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v1_20260805",
    "qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv"
  )
  expect_identical(
    unname(tools::sha256sum(interface)),
    "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a"
  )
  authority <- qdesn_hacv1_authority(interface)

  expect_equal(nrow(authority$parents), 11L)
  expect_equal(sum(authority$parents$launch_wave == "wave1"), 4L)
  expect_equal(sum(authority$parents$launch_wave == "wave2_universe"), 7L)
  expect_false(any(authority$parents$tau == 0.50))
  expect_equal(nrow(authority$metric_sources), 33L)
  expect_true(all(file.exists(authority$parents$parent_fit_request_path)))
  expect_true(all(nzchar(authority$parents$parent_fit_request_sha256)))

  normal005 <- authority$parents[authority$parents$target_cell_id == "al_normal_t0p05", , drop = FALSE]
  expect_equal(normal005$D, 1L)
  expect_equal(normal005$n_each, 6L)
  expect_equal(normal005$m, 1L)
  expect_equal(normal005$alpha, 0.00075)
  expect_equal(normal005$rho, 0.35)
  expect_equal(normal005$rhs_tau0, 3e-4)
})

test_that("Wave 1 varies only active axes around exact parents", {
  interface <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v1_20260805",
    "qdesn_dqlm_500obs_trainonly_article_v1_20260805_interface.csv"
  )
  plan <- qdesn_hacv1_build_plan(interface)
  audit <- qdesn_hacv1_topology_audit(plan$profiles)
  wave1 <- plan$profiles[plan$profiles$launch_wave == "wave1", , drop = FALSE]

  expect_equal(nrow(plan$profiles), 376L)
  expect_equal(nrow(wave1), 124L)
  expect_equal(nrow(plan$profiles[plan$profiles$launch_wave == "wave2_universe", ]), 252L)
  expect_equal(length(unique(wave1$target_cell_id)), 4L)
  expect_true(all(audit$candidate_topology_valid))
  expect_true(all(wave1$D == ave(wave1$D, wave1$target_cell_id, FUN = function(x) x[[1L]])))
  expect_true(all(wave1$rhs_tau0 == ave(wave1$rhs_tau0, wave1$target_cell_id, FUN = function(x) x[[1L]])))

  repair_cells <- plan$topology_classes$target_cell_id[
    plan$topology_classes$launch_wave == "wave1" &
      plan$topology_classes$topology_search_mode == "repair_alpha_rho"
  ]
  alpha_only_cells <- plan$topology_classes$target_cell_id[
    plan$topology_classes$launch_wave == "wave1" &
      plan$topology_classes$topology_search_mode == "exact_alpha_only"
  ]
  expect_setequal(repair_cells, c("al_normal_t0p05", "exal_gausmix_t0p25"))
  expect_setequal(alpha_only_cells, c("al_normal_t0p25", "exal_normal_t0p25"))
  expect_true(all(wave1$rho[wave1$target_cell_id %in% alpha_only_cells] < 0.50))
})

test_that("materialized execution contract is 20-core, staged, and storage-light", {
  stub <- file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1"
  )
  skip_if_not(file.exists(paste0(stub, "_phase_index.csv")), "campaign has not been materialized")
  index <- utils::read.csv(paste0(stub, "_phase_index.csv"), check.names = FALSE)
  wave1 <- index[index$phase == "wave1", , drop = FALSE]
  wave2 <- index[index$phase == "wave2_universe", , drop = FALSE]

  expect_equal(wave1$profiles, 124L)
  expect_equal(wave1$expected_specs, 372L)
  expect_true(wave1$launch_approved)
  expect_equal(wave2$profiles, 252L)
  expect_equal(wave2$expected_specs, 756L)
  expect_false(wave2$launch_approved)

  defaults <- yaml::read_yaml(wave1$defaults_path)
  grid <- utils::read.csv(wave1$grid_path, check.names = FALSE)
  specs <- utils::read.csv(wave1$target_specs_path, check.names = FALSE)
  expect_equal(nrow(grid), 372L)
  expect_equal(nrow(specs), 372L)
  expect_equal(anyDuplicated(specs$spec_id), 0L)
  expect_true(all(specs$likelihood_family == specs$likelihood_target))
  expect_true(all(grid$train_start_source_index == 8501L))
  expect_true(all(grid$train_end_source_index == 9000L))
  expect_true(all(grid$forecast_start_source_index == 9001L))
  expect_true(all(grid$forecast_end_source_index == 10000L))
  expect_identical(defaults$preproc$fit_scope, "train_only")
  expect_equal(defaults$runtime$workers, 20L)
  expect_equal(defaults$runtime$threads, 1L)
  expect_equal(defaults$pipeline$inference$mcmc$n_burn, 1000L)
  expect_equal(defaults$pipeline$inference$mcmc$n_mcmc, 3000L)
  expect_equal(defaults$pipeline$inference$mcmc$progress_every, 50L)
  expect_true(defaults$pipeline$inference$mcmc$init_from_vb)
  expect_false(defaults$pipeline$outputs$keep_draws)
  expect_false(defaults$pipeline$outputs$keep_mcmc_vb_init)
  expect_false(defaults$pipeline$outputs$save_forecast_objects)
  expect_false(defaults$pipeline$outputs$retain_full_rds_on_failure)
})

test_that("source and launcher contracts reserve confirmation evidence", {
  cfg <- yaml::read_yaml(file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1_source_replicates.yaml"
  ))
  roles <- vapply(cfg$replicates, function(x) as.character(x$role), character(1L))
  expect_equal(sum(roles == "discovery"), 3L)
  expect_equal(sum(roles == "sealed_holdout"), 1L)
  expect_equal(cfg$generation$TT_warmup, 2000L)
  expect_equal(cfg$generation$TT_main, 10000L)
  expect_equal(cfg$generation$TT_total, 12000L)
  expect_equal(cfg$selection_contract$workers, 20L)
  expect_equal(cfg$selection_contract$threads_per_worker, 1L)

  pipeline <- paste(readLines(file.path(
    repo_root, "validation", "fitforecast_v2", "scripts",
    "run_qdesn_mcmc_highalpha_cellwise_v1_pipeline.sh"
  ), warn = FALSE), collapse = "\n")
  expect_match(pipeline, "WORKERS=20", fixed = TRUE)
  expect_match(pipeline, "OPENBLAS_NUM_THREADS=1", fixed = TRUE)
  expect_match(pipeline, "getconf _NPROCESSORS_ONLN", fixed = TRUE)
  expect_match(pipeline, "taskset -c", fixed = TRUE)
  expect_match(pipeline, "WAVE2_APPROVED=FALSE", fixed = TRUE)
  expect_match(pipeline, "FULL_CONFIRMATION_APPROVED=FALSE", fixed = TRUE)
  expect_false(grepl("wave2_universe_defaults.yaml.*--batch full", pipeline))
})
