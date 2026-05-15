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

cmd_lines <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) sprintf("ERROR: %s", conditionMessage(e))
  )
  enc2utf8(out)
}

write_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

count_table_df <- function(x, name) {
  if (!length(x)) return(data.frame(stringsAsFactors = FALSE))
  out <- as.data.frame(table(value = as.character(x)), stringsAsFactors = FALSE)
  names(out) <- c(name, "n")
  out[order(out[[name]]), , drop = FALSE]
}

grid_equivalent <- function(a, b) {
  cols <- intersect(names(a), names(b))
  cols <- cols[!cols %in% c("enabled")]
  if (!length(cols)) return(FALSE)
  normalize <- function(df) {
    out <- df[, cols, drop = FALSE]
    if ("tau" %in% names(out)) out$tau <- as.numeric(out$tau)
    if ("fit_size" %in% names(out)) out$fit_size <- as.integer(out$fit_size)
    if ("seed" %in% names(out)) out$seed <- as.integer(out$seed)
    out[] <- lapply(out, function(x) if (is.logical(x)) as.character(x) else x)
    out[do.call(order, out), , drop = FALSE]
  }
  identical(normalize(a), normalize(b))
}

summary_md <- function(title, body_lines) {
  c(paste0("# ", title), "", body_lines)
}

