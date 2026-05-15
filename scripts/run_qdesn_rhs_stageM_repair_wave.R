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

median_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else stats::median(x)
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

resolve_rhs_family_guardrail <- function(cfg) {
  beta_cfg <- cfg$pipeline$inference$vb$priors$beta %||% list()
  beta_prior_type <- tolower(as.character(beta_cfg$type %||% "rhs")[1L])
  rhs_key <- if (identical(beta_prior_type, "rhs_ns")) "rhs_ns" else "rhs"
  rhs_cfg <- beta_cfg[[rhs_key]] %||% beta_cfg$rhs %||% list()

  init_log_tau <- suppressWarnings(as.numeric(rhs_cfg$init_log_tau %||% NA_real_)[1L])
  if (!is.finite(init_log_tau)) {
    init_tau <- suppressWarnings(as.numeric(rhs_cfg$init_tau %||% NA_real_)[1L])
    if (is.finite(init_tau) && init_tau > 0) init_log_tau <- log(init_tau)
  }
  if (!is.finite(init_log_tau)) {
    init_tau2 <- suppressWarnings(as.numeric(rhs_cfg$init_tau2 %||% NA_real_)[1L])
    if (is.finite(init_tau2) && init_tau2 > 0) init_log_tau <- 0.5 * log(init_tau2)
  }
  if (!is.finite(init_log_tau)) init_log_tau <- 0.0

  list(beta_prior_type = beta_prior_type, rhs_key = rhs_key, init_log_tau = as.numeric(init_log_tau))
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

extract_campaign_summary <- function(stage_id, profile_id, description, report_root, results_root, gate_cfg) {
  pair_df <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
  method_df <- read_csv_safe(file.path(report_root, "tables", "campaign_method_signoff.csv"))
  mcmc_df <- method_df[as.character(method_df$method %||% "") == "mcmc", , drop = FALSE]
  gate <- exdqlm:::.qdesn_rhs_campaign_strict_gate(pair_df, cfg = gate_cfg)

  out <- data.frame(
    stage_id = stage_id,
    profile_id = profile_id,
    description = description,
    n_pairs = as.integer(gate$n_pairs %||% 0L),
    n_pair_pass = sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "PASS", na.rm = TRUE),
    n_pair_warn = sum(toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "WARN", na.rm = TRUE),
    n_pair_fail = as.integer(gate$n_pair_fail %||% 0L),
    n_pair_eligible = as.integer(gate$n_pair_eligible %||% 0L),
    all_finite_ok = isTRUE(gate$all_finite_ok),
    all_domain_ok = isTRUE(gate$all_domain_ok),
    all_finite_domain_ok = isTRUE(gate$all_finite_domain_ok),
    mcmc_signoff_pass = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "PASS", na.rm = TRUE),
    mcmc_signoff_warn = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "WARN", na.rm = TRUE),
    mcmc_signoff_fail = sum(toupper(as.character(mcmc_df$signoff_grade %||% "")) == "FAIL", na.rm = TRUE),
    mcmc_signoff_grade_worst = grade_worst(mcmc_df$signoff_grade),
    mcmc_signoff_reason_worst = worst_reason(mcmc_df),
    mcmc_min_ess_rhs_min = min_or_na(mcmc_df$mcmc_min_ess_rhs),
    mcmc_max_geweke_absz_rhs_max = max_or_na(mcmc_df$mcmc_max_geweke_absz_rhs),
    mcmc_max_half_drift_rhs_max = max_or_na(mcmc_df$mcmc_max_half_drift_rhs),
    runtime_ratio_median = median_or_na(pair_df$runtime_ratio_mcmc_vs_vb),
    mcmc_fit_runtime_seconds_mean = safe_num(mean(as.numeric(pair_df$mcmc_fit_runtime_seconds), na.rm = TRUE), NA_real_),
    n_trace_unavailable_total = as.integer(gate$n_trace_unavailable_total %||% 0L),
    gate_pass = isTRUE(gate$pass),
    gate_zero_fail = isTRUE(gate$pass_zero_fail),
    gate_all_eligible = isTRUE(gate$pass_all_eligible),
    gate_finite_domain = isTRUE(gate$pass_finite_domain),
    gate_no_trace_unavailable = isTRUE(gate$pass_trace),
    report_root = report_root,
    results_root = results_root,
    stringsAsFactors = FALSE
  )
  list(summary = out, pair = pair_df, method = method_df, gate = gate)
}

