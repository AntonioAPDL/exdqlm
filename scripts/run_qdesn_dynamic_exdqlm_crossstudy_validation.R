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
    if ("effective_fit_size" %in% names(out)) out$effective_fit_size <- as.integer(out$effective_fit_size)
    if ("source_total_size" %in% names(out)) out$source_total_size <- as.integer(out$source_total_size)
    if ("seed" %in% names(out)) out$seed <- as.integer(out$seed)
    out[] <- lapply(out, function(x) if (is.logical(x)) as.character(x) else x)
    out[do.call(order, out), , drop = FALSE]
  }
  identical(normalize(a), normalize(b))
}

grid_subset_of <- function(a, b) {
  cols <- intersect(names(a), names(b))
  cols <- cols[!cols %in% c("enabled")]
  if (!length(cols) || !nrow(a) || !nrow(b)) return(FALSE)
  normalize <- function(df) {
    out <- df[, cols, drop = FALSE]
    if ("tau" %in% names(out)) out$tau <- as.numeric(out$tau)
    if ("fit_size" %in% names(out)) out$fit_size <- as.integer(out$fit_size)
    if ("effective_fit_size" %in% names(out)) out$effective_fit_size <- as.integer(out$effective_fit_size)
    if ("source_total_size" %in% names(out)) out$source_total_size <- as.integer(out$source_total_size)
    if ("seed" %in% names(out)) out$seed <- as.integer(out$seed)
    out[] <- lapply(out, function(x) if (is.logical(x)) as.character(x) else x)
    out
  }
  encode <- function(df) do.call(paste, c(df, sep = "\r"))
  all(encode(normalize(a)) %in% encode(normalize(b)))
}

summary_md <- function(title, body_lines) {
  c(paste0("# ", title), "", body_lines)
}

select_batch_grid <- function(grid_df, defaults, batch = c("full", "smoke")) {
  batch <- match.arg(batch)
  if (identical(batch, "full")) return(grid_df)
  smoke_cfg <- defaults$smoke %||% list()
  out <- grid_df
  if (!is.null(smoke_cfg$scenario)) {
    out <- out[as.character(out$source_scenario) == as.character(smoke_cfg$scenario)[1L], , drop = FALSE]
  }
  if (!is.null(smoke_cfg$family)) {
    out <- out[as.character(out$source_family) == as.character(smoke_cfg$family)[1L], , drop = FALSE]
  }
  if (!is.null(smoke_cfg$tau)) {
    out <- out[abs(as.numeric(out$tau) - as.numeric(smoke_cfg$tau)[1L]) < 1e-8, , drop = FALSE]
  }
  if (!is.null(smoke_cfg$fit_sizes)) {
    out <- out[as.integer(out$fit_size) %in% as.integer(unlist(smoke_cfg$fit_sizes, use.names = FALSE)), , drop = FALSE]
  }
  if (!is.null(smoke_cfg$priors)) {
    out <- out[as.character(out$beta_prior_type) %in% as.character(unlist(smoke_cfg$priors, use.names = FALSE)), , drop = FALSE]
  }
  out
}

