#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_external_coherent_confirmation_v1"
expected_spec_id <- "qdesn__laplace__0p25__tt500__rhs_ns__mcmc__exal__020293d289bcb0"
defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_path <- file.path("config", "validation", paste0(stage, "_target_spec_ids.csv"))
manifest_path <- file.path("config", "validation", paste0(stage, "_materialization_manifest.json"))

prepare_only <- has_flag("--prepare-only")
smoke_requested <- has_flag("--smoke")
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")
if (!prepare_only && !smoke_requested && !full) prepare_only <- TRUE
if (full && !launch_approved) {
  stop("Full confirmation requires --full --launch-approved.", call. = FALSE)
}
run_smoke <- !skip_smoke && (smoke_requested || full)

git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestration_tag <- sprintf(
  "qdesn-tt500-mcmc-external-coherent-confirmation-v1-orch-%s__git-%s",
  stamp,
  git_short
)
orchestration_root <- file.path(
  "reports", "qdesn_mcmc_validation", stage, "orchestration", orchestration_tag
)
dir.create(file.path(orchestration_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestration_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

quote_command <- function(command, command_args) {
  paste(c(shQuote(command), shQuote(command_args)), collapse = " ")
}
run_step <- function(label, command, command_args) {
  log_path <- file.path(orchestration_root, "logs", paste0(label, ".log"))
  command_path <- file.path(orchestration_root, "logs", paste0(label, "_command.txt"))
  writeLines(quote_command(command, command_args), command_path, useBytes = TRUE)
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), label))
  status <- system2(command, command_args, stdout = log_path, stderr = log_path)
  if (!identical(as.integer(status), 0L)) {
    stop(sprintf("Step `%s` failed with status %d. Log: %s", label, status, log_path), call. = FALSE)
  }
  list(
    label = label,
    status = as.integer(status),
    command_path = normalizePath(command_path, winslash = "/", mustWork = TRUE),
    log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE)
  )
}

steps <- list()
if (!skip_materialize) {
  steps[[length(steps) + 1L]] <- run_step(
    "00_materialize",
    "Rscript",
    c("scripts/materialize_qdesn_tt500_mcmc_external_coherent_confirmation_v1.R")
  )
}
invisible(lapply(
  c(defaults_path, grid_path, target_specs_path, manifest_path),
  normalizePath,
  mustWork = TRUE
))
targets <- utils::read.csv(target_specs_path, check.names = FALSE, stringsAsFactors = FALSE)
defaults <- yaml::read_yaml(defaults_path)
materialization <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
if (nrow(targets) != 1L ||
    targets$spec_id[[1L]] != expected_spec_id ||
    targets$likelihood_target[[1L]] != "exal" ||
    as.integer(defaults$study_contract$budget$mcmc_n_burn) != 5000L ||
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc) != 20000L ||
    materialization$launch_status != "prepared_not_launched") {
  stop("Confirmation materialization does not certify the exact one-spec full budget.", call. = FALSE)
}

runner_base <- c(
  "scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R",
  "--defaults", defaults_path,
  "--grid", grid_path,
  "--methods", "mcmc",
  "--likelihoods", "exal",
  "--fit-sizes", "500",
  "--priors", "rhs_ns",
  "--scheduler", "load_balanced",
  "--allow-grid-subset",
  "--workers", "1",
  "--no-plots"
)
if (!skip_prepare) {
  prepare_tag <- sprintf(
    "qdesn-tt500-mcmc-external-coherent-confirmation-v1-prepare-%s__git-%s",
    stamp,
    git_short
  )
  steps[[length(steps) + 1L]] <- run_step(
    "10_prepare",
    "Rscript",
    c(
      runner_base,
      "--batch", "full",
      "--run-tag", prepare_tag,
      "--spec-ids", expected_spec_id,
      "--prepare-only"
    )
  )
}
if (run_smoke) {
  smoke_tag <- sprintf(
    "qdesn-tt500-mcmc-external-coherent-confirmation-v1-smoke-%s__git-%s",
    stamp,
    git_short
  )
  steps[[length(steps) + 1L]] <- run_step(
    "20_smoke",
    "Rscript",
    c(
      runner_base,
      "--batch", "smoke",
      "--run-tag", smoke_tag,
      "--spec-ids", expected_spec_id,
      "--stream-child-stdout"
    )
  )
}

full_launch <- NULL
if (full) {
  dirty <- system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    system("git diff --cached --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    length(system("git ls-files --others --exclude-standard", intern = TRUE)) > 0L
  if (dirty) {
    stop("Full confirmation requires a clean committed worktree.", call. = FALSE)
  }
  run_tag <- as.character(get_arg(
    "--run-tag",
    sprintf(
      "qdesn-tt500-mcmc-external-coherent-confirmation-v1-full-%s__git-%s",
      stamp,
      git_short
    )
  ))[1L]
  tmux_session <- as.character(get_arg(
    "--tmux-session",
    sprintf("qdesn_tt500_external_confirm_v1_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
  ))[1L]
  full_launch <- run_step(
    "30_full_detached",
    "Rscript",
    c(
      "scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R",
      runner_base[-1L],
      "--batch", "full",
      "--run-tag", run_tag,
      "--spec-ids", expected_spec_id,
      "--stream-child-stdout",
      "--tmux-session", tmux_session
    )
  )
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestration_tag = orchestration_tag,
  orchestration_root = normalizePath(orchestration_root, winslash = "/", mustWork = TRUE),
  stage = stage,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  selected_specs = nrow(targets),
  selected_spec_id = expected_spec_id,
  workers = 1L,
  prepare_only = prepare_only,
  smoke_requested = run_smoke,
  full_requested = full,
  launch_approved = launch_approved,
  steps = steps,
  full_launch = full_launch
)
orchestration_manifest_path <- file.path(
  orchestration_root,
  "manifest",
  "qdesn_tt500_mcmc_external_coherent_confirmation_v1_orchestration.json"
)
jsonlite::write_json(
  manifest,
  orchestration_manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)
cat(sprintf("orchestration_root: %s\n", normalizePath(orchestration_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("orchestration_manifest: %s\n", normalizePath(orchestration_manifest_path, winslash = "/", mustWork = TRUE)))
if (!is.null(full_launch)) cat("full_launch: detached\n")
