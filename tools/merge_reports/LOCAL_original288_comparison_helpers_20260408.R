source("tools/merge_reports/LOCAL_validation_campaign_comparison_helpers_20260405.R")

o288_na_chr_20260408 <- function(x) {
  out <- as.character(x)
  out[is.na(out) | out == ""] <- NA_character_
  out
}

o288_truthy_20260408 <- function(x) {
  vc_truthy_20260405(x)
}

o288_numeric_or_na_20260408 <- function(x) {
  vc_numeric_or_na_20260405(x)
}

o288_bridge_selection_row_20260408 <- function(sel_row) {
  data.frame(
    case_key = sel_row$original_case_key[[1]],
    row_id = if ("row_id" %in% names(sel_row)) as.integer(sel_row$row_id[[1]]) else NA_integer_,
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = sel_row$fit_size[[1]],
    inference = sel_row$inference[[1]],
    model = sel_row$model[[1]],
    selected_pool = sel_row$selected_source_type[[1]],
    selected_variant_tag = o288_na_chr_20260408(sel_row$selected_variant_tag[[1]]),
    selected_fit_path = sel_row$selected_fit_path[[1]],
    selected_health_path = sel_row$selected_health_path[[1]],
    selected_summary_path = o288_na_chr_20260408(sel_row$selected_summary_path[[1]]),
    stringsAsFactors = FALSE
  )
}

o288_extract_selected_diagnostics_20260408 <- function(sel_row) {
  bridge <- o288_bridge_selection_row_20260408(sel_row)
  health_path <- vc_normalize_repo_path_20260405(bridge$selected_health_path[[1]])

  if (is.na(health_path) || !file.exists(health_path)) {
    stop(sprintf("Selected health path does not exist for %s", bridge$case_key[[1]]))
  }

  if (identical(basename(health_path), "method_signoff_long.csv")) {
    return(vc_extract_from_method_signoff_20260405(bridge))
  }

  summary_path <- o288_resolve_summary_source_path_20260408(bridge)
  if (!is.na(summary_path) && file.exists(summary_path)) {
    return(o288_extract_from_summary_row_20260408(sel_row, bridge, summary_path))
  }

  o288_extract_from_candidate_health_20260408(sel_row, bridge)
}

o288_make_method_id_20260408 <- function(inference, model) {
  paste(inference, model, sep = "__")
}

o288_make_selected_pool_group_20260408 <- function(selection_mode, selected_source_type) {
  if (is.na(selection_mode) || !nzchar(selection_mode)) {
    return(if (identical(selected_source_type, "baseline_original")) "baseline" else "promoted")
  }

  if (selection_mode %in% c("baseline_kept", "unresolved_baseline_fail")) {
    return("baseline")
  }

  "promoted"
}

