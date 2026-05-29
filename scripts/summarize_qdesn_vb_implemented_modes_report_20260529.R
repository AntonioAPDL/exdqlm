#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit)) return(default)
  if (hit[[1L]] == length(args)) stop(sprintf("Missing value for %s.", flag), call. = FALSE)
  args[[hit[[1L]] + 1L]]
}

repo_root <- normalizePath(getwd(), mustWork = TRUE)
input_dir <- normalizePath(
  arg_value(
    "--input-dir",
    file.path(repo_root, "results", "qdesn_vb_implemented_modes_source_last1000_wash500_d1n300_20260529_current_head")
  ),
  mustWork = TRUE
)
output_dir <- arg_value("--output-dir", input_dir)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)

read_required <- function(file) {
  path <- file.path(input_dir, file)
  if (!file.exists(path)) stop(sprintf("Missing required input file: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE)
}

method_summary <- read_required("method_summary.csv")
exact_equivalence <- read_required("exact_equivalence.csv")
approximate_diagnostics <- read_required("approximate_diagnostics.csv")
target_changing_diagnostics <- read_required("target_changing_diagnostics.csv")
forbidden_modes <- read_required("forbidden_modes.csv")
repo_state <- read_required("repo_state.csv")

`%||%` <- function(a, b) if (is.null(a)) b else a

fmt_num <- function(x, digits = 4) {
  ifelse(
    is.na(x),
    "",
    ifelse(abs(x) >= 1e4 | (abs(x) > 0 & abs(x) < 1e-3),
      formatC(x, format = "e", digits = 3),
      formatC(x, format = "f", digits = digits)
    )
  )
}

fmt_bool <- function(x) {
  ifelse(is.na(x), "", ifelse(as.logical(x), "yes", "no"))
}

method_label <- function(id) {
  out <- gsub("^qdesn_", "", id)
  out <- gsub("_", " ", out)
  out <- gsub("rhs ns", "RHS_NS", out, fixed = TRUE)
  out <- gsub("rhs", "RHS", out, fixed = TRUE)
  out <- gsub("exal", "exAL", out, fixed = TRUE)
  out <- gsub(" al ", " AL ", paste0(" ", out, " "), fixed = TRUE)
  trimws(out)
}

target_class <- function(row) {
  label <- row[["target_label"]]
  if (isTRUE(row[["target_changes"]])) return("target-changing")
  if (isTRUE(row[["approximate"]])) return("approximate")
  if (identical(label, "covariance_approximation")) return("covariance approximation")
  if (grepl("exact_chunked", label, fixed = TRUE)) return("exact chunked")
  "full-data exact"
}

compact_rows <- lapply(seq_len(nrow(method_summary)), function(i) {
  row <- method_summary[i, , drop = FALSE]
  data.frame(
    method_id = row$method_id,
    method = method_label(row$method_id),
    likelihood = row$likelihood_family,
    prior = row$prior_family,
    covariance = row$covariance_form,
    mode = row$chunking_mode,
    target_class = target_class(row),
    preserves_full_data = isTRUE(row$preserves_full_data_target),
    finite = isTRUE(row$finite_state),
    iter = row$iter,
    elapsed_sec = row$elapsed_sec,
    pinball_y = row$pinball_y,
    rmse_q_target = row$rmse_q_target,
    sigma_tail = row$sigma_tail,
    gamma_tail = row$gamma_tail,
    stringsAsFactors = FALSE
  )
})
compact_table <- do.call(rbind, compact_rows)

priority <- c(
  "qdesn_al_ridge_full",
  "qdesn_al_ridge_exact",
  "qdesn_al_ridge_stochastic",
  "qdesn_al_ridge_hybrid",
  "qdesn_al_ridge_diagonal",
  "qdesn_al_ridge_fixed_subset",
  "qdesn_al_ridge_stratified_subset",
  "qdesn_al_ridge_stratified_equal_subset",
  "qdesn_al_ridge_stratified_response_subset",
  "qdesn_al_ridge_stratified_leverage_subset",
  "qdesn_al_rhs_full",
  "qdesn_al_rhs_exact",
  "qdesn_al_rhs_diagonal",
  "qdesn_al_rhs_ns_full",
  "qdesn_al_rhs_ns_exact",
  "qdesn_al_rhs_ns_diagonal",
  "qdesn_exal_ridge_full",
  "qdesn_exal_ridge_exact",
  "qdesn_exal_ridge_diagonal",
  "qdesn_exal_ridge_hybrid",
  "qdesn_exal_rhs_full",
  "qdesn_exal_rhs_exact",
  "qdesn_exal_rhs_hybrid",
  "qdesn_exal_rhs_ns_full",
  "qdesn_exal_rhs_ns_exact",
  "qdesn_exal_rhs_ns_hybrid"
)
compact_table$order <- match(compact_table$method_id, priority)
compact_table$order[is.na(compact_table$order)] <- length(priority) + seq_len(sum(is.na(compact_table$order)))
compact_table <- compact_table[order(compact_table$order), ]
compact_table$order <- NULL

utils::write.csv(
  compact_table,
  file.path(output_dir, "polished_method_table.csv"),
  row.names = FALSE
)

md_table <- function(df, con) {
  if (!nrow(df)) {
    writeLines("_None._", con)
    return(invisible(NULL))
  }
  df[] <- lapply(df, as.character)
  writeLines(paste0("| ", paste(names(df), collapse = " | "), " |"), con)
  writeLines(paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"), con)
  apply(df, 1L, function(x) {
    x <- gsub("\\|", "\\\\|", x)
    writeLines(paste0("| ", paste(x, collapse = " | "), " |"), con)
  })
  invisible(NULL)
}

report_path <- file.path(output_dir, "polished_comparison_report.md")
con <- file(report_path, open = "wt")
on.exit(close(con), add = TRUE)

rs <- repo_state[1, , drop = FALSE]
writeLines("# Q-DESN VB Implemented Modes Polished Comparison", con)
writeLines("", con)
writeLines("## Source and Run", con)
writeLines(sprintf("- Package branch: `%s`", rs$branch), con)
writeLines(sprintf("- Package HEAD recorded by comparison: `%s`", rs$head), con)
writeLines(sprintf("- Source rows: %s selected from %s total", rs$selected_n_rows, rs$source_n_rows), con)
writeLines(sprintf("- Source index range: %s:%s", rs$source_index_min, rs$source_index_max), con)
writeLines(sprintf("- Effective fitted rows: %s after washout %s", rs$effective_rows, rs$washout), con)
writeLines(sprintf("- Q-DESN: D=%s, reservoir n=%s, m=%s", rs$D, rs$reservoir_n, rs$m), con)
writeLines(sprintf("- Seed: %s; cores: %s", rs$seed, rs$cores), con)
writeLines("", con)

writeLines("## Compact Method Table", con)
display <- compact_table
display$preserves_full_data <- fmt_bool(display$preserves_full_data)
display$finite <- fmt_bool(display$finite)
display$elapsed_sec <- fmt_num(display$elapsed_sec, 3)
display$pinball_y <- fmt_num(display$pinball_y, 4)
display$rmse_q_target <- fmt_num(display$rmse_q_target, 4)
display$sigma_tail <- fmt_num(display$sigma_tail, 4)
display$gamma_tail <- fmt_num(display$gamma_tail, 4)
display <- display[, c(
  "method", "likelihood", "prior", "covariance", "mode",
  "target_class", "preserves_full_data", "finite", "elapsed_sec",
  "pinball_y", "rmse_q_target"
)]
names(display) <- c(
  "method", "like", "prior", "cov", "mode", "target",
  "full-data?", "finite?", "sec", "pinball_y", "rmse_mu"
)
md_table(display, con)
writeLines("", con)

writeLines("## Exact Gates", con)
exact_display <- exact_equivalence[, c(
  "comparison_type", "reference_method", "candidate_method",
  "max_gate_diff", "relative_gate_diff", "passed"
)]
exact_display$reference_method <- method_label(exact_display$reference_method)
exact_display$candidate_method <- method_label(exact_display$candidate_method)
exact_display$max_gate_diff <- fmt_num(exact_display$max_gate_diff, 6)
exact_display$relative_gate_diff <- fmt_num(exact_display$relative_gate_diff, 6)
exact_display$passed <- fmt_bool(exact_display$passed)
names(exact_display) <- c("type", "reference", "candidate", "max_abs", "max_rel", "passed")
md_table(exact_display, con)
writeLines("", con)

writeLines("## Approximate and Covariance Diagnostics", con)
approx_display <- approximate_diagnostics[, c(
  "comparison_type", "reference_method", "candidate_method",
  "finite_state", "reproducible_beta_mean_max_abs_diff",
  "fitted_median_max_abs_diff_vs_reference", "pinball_diff_vs_reference"
)]
approx_display$reference_method <- method_label(approx_display$reference_method)
approx_display$candidate_method <- method_label(approx_display$candidate_method)
approx_display$finite_state <- fmt_bool(approx_display$finite_state)
approx_display$reproducible_beta_mean_max_abs_diff <- fmt_num(
  approx_display$reproducible_beta_mean_max_abs_diff,
  6
)
approx_display$fitted_median_max_abs_diff_vs_reference <- fmt_num(
  approx_display$fitted_median_max_abs_diff_vs_reference,
  4
)
approx_display$pinball_diff_vs_reference <- fmt_num(
  approx_display$pinball_diff_vs_reference,
  6
)
names(approx_display) <- c("type", "reference", "candidate", "finite?", "repeat_beta", "max_fit_diff", "pinball_diff")
md_table(approx_display, con)
writeLines("", con)

writeLines("## Target-Changing Subset Diagnostics", con)
target_rows <- target_changing_diagnostics[!is.na(target_changing_diagnostics$candidate_method), , drop = FALSE]
target_display <- target_rows[, c(
  "reference_method", "candidate_method", "candidate_subset_rows",
  "candidate_original_rows", "fitted_median_max_abs_diff_vs_reference",
  "pinball_diff_vs_reference", "finite_state"
)]
target_display$reference_method <- method_label(target_display$reference_method)
target_display$candidate_method <- method_label(target_display$candidate_method)
target_display$fitted_median_max_abs_diff_vs_reference <- fmt_num(
  target_display$fitted_median_max_abs_diff_vs_reference,
  4
)
target_display$pinball_diff_vs_reference <- fmt_num(target_display$pinball_diff_vs_reference, 6)
target_display$finite_state <- fmt_bool(target_display$finite_state)
names(target_display) <- c("reference", "candidate", "subset_rows", "original_rows", "max_fit_diff", "pinball_diff", "finite?")
md_table(target_display, con)
writeLines("", con)

writeLines("## Forbidden and Deferred Modes", con)
forbidden_display <- forbidden_modes[, c("method", "attempted", "failed_early", "message", "reason")]
forbidden_display$attempted <- fmt_bool(forbidden_display$attempted)
forbidden_display$failed_early <- fmt_bool(forbidden_display$failed_early)
forbidden_display$message[is.na(forbidden_display$message)] <- ""
forbidden_display$reason[is.na(forbidden_display$reason)] <- ""
md_table(forbidden_display, con)
writeLines("", con)

writeLines("## Decision", con)
if (!all(exact_equivalence$passed)) {
  writeLines("- Status: FAIL. At least one exact equivalence gate failed.", con)
} else if (!all(compact_table$finite)) {
  writeLines("- Status: FAIL. At least one fitted method had non-finite state.", con)
} else {
  writeLines("- Status: PASS. Exact gates passed and all fitted method states were finite.", con)
}
writeLines("- Exact chunking preserves the full-data target for supported exact modes.", con)
writeLines("- Stochastic and hybrid rows are approximate and must not be read as exact equivalence claims.", con)
writeLines("- Subset rows are target-changing and should be interpreted as screening/sensitivity fits.", con)
writeLines("- Stochastic exAL, exAL RHS-family diagonal covariance, divide-and-combine, and coresets remain gated or deferred.", con)

cat("Wrote polished table to: ", file.path(output_dir, "polished_method_table.csv"), "\n", sep = "")
cat("Wrote polished report to: ", report_path, "\n", sep = "")
