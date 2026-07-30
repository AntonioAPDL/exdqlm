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
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)

stage_base <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1"
materializer <- file.path(
  "validation", "fitforecast_v2", "scripts",
  "materialize_qdesn_mcmc_nested_cellwise_v1_20260729.R"
)
promotion_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_design_20260729"
promotion_root <- file.path("validation", "fitforecast_v2", "promotions", promotion_id)
source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
origins <- c(7000L, 8000L)

workers <- suppressWarnings(as.integer(get_arg("--workers", "16"))[1L])
if (!is.finite(workers) || workers < 2L) workers <- 16L
workers <- min(workers, 16L)
workers_per_view <- max(1L, workers %/% length(origins))

prepare_only <- has_flag("--prepare-only")
smoke_requested <- has_flag("--smoke")
full <- has_flag("--full")
launch_approved <- has_flag("--launch-approved")
skip_materialize <- has_flag("--skip-materialize")
skip_prepare <- has_flag("--skip-prepare")
skip_smoke <- has_flag("--skip-smoke")
if (!prepare_only && !smoke_requested && !full) prepare_only <- TRUE
if (full && !launch_approved) {
  stop("Full nested-cellwise v1 launch requires --full --launch-approved.", call. = FALSE)
}
run_smoke <- !skip_smoke && (smoke_requested || full)

