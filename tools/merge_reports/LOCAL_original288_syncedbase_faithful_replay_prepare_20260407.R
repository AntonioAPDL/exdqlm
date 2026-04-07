#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_syncedbase_faithful_replay_helpers_20260407.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_syncedbase_rerun()

ensure_dir_original288_syncedbase_rerun(dirname(paths$manifest))
if (dir.exists(dirname(paths$config_dir))) {
  unlink(dirname(paths$config_dir), recursive = TRUE, force = TRUE)
}
ensure_dir_original288_syncedbase_rerun(paths$config_dir)

accepted <- read_accepted_selection_original288_syncedbase_rerun()
validate_reference_status_original288_syncedbase_rerun(accepted)

source_registry <- read_source_registry_original288_syncedbase_rerun()
utils::write.csv(source_registry, paths$source_registry, row.names = FALSE)

merged <- merge(
  accepted,
  source_registry[, c("original_case_key", "baseline_signoff_path", "baseline_fit_path")],
  by = "original_case_key",
  all.x = TRUE,
  suffixes = c("", "_source")
)

if (anyNA(merged$baseline_signoff_path_source) || anyNA(merged$baseline_fit_path_source)) {
  stop("Source registry merge failed for one or more accepted rows.")
}

accepted_vb <- accepted[accepted$inference == "vb", c("original_scenario_key", "model", "selected_fit_path"), drop = FALSE]
names(accepted_vb)[names(accepted_vb) == "selected_fit_path"] <- "vb_reference_fit_path"
merged <- merge(
  merged,
  accepted_vb,
  by = c("original_scenario_key", "model"),
  all.x = TRUE
)

merged$source_reference_fit_path <- merged$selected_fit_path
merged$phase <- mapply(
  expected_phase_original288_syncedbase_rerun,
  merged$inference,
  merged$root_kind,
  merged$prior_semantics,
  USE.NAMES = FALSE
)
merged$phase_order <- unname(phase_order_original288_syncedbase_rerun[merged$phase])
merged <- merged[order(
  merged$phase_order,
  merged$root_kind,
  merged$family,
  merged$tau_label,
  merged$fit_size,
  merged$prior_semantics,
  merged$model,
  merged$inference
), , drop = FALSE]
rownames(merged) <- NULL
merged$row_id <- seq_len(nrow(merged))

rows <- vector("list", nrow(merged))

for (i in seq_len(nrow(merged))) {
  row <- merged[i, , drop = FALSE]
  source_ctx <- source_context_from_signoff_original288_syncedbase_rerun(row$baseline_signoff_path_source)
  base_cfg <- readRDS(source_ctx$source_run_config_path)
  cfg <- build_selected_config_original288_syncedbase_rerun(base_cfg, row)
  cfg$sim_path <- source_ctx$source_sim_output_path
  cfg$out_root <- target_run_root_original288_syncedbase_rerun(source_ctx$source_run_root, repo_root)
  cfg$cores_pipeline <- 1L
  selected_obj <- readRDS(row$source_reference_fit_path)
  selected_seed <- extract_selected_seed_original288_syncedbase_rerun(selected_obj, NA_integer_)

  cfg_path <- config_path_original288_syncedbase_rerun(row$row_id)
  ensure_dir_original288_syncedbase_rerun(dirname(cfg_path))
  saveRDS(cfg, cfg_path)

  target_run_root <- target_run_root_original288_syncedbase_rerun(source_ctx$source_run_root, repo_root)
  candidate_fit_path <- candidate_fit_path_original288_syncedbase_rerun(target_run_root, row$inference, row$model, row$tau_label)
  vb_candidate_fit_path <- vb_candidate_fit_path_original288_syncedbase_rerun(target_run_root, row$model, row$tau_label)

  rows[[i]] <- data.frame(
    row_id = row$row_id,
    pair_id = paste(row$original_scenario_key, row$model, sep = "::"),
    seed = selected_seed,
    status = "pending",
    phase = row$phase,
    phase_order = row$phase_order,
    missing_inputs = !file.exists(source_ctx$baseline_signoff_path) ||
      !file.exists(source_ctx$source_run_config_path) ||
      !file.exists(source_ctx$source_sim_output_path) ||
      !file.exists(row$source_reference_fit_path) ||
      (identical(row$inference, "mcmc") && !file.exists(row$vb_reference_fit_path)),
    block = row$block,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau_num,
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
    accepted_gate = row$gate_overall,
    accepted_healthy = isTRUE(row$healthy),
    selection_mode = row$selection_mode,
    selected_source_type = row$selected_source_type,
    selected_variant_tag = row$selected_variant_tag,
    run_root = target_run_root,
    run_config_path = cfg_path,
    sim_output_path = source_ctx$source_sim_output_path,
    baseline_signoff_path = source_ctx$baseline_signoff_path,
    baseline_fit_path = row$source_reference_fit_path,
    source_baseline_fit_path = row$baseline_fit_path_source,
    source_selected_fit_path = row$selected_fit_path,
    source_reference_fit_path = row$source_reference_fit_path,
    vb_reference_fit_path = if (identical(row$inference, "mcmc")) row$vb_reference_fit_path else row$selected_fit_path,
    source_run_root = source_ctx$source_run_root,
    source_run_config_path = source_ctx$source_run_config_path,
    candidate_fit_path = candidate_fit_path,
    vb_candidate_fit_path = if (identical(row$inference, "mcmc")) vb_candidate_fit_path else NA_character_,
    stringsAsFactors = FALSE
  )
}

manifest <- do.call(rbind, rows)
manifest <- manifest[order(
  manifest$phase_order,
  manifest$root_kind,
  manifest$family,
  manifest$tau_label,
  manifest$fit_size,
  manifest$prior_semantics,
  manifest$model,
  manifest$inference
), , drop = FALSE]
rownames(manifest) <- NULL
manifest$row_id <- seq_len(nrow(manifest))
manifest$pair_id <- paste(manifest$original_scenario_key, manifest$model, sep = "::")

for (i in seq_len(nrow(manifest))) {
  new_cfg_path <- config_path_original288_syncedbase_rerun(manifest$row_id[i])
  old_cfg_path <- manifest$run_config_path[i]
  if (!identical(old_cfg_path, new_cfg_path)) {
    cfg <- readRDS(old_cfg_path)
    saveRDS(cfg, new_cfg_path)
    unlink(old_cfg_path)
    manifest$run_config_path[i] <- new_cfg_path
  }
}

utils::write.csv(manifest, paths$manifest, row.names = FALSE)

stage_counts <- as.data.frame(with(manifest, table(phase)), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(phase_order_original288_syncedbase_rerun[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

cat(sprintf("accepted_reference: healthy=%d total=%d fail=%d\n",
            reference_status_original288_syncedbase_rerun()$healthy,
            reference_status_original288_syncedbase_rerun()$total,
            reference_status_original288_syncedbase_rerun()$fail))
cat(sprintf("manifest: %s\n", paths$manifest))
cat(sprintf("source_registry: %s\n", paths$source_registry))
cat(sprintf("rows: %d\n", nrow(manifest)))
cat(sprintf("missing_inputs: %d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
