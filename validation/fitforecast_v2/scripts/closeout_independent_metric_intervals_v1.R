#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_metric_intervals_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
materialization <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
smoke <- isTRUE(materialization$smoke)
campaign_schema <- as.character(materialization$schema_version %||% imi_v1_schema)[1L]
campaign_authority_id <- as.character(materialization$authority_id %||% imi_v1_authority_id)[1L]
campaign_stage <- if (identical(campaign_schema, i111_schema)) i111_stage else imi_v1_stage
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
closeout_root <- file.path(state_root, "closeout")
ffv2_ensure_dir(closeout_root)

status_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  if (!file.exists(path)) stop(sprintf("Missing status: %s", row$job_id[[1L]]), call. = FALSE)
  x <- ffv2_read_json(path)
  checks <- c(
    success = identical(as.character(x$status), "SUCCESS"),
    config_hash = identical(as.character(x$config_sha256), as.character(row$config_sha256[[1L]])),
    draws_exist = file.exists(as.character(x$metric_draws_path)),
    draws_hash = identical(ffv2_file_sha256(as.character(x$metric_draws_path)),
                            as.character(x$metric_draws_sha256)),
    summary_exist = file.exists(as.character(x$metric_interval_summary_path)),
    summary_hash = identical(ffv2_file_sha256(as.character(x$metric_interval_summary_path)),
                              as.character(x$metric_interval_summary_sha256)),
    interval_manifest_exists = file.exists(as.character(x$metric_interval_manifest_path)),
    interval_manifest_hash = identical(ffv2_file_sha256(as.character(x$metric_interval_manifest_path)),
                                        as.character(x$metric_interval_manifest_sha256)),
    draw_count = identical(as.integer(x$metric_draws), as.integer(row$expected_draws[[1L]])),
    no_heavy_binary = identical(as.integer(x$heavy_binary_count), 0L)
  )
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    engine = row$engine[[1L]], inference = row$inference[[1L]],
    model_variant = row$model_variant[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    metric_draws_path = as.character(x$metric_draws_path),
    metric_draws_sha256 = as.character(x$metric_draws_sha256),
    inference_diagnostics_path = as.character(
      x$inference_diagnostics_path %||% NA_character_
    )[1L],
    inference_diagnostics_sha256 = as.character(
      x$inference_diagnostics_sha256 %||% NA_character_
    )[1L],
    chain_summary_path = as.character(x$chain_summary_path %||% NA_character_)[1L],
    chain_summary_sha256 = as.character(x$chain_summary_sha256 %||% NA_character_)[1L],
    sigmagam_trace_path = as.character(x$sigmagam_trace_path %||% NA_character_)[1L],
    sigmagam_trace_sha256 = as.character(
      x$sigmagam_trace_sha256 %||% NA_character_
    )[1L],
    checks_pass = all(checks), failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
})
job_audit <- ffv2_bind_rows(status_rows)
ffv2_write_csv(job_audit, file.path(closeout_root, "job_artifact_audit.csv"))
if (!all(job_audit$checks_pass)) {
  stop(sprintf("Job artifact audit failed for: %s",
               paste(job_audit$job_id[!job_audit$checks_pass], collapse = ", ")), call. = FALSE)
}

diagnostic_artifacts <- list()
diagnostic_i <- 0L
for (i in seq_len(nrow(job_audit))) {
  row <- job_audit[i, , drop = FALSE]
  for (artifact_type in c("inference_diagnostics", "chain_summary", "sigmagam_trace")) {
    path <- as.character(row[[paste0(artifact_type, "_path")]][[1L]])
    expected_sha <- as.character(row[[paste0(artifact_type, "_sha256")]][[1L]])
    if (is.na(path) || !nzchar(path)) next
    diagnostic_i <- diagnostic_i + 1L
    diagnostic_artifacts[[diagnostic_i]] <- data.frame(
      job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
      engine = row$engine[[1L]], inference = row$inference[[1L]],
      model_variant = row$model_variant[[1L]], family = row$family[[1L]],
      tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
      artifact_type = artifact_type, path = path, expected_sha256 = expected_sha,
      exists = file.exists(path),
      hash_ok = file.exists(path) && identical(ffv2_file_sha256(path), expected_sha),
      stringsAsFactors = FALSE
    )
  }
}
diagnostic_artifact_audit <- ffv2_bind_rows(diagnostic_artifacts)
ffv2_write_csv(
  diagnostic_artifact_audit,
  file.path(closeout_root, "inference_diagnostic_artifact_audit.csv")
)

