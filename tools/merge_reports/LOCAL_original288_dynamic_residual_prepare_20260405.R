#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_residual_helpers_20260405.R")

paths <- paths_dynamic_residual_original288()
dir.create(dirname(paths$manifest), recursive = TRUE, showWarnings = FALSE)

config_dir <- file.path("tools", "merge_reports", "original288_dynamic_residual_configs_20260405")
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

unresolved <- read_unresolved_dynamic_original288_dynamic_residual()
harvested <- read_dynamic_harvest_candidates_original288()
archive_catalog <- build_archive_catalog_dynamic_residual_original288(unresolved, harvested)
seed_map <- full288_seed_map_dynamic_residual_original288()

write.csv(archive_catalog, paths$archive_catalog, row.names = FALSE, na = "")

seed_for_key <- function(original_case_key, fallback_seed) {
  hit <- seed_map$seed_full288[seed_map$original_case_key == original_case_key]
  if (length(hit) && is.finite(hit[1])) return(as.integer(hit[1]))
  as.integer(fallback_seed)
}

config_variant_tag <- function(config_id) {
  switch(
    config_id,
    vb_relaxed = "orig288_dyn_vb_relaxed_20260405",
    mcmc_dqlm_cppgig_refresh = "orig288_dyn_cppgig_refresh_20260405",
    mcmc_exdqlm_slice_short = "orig288_dyn_slice_short_20260405",
    mcmc_exdqlm_joint_long = "orig288_dyn_joint_long_20260405",
    stop(sprintf("unknown config_id: %s", config_id))
  )
}

build_candidate_fit_path <- function(baseline_fit_path, variant_tag) {
  sub("\\.rds$", paste0("_", variant_tag, ".rds"), baseline_fit_path)
}

rows <- list()
row_id <- 0L

archive_stage <- subset(archive_catalog, include_archive_stage)
if (nrow(archive_stage)) {
  archive_stage <- archive_stage[order(
    archive_stage$archive_priority,
    archive_stage$family,
    archive_stage$tau,
    archive_stage$fit_size,
    archive_stage$model,
    archive_stage$inference,
    archive_stage$candidate_variant_tag
  ), , drop = FALSE]
}

for (i in seq_len(nrow(archive_stage))) {
  row_id <- row_id + 1L
  r <- archive_stage[i, , drop = FALSE]
  rows[[row_id]] <- data.frame(
    row_id = row_id,
    pair_id = paste(r$original_case_key, r$candidate_variant_tag, sep = "::"),
    seed = seed_for_key(r$original_case_key, 2026040500L + row_id),
    status = "pending",
    missing_inputs = FALSE,
    block = "dynamic",
    phase = "archive_rescore_existing",
    phase_order = dynamic_residual_phase_order_original288["archive_rescore_existing"],
    config_id = "archive_existing",
    original_case_key = r$original_case_key,
    baseline_gate_overall = unresolved$baseline_gate_overall[match(r$original_case_key, unresolved$original_case_key)],
    root_kind = r$root_kind,
    family = r$family,
    tau = suppressWarnings(as.numeric(gsub("p", ".", r$tau, fixed = TRUE))),
    tau_label = r$tau,
    fit_size = as.integer(r$fit_size),
    prior = r$prior_semantics,
    prior_override = r$prior_semantics,
    inference = r$inference,
    model = r$model,
    method = paste(r$inference, r$model, sep = "::"),
    run_root = r$run_root,
    tables_dir = r$tables_dir,
    run_config_path = r$run_config_path,
    sim_output_path = r$sim_output_path,
    baseline_fit_path = r$baseline_fit_path,
    candidate_fit_path = r$candidate_fit_path,
    source_signoff_path = r$source_signoff_path,
    candidate_variant_tag = r$candidate_variant_tag,
    evidence_gate = r$evidence_gate,
    evidence_healthy = r$evidence_healthy,
    evidence_source_type = r$evidence_source_type,
    evidence_source_path = r$evidence_source_path,
    vb_candidate_fit_path = NA_character_,
    rationale = sprintf(
      "Archive rescore of existing candidate %s for unresolved original case %s.",
      r$candidate_variant_tag,
      r$original_case_key
    ),
    candidate_exists_prelaunch = file.exists(r$candidate_fit_path),
    stringsAsFactors = FALSE
  )
}

vb_lookup <- list()

repair_rows <- unresolved[order(
  unresolved$inference,
  unresolved$model,
  unresolved$fit_size,
  unresolved$family,
  unresolved$tau
), , drop = FALSE]

