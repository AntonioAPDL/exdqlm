#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) args[[1]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)
force_rebuild <- any(args %in% c("--force", "force"))
jobs <- suppressWarnings(as.integer(Sys.getenv("EXDQLM_FQSG_REBUILD_JOBS", "1"))[1L])
if (!is.finite(jobs) || is.na(jobs) || jobs < 1L) jobs <- 1L

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

root_catalog <- fq_read_tsv(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_root_catalog.tsv"))
out_dir <- file.path(repo_root, "tools", "merge_reports")
root_signoff_script <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_root_signoff.R")

rbind_fill_list <- function(dfs) {
  dfs <- dfs[!vapply(dfs, is.null, logical(1))]
  if (!length(dfs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(dfs, names), use.names = FALSE))
  dfs2 <- lapply(dfs, function(df) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) {
      for (nm in miss) df[[nm]] <- NA
    }
    df[, cols, drop = FALSE]
  })
  do.call(rbind, dfs2)
}

ensure_root_signoff <- function(root_row) {
  det_post <- fq_detect_root_postprocess(root_row, repo_root)
  if (!identical(det_post$state[[1]], "complete_reusable")) {
    stop("Cannot build root signoff before postprocess is complete for root: ", root_row$root_id, call. = FALSE)
  }
  det_signoff <- fq_detect_root_signoff(root_row, repo_root)
  if (!force_rebuild && identical(det_signoff$state[[1]], "complete_reusable")) {
    return(invisible(FALSE))
  }
  cmd <- c(shQuote(root_signoff_script), shQuote(file.path(repo_root, root_row$run_root)), shQuote(repo_root))
  status <- system2("Rscript", cmd)
  if (!identical(status, 0L)) {
    stop("Root signoff build failed for root: ", root_row$root_id, call. = FALSE)
  }
  invisible(TRUE)
}

root_rows <- lapply(seq_len(nrow(root_catalog)), function(i) root_catalog[i, , drop = FALSE])
if (jobs > 1L && .Platform$OS.type == "unix") {
  parallel::mclapply(root_rows, ensure_root_signoff, mc.cores = jobs)
} else {
  lapply(root_rows, ensure_root_signoff)
}

read_root_signoff <- function(root_row, name) {
  path <- file.path(repo_root, root_row$run_root, "tables", name)
  df <- fq_read_csv_safe(path)
  if (is.null(df)) {
    stop("Missing required signoff file after ensure step: ", path, call. = FALSE)
  }
  n <- nrow(df)
  df$run_root <- rep(root_row$run_root, n)
  df
}

method_long <- rbind_fill_list(lapply(seq_len(nrow(root_catalog)), function(i) read_root_signoff(root_catalog[i, , drop = FALSE], "method_signoff_long.csv")))
algorithm_long <- rbind_fill_list(lapply(seq_len(nrow(root_catalog)), function(i) read_root_signoff(root_catalog[i, , drop = FALSE], "algorithm_pair_signoff.csv")))
model_long <- rbind_fill_list(lapply(seq_len(nrow(root_catalog)), function(i) read_root_signoff(root_catalog[i, , drop = FALSE], "model_pair_signoff.csv")))
root_long <- rbind_fill_list(lapply(seq_len(nrow(root_catalog)), function(i) read_root_signoff(root_catalog[i, , drop = FALSE], "root_signoff_summary.csv")))
repair_long <- rbind_fill_list(lapply(seq_len(nrow(root_catalog)), function(i) read_root_signoff(root_catalog[i, , drop = FALSE], "repair_targets.csv")))

method_summary <- aggregate(
  list(n = rep(1L, nrow(method_long))),
  by = list(
    root_kind = method_long$root_kind,
    family = method_long$family,
    inference = method_long$inference,
    model = method_long$model,
    signoff_grade = method_long$signoff_grade,
    comparison_eligible = method_long$comparison_eligible,
    convergence_certified = method_long$convergence_certified
  ),
  FUN = sum
)
method_summary <- method_summary[order(method_summary$root_kind, method_summary$family, method_summary$inference, method_summary$model, method_summary$signoff_grade), , drop = FALSE]

