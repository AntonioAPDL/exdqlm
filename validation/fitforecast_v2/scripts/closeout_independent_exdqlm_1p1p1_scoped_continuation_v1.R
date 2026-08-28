#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/closeout_independent_exdqlm_1p1p1_scoped_continuation_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
manifest <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
if (!identical(as.character(manifest$schema_version), i111s_schema) ||
    !identical(as.character(manifest$scope_id), i111s_scope_id)) {
  stop("Closeout requires an exDQLM-only scoped continuation.", call. = FALSE)
}
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
plan_checks <- i111s_plan_checks(plan)
if (!all(plan_checks)) stop("The scoped plan contract changed before closeout.", call. = FALSE)
closeout_root <- ffv2_resolve_path(
  args$`output-root` %||% file.path(state_root, "closeout"),
  repo_root = repo_root, must_work = FALSE
)
ffv2_ensure_dir(closeout_root)

artifact_ok <- function(path, expected_sha) {
  path <- as.character(path %||% "")[1L]
  expected_sha <- as.character(expected_sha %||% "")[1L]
  nzchar(path) && nzchar(expected_sha) && file.exists(path) &&
    identical(ffv2_file_sha256(path), expected_sha)
}

job_rows <- lapply(seq_len(nrow(plan)), function(i) {
  row <- plan[i, , drop = FALSE]
  status_path <- file.path(state_root, "status", paste0(row$job_id[[1L]], ".json"))
  if (!file.exists(status_path)) {
    stop(sprintf("Missing terminal status for %s.", row$job_id[[1L]]), call. = FALSE)
  }
  x <- ffv2_read_json(status_path)
  config <- ffv2_read_json(row$config_path[[1L]])
  point_path <- as.character(config$row_metrics_path %||% "")[1L]
  checks <- c(
    success = identical(as.character(x$status), "SUCCESS"),
    config_hash = identical(as.character(x$config_sha256),
                            as.character(row$config_sha256[[1L]])),
    metric_draws = artifact_ok(x$metric_draws_path, x$metric_draws_sha256),
    interval_summary = artifact_ok(x$metric_interval_summary_path,
                                   x$metric_interval_summary_sha256),
    interval_manifest = artifact_ok(x$metric_interval_manifest_path,
                                    x$metric_interval_manifest_sha256),
    inference_diagnostics = artifact_ok(x$inference_diagnostics_path,
                                        x$inference_diagnostics_sha256),
    point_metrics = nzchar(point_path) && file.exists(point_path),
    draw_count = identical(as.integer(x$metric_draws),
                           as.integer(row$expected_draws[[1L]])),
    no_heavy_binary = identical(as.integer(x$heavy_binary_count), 0L)
  )
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    source_identity = row$source_identity[[1L]], inference = row$inference[[1L]],
    model_variant = row$model_variant[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    config_path = row$config_path[[1L]], config_sha256 = row$config_sha256[[1L]],
    status_path = status_path, status_sha256 = ffv2_file_sha256(status_path),
    metric_draws_path = as.character(x$metric_draws_path),
    metric_draws_sha256 = as.character(x$metric_draws_sha256),
    metric_draws = as.integer(x$metric_draws),
    point_metrics_path = point_path,
    point_metrics_sha256 = if (file.exists(point_path)) ffv2_file_sha256(point_path) else "",
    inference_diagnostics_path = as.character(x$inference_diagnostics_path),
    inference_diagnostics_sha256 = as.character(x$inference_diagnostics_sha256),
    elapsed_seconds = as.numeric(x$elapsed_seconds %||% NA_real_),
    checks_pass = all(checks), failed_checks = paste(names(checks)[!checks], collapse = ";"),
    stringsAsFactors = FALSE
  )
})
job_audit <- ffv2_bind_rows(job_rows)
job_audit_path <- ffv2_write_csv(job_audit,
                                  file.path(closeout_root, "job_artifact_audit.csv"))
if (!all(job_audit$checks_pass)) {
  stop(sprintf("Job artifact audit failed: %s",
               paste(job_audit$job_id[!job_audit$checks_pass], collapse = ", ")),
       call. = FALSE)
}

