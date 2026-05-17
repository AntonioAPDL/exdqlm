#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (is.na(idx) || idx >= length(args)) return(default)
  args[idx + 1L]
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
runtime_snapshot <- exdqlm:::qdesn_validation_assert_runtime(repo_root = repo_root)
exdqlm:::qdesn_dynamic_fitforecast_assert_required_packages()
Sys.setenv(EXDQLM_REQUIRE_PACKAGES_ONLY = "1")

phase <- match.arg(
  as.character(get_arg("--phase", "smoke"))[1L],
  c("smoke", "pilot", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full")
)
dry_run <- has_flag("--dry-run")
prepare_only <- has_flag("--prepare-only")

runner_rel <- file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R")
defaults_rel <- file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml")
grid_rel <- file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_full_grid.csv")
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
phase_plan <- exdqlm:::qdesn_dynamic_fitforecast_phase_plan(phase)
phase_tag <- phase_plan$phase_tag
batch <- phase_plan$batch
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-fitforecast-v2-%s-%s__git-%s", phase_tag, format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

requested_session_name <- as.character(get_arg("--tmux-session", ""))[1L]
session_name <- if (nzchar(trimws(requested_session_name))) {
  requested_session_name
} else {
  sprintf("qdesn_ff_v2_%s", gsub("[^0-9]", "", format(Sys.time(), "%m%d_%H%M%S")))
}

methods <- phase_plan$methods
likelihoods <- as.character(phase_plan$likelihoods %||% "")[1L]
fit_sizes <- paste(as.integer(phase_plan$fit_sizes), collapse = ",")

child_args <- args
drop_value_flags <- function(x, flags) {
  idx <- which(x %in% flags)
  if (!length(idx)) return(x)
  drop_idx <- sort(unique(c(idx, idx + 1L)))
  drop_idx <- drop_idx[drop_idx <= length(x)]
  x[-drop_idx]
}
drop_bare_flags <- function(x, flags) {
  x[!x %in% flags]
}
child_args <- drop_value_flags(child_args, "--phase")
child_args <- drop_bare_flags(child_args, "--dry-run")
if (!any(child_args == "--defaults")) child_args <- c(child_args, "--defaults", defaults_rel)
if (!any(child_args == "--grid")) child_args <- c(child_args, "--grid", grid_rel)
if (!any(child_args == "--methods")) child_args <- c(child_args, "--methods", methods)
if (nzchar(likelihoods) && !any(child_args == "--likelihoods")) child_args <- c(child_args, "--likelihoods", likelihoods)
if (nzchar(fit_sizes) && !any(child_args == "--fit-sizes")) child_args <- c(child_args, "--fit-sizes", fit_sizes)
if (!any(child_args == "--batch")) child_args <- c(child_args, "--batch", batch)
if (!any(child_args == "--run-tag")) child_args <- c(child_args, "--run-tag", run_tag)
if (identical(phase, "smoke") && !any(child_args == "--workers")) child_args <- c(child_args, "--workers", "1")
if (identical(phase, "smoke") && !any(child_args == "--scheduler")) child_args <- c(child_args, "--scheduler", "static")
if (identical(phase, "pilot") && !any(child_args == "--workers")) child_args <- c(child_args, "--workers", "2")
if (identical(phase, "pilot") && !any(child_args == "--scheduler")) child_args <- c(child_args, "--scheduler", "static")
if (!any(child_args == "--allow-grid-subset") && isTRUE(phase_plan$allow_grid_subset_default)) child_args <- c(child_args, "--allow-grid-subset")

approval_state <- exdqlm:::qdesn_dynamic_fitforecast_approval_state(phase)
cat("Q-DESN dynamic fit+forecast v2 launch wrapper\n")
cat(sprintf("phase: %s\n", phase))
cat(sprintf("batch: %s\n", batch))
cat(sprintf("dry_run: %s\n", dry_run))
cat(sprintf("prepare_only: %s\n", prepare_only))
cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("branch: %s\n", trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE))))
cat(sprintf("commit: %s\n", trimws(system("git rev-parse HEAD", intern = TRUE))))
cat(sprintf("Rscript: %s\n", runtime_snapshot$rscript))
cat(sprintf("QDESN_FFV2_LAUNCH_APPROVED: %s\n", approval_state$launch_approved))
cat(sprintf("QDESN_FFV2_TT5000_APPROVED: %s\n", approval_state$tt5000_approved))

if (isTRUE(dry_run)) {
  cmd <- c(
    runtime_snapshot$rscript,
    file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--runner", runner_rel,
    "--defaults", defaults_rel,
    "--batch", batch,
    "--tmux-session", session_name,
    child_args
  )
  cat("dry_run_command:\n")
  cat(paste(shQuote(cmd), collapse = " "), "\n")
  quit(status = 0L, save = "no")
}

if (isTRUE(prepare_only)) {
  direct_args <- child_args
  if (!any(direct_args == "--prepare-only")) direct_args <- c(direct_args, "--prepare-only")
  status <- system2(
    runtime_snapshot$rscript,
    c(runner_rel, direct_args),
    stdout = "",
    stderr = ""
  )
  quit(status = as.integer(status), save = "no")
}

exdqlm:::qdesn_dynamic_fitforecast_assert_launch_approved(phase)
status <- system2(
  runtime_snapshot$rscript,
  c(
    file.path("scripts", "launch_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--runner", runner_rel,
    "--defaults", defaults_rel,
    "--batch", batch,
    "--tmux-session", session_name,
    child_args
  ),
  stdout = "",
  stderr = ""
)
quit(status = as.integer(status), save = "no")
