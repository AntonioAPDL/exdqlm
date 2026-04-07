#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_syncedbase_residual_repair_helpers_20260407.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_syncedbase_residual_repair()

ensure_dir_original288_syncedbase_rerun(dirname(paths$manifest))
if (dir.exists(dirname(paths$config_dir))) {
  unlink(dirname(paths$config_dir), recursive = TRUE, force = TRUE)
}
ensure_dir_original288_syncedbase_rerun(paths$config_dir)

failed <- read_failed_source_status_original288_syncedbase_residual_repair()
utils::write.csv(failed, paths$fail_inventory, row.names = FALSE)

rows <- vector("list", nrow(failed))

for (i in seq_len(nrow(failed))) {
  row <- failed[i, , drop = FALSE]
  row$selected_fit_path <- row$source_reference_fit_path

  base_cfg <- readRDS(row$source_run_config_path)
  cfg <- build_selected_config_original288_syncedbase_rerun(base_cfg, row)
  cfg$sim_path <- row$sim_output_path
  cfg$out_root <- row$run_root
  cfg$cores_pipeline <- 1L

  selected_obj <- readRDS(row$source_reference_fit_path)
  selected_seed <- extract_selected_seed_original288_syncedbase_rerun(selected_obj, NA_integer_)

  cfg_path <- config_path_original288_syncedbase_residual_repair(row$row_id)
  ensure_dir_original288_syncedbase_rerun(dirname(cfg_path))
  saveRDS(cfg, cfg_path)

  candidate_fit_path <- candidate_fit_path_original288_syncedbase_residual_repair(
    row$run_root, row$inference, row$model, row$tau_label
  )
  vb_candidate_fit_path <- vb_candidate_fit_path_original288_syncedbase_residual_repair(
    row$run_root, row$model, row$tau_label
  )

  rows[[i]] <- data.frame(
    row_id = row$row_id,
    pair_id = row$pair_id,
    seed = selected_seed,
    status = "pending",
    phase = row$phase,
    phase_order = row$phase_order,
    missing_inputs = !file.exists(row$baseline_signoff_path) ||
      !file.exists(row$source_run_config_path) ||
      !file.exists(row$sim_output_path) ||
      !file.exists(row$source_reference_fit_path) ||
      !file.exists(row$vb_reference_fit_path),
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    tau_label = row$tau_label,
    fit_size = as.integer(row$fit_size),
    prior = row$prior_semantics,
    prior_semantics = row$prior_semantics,
    prior_override = prior_override_original288_syncedbase_rerun(cfg, row),
    inference = row$inference,
    model = row$model,
    method = row$method,
    original_scenario_key = row$original_scenario_key,
    original_case_key = row$original_case_key,
    accepted_gate = row$accepted_gate,
    accepted_healthy = row$accepted_healthy,
    selection_mode = row$selection_mode,
    selected_source_type = row$selected_source_type,
    selected_variant_tag = row$selected_variant_tag,
    run_root = row$run_root,
    run_config_path = cfg_path,
    sim_output_path = row$sim_output_path,
    baseline_signoff_path = row$baseline_signoff_path,
    baseline_fit_path = row$source_reference_fit_path,
    source_baseline_fit_path = row$source_baseline_fit_path,
    source_selected_fit_path = row$source_selected_fit_path,
    source_reference_fit_path = row$source_reference_fit_path,
    vb_reference_fit_path = row$vb_reference_fit_path,
    source_run_root = row$source_run_root,
    source_run_config_path = row$source_run_config_path,
    candidate_fit_path = candidate_fit_path,
    vb_candidate_fit_path = vb_candidate_fit_path,
    stringsAsFactors = FALSE
  )
}

manifest <- do.call(rbind, rows)
manifest <- manifest[order(
  manifest$phase_order,
  manifest$block,
  manifest$family,
  manifest$tau_label,
  manifest$fit_size,
  manifest$prior_override,
  manifest$model
), , drop = FALSE]
rownames(manifest) <- NULL

utils::write.csv(manifest, paths$manifest, row.names = FALSE)

stage_counts <- as.data.frame(table(manifest$phase), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(phase_order_original288_syncedbase_residual_repair[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

cat(sprintf("fail_inventory=%d\n", nrow(failed)))
cat(sprintf("manifest=%s\n", paths$manifest))
cat(sprintf("rows=%d\n", nrow(manifest)))
cat(sprintf("missing_inputs=%d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
