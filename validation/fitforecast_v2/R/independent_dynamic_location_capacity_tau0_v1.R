idlc_v1_repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)

source(file.path(
  idlc_v1_repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_canonical_gap_mcmc_v2.R"
))
source(file.path(
  idlc_v1_repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_trainonly_transport_audit_v2.R"
))

idlc_v1_stage <-
  "qdesn_dynamic_fitforecast_v2_500obs_dynamic_location_capacity_tau0_v1"
idlc_v1_schema <- "independent_dynamic_location_capacity_tau0_v1_job_v1"
idlc_v1_branch <-
  "validation/independent-dynamic-location-capacity-tau0-v1-1.0.0"
idlc_v1_max_effective_dimension <- 400L
idlc_v1_reconstruction_tolerance <- 1e-6
idlc_v1_target_metrics <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000"
)
idlc_v1_promotion_metrics <- c(
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
idlc_v1_config_stem <- file.path(
  "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_dynamic_location_capacity_tau0_v1"
)
idlc_v1_authorities <- data.frame(
  authority = c("point_interface_v9", "remaining_gap_v9", "metric_intervals_v10",
                "canonical_source_registry"),
  path = c(
    file.path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821",
      "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821_interface.csv"
    ),
    file.path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821",
      "remaining_gap_ledger.csv"
    ),
    file.path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_metric_intervals_v10_20260824",
      "article_metric_role_intervals.csv"
    ),
    file.path(
      "validation", "fitforecast_v2", "promotions",
      "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821",
      "evidence", "control", "canonical_source_registry.csv"
    )
  ),
  sha256 = c(
    "eb697b6f3e366581d158a41ecd2213761486be769b541439d2d862d840ea4b27",
    "18acdf841ecde4df7e518e9b92c1598edb6e31f19ed2d14b1fcd418cc6e94ab9",
    "313abc5a4123b4a51470d14194aa4b0028bfcfb3c7ce37369fb3ff2567c4d580",
    "ef8d83fb7c657dada928da3cf0427f73a3d70f98aae88886618bea0e81b13e46"
  ),
  stringsAsFactors = FALSE
)

idlc_v1_path <- function(repo_root, ...) {
  normalizePath(file.path(repo_root, ...), winslash = "/", mustWork = FALSE)
}

idlc_v1_assert_authorities <- function(repo_root) {
  rows <- idlc_v1_authorities
  rows$absolute_path <- vapply(rows$path, function(path) {
    normalizePath(file.path(repo_root, path), winslash = "/", mustWork = TRUE)
  }, character(1L))
  rows$observed_sha256 <- vapply(rows$absolute_path, qdesn_ssv2_sha256,
                                 character(1L))
  rows$status <- ifelse(rows$observed_sha256 == rows$sha256, "PASS", "FAIL")
  if (any(rows$status != "PASS")) {
    stop(sprintf("Frozen authority hash failed: %s",
                 paste(rows$authority[rows$status != "PASS"], collapse = ", ")),
         call. = FALSE)
  }
  rows
}

idlc_v1_read_targets <- function(repo_root) {
  path <- file.path(repo_root, paste0(idlc_v1_config_stem, "_target_cells.csv"))
  x <- qdesn_ssv2_read_csv(path)
  if (nrow(x) != 4L || anyDuplicated(x$target_cell_id) ||
      !identical(sort(unique(x$likelihood_target)), c("al", "exal")) ||
      !all(x$family == "normal") || !all(x$tier == "A")) {
    stop("The Tier-A target-cell contract has drifted.", call. = FALSE)
  }
  x$objective_current_value <- vapply(seq_len(nrow(x)), function(i) {
    as.numeric(x[[paste0("current_", x$objective_metric[[i]])]][[i]])
  }, numeric(1L))
  x$objective_comparator_value <- vapply(seq_len(nrow(x)), function(i) {
    as.numeric(x[[paste0("comparator_", x$objective_metric[[i]])]][[i]])
  }, numeric(1L))
  x$priority <- "tier_a"
  for (i in seq_len(nrow(x))) {
    request <- normalizePath(file.path(repo_root, x$parent_request_path[[i]]),
                             winslash = "/", mustWork = TRUE)
    if (!identical(qdesn_ssv2_sha256(request), x$parent_request_sha256[[i]])) {
      stop(sprintf("Parent request hash failed for %s", x$target_cell_id[[i]]),
           call. = FALSE)
    }
  }
  x
}

