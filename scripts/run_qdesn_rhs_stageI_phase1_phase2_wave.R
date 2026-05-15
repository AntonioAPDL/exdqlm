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

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
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

count_contains <- function(x, token) {
  x <- as.character(x %||% character(0))
  sum(grepl(token, x, fixed = TRUE), na.rm = TRUE)
}

max_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else max(x)
}

min_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else min(x)
}

median_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else stats::median(x)
}

grade_worst <- function(x) {
  g <- toupper(trimws(as.character(x %||% "")))
  if (any(g == "FAIL", na.rm = TRUE)) return("FAIL")
  if (any(g == "WARN", na.rm = TRUE)) return("WARN")
  if (any(g == "PASS", na.rm = TRUE)) return("PASS")
  NA_character_
}

worst_reason <- function(df) {
  if (!nrow(df)) return(NA_character_)
  g <- toupper(as.character(df$signoff_grade %||% ""))
  if (any(g == "FAIL", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "FAIL"][1L] %||% NA_character_))
  }
  if (any(g == "WARN", na.rm = TRUE)) {
    return(as.character(df$signoff_reason[g == "WARN"][1L] %||% NA_character_))
  }
  as.character(df$signoff_reason[1L] %||% NA_character_)
}

find_latest_completed_campaign <- function(parent_report_root) {
  if (!dir.exists(parent_report_root)) return(NULL)
  run_dirs <- sort(list.dirs(parent_report_root, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
  if (!length(run_dirs)) return(NULL)
  for (run_dir in run_dirs) {
    done_path <- file.path(run_dir, "manifest", "campaign_completed.json")
    pair_path <- file.path(run_dir, "tables", "campaign_pair_summary.csv")
    if (!file.exists(done_path) || !file.exists(pair_path)) next
    done <- tryCatch(jsonlite::fromJSON(done_path), error = function(...) NULL)
    mani <- tryCatch(jsonlite::fromJSON(file.path(run_dir, "manifest", "campaign_manifest.json")), error = function(...) NULL)
    results_root <- as.character(done$results_root %||% mani$results_root %||% NA_character_)[1L]
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

extract_profile_summary <- function(phase_id, profile_id, description, report_root, results_root) {
  pair_df <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
  method_df <- read_csv_safe(file.path(report_root, "tables", "campaign_method_signoff.csv"))
  mcmc_df <- method_df[as.character(method_df$method) == "mcmc", , drop = FALSE]

  n_pairs <- nrow(pair_df)
  n_pair_pass <- sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "PASS", na.rm = TRUE)
  n_pair_warn <- sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "WARN", na.rm = TRUE)
  n_pair_fail <- sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "FAIL", na.rm = TRUE)
  n_pair_eligible <- sum(as.logical(pair_df$pair_comparison_eligible %||% FALSE), na.rm = TRUE)
  all_finite_ok <- if (n_pairs) all(as.logical(pair_df$both_finite_ok %||% FALSE), na.rm = TRUE) else FALSE
  all_domain_ok <- if (n_pairs) all(as.logical(pair_df$both_domain_ok %||% FALSE), na.rm = TRUE) else FALSE
  all_finite_domain_ok <- isTRUE(all_finite_ok) && isTRUE(all_domain_ok)

  n_trace_unavail_signoff <- count_contains(pair_df$mcmc_signoff_reason, "rhs_trace_unavailable")
  n_trace_unavail_unhealthy <- count_contains(pair_df$mcmc_unhealthy_reason, "rhs_trace_unavailable")
  n_trace_unavailable_total <- n_trace_unavail_signoff + n_trace_unavail_unhealthy

  out <- data.frame(
    phase_id = phase_id,
    profile_id = profile_id,
    description = description,
    n_pairs = n_pairs,
    n_pair_pass = n_pair_pass,
    n_pair_warn = n_pair_warn,
    n_pair_fail = n_pair_fail,
    n_pair_eligible = n_pair_eligible,
    all_finite_ok = isTRUE(all_finite_ok),
    all_domain_ok = isTRUE(all_domain_ok),
    all_finite_domain_ok = isTRUE(all_finite_domain_ok),
    mcmc_signoff_pass = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "PASS", na.rm = TRUE),
    mcmc_signoff_warn = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "WARN", na.rm = TRUE),
    mcmc_signoff_fail = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "FAIL", na.rm = TRUE),
    mcmc_signoff_grade_worst = grade_worst(mcmc_df$signoff_grade),
    mcmc_signoff_reason_worst = worst_reason(mcmc_df),
    mcmc_min_ess_rhs_min = min_or_na(mcmc_df$mcmc_min_ess_rhs),
    mcmc_max_geweke_absz_rhs_max = max_or_na(mcmc_df$mcmc_max_geweke_absz_rhs),
    mcmc_max_half_drift_rhs_max = max_or_na(mcmc_df$mcmc_max_half_drift_rhs),
    runtime_ratio_median = median_or_na(pair_df$runtime_ratio_mcmc_vs_vb),
    mcmc_fit_runtime_seconds_mean = mean(as.numeric(pair_df$mcmc_fit_runtime_seconds), na.rm = TRUE),
    n_trace_unavailable_mcmc_signoff = n_trace_unavail_signoff,
    n_trace_unavailable_mcmc_unhealthy = n_trace_unavail_unhealthy,
    n_trace_unavailable_total = n_trace_unavailable_total,
    report_root = report_root,
    results_root = results_root,
    stringsAsFactors = FALSE
  )
  out$mcmc_fit_runtime_seconds_mean <- safe_num(out$mcmc_fit_runtime_seconds_mean, NA_real_)
  out
}

