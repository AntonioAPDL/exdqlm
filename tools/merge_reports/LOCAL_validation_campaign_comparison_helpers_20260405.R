source("tools/merge_reports/LOCAL_validation_campaign_assembly_helpers_20260405.R")

vc_repo_root_20260405 <- function() {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

vc_normalize_repo_path_20260405 <- function(path) {
  if (is.null(path) || length(path) < 1L || is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }

  if (grepl("^/", path)) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }

  normalizePath(file.path(vc_repo_root_20260405(), path), winslash = "/", mustWork = FALSE)
}

vc_rel_repo_path_20260405 <- function(path) {
  abs_path <- vc_normalize_repo_path_20260405(path)
  if (is.na(abs_path)) {
    return(NA_character_)
  }

  sub(paste0("^", vc_repo_root_20260405(), "/?"), "", abs_path)
}

vc_run_root_from_fit_path_20260405 <- function(path) {
  fit_path <- vc_normalize_repo_path_20260405(path)
  if (is.na(fit_path) || !grepl("/fits/", fit_path, fixed = TRUE)) {
    return(NA_character_)
  }

  sub("/fits/.*$", "", fit_path)
}

vc_truthy_20260405 <- function(x) {
  if (is.logical(x)) {
    return(x)
  }

  x_chr <- toupper(as.character(x))
  out <- x_chr %in% c("TRUE", "T", "1", "YES")
  out[is.na(x) | x_chr == ""] <- NA
  out
}

vc_numeric_or_na_20260405 <- function(x) {
  suppressWarnings(as.numeric(x))
}

vc_character_or_na_20260405 <- function(x) {
  out <- as.character(x)
  out[is.na(out) | out == ""] <- NA_character_
  out
}

vc_gate_match_20260405 <- function(selected_gate, source_gate) {
  if (is.na(source_gate) || !nzchar(source_gate)) {
    return(NA)
  }
  identical(as.character(selected_gate), as.character(source_gate))
}

vc_make_method_id_20260405 <- function(inference, model) {
  paste(inference, model, sep = "__")
}

vc_pick_candidate_health_row_20260405 <- function(df, sel_row) {
  fit_path <- vc_normalize_repo_path_20260405(sel_row$selected_fit_path[[1]])

  if ("candidate_path" %in% names(df)) {
    candidate_paths <- vapply(
      df$candidate_path,
      vc_normalize_repo_path_20260405,
      FUN.VALUE = character(1)
    )
    idx <- which(!is.na(candidate_paths) & candidate_paths == fit_path)
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "candidate_path"))
    }
  }

  if ("variant" %in% names(df)) {
    idx <- which(as.character(df$variant) == as.character(sel_row$selected_variant_tag[[1]]))
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "variant"))
    }
  }

  if ("candidate_path" %in% names(df)) {
    idx <- which(!is.na(df$candidate_path) & nzchar(as.character(df$candidate_path)))
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "only_nonempty_candidate_path"))
    }
  }

  if (nrow(df) == 1L) {
    return(list(index = 1L, selector = "singleton"))
  }

  stop(sprintf(
    "Could not resolve a unique selected row in %s for %s",
    sel_row$selected_health_path[[1]],
    sel_row$case_key[[1]]
  ))
}

vc_resolve_summary_source_path_20260405 <- function(sel_row) {
  summary_path <- vc_normalize_repo_path_20260405(sel_row$selected_summary_path[[1]])
  if (!is.na(summary_path) &&
      file.exists(summary_path) &&
      grepl("summary", basename(summary_path), fixed = TRUE)) {
    return(summary_path)
  }

  if (identical(sel_row$selected_pool[[1]], "static_residual_broad_default")) {
    fallback <- file.path(
      vc_repo_root_20260405(),
      "tools/merge_reports",
      sprintf("LOCAL_static_case_health_summary_%s.csv", sel_row$selected_variant_tag[[1]])
    )
    fallback <- normalizePath(fallback, winslash = "/", mustWork = FALSE)
    if (file.exists(fallback)) {
      return(fallback)
    }
  }

  NA_character_
}

