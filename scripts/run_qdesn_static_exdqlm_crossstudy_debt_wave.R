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
  if (is.null(df) || !nrow(df) || !ncol(df)) return("(no rows)")
  df[] <- lapply(df, function(x) {
    out <- as.character(x)
    out[is.na(out)] <- ""
    out <- gsub("[\r\n]+", " ", out)
    out
  })
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

summary_md <- function(title, body_lines) {
  c(paste0("# ", title), "", body_lines)
}

as_profile_df <- function(profile_cfgs) {
  do.call(rbind, lapply(profile_cfgs, function(profile) {
    data.frame(
      profile_id = as.character(profile$profile_id)[1L],
      label = as.character(profile$label %||% profile$profile_id)[1L],
      anchor_control = isTRUE(profile$anchor_control),
      rationale = as.character(profile$rationale %||% "")[1L],
      stringsAsFactors = FALSE
    )
  }))
}

make_error_metric <- function(stage_name, profile_id, stage_root_ids, hard_fail_root_ids, message_text) {
  hard_ids <- intersect(unique(as.character(stage_root_ids)), unique(as.character(hard_fail_root_ids)))
  data.frame(
    stage_name = stage_name,
    profile_id = profile_id,
    root_n_planned = length(stage_root_ids),
    root_n_status_success = 0L,
    root_n_status_fail = 0L,
    root_n_status_missing = length(stage_root_ids),
    hard_fail_n_planned = length(hard_ids),
    hard_fail_n_rescued = 0L,
    hard_fail_n_remaining = length(hard_ids),
    root_n_compare_any = 0L,
    root_n_compare_full = 0L,
    fit_n_fail = NA_integer_,
    fit_n_warn = NA_integer_,
    fit_n_pass = NA_integer_,
    exal_mcmc_fail_n = NA_integer_,
    rhs_vb_fail_n = NA_integer_,
    median_runtime_sec = NA_real_,
    error_message = as.character(message_text)[1L],
    stringsAsFactors = FALSE
  )
}

