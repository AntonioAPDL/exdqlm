#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
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
split_csv_arg <- function(x) {
  x <- as.character(x %||% "")[1L]
  if (!nzchar(trimws(x))) return(character(0))
  trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
}

stage_prefix <- get_arg("--stage-prefix", "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first")
short_path_mode <- has_flag("--short-path-mode") || grepl("^qvbm[0-9]+$", stage_prefix)
stage_short_code <- if (grepl("^qvbm[0-9]+$", stage_prefix)) {
  sub("^qvbm", "m", stage_prefix)
} else {
  "m"
}
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
workers <- min(workers, 30L)

dry_run <- has_flag("--dry-run")
materialize_only <- has_flag("--materialize-only")
prepare_only <- has_flag("--prepare-only")
full <- has_flag("--full") && !dry_run
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_audit <- has_flag("--skip-audit")
skip_prepare <- has_flag("--skip-prepare")
bundle_filter <- split_csv_arg(get_arg("--bundles", ""))
fit_timeout_seconds <- suppressWarnings(as.integer(get_arg("--fit-timeout-seconds", "0"))[1L])
stream_child_stdout <- has_flag("--stream-child-stdout")
if (isTRUE(full) && !isTRUE(launch_approved)) {
  stop("Mechanism-first full launch requires --full --launch-approved.", call. = FALSE)
}

git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
stamp_short <- format(Sys.time(), "%m%d%H%M")
orchestrator_tag <- get_arg(
  "--orchestrator-tag",
  if (isTRUE(short_path_mode)) {
    sprintf("%s_%s__git-%s", stage_prefix, stamp_short, git_short)
  } else {
    sprintf("qdesn-vb-mechanism-first-orchestrator-%s__git-%s", stamp, git_short)
  }
)
orchestrator_root <- if (isTRUE(short_path_mode)) {
  resolve_path(file.path("reports", stage_prefix, "orch", orchestrator_tag), must_work = FALSE)
} else {
  resolve_path(file.path(
    "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first",
    orchestrator_tag
  ), must_work = FALSE)
}
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

run_cmd <- function(label, cmd, cmd_args, allow_failure = FALSE) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  writeLines(paste(c(cmd, shQuote(cmd_args)), collapse = " "), cmd_path)
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), label))
  status <- system2(cmd, args = cmd_args, stdout = log_path, stderr = log_path)
  if (!identical(as.integer(status), 0L) && !isTRUE(allow_failure)) {
    stop(sprintf("Command '%s' failed with status %d. Log: %s", label, as.integer(status), log_path), call. = FALSE)
  }
  list(label = label, status = as.integer(status), log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE), command_path = normalizePath(cmd_path, winslash = "/", mustWork = TRUE))
}

