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
  init_log_tau <- cfg$pipeline$inference$vb$priors$beta$rhs$init_log_tau %||% NA_real_
  if (!identical(input_mode, "raw_y_lags")) {
    stop(sprintf("Guardrail violation: readout.input_mode must be raw_y_lags; got '%s'.", input_mode), call. = FALSE)
  }
  if (decomp_enabled) {
    stop("Guardrail violation: decomposition.enabled must be FALSE for this validation framework.", call. = FALSE)
  }
  if (!is.finite(as.numeric(init_log_tau))) {
    stop("Guardrail violation: vb.priors.beta.rhs.init_log_tau must resolve to numeric.", call. = FALSE)
  }
  invisible(TRUE)
}

run_profile_set <- function(stage_id, profiles_cfg, stage_base_defaults, grid_path, analysis_root, results_root, report_root, create_plots, verbose, resume_mode, gate_cfg, outer_workers = 1L, threads_per_worker = 1L, profile_workers = 1L) {
  profiles <- profiles_cfg$profiles %||% list()
  if (!length(profiles)) {
    stop(sprintf("%s has no profiles.", stage_id), call. = FALSE)
  }
  base_patch <- profiles_cfg$base_patch %||% list()
  phase_base_defaults <- deep_merge(stage_base_defaults, base_patch)
  profile_workers <- as.integer(max(1L, profile_workers))

  run_one_profile <- function(ii) {
    prof <- profiles[[ii]]
    prof_id <- as.character(prof$id %||% sprintf("%s_%02d", stage_id, ii))
    prof_desc <- as.character(prof$description %||% prof_id)
    cfg_i <- deep_merge(phase_base_defaults, prof$patch %||% list())
    cfg_i$campaign <- cfg_i$campaign %||% list()
    cfg_i$campaign$name <- paste0("qdesn_rhs_", tolower(stage_id), "__", prof_id)
    cfg_i$campaign$results_root <- file.path(results_root, tolower(stage_id), prof_id)
    cfg_i$campaign$reports_root <- file.path(report_root, tolower(stage_id), prof_id)
    cfg_i$runtime <- cfg_i$runtime %||% list()
    cfg_i$runtime$campaign_workers <- as.integer(max(1L, outer_workers))
    cfg_i$runtime$workers <- as.integer(max(1L, outer_workers))
    cfg_i$runtime$threads <- as.integer(max(1L, threads_per_worker))

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
    list(
      profile_id = prof_id,
      summary = sum_i$summary,
      defaults = cfg_i,
      run = run_i
    )
  }

  idx <- seq_along(profiles)
  can_parallel <- profile_workers > 1L && .Platform$OS.type == "unix" && length(idx) > 1L
  if (can_parallel) {
    profile_results <- parallel::mclapply(
      idx,
      run_one_profile,
      mc.cores = min(profile_workers, length(idx)),
      mc.preschedule = FALSE
    )
  } else {
    profile_results <- lapply(idx, run_one_profile)
  }

  rows <- lapply(profile_results, function(x) x$summary)
  defaults_map <- stats::setNames(
    lapply(profile_results, function(x) x$defaults),
    vapply(profile_results, function(x) as.character(x$profile_id), character(1))
  )
  run_map <- stats::setNames(
    lapply(profile_results, function(x) x$run),
    vapply(profile_results, function(x) as.character(x$profile_id), character(1))
  )

  list(
    summary = do.call(rbind, rows),
    defaults_map = defaults_map,
    run_map = run_map
  )
}