numeric_or_na <- function(x) {
  value <- suppressWarnings(as.numeric(x %||% NA_real_)[1L])
  if (is.finite(value)) value else NA_real_
}
diagnostic_rows <- lapply(seq_len(nrow(job_audit)), function(i) {
  row <- job_audit[i, , drop = FALSE]
  x <- ffv2_read_json(row$inference_diagnostics_path[[1L]])
  data.frame(
    job_id = row$job_id[[1L]], replay_id = row$replay_id[[1L]],
    inference = row$inference[[1L]], family = row$family[[1L]],
    tau = row$tau[[1L]], chain_id = row$chain_id[[1L]],
    gamma_fixed = isTRUE(x$gamma_fixed),
    requested_mh_proposal = as.character(x$requested_mh_proposal %||% NA_character_)[1L],
    observed_mh_proposal = as.character(x$observed_mh_proposal %||% NA_character_)[1L],
    vb_sigmagam_factorization = as.character(
      x$vb_sigmagam_factorization %||% NA_character_
    )[1L],
    gamma_n = as.integer(x$gamma$n %||% 0L),
    gamma_mean = numeric_or_na(x$gamma$mean), gamma_sd = numeric_or_na(x$gamma$sd),
    gamma_ess = numeric_or_na(x$gamma$ess), gamma_acf1 = numeric_or_na(x$gamma$acf1),
    sigma_n = as.integer(x$sigma$n %||% 0L),
    sigma_mean = numeric_or_na(x$sigma$mean), sigma_sd = numeric_or_na(x$sigma$sd),
    sigma_ess = numeric_or_na(x$sigma$ess), sigma_acf1 = numeric_or_na(x$sigma$acf1),
    stringsAsFactors = FALSE
  )
})
inference_diagnostics <- ffv2_bind_rows(diagnostic_rows)
diagnostics_path <- ffv2_write_csv(
  inference_diagnostics, file.path(closeout_root, "exdqlm_inference_diagnostics.csv")
)

source_summaries <- list()
point_summaries <- list()
chain_diagnostics <- list()
source_i <- point_i <- diag_i <- 0L
point_columns <- c(
  fit_rmse = "fit_q_rmse",
  forecast_mae = "forecast_h1000_q_mae",
  forecast_check_loss = "forecast_h1000_pinball_mean"
)
for (replay_id in unique(job_audit$replay_id)) {
  jobs <- job_audit[job_audit$replay_id == replay_id, , drop = FALSE]
  inference <- jobs$inference[[1L]]
  expected_chains <- if (inference == "mcmc") 3L else 1L
  draws <- ffv2_bind_rows(lapply(seq_len(nrow(jobs)), function(i) {
    x <- ffv2_read_csv(jobs$metric_draws_path[[i]])
    x$chain_id <- as.integer(jobs$chain_id[[i]])
    x
  }))
  if (length(unique(draws$chain_id)) != expected_chains ||
      any(table(draws$chain_id) != jobs$metric_draws[match(
        as.integer(names(table(draws$chain_id))), jobs$chain_id
      )])) {
    stop(sprintf("Metric-draw chain balance failed for %s.", replay_id), call. = FALSE)
  }
  interval_summary <- ffv2_metric_interval_summary(draws, inference = inference)
  source_i <- source_i + 1L
  source_summaries[[source_i]] <- cbind(data.frame(
    replay_id = replay_id, inference = inference, model_variant = "exdqlm",
    family = jobs$family[[1L]], tau = jobs$tau[[1L]], stringsAsFactors = FALSE
  ), interval_summary)

  raw_point <- ffv2_bind_rows(lapply(seq_len(nrow(jobs)), function(i) {
    x <- ffv2_read_csv(jobs$point_metrics_path[[i]])
    data.frame(
      chain_id = jobs$chain_id[[i]],
      fit_rmse = as.numeric(x[[point_columns[["fit_rmse"]]]][[1L]]),
      forecast_mae = as.numeric(x[[point_columns[["forecast_mae"]]]][[1L]]),
      forecast_check_loss = as.numeric(
        x[[point_columns[["forecast_check_loss"]]]][[1L]]
      ), stringsAsFactors = FALSE
    )
  }))
  for (metric in names(point_columns)) {
    values <- raw_point[[metric]]
    point_i <- point_i + 1L
    point_summaries[[point_i]] <- data.frame(
      replay_id = replay_id, inference = inference, model_variant = "exdqlm",
      family = jobs$family[[1L]], tau = jobs$tau[[1L]], metric = metric,
      point_mean = mean(values), point_sd_across_chains = if (length(values) > 1L) {
        stats::sd(values)
      } else 0,
      point_min = min(values), point_max = max(values), n_chains = length(values),
      stringsAsFactors = FALSE
    )
  }
  if (inference == "mcmc") {
    d <- tryCatch(ffv2_metric_chain_diagnostics(draws), error = function(e) {
      data.frame(
        metric = names(point_columns), chains = expected_chains,
        draws_per_chain = NA_integer_, split_rhat = NA_real_, bulk_ess = NA_real_,
        tail_ess = NA_real_, mcse_mean = NA_real_,
        mcse_fraction_interval_width = NA_real_,
        endpoint_max_range_pooled_sd = NA_real_, interval_overlap_min = NA_real_,
        diagnostic_error = conditionMessage(e), stringsAsFactors = FALSE
      )
    })
    if (!"diagnostic_error" %in% names(d)) d$diagnostic_error <- ""
    d$diagnostic_grade <- ifelse(
      is.finite(d$split_rhat) & d$split_rhat <= 1.05 &
        is.finite(d$bulk_ess) & d$bulk_ess >= 400 &
        is.finite(d$tail_ess) & d$tail_ess >= 200 &
        is.finite(d$mcse_fraction_interval_width) &
        d$mcse_fraction_interval_width <= 0.05 &
        is.finite(d$endpoint_max_range_pooled_sd) &
        d$endpoint_max_range_pooled_sd <= 0.50,
      "PASS", "WARN"
    )
    diag_i <- diag_i + 1L
    chain_diagnostics[[diag_i]] <- cbind(data.frame(
      replay_id = replay_id, family = jobs$family[[1L]], tau = jobs$tau[[1L]],
      stringsAsFactors = FALSE
    ), d)
  }
}
source_summary <- ffv2_bind_rows(source_summaries)
point_summary <- ffv2_bind_rows(point_summaries)
metric_diagnostics <- ffv2_bind_rows(chain_diagnostics)
source_summary_path <- ffv2_write_csv(
  source_summary, file.path(closeout_root, "source_interval_summary.csv")
)
point_summary_path <- ffv2_write_csv(
  point_summary, file.path(closeout_root, "source_point_metric_summary.csv")
)
metric_diagnostics_path <- ffv2_write_csv(
  metric_diagnostics, file.path(closeout_root, "mcmc_metric_diagnostics.csv")
)

