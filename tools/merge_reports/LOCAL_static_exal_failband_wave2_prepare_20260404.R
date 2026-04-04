#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
wave1_schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_schedule_20260403.csv")

if (!file.exists(wave1_schedule_path)) {
  stop(sprintf("missing wave-1 schedule: %s", wave1_schedule_path))
}

summary_files <- list.files(
  out_dir,
  pattern = "^LOCAL_static_case_health_summary_failband1_.*\\.csv$",
  full.names = TRUE
)
if (!length(summary_files)) {
  stop("no completed wave-1 summary files found")
}

wave1 <- utils::read.csv(wave1_schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
wave1$case_id <- paste0(gsub("^.*/results/", "results/", wave1$run_root), "::exal")
wave1$key <- paste(wave1$case_id, wave1$variant_tag, wave1$row_id, sep = "\r")

summary_list <- lapply(summary_files, function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
})
summ <- do.call(rbind, summary_list)
summ$key <- paste(summ$case_id, summ$variant_tag, summ$queue_id, sep = "\r")

idx <- match(wave1$key, summ$key)
wave1$gate_overall <- summ$gate_overall[idx]
wave1$gate_overall[is.na(wave1$gate_overall) | !nzchar(wave1$gate_overall)] <- "MISSING"

if (any(wave1$gate_overall == "MISSING")) {
  stop("wave-1 must be complete before preparing wave-2")
}

row_coverage <- do.call(rbind, lapply(split(wave1, paste(wave1$scope_label, wave1$row_id, sep = "\r")), function(df) {
  data.frame(
    scope_label = df$scope_label[1],
    row_id = df$row_id[1],
    family_scope = df$family_scope[1],
    family = df$family[1],
    tt = df$tt[1],
    tau = df$tau[1],
    resolved_by_candidates = sum(df$gate_overall %in% c("PASS", "WARN")),
    fail_by_candidates = sum(df$gate_overall == "FAIL"),
    stringsAsFactors = FALSE
  )
}))

row_coverage <- row_coverage[order(
  row_coverage$scope_label,
  row_coverage$resolved_by_candidates,
  -row_coverage$fail_by_candidates,
  row_coverage$row_id
), , drop = FALSE]

current_rows <- row_coverage[row_coverage$scope_label == "current_rhsns_refresh", , drop = FALSE]
legacy_rows <- row_coverage[row_coverage$scope_label == "legacy_rhs_refresh", , drop = FALSE]

current_rows$scope_rank <- seq_len(nrow(current_rows))
legacy_rows$scope_rank <- seq_len(nrow(legacy_rows))
row_coverage <- rbind(current_rows, legacy_rows)
row_coverage$global_rank <- seq_len(nrow(row_coverage))

stage_defs <- data.frame(
  stage = c("sentinel12", "expand20", "full30"),
  current_n = c(8L, 14L, 21L),
  legacy_n = c(4L, 6L, 9L),
  stage_order = c(1L, 2L, 3L),
  stage_seed_offset = c(0L, 10000L, 20000L),
  stringsAsFactors = FALSE
)

stage_rows <- vector("list", nrow(stage_defs))
for (i in seq_len(nrow(stage_defs))) {
  def <- stage_defs[i, , drop = FALSE]
  sel <- rbind(
    head(current_rows, def$current_n),
    head(legacy_rows, def$legacy_n)
  )
  sel$stage <- def$stage
  sel$stage_order <- def$stage_order
  sel$stage_seed_offset <- def$stage_seed_offset
  sel$stage_scope_target_n <- ifelse(
    sel$scope_label == "current_rhsns_refresh",
    def$current_n,
    def$legacy_n
  )
  stage_rows[[i]] <- sel
}
stage_rows <- do.call(rbind, stage_rows)
stage_rows <- stage_rows[order(stage_rows$stage_order, stage_rows$scope_label, stage_rows$scope_rank), , drop = FALSE]

base_cols <- c(
  "scope_label", "row_id", "run_root", "family_scope", "family", "tt", "tau",
  "mcmc_base_path", "run_config_path", "prior_template_path",
  "expected_prior_override"
)
base_rows <- unique(wave1[, base_cols, drop = FALSE])
stage_rows <- merge(
  stage_rows,
  base_rows,
  by = c("scope_label", "row_id", "family_scope", "family", "tt", "tau"),
  all.x = TRUE,
  sort = FALSE
)

required_cols <- c("run_root", "mcmc_base_path", "run_config_path", "prior_template_path", "expected_prior_override")
if (any(!stats::complete.cases(stage_rows[, required_cols, drop = FALSE]))) {
  stop("failed to map one or more stage rows back to the validated fail-band runner inputs")
}

