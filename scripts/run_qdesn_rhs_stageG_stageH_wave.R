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

extract_run_paths <- function(report_root) {
  done_path <- file.path(report_root, "manifest", "campaign_completed.json")
  mani_path <- file.path(report_root, "manifest", "campaign_manifest.json")
  done <- if (file.exists(done_path)) jsonlite::fromJSON(done_path, simplifyVector = TRUE) else list()
  mani <- if (file.exists(mani_path)) jsonlite::fromJSON(mani_path, simplifyVector = TRUE) else list()
  list(
    report_root = normalizePath(report_root, winslash = "/", mustWork = TRUE),
    results_root = normalizePath(as.character(done$results_root %||% mani$results_root %||% ""), winslash = "/", mustWork = FALSE)
  )
}

select_blocker_rows <- function(df, selector) {
  if (!nrow(df)) return(df[0, , drop = FALSE])
  out <- df
  if ("scenario" %in% names(out)) out <- out[as.character(out$scenario) == as.character(selector$scenario), , drop = FALSE]
  if ("beta_prior_type" %in% names(out)) out <- out[as.character(out$beta_prior_type) == as.character(selector$beta_prior_type), , drop = FALSE]
  if ("seed" %in% names(out)) out <- out[as.integer(out$seed) == as.integer(selector$seed), , drop = FALSE]
  if ("reservoir_profile" %in% names(out)) out <- out[as.character(out$reservoir_profile) == as.character(selector$reservoir_profile), , drop = FALSE]
  if ("tau" %in% names(out)) out <- out[abs(as.numeric(out$tau) - as.numeric(selector$tau)) < 1e-12, , drop = FALSE]
  out
}

