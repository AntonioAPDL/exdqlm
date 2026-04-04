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

candidate_cfg <- data.frame(
  candidate_id = c(
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s1025",
    "F085_sub2_s100",
    "F085_sub2_s1025",
    "F0875_sub2_s105"
  ),
  gamma_substeps = c(2L, 2L, 2L, 2L, 2L, 2L),
  p_global_eta_jump = c(0.0835, 0.0845, 0.0845, 0.0850, 0.0850, 0.0875),
  global_eta_jump_scale = c(1.025, 1.000, 1.025, 1.000, 1.025, 1.050),
  stringsAsFactors = FALSE
)

selected_map <- data.frame(
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
  candidate_id = c(
    "F085_sub2_s1025",
    "F0845_sub2_s1025",
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F085_sub2_s1025",
    "F0835_sub2_s1025",
    "F0845_sub2_s1025",
    "F085_sub2_s100",
    "F085_sub2_s100"
  ),
  selected_gate = c("WARN", "PASS", "PASS", "WARN", "PASS", "PASS", "PASS", "PASS", "WARN"),
  selected_reason = c(
    "closest default-adjacent WARN for row 87",
    "closest PASS to default on row 115",
    "closest PASS to default on row 135",
    "only wave-4 WARN on the hardest row 174",
    "closest PASS to default on row 190",
    "closest PASS to default on row 206",
    "closest PASS to default on row 278",
    "default already PASS on row 181",
    "default already WARN on row 269"
  ),
  stringsAsFactors = FALSE
)

probe_rows <- data.frame(
  scope_label = c("current_rhsns_refresh", "legacy_rhs_refresh"),
  row_id = c(174L, 269L),
  candidate_id = c("F0875_sub2_s105", "F0875_sub2_s105"),
  probe_reason = c(
    "historically strongest WARN-only outlier on row 174",
    "historically strongest WARN-only outlier on row 269"
  ),
  stringsAsFactors = FALSE
)

materialize_rows <- function(mapping, stage, stage_order, variant_prefix, reason_col, seed_base) {
  map_key <- paste(mapping$scope_label, mapping$row_id, sep = "\r")
  idx <- match(map_key, target_key)
  if (anyNA(idx)) {
    stop(sprintf("failed to match %d mapped rows into target_rows", sum(is.na(idx))))
  }
  cfg_idx <- match(mapping$candidate_id, candidate_cfg$candidate_id)
  if (anyNA(cfg_idx)) {
    stop("failed to match one or more candidate ids into candidate_cfg")
  }
  block <- target_rows[idx, , drop = FALSE]
  cfg <- candidate_cfg[cfg_idx, , drop = FALSE]
  block$stage <- stage
  block$stage_order <- stage_order
  block$candidate_id <- mapping$candidate_id
  block$variant_tag <- sprintf("%s_%s", variant_prefix, mapping$candidate_id)
  block$gamma_substeps <- cfg$gamma_substeps
  block$p_global_eta_jump <- cfg$p_global_eta_jump
  block$global_eta_jump_scale <- cfg$global_eta_jump_scale
  block$selection_reason <- mapping[[reason_col]]
  block$seed_wave5 <- seed_base + as.integer(block$row_id)
  block
}

confirm_block <- materialize_rows(selected_map, "confirm9", 1L, "repairmap5", "selected_reason", 2026081000L)
confirm_block$target_outcome <- selected_map$selected_gate

probe_block <- materialize_rows(probe_rows, "probe2", 2L, "probe5", "probe_reason", 2026089000L)
probe_block$target_outcome <- "WARN_OR_BETTER"

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule <- rbind(confirm_block, probe_block)
schedule$candidate_path <- mapply(resolve_candidate_path, schedule$run_root, schedule$tau, schedule$variant_tag, USE.NAMES = FALSE)
schedule <- schedule[order(schedule$stage_order, schedule$scope_label, schedule$row_id, schedule$candidate_id), , drop = FALSE]

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_config_20260404.csv")
repair_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_repair_map_20260404.csv")
probe_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_probe_rows_20260404.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_stage_counts_20260404.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_candidate_counts_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave5_rows_20260404.tsv")

stage_counts <- data.frame(
  stage = c("confirm9", "probe2"),
  n_rows = c(nrow(confirm_block), nrow(probe_block)),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$candidate_id), stringsAsFactors = FALSE)
names(candidate_counts) <- c("candidate_id", "n_rows")

utils::write.csv(candidate_cfg, config_path, row.names = FALSE)
utils::write.csv(selected_map, repair_map_path, row.names = FALSE)
utils::write.csv(probe_rows, probe_rows_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave5",
    "mcmc_base_path", "run_config_path", "prior_template_path",
    "expected_prior_override", "candidate_path"
  )],
  rows_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("config: %s\n", config_path))
cat(sprintf("repair_map: %s\n", repair_map_path))
cat(sprintf("probe_rows: %s\n", probe_rows_path))
cat(sprintf("stage_counts: %s\n", stage_counts_path))
cat(sprintf("candidate_counts: %s\n", candidate_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
