source(file.path(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                winslash = "/", mustWork = TRUE),
  "validation", "fitforecast_v2", "R",
  "independent_exal_m0_structural_screen_v2.R"
))

qdesn_tbcv1_stage <- "qdesn_dynamic_fitforecast_v2_500obs_tierb_cellwise_mcmc_v1"
qdesn_tbcv1_branch <- "validation/qdesn-tierb-cellwise-mcmc-v1-1.0.0"
qdesn_tbcv1_base_commit <- "e75280ba14fcdefc8508f150623323e783f4c54a"
qdesn_tbcv1_closed_tiera_decision <- "NO_CONFIRMED_GAIN_RETAIN_V6"
qdesn_tbcv1_article_interface <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811",
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811_interface.csv"
)
qdesn_tbcv1_target_metrics <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000"
)
qdesn_tbcv1_profile_fields <- c(
  qdesn_ssv2_profile_fields, "likelihood_target", "target_metrics",
  "design_provenance", "history_disposition"
)

.qdesn_tbcv1_bind_fill <- function(...) {
  rows <- list(...)
  rows <- rows[vapply(rows, function(x) !is.null(x) && nrow(x), logical(1L))]
  if (!length(rows)) return(data.frame())
  fields <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(fields, names(x))
    for (field in missing) x[[field]] <- NA
    x[, fields, drop = FALSE]
  })
  do.call(rbind, rows)
}

.qdesn_tbcv1_profile_schema <- function(x) {
  missing <- setdiff(qdesn_tbcv1_profile_fields, names(x))
  for (field in missing) x[[field]] <- NA
  x[, qdesn_tbcv1_profile_fields, drop = FALSE]
}

qdesn_tbcv1_target_contract <- function() {
  data.frame(
    target_cell_id = c(
      "al_laplace_t0p05", "al_laplace_t0p25", "al_gausmix_t0p05",
      "al_gausmix_t0p25"
    ),
    tier = rep("B", 4L),
    likelihood_target = rep("al", 4L),
    family = c("laplace", "laplace", "gausmix", "gausmix"),
    tau = c(.05, .25, .05, .25),
    objective_metric = rep("fit_qtrue_rmse", 4L),
    target_metrics = rep("fit_qtrue_rmse", 4L),
    candidates_per_cell = 8L,
    discovery_sources = 3L,
    replication_survivors = 3L,
    sealed_finalists = 2L,
    stringsAsFactors = FALSE
  )
}

