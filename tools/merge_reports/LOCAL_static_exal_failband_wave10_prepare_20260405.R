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

active_map_v6 <- data.frame(
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
    "F0825_sub2_s105_none",
    "F085_sub2_s105_histshort",
    "F0825_sub2_s100_rwlong",
    "F0825_sub2_s1025_rwlong",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0845_sub2_s100_histshort"
  ),
  role = c(
    "open_fail_anchor",
    "stable_pass",
    "promoted_pass",
    "promoted_warn",
    "stable_warn",
    "stable_pass",
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
    "row 87 remains the only blocking static case, but the surviving evidence is concentrated in the narrow F085/F0855 scale-1.025 micro-band with slice and rwlong proposals",
    "durable repeated PASS anchor",
    "wave-9 promoted row-135 PASS under init_mode=none",
    "wave-9 promoted row-174 WARN under exact historical replay",
    "durable non-FAIL stability anchor",
    "fresh PASS anchor from wave-7",
    "stable repeated PASS anchor",
    "durable repeated PASS anchor",
    "wave-9 promoted row-269 WARN under exact historical short replay"
  ),
  stringsAsFactors = FALSE
)

row87_profiles <- data.frame(
  scope_label = rep("current_rhsns_refresh", 8L),
  row_id = rep(87L, 8L),
  stage = c(
    rep("anchor4_confirm", 4L),
    rep("micro4_expand", 4L)
  ),
  stage_order = c(rep(1L, 4L), rep(2L, 4L)),
  candidate_id = c(
    "R87_F085_sub2_s1025_slice_seed2026107007",
    "R87_F0855_sub2_s1025_rwlong_seed2026107005",
    "R87_F085_sub2_s1025_slice_long_seed2026108711",
    "R87_F0855_sub2_s1025_rwlong_long_seed2026108712",
    "R87_F08525_sub2_s1025_slice_seed2026108713",
    "R87_F08525_sub2_s1025_rwlong_seed2026108714",
    "R87_F0855_sub2_s1025_slice_seed2026108715",
    "R87_F08575_sub2_s1025_rwlong_seed2026108716"
  ),
  geometry_candidate = c(
    "F085_sub2_s1025",
    "F0855_sub2_s1025",
    "F085_sub2_s1025",
    "F0855_sub2_s1025",
    "F08525_sub2_s1025",
    "F08525_sub2_s1025",
    "F0855_sub2_s1025",
    "F08575_sub2_s1025"
  ),
  variant_prefix = "row87fix10",
  gamma_substeps = 2L,
  p_global_eta_jump = c(0.0850, 0.0855, 0.0850, 0.0855, 0.08525, 0.08525, 0.0855, 0.08575),
  global_eta_jump_scale = rep(1.025, 8L),
  n_burn = c(4000L, 4000L, 5000L, 5000L, 4000L, 4000L, 4000L, 4000L),
  n_mcmc = c(2000L, 2000L, 3000L, 3000L, 2000L, 2000L, 2000L, 2000L),
  thin = 1L,
  mh_proposal = c("slice_eta", "laplace_rw", "slice_eta", "laplace_rw", "slice_eta", "laplace_rw", "slice_eta", "laplace_rw"),
  mh_adapt = c("false", "true", "false", "true", "false", "true", "false", "true"),
  slice_width = c(0.20, 0.12, 0.20, 0.12, 0.20, 0.12, 0.20, 0.12),
  slice_max_steps = c(120L, 80L, 120L, 80L, 120L, 80L, 120L, 80L),
  init_mode = rep("baseline_last", 8L),
  seed_wave10 = c(2026107007L, 2026107005L, 2026108711L, 2026108712L, 2026108713L, 2026108714L, 2026108715L, 2026108716L),
  target_outcome = rep("WARN_OR_BETTER", 8L),
  selection_reason = c(
    "exact replay of the only historical slice WARN anchor for row 87",
    "exact replay of the only historical rwlong WARN anchor for row 87",
    "longer confirmation of the surviving slice anchor to target gamma ESS instability directly",
    "longer confirmation of the surviving rwlong anchor to target gamma ESS instability directly",
    "midpoint slice probe between the two only surviving row-87 jump frequencies",
    "midpoint rwlong probe between the two only surviving row-87 jump frequencies",
    "upper micro-band slice probe to test whether the surviving rwlong geometry also benefits from slice dynamics",
    "upper micro-band rwlong probe just above the only historical rwlong WARN anchor"
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

baseline_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave10_baseline_map_v6_20260405.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave10_stage_counts_20260405.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave10_candidate_counts_20260405.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave10_schedule_20260405.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave10_rows_20260405.tsv")

stage_counts <- data.frame(
  stage = c("anchor4_confirm", "micro4_expand"),
  n_rows = c(4L, 4L),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$geometry_candidate), stringsAsFactors = FALSE)
names(candidate_counts) <- c("geometry_candidate", "n_rows")
candidate_counts <- candidate_counts[order(-candidate_counts$n_rows, candidate_counts$geometry_candidate), , drop = FALSE]

utils::write.csv(active_map_v6, baseline_map_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)

tsv_cols <- c(
  "stage", "candidate_id", "geometry_candidate", "scope_label", "row_id",
  "run_root", "family_scope", "family", "tt", "tau", "variant_tag",
  "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
  "seed_wave10", "mcmc_base_path", "run_config_path", "prior_template_path",
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
