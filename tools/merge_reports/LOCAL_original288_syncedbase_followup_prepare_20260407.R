#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_syncedbase_followup_helpers_20260407.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_syncedbase_followup()

ensure_dir_original288_syncedbase_rerun(dirname(paths$manifest))
if (dir.exists(dirname(paths$config_dir))) {
  unlink(dirname(paths$config_dir), recursive = TRUE, force = TRUE)
}
ensure_dir_original288_syncedbase_rerun(paths$config_dir)

source_status <- read_source_status_original288_syncedbase_followup()
queue <- subset(source_status, in_scope)
deferred <- read_deferred_unresolved_dynamic_original288_syncedbase_followup()

queue_out <- queue[, c(
  "row_id", "original_case_key", "block", "family", "tau_label", "fit_size",
  "prior_override", "model", "inference", "accepted_gate", "gate_current",
  "selected_variant_tag", "queue_group", "source_reference_fit_path",
  "source_selected_fit_path", "vb_reference_fit_path", "source_run_config_path",
  "sim_output_path"
)]
utils::write.csv(queue_out, paths$queue, row.names = FALSE)

if (nrow(deferred)) {
  deferred_out <- deferred[, c(
    "original_case_key", "block", "family", "tau", "fit_size", "prior_semantics",
    "model", "inference", "gate_overall", "selected_variant_tag", "queue_group",
    "in_scope"
  )]
} else {
  deferred_out <- data.frame()
}
utils::write.csv(deferred_out, paths$deferred, row.names = FALSE)

spec <- schedule_spec_original288_syncedbase_followup()
target_idx <- match(spec$target_case_key, source_status$original_case_key)
if (anyNA(target_idx)) {
  missing_keys <- unique(spec$target_case_key[is.na(target_idx)])
  stop(sprintf("Missing target cases in source status: %s", paste(missing_keys, collapse = ", ")))
}

resolved <- cbind(spec, source_status[target_idx, setdiff(names(source_status), c("queue_group", "in_scope")), drop = FALSE])

rows <- vector("list", nrow(resolved))
schedule_rows <- vector("list", nrow(resolved))

