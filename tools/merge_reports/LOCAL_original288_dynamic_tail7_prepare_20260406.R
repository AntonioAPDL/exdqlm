#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tail7_helpers_20260406.R")

paths <- paths_dynamic_tail7_original288()
dir.create(dirname(paths$manifest), recursive = TRUE, showWarnings = FALSE)

config_dir <- file.path("tools", "merge_reports", "original288_dynamic_tail7_configs_20260406")
dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)

unresolved <- read_unresolved_dynamic_original288_dynamic_tail7()
vb_sel <- read_dynamic_vb_selection_original288_dynamic_tail7()
seed_map <- full288_seed_map_dynamic_tail7_original288()

if (nrow(unresolved) != 7L) {
  stop(sprintf("expected exactly 7 unresolved dynamic tail cases, found %d", nrow(unresolved)))
}

tau05_subset <- subset(unresolved, tau == "0p05")
if (nrow(tau05_subset) != 6L) {
  stop(sprintf("expected exactly 6 tau=0p05 unresolved tail cases, found %d", nrow(tau05_subset)))
}

vb_key <- paste(
  vb_sel$root_kind,
  vb_sel$family,
  vb_sel$tau,
  as.integer(vb_sel$fit_size),
  vb_sel$prior_semantics,
  vb_sel$model,
  sep = "::"
)
vb_sel$key <- vb_key

resolve_vb_path <- function(row) {
  key <- paste(
    row$root_kind[1],
    row$family[1],
    row$tau[1],
    as.integer(row$fit_size[1]),
    row$prior_semantics[1],
    row$model[1],
    sep = "::"
  )
  hit <- vb_sel$selected_fit_path[vb_sel$key == key]
  if (!length(hit)) return(NA_character_)
  normalize_path_original288(hit[1])
}

seed_for_key <- function(original_case_key, fallback_seed) {
  hit <- seed_map$seed_full288[seed_map$original_case_key == original_case_key]
  if (length(hit) && is.finite(hit[1])) return(as.integer(hit[1]))
  as.integer(fallback_seed)
}

variant_tag_for_config <- function(config_id) {
  switch(
    config_id,
    mcmc_exdqlm_slice_band18 = "orig288_dyn_tail7_slice_band18_20260406",
    mcmc_exdqlm_slice_band24 = "orig288_dyn_tail7_slice_band24_20260406",
    mcmc_exdqlm_slice_band18_long = "orig288_dyn_tail7_slice_band18_long_20260406",
    stop(sprintf("unknown config_id: %s", config_id))
  )
}

build_rows <- function(df, phase, config_id, seed_offset) {
  if (!nrow(df)) return(list())
  rows <- vector("list", nrow(df))
  for (i in seq_len(nrow(df))) {
    r <- df[i, , drop = FALSE]
    base_cfg <- readRDS(file.path(dirname(r$source_path[1]), "run_config.rds"))
    cfg_out <- apply_dynamic_tail7_config_original288(base_cfg, config_id)
    variant_tag <- variant_tag_for_config(config_id)
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
    vb_candidate_fit_path <- resolve_vb_path(r)
    rows[[i]] <- data.frame(
      row_id = NA_integer_,
      pair_id = paste(r$original_case_key[1], config_id, sep = "::"),
      seed = seed_for_key(r$original_case_key[1], seed_offset + i),
      status = "pending",
      missing_inputs = FALSE,
      block = "dynamic",
      phase = phase,
      phase_order = dynamic_tail7_phase_order_original288[phase],
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
      candidate_fit_path = build_candidate_fit_path_dynamic_tail7_original288(baseline_fit_path, variant_tag),
      source_signoff_path = normalize_path_original288(r$source_path[1]),
      candidate_variant_tag = variant_tag,
      evidence_gate = NA_character_,
      evidence_healthy = NA,
      evidence_source_type = "new_compute_targeted",
      evidence_source_path = normalize_path_original288(cfg_path),
      vb_candidate_fit_path = vb_candidate_fit_path,
      rationale = config_note_dynamic_tail7_original288(config_id),
      candidate_exists_prelaunch = FALSE,
      stringsAsFactors = FALSE
    )
  }
  rows
}

unresolved <- unresolved[order(
  unresolved$fit_size,
  unresolved$family,
  unresolved$tau,
  unresolved$model,
  unresolved$inference
), , drop = FALSE]
tau05_subset <- tau05_subset[order(
  tau05_subset$fit_size,
  tau05_subset$family,
  tau05_subset$tau,
  tau05_subset$model,
  tau05_subset$inference
), , drop = FALSE]

rows <- c(
  build_rows(unresolved, "anchor7_slice_band18", "mcmc_exdqlm_slice_band18", 2026046100L),
  build_rows(unresolved, "anchor7_slice_band24", "mcmc_exdqlm_slice_band24", 2026047100L),
  build_rows(tau05_subset, "tau05_long6_slice_band18", "mcmc_exdqlm_slice_band18_long", 2026048100L)
)

manifest <- rbind_fill_dynamic_tail7_original288(rows)
if (!nrow(manifest)) {
  stop("dynamic tail-7 manifest would be empty")
}

manifest$row_id <- seq_len(nrow(manifest))

manifest$missing_inputs <- !file.exists(manifest$run_root) |
  !file.exists(manifest$baseline_fit_path) |
  !file.exists(manifest$run_config_path) |
  !file.exists(manifest$sim_output_path) |
  !file.exists(manifest$source_signoff_path) |
  is.na(manifest$vb_candidate_fit_path) |
  !file.exists(manifest$vb_candidate_fit_path)

manifest <- manifest[order(
  manifest$phase_order,
  manifest$fit_size,
  manifest$family,
  manifest$tau_label,
  manifest$row_id
), , drop = FALSE]
rownames(manifest) <- NULL

stage_counts <- do.call(rbind, lapply(split(manifest, manifest$phase), function(df) {
  data.frame(
    phase = df$phase[1],
    total = nrow(df),
    vb_warmstarts_present = sum(!is.na(df$vb_candidate_fit_path) & file.exists(df$vb_candidate_fit_path)),
    missing_inputs = sum(df$missing_inputs),
    stringsAsFactors = FALSE
  )
}))
stage_counts <- stage_counts[order(dynamic_tail7_phase_order_original288[stage_counts$phase]), , drop = FALSE]

write.csv(manifest, paths$manifest, row.names = FALSE, na = "")
write.csv(stage_counts, paths$stage_counts, row.names = FALSE, na = "")

cat(sprintf("manifest=%s\n", paths$manifest))
cat(sprintf("stage_counts=%s\n", paths$stage_counts))
cat(sprintf("rows=%d\n", nrow(manifest)))
print(stage_counts, row.names = FALSE)
