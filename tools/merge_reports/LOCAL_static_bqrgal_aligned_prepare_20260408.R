#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_static_bqrgal_aligned_helpers_20260408.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- static_bqrgal_aligned_paths_20260408()

ensure_dir_static_bqrgal(paths$run_root)
ensure_dir_static_bqrgal(paths$config_dir)
ensure_dir_static_bqrgal(paths$rows_dir)
ensure_dir_static_bqrgal(paths$health_dir)
ensure_dir_static_bqrgal(paths$metrics_dir)
ensure_dir_static_bqrgal(paths$logs_dir)
ensure_dir_static_bqrgal(paths$data_dir)
ensure_dir_static_bqrgal(paths$fits_dir)

bootstrap_static_bqrgal_lib_20260408(paths)

if (!file.exists(paths$data_core)) {
  core_data <- build_static_bqrgal_dataset_20260408(
    n_train = 100L,
    n_test = 100L,
    train_reps = 100L,
    test_reps = 100L,
    p0_vals = c(0.05, 0.25, 0.50),
    seed = 42L
  )
  saveRDS(core_data, paths$data_core)
}

if (!file.exists(paths$data_extension)) {
  ext_data <- build_static_bqrgal_dataset_20260408(
    n_train = 1000L,
    n_test = 100L,
    train_reps = 100L,
    test_reps = 100L,
    p0_vals = c(0.05, 0.25, 0.50),
    seed = 1042L
  )
  saveRDS(ext_data, paths$data_extension)
}

grid <- static_bqrgal_grid_20260408()
grid$data_path <- vapply(grid$lane_label, function(x) data_path_for_lane_static_bqrgal_20260408(paths, x), character(1))
grid$fit_path <- vapply(seq_len(nrow(grid)), function(i) {
  fit_path_static_bqrgal_20260408(
    paths = paths,
    lane_label = grid$lane_label[i],
    family = grid$family[i],
    tau_label = grid$tau_label[i],
    n_train = grid$n_train[i],
    model = grid$model[i],
    rep_id = grid$rep_id[i]
  )
}, character(1))
grid$config_path <- vapply(grid$row_id, row_config_path_static_bqrgal_20260408, character(1), paths = paths)
grid$row_status_path <- vapply(grid$row_id, row_status_path_static_bqrgal_20260408, character(1), paths = paths)
grid$health_path <- vapply(grid$row_id, row_health_path_static_bqrgal_20260408, character(1), paths = paths)
grid$metrics_path <- vapply(grid$row_id, row_metrics_path_static_bqrgal_20260408, character(1), paths = paths)
grid$engine <- "bqrgal_reference"
grid$beta_prior_keyword <- "laplace"
grid$gamma_kernel <- ifelse(grid$model == "exal", "slice", NA_character_)
grid$step_size <- ifelse(grid$model == "exal", 0.01, NA_real_)
grid$slice_max_steps <- ifelse(grid$model == "exal", Inf, NA_real_)
grid$n_iter <- 150000L
grid$n_burn <- 50000L
grid$n_thin <- 20L
grid$n_keep <- 5000L
grid$n_report <- 2000L
grid$missing_inputs <- !file.exists(grid$data_path)

priors <- list(
  intercept_gaus_var = 100,
  sigma_invgamma = c(2, 2),
  eta_gamma = c(0.1, 0.1)
)
mcmc_settings <- list(n_iter = 150000L, n_burn = 50000L, n_thin = 20L, n_report = 2000L)
tuning <- list(step_size = 0.01)

for (i in seq_len(nrow(grid))) {
  cfg <- list(
    row_id = grid$row_id[i],
    phase = grid$phase[i],
    phase_order = grid$phase_order[i],
    lane_label = grid$lane_label[i],
    family = grid$family[i],
    tau = grid$tau[i],
    tau_label = grid$tau_label[i],
    n_train = grid$n_train[i],
    n_test = grid$n_test[i],
    train_reps = grid$train_reps[i],
    test_reps = grid$test_reps[i],
    rep_id = grid$rep_id[i],
    model = grid$model[i],
    engine = grid$engine[i],
    beta_prior_keyword = grid$beta_prior_keyword[i],
    gamma_kernel = grid$gamma_kernel[i],
    step_size = grid$step_size[i],
    slice_max_steps = grid$slice_max_steps[i],
    fit_seed = grid$fit_seed[i],
    data_seed = grid$data_seed[i],
    data_path = grid$data_path[i],
    fit_path = grid$fit_path[i],
    row_status_path = grid$row_status_path[i],
    health_path = grid$health_path[i],
    metrics_path = grid$metrics_path[i],
    lib_dir = paths$lib_dir,
    priors = priors,
    mcmc_settings = mcmc_settings,
    tuning = tuning,
    true_params = list(
      beta_truth = c(3, 1.5, 0, 0, 2, 0, 0, 0),
      true_ind = c(1, 1, 0, 0, 1, 0, 0, 0)
    ),
    bqrgal_run_wrapper = paths$bqrgal_run_wrapper
  )
  ensure_dir_static_bqrgal(dirname(grid$config_path[i]))
  saveRDS(cfg, grid$config_path[i])
}

manifest <- grid[, c(
  "row_id", "phase", "phase_order", "lane_label", "family", "tau", "tau_label",
  "n_train", "n_test", "train_reps", "test_reps", "rep_id", "model", "engine",
  "beta_prior_keyword", "gamma_kernel", "step_size", "slice_max_steps",
  "n_iter", "n_burn", "n_thin", "n_keep", "n_report", "data_seed", "fit_seed",
  "data_path", "fit_path", "config_path", "row_status_path", "health_path",
  "metrics_path", "missing_inputs"
)]
utils::write.csv(manifest, paths$manifest, row.names = FALSE)

schedule <- unique(manifest[, c(
  "phase", "phase_order", "lane_label", "family", "tau", "tau_label", "n_train",
  "n_test", "train_reps", "test_reps"
)])
schedule <- schedule[order(schedule$phase_order, schedule$family, schedule$tau), , drop = FALSE]
utils::write.csv(schedule, paths$schedule, row.names = FALSE)

stage_counts <- as.data.frame(table(manifest$phase), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(static_bqrgal_phase_order_20260408[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

audit <- data.frame(
  item = c(
    "manifest_rows",
    "core_rows",
    "extension_rows",
    "core_data_exists",
    "extension_data_exists",
    "missing_inputs",
    "lib_dir"
  ),
  value = c(
    nrow(manifest),
    sum(manifest$lane_label == "paper_matched_core"),
    sum(manifest$lane_label == "extension_n1000"),
    file.exists(paths$data_core),
    file.exists(paths$data_extension),
    sum(manifest$missing_inputs),
    paths$lib_dir
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(audit, paths$audit, row.names = FALSE)

cat(sprintf("manifest=%s\n", paths$manifest))
cat(sprintf("rows=%d\n", nrow(manifest)))
cat(sprintf("core_rows=%d\n", sum(manifest$lane_label == "paper_matched_core")))
cat(sprintf("extension_rows=%d\n", sum(manifest$lane_label == "extension_n1000")))
cat(sprintf("missing_inputs=%d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