path_present <- function(x) !is.na(x) & nzchar(as.character(x))
dqlm_rows <- job_audit$engine == "dqlm"
qdesn_mcmc_rows <- job_audit$engine == "qdesn" & job_audit$inference == "mcmc"
qdesn_exal_mcmc_rows <- qdesn_mcmc_rows &
  job_audit$model_variant == "qdesn_exal_rhs_ns"
diagnostic_contract <- c(
  diagnostic_hashes = nrow(diagnostic_artifact_audit) > 0L &&
    all(diagnostic_artifact_audit$exists & diagnostic_artifact_audit$hash_ok),
  dqlm_compact_diagnostics = all(!dqlm_rows |
    path_present(job_audit$inference_diagnostics_path)),
  qdesn_mcmc_chain_summaries = all(!qdesn_mcmc_rows |
    path_present(job_audit$chain_summary_path)),
  qdesn_exal_mcmc_sigmagam_traces = all(!qdesn_exal_mcmc_rows |
    path_present(job_audit$sigmagam_trace_path))
)
if (!all(diagnostic_contract)) {
  stop(sprintf(
    "Inference diagnostic contract failed: %s",
    paste(names(diagnostic_contract)[!diagnostic_contract], collapse = ", ")
  ), call. = FALSE)
}

numeric_or_na <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_)[1L])
  if (!length(value) || !is.finite(value)) NA_real_ else value
}

dqlm_diagnostic_summary <- ffv2_bind_rows(lapply(which(dqlm_rows), function(i) {
  row <- job_audit[i, , drop = FALSE]
  x <- ffv2_read_json(row$inference_diagnostics_path[[1L]])
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    inference = row$inference[[1L]], model_variant = row$model_variant[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    gamma_fixed = isTRUE(x$gamma_fixed),
    requested_mh_proposal = as.character(x$requested_mh_proposal %||% NA_character_)[1L],
    observed_mh_proposal = as.character(x$observed_mh_proposal %||% NA_character_)[1L],
    vb_sigmagam_factorization = as.character(
      x$vb_sigmagam_factorization %||% NA_character_
    )[1L],
    gamma_n = as.integer(x$gamma$n %||% 0L),
    gamma_mean = numeric_or_na(x$gamma$mean),
    gamma_sd = numeric_or_na(x$gamma$sd),
    gamma_ess = numeric_or_na(x$gamma$ess),
    gamma_acf1 = numeric_or_na(x$gamma$acf1),
    sigma_n = as.integer(x$sigma$n %||% 0L),
    sigma_mean = numeric_or_na(x$sigma$mean),
    sigma_sd = numeric_or_na(x$sigma$sd),
    sigma_ess = numeric_or_na(x$sigma$ess),
    sigma_acf1 = numeric_or_na(x$sigma$acf1),
    stringsAsFactors = FALSE
  )
}))
ffv2_write_csv(dqlm_diagnostic_summary,
                file.path(closeout_root, "dqlm_exdqlm_inference_diagnostics.csv"))

qdesn_chain_summary <- ffv2_bind_rows(lapply(which(qdesn_mcmc_rows), function(i) {
  row <- job_audit[i, , drop = FALSE]
  x <- ffv2_read_csv(row$chain_summary_path[[1L]])
  cbind(data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    inference = row$inference[[1L]], model_variant = row$model_variant[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    stringsAsFactors = FALSE
  ), x)
}))
ffv2_write_csv(qdesn_chain_summary,
                file.path(closeout_root, "qdesn_mcmc_chain_diagnostics.csv"))