collect_blocker_metrics <- function(profile_group, profile_id, description, report_root, selector) {
  run_paths <- extract_run_paths(report_root)
  pair_df <- read_csv_safe(file.path(report_root, "tables", "campaign_pair_summary.csv"))
  signoff_df <- read_csv_safe(file.path(report_root, "tables", "campaign_method_signoff.csv"))
  chain_df <- read_csv_safe(file.path(report_root, "tables", "campaign_chain_summary.csv"))

  pair_row <- select_blocker_rows(pair_df, selector)
  if (nrow(pair_row)) pair_row <- pair_row[1L, , drop = FALSE]
  mcmc_signoff <- signoff_df[as.character(signoff_df$method) == "mcmc", , drop = FALSE]
  mcmc_signoff <- select_blocker_rows(mcmc_signoff, selector)
  if (nrow(mcmc_signoff)) mcmc_signoff <- mcmc_signoff[1L, , drop = FALSE]

  chain_sub <- select_blocker_rows(chain_df, selector)
  if (nrow(chain_sub) && "parameter" %in% names(chain_sub)) {
    chain_sub <- chain_sub[chain_sub$parameter %in% c("tau", "c2", "gamma", "sigma", "beta_norm"), , drop = FALSE]
  }

  root_id <- as.character(pair_row$root_id[1L] %||% mcmc_signoff$root_id[1L] %||% NA_character_)
  trace_path <- if (!is.na(root_id) && nzchar(root_id)) {
    file.path(run_paths$results_root, "roots", root_id, "fits", "mcmc", "progress_trace.csv")
  } else {
    ""
  }
  trace_df <- read_csv_safe(trace_path)
  if (nrow(trace_df)) {
    trace_df$profile_group <- profile_group
    trace_df$profile_id <- profile_id
    trace_df$report_root <- report_root
    trace_df$root_id <- root_id
  }

  row <- data.frame(
    profile_group = profile_group,
    profile_id = profile_id,
    description = description,
    report_root = run_paths$report_root,
    results_root = run_paths$results_root,
    root_id = root_id,
    pair_signoff_grade = as.character(pair_row$pair_signoff_grade[1L] %||% NA_character_),
    pair_comparison_eligible = as.logical(pair_row$pair_comparison_eligible[1L] %||% FALSE),
    both_finite_ok = as.logical(pair_row$both_finite_ok[1L] %||% FALSE),
    both_domain_ok = as.logical(pair_row$both_domain_ok[1L] %||% FALSE),
    runtime_ratio_mcmc_vs_vb = as.numeric(pair_row$runtime_ratio_mcmc_vs_vb[1L] %||% NA_real_),
    mcmc_signoff_grade = as.character(mcmc_signoff$signoff_grade[1L] %||% NA_character_),
    mcmc_signoff_reason = as.character(mcmc_signoff$signoff_reason[1L] %||% NA_character_),
    mcmc_min_ess_core = as.numeric(mcmc_signoff$mcmc_min_ess_core[1L] %||% NA_real_),
    mcmc_min_ess_rhs = as.numeric(mcmc_signoff$mcmc_min_ess_rhs[1L] %||% NA_real_),
    mcmc_max_geweke_absz_core = as.numeric(mcmc_signoff$mcmc_max_geweke_absz_core[1L] %||% NA_real_),
    mcmc_max_geweke_absz_rhs = as.numeric(mcmc_signoff$mcmc_max_geweke_absz_rhs[1L] %||% NA_real_),
    mcmc_max_half_drift_core = as.numeric(mcmc_signoff$mcmc_max_half_drift_core[1L] %||% NA_real_),
    mcmc_max_half_drift_rhs = as.numeric(mcmc_signoff$mcmc_max_half_drift_rhs[1L] %||% NA_real_),
    chain_tau_ess = if (nrow(chain_sub)) safe_num(chain_sub$ess[chain_sub$parameter == "tau"][1L]) else NA_real_,
    chain_c2_ess = if (nrow(chain_sub)) safe_num(chain_sub$ess[chain_sub$parameter == "c2"][1L]) else NA_real_,
    chain_tau_geweke = if (nrow(chain_sub)) safe_num(chain_sub$geweke_absz[chain_sub$parameter == "tau"][1L]) else NA_real_,
    chain_c2_geweke = if (nrow(chain_sub)) safe_num(chain_sub$geweke_absz[chain_sub$parameter == "c2"][1L]) else NA_real_,
    chain_tau_half_drift = if (nrow(chain_sub)) safe_num(chain_sub$half_drift[chain_sub$parameter == "tau"][1L]) else NA_real_,
    chain_c2_half_drift = if (nrow(chain_sub)) safe_num(chain_sub$half_drift[chain_sub$parameter == "c2"][1L]) else NA_real_,
    stringsAsFactors = FALSE
  )
  list(row = row, trace = trace_df)
}

manifest_path <- resolve_path(get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_stageG_H_manifest.yaml")), must_work = TRUE)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
reuse_stageg_table_path <- resolve_path(get_arg("--reuse-stageg-table", NULL), must_work = FALSE)
reuse_stageg_trace_path <- resolve_path(get_arg("--reuse-stageg-trace", NULL), must_work = FALSE)

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0(stamp, "__git-", git_sha)))[1L]

report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_stageG_stageH_wave", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_stageG_stageH_wave", run_tag)),
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
stage_g_cfg <- cfg$stage_g %||% list()
stage_h_cfg <- cfg$stage_h %||% list()

base_defaults_path <- resolve_path(inputs$base_defaults, must_work = TRUE)
profiles_path <- resolve_path(inputs$profiles, must_work = TRUE)
target_grid_path <- resolve_path(inputs$target_grid, must_work = TRUE)
broader_grid_path <- resolve_path(inputs$broader_grid, must_work = TRUE)
drift_e_root <- resolve_path(inputs$drift_e_report_root, must_work = TRUE)
stage_f_root <- resolve_path(inputs$stage_f_report_root, must_work = TRUE)
promotion_defaults_path <- resolve_path(outputs$promotion_defaults, must_work = FALSE)
tracker_doc_path <- resolve_path(outputs$tracker_doc, must_work = FALSE)
escalation_note_path <- resolve_path(outputs$escalation_note, must_work = FALSE)