defaults_rel <- get_arg("--defaults", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"))
grid_rel <- get_arg("--grid", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"))
defaults_path <- resolve_path(defaults_rel, must_work = TRUE)
grid_path_raw <- resolve_path(grid_rel, must_work = FALSE)
prepare_only <- has_flag("--prepare-only")
refresh_grid <- has_flag("--refresh-grid")
allow_grid_subset <- has_flag("--allow-grid-subset")
verbose <- !has_flag("--quiet")
create_plots <- !has_flag("--no-plots")
batch <- match.arg(as.character(get_arg("--batch", "full"))[1L], c("full", "smoke"))

defaults <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults = defaults,
  refresh_materialized = isTRUE(refresh_grid),
  verbose = isTRUE(verbose)
)
canonical_grid_summary <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(canonical_grid, defaults)

if (isTRUE(refresh_grid) || !file.exists(grid_path_raw)) {
  dir.create(dirname(grid_path_raw), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(canonical_grid, grid_path_raw, row.names = FALSE)
}

grid_df <- exdqlm:::qdesn_dynamic_crossstudy_load_grid(grid_path_raw)
grid_summary <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid_df, defaults, allow_subset = allow_grid_subset)
if (!(grid_equivalent(grid_df, canonical_grid) || (isTRUE(allow_grid_subset) && grid_subset_of(grid_df, canonical_grid)))) {
  stop(
    paste(
      c(
        if (isTRUE(allow_grid_subset)) {
          "The supplied dynamic grid is neither the canonical grid nor a valid subset of the canonical grid recovered from the exdqlm dynamic reference roots."
        } else {
          "The checked-in dynamic grid does not match the canonical grid recovered from the exdqlm dynamic reference roots."
        },
        "Re-run with `--refresh-grid`, pass `--allow-grid-subset` for an auditable subset rerun, or inspect the dynamic grid CSV."
      ),
      collapse = "\n"
    ),
    call. = FALSE
  )
}

selected_grid <- select_batch_grid(grid_df, defaults, batch = batch)
if (!nrow(selected_grid)) {
  stop(sprintf("Selected batch '%s' has no enabled roots after filtering.", batch), call. = FALSE)
}

reference_cfg <- defaults$reference %||% list()
reference_inventory <- exdqlm:::qdesn_dynamic_crossstudy_collect_reference_inventory(
  reference_root = resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
)
reference_summary <- exdqlm:::qdesn_dynamic_crossstudy_validate_reference_inventory(reference_inventory, defaults)

runtime_cfg <- defaults$runtime %||% list()
multiseed_cfg <- defaults$multiseed %||% list()
pipeline_cfg <- defaults$pipeline %||% list()
pipeline_mcmc_cfg <- pipeline_cfg$inference$mcmc %||% list()
pipeline_sampling_cfg <- pipeline_cfg$sampling %||% list()
pipeline_synthesis_cfg <- pipeline_cfg$synthesis %||% list()
active_qdesn_processes <- cmd_lines(
  "bash",
  c(
    "-lc",
    paste(
      "ps -eo pid=,args=",
      "| grep -E -- 'run_qdesn_|pipeline_real_main\\.R|pipeline_sim_main\\.R'",
      "| grep -vE 'grep -E|run_qdesn_dynamic_exdqlm_crossstudy_validation\\.R|materialize_qdesn_dynamic_exdqlm_crossstudy_grid\\.R|healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation\\.R'",
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
  sprintf("qdesn-dynamic-exdqlm-crossstudy-%s-%s__git-%s", batch, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

campaign_cfg <- defaults$campaign %||% list()
base_results_root <- resolve_path(campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"), must_work = FALSE)
base_report_root <- resolve_path(campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"), must_work = FALSE)
run_results_root <- file.path(base_results_root, run_tag)
run_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(run_report_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

selected_grid_path <- file.path(launch_root, sprintf("selected_grid_%s.csv", batch))
write_csv(selected_grid, selected_grid_path)

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
  batch = batch,
  defaults_path = defaults_path,
  grid_path = grid_path_raw,
  selected_grid_path = selected_grid_path,
  prepare_only = prepare_only,
  refresh_grid = refresh_grid,
  allow_grid_subset = allow_grid_subset,
  create_plots = create_plots,
  chosen_workers = workers,
  reference_summary = reference_summary,
  grid_summary = grid_summary,
  canonical_grid_summary = canonical_grid_summary,
  selected_grid_summary = list(
    selected_roots = nrow(selected_grid),
    unique_dataset_cells = length(unique(as.character(selected_grid$dataset_cell_id))),
    scenarios = sort(unique(as.character(selected_grid$source_scenario))),
    families = sort(unique(as.character(selected_grid$source_family))),
    taus = sort(unique(as.numeric(selected_grid$tau))),
    fit_sizes = sort(unique(as.integer(selected_grid$fit_size))),
    priors = sort(unique(as.character(selected_grid$beta_prior_type)))
  ),
  normalized_contract = list(
    posterior_metric_draws = as.integer(defaults$metrics$posterior_metric_draws %||% NA_integer_)[1L],
    vb_draws = as.integer(pipeline_sampling_cfg$nd_draws %||% NA_integer_)[1L],
    synthesis_draws = as.integer(pipeline_synthesis_cfg$n_samp %||% NA_integer_)[1L],
    mcmc_n_burn = as.integer(pipeline_mcmc_cfg$n_burn %||% NA_integer_)[1L],
    mcmc_n_mcmc = as.integer(pipeline_mcmc_cfg$n_mcmc %||% NA_integer_)[1L],
    mcmc_thin = as.integer(pipeline_mcmc_cfg$thin %||% NA_integer_)[1L]
  ),
  multiseed_summary = list(
    enabled = isTRUE(multiseed_cfg$enabled),
    mcmc_seed_reps = as.integer(multiseed_cfg$mcmc_seed_reps %||% 1L)[1L],
    parallel_seed_workers = as.integer(multiseed_cfg$parallel_seed_workers %||% 1L)[1L],
    selection_metric = as.character(multiseed_cfg$selection_metric %||% NA_character_)[1L],
    prune_nonwinning_heavy_outputs = isTRUE(multiseed_cfg$prune_nonwinning_heavy_outputs)
  ),
  resource_snapshot = resource_snapshot,
  output_roots = list(
    outer_results_root = run_results_root,
    outer_report_root = run_report_root
  ),
  acceptance_criteria = list(
    all_grid_roots_materialized = TRUE,
    all_root_status_explicit = TRUE,
    grouped_qdesn_summaries_written = TRUE,
    grouped_reference_summaries_written = TRUE,
    qdesn_vs_reference_comparison_written = TRUE,
    recommendation_in = c(
      "COMPARISON_READY_QDESN_DYNAMIC_EXDQLM_COMPLETE",
      "COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND",
      "HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS"
    )
  )
)

jsonlite::write_json(
  preflight_manifest,
  file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

preflight_lines <- c(
  sprintf("- generated_at: `%s`", preflight_manifest$generated_at),
  sprintf("- git_sha: `%s`", git_sha),
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- batch: `%s`", batch),
  sprintf("- defaults_path: `%s`", defaults_path),
  sprintf("- grid_path: `%s`", grid_path_raw),
  sprintf("- selected_grid_path: `%s`", selected_grid_path),
  sprintf("- outer_report_root: `%s`", run_report_root),
  sprintf("- outer_results_root: `%s`", run_results_root),
  sprintf("- chosen_workers: `%d`", as.integer(workers)),
  sprintf("- active_qdesn_processes_n: `%d`", as.integer(length(active_qdesn_processes))),
  sprintf("- allow_grid_subset: `%s`", if (isTRUE(allow_grid_subset)) "TRUE" else "FALSE"),
  sprintf("- create_plots: `%s`", if (isTRUE(create_plots)) "TRUE" else "FALSE"),
  "",
  "## Scope Decision",
  "- study_surface: `dynamic exdqlm-aligned`",
  "- model: `QDESN`",
  "- likelihoods_per_root: `exal, al`",
  "- methods_per_root: `vb, mcmc`",
  "- QDESN_priors: `ridge, rhs_ns`",
  "",
  "## Normalized Posterior Contract",
  sprintf("- posterior_metric_draws: `%s`", as.character(preflight_manifest$normalized_contract$posterior_metric_draws)),
  sprintf("- vb_draws: `%s`", as.character(preflight_manifest$normalized_contract$vb_draws)),
  sprintf("- synthesis_draws: `%s`", as.character(preflight_manifest$normalized_contract$synthesis_draws)),
  sprintf("- mcmc_n_burn: `%s`", as.character(preflight_manifest$normalized_contract$mcmc_n_burn)),
  sprintf("- mcmc_n_mcmc: `%s`", as.character(preflight_manifest$normalized_contract$mcmc_n_mcmc)),
  sprintf("- mcmc_thin: `%s`", as.character(preflight_manifest$normalized_contract$mcmc_thin)),
  "",
  "## Multiseed Policy",
  sprintf("- enabled: `%s`", if (isTRUE(preflight_manifest$multiseed_summary$enabled)) "TRUE" else "FALSE"),
  sprintf("- mcmc_seed_reps: `%s`", as.character(preflight_manifest$multiseed_summary$mcmc_seed_reps)),
  sprintf("- parallel_seed_workers: `%s`", as.character(preflight_manifest$multiseed_summary$parallel_seed_workers)),
  sprintf("- selection_metric: `%s`", as.character(preflight_manifest$multiseed_summary$selection_metric)),
  sprintf("- prune_nonwinning_heavy_outputs: `%s`", if (isTRUE(preflight_manifest$multiseed_summary$prune_nonwinning_heavy_outputs)) "TRUE" else "FALSE"),
  "",
  "## Reference Inventory",
  sprintf("- reference_root_dirs: `%d`", as.integer(reference_summary$reference_root_dirs_n)),
  sprintf("- reference_root_rows: `%d`", as.integer(reference_summary$reference_root_rows_n)),
  sprintf("- unique_dataset_cells: `%d`", as.integer(reference_summary$reference_unique_dataset_cells)),
  sprintf("- scenarios: `%s`", paste(reference_summary$scenarios, collapse = ", ")),
  sprintf("- families: `%s`", paste(reference_summary$families, collapse = ", ")),
  sprintf("- taus: `%s`", paste(reference_summary$taus, collapse = ", ")),
  sprintf("- fit_sizes: `%s`", paste(reference_summary$fit_sizes, collapse = ", ")),
  "",
  "## Selected Batch Grid",
  sprintf("- selected_roots: `%d`", as.integer(preflight_manifest$selected_grid_summary$selected_roots)),
  sprintf("- unique_dataset_cells: `%d`", as.integer(preflight_manifest$selected_grid_summary$unique_dataset_cells)),
  sprintf("- scenarios: `%s`", paste(preflight_manifest$selected_grid_summary$scenarios, collapse = ", ")),
  sprintf("- families: `%s`", paste(preflight_manifest$selected_grid_summary$families, collapse = ", ")),
  sprintf("- taus: `%s`", paste(preflight_manifest$selected_grid_summary$taus, collapse = ", ")),
  sprintf("- fit_sizes: `%s`", paste(preflight_manifest$selected_grid_summary$fit_sizes, collapse = ", ")),
  sprintf("- priors: `%s`", paste(preflight_manifest$selected_grid_summary$priors, collapse = ", ")),
  "",
  "## Active QDESN Processes",
  if (length(active_qdesn_processes)) paste0("- ", active_qdesn_processes) else "- none"
)
writeLines(summary_md("QDESN Dynamic exdqlm Cross-Study Preflight", preflight_lines), file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight.md"))

if (isTRUE(verbose)) {
  cat(sprintf("[qdesn-dynamic-exdqlm-crossstudy] run_tag=%s\n", run_tag))
  cat(sprintf("[qdesn-dynamic-exdqlm-crossstudy] batch=%s\n", batch))
  cat(sprintf("[qdesn-dynamic-exdqlm-crossstudy] workers=%d\n", workers))
  cat(sprintf("[qdesn-dynamic-exdqlm-crossstudy] prepare_only=%s\n", if (prepare_only) "TRUE" else "FALSE"))
}

if (isTRUE(prepare_only)) {
  cat(sprintf("Preflight manifest: %s\n", file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight_manifest.json")))
  cat(sprintf("Preflight markdown: %s\n", file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_preflight.md")))
  cat(sprintf("Selected grid: %s\n", selected_grid_path))
  cat(sprintf("Planned outer report root: %s\n", run_report_root))
  cat(sprintf("Planned outer results root: %s\n", run_results_root))
  quit(status = 0)
}

run <- exdqlm:::qdesn_dynamic_crossstudy_run_campaign(
  grid = selected_grid,
  defaults = defaults,
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
    "scripts/healthcheck_qdesn_dynamic_exdqlm_crossstudy_validation.R",
    "--run-tag", run_tag,
    "--defaults", defaults_path,
    "--grid", grid_path_raw,
    "--batch", batch,
    "--results-root", base_results_root,
    "--report-root", base_report_root
  )
)
writeLines(summary_md("QDESN Dynamic exdqlm Cross-Study Healthcheck", c("```text", healthcheck_lines, "```")), file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_healthcheck.md"))

campaign_summary_path <- file.path(campaign_report_root, "summary", "qdesn_dynamic_crossstudy_summary.md")
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
  batch = batch,
  defaults_path = defaults_path,
  grid_path = grid_path_raw,
  selected_grid_path = selected_grid_path,
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
  file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_launch_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

if (isTRUE(verbose)) {
  cat(sprintf("Campaign report root: %s\n", campaign_report_root))
  cat(sprintf("Campaign results root: %s\n", campaign_results_root))
  cat(sprintf("Campaign summary: %s\n", campaign_summary_path))
  cat(sprintf("Launch manifest: %s\n", file.path(launch_root, "qdesn_dynamic_exdqlm_crossstudy_launch_manifest.json")))
}