registry <- ffv2_read_csv(file.path(state_root, "materialization", "source_replay_registry.csv"))
roles <- ffv2_read_csv(file.path(state_root, "materialization", "metric_role_ledger.csv"))
source_summaries <- list()
diagnostics <- list()
summary_i <- 0L
diag_i <- 0L
for (replay_id in unique(job_audit$replay_id)) {
  jobs <- job_audit[job_audit$replay_id == replay_id, , drop = FALSE]
  draws <- ffv2_bind_rows(lapply(seq_len(nrow(jobs)), function(i) {
    x <- ffv2_read_csv(jobs$metric_draws_path[[i]])
    x$chain_id <- as.integer(jobs$chain_id[[i]])
    x
  }))
  inference <- jobs$inference[[1L]]
  expected_chains <- if (smoke) 1L else if (inference == "mcmc") 3L else 1L
  if (length(unique(draws$chain_id)) != expected_chains ||
      any(table(draws$chain_id) != as.integer(plan$expected_draws[match(jobs$job_id, plan$job_id)]))) {
    stop(sprintf("Chain balance failed for %s.", replay_id), call. = FALSE)
  }
  summary <- ffv2_metric_interval_summary(draws, inference = inference)
  summary_i <- summary_i + 1L
  source_summaries[[summary_i]] <- cbind(
    data.frame(
      replay_id = replay_id, engine = jobs$engine[[1L]], inference = inference,
      model_variant = jobs$model_variant[[1L]], family = jobs$family[[1L]],
      tau = jobs$tau[[1L]], stringsAsFactors = FALSE
    ), summary
  )
  if (inference == "mcmc" && expected_chains > 1L) {
    d <- tryCatch(ffv2_metric_chain_diagnostics(draws), error = function(e) {
      data.frame(metric = c("fit_rmse", "forecast_mae", "forecast_check_loss"),
                 chains = expected_chains, draws_per_chain = NA_integer_,
                 split_rhat = NA_real_, bulk_ess = NA_real_, tail_ess = NA_real_,
                 mcse_mean = NA_real_, mcse_fraction_interval_width = NA_real_,
                 endpoint_max_range_pooled_sd = NA_real_, interval_overlap_min = NA_real_,
                 diagnostic_error = conditionMessage(e),
                 stringsAsFactors = FALSE)
    })
    if (!"diagnostic_error" %in% names(d)) d$diagnostic_error <- ""
    d$diagnostic_grade <- ifelse(
      is.finite(d$split_rhat) & d$split_rhat <= 1.05 &
        is.finite(d$bulk_ess) & d$bulk_ess >= 400 &
        is.finite(d$tail_ess) & d$tail_ess >= 200 &
        is.finite(d$mcse_fraction_interval_width) & d$mcse_fraction_interval_width <= 0.05 &
        is.finite(d$endpoint_max_range_pooled_sd) & d$endpoint_max_range_pooled_sd <= 0.50,
      "PASS", "WARN"
    )
    diag_i <- diag_i + 1L
    diagnostics[[diag_i]] <- cbind(data.frame(replay_id = replay_id, stringsAsFactors = FALSE), d)
  }
}
source_summary <- ffv2_bind_rows(source_summaries)
diagnostic_table <- if (length(diagnostics)) ffv2_bind_rows(diagnostics) else data.frame()
ffv2_write_csv(source_summary, file.path(closeout_root, "source_interval_summary.csv"))
ffv2_write_csv(diagnostic_table, file.path(closeout_root, "mcmc_metric_diagnostics.csv"))

if (smoke) {
  checks <- c(
    jobs_complete = nrow(job_audit) == 4L && all(job_audit$checks_pass),
    sources_complete = length(unique(source_summary$replay_id)) == 4L,
    metrics_complete = nrow(source_summary) == 12L,
    intervals_ordered = all(source_summary$cri_lower <= source_summary$posterior_median &
                              source_summary$posterior_median <= source_summary$cri_upper)
  )
  ffv2_write_json(list(
    schema_version = campaign_schema, smoke = TRUE,
    status = if (all(checks)) "PASS" else "FAIL",
    checks = as.list(checks), jobs = nrow(job_audit), sources = length(unique(source_summary$replay_id)),
    metric_rows = nrow(source_summary)
  ), file.path(closeout_root, "smoke_closeout.json"))
  if (!all(checks)) stop("Smoke closeout failed.", call. = FALSE)
  cat("independent metric-interval smoke closeout: PASS\n")
  quit(save = "no", status = 0L)
}

