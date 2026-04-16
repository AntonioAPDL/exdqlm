#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

validation_repo <- normalizePath(
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration",
  winslash = "/",
  mustWork = TRUE
)

tag <- "original288_dynamic_tt5000_mcmc_rootcause_20260416"
run_root <- file.path(repo_root, "tools/merge_reports", paste0("full288_", tag))
config_dir <- file.path(run_root, "configs")
rows_dir <- file.path(run_root, "rows")
fits_dir <- file.path(run_root, "fits")
debug_dir <- file.path(run_root, "debug")
logs_dir <- file.path(run_root, "logs")

manifest_path <- file.path(repo_root, "tools/merge_reports", "LOCAL_original288_dynamic_tt5000_mcmc_rootcause_manifest_20260416.csv")
stage_counts_path <- file.path(repo_root, "tools/merge_reports", "LOCAL_original288_dynamic_tt5000_mcmc_rootcause_stage_counts_20260416.csv")
summary_path <- file.path(repo_root, "tools/merge_reports", "LOCAL_original288_dynamic_tt5000_mcmc_rootcause_summary_20260416.csv")

dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
for (p in c(config_dir, rows_dir, fits_dir, debug_dir, logs_dir)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

phase1_manifest_path <- file.path(
  validation_repo,
  "tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_repair_phase1_manifest_20260415.csv"
)
stopifnot(file.exists(phase1_manifest_path))

phase1 <- utils::read.csv(phase1_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
phase1_seed1 <- phase1[phase1$seed_slot == 1, , drop = FALSE]

mcmc_cases <- c(
  "dynamic::gausmix::0p05::5000::default::dqlm::mcmc",
  "dynamic::gausmix::0p05::5000::default::exdqlm::mcmc",
  "dynamic::gausmix::0p95::5000::default::dqlm::mcmc",
  "dynamic::gausmix::0p95::5000::default::exdqlm::mcmc",
  "dynamic::laplace::0p05::5000::default::dqlm::mcmc",
  "dynamic::laplace::0p05::5000::default::exdqlm::mcmc",
  "dynamic::normal::0p05::5000::default::dqlm::mcmc",
  "dynamic::normal::0p05::5000::default::exdqlm::mcmc"
)

vb_controls <- c(
  "dynamic::gausmix::0p05::5000::default::dqlm::vb",
  "dynamic::gausmix::0p05::5000::default::exdqlm::vb",
  "dynamic::laplace::0p05::5000::default::dqlm::vb",
  "dynamic::laplace::0p05::5000::default::exdqlm::vb",
  "dynamic::normal::0p05::5000::default::dqlm::vb",
  "dynamic::normal::0p05::5000::default::exdqlm::vb"
)

pick_rows <- function(case_keys) {
  out <- phase1_seed1[phase1_seed1$original_case_key %in% case_keys, , drop = FALSE]
  out <- out[match(case_keys, out$original_case_key), , drop = FALSE]
  if (anyNA(out$original_case_key)) {
    missing <- case_keys[is.na(out$original_case_key)]
    stop(sprintf("Missing representative cases in phase1 manifest: %s", paste(missing, collapse = ", ")))
  }
  out
}

mcmc_rows <- pick_rows(mcmc_cases)
vb_rows <- pick_rows(vb_controls)

variants_for_case <- function(row) {
  if (identical(row$inference, "mcmc")) {
    c("exact_short", "no_vb_init_short", "regfloor_short")
  } else {
    c("exact_short")
  }
}

build_row <- function(src_row, variant, row_id) {
  debug_case_key <- sprintf("%s__%s", src_row$original_case_key, variant)
  data.frame(
    row_id = row_id,
    source_phase1_row_id = src_row$row_id,
    base_row_id = src_row$base_row_id,
    original_case_key = src_row$original_case_key,
    family = src_row$family,
    tau_label = src_row$tau_label,
    fit_size = src_row$fit_size,
    prior_semantics = src_row$prior_semantics,
    model = src_row$model,
    inference = src_row$inference,
    variant = variant,
    fit_seed = src_row$seed,
    sim_output_path = src_row$sim_output_path,
    source_run_config_path = src_row$run_config_path,
    source_reference_fit_path = src_row$source_reference_fit_path,
    baseline_fit_path = src_row$baseline_fit_path,
    vb_reference_fit_path = src_row$vb_reference_fit_path,
    debug_case_key = debug_case_key,
    fit_output_path = file.path(fits_dir, sprintf("fit_%03d_%s.rds", row_id, variant)),
    row_status_path = file.path(rows_dir, sprintf("row_%03d.csv", row_id)),
    debug_dump_dir = file.path(debug_dir, sprintf("row_%03d_%s", row_id, variant)),
    progress_csv = file.path(debug_dir, sprintf("progress_%03d_%s.csv", row_id, variant)),
    stringsAsFactors = FALSE
  )
}

manifest_rows <- list()
next_id <- 1L
for (i in seq_len(nrow(mcmc_rows))) {
  src <- mcmc_rows[i, , drop = FALSE]
  for (variant in variants_for_case(src)) {
    manifest_rows[[length(manifest_rows) + 1L]] <- build_row(src, variant, next_id)
    next_id <- next_id + 1L
  }
}
for (i in seq_len(nrow(vb_rows))) {
  src <- vb_rows[i, , drop = FALSE]
  for (variant in variants_for_case(src)) {
    manifest_rows[[length(manifest_rows) + 1L]] <- build_row(src, variant, next_id)
    next_id <- next_id + 1L
  }
}

manifest <- do.call(rbind, manifest_rows)
manifest <- manifest[order(manifest$row_id), , drop = FALSE]
utils::write.csv(manifest, manifest_path, row.names = FALSE)

stage_counts <- as.data.frame(table(manifest$inference, manifest$variant), stringsAsFactors = FALSE)
names(stage_counts) <- c("inference", "variant", "rows")
utils::write.csv(stage_counts, stage_counts_path, row.names = FALSE)

summary_seed <- data.frame(
  scope = c("mcmc_anchor_cases", "vb_control_cases", "total_debug_rows"),
  count = c(length(mcmc_cases), length(vb_controls), nrow(manifest)),
  stringsAsFactors = FALSE
)
utils::write.csv(summary_seed, summary_path, row.names = FALSE)

cat(sprintf("mcmc_anchor_cases=%d\n", length(mcmc_cases)))
cat(sprintf("vb_control_cases=%d\n", length(vb_controls)))
cat(sprintf("debug_rows=%d\n", nrow(manifest)))
