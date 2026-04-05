#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
target_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_target_rows_20260404.csv")

if (!file.exists(target_rows_path)) {
  stop(sprintf("missing wave-4 target rows: %s", target_rows_path))
}

target_rows <- utils::read.csv(target_rows_path, stringsAsFactors = FALSE, check.names = FALSE)
target_rows <- target_rows[order(target_rows$scope_label, target_rows$row_id), , drop = FALSE]
target_key <- paste(target_rows$scope_label, target_rows$row_id, sep = "\r")

active_map_v4 <- data.frame(
  scope_label = c(
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "legacy_rhs_refresh",
    "legacy_rhs_refresh"
  ),
  row_id = c(87L, 115L, 135L, 174L, 190L, 206L, 278L, 181L, 269L),
  preferred_candidate = c(
    "F085_sub2_s1025_slice",
    "F0825_sub2_s100",
    "F0835_sub2_s1025",
    "F0875_sub2_s105",
    "F0825_sub2_s100_rwlong",
    "F0825_sub2_s1025_rwlong",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0825_sub2_s100"
  ),
  role = c(
    "warn_anchor_needs_confirmation",
    "stable_pass",
    "open_fail_anchor",
    "open_fail_anchor",
    "stable_warn",
    "stable_pass",
    "stable_pass",
    "stable_pass",
    "open_fail_anchor"
  ),
  best_read = c(
    "WARN",
    "PASS",
    "FAIL",
    "FAIL",
    "WARN",
    "PASS",
    "PASS",
    "PASS",
    "FAIL"
  ),
  evidence_note = c(
    "fresh wave-7 slice replay is the cleanest row-87 non-FAIL anchor",
    "durable repeated PASS anchor",
    "wave-7 showed longer-run midpoint fallback is not enough; best remaining lane is exact short replay plus vb-init probes",
    "wave-7 ruled out longer/slice widening around the exception corridor; exact short replay plus vb-init probes now dominate",
    "wave-7 long-run confirmation keeps row 190 at WARN",
    "wave-7 long-run confirmation upgraded row 206 to PASS",
    "stable repeated PASS anchor",
    "durable repeated PASS anchor",
    "repeated short-run WARN anchor is stronger than the wave-7 long/slice regressions"
  ),
  stringsAsFactors = FALSE
)

stability_rows <- data.frame(
  scope_label = "current_rhsns_refresh",
  row_id = 87L,
  stage = "stability1_warn87",
  stage_order = 1L,
  candidate_id = "R87_F085_sub2_s1025_slice_replay",
  geometry_candidate = "F085_sub2_s1025",
  variant_prefix = "repairmap8",
  gamma_substeps = 2L,
  p_global_eta_jump = 0.0850,
  global_eta_jump_scale = 1.025,
  n_burn = 4000L,
  n_mcmc = 2000L,
  thin = 1L,
  mh_proposal = "slice_eta",
  mh_adapt = "false",
  slice_width = 0.20,
  slice_max_steps = 120L,
  init_mode = "baseline_last",
  target_outcome = "WARN_OR_BETTER",
  selection_reason = "row 87 freshest non-FAIL anchor from wave-7; one confirmation only because the remaining closure debt is elsewhere",
  stringsAsFactors = FALSE
)