registry_index <- match(roles$source_identity, registry$source_identity)
if (anyNA(registry_index)) stop("Metric role/source registry join failed.", call. = FALSE)
roles$replay_id <- registry$replay_id[registry_index]
role_metric <- c(fit = "fit_rmse", forecast_mae = "forecast_mae",
                 forecast_check = "forecast_check_loss")
roles$pooled_metric <- unname(role_metric[roles$metric_role])
join_key <- paste(source_summary$replay_id, source_summary$metric, sep = "\r")
role_key <- paste(roles$replay_id, roles$pooled_metric, sep = "\r")
idx <- match(role_key, join_key)
if (anyNA(idx)) stop("Not all 216 article metric roles have pooled intervals.", call. = FALSE)
for (field in c("posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
                "cri_upper", "posterior_mean_inside_cri", "n_draws", "n_chains",
                "interval_label", "estimator_id")) {
  roles[[field]] <- source_summary[[field]][idx]
}
roles$point_delta_from_authority <- roles$posterior_mean - roles$authoritative_value
roles$point_ratio_to_authority <- roles$posterior_mean / roles$authoritative_value
roles$strict_improvement <- is.finite(roles$point_delta_from_authority) &
  roles$point_delta_from_authority < -1e-12
roles$material_change_1e6 <- is.finite(roles$point_delta_from_authority) &
  abs(roles$point_delta_from_authority) > 1e-6
if (nrow(diagnostic_table)) {
  dkey <- paste(diagnostic_table$replay_id, diagnostic_table$metric, sep = "\r")
  didx <- match(role_key, dkey)
  roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX",
                                   diagnostic_table$diagnostic_grade[didx])
} else roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX", "WARN")
ffv2_write_csv(roles, file.path(closeout_root, "article_metric_role_intervals.csv"))
ffv2_write_csv(roles[, c(
  "article_row", "inference", "model_variant", "family", "tau", "metric_role",
  "metric_name", "authoritative_value", "posterior_mean", "posterior_sd",
  "cri_lower", "posterior_median", "cri_upper", "point_delta_from_authority",
  "point_ratio_to_authority", "strict_improvement", "material_change_1e6",
  "diagnostic_grade", "replay_id"
)], file.path(closeout_root, "exdqlm_1p1p1_vs_current_authority.csv"))

interface <- ffv2_read_csv(imi_v1_authority_interface_path(repo_root, campaign_authority_id))
interface$article_interface_id <- if (identical(campaign_schema, i111_schema)) {
  "qdesn_dqlm_500obs_exdqlm_1p1p1_candidate"
} else "qdesn_dqlm_500obs_metric_intervals_v10"
interface$metric_estimator_contract <- "posterior_mean_draw_metric_equal_tailed_95cri_v1"
for (role in names(role_metric)) {
  block <- roles[roles$metric_role == role, , drop = FALSE]
  block <- block[order(block$article_row), , drop = FALSE]
  stem <- switch(role, fit = "fit", forecast_mae = "forecast_mae",
                 forecast_check = "forecast_check")
  point_col <- switch(role, fit = "fit_qtrue_rmse",
                      forecast_mae = "forecast_qtrue_mae_H1000",
                      forecast_check = "forecast_check_loss_H1000")
  interface[[point_col]] <- block$posterior_mean
  for (field in c("posterior_sd", "cri_lower", "posterior_median", "cri_upper",
                  "posterior_mean_inside_cri", "n_draws", "n_chains",
                  "interval_label", "diagnostic_grade", "replay_id")) {
    interface[[paste0(stem, "_", field)]] <- block[[field]]
  }
}
interface_path <- ffv2_write_csv(
  interface, file.path(closeout_root, if (identical(campaign_schema, i111_schema)) {
    "qdesn_dqlm_500obs_exdqlm_1p1p1_candidate_interface.csv"
  } else "qdesn_dqlm_500obs_metric_intervals_v10_interface.csv")
)