for (i in seq_len(nrow(repair_rows))) {
  r <- repair_rows[i, , drop = FALSE]
  config_id <- config_id_dynamic_residual_original288(r)
  phase <- if (identical(r$inference[1], "vb")) "vb_relaxed" else "mcmc_targeted"
  variant_tag <- config_variant_tag(config_id)
  base_cfg <- readRDS(file.path(dirname(r$source_path[1]), "run_config.rds"))
  cfg_out <- apply_dynamic_residual_config_original288(base_cfg, config_id)

  cfg_path <- file.path(
    config_dir,
    phase,
    sprintf(
      "%s_%s_tau%s_tt%s_%s.rds",
      r$model[1],
      r$family[1],
      r$tau[1],
      r$fit_size[1],
      config_id
    )
  )
  dir.create(dirname(cfg_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(cfg_out, cfg_path)

  baseline_fit_path <- normalize_path_original288(r$selected_fit_path[1])
  candidate_fit_path <- build_candidate_fit_path(baseline_fit_path, variant_tag)
  scenario_model_key <- paste(
    r$root_kind[1],
    r$family[1],
    r$tau[1],
    as.integer(r$fit_size[1]),
    r$prior_semantics[1],
    r$model[1],
    sep = "::"
  )
  if (identical(phase, "vb_relaxed")) {
    vb_lookup[[scenario_model_key]] <- normalize_path_original288(candidate_fit_path)
  }

  row_id <- row_id + 1L
  rows[[row_id]] <- data.frame(
    row_id = row_id,
    pair_id = paste(r$original_case_key[1], config_id, sep = "::"),
    seed = seed_for_key(r$original_case_key[1], 2026041500L + row_id),
    status = "pending",
    missing_inputs = FALSE,
    block = "dynamic",
    phase = phase,
    phase_order = dynamic_residual_phase_order_original288[phase],
    config_id = config_id,
    original_case_key = r$original_case_key[1],
    baseline_gate_overall = r$baseline_gate_overall[1],
    root_kind = r$root_kind[1],
    family = r$family[1],
    tau = suppressWarnings(as.numeric(gsub("p", ".", r$tau[1], fixed = TRUE))),
    tau_label = r$tau[1],
    fit_size = as.integer(r$fit_size[1]),
    prior = r$prior_semantics[1],
    prior_override = r$prior_semantics[1],
    inference = r$inference[1],
    model = r$model[1],
    method = r$method[1],
    run_root = normalize_path_original288(dirname(dirname(dirname(baseline_fit_path)))),
    tables_dir = normalize_path_original288(dirname(r$source_path[1])),
    run_config_path = normalize_path_original288(cfg_path),
    sim_output_path = normalize_path_original288(file.path(dirname(dirname(dirname(dirname(baseline_fit_path)))), "sim_output.rds")),
    baseline_fit_path = baseline_fit_path,
    candidate_fit_path = normalize_path_original288(candidate_fit_path),
    source_signoff_path = normalize_path_original288(r$source_path[1]),
    candidate_variant_tag = variant_tag,
    evidence_gate = NA_character_,
    evidence_healthy = NA,
    evidence_source_type = "new_compute_targeted",
    evidence_source_path = normalize_path_original288(cfg_path),
    vb_candidate_fit_path = NA_character_,
    rationale = config_note_dynamic_residual_original288(config_id),
    candidate_exists_prelaunch = file.exists(candidate_fit_path),
    stringsAsFactors = FALSE
  )
}

manifest <- rbind_fill_dynamic_residual_original288(rows)

if (!nrow(manifest)) {
  stop("dynamic residual manifest would be empty")
}

mcmc_long_idx <- manifest$phase == "mcmc_targeted" &
  manifest$model == "exdqlm" &
  manifest$fit_size == 5000L &
  manifest$tau_label == "0p05"

if (any(mcmc_long_idx)) {
  for (i in which(mcmc_long_idx)) {
    scenario_model_key <- paste(
      manifest$root_kind[i],
      manifest$family[i],
      manifest$tau_label[i],
      as.integer(manifest$fit_size[i]),
      manifest$prior[i],
      manifest$model[i],
      sep = "::"
    )
    if (!is.null(vb_lookup[[scenario_model_key]])) {
      manifest$vb_candidate_fit_path[i] <- vb_lookup[[scenario_model_key]]
    }
  }
}

manifest$missing_inputs <- !file.exists(manifest$run_root) |
  !file.exists(manifest$baseline_fit_path) |
  !file.exists(manifest$run_config_path) |
  !file.exists(manifest$sim_output_path) |
  !file.exists(manifest$source_signoff_path) |
  (manifest$phase == "archive_rescore_existing" & !file.exists(manifest$candidate_fit_path))

manifest <- manifest[order(
  manifest$phase_order,
  manifest$family,
  manifest$tau_label,
  manifest$fit_size,
  manifest$model,
  manifest$inference,
  manifest$config_id,
  manifest$row_id
), , drop = FALSE]
rownames(manifest) <- NULL

stage_counts <- do.call(rbind, lapply(split(manifest, manifest$phase), function(df) {
  data.frame(
    phase = df$phase[1],
    total = nrow(df),
    candidate_exists_prelaunch = sum(df$candidate_exists_prelaunch),
    missing_inputs = sum(df$missing_inputs),
    stringsAsFactors = FALSE
  )
}))
stage_counts <- stage_counts[order(dynamic_residual_phase_order_original288[stage_counts$phase]), , drop = FALSE]

write.csv(manifest, paths$manifest, row.names = FALSE, na = "")
write.csv(stage_counts, paths$stage_counts, row.names = FALSE, na = "")

cat(sprintf("manifest=%s\n", paths$manifest))
cat(sprintf("archive_catalog=%s\n", paths$archive_catalog))
cat(sprintf("stage_counts=%s\n", paths$stage_counts))
cat(sprintf("rows=%d\n", nrow(manifest)))
print(stage_counts, row.names = FALSE)
