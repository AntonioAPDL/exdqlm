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
    gsub("[\r\n]+", " ", out)
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

make_error_metric <- function(stage_name, profile_id, stage_root_ids, message_text) {
  data.frame(
    stage_name = stage_name,
    profile_id = profile_id,
    root_n_planned = length(stage_root_ids),
    root_n_status_success = 0L,
    root_n_status_fail = 0L,
    root_n_status_missing = length(stage_root_ids),
    root_n_compare_any = 0L,
    root_n_compare_full = 0L,
    fit_n_fail = NA_integer_,
    fit_n_warn = NA_integer_,
    fit_n_pass = NA_integer_,
    target_fit_fail_n = NA_integer_,
    target_root_fail_n = NA_integer_,
    rhs_vb_fail_n = NA_integer_,
    rhs_mcmc_fail_n = NA_integer_,
    ridge_exal_mcmc_fail_n = NA_integer_,
    exal_mcmc_fail_n = NA_integer_,
    mcmc_fail_n = NA_integer_,
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
                               total_stages,
                               total_profiles,
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
    total_stages = as.integer(total_stages),
    completed_profiles = if (nrow(stage_results_df)) sum(as.integer(stage_results_df$profile_n_completed), na.rm = TRUE) else 0L,
    total_profiles = as.integer(total_profiles),
    stop_reason = stop_reason
  )
  write_json(payload, path)
}

manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml"))
defaults_rel <- get_arg("--defaults", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_defaults.yaml"))
grid_rel <- get_arg("--grid", file.path("config", "validation", "qdesn_static_exdqlm_crossstudy_grid.csv"))
prepare_only <- has_flag("--prepare-only")
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")

manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
defaults_path <- resolve_path(defaults_rel, must_work = TRUE)
grid_path <- resolve_path(grid_rel, must_work = TRUE)

manifest <- exdqlm:::qdesn_static_crossstudy_fitfail_load_manifest(manifest_path)
base_defaults <- exdqlm:::qdesn_static_crossstudy_load_defaults(defaults_path)
grid_df <- exdqlm:::qdesn_static_crossstudy_load_grid(grid_path)
grid_summary <- exdqlm:::qdesn_static_crossstudy_validate_grid(grid_df, base_defaults)
reference_cfg <- base_defaults$reference %||% list()
reference_inventory <- exdqlm:::qdesn_static_crossstudy_collect_reference_inventory(
  paper_root = resolve_path(reference_cfg$paper_root, must_work = TRUE),
  shrink_root = resolve_path(reference_cfg$shrink_root, must_work = TRUE)
)

source_cfg <- manifest$source %||% list()
source_run_tag <- as.character(source_cfg$run_tag %||% "")[1L]
if (!nzchar(source_run_tag)) stop("Fit-fail closure manifest must define source.run_tag.", call. = FALSE)
source_state <- exdqlm:::qdesn_static_crossstudy_fitfail_collect_source_state(
  source_run_tag = source_run_tag,
  defaults = base_defaults,
  grid = grid_df,
  defaults_path = defaults_path,
  grid_path = grid_path
)

profile_cfgs <- manifest$profiles %||% list()
if (!length(profile_cfgs)) stop("Fit-fail closure manifest has no profiles.", call. = FALSE)
profile_df <- as_profile_df(profile_cfgs)
anchor_profile_id <- as.character(profile_df$profile_id[profile_df$anchor_control])[1L]
if (!nzchar(anchor_profile_id)) stop("Fit-fail closure manifest must define one anchor_control profile.", call. = FALSE)
profile_map <- setNames(profile_cfgs, vapply(profile_cfgs, function(x) as.character(x$profile_id)[1L], character(1)))

stage_cfgs <- manifest$stages %||% list()
if (!length(stage_cfgs)) stop("Fit-fail closure manifest has no stages.", call. = FALSE)

stage_plans <- list()
for (stage_cfg in stage_cfgs) {
  stage_name <- as.character(stage_cfg$id %||% "")[1L]
  if (!nzchar(stage_name)) stop("Each stage must define an id.", call. = FALSE)
  stage_profile_ids <- as.character(unlist(stage_cfg$profile_ids %||% character(0), use.names = FALSE))
  if (!length(stage_profile_ids)) stop(sprintf("Stage '%s' has no profile_ids.", stage_name), call. = FALSE)
  missing_profiles <- setdiff(stage_profile_ids, names(profile_map))
  if (length(missing_profiles)) {
    stop(sprintf("Stage '%s' references unknown profiles: %s", stage_name, paste(missing_profiles, collapse = ", ")), call. = FALSE)
  }
  stage_root_ids <- exdqlm:::qdesn_static_crossstudy_fitfail_stage_root_ids(source_state, grid_df, stage_cfg)
  stage_grid_df <- exdqlm:::qdesn_static_crossstudy_debt_subset_grid(grid_df, stage_root_ids)
  stage_plans[[stage_name]] <- list(
    cfg = stage_cfg,
    profile_ids = stage_profile_ids,
    root_ids = stage_root_ids,
    grid = stage_grid_df
  )
}

runtime_cfg <- manifest$runtime %||% list()
active_qdesn_processes <- cmd_lines(
  "bash",
  c(
    "-lc",
    paste(
      "ps -eo pid=,args=",
      "| grep -E -- 'run_qdesn_|qdesn_static_exdqlm_crossstudy|pipeline_real_main\\.R|pipeline_sim_main\\.R'",
      "| grep -vE 'grep -E|run_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave\\.R|healthcheck_qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave\\.R'",
      "|| true"
    )
  )
)
active_qdesn_processes <- active_qdesn_processes[nzchar(trimws(active_qdesn_processes))]

workers_arg <- suppressWarnings(as.integer(get_arg("--workers", NA_character_))[1L])
workers <- if (is.finite(workers_arg) && workers_arg >= 1L) {
  workers_arg
} else if (length(active_qdesn_processes)) {
  as.integer(runtime_cfg$active_job_workers %||% 6L)[1L]
} else {
  as.integer(runtime_cfg$default_workers %||% 8L)[1L]
}
hard_cap_workers <- as.integer(runtime_cfg$hard_cap_workers %||% 8L)[1L]
if (!is.finite(workers) || workers < 1L) workers <- 1L
if (!is.finite(hard_cap_workers) || hard_cap_workers < 1L) hard_cap_workers <- 8L
workers <- min(as.integer(hard_cap_workers), as.integer(workers))

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-static-exdqlm-crossstudy-fitfail-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

campaign_cfg <- manifest$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_fit_fail_closure_wave"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "static_exdqlm_crossstudy_fit_fail_closure_wave"), must_work = FALSE)
run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)

