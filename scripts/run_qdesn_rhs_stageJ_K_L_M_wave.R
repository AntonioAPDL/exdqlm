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

min_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else min(x)
}

max_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else max(x)
}

median_or_na <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else stats::median(x)
}

count_contains <- function(x, token) {
  x <- as.character(x %||% character(0))
  sum(grepl(token, x, fixed = TRUE), na.rm = TRUE)
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
  mcmc_df <- method_df[as.character(method_df$method) == "mcmc", , drop = FALSE]

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
    n_trace_unavailable_mcmc_signoff = count_contains(pair_df$mcmc_signoff_reason, "rhs_trace_unavailable"),
    n_trace_unavailable_mcmc_unhealthy = count_contains(pair_df$mcmc_unhealthy_reason, "rhs_trace_unavailable"),
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

build_failed_root_grid <- function(pair_df, out_path) {
  if (!is.data.frame(pair_df) || !nrow(pair_df)) {
    out <- data.frame(
      scenario = character(0),
      tau = numeric(0),
      beta_prior_type = character(0),
      seed = integer(0),
      reservoir_profile = character(0),
      enabled = logical(0),
      stringsAsFactors = FALSE
    )
    utils::write.csv(out, out_path, row.names = FALSE)
    return(out)
  }

  fail_grade <- toupper(as.character(pair_df$pair_signoff_grade %||% "")) == "FAIL"
  ineligible <- !as.logical(pair_df$pair_comparison_eligible %||% FALSE)
  nonfinite <- !as.logical(pair_df$both_finite_ok %||% FALSE)
  nondomain <- !as.logical(pair_df$both_domain_ok %||% FALSE)
  idx <- fail_grade | ineligible | nonfinite | nondomain
  sub <- pair_df[idx, , drop = FALSE]
  if (!nrow(sub)) {
    out <- data.frame(
      scenario = character(0),
      tau = numeric(0),
      beta_prior_type = character(0),
      seed = integer(0),
      reservoir_profile = character(0),
      enabled = logical(0),
      stringsAsFactors = FALSE
    )
    utils::write.csv(out, out_path, row.names = FALSE)
    return(out)
  }

  need <- c("scenario", "tau", "beta_prior_type", "seed", "reservoir_profile")
  missing <- setdiff(need, names(sub))
  if (length(missing)) {
    stop(sprintf("Cannot build failed grid; missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  out <- unique(sub[, need, drop = FALSE])
  out$seed <- as.integer(out$seed)
  out$tau <- as.numeric(out$tau)
  out$enabled <- TRUE
  out <- out[, c("scenario", "tau", "beta_prior_type", "seed", "reservoir_profile", "enabled"), drop = FALSE]
  utils::write.csv(out, out_path, row.names = FALSE)
  out
}

build_stageM_grid <- function(stagem_cfg, out_path) {
  scenario <- as.character(unlist(stagem_cfg$scenario %||% character(0), use.names = FALSE))
  tau <- as.numeric(unlist(stagem_cfg$tau %||% numeric(0), use.names = FALSE))
  beta_prior_type <- as.character(unlist(stagem_cfg$beta_prior_type %||% "rhs", use.names = FALSE))
  seed <- as.integer(unlist(stagem_cfg$seed %||% integer(0), use.names = FALSE))
  reservoir_profile <- as.character(unlist(stagem_cfg$reservoir_profile %||% "tiny_d1_n8", use.names = FALSE))
  enabled <- isTRUE(stagem_cfg$enabled %||% TRUE)

  if (!length(scenario) || !length(tau) || !length(seed) || !length(reservoir_profile) || !length(beta_prior_type)) {
    stop("stageM config must provide non-empty scenario, tau, seed, reservoir_profile, beta_prior_type.", call. = FALSE)
  }

  grid <- expand.grid(
    scenario = scenario,
    tau = tau,
    beta_prior_type = beta_prior_type,
    seed = seed,
    reservoir_profile = reservoir_profile,
    stringsAsFactors = FALSE
  )
  grid$enabled <- enabled
  utils::write.csv(grid, out_path, row.names = FALSE)
  grid
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageJ_K_manifest.yaml")),
  must_work = TRUE
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume_mode <- !has_flag("--no-resume")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0("stageJKLM-", stamp, "__git-", git_sha)))[1L]

report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageJ_K_L_M_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageJ_K_L_M_wave", run_tag)),
  must_work = FALSE
)
analysis_root <- report_root

for (d in c(analysis_root, file.path(analysis_root, "tables"), file.path(analysis_root, "config"), file.path(analysis_root, "manifest"), file.path(analysis_root, "plots"))) {
  dir_create(d)
}
dir_create(results_root)

cfg <- yaml::read_yaml(manifest_path)
inputs <- cfg$inputs %||% list()
outputs <- cfg$outputs %||% list()
gates <- cfg$gates %||% list()
stagem_cfg <- cfg$stageM %||% list()

candidate_defaults_path <- resolve_path(inputs$candidate_defaults, must_work = TRUE)
broader_grid_path <- resolve_path(inputs$broader_grid, must_work = TRUE)
stagek_profiles_path <- resolve_path(inputs$stagek_profiles, must_work = TRUE)
stagei_analysis_root <- resolve_path(inputs$stagei_analysis_root, must_work = FALSE)

promotion_defaults_path <- resolve_path(outputs$promotion_defaults, must_work = FALSE)
stagem_defaults_template_path <- resolve_path(outputs$stagem_defaults_template, must_work = FALSE)
stagem_grid_path <- resolve_path(outputs$stagem_grid, must_work = FALSE)
tracker_doc_path <- resolve_path(outputs$tracker_doc, must_work = FALSE)

candidate_defaults <- yaml::read_yaml(candidate_defaults_path)

baseline_ref <- list(
  frozen_at = as.character(Sys.time()),
  git_sha = git_sha,
  manifest_path = manifest_path,
  candidate_defaults_path = candidate_defaults_path,
  broader_grid_path = broader_grid_path,
  stagei_analysis_root = stagei_analysis_root
)
if (!is.null(stagei_analysis_root) && dir.exists(stagei_analysis_root)) {
  stagei_manifest_path <- file.path(stagei_analysis_root, "manifest", "stageI_phase1_phase2_manifest.json")
  if (file.exists(stagei_manifest_path)) {
    baseline_ref$stagei_manifest <- jsonlite::fromJSON(stagei_manifest_path, simplifyVector = TRUE)
    baseline_ref$stagei_manifest_path <- stagei_manifest_path
  }
}
jsonlite::write_json(
  baseline_ref,
  file.path(analysis_root, "manifest", "step0_baseline_reference.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

# Stage J: broader reconfirmation with Stage-I candidate defaults.
stageJ_defaults <- candidate_defaults
stageJ_defaults$campaign <- stageJ_defaults$campaign %||% list()
stageJ_defaults$campaign$name <- "qdesn_rhs_stageJ_broader_reconfirm"
stageJ_defaults$campaign$results_root <- file.path(results_root, "stageJ")
stageJ_defaults$campaign$reports_root <- file.path(report_root, "stageJ")
stageJ_defaults_path <- file.path(analysis_root, "config", "stageJ_defaults.yaml")
yaml::write_yaml(stageJ_defaults, stageJ_defaults_path)

run_stageJ <- run_or_resume_campaign(
  grid_path = broader_grid_path,
  defaults_path = stageJ_defaults_path,
  results_root = stageJ_defaults$campaign$results_root,
  report_root = stageJ_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose,
  resume_mode = resume_mode
)
stageJ <- extract_campaign_summary(
  stage_id = "J",
  profile_id = "J0_stageI_candidate",
  description = "Broader reconfirmation with Stage-I promoted candidate.",
  report_root = run_stageJ$report_root,
  results_root = run_stageJ$results_root,
  gate_cfg = gates$stageJ %||% list()
)
utils::write.csv(stageJ$summary, file.path(analysis_root, "tables", "stageJ_summary.csv"), row.names = FALSE)
utils::write.csv(stageJ$pair, file.path(analysis_root, "tables", "stageJ_pair_summary.csv"), row.names = FALSE)

stageK_summary <- data.frame(stringsAsFactors = FALSE)
stageK_failed_grid <- data.frame(stringsAsFactors = FALSE)
stageK_decision <- list(
  attempted = FALSE,
  pass = FALSE,
  winner_profile_id = NA_character_,
  winner_report_root = NA_character_,
  winner_results_root = NA_character_
)
stageK_winner_defaults <- NULL

if (!isTRUE(stageJ$gate$pass)) {
  stageK_failed_grid_path <- file.path(analysis_root, "config", "stageK_failed_root_grid.csv")
  stageK_failed_grid <- build_failed_root_grid(stageJ$pair, stageK_failed_grid_path)
  utils::write.csv(stageK_failed_grid, file.path(analysis_root, "tables", "stageK_failed_root_grid.csv"), row.names = FALSE)

  if (nrow(stageK_failed_grid) > 0L) {
    stageK_profiles <- yaml::read_yaml(stagek_profiles_path)
    profiles <- stageK_profiles$profiles %||% list()
    base_patch <- stageK_profiles$base_patch %||% list()
    stageK_base_defaults <- deep_merge(candidate_defaults, base_patch)
    rows <- list()
    defaults_map <- list()
    runs_map <- list()

    for (ii in seq_along(profiles)) {
      prof <- profiles[[ii]]
      prof_id <- as.character(prof$id %||% sprintf("K%02d", ii))
      prof_desc <- as.character(prof$description %||% prof_id)
      cfg_i <- deep_merge(stageK_base_defaults, prof$patch %||% list())
      cfg_i$campaign <- cfg_i$campaign %||% list()
      cfg_i$campaign$name <- paste0("qdesn_rhs_stageK__", prof_id)
      cfg_i$campaign$results_root <- file.path(results_root, "stageK", prof_id)
      cfg_i$campaign$reports_root <- file.path(report_root, "stageK", prof_id)

      defaults_i <- file.path(analysis_root, "config", sprintf("stageK_defaults_%s.yaml", prof_id))
      yaml::write_yaml(cfg_i, defaults_i)
      run_i <- run_or_resume_campaign(
        grid_path = stageK_failed_grid_path,
        defaults_path = defaults_i,
        results_root = cfg_i$campaign$results_root,
        report_root = cfg_i$campaign$reports_root,
        create_plots = create_plots,
        verbose = verbose,
        resume_mode = resume_mode
      )
      sum_i <- extract_campaign_summary(
        stage_id = "K",
        profile_id = prof_id,
        description = prof_desc,
        report_root = run_i$report_root,
        results_root = run_i$results_root,
        gate_cfg = gates$stageK %||% list()
      )
      rows[[length(rows) + 1L]] <- sum_i$summary
      defaults_map[[prof_id]] <- cfg_i
      runs_map[[prof_id]] <- run_i
    }

    stageK_summary <- do.call(rbind, rows)
    utils::write.csv(stageK_summary, file.path(analysis_root, "tables", "stageK_profile_matrix.csv"), row.names = FALSE)
    stageK_winner <- choose_winner(stageK_summary)
    winner_id <- as.character(stageK_winner$profile_id[1L])
    stageK_decision <- list(
      attempted = TRUE,
      pass = any(as.logical(stageK_summary$gate_pass)),
      winner_profile_id = winner_id,
      winner_report_root = as.character(stageK_winner$report_root[1L] %||% NA_character_),
      winner_results_root = as.character(stageK_winner$results_root[1L] %||% NA_character_),
      generated_at = as.character(Sys.time())
    )
    stageK_winner_defaults <- defaults_map[[winner_id]]
  } else {
    stageK_decision <- list(
      attempted = TRUE,
      pass = FALSE,
      winner_profile_id = NA_character_,
      winner_report_root = NA_character_,
      winner_results_root = NA_character_,
      generated_at = as.character(Sys.time()),
      reason = "stageJ_failed_but_no_failed_roots_selected"
    )
  }
}

jsonlite::write_json(
  stageK_decision,
  file.path(analysis_root, "manifest", "stageK_decision.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

# Stage L: promotion decision and broader reconfirmation fallback.
stageL_summary <- data.frame(stringsAsFactors = FALSE)
stageL_gate <- list(pass = FALSE)
promotion_written <- FALSE
promotion_source <- NA_character_

if (isTRUE(stageJ$gate$pass)) {
  promoted <- stageJ_defaults
  promoted$campaign$name <- "qdesn_mcmc_rhs_stageJKL_promoted"
  promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_stageJKL_promoted")
  promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_stageJKL_promoted")
  dir_create(dirname(promotion_defaults_path))
  yaml::write_yaml(promoted, promotion_defaults_path)
  promotion_written <- TRUE
  promotion_source <- "stageJ_direct"
  stageL_summary <- stageJ$summary
  stageL_summary$stage_id <- "L"
  stageL_summary$profile_id <- "L0_stageJ_direct"
  stageL_summary$description <- "Stage-J passed strict broader gate; direct promotion."
  stageL_gate <- stageJ$gate
} else if (isTRUE(stageK_decision$attempted) && isTRUE(stageK_decision$pass) && !is.null(stageK_winner_defaults)) {
  stageL_defaults <- stageK_winner_defaults
  stageL_defaults$campaign <- stageL_defaults$campaign %||% list()
  stageL_defaults$campaign$name <- "qdesn_rhs_stageL_broader_reconfirm"
  stageL_defaults$campaign$results_root <- file.path(results_root, "stageL")
  stageL_defaults$campaign$reports_root <- file.path(report_root, "stageL")
  stageL_defaults_path <- file.path(analysis_root, "config", "stageL_defaults.yaml")
  yaml::write_yaml(stageL_defaults, stageL_defaults_path)

  run_stageL <- run_or_resume_campaign(
    grid_path = broader_grid_path,
    defaults_path = stageL_defaults_path,
    results_root = stageL_defaults$campaign$results_root,
    report_root = stageL_defaults$campaign$reports_root,
    create_plots = create_plots,
    verbose = verbose,
    resume_mode = resume_mode
  )
  stageL <- extract_campaign_summary(
    stage_id = "L",
    profile_id = paste0("L0_reconfirm__", as.character(stageK_decision$winner_profile_id)),
    description = "Broader reconfirmation from Stage-K winner on failed-root fallback.",
    report_root = run_stageL$report_root,
    results_root = run_stageL$results_root,
    gate_cfg = gates$stageL %||% list()
  )
  stageL_summary <- stageL$summary
  stageL_gate <- stageL$gate
  utils::write.csv(stageL$pair, file.path(analysis_root, "tables", "stageL_pair_summary.csv"), row.names = FALSE)

  if (isTRUE(stageL$gate$pass)) {
    promoted <- stageL_defaults
    promoted$campaign$name <- "qdesn_mcmc_rhs_stageJKL_promoted"
    promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_stageJKL_promoted")
    promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_stageJKL_promoted")
    dir_create(dirname(promotion_defaults_path))
    yaml::write_yaml(promoted, promotion_defaults_path)
    promotion_written <- TRUE
    promotion_source <- "stageL_reconfirm_after_stageK"
  }
}

if (nrow(stageL_summary)) {
  utils::write.csv(stageL_summary, file.path(analysis_root, "tables", "stageL_summary.csv"), row.names = FALSE)
}

# Stage M: scaffold expansion artifacts for next wave.
dir_create(dirname(stagem_grid_path))
dir_create(dirname(stagem_defaults_template_path))
stageM_grid <- build_stageM_grid(stagem_cfg, out_path = stagem_grid_path)
stageM_defaults <- if (isTRUE(promotion_written) && file.exists(promotion_defaults_path)) {
  yaml::read_yaml(promotion_defaults_path)
} else {
  candidate_defaults
}
stageM_defaults$campaign <- stageM_defaults$campaign %||% list()
stageM_defaults$campaign$name <- "qdesn_mcmc_rhs_stageM_template"
stageM_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_stageM_template")
stageM_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_stageM_template")
yaml::write_yaml(stageM_defaults, stagem_defaults_template_path)

stageM_manifest <- list(
  generated_at = as.character(Sys.time()),
  grid_path = stagem_grid_path,
  defaults_template_path = stagem_defaults_template_path,
  n_roots = nrow(stageM_grid),
  promotion_written = isTRUE(promotion_written),
  promotion_source = promotion_source
)
jsonlite::write_json(
  stageM_manifest,
  file.path(analysis_root, "manifest", "stageM_scaffold_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

# Tracker + final manifest.
tracker_lines <- c(
  "# TRACK: QDESN RHS Stage-J/K/L/M Wave",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- analysis_root: `%s`", analysis_root),
  sprintf("- candidate_defaults: `%s`", candidate_defaults_path),
  sprintf("- broader_grid: `%s`", broader_grid_path),
  sprintf("- stageJ_pass: `%s`", if (isTRUE(stageJ$gate$pass)) "true" else "false"),
  sprintf("- stageK_attempted: `%s`", if (isTRUE(stageK_decision$attempted)) "true" else "false"),
  sprintf("- stageK_pass: `%s`", if (isTRUE(stageK_decision$pass)) "true" else "false"),
  sprintf("- stageK_winner: `%s`", as.character(stageK_decision$winner_profile_id %||% NA_character_)),
  sprintf("- stageL_pass: `%s`", if (isTRUE(stageL_gate$pass)) "true" else "false"),
  sprintf("- promotion_written: `%s`", if (isTRUE(promotion_written)) "true" else "false"),
  sprintf("- promotion_source: `%s`", as.character(promotion_source %||% "none")),
  sprintf("- promotion_defaults: `%s`", if (isTRUE(promotion_written)) promotion_defaults_path else "none"),
  sprintf("- stageM_grid: `%s`", stagem_grid_path),
  sprintf("- stageM_defaults_template: `%s`", stagem_defaults_template_path),
  "",
  "## Stage-J Summary",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageJ$summary))
if (nrow(stageK_summary)) {
  tracker_lines <- c(tracker_lines, "", "## Stage-K Profile Matrix", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageK_summary))
}
if (nrow(stageL_summary)) {
  tracker_lines <- c(tracker_lines, "", "## Stage-L Summary", "")
  tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageL_summary))
}
tracker_lines <- c(
  tracker_lines,
  "",
  "## Stage-M Scaffold",
  sprintf("- n_roots: `%d`", nrow(stageM_grid)),
  sprintf("- grid_path: `%s`", stagem_grid_path),
  sprintf("- defaults_template_path: `%s`", stagem_defaults_template_path)
)
dir_create(dirname(tracker_doc_path))
writeLines(tracker_lines, tracker_doc_path)

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    manifest_path = manifest_path,
    stageJ = list(summary = stageJ$summary, gate = stageJ$gate),
    stageK = list(summary = stageK_summary, decision = stageK_decision),
    stageL = list(summary = stageL_summary, gate = stageL_gate),
    promotion_written = promotion_written,
    promotion_source = promotion_source,
    promotion_defaults_path = if (isTRUE(promotion_written)) promotion_defaults_path else NULL,
    stageM = stageM_manifest,
    tracker_doc_path = tracker_doc_path
  ),
  file.path(analysis_root, "manifest", "stageJ_K_L_M_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Stage-J pass: %s\n", if (isTRUE(stageJ$gate$pass)) "yes" else "no"))
cat(sprintf("Stage-K attempted: %s\n", if (isTRUE(stageK_decision$attempted)) "yes" else "no"))
cat(sprintf("Stage-K pass: %s\n", if (isTRUE(stageK_decision$pass)) "yes" else "no"))
cat(sprintf("Stage-L pass: %s\n", if (isTRUE(stageL_gate$pass)) "yes" else "no"))
cat(sprintf("Promotion written: %s\n", if (isTRUE(promotion_written)) "yes" else "no"))