resolve_stageN_runtime_baseline <- function(stageN_analysis_root) {
  out <- list(
    value = NA_real_,
    source = NA_character_,
    available = FALSE
  )
  if (is.null(stageN_analysis_root) || !dir.exists(stageN_analysis_root)) return(out)

  summary_path <- file.path(stageN_analysis_root, "tables", "mr3_full_summary.csv")
  if (file.exists(summary_path)) {
    df <- read_csv_safe(summary_path)
    if (nrow(df) && "runtime_ratio_median" %in% names(df)) {
      val <- safe_num(df$runtime_ratio_median[1L], NA_real_)
      if (is.finite(val)) {
        out$value <- val
        out$source <- summary_path
        out$available <- TRUE
        return(out)
      }
    }
  }

  mr3_dir <- file.path(stageN_analysis_root, "mr3_full")
  if (dir.exists(mr3_dir)) {
    runs <- sort(list.dirs(mr3_dir, recursive = FALSE, full.names = TRUE), decreasing = TRUE)
    for (rr in runs) {
      pair_path <- file.path(rr, "tables", "campaign_pair_summary.csv")
      if (!file.exists(pair_path)) next
      pair_df <- read_csv_safe(pair_path)
      val <- median_or_na(pair_df$runtime_ratio_mcmc_vs_vb)
      if (is.finite(val)) {
        out$value <- val
        out$source <- pair_path
        out$available <- TRUE
        return(out)
      }
    }
  }
  out
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageO_manifest.yaml")),
  must_work = TRUE
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume_mode <- !has_flag("--no-resume")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageO-", stamp, "__git-", git_sha)))[1L]

analysis_root <- resolve_path(
  get_arg("--analysis-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageO_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageO_wave", run_tag)),
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
controls <- manifest$controls %||% list()
meta <- manifest$meta %||% list()

tracker_title <- as.character(meta$tracker_title %||% "TRACK: QDESN RHS Stage-O Drift Closure Wave")[1L]
stage_label <- as.character(meta$stage_label %||% "Stage-O")[1L]
o1_description <- as.character(meta$o1_description %||% "O1 stochasticity probe on blocker root.")[1L]
o2_description <- as.character(meta$o2_description %||% "O2 blocker-root candidate racing matrix.")[1L]
o3_description <- as.character(meta$o3_description %||% "O3 stress6 reconfirmation with selected candidate.")[1L]
o4_description <- as.character(meta$o4_description %||% "O4 full reconfirmation with selected candidate.")[1L]
output_manifest_name <- as.character(meta$output_manifest_name %||% "stageO_manifest.json")[1L]
if (!nzchar(trimws(output_manifest_name))) output_manifest_name <- "stageO_manifest.json"

base_defaults_path <- resolve_path(inputs$base_defaults, must_work = TRUE)
guardrail_lock_path <- resolve_path(inputs$guardrail_lock, must_work = TRUE)
blocker_grid_path <- resolve_path(inputs$blocker_grid, must_work = TRUE)
stress_grid_path <- resolve_path(inputs$stress_grid, must_work = TRUE)
full_grid_path <- resolve_path(inputs$full_grid, must_work = TRUE)
o1_profiles_path <- resolve_path(inputs$o1_profiles, must_work = TRUE)
o2_profiles_path <- resolve_path(inputs$o2_profiles, must_work = TRUE)
stageN_analysis_root <- resolve_path(inputs$stageN_analysis_root, must_work = FALSE)

winner_defaults_out <- resolve_path(outputs$winner_defaults, must_work = FALSE)
promoted_defaults_out <- resolve_path(outputs$promoted_defaults, must_work = FALSE)
tracker_doc_path <- resolve_path(outputs$tracker_doc, must_work = FALSE)

skip_o2_if_o1_clean <- if (is.null(controls$skip_o2_if_o1_clean)) TRUE else isTRUE(controls$skip_o2_if_o1_clean)
runtime_guardrail_max_increase_frac <- as.numeric(controls$runtime_guardrail_max_increase_frac %||% 0.20)[1L]
if (!is.finite(runtime_guardrail_max_increase_frac) || runtime_guardrail_max_increase_frac < 0) {
  runtime_guardrail_max_increase_frac <- 0.20
}
outer_workers <- as.integer(controls$outer_workers %||% 1L)[1L]
threads_per_worker <- as.integer(controls$threads_per_worker %||% 1L)[1L]
profile_workers <- as.integer(controls$profile_workers %||% 1L)[1L]
if (!is.finite(outer_workers) || outer_workers < 1L) outer_workers <- 1L
if (!is.finite(threads_per_worker) || threads_per_worker < 1L) threads_per_worker <- 1L
if (!is.finite(profile_workers) || profile_workers < 1L) profile_workers <- 1L

# O0: materialize guardrailed base + baseline runtime reference.
base_defaults <- yaml::read_yaml(base_defaults_path)
guardrail_lock <- yaml::read_yaml(guardrail_lock_path)
if (!is.list(base_defaults) || !is.list(guardrail_lock)) {
  stop("Base defaults and guardrail lock must parse as YAML lists.", call. = FALSE)
}
guardrail_lock$guardrails <- NULL
guardrailed_defaults <- modifyList(base_defaults, guardrail_lock)
validate_guardrails(guardrailed_defaults)

guardrailed_defaults_path <- file.path(analysis_root, "config", "base_guardrailed_defaults.yaml")
yaml::write_yaml(guardrailed_defaults, guardrailed_defaults_path)

stageN_runtime <- resolve_stageN_runtime_baseline(stageN_analysis_root)
blocker_grid_df <- read_csv_safe(blocker_grid_path)
jsonlite::write_json(
  list(
    frozen_at = as.character(Sys.time()),
    run_tag = run_tag,
    git_sha = git_sha,
    manifest_path = manifest_path,
    base_defaults = base_defaults_path,
    guardrail_lock = guardrail_lock_path,
    guardrailed_defaults = guardrailed_defaults_path,
    blocker_grid = blocker_grid_path,
    blocker_rows = nrow(blocker_grid_df),
    blocker_root_id = if (nrow(blocker_grid_df) == 1L) {
      with(blocker_grid_df[1L, ], {
        tau_txt <- gsub("\\.", "p", format(as.numeric(tau), trim = TRUE, scientific = FALSE))
        sprintf(
          "scenario-%s__tau-%s__prior-%s__seed-%s__res-%s",
          as.character(scenario),
          as.character(tau_txt),
          as.character(beta_prior_type),
          as.integer(seed),
          as.character(reservoir_profile)
        )
      })
    } else {
      NA_character_
    },
    stageN_analysis_root = stageN_analysis_root,
    stageN_runtime_ratio_median = if (isTRUE(stageN_runtime$available)) as.numeric(stageN_runtime$value) else NA_real_,
    stageN_runtime_source = stageN_runtime$source,
    runtime_guardrail_max_increase_frac = runtime_guardrail_max_increase_frac
  ),
  file.path(analysis_root, "manifest", "o0_baseline_forensics.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

# O1: stochasticity probe (single blocker root, 3 repeats).
o1_profiles <- yaml::read_yaml(o1_profiles_path)
o1 <- run_profile_set(
  stage_id = "O1",
  profiles_cfg = o1_profiles,
  stage_base_defaults = guardrailed_defaults,
  grid_path = blocker_grid_path,
  analysis_root = analysis_root,
  results_root = results_root,
  report_root = analysis_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode,
  gate_cfg = gates$o1 %||% list(),
  outer_workers = outer_workers,
  threads_per_worker = threads_per_worker,
  profile_workers = profile_workers
)
utils::write.csv(o1$summary, file.path(analysis_root, "tables", "o1_profile_matrix.csv"), row.names = FALSE)
o1_all_pass <- nrow(o1$summary) > 0L && all(as.logical(o1$summary$gate_pass))
o1_winner <- choose_winner(o1$summary)
o1_winner_id <- as.character(o1_winner$profile_id[1L])

# O2: candidate matrix (skip if O1 is already fully clean and skip flag enabled).
o2_attempted <- FALSE
o2 <- list(summary = data.frame(stringsAsFactors = FALSE), defaults_map = list(), run_map = list())
selected_phase <- "O1"
selected_profile_id <- o1_winner_id
selected_defaults <- o1$defaults_map[[o1_winner_id]]

if (!(isTRUE(skip_o2_if_o1_clean) && isTRUE(o1_all_pass))) {
  o2_attempted <- TRUE
  o2_profiles <- yaml::read_yaml(o2_profiles_path)
  o2 <- run_profile_set(
    stage_id = "O2",
    profiles_cfg = o2_profiles,
    stage_base_defaults = guardrailed_defaults,
    grid_path = blocker_grid_path,
    analysis_root = analysis_root,
    results_root = results_root,
    report_root = analysis_root,
    create_plots = create_plots,
    verbose = verbose,
    resume_mode = resume_mode,
    gate_cfg = gates$o2 %||% list(),
    outer_workers = outer_workers,
    threads_per_worker = threads_per_worker,
    profile_workers = profile_workers
  )
  utils::write.csv(o2$summary, file.path(analysis_root, "tables", "o2_profile_matrix.csv"), row.names = FALSE)
  o2_winner <- choose_winner(o2$summary)
  selected_phase <- "O2"
  selected_profile_id <- as.character(o2_winner$profile_id[1L])
  selected_defaults <- o2$defaults_map[[selected_profile_id]]
}

selected_candidate <- list(
  phase = selected_phase,
  profile_id = selected_profile_id,
  selected_at = as.character(Sys.time())
)
jsonlite::write_json(
  selected_candidate,
  file.path(analysis_root, "manifest", "selected_candidate.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

dir_create(dirname(winner_defaults_out))
yaml::write_yaml(selected_defaults, winner_defaults_out)
yaml::write_yaml(selected_defaults, file.path(analysis_root, "config", "selected_candidate_defaults.yaml"))

# O3: stress6 reconfirm using selected candidate.
o3_defaults <- selected_defaults
o3_defaults$campaign <- o3_defaults$campaign %||% list()
o3_defaults$campaign$name <- "qdesn_rhs_o3_stress6_reconfirm"
o3_defaults$campaign$results_root <- file.path(results_root, "o3_stress6")
o3_defaults$campaign$reports_root <- file.path(analysis_root, "o3_stress6")
o3_defaults$runtime <- o3_defaults$runtime %||% list()
o3_defaults$runtime$campaign_workers <- as.integer(max(1L, outer_workers))
o3_defaults$runtime$workers <- as.integer(max(1L, outer_workers))
o3_defaults$runtime$threads <- as.integer(max(1L, threads_per_worker))
o3_defaults_path <- file.path(analysis_root, "config", "o3_defaults.yaml")
yaml::write_yaml(o3_defaults, o3_defaults_path)

run_o3 <- run_or_resume_campaign(
  grid_path = stress_grid_path,
  defaults_path = o3_defaults_path,
  results_root = o3_defaults$campaign$results_root,
  report_root = o3_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
o3 <- extract_campaign_summary(
  stage_id = "O3",
  profile_id = "O3_stress6_reconfirm",
  description = o3_description,
  report_root = run_o3$report_root,
  results_root = run_o3$results_root,
  gate_cfg = gates$o3 %||% list()
)
utils::write.csv(o3$summary, file.path(analysis_root, "tables", "o3_stress6_summary.csv"), row.names = FALSE)
utils::write.csv(o3$pair, file.path(analysis_root, "tables", "o3_stress6_pair_summary.csv"), row.names = FALSE)

# O4: full reconfirm only if O3 strict gate passes.
o4_attempted <- FALSE
o4 <- list(summary = data.frame(stringsAsFactors = FALSE), gate = list(pass = FALSE), pair = data.frame(stringsAsFactors = FALSE))
if (isTRUE(o3$gate$pass)) {
  o4_attempted <- TRUE
  o4_defaults <- selected_defaults
  o4_defaults$campaign <- o4_defaults$campaign %||% list()
  o4_defaults$campaign$name <- "qdesn_rhs_o4_full_reconfirm"
  o4_defaults$campaign$results_root <- file.path(results_root, "o4_full")
  o4_defaults$campaign$reports_root <- file.path(analysis_root, "o4_full")
  o4_defaults$runtime <- o4_defaults$runtime %||% list()
  o4_defaults$runtime$campaign_workers <- as.integer(max(1L, outer_workers))
  o4_defaults$runtime$workers <- as.integer(max(1L, outer_workers))
  o4_defaults$runtime$threads <- as.integer(max(1L, threads_per_worker))
  o4_defaults_path <- file.path(analysis_root, "config", "o4_defaults.yaml")
  yaml::write_yaml(o4_defaults, o4_defaults_path)

  run_o4 <- run_or_resume_campaign(
    grid_path = full_grid_path,
    defaults_path = o4_defaults_path,
    results_root = o4_defaults$campaign$results_root,
    report_root = o4_defaults$campaign$reports_root,
    create_plots = create_plots,
    verbose = verbose,
    resume_mode = resume_mode
  )
  o4 <- extract_campaign_summary(
    stage_id = "O4",
    profile_id = "O4_full_reconfirm",
    description = o4_description,
    report_root = run_o4$report_root,
    results_root = run_o4$results_root,
    gate_cfg = gates$o4 %||% list()
  )
  utils::write.csv(o4$summary, file.path(analysis_root, "tables", "o4_full_summary.csv"), row.names = FALSE)
  utils::write.csv(o4$pair, file.path(analysis_root, "tables", "o4_full_pair_summary.csv"), row.names = FALSE)
}

# Runtime guardrail against Stage-N winner median runtime ratio.
o4_runtime_ratio_median <- if (nrow(o4$summary)) safe_num(o4$summary$runtime_ratio_median[1L], NA_real_) else NA_real_
runtime_baseline_ratio <- if (isTRUE(stageN_runtime$available)) safe_num(stageN_runtime$value, NA_real_) else NA_real_
runtime_guardrail_limit <- if (is.finite(runtime_baseline_ratio)) runtime_baseline_ratio * (1 + runtime_guardrail_max_increase_frac) else NA_real_
runtime_guardrail_evaluated <- isTRUE(o4_attempted) && is.finite(runtime_baseline_ratio) && is.finite(o4_runtime_ratio_median)
runtime_guardrail_pass <- isTRUE(runtime_guardrail_evaluated) && (o4_runtime_ratio_median <= runtime_guardrail_limit)

promotion_written <- FALSE
if (isTRUE(o4_attempted) && isTRUE(o4$gate$pass) && isTRUE(runtime_guardrail_pass)) {
  dir_create(dirname(promoted_defaults_out))
  yaml::write_yaml(selected_defaults, promoted_defaults_out)
  promotion_written <- TRUE
}

decision <- list(
  selected_phase = selected_phase,
  selected_profile_id = selected_profile_id,
  o1_all_pass = isTRUE(o1_all_pass),
  o2_attempted = isTRUE(o2_attempted),
  o3_pass = isTRUE(o3$gate$pass),
  o4_attempted = isTRUE(o4_attempted),
  o4_pass = isTRUE(o4$gate$pass),
  runtime_guardrail_evaluated = isTRUE(runtime_guardrail_evaluated),
  runtime_guardrail_pass = isTRUE(runtime_guardrail_pass),
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
  sprintf("- base_defaults: `%s`", base_defaults_path),
  sprintf("- guardrail_lock: `%s`", guardrail_lock_path),
  sprintf("- guardrailed_base_materialized: `%s`", guardrailed_defaults_path),
  sprintf("- blocker_grid: `%s`", blocker_grid_path),
  sprintf("- stress_grid: `%s`", stress_grid_path),
  sprintf("- full_grid: `%s`", full_grid_path),
  sprintf("- skip_o2_if_o1_clean: `%s`", if (isTRUE(skip_o2_if_o1_clean)) "true" else "false"),
  sprintf("- selected_candidate: `%s/%s`", selected_phase, selected_profile_id),
  sprintf("- outer_workers: `%d`", as.integer(outer_workers)),
  sprintf("- profile_workers: `%d`", as.integer(profile_workers)),
  sprintf("- threads_per_worker: `%d`", as.integer(threads_per_worker)),
  sprintf("- stageN_runtime_ratio_baseline: `%s`", if (is.finite(runtime_baseline_ratio)) format(runtime_baseline_ratio, digits = 6) else "NA"),
  sprintf("- stageN_runtime_ratio_source: `%s`", stageN_runtime$source %||% "NA"),
  sprintf("- runtime_guardrail_max_increase_frac: `%s`", format(runtime_guardrail_max_increase_frac, digits = 6)),
  sprintf("- runtime_guardrail_limit: `%s`", if (is.finite(runtime_guardrail_limit)) format(runtime_guardrail_limit, digits = 6) else "NA"),
  "",
  "## O1 Stochasticity Probe",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(o1$summary))
if (isTRUE(o2_attempted) && nrow(o2$summary)) {
  tracker_lines <- c(tracker_lines, "", "## O2 Candidate Matrix", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(o2$summary))
} else {
  tracker_lines <- c(tracker_lines, "", "## O2 Candidate Matrix", "", "_Skipped because O1 profiles were all strict-gate clean._")
}
tracker_lines <- c(tracker_lines, "", "## O3 Stress6 Summary", "")
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(o3$summary))
if (isTRUE(o4_attempted) && nrow(o4$summary)) {
  tracker_lines <- c(tracker_lines, "", "## O4 Full Summary", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(o4$summary))
} else {
  tracker_lines <- c(tracker_lines, "", "## O4 Full Summary", "", "_Not attempted because O3 strict gate did not pass._")
}
tracker_lines <- c(
  tracker_lines,
  "",
  "## Decision",
  sprintf("- selected_candidate: `%s/%s`", selected_phase, selected_profile_id),
  sprintf("- o1_all_pass: `%s`", if (isTRUE(o1_all_pass)) "true" else "false"),
  sprintf("- o2_attempted: `%s`", if (isTRUE(o2_attempted)) "true" else "false"),
  sprintf("- o3_pass: `%s`", if (isTRUE(o3$gate$pass)) "true" else "false"),
  sprintf("- o4_attempted: `%s`", if (isTRUE(o4_attempted)) "true" else "false"),
  sprintf("- o4_pass: `%s`", if (isTRUE(o4$gate$pass)) "true" else "false"),
  sprintf("- runtime_guardrail_evaluated: `%s`", if (isTRUE(runtime_guardrail_evaluated)) "true" else "false"),
  sprintf("- runtime_guardrail_pass: `%s`", if (isTRUE(runtime_guardrail_pass)) "true" else "false"),
  sprintf("- promoted_for_next_wave: `%s`", if (isTRUE(promotion_written)) "true" else "false")
)
if (!isTRUE(promotion_written)) {
  tracker_lines <- c(
    tracker_lines,
    "",
    "## O5 Escalation Trigger",
    "- Promotion is blocked. Keep Stage-O candidate as provisional and escalate transformed RHS block kernel only."
  )
}
dir_create(dirname(tracker_doc_path))
writeLines(tracker_lines, tracker_doc_path)

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    manifest_path = manifest_path,
    base_defaults = base_defaults_path,
    guardrail_lock = guardrail_lock_path,
    blocker_grid = blocker_grid_path,
    stress_grid = stress_grid_path,
    full_grid = full_grid_path,
    stageN_runtime = stageN_runtime,
    runtime_guardrail_max_increase_frac = runtime_guardrail_max_increase_frac,
    runtime_guardrail_limit = runtime_guardrail_limit,
    o1 = list(summary = o1$summary, winner = o1_winner),
    o2 = list(attempted = o2_attempted, summary = o2$summary),
    o3 = list(summary = o3$summary, gate = o3$gate),
    o4 = list(attempted = o4_attempted, summary = o4$summary, gate = o4$gate),
    selected_candidate = selected_candidate,
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

cat(sprintf("%s analysis root: %s\n", stage_label, analysis_root))
cat(sprintf("Selected candidate: %s/%s\n", selected_phase, selected_profile_id))
cat(sprintf("O1 all pass: %s\n", if (isTRUE(o1_all_pass)) "yes" else "no"))
cat(sprintf("O2 attempted: %s\n", if (isTRUE(o2_attempted)) "yes" else "no"))
cat(sprintf("O3 pass: %s\n", if (isTRUE(o3$gate$pass)) "yes" else "no"))
cat(sprintf("O4 attempted: %s\n", if (isTRUE(o4_attempted)) "yes" else "no"))
cat(sprintf("O4 pass: %s\n", if (isTRUE(o4$gate$pass)) "yes" else "no"))
cat(sprintf("Runtime guardrail pass: %s\n", if (isTRUE(runtime_guardrail_pass)) "yes" else "no"))
cat(sprintf("Promoted for next wave: %s\n", if (isTRUE(promotion_written)) "yes" else "no"))
cat(sprintf("Tracker: %s\n", tracker_doc_path))
