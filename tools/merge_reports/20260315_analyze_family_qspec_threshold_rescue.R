#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
repo_root <- if (length(args) >= 1L) args[[1L]] else "."
repo_root <- normalizePath(repo_root, mustWork = TRUE)

source(file.path(repo_root, "tools", "merge_reports", "20260312_family_qspec_v2_common.R"))

method_path <- file.path(repo_root, "tools", "merge_reports", "20260314_family_qspec_method_signoff.tsv")
bucket_path <- file.path(repo_root, "tools", "merge_reports", "20260315_family_qspec_post_repair_unhealthy_classification.tsv")

method_df <- fq_read_tsv(method_path)
bucket_df <- fq_read_tsv(bucket_path)

join_key <- c("root_id", "inference", "model")
bucket_df <- bucket_df[, c(join_key, "failure_bucket"), drop = FALSE]
unhealthy_df <- merge(method_df, bucket_df, by = join_key, all.x = FALSE, all.y = FALSE, sort = FALSE)

soft_df <- unhealthy_df[unhealthy_df$failure_bucket == "soft_only", , drop = FALSE]

safe_num <- function(x) suppressWarnings(as.numeric(x))

max_finite <- function(x) {
  x <- safe_num(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  max(x)
}

min_finite <- function(x) {
  x <- safe_num(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  min(x)
}

median_finite <- function(x) {
  x <- safe_num(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  stats::median(x)
}

q75_finite <- function(x) {
  x <- safe_num(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(stats::quantile(x, 0.75, names = FALSE, type = 7))
}

soft_metric_group_row <- function(df) {
  data.frame(
    count = nrow(df),
    reasons = paste(sort(unique(df$signoff_reason)), collapse = " | "),
    ess_sigma_min = min_finite(df$mcmc_ess_sigma),
    ess_sigma_median = median_finite(df$mcmc_ess_sigma),
    ess_gamma_min = min_finite(df$mcmc_ess_gamma),
    ess_gamma_median = median_finite(df$mcmc_ess_gamma),
    ess_state_min = min_finite(df$mcmc_ess_state),
    ess_state_median = median_finite(df$mcmc_ess_state),
    acf1_sigma_max = max_finite(df$mcmc_acf1_sigma),
    acf1_gamma_max = max_finite(df$mcmc_acf1_gamma),
    acf1_state_max = max_finite(df$mcmc_acf1_state),
    geweke_sigma_q75 = q75_finite(df$mcmc_geweke_absz_sigma),
    geweke_gamma_q75 = q75_finite(df$mcmc_geweke_absz_gamma),
    geweke_state_q75 = q75_finite(df$mcmc_geweke_absz_state),
    drift_sigma_q75 = q75_finite(df$mcmc_half_drift_sigma),
    drift_gamma_q75 = q75_finite(df$mcmc_half_drift_gamma),
    drift_state_q75 = q75_finite(df$mcmc_half_drift_state),
    vb_elbo_max = max_finite(df$vb_elbo_tail_rel_range),
    vb_sigma_tail_max = max_finite(df$vb_sigma_tail_rel_range),
    vb_gamma_tail_max = max_finite(df$vb_gamma_tail_rel_range),
    vb_delta_state_max = max_finite(abs(safe_num(df$vb_delta_state_last))),
    stringsAsFactors = FALSE
  )
}

soft_groups <- split(soft_df, interaction(soft_df$inference, soft_df$model, drop = TRUE))
soft_metric_rows <- lapply(soft_groups, function(df) {
  base <- df[1L, c("inference", "model"), drop = FALSE]
  cbind(base, soft_metric_group_row(df), stringsAsFactors = FALSE)
})
soft_metric_summary <- if (length(soft_metric_rows)) do.call(rbind, soft_metric_rows) else data.frame(stringsAsFactors = FALSE)
if (nrow(soft_metric_summary)) {
  rownames(soft_metric_summary) <- NULL
  soft_metric_summary <- soft_metric_summary[order(soft_metric_summary$inference, soft_metric_summary$model), , drop = FALSE]
}

scenario_defs <- data.frame(
  scenario_id = c("baseline_recommended", "moderate_relax", "aggressive_relax"),
  scenario_label = c(
    "Current recommended policy",
    "Moderate MCMC threshold relaxation",
    "Aggressive MCMC threshold relaxation"
  ),
  ess_min = c(5, 3, 1),
  acf1_max = c(0.995, 0.998, 0.999),
  geweke_max = c(5.0, 7.5, 10.0),
  drift_max = c(0.75, 1.0, 1.5),
  stringsAsFactors = FALSE
)

evaluate_mcmc_rescue <- function(row, scenario) {
  reasons <- trimws(strsplit(row$signoff_reason, ";", fixed = TRUE)[[1L]])
  reasons <- reasons[nzchar(reasons)]
  if (row$inference != "mcmc") {
    return(FALSE)
  }
  if ("low_ess" %in% reasons) {
    ess_vals <- c(safe_num(row$mcmc_ess_sigma), safe_num(row$mcmc_ess_state))
    if (row$model %in% c("exal", "exdqlm")) ess_vals <- c(ess_vals, safe_num(row$mcmc_ess_gamma))
    ess_vals <- ess_vals[is.finite(ess_vals)]
    if (!length(ess_vals) || min(ess_vals) < scenario$ess_min) return(FALSE)
  }
  if ("high_autocorrelation" %in% reasons) {
    acf_vals <- c(abs(safe_num(row$mcmc_acf1_sigma)), abs(safe_num(row$mcmc_acf1_state)))
    if (row$model %in% c("exal", "exdqlm")) acf_vals <- c(acf_vals, abs(safe_num(row$mcmc_acf1_gamma)))
    acf_vals <- acf_vals[is.finite(acf_vals)]
    if (!length(acf_vals) || max(acf_vals) > scenario$acf1_max) return(FALSE)
  }
  if ("geweke_drift" %in% reasons) {
    z_vals <- c(safe_num(row$mcmc_geweke_absz_sigma), safe_num(row$mcmc_geweke_absz_state))
    if (row$model %in% c("exal", "exdqlm")) z_vals <- c(z_vals, safe_num(row$mcmc_geweke_absz_gamma))
    z_vals <- z_vals[is.finite(z_vals)]
    if (!length(z_vals) || max(z_vals) > scenario$geweke_max) return(FALSE)
  }
  if ("half_chain_drift" %in% reasons) {
    d_vals <- c(safe_num(row$mcmc_half_drift_sigma), safe_num(row$mcmc_half_drift_state))
    if (row$model %in% c("exal", "exdqlm")) d_vals <- c(d_vals, safe_num(row$mcmc_half_drift_gamma))
    d_vals <- d_vals[is.finite(d_vals)]
    if (!length(d_vals) || max(d_vals) > scenario$drift_max) return(FALSE)
  }
  TRUE
}

scenario_result_rows <- list()
row_classification_rows <- list()

for (i in seq_len(nrow(soft_df))) {
  row <- soft_df[i, , drop = FALSE]
  rescue_flags <- vapply(seq_len(nrow(scenario_defs)), function(j) {
    evaluate_mcmc_rescue(row, scenario_defs[j, , drop = FALSE])
  }, logical(1))
  names(rescue_flags) <- scenario_defs$scenario_id

  rescue_class <- if (row$inference != "mcmc") {
    "needs_model_or_vb_debug"
  } else if (isTRUE(rescue_flags[["moderate_relax"]])) {
    "threshold_only_rescue_moderate"
  } else if (isTRUE(rescue_flags[["aggressive_relax"]])) {
    "aggressive_policy_only_rescue"
  } else {
    "needs_deeper_chain"
  }

  row_classification_rows[[length(row_classification_rows) + 1L]] <- data.frame(
    root_id = row$root_id,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = row$fit_size,
    prior = row$prior,
    inference = row$inference,
    model = row$model,
    signoff_reason = row$signoff_reason,
    failure_bucket = row$failure_bucket,
    moderate_relax_rescues = rescue_flags[["moderate_relax"]],
    aggressive_relax_rescues = rescue_flags[["aggressive_relax"]],
    rescue_class = rescue_class,
    stringsAsFactors = FALSE
  )
}

row_classification <- if (length(row_classification_rows)) do.call(rbind, row_classification_rows) else data.frame(stringsAsFactors = FALSE)

scenario_summary <- do.call(rbind, lapply(seq_len(nrow(scenario_defs)), function(j) {
  scenario <- scenario_defs[j, , drop = FALSE]
  rescued <- if (!nrow(soft_df)) logical(0) else vapply(seq_len(nrow(soft_df)), function(i) {
    evaluate_mcmc_rescue(soft_df[i, , drop = FALSE], scenario)
  }, logical(1))
  data.frame(
    scenario_id = scenario$scenario_id,
    scenario_label = scenario$scenario_label,
    ess_min = scenario$ess_min,
    acf1_max = scenario$acf1_max,
    geweke_max = scenario$geweke_max,
    drift_max = scenario$drift_max,
    rescued_soft_rows = sum(rescued),
    rescued_soft_pct = if (length(rescued)) round(100 * mean(rescued), 1) else 0,
    stringsAsFactors = FALSE
  )
}))

scenario_rescue_by_model <- do.call(rbind, lapply(seq_len(nrow(scenario_defs)), function(j) {
  scenario <- scenario_defs[j, , drop = FALSE]
  if (!nrow(soft_df)) return(NULL)
  rescued <- vapply(seq_len(nrow(soft_df)), function(i) evaluate_mcmc_rescue(soft_df[i, , drop = FALSE], scenario), logical(1))
  tmp <- soft_df[rescued, c("inference", "model"), drop = FALSE]
  if (!nrow(tmp)) return(NULL)
  out <- aggregate(list(count = rep(1L, nrow(tmp))), by = list(
    scenario_id = rep(scenario$scenario_id, nrow(tmp)),
    scenario_label = rep(scenario$scenario_label, nrow(tmp)),
    inference = tmp$inference,
    model = tmp$model
  ), FUN = sum)
  out
}))
if (is.null(scenario_rescue_by_model)) {
  scenario_rescue_by_model <- data.frame(stringsAsFactors = FALSE)
}

rescue_class_summary <- if (nrow(row_classification)) {
  aggregate(list(count = rep(1L, nrow(row_classification))), by = list(
    rescue_class = row_classification$rescue_class
  ), FUN = sum)
} else {
  data.frame(rescue_class = character(0), count = integer(0), stringsAsFactors = FALSE)
}

rescue_class_by_model <- if (nrow(row_classification)) {
  aggregate(list(count = rep(1L, nrow(row_classification))), by = list(
    inference = row_classification$inference,
    model = row_classification$model,
    rescue_class = row_classification$rescue_class
  ), FUN = sum)
} else {
  data.frame(inference = character(0), model = character(0), rescue_class = character(0), count = integer(0), stringsAsFactors = FALSE)
}

full_action_rows <- lapply(seq_len(nrow(unhealthy_df)), function(i) {
  row <- unhealthy_df[i, , drop = FALSE]
  action_class <- if (row$failure_bucket[[1L]] == "mixed") {
    "mixed_debug_and_resample"
  } else if (row$failure_bucket[[1L]] == "hard_only") {
    "hard_numerical_repair"
  } else {
    idx <- match(
      paste(row$root_id[[1L]], row$inference[[1L]], row$model[[1L]], sep = "||"),
      paste(row_classification$root_id, row_classification$inference, row_classification$model, sep = "||")
    )
    if (is.na(idx)) "unclassified_soft_only" else row_classification$rescue_class[[idx]]
  }
  data.frame(
    root_id = row$root_id,
    root_kind = row$root_kind,
    family = row$family,
    tau = row$tau,
    fit_size = row$fit_size,
    prior = row$prior,
    inference = row$inference,
    model = row$model,
    failure_bucket = row$failure_bucket,
    signoff_reason = row$signoff_reason,
    action_class = action_class,
    stringsAsFactors = FALSE
  )
})
full_action_plan <- do.call(rbind, full_action_rows)

full_action_summary <- aggregate(
  list(count = rep(1L, nrow(full_action_plan))),
  by = list(action_class = full_action_plan$action_class),
  FUN = sum
)
full_action_by_model <- aggregate(
  list(count = rep(1L, nrow(full_action_plan))),
  by = list(
    inference = full_action_plan$inference,
    model = full_action_plan$model,
    action_class = full_action_plan$action_class
  ),
  FUN = sum
)

out_dir <- file.path(repo_root, "tools", "merge_reports")
fq_write_tsv(soft_metric_summary, file.path(out_dir, "20260315_family_qspec_soft_failure_metric_summary.tsv"))
fq_write_tsv(scenario_summary, file.path(out_dir, "20260315_family_qspec_threshold_rescue_scenarios.tsv"))
fq_write_tsv(scenario_rescue_by_model, file.path(out_dir, "20260315_family_qspec_threshold_rescue_by_model.tsv"))
fq_write_tsv(row_classification, file.path(out_dir, "20260315_family_qspec_threshold_rescue_classification.tsv"))
fq_write_tsv(rescue_class_summary, file.path(out_dir, "20260315_family_qspec_threshold_rescue_class_summary.tsv"))
fq_write_tsv(rescue_class_by_model, file.path(out_dir, "20260315_family_qspec_threshold_rescue_class_by_model.tsv"))
fq_write_tsv(full_action_plan, file.path(out_dir, "20260315_family_qspec_residual_action_plan.tsv"))
fq_write_tsv(full_action_summary, file.path(out_dir, "20260315_family_qspec_residual_action_summary.tsv"))
fq_write_tsv(full_action_by_model, file.path(out_dir, "20260315_family_qspec_residual_action_by_model.tsv"))

md_lines <- c(
  "# Family-QSpec Threshold Rescue Analysis",
  "",
  "## Soft-Failure Metric Surface",
  "",
  "| inference | model | count | median ESS sigma | median ESS gamma | median ESS state | max ACF1 gamma | q75 Geweke state | q75 drift gamma |",
  "|---|---|---:|---:|---:|---:|---:|---:|---:|"
)

if (nrow(soft_metric_summary)) {
  for (i in seq_len(nrow(soft_metric_summary))) {
    md_lines <- c(md_lines, sprintf(
      "| %s | %s | %d | %s | %s | %s | %s | %s | %s |",
      soft_metric_summary$inference[[i]],
      soft_metric_summary$model[[i]],
      soft_metric_summary$count[[i]],
      formatC(soft_metric_summary$ess_sigma_median[[i]], format = "f", digits = 2),
      formatC(soft_metric_summary$ess_gamma_median[[i]], format = "f", digits = 2),
      formatC(soft_metric_summary$ess_state_median[[i]], format = "f", digits = 2),
      formatC(soft_metric_summary$acf1_gamma_max[[i]], format = "f", digits = 3),
      formatC(soft_metric_summary$geweke_state_q75[[i]], format = "f", digits = 2),
      formatC(soft_metric_summary$drift_gamma_q75[[i]], format = "f", digits = 2)
    ))
  }
}

md_lines <- c(md_lines, "", "## Threshold Rescue Scenarios", "", "| scenario | rescued soft rows | rescued pct | ESS min | ACF1 max | Geweke max | drift max |", "|---|---:|---:|---:|---:|---:|---:|")
for (i in seq_len(nrow(scenario_summary))) {
  md_lines <- c(md_lines, sprintf(
    "| %s | %d | %.1f | %s | %s | %s | %s |",
    scenario_summary$scenario_label[[i]],
    scenario_summary$rescued_soft_rows[[i]],
    scenario_summary$rescued_soft_pct[[i]],
    scenario_summary$ess_min[[i]],
    scenario_summary$acf1_max[[i]],
    scenario_summary$geweke_max[[i]],
    scenario_summary$drift_max[[i]]
  ))
}

md_lines <- c(md_lines, "", "## Residual Triage Classes", "", "| class | count |", "|---|---:|")
if (nrow(rescue_class_summary)) {
  for (i in seq_len(nrow(rescue_class_summary))) {
    md_lines <- c(md_lines, sprintf("| %s | %d |", rescue_class_summary$rescue_class[[i]], rescue_class_summary$count[[i]]))
  }
}

md_lines <- c(md_lines, "", "## Full Residual Action Plan", "", "| class | count |", "|---|---:|")
for (i in seq_len(nrow(full_action_summary))) {
  md_lines <- c(md_lines, sprintf("| %s | %d |", full_action_summary$action_class[[i]], full_action_summary$count[[i]]))
}

writeLines(md_lines, con = file.path(out_dir, "20260315_family_qspec_threshold_rescue_summary.md"))

cat("Wrote threshold rescue analysis under tools/merge_reports\n")