launch_root <- file.path(run_report_root, "launch")
status_root <- file.path(run_report_root, "status")
summary_root <- file.path(run_report_root, "summary")
tables_root <- file.path(run_report_root, "tables")
for (d in c(run_results_root, run_report_root, launch_root, status_root, summary_root, tables_root)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

source_bucket_inventory <- exdqlm:::.qdesn_validation_bind_rows(list(
  data.frame(root_id = source_state$rhs_ns_vb_diagnostics_root_ids, bucket = "rhs_ns_vb_diagnostics", stringsAsFactors = FALSE),
  data.frame(root_id = source_state$ridge_exal_mcmc_root_ids, bucket = "ridge_exal_mcmc_fail", stringsAsFactors = FALSE),
  data.frame(root_id = source_state$rhs_ns_mcmc_root_ids, bucket = "rhs_ns_mcmc_fail", stringsAsFactors = FALSE),
  data.frame(root_id = source_state$root_fail_root_ids, bucket = "root_status_fail", stringsAsFactors = FALSE),
  data.frame(root_id = source_state$bug_only_root_ids, bucket = "rhs_vb_bug_only", stringsAsFactors = FALSE)
))
write_csv(source_bucket_inventory, file.path(tables_root, "source_fail_bucket_inventory.csv"))
write_csv(source_state$root_status, file.path(tables_root, "source_root_status.csv"))
if (nrow(source_state$root_summary)) write_csv(source_state$root_summary, file.path(tables_root, "source_root_signoff_summary.csv"))
if (nrow(source_state$fit_summary)) write_csv(source_state$fit_summary, file.path(tables_root, "source_fit_summary.csv"))

stage_plan_rows <- list()
for (stage_name in names(stage_plans)) {
  stage_plan <- stage_plans[[stage_name]]
  stage_cfg <- stage_plan$cfg
  stage_dir <- file.path(run_report_root, "stages", stage_name)
  dir.create(file.path(stage_dir, "configs"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(stage_dir, "grids"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(stage_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(stage_dir, "summary"), recursive = TRUE, showWarnings = FALSE)
  write_csv(stage_plan$grid, file.path(stage_dir, "grids", sprintf("%s_grid.csv", stage_name)))
  write_csv(data.frame(root_id = stage_plan$root_ids, stringsAsFactors = FALSE), file.path(stage_dir, "tables", "stage_root_ids.csv"))
  for (profile_id in stage_plan$profile_ids) {
    profile <- profile_map[[profile_id]]
    profile_defaults <- exdqlm:::qdesn_static_crossstudy_debt_apply_overrides(base_defaults, profile$overrides %||% list())
    profile_defaults$campaign$name <- sprintf("%s__%s", campaign_cfg$name %||% "qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave", profile_id)
    exdqlm:::qdesn_static_crossstudy_debt_write_yaml(
      profile_defaults,
      file.path(stage_dir, "configs", sprintf("%s.yaml", profile_id))
    )
  }
  stage_plan_rows[[length(stage_plan_rows) + 1L]] <- data.frame(
    stage_id = stage_name,
    bucket = as.character(stage_cfg$bucket %||% "")[1L],
    stage_root_n = nrow(stage_plan$grid),
    stage_profile_n = length(stage_plan$profile_ids),
    selection_metric = as.character(stage_cfg$selection_metric %||% "target_fit_fail_n")[1L],
    stringsAsFactors = FALSE
  )
}
stage_plan_df <- do.call(rbind, stage_plan_rows)
write_csv(stage_plan_df, file.path(tables_root, "stage_plan.csv"))

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
  source_counts = list(
    materialized_roots = nrow(source_state$root_status),
    root_status_fail = length(source_state$root_fail_root_ids),
    fit_fail_roots = length(source_state$all_fit_fail_root_ids),
    rhs_ns_vb_diagnostics_roots = length(source_state$rhs_ns_vb_diagnostics_root_ids),
    ridge_exal_mcmc_roots = length(source_state$ridge_exal_mcmc_root_ids),
    rhs_ns_mcmc_roots = length(source_state$rhs_ns_mcmc_root_ids),
    bug_only_roots = length(source_state$bug_only_root_ids)
  ),
  stage_plan = stage_plan_df,
  resource_snapshot = resource_snapshot,
  output_roots = list(
    outer_results_root = run_results_root,
    outer_report_root = run_report_root
  )
)
write_json(preflight_manifest, file.path(launch_root, "qdesn_static_exdqlm_crossstudy_fit_fail_closure_preflight_manifest.json"))

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
  "## Source FAIL Surface",
  sprintf("- materialized_roots: `%d`", nrow(source_state$root_status)),
  sprintf("- root_status_fail_roots: `%d`", length(source_state$root_fail_root_ids)),
  sprintf("- fit_fail_roots: `%d`", length(source_state$all_fit_fail_root_ids)),
  sprintf("- rhs_ns_vb_diagnostics_roots: `%d`", length(source_state$rhs_ns_vb_diagnostics_root_ids)),
  sprintf("- ridge_exal_mcmc_fail_roots: `%d`", length(source_state$ridge_exal_mcmc_root_ids)),
  sprintf("- rhs_ns_mcmc_fail_roots: `%d`", length(source_state$rhs_ns_mcmc_root_ids)),
  sprintf("- bug_only_roots: `%d`", length(source_state$bug_only_root_ids)),
  "",
  "## Stage Plan",
  "",
  render_md_table(stage_plan_df),
  "",
  "## Profiles",
  "",
  render_md_table(profile_df)
)
write_lines(summary_md("QDESN Static exdqlm Cross-Study Fit-Fail Closure Preflight", preflight_lines), file.path(launch_root, "qdesn_static_exdqlm_crossstudy_fit_fail_closure_preflight.md"))

if (isTRUE(verbose)) {
  cat(sprintf("[qdesn-static-crossstudy-fitfail] run_tag=%s\n", run_tag))
  cat(sprintf("[qdesn-static-crossstudy-fitfail] workers=%d\n", workers))
  cat(sprintf("[qdesn-static-crossstudy-fitfail] prepare_only=%s\n", if (prepare_only) "TRUE" else "FALSE"))
}

if (isTRUE(prepare_only)) {
  cat(sprintf("Preflight manifest: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_fit_fail_closure_preflight_manifest.json")))
  cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_fit_fail_closure_preflight.md")))
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

stage_result_rows <- list()
local_baseline_rows <- list()
total_profiles <- sum(vapply(stage_plans, function(x) length(x$profile_ids), integer(1)))
stop_reason <- "RUNNING"
write_runner_state(file.path(status_root, "runner_state.json"), run_tag, NA_character_, NA_character_, data.frame(stringsAsFactors = FALSE), length(stage_plans), total_profiles, stop_reason)

current_stage_results_df <- function() {
  if (!length(stage_result_rows)) return(data.frame(stringsAsFactors = FALSE))
  do.call(rbind, stage_result_rows)
}

run_profile <- function(stage_name, stage_root_ids, stage_grid_df, profile, stage_cfg) {
  profile_id <- as.character(profile$profile_id)[1L]
  profile_label <- as.character(profile$label %||% profile_id)[1L]
  profile_defaults <- exdqlm:::qdesn_static_crossstudy_debt_apply_overrides(base_defaults, profile$overrides %||% list())
  profile_defaults$campaign$name <- sprintf("%s__%s", campaign_cfg$name %||% "qdesn_static_exdqlm_crossstudy_fit_fail_closure_wave", profile_id)
  stage_report_parent <- file.path(run_report_root, "stages", stage_name, "profiles", profile_id)
  stage_results_parent <- file.path(run_results_root, "stages", stage_name, "profiles", profile_id)
  dir.create(stage_report_parent, recursive = TRUE, showWarnings = FALSE)
  dir.create(stage_results_parent, recursive = TRUE, showWarnings = FALSE)
  exdqlm:::qdesn_static_crossstudy_debt_write_yaml(
    profile_defaults,
    file.path(run_report_root, "stages", stage_name, "configs", sprintf("%s.yaml", profile_id))
  )
  write_runner_state(file.path(status_root, "runner_state.json"), run_tag, stage_name, profile_id, current_stage_results_df(), length(stage_plans), total_profiles, stop_reason)
  tryCatch(
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
      metric <- exdqlm:::qdesn_static_crossstudy_fitfail_profile_metrics(
        profile_id = profile_id,
        stage_name = stage_name,
        stage_root_ids = stage_root_ids,
        run_obj = run,
        stage_cfg = stage_cfg
      )
      metric$profile_label <- profile_label
      metric$rationale <- as.character(profile$rationale %||% "")[1L]
      metric$error_message <- ""
      list(metric = metric, execution_status = "COMPLETED", report_root = run$report_root, results_root = run$results_root)
    },
    error = function(e) {
      metric <- transform(
        make_error_metric(stage_name, profile_id, stage_root_ids, conditionMessage(e)),
        profile_label = profile_label,
        rationale = as.character(profile$rationale %||% "")[1L]
      )
      list(metric = metric, execution_status = "ERROR", report_root = stage_report_parent, results_root = stage_results_parent)
    }
  )
}

append_stage_row <- function(stage_id,
                             profile_n_planned,
                             profile_n_completed,
                             recommended_profile,
                             recommendation,
                             execution_status,
                             stage_report_root) {
  stage_result_rows[[length(stage_result_rows) + 1L]] <<- data.frame(
    stage_id = stage_id,
    execution_status = execution_status,
    profile_n_planned = as.integer(profile_n_planned),
    profile_n_completed = as.integer(profile_n_completed),
    recommended_profile = as.character(recommended_profile)[1L],
    recommendation = as.character(recommendation)[1L],
    stage_report_root = stage_report_root,
    stringsAsFactors = FALSE
  )
  stage_results_df <- current_stage_results_df()
  write_csv(stage_results_df, file.path(tables_root, "stage_execution_status.csv"))
  write_runner_state(file.path(status_root, "runner_state.json"), run_tag, stage_id, NA_character_, stage_results_df, length(stage_plans), total_profiles, stop_reason)
}

for (stage_name in names(stage_plans)) {
  stage_plan <- stage_plans[[stage_name]]
  stage_cfg <- stage_plan$cfg
  stage_root_ids <- stage_plan$root_ids
  stage_grid_df <- stage_plan$grid
  stage_profile_ids <- stage_plan$profile_ids
  stage_dir <- file.path(run_report_root, "stages", stage_name)

  source_metric <- exdqlm:::qdesn_static_crossstudy_fitfail_profile_metrics(
    profile_id = "SOURCE_BASELINE",
    stage_name = stage_name,
    stage_root_ids = stage_root_ids,
    run_obj = source_run_obj,
    stage_cfg = stage_cfg
  )
  source_metric$profile_label <- "Source Broad Baseline"
  source_metric$rationale <- "Authoritative Wave-1 broad launch baseline."
  source_metric$error_message <- ""

  stage_metrics <- list()
  for (profile_id in stage_profile_ids) {
    res <- run_profile(stage_name, stage_root_ids, stage_grid_df, profile_map[[profile_id]], stage_cfg)
    stage_metrics[[length(stage_metrics) + 1L]] <- res$metric
    stage_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage_metrics)
    write_csv(stage_metrics_df, file.path(stage_dir, "tables", "profile_metrics.csv"))
  }
  stage_metrics_df <- exdqlm:::.qdesn_validation_bind_rows(stage_metrics)
  stage_compare_df <- exdqlm:::.qdesn_validation_bind_rows(list(source_metric, stage_metrics_df))
  stage_rank_df <- exdqlm:::qdesn_static_crossstudy_fitfail_rank_profiles(
    stage_metrics_df,
    primary_metric = as.character(stage_cfg$selection_metric %||% "target_fit_fail_n")[1L]
  )
  stage_lead_id <- exdqlm:::qdesn_static_crossstudy_fitfail_pick_stage_lead(
    stage_metrics_df,
    anchor_profile_id = anchor_profile_id,
    primary_metric = as.character(stage_cfg$selection_metric %||% "target_fit_fail_n")[1L]
  )
  recommendation <- if (identical(stage_lead_id, anchor_profile_id)) {
    sprintf("KEEP_%s_AS_%s_BASELINE", anchor_profile_id, stage_name)
  } else {
    sprintf("PROMOTE_%s_AS_%s_LOCAL_BASELINE", stage_lead_id, stage_name)
  }

  write_csv(stage_compare_df, file.path(stage_dir, "tables", "profile_metrics_with_source.csv"))
  write_csv(stage_rank_df, file.path(stage_dir, "tables", "profile_ranking.csv"))

  stage_lines <- c(
    sprintf("# %s Selection Summary", stage_name),
    "",
    sprintf("- source_run_tag: `%s`", source_run_tag),
    sprintf("- recommendation: `%s`", recommendation),
    sprintf("- selected_local_baseline: `%s`", stage_lead_id),
    "",
    "## Source Baseline Metrics",
    "",
    render_md_table(source_metric),
    "",
    "## Stage Ranking",
    "",
    render_md_table(stage_rank_df),
    ""
  )
  write_lines(stage_lines, file.path(stage_dir, "summary", "stage_candidate_selection.md"))

  local_baseline_rows[[length(local_baseline_rows) + 1L]] <- data.frame(
    stage_id = stage_name,
    local_baseline_profile = stage_lead_id,
    recommendation = recommendation,
    stringsAsFactors = FALSE
  )
  append_stage_row(
    stage_id = stage_name,
    profile_n_planned = length(stage_profile_ids),
    profile_n_completed = nrow(stage_metrics_df),
    recommended_profile = stage_lead_id,
    recommendation = recommendation,
    execution_status = "COMPLETED",
    stage_report_root = stage_dir
  )
}