registry <- ffv2_read_csv(file.path(state_root, "materialization", "source_replay_registry.csv"))
roles <- ffv2_read_csv(file.path(state_root, "materialization", "metric_role_ledger.csv"))
registry_index <- match(roles$source_identity, registry$source_identity)
if (anyNA(registry_index)) stop("Metric-role/source join failed.", call. = FALSE)
roles$replay_id <- registry$replay_id[registry_index]
role_metric <- c(fit = "fit_rmse", forecast_mae = "forecast_mae",
                 forecast_check = "forecast_check_loss")
roles$metric <- unname(role_metric[roles$metric_role])
source_key <- paste(source_summary$replay_id, source_summary$metric, sep = "\r")
role_key <- paste(roles$replay_id, roles$metric, sep = "\r")
source_index <- match(role_key, source_key)
point_key <- paste(point_summary$replay_id, point_summary$metric, sep = "\r")
point_index <- match(role_key, point_key)
if (anyNA(source_index) || anyNA(point_index)) {
  stop("Not all scoped metric roles have interval and point summaries.", call. = FALSE)
}
for (field in c("posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
                "cri_upper", "posterior_mean_inside_cri", "n_draws", "n_chains",
                "interval_label", "estimator_id")) {
  roles[[field]] <- source_summary[[field]][source_index]
}
for (field in c("point_mean", "point_sd_across_chains", "point_min", "point_max")) {
  roles[[field]] <- point_summary[[field]][point_index]
}
roles$posterior_delta_from_authority <- roles$posterior_mean - roles$authoritative_value
roles$posterior_ratio_to_authority <- roles$posterior_mean / roles$authoritative_value
roles$point_delta_from_authority <- roles$point_mean - roles$authoritative_value
roles$point_ratio_to_authority <- roles$point_mean / roles$authoritative_value
roles$strict_posterior_improvement <- roles$posterior_delta_from_authority < -1e-12
roles$strict_point_improvement <- roles$point_delta_from_authority < -1e-12
roles$material_point_change_1e6 <- abs(roles$point_delta_from_authority) > 1e-6
if (nrow(metric_diagnostics)) {
  diagnostic_key <- paste(metric_diagnostics$replay_id, metric_diagnostics$metric, sep = "\r")
  diagnostic_index <- match(role_key, diagnostic_key)
  roles$diagnostic_grade <- ifelse(
    roles$inference == "vb", "APPROX", metric_diagnostics$diagnostic_grade[diagnostic_index]
  )
} else roles$diagnostic_grade <- ifelse(roles$inference == "vb", "APPROX", "WARN")

