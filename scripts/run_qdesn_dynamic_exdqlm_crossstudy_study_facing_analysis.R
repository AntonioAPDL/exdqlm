#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
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
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

write_lines <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(lines), path)
  invisible(path)
}

render_md_table <- function(df) {
  if (is.null(df)) return("(no rows)")
  if (!is.data.frame(df)) df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (!nrow(df) || !ncol(df)) return("(no rows)")
  df[] <- lapply(df, function(x) {
    out <- as.character(x)
    out[is.na(out)] <- ""
    gsub("[\r\n]+", " ", out)
  })
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

expectation_table <- function(expected_state, source_state) {
  expected_state <- expected_state %||% list()
  overview <- source_state$analysis_overview
  actual <- c(
    source_fit_rows_total = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "fit_rows_total"),
    source_runtime_fail_n = sum(as.character(source_state$fit_summary$status) == "FAIL", na.rm = TRUE),
    source_signoff_fail_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "fit_fail_n"),
    source_root_total = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "root_total"),
    source_root_status_fail_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "root_status_fail_n"),
    source_root_compare_any_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "root_compare_any_n"),
    source_root_compare_full_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "root_compare_full_n"),
    representative_case_rows = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "representative_case_rows"),
    representative_pass_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "representative_pass_n"),
    representative_warn_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "representative_warn_n"),
    representative_fail_n = exdqlm:::`.qdesn_dynamic_studyfacing_metric_value`(overview, "representative_fail_n")
  )
  metrics <- union(names(actual), names(expected_state))
  rows <- lapply(metrics, function(metric) {
    expected_val <- expected_state[[metric]]
    actual_val <- actual[[metric]]
    matches <- if (is.null(expected_val)) NA else identical(as.numeric(actual_val), as.numeric(expected_val))
    data.frame(
      metric = metric,
      expected = if (is.null(expected_val)) NA else as.character(expected_val),
      actual = as.character(actual_val),
      matches = if (is.na(matches)) NA else as.character(matches),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_recovered_study_facing_analysis_manifest.yaml"))
prepare_only <- has_flag("--prepare-only")

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
manifest <- exdqlm:::qdesn_dynamic_studyfacing_load_manifest(manifest_path)
source_state <- exdqlm:::qdesn_dynamic_studyfacing_load_source_state(
  exdqlm:::`.qdesn_dynamic_studyfacing_resolve_comparison_root`(manifest, repo_root = repo_root)
)

analysis_cfg <- manifest$analysis %||% list()
report_root <- resolve_path(
  analysis_cfg$report_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_recovered_study_facing_analysis"),
  must_work = FALSE
)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag_prefix <- as.character(manifest$meta$run_tag_prefix %||% "qdesn-dynamic-exdqlm-crossstudy-studyfacing")[1L]
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("%s-%s__git-%s", run_tag_prefix, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

output_root <- file.path(report_root, run_tag)
launch_root <- file.path(output_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

expectation_df <- expectation_table(manifest$expected_state, source_state)
expected_checks <- expectation_df$matches
expected_checks <- expected_checks[!is.na(expected_checks)]
if (length(expected_checks) && !all(tolower(expected_checks) == "true")) {
  stop("Recovered comparison source state does not match study-facing manifest expectations.", call. = FALSE)
}

preflight_lines <- c(
  "# QDESN Recovered Study-Facing Analysis Preflight",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- prepare_only: `%s`", if (prepare_only) "TRUE" else "FALSE"),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- recovered_comparison_root: `%s`", source_state$comparison_root),
  "",
  "## Source State Checks",
  render_md_table(expectation_df),
  "",
  "## Representative Selection Counts",
  render_md_table(source_state$representative_selection_counts),
  "",
  "## Output",
  sprintf("- output_root: `%s`", output_root)
)
write_lines(preflight_lines, file.path(launch_root, "qdesn_dynamic_study_facing_analysis_preflight.md"))
write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  prepare_only = prepare_only,
  manifest_path = manifest_path,
  recovered_comparison_root = source_state$comparison_root,
  output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE)
), file.path(launch_root, "run_metadata.json"))

if (prepare_only) {
  cat(sprintf("Prepare-only OK: %s\n", output_root))
  quit(save = "no", status = 0L)
}

analysis_obj <- exdqlm:::qdesn_dynamic_studyfacing_write_analysis(
  source_state = source_state,
  output_root = output_root,
  manifest = manifest
)

write_json(list(
  completed_at = as.character(Sys.time())),
  file.path(launch_root, "completion_metadata.json")
)

cat(sprintf("Study-facing analysis complete: %s\n", output_root))
