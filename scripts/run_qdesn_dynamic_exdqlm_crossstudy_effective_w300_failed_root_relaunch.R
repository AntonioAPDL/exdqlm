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

resolve_campaign_root <- function(run_root, child) {
  if (!dir.exists(run_root)) return(run_root)
  direct <- file.path(run_root, child)
  if (dir.exists(direct)) return(run_root)
  kids <- sort(list.dirs(run_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (k in kids) {
    if (dir.exists(file.path(k, child))) return(k)
  }
  run_root
}

run_cmd <- function(cmd, args) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) structure(enc2utf8(conditionMessage(e)), status = 1L)
  )
  status <- as.integer(attr(out, "status") %||% 0L)[1L]
  list(status = status, output = enc2utf8(out))
}

source_run_tag <- as.character(get_arg("--source-run-tag", ""))[1L]
if (!nzchar(trimws(source_run_tag))) {
  stop("--source-run-tag is required.", call. = FALSE)
}

defaults_path <- resolve_path(
  get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_defaults.yaml")),
  must_work = TRUE
)
grid_path <- resolve_path(
  get_arg("--grid", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_effective_w300_postdraw_grid.csv")),
  must_work = TRUE
)
prepare_only <- has_flag("--prepare-only")
execute <- has_flag("--execute")
create_plots <- !has_flag("--no-plots")
workers <- suppressWarnings(as.integer(get_arg("--workers", "6"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 6L

defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
campaign_cfg <- defaults$campaign %||% list()

base_results_root <- resolve_path(
  campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation"),
  must_work = TRUE
)
base_report_root <- resolve_path(
  campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_effective_w300_postdraw_validation"),
  must_work = TRUE
)

source_outer_results_root <- file.path(base_results_root, source_run_tag)
source_results_root <- resolve_campaign_root(source_outer_results_root, "roots")
root_base <- file.path(source_results_root, "roots")
if (!dir.exists(root_base)) {
  stop(sprintf("Source run roots directory not found: %s", root_base), call. = FALSE)
}

root_dirs <- sort(list.dirs(root_base, recursive = FALSE, full.names = TRUE))
status_rows <- lapply(root_dirs, function(root_dir) {
  status_path <- file.path(root_dir, "manifest", "root_status.txt")
  error_path <- file.path(root_dir, "manifest", "root_error.txt")
  data.frame(
    root_id = basename(root_dir),
    root_status = if (file.exists(status_path)) trimws(readLines(status_path, warn = FALSE, n = 1L)) else "MISSING",
    root_error = if (file.exists(error_path)) paste(readLines(error_path, warn = FALSE), collapse = "\n") else NA_character_,
    stringsAsFactors = FALSE
  )
})
status_df <- exdqlm:::.qdesn_validation_bind_rows(status_rows)
failed_df <- status_df[as.character(status_df$root_status) == "FAIL", , drop = FALSE]
failed_root_ids <- sort(unique(as.character(failed_df$root_id)))
if (!length(failed_root_ids)) {
  stop(sprintf("No failed roots found in source run: %s", source_run_tag), call. = FALSE)
}

failed_grid <- grid_df[match(failed_root_ids, as.character(grid_df$root_id), nomatch = 0L), , drop = FALSE]
if (nrow(failed_grid) != length(failed_root_ids)) {
  missing_ids <- setdiff(failed_root_ids, as.character(failed_grid$root_id))
  stop(sprintf("Failed to recover %d failed roots from canonical grid: %s", length(missing_ids), paste(missing_ids, collapse = ", ")), call. = FALSE)
}

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-exdqlm-crossstudy-failedrelaunch-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

launch_root <- file.path(base_report_root, run_tag, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)
selected_grid_path <- file.path(launch_root, "selected_failed_roots_grid.csv")
utils::write.csv(failed_grid, selected_grid_path, row.names = FALSE)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  source_run_tag = source_run_tag,
  source_outer_results_root = source_outer_results_root,
  source_results_root = source_results_root,
  defaults_path = defaults_path,
  canonical_grid_path = grid_path,
  selected_grid_path = selected_grid_path,
  run_tag = run_tag,
  workers = as.integer(workers),
  create_plots = isTRUE(create_plots),
  failed_root_n = length(failed_root_ids),
  failed_root_ids = failed_root_ids,
  failed_roots = split(failed_df, seq_len(nrow(failed_df)))
)
write_json(manifest, file.path(launch_root, "failed_root_relaunch_manifest.json"))

summary_lines <- c(
  "# QDESN Dynamic Effective-W300 Failed-Root Relaunch",
  "",
  sprintf("- generated_at: `%s`", manifest$generated_at),
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- relaunch_run_tag: `%s`", run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- canonical_grid_path: `%s`", grid_path),
  sprintf("- selected_grid_path: `%s`", selected_grid_path),
  sprintf("- failed_root_n: `%d`", length(failed_root_ids)),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- create_plots: `%s`", if (isTRUE(create_plots)) "TRUE" else "FALSE"),
  "",
  "## Failed Roots",
  paste0("- `", failed_root_ids, "`"),
  "",
  "## Execution Contract",
  "- runner: `scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R`",
  "- launcher: `scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R`",
  "- subset mode: `--allow-grid-subset`",
  "- batch: `full`"
)
write_lines(summary_lines, file.path(launch_root, "failed_root_relaunch_summary.md"))

prepare_args <- c(
  file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
  "--defaults", defaults_path,
  "--grid", selected_grid_path,
  "--batch", "full",
  "--workers", as.character(workers),
  "--run-tag", run_tag,
  "--allow-grid-subset",
  "--prepare-only"
)
if (!isTRUE(create_plots)) {
  prepare_args <- c(prepare_args, "--no-plots")
}

if (isTRUE(prepare_only) || isTRUE(execute)) {
  prep <- run_cmd("Rscript", prepare_args)
  write_lines(prep$output, file.path(launch_root, "failed_root_relaunch_prepare.log"))
  if (!identical(prep$status, 0L)) {
    cat(paste(prep$output, collapse = "\n"), "\n")
    stop("Failed-root relaunch prepare-only check failed.", call. = FALSE)
  }
}

if (!isTRUE(execute)) {
  cat(sprintf("Manifest: %s\n", file.path(launch_root, "failed_root_relaunch_manifest.json")))
  cat(sprintf("Summary: %s\n", file.path(launch_root, "failed_root_relaunch_summary.md")))
  cat(sprintf("Selected grid: %s\n", selected_grid_path))
  cat(sprintf("Prepare command: Rscript %s\n", paste(shQuote(prepare_args), collapse = " ")))
  quit(status = 0)
}

launch_args <- c(
  file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
  "--defaults", defaults_path,
  "--grid", selected_grid_path,
  "--batch", "full",
  "--workers", as.character(workers),
  "--run-tag", run_tag,
  "--allow-grid-subset"
)
if (!isTRUE(create_plots)) {
  launch_args <- c(launch_args, "--no-plots")
}

launch <- run_cmd("Rscript", launch_args)
write_lines(launch$output, file.path(launch_root, "failed_root_relaunch_launch.log"))
cat(paste(launch$output, collapse = "\n"), "\n")
if (!identical(launch$status, 0L)) {
  stop("Failed-root relaunch launch step failed.", call. = FALSE)
}
