#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
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

workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
workers <- min(workers, 30L)
prepare_only <- has_flag("--prepare-only")
dry_run <- has_flag("--dry-run")
refresh_materialized <- has_flag("--refresh-materialized")
skip_rank <- has_flag("--skip-rank")
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-tt500-vb-dominance-period90-broad-%s__git-%s", stamp, git_sha)
))[1L]
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-tt500-vb-dominance-screening-%s__git-%s", stamp, git_sha)
))[1L]
baseline_path <- resolve_path(get_arg(
  "--baseline",
  "/data/jaguir26/local/src/Article-Q-DESN/tables/qdesn_validation_tt500_final_summary.csv"
), must_work = FALSE)

profile_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_profiles.csv"
)
defaults_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_defaults.yaml"
)
grid_path <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_grid.csv"
)
base_defaults_path <- resolve_path(file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_tt500_vb_broad_defaults.yaml"
), must_work = TRUE)

orchestrator_root <- file.path(
  repo_root,
  "reports",
  "qdesn_mcmc_validation",
  "qdesn_tt500_vb_dominance_screening",
  orchestrator_tag
)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

write_df <- function(df, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

profiles <- exdqlm:::qdesn_dynamic_fitforecast_dominance_profiles()
write_df(profiles, profile_path)

defaults <- yaml::read_yaml(base_defaults_path)
defaults$campaign$name <- "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance"
defaults$campaign$results_root <- "results/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance"
defaults$campaign$reports_root <- "reports/qdesn_mcmc_validation/qdesn_dynamic_fitforecast_v2_tt500_vb_dominance"
defaults$study_contract$id <- "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_period90_2026_06_26"
defaults$study_contract$description <- paste(
  "Broad Q-DESN TT500 VB dominance screen against the best available DQLM/exDQLM",
  "VB baseline per family and quantile. The lane uses deterministic period-90",
  "harmonic covariates plus trend, m=90, y-lag readout 90, RHS-NS tau0=1e-4,",
  "and compact reservoirs with p/n <= 0.50."
)
defaults$source_materialization$staged_root <- "results/qdesn_mcmc_validation/dynamic_fitforecast_v2_qdesn_sources_period90_m90_w300"
defaults$source_materialization$taus <- c(0.05, 0.25, 0.50)
defaults$source_materialization$windows <- list(list(
  effective_fit_size = 500L,
  source_total_size = 1890L,
  source_dir_name = "fit_input_effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90",
  label = "effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
))
defaults$pilot$source_total_size <- 1890L
defaults$pilot$source_window_label <- "effTT500_totalTT1890_trainEnd9000_H1000_m90_w300_period90"
defaults$reference_contract$taus <- c(0.05, 0.25, 0.50)
defaults$reference_contract$expected_unique_dataset_cells <- 9L
defaults$reference_contract$expected_qdesn_roots <- as.integer(nrow(profiles) * 9L)
defaults$screening_profiles$csv <- profile_path
defaults$screening_profiles$design <- paste(
  "Seventy-two period-90 dominance profiles: D in {1,2}, n_each in {20,30,50},",
  "alpha/rho ladder {(0.05,0.60),(0.10,0.70),(0.20,0.80),(0.30,0.85)},",
  "and three sparsity/readout-lag variants. All use m=90, readout_y_lags=90,",
  "washout=300, deterministic period-90 x features, and RHS-NS tau0=1e-4."
)
defaults$lags <- list(m_y = 90L, m_x = 0L, x = 0L)
defaults$deterministic_features <- list(
  enabled = TRUE,
  period = 90L,
  harmonics = c(1L, 2L),
  include_trend = TRUE,
  include_index = FALSE,
  prefix = "period90"
)
defaults$runtime$campaign_workers <- as.integer(workers)
defaults$runtime$workers <- as.integer(workers)
defaults$runtime$root_scheduler <- "load_balanced"
defaults$smoke$tau <- 0.5
defaults$smoke$fit_sizes <- 500L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$retention_profile <- "storage_light_screening"
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$pipeline$diagnostics$plots <- FALSE

defaults_abs <- resolve_path(defaults_path, must_work = FALSE)
dir.create(dirname(defaults_abs), recursive = TRUE, showWarnings = FALSE)
yaml::write_yaml(defaults, defaults_abs)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_abs)
grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults = defaults_loaded,
  refresh_materialized = isTRUE(refresh_materialized),
  verbose = TRUE
)
grid_summary <- exdqlm:::qdesn_dynamic_crossstudy_validate_grid(grid, defaults_loaded)
write_df(grid, grid_path)

