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
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation"
workers <- min(int_arg("--workers", 9L), 9L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_tag <- as.character(get_arg("--run-tag", sprintf("qdesn-tt500-mcmc-vb-winner-confirmation-full-%s__git-%s", stamp, git_sha)))[1L]
orchestrator_tag <- as.character(get_arg("--orchestrator-tag", sprintf("qdesn-tt500-mcmc-vbwin-orchestrator-%s__git-%s", stamp, git_sha)))[1L]
dry_run <- has_flag("--dry-run")
do_prepare <- has_flag("--prepare") || has_flag("--all")
do_smoke <- has_flag("--smoke") || has_flag("--all")
do_pilot <- has_flag("--pilot") || has_flag("--all")
do_full_background <- has_flag("--full-background") || has_flag("--all")
skip_materialize <- has_flag("--skip-materialize")

defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
manifest_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)
winners_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_winners.csv")), must_work = FALSE)

orchestrator_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage_file, "orchestrators", orchestrator_tag)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

run_cmd <- function(label, cmd, args) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  line <- paste(shQuote(c(cmd, args)), collapse = " ")
  writeLines(line, cmd_path)
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[mcmc-vbwin] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = args, stdout = log_path, stderr = log_path)
  cat(sprintf("[mcmc-vbwin] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
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

if (!isTRUE(skip_materialize)) {
  status <- run_cmd("materialize", "Rscript", c(file.path("scripts", "materialize_qdesn_tt500_mcmc_vb_winner_confirmation.R"), "--workers", as.character(workers)))
  if (!identical(status, 0L)) stop("MCMC VB-winner materialization failed.", call. = FALSE)
} else if (!file.exists(manifest_path)) {
  stop("Cannot --skip-materialize because the materialization manifest does not exist.", call. = FALSE)
}

if (isTRUE(do_prepare)) {
  status <- run_cmd("prepare_preflight", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "mcmc",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--allow-grid-subset",
    "--prepare-only",
    "--workers", as.character(workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_tag, "-prepare")
  ))
  if (!identical(status, 0L)) stop("Prepare-only preflight failed.", call. = FALSE)
}

if (isTRUE(do_smoke)) {
  status <- run_cmd("smoke_run", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "smoke",
    "--methods", "mcmc",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--allow-grid-subset",
    "--workers", "1",
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_tag, "-smoke")
  ))
  if (!identical(status, 0L)) stop("Smoke run failed.", call. = FALSE)
}

pilot_defaults_path <- file.path(orchestrator_root, "manifest", "pilot_defaults.yaml")
pilot_run_tag <- paste0(run_tag, "-pilot")
pilot_root_ids <- c(
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p05__lasttt_500__qdesn_rhs_ns__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
)
if (isTRUE(do_pilot)) {
  cfg <- yaml::read_yaml(defaults_path)
  cfg$study_contract$budget$mcmc_n_burn <- 200L
  cfg$study_contract$budget$mcmc_n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$n_burn <- 200L
  cfg$pipeline$inference$mcmc$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$progress_every <- 50L
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 200L
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
  cfg$reference_contract$expected_selected_qdesn_roots <- 2L
  yaml::write_yaml(cfg, pilot_defaults_path)
  status <- run_cmd("pilot_run", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", pilot_defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "mcmc",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--root-ids", paste(pilot_root_ids, collapse = ","),
    "--allow-grid-subset",
    "--workers", "2",
    "--scheduler", "load_balanced",
    "--run-tag", pilot_run_tag
  ))
  if (!identical(status, 0L)) stop("Micro-pilot run failed.", call. = FALSE)
}

full_launch_status <- NA_integer_
if (isTRUE(do_full_background)) {
  if (isTRUE(dry_run)) {
    cat("[dry-run] full background launch skipped.\n")
    full_launch_status <- 0L
  } else {
    Sys.setenv(
      OMP_NUM_THREADS = "1",
      OPENBLAS_NUM_THREADS = "1",
      MKL_NUM_THREADS = "1",
      VECLIB_MAXIMUM_THREADS = "1",
      NUMEXPR_NUM_THREADS = "1"
    )
    full_launch_status <- run_cmd("full_background_launch", "Rscript", c(
      file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path,
      "--grid", grid_path,
      "--batch", "full",
      "--methods", "mcmc",
      "--likelihoods", "exal",
      "--fit-sizes", "500",
      "--priors", "rhs_ns",
      "--allow-grid-subset",
      "--workers", as.character(workers),
      "--scheduler", "load_balanced",
      "--run-tag", run_tag,
      "--tmux-session", paste0("qdesn_tt500_mcmc_vbwin_", gsub("[^0-9A-Za-z_]", "_", substr(run_tag, 1L, 48L)))
    ))
    if (!identical(full_launch_status, 0L)) stop("Full detached launch failed.", call. = FALSE)
  }
}

defaults <- yaml::read_yaml(defaults_path)
full_report_root <- file.path(defaults$campaign$reports_root, run_tag)
manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestrator_tag = orchestrator_tag,
  run_tag = run_tag,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  workers = workers,
  defaults_path = defaults_path,
  grid_path = grid_path,
  winners_path = winners_path,
  materialization_manifest = manifest_path,
  prepare = do_prepare,
  smoke = do_smoke,
  pilot = do_pilot,
  full_background = do_full_background,
  full_launch_status = full_launch_status,
  full_report_root = full_report_root,
  full_results_root = file.path(defaults$campaign$results_root, run_tag),
  latest_pilot_report = latest_campaign_report(defaults$campaign$reports_root, pilot_run_tag)
)
manifest_out <- file.path(orchestrator_root, "manifest", "orchestrator_manifest.json")
jsonlite::write_json(manifest, manifest_out, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("orchestrator_manifest: %s\n", manifest_out))
cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("full_report_root: %s\n", manifest$full_report_root))
cat(sprintf("full_results_root: %s\n", manifest$full_results_root))
cat(sprintf("full_background: %s\n", as.character(do_full_background)))