choose_winner <- function(gated_df, baseline_profile_id = NULL) {
  if (!nrow(gated_df)) stop("Cannot choose winner from empty table.", call. = FALSE)
  candidates <- gated_df[as.logical(gated_df$gate_pass), , drop = FALSE]
  if (nrow(candidates) == 0L) {
    candidates <- gated_df
  }

  ord <- with(candidates, order(
    as.numeric(n_pair_fail),
    as.numeric(mcmc_signoff_fail),
    !as.logical(gate_all_eligible),
    !as.logical(gate_finite_domain),
    as.numeric(mcmc_max_geweke_absz_rhs_max),
    as.numeric(mcmc_max_half_drift_rhs_max),
    -as.numeric(mcmc_min_ess_rhs_min),
    as.numeric(runtime_ratio_median),
    as.character(profile_id)
  ))
  candidates[ord[1L], , drop = FALSE]
}

run_profile_set <- function(phase_id, profiles_cfg, stage_base_defaults, grid_path, analysis_root, results_root, report_root, create_plots, verbose, resume_mode = TRUE) {
  profiles <- profiles_cfg$profiles %||% list()
  if (!length(profiles)) {
    stop(sprintf("Phase '%s' has no profiles.", phase_id), call. = FALSE)
  }

  base_patch <- profiles_cfg$base_patch %||% list()
  phase_base_defaults <- deep_merge(stage_base_defaults, base_patch)
  defaults_map <- list()
  run_map <- list()
  rows <- list()

  for (ii in seq_along(profiles)) {
    prof <- profiles[[ii]]
    prof_id <- as.character(prof$id %||% sprintf("%s_%02d", phase_id, ii))
    prof_desc <- as.character(prof$description %||% prof_id)
    cfg_i <- deep_merge(phase_base_defaults, prof$patch %||% list())
    cfg_i$campaign <- cfg_i$campaign %||% list()
    cfg_i$campaign$name <- paste0("qdesn_rhs_", phase_id, "__", prof_id)
    cfg_i$campaign$results_root <- file.path(results_root, phase_id, prof_id)
    cfg_i$campaign$reports_root <- file.path(report_root, phase_id, prof_id)

    defaults_i <- file.path(analysis_root, "config", sprintf("%s_defaults_%s.yaml", phase_id, prof_id))
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
      phase_id = phase_id,
      profile_id = prof_id,
      description = prof_desc,
      report_root = run_i$report_root,
      results_root = run_i$results_root
    )
    rows[[length(rows) + 1L]] <- row_i
    defaults_map[[prof_id]] <- cfg_i
    run_map[[prof_id]] <- run_i
  }

  list(
    phase_id = phase_id,
    summary = do.call(rbind, rows),
    defaults_map = defaults_map,
    run_map = run_map
  )
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageI_manifest.yaml")),
  must_work = TRUE
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume_mode <- !has_flag("--no-resume")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageI-", stamp, "__git-", git_sha)))[1L]

