#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_helpers_20260415.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_dynamic_tt5000_postfix_repair()

run_dir <- paths$run_root
if (dir.exists(run_dir)) {
  unlink(run_dir, recursive = TRUE, force = TRUE)
}

for (path in c(
  paths$run_root,
  paths$config_dir,
  paths$rows_dir,
  paths$health_dir,
  paths$metrics_dir,
  paths$draws_dir,
  paths$logs_dir,
  dirname(paths$plan_doc),
  dirname(paths$comparison_report)
)) {
  ensure_dir_original288_dynamic_tt5000_postfix_repair(path)
}

current_selection <- read_current_selection_targets_original288_dynamic_tt5000_postfix_repair()
baseline_selection <- read_baseline_selection_original288_dynamic_tt5000_postfix_repair()
baseline_subset <- baseline_selection[match(current_selection$original_case_key, baseline_selection$original_case_key), , drop = FALSE]

if (anyNA(baseline_subset$original_case_key)) {
  stop("Baseline selection lookup failed for one or more dynamic TT5000 target rows.")
}

vb_lookup <- baseline_dynamic_vb_lookup_original288_dynamic_tt5000_postfix_repair(baseline_selection)
registry <- phase1_source_registry_original288_dynamic_tt5000_postfix_repair()

phase1_audit_rows <- vector("list", nrow(current_selection))
phase1_rows <- vector("list", nrow(current_selection))
seedbank_rows <- vector("list", nrow(current_selection))
next_row_id <- 1L

for (i in seq_len(nrow(current_selection))) {
  target_row <- current_selection[i, , drop = FALSE]
  baseline_row <- baseline_subset[i, , drop = FALSE]
  resolved <- resolve_phase1_source_row_original288_dynamic_tt5000_postfix_repair(
    target_row = target_row,
    baseline_row = baseline_row,
    registry = registry
  )

  vb_ref <- vb_lookup[
    vb_lookup$original_scenario_key == baseline_row$original_scenario_key &
      vb_lookup$model == baseline_row$model,
    ,
    drop = FALSE
  ]
  vb_reference_fit_path <- if (nrow(vb_ref)) {
    resolve_existing_path_original288_dynamic_tt5000_postfix_repair(vb_ref$selected_fit_path[1])
  } else {
    NA_character_
  }
  if (is.na(vb_reference_fit_path) || !nzchar(vb_reference_fit_path)) {
    vb_case_key <- sprintf(
      "%s::%s",
      baseline_row$original_scenario_key,
      "vb"
    )
    vb_match <- registry[registry$original_case_key == paste(
      baseline_row$block,
      baseline_row$family,
      baseline_row$tau,
      baseline_row$fit_size,
      baseline_row$prior_semantics,
      baseline_row$model,
      "vb",
      sep = "::"
    ), , drop = FALSE]
    if (nrow(vb_match)) {
      vb_reference_fit_path <- vb_match$candidate_fit_path_resolved[1]
    }
  }

  base_seed <- base_seed_from_source_original288_dynamic_tt5000_postfix_repair(
    source_row = resolved,
    fallback_fit_path = baseline_row$selected_fit_path,
    original_case_key = baseline_row$original_case_key
  )
  seedbank <- seedbank_for_base_row_original288_dynamic_tt5000_postfix_repair(
    base_seed = base_seed,
    base_row_id = target_row$base_row_id,
    original_case_key = target_row$original_case_key
  )
  seedbank$row_id <- seq.int(next_row_id, length.out = nrow(seedbank))
  next_row_id <- max(seedbank$row_id) + 1L
  seedbank_rows[[i]] <- seedbank

  src <- data.frame(
    base_row_id = target_row$base_row_id,
    original_case_key = target_row$original_case_key,
    block = baseline_row$block,
    root_kind = baseline_row$root_kind,
    family = baseline_row$family,
    tau = baseline_row$tau,
    tau_label = baseline_row$tau,
    fit_size = baseline_row$fit_size,
    prior_semantics = baseline_row$prior_semantics,
    model = baseline_row$model,
    inference = baseline_row$inference,
    run_root = resolved$run_root,
    run_config_path = resolved$run_config_path,
    sim_output_path = dynamic_source_context_original288_normalized_multiseed(baseline_row)$materialized_sim_output_path,
    source_run_root = resolved$source_run_root,
    stringsAsFactors = FALSE
  )

  phase1_rows[[i]] <- build_manifest_rows_original288_dynamic_tt5000_postfix_repair(
    seedbank = seedbank,
    source_rows = src,
    candidate_label = "exact_accepted_source",
    phase = "phase1_dynamic_tt5000_exact_replay",
    candidate_source_type = "accepted_selected_fit_exact_source",
    candidate_source_subtype = resolved$source_registry_source[1],
    reference_gate = target_row$gate_overall[1],
    accepted_baseline_gate = baseline_row$gate_overall[1],
    vb_reference_fit_path = vb_reference_fit_path,
    source_reference_fit_path = resolved$reference_fit_path[1],
    source_selected_variant_tag = baseline_row$selected_variant_tag[1],
    source_rank = 0L
  )

  phase1_audit_rows[[i]] <- data.frame(
    base_row_id = target_row$base_row_id,
    original_case_key = target_row$original_case_key,
    current_gate = target_row$gate_overall,
    baseline_gate = baseline_row$gate_overall,
    current_selected_fit_path = target_row$selected_fit_path,
    baseline_selected_fit_path = baseline_row$selected_fit_path,
    source_registry_source = resolved$source_registry_source[1],
    source_selected_fit_path = resolved$source_selected_fit_path[1],
    run_config_path = resolved$run_config_path[1],
    run_config_exists = file.exists(resolved$run_config_path[1]),
    sim_output_path = resolved$sim_output_path[1],
    sim_output_exists = file.exists(resolved$sim_output_path[1]),
    vb_reference_fit_path = vb_reference_fit_path,
    vb_reference_exists = ifelse(is.na(vb_reference_fit_path) || !nzchar(vb_reference_fit_path), TRUE, file.exists(vb_reference_fit_path)),
    reference_fit_path = resolved$reference_fit_path[1],
    reference_fit_exists = ifelse(is.na(resolved$reference_fit_path[1]) || !nzchar(resolved$reference_fit_path[1]), FALSE, file.exists(resolved$reference_fit_path[1])),
    base_seed = base_seed,
    stringsAsFactors = FALSE
  )
}