qdesn_tbcv1_interface <- function(repo_root) {
  path <- qdesn_ssv2_path(repo_root, qdesn_tbcv1_article_interface,
                          must_work = TRUE)
  x <- qdesn_ssv2_read_csv(path)
  expected <- c(
    "inference", "model_variant", "family", "tau",
    qdesn_tbcv1_target_metrics, "source_registry_hash_value",
    "preprocessing_scope"
  )
  missing <- setdiff(expected, names(x))
  if (length(missing)) {
    stop(sprintf("The v6 interface is missing: %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  if (!identical(unique(x$source_registry_hash_value), qdesn_ssv2_registry_hash)) {
    stop("The v6 interface does not use the frozen source registry.", call. = FALSE)
  }
  x
}

.qdesn_tbcv1_metric_source_fields <- function(metric) {
  switch(metric,
    fit_qtrue_rmse = c("fit_source_candidate_id", "fit_source_path"),
    forecast_qtrue_mae_H1000 = c(
      "forecast_mae_source_candidate_id", "forecast_mae_source_path"
    ),
    forecast_check_loss_H1000 = c(
      "forecast_check_source_candidate_id", "forecast_check_source_path"
    ),
    stop(sprintf("Unsupported target metric: %s", metric), call. = FALSE)
  )
}

.qdesn_tbcv1_adjacent_request <- function(metric_path) {
  candidates <- c(
    file.path(dirname(metric_path), "fit_request.json"),
    file.path(dirname(dirname(metric_path)), "fit_request.json")
  )
  found <- candidates[file.exists(candidates)]
  if (length(found)) normalizePath(found[[1L]], winslash = "/", mustWork = TRUE)
  else NA_character_
}

.qdesn_tbcv1_find_request <- function(repo_root, candidate_id, metric_path) {
  adjacent <- .qdesn_tbcv1_adjacent_request(metric_path)
  if (!is.na(adjacent)) return(adjacent)

  suffix <- sub("^.*__", "", candidate_id)
  frozen <- list.files(
    qdesn_ssv2_path(
      repo_root, "config", "validation",
      "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_relaunch_v1_frozen_requests"
    ), pattern = paste0(suffix, "[.]json$"), full.names = TRUE
  )
  if (length(frozen) == 1L) {
    return(normalizePath(frozen, winslash = "/", mustWork = TRUE))
  }

  evidence <- list.files(
    qdesn_ssv2_path(
      repo_root, "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811",
      "evidence", "configs"
    ), pattern = "[.]json$", full.names = TRUE
  )
  if (length(evidence)) {
    matched <- evidence[vapply(evidence, function(path) {
      job <- tryCatch(qdesn_ssv2_read_json(path), error = function(e) NULL)
      !is.null(job) && identical(as.character(job$candidate_id), candidate_id)
    }, logical(1L))]
    if (length(matched)) {
      return(normalizePath(matched[[1L]], winslash = "/", mustWork = TRUE))
    }
  }

  parent_ledger <- qdesn_ssv2_read_csv(qdesn_ssv2_path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_mcmc_highalpha_cellwise_v1_authoritative_parent_profiles.csv",
    must_work = TRUE
  ))
  matched <- parent_ledger[parent_ledger$parent_candidate_id == candidate_id, , drop = FALSE]
  if (nrow(matched) == 1L && file.exists(matched$parent_fit_request_path[[1L]])) {
    return(normalizePath(matched$parent_fit_request_path[[1L]],
                         winslash = "/", mustWork = TRUE))
  }
  stop(sprintf("Cannot locate the authoritative request for %s.", candidate_id),
       call. = FALSE)
}

qdesn_tbcv1_targets <- function(repo_root, freeze_requests = FALSE) {
  contract <- qdesn_tbcv1_target_contract()
  interface <- qdesn_tbcv1_interface(repo_root)
  q <- interface[
    interface$inference == "mcmc" &
      interface$model_variant == "qdesn_al_rhs_ns",
    , drop = FALSE
  ]
  q$likelihood_target <- "al"
  structured <- interface[
    interface$inference == "mcmc" & interface$model_variant %in% c("dqlm", "exdqlm"),
    , drop = FALSE
  ]
  rows <- lapply(seq_len(nrow(contract)), function(i) {
    spec <- contract[i, , drop = FALSE]
    row <- q[
      q$likelihood_target == spec$likelihood_target &
        q$family == spec$family & abs(q$tau - spec$tau) < 1e-10,
      , drop = FALSE
    ]
    cmp <- structured[
      structured$family == spec$family & abs(structured$tau - spec$tau) < 1e-10,
      , drop = FALSE
    ]
    if (nrow(row) != 1L || nrow(cmp) != 2L) {
      stop(sprintf("Authority resolution failed for %s.", spec$target_cell_id),
           call. = FALSE)
    }
    fields <- .qdesn_tbcv1_metric_source_fields(spec$objective_metric)
    candidate_id <- as.character(row[[fields[[1L]]]][[1L]])
    metric_path <- as.character(row[[fields[[2L]]]][[1L]])
    request_suffix <- substr(
      digest::digest(candidate_id, algo = "sha256", serialize = FALSE),
      1L, 12L
    )
    frozen_rel <- file.path(
      "config", "validation", paste0(qdesn_tbcv1_stage, "_frozen_parent_requests"),
      paste0(qdesn_ssv2_safe(spec$target_cell_id), "__", request_suffix, ".json")
    )
    frozen_abs <- qdesn_ssv2_path(repo_root, frozen_rel)
    source_request <- if (file.exists(frozen_abs) && !isTRUE(freeze_requests)) {
      frozen_abs
    } else {
      .qdesn_tbcv1_find_request(repo_root, candidate_id, metric_path)
    }
    if (isTRUE(freeze_requests)) {
      request <- qdesn_ssv2_read_json(source_request)
      qdesn_ssv2_write_json(request, frozen_abs)
      source_request <- frozen_abs
    }
    if (!file.exists(frozen_abs)) {
      stop(sprintf("Frozen parent request is missing for %s.", spec$target_cell_id),
           call. = FALSE)
    }
    current <- vapply(qdesn_tbcv1_target_metrics, function(metric) {
      as.numeric(row[[metric]][[1L]])
    }, numeric(1L))
    comparator <- vapply(qdesn_tbcv1_target_metrics, function(metric) {
      min(as.numeric(cmp[[metric]]), na.rm = TRUE)
    }, numeric(1L))
    data.frame(
      spec,
      current_fit_qtrue_rmse = current[["fit_qtrue_rmse"]],
      current_forecast_qtrue_mae_H1000 =
        current[["forecast_qtrue_mae_H1000"]],
      current_forecast_check_loss_H1000 =
        current[["forecast_check_loss_H1000"]],
      comparator_fit_qtrue_rmse = comparator[["fit_qtrue_rmse"]],
      comparator_forecast_qtrue_mae_H1000 =
        comparator[["forecast_qtrue_mae_H1000"]],
      comparator_forecast_check_loss_H1000 =
        comparator[["forecast_check_loss_H1000"]],
      objective_current_value = current[[spec$objective_metric]],
      objective_comparator_value = comparator[[spec$objective_metric]],
      parent_candidate_id = candidate_id,
      parent_metric_path = metric_path,
      parent_request_source_path = source_request,
      parent_request_path = frozen_rel,
      parent_request_sha256 = qdesn_ssv2_sha256(frozen_abs),
      guard_relative_tolerance = .02,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (nrow(out) != 4L || !all(out$tier == "B") ||
      !all(out$likelihood_target == "al") || anyDuplicated(out$target_cell_id)) {
    stop("The Tier-B target contract has drifted.", call. = FALSE)
  }
  out
}

qdesn_tbcv1_parent_profiles <- function(repo_root, targets) {
  rows <- lapply(seq_len(nrow(targets)), function(i) {
    target <- targets[i, , drop = FALSE]
    request <- qdesn_ssv2_read_json(qdesn_ssv2_path(
      repo_root, target$parent_request_path[[1L]], must_work = TRUE
    ))
    profile <- .qdesn_ssv2_parent_profile(request)
    profile$target_cell_id <- target$target_cell_id
    profile$family <- target$family
    profile$tau <- target$tau
    profile$priority <- "tier_b"
    profile$objective_metric <- target$objective_metric
    profile$current_value <- target$objective_current_value
    profile$comparator_value <- target$objective_comparator_value
    profile$parent_anchor_id <- target$parent_candidate_id
    profile$candidate_id <- paste0("tbcv1_", target$target_cell_id, "_parent")
    profile$screening_profile_id <- profile$candidate_id
    profile$design_role <- "exact_v6_metric_parent_control"
    profile$selection_arm <- "parent"
    profile$likelihood_target <- target$likelihood_target
    profile$target_metrics <- target$target_metrics
    profile$design_provenance <- "exact_v6_metric_parent"
    profile$history_disposition <- "parent_control_not_candidate"
    profile
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  .qdesn_tbcv1_profile_schema(qdesn_ssv2_ensure_effective_dimension(out))
}

.qdesn_tbcv1_clone <- function(parent, arm, role) {
  x <- parent
  x$selection_arm <- arm
  x$design_role <- role
  x
}

.qdesn_tbcv1_finalize_profile <- function(x) {
  x <- qdesn_ssv2_ensure_effective_dimension(x)
  x$total_states <- vapply(x$n, function(z) sum(qdesn_ssv2_vec(z, "integer")),
                           numeric(1L))
  x$max_alpha <- vapply(x$alpha, function(z) max(qdesn_ssv2_vec(z)), numeric(1L))
  x$min_alpha <- vapply(x$alpha, function(z) min(qdesn_ssv2_vec(z)), numeric(1L))
  x$mean_alpha <- vapply(x$alpha, function(z) mean(qdesn_ssv2_vec(z)), numeric(1L))
  x$max_rho <- vapply(x$rho, function(z) max(qdesn_ssv2_vec(z)), numeric(1L))
  x$min_rho <- vapply(x$rho, function(z) min(qdesn_ssv2_vec(z)), numeric(1L))
  x$mean_rho <- vapply(x$rho, function(z) mean(qdesn_ssv2_vec(z)), numeric(1L))
  x$profile_signature <- vapply(seq_len(nrow(x)), function(i) {
    qdesn_ssv2_profile_signature(x[i, , drop = FALSE])
  }, character(1L))
  x
}

.qdesn_tbcv1_copy_context <- function(x, parent) {
  for (nm in c("target_cell_id", "family", "tau", "priority",
               "objective_metric", "current_value", "comparator_value",
               "parent_anchor_id", "likelihood_target", "target_metrics")) {
    x[[nm]] <- parent[[nm]][[1L]]
  }
  x
}

.qdesn_tbcv1_coupled_arms <- function(parent, cell_index) {
  tau_lower <- max(1e-8, as.numeric(parent$rhs_tau0) / 10)
  input <- .qdesn_tbcv1_clone(
    parent, "coupled_tau_input_memory", "local_shrinkage_input_memory_coupling"
  )
  input$rhs_tau0 <- tau_lower
  input$m <- min(150L, max(15L, as.integer(parent$m) * 2L))

  readout <- .qdesn_tbcv1_clone(
    parent, "coupled_tau_readout_memory", "local_shrinkage_readout_memory_coupling"
  )
  readout$rhs_tau0 <- tau_lower
  readout$readout_y_lags <- min(12L, max(3L, as.integer(parent$readout_y_lags) + 2L))

  bridge <- .qdesn_tbcv1_clone(
    parent, "local_alpha_rho_bridge", "local_recurrence_bridge_under_stronger_shrinkage"
  )
  bridge$alpha <- qdesn_ssv2_pack(pmin(
    .20, pmax(.003, qdesn_ssv2_vec(parent$alpha) * (4 + cell_index / 10))
  ))
  bridge$rho <- qdesn_ssv2_pack(pmin(
    .80, qdesn_ssv2_vec(parent$rho) + .08 + cell_index / 100
  ))
  bridge$rhs_tau0 <- max(1e-8, as.numeric(parent$rhs_tau0) / 3)

  sentinel_alpha <- c(.42, .52, .62, .72)[[cell_index]]
  sentinel_rho <- c(.82, .86, .90, .94)[[cell_index]]
  sentinel <- .qdesn_ssv2_profile_row(
    D = 1L, n = as.integer(parent$total_states) + 8L + cell_index,
    m = 24L + 3L * cell_index, alpha = sentinel_alpha,
    rho = sentinel_rho, degree = 4L,
    tau0 = max(1e-8, as.numeric(parent$rhs_tau0) / 100),
    readout_y_lags = if (cell_index %% 2L) 3L else 6L,
    reservoir_lags = 1L, washout = 300L, layer_shape = "constant",
    alpha_pattern = "constant", rho_pattern = "constant",
    design_role = "shallow_high_alpha_strong_shrinkage_sentinel",
    selection_arm = "shallow_high_alpha_sentinel"
  )
  sentinel <- .qdesn_tbcv1_copy_context(sentinel, parent)
  out <- .qdesn_tbcv1_bind_fill(input, readout, bridge, sentinel)
  out <- .qdesn_tbcv1_copy_context(out, parent)
  .qdesn_tbcv1_finalize_profile(out)
}

qdesn_tbcv1_configured_unrun_local_profiles <- function(repo_root, parents) {
  path <- qdesn_ssv2_path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_lower_tail_cellwise_mcmc_v1_candidate_profiles.csv",
    must_work = TRUE
  )
  prior <- qdesn_ssv2_read_csv(path)
  local_arms <- c(
    "local_tau_lower", "local_tau_upper", "local_readout_memory",
    "local_input_memory"
  )
  prior <- prior[
    prior$target_cell_id %in% parents$target_cell_id &
      prior$selection_arm %in% local_arms, , drop = FALSE
  ]
  if (nrow(prior) != 16L || any(table(prior$target_cell_id) != 4L)) {
    stop("The configured-unrun Tier-B local allowlist has drifted.", call. = FALSE)
  }
  prior$design_role <- paste0("configured_unrun_", prior$design_role)
  prior$design_provenance <- qdesn_ssv2_rel(path, repo_root)
  prior$history_disposition <- "admitted_configured_unrun_not_evaluated"
  prior
}

qdesn_tbcv1_candidate_profiles <- function(repo_root, parents, history) {
  configured <- qdesn_tbcv1_configured_unrun_local_profiles(repo_root, parents)
  rows <- list()
  for (i in seq_len(nrow(parents))) {
    parent <- parents[i, , drop = FALSE]
    local <- configured[
      configured$target_cell_id == parent$target_cell_id[[1L]], , drop = FALSE
    ]
    coupled <- .qdesn_tbcv1_coupled_arms(parent, i)
    coupled$design_provenance <- "tierb_v1_predeclared_coupled_design"
    coupled$history_disposition <- "new_signature_not_in_history"
    cell <- .qdesn_tbcv1_bind_fill(local, coupled)
    new_rows <- cell$history_disposition == "new_signature_not_in_history"
    if (any(cell$profile_signature[new_rows] %in% history$profile_signature)) {
      stop(sprintf("A new Tier-B signature repeats history for %s.",
                   parent$target_cell_id[[1L]]), call. = FALSE)
    }
    hashes <- vapply(cell$profile_signature, digest::digest, character(1L),
                     algo = "sha256", serialize = FALSE)
    cell$candidate_id <- sprintf(
      "tbcv1_%s_%02d_%s", parent$target_cell_id, seq_len(nrow(cell)),
      substr(hashes, 1L, 10L)
    )
    cell$screening_profile_id <- cell$candidate_id
    rows[[i]] <- .qdesn_tbcv1_profile_schema(cell)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  admitted <- out$history_disposition == "admitted_configured_unrun_not_evaluated"
  if (nrow(out) != 32L || sum(admitted) != 16L || anyDuplicated(out$candidate_id) ||
      anyDuplicated(paste(out$target_cell_id, out$profile_signature, sep = "\r")) ||
      any(out$profile_signature[!admitted] %in% history$profile_signature) ||
      any(out$effective_readout_dimension > qdesn_ssv2_max_effective_readout_dimension)) {
    stop("The 32-profile Tier-B candidate contract failed.", call. = FALSE)
  }
  out
}

qdesn_tbcv1_budget <- function(stage) {
  if (stage == "smoke") return(list(n_burn = 4L, n_mcmc = 4L, draws = 4L))
  if (stage == "calibration") return(list(n_burn = 200L, n_mcmc = 500L, draws = 32L))
  if (grepl("confirmation$", stage)) {
    return(list(n_burn = 5000L, n_mcmc = 20000L, draws = 200L))
  }
  list(n_burn = 1000L, n_mcmc = 3000L, draws = 100L)
}

qdesn_tbcv1_timeout_seconds <- function(stage) {
  if (stage == "smoke") 1800L else if (stage == "calibration") 21600L else
    if (grepl("confirmation$", stage)) 604800L else 86400L
}

qdesn_tbcv1_make_job <- function(repo_root, profile, target, source, stage,
                                  source_registry_path, chain_id = 1L,
                                  reservoir_seed_id = "r01") {
  base_stage <- if (stage %in% c("smoke", "calibration")) stage else
    if (grepl("confirmation$", stage)) "confirmation" else "wave1"
  helper_target <- target
  helper_target$current_value <- target$objective_current_value
  helper_target$comparator_value <- target$objective_comparator_value
  job <- qdesn_ssv2_make_job(
    repo_root, profile, helper_target, source, base_stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  request <- qdesn_ssv2_read_json(qdesn_ssv2_path(
    repo_root, target$parent_request_path[[1L]], must_work = TRUE
  ))
  likelihood <- as.character(target$likelihood_target[[1L]])
  if (!identical(likelihood, "al")) {
    stop("Tier-B v1 is scoped exclusively to AL-RHS cells.", call. = FALSE)
  }
  method_id <- as.character(
    request$config$inference$mcmc$slice$core_update_mode %||% "sigma_then_gamma"
  )
  job$config$inference$mcmc$slice <- request$config$inference$mcmc$slice
  budget <- qdesn_tbcv1_budget(stage)
  job$config$inference$likelihood_family <- likelihood
  job$config$inference$mcmc$n_burn <- budget$n_burn
  job$config$inference$mcmc$n_mcmc <- budget$n_mcmc
  job$config$sampling$nd_draws <- budget$draws
  job$config$synthesis$n_samp <- budget$draws
  job$config$metrics$posterior_metric_draws <- budget$draws
  job$config$validation$timeout_seconds <- qdesn_tbcv1_timeout_seconds(stage)
  job$config$outputs$retention_profile <- "storage_light_tierb_cellwise_mcmc_v1"
  old_id <- job$job_id
  job$job_id <- sub(paste0("^", base_stage), stage, old_id)
  job$stage <- stage
  job$spec_id <- paste0("tierb_cellwise_mcmc_v1__", job$job_id)
  job$config$validation_spec_id <- job$spec_id
  job$root_spec$root_id <- job$job_id
  job$root_spec$screening_stage <- qdesn_tbcv1_stage
  job$root_spec$screening_wave <- stage
  job$root_spec$likelihood_family <- likelihood
  job$inference_method_id <- method_id
  job$likelihood_target <- likelihood
  job$target_metrics <- strsplit(target$target_metrics[[1L]], ";", fixed = TRUE)[[1L]]
  job$current_metric_values <- as.list(setNames(
    as.numeric(target[1L, paste0("current_", qdesn_tbcv1_target_metrics)]),
    qdesn_tbcv1_target_metrics
  ))
  job$comparator_metric_values <- as.list(setNames(
    as.numeric(target[1L, paste0("comparator_", qdesn_tbcv1_target_metrics)]),
    qdesn_tbcv1_target_metrics
  ))
  job$study_contract$validation_stage <- qdesn_tbcv1_stage
  job$study_contract$tier <- target$tier[[1L]]
  job$study_contract$metric_specific_authority <- TRUE
  job$study_contract$posterior_recycled_as_prior <- FALSE
  job$study_contract$full_confirmation_requires_explicit_approval <- TRUE
  job$study_contract$closed_tier_a_decision <- qdesn_tbcv1_closed_tiera_decision
  job$schema_version <- "qdesn_tierb_cellwise_mcmc_v1_job_v1"
  job
}

qdesn_tbcv1_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ssv2_path(
    repo_root, "results", "qdesn_mcmc_validation", qdesn_tbcv1_stage,
    run_tag, "jobs", job_id
  )
}

qdesn_tbcv1_compact_forecast_metric_value <- function(job_root, metric) {
  lead_path <- file.path(job_root, "tables", "forecast_lead_metrics.csv")
  retention_path <- file.path(job_root, "manifest", "output_retention.json")
  if (!file.exists(lead_path) || !file.exists(retention_path)) return(NA_real_)
  lead <- qdesn_ssv2_read_csv(lead_path)
  retention <- qdesn_ssv2_read_json(retention_path)
  required <- c(
    "forecast_lead", "n_origins_scored", "forecast_qtrue_mae",
    "forecast_pinball_mean"
  )
  valid <- all(required %in% names(lead)) && nrow(lead) == 30L &&
    identical(sort(as.integer(lead$forecast_lead)), 1:30) &&
    sum(as.integer(lead$n_origins_scored)) == 1000L &&
    identical(as.character(retention$forecast_rolling_origin_status), "PASS") &&
    identical(as.integer(retention$forecast_rolling_origin_rows), 1000L) &&
    identical(as.integer(retention$forecast_lead_metrics_rows), 30L) &&
    isTRUE(retention$rolling_origin_ready_for_pruning) &&
    !isTRUE(retention$required_lead_export_failure)
  if (!isTRUE(valid)) return(NA_real_)
  weights <- as.numeric(lead$n_origins_scored)
  values <- if (metric == "forecast_qtrue_mae_H1000") {
    as.numeric(lead$forecast_qtrue_mae)
  } else if (metric %in% c("forecast_check_loss_H1000",
                           "forecast_pinball_H1000")) {
    as.numeric(lead$forecast_pinball_mean)
  } else {
    return(NA_real_)
  }
  if (any(!is.finite(weights)) || any(weights <= 0) ||
      any(!is.finite(values))) return(NA_real_)
  stats::weighted.mean(values, weights)
}

qdesn_tbcv1_metric_values <- function(job_root) {
  setNames(vapply(qdesn_tbcv1_target_metrics, function(metric) {
    value <- qdesn_ssv2_metric_value(
      job_root, metric, require_rolling = grepl("^forecast_", metric)
    )
    if (!is.finite(value) && grepl("^forecast_", metric)) {
      value <- qdesn_tbcv1_compact_forecast_metric_value(job_root, metric)
    }
    value
  }, numeric(1L)), qdesn_tbcv1_target_metrics)
}