for (i in seq_len(nrow(resolved))) {
  spec_row <- resolved[i, , drop = FALSE]
  target_row <- source_status[source_status$original_case_key == spec_row$target_case_key[1], , drop = FALSE]
  stopifnot(nrow(target_row) == 1L)

  reference_fit_path <- reference_fit_path_original288_syncedbase_followup(
    target_row,
    spec_row$reference_basename[1]
  )
  base_cfg <- readRDS(target_row$source_run_config_path)

  cfg_row <- target_row
  cfg_row$selected_fit_path <- reference_fit_path
  cfg <- build_selected_config_original288_syncedbase_rerun(base_cfg, cfg_row)
  cfg <- apply_overrides_original288_syncedbase_followup(cfg, spec_row)
  cfg <- apply_prior_policy_original288_syncedbase_rerun(cfg, target_row)
  cfg$sim_path <- target_row$sim_output_path
  cfg$out_root <- target_row$run_root
  cfg$cores_pipeline <- 1L

  selected_obj <- readRDS(reference_fit_path)
  selected_seed <- extract_selected_seed_original288_syncedbase_rerun(selected_obj, NA_integer_)

  row_id <- i
  cfg_path <- config_path_original288_syncedbase_followup(row_id)
  ensure_dir_original288_syncedbase_rerun(dirname(cfg_path))
  saveRDS(cfg, cfg_path)

  candidate_fit_path <- candidate_fit_path_original288_syncedbase_followup(
    target_row$run_root,
    target_row$inference,
    target_row$model,
    target_row$tau_label,
    spec_row$candidate_label[1]
  )
  vb_candidate_fit_path <- vb_candidate_fit_path_original288_syncedbase_followup(
    target_row$run_root,
    target_row$model,
    target_row$tau_label,
    spec_row$candidate_label[1]
  )

  rows[[i]] <- data.frame(
    row_id = row_id,
    target_row_id = target_row$row_id,
    pair_id = sprintf("%s::%s", target_row$original_case_key, spec_row$candidate_label[1]),
    seed = selected_seed,
    status = "pending",
    phase = spec_row$phase[1],
    phase_order = unname(phase_order_original288_syncedbase_followup[spec_row$phase[1]]),
    missing_inputs = !file.exists(target_row$source_run_config_path) ||
      !file.exists(target_row$sim_output_path) ||
      !file.exists(reference_fit_path) ||
      !file.exists(target_row$vb_reference_fit_path),
    block = target_row$block,
    root_kind = target_row$root_kind,
    family = target_row$family,
    tau = target_row$tau,
    tau_label = target_row$tau_label,
    fit_size = as.integer(target_row$fit_size),
    prior = target_row$prior_semantics,
    prior_semantics = target_row$prior_semantics,
    prior_override = prior_override_original288_syncedbase_rerun(cfg, target_row),
    inference = target_row$inference,
    model = target_row$model,
    method = target_row$method,
    original_scenario_key = target_row$original_scenario_key,
    original_case_key = target_row$original_case_key,
    accepted_gate = target_row$accepted_gate,
    accepted_healthy = target_row$accepted_healthy,
    source_gate_current = target_row$gate_current,
    source_compare = target_row$accepted_compare,
    selection_mode = target_row$selection_mode,
    selected_source_type = target_row$selected_source_type,
    selected_variant_tag = target_row$selected_variant_tag,
    planned_candidate_label = spec_row$candidate_label[1],
    planned_reference_basename = safe_chr_original288_syncedbase_rerun(spec_row$reference_basename[1], basename(reference_fit_path)),
    planned_reason = spec_row$reason[1],
    run_root = target_row$run_root,
    run_config_path = cfg_path,
    sim_output_path = target_row$sim_output_path,
    baseline_signoff_path = target_row$baseline_signoff_path,
    baseline_fit_path = reference_fit_path,
    source_baseline_fit_path = target_row$source_baseline_fit_path,
    source_selected_fit_path = target_row$source_selected_fit_path,
    source_reference_fit_path = target_row$source_reference_fit_path,
    vb_reference_fit_path = target_row$vb_reference_fit_path,
    source_run_root = target_row$source_run_root,
    source_run_config_path = target_row$source_run_config_path,
    candidate_fit_path = candidate_fit_path,
    vb_candidate_fit_path = vb_candidate_fit_path,
    stringsAsFactors = FALSE
  )

  schedule_rows[[i]] <- data.frame(
    phase = spec_row$phase[1],
    candidate_label = spec_row$candidate_label[1],
    original_case_key = target_row$original_case_key,
    block = target_row$block,
    family = target_row$family,
    tau_label = target_row$tau_label,
    fit_size = target_row$fit_size,
    prior_semantics = target_row$prior_semantics,
    model = target_row$model,
    inference = target_row$inference,
    accepted_gate = target_row$accepted_gate,
    source_gate_current = target_row$gate_current,
    source_compare = target_row$accepted_compare,
    source_selected_variant_tag = target_row$selected_variant_tag,
    reference_fit_path = reference_fit_path,
    candidate_fit_path = candidate_fit_path,
    override_burn = spec_row$override_burn[1],
    override_n = spec_row$override_n[1],
    override_proposal = spec_row$override_proposal[1],
    override_joint_sample = spec_row$override_joint_sample[1],
    override_slice_width = spec_row$override_slice_width[1],
    override_slice_max_steps = spec_row$override_slice_max_steps[1],
    override_laplace_refresh_interval = spec_row$override_laplace_refresh_interval[1],
    override_laplace_refresh_start = spec_row$override_laplace_refresh_start[1],
    override_laplace_refresh_weight = spec_row$override_laplace_refresh_weight[1],
    reason = spec_row$reason[1],
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
  manifest$model,
  manifest$planned_candidate_label
), , drop = FALSE]
rownames(manifest) <- NULL

schedule <- do.call(rbind, schedule_rows)
schedule <- schedule[match(manifest$planned_candidate_label, schedule$candidate_label), , drop = FALSE]
rownames(schedule) <- NULL

utils::write.csv(schedule, paths$schedule, row.names = FALSE)
utils::write.csv(manifest, paths$manifest, row.names = FALSE)

stage_counts <- as.data.frame(table(manifest$phase), stringsAsFactors = FALSE)
names(stage_counts) <- c("phase", "rows")
stage_counts$phase_order <- unname(phase_order_original288_syncedbase_followup[stage_counts$phase])
stage_counts <- stage_counts[order(stage_counts$phase_order), c("phase", "rows"), drop = FALSE]
utils::write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

cat(sprintf("followup_queue=%d\n", nrow(queue_out)))
cat(sprintf("deferred_tail=%d\n", nrow(deferred_out)))
cat(sprintf("manifest=%s\n", paths$manifest))
cat(sprintf("rows=%d\n", nrow(manifest)))
cat(sprintf("missing_inputs=%d\n", sum(manifest$missing_inputs)))
cat("phase_counts:\n")
print(stage_counts, row.names = FALSE)
