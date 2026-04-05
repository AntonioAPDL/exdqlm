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

extract_candidate_from_variant <- function(x) {
  m <- regexpr("F[0-9]+_sub[0-9]+_s[0-9]+(?:_ref)?", x)
  out <- rep(NA_character_, length(x))
  ok <- m > 0
  out[ok] <- regmatches(x, m)[ok]
  out
}

historical_summary_files <- Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_*.csv"))
historical_summary_files <- historical_summary_files[file.exists(historical_summary_files)]
historical_summary_files <- historical_summary_files[!grepl("\\.lock$", historical_summary_files)]

extract_history <- function(files, wanted_rows) {
  keep_cols <- c(
    "queue_id", "gate_overall", "variant_tag", "family_scope", "family",
    "tt", "tau", "p_global_eta_jump", "global_eta_jump_scale"
  )
  pieces <- lapply(files, function(path) {
    x <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x) || !("queue_id" %in% names(x)) || !("variant_tag" %in% names(x))) return(NULL)
    x <- x[x$queue_id %in% wanted_rows, intersect(keep_cols, names(x)), drop = FALSE]
    if (!nrow(x)) return(NULL)
    x$geometry_candidate <- extract_candidate_from_variant(x$variant_tag)
    x <- x[!is.na(x$geometry_candidate) & nzchar(x$geometry_candidate), , drop = FALSE]
    if (!nrow(x)) return(NULL)
    x$source_file <- basename(path)
    x
  })
  pieces <- Filter(Negate(is.null), pieces)
  if (!length(pieces)) return(data.frame())
  out <- do.call(rbind, pieces)
  out$key <- paste(out$queue_id, out$geometry_candidate, sep = "\r")
  summary <- do.call(rbind, lapply(split(out, out$key), function(df) {
    data.frame(
      row_id = df$queue_id[1],
      family_scope = df$family_scope[1],
      family = df$family[1],
      tt = df$tt[1],
      tau = df$tau[1],
      geometry_candidate = df$geometry_candidate[1],
      jump = df$p_global_eta_jump[1],
      scale = df$global_eta_jump_scale[1],
      n_obs = nrow(df),
      pass_n = sum(df$gate_overall == "PASS"),
      warn_n = sum(df$gate_overall == "WARN"),
      fail_n = sum(df$gate_overall == "FAIL"),
      stringsAsFactors = FALSE
    )
  }))
  summary$score <- summary$pass_n * 3 + summary$warn_n - summary$fail_n * 3
  summary[order(summary$row_id, -summary$score, -summary$pass_n, -summary$warn_n, summary$fail_n, summary$geometry_candidate), , drop = FALSE]
}

baseline_map_v3 <- data.frame(
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
    "F085_sub2_s1025",
    "F0825_sub2_s100",
    "F0840_sub2_s1025",
    "F0875_sub2_s105",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0845_sub2_s1025",
    "F0825_sub2_s100",
    "F0845_sub2_s100"
  ),
  role = c(
    "open_fail_anchor",
    "stable_pass",
    "promoted_warn",
    "open_fail_anchor",
    "stability_warn_anchor",
    "stability_warn_anchor",
    "stable_pass",
    "stable_pass",
    "open_fail_anchor"
  ),
  best_read = c(
    "FAIL",
    "PASS",
    "WARN",
    "FAIL",
    "WARN",
    "WARN",
    "PASS",
    "PASS",
    "FAIL"
  ),
  evidence_note = c(
    "best repeated non-FAIL anchor for row 87, but still unresolved",
    "durable repeated PASS anchor",
    "fresh wave-6 WARN improvement promoted over the old fallback",
    "row-specific exception anchor; still unresolved",
    "best stability-oriented non-FAIL anchor after wave-6",
    "reusable non-FAIL anchor from wave-6 confirmation",
    "stable repeated PASS anchor",
    "durable repeated PASS anchor",
    "best current fallback anchor, but still unresolved"
  ),
  stringsAsFactors = FALSE
)

stability_profiles <- data.frame(
  scope_label = c("current_rhsns_refresh", "current_rhsns_refresh", "current_rhsns_refresh"),
  row_id = c(135L, 190L, 206L),
  stage = "stability3_v3",
  stage_order = 1L,
  candidate_id = c(
    "R135_F0840_sub2_s1025_rwlong",
    "R190_F0825_sub2_s100_rwlong",
    "R206_F0825_sub2_s1025_rwlong"
  ),
  geometry_candidate = c("F0840_sub2_s1025", "F0825_sub2_s100", "F0825_sub2_s1025"),
  variant_prefix = "repairmap7",
  gamma_substeps = 2L,
  p_global_eta_jump = c(0.0840, 0.0825, 0.0825),
  global_eta_jump_scale = c(1.025, 1.000, 1.025),
  n_burn = 4000L,
  n_mcmc = 2000L,
  thin = 1L,
  mh_proposal = "laplace_rw",
  mh_adapt = "true",
  slice_width = 0.12,
  slice_max_steps = 80L,
  init_mode = "baseline_last",
  target_outcome = "WARN_OR_BETTER",
  selection_reason = c(
    "row 135 promoted wave-6 midpoint WARN rescue under a longer confirmation run",
    "row 190 strongest repeated non-FAIL anchor promoted for fresh confirmation",
    "row 206 reusable non-FAIL anchor confirmed under the same longer run profile"
  ),
  stringsAsFactors = FALSE
)