candidate_cfg <- data.frame(
  candidate_id = c(
    "F080_sub2_s0975",
    "F0825_sub2_s100",
    "F0825_sub2_s1025",
    "F0825_sub2_s105",
    "F085_sub2_s100",
    "F085_sub2_s1025",
    "F085_sub2_s105",
    "F0875_sub2_s100",
    "F0875_sub2_s1025",
    "F0875_sub2_s105"
  ),
  variant_tag = c(
    "failband2_F080_sub2_s0975",
    "failband2_F0825_sub2_s100",
    "failband2_F0825_sub2_s1025",
    "failband2_F0825_sub2_s105",
    "failband2_F085_sub2_s100",
    "failband2_F085_sub2_s1025",
    "failband2_F085_sub2_s105",
    "failband2_F0875_sub2_s100",
    "failband2_F0875_sub2_s1025",
    "failband2_F0875_sub2_s105"
  ),
  gamma_substeps = rep(2L, 10L),
  p_global_eta_jump = c(0.0800, 0.0825, 0.0825, 0.0825, 0.0850, 0.0850, 0.0850, 0.0875, 0.0875, 0.0875),
  global_eta_jump_scale = c(0.975, 1.000, 1.025, 1.050, 1.000, 1.025, 1.050, 1.000, 1.025, 1.050),
  seed_base = c(2026051000L, 2026052000L, 2026053000L, 2026054000L, 2026055000L, 2026056000L, 2026057000L, 2026058000L, 2026059000L, 2026060000L),
  why_included = c(
    "Co-lead wave-1 winner; strongest central-tight anchor",
    "Midpoint control that helped the gausmix tau0p25 tt1000 cluster",
    "Bridge between midpoint neutral and wider midpoint scale",
    "Wider midpoint bridge toward the upper-edge winner",
    "Isolates jump increase from scale widening at F085",
    "Bridge between neutral and wide F085 scale",
    "Co-lead wave-1 winner; strongest upper-edge wide anchor",
    "Cautious extension below the rejected F090 frontier",
    "Cautious extension with modest widening",
    "Upper-edge extension with wide scale"
  ),
  stringsAsFactors = FALSE
)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule_list <- vector("list", nrow(candidate_cfg) * nrow(stage_defs))
k <- 0L
for (i in seq_len(nrow(candidate_cfg))) {
  cfg <- candidate_cfg[i, , drop = FALSE]
  for (j in seq_len(nrow(stage_defs))) {
    def <- stage_defs[j, , drop = FALSE]
    rows_j <- stage_rows[stage_rows$stage == def$stage, , drop = FALSE]
    rows_j$candidate_id <- cfg$candidate_id
    rows_j$variant_tag <- cfg$variant_tag
    rows_j$gamma_substeps <- cfg$gamma_substeps
    rows_j$p_global_eta_jump <- cfg$p_global_eta_jump
    rows_j$global_eta_jump_scale <- cfg$global_eta_jump_scale
    rows_j$seed_wave2 <- cfg$seed_base + def$stage_seed_offset + as.integer(rows_j$row_id)
    rows_j$why_included <- cfg$why_included
    rows_j$pattern_key <- paste(rows_j$family, rows_j$tau, rows_j$tt, sep = "::")
    rows_j$candidate_path <- mapply(resolve_candidate_path, rows_j$run_root, rows_j$tau, cfg$variant_tag, USE.NAMES = FALSE)
    k <- k + 1L
    schedule_list[[k]] <- rows_j
  }
}
schedule <- do.call(rbind, schedule_list)
schedule <- schedule[order(schedule$stage_order, schedule$candidate_id, schedule$scope_label, schedule$row_id), , drop = FALSE]

expected_total <- nrow(candidate_cfg) * sum(stage_defs$current_n + stage_defs$legacy_n)
if (nrow(schedule) != expected_total) {
  stop(sprintf("expected %d staged rows, found %d", expected_total, nrow(schedule)))
}

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_config_20260404.csv")
row_hardness_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_row_hardness_20260404.csv")
stage_rows_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_stage_rows_20260404.csv")
stage_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_stage_counts_20260404.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_candidate_counts_20260404.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_schedule_20260404.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave2_rows_20260404.tsv")

config <- candidate_cfg[, c(
  "candidate_id", "variant_tag", "gamma_substeps", "p_global_eta_jump",
  "global_eta_jump_scale", "why_included"
), drop = FALSE]

stage_counts <- as.data.frame(table(schedule$stage), stringsAsFactors = FALSE)
names(stage_counts) <- c("stage", "n_rows")
candidate_counts <- as.data.frame(table(schedule$stage, schedule$candidate_id), stringsAsFactors = FALSE)
names(candidate_counts) <- c("stage", "candidate_id", "n_rows")

utils::write.csv(config, config_path, row.names = FALSE)
utils::write.csv(row_coverage, row_hardness_path, row.names = FALSE)
utils::write.csv(stage_rows, stage_rows_path, row.names = FALSE)
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave2",
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
cat(sprintf("row_hardness: %s\n", row_hardness_path))
cat(sprintf("stage_rows: %s\n", stage_rows_path))
cat(sprintf("stage_counts: %s\n", stage_counts_path))
cat(sprintf("candidate_counts: %s\n", candidate_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
