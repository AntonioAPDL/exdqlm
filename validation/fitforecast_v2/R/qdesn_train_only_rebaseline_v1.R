`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_tor1_safe_token <- function(x, max_chars = 44L) {
  value <- tolower(trimws(as.character(x)[1L]))
  value <- gsub("[^a-z0-9]+", "_", value)
  value <- gsub("^_+|_+$", "", value)
  if (!nzchar(value)) value <- "candidate"
  substr(value, 1L, as.integer(max_chars)[1L])
}

qdesn_tor1_metric_contract <- function(article_envelope) {
  q_rows <- article_envelope[grepl("^qdesn_", article_envelope$model_variant), , drop = FALSE]
  expected_variants <- c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
  if (nrow(q_rows) != 18L || !setequal(q_rows$model_variant, expected_variants)) {
    stop("Expected exactly 18 Q-DESN rows across AL-RHS and exAL-RHS.", call. = FALSE)
  }

  definitions <- list(
    list(
      metric_name = "fit_qtrue_rmse",
      value_col = "fit_qtrue_rmse",
      candidate_col = "fit_source_candidate_id",
      run_tag_col = "fit_source_run_tag",
      status_col = "fit_source_status",
      signoff_col = "fit_source_signoff_grade",
      path_col = "fit_source_path",
      hash_col = "fit_source_sha256"
    ),
    list(
      metric_name = "forecast_qtrue_mae_H1000",
      value_col = "forecast_qtrue_mae_H1000",
      candidate_col = "forecast_mae_source_candidate_id",
      run_tag_col = "forecast_mae_source_run_tag",
      status_col = "forecast_mae_source_status",
      signoff_col = "forecast_mae_source_signoff_grade",
      path_col = "forecast_mae_source_path",
      hash_col = "forecast_mae_source_sha256"
    ),
    list(
      metric_name = "forecast_check_loss_H1000",
      value_col = "forecast_check_loss_H1000",
      candidate_col = "forecast_check_source_candidate_id",
      run_tag_col = "forecast_check_source_run_tag",
      status_col = "forecast_check_source_status",
      signoff_col = "forecast_check_source_signoff_grade",
      path_col = "forecast_check_source_path",
      hash_col = "forecast_check_source_sha256"
    )
  )

  rows <- lapply(definitions, function(definition) {
    data.frame(
      model_variant = q_rows$model_variant,
      family = q_rows$family,
      tau = as.numeric(q_rows$tau),
      fit_size = as.integer(q_rows$fit_size),
      metric_name = definition$metric_name,
      legacy_metric_value = as.numeric(q_rows[[definition$value_col]]),
      legacy_candidate_id = as.character(q_rows[[definition$candidate_col]]),
      legacy_run_tag = as.character(q_rows[[definition$run_tag_col]]),
      legacy_status = as.character(q_rows[[definition$status_col]]),
      legacy_signoff_grade = as.character(q_rows[[definition$signoff_col]]),
      legacy_source_path = as.character(q_rows[[definition$path_col]]),
      legacy_source_sha256 = as.character(q_rows[[definition$hash_col]]),
      source_registry_hash_value = as.character(q_rows$source_registry_hash_value),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$likelihood_target <- ifelse(out$model_variant == "qdesn_al_rhs_ns", "al", "exal")
  out$cell_id <- sprintf(
    "%s_%s_t%s",
    out$likelihood_target,
    out$family,
    gsub("\\.", "p", format(out$tau, trim = TRUE, scientific = FALSE))
  )
  out$candidate_key <- paste(
    out$model_variant,
    out$family,
    sprintf("%.8f", out$tau),
    out$legacy_candidate_id,
    out$legacy_run_tag,
    sep = "\r"
  )
  if (anyNA(out$legacy_metric_value) || any(!is.finite(out$legacy_metric_value)) ||
      any(!nzchar(out$legacy_candidate_id)) || nrow(out) != 54L) {
    stop("The legacy Q-DESN metric-source contract is incomplete.", call. = FALSE)
  }
  out
}

qdesn_tor1_profile_base <- function(candidate_id) {
  value <- sub("__seed_[0-9]+$", "", as.character(candidate_id))
  sub("__full_[a-z0-9]+$", "", value)
}

qdesn_tor1_seed_dir <- function(candidate_id) {
  match <- regexec("__seed_([0-9]+)$", as.character(candidate_id))
  pieces <- regmatches(as.character(candidate_id), match)[[1L]]
  if (length(pieces) < 2L) return(NA_character_)
  sprintf("seed_%02d", as.integer(pieces[[2L]]))
}

qdesn_tor1_find_run_dir <- function(run_tag, search_roots) {
  matches <- unlist(lapply(search_roots, function(root) {
    Sys.glob(file.path(root, "results", "qdesn_mcmc_validation", "*", run_tag))
  }), use.names = FALSE)
  matches <- unique(normalizePath(matches, winslash = "/", mustWork = FALSE))
  matches <- matches[dir.exists(matches)]
  if (length(matches) != 1L) {
    stop(sprintf(
      "Expected one source run directory for `%s`; found %d.",
      run_tag,
      length(matches)
    ), call. = FALSE)
  }
  matches[[1L]]
}

qdesn_tor1_resolve_fit_request <- function(candidate_id, run_tag, family, tau,
                                            likelihood_target, search_roots,
                                            request_cache = NULL) {
  run_dir <- qdesn_tor1_find_run_dir(run_tag, search_roots)
  cache_key <- run_dir
  requests <- if (!is.null(request_cache) && exists(cache_key, request_cache, inherits = FALSE)) {
    get(cache_key, request_cache, inherits = FALSE)
  } else {
    value <- list.files(
      run_dir,
      pattern = "^fit_request\\.json$",
      recursive = TRUE,
      full.names = TRUE
    )
    if (!is.null(request_cache)) assign(cache_key, value, request_cache)
    value
  }

  profile_id <- qdesn_tor1_profile_base(candidate_id)
  profile_segment <- paste0("__profile_", profile_id, "/")
  method_segment <- paste0("/fits/mcmc_", likelihood_target, "/")
  keep <- grepl(profile_segment, requests, fixed = TRUE) &
    grepl(method_segment, requests, fixed = TRUE)
  seed_dir <- qdesn_tor1_seed_dir(candidate_id)
  if (!is.na(seed_dir)) {
    keep <- keep & grepl(paste0("/seeds/", seed_dir, "/"), requests, fixed = TRUE)
  } else {
    keep <- keep & !grepl("/seeds/seed_", requests, fixed = TRUE)
  }
  matches <- requests[keep]
  if (length(matches) > 1L) {
    identity_match <- vapply(matches, function(path) {
      request <- jsonlite::read_json(path, simplifyVector = TRUE)
      root <- request$root_spec
      identical(as.character(root$source_family), as.character(family)) &&
        isTRUE(abs(as.numeric(root$tau) - as.numeric(tau)) <= 1e-12) &&
        identical(as.character(root$likelihood_family), as.character(likelihood_target))
    }, logical(1L))
    matches <- matches[identity_match]
  }
  if (length(matches) != 1L) {
    stop(sprintf(
      "Expected one fit request for `%s` in `%s`; found %d.",
      candidate_id,
      run_tag,
      length(matches)
    ), call. = FALSE)
  }
  normalizePath(matches[[1L]], winslash = "/", mustWork = TRUE)
}

qdesn_tor1_scalar_layer_value <- function(x, field, allow_empty = FALSE) {
  value <- as.numeric(unlist(x, use.names = FALSE))
  if (!length(value) && isTRUE(allow_empty)) return(0)
  if (!length(value) || any(!is.finite(value))) {
    stop(sprintf("Effective design field `%s` is missing or non-finite.", field), call. = FALSE)
  }
  if (max(abs(value - value[[1L]])) > 1e-12) {
    stop(sprintf(
      "Effective design field `%s` is layer-specific and cannot use the scalar profile contract.",
      field
    ), call. = FALSE)
  }
  value[[1L]]
}

qdesn_tor1_extract_candidate_profiles <- function(candidate_contract, search_roots,
                                                   expected_registry_hash) {
  required <- c(
    "candidate_key", "legacy_candidate_id", "legacy_run_tag", "model_variant",
    "family", "tau", "likelihood_target"
  )
  missing <- setdiff(required, names(candidate_contract))
  if (length(missing)) {
    stop(sprintf("Candidate contract missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  request_cache <- new.env(parent = emptyenv())
  rows <- lapply(seq_len(nrow(candidate_contract)), function(i) {
    candidate <- candidate_contract[i, , drop = FALSE]
    request_path <- qdesn_tor1_resolve_fit_request(
      candidate$legacy_candidate_id,
      candidate$legacy_run_tag,
      candidate$family,
      candidate$tau,
      candidate$likelihood_target,
      search_roots,
      request_cache
    )
    request <- jsonlite::read_json(request_path, simplifyVector = TRUE)
    cfg <- request$config
    root <- request$root_spec
    request_methods <- as.character(
      request$execution$methods %||% request$method %||% character(0)
    )
    if (!("mcmc" %in% request_methods) ||
        !identical(as.character(root$source_family), as.character(candidate$family)) ||
        abs(as.numeric(root$tau) - as.numeric(candidate$tau)) > 1e-12 ||
        !identical(as.character(root$likelihood_family), as.character(candidate$likelihood_target))) {
      stop(sprintf("Fit-request identity mismatch: %s", request_path), call. = FALSE)
    }
    if (as.integer(cfg$split$T_use) != 1890L || as.integer(cfg$split$train_n) != 890L ||
        !isTRUE(cfg$preproc$scale_y) || !isTRUE(cfg$preproc$scale_x) ||
        as.integer(cfg$forecast$horizon) != 30L ||
        as.integer(cfg$forecast$origin_stride) != 30L ||
        isTRUE(cfg$forecast$refit_per_origin %||% FALSE)) {
      stop(sprintf("Fit-request protocol mismatch: %s", request_path), call. = FALSE)
    }

    D <- as.integer(cfg$desn$D)
    n_each <- qdesn_tor1_scalar_layer_value(cfg$desn$n, "desn.n")
    n_tilde_each <- qdesn_tor1_scalar_layer_value(
      cfg$desn$n_tilde,
      "desn.n_tilde",
      allow_empty = D == 1L
    )
    alpha <- qdesn_tor1_scalar_layer_value(cfg$desn$alpha, "desn.alpha")
    rho <- qdesn_tor1_scalar_layer_value(cfg$desn$rho, "desn.rho")
    pi_w <- qdesn_tor1_scalar_layer_value(cfg$desn$pi_w, "desn.pi_w")
    pi_in <- qdesn_tor1_scalar_layer_value(cfg$desn$pi_in, "desn.pi_in")
    rhs_tau0 <- as.numeric(
      cfg$inference$mcmc$priors$beta$rhs_ns$tau0 %||%
        cfg$inference$mcmc$priors$beta$rhs$tau0 %||%
        root$rhs_tau0
    )
    dimension <- as.integer(root$dimension_p_estimate %||%
      (1L + as.integer(cfg$lags$m_y) + D * as.integer(n_each)))
    new_profile_id <- sprintf(
      "tor1_%02d_%s",
      i,
      qdesn_tor1_safe_token(candidate$legacy_candidate_id)
    )

    data.frame(
      candidate_key = candidate$candidate_key,
      screening_profile_id = new_profile_id,
      screening_stage = "mcmc_train_only_preprocessing_rebaseline_v1",
      screening_wave = "train_only_preprocessing_rebaseline_2026_08_04",
      profile_role = "exact_current_metric_source_design_rebaseline",
      enabled = TRUE,
      D = D,
      n_each = as.integer(n_each),
      n_tilde_each = as.integer(n_tilde_each),
      m = as.integer(cfg$desn$m),
      alpha = alpha,
      rho = rho,
      pi_w = pi_w,
      pi_in = pi_in,
      washout = as.integer(cfg$desn$washout),
      add_bias = isTRUE(cfg$desn$add_bias),
      seed = as.integer(cfg$desn$seed),
      readout_y_lags = as.integer(cfg$lags$m_y),
      reservoir_lags = as.integer(cfg$readout$reservoir_lags),
      rhs_tau0 = rhs_tau0,
      dimension_p_estimate = dimension,
      p_over_n_tt500 = dimension / 500,
      x_feature_count = 5L,
      target_cells = sprintf(
        "%s:%s:%s",
        candidate$family,
        format(candidate$tau, trim = TRUE, scientific = FALSE),
        candidate$likelihood_target
      ),
      model_variant = candidate$model_variant,
      target_family = candidate$family,
      target_tau = as.numeric(candidate$tau),
      likelihood_target = candidate$likelihood_target,
      legacy_candidate_id = candidate$legacy_candidate_id,
      legacy_run_tag = candidate$legacy_run_tag,
      legacy_profile_id = qdesn_tor1_profile_base(candidate$legacy_candidate_id),
      source_fit_request_path = request_path,
      source_fit_request_sha256 = unname(tools::sha256sum(request_path)),
      source_effective_desn_seed = as.integer(cfg$desn$seed),
      source_root_seed = as.integer(root$seed %||% NA_integer_),
      source_mcmc_seed = as.integer(root$mcmc_seed %||% NA_integer_),
      source_mcmc_rng_seed = as.integer(root$mcmc_rng_seed %||% NA_integer_),
      source_vb_warm_start_seed = as.integer(root$vb_warm_start_seed %||% NA_integer_),
      source_synthesis_seed = as.integer(root$synthesis_seed %||% NA_integer_),
      source_registry_hash_value = expected_registry_hash,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (anyDuplicated(out$screening_profile_id) || anyDuplicated(out$candidate_key)) {
    stop("Rebaseline candidate profiles are not unique.", call. = FALSE)
  }
  out
}

qdesn_tor1_assign_fresh_seeds <- function(grid, profile_contract) {
  index <- match(grid$screening_profile_id, profile_contract$screening_profile_id)
  if (anyNA(index)) stop("Grid/profile mapping failed while assigning seeds.", call. = FALSE)
  ordinal <- as.integer(index)
  # Keep the canonical run-level `seed` already assigned by the grid builder.
  # The recovered reservoir realization belongs in the distinct `desn_seed`
  # field; this distinction matters for historical multi-seed designs.
  grid$desn_seed <- as.integer(profile_contract$source_effective_desn_seed[index])
  grid$mcmc_seed <- 820000L + ordinal
  grid$mcmc_rng_seed <- 830000L + ordinal
  grid$vb_warm_start_seed <- 840000L + ordinal
  grid$synthesis_seed <- 850000L + ordinal
  grid$legacy_candidate_id <- profile_contract$legacy_candidate_id[index]
  grid$legacy_run_tag <- profile_contract$legacy_run_tag[index]
  grid$source_fit_request_path <- profile_contract$source_fit_request_path[index]
  grid$source_fit_request_sha256 <- profile_contract$source_fit_request_sha256[index]
  grid$model_variant <- profile_contract$model_variant[index]
  grid$likelihood_target <- profile_contract$likelihood_target[index]
  grid$source_registry_hash_value <- profile_contract$source_registry_hash_value[index]
  grid
}
