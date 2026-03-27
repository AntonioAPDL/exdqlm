#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  if (is.null(path)) return(NULL)
  raw <- as.character(path)[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

dir_create <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

deep_merge <- function(x, y) {
  if (!is.list(x) || !is.list(y)) return(y)
  out <- x
  for (nm in names(y)) {
    if (is.list(out[[nm]]) && is.list(y[[nm]])) {
      out[[nm]] <- deep_merge(out[[nm]], y[[nm]])
    } else {
      out[[nm]] <- y[[nm]]
    }
  }
  out
}

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
}

count_contains <- function(x, token) {
  x <- as.character(x %||% character(0))
  sum(grepl(token, x, fixed = TRUE), na.rm = TRUE)
}

grade_score <- function(x) {
  x <- toupper(trimws(as.character(x %||% "")))
  out <- rep(NA_real_, length(x))
  out[x == "PASS"] <- 2
  out[x == "WARN"] <- 1
  out[x == "FAIL"] <- 0
  out
}

summarize_pair <- function(pair_df) {
  if (!nrow(pair_df)) {
    return(data.frame(
      n_pairs = 0L,
      n_pair_pass = 0L,
      n_pair_warn = 0L,
      n_pair_fail = 0L,
      n_pair_eligible = 0L,
      runtime_ratio_median = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    n_pairs = nrow(pair_df),
    n_pair_pass = sum(as.character(pair_df$pair_signoff_grade) == "PASS", na.rm = TRUE),
    n_pair_warn = sum(as.character(pair_df$pair_signoff_grade) == "WARN", na.rm = TRUE),
    n_pair_fail = sum(as.character(pair_df$pair_signoff_grade) == "FAIL", na.rm = TRUE),
    n_pair_eligible = sum(as.logical(pair_df$pair_comparison_eligible), na.rm = TRUE),
    runtime_ratio_median = suppressWarnings(stats::median(as.numeric(pair_df$runtime_ratio_mcmc_vs_vb), na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
}

extract_profile_summary <- function(profile_id, description, report_root, results_root) {
  pair_df <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
  method_df <- read_csv_safe(file.path(report_root, "tables", "campaign_method_signoff.csv"))
  mcmc_df <- method_df[as.character(method_df$method) == "mcmc", , drop = FALSE]
  pair_summary <- summarize_pair(pair_df)

  mcmc_grade_score <- grade_score(mcmc_df$signoff_grade)
  mcmc_grade_worst <- if (length(mcmc_grade_score) && any(is.finite(mcmc_grade_score))) {
    if (any(mcmc_grade_score == 0, na.rm = TRUE)) "FAIL"
    else if (any(mcmc_grade_score == 1, na.rm = TRUE)) "WARN"
    else if (any(mcmc_grade_score == 2, na.rm = TRUE)) "PASS"
    else NA_character_
  } else {
    NA_character_
  }
  mcmc_reason_worst <- {
    if (!nrow(mcmc_df)) {
      NA_character_
    } else if (any(toupper(as.character(mcmc_df$signoff_grade)) == "FAIL", na.rm = TRUE)) {
      as.character(mcmc_df$signoff_reason[toupper(as.character(mcmc_df$signoff_grade)) == "FAIL"][1L])
    } else if (any(toupper(as.character(mcmc_df$signoff_grade)) == "WARN", na.rm = TRUE)) {
      as.character(mcmc_df$signoff_reason[toupper(as.character(mcmc_df$signoff_grade)) == "WARN"][1L])
    } else {
      as.character(mcmc_df$signoff_reason[1L])
    }
  }

  out <- pair_summary
  out$profile_id <- profile_id
  out$description <- description
  out$mcmc_signoff_pass <- sum(toupper(as.character(mcmc_df$signoff_grade)) == "PASS", na.rm = TRUE)
  out$mcmc_signoff_warn <- sum(toupper(as.character(mcmc_df$signoff_grade)) == "WARN", na.rm = TRUE)
  out$mcmc_signoff_fail <- sum(toupper(as.character(mcmc_df$signoff_grade)) == "FAIL", na.rm = TRUE)
  out$mcmc_signoff_score_sum <- sum(mcmc_grade_score, na.rm = TRUE)
  out$mcmc_signoff_grade_worst <- mcmc_grade_worst
  out$mcmc_signoff_reason_worst <- mcmc_reason_worst
  out$mcmc_fit_runtime_seconds_mean <- suppressWarnings(mean(as.numeric(pair_df$mcmc_fit_runtime_seconds), na.rm = TRUE))
  out$n_trace_unavailable_mcmc_signoff <- count_contains(pair_df$mcmc_signoff_reason, "rhs_trace_unavailable")
  out$n_trace_unavailable_mcmc_unhealthy <- count_contains(pair_df$mcmc_unhealthy_reason, "rhs_trace_unavailable")
  out$report_root <- report_root
  out$results_root <- results_root
  out
}

choose_winner <- function(summary_df) {
  if (!nrow(summary_df)) stop("No profile runs available for winner selection.", call. = FALSE)
  trace_total <- as.numeric(summary_df$n_trace_unavailable_mcmc_signoff) +
    as.numeric(summary_df$n_trace_unavailable_mcmc_unhealthy)
  score <- as.numeric(summary_df$mcmc_signoff_score_sum)
  ord <- order(
    as.numeric(summary_df$n_pair_fail),
    trace_total,
    as.numeric(summary_df$n_pair_warn),
    -as.numeric(summary_df$n_pair_eligible),
    -score,
    as.numeric(summary_df$runtime_ratio_median),
    as.numeric(summary_df$mcmc_fit_runtime_seconds_mean),
    as.character(summary_df$profile_id)
  )
  summary_df[ord[1L], , drop = FALSE]
}

write_stage_artifacts <- function(stage_id, stage_desc, stage_summary, stage_winner, analysis_root) {
  table_path <- file.path(analysis_root, "tables", sprintf("stage%s_profiles_summary.csv", stage_id))
  utils::write.csv(stage_summary, table_path, row.names = FALSE)
  jsonlite::write_json(
    list(
      stage_id = stage_id,
      stage_description = stage_desc,
      winner_profile_id = as.character(stage_winner$profile_id[1L]),
      winner = stage_winner,
      generated_at = as.character(Sys.time())
    ),
    file.path(analysis_root, "manifest", sprintf("stage%s_winner.json", stage_id)),
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
}

find_latest_completed_campaign <- function(parent_report_root) {
  if (!dir.exists(parent_report_root)) return(NULL)
  run_dirs <- sort(list.dirs(parent_report_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  if (!length(run_dirs)) return(NULL)

  for (run_dir in run_dirs) {
    completed_path <- file.path(run_dir, "manifest", "campaign_completed.json")
    pair_path <- file.path(run_dir, "tables", "campaign_pair_summary.csv")
    if (!file.exists(completed_path) || !file.exists(pair_path)) next

    completed <- tryCatch(jsonlite::fromJSON(completed_path), error = function(...) NULL)
    manifest <- tryCatch(jsonlite::fromJSON(file.path(run_dir, "manifest", "campaign_manifest.json")), error = function(...) NULL)
    results_root <- as.character(completed$results_root %||% manifest$results_root %||% NA_character_)[1L]
    if (is.na(results_root) || !nzchar(trimws(results_root))) {
      results_root <- NA_character_
    } else {
      results_root <- normalizePath(results_root, winslash = "/", mustWork = FALSE)
    }

    return(list(
      report_root = normalizePath(run_dir, winslash = "/", mustWork = TRUE),
      results_root = results_root,
      resumed = TRUE
    ))
  }

  NULL
}

run_or_resume_campaign <- function(grid_path, defaults_path, results_root, report_root, create_plots, verbose, resume_mode = TRUE) {
  if (isTRUE(resume_mode)) {
    existing <- find_latest_completed_campaign(report_root)
    if (!is.null(existing)) {
      if (isTRUE(verbose)) {
        message(sprintf("[resume] reusing completed campaign: %s", existing$report_root))
      }
      return(existing)
    }
  }

  run <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = grid_path,
    defaults_path = defaults_path,
    results_root = results_root,
    report_root = report_root,
    create_plots = create_plots,
    verbose = verbose
  )
  list(
    report_root = run$report_root,
    results_root = run$results_root,
    resumed = FALSE
  )
}

run_stage <- function(stage_id, stage_cfg, stage_base_defaults, grid_path, analysis_root, results_root, report_root, create_plots, verbose, resume_mode = TRUE) {
  profiles <- stage_cfg$profiles %||% list()
  if (!length(profiles)) {
    stop(sprintf("Stage %s has no profiles.", stage_id), call. = FALSE)
  }

  rows <- list()
  cfg_map <- list()
  run_map <- list()
  for (ii in seq_along(profiles)) {
    prof <- profiles[[ii]]
    prof_id <- as.character(prof$id %||% sprintf("%s_%02d", stage_id, ii))
    prof_desc <- as.character(prof$description %||% prof_id)
    cfg_i <- deep_merge(stage_base_defaults, prof$patch %||% list())
    cfg_i$campaign <- cfg_i$campaign %||% list()
    cfg_i$campaign$name <- paste0("qdesn_mcmc_rhs_drift_rescue_stage", stage_id, "__", prof_id)
    cfg_i$campaign$results_root <- file.path(results_root, paste0("stage", stage_id), prof_id)
    cfg_i$campaign$reports_root <- file.path(report_root, paste0("stage", stage_id), prof_id)

    defaults_i <- file.path(analysis_root, "config", sprintf("stage%s_defaults_%s.yaml", stage_id, prof_id))
    yaml::write_yaml(cfg_i, defaults_i)

    run_i <- run_or_resume_campaign(
      grid_path = grid_path,
      defaults_path = defaults_i,
      results_root = cfg_i$campaign$results_root,
      report_root = cfg_i$campaign$reports_root,
      create_plots = create_plots,
      verbose = verbose,
      resume_mode = resume_mode
    )
    row_i <- extract_profile_summary(
      profile_id = prof_id,
      description = prof_desc,
      report_root = run_i$report_root,
      results_root = run_i$results_root
    )
    row_i$stage_id <- stage_id
    rows[[length(rows) + 1L]] <- row_i
    cfg_map[[prof_id]] <- cfg_i
    run_map[[prof_id]] <- run_i
  }

  stage_summary <- do.call(rbind, rows)
  stage_summary <- stage_summary[, c(
    "stage_id", "profile_id", "description",
    "n_pairs", "n_pair_pass", "n_pair_warn", "n_pair_fail", "n_pair_eligible",
    "mcmc_signoff_pass", "mcmc_signoff_warn", "mcmc_signoff_fail",
    "mcmc_signoff_score_sum", "mcmc_signoff_grade_worst", "mcmc_signoff_reason_worst",
    "runtime_ratio_median", "mcmc_fit_runtime_seconds_mean",
    "n_trace_unavailable_mcmc_signoff", "n_trace_unavailable_mcmc_unhealthy",
    "report_root", "results_root"
  ), drop = FALSE]
  winner <- choose_winner(stage_summary)
  write_stage_artifacts(
    stage_id = stage_id,
    stage_desc = as.character(stage_cfg$description %||% ""),
    stage_summary = stage_summary,
    stage_winner = winner,
    analysis_root = analysis_root
  )

  winner_id <- as.character(winner$profile_id[1L])
  list(
    stage_id = stage_id,
    summary = stage_summary,
    winner = winner,
    winner_id = winner_id,
    winner_defaults = cfg_map[[winner_id]],
    winner_run = run_map[[winner_id]]
  )
}

build_replicate_grid <- function(failing_grid_df, seeds, out_path) {
  seeds <- as.integer(unlist(seeds, use.names = FALSE))
  seeds <- unique(seeds[is.finite(seeds)])
  if (!length(seeds)) stop("Replicate stage requires at least one finite seed.", call. = FALSE)
  rows <- vector("list", nrow(failing_grid_df) * length(seeds))
  kk <- 0L
  for (i in seq_len(nrow(failing_grid_df))) {
    for (sd in seeds) {
      kk <- kk + 1L
      rr <- failing_grid_df[i, , drop = FALSE]
      rr$seed <- as.integer(sd)
      rr$enabled <- TRUE
      rows[[kk]] <- rr
    }
  }
  out <- do.call(rbind, rows)
  utils::write.csv(out, out_path, row.names = FALSE)
  out
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_drift_rescue_wave.yaml")),
  must_work = TRUE
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume_mode <- !has_flag("--no-resume")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0(stamp, "__git-", git_sha)))[1L]

report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_drift_rescue_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_drift_rescue_wave", run_tag)),
  must_work = FALSE
)
analysis_root <- report_root

for (d in c(
  analysis_root,
  file.path(analysis_root, "tables"),
  file.path(analysis_root, "config"),
  file.path(analysis_root, "manifest")
)) {
  dir_create(d)
}
dir_create(results_root)

wave_cfg <- yaml::read_yaml(manifest_path)
inputs <- wave_cfg$inputs %||% list()
outputs <- wave_cfg$outputs %||% list()
stages_cfg <- wave_cfg$stages %||% list()
gates_cfg <- wave_cfg$gates %||% list()
replicate_cfg <- wave_cfg$replicate %||% list()

base_defaults_path <- resolve_path(inputs$base_defaults, must_work = TRUE)
failing_grid_path <- resolve_path(inputs$failing_root_grid, must_work = TRUE)
broader_grid_path <- resolve_path(inputs$broader_grid, must_work = TRUE)
promotion_defaults_path <- resolve_path(outputs$promotion_defaults %||% file.path("config", "validation", "qdesn_mcmc_compare_rhs_drift_rescue_candidate.yaml"), must_work = FALSE)

base_defaults <- yaml::read_yaml(base_defaults_path)
baseline_defaults <- deep_merge(base_defaults, wave_cfg$baseline_patch %||% list())
baseline_defaults$campaign <- baseline_defaults$campaign %||% list()
baseline_defaults$campaign$name <- "qdesn_mcmc_rhs_drift_rescue_baseline"
baseline_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_drift_rescue_baseline")
baseline_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_drift_rescue_baseline")
baseline_defaults_path <- file.path(analysis_root, "config", "baseline_defaults.yaml")
yaml::write_yaml(baseline_defaults, baseline_defaults_path)

failing_grid <- read_csv_safe(failing_grid_path)
if (!nrow(failing_grid)) stop("Failing-root grid is empty.", call. = FALSE)
if (!("seed" %in% names(failing_grid))) stop("Failing-root grid must contain a 'seed' column.", call. = FALSE)

stage_A <- run_stage(
  stage_id = "A",
  stage_cfg = stages_cfg$A %||% list(),
  stage_base_defaults = baseline_defaults,
  grid_path = failing_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
stage_B <- run_stage(
  stage_id = "B",
  stage_cfg = stages_cfg$B %||% list(),
  stage_base_defaults = stage_A$winner_defaults,
  grid_path = failing_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
stage_C <- run_stage(
  stage_id = "C",
  stage_cfg = stages_cfg$C %||% list(),
  stage_base_defaults = stage_B$winner_defaults,
  grid_path = failing_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)

# Stage D: seed-replicate robustness
replicate_grid_path <- file.path(analysis_root, "config", "stageD_replicate_grid.csv")
replicate_grid <- build_replicate_grid(failing_grid, replicate_cfg$seeds %||% c(123L, 231L, 321L), replicate_grid_path)
stageD_defaults <- stage_C$winner_defaults
stageD_defaults$campaign <- stageD_defaults$campaign %||% list()
stageD_defaults$campaign$name <- "qdesn_mcmc_rhs_drift_rescue_stageD_replicates"
stageD_defaults$campaign$results_root <- file.path(results_root, "stageD_replicates")
stageD_defaults$campaign$reports_root <- file.path(report_root, "stageD_replicates")
stageD_defaults_path <- file.path(analysis_root, "config", "stageD_defaults.yaml")
yaml::write_yaml(stageD_defaults, stageD_defaults_path)
run_stageD <- run_or_resume_campaign(
  grid_path = replicate_grid_path,
  defaults_path = stageD_defaults_path,
  results_root = stageD_defaults$campaign$results_root,
  report_root = stageD_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
stageD_pair <- read_csv_safe(file.path(run_stageD$report_root, "tables", "campaign_pair_summary.csv"))
stageD_method <- read_csv_safe(file.path(run_stageD$report_root, "tables", "campaign_method_signoff.csv"))
stageD_summary <- summarize_pair(stageD_pair)
stageD_summary$stage_id <- "D"
stageD_summary$profile_id <- paste0("D__", stage_C$winner_id)
stageD_summary$description <- "Seed replicates on failing root"
stageD_summary$mcmc_signoff_fail <- sum(
  toupper(as.character(stageD_method$signoff_grade[as.character(stageD_method$method) == "mcmc"])) == "FAIL",
  na.rm = TRUE
)
stageD_summary$n_trace_unavailable_mcmc_signoff <- count_contains(stageD_pair$mcmc_signoff_reason, "rhs_trace_unavailable")
stageD_summary$n_trace_unavailable_mcmc_unhealthy <- count_contains(stageD_pair$mcmc_unhealthy_reason, "rhs_trace_unavailable")
stageD_summary$report_root <- run_stageD$report_root
stageD_summary$results_root <- run_stageD$results_root
utils::write.csv(stageD_summary, file.path(analysis_root, "tables", "stageD_replicate_summary.csv"), row.names = FALSE)
seed_summary <- stageD_pair[, intersect(
  c("root_id", "scenario", "tau", "seed", "pair_signoff_grade", "pair_comparison_eligible", "mcmc_signoff_reason"),
  names(stageD_pair)
), drop = FALSE]
utils::write.csv(seed_summary, file.path(analysis_root, "tables", "stageD_replicate_seed_summary.csv"), row.names = FALSE)

stageD_gate <- list(
  require_zero_fail = isTRUE(gates_cfg$require_zero_fail_stageD %||% TRUE),
  require_all_eligible = isTRUE(gates_cfg$require_all_eligible_stageD %||% TRUE),
  n_pairs = safe_num(stageD_summary$n_pairs, 0),
  n_pair_fail = safe_num(stageD_summary$n_pair_fail, 0),
  n_pair_eligible = safe_num(stageD_summary$n_pair_eligible, 0),
  pass = TRUE
)
if (isTRUE(stageD_gate$require_zero_fail) && stageD_gate$n_pair_fail > 0) stageD_gate$pass <- FALSE
if (isTRUE(stageD_gate$require_all_eligible) && stageD_gate$n_pair_eligible != stageD_gate$n_pairs) stageD_gate$pass <- FALSE

# Stage E: broader reconfirmation
stageE_defaults <- stage_C$winner_defaults
stageE_defaults$campaign <- stageE_defaults$campaign %||% list()
stageE_defaults$campaign$name <- "qdesn_mcmc_rhs_drift_rescue_stageE_broader"
stageE_defaults$campaign$results_root <- file.path(results_root, "stageE_broader")
stageE_defaults$campaign$reports_root <- file.path(report_root, "stageE_broader")
stageE_defaults_path <- file.path(analysis_root, "config", "stageE_defaults.yaml")
yaml::write_yaml(stageE_defaults, stageE_defaults_path)
run_stageE <- run_or_resume_campaign(
  grid_path = broader_grid_path,
  defaults_path = stageE_defaults_path,
  results_root = stageE_defaults$campaign$results_root,
  report_root = stageE_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
stageE_pair <- read_csv_safe(file.path(run_stageE$report_root, "tables", "campaign_pair_summary.csv"))
stageE_method <- read_csv_safe(file.path(run_stageE$report_root, "tables", "campaign_method_signoff.csv"))
stageE_summary <- summarize_pair(stageE_pair)
stageE_summary$stage_id <- "E"
stageE_summary$profile_id <- paste0("E__", stage_C$winner_id)
stageE_summary$description <- "Broader 8-root reconfirmation"
stageE_summary$mcmc_signoff_fail <- sum(
  toupper(as.character(stageE_method$signoff_grade[as.character(stageE_method$method) == "mcmc"])) == "FAIL",
  na.rm = TRUE
)
stageE_summary$n_trace_unavailable_mcmc_signoff <- count_contains(stageE_pair$mcmc_signoff_reason, "rhs_trace_unavailable")
stageE_summary$n_trace_unavailable_mcmc_unhealthy <- count_contains(stageE_pair$mcmc_unhealthy_reason, "rhs_trace_unavailable")
stageE_summary$report_root <- run_stageE$report_root
stageE_summary$results_root <- run_stageE$results_root
utils::write.csv(stageE_summary, file.path(analysis_root, "tables", "stageE_broader_summary.csv"), row.names = FALSE)

stageE_gate <- list(
  require_zero_fail = isTRUE(gates_cfg$require_zero_fail_stageE %||% TRUE),
  require_all_eligible = isTRUE(gates_cfg$require_all_eligible_stageE %||% TRUE),
  require_zero_trace_unavailable = isTRUE(gates_cfg$require_zero_trace_unavailable_stageE %||% TRUE),
  n_pairs = safe_num(stageE_summary$n_pairs, 0),
  n_pair_fail = safe_num(stageE_summary$n_pair_fail, 0),
  n_pair_eligible = safe_num(stageE_summary$n_pair_eligible, 0),
  n_trace_unavailable_total = safe_num(stageE_summary$n_trace_unavailable_mcmc_signoff, 0) +
    safe_num(stageE_summary$n_trace_unavailable_mcmc_unhealthy, 0),
  pass = TRUE
)
if (isTRUE(stageE_gate$require_zero_fail) && stageE_gate$n_pair_fail > 0) stageE_gate$pass <- FALSE
if (isTRUE(stageE_gate$require_all_eligible) && stageE_gate$n_pair_eligible != stageE_gate$n_pairs) stageE_gate$pass <- FALSE
if (isTRUE(stageE_gate$require_zero_trace_unavailable) && stageE_gate$n_trace_unavailable_total > 0) stageE_gate$pass <- FALSE

promote <- isTRUE(stageD_gate$pass) && isTRUE(stageE_gate$pass)
promotion_written <- FALSE
if (isTRUE(promote)) {
  promoted <- stage_C$winner_defaults
  promoted$campaign <- promoted$campaign %||% list()
  promoted$campaign$name <- "qdesn_mcmc_rhs_drift_rescue_candidate"
  promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_drift_rescue_candidate")
  promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_drift_rescue_candidate")
  dir_create(dirname(promotion_defaults_path))
  yaml::write_yaml(promoted, promotion_defaults_path)
  promotion_written <- TRUE
}

decision <- list(
  promote = promote,
  promotion_written = promotion_written,
  winner_stageA = stage_A$winner_id,
  winner_stageB = stage_B$winner_id,
  winner_stageC = stage_C$winner_id,
  winner_report_root = stage_C$winner_run$report_root,
  stageD_gate = stageD_gate,
  stageE_gate = stageE_gate,
  promotion_defaults_path = if (promotion_written) promotion_defaults_path else NULL,
  generated_at = as.character(Sys.time()),
  git_sha = git_sha
)
jsonlite::write_json(
  decision,
  file.path(analysis_root, "manifest", "final_decision.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

summary_lines <- c(
  "# QDESN RHS Drift-Rescue Wave",
  "",
  sprintf("- Manifest: `%s`", manifest_path),
  sprintf("- Base defaults: `%s`", base_defaults_path),
  sprintf("- Failing grid: `%s`", failing_grid_path),
  sprintf("- Broader grid: `%s`", broader_grid_path),
  "",
  "## Stage A",
  ""
)
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(stage_A$summary))
summary_lines <- c(summary_lines, "", "## Stage B", "")
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(stage_B$summary))
summary_lines <- c(summary_lines, "", "## Stage C", "")
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(stage_C$summary))
summary_lines <- c(summary_lines, "", "## Stage D", "")
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageD_summary))
summary_lines <- c(summary_lines, "", "## Stage E", "")
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageE_summary))
summary_lines <- c(
  summary_lines,
  "",
  "## Decision",
  sprintf("- winner_stageA: `%s`", stage_A$winner_id),
  sprintf("- winner_stageB: `%s`", stage_B$winner_id),
  sprintf("- winner_stageC: `%s`", stage_C$winner_id),
  sprintf("- stageD_pass: `%s`", if (isTRUE(stageD_gate$pass)) "true" else "false"),
  sprintf("- stageE_pass: `%s`", if (isTRUE(stageE_gate$pass)) "true" else "false"),
  sprintf("- promote: `%s`", if (isTRUE(promote)) "true" else "false"),
  sprintf("- promotion_written: `%s`", if (isTRUE(promotion_written)) "true" else "false")
)
writeLines(summary_lines, file.path(analysis_root, "drift_rescue_summary.md"))

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    manifest_path = manifest_path,
    base_defaults_path = base_defaults_path,
    baseline_defaults_path = baseline_defaults_path,
    failing_grid_path = failing_grid_path,
    broader_grid_path = broader_grid_path,
    replicate_grid_path = replicate_grid_path,
    winners = list(
      stageA = stage_A$winner_id,
      stageB = stage_B$winner_id,
      stageC = stage_C$winner_id
    ),
    decision = decision
  ),
  file.path(analysis_root, "manifest", "drift_rescue_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Winner Stage A: %s\n", stage_A$winner_id))
cat(sprintf("Winner Stage B: %s\n", stage_B$winner_id))
cat(sprintf("Winner Stage C: %s\n", stage_C$winner_id))
cat(sprintf("Promote: %s\n", if (isTRUE(promote)) "yes" else "no"))
if (isTRUE(promotion_written)) {
  cat(sprintf("Promotion defaults: %s\n", promotion_defaults_path))
}
