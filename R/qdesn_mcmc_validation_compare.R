`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_report_read_csv <- function(report_root, name) {
  path <- file.path(report_root, "tables", name)
  if (!file.exists(path)) {
    stop(sprintf("Required report table missing: %s", path), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_validation_compare_merge <- function(base_df, cand_df, by, base_prefix = "baseline", cand_prefix = "tuned") {
  names(base_df) <- c(by, paste0(base_prefix, "_", setdiff(names(base_df), by)))
  names(cand_df) <- c(by, paste0(cand_prefix, "_", setdiff(names(cand_df), by)))
  merge(base_df, cand_df, by = by, all = TRUE, sort = FALSE)
}

.qdesn_validation_compare_method_groups <- function(base_df, cand_df) {
  by <- c("scenario", "tau", "beta_prior_type", "reservoir_profile", "method")
  out <- .qdesn_validation_compare_merge(base_df, cand_df, by = by)
  delta_specs <- list(
    comparison_eligible_rate = "higher_better",
    signoff_pass_rate = "higher_better",
    fit_runtime_seconds_mean = "lower_better",
    forecast_qhat_mae_mean = "lower_better",
    forecast_pinball_tau_mean = "lower_better"
  )
  for (nm in names(delta_specs)) {
    b <- paste0("baseline_", nm)
    c <- paste0("tuned_", nm)
    if (all(c(b, c) %in% names(out))) {
      out[[paste0(nm, "_delta_tuned_minus_baseline")]] <- out[[c]] - out[[b]]
    }
  }
  out
}

.qdesn_validation_compare_pair_groups <- function(base_df, cand_df) {
  by <- c("scenario", "tau", "beta_prior_type", "reservoir_profile")
  out <- .qdesn_validation_compare_merge(base_df, cand_df, by = by)
  metrics <- c(
    "pair_comparison_eligible_rate",
    "pair_signoff_pass_rate",
    "runtime_ratio_mcmc_vs_vb_mean",
    "forecast_qhat_mae_delta_mcmc_minus_vb_mean",
    "forecast_pinball_tau_delta_mcmc_minus_vb_mean"
  )
  for (nm in metrics) {
    b <- paste0("baseline_", nm)
    c <- paste0("tuned_", nm)
    if (all(c(b, c) %in% names(out))) {
      out[[paste0(nm, "_delta_tuned_minus_baseline")]] <- out[[c]] - out[[b]]
    }
  }
  out
}

.qdesn_validation_compare_pair_summaries <- function(base_df, cand_df) {
  by <- c("root_id", "scenario", "tau", "beta_prior_type", "seed", "reservoir_profile")
  out <- .qdesn_validation_compare_merge(base_df, cand_df, by = by)
  metrics <- c(
    "pair_comparison_eligible",
    "runtime_ratio_mcmc_vs_vb",
    "forecast_qhat_mae_delta_mcmc_minus_vb",
    "forecast_pinball_tau_delta_mcmc_minus_vb"
  )
  for (nm in metrics) {
    b <- paste0("baseline_", nm)
    c <- paste0("tuned_", nm)
    if (all(c(b, c) %in% names(out))) {
      out[[paste0(nm, "_delta_tuned_minus_baseline")]] <- out[[c]] - out[[b]]
    }
  }
  out
}

.qdesn_validation_compare_overview_lines <- function(output_root, method_group_cmp, pair_group_cmp) {
  method_rollup <- if (nrow(method_group_cmp)) {
    method_group_cmp[, c(
      "scenario", "tau", "beta_prior_type", "method",
      "baseline_comparison_eligible_rate", "tuned_comparison_eligible_rate",
      "comparison_eligible_rate_delta_tuned_minus_baseline",
      "baseline_signoff_pass_rate", "tuned_signoff_pass_rate",
      "signoff_pass_rate_delta_tuned_minus_baseline"
    ), drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  pair_rollup <- if (nrow(pair_group_cmp)) {
    pair_group_cmp[, c(
      "scenario", "tau", "beta_prior_type",
      "baseline_pair_comparison_eligible_rate", "tuned_pair_comparison_eligible_rate",
      "pair_comparison_eligible_rate_delta_tuned_minus_baseline",
      "baseline_pair_signoff_pass_rate", "tuned_pair_signoff_pass_rate",
      "pair_signoff_pass_rate_delta_tuned_minus_baseline"
    ), drop = FALSE]
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  lines <- c(
    "# Q-DESN Validation Baseline vs Tuned Comparison",
    "",
    sprintf("- Output root: `%s`", output_root),
    "",
    "## Pair Group Deltas",
    ""
  )
  lines <- c(lines, .qdesn_validation_df_to_markdown(utils::head(pair_rollup, 24L)))
  lines <- c(lines, "", "## Method Group Deltas", "")
  lines <- c(lines, .qdesn_validation_df_to_markdown(utils::head(method_rollup, 24L)))
  lines
}

qdesn_validation_compare_campaign_reports <- function(baseline_report_root,
                                                      tuned_report_root,
                                                      output_root,
                                                      create_plots = TRUE) {
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "plots"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  baseline_report_root <- normalizePath(baseline_report_root, winslash = "/", mustWork = TRUE)
  tuned_report_root <- normalizePath(tuned_report_root, winslash = "/", mustWork = TRUE)

  method_group_cmp <- .qdesn_validation_compare_method_groups(
    .qdesn_validation_report_read_csv(baseline_report_root, "campaign_method_group_summary.csv"),
    .qdesn_validation_report_read_csv(tuned_report_root, "campaign_method_group_summary.csv")
  )
  pair_group_cmp <- .qdesn_validation_compare_pair_groups(
    .qdesn_validation_report_read_csv(baseline_report_root, "campaign_pair_group_summary.csv"),
    .qdesn_validation_report_read_csv(tuned_report_root, "campaign_pair_group_summary.csv")
  )
  pair_summary_cmp <- .qdesn_validation_compare_pair_summaries(
    .qdesn_validation_report_read_csv(baseline_report_root, "campaign_pair_summary.csv"),
    .qdesn_validation_report_read_csv(tuned_report_root, "campaign_pair_summary.csv")
  )

  .qdesn_validation_write_df(method_group_cmp, file.path(output_root, "tables", "method_group_compare.csv"))
  .qdesn_validation_write_df(pair_group_cmp, file.path(output_root, "tables", "pair_group_compare.csv"))
  .qdesn_validation_write_df(pair_summary_cmp, file.path(output_root, "tables", "pair_summary_compare.csv"))
  .qdesn_validation_write_json(file.path(output_root, "manifest", "comparison_manifest.json"), list(
    baseline_report_root = baseline_report_root,
    tuned_report_root = tuned_report_root,
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    generated_at = as.character(Sys.time()),
    analysis_git_sha = .qdesn_validation_git_sha()
  ))
  .qdesn_validation_write_lines(
    file.path(output_root, "comparison_summary.md"),
    .qdesn_validation_compare_overview_lines(output_root, method_group_cmp, pair_group_cmp)
  )

  if (isTRUE(create_plots) && nrow(pair_group_cmp)) {
    .qdesn_validation_require_namespace("ggplot2")
    pair_group_cmp$tau_label <- .qdesn_validation_tau_label(pair_group_cmp$tau)

    elig_df <- .qdesn_validation_bind_rows(list(
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        campaign = "baseline",
        value = pair_group_cmp$baseline_pair_comparison_eligible_rate,
        stringsAsFactors = FALSE
      ),
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        campaign = "tuned",
        value = pair_group_cmp$tuned_pair_comparison_eligible_rate,
        stringsAsFactors = FALSE
      )
    ))
    elig_df <- elig_df[is.finite(elig_df$value), , drop = FALSE]
    if (nrow(elig_df)) {
      p_elig <- ggplot2::ggplot(elig_df, ggplot2::aes(x = tau_label, y = value, fill = campaign)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_grid(scenario ~ beta_prior_type) +
        ggplot2::labs(title = "Pair Eligibility Rate: Baseline vs Tuned", x = "tau", y = "rate", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(output_root, "plots", "pair_eligibility_rate_compare.png"), p_elig, width = 12, height = 8, dpi = 150)
    }

    runtime_df <- .qdesn_validation_bind_rows(list(
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        campaign = "baseline",
        value = pair_group_cmp$baseline_runtime_ratio_mcmc_vs_vb_mean,
        stringsAsFactors = FALSE
      ),
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        campaign = "tuned",
        value = pair_group_cmp$tuned_runtime_ratio_mcmc_vs_vb_mean,
        stringsAsFactors = FALSE
      )
    ))
    runtime_df <- runtime_df[is.finite(runtime_df$value), , drop = FALSE]
    if (nrow(runtime_df)) {
      p_runtime <- ggplot2::ggplot(runtime_df, ggplot2::aes(x = tau_label, y = value, fill = campaign)) +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_grid(scenario ~ beta_prior_type) +
        ggplot2::labs(title = "MCMC/VB Runtime Ratio: Baseline vs Tuned", x = "tau", y = "ratio", fill = NULL) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(output_root, "plots", "runtime_ratio_compare.png"), p_runtime, width = 12, height = 8, dpi = 150)
    }

    delta_df <- .qdesn_validation_bind_rows(list(
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        metric = "qhat_mae_delta",
        value = pair_group_cmp$forecast_qhat_mae_delta_mcmc_minus_vb_delta_tuned_minus_baseline,
        stringsAsFactors = FALSE
      ),
      data.frame(
        scenario = pair_group_cmp$scenario,
        tau_label = pair_group_cmp$tau_label,
        beta_prior_type = pair_group_cmp$beta_prior_type,
        metric = "pinball_tau_delta",
        value = pair_group_cmp$forecast_pinball_tau_delta_mcmc_minus_vb_delta_tuned_minus_baseline,
        stringsAsFactors = FALSE
      )
    ))
    delta_df <- delta_df[is.finite(delta_df$value), , drop = FALSE]
    if (nrow(delta_df)) {
      p_delta <- ggplot2::ggplot(delta_df, ggplot2::aes(x = tau_label, y = value, fill = beta_prior_type)) +
        ggplot2::geom_hline(yintercept = 0, linetype = 2, linewidth = 0.5, colour = "#6b7280") +
        ggplot2::geom_col(position = "dodge", width = 0.65) +
        ggplot2::facet_grid(metric ~ scenario, scales = "free_y") +
        ggplot2::labs(title = "Change in MCMC-VB Score Delta: Tuned vs Baseline", x = "tau", y = "delta change", fill = "prior") +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(legend.position = "top")
      ggplot2::ggsave(file.path(output_root, "plots", "score_delta_change_compare.png"), p_delta, width = 12, height = 8, dpi = 150)
    }
  }

  invisible(list(
    method_group_compare = method_group_cmp,
    pair_group_compare = pair_group_cmp,
    pair_summary_compare = pair_summary_cmp,
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE)
  ))
}