core_profiles <- data.frame(
  scope_label = c(
    rep("current_rhsns_refresh", 5L),
    rep("current_rhsns_refresh", 5L),
    rep("legacy_rhs_refresh", 7L)
  ),
  row_id = c(
    rep(87L, 5L),
    rep(174L, 5L),
    rep(269L, 7L)
  ),
  stage = "core17_triplet",
  stage_order = 2L,
  candidate_id = c(
    "R87_F085_sub2_s1025_rwlong",
    "R87_F0855_sub2_s1025_rwlong",
    "R87_F0860_sub2_s1025_rwlong",
    "R87_F085_sub2_s1025_slice",
    "R87_F0825_sub2_s100_rwlong",
    "R174_F0875_sub2_s105_rwlong",
    "R174_F0865_sub2_s105_rwlong",
    "R174_F0880_sub2_s105_rwlong",
    "R174_F0885_sub2_s105_rwlong",
    "R174_F0875_sub2_s105_slice",
    "R269_F0845_sub2_s100_rwlong",
    "R269_F0825_sub2_s100_rwlong",
    "R269_F0825_sub2_s1025_rwlong",
    "R269_F0875_sub2_s105_rwlong",
    "R269_F0845_sub2_s100_slice",
    "R269_F0825_sub2_s100_slice",
    "R269_F0875_sub2_s105_slice"
  ),
  geometry_candidate = c(
    "F085_sub2_s1025",
    "F0855_sub2_s1025",
    "F0860_sub2_s1025",
    "F085_sub2_s1025",
    "F0825_sub2_s100",
    "F0875_sub2_s105",
    "F0865_sub2_s105",
    "F0880_sub2_s105",
    "F0885_sub2_s105",
    "F0875_sub2_s105",
    "F0845_sub2_s100",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0875_sub2_s105",
    "F0845_sub2_s100",
    "F0825_sub2_s100",
    "F0875_sub2_s105"
  ),
  variant_prefix = "rowfix7",
  gamma_substeps = 2L,
  p_global_eta_jump = c(
    0.0850, 0.0855, 0.0860, 0.0850, 0.0825,
    0.0875, 0.0865, 0.0880, 0.0885, 0.0875,
    0.0845, 0.0825, 0.0825, 0.0875, 0.0845, 0.0825, 0.0875
  ),
  global_eta_jump_scale = c(
    1.025, 1.025, 1.025, 1.025, 1.000,
    1.050, 1.050, 1.050, 1.050, 1.050,
    1.000, 1.000, 1.025, 1.050, 1.000, 1.000, 1.050
  ),
  n_burn = 4000L,
  n_mcmc = 2000L,
  thin = 1L,
  mh_proposal = c(
    "laplace_rw", "laplace_rw", "laplace_rw", "slice_eta", "laplace_rw",
    "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw", "slice_eta",
    "laplace_rw", "laplace_rw", "laplace_rw", "laplace_rw", "slice_eta", "slice_eta", "slice_eta"
  ),
  mh_adapt = c(
    rep("true", 3L), "false", "true",
    rep("true", 4L), "false",
    rep("true", 4L), rep("false", 3L)
  ),
  slice_width = c(
    rep(0.12, 3L), 0.20, 0.12,
    rep(0.12, 4L), 0.20,
    rep(0.12, 4L), rep(0.20, 3L)
  ),
  slice_max_steps = c(
    rep(80L, 3L), 120L, 80L,
    rep(80L, 4L), 120L,
    rep(80L, 4L), rep(120L, 3L)
  ),
  init_mode = "baseline_last",
  target_outcome = "WARN_OR_BETTER",
  selection_reason = c(
    "row 87 best historical corridor under a longer control run",
    "row 87 upper micro-step inside the same surviving scale-1.025 ridge",
    "row 87 upper micro-step just below the weak F0875 frontier",
    "row 87 proposal-style pivot on the best historical geometry anchor",
    "row 87 repeated lower-jump fallback with the strongest non-FAIL count after F085_s1025",
    "row 174 long-run control on the lone surviving row-specific exception",
    "row 174 lower micro-step around the same exception corridor",
    "row 174 upper micro-step around the same exception corridor",
    "row 174 farther upper micro-step while still below the discarded broad frontier",
    "row 174 proposal-style pivot on the only durable row-specific anchor",
    "row 269 safest current scale-1.000 anchor under a longer control run",
    "row 269 repeated lower-jump WARN fallback under a longer run",
    "row 269 scale bridge between the lower fallback and the upper-scale exception",
    "row 269 upper-scale historical WARN anchor under a longer run",
    "row 269 proposal-style pivot on the safest current scale-1.000 anchor",
    "row 269 proposal-style pivot on the repeated lower-jump WARN fallback",
    "row 269 proposal-style pivot on the historical upper-scale WARN anchor"
  ),
  stringsAsFactors = FALSE
)