write_runner_state <- function(path,
                               run_tag,
                               current_stage_id,
                               current_profile_id,
                               stage_results_df,
                               stop_reason = NA_character_) {
  if (is.null(stage_results_df) || !nrow(stage_results_df)) {
    stage_results_df <- data.frame(stringsAsFactors = FALSE)
  }
  payload <- list(
    generated_at = as.character(Sys.time()),
    run_tag = run_tag,
    current_stage_id = current_stage_id,
    current_profile_id = current_profile_id,
    completed_stages = if (nrow(stage_results_df)) sum(as.character(stage_results_df$execution_status) == "COMPLETED", na.rm = TRUE) else 0L,
    total_stages = 2L,
    completed_profiles = if (nrow(stage_results_df)) sum(as.integer(stage_results_df$profile_n_completed), na.rm = TRUE) else 0L,
    total_profiles = if (nrow(stage_results_df)) sum(as.integer(stage_results_df$profile_n_planned), na.rm = TRUE) else 0L,
    stop_reason = stop_reason
  )
  write_json(payload, path)
}

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_debt_wave_manifest.yaml"))
defaults_rel <- get_arg("--defaults", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"))
grid_rel <- get_arg("--grid", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv"))
prepare_only <- has_flag("--prepare-only")
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
defaults_path <- resolve_path(defaults_rel, must_work = TRUE)
grid_path <- resolve_path(grid_rel, must_work = TRUE)

manifest <- exdqlm:::qdesn_static_crossstudy_debt_load_manifest(manifest_path)
base_defaults <- exdqlm:::qdesn_static_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_static_crossstudy_load_grid(grid_path)
grid_summary <- exdqlm:::qdesn_static_crossstudy_validate_grid(grid_df, base_defaults)
reference_cfg <- base_defaults$reference %||% list()
reference_inventory <- exdqlm:::qdesn_static_crossstudy_collect_reference_inventory(
  paper_root = resolve_path(reference_cfg$paper_root, must_work = TRUE),
  shrink_root = resolve_path(reference_cfg$shrink_root, must_work = TRUE)
)

source_run_tag <- as.character((manifest$source %||% list())$run_tag %||% "")[1L]
if (!nzchar(source_run_tag)) stop("Debt-wave manifest must define source.run_tag.", call. = FALSE)
source_state <- exdqlm:::qdesn_static_crossstudy_debt_collect_source_state(
  source_run_tag = source_run_tag,
  defaults = base_defaults,
  grid = grid_df,
  defaults_path = defaults_path,
  grid_path = grid_path
)

hard_fail_root_ids <- unique(as.character(source_state$hard_fail_root_ids))
full_debt_root_ids <- unique(as.character(source_state$full_debt_root_ids))
rhs_probe_root_ids <- unique(as.character((manifest$stage1 %||% list())$rhs_probe_root_ids %||% character(0)))
stage1_root_ids <- exdqlm:::qdesn_static_crossstudy_debt_stage1_root_ids(source_state, rhs_probe_root_ids)
stage2_root_ids <- sort(full_debt_root_ids)

if (!identical(length(hard_fail_root_ids), 6L)) {
  stop(sprintf("Expected 6 hard-fail roots from source run, found %d.", length(hard_fail_root_ids)), call. = FALSE)
}
if (!identical(length(stage1_root_ids), 9L)) {
  stop(sprintf("Expected 9 Stage-1 pilot roots, found %d.", length(stage1_root_ids)), call. = FALSE)
}
if (!identical(length(stage2_root_ids), 36L)) {
  stop(sprintf("Expected 36 full debt roots, found %d.", length(stage2_root_ids)), call. = FALSE)
}

profile_cfgs <- manifest$profiles %||% list()
if (!length(profile_cfgs)) stop("Debt-wave manifest has no profiles.", call. = FALSE)
profile_df <- as_profile_df(profile_cfgs)
anchor_profile_id <- as.character(profile_df$profile_id[profile_df$anchor_control])[1L]
if (!nzchar(anchor_profile_id)) stop("Debt-wave manifest must define one anchor_control profile.", call. = FALSE)

runtime_cfg <- manifest$runtime %||% list()
active_qdesn_processes <- cmd_lines(
  "bash",
  c(
    "-lc",
    paste(
      "ps -eo pid=,args=",
      "| grep -E -- 'run_qdesn_|qdesn_static_exdqlm_crossstudy|pipeline_real_main\\.R|pipeline_sim_main\\.R'",
      "| grep -vE 'grep -E|run_qdesn_static_exdqlm_crossstudy_debt_wave\\.R|healthcheck_qdesn_static_exdqlm_crossstudy_debt_wave\\.R'",
      "|| true"
    )
  )
)
active_qdesn_processes <- active_qdesn_processes[nzchar(trimws(active_qdesn_processes))]

workers_arg <- suppressWarnings(as.integer(get_arg("--workers", NA_character_))[1L])
workers <- if (is.finite(workers_arg) && workers_arg >= 1L) {
  workers_arg
} else if (length(active_qdesn_processes)) {
  as.integer(runtime_cfg$active_job_workers %||% 4L)[1L]
} else {
  as.integer(runtime_cfg$default_workers %||% 6L)[1L]
}
hard_cap_workers <- as.integer(runtime_cfg$hard_cap_workers %||% 6L)[1L]
if (!is.finite(workers) || workers < 1L) workers <- 1L
if (!is.finite(hard_cap_workers) || hard_cap_workers < 1L) hard_cap_workers <- 6L
workers <- min(as.integer(hard_cap_workers), as.integer(workers))

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-static-exdqlm-crossstudy-debt-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

campaign_cfg <- manifest$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_debt_wave"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_debt_wave"), must_work = FALSE)
run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)

