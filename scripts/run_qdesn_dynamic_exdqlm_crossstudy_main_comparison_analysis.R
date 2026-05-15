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
  if (is.list(df) && !is.data.frame(df)) {
    nm <- names(df)
    if (is.null(nm) || !length(nm)) {
      df <- data.frame(value = unlist(df, use.names = FALSE), stringsAsFactors = FALSE)
    } else {
      df <- data.frame(
        metric = nm,
        value = vapply(df, function(x) paste(as.character(x), collapse = ", "), character(1)),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!is.data.frame(df)) {
    df <- as.data.frame(df, stringsAsFactors = FALSE)
  }
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

state_expectation_table <- function(expected_state, source_state) {
  expected_state <- expected_state %||% list()
  actual <- c(
    fit_rows = nrow(source_state$fit_summary),
    fit_pass_rows = sum(as.character(source_state$fit_summary$signoff_grade) == "PASS", na.rm = TRUE),
    fit_warn_rows = sum(as.character(source_state$fit_summary$signoff_grade) == "WARN", na.rm = TRUE),
    fit_fail_rows = sum(as.character(source_state$fit_summary$signoff_grade) == "FAIL", na.rm = TRUE),
    root_rows = nrow(source_state$root_summary),
    root_status_fail_rows = sum(as.character(source_state$root_summary$root_status) == "FAIL", na.rm = TRUE),
    root_compare_any_rows = sum(as.logical(source_state$root_summary$root_comparison_eligible_any), na.rm = TRUE),
    root_compare_full_rows = sum(as.logical(source_state$root_summary$root_comparison_eligible_full), na.rm = TRUE),
    local_baseline_rows = nrow(source_state$local_baseline_map %||% data.frame(stringsAsFactors = FALSE)),
    root_override_rows = nrow(source_state$root_override_map %||% data.frame(stringsAsFactors = FALSE))
  )
  expected_names <- union(names(actual), names(expected_state))
  rows <- lapply(expected_names, function(metric) {
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

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_main_comparison_analysis_manifest.yaml"))
defaults_rel <- get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"))
grid_rel <- get_arg("--grid", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"))
prepare_only <- has_flag("--prepare-only")

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
defaults_path <- resolve_path(defaults_rel, must_work = TRUE)
grid_path <- resolve_path(grid_rel, must_work = TRUE)

manifest <- exdqlm:::qdesn_dynamic_maincmp_load_manifest(manifest_path)
defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path)
grid_summary <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid_df, defaults)

reference_cfg <- defaults$reference %||% list()
reference_validation_defaults <- defaults
reference_contract_override <- manifest$reference_contract_override %||% list()
if (is.list(reference_contract_override) && length(reference_contract_override)) {
  reference_validation_defaults$reference_contract <- utils::modifyList(
    defaults$reference_contract %||% list(),
    reference_contract_override
  )
}
reference_inventory <- exdqlm:::qdesn_dynamic_crossstudy_collect_reference_inventory(
  reference_root = resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
)
invisible(exdqlm:::qdesn_dynamic_crossstudy_validate_reference_inventory(reference_inventory, reference_validation_defaults))

source_cfg <- manifest$source %||% list()
source_run_tag <- as.character(source_cfg$run_tag %||% "")[1L]
if (!nzchar(source_run_tag)) stop("Main comparison manifest must define source.run_tag.", call. = FALSE)
source_root_profile_overrides <- source_cfg[["root_profile_overrides"]] %||% list()
root_override_csv <- as.character(source_cfg[["root_profile_overrides_csv"]] %||% "")[1L]
if (nzchar(trimws(root_override_csv))) {
  source_root_profile_overrides <- c(
    source_root_profile_overrides,
    exdqlm:::qdesn_dynamic_maincmp_load_root_profile_overrides_csv(root_override_csv, repo_root = repo_root)
  )
}
source_state <- exdqlm:::qdesn_dynamic_crossstudy_fitfail_collect_source_state(
  source_run_tag = source_run_tag,
  source_report_root = source_cfg$report_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_residual_fail_closure_wave"),
  source_mode = source_cfg$mode %||% "prior_fitfail_wave",
  source_stage_profile_overrides = source_cfg$stage_profile_overrides %||% list(),
  source_root_profile_overrides = source_root_profile_overrides,
  defaults = defaults,
  grid = grid_df,
  defaults_path = defaults_path,
  grid_path = grid_path
)
source_state$source_label <- as.character(source_cfg$source_label %||% source_state$source_label)[1L]
source_state$source_rationale <- as.character(source_cfg$source_rationale %||% source_state$source_rationale)[1L]

analysis_cfg <- manifest$analysis %||% list()
refresh_fit_metrics <- isTRUE(analysis_cfg$refresh_fit_metrics %||% TRUE)
report_root <- resolve_path(
  analysis_cfg$report_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_main_comparison_analysis"),
  must_work = FALSE
)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag_prefix <- as.character(manifest$meta$run_tag_prefix %||% "qdesn-dynamic-exdqlm-crossstudy-maincmp")[1L]
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("%s-%s__git-%s", run_tag_prefix, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

output_root <- file.path(report_root, run_tag)
launch_root <- file.path(output_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

expectation_df <- state_expectation_table(manifest$expected_state, source_state)
expected_checks <- expectation_df$matches
expected_checks <- expected_checks[!is.na(expected_checks)]
if (length(expected_checks) && !all(tolower(expected_checks) == "true")) {
  stop("Authoritative source state does not match the manifest expectations.", call. = FALSE)
}

preflight_lines <- c(
  "# QDESN Dynamic Main Comparison Analysis Preflight",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- prepare_only: `%s`", if (prepare_only) "TRUE" else "FALSE"),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- defaults: `%s`", defaults_path),
  sprintf("- grid: `%s`", grid_path),
  "",
  "## Source",
  sprintf("- source_run_tag: `%s`", source_state$source_run_tag),
  sprintf("- source_mode: `%s`", source_state$source_mode),
  sprintf("- source_label: `%s`", source_state$source_label),
  sprintf("- source_report_root: `%s`", source_state$campaign_report_root),
  sprintf("- source_root_profile_overrides: `%d`", length(source_root_profile_overrides)),
  sprintf("- refresh_fit_metrics: `%s`", if (refresh_fit_metrics) "TRUE" else "FALSE"),
  "",
  "## Reference Surface",
  sprintf("- reference_root_dirs: `%d`", length(reference_inventory$root_dirs)),
  sprintf("- reference_fit_rows: `%d`", nrow(reference_inventory$fit_summary)),
  sprintf("- reference_pair_rows: `%d`", nrow(reference_inventory$pairwise_vb_vs_mcmc)),
  sprintf("- reference_root_rows: `%d`", nrow(reference_inventory$root_signoff_summary)),
  sprintf("- reference_contract_override: `%s`", if (length(reference_contract_override)) "TRUE" else "FALSE"),
  "",
  "## Grid",
  sprintf("- qdesn_root_rows: `%d`", nrow(grid_df)),
  sprintf("- qdesn_root_unique: `%d`", length(unique(as.character(grid_df$root_id)))),
  sprintf("- qdesn_fit_rows_expected: `%d`", nrow(grid_df) * 4L),
  "",
  "## Authoritative Source State Checks",
  render_md_table(expectation_df),
  "",
  "## Grid Summary",
  render_md_table(grid_summary),
  "",
  "## Local Baseline Map",
  render_md_table(source_state$local_baseline_map),
  "",
  "## Root Override Map",
  render_md_table(source_state$root_override_map),
  "",
  sprintf("- output_root: `%s`", output_root)
)
write_lines(preflight_lines, file.path(launch_root, "qdesn_dynamic_main_comparison_analysis_preflight.md"))
write_json(list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  prepare_only = prepare_only,
  manifest_path = manifest_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
  source_run_tag = source_state$source_run_tag,
  source_mode = source_state$source_mode,
  refresh_fit_metrics = refresh_fit_metrics
), file.path(launch_root, "run_metadata.json"))

if (prepare_only) {
  cat(sprintf("Prepare-only OK: %s\n", output_root))
  quit(save = "no", status = 0L)
}

analysis_obj <- exdqlm:::qdesn_dynamic_maincmp_write_analysis(
  source_state = source_state,
  reference_inventory = reference_inventory,
  output_root = output_root,
  manifest = manifest,
  defaults = defaults,
  refresh_fit_metrics = refresh_fit_metrics,
  final_wave_run_tag = analysis_cfg$final_wave_evidence_run_tag %||% NA_character_
)

write_json(list(
  completed_at = as.character(Sys.time()),
  run_tag = run_tag,
  output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
  source_run_tag = source_state$source_run_tag,
  comparison_root = normalizePath(file.path(output_root, "comparison_vs_reference"), winslash = "/", mustWork = FALSE),
  fit_surface_rows = nrow(analysis_obj$fit_surface_summary %||% data.frame(stringsAsFactors = FALSE)),
  pair_surface_rows = nrow(analysis_obj$pair_surface_summary %||% data.frame(stringsAsFactors = FALSE)),
  root_inventory_rows = nrow(analysis_obj$root_inventory %||% data.frame(stringsAsFactors = FALSE))
), file.path(launch_root, "completion_metadata.json"))

cat(sprintf("Main comparison analysis complete: %s\n", output_root))