vc_pick_summary_row_20260405 <- function(df, sel_row) {
  fit_path <- vc_normalize_repo_path_20260405(sel_row$selected_fit_path[[1]])

  if ("candidate_path" %in% names(df)) {
    candidate_paths <- vapply(
      df$candidate_path,
      vc_normalize_repo_path_20260405,
      FUN.VALUE = character(1)
    )
    idx <- which(!is.na(candidate_paths) & candidate_paths == fit_path)
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "candidate_path"))
    }
  }

  if ("queue_id" %in% names(df)) {
    idx <- which(vc_numeric_or_na_20260405(df$queue_id) == vc_numeric_or_na_20260405(sel_row$row_id[[1]]))
    if ("variant_tag" %in% names(df)) {
      idx <- idx[as.character(df$variant_tag[idx]) == as.character(sel_row$selected_variant_tag[[1]])]
    }
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "queue_id_variant_tag"))
    }
  }

  if ("variant_tag" %in% names(df)) {
    idx <- which(as.character(df$variant_tag) == as.character(sel_row$selected_variant_tag[[1]]))
    if (length(idx) == 1L) {
      return(list(index = idx, selector = "variant_tag"))
    }
  }

  stop(sprintf(
    "Could not resolve a unique summary row in %s for %s",
    sel_row$selected_summary_path[[1]],
    sel_row$case_key[[1]]
  ))
}

