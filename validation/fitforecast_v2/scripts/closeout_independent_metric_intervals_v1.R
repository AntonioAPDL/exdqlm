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
    schema_version = imi_v1_schema, smoke = TRUE,
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
roles$point_delta_from_v9 <- roles$posterior_mean - roles$authoritative_value
roles$point_ratio_to_v9 <- roles$posterior_mean / roles$authoritative_value
if (nrow(diagnostic_table)) {
  dkey <- paste(diagnostic_table$replay_id, diagnostic_table$metric, sep = "\r")
  didx <- match(role_key, dkey)
  roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX",
                                   diagnostic_table$diagnostic_grade[didx])
} else roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX", "WARN")
ffv2_write_csv(roles, file.path(closeout_root, "article_metric_role_intervals.csv"))

interface <- ffv2_read_csv(imi_v1_authority_interface_path(repo_root))
interface$article_interface_id <- "qdesn_dqlm_500obs_metric_intervals_v10"
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
  interface, file.path(closeout_root, "qdesn_dqlm_500obs_metric_intervals_v10_interface.csv")
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
  list(point = "fit_qtrue_rmse", lo = "fit_cri_lower", hi = "fit_cri_upper"),
  list(point = "forecast_qtrue_mae_H1000", lo = "forecast_mae_cri_lower", hi = "forecast_mae_cri_upper"),
  list(point = "forecast_check_loss_H1000", lo = "forecast_check_cri_lower", hi = "forecast_check_cri_upper")
)
cell_tex <- function(row, spec, best) {
  mean_text <- fmt(row[[spec$point]])
  if (isTRUE(best)) mean_text <- paste0("\\textbf{", mean_text, "}")
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
  caption <- sprintf(
    "%s metric intervals for the %s single-quantile simulation family. Entries report posterior means with equal-tailed 95\\%% credible intervals in brackets. Fit RMSE compares conditional-quantile draws with the oracle training path; forecast MAE and check loss aggregate the fixed rolling-origin grid. Lower posterior means are better, and boldface marks the lowest displayed mean within each target level and criterion. Intervals condition on the fixed simulated data, evaluation design, and reservoir realization; VB intervals are approximate.",
    qualifier, family_tex[[family]]
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
writeLines(c(
  "Each metric is recomputed for every retained conditional-quantile draw. Table entries report the posterior mean and equal-tailed 95\\% credible interval of the resulting draw-wise metric. The fit criterion is oracle-path RMSE over the 500-observation training window; forecast MAE and check loss aggregate the same 1,000 rolling-origin lead-target pairs used by the point comparison. These intervals condition on the fixed simulated data set, evaluation grid, and case-specific reservoir realization, and therefore do not represent repeated-simulation or reservoir-design uncertainty. Variational Bayes intervals are approximate.",
  "",
  "The displayed specifications remain metric- and case-specific selections frozen before this interval campaign. Q--DESN and exQ--DESN intervals use conditional-quantile path draws; DQLM and exDQLM use latent-state quantile draws. Response-predictive draws are not used to form the metric intervals."
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

heavy <- list.files(file.path(repo_root, "results", "qdesn_mcmc_validation", imi_v1_stage,
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
  no_heavy_binaries = length(heavy) == 0L,
  article_assets_9 = nrow(asset_manifest) == 9L
)
checks_path <- ffv2_write_csv(data.frame(check = names(checks), pass = unname(checks)),
                              file.path(closeout_root, "closeout_checks.csv"))
if (!all(checks)) stop(sprintf("Closeout failed: %s", paste(names(checks)[!checks], collapse = ", ")),
                       call. = FALSE)
manifest <- list(
  schema_version = imi_v1_schema, status = "READY_FOR_INTEGRATION",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = as.character(materialization$run_id), authority_id = imi_v1_authority_id,
  estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1",
  jobs = nrow(job_audit), sources = length(unique(source_summary$replay_id)),
  metric_roles = nrow(roles), mcmc_diagnostic_warn_rows = if (nrow(diagnostic_table))
    sum(diagnostic_table$diagnostic_grade == "WARN") else 0L,
  interface_path = interface_path, interface_sha256 = ffv2_file_sha256(interface_path),
  article_asset_manifest_path = asset_manifest_path,
  article_asset_manifest_sha256 = ffv2_file_sha256(asset_manifest_path),
  checks_path = checks_path, checks_sha256 = ffv2_file_sha256(checks_path),
  rollback_authority = imi_v1_authority_id,
  article_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION",
  git_commit = system("git rev-parse HEAD", intern = TRUE)
)
ffv2_write_json(manifest, file.path(closeout_root, "integration_handoff.json"))
cat("independent metric-interval production closeout: READY_FOR_INTEGRATION\n")
