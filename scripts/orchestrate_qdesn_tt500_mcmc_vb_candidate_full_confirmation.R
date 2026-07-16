#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

quote_cmd <- function(cmd, args) paste(c(cmd, shQuote(args)), collapse = " ")
run_cmd <- function(label, cmd, cmd_args, orchestrator_root, allow_failure = FALSE) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  writeLines(quote_cmd(cmd, cmd_args), cmd_path, useBytes = TRUE)
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), label))
  status <- system2(cmd, cmd_args, stdout = log_path, stderr = log_path)
  if (!identical(as.integer(status), 0L) && !isTRUE(allow_failure)) {
    stop(sprintf("Command `%s` failed with status %d. Log: %s", label, as.integer(status), log_path), call. = FALSE)
  }
  list(
    label = label,
    status = as.integer(status),
    log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE),
    command_path = normalizePath(cmd_path, winslash = "/", mustWork = TRUE)
  )
}

stage_file <- as.character(get_arg("--stage-file", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation"))[1L]
workers <- suppressWarnings(as.integer(get_arg("--workers", "12"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 12L
workers <- min(workers, 16L)
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
prepare_only <- has_flag("--prepare-only")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")
run_smoke <- has_flag("--smoke") || (!prepare_only && !skip_smoke)
if (isTRUE(full) && !isTRUE(launch_approved)) {
  stop("Full launch requires --full --launch-approved.", call. = FALSE)
}

git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestrator_tag <- as.character(get_arg(
  "--orchestrator-tag",
  sprintf("qdesn-tt500-mcmc-vbcandidate-orch-%s__git-%s", stamp, git_short)
))[1L]
orchestrator_root <- resolve_path(file.path("reports", "qdesn_mcmc_validation", stage_file, "orchestration", orchestrator_tag), must_work = FALSE)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
target_specs_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv")), must_work = FALSE)
manifest_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)

steps <- list()
if (!isTRUE(skip_materialize)) {
  steps[[length(steps) + 1L]] <- run_cmd(
    "00_materialize",
    "Rscript",
    c(
      "scripts/materialize_qdesn_tt500_mcmc_vb_candidate_full_confirmation.R",
      "--stage-file", stage_file,
      "--workers", as.character(workers)
    ),
    orchestrator_root = orchestrator_root
  )
}

manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
target_specs <- utils::read.csv(target_specs_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(target_specs) || !"spec_id" %in% names(target_specs)) {
  stop(sprintf("No target spec IDs found at %s", target_specs_path), call. = FALSE)
}
all_spec_ids <- paste(unique(as.character(target_specs$spec_id)), collapse = ",")
smoke_spec_id <- as.character(target_specs$spec_id[[1L]])

runner_args_base <- c(
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

if (!isTRUE(skip_prepare)) {
  prepare_tag <- sprintf("qdesn-tt500-mcmc-vbcandidate-prepare-%s__git-%s", stamp, git_short)
  steps[[length(steps) + 1L]] <- run_cmd(
    "10_prepare",
    "Rscript",
    c(
      runner_args_base,
      "--batch", "full",
      "--run-tag", prepare_tag,
      "--spec-ids", all_spec_ids,
      "--prepare-only"
    ),
    orchestrator_root = orchestrator_root
  )
}

if (isTRUE(run_smoke)) {
  smoke_tag <- sprintf("qdesn-tt500-mcmc-vbcandidate-smoke-%s__git-%s", stamp, git_short)
  steps[[length(steps) + 1L]] <- run_cmd(
    "20_smoke",
    "Rscript",
    c(
      runner_args_base,
      "--batch", "smoke",
      "--run-tag", smoke_tag,
      "--workers", "1",
      "--spec-ids", smoke_spec_id,
      "--stream-child-stdout"
    ),
    orchestrator_root = orchestrator_root
  )
}

full_step <- NULL
if (isTRUE(full)) {
  full_tag <- as.character(get_arg(
    "--run-tag",
    sprintf("qdesn-tt500-mcmc-vbcandidate-full-%s__git-%s", stamp, git_short)
  ))[1L]
  full_step <- run_cmd(
    "30_full",
    "Rscript",
    c(
      runner_args_base,
      "--batch", "full",
      "--run-tag", full_tag,
      "--spec-ids", all_spec_ids,
      "--stream-child-stdout"
    ),
    orchestrator_root = orchestrator_root
  )
}

out <- list(
  generated_at = as.character(Sys.time()),
  stage_file = stage_file,
  orchestrator_tag = orchestrator_tag,
  orchestrator_root = orchestrator_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  full = isTRUE(full),
  launch_approved = isTRUE(launch_approved),
  materialization_manifest = manifest_path,
  defaults_path = defaults_path,
  grid_path = grid_path,
  target_specs_path = target_specs_path,
  target_spec_count = length(unique(as.character(target_specs$spec_id))),
  selected_root_count = length(unique(as.character(target_specs$root_id))),
  selected_cell_likelihoods = length(unique(paste(target_specs$family.x, target_specs$tau.x, target_specs$likelihood_target, sep = "\r"))),
  steps = steps,
  full_step = full_step
)
manifest_written <- write_json(out, file.path(orchestrator_root, "manifest", "qdesn_tt500_mcmc_vb_candidate_orchestrator_manifest.json"))
cat(sprintf("orchestrator_manifest: %s\n", manifest_written))
cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
cat(sprintf("target_spec_count: %d\n", out$target_spec_count))
cat(sprintf("selected_root_count: %d\n", out$selected_root_count))