pair_summary <- rbind_fill_list(list(
  if (nrow(algorithm_long)) aggregate(list(n = rep(1L, nrow(algorithm_long))), by = list(
    pair_type = rep("algorithm_pair", nrow(algorithm_long)),
    root_kind = algorithm_long$root_kind,
    family = algorithm_long$family,
    signoff_grade = algorithm_long$pair_signoff_grade,
    comparison_eligible = algorithm_long$pair_comparison_eligible
  ), FUN = sum) else NULL,
  if (nrow(model_long)) aggregate(list(n = rep(1L, nrow(model_long))), by = list(
    pair_type = rep("model_pair", nrow(model_long)),
    root_kind = model_long$root_kind,
    family = model_long$family,
    signoff_grade = model_long$pair_signoff_grade,
    comparison_eligible = model_long$pair_comparison_eligible
  ), FUN = sum) else NULL
))

root_readiness <- root_long[, c(
  "root_id", "root_kind", "family", "tau", "fit_size", "prior",
  "n_methods", "n_signoff_pass", "n_signoff_warn", "n_signoff_fail",
  "method_comparison_eligible_rate", "algorithm_pair_comparison_eligible_rate",
  "model_pair_comparison_eligible_rate", "root_comparison_eligible_any",
  "root_comparison_eligible_full", "run_root"
), drop = FALSE]

signoff_summary <- data.frame(
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  method_fit_count = nrow(method_long),
  method_fit_pass_count = sum(method_long$signoff_grade == "PASS", na.rm = TRUE),
  method_fit_warn_count = sum(method_long$signoff_grade == "WARN", na.rm = TRUE),
  method_fit_fail_count = sum(method_long$signoff_grade == "FAIL", na.rm = TRUE),
  method_fit_eligible_count = sum(as.logical(method_long$comparison_eligible), na.rm = TRUE),
  method_fit_certified_count = sum(as.logical(method_long$convergence_certified), na.rm = TRUE),
  algorithm_pair_count = nrow(algorithm_long),
  algorithm_pair_eligible_count = sum(as.logical(algorithm_long$pair_comparison_eligible), na.rm = TRUE),
  model_pair_count = nrow(model_long),
  model_pair_eligible_count = sum(as.logical(model_long$pair_comparison_eligible), na.rm = TRUE),
  root_count = nrow(root_long),
  root_full_eligible_count = sum(as.logical(root_long$root_comparison_eligible_full), na.rm = TRUE),
  root_any_eligible_count = sum(as.logical(root_long$root_comparison_eligible_any), na.rm = TRUE),
  unhealthy_target_count = nrow(repair_long),
  stringsAsFactors = FALSE
)

fq_write_tsv(method_long, file.path(out_dir, "20260314_family_qspec_method_signoff.tsv"))
fq_write_tsv(algorithm_long, file.path(out_dir, "20260314_family_qspec_algorithm_pair_signoff.tsv"))
fq_write_tsv(model_long, file.path(out_dir, "20260314_family_qspec_model_pair_signoff.tsv"))
fq_write_tsv(root_readiness, file.path(out_dir, "20260314_family_qspec_root_readiness.tsv"))
fq_write_tsv(repair_long, file.path(out_dir, "20260314_family_qspec_unhealthy_targets.tsv"))
fq_write_tsv(method_summary, file.path(out_dir, "20260314_family_qspec_method_signoff_summary.tsv"))
fq_write_tsv(pair_summary, file.path(out_dir, "20260314_family_qspec_pair_signoff_summary.tsv"))
fq_write_tsv(signoff_summary, file.path(out_dir, "20260314_family_qspec_signoff_summary.tsv"))

writeLines(c(
  "# Family-QSpec Signoff Views",
  "",
  paste0("- generated_at: `", signoff_summary$generated_at[[1]], "`"),
  paste0("- method_fit_count: `", signoff_summary$method_fit_count[[1]], "`"),
  paste0("- method_fit_pass_count: `", signoff_summary$method_fit_pass_count[[1]], "`"),
  paste0("- method_fit_warn_count: `", signoff_summary$method_fit_warn_count[[1]], "`"),
  paste0("- method_fit_fail_count: `", signoff_summary$method_fit_fail_count[[1]], "`"),
  paste0("- method_fit_eligible_count: `", signoff_summary$method_fit_eligible_count[[1]], "`"),
  paste0("- algorithm_pair_eligible_count: `", signoff_summary$algorithm_pair_eligible_count[[1]], "`"),
  paste0("- model_pair_eligible_count: `", signoff_summary$model_pair_eligible_count[[1]], "`"),
  paste0("- root_full_eligible_count: `", signoff_summary$root_full_eligible_count[[1]], "`"),
  paste0("- unhealthy_target_count: `", signoff_summary$unhealthy_target_count[[1]], "`")
), con = file.path(out_dir, "20260314_family_qspec_signoff_summary.md"))

cat("Wrote signoff views under tools/merge_reports\n")
