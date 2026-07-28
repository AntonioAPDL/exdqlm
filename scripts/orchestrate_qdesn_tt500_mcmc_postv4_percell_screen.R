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

stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell"
defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_path <- file.path("config", "validation", paste0(stage, "_target_spec_ids.csv"))
manifest_path <- file.path("config", "validation", paste0(stage, "_materialization_manifest.json"))
workers <- suppressWarnings(as.integer(get_arg("--workers", "16"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 24L)

prepare_only <- has_flag("--prepare-only")
smoke_requested <- has_flag("--smoke")
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")
if (full && !launch_approved) {
  stop("Full post-v4 per-cell launch requires --full --launch-approved.", call. = FALSE)
}
if (!prepare_only && !smoke_requested && !full) {
  prepare_only <- TRUE
}
run_smoke <- !skip_smoke && (smoke_requested || full)

git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestration_tag <- sprintf(
  "qdesn-tt500-mcmc-postv4-percell-orch-%s__git-%s",
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
worktree_dirty <- function() {
  system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    system("git diff --cached --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    length(system("git ls-files --others --exclude-standard", intern = TRUE)) > 0L
}

steps <- list()
if (!skip_materialize) {
  steps[[length(steps) + 1L]] <- run_step(
    "00_materialize",
    "Rscript",
    c("scripts/materialize_qdesn_tt500_mcmc_postv4_percell_screen.R", "--workers", as.character(workers))
  )
}
invisible(lapply(c(defaults_path, grid_path, target_specs_path, manifest_path), normalizePath, mustWork = TRUE))
targets <- utils::read.csv(target_specs_path, check.names = FALSE, stringsAsFactors = FALSE)
defaults <- yaml::read_yaml(defaults_path)
materialization <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
if (nrow(targets) != 90L ||
    length(unique(as.character(targets$spec_id))) != 90L ||
    as.integer(defaults$study_contract$budget$mcmc_n_burn) != 2000L ||
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc) != 8000L ||
    as.integer(materialization$counts$target_mcmc_atomic_specs) != 90L ||
    as.character(materialization$launch_status) != "prepared_not_launched") {
  stop("Post-v4 per-cell materialization does not certify the exact 90-spec screening contract.", call. = FALSE)
}
all_spec_ids <- paste(as.character(targets$spec_id), collapse = ",")

smoke_profiles <- as.character(unlist(defaults$smoke$screening_profile_ids, use.names = FALSE))
profile_col <- if ("screening_profile_id.x" %in% names(targets)) "screening_profile_id.x" else "screening_profile_id"
family_col <- if ("family.x" %in% names(targets)) "family.x" else "family"
tau_col <- if ("tau.x" %in% names(targets)) "tau.x" else "tau"
smoke_target <- targets[
  as.character(targets[[profile_col]]) %in% smoke_profiles &
    as.character(targets[[family_col]]) == as.character(defaults$smoke$family)[1L] &
    abs(as.numeric(targets[[tau_col]]) - as.numeric(defaults$smoke$tau)[1L]) <= 1e-8,
  ,
  drop = FALSE
]
if (nrow(smoke_target) != 1L) {
  stop("Could not resolve exactly one post-v4 per-cell smoke spec.", call. = FALSE)
}

runner_base <- c(
  "scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R",
  "--defaults", defaults_path,
  "--grid", grid_path,
  "--methods", "mcmc",
  "--likelihoods", "al,exal",
  "--fit-sizes", "500",
  "--priors", "rhs_ns",
  "--scheduler", "load_balanced",
  "--allow-grid-subset",
  "--workers", as.character(workers),
  "--no-plots"
)
if (!skip_prepare) {
  prepare_tag <- sprintf(
    "qdesn-tt500-mcmc-postv4-percell-prepare-%s__git-%s",
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
      "--spec-ids", all_spec_ids,
      "--prepare-only"
    )
  )
}
if (run_smoke) {
  smoke_tag <- sprintf(
    "qdesn-tt500-mcmc-postv4-percell-smoke-%s__git-%s",
    stamp,
    git_short
  )
  steps[[length(steps) + 1L]] <- run_step(
    "20_smoke",
    "Rscript",
    c(
      runner_base,
      "--batch", "smoke",
      "--workers", "1",
      "--run-tag", smoke_tag,
      "--spec-ids", as.character(smoke_target$spec_id[[1L]]),
      "--stream-child-stdout"
    )
  )
}

full_launch <- NULL
if (full) {
  if (worktree_dirty()) {
    stop(
      "Full post-v4 launch requires a clean committed worktree. Commit materialized artifacts, then rerun with --skip-materialize.",
      call. = FALSE
    )
  }
  run_tag <- as.character(get_arg(
    "--run-tag",
    sprintf(
      "qdesn-tt500-mcmc-postv4-percell-full-%s__git-%s",
      format(Sys.Date(), "%Y%m%d"),
      git_short
    )
  ))[1L]
  tmux_session <- as.character(get_arg(
    "--tmux-session",
    sprintf("qdesn_tt500_mcmc_postv4_percell_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
  ))[1L]
  full_launch <- run_step(
    "30_full_detached",
    "Rscript",
    c(
      "scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R",
      runner_base[-1L],
      "--batch", "full",
      "--run-tag", run_tag,
      "--spec-ids", all_spec_ids,
      "--stream-child-stdout",
      "--tmux-session", tmux_session
    )
  )
}

orchestration_manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestration_tag = orchestration_tag,
  orchestration_root = normalizePath(orchestration_root, winslash = "/", mustWork = TRUE),
  stage = stage,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  selected_specs = nrow(targets),
  source_registry_hash = as.character(materialization$source_registry_hash),
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
  "qdesn_tt500_mcmc_postv4_percell_orchestration.json"
)
jsonlite::write_json(
  orchestration_manifest,
  orchestration_manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)
cat(sprintf("orchestration_root: %s\n", normalizePath(orchestration_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("orchestration_manifest: %s\n", normalizePath(orchestration_manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("selected_specs: %d\n", nrow(targets)))
if (!is.null(full_launch)) cat("full_launch: detached\n")