o288_build_comparison_row_20260408 <- function(sel_row) {
  diag <- o288_extract_selected_diagnostics_20260408(sel_row)

  base <- data.frame(
    case_key = sel_row$original_case_key[[1]],
    row_id = if ("row_id" %in% names(sel_row)) as.integer(sel_row$row_id[[1]]) else NA_integer_,
    scenario_key = sel_row$original_scenario_key[[1]],
    workstream = sel_row$block[[1]],
    scope_label = sel_row$root_id[[1]],
    block = sel_row$block[[1]],
    root_kind = sel_row$root_kind[[1]],
    family = sel_row$family[[1]],
    tau_label = sel_row$tau[[1]],
    fit_size = o288_numeric_or_na_20260408(sel_row$fit_size[[1]]),
    prior_semantics = sel_row$prior_semantics[[1]],
    model = sel_row$model[[1]],
    inference = sel_row$inference[[1]],
    method = sel_row$method[[1]],
    root_id = sel_row$root_id[[1]],
    baseline_gate_overall = sel_row$baseline_gate_overall[[1]],
    baseline_healthy = o288_truthy_20260408(sel_row$baseline_healthy[[1]]),
    selected_source_type = sel_row$selected_source_type[[1]],
    selected_source_subtype = sel_row$selected_source_subtype[[1]],
    selected_pool = sel_row$selected_source_type[[1]],
    selected_pool_group = o288_make_selected_pool_group_20260408(
      sel_row$selection_mode[[1]],
      sel_row$selected_source_type[[1]]
    ),
    selected_candidate = sel_row$selected_candidate[[1]],
    selected_variant_tag = o288_na_chr_20260408(sel_row$selected_variant_tag[[1]]),
    selected_fit_path = sel_row$selected_fit_path[[1]],
    selected_health_path = sel_row$selected_health_path[[1]],
    selected_summary_path = o288_na_chr_20260408(sel_row$selected_summary_path[[1]]),
    source_path = sel_row$source_path[[1]],
    gate_overall = sel_row$gate_overall[[1]],
    healthy = o288_truthy_20260408(sel_row$healthy[[1]]),
    state = sel_row$gate_overall[[1]],
    runtime_sec = o288_numeric_or_na_20260408(sel_row$runtime_sec[[1]]),
    improved_over_baseline = o288_truthy_20260408(sel_row$improved_over_baseline[[1]]),
    selection_mode = sel_row$selection_mode[[1]],
    selection_reason = sel_row$selection_reason[[1]],
    provenance_source = sel_row$selected_source_type[[1]],
    stringsAsFactors = FALSE
  )

  out <- cbind(base, diag, stringsAsFactors = FALSE)

  out$selected_fit_path_abs <- vc_normalize_repo_path_20260405(out$selected_fit_path[[1]])
  out$selected_health_path_abs <- vc_normalize_repo_path_20260405(out$selected_health_path[[1]])
  out$selected_summary_path_abs <- vc_normalize_repo_path_20260405(out$selected_summary_path[[1]])
  out$selected_fit_path_rel <- vc_rel_repo_path_20260405(out$selected_fit_path[[1]])
  out$selected_health_path_rel <- vc_rel_repo_path_20260405(out$selected_health_path[[1]])
  out$selected_summary_path_rel <- vc_rel_repo_path_20260405(out$selected_summary_path[[1]])
  out$source_path_abs <- vc_normalize_repo_path_20260405(out$source_path[[1]])
  out$source_path_rel <- vc_rel_repo_path_20260405(out$source_path[[1]])
  out$method_id <- o288_make_method_id_20260408(out$inference[[1]], out$model[[1]])
  out$gate_rank_num <- gate_rank(out$gate_overall[[1]])
  out$baseline_gate_rank_num <- gate_rank(out$baseline_gate_overall[[1]])

  out
}