fmt <- function(x) {
  x <- as.numeric(x)
  ifelse(abs(x) >= 10, formatC(x, format = "fg", digits = 4),
         formatC(x, format = "f", digits = 3))
}
model_tex <- c(
  dqlm = "DQLM", exdqlm = "exDQLM",
  qdesn_al_rhs_ns = "Q--DESN AL--RHS",
  qdesn_exal_rhs_ns = "Q--DESN exAL--RHS"
)
family_tex <- c(normal = "Gaussian", laplace = "Laplace", gausmix = "Gaussian mixture")
metric_specs <- list(
  list(point = "fit_qtrue_rmse", lo = "fit_cri_lower", hi = "fit_cri_upper",
       diagnostic = "fit_diagnostic_grade"),
  list(point = "forecast_qtrue_mae_H1000", lo = "forecast_mae_cri_lower",
       hi = "forecast_mae_cri_upper", diagnostic = "forecast_mae_diagnostic_grade"),
  list(point = "forecast_check_loss_H1000", lo = "forecast_check_cri_lower",
       hi = "forecast_check_cri_upper", diagnostic = "forecast_check_diagnostic_grade")
)
cell_tex <- function(row, spec, best) {
  mean_text <- fmt(row[[spec$point]])
  if (isTRUE(best)) mean_text <- paste0("\\textbf{", mean_text, "}")
  if (identical(as.character(row[[spec$diagnostic]]), "WARN")) {
    mean_text <- paste0(mean_text, "\\textsuperscript{\\(\\dagger\\)}")
  }
  paste0("\\shortstack{", mean_text, "\\\\{\\scriptsize [",
         fmt(row[[spec$lo]]), ", ", fmt(row[[spec$hi]]), "]}}")
}
render_family <- function(inference, family) {
  x <- interface[interface$inference == inference & interface$family == family, , drop = FALSE]
  x <- x[order(x$tau, match(x$model_variant, names(model_tex))), , drop = FALSE]
  lines <- c(
    "\\begin{table}[!htbp]", "\\centering", "\\scriptsize",
    "\\setlength{\\tabcolsep}{4pt}",
    "\\begin{tabular}{@{}clccc@{}}", "\\toprule",
    "Target & Model & Fit RMSE & Forecast MAE & Forecast check loss \\\\",
    "\\midrule"
  )
  for (tau in sort(unique(x$tau))) {
    block <- x[abs(x$tau - tau) < 1e-12, , drop = FALSE]
    best <- lapply(metric_specs, function(spec) which.min(block[[spec$point]]))
    for (i in seq_len(nrow(block))) {
      target <- if (i == 1L) sprintf("$p=%.2f$", tau) else ""
      cells <- vapply(seq_along(metric_specs), function(j) {
        cell_tex(block[i, , drop = FALSE], metric_specs[[j]], i == best[[j]])
      }, character(1L))
      lines <- c(lines, paste0(
        paste(c(target, model_tex[[block$model_variant[[i]]]], cells), collapse = " & "),
        " \\\\"
      ))
    }
    if (tau != max(x$tau)) lines <- c(lines, "\\addlinespace[2pt]")
  }
  qualifier <- if (inference == "vb") "Approximate posterior" else "Posterior"
  label_family <- if (family == "gausmix") "gausmix" else family
  approximation_note <- if (inference == "vb") {
    " Variational Bayes intervals are approximate."
  } else ""
  diagnostic_note <- if (inference == "mcmc") {
    " A dagger marks a metric-level warning in the supporting diagnostics; warnings are disclosed and are not used as exclusion rules."
  } else ""
  caption <- sprintf(
    "%s metric intervals for the %s single-quantile simulation family. Entries report posterior means with equal-tailed 95\\%% credible intervals in brackets. Fit RMSE compares conditional-quantile draws with the oracle training path; forecast MAE and check loss aggregate the fixed rolling-origin grid. Lower posterior means are better, and boldface marks the lowest displayed mean within each target level and criterion. Intervals condition on the fixed simulated data, evaluation design, and reservoir realization.%s%s",
    qualifier, family_tex[[family]], approximation_note, diagnostic_note
  )
  c(lines, "\\bottomrule", "\\end{tabular}",
    paste0("\\caption{", caption, "}"),
    sprintf("\\label{tab:simulation-500obs-%s-intervals-%s}", inference, label_family),
    "\\end{table}")
}

