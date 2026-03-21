#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path)[1L]
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

count_by <- function(df, col) {
  if (!nrow(df) || !(col %in% names(df))) return(data.frame(stringsAsFactors = FALSE))
  out <- as.data.frame(table(as.character(df[[col]])), stringsAsFactors = FALSE)
  names(out) <- c(col, "n")
  out
}

safe_num <- function(x) suppressWarnings(as.numeric(x))

default_broader <- file.path(
  "reports", "qdesn_mcmc_validation", "rhs_constc2_broader_confirmation",
  "20260319-154559__git-5f63b98"
)
default_compare <- file.path(
  "reports", "qdesn_mcmc_validation", "compare_constc2_v1",
  "20260320-084314__git-37f1bd0"
)

broader_root <- resolve_path(get_arg("--broader-report-root", default_broader), must_work = TRUE)
compare_root <- resolve_path(get_arg("--compare-report-root", default_compare), must_work = TRUE)

timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
output_root <- get_arg(
  "--output-root",
  file.path("reports", "qdesn_mcmc_validation", "postmortem", paste0(timestamp, "__git-", system("git rev-parse --short HEAD", intern = TRUE)))
)
if (!grepl("^(/|~)", output_root)) output_root <- file.path(repo_root, output_root)
output_root <- normalizePath(output_root, winslash = "/", mustWork = FALSE)
dir.create(file.path(output_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

broader_progress <- read_csv_safe(file.path(broader_root, "tables", "campaign_progress.csv"))
compare_progress <- read_csv_safe(file.path(compare_root, "tables", "campaign_progress.csv"))
compare_pair <- read_csv_safe(file.path(compare_root, "tables", "campaign_pair_summary.csv"))

overview <- data.frame(
  campaign = c("broader_confirmation", "compare_constc2_v1"),
  report_root = c(broader_root, compare_root),
  n_roots = c(nrow(broader_progress), nrow(compare_progress)),
  n_fail = c(
    sum(as.character(broader_progress$confirmation_grade %||% character(0)) == "FAIL"),
    sum(as.character(compare_progress$pair_signoff_grade %||% character(0)) == "FAIL")
  ),
  n_warn = c(
    sum(as.character(broader_progress$confirmation_grade %||% character(0)) == "WARN"),
    sum(as.character(compare_progress$pair_signoff_grade %||% character(0)) == "WARN")
  ),
  n_pass = c(
    sum(as.character(broader_progress$confirmation_grade %||% character(0)) == "PASS"),
    sum(as.character(compare_progress$pair_signoff_grade %||% character(0)) == "PASS")
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(overview, file.path(output_root, "tables", "campaign_overview.csv"), row.names = FALSE)

utils::write.csv(
  count_by(broader_progress, "confirmation_grade"),
  file.path(output_root, "tables", "broader_confirmation_grade_counts.csv"),
  row.names = FALSE
)
utils::write.csv(
  count_by(compare_progress, "pair_signoff_grade"),
  file.path(output_root, "tables", "compare_pair_signoff_grade_counts.csv"),
  row.names = FALSE
)

fail_cols <- c(
  "root_id", "scenario", "tau", "beta_prior_type", "seed", "reservoir_profile",
  "pair_signoff_grade", "pair_comparison_eligible",
  "vb_signoff_grade", "vb_signoff_reason",
  "mcmc_signoff_grade", "mcmc_signoff_reason",
  "runtime_ratio_mcmc_vs_vb"
)
fail_cols <- intersect(fail_cols, names(compare_pair))
compare_fail <- if (nrow(compare_pair)) {
  idx <- as.character(compare_pair$pair_signoff_grade %||% character(0)) == "FAIL"
  compare_pair[idx, fail_cols, drop = FALSE]
} else {
  data.frame(stringsAsFactors = FALSE)
}
utils::write.csv(compare_fail, file.path(output_root, "tables", "compare_pair_failures.csv"), row.names = FALSE)

runtime_profile <- if (nrow(compare_pair)) {
  split_rows <- split(compare_pair, interaction(compare_pair$scenario, compare_pair$beta_prior_type, drop = TRUE))
  out <- lapply(split_rows, function(df) {
    data.frame(
      scenario = as.character(df$scenario[1L]),
      beta_prior_type = as.character(df$beta_prior_type[1L]),
      n_pairs = nrow(df),
      runtime_ratio_mean = mean(safe_num(df$runtime_ratio_mcmc_vs_vb), na.rm = TRUE),
      runtime_ratio_median = stats::median(safe_num(df$runtime_ratio_mcmc_vs_vb), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
} else {
  data.frame(stringsAsFactors = FALSE)
}
utils::write.csv(runtime_profile, file.path(output_root, "tables", "compare_runtime_ratio_profile.csv"), row.names = FALSE)

manifest <- list(
  generated_at = as.character(Sys.time()),
  output_root = output_root,
  broader_report_root = broader_root,
  compare_report_root = compare_root,
  n_broader_roots = nrow(broader_progress),
  n_compare_roots = nrow(compare_progress),
  n_compare_fail_pairs = nrow(compare_fail),
  git_sha = trimws(system("git rev-parse --short HEAD", intern = TRUE))
)
jsonlite::write_json(manifest, file.path(output_root, "manifest", "postmortem_manifest.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

summary_lines <- c(
  "# QDESN MCMC Postmortem Pack",
  "",
  sprintf("- broader_report_root: `%s`", broader_root),
  sprintf("- compare_report_root: `%s`", compare_root),
  sprintf("- broader roots: `%d`", nrow(broader_progress)),
  sprintf("- compare roots: `%d`", nrow(compare_progress)),
  sprintf("- compare FAIL pairs: `%d`", nrow(compare_fail)),
  "",
  "## Key Tables",
  "",
  "- `tables/campaign_overview.csv`",
  "- `tables/compare_pair_failures.csv`",
  "- `tables/compare_runtime_ratio_profile.csv`",
  "- `tables/compare_pair_signoff_grade_counts.csv`"
)
writeLines(summary_lines, file.path(output_root, "postmortem_summary.md"))

cat(sprintf("Postmortem pack written to: %s\n", output_root))
