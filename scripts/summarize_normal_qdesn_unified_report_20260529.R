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
    file.path(repo_root, "results", "normal_qdesn_unified_source_median_20260529")
  ),
  mustWork = TRUE
)
output_dir <- arg_value("--output-dir", file.path(input_dir, "manuscript_ready"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)

read_required <- function(file) {
  path <- file.path(input_dir, file)
  if (!file.exists(path)) stop(sprintf("Missing required input file: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE)
}

coalesce_col <- function(df, cols, default = NA) {
  out <- rep(default, nrow(df))
  for (nm in cols) {
    if (!nm %in% names(df)) next
    hit <- !is.na(df[[nm]]) & nzchar(as.character(df[[nm]]))
    out[hit] <- df[[nm]][hit]
  }
  out
}

as_bool <- function(x) {
  if (is.logical(x)) return(x)
  x <- tolower(trimws(as.character(x)))
  x %in% c("true", "t", "1", "yes")
}

fmt_num <- function(x, digits = 4) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(
    is.na(x),
    "",
    ifelse(abs(x) >= 1e4 | (abs(x) > 0 & abs(x) < 1e-3),
      formatC(x, format = "e", digits = 3),
      formatC(x, format = "f", digits = digits)
    )
  )
}

fmt_bool <- function(x) ifelse(is.na(x), "", ifelse(as_bool(x), "yes", "no"))

method_label <- function(id) {
  out <- as.character(id)
  out <- gsub("^qdesn_", "Q-DESN ", out)
  out <- gsub("^normal_", "Normal ", out)
  out <- gsub("_", " ", out)
  out <- gsub(" rhs ns", " RHS_NS", out, fixed = TRUE)
  out <- gsub(" rhs", " RHS", out, fixed = TRUE)
  out <- gsub(" exal", " exAL", out, fixed = TRUE)
  out <- gsub(" al ", " AL ", paste0(" ", out, " "), fixed = TRUE)
  trimws(out)
}

target_group <- function(method_id, target_label, exact_status, approximate, target_changes) {
  id <- as.character(method_id)
  target_label <- as.character(target_label)
  exact_status <- as.character(exact_status)
  if (grepl("initializer", target_label, fixed = TRUE)) return("initializer workflow")
  if (isTRUE(target_changes)) return("target-changing workflow/sensitivity")
  if (identical(target_label, "covariance_approximation")) return("covariance approximation")
  if (isTRUE(approximate)) return("approximate full-data fit")
  if (grepl("exact_chunked", target_label, fixed = TRUE) ||
      grepl("exact_chunked", exact_status, fixed = TRUE) ||
      grepl("_exact$", id)) return("exact chunked verification")
  if (grepl("normal_.*exact", target_label)) return("Normal exact baseline")
  "full-data baseline"
}

role_for_method <- function(method_id, target_group_value) {
  id <- as.character(method_id)
  if (id %in% c(
    "normal_scaled_ridge", "qdesn_al_ridge_full", "qdesn_exal_ridge_full",
    "qdesn_al_rhs_full", "qdesn_al_rhs_ns_full",
    "qdesn_exal_rhs_full", "qdesn_exal_rhs_ns_full"
  )) return("primary_baseline")
  if (id %in% c("normal_rhs_ns_vb")) return("normal_rhs_ns_diagnostic")
  if (id %in% c(
    "qdesn_al_ridge_stochastic", "qdesn_al_ridge_hybrid",
    "qdesn_exal_ridge_hybrid", "qdesn_exal_rhs_hybrid",
    "qdesn_exal_rhs_ns_hybrid"
  )) return("approximate_candidate")
  if (grepl("diagonal", id, fixed = TRUE)) return("diagnostic_not_default")
  if (grepl("subset|rolling|posterior|online", id)) return("sensitivity_or_workflow")
  if (grepl("exact", id, fixed = TRUE)) return("exact_gate_reference")
  if (identical(target_group_value, "initializer workflow")) return("initializer_workflow")
  "supporting"
}

md_table <- function(df, con) {
  if (!nrow(df)) {
    writeLines("_None._", con)
    return(invisible(NULL))
  }
  df[] <- lapply(df, function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    gsub("\\|", "\\\\|", x)
  })
  writeLines(paste0("| ", paste(names(df), collapse = " | "), " |"), con)
  writeLines(paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"), con)
  for (i in seq_len(nrow(df))) {
    writeLines(paste0("| ", paste(df[i, ], collapse = " | "), " |"), con)
  }
  invisible(NULL)
}

method_summary <- read_required("method_summary.csv")
exact_equivalence <- read_required("exact_equivalence.csv")
approximate_diagnostics <- read_required("approximate_diagnostics.csv")
target_changing_diagnostics <- read_required("target_changing_diagnostics.csv")
initializer_diagnostics <- read_required("initializer_diagnostics.csv")
forbidden_modes <- read_required("forbidden_modes.csv")
repo_state <- read_required("repo_state.csv")

method_summary$pinball_unified <- suppressWarnings(as.numeric(coalesce_col(
  method_summary,
  c("pinball_y", "pinball_tau_0p50")
)))
method_summary$rmse_unified <- suppressWarnings(as.numeric(coalesce_col(
  method_summary,
  c("rmse_q_target", "rmse_y")
)))
method_summary$preserves_full_data_target_bool <- as_bool(coalesce_col(
  method_summary,
  "preserves_full_data_target",
  default = NA
))
method_summary$approximate_bool <- as_bool(coalesce_col(method_summary, "approximate", default = NA))
method_summary$target_changes_bool <- as_bool(coalesce_col(method_summary, "target_changes", default = NA))
method_summary$finite_state_bool <- as_bool(coalesce_col(method_summary, "finite_state", default = NA))

groups <- mapply(
  target_group,
  method_summary$method_id,
  coalesce_col(method_summary, "target_label", default = ""),
  coalesce_col(method_summary, "exact_status", default = ""),
  method_summary$approximate_bool,
  method_summary$target_changes_bool,
  USE.NAMES = FALSE
)
roles <- mapply(role_for_method, method_summary$method_id, groups, USE.NAMES = FALSE)

method_table <- data.frame(
  component = method_summary$component,
  method_id = method_summary$method_id,
  label = method_label(method_summary$method_id),
  role = roles,
  target_group = groups,
  likelihood_family = coalesce_col(method_summary, "likelihood_family", default = ""),
  prior_family = coalesce_col(method_summary, "prior_family", default = ""),
  covariance_form = coalesce_col(method_summary, "covariance_form", default = ""),
  chunking_mode = coalesce_col(method_summary, "chunking_mode", default = ""),
  preserves_full_data_target = method_summary$preserves_full_data_target_bool,
  approximate = method_summary$approximate_bool,
  target_changes = method_summary$target_changes_bool,
  converged = as_bool(coalesce_col(method_summary, "converged", default = NA)),
  finite_state = method_summary$finite_state_bool,
  elapsed_sec = suppressWarnings(as.numeric(coalesce_col(method_summary, "elapsed_sec", default = NA))),
  pinball = method_summary$pinball_unified,
  rmse = method_summary$rmse_unified,
  stringsAsFactors = FALSE
)

priority <- c(
  "normal_scaled_ridge", "normal_scaled_ridge_exact_chunked", "normal_rhs_ns_vb",
  "qdesn_al_ridge_full", "qdesn_al_ridge_exact",
  "qdesn_al_ridge_stochastic", "qdesn_al_ridge_hybrid",
  "qdesn_exal_ridge_full", "qdesn_exal_ridge_exact", "qdesn_exal_ridge_hybrid",
  "qdesn_al_rhs_full", "qdesn_al_rhs_exact",
  "qdesn_al_rhs_ns_full", "qdesn_al_rhs_ns_exact",
  "qdesn_exal_rhs_full", "qdesn_exal_rhs_exact", "qdesn_exal_rhs_hybrid",
  "qdesn_exal_rhs_ns_full", "qdesn_exal_rhs_ns_exact", "qdesn_exal_rhs_ns_hybrid",
  "qdesn_al_ridge_fixed_subset", "qdesn_al_ridge_stratified_subset",
  "qdesn_al_ridge_stratified_response_subset", "qdesn_al_ridge_stratified_leverage_subset",
  "qdesn_al_ridge_rolling", "qdesn_al_ridge_posterior_as_prior", "qdesn_al_ridge_online"
)
method_table$order <- match(method_table$method_id, priority)
method_table$order[is.na(method_table$order)] <- length(priority) + seq_len(sum(is.na(method_table$order)))
method_table <- method_table[order(method_table$order, method_table$method_id), ]
method_table$order <- NULL

compact_ids <- c(
  "normal_scaled_ridge",
  "normal_rhs_ns_vb",
  "qdesn_al_ridge_full",
  "qdesn_al_ridge_stochastic",
  "qdesn_al_ridge_hybrid",
  "qdesn_exal_ridge_full",
  "qdesn_exal_ridge_hybrid",
  "qdesn_al_rhs_full",
  "qdesn_al_rhs_ns_full",
  "qdesn_exal_rhs_full",
  "qdesn_exal_rhs_hybrid",
  "qdesn_exal_rhs_ns_full",
  "qdesn_exal_rhs_ns_hybrid"
)
compact_table <- method_table[
  (method_table$component == "normal_source" &
     method_table$method_id %in% c("normal_scaled_ridge", "normal_rhs_ns_vb")) |
    (method_table$component == "qdesn_implemented_modes" &
       method_table$method_id %in% setdiff(compact_ids, c("normal_scaled_ridge", "normal_rhs_ns_vb"))),
  ,
  drop = FALSE
]

exact_summary <- exact_equivalence
exact_summary$max_gate_diff_num <- suppressWarnings(as.numeric(exact_summary$max_gate_diff))
exact_summary$passed_bool <- as_bool(exact_summary$passed)
exact_summary <- exact_summary[order(-exact_summary$max_gate_diff_num), , drop = FALSE]

approx_summary <- approximate_diagnostics
approx_summary$pinball_diff_num <- suppressWarnings(as.numeric(approx_summary$pinball_diff_vs_reference))
approx_summary <- approx_summary[order(abs(approx_summary$pinball_diff_num), na.last = TRUE), , drop = FALSE]

target_summary <- target_changing_diagnostics
if ("pinball_diff_vs_reference" %in% names(target_summary)) {
  target_summary$pinball_diff_num <- suppressWarnings(as.numeric(target_summary$pinball_diff_vs_reference))
  target_summary <- target_summary[order(abs(target_summary$pinball_diff_num), na.last = TRUE), , drop = FALSE]
}

write.csv(method_table, file.path(output_dir, "manuscript_method_table.csv"), row.names = FALSE)
write.csv(compact_table, file.path(output_dir, "manuscript_compact_methods.csv"), row.names = FALSE)
write.csv(exact_summary, file.path(output_dir, "manuscript_exact_gate_summary.csv"), row.names = FALSE)
write.csv(approx_summary, file.path(output_dir, "manuscript_approximate_summary.csv"), row.names = FALSE)

plot_path <- file.path(output_dir, "manuscript_pinball_overview.pdf")
plot_rows <- method_table[method_table$method_id %in% compact_ids & is.finite(method_table$pinball), ]
if (nrow(plot_rows)) {
  grDevices::pdf(plot_path, width = 11, height = 7)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mar = c(9, 5, 3, 1))
  bar_cols <- ifelse(
    plot_rows$role == "primary_baseline",
    "#2C7FB8",
    ifelse(plot_rows$role == "approximate_candidate", "#41AB5D", "#756BB1")
  )
  graphics::barplot(
    plot_rows$pinball,
    names.arg = plot_rows$label,
    las = 2,
    col = bar_cols,
    border = NA,
    ylab = "Pinball/check loss",
    main = "Normal/Q-DESN Source-Median Compact Comparison"
  )
  graphics::legend(
    "topright",
    legend = c("primary baseline", "approximate candidate", "diagnostic/workflow"),
    fill = c("#2C7FB8", "#41AB5D", "#756BB1"),
    bty = "n"
  )
  grDevices::dev.off()
}

report_path <- file.path(output_dir, "normal_qdesn_manuscript_ready_summary.md")
con <- file(report_path, open = "wt")
on.exit(close(con), add = TRUE)

rs <- repo_state[1, , drop = FALSE]
writeLines("# Normal/Q-DESN Manuscript-Ready Comparison Prep", con)
writeLines("", con)
writeLines("## Run", con)
writeLines(sprintf("- Package HEAD: `%s`", rs$head), con)
writeLines(sprintf("- Dirty at run time: `%s`", rs$dirty), con)
writeLines(sprintf("- Source: `%s`", rs$source_dir), con)
writeLines(sprintf("- DESN settings: D=%s, n=%s, m=%s, washout=%s", rs$D, rs$reservoir_n, rs$m, rs$washout), con)
writeLines(sprintf("- Seed: `%s`", rs$seed), con)
writeLines("", con)

writeLines("## Recommended Compact Methods", con)
display_compact <- compact_table[, c(
  "label", "role", "target_group", "likelihood_family", "prior_family",
  "finite_state", "pinball", "rmse", "elapsed_sec"
)]
display_compact$finite_state <- fmt_bool(display_compact$finite_state)
display_compact$pinball <- fmt_num(display_compact$pinball, 4)
display_compact$rmse <- fmt_num(display_compact$rmse, 4)
display_compact$elapsed_sec <- fmt_num(display_compact$elapsed_sec, 3)
names(display_compact) <- c("method", "role", "target", "like", "prior", "finite?", "pinball", "rmse", "sec")
md_table(display_compact, con)
writeLines("", con)

writeLines("## Exact Gate Summary", con)
exact_display <- exact_summary[, intersect(c(
  "component", "comparison_type", "reference_method", "candidate_method",
  "max_gate_diff", "relative_gate_diff", "passed"
), names(exact_summary)), drop = FALSE]
for (nm in intersect(c("max_gate_diff", "relative_gate_diff"), names(exact_display))) {
  exact_display[[nm]] <- fmt_num(exact_display[[nm]], 6)
}
if ("passed" %in% names(exact_display)) exact_display$passed <- fmt_bool(exact_display$passed)
md_table(exact_display, con)
writeLines("", con)

writeLines("## Approximate Candidates", con)
approx_display <- approx_summary[, intersect(c(
  "comparison_type", "reference_method", "candidate_method", "finite_state",
  "reproducible_beta_mean_max_abs_diff",
  "fitted_median_max_abs_diff_vs_reference",
  "pinball_diff_vs_reference"
), names(approx_summary)), drop = FALSE]
if ("finite_state" %in% names(approx_display)) approx_display$finite_state <- fmt_bool(approx_display$finite_state)
for (nm in intersect(c(
  "reproducible_beta_mean_max_abs_diff",
  "fitted_median_max_abs_diff_vs_reference",
  "pinball_diff_vs_reference"
), names(approx_display))) {
  approx_display[[nm]] <- fmt_num(approx_display[[nm]], 6)
}
md_table(approx_display, con)
writeLines("", con)

writeLines("## Figure/Table Files", con)
writeLines("- `manuscript_method_table.csv`: all methods with normalized labels and roles.", con)
writeLines("- `manuscript_compact_methods.csv`: suggested compact methods for first manuscript table.", con)
writeLines("- `manuscript_exact_gate_summary.csv`: exact equivalence gates sorted by largest difference.", con)
writeLines("- `manuscript_approximate_summary.csv`: approximate diagnostics sorted by absolute pinball difference.", con)
if (file.exists(plot_path)) {
  writeLines("- `manuscript_pinball_overview.pdf`: compact pinball-loss overview figure.", con)
}
writeLines("", con)

writeLines("## Recommendation", con)
writeLines("- Use full-covariance Normal ridge and Q-DESN AL/exAL ridge/RHS/RHS_NS rows as the primary comparison spine.", con)
writeLines("- Use stochastic/hybrid rows as approximate speed/accuracy diagnostics, clearly labeled approximate.", con)
writeLines("- Keep diagonal covariance rows out of the primary table for this source gate; they are finite but diagnostically poor here.", con)
writeLines("- Keep subset, rolling, posterior-as-prior, online, and initializer rows as workflow/sensitivity diagnostics unless the manuscript question explicitly needs them.", con)

cat("Wrote method table: ", file.path(output_dir, "manuscript_method_table.csv"), "\n", sep = "")
cat("Wrote compact table: ", file.path(output_dir, "manuscript_compact_methods.csv"), "\n", sep = "")
cat("Wrote report: ", report_path, "\n", sep = "")
if (file.exists(plot_path)) cat("Wrote plot: ", plot_path, "\n", sep = "")