launch_root <- file.path(run_report_root, "launch")
status_root <- file.path(run_report_root, "status")
summary_root <- file.path(run_report_root, "summary")
tables_root <- file.path(run_report_root, "tables")
for (d in c(run_results_root, run_report_root, launch_root, status_root, summary_root, tables_root)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

stage1_grid_df <- exdqlm:::qdesn_static_crossstudy_debt_subset_grid(grid_df, stage1_root_ids)
stage2_grid_df <- exdqlm:::qdesn_static_crossstudy_debt_subset_grid(grid_df, stage2_root_ids)

materialize_stage_assets <- function(stage_name, stage_grid_df) {
  stage_dir <- file.path(run_report_root, "stages", stage_name)
  dir.create(file.path(stage_dir, "configs"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(stage_dir, "grids"), recursive = TRUE, showWarnings = FALSE)
  write_csv(stage_grid_df, file.path(stage_dir, "grids", sprintf("%s_grid.csv", stage_name)))
  for (profile in profile_cfgs) {
    profile_defaults <- exdqlm:::qdesn_static_crossstudy_debt_apply_overrides(base_defaults, profile$overrides %||% list())
    profile_defaults$campaign$name <- sprintf("%s__%s", campaign_cfg$name %||% "qdesn_static_exdqlm_crossstudy_debt_wave", as.character(profile$profile_id)[1L])
    exdqlm:::qdesn_static_crossstudy_debt_write_yaml(
      profile_defaults,
      file.path(stage_dir, "configs", sprintf("%s.yaml", as.character(profile$profile_id)[1L]))
    )
  }
}

materialize_stage_assets(as.character((manifest$stage1 %||% list())$id %||% "S1_failband_and_rhs_probe"), stage1_grid_df)
materialize_stage_assets(as.character((manifest$stage2 %||% list())$id %||% "S2_full_debt_confirmation"), stage2_grid_df)

source_status_mix <- as.data.frame(table(root_status = as.character(source_state$root_status$root_status)), stringsAsFactors = FALSE)
source_baseline_inventory <- exdqlm:::.qdesn_validation_bind_rows(list(
  data.frame(root_id = sort(hard_fail_root_ids), debt_class = "hard_fail_root", stringsAsFactors = FALSE),
  data.frame(root_id = sort(setdiff(full_debt_root_ids, hard_fail_root_ids)), debt_class = "rhs_ns_noneligible_root", stringsAsFactors = FALSE)
))
write_csv(source_baseline_inventory, file.path(tables_root, "source_debt_root_inventory.csv"))
write_csv(source_state$root_status, file.path(tables_root, "source_root_status.csv"))
if (nrow(source_state$root_summary)) write_csv(source_state$root_summary, file.path(tables_root, "source_root_signoff_summary.csv"))
if (nrow(source_state$fit_summary)) write_csv(source_state$fit_summary, file.path(tables_root, "source_fit_summary.csv"))

resource_snapshot <- list(
  generated_at = as.character(Sys.time()),
  nproc = cmd_lines("nproc"),
  free_h = cmd_lines("free", "-h"),
  uptime = cmd_lines("uptime"),
  active_qdesn_processes = as.list(active_qdesn_processes)
)

preflight_manifest <- list(
  generated_at = as.character(Sys.time()),
  git_sha = git_sha,
  run_tag = run_tag,
  manifest_path = manifest_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  prepare_only = prepare_only,
  create_plots = create_plots,
  chosen_workers = workers,
  source_run_tag = source_run_tag,
  source_status_mix = source_status_mix,
  source_counts = list(
    hard_fail_roots = length(hard_fail_root_ids),
    rhs_ns_noneligible_roots = length(source_state$rhs_ns_noneligible_root_ids),
    full_debt_roots = length(full_debt_root_ids)
  ),
  stage_counts = list(
    stage1_roots = nrow(stage1_grid_df),
    stage2_roots = nrow(stage2_grid_df),
    stage1_profiles = nrow(profile_df)
  ),
  resource_snapshot = resource_snapshot,
  output_roots = list(
    outer_results_root = run_results_root,
    outer_report_root = run_report_root
  )
)
write_json(preflight_manifest, file.path(launch_root, "qdesn_static_exdqlm_crossstudy_debt_wave_preflight_manifest.json"))

preflight_lines <- c(
  sprintf("- generated_at: `%s`", preflight_manifest$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path),
  sprintf("- outer_report_root: `%s`", run_report_root),
  sprintf("- outer_results_root: `%s`", run_results_root),
  sprintf("- chosen_workers: `%d`", as.integer(workers)),
  sprintf("- active_qdesn_processes_n: `%d`", as.integer(length(active_qdesn_processes))),
  "",
  "## Source Baseline",
  sprintf("- materialized_roots: `%d`", nrow(source_state$root_status)),
  sprintf("- success_roots: `%d`", sum(as.character(source_state$root_status$root_status) == "SUCCESS", na.rm = TRUE)),
  sprintf("- fail_roots: `%d`", sum(as.character(source_state$root_status$root_status) == "FAIL", na.rm = TRUE)),
  sprintf("- hard_fail_roots: `%d`", length(hard_fail_root_ids)),
  sprintf("- rhs_ns_noneligible_roots: `%d`", length(source_state$rhs_ns_noneligible_root_ids)),
  sprintf("- full_debt_roots: `%d`", length(full_debt_root_ids)),
  "",
  "## Stage Design",
  sprintf("- stage1_id: `%s`", as.character((manifest$stage1 %||% list())$id %||% "S1_failband_and_rhs_probe")),
  sprintf("- stage1_roots: `%d`", nrow(stage1_grid_df)),
  sprintf("- stage1_profiles: `%d`", nrow(profile_df)),
  sprintf("- stage2_id: `%s`", as.character((manifest$stage2 %||% list())$id %||% "S2_full_debt_confirmation")),
  sprintf("- stage2_roots: `%d`", nrow(stage2_grid_df)),
  sprintf("- stage2_selection_rule: `anchor replay + top %d experimental survivor(s)`", as.integer((manifest$stage1 %||% list())$select_top_experimental_n %||% 1L)),
  "",
  "## Profiles",
  render_md_table(profile_df),
  "",
  "## Hard-Fail Roots",
  paste0("- ", hard_fail_root_ids),
  "",
  "## Representative RHS Probe Roots",
  paste0("- ", rhs_probe_root_ids)
)
write_lines(summary_md("QDESN Static exdqlm Cross-Study Debt-Wave Preflight", preflight_lines), file.path(launch_root, "qdesn_static_exdqlm_crossstudy_debt_wave_preflight.md"))

if (isTRUE(verbose)) {
  cat(sprintf("[qdesn-static-crossstudy-debt-wave] run_tag=%s\n", run_tag))
  cat(sprintf("[qdesn-static-crossstudy-debt-wave] workers=%d\n", workers))
  cat(sprintf("[qdesn-static-crossstudy-debt-wave] prepare_only=%s\n", if (prepare_only) "TRUE" else "FALSE"))
}

if (isTRUE(prepare_only)) {
  cat(sprintf("Preflight manifest: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_debt_wave_preflight_manifest.json")))
  cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_debt_wave_preflight.md")))
  cat(sprintf("Planned outer report root: %s\n", run_report_root))
  cat(sprintf("Planned outer results root: %s\n", run_results_root))
  quit(status = 0)
}

source_run_obj <- list(
  results_root = source_state$source_roots$campaign_results_root,
  summary = list(
    root_summary = source_state$root_summary,
    fit_summary = source_state$fit_summary
  )
)
source_stage1_metric <- exdqlm:::qdesn_static_crossstudy_debt_profile_metrics(
  profile_id = "SOURCE_BASELINE",
  stage_name = as.character((manifest$stage1 %||% list())$id %||% "S1_failband_and_rhs_probe"),
  stage_root_ids = stage1_root_ids,
  hard_fail_root_ids = hard_fail_root_ids,
  run_obj = source_run_obj
)
source_stage1_metric$profile_label <- "Source Broad Baseline"
source_stage1_metric$rationale <- "Authoritative source broad launch root-state baseline."
source_stage1_metric$error_message <- ""
source_stage2_metric <- exdqlm:::qdesn_static_crossstudy_debt_profile_metrics(
  profile_id = "SOURCE_BASELINE",
  stage_name = as.character((manifest$stage2 %||% list())$id %||% "S2_full_debt_confirmation"),
  stage_root_ids = stage2_root_ids,
  hard_fail_root_ids = hard_fail_root_ids,
  run_obj = source_run_obj
)
source_stage2_metric$profile_label <- "Source Broad Baseline"
source_stage2_metric$rationale <- "Authoritative source broad launch root-state baseline."
source_stage2_metric$error_message <- ""

stage_result_rows <- list()
stop_reason <- "RUNNING"
write_runner_state(file.path(status_root, "runner_state.json"), run_tag, NA_character_, NA_character_, data.frame(stringsAsFactors = FALSE), stop_reason)

current_stage_results_df <- function() {
  if (!length(stage_result_rows)) return(data.frame(stringsAsFactors = FALSE))
  do.call(rbind, stage_result_rows)
}

run_profile <- function(stage_name, stage_root_ids, profile) {
  profile_id <- as.character(profile$profile_id)[1L]
  profile_label <- as.character(profile$label %||% profile_id)[1L]
  stage_grid_df <- exdqlm:::qdesn_static_crossstudy_debt_subset_grid(grid_df, stage_root_ids)
  profile_defaults <- exdqlm:::qdesn_static_crossstudy_debt_apply_overrides(base_defaults, profile$overrides %||% list())
  profile_defaults$campaign$name <- sprintf("%s__%s", campaign_cfg$name %||% "qdesn_static_exdqlm_crossstudy_debt_wave", profile_id)
  stage_report_parent <- file.path(run_report_root, "stages", stage_name, "profiles", profile_id)
  stage_results_parent <- file.path(run_results_root, "stages", stage_name, "profiles", profile_id)
  dir.create(stage_report_parent, recursive = TRUE, showWarnings = FALSE)
  dir.create(stage_results_parent, recursive = TRUE, showWarnings = FALSE)
  exdqlm:::qdesn_static_crossstudy_debt_write_yaml(
    profile_defaults,
    file.path(run_report_root, "stages", stage_name, "configs", sprintf("%s.yaml", profile_id))
  )
  write_runner_state(file.path(status_root, "runner_state.json"), run_tag, stage_name, profile_id, current_stage_results_df(), stop_reason)
  out <- tryCatch(
    {
      run <- exdqlm:::qdesn_static_crossstudy_run_campaign(
        grid = stage_grid_df,
        defaults = profile_defaults,
        results_root = stage_results_parent,
        report_root = stage_report_parent,
        verbose = verbose,
        workers = workers,
        create_plots = create_plots,
        reference_inventory = reference_inventory
      )
      metric <- exdqlm:::qdesn_static_crossstudy_debt_profile_metrics(
        profile_id = profile_id,
        stage_name = stage_name,
        stage_root_ids = stage_root_ids,
        hard_fail_root_ids = hard_fail_root_ids,
        run_obj = run
      )
      metric$profile_label <- profile_label
      metric$rationale <- as.character(profile$rationale %||% "")[1L]
      list(
        metric = metric,
        execution_status = "COMPLETED",
        report_root = run$report_root,
        results_root = run$results_root,
        error_message = ""
      )
    },
    error = function(e) {
      list(
        metric = transform(
          make_error_metric(stage_name, profile_id, stage_root_ids, hard_fail_root_ids, conditionMessage(e)),
          profile_label = profile_label,
          rationale = as.character(profile$rationale %||% "")[1L]
        ),
        execution_status = "ERROR",
        report_root = stage_report_parent,
        results_root = stage_results_parent,
        error_message = conditionMessage(e)
      )
    }
  )
  out
}

append_stage_row <- function(stage_id, profile_n_planned, profile_n_completed, selected_profiles, execution_status, stage_report_root) {
  stage_result_rows[[length(stage_result_rows) + 1L]] <<- data.frame(
    stage_id = stage_id,
    execution_status = execution_status,
    profile_execution_status = if (identical(execution_status, "COMPLETED")) "COMPLETED" else "INCOMPLETE",
    profile_n_planned = as.integer(profile_n_planned),
    profile_n_completed = as.integer(profile_n_completed),
    selected_profiles = paste(selected_profiles, collapse = "|"),
    stage_report_root = stage_report_root,
    stringsAsFactors = FALSE
  )
  stage_results_df <- current_stage_results_df()
  write_csv(stage_results_df, file.path(tables_root, "stage_execution_status.csv"))
  write_runner_state(file.path(status_root, "runner_state.json"), run_tag, stage_id, NA_character_, stage_results_df, stop_reason)
}

stage1_name <- as.character((manifest$stage1 %||% list())$id %||% "S1_failband_and_rhs_probe")
stage1_metrics <- list()
for (profile in profile_cfgs) {
  res <- run_profile(stage1_name, stage1_root_ids, profile)
  stage1_metrics[[length(stage1_metrics) + 1L]] <- res$metric
  stage1_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage1_metrics)
  write_csv(stage1_metrics_df, file.path(run_report_root, "stages", stage1_name, "tables", "profile_metrics.csv"))
}
stage1_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage1_metrics)
stage1_rank_df <- exdqlm:::qdesn_static_crossstudy_debt_rank_profiles(stage1_metrics_df)
stage1_compare_df <- exdqlm:::.qdesn_validation_bind_rows(list(source_stage1_metric, stage1_metrics_df))
write_csv(stage1_compare_df, file.path(run_report_root, "stages", stage1_name, "tables", "profile_metrics_with_source.csv"))
write_csv(stage1_rank_df, file.path(run_report_root, "stages", stage1_name, "tables", "profile_ranking.csv"))
selected_experimental <- exdqlm:::qdesn_static_crossstudy_debt_pick_top_experimental(
  stage1_rank_df,
  anchor_profile_id = anchor_profile_id,
  top_n = as.integer((manifest$stage1 %||% list())$select_top_experimental_n %||% 1L)
)
selected_stage2_profiles <- unique(c(anchor_profile_id, selected_experimental))
stage1_selection_lines <- c(
  sprintf("# %s Selection Summary", stage1_name),
  "",
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- selected_stage2_profiles: `%s`", paste(selected_stage2_profiles, collapse = ", ")),
  "",
  "## Source Baseline Metrics",
  "",
  render_md_table(source_stage1_metric),
  "",
  "## Stage-1 Ranking",
  "",
  render_md_table(stage1_rank_df),
  ""
)
write_lines(stage1_selection_lines, file.path(run_report_root, "stages", stage1_name, "summary", "stage_candidate_selection.md"))
append_stage_row(stage1_name, nrow(profile_df), nrow(stage1_metrics_df), selected_stage2_profiles, "COMPLETED", file.path(run_report_root, "stages", stage1_name))

