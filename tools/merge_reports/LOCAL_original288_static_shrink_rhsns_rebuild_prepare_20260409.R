#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_static_shrink_rhsns_rebuild_helpers_20260409.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_static_shrink_rhsns_rebuild()

run_dir <- dirname(paths$config_dir)
if (dir.exists(run_dir)) {
  unlink(run_dir, recursive = TRUE, force = TRUE)
}
ensure_dir_original288_syncedbase_rerun(paths$config_dir)
ensure_dir_original288_syncedbase_rerun(paths$rows_dir)
ensure_dir_original288_syncedbase_rerun(paths$health_dir)
ensure_dir_original288_syncedbase_rerun(paths$metrics_dir)
ensure_dir_original288_syncedbase_rerun(paths$logs_dir)

accepted <- read_accepted_selection_original288_static_shrink_rhsns_rebuild()
validate_reference_status_original288_static_shrink_rhsns_rebuild(accepted)

accepted$row_id <- seq_len(nrow(accepted))
rows <- vector("list", nrow(accepted))

for (i in seq_len(nrow(accepted))) {
  row <- accepted[i, , drop = FALSE]
  cfg <- build_row_config_original288_static_shrink_rhsns_rebuild(row, repo_root)
  cfg_path <- config_path_original288_static_shrink_rhsns_rebuild(row$row_id)
  saveRDS(cfg, cfg_path)

  required_inputs <- c(
    cfg$series_wide_path,
    cfg$coef_truth_path,
    cfg$selection_indices_path,
    cfg$true_quantile_grid_path
  )

  rows[[i]] <- data.frame(
    row_id = cfg$row_id,
    pair_id = paste(cfg$family, cfg$tau_label, cfg$fit_size, cfg$model, sep = "::"),
    seed = cfg$fit_seed,
    status = "pending",
    phase = cfg$phase,
    phase_order = cfg$phase_order,
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
    original_scenario_key = row$target_original_scenario_key,
    original_case_key = row$target_original_case_key,
    target_original_scenario_key = row$target_original_scenario_key,
    target_original_case_key = row$target_original_case_key,
    target_root_id = row$target_root_id,
    accepted_gate = cfg$accepted_gate,
    accepted_healthy = cfg$accepted_healthy,
    selection_mode = cfg$selection_mode,
    selected_source_type = "legacy_mixed_prior_freeze",
    selected_source_subtype = row$selected_source_subtype,
    selected_candidate = cfg$selected_candidate,
    selected_variant_tag = cfg$selected_variant_tag,
    evidence_bucket = cfg$evidence_bucket,
    rebuild_scope = cfg$rebuild_scope,
    profile_id = cfg$profile_id,
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
  manifest$family,
  manifest$tau_label,
  manifest$fit_size,
  manifest$model,
  manifest$inference
), , drop = FALSE]
rownames(manifest) <- NULL
manifest$row_id <- seq_len(nrow(manifest))

for (i in seq_len(nrow(manifest))) {
  cfg <- readRDS(manifest$config_path[i])
  if (!identical(cfg$row_id, manifest$row_id[i])) {
    cfg$row_id <- manifest$row_id[i]
    cfg$config_path <- config_path_original288_static_shrink_rhsns_rebuild(manifest$row_id[i])
    cfg$row_status_path <- row_status_path_original288_static_shrink_rhsns_rebuild(manifest$row_id[i])
    cfg$health_path <- health_path_original288_static_shrink_rhsns_rebuild(manifest$row_id[i])
    cfg$metrics_path <- metrics_path_original288_static_shrink_rhsns_rebuild(manifest$row_id[i])
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
stage_counts$phase_order <- unname(phase_order_original288_static_shrink_rhsns_rebuild[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

ref <- reference_status_original288_static_shrink_rhsns_rebuild()
cat(sprintf(
  "accepted_reference: healthy=%d total=%d pass=%d warn=%d fail=%d\n",
  ref$healthy,
  ref$total,
  ref$pass,
  ref$warn,
  ref$fail
))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("rows: %d\n", nrow(manifest)))
cat(sprintf("missing_inputs: %d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