asset_root <- file.path(closeout_root, "article_assets")
ffv2_ensure_dir(asset_root)
asset_paths <- character(0)
for (inference in c("mcmc", "vb")) {
  includes <- character(0)
  for (family in c("normal", "laplace", "gausmix")) {
    name <- sprintf("qdesn_validation_500obs_%s_metric_intervals_%s.tex", inference, family)
    path <- file.path(asset_root, name)
    writeLines(render_family(inference, family), path, useBytes = TRUE)
    asset_paths <- c(asset_paths, path)
    includes <- c(includes, sprintf("\\input{tables/%s}", name))
  }
  master <- file.path(asset_root, sprintf("qdesn_validation_500obs_%s_metric_interval_tables.tex", inference))
  writeLines(includes, master, useBytes = TRUE)
  asset_paths <- c(asset_paths, master)
}
prose_path <- file.path(asset_root, "qdesn_validation_500obs_metric_intervals_prose.tex")
diagnostic_pass_n <- sum(diagnostic_table$diagnostic_grade == "PASS")
diagnostic_warn_n <- sum(diagnostic_table$diagnostic_grade == "WARN")
displayed_warning_n <- sum(c(
  interface$fit_diagnostic_grade,
  interface$forecast_mae_diagnostic_grade,
  interface$forecast_check_diagnostic_grade
) == "WARN")
writeLines(c(
  "Each metric is recomputed for every retained conditional-quantile draw. Table entries report the posterior mean and equal-tailed 95\\% credible interval of the resulting draw-wise metric. The fit criterion is oracle-path RMSE over the 500-observation training window; forecast MAE and check loss aggregate the same 1,000 rolling-origin lead-target pairs used by the point comparison. These intervals condition on the fixed simulated data set, evaluation grid, and case-specific reservoir realization, and therefore do not represent repeated-simulation or reservoir-design uncertainty. Variational Bayes intervals are approximate.",
  "",
  "The displayed specifications remain metric- and case-specific selections frozen before this interval campaign. Q--DESN and exQ--DESN intervals use conditional-quantile path draws; DQLM and exDQLM use latent-state quantile draws. Response-predictive draws are not used to form the metric intervals.",
  "",
  sprintf(
    "Among the %d pooled MCMC source--metric diagnostics, %d pass and %d are warnings; %d warning-marked metrics contribute to displayed table cells. Warnings remain disclosure fields and do not alter metric inclusion.",
    nrow(diagnostic_table), diagnostic_pass_n, diagnostic_warn_n, displayed_warning_n
  )
), prose_path, useBytes = TRUE)
asset_paths <- c(asset_paths, prose_path)
asset_manifest <- data.frame(
  file = basename(asset_paths), bytes = as.numeric(file.info(asset_paths)$size),
  sha256 = vapply(asset_paths, ffv2_file_sha256, character(1L)),
  article_destination = file.path("tables", basename(asset_paths)),
  stringsAsFactors = FALSE
)
asset_manifest_path <- ffv2_write_csv(asset_manifest,
                                      file.path(closeout_root, "article_asset_manifest.csv"))