choose_winner <- function(df) {
  if (!is.data.frame(df) || !nrow(df)) {
    stop("Cannot choose winner from empty profile table.", call. = FALSE)
  }
  cand <- df[as.logical(df$gate_pass), , drop = FALSE]
  if (!nrow(cand)) cand <- df
  ord <- with(cand, order(
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
  cand[ord[1L], , drop = FALSE]
}

validate_guardrails <- function(cfg) {
  input_mode <- tolower(as.character(cfg$pipeline$readout$input_mode %||% "raw_y_lags")[1L])
  decomp_enabled <- isTRUE(cfg$pipeline$decomposition$enabled %||% FALSE)
  guardrail <- resolve_rhs_family_guardrail(cfg)
  init_log_tau <- guardrail$init_log_tau
  if (!identical(input_mode, "raw_y_lags")) {
    stop(sprintf("Guardrail violation: readout.input_mode must be raw_y_lags; got '%s'.", input_mode), call. = FALSE)
  }
  if (decomp_enabled) {
    stop("Guardrail violation: decomposition.enabled must be FALSE for this validation framework.", call. = FALSE)
  }
  if (!is.finite(as.numeric(init_log_tau))) {
    stop("Guardrail violation: RHS-family init_log_tau must resolve to numeric.", call. = FALSE)
  }
  invisible(TRUE)
}

run_profile_set <- function(stage_id, profiles_cfg, stage_base_defaults, grid_path, analysis_root, results_root, report_root, create_plots, verbose, resume_mode, gate_cfg) {
  profiles <- profiles_cfg$profiles %||% list()
  if (!length(profiles)) {
    stop(sprintf("%s has no profiles.", stage_id), call. = FALSE)
  }
  base_patch <- profiles_cfg$base_patch %||% list()
  phase_base_defaults <- deep_merge(stage_base_defaults, base_patch)
  rows <- list()
  defaults_map <- list()
  run_map <- list()

  for (ii in seq_along(profiles)) {
    prof <- profiles[[ii]]
    prof_id <- as.character(prof$id %||% sprintf("%s_%02d", stage_id, ii))
    prof_desc <- as.character(prof$description %||% prof_id)
    cfg_i <- deep_merge(phase_base_defaults, prof$patch %||% list())
    cfg_i$campaign <- cfg_i$campaign %||% list()
    cfg_i$campaign$name <- paste0("qdesn_rhs_", tolower(stage_id), "__", prof_id)
    cfg_i$campaign$results_root <- file.path(results_root, tolower(stage_id), prof_id)
    cfg_i$campaign$reports_root <- file.path(report_root, tolower(stage_id), prof_id)

    defaults_i <- file.path(analysis_root, "config", sprintf("%s_defaults_%s.yaml", tolower(stage_id), prof_id))
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

    sum_i <- extract_campaign_summary(
      stage_id = stage_id,
      profile_id = prof_id,
      description = prof_desc,
      report_root = run_i$report_root,
      results_root = run_i$results_root,
      gate_cfg = gate_cfg
    )
    rows[[length(rows) + 1L]] <- sum_i$summary
    defaults_map[[prof_id]] <- cfg_i
    run_map[[prof_id]] <- run_i
  }

  list(
    summary = do.call(rbind, rows),
    defaults_map = defaults_map,
    run_map = run_map
  )
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageM_repair_manifest.yaml")),
  must_work = TRUE
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume_mode <- !has_flag("--no-resume")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageMrepair-", stamp, "__git-", git_sha)))[1L]

analysis_root <- resolve_path(
  get_arg("--analysis-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageM_repair_wave", run_tag)),
  must_work = FALSE
)
for (d in c(analysis_root, file.path(analysis_root, "config"), file.path(analysis_root, "tables"), file.path(analysis_root, "manifest"), file.path(analysis_root, "plots"))) {
  dir_create(d)
}
dir_create(results_root)

manifest <- yaml::read_yaml(manifest_path)
inputs <- manifest$inputs %||% list()
gates <- manifest$gates %||% list()
outputs <- manifest$outputs %||% list()
meta <- manifest$meta %||% list()

tracker_title <- as.character(meta$tracker_title %||% "TRACK: QDESN RHS Stage-M Repair Wave")[1L]
stage_label <- as.character(meta$stage_label %||% "Stage-M")[1L]
mr2_description <- as.character(
  meta$mr2_description %||% "Canary reconfirm (12 roots, seed 123) with MR1 winner."
)[1L]
mr3_description <- as.character(
  meta$mr3_description %||% "Full Stage-M expansion (36 roots) with MR1 winner."
)[1L]
output_manifest_name <- as.character(meta$output_manifest_name %||% "stageM_repair_manifest.json")[1L]
if (!nzchar(trimws(output_manifest_name))) output_manifest_name <- "stageM_repair_manifest.json"

promoted_defaults_path <- resolve_path(inputs$promoted_defaults, must_work = TRUE)
guardrail_lock_path <- resolve_path(inputs$guardrail_lock, must_work = TRUE)
failed_grid_path <- resolve_path(inputs$failed_grid, must_work = TRUE)
canary_grid_path <- resolve_path(inputs$canary_grid, must_work = TRUE)
full_grid_path <- resolve_path(inputs$full_grid, must_work = TRUE)
mr1_profiles_path <- resolve_path(inputs$mr1_profiles, must_work = TRUE)

winner_defaults_out <- resolve_path(outputs$winner_defaults, must_work = FALSE)
promoted_defaults_out <- resolve_path(outputs$promoted_defaults, must_work = FALSE)
tracker_doc_path <- resolve_path(outputs$tracker_doc, must_work = FALSE)

# Step 0: materialize guardrailed base defaults.
promoted_defaults <- yaml::read_yaml(promoted_defaults_path)
guardrail_lock <- yaml::read_yaml(guardrail_lock_path)
if (!is.list(promoted_defaults) || !is.list(guardrail_lock)) {
  stop("Promoted defaults and guardrail lock must parse as YAML lists.", call. = FALSE)
}
guardrail_lock$guardrails <- NULL
base_defaults <- modifyList(promoted_defaults, guardrail_lock)
validate_guardrails(base_defaults)

base_defaults_path <- file.path(analysis_root, "config", "base_guardrailed_defaults.yaml")
yaml::write_yaml(base_defaults, base_defaults_path)

# Step MR1: failed-root-only profile matrix.
mr1_profiles <- yaml::read_yaml(mr1_profiles_path)
mr1 <- run_profile_set(
  stage_id = "MR1",
  profiles_cfg = mr1_profiles,
  stage_base_defaults = base_defaults,
  grid_path = failed_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = analysis_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode,
  gate_cfg = gates$mr1 %||% list()
)
utils::write.csv(mr1$summary, file.path(analysis_root, "tables", "mr1_profile_matrix.csv"), row.names = FALSE)

mr1_winner <- choose_winner(mr1$summary)
mr1_winner_id <- as.character(mr1_winner$profile_id[1L])
winner_defaults <- mr1$defaults_map[[mr1_winner_id]]
dir_create(dirname(winner_defaults_out))
yaml::write_yaml(winner_defaults, winner_defaults_out)
yaml::write_yaml(winner_defaults, file.path(analysis_root, "config", "mr1_winner_defaults.yaml"))

jsonlite::write_json(
  list(
    stage_id = "MR1",
    winner_profile_id = mr1_winner_id,
    winner_summary = mr1_winner,
    generated_at = as.character(Sys.time())
  ),
  file.path(analysis_root, "manifest", "mr1_winner.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

# Step MR2: canary reconfirm with MR1 winner.
mr2_defaults <- winner_defaults
mr2_defaults$campaign <- mr2_defaults$campaign %||% list()
mr2_defaults$campaign$name <- "qdesn_rhs_mr2_canary_reconfirm"
mr2_defaults$campaign$results_root <- file.path(results_root, "mr2_canary")
mr2_defaults$campaign$reports_root <- file.path(analysis_root, "mr2_canary")
mr2_defaults_path <- file.path(analysis_root, "config", "mr2_defaults.yaml")
yaml::write_yaml(mr2_defaults, mr2_defaults_path)

run_mr2 <- run_or_resume_campaign(
  grid_path = canary_grid_path,
  defaults_path = mr2_defaults_path,
  results_root = mr2_defaults$campaign$results_root,
  report_root = mr2_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
mr2 <- extract_campaign_summary(
  stage_id = "MR2",
  profile_id = "MR2_canary_reconfirm",
  description = mr2_description,
  report_root = run_mr2$report_root,
  results_root = run_mr2$results_root,
  gate_cfg = gates$mr2 %||% list()
)
utils::write.csv(mr2$summary, file.path(analysis_root, "tables", "mr2_canary_summary.csv"), row.names = FALSE)
utils::write.csv(mr2$pair, file.path(analysis_root, "tables", "mr2_canary_pair_summary.csv"), row.names = FALSE)

# Step MR3: full expansion only if MR2 gate passes.
mr3 <- list(summary = data.frame(stringsAsFactors = FALSE), gate = list(pass = FALSE), pair = data.frame(stringsAsFactors = FALSE))
mr3_attempted <- FALSE
promotion_written <- FALSE

if (isTRUE(mr2$gate$pass)) {
  mr3_attempted <- TRUE
  mr3_defaults <- winner_defaults
  mr3_defaults$campaign <- mr3_defaults$campaign %||% list()
  mr3_defaults$campaign$name <- "qdesn_rhs_mr3_full_reconfirm"
  mr3_defaults$campaign$results_root <- file.path(results_root, "mr3_full")
  mr3_defaults$campaign$reports_root <- file.path(analysis_root, "mr3_full")
  mr3_defaults_path <- file.path(analysis_root, "config", "mr3_defaults.yaml")
  yaml::write_yaml(mr3_defaults, mr3_defaults_path)

  run_mr3 <- run_or_resume_campaign(
    grid_path = full_grid_path,
    defaults_path = mr3_defaults_path,
    results_root = mr3_defaults$campaign$results_root,
    report_root = mr3_defaults$campaign$reports_root,
    create_plots = create_plots,
    verbose = verbose,
    resume_mode = resume_mode
  )
  mr3 <- extract_campaign_summary(
    stage_id = "MR3",
    profile_id = "MR3_full_reconfirm",
    description = mr3_description,
    report_root = run_mr3$report_root,
    results_root = run_mr3$results_root,
    gate_cfg = gates$mr3 %||% list()
  )
  utils::write.csv(mr3$summary, file.path(analysis_root, "tables", "mr3_full_summary.csv"), row.names = FALSE)
  utils::write.csv(mr3$pair, file.path(analysis_root, "tables", "mr3_full_pair_summary.csv"), row.names = FALSE)

  if (isTRUE(mr3$gate$pass)) {
    dir_create(dirname(promoted_defaults_out))
    yaml::write_yaml(winner_defaults, promoted_defaults_out)
    promotion_written <- TRUE
  }
}

decision <- list(
  mr1_winner = mr1_winner_id,
  mr2_pass = isTRUE(mr2$gate$pass),
  mr3_attempted = isTRUE(mr3_attempted),
  mr3_pass = isTRUE(mr3$gate$pass),
  promoted_for_next_wave = isTRUE(promotion_written),
  generated_at = as.character(Sys.time())
)

tracker_lines <- c(
  sprintf("# %s", tracker_title),
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- analysis_root: `%s`", analysis_root),
  sprintf("- results_root: `%s`", results_root),
  sprintf("- base_defaults: `%s`", promoted_defaults_path),
  sprintf("- guardrail_lock: `%s`", guardrail_lock_path),
  sprintf("- guardrailed_base_materialized: `%s`", base_defaults_path),
  sprintf("- failed_grid: `%s`", failed_grid_path),
  sprintf("- canary_grid: `%s`", canary_grid_path),
  sprintf("- full_grid: `%s`", full_grid_path),
  sprintf("- mr1_winner: `%s`", mr1_winner_id),
  sprintf("- mr2_pass: `%s`", if (isTRUE(mr2$gate$pass)) "true" else "false"),
  sprintf("- mr3_attempted: `%s`", if (isTRUE(mr3_attempted)) "true" else "false"),
  sprintf("- mr3_pass: `%s`", if (isTRUE(mr3$gate$pass)) "true" else "false"),
  sprintf("- promoted_for_next_wave: `%s`", if (isTRUE(promotion_written)) "true" else "false"),
  "",
  "## MR1 Profile Matrix",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(mr1$summary))
tracker_lines <- c(tracker_lines, "", "## MR2 Canary Summary", "")
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(mr2$summary))
if (isTRUE(mr3_attempted) && nrow(mr3$summary)) {
  tracker_lines <- c(tracker_lines, "", "## MR3 Full Summary", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(mr3$summary))
}
tracker_lines <- c(
  tracker_lines,
  "",
  "## Decision",
  sprintf("- mr1_winner: `%s`", mr1_winner_id),
  sprintf("- mr2_pass: `%s`", if (isTRUE(mr2$gate$pass)) "true" else "false"),
  sprintf("- mr3_attempted: `%s`", if (isTRUE(mr3_attempted)) "true" else "false"),
  sprintf("- mr3_pass: `%s`", if (isTRUE(mr3$gate$pass)) "true" else "false"),
  sprintf("- promoted_for_next_wave: `%s`", if (isTRUE(promotion_written)) "true" else "false")
)
dir_create(dirname(tracker_doc_path))
writeLines(tracker_lines, tracker_doc_path)

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    manifest_path = manifest_path,
    base_defaults = promoted_defaults_path,
    guardrail_lock = guardrail_lock_path,
    failed_grid = failed_grid_path,
    canary_grid = canary_grid_path,
    full_grid = full_grid_path,
    mr1 = list(summary = mr1$summary, winner = mr1_winner),
    mr2 = list(summary = mr2$summary, gate = mr2$gate),
    mr3 = list(summary = mr3$summary, gate = mr3$gate, attempted = mr3_attempted),
    decision = decision,
    winner_defaults_out = winner_defaults_out,
    promoted_defaults_out = if (isTRUE(promotion_written)) promoted_defaults_out else NULL,
    tracker_doc_path = tracker_doc_path
  ),
  file.path(analysis_root, "manifest", output_manifest_name),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("%s repair analysis root: %s\n", stage_label, analysis_root))
cat(sprintf("MR1 winner: %s\n", mr1_winner_id))
cat(sprintf("MR2 pass: %s\n", if (isTRUE(mr2$gate$pass)) "yes" else "no"))
cat(sprintf("MR3 attempted: %s\n", if (isTRUE(mr3_attempted)) "yes" else "no"))
cat(sprintf("MR3 pass: %s\n", if (isTRUE(mr3$gate$pass)) "yes" else "no"))
cat(sprintf("Promoted for next wave: %s\n", if (isTRUE(promotion_written)) "yes" else "no"))
cat(sprintf("Tracker: %s\n", tracker_doc_path))
