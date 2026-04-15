#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_helpers_20260415.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
paths <- paths_original288_dynamic_tt5000_postfix_repair()

phase1_manifest <- read.csv(paths$phase1_manifest, stringsAsFactors = FALSE, check.names = FALSE)
phase1_selected <- read.csv(paths$full_selected, stringsAsFactors = FALSE, check.names = FALSE)
phase2_inventory <- read.csv(paths$phase2_candidate_inventory, stringsAsFactors = FALSE, check.names = FALSE)
baseline_selection <- read_baseline_selection_original288_dynamic_tt5000_postfix_repair()
vb_lookup <- baseline_dynamic_vb_lookup_original288_dynamic_tt5000_postfix_repair(baseline_selection)

unresolved <- subset(phase1_selected, gate_current == "FAIL")

empty_manifest <- phase1_manifest[0, , drop = FALSE]
if (!nrow(unresolved) || !nrow(phase2_inventory)) {
  utils::write.csv(empty_manifest, paths$phase2_manifest, row.names = FALSE)
  utils::write.csv(phase1_manifest, paths$full_manifest, row.names = FALSE)
  write_stage_counts_original288_dynamic_tt5000_postfix_repair(empty_manifest, paths$phase2_stage_counts)
  cat("phase2_rows=0\n")
  quit(save = "no", status = 0)
}

phase2_inventory <- subset(phase2_inventory, source_resolved)
phase2_inventory <- phase2_inventory[phase2_inventory$original_case_key %in% unresolved$original_case_key, , drop = FALSE]

if (!nrow(phase2_inventory)) {
  utils::write.csv(empty_manifest, paths$phase2_manifest, row.names = FALSE)
  utils::write.csv(phase1_manifest, paths$full_manifest, row.names = FALSE)
  write_stage_counts_original288_dynamic_tt5000_postfix_repair(empty_manifest, paths$phase2_stage_counts)
  cat("phase2_rows=0\n")
  quit(save = "no", status = 0)
}

phase2_inventory$candidate_rank_within_case <- ave(
  seq_len(nrow(phase2_inventory)),
  phase2_inventory$original_case_key,
  FUN = seq_along
)
phase2_inventory <- subset(phase2_inventory, candidate_rank_within_case <= 3L)
phase2_inventory <- phase2_inventory[order(
  phase2_inventory$original_case_key,
  phase2_inventory$candidate_rank_within_case
), , drop = FALSE]

next_row_id <- max(phase1_manifest$row_id) + 1L
phase2_rows <- vector("list", nrow(phase2_inventory))

for (i in seq_len(nrow(phase2_inventory))) {
  cand <- phase2_inventory[i, , drop = FALSE]
  vb_ref <- vb_lookup[
    vb_lookup$original_scenario_key == cand$original_scenario_key &
      vb_lookup$model == cand$model,
    ,
    drop = FALSE
  ]
  vb_reference_fit_path <- if (!is.na(cand$hist_vb_path[1]) && nzchar(cand$hist_vb_path[1])) {
    cand$hist_vb_path[1]
  } else if (nrow(vb_ref)) {
    resolve_existing_path_original288_dynamic_tt5000_postfix_repair(vb_ref$selected_fit_path[1])
  } else {
    NA_character_
  }

  src <- data.frame(
    base_row_id = cand$base_row_id,
    original_case_key = cand$original_case_key,
    block = cand$block,
    root_kind = "dynamic",
    family = cand$family,
    tau = cand$tau,
    tau_label = cand$tau,
    fit_size = cand$fit_size,
    prior_semantics = cand$prior_semantics,
    model = cand$model,
    inference = cand$inference,
    run_root = map_to_current_repo_root_original288_dynamic_tt5000_postfix_repair(sub("/fits/.*$", "", cand$selected_fit_path)),
    run_config_path = cand$run_config_path,
    sim_output_path = dynamic_source_context_original288_normalized_multiseed(cand)$materialized_sim_output_path,
    source_run_root = cand$source_run_root %||% dirname(dirname(cand$run_config_path)),
    historical_source_kind = cand$historical_source_kind,
    phase1_registry_source = cand$phase1_registry_source,
    hist_mh_proposal = cand$hist_mh_proposal,
    hist_mh_adapt = cand$hist_mh_adapt,
    hist_laplace_refresh_interval = cand$hist_laplace_refresh_interval,
    hist_laplace_refresh_start = cand$hist_laplace_refresh_start,
    hist_laplace_refresh_weight = cand$hist_laplace_refresh_weight,
    hist_slice_width = cand$hist_slice_width,
    hist_slice_max_steps = cand$hist_slice_max_steps,
    hist_n_burn = cand$hist_n_burn,
    hist_n_mcmc = cand$hist_n_mcmc,
    hist_trace_every = cand$hist_trace_every,
    hist_progress_every = cand$hist_progress_every,
    hist_init_from_vb_requested = cand$hist_init_from_vb_requested,
    hist_init_from_vb = cand$hist_init_from_vb,
    hist_vb_path = cand$hist_vb_path,
    hist_baseline_fit_path = cand$hist_baseline_fit_path,
    stringsAsFactors = FALSE
  )

  base_seed <- base_seed_from_source_original288_dynamic_tt5000_postfix_repair(
    source_row = cand,
    fallback_fit_path = cand$selected_fit_path,
    original_case_key = cand$original_case_key
  )
  seedbank <- seedbank_for_base_row_original288_dynamic_tt5000_postfix_repair(
    base_seed = base_seed,
    base_row_id = cand$base_row_id,
    original_case_key = cand$original_case_key
  )
  seedbank$row_id <- seq.int(next_row_id, length.out = nrow(seedbank))
  next_row_id <- max(seedbank$row_id) + 1L

  candidate_label <- sprintf(
    "hist_%02d_%s",
    cand$candidate_rank_within_case,
    sanitize_candidate_label_original288_dynamic_tt5000_postfix_repair(cand$selected_variant_tag)
  )
  phase2_rows[[i]] <- build_manifest_rows_original288_dynamic_tt5000_postfix_repair(
    seedbank = seedbank,
    source_rows = src,
    candidate_label = candidate_label,
    phase = "phase2_dynamic_tt5000_historical_repair",
    candidate_source_type = cand$candidate_source_type[1],
    candidate_source_subtype = cand$candidate_source_subtype[1],
    reference_gate = "FAIL",
    accepted_baseline_gate = "FAIL",
    vb_reference_fit_path = vb_reference_fit_path,
    source_reference_fit_path = cand$reference_fit_path[1],
    source_selected_variant_tag = cand$selected_variant_tag[1],
    source_rank = cand$source_rank[1]
  )
}

phase2_manifest <- do.call(rbind, phase2_rows)
phase2_manifest <- phase2_manifest[order(phase2_manifest$row_id), , drop = FALSE]
full_manifest <- rbind(phase1_manifest, phase2_manifest)
full_manifest <- full_manifest[order(full_manifest$phase_order, full_manifest$row_id), , drop = FALSE]

utils::write.csv(phase2_manifest, paths$phase2_manifest, row.names = FALSE)
utils::write.csv(full_manifest, paths$full_manifest, row.names = FALSE)
write_stage_counts_original288_dynamic_tt5000_postfix_repair(phase2_manifest, paths$phase2_stage_counts)

cat(sprintf("unresolved_after_phase1=%d\n", nrow(unresolved)))
cat(sprintf("phase2_rows=%d\n", nrow(phase2_manifest)))