idlc_v1_read_tau0_ladder <- function(repo_root) {
  x <- qdesn_ssv2_read_csv(file.path(
    repo_root, paste0(idlc_v1_config_stem, "_tau0_ladder.csv")
  ))
  if (nrow(x) != 16L || any(!is.finite(x$tau0)) || any(x$tau0 < 1e-9) ||
      any(table(x$target_cell_id) != 4L) ||
      anyDuplicated(paste(x$target_cell_id, format(x$tau0, digits = 17), sep = "|"))) {
    stop("The cell-specific tau0 ladder contract has drifted.", call. = FALSE)
  }
  x
}

idlc_v1_profile_from_request <- function(request, profile_role = "P0_parent") {
  cfg <- request$config %||% request
  d <- cfg$desn
  D <- as.integer(d$D)[1L]
  n <- rep(as.integer(unlist(d$n, use.names = FALSE)), length.out = D)
  n_tilde <- if (D > 1L) {
    rep(as.integer(unlist(d$n_tilde, use.names = FALSE)), length.out = D - 1L)
  } else integer()
  alpha <- rep(as.numeric(unlist(d$alpha, use.names = FALSE)), length.out = D)
  rho <- rep(as.numeric(unlist(d$rho, use.names = FALSE)), length.out = D)
  pi_w <- rep(as.numeric(unlist(d$pi_w, use.names = FALSE)), length.out = D)
  pi_in <- rep(as.numeric(unlist(d$pi_in, use.names = FALSE)), length.out = D)
  tau0 <- as.numeric(
    cfg$inference$mcmc$priors$beta$rhs_ns$tau0 %||%
      cfg$inference$mcmc$prior_overrides$rhs_ns$tau0
  )[1L]
  row <- data.frame(
    D = D, n = qdesn_ssv2_pack(n), n_tilde = qdesn_ssv2_pack(n_tilde),
    m = as.integer(d$m)[1L], alpha = qdesn_ssv2_pack(alpha),
    rho = qdesn_ssv2_pack(rho), pi_w = qdesn_ssv2_pack(pi_w),
    pi_in = qdesn_ssv2_pack(pi_in), rhs_tau0 = tau0,
    readout_y_lags = as.integer(cfg$lags$m_y)[1L],
    reservoir_lags = as.integer(cfg$readout$reservoir_lags)[1L],
    washout = as.integer(d$washout)[1L], layer_shape = "frozen_parent",
    alpha_pattern = "frozen_parent", rho_pattern = "frozen_parent",
    expected_degree = NA_integer_, total_states = sum(n),
    effective_readout_dimension = qdesn_ssv2_effective_readout_dimension(
      n, n_tilde, as.integer(cfg$readout$reservoir_lags)[1L],
      as.integer(cfg$lags$m_y)[1L]
    ),
    max_alpha = max(alpha), min_alpha = min(alpha), mean_alpha = mean(alpha),
    max_rho = max(rho), min_rho = min(rho), mean_rho = mean(rho),
    design_role = "exact_current_forecast_parent",
    selection_arm = profile_role, stringsAsFactors = FALSE
  )
  row$profile_signature <- qdesn_ssv2_profile_signature(row)
  row
}

idlc_v1_alternative_profile <- function(row) {
  D <- as.integer(row$D[[1L]])
  n <- qdesn_ssv2_vec(row$n[[1L]], "integer")
  alpha <- qdesn_ssv2_vec(row$alpha[[1L]], "numeric")
  rho <- qdesn_ssv2_vec(row$rho[[1L]], "numeric")
  if (length(n) != D || length(alpha) != D || length(rho) != D) {
    stop(sprintf("Malformed architecture row: %s/%s",
                 row$target_cell_id[[1L]], row$profile_role[[1L]]), call. = FALSE)
  }
  .qdesn_ssv2_profile_row(
    D = D, n = n, m = as.integer(row$m[[1L]]), alpha = alpha, rho = rho,
    degree = as.integer(row$expected_degree[[1L]]), tau0 = 1,
    readout_y_lags = as.integer(row$readout_y_lags[[1L]]),
    reservoir_lags = as.integer(row$reservoir_lags[[1L]]),
    washout = as.integer(row$washout[[1L]]),
    layer_shape = as.character(row$layer_shape[[1L]]),
    alpha_pattern = as.character(row$alpha_pattern[[1L]]),
    rho_pattern = as.character(row$rho_pattern[[1L]]),
    design_role = as.character(row$design_rationale[[1L]]),
    selection_arm = as.character(row$profile_role[[1L]])
  )
}

idlc_v1_exact_signature <- function(target_cell_id, likelihood_target, family,
                                    tau, profile_signature, method_id) {
  paste(target_cell_id, likelihood_target, family,
        sprintf("%.8f", as.numeric(tau)), profile_signature, method_id, sep = "||")
}