point_source_relpath <- file.path(
  "validation", "fitforecast_v2", "promotions", i111s_promotion_id,
  "source_point_metric_summary.csv"
)
interval_source_relpath <- file.path(
  "validation", "fitforecast_v2", "promotions", i111s_promotion_id,
  "source_interval_summary.csv"
)
authority_source_fields <- c(
  "source_candidate_id", "source_run_tag", "source_status",
  "source_signoff_grade", "source_path", "source_sha256", "source_identity"
)
for (field in authority_source_fields) {
  names(roles)[names(roles) == field] <- paste0("authority_", field)
}
roles$new_source_candidate_id <- i111s_interval_candidate_id
roles$new_source_run_tag <- as.character(manifest$run_id)
roles$new_source_status <- "SUCCESS"
roles$new_source_signoff_grade <- ifelse(
  roles$diagnostic_grade == "WARN", "WARN", "PASS"
)
roles$new_interval_source_path <- interval_source_relpath
roles$new_interval_source_sha256 <- ffv2_file_sha256(source_summary_path)
roles$new_point_source_path <- point_source_relpath
roles$new_point_source_sha256 <- ffv2_file_sha256(point_summary_path)
roles$new_source_identity <- paste(
  roles$inference, roles$model_variant, roles$family, sprintf("%.2f", roles$tau),
  roles$replay_id, as.character(manifest$run_id), sep = "|"
)
comparison_path <- ffv2_write_csv(
  roles, file.path(closeout_root, "exdqlm_1p1p1_scoped_vs_authority_v2.csv")
)

authority <- ffv2_read_csv(imi_v1_authority_interface_path(repo_root, i111_authority_id))
point_candidate <- authority
point_candidate$article_interface_id <- i111s_point_candidate_id
point_columns <- c(
  fit = "fit_qtrue_rmse",
  forecast_mae = "forecast_qtrue_mae_H1000",
  forecast_check = "forecast_check_loss_H1000"
)
source_prefixes <- c(
  fit = "fit", forecast_mae = "forecast_mae",
  forecast_check = "forecast_check"
)
execution_commit <- as.character(
  manifest$launch_commit %||% manifest$git_commit %||%
    manifest$preparation_commit %||% NA_character_
)[1L]
closeout_commit <- system2(
  "git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE
)
validation_branch <- system2(
  "git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE
)
for (i in seq_len(nrow(roles))) {
  role <- roles[i, , drop = FALSE]
  match_row <- point_candidate$inference == role$inference[[1L]] &
    point_candidate$model_variant == "exdqlm" &
    point_candidate$family == role$family[[1L]] &
    abs(point_candidate$tau - role$tau[[1L]]) < 1e-12
  if (sum(match_row) != 1L) stop("Candidate interface join failed.", call. = FALSE)
  metric_role <- role$metric_role[[1L]]
  point_candidate[[point_columns[[metric_role]]]][match_row] <- role$point_mean[[1L]]
  prefix <- source_prefixes[[metric_role]]
  updates <- list(
    candidate_id = i111s_point_candidate_id,
    run_tag = as.character(manifest$run_id),
    signoff_grade = if (role$diagnostic_grade[[1L]] == "WARN") "WARN" else "PASS",
    status = "SUCCESS", path = point_source_relpath,
    sha256 = ffv2_file_sha256(point_summary_path)
  )
  for (field in names(updates)) {
    column <- paste0(prefix, "_source_", field)
    point_candidate[[column]][match_row] <- updates[[field]]
  }
}
exdqlm_rows <- point_candidate$model_variant == "exdqlm"
point_candidate$status[exdqlm_rows] <- "SUCCESS"
point_candidate$signoff_grade[exdqlm_rows] <- vapply(
  which(exdqlm_rows), function(i) {
    row_roles <- roles[
      roles$inference == point_candidate$inference[[i]] &
        roles$family == point_candidate$family[[i]] &
        abs(roles$tau - point_candidate$tau[[i]]) < 1e-12,
      , drop = FALSE
    ]
    if (any(row_roles$diagnostic_grade == "WARN")) "WARN" else "PASS"
  }, character(1L)
)
point_candidate$metric_source_mixed[exdqlm_rows] <- FALSE
point_candidate$source_registry_hash_value[exdqlm_rows] <-
  ffv2_file_sha256(point_summary_path)
point_candidate$package_version[exdqlm_rows] <- i111_package_version
point_candidate$validation_branch[exdqlm_rows] <- validation_branch
point_candidate$validation_commit[exdqlm_rows] <- execution_commit
point_candidate$validation_closeout_commit[exdqlm_rows] <- closeout_commit
point_candidate$source_promotion_id[exdqlm_rows] <- i111s_point_candidate_id
point_candidate$article_consumption_allowed[exdqlm_rows] <- TRUE
point_candidate$promotion_validation_branch[exdqlm_rows] <- validation_branch
point_candidate$promotion_validation_commit[exdqlm_rows] <- closeout_commit
point_candidate$rolling_evidence_promotion_id[exdqlm_rows] <- i111s_point_candidate_id
point_candidate$metric_estimator_contract[exdqlm_rows] <- i111s_point_estimator_id
point_candidate$confirmation_chain_count[exdqlm_rows] <- ifelse(
  point_candidate$inference[exdqlm_rows] == "mcmc", 3L, 1L
)
point_candidate$confirmation_execution_commit[exdqlm_rows] <- execution_commit
point_candidate$confirmation_closeout_commit[exdqlm_rows] <- closeout_commit
point_candidate$confirmation_state[exdqlm_rows] <- "COMPLETE"
point_candidate_path <- ffv2_write_csv(
  point_candidate,
  file.path(closeout_root, "candidate_point_interface_exdqlm_only_replacement.csv")
)
point_candidate_rows_path <- ffv2_write_csv(
  point_candidate[exdqlm_rows, , drop = FALSE],
  file.path(closeout_root, "candidate_point_exdqlm_rows.csv")
)

