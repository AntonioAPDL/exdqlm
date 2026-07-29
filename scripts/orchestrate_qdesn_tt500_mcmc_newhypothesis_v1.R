#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(required, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

stage <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1"
defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_path <- file.path("config", "validation", paste0(stage, "_target_spec_ids.csv"))
materializer <- file.path(
  "validation", "fitforecast_v2", "scripts", "materialize_qdesn_mcmc_newhypothesis_v1_design_20260729.R"
)

workers <- suppressWarnings(as.integer(get_arg("--workers", "16"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 16L
workers <- min(workers, 24L)

prepare_only <- has_flag("--prepare-only")
run_smoke <- has_flag("--smoke")
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")

if (full && !launch_approved) {
  stop("Full new-hypothesis v1 launch requires --full --launch-approved.", call. = FALSE)
}
if (!prepare_only && !run_smoke && !full) {
  prepare_only <- TRUE
}
if (full && !skip_smoke) {
  run_smoke <- TRUE
}

git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestration_tag <- sprintf(
  "qdesn-tt500-mcmc-newhypothesis-v1-orch-%s__git-%s",
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
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
col_or <- function(df, candidates, label) {
  hit <- intersect(candidates, names(df))
  if (!length(hit)) {
    stop(sprintf("Target spec table is missing %s column candidates: %s", label, paste(candidates, collapse = ", ")), call. = FALSE)
  }
  df[[hit[[1L]]]]
}

steps <- list()
if (!skip_materialize) {
  steps[[length(steps) + 1L]] <- run_step(
    "00_materialize",
    "Rscript",
    c(materializer, "--workers", as.character(workers))
  )
}
invisible(lapply(c(defaults_path, grid_path, target_specs_path), normalizePath, mustWork = TRUE))
targets <- read_csv(target_specs_path)
defaults <- yaml::read_yaml(defaults_path)

spec_id <- as.character(col_or(targets, "spec_id", "spec_id"))
likelihood_target <- as.character(col_or(targets, "likelihood_target", "likelihood_target"))
rhs_tau0 <- suppressWarnings(as.numeric(col_or(targets, c("rhs_tau0.y", "rhs_tau0"), "rhs_tau0")))
p_over_n <- suppressWarnings(as.numeric(col_or(targets, c("p_over_n_tt500.y", "p_over_n_tt500"), "p_over_n_tt500")))
method <- as.character(col_or(targets, c("method", "inference"), "method"))
prior <- as.character(col_or(targets, c("prior", "beta_prior_type"), "prior"))

if (nrow(targets) != 96L ||
    anyDuplicated(spec_id) ||
    any(!likelihood_target %in% c("al", "exal")) ||
    any(!is.finite(rhs_tau0) | rhs_tau0 <= 0) ||
    any(!is.finite(p_over_n) | p_over_n > 0.35) ||
    any(method != "mcmc") ||
    any(prior != "rhs_ns")) {
  stop("New-hypothesis v1 target table failed the 96-root RHS MCMC launch contract.", call. = FALSE)
}
if (as.integer(defaults$study_contract$budget$mcmc_n_burn %||% NA_integer_) != 2000L ||
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc %||% NA_integer_) != 8000L ||
    as.integer(defaults$pipeline$inference$mcmc$progress_every %||% NA_integer_) != 50L) {
  stop("New-hypothesis v1 defaults lost the frozen MCMC budget/progress contract.", call. = FALSE)
}
all_spec_ids <- paste(spec_id, collapse = ",")

smoke_profile_id <- as.character(unlist(defaults$smoke$screening_profile_ids, use.names = FALSE))[[1L]]
screening_profile <- as.character(col_or(targets, c("screening_profile_id.y", "screening_profile_id.x", "screening_profile_id"), "screening_profile_id"))
family <- as.character(col_or(targets, c("family.y", "family.x", "family"), "family"))
tau <- suppressWarnings(as.numeric(col_or(targets, c("tau.y", "tau.x", "tau"), "tau")))
smoke_target <- targets[
  screening_profile == smoke_profile_id &
    family == as.character(defaults$smoke$family)[1L] &
    abs(tau - as.numeric(defaults$smoke$tau)[1L]) <= 1e-8 &
    likelihood_target == as.character(targets$likelihood_target[[1L]]),
  ,
  drop = FALSE
]
if (nrow(smoke_target) != 1L) {
  stop("Could not resolve exactly one new-hypothesis v1 smoke spec.", call. = FALSE)
}
smoke_spec_id <- as.character(smoke_target$spec_id[[1L]])

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
    "qdesn-tt500-mcmc-newhypothesis-v1-prepare-%s__git-%s",
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

if (run_smoke && !skip_smoke) {
  smoke_tag <- sprintf(
    "qdesn-tt500-mcmc-newhypothesis-v1-smoke-%s__git-%s",
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
      "--spec-ids", smoke_spec_id,
      "--stream-child-stdout"
    )
  )
}

full_launch <- NULL
if (full) {
  run_tag <- as.character(get_arg(
    "--run-tag",
    sprintf(
      "qdesn-tt500-mcmc-newhypothesis-v1-full-%s__git-%s",
      format(Sys.Date(), "%Y%m%d"),
      git_short
    )
  ))[1L]
  tmux_session <- as.character(get_arg(
    "--tmux-session",
    sprintf("qdesn_tt500_mcmc_newhypothesis_v1_%s", format(Sys.time(), "%Y%m%d_%H%M%S"))
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

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestration_tag = orchestration_tag,
  orchestration_root = normalizePath(orchestration_root, winslash = "/", mustWork = TRUE),
  stage = stage,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  workers = workers,
  selected_specs = nrow(targets),
  mcmc_n_burn = as.integer(defaults$study_contract$budget$mcmc_n_burn),
  mcmc_n_mcmc = as.integer(defaults$study_contract$budget$mcmc_n_mcmc),
  max_p_over_n_tt500 = max(p_over_n),
  prepare_only = prepare_only,
  smoke_requested = run_smoke && !skip_smoke,
  smoke_spec_id = smoke_spec_id,
  full_requested = full,
  launch_approved = launch_approved,
  steps = steps,
  full_launch = full_launch
)
manifest_path <- file.path(
  orchestration_root,
  "manifest",
  "qdesn_tt500_mcmc_newhypothesis_v1_orchestration.json"
)
jsonlite::write_json(
  manifest,
  manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)
cat(sprintf("orchestration_manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("selected_specs: %d\n", nrow(targets)))
cat(sprintf("workers: %d\n", workers))
if (!is.null(full_launch)) cat("full_launch: detached\n")