all_profiles <- rbind(stability_profiles, core_profiles)
all_profiles$key <- paste(all_profiles$scope_label, all_profiles$row_id, sep = "\r")
idx <- match(all_profiles$key, target_key)
if (anyNA(idx)) {
  stop(sprintf("failed to match %d wave-7 rows into target_rows", sum(is.na(idx))))
}

schedule <- target_rows[idx, , drop = FALSE]
schedule$stage <- all_profiles$stage
schedule$stage_order <- all_profiles$stage_order
schedule$candidate_id <- all_profiles$candidate_id
schedule$geometry_candidate <- all_profiles$geometry_candidate
schedule$variant_tag <- sprintf("%s_%s", all_profiles$variant_prefix, all_profiles$candidate_id)
schedule$gamma_substeps <- all_profiles$gamma_substeps
schedule$p_global_eta_jump <- all_profiles$p_global_eta_jump
schedule$global_eta_jump_scale <- all_profiles$global_eta_jump_scale
schedule$n_burn <- all_profiles$n_burn
schedule$n_mcmc <- all_profiles$n_mcmc
schedule$thin <- all_profiles$thin
schedule$mh_proposal <- all_profiles$mh_proposal
schedule$mh_adapt <- all_profiles$mh_adapt
schedule$slice_width <- all_profiles$slice_width
schedule$slice_max_steps <- all_profiles$slice_max_steps
schedule$init_mode <- all_profiles$init_mode
schedule$selection_reason <- all_profiles$selection_reason
schedule$target_outcome <- all_profiles$target_outcome
schedule$seed_wave7 <- 2026107000L + seq_len(nrow(schedule))
schedule$candidate_path <- file.path(
  schedule$run_root,
  "fits", "mcmc",
  sprintf("mcmc_exal_tau_%s_fit_%s.rds", schedule$tau, schedule$variant_tag)
)
schedule <- schedule[order(schedule$stage_order, schedule$scope_label, schedule$row_id, schedule$candidate_id), , drop = FALSE]

evidence_rows <- sort(unique(c(baseline_map_v3$row_id, 135L, 190L, 206L)))
evidence_summary <- extract_history(historical_summary_files, evidence_rows)

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_candidate_profiles_20260404.csv")
baseline_map_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_baseline_map_v3_20260404.csv")
stability_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_stability3_20260404.csv")
core_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_core17_20260404.csv")
evidence_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_historical_evidence_20260404.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_stage_counts_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave7_rows_20260404.tsv")

stage_counts <- do.call(rbind, lapply(split(schedule, schedule$stage), function(df) {
  data.frame(stage = df$stage[1], n_rows = nrow(df), stringsAsFactors = FALSE)
}))
stage_counts <- stage_counts[order(match(stage_counts$stage, c("stability3_v3", "core17_triplet"))), , drop = FALSE]

utils::write.csv(all_profiles, config_path, row.names = FALSE)
utils::write.csv(baseline_map_v3, baseline_map_path, row.names = FALSE)
utils::write.csv(stability_profiles, stability_path, row.names = FALSE)
utils::write.csv(core_profiles, core_path, row.names = FALSE)
utils::write.csv(evidence_summary, evidence_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "geometry_candidate", "scope_label", "row_id",
    "run_root", "family_scope", "family", "tt", "tau", "variant_tag",
    "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
    "seed_wave7", "mcmc_base_path", "run_config_path", "prior_template_path",
    "expected_prior_override", "n_burn", "n_mcmc", "thin", "mh_proposal",
    "mh_adapt", "slice_width", "slice_max_steps", "init_mode",
    "candidate_path"
  )],
  rows_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("candidate_profiles: %s\n", config_path))
cat(sprintf("baseline_map_v3: %s\n", baseline_map_path))
cat(sprintf("stability3: %s\n", stability_path))
cat(sprintf("core17: %s\n", core_path))
cat(sprintf("historical_evidence: %s\n", evidence_path))
cat(sprintf("stage_counts: %s\n", stage_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
