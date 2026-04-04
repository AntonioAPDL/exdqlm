#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
refresh_prepare_script <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_prepare_20260403.R")
refresh_schedule_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_schedule_20260403.csv")
fail_extract_script <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_fail_extract_20260403.R")
fail_inventory_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_fail_inventory_20260403.csv")
current_summary_path <- file.path(out_dir, "LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhsns_current_20260403.csv")
legacy_summary_path <- file.path(out_dir, "LOCAL_static_case_health_summary_static_exal_f080_sub2_s105_rhs_legacy_20260403.csv")

if (!file.exists(refresh_schedule_path)) {
  if (!file.exists(refresh_prepare_script)) stop(sprintf("missing refresh prepare script: %s", refresh_prepare_script))
  system2("Rscript", refresh_prepare_script, stdout = FALSE, stderr = FALSE)
}
if (!file.exists(fail_inventory_path)) {
  if (!file.exists(fail_extract_script)) stop(sprintf("missing fail extract script: %s", fail_extract_script))
  system2("Rscript", fail_extract_script, stdout = FALSE, stderr = FALSE)
}

for (path in c(refresh_schedule_path, fail_inventory_path, current_summary_path, legacy_summary_path)) {
  if (!file.exists(path)) stop(sprintf("required input missing: %s", path))
}

