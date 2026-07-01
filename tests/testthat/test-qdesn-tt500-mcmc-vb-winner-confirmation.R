qdesn_mcmc_vbwin_repo_path <- function(...) {
  root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
  file.path(root, ...)
}

test_that("TT500 MCMC VB-winner confirmation config bundle is frozen and narrow", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
  defaults_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_defaults.yaml"))
  grid_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_grid.csv"))
  winners_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_winners.csv"))
  assignments_path <- qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_cell_assignments.csv"))

  expect_true(file.exists(defaults_path))
  expect_true(file.exists(grid_path))
  expect_true(file.exists(winners_path))
  expect_true(file.exists(assignments_path))

  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE, check.names = FALSE)
  winners <- utils::read.csv(winners_path, stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(assignments_path, stringsAsFactors = FALSE, check.names = FALSE)

  expect_equal(nrow(winners), 9L)
  expect_equal(nrow(grid), 9L)
  expect_equal(nrow(assignments), 9L)
  expect_equal(sort(unique(as.character(grid$source_family))), c("gausmix", "laplace", "normal"))
  expect_equal(sort(unique(as.numeric(grid$tau))), c(0.05, 0.25, 0.5))
  expect_true(all(as.character(grid$beta_prior_type) == "rhs_ns"))
  expect_true(all(as.character(grid$screening_profile_id) %in% as.character(winners$screening_profile_id)))

  expect_identical(as.character(defaults$execution$methods), "mcmc")
  expect_identical(as.character(defaults$execution$likelihood_families), "exal")
  expect_equal(as.integer(defaults$reference_contract$expected_qdesn_roots), 27L)
  expect_equal(as.integer(defaults$reference_contract$expected_selected_qdesn_roots), 9L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_burn), 5000L)
  expect_equal(as.integer(defaults$study_contract$budget$mcmc_n_mcmc), 20000L)
  expect_equal(as.integer(defaults$pipeline$inference$mcmc$progress_every), 50L)
  expect_true(isTRUE(defaults$pipeline$inference$mcmc$init_from_vb))
  expect_true(isFALSE(defaults$multiseed$enabled))
  expect_equal(as.integer(defaults$multiseed$mcmc_seed_reps), 1L)
  expect_true(isFALSE(defaults$pipeline$outputs$keep_draws))
  expect_true(isFALSE(defaults$pipeline$outputs$save_forecast_objects))
  expect_true(isTRUE(defaults$pipeline$outputs$save_compact_fit_paths))
})

test_that("TT500 MCMC VB-winner confirmation uses the promoted per-cell profile set", {
  stub <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
  winners <- utils::read.csv(
    qdesn_mcmc_vbwin_repo_path("config", "validation", paste0(stub, "_winners.csv")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  key <- paste(winners$family, sprintf("%.2f", winners$tau), sep = ":")
  profile_by_key <- stats::setNames(as.character(winners$screening_profile_id), key)

  primary <- "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
  expect_equal(profile_by_key[["normal:0.25"]], primary)
  expect_equal(profile_by_key[["normal:0.50"]], primary)
  expect_equal(profile_by_key[["laplace:0.25"]], primary)
  expect_equal(profile_by_key[["gausmix:0.25"]], primary)
  expect_equal(
    profile_by_key[["gausmix:0.05"]],
    "tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3"
  )
  expect_equal(
    profile_by_key[["gausmix:0.50"]],
    "tt500vb_f3_d1_n30_a0p03_r0p5_m15_lag15_rl0_pw0p03_pin0p3"
  )
})

test_that("TT500 MCMC audit resolves mcmc_exal artifact directories", {
  tmp <- tempfile("qdesn_mcmc_audit_")
  results_root <- file.path(tmp, "results", "campaign", "tag", "stamp")
  root_dir <- file.path(results_root, "roots", "root_mcmc_success")
  method_dir <- file.path(root_dir, "fits", "mcmc_exal")
  dir.create(file.path(method_dir, "tables"), recursive = TRUE)
  dir.create(file.path(method_dir, "manifest"), recursive = TRUE)
  dir.create(file.path(root_dir, "manifest"), recursive = TRUE)
  writeLines("SUCCESS", file.path(root_dir, "manifest", "root_status.txt"))
  writeLines("SUCCESS", file.path(method_dir, "manifest", "status.txt"))

  lead <- data.frame(
    forecast_lead = 1:30,
    origin_end_source_index = 9990L,
    pinball_mean = seq_len(30),
    stringsAsFactors = FALSE
  )
  rolling <- data.frame(
    forecast_origin_source_index = c(rep(seq(9000, 9960, by = 30), each = 30), rep(9990L, 10L)),
    forecast_lead = c(rep(1:30, length(seq(9000, 9960, by = 30))), 1:10),
    target_source_index = 9001:10000,
    stringsAsFactors = FALSE
  )
  utils::write.csv(lead, file.path(method_dir, "tables", "forecast_lead_metrics.csv"), row.names = FALSE)
  utils::write.csv(rolling, file.path(method_dir, "tables", "forecast_rolling_origin_paths.csv"), row.names = FALSE)
  exdqlm:::.qdesn_validation_write_json(
    file.path(method_dir, "manifest", "output_retention.json"),
    list(forecast_objects_pruned = TRUE, forecast_objects_exists_after = FALSE)
  )

  audit <- exdqlm:::qdesn_dynamic_fitforecast_audit_screen_campaign(
    results_root = results_root,
    expected_roots = 1L,
    strict = TRUE
  )
  expect_true(audit$summary$strict_ready)
  expect_equal(audit$root_audit$method_dir_name, "mcmc_exal")
  expect_true(audit$root_audit$lead_metrics_pass)
  expect_true(audit$root_audit$rolling_paths_pass)
})

test_that("TT500 split alignment scores effective train rows while preserving context rows", {
  df <- data.frame(
    source_index = 8426:9000,
    effective_train = 8426:9000 >= 8501L,
    evaluation_role = ifelse(8426:9000 >= 8501L, "effective_train", "train_context"),
    stringsAsFactors = FALSE
  )
  root_spec <- list(
    root_id = "root_effective_train",
    dataset_cell_id = "cell",
    effective_fit_size = 500L,
    train_start_source_index = 8501L,
    train_end_source_index = 9000L
  )
  row <- exdqlm:::.qdesn_validation_split_alignment_row(df, root_spec, split = "train")
  expect_equal(row$status, "PASS")
  expect_equal(row$realized_n, 500L)
  expect_equal(row$realized_n_total, 575L)
  expect_equal(row$realized_source_index_first, 8501L)
  expect_equal(row$realized_source_index_last, 9000L)
})
