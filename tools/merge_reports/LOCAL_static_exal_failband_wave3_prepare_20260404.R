#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
wave2_schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_schedule_20260404.csv")

if (!file.exists(wave2_schedule_path)) {
  stop(sprintf("missing wave-2 schedule: %s", wave2_schedule_path))
}

summary_files <- list.files(
  out_dir,
  pattern = "^LOCAL_static_case_health_summary_failband2_.*\\.csv$",
  full.names = TRUE
)
if (!length(summary_files)) {
  stop("no wave-2 summary files found")
}

wave2 <- utils::read.csv(wave2_schedule_path, stringsAsFactors = FALSE, check.names = FALSE)

summary_list <- lapply(summary_files, function(path) {
  tryCatch(utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
})
summary_list <- Filter(Negate(is.null), summary_list)
if (!length(summary_list)) {
  stop("failed to read any wave-2 summary files")
}

all_cols <- unique(unlist(lapply(summary_list, names), use.names = FALSE))
summary_list <- lapply(summary_list, function(x) {
  for (nm in setdiff(all_cols, names(x))) x[[nm]] <- NA
  x[, all_cols, drop = FALSE]
})
summ <- do.call(rbind, summary_list)

base_cols <- c(
  "scope_label", "row_id", "run_root", "family_scope", "family", "tt", "tau",
  "mcmc_base_path", "run_config_path", "prior_template_path",
  "expected_prior_override"
)
base_rows <- unique(wave2[, base_cols, drop = FALSE])
base_rows$case_id <- paste0(gsub("^.*/results/", "results/", base_rows$run_root), "::exal")
base_rows$key <- paste(base_rows$case_id, base_rows$row_id, sep = "\r")

candidate_rows <- unique(wave2[, c("candidate_id", "variant_tag", base_cols), drop = FALSE])
candidate_rows$case_id <- paste0(gsub("^.*/results/", "results/", candidate_rows$run_root), "::exal")
candidate_rows$key <- paste(candidate_rows$case_id, candidate_rows$variant_tag, candidate_rows$row_id, sep = "\r")

summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
idx <- match(candidate_rows$key, summ$key)
candidate_rows$gate_overall <- summ$gate_overall[idx]
candidate_rows$gate_overall[is.na(candidate_rows$gate_overall) | !nzchar(candidate_rows$gate_overall)] <- "MISSING"

finalists <- c("F085_sub2_s100", "F0825_sub2_s100")
full30_rows <- unique(wave2[wave2$stage == "full30", base_cols, drop = FALSE])
full30_rows <- full30_rows[order(full30_rows$scope_label, full30_rows$row_id), , drop = FALSE]

full30_finalists <- candidate_rows[candidate_rows$candidate_id %in% finalists,
  c("candidate_id", "scope_label", "row_id", "family", "tt", "tau", "gate_overall"),
  drop = FALSE
]

if (length(unique(full30_finalists$candidate_id)) != length(finalists)) {
  stop("wave-2 finalist summaries are incomplete")
}

full30_wide <- reshape(
  full30_finalists,
  idvar = c("scope_label", "row_id", "family", "tt", "tau"),
  timevar = "candidate_id",
  direction = "wide"
)

residual_rows <- full30_wide[
  full30_wide$gate_overall.F085_sub2_s100 %in% c("FAIL", "MISSING") |
    full30_wide$gate_overall.F0825_sub2_s100 %in% c("FAIL", "MISSING"),
  ,
  drop = FALSE
]
if (!nrow(residual_rows)) {
  stop("no residual rows found under the wave-2 finalists")
}

residual_key <- paste(residual_rows$scope_label, residual_rows$row_id, sep = "\r")
base_key <- paste(base_rows$scope_label, base_rows$row_id, sep = "\r")
base_idx <- match(residual_key, base_key)
for (nm in c("run_root", "family_scope", "mcmc_base_path", "run_config_path", "prior_template_path", "expected_prior_override")) {
  residual_rows[[nm]] <- base_rows[[nm]][base_idx]
}

required_cols <- c("run_root", "mcmc_base_path", "run_config_path", "prior_template_path", "expected_prior_override")
if (any(!stats::complete.cases(residual_rows[, required_cols, drop = FALSE]))) {
  stop("failed to map one or more residual rows back to validated runner inputs")
}

residual_rows <- residual_rows[order(residual_rows$scope_label, residual_rows$row_id), , drop = FALSE]

candidate_cfg <- data.frame(
  candidate_id = c(
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0835_sub2_s100",
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s1025",
    "F085_sub2_s100",
    "F085_sub2_s1025"
  ),
  gamma_substeps = rep(2L, 8L),
  p_global_eta_jump = c(0.0825, 0.0825, 0.0835, 0.0835, 0.0845, 0.0845, 0.0850, 0.0850),
  global_eta_jump_scale = c(1.000, 1.025, 1.000, 1.025, 1.000, 1.025, 1.000, 1.025),
  seed_base = c(2026061000L, 2026062000L, 2026063000L, 2026064000L, 2026065000L, 2026066000L, 2026067000L, 2026068000L),
  why_included = c(
    "Primary complementary control from wave-2; resolves rows the leader misses",
    "Lower-jump widened hedge retained from the live bridge zone",
    "New lower-mid bridge between the two wave-2 finalists",
    "Lower-mid bridge with mild widening",
    "New upper-mid bridge leaning toward the wave-2 leader",
    "Upper-mid bridge with mild widening",
    "Best completed broad residual-band baseline from wave-2",
    "Best remaining widened upper-edge hedge inside the live zone"
  ),
  stringsAsFactors = FALSE
)

stage_defs <- data.frame(
  stage = c("residual18", "confirm30"),
  stage_order = c(1L, 2L),
  stage_seed_offset = c(0L, 10000L),
  stage_variant_prefix = c("failband3_resid", "failband3_confirm"),
  stringsAsFactors = FALSE
)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

make_stage_block <- function(rows_df, stage_row, cfg_df) {
  out <- vector("list", nrow(cfg_df))
  for (i in seq_len(nrow(cfg_df))) {
    cfg <- cfg_df[i, , drop = FALSE]
    block <- rows_df
    block$stage <- stage_row$stage
    block$stage_order <- stage_row$stage_order
    block$stage_variant_prefix <- stage_row$stage_variant_prefix
    block$candidate_id <- cfg$candidate_id
    block$variant_tag <- sprintf("%s_%s", stage_row$stage_variant_prefix, cfg$candidate_id)
    block$gamma_substeps <- cfg$gamma_substeps
    block$p_global_eta_jump <- cfg$p_global_eta_jump
    block$global_eta_jump_scale <- cfg$global_eta_jump_scale
    block$seed_wave3 <- cfg$seed_base + stage_row$stage_seed_offset + as.integer(block$row_id)
    block$why_included <- cfg$why_included
    block$candidate_path <- mapply(resolve_candidate_path, block$run_root, block$tau, block$variant_tag, USE.NAMES = FALSE)
    out[[i]] <- block
  }
  do.call(rbind, out)
}

residual_base <- residual_rows[, c(
  "scope_label", "row_id", "run_root", "family_scope", "family", "tt", "tau",
  "mcmc_base_path", "run_config_path", "prior_template_path",
  "expected_prior_override", "gate_overall.F085_sub2_s100",
  "gate_overall.F0825_sub2_s100"
), drop = FALSE]

confirm_base <- full30_rows
confirm_base$gate_overall.F085_sub2_s100 <- full30_wide$gate_overall.F085_sub2_s100[match(
  paste(confirm_base$scope_label, confirm_base$row_id, sep = "\r"),
  paste(full30_wide$scope_label, full30_wide$row_id, sep = "\r")
)]
confirm_base$gate_overall.F0825_sub2_s100 <- full30_wide$gate_overall.F0825_sub2_s100[match(
  paste(confirm_base$scope_label, confirm_base$row_id, sep = "\r"),
  paste(full30_wide$scope_label, full30_wide$row_id, sep = "\r")
)]

schedule <- rbind(
  make_stage_block(residual_base, stage_defs[stage_defs$stage == "residual18", , drop = FALSE], candidate_cfg),
  make_stage_block(confirm_base, stage_defs[stage_defs$stage == "confirm30", , drop = FALSE], candidate_cfg)
)
schedule <- schedule[order(schedule$stage_order, schedule$candidate_id, schedule$scope_label, schedule$row_id), , drop = FALSE]

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_config_20260404.csv")
residual_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_residual_rows_20260404.csv")
confirm_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_confirm_rows_20260404.csv")
potential_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_potential_counts_20260404.csv")
actual_budget_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_actual_budget_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave3_rows_20260404.tsv")

potential_counts <- as.data.frame(table(schedule$stage), stringsAsFactors = FALSE)
names(potential_counts) <- c("stage", "n_rows")

actual_budget <- data.frame(
  stage = c("residual18", "confirm30", "overall"),
  launched_candidates = c(8L, 2L, NA),
  rows_per_candidate = c(nrow(residual_base), nrow(confirm_base), NA),
  actual_runs = c(8L * nrow(residual_base), 2L * nrow(confirm_base), 8L * nrow(residual_base) + 2L * nrow(confirm_base)),
  stringsAsFactors = FALSE
)

utils::write.csv(candidate_cfg[, c(
  "candidate_id", "gamma_substeps", "p_global_eta_jump",
  "global_eta_jump_scale", "why_included"
)], config_path, row.names = FALSE)
utils::write.csv(residual_base, residual_rows_path, row.names = FALSE)
utils::write.csv(confirm_base, confirm_rows_path, row.names = FALSE)
utils::write.csv(potential_counts, potential_counts_path, row.names = FALSE)
utils::write.csv(actual_budget, actual_budget_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave3",
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
cat(sprintf("residual_rows: %s\n", residual_rows_path))
cat(sprintf("confirm_rows: %s\n", confirm_rows_path))
cat(sprintf("potential_counts: %s\n", potential_counts_path))
cat(sprintf("actual_budget: %s\n", actual_budget_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