heavy <- list.files(file.path(repo_root, "results", "qdesn_mcmc_validation", campaign_stage,
                              as.character(materialization$run_id)),
                    pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
checks <- c(
  jobs_198 = nrow(job_audit) == 198L,
  jobs_verified = all(job_audit$checks_pass),
  sources_90 = length(unique(source_summary$replay_id)) == 90L,
  source_metric_rows_270 = nrow(source_summary) == 270L,
  roles_216 = nrow(roles) == 216L,
  interface_72 = nrow(interface) == 72L,
  intervals_ordered = all(roles$cri_lower <= roles$posterior_median &
                            roles$posterior_median <= roles$cri_upper),
  mcmc_draws_12000 = all(source_summary$n_draws[source_summary$inference == "mcmc"] == 12000L),
  vb_draws_10000 = all(source_summary$n_draws[source_summary$inference == "vb"] == 10000L),
  inference_diagnostics_verified = all(diagnostic_contract),
  dqlm_diagnostic_jobs_complete = nrow(dqlm_diagnostic_summary) == sum(dqlm_rows),
  qdesn_mcmc_diagnostics_present = nrow(qdesn_chain_summary) >= sum(qdesn_mcmc_rows),
  no_heavy_binaries = length(heavy) == 0L,
  article_assets_9 = nrow(asset_manifest) == 9L
)
checks_path <- ffv2_write_csv(data.frame(check = names(checks), pass = unname(checks)),
                              file.path(closeout_root, "closeout_checks.csv"))
if (!all(checks)) stop(sprintf("Closeout failed: %s", paste(names(checks)[!checks], collapse = ", ")),
                       call. = FALSE)
scientific_decision <- if (identical(campaign_schema, i111_schema) &&
                           !any(roles$material_change_1e6)) {
  "READY_NO_ARTICLE_CHANGE"
} else "READY_FOR_INTEGRATION"
manifest <- list(
  schema_version = campaign_schema, status = scientific_decision,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = as.character(materialization$run_id), authority_id = campaign_authority_id,
  package_version = as.character(materialization$package_version %||% NA_character_),
  package_source_commit = as.character(materialization$package_source_commit %||% NA_character_),
  package_tarball_sha256 = as.character(
    materialization$package_tarball_sha256 %||% NA_character_
  ),
  estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1",
  jobs = nrow(job_audit), sources = length(unique(source_summary$replay_id)),
  metric_roles = nrow(roles), mcmc_diagnostic_warn_rows = if (nrow(diagnostic_table))
    sum(diagnostic_table$diagnostic_grade == "WARN") else 0L,
  interface_path = interface_path, interface_sha256 = ffv2_file_sha256(interface_path),
  article_asset_manifest_path = asset_manifest_path,
  article_asset_manifest_sha256 = ffv2_file_sha256(asset_manifest_path),
  checks_path = checks_path, checks_sha256 = ffv2_file_sha256(checks_path),
  inference_diagnostic_artifact_audit_path = file.path(
    closeout_root, "inference_diagnostic_artifact_audit.csv"
  ),
  inference_diagnostic_artifact_audit_sha256 = ffv2_file_sha256(file.path(
    closeout_root, "inference_diagnostic_artifact_audit.csv"
  )),
  dqlm_exdqlm_inference_diagnostics_path = file.path(
    closeout_root, "dqlm_exdqlm_inference_diagnostics.csv"
  ),
  dqlm_exdqlm_inference_diagnostics_sha256 = ffv2_file_sha256(file.path(
    closeout_root, "dqlm_exdqlm_inference_diagnostics.csv"
  )),
  qdesn_mcmc_chain_diagnostics_path = file.path(
    closeout_root, "qdesn_mcmc_chain_diagnostics.csv"
  ),
  qdesn_mcmc_chain_diagnostics_sha256 = ffv2_file_sha256(file.path(
    closeout_root, "qdesn_mcmc_chain_diagnostics.csv"
  )),
  strict_metric_improvements = sum(roles$strict_improvement),
  material_metric_changes_1e6 = sum(roles$material_change_1e6),
  rollback_authority = campaign_authority_id,
  article_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION",
  git_commit = system("git rev-parse HEAD", intern = TRUE)
)
ffv2_write_json(manifest, file.path(closeout_root, "integration_handoff.json"))
cat(sprintf("independent metric-interval production closeout: %s\n", scientific_decision))
