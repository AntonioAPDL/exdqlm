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

active_map_v8 <- data.frame(
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
    "open_lowermid_row87_corridor",
    "F0825_sub2_s100",
    "F0825_sub2_s105_none",
    "F085_sub2_s105_histshort",
    "F0825_sub2_s100_rwlong",
    "F0825_sub2_s1025_rwlong",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0845_sub2_s100_histshort"
  ),
  role = c(
    "remaining_blocker",
    "stable_pass",
    "promoted_pass",
    "promoted_warn",
    "stable_warn",
    "promoted_pass",
    "stable_pass",
    "stable_pass",
    "promoted_warn"
  ),
  best_read = c(
    "FAIL",
    "PASS",
    "PASS",
    "WARN",
    "WARN",
    "PASS",
    "PASS",
    "PASS",
    "WARN"
  ),
  evidence_note = c(
    "wave-10 exhausted the late F085/F0855 micro-band, but the row-87 historical non-FAIL anchors also include the lower-mid F0825/F0835 laplace_rw short-run corridor",
    "durable repeated PASS anchor",
    "wave-9 promoted row-135 PASS under init_mode=none",
    "wave-9 promoted row-174 WARN under exact historical short replay",
    "durable non-FAIL stability anchor",
    "fresh PASS anchor from wave-7",
    "stable repeated PASS anchor",
    "durable repeated PASS anchor",
    "wave-9 promoted row-269 WARN under exact historical short replay"
  ),
  stringsAsFactors = FALSE
)

row87_profiles <- data.frame(
  scope_label = rep("current_rhsns_refresh", 11L),
  row_id = rep(87L, 11L),
  stage = c(
    rep("anchor4_short_hist", 4L),
    rep("confirm4_medium", 4L),
    rep("none3_lowermid", 3L)
  ),
  stage_order = c(rep(1L, 4L), rep(2L, 4L), rep(3L, 3L)),
  candidate_id = c(
    "R87_F0825_sub2_s100_histshort_seed2026071087",
    "R87_F0825_sub2_s1025_histshort_seed2026072087",
    "R87_F0835_sub2_s1025_histshort_seed2026074087",
    "R87_F085_sub2_s1025_histshort_seed2026079087",
    "R87_F0825_sub2_s100_medium_seed2026111087",
    "R87_F0825_sub2_s1025_medium_seed2026112087",
    "R87_F0835_sub2_s1025_medium_seed2026113087",
    "R87_F085_sub2_s1025_medium_seed2026114087",
    "R87_F0825_sub2_s100_none_seed2026115087",
    "R87_F0825_sub2_s1025_none_seed2026116087",
    "R87_F0835_sub2_s1025_none_seed2026117087"
  ),
  geometry_candidate = c(
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0835_sub2_s1025",
    "F085_sub2_s1025",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0835_sub2_s1025",
    "F085_sub2_s1025",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0835_sub2_s1025"
  ),
  variant_prefix = "row87fix11",
  gamma_substeps = 2L,
  p_global_eta_jump = c(
    0.0825, 0.0825, 0.0835, 0.0850,
    0.0825, 0.0825, 0.0835, 0.0850,
    0.0825, 0.0825, 0.0835
  ),
  global_eta_jump_scale = c(
    1.000, 1.025, 1.025, 1.025,
    1.000, 1.025, 1.025, 1.025,
    1.000, 1.025, 1.025
  ),
  n_burn = c(
    2000L, 2000L, 2000L, 2000L,
    3000L, 3000L, 3000L, 3000L,
    2000L, 2000L, 2000L
  ),
  n_mcmc = c(
    1000L, 1000L, 1000L, 1000L,
    1500L, 1500L, 1500L, 1500L,
    1000L, 1000L, 1000L
  ),
  thin = 1L,
  mh_proposal = rep("laplace_rw", 11L),
  mh_adapt = rep("true", 11L),
  slice_width = rep(0.12, 11L),
  slice_max_steps = rep(80L, 11L),
  init_mode = c(
    rep("baseline_last", 8L),
    rep("none", 3L)
  ),
  seed_wave11 = c(
    2026071087L, 2026072087L, 2026074087L, 2026079087L,
    2026111087L, 2026112087L, 2026113087L, 2026114087L,
    2026115087L, 2026116087L, 2026117087L
  ),
  target_outcome = rep("WARN_OR_BETTER", 11L),
  selection_reason = c(
    "exact replay of the strongest overlooked lower-mid short historical WARN anchor for row 87",
    "exact replay of the strongest scale-1.025 lower-mid short historical WARN anchor for row 87",
    "exact replay of the midpoint short historical WARN anchor that survived the broad fail-band screens",
    "exact replay of the upper-edge short historical WARN control that remains useful for comparison against the lower-mid corridor",
    "moderate-length confirmation of the strongest lower-mid scale-1.000 anchor",
    "moderate-length confirmation of the strongest lower-mid scale-1.025 anchor",
    "moderate-length confirmation of the midpoint lower-mid scale-1.025 anchor",
    "moderate-length confirmation of the upper-edge scale-1.025 control",
    "no-warm-start probe on the strongest lower-mid scale-1.000 anchor to test whether baseline_last is still hurting row 87",
    "no-warm-start probe on the strongest lower-mid scale-1.025 anchor",
    "no-warm-start probe on the midpoint lower-mid scale-1.025 anchor"
  ),
  stringsAsFactors = FALSE
)

materialize_rows <- function(mapping) {
  map_key <- paste(mapping$scope_label, mapping$row_id, sep = "\r")
  idx <- match(map_key, target_key)
  if (anyNA(idx)) {
    stop(sprintf("failed to match %d mapped rows into target_rows", sum(is.na(idx))))
  }
  block <- target_rows[idx, , drop = FALSE]
  for (nm in names(mapping)) {
    if (!(nm %in% c("scope_label", "row_id"))) block[[nm]] <- mapping[[nm]]
  }
  block
}

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule <- materialize_rows(row87_profiles)
schedule$variant_tag <- sprintf("%s_%s", schedule$variant_prefix, schedule$candidate_id)
schedule$candidate_path <- mapply(resolve_candidate_path, schedule$run_root, schedule$tau, schedule$variant_tag, USE.NAMES = FALSE)
schedule <- schedule[order(schedule$stage_order, schedule$candidate_id), , drop = FALSE]

baseline_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave11_baseline_map_v8_20260405.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave11_stage_counts_20260405.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave11_candidate_counts_20260405.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave11_schedule_20260405.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave11_rows_20260405.tsv")

stage_counts <- data.frame(
  stage = c("anchor4_short_hist", "confirm4_medium", "none3_lowermid"),
  n_rows = c(4L, 4L, 3L),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$geometry_candidate), stringsAsFactors = FALSE)
names(candidate_counts) <- c("geometry_candidate", "n_rows")
candidate_counts <- candidate_counts[order(-candidate_counts$n_rows, candidate_counts$geometry_candidate), , drop = FALSE]

utils::write.csv(active_map_v8, baseline_map_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)

tsv_cols <- c(
  "stage", "candidate_id", "geometry_candidate", "scope_label", "row_id",
  "run_root", "family_scope", "family", "tt", "tau", "variant_tag",
  "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
  "seed_wave11", "mcmc_base_path", "run_config_path", "prior_template_path",
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