defaults_rel <- get_arg("--defaults", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"))
grid_rel <- get_arg("--grid", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv"))
defaults_path <- resolve_path(defaults_rel, must_work = TRUE)
grid_path_raw <- resolve_path(grid_rel, must_work = FALSE)
prepare_only <- has_flag("--prepare-only")
refresh_grid <- has_flag("--refresh-grid")
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")

defaults <- exdqlm:::qdesn_static_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_static_crossstudy_build_grid_from_reference(defaults)
canonical_grid_summary <- exdqlm:::qdesn_static_crossstudy_validate_grid(canonical_grid, defaults)

if (isTRUE(refresh_grid) || !file.exists(grid_path_raw)) {
  dir.create(dirname(grid_path_raw), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(canonical_grid, grid_path_raw, row.names = FALSE)
}

grid_df <- exdqlm:::qdesn_static_crossstudy_load_grid(grid_path_raw)
grid_summary <- exdqlm:::qdesn_static_crossstudy_validate_grid(grid_df, defaults)
if (!grid_equivalent(grid_df, canonical_grid)) {
  stop(
    paste(
      c(
        "The checked-in grid does not match the canonical grid recovered from the exdqlm signoff roots.",
        "Re-run with `--refresh-grid` or inspect config/validation/qdesn_static_exdqlm_crossstudy_grid.csv."
      ),
      collapse = "\n"
    ),
    call. = FALSE
  )
}

reference_cfg <- defaults$reference %||% list()
reference_inventory <- exdqlm:::qdesn_static_crossstudy_collect_reference_inventory(
  paper_root = resolve_path(reference_cfg$paper_root, must_work = TRUE),
  shrink_root = resolve_path(reference_cfg$shrink_root, must_work = TRUE)
)
reference_summary <- exdqlm:::qdesn_static_crossstudy_validate_reference_inventory(reference_inventory, defaults)

runtime_cfg <- defaults$runtime %||% list()
active_qdesn_processes <- cmd_lines(
  "bash",
  c(
    "-lc",
    paste(
      "ps -eo pid=,args=",
      "| grep -E -- 'run_qdesn_|qdesn-phase|pipeline_real_main\\.R|pipeline_sim_main\\.R'",
      "| grep -vE 'grep -E|run_qdesn_static_exdqlm_crossstudy_validation\\.R|materialize_qdesn_static_exdqlm_crossstudy_grid\\.R'",
      "|| true"
    )
  )
)
active_qdesn_processes <- active_qdesn_processes[nzchar(trimws(active_qdesn_processes))]

workers_arg <- suppressWarnings(as.integer(get_arg("--workers", NA_character_))[1L])
workers <- if (is.finite(workers_arg) && workers_arg >= 1L) {
  min(16L, workers_arg)
} else if (length(active_qdesn_processes)) {
  4L
} else {
  as.integer(runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 6L)[1L]
}
if (!is.finite(workers) || workers < 1L) workers <- 1L
workers <- min(16L, workers)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-static-exdqlm-crossstudy-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy"), must_work = FALSE)
run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(run_report_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

resource_snapshot <- list(
  generated_at = as.character(Sys.time()),
  nproc = cmd_lines("nproc"),
  lscpu = cmd_lines("bash", c("-lc", "lscpu | sed -n '1,40p'")),
  free_h = cmd_lines("free", "-h"),
  uptime = cmd_lines("uptime"),
  active_qdesn_processes = as.list(active_qdesn_processes)
)

preflight_manifest <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  defaults_path = defaults_path,
  grid_path = grid_path_raw,
  prepare_only = prepare_only,
  refresh_grid = refresh_grid,
  create_plots = create_plots,
  chosen_workers = workers,
  scope = list(
    static_crossstudy = TRUE,
    include_dynamic_row15_sidecar = FALSE,
    exclude_gausmix_tau_0p50 = TRUE
  ),
  reference_summary = reference_summary,
  grid_summary = grid_summary,
  canonical_grid_summary = canonical_grid_summary,
  resource_snapshot = resource_snapshot,
  output_roots = list(
    outer_results_root = run_results_root,
    outer_report_root = run_report_root
  ),
  acceptance_criteria = list(
    all_grid_roots_materialized = TRUE,
    all_root_status_success = TRUE,
    comparison_tables_written = TRUE,
    reference_compare_summary_written = TRUE,
    recommendation_in = c(
      "COMPARISON_READY_QDESN_STATIC_CROSSSTUDY_COMPLETE",
      "COMPARISON_READY_WITH_DOCUMENTED_FAIL_BAND",
      "HOLD_QDESN_STATIC_CROSSSTUDY_WITH_GAPS"
    )
  )
)

jsonlite::write_json(
  preflight_manifest,
  file.path(launch_root, "qdesn_static_exdqlm_crossstudy_preflight_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

preflight_lines <- c(
  sprintf("- generated_at: `%s`", preflight_manifest$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path_raw),
  sprintf("- outer_report_root: `%s`", run_report_root),
  sprintf("- outer_results_root: `%s`", run_results_root),
  sprintf("- chosen_workers: `%d`", as.integer(workers)),
  sprintf("- active_qdesn_processes_n: `%d`", as.integer(length(active_qdesn_processes))),
  sprintf("- create_plots: `%s`", if (isTRUE(create_plots)) "TRUE" else "FALSE"),
  "",
  "## Scope Decision",
  "- study_surface: `static only`",
  "- include_dynamic_row15_sidecar: `FALSE`",
  "- exclude_gausmix_tau_0p50: `TRUE`",
  "",
  "## Reference Inventory",
  sprintf("- reference_root_dirs: `%d`", as.integer(reference_summary$reference_root_dirs_n)),
  sprintf("- paper_signoff_roots: `%d`", as.integer(reference_summary$reference_paper_signoff_roots)),
  sprintf("- shrink_signoff_roots: `%d`", as.integer(reference_summary$reference_shrink_signoff_roots)),
  sprintf("- unique_dataset_cells: `%d`", as.integer(reference_summary$reference_unique_dataset_cells)),
  "",
  "## QDESN Analog Grid",
  sprintf("- enabled_roots: `%d`", as.integer(grid_summary$enabled_roots)),
  sprintf("- unique_dataset_cells: `%d`", as.integer(grid_summary$unique_dataset_cells)),
  sprintf("- families: `%s`", paste(grid_summary$families, collapse = ", ")),
  sprintf("- taus: `%s`", paste(grid_summary$taus, collapse = ", ")),
  sprintf("- fit_sizes: `%s`", paste(grid_summary$fit_sizes, collapse = ", ")),
  sprintf("- root_kinds: `%s`", paste(grid_summary$root_kinds, collapse = ", ")),
  sprintf("- priors: `%s`", paste(grid_summary$priors, collapse = ", ")),
  "",
  "## Active QDESN Processes",
  if (length(active_qdesn_processes)) paste0("- ", active_qdesn_processes) else "- none"
)
writeLines(summary_md("QDESN Static exdqlm Cross-Study Preflight", preflight_lines), file.path(launch_root, "qdesn_static_exdqlm_crossstudy_preflight.md"))

if (isTRUE(verbose)) {
  cat(sprintf("[qdesn-static-exdqlm-crossstudy] run_tag=%s\n", run_tag))
  cat(sprintf("[qdesn-static-exdqlm-crossstudy] workers=%d\n", workers))
  cat(sprintf("[qdesn-static-exdqlm-crossstudy] prepare_only=%s\n", if (prepare_only) "TRUE" else "FALSE"))
}

if (isTRUE(prepare_only)) {
  cat(sprintf("Preflight manifest: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_preflight_manifest.json")))
  cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_preflight.md")))
  cat(sprintf("Planned outer report root: %s\n", run_report_root))
  cat(sprintf("Planned outer results root: %s\n", run_results_root))
  quit(status = 0)
}

run <- exdqlm:::qdesn_static_crossstudy_run_campaign(
  grid_path = grid_path_raw,
  defaults_path = defaults_path,
  results_root = run_results_root,
  report_root = run_report_root,
  verbose = verbose,
  workers = workers,
  create_plots = create_plots,
  reference_inventory = reference_inventory
)

campaign_report_root <- normalizePath(run$report_root, winslash = "/", mustWork = TRUE)
campaign_results_root <- normalizePath(run$results_root, winslash = "/", mustWork = TRUE)
healthcheck_lines <- cmd_lines(
  "Rscript",
  c(
    "scripts/healthcheck_qdesn_static_exdqlm_crossstudy_validation.R",
    "--run-tag", run_tag,
    "--defaults", defaults_path,
    "--grid", grid_path_raw,
    "--results-root", base_results_root,
    "--report-root", base_report_root
  )
)
writeLines(summary_md("QDESN Static exdqlm Cross-Study Healthcheck", c("```text", healthcheck_lines, "```")), file.path(launch_root, "qdesn_static_exdqlm_crossstudy_healthcheck.md"))

campaign_summary_path <- file.path(campaign_report_root, "summary", "qdesn_static_crossstudy_summary.md")
recommendation <- as.character(run$summary$recommendation %||% NA_character_)[1L]
root_status_mix <- if (nrow(run$summary$root_summary)) {
  count_table_df(as.character(run$summary$root_summary$root_status), "root_status")
} else {
  data.frame(stringsAsFactors = FALSE)
}
write_csv(root_status_mix, file.path(launch_root, "root_status_mix.csv"))

launch_manifest <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  defaults_path = defaults_path,
  grid_path = grid_path_raw,
  outer_report_root = run_report_root,
  outer_results_root = run_results_root,
  campaign_report_root = campaign_report_root,
  campaign_results_root = campaign_results_root,
  chosen_workers = workers,
  recommendation = recommendation,
  summary_path = campaign_summary_path,
  comparison_root = file.path(campaign_report_root, "comparison_vs_reference")
)
jsonlite::write_json(
  launch_manifest,
  file.path(launch_root, "qdesn_static_exdqlm_crossstudy_launch_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

if (isTRUE(verbose)) {
  cat(sprintf("Campaign report root: %s\n", campaign_report_root))
  cat(sprintf("Campaign results root: %s\n", campaign_results_root))
  cat(sprintf("Campaign summary: %s\n", campaign_summary_path))
  cat(sprintf("Launch manifest: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_launch_manifest.json")))
}
