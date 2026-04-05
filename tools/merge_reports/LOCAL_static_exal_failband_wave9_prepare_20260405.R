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

active_map_v5 <- data.frame(
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
    "F0825_sub2_s105",
    "F0875_sub2_s105",
    "F0825_sub2_s100_rwlong",
    "F0825_sub2_s1025_rwlong",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0845_sub2_s100_vb"
  ),
  role = c(
    "unstable_warn_anchor",
    "stable_pass",
    "open_fail_anchor",
    "open_fail_anchor",
    "stable_warn",
    "stable_pass",
    "stable_pass",
    "stable_pass",
    "promoted_warn_anchor"
  ),
  best_read = c(
    "WARN_then_FAIL",
    "PASS",
    "FAIL",
    "FAIL",
    "WARN",
    "PASS",
    "PASS",
    "PASS",
    "WARN"
  ),
  evidence_note = c(
    "row 87 remains the best geometry corridor, but the warning anchor is now clearly seed-sensitive and requires exact-history replay rather than another generic confirmation",
    "durable repeated PASS anchor",
    "row 135 still needs closure, but exact historical PASS anchors now dominate over the failed vb-init probes",
    "row 174 still needs closure, but only exact historical WARN anchors remain credible after the longer-run and vb-init regressions",
    "durable non-FAIL stability anchor",
    "fresh PASS anchor from wave-7",
    "stable repeated PASS anchor",
    "durable repeated PASS anchor",
    "wave-8 improved row 269 from FAIL to WARN under F0845_sub2_s100_vb and that now deserves promotion as the local default"
  ),
  stringsAsFactors = FALSE
)

stability_rows <- data.frame(
  scope_label = c(
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "current_rhsns_refresh",
    "legacy_rhs_refresh",
    "legacy_rhs_refresh",
    "legacy_rhs_refresh",
    "legacy_rhs_refresh"
  ),
  row_id = c(87L, 87L, 87L, 269L, 269L, 269L, 269L),
  stage = "stability7_exact",
  stage_order = 1L,
  candidate_id = c(
    "R87_F085_sub2_s1025_slice_seed2026107007",
    "R87_F0855_sub2_s1025_rwlong_seed2026107005",
    "R87_F085_sub2_s1025_histshort_seed2026056087",
    "R269_F0845_sub2_s100_histshort_seed2026076269",
    "R269_F0845_sub2_s100_vb_seed2026088012",
    "R269_F0845_sub2_s100_none_seed2026092691",
    "R269_F0825_sub2_s1025_vb_seed2026088011"
  ),
  geometry_candidate = c(
    "F085_sub2_s1025",
    "F0855_sub2_s1025",
    "F085_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s100",
    "F0845_sub2_s100",
    "F0825_sub2_s1025"
  ),
  variant_prefix = "repairmap9",
  gamma_substeps = 2L,
  p_global_eta_jump = c(0.0850, 0.0855, 0.0850, 0.0845, 0.0845, 0.0845, 0.0825),
  global_eta_jump_scale = c(1.025, 1.025, 1.025, 1.000, 1.000, 1.000, 1.025),
  n_burn = c(4000L, 4000L, 2000L, 2000L, 2000L, 2000L, 2000L),
  n_mcmc = c(2000L, 2000L, 1000L, 1000L, 1000L, 1000L, 1000L),
  thin = 1L,
  mh_proposal = c("slice_eta", "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw"),
  mh_adapt = c("false", "true", "true", "true", "true", "true", "true"),
  slice_width = c(0.20, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12),
  slice_max_steps = c(120L, 80L, 80L, 80L, 80L, 80L, 80L),
  init_mode = c("baseline_last", "baseline_last", "baseline_last", "baseline_last", "vb", "none", "vb"),
  seed_wave9 = c(2026107007L, 2026107005L, 2026056087L, 2026076269L, 2026088012L, 2026092691L, 2026088011L),
  target_outcome = "WARN_OR_BETTER",
  selection_reason = c(
    "row 87 exact replay of the only fresh slice_eta WARN anchor from wave-7, using the original successful seed",
    "row 87 exact replay of the only upper-micro-step rwlong WARN anchor from wave-7, using the original successful seed",
    "row 87 exact replay of the earlier failband WARN geometry in short baseline-last form, to separate geometry from the later rowfix seed regression",
    "row 269 exact replay of the best historical short WARN anchor under the broad bridge search",
    "row 269 exact replay of the promoted wave-8 vb-init WARN rescue",
    "row 269 same promoted geometry with init_mode=none to test whether the WARN rescue can be retained without vb warm-start dependence",
    "row 269 alternate wave-8 vb-init WARN rescue kept as the only lower-jump local comparator still worth compute"
  ),
  stringsAsFactors = FALSE
)