core_rows <- data.frame(
  scope_label = c(
    rep("current_rhsns_refresh", 4L),
    rep("current_rhsns_refresh", 4L),
    rep("legacy_rhs_refresh", 4L)
  ),
  row_id = c(
    rep(135L, 4L),
    rep(174L, 4L),
    rep(269L, 4L)
  ),
  stage = "core12_seedinit",
  stage_order = 2L,
  candidate_id = c(
    "R135_F0835_sub2_s1025_short",
    "R135_F0835_sub2_s1025_vb",
    "R135_F0825_sub2_s105_vb",
    "R135_F0840_sub2_s1025_vb",
    "R174_F0875_sub2_s105_short",
    "R174_F0875_sub2_s105_vb",
    "R174_F0845_sub2_s100_vb",
    "R174_F0835_sub2_s1025_vb",
    "R269_F0825_sub2_s100_short",
    "R269_F0825_sub2_s100_vb",
    "R269_F0825_sub2_s1025_vb",
    "R269_F0845_sub2_s100_vb"
  ),
  geometry_candidate = c(
    "F0835_sub2_s1025",
    "F0835_sub2_s1025",
    "F0825_sub2_s105",
    "F0840_sub2_s1025",
    "F0875_sub2_s105",
    "F0875_sub2_s105",
    "F0845_sub2_s100",
    "F0835_sub2_s1025",
    "F0825_sub2_s100",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0845_sub2_s100"
  ),
  variant_prefix = "rowfix8",
  gamma_substeps = 2L,
  p_global_eta_jump = c(
    0.0835, 0.0835, 0.0825, 0.0840,
    0.0875, 0.0875, 0.0845, 0.0835,
    0.0825, 0.0825, 0.0825, 0.0845
  ),
  global_eta_jump_scale = c(
    1.025, 1.025, 1.050, 1.025,
    1.050, 1.050, 1.000, 1.025,
    1.000, 1.000, 1.025, 1.000
  ),
  n_burn = 2000L,
  n_mcmc = 1000L,
  thin = 1L,
  mh_proposal = "laplace_rw",
  mh_adapt = "true",
  slice_width = 0.12,
  slice_max_steps = 80L,
  init_mode = c(
    "baseline_last", "vb", "vb", "vb",
    "baseline_last", "vb", "vb", "vb",
    "baseline_last", "vb", "vb", "vb"
  ),
  target_outcome = "WARN_OR_BETTER",
  selection_reason = c(
    "row 135 exact short replay of the strongest surviving broad-bridge anchor",
    "row 135 strongest anchor with vb init because longer baseline-last replay regressed in wave-7",
    "row 135 historical PASS anchor retested only under vb init",
    "row 135 freshest midpoint WARN anchor, but now with vb init instead of longer baseline-last reuse",
    "row 174 exact short replay of the lone repeated non-FAIL exception anchor",
    "row 174 same exception anchor with vb init because wave-7 longer/slice variants regressed",
    "row 174 lower-mid rescue anchor retested only under vb init",
    "row 174 surviving lower-mid comparator under vb init",
    "row 269 exact short replay of the strongest repeated legacy WARN anchor",
    "row 269 strongest repeated legacy anchor with vb init",
    "row 269 nearby repeated legacy WARN anchor with vb init",
    "row 269 upper-mid legacy fallback with vb init instead of another long/slice rerun"
  ),
  stringsAsFactors = FALSE
)

materialize_rows <- function(mapping, seed_base) {
  map_key <- paste(mapping$scope_label, mapping$row_id, sep = "\r")
  idx <- match(map_key, target_key)
  if (anyNA(idx)) {
    stop(sprintf("failed to match %d mapped rows into target_rows", sum(is.na(idx))))
  }
  block <- target_rows[idx, , drop = FALSE]
  for (nm in names(mapping)) {
    if (!(nm %in% c("scope_label", "row_id"))) block[[nm]] <- mapping[[nm]]
  }
  block$seed_wave8 <- seed_base + seq_len(nrow(block))
  block
}

stability_block <- materialize_rows(stability_rows, 2026087000L)
core_block <- materialize_rows(core_rows, 2026088000L)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule <- rbind(stability_block, core_block)
schedule$variant_tag <- sprintf("%s_%s", schedule$variant_prefix, schedule$candidate_id)
schedule$candidate_path <- mapply(resolve_candidate_path, schedule$run_root, schedule$tau, schedule$variant_tag, USE.NAMES = FALSE)
schedule <- schedule[order(schedule$stage_order, schedule$scope_label, schedule$row_id, schedule$candidate_id), , drop = FALSE]

baseline_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave8_baseline_map_v4_20260405.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave8_stage_counts_20260405.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave8_candidate_counts_20260405.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave8_schedule_20260405.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave8_rows_20260405.tsv")

stage_counts <- data.frame(
  stage = c("stability1_warn87", "core12_seedinit"),
  n_rows = c(nrow(stability_block), nrow(core_block)),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$geometry_candidate), stringsAsFactors = FALSE)
names(candidate_counts) <- c("geometry_candidate", "n_rows")
candidate_counts <- candidate_counts[order(-candidate_counts$n_rows, candidate_counts$geometry_candidate), , drop = FALSE]

utils::write.csv(active_map_v4, baseline_map_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)

tsv_cols <- c(
  "stage", "candidate_id", "geometry_candidate", "scope_label", "row_id",
  "run_root", "family_scope", "family", "tt", "tau", "variant_tag",
  "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
  "seed_wave8", "mcmc_base_path", "run_config_path", "prior_template_path",
  "expected_prior_override", "n_burn", "n_mcmc", "thin", "mh_proposal",
  "mh_adapt", "slice_width", "slice_max_steps", "init_mode", "candidate_path"
)
write.table(
  schedule[, tsv_cols, drop = FALSE],
  file = rows_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("Wrote baseline map: %s\n", baseline_map_path))
cat(sprintf("Wrote schedule: %s\n", schedule_path))
cat(sprintf("Wrote launch rows: %s\n", rows_tsv))
cat("STAGE_COUNTS\n")
print(stage_counts, row.names = FALSE)
cat("CANDIDATE_COUNTS\n")
print(candidate_counts, row.names = FALSE)