interval_parent_path <- i111s_interval_authority_path(repo_root)
if (!file.exists(interval_parent_path)) {
  stop("The frozen v11.1 interval authority is unavailable.", call. = FALSE)
}
interval_parent <- ffv2_read_csv(interval_parent_path)
interval_candidate <- interval_parent
parent_key <- i111s_role_key(interval_parent)
role_key <- i111s_role_key(roles)
if (anyDuplicated(parent_key) || anyDuplicated(role_key)) {
  stop("Point or interval candidate keys are not unique.", call. = FALSE)
}
interval_index <- match(role_key, parent_key)
if (anyNA(interval_index) || length(interval_index) != i111s_expected_metric_roles) {
  stop("The 1.1.1 interval roles do not cover the exDQLM authority block.",
       call. = FALSE)
}
interval_fields <- c(
  "posterior_mean", "posterior_sd", "cri_lower", "posterior_median",
  "cri_upper", "posterior_mean_inside_cri", "n_draws", "n_chains",
  "interval_label", "estimator_id"
)
for (i in seq_len(nrow(roles))) {
  target <- interval_index[[i]]
  role <- roles[i, , drop = FALSE]
  interval_candidate$authoritative_value[[target]] <- role$point_mean[[1L]]
  interval_candidate$source_candidate_id[[target]] <- i111s_interval_candidate_id
  interval_candidate$source_run_tag[[target]] <- as.character(manifest$run_id)
  interval_candidate$source_status[[target]] <- "SUCCESS"
  interval_candidate$source_signoff_grade[[target]] <- if (
    role$diagnostic_grade[[1L]] == "WARN"
  ) "WARN" else "PASS"
  interval_candidate$source_path[[target]] <- interval_source_relpath
  interval_candidate$source_sha256[[target]] <- ffv2_file_sha256(source_summary_path)
  interval_candidate$source_identity[[target]] <- role$new_source_identity[[1L]]
  interval_candidate$replay_id[[target]] <- role$replay_id[[1L]]
  interval_candidate$pooled_metric[[target]] <- role$metric[[1L]]
  for (field in interval_fields) {
    interval_candidate[[field]][[target]] <- role[[field]][[1L]]
  }
  interval_candidate$diagnostic_grade[[target]] <- role$diagnostic_grade[[1L]]
  interval_candidate$point_authority_id[[target]] <- i111s_point_candidate_id
  interval_candidate$point_delta_from_v11[[target]] <-
    role$posterior_mean[[1L]] - role$point_mean[[1L]]
  interval_candidate$point_ratio_to_v11[[target]] <-
    role$posterior_mean[[1L]] / role$point_mean[[1L]]
}
interval_candidate_path <- ffv2_write_csv(
  interval_candidate,
  file.path(closeout_root, "candidate_interval_roles_exdqlm_only_replacement.csv")
)
interval_candidate_rows_path <- ffv2_write_csv(
  interval_candidate[interval_index, , drop = FALSE],
  file.path(closeout_root, "candidate_interval_exdqlm_roles.csv")
)
invariance <- i111s_invariance_ledger(interval_parent, interval_candidate)
invariance_path <- ffv2_write_csv(
  invariance, file.path(closeout_root, "non_exdqlm_interval_invariance_ledger.csv")
)

