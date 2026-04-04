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

normalize_candidate_id <- function(x) {
  x <- sub("^failband[0-9]+_(confirm_|resid_)", "", x)
  x <- sub("^failband[0-9]+_", "", x)
  x <- sub("^(repairmap5_|probe5_|failonly_)", "", x)
  x
}

candidate_cfg <- data.frame(
  candidate_id = c(
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0825_sub2_s105",
    "F0830_sub2_s1025",
    "F0830_sub2_s105",
    "F0835_sub2_s1025",
    "F0840_sub2_s100",
    "F0840_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s1025",
    "F085_sub2_s100",
    "F085_sub2_s1025",
    "F0875_sub2_s105",
    "F0860_sub2_s100"
  ),
  gamma_substeps = rep(2L, 14L),
  p_global_eta_jump = c(
    0.0825, 0.0825, 0.0825,
    0.0830, 0.0830,
    0.0835,
    0.0840, 0.0840,
    0.0845, 0.0845,
    0.0850,
    0.0850,
    0.0875,
    0.0860
  ),
  global_eta_jump_scale = c(
    1.000, 1.025, 1.050,
    1.025, 1.050,
    1.025,
    1.000, 1.025,
    1.000, 1.025,
    1.000,
    1.025,
    1.050,
    1.000
  ),
  stringsAsFactors = FALSE
)

historical_summary_files <- unique(c(
  Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_failband*.csv")),
  Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_repairmap5_*.csv")),
  Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_probe5_*.csv")),
  Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_failonly_*.csv"))
))
historical_summary_files <- historical_summary_files[file.exists(historical_summary_files)]

extract_history <- function(files, wanted_rows) {
  keep_cols <- c(
    "queue_id", "gate_overall", "variant_tag", "family_scope", "family",
    "tt", "tau", "p_global_eta_jump", "global_eta_jump_scale"
  )
  pieces <- lapply(files, function(path) {
    x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x) || !("queue_id" %in% names(x))) return(NULL)
    x <- x[x$queue_id %in% wanted_rows, intersect(keep_cols, names(x)), drop = FALSE]
    if (!nrow(x)) return(NULL)
    x$candidate_id <- normalize_candidate_id(x$variant_tag)
    x$source_file <- basename(path)
    x
  })
  pieces <- Filter(Negate(is.null), pieces)
  if (!length(pieces)) return(data.frame())
  out <- do.call(rbind, pieces)
  out$key <- paste(out$queue_id, out$candidate_id, sep = "\r")
  summary <- do.call(rbind, lapply(split(out, out$key), function(df) {
    data.frame(
      row_id = df$queue_id[1],
      family = df$family[1],
      tt = df$tt[1],
      tau = df$tau[1],
      candidate_id = df$candidate_id[1],
      jump = df$p_global_eta_jump[1],
      scale = df$global_eta_jump_scale[1],
      n_obs = nrow(df),
      pass_n = sum(df$gate_overall == "PASS"),
      warn_n = sum(df$gate_overall == "WARN"),
      fail_n = sum(df$gate_overall == "FAIL"),
      best_gate = c("FAIL", "WARN", "PASS")[max(match(df$gate_overall, c("FAIL", "WARN", "PASS")), na.rm = TRUE)],
      stringsAsFactors = FALSE
    )
  }))
  summary[order(summary$row_id, -summary$pass_n, -summary$warn_n, summary$fail_n, summary$candidate_id), , drop = FALSE]
}

evidence_summary <- extract_history(historical_summary_files, unique(target_rows$row_id))
evidence_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_historical_evidence_20260404.csv")
utils::write.csv(evidence_summary, evidence_path, row.names = FALSE)

active_map_v2 <- data.frame(
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
    "F0825_sub2_s100",
    "F0845_sub2_s100",
    "F0875_sub2_s105",
    "F0825_sub2_s1025",
    "F0825_sub2_s1025",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0845_sub2_s100"
  ),
  provisional_gate = c("WARN", "PASS", "WARN", "WARN", "PASS", "PASS", "PASS", "PASS", "WARN"),
  selection_reason = c(
    "stable repeated WARN with zero observed FAIL on row 87",
    "most durable PASS evidence on row 115 after wave-5 demoted the old choice",
    "safest current non-FAIL fallback on row 135 pending closure repair",
    "stable row-specific WARN outlier for row 174",
    "best current closure anchor on row 190 with PASS/WARN and no observed FAIL",
    "most efficient reusable PASS/WARN anchor on row 206",
    "stable repeated PASS on row 278",
    "more durable local option than keeping the broad default on row 181",
    "safest current non-FAIL fallback on row 269 pending closure repair"
  ),
  stringsAsFactors = FALSE
)