target_grid <- read_csv_safe(target_grid_path)
if (!nrow(target_grid)) stop("Stage-G target grid is empty.", call. = FALSE)
selector <- as.list(target_grid[1L, , drop = FALSE])

# Step 1: Freeze baseline evidence
stagef_decision_path <- file.path(stage_f_root, "manifest", "step5_decision.json")
if (!file.exists(stagef_decision_path)) stop("Missing Stage-F decision JSON.", call. = FALSE)
stagef_decision <- jsonlite::fromJSON(stagef_decision_path, simplifyVector = TRUE)
drifte_stageE <- read_csv_safe(file.path(drift_e_root, "tables", "stageE_broader_summary.csv"))
if (!nrow(drifte_stageE)) stop("Missing Drift-E Stage-E summary.", call. = FALSE)
drifte_row <- drifte_stageE[1L, , drop = FALSE]

baseline_refs <- list(
  frozen_at = as.character(Sys.time()),
  git_sha = git_sha,
  manifest = manifest_path,
  drift_e_report_root = drift_e_root,
  drift_e_stageE_report_root = as.character(drifte_row$report_root[1L] %||% NA_character_),
  stage_f_report_root = stage_f_root,
  stage_f_step5_decision = stagef_decision,
  stage_f_broader_report_root = as.character(stagef_decision$broader_report_root %||% NA_character_)
)
jsonlite::write_json(
  baseline_refs,
  file.path(analysis_root, "manifest", "step1_frozen_baseline.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

baseline_rows <- list(
  collect_blocker_metrics("Drift-E", as.character(drifte_row$profile_id[1L] %||% "E_profile"), "Drift-E broader reconfirmation", as.character(drifte_row$report_root[1L]), selector)$row,
  collect_blocker_metrics("Stage-F", as.character(stagef_decision$winner_profile_id %||% "F0"), "Stage-F broader winner", as.character(stagef_decision$broader_report_root), selector)$row
)
baseline_table <- do.call(rbind, baseline_rows)
utils::write.csv(baseline_table, file.path(analysis_root, "tables", "step1_baseline_blocker_metrics.csv"), row.names = FALSE)

# Step 2: Forensic pack across Drift-E and Stage-F profiles
stagef_profiles <- read_csv_safe(file.path(stage_f_root, "tables", "step3_balanced_summary.csv"))
stagef_profiles <- stagef_profiles[grepl("^F", as.character(stagef_profiles$profile_id)), , drop = FALSE]

forensic_rows <- list()
forensic_traces <- list()

drift_pack <- collect_blocker_metrics(
  profile_group = "Drift-E",
  profile_id = as.character(drifte_row$profile_id[1L] %||% "E_profile"),
  description = as.character(drifte_row$description[1L] %||% "Drift-E broader"),
  report_root = as.character(drifte_row$report_root[1L]),
  selector = selector
)
forensic_rows[[length(forensic_rows) + 1L]] <- drift_pack$row
forensic_traces[[length(forensic_traces) + 1L]] <- drift_pack$trace

for (ii in seq_len(nrow(stagef_profiles))) {
  row_i <- stagef_profiles[ii, , drop = FALSE]
  pack_i <- collect_blocker_metrics(
    profile_group = "Stage-F",
    profile_id = as.character(row_i$profile_id[1L]),
    description = as.character(row_i$description[1L] %||% ""),
    report_root = as.character(row_i$report_root[1L]),
    selector = selector
  )
  forensic_rows[[length(forensic_rows) + 1L]] <- pack_i$row
  forensic_traces[[length(forensic_traces) + 1L]] <- pack_i$trace
}

forensic_table <- do.call(rbind, forensic_rows)
forensic_trace_long <- do.call(rbind, forensic_traces[!vapply(forensic_traces, is.null, logical(1))])
utils::write.csv(forensic_table, file.path(analysis_root, "tables", "step2_failure_forensic_metrics.csv"), row.names = FALSE)
utils::write.csv(forensic_trace_long, file.path(analysis_root, "tables", "step2_failure_forensic_trace_long.csv"), row.names = FALSE)

if (isTRUE(create_plots) && nrow(forensic_trace_long) && requireNamespace("ggplot2", quietly = TRUE)) {
  trace_plot <- forensic_trace_long
  if (!("step" %in% names(trace_plot)) && "iter" %in% names(trace_plot)) trace_plot$step <- trace_plot$iter
  rhs_trace <- trace_plot[, intersect(c("profile_group", "profile_id", "step", "rhs_tau", "rhs_c2"), names(trace_plot)), drop = FALSE]
  rhs_trace <- rhs_trace[is.finite(rhs_trace$step), , drop = FALSE]
  if (nrow(rhs_trace)) {
    long_rows <- list(
      data.frame(profile = paste(rhs_trace$profile_group, rhs_trace$profile_id, sep = "::"), step = rhs_trace$step, metric = "rhs_tau", value = rhs_trace$rhs_tau, stringsAsFactors = FALSE),
      data.frame(profile = paste(rhs_trace$profile_group, rhs_trace$profile_id, sep = "::"), step = rhs_trace$step, metric = "rhs_c2", value = rhs_trace$rhs_c2, stringsAsFactors = FALSE)
    )
    long_df <- do.call(rbind, long_rows)
    long_df <- long_df[is.finite(long_df$value) & long_df$value > 0, , drop = FALSE]
    if (nrow(long_df)) {
      p <- ggplot2::ggplot(long_df, ggplot2::aes(x = step, y = value, colour = profile)) +
        ggplot2::geom_line(linewidth = 0.7) +
        ggplot2::scale_y_log10() +
        ggplot2::facet_wrap(~ metric, scales = "free_y", ncol = 1) +
        ggplot2::labs(title = "Failure Forensic: Blocker Root RHS Traces", x = "MCMC step", y = "value (log scale)", colour = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "bottom")
      ggplot2::ggsave(file.path(analysis_root, "plots", "step2_failure_forensic_rhs_traces.png"), p, width = 10.5, height = 7.0, dpi = 150)
    }
  }
}

# Step 3-6: Stage-G single-root profile matrix
base_defaults <- yaml::read_yaml(base_defaults_path)
profiles_cfg <- yaml::read_yaml(profiles_path)
profiles_base_patch <- profiles_cfg$base_patch %||% list()
profiles <- profiles_cfg$profiles %||% list()
if (!length(profiles)) stop("No Stage-G profiles defined.", call. = FALSE)

cfg_base <- deep_merge(base_defaults, profiles_base_patch)
stageg_rows <- list()
stageg_traces <- list()
profile_defaults_map <- list()

for (ii in seq_along(profiles)) {
  prof <- profiles[[ii]]
  prof_id <- as.character(prof$id %||% sprintf("G%02d", ii))
  prof_desc <- as.character(prof$description %||% prof_id)
  cfg_i <- deep_merge(cfg_base, prof$patch %||% list())
  cfg_i$campaign <- cfg_i$campaign %||% list()
  cfg_i$campaign$name <- paste0("qdesn_rhs_stageG__", prof_id)
  cfg_i$campaign$results_root <- file.path(results_root, "stageG", prof_id)
  cfg_i$campaign$reports_root <- file.path(report_root, "stageG", prof_id)

  defaults_i <- file.path(analysis_root, "config", sprintf("stageG_defaults_%s.yaml", prof_id))
  yaml::write_yaml(cfg_i, defaults_i)
  profile_defaults_map[[prof_id]] <- cfg_i
}

if (!is.null(reuse_stageg_table_path) && !file.exists(reuse_stageg_table_path)) {
  stop(sprintf("Missing --reuse-stageg-table file: %s", reuse_stageg_table_path), call. = FALSE)
}

if (is.null(reuse_stageg_table_path)) {
  for (ii in seq_along(profiles)) {
    prof <- profiles[[ii]]
    prof_id <- as.character(prof$id %||% sprintf("G%02d", ii))
    prof_desc <- as.character(prof$description %||% prof_id)
    cfg_i <- profile_defaults_map[[prof_id]]
    defaults_i <- file.path(analysis_root, "config", sprintf("stageG_defaults_%s.yaml", prof_id))

    run_i <- exdqlm:::qdesn_validation_run_campaign(
      grid_path = target_grid_path,
      defaults_path = defaults_i,
      results_root = cfg_i$campaign$results_root,
      report_root = cfg_i$campaign$reports_root,
      create_plots = create_plots,
      verbose = verbose
    )
    pack_i <- collect_blocker_metrics(
      profile_group = "Stage-G",
      profile_id = prof_id,
      description = prof_desc,
      report_root = run_i$report_root,
      selector = selector
    )
    stageg_rows[[length(stageg_rows) + 1L]] <- pack_i$row
    stageg_traces[[length(stageg_traces) + 1L]] <- pack_i$trace
  }
  stageg_table <- do.call(rbind, stageg_rows)
  trace_parts <- stageg_traces[!vapply(stageg_traces, is.null, logical(1))]
  stageg_trace_long <- if (length(trace_parts)) {
    do.call(rbind, trace_parts)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
} else {
  stageg_table <- read_csv_safe(reuse_stageg_table_path)
  if (!nrow(stageg_table)) {
    stop("Reused Stage-G table is empty.", call. = FALSE)
  }
  if (!is.null(reuse_stageg_trace_path) && file.exists(reuse_stageg_trace_path)) {
    stageg_trace_long <- read_csv_safe(reuse_stageg_trace_path)
  } else {
    stageg_trace_long <- data.frame(stringsAsFactors = FALSE)
  }
  expected_profiles <- names(profile_defaults_map)
  missing_profiles <- setdiff(expected_profiles, unique(as.character(stageg_table$profile_id)))
  if (length(missing_profiles)) {
    stop(
      sprintf(
        "Reused Stage-G table missing profile rows for: %s",
        paste(missing_profiles, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

required_stageg_cols <- c(
  "profile_group", "profile_id", "description", "report_root", "results_root",
  "root_id", "pair_signoff_grade", "pair_comparison_eligible", "both_finite_ok",
  "both_domain_ok", "runtime_ratio_mcmc_vs_vb", "mcmc_signoff_grade",
  "mcmc_signoff_reason", "mcmc_min_ess_core", "mcmc_min_ess_rhs",
  "mcmc_max_geweke_absz_core", "mcmc_max_geweke_absz_rhs",
  "mcmc_max_half_drift_core", "mcmc_max_half_drift_rhs"
)
missing_stageg_cols <- setdiff(required_stageg_cols, names(stageg_table))
if (length(missing_stageg_cols)) {
  stop(sprintf("Stage-G table missing required columns: %s", paste(missing_stageg_cols, collapse = ", ")), call. = FALSE)
}

stageg_gated <- exdqlm:::.qdesn_rhs_stageg_gate_eval(
  stageg_df = stageg_table,
  baseline_profile_id = as.character(stage_g_cfg$baseline_profile_id %||% "G0_baseline"),
  gate_cfg = stage_g_cfg$strict_gate %||% list()
)
utils::write.csv(stageg_gated, file.path(analysis_root, "tables", "stageG_profile_matrix.csv"), row.names = FALSE)
utils::write.csv(stageg_trace_long, file.path(analysis_root, "tables", "stageG_trace_long.csv"), row.names = FALSE)

baseline_id <- as.character(stage_g_cfg$baseline_profile_id %||% "G0_baseline")
stageg_candidates <- stageg_gated[stageg_gated$profile_id != baseline_id & as.logical(stageg_gated$gate_pass), , drop = FALSE]
stageg_pass <- nrow(stageg_candidates) > 0L
if (isTRUE(stageg_pass)) {
  ord <- with(stageg_candidates, order(
    as.numeric(mcmc_max_geweke_absz_rhs),
    as.numeric(mcmc_max_half_drift_rhs),
    -as.numeric(mcmc_min_ess_rhs),
    as.numeric(runtime_ratio_mcmc_vs_vb)
  ))
  stageg_winner <- stageg_candidates[ord[1L], , drop = FALSE]
} else {
  stageg_winner <- stageg_gated[stageg_gated$profile_id == baseline_id, , drop = FALSE]
}

stageg_decision <- list(
  stageg_pass = isTRUE(stageg_pass),
  baseline_profile_id = baseline_id,
  winner_profile_id = as.character(stageg_winner$profile_id[1L] %||% NA_character_),
  winner_report_root = as.character(stageg_winner$report_root[1L] %||% NA_character_),
  generated_at = as.character(Sys.time())
)
jsonlite::write_json(stageg_decision, file.path(analysis_root, "manifest", "stageG_decision.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

# Step 8-9: Stage-H reconfirmation on winner and promotion/escalation
stageh_pass <- FALSE
promotion_written <- FALSE
stageh_report_root <- NA_character_
stageh_results_root <- NA_character_
escalation_lines <- c(
  "# Stage-G/H Escalation",
  "",
  "Stage-H promotion gate failed or Stage-G had no strict-gate winner.",
  "",
  "Recommended next kernel step:",
  "1. Delayed-rejection on transformed `(log_tau, log_c2)` block.",
  "2. Independent proposal fallback on transformed RHS block from short pilot covariance.",
  "3. Keep RHS guardrails unchanged during escalation runs."
)

if (isTRUE(stageg_pass)) {
  winner_id <- as.character(stageg_winner$profile_id[1L])
  winner_defaults <- profile_defaults_map[[winner_id]]
  winner_defaults$campaign <- winner_defaults$campaign %||% list()
  winner_defaults$campaign$name <- paste0("qdesn_rhs_stageH__", winner_id)
  winner_defaults$campaign$results_root <- file.path(results_root, "stageH", winner_id)
  winner_defaults$campaign$reports_root <- file.path(report_root, "stageH", winner_id)
  winner_defaults_path <- file.path(analysis_root, "config", sprintf("stageH_winner_defaults_%s.yaml", winner_id))
  yaml::write_yaml(winner_defaults, winner_defaults_path)

  run_h <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = broader_grid_path,
    defaults_path = winner_defaults_path,
    results_root = winner_defaults$campaign$results_root,
    report_root = winner_defaults$campaign$reports_root,
    create_plots = create_plots,
    verbose = verbose
  )
  stageh_report_root <- run_h$report_root
  stageh_results_root <- run_h$results_root

  pair_h <- read_csv_safe(file.path(run_h$report_root, "tables", "campaign_pair_summary.csv"))
  utils::write.csv(pair_h, file.path(analysis_root, "tables", "stageH_pair_summary.csv"), row.names = FALSE)
  n_pairs <- nrow(pair_h)
  n_fail <- sum(toupper(as.character(pair_h$pair_signoff_grade)) == "FAIL", na.rm = TRUE)
  n_eligible <- sum(as.logical(pair_h$pair_comparison_eligible), na.rm = TRUE)
  all_fd <- if (n_pairs) {
    all(as.logical(pair_h$both_finite_ok)) && all(as.logical(pair_h$both_domain_ok))
  } else {
    FALSE
  }
  pass_zero_fail <- !isTRUE(stage_h_cfg$require_zero_fail %||% TRUE) || n_fail == 0L
  pass_eligible <- !isTRUE(stage_h_cfg$require_all_eligible %||% TRUE) || (n_pairs > 0L && n_eligible == n_pairs)
  pass_fd <- !isTRUE(stage_h_cfg$require_all_finite_domain %||% TRUE) || isTRUE(all_fd)
  stageh_pass <- isTRUE(pass_zero_fail) && isTRUE(pass_eligible) && isTRUE(pass_fd)

  stageh_gate <- list(
    stageh_pass = stageh_pass,
    n_pairs = n_pairs,
    n_pair_fail = n_fail,
    n_pair_eligible = n_eligible,
    all_finite_domain = all_fd
  )
  jsonlite::write_json(stageh_gate, file.path(analysis_root, "manifest", "stageH_gate.json"), pretty = TRUE, auto_unbox = TRUE, null = "null")

  if (isTRUE(stageh_pass)) {
    promoted <- winner_defaults
    promoted$campaign$name <- "qdesn_mcmc_rhs_stageGH_candidate"
    promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_stageGH_candidate")
    promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_stageGH_candidate")
    dir_create(dirname(promotion_defaults_path))
    yaml::write_yaml(promoted, promotion_defaults_path)
    promotion_written <- TRUE
  }
}

if (!isTRUE(promotion_written)) {
  dir_create(dirname(escalation_note_path))
  writeLines(escalation_lines, escalation_note_path)
}

tracker_lines <- c(
  "# TRACK: QDESN RHS Stage-G/Stage-H Wave",
  "",
  sprintf("- run_tag: `%s`", run_tag),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- analysis_root: `%s`", analysis_root),
  sprintf("- stageG_mode: `%s`", if (is.null(reuse_stageg_table_path)) "fresh_runs" else "reuse_existing_table"),
  sprintf("- stageG_reuse_table: `%s`", if (is.null(reuse_stageg_table_path)) "none" else reuse_stageg_table_path),
  sprintf("- baseline_frozen: `%s`", "yes"),
  sprintf("- forensic_pack: `%s`", file.path(analysis_root, "tables", "step2_failure_forensic_metrics.csv")),
  sprintf("- stageG_pass: `%s`", if (isTRUE(stageg_pass)) "true" else "false"),
  sprintf("- stageG_winner_profile_id: `%s`", as.character(stageg_decision$winner_profile_id %||% NA_character_)),
  sprintf("- stageH_pass: `%s`", if (isTRUE(stageh_pass)) "true" else "false"),
  sprintf("- promotion_written: `%s`", if (isTRUE(promotion_written)) "true" else "false"),
  sprintf("- promoted_defaults: `%s`", if (isTRUE(promotion_written)) promotion_defaults_path else "none"),
  sprintf("- escalation_note: `%s`", if (isTRUE(promotion_written)) "none" else escalation_note_path),
  "",
  "## Stage-G Table",
  ""
)
tracker_lines <- c(tracker_lines, exdqlm:::.qdesn_validation_df_to_markdown(stageg_gated))
if (file.exists(file.path(analysis_root, "tables", "stageH_pair_summary.csv"))) {
  tracker_lines <- c(tracker_lines, "", "## Stage-H Pair Summary", "")
  tracker_lines <- c(
    tracker_lines,
    exdqlm:::.qdesn_validation_df_to_markdown(utils::head(read_csv_safe(file.path(analysis_root, "tables", "stageH_pair_summary.csv")), 12L))
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
    stageg_mode = if (is.null(reuse_stageg_table_path)) "fresh_runs" else "reuse_existing_table",
    stageg_reuse_table = reuse_stageg_table_path,
    stageg = stageg_decision,
    stageh_pass = stageh_pass,
    promotion_written = promotion_written,
    promotion_defaults_path = if (isTRUE(promotion_written)) promotion_defaults_path else NULL,
    stageh_report_root = stageh_report_root,
    stageh_results_root = stageh_results_root,
    tracker_doc_path = tracker_doc_path,
    escalation_note_path = if (isTRUE(promotion_written)) NULL else escalation_note_path
  ),
  file.path(analysis_root, "manifest", "stageG_stageH_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Stage-G pass: %s\n", if (isTRUE(stageg_pass)) "yes" else "no"))
cat(sprintf("Stage-H pass: %s\n", if (isTRUE(stageh_pass)) "yes" else "no"))
cat(sprintf("Promotion written: %s\n", if (isTRUE(promotion_written)) "yes" else "no"))