run_cmd <- function(label, cmd, args) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  line <- paste(shQuote(c(cmd, args)), collapse = " ")
  writeLines(line, cmd_path)
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[orchestrator] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[orchestrator] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

latest_campaign_report <- function(base_report_root, tag) {
  outer <- file.path(repo_root, base_report_root, tag)
  if (!dir.exists(outer)) return(NA_character_)
  direct <- file.path(outer, "tables", "campaign_fit_summary.csv")
  if (file.exists(direct)) return(normalizePath(outer, winslash = "/", mustWork = FALSE))
  kids <- sort(list.dirs(outer, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  for (kid in kids) {
    if (file.exists(file.path(kid, "tables", "campaign_fit_summary.csv"))) {
      return(normalizePath(kid, winslash = "/", mustWork = FALSE))
    }
  }
  NA_character_
}

prepare_status <- run_cmd(
  label = "prepare_preflight",
  cmd = "Rscript",
  args = c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "vb",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--allow-grid-subset",
    "--prepare-only",
    "--workers", as.character(workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_tag, "-prepare")
  )
)

stage_results <- list(
  prepare = list(
    status = prepare_status,
    defaults = defaults_path,
    profiles = profile_path,
    grid = grid_path,
    n_profiles = nrow(profiles),
    n_grid_roots = nrow(grid)
  )
)

if (!identical(prepare_status, 0L)) {
  stop("Dominance screening prepare preflight failed. Inspect orchestrator logs.", call. = FALSE)
}

if (!isTRUE(prepare_only)) {
  run_status <- run_cmd(
    label = "dominance_run",
    cmd = "Rscript",
    args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path,
      "--grid", grid_path,
      "--batch", "full",
      "--methods", "vb",
      "--likelihoods", "exal",
      "--fit-sizes", "500",
      "--priors", "rhs_ns",
      "--allow-grid-subset",
      "--workers", as.character(workers),
      "--scheduler", "load_balanced",
      "--run-tag", run_tag
    )
  )
  report_root <- latest_campaign_report(defaults$campaign$reports_root, run_tag)
  generic_rank_status <- NA_integer_
  dominance_rank_status <- NA_integer_
  if (identical(run_status, 0L) && !is.na(report_root) && !isTRUE(skip_rank)) {
    generic_rank_status <- run_cmd(
      label = "generic_rank",
      cmd = "Rscript",
      args = c(
        file.path("scripts", "rank_qdesn_tt500_vb_screen.R"),
        "--report-root", report_root,
        "--top-n", "20"
      )
    )
    if (identical(generic_rank_status, 0L) && file.exists(baseline_path)) {
      dominance_rank_status <- run_cmd(
        label = "dominance_rank",
        cmd = "Rscript",
        args = c(
          file.path("scripts", "rank_qdesn_tt500_vb_dominance_screen.R"),
          "--report-root", report_root,
          "--baseline", baseline_path,
          "--top-n", "20"
        )
      )
    }
  }
  stage_results$run <- list(
    run_tag = run_tag,
    report_root = report_root,
    run_status = run_status,
    generic_rank_status = generic_rank_status,
    dominance_rank_status = dominance_rank_status,
    baseline_path = baseline_path
  )
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  dry_run = dry_run,
  prepare_only = prepare_only,
  refresh_materialized = refresh_materialized,
  baseline_path = baseline_path,
  profile_path = resolve_path(profile_path, must_work = TRUE),
  defaults_path = resolve_path(defaults_path, must_work = TRUE),
  grid_path = resolve_path(grid_path, must_work = TRUE),
  grid_summary = grid_summary,
  deterministic_features = defaults$deterministic_features,
  source_window = defaults$source_materialization$windows[[1L]],
  stages = stage_results
)
manifest_path <- file.path(orchestrator_root, "manifest", "qdesn_tt500_vb_dominance_screening_manifest.json")
jsonlite::write_json(manifest, manifest_path, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("profiles: %s\n", resolve_path(profile_path, must_work = TRUE)))
cat(sprintf("defaults: %s\n", resolve_path(defaults_path, must_work = TRUE)))
cat(sprintf("grid: %s\n", resolve_path(grid_path, must_work = TRUE)))
failed <- vapply(stage_results, function(x) {
  vals <- unlist(x[names(x) %in% c("status", "run_status", "generic_rank_status", "dominance_rank_status")], use.names = FALSE)
  vals <- vals[!is.na(vals)]
  any(as.integer(vals) != 0L)
}, logical(1L))
quit(status = if (any(failed)) 1L else 0L, save = "no")