report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageI_phase1_phase2_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageI_phase1_phase2_wave", run_tag)),
  must_work = FALSE
)
analysis_root <- report_root

for (d in c(analysis_root, file.path(analysis_root, "tables"), file.path(analysis_root, "config"), file.path(analysis_root, "manifest"))) {
  dir_create(d)
}
dir_create(results_root)

manifest <- yaml::read_yaml(manifest_path)
inputs <- manifest$inputs %||% list()
outputs <- manifest$outputs %||% list()
phase1_cfg <- manifest$phase1 %||% list()
phase2_cfg <- manifest$phase2 %||% list()

base_defaults_path <- resolve_path(inputs$base_defaults, must_work = TRUE)
blocker_grid_path <- resolve_path(inputs$blocker_grid, must_work = TRUE)
phase1_profiles_path <- resolve_path(phase1_cfg$profiles, must_work = TRUE)
phase2_profiles_path <- resolve_path(phase2_cfg$profiles, must_work = TRUE)
tracker_doc_path <- resolve_path(outputs$tracker_doc, must_work = FALSE)
promotion_defaults_path <- resolve_path(outputs$promotion_defaults, must_work = FALSE)
stageh_analysis_root <- resolve_path(inputs$stageh_analysis_root, must_work = FALSE)

base_defaults <- yaml::read_yaml(base_defaults_path)
baseline_defaults <- deep_merge(base_defaults, manifest$baseline_patch %||% list())
baseline_defaults_path <- file.path(analysis_root, "config", "stageI_baseline_defaults.yaml")
yaml::write_yaml(baseline_defaults, baseline_defaults_path)