o288_group_gate_summary_20260408 <- function(df, by) {
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
      healthy_true = sum(o288_truthy_20260408(chunk$healthy), na.rm = TRUE),
      healthy_false = sum(!o288_truthy_20260408(chunk$healthy), na.rm = TRUE),
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

o288_group_numeric_summary_20260408 <- function(df, by, metrics) {
  if (!nrow(df)) {
    return(data.frame())
  }

  parts <- split(df, interaction(df[by], drop = TRUE, lex.order = TRUE))
  out <- lapply(parts, function(chunk) {
    base <- chunk[1, by, drop = FALSE]
    row <- base
    row$n <- nrow(chunk)
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

o288_resolve_summary_source_path_20260408 <- function(bridge) {
  summary_path <- vc_normalize_repo_path_20260405(bridge$selected_summary_path[[1]])
  if (!is.na(summary_path) && file.exists(summary_path)) {
    nm <- basename(summary_path)
    if (grepl("summary", nm, fixed = TRUE) || grepl("checkpoint", nm, fixed = TRUE)) {
      return(summary_path)
    }
  }

  vc_resolve_summary_source_path_20260405(bridge)
}

o288_pick_summary_row_20260408 <- function(df, sel_row, bridge) {
  idx <- seq_len(nrow(df))

  if ("candidate_path" %in% names(df)) {
    candidate_paths <- vapply(
      df$candidate_path,
      vc_normalize_repo_path_20260405,
      FUN.VALUE = character(1)
    )
    fit_path <- vc_normalize_repo_path_20260405(bridge$selected_fit_path[[1]])
    idx_fit <- idx[!is.na(candidate_paths[idx]) & candidate_paths[idx] == fit_path]
    if (length(idx_fit)) {
      idx <- idx_fit
    }
  }

  if ("queue_id" %in% names(df) && !is.na(bridge$row_id[[1]])) {
    idx_queue <- idx[vc_numeric_or_na_20260405(df$queue_id[idx]) == vc_numeric_or_na_20260405(bridge$row_id[[1]])]
    if (length(idx_queue)) {
      idx <- idx_queue
    }
  }

  if ("family" %in% names(df)) {
    idx_family <- idx[as.character(df$family[idx]) == as.character(sel_row$family[[1]])]
    if (length(idx_family)) {
      idx <- idx_family
    }
  }

  if ("tau" %in% names(df)) {
    tau_vals <- as.character(df$tau[idx])
    sel_tau <- as.character(sel_row$tau[[1]])
    tau_numeric <- suppressWarnings(as.numeric(sub("p", ".", tau_vals, fixed = TRUE)))
    sel_tau_numeric <- suppressWarnings(as.numeric(sub("p", ".", sel_tau, fixed = TRUE)))
    idx_tau <- idx[tau_vals == sel_tau | (!is.na(tau_numeric) & !is.na(sel_tau_numeric) & abs(tau_numeric - sel_tau_numeric) < 1e-12)]
    if (length(idx_tau)) {
      idx <- idx_tau
    }
  }

  if ("fit_size" %in% names(df)) {
    fit_vals <- vc_numeric_or_na_20260405(df$fit_size[idx])
    sel_fit <- vc_numeric_or_na_20260405(sel_row$fit_size[[1]])
    idx_fit_size <- idx[!is.na(fit_vals) & !is.na(sel_fit) & fit_vals == sel_fit]
    if (length(idx_fit_size)) {
      idx <- idx_fit_size
    }
  }

  if ("tt" %in% names(df)) {
    tt_vals <- vc_numeric_or_na_20260405(df$tt[idx])
    sel_fit <- vc_numeric_or_na_20260405(sel_row$fit_size[[1]])
    idx_tt <- idx[!is.na(tt_vals) & !is.na(sel_fit) & tt_vals == sel_fit]
    if (length(idx_tt)) {
      idx <- idx_tt
    }
  }

  if ("inference" %in% names(df)) {
    idx_inf <- idx[as.character(df$inference[idx]) == as.character(sel_row$inference[[1]])]
    if (length(idx_inf)) {
      idx <- idx_inf
    }
  }

  if ("model" %in% names(df)) {
    idx_model <- idx[as.character(df$model[idx]) == as.character(sel_row$model[[1]])]
    if (length(idx_model)) {
      idx <- idx_model
    }
  }

  if ("variant_tag" %in% names(df)) {
    idx_variant <- idx[as.character(df$variant_tag[idx]) == as.character(bridge$selected_variant_tag[[1]])]
    if (length(idx_variant)) {
      idx <- idx_variant
    }
  }

  if (length(idx) > 1L && "case_id" %in% names(df)) {
    idx_case <- idx[
      as.character(df$case_id[idx]) %in% c(
        as.character(sel_row$root_id[[1]]),
        paste(as.character(sel_row$root_id[[1]]), as.character(sel_row$model[[1]]), sep = "::")
      )
    ]
    if (length(idx_case)) {
      idx <- idx_case
    }
  }

  if (length(idx) > 1L && "stage" %in% names(df)) {
    idx_complete <- idx[as.character(df$stage[idx]) == "complete"]
    if (length(idx_complete)) {
      idx <- idx_complete
    }
  }

  if (length(idx) > 1L && "ts" %in% names(df)) {
    ts_vals <- as.character(df$ts[idx])
    ts_vals[is.na(ts_vals) | !nzchar(ts_vals)] <- ""
    idx <- idx[ts_vals == max(ts_vals)]
  }

  if (length(idx) > 1L && "model" %in% names(df)) {
    model_vals <- as.character(df$model[idx])
    idx_model_nonmissing <- idx[!is.na(model_vals) & nzchar(model_vals)]
    if (length(idx_model_nonmissing) == 1L) {
      idx <- idx_model_nonmissing
    }
  }

  if (length(idx) != 1L) {
    stop(sprintf(
      "Could not resolve a unique summary row in %s for %s",
      summary_path <- vc_normalize_repo_path_20260405(bridge$selected_summary_path[[1]]),
      bridge$case_key[[1]]
    ))
  }

  list(index = idx, selector = "candidate_path_family_tau_fit_model_variant")
}

o288_extract_from_summary_row_20260408 <- function(sel_row, bridge, summary_path) {
  df <- read.csv(summary_path, check.names = FALSE, stringsAsFactors = FALSE)
  picked <- o288_pick_summary_row_20260408(df, sel_row, bridge)
  row <- df[picked$index, , drop = FALSE]

  run_root <- vc_run_root_from_fit_path_20260405(bridge$selected_fit_path[[1]])
  root_id <- if ("case_id" %in% names(row)) vc_character_or_na_20260405(row$case_id[[1]]) else vc_rel_repo_path_20260405(run_root)

  num_from_row <- function(primary, secondary = NULL) {
    if (!is.null(primary) && primary %in% names(row)) {
      return(vc_numeric_or_na_20260405(row[[primary]][[1]]))
    }
    if (!is.null(secondary) && secondary %in% names(row)) {
      return(vc_numeric_or_na_20260405(row[[secondary]][[1]]))
    }
    NA_real_
  }

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
    ess_sigma_per1k = num_from_row("ess_sigma_per1k_cand", "ess_sigma_per1k"),
    ess_gamma_per1k = num_from_row("ess_gamma_per1k_cand", "ess_gamma_per1k"),
    acf1_sigma = num_from_row("acf1_sigma_cand", "acf1_sigma"),
    acf1_gamma = num_from_row("acf1_gamma_cand", "acf1_gamma"),
    geweke_sigma = num_from_row("geweke_sigma_cand", "geweke_sigma"),
    geweke_gamma = num_from_row("geweke_gamma_cand", "geweke_gamma"),
    half_drift_sigma = num_from_row("half_drift_sigma_cand", "half_drift_sigma"),
    half_drift_gamma = num_from_row("half_drift_gamma_cand", "half_drift_gamma"),
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

o288_pick_candidate_health_row_20260408 <- function(df, sel_row, bridge) {
  idx <- seq_len(nrow(df))

  if ("candidate_path" %in% names(df)) {
    candidate_paths <- vapply(
      df$candidate_path,
      vc_normalize_repo_path_20260405,
      FUN.VALUE = character(1)
    )
    fit_path <- vc_normalize_repo_path_20260405(bridge$selected_fit_path[[1]])
    idx_fit <- idx[!is.na(candidate_paths[idx]) & candidate_paths[idx] == fit_path]
    if (length(idx_fit)) {
      idx <- idx_fit
    }
  }

  if ("row_id" %in% names(df) && !is.na(bridge$row_id[[1]])) {
    idx_row <- idx[vc_numeric_or_na_20260405(df$row_id[idx]) == vc_numeric_or_na_20260405(bridge$row_id[[1]])]
    if (length(idx_row)) {
      idx <- idx_row
    }
  }

  if ("root_kind" %in% names(df)) {
    idx_root <- idx[as.character(df$root_kind[idx]) == as.character(sel_row$root_kind[[1]])]
    if (length(idx_root)) {
      idx <- idx_root
    }
  }

  if ("family" %in% names(df)) {
    idx_family <- idx[as.character(df$family[idx]) == as.character(sel_row$family[[1]])]
    if (length(idx_family)) {
      idx <- idx_family
    }
  }

  if ("tau_label" %in% names(df)) {
    idx_tau <- idx[as.character(df$tau_label[idx]) == as.character(sel_row$tau[[1]])]
    if (length(idx_tau)) {
      idx <- idx_tau
    }
  }

  if ("fit_size" %in% names(df)) {
    fit_vals <- vc_numeric_or_na_20260405(df$fit_size[idx])
    sel_fit <- vc_numeric_or_na_20260405(sel_row$fit_size[[1]])
    idx_fit_size <- idx[!is.na(fit_vals) & !is.na(sel_fit) & fit_vals == sel_fit]
    if (length(idx_fit_size)) {
      idx <- idx_fit_size
    }
  }

  if ("inference" %in% names(df)) {
    idx_inf <- idx[as.character(df$inference[idx]) == as.character(sel_row$inference[[1]])]
    if (length(idx_inf)) {
      idx <- idx_inf
    }
  }

  if ("model" %in% names(df)) {
    idx_model <- idx[as.character(df$model[idx]) == as.character(sel_row$model[[1]])]
    if (length(idx_model)) {
      idx <- idx_model
    }
  }

  if ("variant" %in% names(df)) {
    idx_variant <- idx[as.character(df$variant[idx]) == as.character(bridge$selected_variant_tag[[1]])]
    if (length(idx_variant)) {
      idx <- idx_variant
    }
  }

  if ("variant_tag" %in% names(df)) {
    idx_variant_tag <- idx[as.character(df$variant_tag[idx]) == as.character(bridge$selected_variant_tag[[1]])]
    if (length(idx_variant_tag)) {
      idx <- idx_variant_tag
    }
  }

  if (length(idx) != 1L) {
    stop(sprintf(
      "Could not resolve a unique candidate-health row in %s for %s",
      vc_normalize_repo_path_20260405(bridge$selected_health_path[[1]]),
      bridge$case_key[[1]]
    ))
  }

  list(index = idx, selector = "candidate_path_row_id_family_tau_fit_model_variant")
}

o288_extract_from_candidate_health_20260408 <- function(sel_row, bridge) {
  path <- vc_normalize_repo_path_20260405(bridge$selected_health_path[[1]])
  df <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  picked <- o288_pick_candidate_health_row_20260408(df, sel_row, bridge)
  row <- df[picked$index, , drop = FALSE]
  has_exact_candidate_path <- "candidate_path" %in% names(df) && any(!is.na(df$candidate_path) & nzchar(as.character(df$candidate_path)))

  run_root <- vc_run_root_from_fit_path_20260405(bridge$selected_fit_path[[1]])
  root_id <- if ("case_id" %in% names(row)) vc_character_or_na_20260405(row$case_id[[1]]) else vc_rel_repo_path_20260405(run_root)

  data.frame(
    diagnostic_source_type = "candidate_health_csv",
    diagnostic_row_selector = picked$selector,
    run_root = run_root,
    run_root_rel = vc_rel_repo_path_20260405(run_root),
    root_id = root_id,
    method = paste(sel_row$inference[[1]], sel_row$model[[1]], sep = "::"),
    signoff_grade_source = if ("gate_overall" %in% names(row)) vc_character_or_na_20260405(row$gate_overall[[1]]) else NA_character_,
    source_gate_matches_selected = if ("gate_overall" %in% names(row) && has_exact_candidate_path) vc_gate_match_20260405(sel_row$gate_overall[[1]], row$gate_overall[[1]]) else NA,
    comparison_eligible = if ("healthy" %in% names(row)) vc_truthy_20260405(row$healthy[[1]]) else NA,
    convergence_certified = if ("healthy" %in% names(row)) vc_truthy_20260405(row$healthy[[1]]) else NA,
    signoff_reason = if ("unhealthy_reason" %in% names(row)) vc_character_or_na_20260405(row$unhealthy_reason[[1]]) else NA_character_,
    status_source = if ("state" %in% names(row)) vc_character_or_na_20260405(row$state[[1]]) else "SUCCESS",
    finite_ok = NA,
    domain_ok = NA,
    execution_healthy_source = if ("healthy" %in% names(row)) vc_truthy_20260405(row$healthy[[1]]) else NA,
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
    accept_burn = if ("accept_burn" %in% names(row)) vc_numeric_or_na_20260405(row$accept_burn[[1]]) else NA_real_,
    accept_overall = if ("accept_overall" %in% names(row)) vc_numeric_or_na_20260405(row$accept_overall[[1]]) else if ("accept_keep" %in% names(row)) vc_numeric_or_na_20260405(row$accept_keep[[1]]) else NA_real_,
    gate_ess_sigma = if ("gate_ess_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_ess_sigma[[1]]) else NA_character_,
    gate_acf1_sigma = if ("gate_acf1_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_acf1_sigma[[1]]) else NA_character_,
    gate_geweke_sigma = if ("gate_geweke_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_geweke_sigma[[1]]) else NA_character_,
    gate_half_drift_sigma = if ("gate_half_drift_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_half_drift_sigma[[1]]) else NA_character_,
    gate_ess_gamma = if ("gate_ess_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_ess_gamma[[1]]) else NA_character_,
    gate_acf1_gamma = if ("gate_acf1_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_acf1_gamma[[1]]) else NA_character_,
    gate_geweke_gamma = if ("gate_geweke_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_geweke_gamma[[1]]) else NA_character_,
    gate_half_drift_gamma = if ("gate_half_drift_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_half_drift_gamma[[1]]) else NA_character_,
    gate_sigma = if ("gate_sigma" %in% names(row)) vc_character_or_na_20260405(row$gate_sigma[[1]]) else if ("gate_overall" %in% names(row)) vc_character_or_na_20260405(row$gate_overall[[1]]) else NA_character_,
    gate_gamma = if ("gate_gamma" %in% names(row)) vc_character_or_na_20260405(row$gate_gamma[[1]]) else if (grepl("ex", sel_row$model[[1]], fixed = TRUE) && "gate_overall" %in% names(row)) vc_character_or_na_20260405(row$gate_overall[[1]]) else NA_character_,
    stringsAsFactors = FALSE
  )
}