closure_rows <- data.frame(
  scope_label = c(rep("current_rhsns_refresh", 6L), rep("current_rhsns_refresh", 6L)),
  row_id = c(rep(135L, 6L), rep(174L, 6L)),
  stage = "closure12_exact_none",
  stage_order = 2L,
  candidate_id = c(
    "R135_F0825_sub2_s105_histshort_seed2026054135",
    "R135_F0835_sub2_s1025_histshort_seed2026075135",
    "R135_F0845_sub2_s100_histshort_seed2026076135",
    "R135_F0845_sub2_s1025_histshort_seed2026077135",
    "R135_F0825_sub2_s105_none_seed2026091351",
    "R135_F0835_sub2_s1025_none_seed2026091352",
    "R174_F085_sub2_s105_histshort_seed2026040474",
    "R174_F0875_sub2_s105_histshort_seed2026060174",
    "R174_F0835_sub2_s1025_histshort_seed2026064174",
    "R174_F0845_sub2_s100_histshort_seed2026076174",
    "R174_F0875_sub2_s105_none_seed2026091741",
    "R174_F0845_sub2_s100_none_seed2026091742"
  ),
  geometry_candidate = c(
    "F0825_sub2_s105",
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s1025",
    "F0825_sub2_s105",
    "F0835_sub2_s1025",
    "F085_sub2_s105",
    "F0875_sub2_s105",
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F0875_sub2_s105",
    "F0845_sub2_s100"
  ),
  variant_prefix = "rowfix9",
  gamma_substeps = 2L,
  p_global_eta_jump = c(
    0.0825, 0.0835, 0.0845, 0.0845, 0.0825, 0.0835,
    0.0850, 0.0875, 0.0835, 0.0845, 0.0875, 0.0845
  ),
  global_eta_jump_scale = c(
    1.050, 1.025, 1.000, 1.025, 1.050, 1.025,
    1.050, 1.050, 1.025, 1.000, 1.050, 1.000
  ),
  n_burn = 2000L,
  n_mcmc = 1000L,
  thin = 1L,
  mh_proposal = "laplace_rw",
  mh_adapt = "true",
  slice_width = 0.12,
  slice_max_steps = 80L,
  init_mode = c(
    "baseline_last", "baseline_last", "baseline_last", "baseline_last", "none", "none",
    "baseline_last", "baseline_last", "baseline_last", "baseline_last", "none", "none"
  ),
  seed_wave9 = c(
    2026054135L, 2026075135L, 2026076135L, 2026077135L, 2026091351L, 2026091352L,
    2026040474L, 2026060174L, 2026064174L, 2026076174L, 2026091741L, 2026091742L
  ),
  target_outcome = "WARN_OR_BETTER",
  selection_reason = c(
    "row 135 exact replay of the only historical PASS anchor in the lower-jump wide-scale corridor",
    "row 135 exact replay of the historical PASS anchor that later regressed under a different seed",
    "row 135 exact replay of the strongest historical WARN fallback in the upper-mid scale-1.000 corridor",
    "row 135 exact replay of the strongest historical WARN fallback in the upper-mid scale-1.025 corridor",
    "row 135 no-warm-start probe on the only historical PASS anchor after wave-8 showed vb-init is invalid",
    "row 135 no-warm-start probe on the second historical PASS anchor after wave-8 showed vb-init is invalid",
    "row 174 exact replay of the earliest historical WARN anchor in the lower edge of the surviving exception corridor",
    "row 174 exact replay of the strongest repeated historical WARN anchor in the upper exception corridor",
    "row 174 exact replay of the only lower-mid WARN anchor that ever helped this row",
    "row 174 exact replay of the only scale-1.000 WARN anchor that ever helped this row",
    "row 174 no-warm-start probe on the strongest repeated WARN anchor after the vb-init probes crashed",
    "row 174 no-warm-start probe on the only scale-1.000 WARN anchor after the vb-init probes crashed"
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

stability_block <- materialize_rows(stability_rows)
closure_block <- materialize_rows(closure_rows)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule <- rbind(stability_block, closure_block)
schedule$variant_tag <- sprintf("%s_%s", schedule$variant_prefix, schedule$candidate_id)
schedule$candidate_path <- mapply(resolve_candidate_path, schedule$run_root, schedule$tau, schedule$variant_tag, USE.NAMES = FALSE)
schedule <- schedule[order(schedule$stage_order, schedule$scope_label, schedule$row_id, schedule$candidate_id), , drop = FALSE]

baseline_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave9_baseline_map_v5_20260405.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave9_stage_counts_20260405.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave9_candidate_counts_20260405.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave9_schedule_20260405.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave9_rows_20260405.tsv")

stage_counts <- data.frame(
  stage = c("stability7_exact", "closure12_exact_none"),
  n_rows = c(nrow(stability_block), nrow(closure_block)),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$geometry_candidate), stringsAsFactors = FALSE)
names(candidate_counts) <- c("geometry_candidate", "n_rows")
candidate_counts <- candidate_counts[order(-candidate_counts$n_rows, candidate_counts$geometry_candidate), , drop = FALSE]

utils::write.csv(active_map_v5, baseline_map_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)

tsv_cols <- c(
  "stage", "candidate_id", "geometry_candidate", "scope_label", "row_id",
  "run_root", "family_scope", "family", "tt", "tau", "variant_tag",
  "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
  "seed_wave9", "mcmc_base_path", "run_config_path", "prior_template_path",
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
