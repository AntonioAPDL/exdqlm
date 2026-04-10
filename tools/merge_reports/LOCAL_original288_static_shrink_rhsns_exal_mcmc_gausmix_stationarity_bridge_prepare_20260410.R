#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge_helpers_20260410.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()

run_dir <- dirname(paths$config_dir)
if (dir.exists(run_dir)) {
  unlink(run_dir, recursive = TRUE, force = TRUE)
}
ensure_dir_original288_syncedbase_rerun(paths$config_dir)
ensure_dir_original288_syncedbase_rerun(paths$rows_dir)
ensure_dir_original288_syncedbase_rerun(paths$health_dir)
ensure_dir_original288_syncedbase_rerun(paths$metrics_dir)
ensure_dir_original288_syncedbase_rerun(paths$logs_dir)

base_fail <- read_failed_rows_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()
schedule <- materialize_schedule_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge()

utils::write.csv(schedule, paths$schedule, row.names = FALSE)

rows <- vector("list", nrow(schedule))
for (i in seq_len(nrow(schedule))) {
  row <- schedule[i, , drop = FALSE]
  cfg <- build_row_config_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(row, repo_root)
  cfg_path <- config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(cfg$row_id)
  saveRDS(cfg, cfg_path)

  required_inputs <- c(
    cfg$series_wide_path,
    cfg$coef_truth_path,
    cfg$selection_indices_path,
    cfg$true_quantile_grid_path
  )

  rows[[i]] <- data.frame(
    row_id = cfg$row_id,
    base_row_id = cfg$base_row_id,
    pair_id = paste(cfg$family, cfg$tau_label, cfg$fit_size, cfg$profile_id, sep = "::"),
    seed = cfg$fit_seed,
    status = "pending",
    phase = cfg$phase,
    phase_order = cfg$phase_order,
    repair_class = cfg$repair_class,
    missing_inputs = any(!file.exists(required_inputs)),
    block = cfg$block,
    root_kind = cfg$root_kind,
    family = cfg$family,
    tau = cfg$tau,
    tau_label = cfg$tau_label,
    fit_size = cfg$fit_size,
    prior = cfg$beta_prior,
    prior_semantics = cfg$target_prior_semantics,
    source_prior_semantics = "rhs_legacy_mixed",
    target_prior_semantics = cfg$target_prior_semantics,
    inference = cfg$inference,
    model = cfg$model,
    method = paste(cfg$inference, cfg$model, sep = "::"),
    target_original_case_key = cfg$target_original_case_key,
    accepted_gate = cfg$accepted_gate,
    accepted_healthy = cfg$accepted_healthy,
    rebuild_gate = cfg$rebuild_gate,
    rebuild_status = cfg$rebuild_status,
    base_profile_id = cfg$base_profile_id,
    base_selected_variant_tag = cfg$base_selected_variant_tag,
    selected_candidate = cfg$profile_id,
    selected_variant_tag = cfg$source_variant_tag,
    profile_id = cfg$profile_id,
    rationale = cfg$rationale,
    historical_source = cfg$historical_source,
    run_root = cfg$run_root,
    data_dir = cfg$data_dir,
    series_wide_path = cfg$series_wide_path,
    coef_truth_path = cfg$coef_truth_path,
    true_quantile_grid_path = cfg$true_quantile_grid_path,
    selection_indices_path = cfg$selection_indices_path,
    config_path = cfg_path,
    candidate_fit_path = cfg$fit_path,
    row_status_path = cfg$row_status_path,
    health_path = cfg$health_path,
    metrics_path = cfg$metrics_path,
    stringsAsFactors = FALSE
  )
}

manifest <- do.call(rbind, rows)
manifest <- manifest[order(
  manifest$phase_order,
  manifest$base_row_id,
  manifest$row_id
), , drop = FALSE]
rownames(manifest) <- NULL
manifest$row_id <- seq_len(nrow(manifest))

for (i in seq_len(nrow(manifest))) {
  cfg <- readRDS(manifest$config_path[i])
  if (!identical(cfg$row_id, manifest$row_id[i])) {
    cfg$row_id <- manifest$row_id[i]
    cfg$config_path <- config_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(manifest$row_id[i])
    cfg$row_status_path <- row_status_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(manifest$row_id[i])
    cfg$health_path <- health_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(manifest$row_id[i])
    cfg$metrics_path <- metrics_path_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge(manifest$row_id[i])
    saveRDS(cfg, cfg$config_path)
    unlink(manifest$config_path[i], force = TRUE)
    manifest$config_path[i] <- cfg$config_path
    manifest$row_status_path[i] <- cfg$row_status_path
    manifest$health_path[i] <- cfg$health_path
    manifest$metrics_path[i] <- cfg$metrics_path
  }
}

utils::write.csv(manifest, paths$manifest, row.names = FALSE)

stage_counts <- as.data.frame(with(manifest, table(phase)), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(phase_order_original288_static_shrink_rhsns_exal_mcmc_gausmix_stationarity_bridge[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

cat(sprintf("base_fail_rows: %d\n", nrow(base_fail)))
cat(sprintf("gausmix_stationarity_bridge_schedule_rows: %d\n", nrow(schedule)))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("rows: %d\n", nrow(manifest)))
cat(sprintf("missing_inputs: %d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