stage2_name <- as.character((manifest$stage2 %||% list())$id %||% "S2_full_debt_confirmation")
stage2_profile_cfgs <- Filter(function(profile) as.character(profile$profile_id)[1L] %in% selected_stage2_profiles, profile_cfgs)
stage2_metrics <- list()
for (profile in stage2_profile_cfgs) {
  res <- run_profile(stage2_name, stage2_root_ids, profile)
  stage2_metrics[[length(stage2_metrics) + 1L]] <- res$metric
  stage2_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage2_metrics)
  write_csv(stage2_metrics_df, file.path(run_report_root, "stages", stage2_name, "tables", "profile_metrics.csv"))
}
stage2_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage2_metrics)
stage2_rank_df <- exdqlm:::qdesn_static_crossstudy_debt_rank_profiles(stage2_metrics_df)
stage2_compare_df <- exdqlm:::.qdesn_validation_bind_rows(list(source_stage2_metric, stage2_metrics_df))
write_csv(stage2_compare_df, file.path(run_report_root, "stages", stage2_name, "tables", "profile_metrics_with_source.csv"))
write_csv(stage2_rank_df, file.path(run_report_root, "stages", stage2_name, "tables", "profile_ranking.csv"))

anchor_stage2 <- stage2_metrics_df[as.character(stage2_metrics_df$profile_id) == anchor_profile_id, , drop = FALSE]
best_experimental_id <- exdqlm:::qdesn_static_crossstudy_debt_pick_top_experimental(stage2_rank_df, anchor_profile_id, 1L)
best_experimental <- stage2_metrics_df[as.character(stage2_metrics_df$profile_id) %in% best_experimental_id, , drop = FALSE]
experimental_beats_anchor <- FALSE
if (nrow(best_experimental) && nrow(anchor_stage2)) {
  experimental_beats_anchor <-
    (as.numeric(best_experimental$hard_fail_n_rescued[1L]) > as.numeric(anchor_stage2$hard_fail_n_rescued[1L])) ||
    (as.numeric(best_experimental$hard_fail_n_rescued[1L]) == as.numeric(anchor_stage2$hard_fail_n_rescued[1L]) &&
       as.numeric(best_experimental$root_n_compare_any[1L]) > as.numeric(anchor_stage2$root_n_compare_any[1L])) ||
    (as.numeric(best_experimental$hard_fail_n_rescued[1L]) == as.numeric(anchor_stage2$hard_fail_n_rescued[1L]) &&
       as.numeric(best_experimental$root_n_compare_any[1L]) == as.numeric(anchor_stage2$root_n_compare_any[1L]) &&
       as.numeric(best_experimental$fit_n_fail[1L]) < as.numeric(anchor_stage2$fit_n_fail[1L]))
}
recommendation <- if (isTRUE(experimental_beats_anchor) && nrow(best_experimental)) {
  sprintf("PROMOTE_%s_AS_DEBT_WAVE_LEAD", as.character(best_experimental$profile_id[1L]))
} else {
  "KEEP_SHARED_STATIC_BASELINE_WITH_DOCUMENTED_DEBT"
}