refresh <- utils::read.csv(refresh_schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
fail_inv <- utils::read.csv(fail_inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
current_ref <- utils::read.csv(current_summary_path, stringsAsFactors = FALSE, check.names = FALSE)
legacy_ref <- utils::read.csv(legacy_summary_path, stringsAsFactors = FALSE, check.names = FALSE)

fail_inv$scope_label <- ifelse(fail_inv$scope == "current_rhsns", "current_rhsns_refresh", "legacy_rhs_refresh")

key_cols_inv <- c("scope_label", "row_id", "family_scope", "family", "tt", "tau")
key_cols_ref <- c("scope_label", "row_id", "root_kind", "family", "tt", "tau_label")
base_rows <- merge(
  fail_inv,
  refresh,
  by.x = key_cols_inv,
  by.y = key_cols_ref,
  all.x = TRUE,
  sort = FALSE
)

required_cols <- c("run_root", "mcmc_base_path", "run_config_path", "prior_template_path", "expected_prior_override", "variant_tag")
if (any(!nzchar(base_rows$run_root)) || any(!stats::complete.cases(base_rows[, required_cols, drop = FALSE]))) {
  stop("failed to match all fail-band rows back to the completed refresh schedule")
}

reference <- rbind(
  transform(current_ref, scope_label = "current_rhsns_refresh"),
  transform(legacy_ref, scope_label = "legacy_rhs_refresh")
)
reference_key <- paste(reference$scope_label, reference$queue_id, sep = "\r")
base_key <- paste(base_rows$scope_label, base_rows$row_id, sep = "\r")
idx <- match(base_key, reference_key)
base_rows$reference_variant_tag <- reference$variant_tag[idx]
base_rows$reference_gate_overall <- reference$gate_overall[idx]
base_rows$reference_healthy <- reference$healthy[idx]

if (any(is.na(base_rows$reference_gate_overall))) {
  stop("missing reference gate_overall values for one or more fail-band rows")
}
if (any(base_rows$reference_gate_overall != "FAIL")) {
  stop("fail-band prepare expected all reference rows to be FAIL")
}

candidate_cfg <- data.frame(
  candidate_id = c(
    "F080_sub2_s100_ref",
    "F080_sub2_s0975",
    "F0825_sub2_s100",
    "F075_sub2_s105",
    "F085_sub2_s095",
    "F085_sub2_s105"
  ),
  variant_tag = c(
    "failband1_F080_sub2_s100_ref",
    "failband1_F080_sub2_s0975",
    "failband1_F0825_sub2_s100",
    "failband1_F075_sub2_s105",
    "failband1_F085_sub2_s095",
    "failband1_F085_sub2_s105"
  ),
  gamma_substeps = c(2L, 2L, 2L, 2L, 2L, 2L),
  p_global_eta_jump = c(0.0800, 0.0800, 0.0825, 0.0750, 0.0850, 0.0850),
  global_eta_jump_scale = c(1.000, 0.975, 1.000, 1.050, 0.950, 1.050),
  seed_base = c(2026044000L, 2026045000L, 2026046000L, 2026047000L, 2026048000L, 2026049000L),
  why_included = c(
    "Strongest direct backup control from wave-8",
    "Bridge candidate that repaired the tight F080 boundary",
    "Midpoint between F080 and F085 with neutral scale",
    "Lower-jump zero-FAIL hedge from wave-8",
    "Upper-edge tempered hedge",
    "Upper-edge wide hedge"
  ),
  stringsAsFactors = FALSE
)

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

schedule_list <- vector("list", nrow(candidate_cfg))
for (i in seq_len(nrow(candidate_cfg))) {
  cfg <- candidate_cfg[i, , drop = FALSE]
  x <- base_rows
  x$stage <- "screen30"
  x$candidate_id <- cfg$candidate_id
  x$variant_tag <- cfg$variant_tag
  x$gamma_substeps <- cfg$gamma_substeps
  x$p_global_eta_jump <- cfg$p_global_eta_jump
  x$global_eta_jump_scale <- cfg$global_eta_jump_scale
  x$seed_wave1 <- cfg$seed_base + as.integer(x$row_id)
  x$why_included <- cfg$why_included
  x$pattern_key <- paste(x$family, x$tau, x$tt, sep = "::")
  x$candidate_path <- mapply(resolve_candidate_path, x$run_root, x$tau, x$variant_tag, USE.NAMES = FALSE)
  schedule_list[[i]] <- x
}

schedule <- do.call(rbind, schedule_list)
schedule <- schedule[order(schedule$candidate_id, schedule$scope_label, schedule$row_id), , drop = FALSE]

if (nrow(schedule) != 180L) {
  stop(sprintf("expected 180 scheduled runs, found %d", nrow(schedule)))
}
if (length(unique(schedule$candidate_id)) != 6L) stop("expected 6 candidate profiles")
if (sum(schedule$scope_label == "current_rhsns_refresh") != 126L) stop("expected 126 current-scope scheduled runs")
if (sum(schedule$scope_label == "legacy_rhs_refresh") != 54L) stop("expected 54 legacy-scope scheduled runs")

config_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_config_20260403.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_schedule_20260403.csv")
scope_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_scope_counts_20260403.csv")
candidate_counts_path <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_candidate_counts_20260403.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_failband_wave1_rows_20260403.tsv")

config <- unique(schedule[, c(
  "candidate_id", "variant_tag", "gamma_substeps", "p_global_eta_jump",
  "global_eta_jump_scale", "why_included"
), drop = FALSE])
scope_counts <- as.data.frame(table(schedule$scope_label), stringsAsFactors = FALSE)
names(scope_counts) <- c("scope_label", "n_rows")
candidate_counts <- as.data.frame(table(schedule$candidate_id, schedule$scope_label), stringsAsFactors = FALSE)
names(candidate_counts) <- c("candidate_id", "scope_label", "n_rows")

utils::write.csv(config, config_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.csv(scope_counts, scope_counts_path, row.names = FALSE)
utils::write.csv(candidate_counts, candidate_counts_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "stage", "candidate_id", "scope_label", "row_id", "run_root", "family_scope",
    "family", "tt", "tau", "variant_tag", "gamma_substeps",
    "p_global_eta_jump", "global_eta_jump_scale", "seed_wave1",
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
cat(sprintf("scope_counts: %s\n", scope_counts_path))
cat(sprintf("candidate_counts: %s\n", candidate_counts_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