point_long <- function(x) {
  ffv2_bind_rows(lapply(names(point_columns), function(metric_role) {
    data.frame(
      inference = x$inference, model_variant = x$model_variant,
      family = x$family, tau = x$tau, metric_role = metric_role,
      value = as.numeric(x[[point_columns[[metric_role]]]]),
      stringsAsFactors = FALSE
    )
  }))
}
winner_ledger <- function(parent, candidate, value_column) {
  panel_fields <- c("inference", "family", "tau", "metric_role")
  panel_key <- do.call(paste, c(parent[panel_fields], sep = "|"))
  candidate_key <- i111s_role_key(candidate)
  parent_role_key <- i111s_role_key(parent)
  candidate <- candidate[match(parent_role_key, candidate_key), , drop = FALSE]
  panels <- unique(panel_key)
  ffv2_bind_rows(lapply(panels, function(panel) {
    index <- which(panel_key == panel)
    old_order <- order(parent[[value_column]][index], parent$model_variant[index])
    new_order <- order(candidate[[value_column]][index], candidate$model_variant[index])
    old_exdqlm <- index[parent$model_variant[index] == "exdqlm"]
    new_exdqlm <- index[candidate$model_variant[index] == "exdqlm"]
    data.frame(
      parent[index[[1L]], panel_fields, drop = FALSE],
      old_winner = parent$model_variant[index[old_order[[1L]]]],
      new_winner = candidate$model_variant[index[new_order[[1L]]]],
      old_winner_value = parent[[value_column]][index[old_order[[1L]]]],
      new_winner_value = candidate[[value_column]][index[new_order[[1L]]]],
      winner_changed = parent$model_variant[index[old_order[[1L]]]] !=
        candidate$model_variant[index[new_order[[1L]]]],
      exdqlm_old_value = parent[[value_column]][old_exdqlm],
      exdqlm_new_value = candidate[[value_column]][new_exdqlm],
      exdqlm_old_rank = rank(parent[[value_column]][index], ties.method = "min")[
        parent$model_variant[index] == "exdqlm"
      ],
      exdqlm_new_rank = rank(candidate[[value_column]][index], ties.method = "min")[
        candidate$model_variant[index] == "exdqlm"
      ], stringsAsFactors = FALSE
    )
  }))
}
point_winner_ledger <- winner_ledger(
  point_long(authority), point_long(point_candidate), "value"
)
point_winner_path <- ffv2_write_csv(
  point_winner_ledger, file.path(closeout_root, "point_winner_change_ledger.csv")
)
interval_winner_ledger <- winner_ledger(
  interval_parent, interval_candidate, "posterior_mean"
)
interval_winner_path <- ffv2_write_csv(
  interval_winner_ledger, file.path(closeout_root, "interval_winner_change_ledger.csv")
)

heavy <- unique(unlist(lapply(unique(plan$job_root), function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
             full.names = TRUE, ignore.case = TRUE)
}), use.names = FALSE))
point_candidate_long <- point_long(point_candidate)
point_candidate_index <- match(role_key, i111s_role_key(point_candidate_long))
point_candidate_matches <- !anyNA(point_candidate_index) && all(
  abs(point_candidate_long$value[point_candidate_index] - roles$point_mean) < 1e-12
)
interval_candidate_matches <- all(vapply(seq_len(nrow(roles)), function(i) {
  target <- interval_index[[i]]
  all(vapply(interval_fields, function(field) {
    i111s_values_equal(interval_candidate[[field]][[target]], roles[[field]][[i]])
  }, logical(1L))) &&
    i111s_values_equal(interval_candidate$authoritative_value[[target]],
                       roles$point_mean[[i]])
}, logical(1L)))
inherited_invariance <- invariance$inherited_role

