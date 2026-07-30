#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(
      sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
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

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
design_id <- "qdesn_500obs_mcmc_nested_final_origin9000_v1_design_20260730"
design_root <- file.path(
  "validation", "fitforecast_v2", "promotions", design_id
)
materializer <- file.path(
  "validation", "fitforecast_v2", "scripts",
  "materialize_qdesn_mcmc_nested_final_origin_20260730.R"
)
source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_path <- file.path(
  "config", "validation", paste0(stage, "_target_spec_ids.csv")
)
contract_path <- file.path(design_root, "confirmation_contract.csv")
stability_path <- file.path(design_root, "originwise_stability_summary.csv")

workers <- suppressWarnings(as.integer(get_arg("--workers", "8"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 8L
workers <- min(workers, 8L)

prepare_only <- has_flag("--prepare-only")
smoke_requested <- has_flag("--smoke")
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")
if (!prepare_only && !smoke_requested && !full) prepare_only <- TRUE
if (full && !launch_approved) {
  stop(
    "Full final-origin launch requires --full --launch-approved.",
    call. = FALSE
  )
}
run_smoke <- !skip_smoke && (smoke_requested || full)

git_branch <- trimws(system("git branch --show-current", intern = TRUE))
git_commit <- trimws(system("git rev-parse HEAD", intern = TRUE))
git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestration_tag <- sprintf(
  "qdesn-500obs-mcmc-nested-final-o9000-v1-orch-%s__git-%s",
  stamp,
  git_short
)
orchestration_root <- file.path(
  "reports", "qdesn_mcmc_validation", stage, "orchestration",
  orchestration_tag
)
dir.create(
  file.path(orchestration_root, "logs"),
  recursive = TRUE,
  showWarnings = FALSE
)
dir.create(
  file.path(orchestration_root, "manifest"),
  recursive = TRUE,
  showWarnings = FALSE
)

worktree_dirty <- function() {
  system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    system(
      "git diff --cached --quiet",
      ignore.stdout = TRUE,
      ignore.stderr = TRUE
    ) != 0L ||
    length(system("git ls-files --others --exclude-standard", intern = TRUE)) > 0L
}
quote_command <- function(command, command_args) {
  paste(c(shQuote(command), shQuote(command_args)), collapse = " ")
}
run_step <- function(label, command, command_args) {
  log_path <- file.path(orchestration_root, "logs", paste0(label, ".log"))
  command_path <- file.path(
    orchestration_root, "logs", paste0(label, "_command.txt")
  )
  writeLines(
    quote_command(command, command_args),
    command_path,
    useBytes = TRUE
  )
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), label))
  status <- system2(command, command_args, stdout = log_path, stderr = log_path)
  if (!identical(as.integer(status), 0L)) {
    stop(
      sprintf(
        "Step `%s` failed with status %d. Log: %s",
        label,
        status,
        log_path
      ),
      call. = FALSE
    )
  }
  list(
    label = label,
    status = as.integer(status),
    command_path = normalizePath(
      command_path, winslash = "/", mustWork = TRUE
    ),
    log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE)
  )
}
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
col_or <- function(df, candidates, label) {
  hit <- intersect(candidates, names(df))
  if (!length(hit)) {
    stop(
      sprintf(
        "Missing %s column; tried %s.",
        label,
        paste(candidates, collapse = ", ")
      ),
      call. = FALSE
    )
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

required_paths <- c(
  defaults_path,
  grid_path,
  target_specs_path,
  contract_path,
  stability_path,
  file.path(design_root, paste0(design_id, "_manifest.json"))
)
invisible(lapply(required_paths, normalizePath, mustWork = TRUE))

defaults <- yaml::read_yaml(defaults_path)
grid <- read_csv(grid_path)
targets <- read_csv(target_specs_path)
contract <- read_csv(contract_path)
stability <- read_csv(stability_path)
spec_ids <- as.character(col_or(targets, "spec_id", "spec_id"))
profile_ids <- as.character(col_or(
  targets,
  c("screening_profile_id.x", "screening_profile_id.y", "screening_profile_id"),
  "screening_profile_id"
))
methods <- as.character(col_or(targets, c("method", "inference"), "method"))
likelihoods <- as.character(col_or(
  targets,
  c("likelihood_family", "likelihood_target"),
  "likelihood"
))
priors <- as.character(col_or(
  targets,
  c("prior", "beta_prior_type"),
  "prior"
))

contract_ok <- nrow(contract) == 1L &&
  contract$source_registry_hash_value[[1L]] == source_hash &&
  contract$final_origin_source_index[[1L]] == 9000L &&
  contract$selected_cells[[1L]] == 4L &&
  contract$selected_roots[[1L]] == 8L &&
  contract$planned_chain_fits[[1L]] == 16L &&
  contract$mcmc_n_burn[[1L]] == 5000L &&
  contract$mcmc_n_mcmc[[1L]] == 20000L &&
  nrow(grid) == 8L &&
  all(grid$train_start_source_index == 8501L) &&
  all(grid$train_end_source_index == 9000L) &&
  all(grid$forecast_start_source_index == 9001L) &&
  all(grid$forecast_end_source_index == 10000L) &&
  nrow(targets) == 8L &&
  !anyDuplicated(spec_ids) &&
  all(methods == "mcmc") &&
  all(likelihoods %in% c("al", "exal")) &&
  all(priors == "rhs_ns") &&
  nrow(stability) == 4L &&
  sum(stability$confirmation_role == "primary_confirmation") == 3L &&
  sum(stability$confirmation_role == "instability_sentinel") == 1L &&
  identical(
    as.character(defaults$study_contract$source_registry_hash_value),
    source_hash
  ) &&
  as.integer(defaults$study_contract$budget$mcmc_n_burn) == 5000L &&
  as.integer(defaults$study_contract$budget$mcmc_n_mcmc) == 20000L &&
  as.integer(defaults$metrics$posterior_metric_draws) == 200L &&
  as.integer(defaults$pipeline$inference$mcmc$progress_every) == 50L &&
  isTRUE(defaults$multiseed$enabled) &&
  as.integer(defaults$multiseed$mcmc_seed_reps) == 2L &&
  as.integer(defaults$multiseed$parallel_seed_workers) == 1L &&
  !isTRUE(defaults$pipeline$outputs$keep_draws) &&
  !isTRUE(defaults$pipeline$outputs$save_forecast_objects) &&
  !isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure)
if (!contract_ok) {
  stop("Final-origin launch contract failed.", call. = FALSE)
}

smoke_profiles <- as.character(
  unlist(defaults$smoke$screening_profile_ids, use.names = FALSE)
)
smoke_index <- which(profile_ids %in% smoke_profiles)
if (length(smoke_index) != 1L) {
  stop("Could not resolve exactly one final-origin smoke spec.", call. = FALSE)
}
smoke_spec_id <- spec_ids[[smoke_index]]

heavy <- list.files(
  design_root,
  pattern = "[.](rds|rda|RData)$|__design[.]rds$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(heavy)) {
  stop("Forbidden heavy payload found in the tracked design root.", call. = FALSE)
}

runner_args <- function(run_workers) {
  c(
    "scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R",
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--methods", "mcmc",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--scheduler", "load_balanced",
    "--allow-grid-subset",
    "--workers", as.character(run_workers),
    "--no-plots"
  )
}

prepare_tag <- NULL
if (!skip_prepare) {
  prepare_tag <- sprintf(
    "qdesn-500obs-mcmc-nested-final-o9000-v1-prepare-%s__git-%s",
    stamp,
    git_short
  )
  steps[[length(steps) + 1L]] <- run_step(
    "10_prepare",
    "Rscript",
    c(
      runner_args(workers),
      "--batch", "full",
      "--run-tag", prepare_tag,
      "--spec-ids", paste(spec_ids, collapse = ","),
      "--prepare-only"
    )
  )
}

smoke_tag <- NULL
if (run_smoke) {
  smoke_tag <- sprintf(
    "qdesn-500obs-mcmc-nested-final-o9000-v1-smoke-%s__git-%s",
    stamp,
    git_short
  )
  steps[[length(steps) + 1L]] <- run_step(
    "20_smoke",
    "Rscript",
    c(
      runner_args(1L),
      "--batch", "smoke",
      "--run-tag", smoke_tag,
      "--spec-ids", smoke_spec_id,
      "--stream-child-stdout"
    )
  )
}

full_launch <- list()
if (full) {
  if (worktree_dirty()) {
    stop(
      paste(
        "Full final-origin launch requires a clean committed worktree.",
        "Commit the validated campaign files, then rerun with",
        "--skip-materialize --skip-prepare --skip-smoke."
      ),
      call. = FALSE
    )
  }
  run_tag <- sprintf(
    "qdesn-500obs-mcmc-nested-final-o9000-v1-full-%s__git-%s",
    format(Sys.Date(), "%Y%m%d"),
    git_short
  )
  tmux_session <- sprintf(
    "qdesn_500obs_nested_final_o9000_v1_%s",
    format(Sys.time(), "%Y%m%d_%H%M%S")
  )
  full_launch <- run_step(
    "30_full_detached",
    "Rscript",
    c(
      "scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R",
      runner_args(workers)[-1L],
      "--batch", "full",
      "--run-tag", run_tag,
      "--spec-ids", paste(spec_ids, collapse = ","),
      "--stream-child-stdout",
      "--tmux-session", tmux_session
    )
  )
  full_launch$run_tag <- run_tag
  full_launch$tmux_session <- tmux_session
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestration_tag = orchestration_tag,
  orchestration_root = normalizePath(
    orchestration_root, winslash = "/", mustWork = TRUE
  ),
  stage = stage,
  design_id = design_id,
  git_branch = git_branch,
  git_commit = git_commit,
  git_dirty = worktree_dirty(),
  source_registry_hash_value = source_hash,
  workers_cap = workers,
  selected_cells = 4L,
  selected_roots = 8L,
  mcmc_seed_reps = 2L,
  planned_chain_fits = 16L,
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  posterior_metric_draws = 200L,
  primary_confirmations = 3L,
  instability_sentinels = 1L,
  prepare_requested = !skip_prepare,
  prepare_run_tag = prepare_tag,
  smoke_requested = run_smoke,
  smoke_run_tag = smoke_tag,
  full_requested = full,
  launch_approved = launch_approved,
  article_update_policy = "manual_after_final_closeout_only",
  steps = steps,
  full_launch = full_launch
)
manifest_path <- file.path(
  orchestration_root,
  "manifest",
  "qdesn_500obs_mcmc_nested_final_origin_v1_orchestration.json"
)
jsonlite::write_json(
  manifest,
  manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)

cat(sprintf(
  "orchestration_root: %s\n",
  normalizePath(orchestration_root, winslash = "/", mustWork = TRUE)
))
cat(sprintf(
  "orchestration_manifest: %s\n",
  normalizePath(manifest_path, winslash = "/", mustWork = TRUE)
))
cat("selected_roots: 8\n")
cat("planned_chain_fits: 16\n")
cat(sprintf("workers: %d\n", workers))
if (length(full_launch)) {
  cat(sprintf("run_tag: %s\n", full_launch$run_tag))
  cat(sprintf("tmux_session: %s\n", full_launch$tmux_session))
}