phase1_manifest <- do.call(rbind, phase1_rows)
phase1_manifest <- phase1_manifest[order(phase1_manifest$row_id), , drop = FALSE]
phase1_audit <- do.call(rbind, phase1_audit_rows)
seedbank_all <- do.call(rbind, seedbank_rows)

utils::write.csv(phase1_manifest, paths$phase1_manifest, row.names = FALSE)
utils::write.csv(phase1_audit, paths$phase1_source_audit, row.names = FALSE)
utils::write.csv(seedbank_all, file.path(dirname(paths$phase1_source_audit), "LOCAL_original288_dynamic_tt5000_postfix_repair_seedbank_20260415.csv"), row.names = FALSE)
write_stage_counts_original288_dynamic_tt5000_postfix_repair(phase1_manifest, paths$phase1_stage_counts)

phase2_inventory <- read_phase2_candidate_pool_original288_dynamic_tt5000_postfix_repair(
  target_rows = current_selection,
  baseline_rows = baseline_subset
)
if (nrow(phase2_inventory)) {
  phase2_inventory$base_row_id <- current_selection$base_row_id[match(phase2_inventory$original_case_key, current_selection$original_case_key)]
}
utils::write.csv(phase2_inventory, paths$phase2_candidate_inventory, row.names = FALSE)

empty_phase2_manifest <- phase1_manifest[0, , drop = FALSE]
utils::write.csv(empty_phase2_manifest, paths$phase2_manifest, row.names = FALSE)
utils::write.csv(phase1_manifest, paths$full_manifest, row.names = FALSE)
write_stage_counts_original288_dynamic_tt5000_postfix_repair(empty_phase2_manifest, paths$phase2_stage_counts)

cat(sprintf("target_rows=%d\n", nrow(current_selection)))
cat(sprintf("phase1_rows=%d\n", nrow(phase1_manifest)))
cat(sprintf("phase2_historical_candidates=%d\n", nrow(phase2_inventory)))
cat(sprintf("missing_inputs_phase1=%d\n", sum(phase1_manifest$missing_inputs)))