baseline_ref <- list(
  frozen_at = as.character(Sys.time()),
  manifest_path = manifest_path,
  git_sha = git_sha,
  stageh_analysis_root = stageh_analysis_root
)
if (!is.null(stageh_analysis_root) && dir.exists(stageh_analysis_root)) {
  stageh_gate_path <- file.path(stageh_analysis_root, "manifest", "stageH_gate.json")
  stageh_pair_path <- file.path(stageh_analysis_root, "tables", "stageH_pair_summary.csv")
  baseline_ref$stageh_gate_path <- stageh_gate_path
  baseline_ref$stageh_pair_path <- stageh_pair_path
  if (file.exists(stageh_gate_path)) {
    baseline_ref$stageh_gate <- jsonlite::fromJSON(stageh_gate_path, simplifyVector = TRUE)
  }
  if (file.exists(stageh_pair_path)) {
    stageh_pair <- read_csv_safe(stageh_pair_path)
    utils::write.csv(stageh_pair, file.path(analysis_root, "tables", "step0_stageH_pair_summary_frozen.csv"), row.names = FALSE)
  }
}
jsonlite::write_json(
  baseline_ref,
  file.path(analysis_root, "manifest", "step0_baseline_reference.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

profiles1 <- yaml::read_yaml(phase1_profiles_path)
phase1 <- run_profile_set(
  phase_id = "phase1",
  profiles_cfg = profiles1,
  stage_base_defaults = baseline_defaults,
  grid_path = blocker_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)

phase1_gate <- exdqlm:::.qdesn_rhs_stagei_gate_eval(
  profile_df = phase1$summary,
  gate_cfg = phase1_cfg$strict_gate %||% list(),
  baseline_profile_id = as.character(phase1_cfg$baseline_profile_id %||% "P1_baseline")
)
utils::write.csv(phase1_gate, file.path(analysis_root, "tables", "phase1_profile_matrix.csv"), row.names = FALSE)
phase1_winner <- choose_winner(phase1_gate, baseline_profile_id = as.character(phase1_cfg$baseline_profile_id %||% "P1_baseline"))
phase1_pass <- any(as.logical(phase1_gate$gate_pass))
phase1_winner_id <- as.character(phase1_winner$profile_id[1L])
phase1_decision <- list(
  phase1_pass = isTRUE(phase1_pass),
  winner_profile_id = phase1_winner_id,
  winner_report_root = as.character(phase1_winner$report_root[1L]),
  generated_at = as.character(Sys.time())
)
jsonlite::write_json(
  phase1_decision,
  file.path(analysis_root, "manifest", "phase1_decision.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

profiles2 <- yaml::read_yaml(phase2_profiles_path)
phase2 <- run_profile_set(
  phase_id = "phase2",
  profiles_cfg = profiles2,
  stage_base_defaults = phase1$defaults_map[[phase1_winner_id]],
  grid_path = blocker_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = report_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)

phase2_gate <- exdqlm:::.qdesn_rhs_stagei_gate_eval(
  profile_df = phase2$summary,
  gate_cfg = phase2_cfg$strict_gate %||% list(),
  baseline_profile_id = as.character(phase2_cfg$baseline_profile_id %||% "P2_baseline_from_phase1")
)
utils::write.csv(phase2_gate, file.path(analysis_root, "tables", "phase2_profile_matrix.csv"), row.names = FALSE)
phase2_winner <- choose_winner(phase2_gate, baseline_profile_id = as.character(phase2_cfg$baseline_profile_id %||% "P2_baseline_from_phase1"))
phase2_pass <- any(as.logical(phase2_gate$gate_pass))
phase2_winner_id <- as.character(phase2_winner$profile_id[1L])
phase2_decision <- list(
  phase2_pass = isTRUE(phase2_pass),
  winner_profile_id = phase2_winner_id,
  winner_report_root = as.character(phase2_winner$report_root[1L]),
  generated_at = as.character(Sys.time())
)
jsonlite::write_json(
  phase2_decision,
  file.path(analysis_root, "manifest", "phase2_decision.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

promotion_written <- FALSE
if (isTRUE(phase2_pass)) {
  promoted <- phase2$defaults_map[[phase2_winner_id]]
  promoted$campaign <- promoted$campaign %||% list()
  promoted$campaign$name <- "qdesn_mcmc_rhs_stageI_candidate"
  promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_stageI_candidate")
  promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_stageI_candidate")
  dir_create(dirname(promotion_defaults_path))
  yaml::write_yaml(promoted, promotion_defaults_path)
  promotion_written <- TRUE
}

tracker_lines <- c(
  "# TRACK: QDESN RHS Stage-I (Phase1/Phase2) Wave",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- analysis_root: `%s`", analysis_root),
  sprintf("- baseline_defaults: `%s`", baseline_defaults_path),
  sprintf("- phase1_pass: `%s`", if (isTRUE(phase1_pass)) "true" else "false"),
  sprintf("- phase1_winner: `%s`", phase1_winner_id),
  sprintf("- phase2_pass: `%s`", if (isTRUE(phase2_pass)) "true" else "false"),
  sprintf("- phase2_winner: `%s`", phase2_winner_id),
  sprintf("- promotion_written: `%s`", if (isTRUE(promotion_written)) "true" else "false"),
  sprintf("- promotion_defaults: `%s`", if (isTRUE(promotion_written)) promotion_defaults_path else "none"),
  "",
  "## Phase1 Profile Matrix",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(phase1_gate))
tracker_lines <- c(tracker_lines, "", "## Phase2 Profile Matrix", "")
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(phase2_gate))
dir_create(dirname(tracker_doc_path))
writeLines(tracker_lines, tracker_doc_path)

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    manifest_path = manifest_path,
    phase1 = phase1_decision,
    phase2 = phase2_decision,
    promotion_written = promotion_written,
    promotion_defaults_path = if (isTRUE(promotion_written)) promotion_defaults_path else NULL,
    tracker_doc_path = tracker_doc_path
  ),
  file.path(analysis_root, "manifest", "stageI_phase1_phase2_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Phase1 pass: %s\n", if (isTRUE(phase1_pass)) "yes" else "no"))
cat(sprintf("Phase2 pass: %s\n", if (isTRUE(phase2_pass)) "yes" else "no"))
cat(sprintf("Promotion written: %s\n", if (isTRUE(promotion_written)) "yes" else "no"))
