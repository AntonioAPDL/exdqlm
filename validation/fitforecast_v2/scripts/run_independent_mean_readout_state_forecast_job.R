#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/run_independent_mean_readout_state_forecast_job.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
forecast_id <- as.character(args$`forecast-id` %||% "")[[1L]]
config_path <- normalizePath(args$config %||% "", winslash = "/", mustWork = TRUE)
if (!nzchar(forecast_id)) stop("--forecast-id is required.", call. = FALSE)
setwd(repo_root)
imrs_v1_set_one_thread()

config_sha <- ffv2_file_sha256(config_path)
request <- ffv2_read_json(config_path)
if (!identical(as.character(request$schema_version), imrs_v1_schema) ||
    !identical(as.character(request$forecast_id), forecast_id)) {
  stop("Forecast job schema or identity mismatch.", call. = FALSE)
}
if (imrs_v1_status_success(state_root, "forecast", forecast_id, config_sha)) {
  cat("skip verified forecast job ", forecast_id, "\n", sep = "")
  quit(save = "no", status = 0L)
}

started <- Sys.time()
imrs_v1_write_status(state_root, "forecast", forecast_id, list(
  status = "RUNNING", request_sha256 = config_sha, pid = Sys.getpid(),
  host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
))

status <- "FAILED"
error_message <- NULL
result_payload <- list()
log_step <- function(...) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              sprintf(...)))
  flush.console()
}
tryCatch({
  log_step("loading verified fit dependencies for %s", forecast_id)
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.")
  pkgload::load_all(repo_root, quiet = TRUE)
  fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
  fit_ids <- as.character(unlist(request$fit_job_ids, use.names = FALSE))
  rows <- fit_plan[match(fit_ids, fit_plan$job_id), , drop = FALSE]
  if (nrow(rows) != length(fit_ids) || anyNA(rows$job_id) ||
      nrow(rows) != as.integer(request$expected_chains)) {
    stop("Forecast dependency plan is incomplete.", call. = FALSE)
  }

  fit_status <- lapply(fit_ids, function(id) {
    path <- imrs_v1_status_path(state_root, "fit", id)
    if (!file.exists(path)) stop("Missing fit status: ", id, call. = FALSE)
    imrs_v1_read_json(path)
  })
  if (any(vapply(fit_status, function(x) !identical(x$status, "SUCCESS"), logical(1L)))) {
    stop("One or more forecast dependencies are not successful.", call. = FALSE)
  }
  fit_configs <- lapply(seq_len(nrow(rows)), function(i) {
    path <- normalizePath(rows$config_path[[i]], winslash = "/", mustWork = TRUE)
    if (!identical(ffv2_file_sha256(path), rows$config_sha256[[i]])) {
      stop("Fit configuration hash mismatch: ", rows$job_id[[i]], call. = FALSE)
    }
    ffv2_read_json(path)
  })
  policy_hashes <- vapply(fit_configs, function(x) {
    imrs_v1_object_sha256(x$native_authority$compatibility_policy)
  }, character(1L))
  if (length(unique(policy_hashes)) != 1L) {
    stop("Forecast dependencies use incompatible authority policies.", call. = FALSE)
  }
  compatibility_policy <- imrs_v1_historical_compatibility_policy(
    fit_configs[[1L]]$native_authority$compatibility_policy
  )

  bases <- Map(function(row, stat) {
    path <- normalizePath(stat$basis_capsule_path, winslash = "/", mustWork = TRUE)
    if (!identical(imrs_v1_sha256(path), stat$basis_capsule_sha256)) {
      stop("Basis capsule hash mismatch: ", row$job_id, call. = FALSE)
    }
    readRDS(path)
  }, split(rows, seq_len(nrow(rows))), fit_status)
  posteriors <- Map(function(row, stat) {
    path <- normalizePath(stat$posterior_capsule_path, winslash = "/", mustWork = TRUE)
    if (!identical(imrs_v1_sha256(path), stat$posterior_capsule_sha256)) {
      stop("Posterior capsule hash mismatch: ", row$job_id, call. = FALSE)
    }
    readRDS(path)
  }, split(rows, seq_len(nrow(rows))), fit_status)

  hashes <- unique(vapply(bases, `[[`, character(1L), "feature_basis_hash"))
  compatible <- identical(as.character(request$pooling_policy),
                          "compatible_basis_chain_pool")
  if (compatible && length(hashes) != 1L) {
    stop("Compatible-basis forecast group contains multiple basis hashes.",
         call. = FALSE)
  }
  if (!compatible && length(bases) != 1L) {
    stop("A non-pooled forecast job must contain exactly one basis.", call. = FALSE)
  }
  for (i in seq_along(bases)) {
    if (!identical(bases[[i]]$feature_basis_hash,
                   posteriors[[i]]$feature_basis_hash)) {
      stop("Basis/posterior capsule mismatch for ", fit_ids[[i]], call. = FALSE)
    }
  }

  balanced <- imrs_v1_balance_posteriors(posteriors)
  selected_posteriors <- Map(function(x, idx) {
    list(
      beta = x$beta[idx, , drop = FALSE], sigma = x$sigma[idx],
      gamma = x$gamma[idx], source_draw_index = x$source_draw_index[idx],
      chain_id = x$chain_id, feature_basis_hash = x$feature_basis_hash
    )
  }, posteriors, balanced$indices)
  noise_sets <- Map(function(x, idx, row) {
    imrs_v1_generate_pipeline_noise(
      draws = x,
      draw_indices = idx,
      origins = bases[[1L]]$origins,
      horizon = bases[[1L]]$horizon,
      y_obs_last = bases[[1L]]$y_obs_last,
      seed = as.integer(row$forecast_seed[[1L]])
    )
  }, posteriors, balanced$indices, split(rows, seq_len(nrow(rows))))
  pairing_rows <- Map(function(noise, idx, row) {
    contract <- attr(noise, "pairing_contract")
    data.frame(
      stream = "primary",
      fit_job_id = as.character(row$job_id[[1L]]),
      chain_id = as.integer(row$chain_id[[1L]]),
      full_seed = as.integer(contract$full_seed),
      tail_seed = as.integer(contract$tail_seed),
      tail_seed_offset = as.integer(contract$tail_seed_offset),
      complete_origin_count = as.integer(contract$complete_origin_count),
      tail_origin_count = as.integer(contract$tail_origin_count),
      source_draw_count = as.integer(contract$source_draw_count),
      selected_draw_count = as.integer(contract$selected_draw_count),
      selected_draw_indices_sha256 = imrs_v1_object_sha256(as.integer(idx)),
      stringsAsFactors = FALSE
    )
  }, noise_sets, balanced$indices, split(rows, seq_len(nrow(rows))))
  innovation_pairing <- do.call(rbind, pairing_rows)
  combined_noise <- imrs_v1_combine_noise(noise_sets)
  basis <- bases[[1L]]
  draws <- balanced$draws
  chain_id <- balanced$chain_id
  within_chain_draw_id <- balanced$within_chain_draw_id

  run_lattice <- function(draw_set = draws, noise_set = combined_noise) {
    forecast_lattice.qdesn_fit(
      object = basis$qdesn_object,
      y_all = basis$y_all,
      origins = basis$origins,
      H = basis$horizon,
      nd = nrow(draw_set$beta),
      xreg_all = basis$xreg_all,
      y_obs_last = basis$y_obs_last,
      lead_weights = basis$lead_weights,
      mix_nd = 1L,
      chunk = as.integer(request$candidate_chunk_size %||% 256L),
      keep_origin_draws = TRUE,
      draws = draw_set,
      noise_draws_by_origin = noise_set,
      build_mix = FALSE,
      recursion_mode = imrs_v1_recursion_mode
    )
  }

  read_verified <- function(path, sha256, label) {
    path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    if (!identical(imrs_v1_sha256(path), as.character(sha256))) {
      stop(label, " hash mismatch.", call. = FALSE)
    }
    ffv2_read_csv(path)
  }
  native_draw_blocks <- vector("list", length(fit_status))
  authority_draw_blocks <- vector("list", length(fit_status))
  native_path_blocks <- vector("list", length(fit_status))
  parity_rows <- list()
  alignment_rows <- list()
  for (i in seq_along(fit_status)) {
    stat <- fit_status[[i]]
    expected <- read_verified(
      stat$native_metric_draws_path, stat$native_metric_draws_sha256,
      paste0("Native metric draws for ", rows$job_id[[i]])
    )
    authority <- read_verified(
      fit_configs[[i]]$native_authority$metric_draws_path,
      fit_configs[[i]]$native_authority$metric_draws_sha256,
      paste0("Historical authority draws for ", rows$job_id[[i]])
    )
    expected_summary <- read_verified(
      stat$native_metric_summary_path, stat$native_metric_summary_sha256,
      paste0("Native metric summary for ", rows$job_id[[i]])
    )
    native_path_blocks[[i]] <- read_verified(
      stat$native_forecast_path, stat$native_forecast_path_sha256,
      paste0("Native forecast path for ", rows$job_id[[i]])
    )
    idx <- balanced$indices[[i]]
    alignment <- imrs_v1_validate_native_posterior_alignment(
      expected, posteriors[[i]], idx
    )
    if (!identical(
      alignment$posterior_original_draw_index,
      as.integer(selected_posteriors[[i]]$source_draw_index)
    )) stop("Balanced posterior provenance is misaligned.", call. = FALSE)
    alignment$fit_job_id <- rows$job_id[[i]]
    alignment$chain_id <- as.integer(rows$chain_id[[i]])
    alignment_rows[[i]] <- alignment
    native_draw_blocks[[i]] <- data.frame(
      draw_id = seq_along(idx),
      chain_id = as.integer(rows$chain_id[[i]]),
      within_chain_draw_id = seq_along(idx),
      forecast_mae = as.numeric(expected$forecast_mae[idx]),
      forecast_check_loss = as.numeric(expected$forecast_check_loss[idx]),
      stringsAsFactors = FALSE
    )
    if (nrow(authority) != nrow(expected)) {
      stop("Historical authority draw count changed for ", rows$job_id[[i]],
           call. = FALSE)
    }
    authority_draw_blocks[[i]] <- data.frame(
      draw_id = seq_along(idx),
      chain_id = as.integer(rows$chain_id[[i]]),
      within_chain_draw_id = seq_along(idx),
      forecast_mae = as.numeric(authority$forecast_mae[idx]),
      forecast_check_loss = as.numeric(authority$forecast_check_loss[idx]),
      stringsAsFactors = FALSE
    )
    parity <- imrs_v1_native_artifact_parity(
      expected, expected_summary, imrs_v1_tolerance
    )
    parity$fit_job_id <- rows$job_id[[i]]
    parity$chain_id <- as.integer(rows$chain_id[[i]])
    parity_rows[[i]] <- parity
  }
  parity <- do.call(rbind, parity_rows)
  posterior_alignment <- do.call(rbind, alignment_rows)
  if (!all(parity$pass)) {
    stop("Native reconstruction artifacts failed the fixed 1e-6 consistency gate.",
         call. = FALSE)
  }
  native_draws_raw <- do.call(rbind, native_draw_blocks)
  native_draws_raw$draw_id <- seq_len(nrow(native_draws_raw))
  authority_draws_raw <- do.call(rbind, authority_draw_blocks)
  authority_draws_raw$draw_id <- seq_len(nrow(authority_draws_raw))
  source_pool_compatibility <- imrs_v1_native_authority_compatibility(
    native_draws_raw, authority_draws_raw, compatibility_policy
  )
  source_pool_compatibility$scope <- "balanced_forecast_source_pool"
  source_pool_compatibility$fit_jobs <- length(fit_ids)
  source_pool_compatibility$source_id <- request$source_id
  if (!all(source_pool_compatibility$pass)) {
    stop("Pooled source is incompatible with its frozen historical authority.",
         call. = FALSE)
  }
  native_path_score <- imrs_v1_score_native_paths(
    native_path_blocks, as.numeric(basis$root_spec$tau)
  )
  native_score <- c(
    list(draw_metrics = native_draws_raw), native_path_score
  )

  log_step("running primary mean-readout-state lattice with %d draws",
           nrow(draws$beta))
  candidate_lattice <- run_lattice()
  candidate_score <- imrs_v1_score_lattice(
    candidate_lattice, basis, chain_id, within_chain_draw_id
  )
  dispersion <- imrs_v1_flatten_dispersion(candidate_lattice)

  flatten_readout <- function(lattice) {
    do.call(rbind, lapply(seq_along(lattice$origins), function(i) {
      x <- as.matrix(lattice$mean_readout_by_origin[[i]])
      data.frame(
        origin = as.integer(lattice$origins[[i]]),
        lead = rep(seq_len(nrow(x)), each = ncol(x)),
        component = rep(seq_len(ncol(x)), times = nrow(x)),
        value = as.numeric(t(x)), stringsAsFactors = FALSE
      )
    }))
  }
  flatten_states <- function(lattice) {
    rows <- list()
    k <- 0L
    for (i in seq_along(lattice$origins)) {
      by_lead <- lattice$common_states_by_origin[[i]]
      for (h in seq_along(by_lead)) {
        by_layer <- by_lead[[h]]
        for (d in seq_along(by_layer)) {
          k <- k + 1L
          rows[[k]] <- data.frame(
            origin = as.integer(lattice$origins[[i]]), lead = h, layer = d,
            component = seq_along(by_layer[[d]]),
            value = as.numeric(by_layer[[d]]), stringsAsFactors = FALSE
          )
        }
      }
    }
    do.call(rbind, rows)
  }
  metric_stability <- function(label, left_lattice, right_lattice,
                               left_score, right_score) {
    left_readout <- flatten_readout(left_lattice)
    right_readout <- flatten_readout(right_lattice)
    left_state <- flatten_states(left_lattice)
    right_state <- flatten_states(right_lattice)
    if (!identical(left_readout[, 1:3], right_readout[, 1:3]) ||
        !identical(left_state[, 1:4], right_state[, 1:4])) {
      stop("Stability replay lattice coordinates differ.", call. = FALSE)
    }
    metric_names <- c("forecast_mae", "forecast_check_loss")
    left_interval <- imrs_v1_interval_summary(left_score$draw_metrics, "left")
    right_interval <- imrs_v1_interval_summary(right_score$draw_metrics, "right")
    state_distance <- imrs_v1_stability_distance(
      left_state$value, right_state$value, "common-state"
    )
    readout_distance <- imrs_v1_stability_distance(
      left_readout$value, right_readout$value, "mean-readout"
    )
    rows <- list(
      data.frame(
        comparison = label, quantity = "common_state",
        metric = "all",
        max_abs_difference = state_distance[["max_abs_difference"]],
        rms_difference = state_distance[["rms_difference"]],
        compared_values = state_distance[["compared_values"]],
        structural_missing_values =
          state_distance[["structural_missing_values"]],
        stringsAsFactors = FALSE
      ),
      data.frame(
        comparison = label, quantity = "mean_complete_readout",
        metric = "all",
        max_abs_difference = readout_distance[["max_abs_difference"]],
        rms_difference = readout_distance[["rms_difference"]],
        compared_values = readout_distance[["compared_values"]],
        structural_missing_values =
          readout_distance[["structural_missing_values"]],
        stringsAsFactors = FALSE
      )
    )
    for (metric in metric_names) {
      li <- left_interval[left_interval$metric == metric, , drop = FALSE]
      ri <- right_interval[right_interval$metric == metric, , drop = FALSE]
      point_delta <- abs(
        as.numeric(left_score$point_metrics[[metric]]) -
          as.numeric(right_score$point_metrics[[metric]])
      )
      endpoint_delta <- max(abs(c(
        li$cri_lower - ri$cri_lower,
        li$posterior_median - ri$posterior_median,
        li$cri_upper - ri$cri_upper
      )))
      rows[[length(rows) + 1L]] <- data.frame(
        comparison = label, quantity = "score",
        metric = metric, max_abs_difference = max(point_delta, endpoint_delta),
        rms_difference = sqrt(mean(c(point_delta, endpoint_delta)^2)),
        compared_values = 2L, structural_missing_values = 0L,
        stringsAsFactors = FALSE
      )
    }
    do.call(rbind, rows)
  }

  stability <- data.frame(
    comparison = character(), quantity = character(), metric = character(),
    max_abs_difference = numeric(), rms_difference = numeric(),
    compared_values = integer(), structural_missing_values = integer(),
    stringsAsFactors = FALSE
  )
  if (isTRUE(request$stability_check)) {
    odd <- seq.int(1L, nrow(draws$beta), by = 2L)
    even <- seq.int(2L, nrow(draws$beta), by = 2L)
    subset_draws <- function(idx) list(
      beta = draws$beta[idx, , drop = FALSE], sigma = draws$sigma[idx],
      gamma = draws$gamma[idx], source_draw_index = draws$source_draw_index[idx]
    )
    subset_noise <- function(idx) lapply(combined_noise, function(x) {
      lapply(x, function(z) z[, idx, drop = FALSE])
    })
    log_step("running odd/even integration stability lattices")
    odd_lattice <- run_lattice(subset_draws(odd), subset_noise(odd))
    even_lattice <- run_lattice(subset_draws(even), subset_noise(even))
    odd_score <- imrs_v1_score_lattice(
      odd_lattice, basis, chain_id[odd], within_chain_draw_id[odd]
    )
    even_score <- imrs_v1_score_lattice(
      even_lattice, basis, chain_id[even], within_chain_draw_id[even]
    )
    stability <- metric_stability(
      "odd_vs_even", odd_lattice, even_lattice, odd_score, even_score
    )

    offset <- as.integer(
      (request$stability_contract %||% list())$replicate_seed_offset %||% 104729L
    )
    replicate_noise_sets <- Map(function(x, idx, row) {
      imrs_v1_generate_pipeline_noise(
        draws = x,
        draw_indices = idx,
        origins = bases[[1L]]$origins,
        horizon = bases[[1L]]$horizon,
        y_obs_last = bases[[1L]]$y_obs_last,
        seed = as.integer(row$forecast_seed[[1L]]) + offset
      )
    }, posteriors, balanced$indices, split(rows, seq_len(nrow(rows))))
    replicate_pairing <- Map(function(noise, idx, row) {
      contract <- attr(noise, "pairing_contract")
      data.frame(
        stream = "replicate",
        fit_job_id = as.character(row$job_id[[1L]]),
        chain_id = as.integer(row$chain_id[[1L]]),
        full_seed = as.integer(contract$full_seed),
        tail_seed = as.integer(contract$tail_seed),
        tail_seed_offset = as.integer(contract$tail_seed_offset),
        complete_origin_count = as.integer(contract$complete_origin_count),
        tail_origin_count = as.integer(contract$tail_origin_count),
        source_draw_count = as.integer(contract$source_draw_count),
        selected_draw_count = as.integer(contract$selected_draw_count),
        selected_draw_indices_sha256 = imrs_v1_object_sha256(as.integer(idx)),
        stringsAsFactors = FALSE
      )
    }, replicate_noise_sets, balanced$indices,
    split(rows, seq_len(nrow(rows))))
    innovation_pairing <- rbind(
      innovation_pairing, do.call(rbind, replicate_pairing)
    )
    log_step("running alternate-innovation integration stability lattice")
    replicate_lattice <- run_lattice(
      draws, imrs_v1_combine_noise(replicate_noise_sets)
    )
    replicate_score <- imrs_v1_score_lattice(
      replicate_lattice, basis, chain_id, within_chain_draw_id
    )
    stability <- rbind(
      stability,
      metric_stability(
        "primary_vs_replicate_innovations", candidate_lattice,
        replicate_lattice, candidate_score, replicate_score
      )
    )
    rm(odd_lattice, even_lattice, replicate_lattice, odd_score, even_score,
       replicate_score)
    invisible(gc())
  }
  rm(candidate_lattice)
  invisible(gc())

  out_root <- file.path(state_root, "runtime", "forecast_jobs", forecast_id)
  dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(out_root, "manifest"), recursive = TRUE, showWarnings = FALSE)
  decorate <- function(x, estimator) {
    x$estimator_id <- estimator
    x$forecast_id <- forecast_id
    x$source_id <- request$source_id
    x$inference <- request$inference
    x$likelihood_family <- request$likelihood_family
    x$family <- request$family
    x$tau <- as.numeric(request$tau)
    x
  }
  metric_draw_columns <- c(
    "draw_id", "chain_id", "within_chain_draw_id", "forecast_mae",
    "forecast_check_loss"
  )
  native_draws <- decorate(
    native_score$draw_metrics[, metric_draw_columns, drop = FALSE],
    "native_posterior_predictive"
  )
  candidate_draws <- decorate(
    candidate_score$draw_metrics[, metric_draw_columns, drop = FALSE],
    imrs_v1_estimator
  )
  native_intervals <- decorate(
    imrs_v1_interval_summary(native_draws, "native_posterior_predictive"),
    "native_posterior_predictive"
  )
  candidate_intervals <- decorate(
    imrs_v1_interval_summary(candidate_draws, imrs_v1_estimator), imrs_v1_estimator
  )
  native_point <- decorate(native_score$point_metrics, "native_posterior_predictive")
  candidate_point <- decorate(candidate_score$point_metrics, imrs_v1_estimator)
  native_path <- decorate(native_score$point_path, "native_posterior_predictive")
  candidate_path <- decorate(candidate_score$point_path, imrs_v1_estimator)
  profiles <- rbind(
    decorate(transform(native_score$lead_profile, profile = "lead"),
             "native_posterior_predictive"),
    decorate(transform(native_score$origin_profile, profile = "origin"),
             "native_posterior_predictive"),
    decorate(transform(candidate_score$lead_profile, profile = "lead"),
             imrs_v1_estimator),
    decorate(transform(candidate_score$origin_profile, profile = "origin"),
             imrs_v1_estimator)
  )
  dispersion <- decorate(dispersion, imrs_v1_estimator)

  outputs <- list(
    native_draws = native_draws,
    candidate_draws = candidate_draws,
    native_intervals = native_intervals,
    candidate_intervals = candidate_intervals,
    native_point = native_point,
    candidate_point = candidate_point,
    native_path = native_path,
    candidate_path = candidate_path,
    profiles = profiles,
    dispersion = dispersion,
    stability = stability,
    parity = parity,
    source_pool_compatibility = source_pool_compatibility,
    posterior_alignment = decorate(posterior_alignment, imrs_v1_estimator),
    innovation_pairing = decorate(innovation_pairing, imrs_v1_estimator)
  )
  paths <- list()
  for (name in names(outputs)) {
    path <- file.path(out_root, "tables", paste0(name, ".csv"))
    imrs_v1_atomic_write_csv(outputs[[name]], path)
    paths[[name]] <- normalizePath(path, winslash = "/", mustWork = TRUE)
  }
  manifest_rows <- data.frame(
    artifact = names(paths), path = unlist(paths, use.names = FALSE),
    bytes = as.numeric(file.info(unlist(paths, use.names = FALSE))$size),
    sha256 = vapply(unlist(paths, use.names = FALSE), ffv2_file_sha256,
                    character(1L)),
    stringsAsFactors = FALSE
  )
  artifact_manifest_path <- file.path(out_root, "manifest", "artifact_manifest.csv")
  imrs_v1_atomic_write_csv(manifest_rows, artifact_manifest_path)
  result_payload <- list(
    source_id = request$source_id, inference = request$inference,
    likelihood_family = request$likelihood_family,
    family = request$family, tau = as.numeric(request$tau),
    pooling_policy = request$pooling_policy,
    fit_job_ids = fit_ids, feature_basis_hashes = hashes,
    chains = length(unique(chain_id)), draws = nrow(candidate_draws),
    targets = nrow(candidate_path),
    native_artifact_consistency_max_abs_difference = max(parity$max_abs_difference),
    native_authority_source_pool_metric_count = nrow(source_pool_compatibility),
    native_authority_source_pool_pass = all(source_pool_compatibility$pass),
    native_authority_source_pool_max_endpoint_width_ratio =
      max(source_pool_compatibility$endpoint_width_ratio),
    posterior_alignment_rows = nrow(posterior_alignment),
    primary_innovation_pairing_rows = sum(innovation_pairing$stream == "primary"),
    replicate_innovation_pairing_rows = sum(innovation_pairing$stream == "replicate"),
    stability_check = isTRUE(request$stability_check),
    artifact_manifest_path = normalizePath(
      artifact_manifest_path, winslash = "/", mustWork = TRUE
    ),
    artifact_manifest_sha256 = ffv2_file_sha256(artifact_manifest_path),
    output_root = normalizePath(out_root, winslash = "/", mustWork = TRUE)
  )
  log_step("published verified forecast evidence for %s", forecast_id)
  status <- "SUCCESS"
}, error = function(e) {
  error_message <<- conditionMessage(e)
})

ended <- Sys.time()
imrs_v1_write_status(state_root, "forecast", forecast_id, c(list(
  status = status, request_sha256 = config_sha,
  error_message = error_message, pid = Sys.getpid(),
  host = Sys.info()[["nodename"]],
  started_at = format(started, "%Y-%m-%d %H:%M:%S %Z"),
  ended_at = format(ended, "%Y-%m-%d %H:%M:%S %Z"),
  elapsed_seconds = as.numeric(difftime(ended, started, units = "secs")),
  git_commit = system("git rev-parse HEAD", intern = TRUE)
), result_payload))
cat(sprintf("forecast job=%s status=%s elapsed=%.1f error=%s\n", forecast_id,
            status, as.numeric(difftime(ended, started, units = "secs")),
            error_message %||% ""))
quit(save = "no", status = if (identical(status, "SUCCESS")) 0L else 1L)
