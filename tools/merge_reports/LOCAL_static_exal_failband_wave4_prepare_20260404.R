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
wave2 <- wave2[wave2$stage == "full30" & wave2$candidate_id == "F085_sub2_s100", , drop = FALSE]
if (!nrow(wave2)) {
  stop("failed to isolate the wave-2 F085_sub2_s100 broad baseline rows")
}

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

wave2$case_id <- paste0(gsub("^.*/results/", "results/", wave2$run_root), "::exal")
wave2$key <- paste(wave2$case_id, wave2$variant_tag, wave2$row_id, sep = "\r")
summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")
idx <- match(wave2$key, summ$key)
wave2$gate_overall <- summ$gate_overall[idx]
wave2$gate_overall[is.na(wave2$gate_overall) | !nzchar(wave2$gate_overall)] <- "MISSING"

target_rows <- unique(wave2[wave2$gate_overall == "FAIL",
  c(
    "scope_label", "row_id", "run_root", "family_scope", "family", "tt", "tau",
    "mcmc_base_path", "run_config_path", "prior_template_path",
    "expected_prior_override"
  ),
  drop = FALSE
])

if (nrow(target_rows) != 9L) {
  stop(sprintf("expected 9 active repair rows from F085_sub2_s100, found %d", nrow(target_rows)))
}

target_rows <- target_rows[order(target_rows$scope_label, target_rows$row_id), , drop = FALSE]
target_rows$repair_priority <- seq_len(nrow(target_rows))

candidate_cfg <- data.frame(
  candidate_id = c(
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0825_sub2_s105",
    "F0835_sub2_s100",
    "F0835_sub2_s1025",
    "F0845_sub2_s100",
    "F0845_sub2_s1025",
    "F085_sub2_s100",
    "F085_sub2_s1025"
  ),
  gamma_substeps = rep(2L, 9L),
  p_global_eta_jump = c(0.0825, 0.0825, 0.0825, 0.0835, 0.0835, 0.0845, 0.0845, 0.0850, 0.0850),
  global_eta_jump_scale = c(1.000, 1.025, 1.050, 1.000, 1.025, 1.000, 1.025, 1.000, 1.025),
  seed_base = c(2026071000L, 2026072000L, 2026073000L, 2026074000L, 2026075000L, 2026076000L, 2026077000L, 2026078000L, 2026079000L),
  why_included = c(
    "Strongest complementary control; best shared repair anchor for rows 87, 174, 269",
    "Lower-mid widened hedge with the best evidence on row 190",
    "Special-case probe; only observed PASS on row 135",
    "Lower-mid bridge control",
    "Best mid-bridge hedge from wave-3 residual screen",
    "Upper-mid bridge useful on row 278",
    "Upper-mid widened bridge useful on rows 115, 190, 278",
    "Active broad baseline control",
    "Retained upper-edge widened hedge; useful on row 206"
  ),
  stringsAsFactors = FALSE
)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule_list <- vector("list", nrow(candidate_cfg))
for (i in seq_len(nrow(candidate_cfg))) {
  cfg <- candidate_cfg[i, , drop = FALSE]
  block <- target_rows
  block$stage <- "repair9"
  block$stage_order <- 1L
  block$candidate_id <- cfg$candidate_id
  block$variant_tag <- sprintf("failband4_%s", cfg$candidate_id)
  block$gamma_substeps <- cfg$gamma_substeps
  block$p_global_eta_jump <- cfg$p_global_eta_jump
  block$global_eta_jump_scale <- cfg$global_eta_jump_scale
  block$seed_wave4 <- cfg$seed_base + as.integer(block$row_id)
  block$why_included <- cfg$why_included
  block$candidate_path <- mapply(resolve_candidate_path, block$run_root, block$tau, block$variant_tag, USE.NAMES = FALSE)
  schedule_list[[i]] <- block
}

schedule <- do.call(rbind, schedule_list)
schedule <- schedule[order(schedule$candidate_id, schedule$scope_label, schedule$row_id), , drop = FALSE]

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_config_20260404.csv")
target_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_target_rows_20260404.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_stage_counts_20260404.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_candidate_counts_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave4_rows_20260404.tsv")

stage_counts <- data.frame(stage = "repair9", n_rows = nrow(schedule), stringsAsFactors = FALSE)
candidate_counts <- data.frame(candidate_id = candidate_cfg$candidate_id, n_rows = nrow(target_rows), stringsAsFactors = FALSE)

utils::write.csv(candidate_cfg[, c(
  "candidate_id", "gamma_substeps", "p_global_eta_jump",
  "global_eta_jump_scale", "why_included"
)], config_path, row.names = FALSE)
utils::write.csv(target_rows, target_rows_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave4",
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
cat(sprintf("target_rows: %s\n", target_rows_path))
cat(sprintf("stage_counts: %s\n", stage_counts_path))
cat(sprintf("candidate_counts: %s\n", candidate_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