repair_core <- data.frame(
  scope_label = c(
    rep("current_rhsns_refresh", 9L),
    rep("legacy_rhs_refresh", 4L)
  ),
  row_id = c(
    rep(135L, 5L),
    rep(190L, 4L),
    rep(269L, 4L)
  ),
  candidate_id = c(
    "F0825_sub2_s105",
    "F0830_sub2_s105",
    "F0835_sub2_s1025",
    "F0840_sub2_s1025",
    "F0845_sub2_s1025",
    "F0830_sub2_s1025",
    "F0835_sub2_s1025",
    "F0840_sub2_s1025",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0840_sub2_s100",
    "F085_sub2_s100",
    "F0860_sub2_s100"
  ),
  probe_reason = c(
    "row 135 only lower-jump historical PASS candidate",
    "row 135 bridge between lower-jump PASS and upper-mid stable fallback",
    "row 135 unstable wave-4 PASS candidate",
    "row 135 new midpoint between unstable PASS and stable upper-mid WARN region",
    "row 135 stable widened upper-mid fallback",
    "row 190 new lower-mid widened bridge near best current ridge",
    "row 190 historical WARN-only bridge with no observed FAIL",
    "row 190 new midpoint inside the widened positive ridge",
    "row 190 stable widened comparator inside the same ridge",
    "row 269 repeated lower-jump WARN fallback",
    "row 269 new scale-1.000 midpoint near the safest observed region",
    "row 269 broad default control for direct comparison",
    "row 269 upper-mid scale-1.000 probe beyond the default"
  ),
  target_outcome = c(
    rep("WARN_OR_BETTER", 5L),
    rep("WARN_OR_BETTER", 4L),
    rep("WARN_OR_BETTER", 4L)
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
  block$seed_wave6 <- seed_base + as.integer(block$row_id)
  block
}

confirm_block <- materialize_rows(active_map_v2, "confirm9_v2", 1L, "repairmap6", "selection_reason", 2026101000L)
confirm_block$target_outcome <- active_map_v2$provisional_gate

repair_block <- materialize_rows(repair_core, "repair13", 2L, "rowfix6", "probe_reason", 2026109000L)
repair_block$target_outcome <- repair_core$target_outcome

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule <- rbind(confirm_block, repair_block)
schedule$candidate_path <- mapply(resolve_candidate_path, schedule$run_root, schedule$tau, schedule$variant_tag, USE.NAMES = FALSE)
schedule <- schedule[order(schedule$stage_order, schedule$scope_label, schedule$row_id, schedule$candidate_id), , drop = FALSE]

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_config_20260404.csv")
repair_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_repair_map_v2_20260404.csv")
repair_core_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_repair_core_20260404.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_stage_counts_20260404.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_candidate_counts_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave6_rows_20260404.tsv")

stage_counts <- data.frame(
  stage = c("confirm9_v2", "repair13"),
  n_rows = c(nrow(confirm_block), nrow(repair_block)),
  stringsAsFactors = FALSE
)

candidate_counts <- as.data.frame(table(schedule$candidate_id), stringsAsFactors = FALSE)
names(candidate_counts) <- c("candidate_id", "n_rows")
candidate_counts <- candidate_counts[order(-candidate_counts$n_rows, candidate_counts$candidate_id), , drop = FALSE]

utils::write.csv(candidate_cfg, config_path, row.names = FALSE)
utils::write.csv(active_map_v2, repair_map_path, row.names = FALSE)
utils::write.csv(repair_core, repair_core_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave6",
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
cat(sprintf("evidence: %s\n", evidence_path))
cat(sprintf("repair_map_v2: %s\n", repair_map_path))
cat(sprintf("repair_core: %s\n", repair_core_path))
cat(sprintf("stage_counts: %s\n", stage_counts_path))
cat(sprintf("candidate_counts: %s\n", candidate_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