idlc_v1_build_candidate_profiles <- function(repo_root) {
  targets <- idlc_v1_read_targets(repo_root)
  ladder <- idlc_v1_read_tau0_ladder(repo_root)
  architecture <- qdesn_ssv2_read_csv(file.path(
    repo_root, paste0(idlc_v1_config_stem, "_architecture_profiles.csv")
  ))
  if (nrow(architecture) != 12L || any(table(architecture$target_cell_id) != 3L) ||
      anyDuplicated(paste(architecture$target_cell_id, architecture$profile_role))) {
    stop("The architecture-profile contract has drifted.", call. = FALSE)
  }
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, , drop = FALSE]
    request <- qdesn_ssv2_read_json(file.path(repo_root, target$parent_request_path[[1L]]))
    parent <- idlc_v1_profile_from_request(request)
    alternatives <- lapply(
      split(architecture[architecture$target_cell_id == target$target_cell_id[[1L]],
                         , drop = FALSE],
            architecture$profile_role[architecture$target_cell_id ==
                                        target$target_cell_id[[1L]]]),
      idlc_v1_alternative_profile
    )
    base <- do.call(rbind, c(list(parent), alternatives))
    base <- base[match(c("P0_parent", "P1_compact_persistent",
                         "P2_multiscale_moderate", "P3_deep_selective"),
                       base$selection_arm), , drop = FALSE]
    cell_ladder <- ladder[ladder$target_cell_id == target$target_cell_id[[1L]],
                          , drop = FALSE]
    for (j in seq_len(nrow(base))) {
      for (h in seq_len(nrow(cell_ladder))) {
        k <- k + 1L
        z <- base[j, , drop = FALSE]
        z$rhs_tau0 <- as.numeric(cell_ladder$tau0[[h]])
        z$profile_signature <- qdesn_ssv2_profile_signature(z)
        z$target_cell_id <- target$target_cell_id[[1L]]
        z$family <- target$family[[1L]]
        z$tau <- target$tau[[1L]]
        z$priority <- target$tier[[1L]]
        z$objective_metric <- target$objective_metric[[1L]]
        z$current_value <- target$objective_current_value[[1L]]
        z$comparator_value <- target$objective_comparator_value[[1L]]
        z$parent_anchor_id <- basename(target$parent_request_path[[1L]])
        z$likelihood_target <- target$likelihood_target[[1L]]
        z$target_metrics <- target$target_metrics[[1L]]
        z$tau0_ladder_role <- cell_ladder$ladder_role[[h]]
        z$declared_replay <- z$selection_arm == "P0_parent"
        method <- if (z$likelihood_target == "exal") qdesn_ssv2_method_id else
          "sigma_then_gamma"
        z$exact_signature <- idlc_v1_exact_signature(
          z$target_cell_id, z$likelihood_target, z$family, z$tau,
          z$profile_signature, method
        )
        hash <- digest::digest(z$exact_signature, algo = "sha256", serialize = FALSE)
        z$candidate_id <- sprintf(
          "idlc1_%s_%s_%s_%s", z$target_cell_id, tolower(z$selection_arm),
          gsub("[^0-9a-z]", "", format(z$rhs_tau0, scientific = TRUE)),
          substr(hash, 1L, 10L)
        )
        z$screening_profile_id <- z$candidate_id
        rows[[k]] <- z
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (nrow(out) != 64L || any(table(out$target_cell_id) != 16L) ||
      any(table(paste(out$target_cell_id, out$selection_arm)) != 4L) ||
      anyDuplicated(out$exact_signature) || anyDuplicated(out$candidate_id) ||
      any(out$effective_readout_dimension > idlc_v1_max_effective_dimension) ||
      any(vapply(out$pi_w, function(x) any(qdesn_ssv2_vec(x, "numeric") <= 0),
                 logical(1L))) ||
      any(vapply(out$pi_in, function(x) any(qdesn_ssv2_vec(x, "numeric") <= 0),
                 logical(1L)))) {
    stop("The 64-candidate capacity-by-tau0 contract failed.", call. = FALSE)
  }
  out
}

idlc_v1_history_inventory <- function(repo_root) {
  tracked <- system2("git", c("-C", repo_root, "ls-files"), stdout = TRUE)
  csv <- tracked[grepl("[.]csv$", tracked) & grepl(
    "(candidate_profiles|history_signature_ledger|resolved_config|promoted_candidate_specifications)",
    basename(tracked), ignore.case = TRUE
  )]
  json <- tracked[grepl("[.]json$", tracked) & grepl(
    "(^config/validation/|/evidence/configs/)", tracked
  )]
  data.frame(
    path = c(csv, json), type = c(rep("csv", length(csv)), rep("json", length(json))),
    bytes = as.numeric(file.info(file.path(repo_root, c(csv, json)))$size),
    sha256 = vapply(file.path(repo_root, c(csv, json)), qdesn_ssv2_sha256,
                    character(1L)), stringsAsFactors = FALSE
  )
}

idlc_v1_history_signatures <- function(repo_root, inventory = NULL) {
  if (is.null(inventory)) inventory <- idlc_v1_history_inventory(repo_root)
  rows <- list()
  add <- function(path, source_row, target_cell_id, likelihood_target, family,
                  tau, profile_signature, method_id) {
    rows[[length(rows) + 1L]] <<- data.frame(
      source_file = path, source_row = as.integer(source_row),
      target_cell_id = as.character(target_cell_id %||% ""),
      likelihood_target = as.character(likelihood_target %||% ""),
      family = as.character(family %||% ""), tau = as.numeric(tau %||% NA_real_),
      profile_signature = as.character(profile_signature),
      method_id = as.character(method_id %||% ""), stringsAsFactors = FALSE
    )
  }
  for (i in seq_len(nrow(inventory))) {
    rel <- inventory$path[[i]]
    path <- file.path(repo_root, rel)
    if (inventory$type[[i]] == "csv") {
      x <- tryCatch(qdesn_ssv2_read_csv(path), error = function(e) NULL)
      if (is.null(x) || !nrow(x) || !"profile_signature" %in% names(x)) next
      for (j in seq_len(nrow(x))) {
        add(rel, j, x$target_cell_id[[j]] %||% "",
            x$likelihood_target[[j]] %||% x$likelihood_family[[j]] %||% "",
            x$family[[j]] %||% "", x$tau[[j]] %||% NA_real_,
            x$profile_signature[[j]], x$inference_method_id[[j]] %||% "")
      }
    } else {
      x <- tryCatch(qdesn_ssv2_read_json(path), error = function(e) NULL)
      if (is.null(x)) next
      cfg <- x$config %||% x
      if (is.null(cfg$desn) || is.null(cfg$inference)) next
      profile <- tryCatch(idlc_v1_profile_from_request(x), error = function(e) NULL)
      if (is.null(profile)) next
      likelihood <- as.character(
        x$likelihood_target %||% x$likelihood_family %||%
          cfg$inference$likelihood_family %||% ""
      )[1L]
      method <- as.character(
        x$inference_method_id %||% cfg$inference$mcmc$slice$core_update_mode %||% ""
      )[1L]
      add(rel, 1L, x$target_cell_id %||% "", likelihood,
          x$family %||% x$root_spec$family %||% "",
          x$tau %||% x$root_spec$tau %||% cfg$p_vec %||% NA_real_,
          profile$profile_signature[[1L]], method)
    }
  }
  if (!length(rows)) {
    return(data.frame(source_file = character(), source_row = integer(),
      target_cell_id = character(), likelihood_target = character(),
      family = character(), tau = numeric(), profile_signature = character(),
      method_id = character(), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  out <- out[nzchar(out$profile_signature) & !is.na(out$profile_signature), , drop = FALSE]
  out <- out[!duplicated(paste(out$target_cell_id, out$likelihood_target,
                               out$family, out$tau, out$profile_signature,
                               out$method_id, sep = "||")), , drop = FALSE]
  rownames(out) <- NULL
  out
}

idlc_v1_nonrepeat_audit <- function(candidates, history) {
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    candidate <- candidates[i, , drop = FALSE]
    same_profile <- history$profile_signature == candidate$profile_signature[[1L]]
    same_cell <- history$target_cell_id == candidate$target_cell_id[[1L]] |
      (!nzchar(history$target_cell_id) &
         history$family == candidate$family[[1L]] &
         abs(history$tau - candidate$tau[[1L]]) < 1e-10 &
         (history$likelihood_target == candidate$likelihood_target[[1L]] |
            !nzchar(history$likelihood_target)))
    match_idx <- which(same_profile & same_cell)
    duplicate <- length(match_idx) > 0L
    permitted <- !duplicate || isTRUE(candidate$declared_replay[[1L]])
    data.frame(
      candidate_id = candidate$candidate_id[[1L]],
      target_cell_id = candidate$target_cell_id[[1L]],
      profile_role = candidate$selection_arm[[1L]],
      rhs_tau0 = candidate$rhs_tau0[[1L]],
      exact_history_match = duplicate,
      declared_replay = isTRUE(candidate$declared_replay[[1L]]),
      decision = if (permitted) "PASS" else "FAIL_UNDECLARED_DUPLICATE",
      matched_history_rows = length(match_idx),
      matched_history_files = if (length(match_idx)) {
        paste(sort(unique(history$source_file[match_idx])), collapse = ";")
      } else "",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

idlc_v1_nearest_history <- function(candidates, history) {
  features <- function(signature) {
    parts <- strsplit(as.character(signature), "|", fixed = TRUE)[[1L]]
    if (length(parts) != 12L) return(rep(NA_real_, 11L))
    n <- qdesn_ssv2_vec(parts[[2L]], "numeric")
    alpha <- qdesn_ssv2_vec(parts[[5L]], "numeric")
    rho <- qdesn_ssv2_vec(parts[[6L]], "numeric")
    tau0 <- suppressWarnings(as.numeric(parts[[9L]]))
    c(
      D = suppressWarnings(as.numeric(parts[[1L]])) / 4,
      total_states = sum(n) / 600,
      m = suppressWarnings(as.numeric(parts[[4L]])) / 150,
      mean_alpha = mean(alpha), max_alpha = max(alpha),
      mean_rho = mean(rho), max_rho = max(rho),
      log10_tau0 = (log10(tau0) + 12) / 12,
      readout_y_lags = suppressWarnings(as.numeric(parts[[10L]])) / 6,
      reservoir_lags = suppressWarnings(as.numeric(parts[[11L]])) / 3,
      washout = suppressWarnings(as.numeric(parts[[12L]])) / 600
    )
  }
  rows <- lapply(seq_len(nrow(candidates)), function(i) {
    candidate <- candidates[i, , drop = FALSE]
    same_cell <- history[
      history$target_cell_id == candidate$target_cell_id[[1L]] &
        nzchar(history$profile_signature), , drop = FALSE
    ]
    if (!nrow(same_cell)) {
      return(data.frame(candidate_id = candidate$candidate_id[[1L]],
        target_cell_id = candidate$target_cell_id[[1L]], nearest_profile_signature = "",
        exact_match = FALSE, normalized_euclidean_distance = NA_real_,
        nearest_source_file = "", stringsAsFactors = FALSE))
    }
    candidate_features <- features(candidate$profile_signature[[1L]])
    history_features <- t(vapply(same_cell$profile_signature, features,
                                 numeric(length(candidate_features))))
    distances <- sqrt(rowSums(sweep(history_features, 2L, candidate_features, "-")^2))
    distances[!is.finite(distances)] <- Inf
    exact <- which(same_cell$profile_signature == candidate$profile_signature[[1L]])
    j <- if (length(exact)) exact[[1L]] else which.min(distances)
    data.frame(
      candidate_id = candidate$candidate_id[[1L]],
      target_cell_id = candidate$target_cell_id[[1L]],
      nearest_profile_signature = same_cell$profile_signature[[j]],
      exact_match = length(exact) > 0L,
      normalized_euclidean_distance = distances[[j]],
      nearest_source_file = same_cell$source_file[[j]], stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

idlc_v1_budget <- function(stage) {
  switch(stage,
    smoke = list(n_burn = 4L, n_mcmc = 8L, draws = 8L),
    screen = list(n_burn = 1000L, n_mcmc = 4000L, draws = 120L),
    replication = list(n_burn = 2500L, n_mcmc = 7500L, draws = 160L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, draws = 200L),
    stop(sprintf("Unknown IDLC stage: %s", stage), call. = FALSE)
  )
}

idlc_v1_timeout_seconds <- function(stage) {
  switch(stage, smoke = 3600L, screen = 259200L, replication = 432000L,
         confirmation = 604800L,
         stop(sprintf("Unknown IDLC stage: %s", stage), call. = FALSE))
}

idlc_v1_make_job <- function(repo_root, profile, target, source, stage,
                             source_registry_path, chain_id = 1L,
                             reservoir_seed_id = "screen_r01") {
  old_budget <- qdesn_fgav1_budget
  old_timeout <- qdesn_fgav1_timeout_seconds
  on.exit({
    assign("qdesn_fgav1_budget", old_budget, envir = .GlobalEnv)
    assign("qdesn_fgav1_timeout_seconds", old_timeout, envir = .GlobalEnv)
  }, add = TRUE)
  assign("qdesn_fgav1_budget", idlc_v1_budget, envir = .GlobalEnv)
  assign("qdesn_fgav1_timeout_seconds", idlc_v1_timeout_seconds,
         envir = .GlobalEnv)
  job <- qdesn_fgav1_make_job(
    repo_root, profile, target, source, stage, source_registry_path,
    chain_id = chain_id, reservoir_seed_id = reservoir_seed_id
  )
  job$schema_version <- idlc_v1_schema
  job$job_id <- paste(stage, profile$candidate_id[[1L]], "canonical_article",
                      reservoir_seed_id, sprintf("c%02d", chain_id), sep = "__")
  job$spec_id <- paste0("independent_dynamic_location_capacity_tau0_v1__",
                        job$job_id)
  job$config$validation_spec_id <- job$spec_id
  job$root_spec$root_id <- job$job_id
  job$root_spec$screening_stage <- idlc_v1_stage
  job$root_spec$screening_wave <- stage
  job$study_contract$validation_stage <- idlc_v1_stage
  job$study_contract$authority_interface <-
    idlc_v1_authorities$path[idlc_v1_authorities$authority == "point_interface_v9"]
  job$study_contract$metric_interval_authority <-
    idlc_v1_authorities$path[idlc_v1_authorities$authority == "metric_intervals_v10"]
  job$study_contract$capacity_by_tau0_factorial <- TRUE
  job$study_contract$case_specific_selection <- TRUE
  job$study_contract$diagnostics_are_promotion_veto <- FALSE
  job$study_contract$promotion_requires_strict_metric_gain <- TRUE
  job$study_contract$global_specification_required <- FALSE
  job$study_contract$oracle_diagnostics_are_non_deployable <- TRUE
  job$config$outputs$retention_profile <-
    "storage_light_dynamic_location_capacity_tau0_v1"
  budget <- idlc_v1_budget(stage)
  job$config$metrics$posterior_metric_draws <- budget$draws
  job$config$metrics$posterior_metric_intervals <- list(
    enabled = TRUE, required = TRUE, draws = budget$draws,
    chain_id = as.integer(chain_id),
    estimator_id = "posterior_mean_draw_metric_equal_tailed_95cri_v1",
    draw_source_contract = "conditional_quantile_not_response_predictive",
    coupling_sensitivity = list(enabled = FALSE),
    dispersion_diagnostic = list(
      enabled = TRUE, required = TRUE, recursion_counterfactual = TRUE,
      schema_version = "independent_qdesn_metric_interval_dispersion_v1"
    ),
    origin_horizon_attribution = list(
      enabled = TRUE, required = TRUE, balanced_complete_origins = TRUE,
      schema_version = "independent_qdesn_origin_horizon_attribution_v1"
    ),
    common_shift_intervention = list(
      enabled = TRUE, required = TRUE,
      schema_version = "independent_qdesn_common_shift_intervention_v1"
    )
  )
  job$config$sampling$nd_draws <- budget$draws
  job$config$sampling$chunk <- min(120L, budget$draws)
  job$config$synthesis$n_samp <- budget$draws
  job$config$validation$timeout_seconds <- idlc_v1_timeout_seconds(stage)
  job$config$validation$timeout_kill_after_seconds <- 60L
  job$config$cpp$postpred_threads <- 1L
  job$config$outputs$keep_draws <- FALSE
  job$config$outputs$keep_mcmc_vb_init <- FALSE
  job$config$outputs$save_forecast_objects <- FALSE
  job$config$outputs$save_compact_fit_paths <- TRUE
  job$config$outputs$save_metric_summaries <- TRUE
  job$config$outputs$retain_full_rds_on_failure <- FALSE
  job$root_spec$effective_readout_dimension <-
    qdesn_cgcv2_effective_dimension(profile)
  job
}

idlc_v1_apply_seeds <- function(job) {
  key <- paste(idlc_v1_stage, job$stage, job$target_cell_id,
               job$candidate_id, job$reservoir_seed_id, job$chain_id, sep = "|")
  job$config$desn$seed <- qdesn_cgcv2_seed(key, "desn")
  job$config$inference$mcmc$control$seed <- qdesn_cgcv2_seed(key, "mcmc")
  job$config$inference$mcmc$control$rng_seed <- qdesn_cgcv2_seed(key, "rng")
  job$config$inference$mcmc$vb_warm_start_seed <- qdesn_cgcv2_seed(key, "vb")
  job$config$synthesis$seed <- qdesn_cgcv2_seed(key, "synthesis")
  job$root_spec$desn_seed <- job$config$desn$seed
  job$root_spec$mcmc_seed <- job$config$inference$mcmc$control$seed
  job$root_spec$mcmc_rng_seed <- job$config$inference$mcmc$control$rng_seed
  job$root_spec$vb_warm_start_seed <-
    job$config$inference$mcmc$vb_warm_start_seed
  job$root_spec$synthesis_seed <- job$config$synthesis$seed
  job
}

idlc_v1_job_root <- function(repo_root, run_tag, job_id) {
  qdesn_ssv2_path(repo_root, "results", "qdesn_mcmc_validation",
                  idlc_v1_stage, run_tag, "jobs", job_id)
}

idlc_v1_metric_values <- qdesn_cgcv2_metric_values

idlc_v1_stage_full_source_window <- function(root, m, washout, output_root) {
  series <- qdesn_ssv2_read_csv(root$series_wide_path[[1L]])
  if (nrow(series) != 10000L) {
    stop("The full canonical source must cover indices 1:10000.", call. = FALSE)
  }
  all_idx <- seq_len(nrow(series))
  raw_start <- 8501L - as.integer(m) - as.integer(washout)
  if (raw_start < 1L) stop("The requested prehistory exceeds the full source.")
  keep <- all_idx >= raw_start
  x <- series[keep, , drop = FALSE]
  idx <- all_idx[keep]
  x$source_index <- idx
  x$t <- seq_len(nrow(x))
  dir <- file.path(
    output_root, root$family[[1L]],
    sprintf("tau_%s", sub("[.]", "p", sprintf("%.2f", root$tau[[1L]]))),
    sprintf("m%d_w%d", m, washout)
  )
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  series_path <- qdesn_ssv2_write_csv(x, file.path(dir, "series_wide.csv"))
  selection_path <- qdesn_ssv2_write_csv(
    data.frame(t = seq_len(nrow(x)), source_index = idx),
    file.path(dir, "selection_indices.csv")
  )
  phase1 <- 2 * pi * idx / 90
  phase2 <- 4 * pi * idx / 90
  trend <- (idx - mean(idx)) / stats::sd(idx)
  observed_path <- qdesn_ssv2_write_csv(data.frame(
    y = x$y, period90_sin_h1 = sin(phase1), period90_cos_h1 = cos(phase1),
    period90_sin_h2 = sin(phase2), period90_cos_h2 = cos(phase2),
    period90_trend_z = trend
  ), file.path(dir, "observed.csv"))
  qtrue_path <- qdesn_ssv2_write_csv(data.frame(
    t = seq_len(nrow(x)), source_index = idx, q_true = x$q_target,
    y = x$y, mu = x$mu
  ), file.path(dir, "q_true.csv"))
  data.frame(
    source_id = "canonical_article", source_role = "canonical_confirmation",
    scenario = root$scenario, family = root$family, tau = root$tau,
    m = as.integer(m), washout = as.integer(washout),
    raw_start_source_index = raw_start, raw_end_source_index = 10000L,
    train_start_source_index = 8501L, train_end_source_index = 9000L,
    forecast_start_source_index = 9001L, forecast_end_source_index = 10000L,
    source_total_size = nrow(x), source_series_wide_path = series_path,
    source_series_wide_sha256 = qdesn_ssv2_sha256(series_path),
    source_selection_indices_path = selection_path,
    source_selection_indices_sha256 = qdesn_ssv2_sha256(selection_path),
    source_sim_path = root$sim_output_path,
    source_sim_sha256 = root$sim_output_sha256,
    source_master_path = root$series_wide_path,
    source_master_sha256 = root$series_wide_sha256,
    source_latent_seed = NA_integer_, source_noise_seed = NA_integer_,
    observed_path = observed_path,
    observed_sha256 = qdesn_ssv2_sha256(observed_path),
    qtrue_path = qtrue_path, qtrue_sha256 = qdesn_ssv2_sha256(qtrue_path),
    stringsAsFactors = FALSE
  )
}

idlc_v1_required_diagnostic_paths <- function(job_root) {
  file.path(job_root, c(
    "tables/metric_draws.csv.gz",
    "tables/metric_interval_summary.csv",
    "tables/metric_dispersion_mechanism_summary.csv",
    "tables/metric_dispersion_draw_diagnostics.csv.gz",
    "tables/origin_horizon_group_draws.csv.gz",
    "tables/origin_horizon_reconstruction_audit.csv",
    "tables/common_shift_intervention_summary.csv",
    "tables/common_shift_intervention_effects.csv",
    "manifest/metric_interval_manifest.json",
    "manifest/metric_dispersion_manifest.json",
    "manifest/origin_horizon_attribution_manifest.json",
    "manifest/common_shift_intervention_manifest.json"
  ))
}

idlc_v1_write_design_diagnostics <- function(job, observed_path, job_root) {
  cfg <- job$config
  observed <- qdesn_ssv2_read_csv(observed_path)
  n_train <- as.integer(cfg$split$train_n)
  x_names <- as.character(unlist(cfg$columns$x, use.names = FALSE))
  X <- if (length(x_names)) as.matrix(observed[, x_names, drop = FALSE]) else NULL
  scaled <- qdesn_ttav2_scale_train_only(observed$y, X, n_train)
  d <- cfg$desn
  D <- as.integer(d$D)
  d$n <- rep(as.integer(unlist(d$n, use.names = FALSE)), length.out = D)
  d$n_tilde <- if (D > 1L) {
    as.integer(unlist(d$n_tilde, use.names = FALSE))
  } else integer()
  allowed <- c("D", "n", "n_tilde", "m", "alpha", "rho", "act_f", "act_k",
               "pi_w", "pi_in", "washout", "add_bias", "seed")
  readout <- ms_build_readout_design_real(
    y_full = scaled$y, X_use = scaled$X, cfg = cfg,
    desn_args = d[intersect(names(d), allowed)],
    readout_include_input = isTRUE(cfg$readout$include_input),
    readout_reservoir_lags = as.integer(cfg$readout$reservoir_lags),
    readout_scale = isTRUE(cfg$inference$readout_scale),
    readout_input_mode = cfg$readout$input_mode,
    readout_decomposition = cfg$decomposition
  )
  raw_start <- as.integer(job$root_spec$raw_start_source_index)
  effective_start <- as.integer(job$root_spec$train_start_source_index) - raw_start + 1L
  effective_end <- as.integer(job$root_spec$train_end_source_index) - raw_start + 1L
  train_idx <- readout$keep_aug_abs >= effective_start &
    readout$keep_aug_abs <= effective_end
  forecast_idx <- readout$keep_aug_abs > effective_end
  diag <- qdesn_ttav2_matrix_diagnostics(
    readout$X_aug_all[train_idx, , drop = FALSE],
    readout$X_aug_all[forecast_idx, , drop = FALSE],
    readout$X_res_all[train_idx, , drop = FALSE],
    readout$X_res_all[forecast_idx, , drop = FALSE]
  )
  diag$job_id <- job$job_id
  diag$target_cell_id <- job$target_cell_id
  diag$candidate_id <- job$candidate_id
  diag$profile_role <- job$profile$selection_arm
  diag$rhs_tau0 <- as.numeric(job$profile$rhs_tau0)
  diag$expected_effective_dimension <-
    as.integer(job$root_spec$effective_readout_dimension)
  diag$topology_nonzero_probability <- all(
    qdesn_ssv2_vec(job$profile$pi_w, "numeric") > 0
  ) && all(qdesn_ssv2_vec(job$profile$pi_in, "numeric") > 0)
  diag$y_center <- scaled$y_center
  diag$y_scale <- scaled$y_scale
  qdesn_ssv2_write_csv(diag, file.path(
    job_root, "tables", "design_conditioning_diagnostics.csv"
  ))
}

idlc_v1_collect_result <- function(repo_root, run_tag, plan_row) {
  root <- idlc_v1_job_root(repo_root, run_tag, plan_row$job_id[[1L]])
  status_path <- file.path(root, "job_status.json")
  status <- if (file.exists(status_path)) qdesn_ssv2_read_json(status_path) else
    list(status = "MISSING")
  values <- idlc_v1_metric_values(root)
  data.frame(
    job_id = plan_row$job_id[[1L]], stage = plan_row$stage[[1L]],
    target_cell_id = plan_row$target_cell_id[[1L]],
    likelihood_target = plan_row$likelihood_target[[1L]],
    candidate_id = plan_row$candidate_id[[1L]],
    profile_role = plan_row$profile_role[[1L]], rhs_tau0 = plan_row$rhs_tau0[[1L]],
    chain_id = plan_row$chain_id[[1L]], status = as.character(status$status),
    fit_qtrue_rmse = values[["fit_qtrue_rmse"]],
    forecast_qtrue_mae_H1000 = values[["forecast_qtrue_mae_H1000"]],
    forecast_check_loss_H1000 = values[["forecast_check_loss_H1000"]],
    metric_interval_summary_path = file.path(root, "tables", "metric_interval_summary.csv"),
    common_shift_effects_path = file.path(root, "tables", "common_shift_intervention_effects.csv"),
    origin_horizon_reconstruction_path = file.path(
      root, "tables", "origin_horizon_reconstruction_audit.csv"
    ),
    design_conditioning_path = file.path(
      root, "tables", "design_conditioning_diagnostics.csv"
    ),
    binary_payloads_remaining = as.integer(
      status$binary_payloads_remaining %||% NA_integer_
    ), stringsAsFactors = FALSE
  )
}