bundle_postrun_gate <- function(row, run_tag) {
  target_specs <- utils::read.csv(resolve_path(row$target_spec_ids_path[[1L]], must_work = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(resolve_path(row$defaults_path[[1L]], must_work = TRUE))
  results_base <- resolve_path((defaults$campaign %||% list())$results_root, must_work = FALSE)
  run_root <- file.path(results_base, run_tag)
  status_files <- list.files(
    run_root,
    pattern = "root_status[.]txt$",
    recursive = TRUE,
    full.names = TRUE
  )
  status_values <- vapply(status_files, function(path) {
    txt <- tryCatch(readLines(path, warn = FALSE), error = function(e) character(0))
    trimws(as.character(txt[1L] %||% "UNKNOWN"))
  }, character(1L))
  status_values <- toupper(status_values)
  counts <- as.list(table(status_values))
  n_success <- as.integer(counts$SUCCESS %||% 0L)
  n_fail <- as.integer(counts$FAIL %||% 0L)
  n_running <- as.integer(counts$RUNNING %||% 0L)
  n_unknown <- sum(!status_values %in% c("SUCCESS", "FAIL", "RUNNING"))
  gate <- list(
    generated_at = as.character(Sys.time()),
    bundle_id = as.character(row$bundle_id[[1L]]),
    bundle_code = as.character(row$bundle_code[[1L]]),
    run_tag = as.character(run_tag),
    run_root = normalizePath(run_root, winslash = "/", mustWork = FALSE),
    expected_roots = as.integer(nrow(target_specs)),
    observed_root_status_files = as.integer(length(status_files)),
    n_success = n_success,
    n_fail = n_fail,
    n_running = n_running,
    n_unknown = as.integer(n_unknown),
    status_counts = counts
  )
  gate_path <- file.path(orchestrator_root, "logs", sprintf("postrun_gate_%s.json", as.character(row$bundle_code[[1L]])))
  write_json(gate, gate_path)
  if (length(status_files) < nrow(target_specs)) {
    stop(sprintf(
      "Bundle '%s' post-run gate failed: observed %d root_status files, expected %d. Gate: %s",
      as.character(row$bundle_id[[1L]]),
      length(status_files),
      nrow(target_specs),
      gate_path
    ), call. = FALSE)
  }
  if (n_running > 0L || n_unknown > 0L) {
    stop(sprintf(
      "Bundle '%s' post-run gate failed: RUNNING=%d UNKNOWN=%d. Gate: %s",
      as.character(row$bundle_id[[1L]]),
      n_running,
      n_unknown,
      gate_path
    ), call. = FALSE)
  }
  if (n_success < 1L) {
    stop(sprintf(
      "Bundle '%s' post-run gate failed: zero successful roots out of %d. Gate: %s",
      as.character(row$bundle_id[[1L]]),
      length(status_files),
      gate_path
    ), call. = FALSE)
  }
  gate
}

steps <- list()
if (!isTRUE(skip_materialize)) {
  mat_args <- c(
    "scripts/materialize_qdesn_tt500_vb_mechanism_first_redesign.R",
    "--stage-prefix", stage_prefix,
    "--workers", as.character(workers)
  )
  if (isTRUE(short_path_mode)) mat_args <- c(mat_args, "--short-path-mode")
  steps[[length(steps) + 1L]] <- run_cmd("00_materialize", "Rscript", mat_args)
}
if (!isTRUE(skip_audit)) {
  audit_args <- c(
    "scripts/audit_qdesn_tt500_vb_mechanism_first_materialization.R",
    "--stage-prefix", stage_prefix
  )
  if (isTRUE(short_path_mode)) audit_args <- c(audit_args, "--short-path-mode")
  steps[[length(steps) + 1L]] <- run_cmd("01_audit", "Rscript", audit_args)
}

index_path <- resolve_path(file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv")), must_work = TRUE)
index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
if (length(bundle_filter)) {
  index <- index[as.character(index$bundle_id) %in% bundle_filter, , drop = FALSE]
  if (!nrow(index)) stop("No bundles remain after --bundles filter.", call. = FALSE)
}
index <- index[order(index$bundle_order), , drop = FALSE]

if (isTRUE(materialize_only) || isTRUE(dry_run)) {
  manifest_path <- write_json(
    list(
      generated_at = as.character(Sys.time()),
      mode = if (isTRUE(materialize_only)) "materialize_only" else "dry_run",
      orchestrator_root = orchestrator_root,
      index_path = index_path,
      bundles = index,
      steps = steps
    ),
    file.path(orchestrator_root, "manifest", "mechanism_first_orchestrator_manifest.json")
  )
  cat(sprintf("Stopped after materialize/audit. Manifest: %s\n", manifest_path))
  quit(status = 0L, save = "no")
}

run_one_bundle <- function(row, mode = c("prepare", "full")) {
  mode <- match.arg(mode)
  bundle_id <- as.character(row$bundle_id[[1L]])
  bundle_code <- as.character((row$bundle_code %||% gsub("[^A-Za-z0-9]", "", bundle_id))[[1L]])
  if (!nzchar(bundle_code)) bundle_code <- substr(gsub("[^A-Za-z0-9]", "", bundle_id), 1L, 8L)
  target_specs <- utils::read.csv(resolve_path(row$target_spec_ids_path[[1L]], must_work = TRUE), check.names = FALSE, stringsAsFactors = FALSE)
  spec_ids <- paste(as.character(target_specs$spec_id), collapse = ",")
  run_tag <- if (isTRUE(short_path_mode)) {
    sprintf("%s%s%s_%s_%s", stage_short_code, bundle_code, substr(mode, 1L, 1L), stamp_short, git_short)
  } else {
    sprintf(
      "qdesn-vb-mechanism-first-%s-%s-%s__git-%s",
      gsub("_", "-", bundle_id),
      mode,
      stamp,
      git_short
    )
  }
  runner_args <- c(
    "scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R",
    "--defaults", as.character(row$defaults_path[[1L]]),
    "--grid", as.character(row$grid_path[[1L]]),
    "--batch", "full",
    "--methods", "vb",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--scheduler", "load_balanced",
    "--allow-grid-subset",
    "--workers", as.character(workers),
    "--run-tag", run_tag,
    "--spec-ids", spec_ids,
    "--no-plots"
  )
  if (isTRUE(stream_child_stdout)) runner_args <- c(runner_args, "--stream-child-stdout")
  if (is.finite(fit_timeout_seconds) && fit_timeout_seconds > 0L) {
    runner_args <- c(runner_args, "--fit-timeout-seconds", as.character(fit_timeout_seconds))
  }
  if (identical(mode, "prepare")) runner_args <- c(runner_args, "--prepare-only")
  label <- if (isTRUE(short_path_mode)) {
    sprintf("%s_%s", if (identical(mode, "prepare")) "10p" else "20f", bundle_code)
  } else {
    sprintf("%s_%s", if (identical(mode, "prepare")) "10_prepare" else "20_full", bundle_id)
  }
  out <- run_cmd(label, "Rscript", runner_args)
  if (identical(mode, "full")) {
    out$postrun_gate <- bundle_postrun_gate(row, run_tag)
  }
  out$bundle_id <- bundle_id
  out$mode <- mode
  out$run_tag <- run_tag
  out
}

if (!isTRUE(skip_prepare)) {
  for (i in seq_len(nrow(index))) steps[[length(steps) + 1L]] <- run_one_bundle(index[i, , drop = FALSE], "prepare")
}
if (isTRUE(prepare_only)) {
  manifest_path <- write_json(
    list(
      generated_at = as.character(Sys.time()),
      mode = "prepare_only",
      orchestrator_root = orchestrator_root,
      index_path = index_path,
      bundles = index,
      steps = steps
    ),
    file.path(orchestrator_root, "manifest", "mechanism_first_orchestrator_manifest.json")
  )
  cat(sprintf("Stopped after prepare-only. Manifest: %s\n", manifest_path))
  quit(status = 0L, save = "no")
}
if (isTRUE(full)) {
  for (i in seq_len(nrow(index))) steps[[length(steps) + 1L]] <- run_one_bundle(index[i, , drop = FALSE], "full")
}

manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    mode = if (isTRUE(full)) "full" else "audit_prepare",
    launch_approved = isTRUE(launch_approved),
    orchestrator_root = orchestrator_root,
    index_path = index_path,
    workers = workers,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
    bundles = index,
    steps = steps
  ),
  file.path(orchestrator_root, "manifest", "mechanism_first_orchestrator_manifest.json")
)
cat(sprintf("Mechanism-first orchestrator complete. Manifest: %s\n", manifest_path))