git_branch <- trimws(system("git branch --show-current", intern = TRUE))
git_commit <- trimws(system("git rev-parse HEAD", intern = TRUE))
git_short <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
orchestration_tag <- sprintf(
  "qdesn-500obs-mcmc-nested-v1-orch-%s__git-%s",
  stamp,
  git_short
)
orchestration_root <- file.path(
  "reports", "qdesn_mcmc_validation", stage_base, "orchestration",
  orchestration_tag
)
dir.create(file.path(orchestration_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestration_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

worktree_dirty <- function() {
  system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    system("git diff --cached --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
    length(system("git ls-files --others --exclude-standard", intern = TRUE)) > 0L
}
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
    stop(
      sprintf("Step `%s` failed with status %d. Log: %s", label, status, log_path),
      call. = FALSE
    )
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
    stop(
      sprintf("Missing %s column; tried %s.", label, paste(candidates, collapse = ", ")),
      call. = FALSE
    )
  }
  df[[hit[[1L]]]]
}
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

steps <- list()
if (!skip_materialize) {
  steps[[length(steps) + 1L]] <- run_step(
    "00_materialize",
    "Rscript",
    c(materializer, "--workers", as.character(workers))
  )
}

design_summary_path <- file.path(
  promotion_root,
  paste0(promotion_id, "_summary.csv")
)
repeat_audit_path <- file.path(
  promotion_root,
  paste0(promotion_id, "_exact_repeat_audit.csv")
)
view_registry_path <- file.path(
  promotion_root,
  paste0(promotion_id, "_calibration_view_registry.csv")
)
invisible(lapply(
  c(design_summary_path, repeat_audit_path, view_registry_path),
  normalizePath,
  mustWork = TRUE
))
design_summary <- read_csv(design_summary_path)
repeat_audit <- read_csv(repeat_audit_path)
view_registry <- read_csv(view_registry_path)

if (nrow(design_summary) != 1L ||
    design_summary$target_cells[[1L]] != 15L ||
    design_summary$selected_roots_total[[1L]] != 720L ||
    design_summary$planned_chain_fits[[1L]] != 1440L ||
    design_summary$source_registry_hash_value[[1L]] != source_hash ||
    nrow(view_registry) != 2L ||
    !setequal(view_registry$calibration_origin_source_index, origins) ||
    any(as_bool(repeat_audit$exact_history_repeat) & !as_bool(repeat_audit$repeat_allowed))) {
  stop("Nested-cellwise v1 design-level contract failed.", call. = FALSE)
}

view_contracts <- list()
for (origin in origins) {
  view_id <- paste0("origin", origin)
  stage <- paste0(stage_base, "_", view_id)
  defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
  grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
  target_specs_path <- file.path(
    "config", "validation", paste0(stage, "_target_spec_ids.csv")
  )
  invisible(lapply(
    c(defaults_path, grid_path, target_specs_path),
    normalizePath,
    mustWork = TRUE
  ))
  defaults <- yaml::read_yaml(defaults_path)
  grid <- read_csv(grid_path)
  targets <- read_csv(target_specs_path)

  spec_id <- as.character(col_or(targets, "spec_id", "spec_id"))
  likelihood <- as.character(col_or(
    targets,
    c("likelihood_family", "likelihood_target"),
    "likelihood"
  ))
  method <- as.character(col_or(targets, c("method", "inference"), "method"))
  prior <- as.character(col_or(targets, c("prior", "beta_prior_type"), "prior"))
  p_over_n <- suppressWarnings(as.numeric(col_or(
    targets,
    "p_over_n_tt500",
    "p_over_n_tt500"
  )))
  repeat_class <- as.character(col_or(targets, "repeat_class", "repeat_class"))

  view_ok <- nrow(targets) == 360L &&
    !anyDuplicated(spec_id) &&
    nrow(grid) == 360L &&
    all(method == "mcmc") &&
    all(prior == "rhs_ns") &&
    all(likelihood %in% c("al", "exal")) &&
    all(is.finite(p_over_n)) &&
    all(p_over_n[repeat_class == "novel_candidate"] <= 0.20) &&
    max(p_over_n) <= 0.35 &&
    all(as.integer(grid$train_start_source_index) == origin - 499L) &&
    all(as.integer(grid$train_end_source_index) == origin) &&
    all(as.integer(grid$forecast_start_source_index) == origin + 1L) &&
    all(as.integer(grid$forecast_end_source_index) == origin + 1000L) &&
    identical(
      as.character(defaults$study_contract$source_registry_hash_value),
      source_hash
    ) &&
    as.integer(defaults$study_contract$budget$mcmc_n_burn) == 2000L &&
    as.integer(defaults$study_contract$budget$mcmc_n_mcmc) == 8000L &&
    as.integer(defaults$pipeline$inference$mcmc$progress_every) == 50L &&
    isTRUE(defaults$multiseed$enabled) &&
    as.integer(defaults$multiseed$mcmc_seed_reps) == 2L &&
    !isTRUE(defaults$pipeline$outputs$keep_draws) &&
    !isTRUE(defaults$pipeline$outputs$save_forecast_objects) &&
    !isTRUE(defaults$pipeline$outputs$retain_full_rds_on_failure)
  if (!view_ok) {
    stop(sprintf("Launch contract failed for %s.", view_id), call. = FALSE)
  }

  profile_id <- as.character(col_or(
    targets,
    c("screening_profile_id.x", "screening_profile_id.y", "screening_profile_id"),
    "screening_profile_id"
  ))
  smoke_profile <- as.character(
    unlist(defaults$smoke$screening_profile_ids, use.names = FALSE)
  )[[1L]]
  smoke_index <- which(profile_id == smoke_profile)
  if (length(smoke_index) != 1L) {
    stop(sprintf("Could not resolve one smoke spec for %s.", view_id), call. = FALSE)
  }

  view_contracts[[view_id]] <- list(
    origin = origin,
    stage = stage,
    defaults_path = defaults_path,
    grid_path = grid_path,
    target_specs_path = target_specs_path,
    spec_ids = spec_id,
    smoke_spec_id = spec_id[[smoke_index]],
    max_p_over_n = max(p_over_n)
  )
}

heavy <- system(
  sprintf(
    "find %s -type f \\( -name '*.rds' -o -name '*.rda' -o -name '*.RData' -o -name '__design.rds' \\) -print",
    shQuote(normalizePath(promotion_root, winslash = "/", mustWork = TRUE))
  ),
  intern = TRUE
)
if (length(heavy)) {
  stop("Forbidden heavy payload found in the tracked campaign design root.", call. = FALSE)
}

runner_args <- function(view, view_workers) {
  c(
    "scripts/run_qdesn_dynamic_exdqlm_crossstudy_validation.R",
    "--defaults", view$defaults_path,
    "--grid", view$grid_path,
    "--methods", "mcmc",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "rhs_ns",
    "--scheduler", "load_balanced",
    "--allow-grid-subset",
    "--workers", as.character(view_workers),
    "--no-plots"
  )
}

if (!skip_prepare) {
  for (view_id in names(view_contracts)) {
    view <- view_contracts[[view_id]]
    prepare_tag <- sprintf(
      "qdesn-500obs-mcmc-nested-v1-%s-prepare-%s__git-%s",
      view_id,
      stamp,
      git_short
    )
    steps[[length(steps) + 1L]] <- run_step(
      paste0("10_prepare_", view_id),
      "Rscript",
      c(
        runner_args(view, workers_per_view),
        "--batch", "full",
        "--run-tag", prepare_tag,
        "--spec-ids", paste(view$spec_ids, collapse = ","),
        "--prepare-only"
      )
    )
  }
}

if (run_smoke) {
  for (view_id in names(view_contracts)) {
    view <- view_contracts[[view_id]]
    smoke_tag <- sprintf(
      "qdesn-500obs-mcmc-nested-v1-%s-smoke-%s__git-%s",
      view_id,
      stamp,
      git_short
    )
    steps[[length(steps) + 1L]] <- run_step(
      paste0("20_smoke_", view_id),
      "Rscript",
      c(
        runner_args(view, 1L),
        "--batch", "smoke",
        "--run-tag", smoke_tag,
        "--spec-ids", view$smoke_spec_id,
        "--stream-child-stdout"
      )
    )
  }
}

full_launches <- list()
if (full) {
  if (worktree_dirty()) {
    stop(
      paste(
        "Full nested-cellwise v1 launch requires a clean committed worktree.",
        "Commit the validated campaign files, then rerun with",
        "--skip-materialize --skip-prepare --skip-smoke."
      ),
      call. = FALSE
    )
  }
  for (view_id in names(view_contracts)) {
    view <- view_contracts[[view_id]]
    run_tag <- sprintf(
      "qdesn-500obs-mcmc-nested-v1-%s-full-%s__git-%s",
      view_id,
      format(Sys.Date(), "%Y%m%d"),
      git_short
    )
    tmux_session <- sprintf(
      "qdesn_500obs_nested_v1_%s_%s",
      sub("origin", "o", view_id, fixed = TRUE),
      format(Sys.time(), "%Y%m%d_%H%M%S")
    )
    full_launches[[view_id]] <- run_step(
      paste0("30_full_detached_", view_id),
      "Rscript",
      c(
        "scripts/launch_qdesn_dynamic_exdqlm_crossstudy_validation.R",
        runner_args(view, workers_per_view)[-1L],
        "--batch", "full",
        "--run-tag", run_tag,
        "--spec-ids", paste(view$spec_ids, collapse = ","),
        "--stream-child-stdout",
        "--tmux-session", tmux_session
      )
    )
    full_launches[[view_id]]$run_tag <- run_tag
    full_launches[[view_id]]$tmux_session <- tmux_session
  }
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestration_tag = orchestration_tag,
  orchestration_root = normalizePath(orchestration_root, winslash = "/", mustWork = TRUE),
  stage_base = stage_base,
  git_branch = git_branch,
  git_commit = git_commit,
  git_dirty = worktree_dirty(),
  source_registry_hash_value = source_hash,
  workers_total_cap = workers,
  workers_per_view = workers_per_view,
  target_cells = 15L,
  calibration_origins = as.list(origins),
  selected_roots_total = sum(vapply(view_contracts, function(x) length(x$spec_ids), integer(1L))),
  mcmc_seed_reps = 2L,
  planned_chain_fits = 1440L,
  mcmc_n_burn = 2000L,
  mcmc_n_mcmc = 8000L,
  prepare_requested = !skip_prepare,
  smoke_requested = run_smoke,
  full_requested = full,
  launch_approved = launch_approved,
  article_update_policy = "no raw discovery result is article-facing",
  view_contracts = lapply(view_contracts, function(x) {
    x$spec_ids <- NULL
    x
  }),
  steps = steps,
  full_launches = full_launches
)
manifest_path <- file.path(
  orchestration_root,
  "manifest",
  "qdesn_500obs_mcmc_nested_cellwise_v1_orchestration.json"
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
cat("selected_roots_total: 720\n")
cat("planned_chain_fits: 1440\n")
cat(sprintf("workers: %d (%d per view)\n", workers, workers_per_view))
if (length(full_launches)) {
  for (view_id in names(full_launches)) {
    cat(sprintf(
      "%s: run_tag=%s tmux=%s\n",
      view_id,
      full_launches[[view_id]]$run_tag,
      full_launches[[view_id]]$tmux_session
    ))
  }
}