vc_extract_from_summary_row_20260405 <- function(sel_row, summary_path) {
  df <- read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE)
  picked <- vc_pick_summary_row_20260405(df, sel_row)
  row <- df[picked$index, , drop = FALSE]

  run_root <- vc_run_root_from_fit_path_20260405(sel_row$selected_fit_path[[1]])
  root_id <- if ("case_id" %in% names(row)) vc_character_or_na_20260405(row$case_id[[1]]) else vc_rel_repo_path_20260405(run_root)

  data.frame(
    diagnostic_source_type = "summary_row_csv",
    diagnostic_row_selector = picked$selector,
    run_root = run_root,
    run_root_rel = vc_rel_repo_path_20260405(run_root),
    root_id = root_id,
    method = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "::"),
    signoff_grade_source = vc_character_or_na_20260405(row$gate_overall[[1]]),
    source_gate_matches_selected = vc_gate_match_20260405(sel_row$gate_overall[[1]], row$gate_overall[[1]]),
    comparison_eligible = vc_truthy_20260405(row$healthy[[1]]),
    convergence_certified = vc_truthy_20260405(row$healthy[[1]]),
    signoff_reason = vc_character_or_na_20260405(row$unhealthy_reason[[1]]),
    status_source = "SUCCESS",
    finite_ok = NA,
    domain_ok = NA,
    execution_healthy_source = vc_truthy_20260405(row$healthy[[1]]),
    vb_converged = NA,
    vb_stop_reason = NA_character_,
    vb_trace_length = NA_real_,
    vb_elbo_tail_rel_range = NA_real_,
    vb_elbo_tail_rel_drift = NA_real_,
    vb_sigma_tail_rel_range = NA_real_,
    vb_gamma_tail_rel_range = NA_real_,
    vb_s_tail_rel_range = NA_real_,
    vb_delta_state_last = NA_real_,
    vb_delta_sigma_last = NA_real_,
    vb_delta_gamma_last = NA_real_,
    vb_delta_s_last = NA_real_,
    vb_ld_trace_rows = NA_real_,
    vb_ld_local_mode_pass = NA,
    vb_ld_committed_stable_tail = NA,
    vb_ld_candidate_local_pass_rate_tail = NA_real_,
    vb_ld_committed_local_pass_rate_tail = NA_real_,
    vb_ld_mode_fallback_rate = NA_real_,
    vb_ld_stabilized_rate_tail = NA_real_,
    vb_rhs_collapse_flag = NA,
    vb_rhs_tau_near_zero = NA,
    vb_rhs_beta_collapse = NA,
    vb_rhs_tau = NA_real_,
    vb_rhs_c2 = NA_real_,
    vb_rhs_lambda_mean = NA_real_,
    mh_kernel = NA_character_,
    kernel_exact = NA,
    rhs_collapse_flag = if ("rhs_collapse_flag" %in% names(row)) vc_truthy_20260405(row$rhs_collapse_flag[[1]]) else NA,
    rhs_collapse_sources = NA_character_,
    n_keep = NA_real_,
    n_burn = NA_real_,
    n_mcmc = NA_real_,
    ess_sigma = NA_real_,
    ess_gamma = NA_real_,
    ess_sigma_per1k = if ("ess_sigma_per1k_cand" %in% names(row)) vc_numeric_or_na_20260405(row$ess_sigma_per1k_cand[[1]]) else NA_real_,
    ess_gamma_per1k = if ("ess_gamma_per1k_cand" %in% names(row)) vc_numeric_or_na_20260405(row$ess_gamma_per1k_cand[[1]]) else NA_real_,
    acf1_sigma = if ("acf1_sigma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$acf1_sigma_cand[[1]]) else NA_real_,
    acf1_gamma = if ("acf1_gamma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$acf1_gamma_cand[[1]]) else NA_real_,
    geweke_sigma = if ("geweke_sigma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$geweke_sigma_cand[[1]]) else NA_real_,
    geweke_gamma = if ("geweke_gamma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$geweke_gamma_cand[[1]]) else NA_real_,
    half_drift_sigma = if ("half_drift_sigma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$half_drift_sigma_cand[[1]]) else NA_real_,
    half_drift_gamma = if ("half_drift_gamma_cand" %in% names(row)) vc_numeric_or_na_20260405(row$half_drift_gamma_cand[[1]]) else NA_real_,
    accept_keep = NA_real_,
    accept_burn = NA_real_,
    accept_overall = NA_real_,
    gate_ess_sigma = NA_character_,
    gate_acf1_sigma = NA_character_,
    gate_geweke_sigma = NA_character_,
    gate_half_drift_sigma = NA_character_,
    gate_ess_gamma = NA_character_,
    gate_acf1_gamma = NA_character_,
    gate_geweke_gamma = NA_character_,
    gate_half_drift_gamma = NA_character_,
    gate_sigma = vc_character_or_na_20260405(row$gate_overall[[1]]),
    gate_gamma = if (grepl("ex", sel_row$model[[1]], fixed = TRUE)) vc_character_or_na_20260405(row$gate_overall[[1]]) else NA_character_,
    stringsAsFactors = FALSE
  )
}

vc_extract_from_method_signoff_20260405 <- function(sel_row) {
  path <- vc_normalize_repo_path_20260405(sel_row$selected_health_path[[1]])
  df <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)

  idx <- df$inference == sel_row$inference[[1]] &
    df$model == sel_row$model[[1]]

  if ("root_kind" %in% names(df)) {
    idx <- idx & df$root_kind == sel_row$root_kind[[1]]
  }
  if ("family" %in% names(df)) {
    idx <- idx & df$family == sel_row$family[[1]]
  }
  if ("fit_size" %in% names(df)) {
    idx <- idx & vc_numeric_or_na_20260405(df$fit_size) == vc_numeric_or_na_20260405(sel_row$fit_size[[1]])
  }

  tau_numeric <- suppressWarnings(as.numeric(sub("p", ".", sel_row$tau_label[[1]], fixed = TRUE)))
  if ("tau" %in% names(df) && !is.na(tau_numeric)) {
    idx <- idx & abs(vc_numeric_or_na_20260405(df$tau) - tau_numeric) < 1e-12
  }

  match_df <- df[idx, , drop = FALSE]
  if (nrow(match_df) != 1L) {
    stop(sprintf(
      "Expected exactly one method_signoff_long row for %s, found %d",
      sel_row$case_key[[1]],
      nrow(match_df)
    ))
  }

  row <- match_df[1, , drop = FALSE]
  run_root <- vc_run_root_from_fit_path_20260405(sel_row$selected_fit_path[[1]])

  data.frame(
    diagnostic_source_type = "method_signoff_long",
    diagnostic_row_selector = "inference_model",
    run_root = run_root,
    run_root_rel = vc_rel_repo_path_20260405(run_root),
    root_id = vc_character_or_na_20260405(row$root_id[[1]]),
    method = vc_character_or_na_20260405(row$method[[1]]),
    signoff_grade_source = vc_character_or_na_20260405(row$signoff_grade[[1]]),
    source_gate_matches_selected = NA,
    comparison_eligible = vc_truthy_20260405(row$comparison_eligible[[1]]),
    convergence_certified = vc_truthy_20260405(row$convergence_certified[[1]]),
    signoff_reason = vc_character_or_na_20260405(row$signoff_reason[[1]]),
    status_source = vc_character_or_na_20260405(row$status[[1]]),
    finite_ok = vc_truthy_20260405(row$finite_ok[[1]]),
    domain_ok = vc_truthy_20260405(row$domain_ok[[1]]),
    execution_healthy_source = vc_truthy_20260405(row$execution_healthy[[1]]),
    vb_converged = vc_truthy_20260405(row$vb_converged[[1]]),
    vb_stop_reason = vc_character_or_na_20260405(row$vb_stop_reason[[1]]),
    vb_trace_length = vc_numeric_or_na_20260405(row$vb_trace_length[[1]]),
    vb_elbo_tail_rel_range = vc_numeric_or_na_20260405(row$vb_elbo_tail_rel_range[[1]]),
    vb_elbo_tail_rel_drift = vc_numeric_or_na_20260405(row$vb_elbo_tail_rel_drift[[1]]),
    vb_sigma_tail_rel_range = vc_numeric_or_na_20260405(row$vb_sigma_tail_rel_range[[1]]),
    vb_gamma_tail_rel_range = vc_numeric_or_na_20260405(row$vb_gamma_tail_rel_range[[1]]),
    vb_s_tail_rel_range = vc_numeric_or_na_20260405(row$vb_s_tail_rel_range[[1]]),
    vb_delta_state_last = vc_numeric_or_na_20260405(row$vb_delta_state_last[[1]]),
    vb_delta_sigma_last = vc_numeric_or_na_20260405(row$vb_delta_sigma_last[[1]]),
    vb_delta_gamma_last = vc_numeric_or_na_20260405(row$vb_delta_gamma_last[[1]]),
    vb_delta_s_last = vc_numeric_or_na_20260405(row$vb_delta_s_last[[1]]),
    vb_ld_trace_rows = vc_numeric_or_na_20260405(row$vb_ld_trace_rows[[1]]),
    vb_ld_local_mode_pass = vc_truthy_20260405(row$vb_ld_local_mode_pass[[1]]),
    vb_ld_committed_stable_tail = vc_truthy_20260405(row$vb_ld_committed_stable_tail[[1]]),
    vb_ld_candidate_local_pass_rate_tail = vc_numeric_or_na_20260405(row$vb_ld_candidate_local_pass_rate_tail[[1]]),
    vb_ld_committed_local_pass_rate_tail = vc_numeric_or_na_20260405(row$vb_ld_committed_local_pass_rate_tail[[1]]),
    vb_ld_mode_fallback_rate = vc_numeric_or_na_20260405(row$vb_ld_mode_fallback_rate[[1]]),
    vb_ld_stabilized_rate_tail = vc_numeric_or_na_20260405(row$vb_ld_stabilized_rate_tail[[1]]),
    vb_rhs_collapse_flag = vc_truthy_20260405(row$vb_rhs_collapse_flag[[1]]),
    vb_rhs_tau_near_zero = vc_truthy_20260405(row$vb_rhs_tau_near_zero[[1]]),
    vb_rhs_beta_collapse = vc_truthy_20260405(row$vb_rhs_beta_collapse[[1]]),
    vb_rhs_tau = vc_numeric_or_na_20260405(row$vb_rhs_tau[[1]]),
    vb_rhs_c2 = vc_numeric_or_na_20260405(row$vb_rhs_c2[[1]]),
    vb_rhs_lambda_mean = vc_numeric_or_na_20260405(row$vb_rhs_lambda_mean[[1]]),
    mh_kernel = NA_character_,
    kernel_exact = vc_truthy_20260405(row$mcmc_kernel_exact[[1]]),
    rhs_collapse_flag = vc_truthy_20260405(row$vb_rhs_collapse_flag[[1]]),
    rhs_collapse_sources = NA_character_,
    n_keep = vc_numeric_or_na_20260405(row$mcmc_n_keep[[1]]),
    n_burn = NA_real_,
    n_mcmc = vc_numeric_or_na_20260405(row$mcmc_n_keep[[1]]),
    ess_sigma = vc_numeric_or_na_20260405(row$mcmc_ess_sigma[[1]]),
    ess_gamma = vc_numeric_or_na_20260405(row$mcmc_ess_gamma[[1]]),
    ess_sigma_per1k = if ("mcmc_ess_sigma" %in% names(row) && !is.na(row$mcmc_n_keep[[1]]) && row$mcmc_n_keep[[1]] > 0) vc_numeric_or_na_20260405(row$mcmc_ess_sigma[[1]]) / vc_numeric_or_na_20260405(row$mcmc_n_keep[[1]]) * 1000 else NA_real_,
    ess_gamma_per1k = if ("mcmc_ess_gamma" %in% names(row) && !is.na(row$mcmc_n_keep[[1]]) && row$mcmc_n_keep[[1]] > 0) vc_numeric_or_na_20260405(row$mcmc_ess_gamma[[1]]) / vc_numeric_or_na_20260405(row$mcmc_n_keep[[1]]) * 1000 else NA_real_,
    acf1_sigma = vc_numeric_or_na_20260405(row$mcmc_acf1_sigma[[1]]),
    acf1_gamma = vc_numeric_or_na_20260405(row$mcmc_acf1_gamma[[1]]),
    geweke_sigma = vc_numeric_or_na_20260405(row$mcmc_geweke_absz_sigma[[1]]),
    geweke_gamma = vc_numeric_or_na_20260405(row$mcmc_geweke_absz_gamma[[1]]),
    half_drift_sigma = vc_numeric_or_na_20260405(row$mcmc_half_drift_sigma[[1]]),
    half_drift_gamma = vc_numeric_or_na_20260405(row$mcmc_half_drift_gamma[[1]]),
    accept_keep = vc_numeric_or_na_20260405(row$mcmc_accept_rate_keep[[1]]),
    accept_burn = vc_numeric_or_na_20260405(row$mcmc_accept_rate_burn[[1]]),
    accept_overall = vc_numeric_or_na_20260405(row$mcmc_accept_rate[[1]]),
    gate_ess_sigma = NA_character_,
    gate_acf1_sigma = NA_character_,
    gate_geweke_sigma = NA_character_,
    gate_half_drift_sigma = NA_character_,
    gate_ess_gamma = NA_character_,
    gate_acf1_gamma = NA_character_,
    gate_geweke_gamma = NA_character_,
    gate_half_drift_gamma = NA_character_,
    gate_sigma = vc_character_or_na_20260405(row$signoff_grade[[1]]),
    gate_gamma = if (grepl("ex", sel_row$model[[1]], fixed = TRUE)) vc_character_or_na_20260405(row$signoff_grade[[1]]) else NA_character_,
    stringsAsFactors = FALSE
  )
}

vc_extract_from_candidate_health_20260405 <- function(sel_row) {
  path <- vc_normalize_repo_path_20260405(sel_row$selected_health_path[[1]])
  df <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  picked <- vc_pick_candidate_health_row_20260405(df, sel_row)
  row <- df[picked$index, , drop = FALSE]

  run_root <- vc_run_root_from_fit_path_20260405(sel_row$selected_fit_path[[1]])
  root_id <- if ("case_id" %in% names(row)) vc_character_or_na_20260405(row$case_id[[1]]) else vc_rel_repo_path_20260405(run_root)

  data.frame(
    diagnostic_source_type = "candidate_health_csv",
    diagnostic_row_selector = picked$selector,
    run_root = run_root,
    run_root_rel = vc_rel_repo_path_20260405(run_root),
    root_id = root_id,
    method = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "::"),
    signoff_grade_source = vc_character_or_na_20260405(row$gate_overall[[1]]),
    source_gate_matches_selected = vc_gate_match_20260405(sel_row$gate_overall[[1]], row$gate_overall[[1]]),
    comparison_eligible = vc_truthy_20260405(row$healthy[[1]]),
    convergence_certified = vc_truthy_20260405(row$healthy[[1]]),
    signoff_reason = vc_character_or_na_20260405(row$unhealthy_reason[[1]]),
    status_source = "SUCCESS",
    finite_ok = NA,
    domain_ok = NA,
    execution_healthy_source = vc_truthy_20260405(row$healthy[[1]]),
    vb_converged = NA,
    vb_stop_reason = NA_character_,
    vb_trace_length = NA_real_,
    vb_elbo_tail_rel_range = NA_real_,
    vb_elbo_tail_rel_drift = NA_real_,
    vb_sigma_tail_rel_range = NA_real_,
    vb_gamma_tail_rel_range = NA_real_,
    vb_s_tail_rel_range = NA_real_,
    vb_delta_state_last = NA_real_,
    vb_delta_sigma_last = NA_real_,
    vb_delta_gamma_last = NA_real_,
    vb_delta_s_last = NA_real_,
    vb_ld_trace_rows = NA_real_,
    vb_ld_local_mode_pass = NA,
    vb_ld_committed_stable_tail = NA,
    vb_ld_candidate_local_pass_rate_tail = NA_real_,
    vb_ld_committed_local_pass_rate_tail = NA_real_,
    vb_ld_mode_fallback_rate = NA_real_,
    vb_ld_stabilized_rate_tail = NA_real_,
    vb_rhs_collapse_flag = NA,
    vb_rhs_tau_near_zero = NA,
    vb_rhs_beta_collapse = NA,
    vb_rhs_tau = NA_real_,
    vb_rhs_c2 = NA_real_,
    vb_rhs_lambda_mean = NA_real_,
    mh_kernel = if ("mh_kernel" %in% names(row)) vc_character_or_na_20260405(row$mh_kernel[[1]]) else NA_character_,
    kernel_exact = if ("kernel_exact" %in% names(row)) vc_truthy_20260405(row$kernel_exact[[1]]) else NA,
    rhs_collapse_flag = if ("rhs_collapse_flag" %in% names(row)) vc_truthy_20260405(row$rhs_collapse_flag[[1]]) else NA,
    rhs_collapse_sources = if ("rhs_collapse_sources" %in% names(row)) vc_character_or_na_20260405(row$rhs_collapse_sources[[1]]) else NA_character_,
    n_keep = if ("n_mcmc" %in% names(row)) vc_numeric_or_na_20260405(row$n_mcmc[[1]]) else NA_real_,
    n_burn = if ("n_burn" %in% names(row)) vc_numeric_or_na_20260405(row$n_burn[[1]]) else NA_real_,
    n_mcmc = if ("n_mcmc" %in% names(row)) vc_numeric_or_na_20260405(row$n_mcmc[[1]]) else NA_real_,
    ess_sigma = if ("ess_sigma" %in% names(row)) vc_numeric_or_na_20260405(row$ess_sigma[[1]]) else NA_real_,
    ess_gamma = if ("ess_gamma" %in% names(row)) vc_numeric_or_na_20260405(row$ess_gamma[[1]]) else NA_real_,
    ess_sigma_per1k = if ("ess_sigma_per1k" %in% names(row)) vc_numeric_or_na_20260405(row$ess_sigma_per1k[[1]]) else NA_real_,
    ess_gamma_per1k = if ("ess_gamma_per1k" %in% names(row)) vc_numeric_or_na_20260405(row$ess_gamma_per1k[[1]]) else NA_real_,
    acf1_sigma = if ("acf1_sigma" %in% names(row)) vc_numeric_or_na_20260405(row$acf1_sigma[[1]]) else NA_real_,
    acf1_gamma = if ("acf1_gamma" %in% names(row)) vc_numeric_or_na_20260405(row$acf1_gamma[[1]]) else NA_real_,
    geweke_sigma = if ("geweke_sigma" %in% names(row)) vc_numeric_or_na_20260405(row$geweke_sigma[[1]]) else NA_real_,
    geweke_gamma = if ("geweke_gamma" %in% names(row)) vc_numeric_or_na_20260405(row$geweke_gamma[[1]]) else NA_real_,
    half_drift_sigma = if ("half_drift_sigma" %in% names(row)) vc_numeric_or_na_20260405(row$half_drift_sigma[[1]]) else NA_real_,
    half_drift_gamma = if ("half_drift_gamma" %in% names(row)) vc_numeric_or_na_20260405(row$half_drift_gamma[[1]]) else NA_real_,
    accept_keep = if ("accept_keep" %in% names(row)) vc_numeric_or_na_20260405(row$accept_keep[[1]]) else NA_real_,
    accept_burn = NA_real_,
    accept_overall = if ("accept_keep" %in% names(row)) vc_numeric_or_na_20260405(row$accept_keep[[1]]) else NA_real_,
    gate_ess_sigma = if ("gate_ess_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_ess_sigma[[1]]) else NA_character_,
    gate_acf1_sigma = if ("gate_acf1_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_acf1_sigma[[1]]) else NA_character_,
    gate_geweke_sigma = if ("gate_geweke_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_geweke_sigma[[1]]) else NA_character_,
    gate_half_drift_sigma = if ("gate_half_drift_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_half_drift_sigma[[1]]) else NA_character_,
    gate_ess_gamma = if ("gate_ess_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_ess_gamma[[1]]) else NA_character_,
    gate_acf1_gamma = if ("gate_acf1_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_acf1_gamma[[1]]) else NA_character_,
    gate_geweke_gamma = if ("gate_geweke_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_geweke_gamma[[1]]) else NA_character_,
    gate_half_drift_gamma = if ("gate_half_drift_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_half_drift_gamma[[1]]) else NA_character_,
    gate_sigma = if ("gate_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_sigma[[1]]) else NA_character_,
    gate_gamma = if ("gate_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_gamma[[1]]) else NA_character_,
    stringsAsFactors = FALSE
  )
}

vc_extract_selected_diagnostics_20260405 <- function(sel_row) {
  health_path <- vc_normalize_repo_path_20260405(sel_row$selected_health_path[[1]])
  if (is.na(health_path) || !file.exists(health_path)) {
    stop(sprintf("Selected health path does not exist for %s", sel_row$case_key[[1]]))
  }

  if (identical(basename(health_path), "method_signoff_long.csv")) {
    vc_extract_from_method_signoff_20260405(sel_row)
  } else {
    summary_path <- vc_resolve_summary_source_path_20260405(sel_row)
    if (!is.na(summary_path) && file.exists(summary_path)) {
      vc_extract_from_summary_row_20260405(sel_row, summary_path)
    } else {
      vc_extract_from_candidate_health_20260405(sel_row)
    }
  }
}

vc_build_comparison_row_20260405 <- function(sel_row) {
  diag <- vc_extract_selected_diagnostics_20260405(sel_row)

  out <- cbind(
    sel_row,
    diag,
    stringsAsFactors = FALSE
  )

  out$selected_fit_path_abs <- vc_normalize_repo_path_20260405(out$selected_fit_path[[1]])
  out$selected_health_path_abs <- vc_normalize_repo_path_20260405(out$selected_health_path[[1]])
  out$selected_summary_path_abs <- vc_normalize_repo_path_20260405(out$selected_summary_path[[1]])
  out$selected_fit_path_rel <- vc_rel_repo_path_20260405(out$selected_fit_path[[1]])
  out$selected_health_path_rel <- vc_rel_repo_path_20260405(out$selected_health_path[[1]])
  out$selected_summary_path_rel <- vc_rel_repo_path_20260405(out$selected_summary_path[[1]])
  out$method_id <- vc_make_method_id_20260405(out$inference[[1]], out$model[[1]])
  out$scenario_key <- paste(out$root_kind[[1]], out$run_root_rel[[1]], sep = "::")
  out$gate_rank_num <- gate_rank(out$gate_overall[[1]])
  out
}

vc_group_gate_summary_20260405 <- function(df, by) {
  if (!nrow(df)) {
    return(data.frame())
  }

  parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(parts, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    data.frame(
      base,
      total = nrow(chunk),
      pass = sum(chunk$gate_overall == "PASS", na.rm = TRUE),
      warn = sum(chunk$gate_overall == "WARN", na.rm = TRUE),
      fail = sum(chunk$gate_overall == "FAIL", na.rm = TRUE),
      pct_pass = round(100 * mean(chunk$gate_overall == "PASS", na.rm = TRUE), 1),
      pct_warn = round(100 * mean(chunk$gate_overall == "WARN", na.rm = TRUE), 1),
      pct_fail = round(100 * mean(chunk$gate_overall == "FAIL", na.rm = TRUE), 1),
      runtime_sec_total = round(sum(chunk$runtime_sec, na.rm = TRUE), 3),
      runtime_sec_mean = round(mean(chunk$runtime_sec, na.rm = TRUE), 3),
      runtime_sec_median = round(stats::median(chunk$runtime_sec, na.rm = TRUE), 3),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, out)
}

vc_group_numeric_summary_20260405 <- function(df, by, metrics) {
  if (!nrow(df)) {
    return(data.frame())
  }

  parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(parts, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n = nrow(chunk)
    for (metric in metrics) {
      vals <- suppressWarnings(as.numeric(chunk[[metric]]))
      row[[paste0(metric, "_median")]] <- if (all(is.na(vals))) NA_real_ else round(stats::median(vals, na.rm = TRUE), 6)
      row[[paste0(metric, "_mean")]] <- if (all(is.na(vals))) NA_real_ else round(mean(vals, na.rm = TRUE), 6)
      row[[paste0(metric, "_nonmissing")]] <- sum(!is.na(vals))
    }
    row
  })

  do.call(rbind, out)
}