stop_reason <- "completed_requested_scope"
stage_results_df <- current_stage_results_df()
local_baseline_df <- do.call(rbind, local_baseline_rows)
write_csv(stage_results_df, file.path(tables_root, "stage_execution_status.csv"))
write_csv(local_baseline_df, file.path(tables_root, "local_baseline_map.csv"))
write_runner_state(file.path(status_root, "runner_state.json"), run_tag, NA_character_, NA_character_, stage_results_df, length(stage_plans), total_profiles, stop_reason)

final_lines <- c(
  "# QDESN Static exdqlm Cross-Study Fit-Fail Closure Results",
  "",
  sprintf("- updated_at: `%s`", as.character(Sys.time())),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- source_run_tag: `%s`", source_run_tag),
  sprintf("- shared_default_baseline: `%s`", anchor_profile_id),
  "",
  "## Main Takeaways",
  "- This wave targets the true remaining FAIL surface rather than the older narrower hard-root-plus-compare-any debt frame.",
  "- `rhs_ns` VB diagnostics are handled as a code-path closure problem under the shared baseline.",
  "- Remaining MCMC FAILs are handled as local slice problems: ridge `exal/mcmc`, rhs_ns `mcmc @ tt=100`, and rhs_ns `mcmc @ tt=1000`.",
  "- No stage attempts to discover one generic setup for every remaining case.",
  "",
  "## Stage Results",
  "",
  render_md_table(stage_results_df),
  "",
  "## Local Baseline Map",
  "",
  render_md_table(local_baseline_df),
  ""
)
write_lines(final_lines, file.path(summary_root, "qdesn_static_crossstudy_fit_fail_closure_results.md"))
write_json(
  list(
    completed_at = as.character(Sys.time()),
    run_tag = run_tag,
    source_run_tag = source_run_tag,
    shared_default_baseline = anchor_profile_id,
    local_baseline_map = local_baseline_df,
    outer_report_root = run_report_root,
    outer_results_root = run_results_root
  ),
  file.path(run_report_root, "manifest", "fit_fail_closure_completed.json")
)

cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_static_exdqlm_crossstudy_fit_fail_closure_preflight.md")))
cat(sprintf("Runner state: %s\n", file.path(status_root, "runner_state.json")))
cat(sprintf("Stage status table: %s\n", file.path(tables_root, "stage_execution_status.csv")))
cat(sprintf("Result summary: %s\n", file.path(summary_root, "qdesn_static_crossstudy_fit_fail_closure_results.md")))