old_interval_target <- interval_parent[interval_index, , drop = FALSE]
new_interval_target <- interval_candidate[interval_index, , drop = FALSE]
posterior_mean_pct_change <- 100 * (
  new_interval_target$posterior_mean / old_interval_target$posterior_mean - 1
)
old_width <- old_interval_target$cri_upper - old_interval_target$cri_lower
new_width <- new_interval_target$cri_upper - new_interval_target$cri_lower
interval_width_pct_change <- 100 * (new_width / old_width - 1)
mcmc_roles <- roles$inference == "mcmc"
mcmc_forecast_roles <- mcmc_roles & roles$metric_role != "fit"
scientific_summary <- data.frame(
  indicator = c(
    "jobs_completed", "point_roles", "interval_roles",
    "strict_point_improvements", "strict_posterior_improvements",
    "mcmc_fit_point_improvements", "mcmc_forecast_mae_point_improvements",
    "mcmc_forecast_check_point_improvements",
    "posterior_means_changed_at_least_1pct",
    "max_abs_forecast_posterior_mean_change_pct",
    "max_abs_interval_width_change_pct", "point_winner_changes",
    "interval_winner_changes", "mcmc_metric_warning_rows"
  ),
  value = c(
    nrow(job_audit), nrow(roles), nrow(interval_candidate),
    sum(roles$strict_point_improvement), sum(roles$strict_posterior_improvement),
    sum(roles$strict_point_improvement[mcmc_roles & roles$metric_role == "fit"]),
    sum(roles$strict_point_improvement[mcmc_roles &
                                         roles$metric_role == "forecast_mae"]),
    sum(roles$strict_point_improvement[mcmc_roles &
                                         roles$metric_role == "forecast_check"]),
    sum(abs(posterior_mean_pct_change) >= 1),
    max(abs(posterior_mean_pct_change[mcmc_forecast_roles])),
    max(abs(interval_width_pct_change)), sum(point_winner_ledger$winner_changed),
    sum(interval_winner_ledger$winner_changed),
    sum(metric_diagnostics$diagnostic_grade == "WARN")
  ),
  stringsAsFactors = FALSE
)
scientific_summary_path <- ffv2_write_csv(
  scientific_summary, file.path(closeout_root, "scientific_change_summary.csv")
)
checks <- c(
  jobs_36 = nrow(job_audit) == i111s_expected_jobs,
  jobs_verified = all(job_audit$checks_pass),
  vb_jobs_9 = sum(job_audit$inference == "vb") == i111s_expected_vb_jobs,
  mcmc_jobs_27 = sum(job_audit$inference == "mcmc") == i111s_expected_mcmc_jobs,
  sources_18 = length(unique(source_summary$replay_id)) == i111s_expected_source_identities,
  source_metric_rows_54 = nrow(source_summary) == i111s_expected_metric_roles,
  point_metric_rows_54 = nrow(point_summary) == i111s_expected_metric_roles,
  roles_54 = nrow(roles) == i111s_expected_metric_roles,
  point_candidate_rows_72 = nrow(point_candidate) == nrow(authority),
  point_candidate_exdqlm_rows_18 = sum(exdqlm_rows) == i111s_expected_article_rows,
  point_candidate_matches_54_roles = point_candidate_matches,
  point_candidate_uses_point_estimator = all(
    point_candidate$metric_estimator_contract[exdqlm_rows] == i111s_point_estimator_id
  ),
  point_candidate_source_is_point_summary = all(vapply(
    c("fit_source_path", "forecast_mae_source_path", "forecast_check_source_path"),
    function(field) all(point_candidate[[field]][exdqlm_rows] == point_source_relpath),
    logical(1L)
  )),
  interval_candidate_rows_216 = nrow(interval_candidate) == nrow(interval_parent) &&
    nrow(interval_candidate) == 216L,
  interval_candidate_exdqlm_roles_54 = length(interval_index) ==
    i111s_expected_metric_roles,
  interval_candidate_matches_54_roles = interval_candidate_matches,
  interval_candidate_uses_interval_estimator = all(
    interval_candidate$estimator_id[interval_index] == i111s_interval_estimator_id
  ),
  interval_candidate_source_is_interval_summary = all(
    interval_candidate$source_path[interval_index] == interval_source_relpath
  ),
  non_exdqlm_interval_rows_162_invariant =
    sum(inherited_invariance) == 162L && all(invariance$unchanged[inherited_invariance]),
  point_winner_panels_54 = nrow(point_winner_ledger) == 54L,
  interval_winner_panels_54 = nrow(interval_winner_ledger) == 54L,
  intervals_ordered = all(roles$cri_lower <= roles$posterior_median &
                            roles$posterior_median <= roles$cri_upper),
  mcmc_draws_12000 = all(source_summary$n_draws[source_summary$inference == "mcmc"] ==
                           12000L),
  vb_draws_10000 = all(source_summary$n_draws[source_summary$inference == "vb"] ==
                         10000L),
  mcmc_diagnostics_27 = nrow(inference_diagnostics[inference_diagnostics$inference == "mcmc", ]) ==
    i111s_expected_mcmc_jobs,
  mcmc_collapsed_slice = all(
    inference_diagnostics$observed_mh_proposal[inference_diagnostics$inference == "mcmc"] ==
      "collapsed_slice"
  ),
  no_heavy_binaries = length(heavy) == 0L,
  article_write_performed_false = isFALSE(manifest$execution_policy$article_write_performed)
)
checks_path <- ffv2_write_csv(
  data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE),
  file.path(closeout_root, "closeout_checks_v2.csv")
)
if (!all(checks)) {
  stop(sprintf("Scoped closeout failed: %s",
               paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
}
decision <- "READY_FOR_DIAGNOSTIC_RECOVERY"
handoff <- list(
  schema_version = i111s_schema, closeout_revision = "v2_estimator_separated",
  status = decision,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  run_id = as.character(manifest$run_id), scope_id = i111s_scope_id,
  authority_id = i111_authority_id,
  package_version = i111_package_version,
  package_source_commit = i111_package_source_commit,
  package_tarball_sha256 = as.character(manifest$package_tarball_sha256),
  jobs = nrow(job_audit), sources = length(unique(source_summary$replay_id)),
  metric_roles = nrow(roles),
  strict_point_improvements = sum(roles$strict_point_improvement),
  strict_posterior_improvements = sum(roles$strict_posterior_improvement),
  material_point_changes_1e6 = sum(roles$material_point_change_1e6),
  mcmc_metric_warning_rows = sum(metric_diagnostics$diagnostic_grade == "WARN"),
  job_artifact_audit_path = job_audit_path,
  job_artifact_audit_sha256 = ffv2_file_sha256(job_audit_path),
  comparison_path = comparison_path,
  comparison_sha256 = ffv2_file_sha256(comparison_path),
  point_summary_path = point_summary_path,
  point_summary_sha256 = ffv2_file_sha256(point_summary_path),
  source_summary_path = source_summary_path,
  source_summary_sha256 = ffv2_file_sha256(source_summary_path),
  metric_diagnostics_path = metric_diagnostics_path,
  metric_diagnostics_sha256 = ffv2_file_sha256(metric_diagnostics_path),
  inference_diagnostics_path = diagnostics_path,
  inference_diagnostics_sha256 = ffv2_file_sha256(diagnostics_path),
  point_candidate_interface_path = point_candidate_path,
  point_candidate_interface_sha256 = ffv2_file_sha256(point_candidate_path),
  point_candidate_rows_path = point_candidate_rows_path,
  point_candidate_rows_sha256 = ffv2_file_sha256(point_candidate_rows_path),
  point_estimator_id = i111s_point_estimator_id,
  interval_candidate_path = interval_candidate_path,
  interval_candidate_sha256 = ffv2_file_sha256(interval_candidate_path),
  interval_candidate_rows_path = interval_candidate_rows_path,
  interval_candidate_rows_sha256 = ffv2_file_sha256(interval_candidate_rows_path),
  interval_estimator_id = i111s_interval_estimator_id,
  non_exdqlm_invariance_path = invariance_path,
  non_exdqlm_invariance_sha256 = ffv2_file_sha256(invariance_path),
  point_winner_change_path = point_winner_path,
  point_winner_change_sha256 = ffv2_file_sha256(point_winner_path),
  interval_winner_change_path = interval_winner_path,
  interval_winner_change_sha256 = ffv2_file_sha256(interval_winner_path),
  scientific_summary_path = scientific_summary_path,
  scientific_summary_sha256 = ffv2_file_sha256(scientific_summary_path),
  checks_path = checks_path, checks_sha256 = ffv2_file_sha256(checks_path),
  scientific_decision = "EXDQLM_1P1P1_COMPATIBILITY_REFRESH_CONCLUSIONS_STABLE",
  forecast_conclusion = paste(
    "The 1.1.1 rerun does not provide a material forecast improvement;",
    "it refreshes the complete exDQLM compatibility block and confirms the prior conclusions."
  ),
  replacement_policy = paste(
    "The 18 exDQLM rows form one coherent exdqlm 1.1.1 compatibility block;",
    "the integration lane must not cherry-pick only favorable cells."
  ),
  article_write_performed = FALSE,
  integration_owner = "ARTICLE_QDESN_INTEGRATION",
  execution_commit = execution_commit,
  closeout_commit = closeout_commit,
  diagnostic_recovery_required = TRUE
)
handoff_path <- file.path(closeout_root, "closeout_handoff_v2.json")
ffv2_write_json(handoff, handoff_path)
writeLines(c(
  "# exDQLM 1.1.1 scoped continuation closeout v2",
  "",
  sprintf("- Decision: `%s`", decision),
  sprintf("- Completed jobs: %d/%d", nrow(job_audit), i111s_expected_jobs),
  sprintf("- Strict point-metric improvements: %d/%d",
          sum(roles$strict_point_improvement), nrow(roles)),
  sprintf("- Strict posterior-metric improvements: %d/%d",
          sum(roles$strict_posterior_improvement), nrow(roles)),
  sprintf("- MCMC metric diagnostic warnings: %d/%d",
          sum(metric_diagnostics$diagnostic_grade == "WARN"), nrow(metric_diagnostics)),
  sprintf("- Point-estimate winner changes: %d/54",
          sum(point_winner_ledger$winner_changed)),
  sprintf("- Posterior-interval winner changes: %d/54",
          sum(interval_winner_ledger$winner_changed)),
  "- Point estimates and posterior metric intervals are separate candidate artifacts.",
  "- The original pipeline failure and closeout remain immutable; this v2 closeout is additive.",
  "- Article, shared-validation, and Overleaf writes: none",
  "- Integration policy: replace or retain the complete 18-row exDQLM block; do not cherry-pick."
), file.path(closeout_root, "CLOSEOUT_V2.md"), useBytes = TRUE)
cat(sprintf("exDQLM-only 1.1.1 closeout: %s\n", decision))