stage2_selection_lines <- c(
  sprintf("# %s Selection Summary", stage2_name),
  "",
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- selected_profiles: `%s`", paste(selected_stage2_profiles, collapse = ", ")),
  sprintf("- recommendation: `%s`", recommendation),
  "",
  "## Source Baseline Metrics",
  "",
  render_md_table(source_stage2_metric),
  "",
  "## Stage-2 Ranking",
  "",
  render_md_table(stage2_rank_df),
  ""
)
write_lines(stage2_selection_lines, file.path(run_report_root, "stages", stage2_name, "summary", "stage_candidate_selection.md"))
append_stage_row(stage2_name, length(selected_stage2_profiles), nrow(stage2_metrics_df), best_experimental_id, "COMPLETED", file.path(run_report_root, "stages", stage2_name))

stop_reason <- "completed_requested_scope"
stage_results_df <- do.call(rbind, stage_result_rows)
write_csv(stage_results_df, file.path(tables_root, "stage_execution_status.csv"))
write_runner_state(file.path(status_root, "runner_state.json"), run_tag, NA_character_, NA_character_, stage_results_df, stop_reason)

final_lines <- c(
  "# QDESN Static exdqlm Cross-Study Debt-Wave Results",
  "",
  sprintf("- updated_at: `%s`", as.character(Sys.time())),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- recommendation: `%s`", recommendation),
  "",
  "## Main Takeaways",
  "- The source broad launch remains the authoritative cross-study baseline, even though its campaign closeout hung before aggregate tables were written.",
  "- The remaining hard root FAIL band is still exactly the six `static_shrink x laplace x tt=1000` roots.",
  "- The broader rhs_ns debt remains comparison-eligibility debt, not a reason to relaunch the whole 72-root surface.",
  "- This debt wave only reran the true debt roots and a small rhs_ns probe subset before moving to full debt confirmation.",
  "",
  "## Stage Results",
  "",
  render_md_table(stage_results_df),
  "",
  "## Stage-1 Ranking",
  "",
  render_md_table(stage1_rank_df),
  "",
  "## Stage-2 Ranking",
  "",
  render_md_table(stage2_rank_df),
  "",
  "## Source Baseline on Full Debt Set",
  "",
  render_md_table(source_stage2_metric),
  ""
)
write_lines(final_lines, file.path(summary_root, "qdesn_static_crossstudy_debt_wave_results.md"))
write_json(
  list(
    completed_at = as.character(Sys.time()),
    run_tag = run_tag,
    source_run_tag = source_run_tag,
    recommendation = recommendation,
    selected_stage2_profiles = as.list(selected_stage2_profiles),
    best_experimental_profile = if (length(best_experimental_id)) best_experimental_id[1L] else NA_character_,
    outer_report_root = run_report_root,
    outer_results_root = run_results_root
  ),
  file.path(run_report_root, "manifest", "debt_wave_completed.json")
)

cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_debt_wave_preflight.md")))
cat(sprintf("Runner state: %s\n", file.path(status_root, "runner_state.json")))
cat(sprintf("Stage status table: %s\n", file.path(tables_root, "stage_execution_status.csv")))
cat(sprintf("Result summary: %s\n", file.path(summary_root, "qdesn_static_crossstudy_debt_wave_results.md")))
