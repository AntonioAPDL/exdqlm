#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/backfill_independent_mean_readout_state_source_pool_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/",
                           mustWork = TRUE)
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/",
                            mustWork = TRUE)
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
setwd(repo_root)

fit_plan <- ffv2_read_csv(file.path(state_root, "manifests", "fit_plan.csv"))
forecast_plan <- ffv2_read_csv(
  file.path(state_root, "manifests", "forecast_plan.csv")
)
recovery_root <- file.path(
  state_root, "manifests", "recovery", "endpoint_review_source_pool_v1"
)
archive_root <- file.path(recovery_root, "pre_backfill_forecast_metadata")
if (!dry_run) dir.create(archive_root, recursive = TRUE, showWarnings = FALSE)

read_verified <- function(path, sha256, label) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (!identical(ffv2_file_sha256(path), as.character(sha256))) {
    stop(label, " hash mismatch.", call. = FALSE)
  }
  ffv2_read_csv(path)
}

ledger <- list()
ledger_i <- 0L
for (i in seq_len(nrow(forecast_plan))) {
  forecast_id <- forecast_plan$forecast_id[[i]]
  status_path <- imrs_v1_status_path(state_root, "forecast", forecast_id)
  if (!file.exists(status_path)) next
  status <- imrs_v1_read_json(status_path)
  if (!identical(as.character(status$status), "SUCCESS")) next

  manifest_path <- normalizePath(
    status$artifact_manifest_path, winslash = "/", mustWork = TRUE
  )
  if (!identical(
    ffv2_file_sha256(manifest_path), as.character(status$artifact_manifest_sha256)
  )) stop("Forecast artifact manifest hash mismatch: ", forecast_id, call. = FALSE)
  artifact_manifest <- ffv2_read_csv(manifest_path)
  if ("source_pool_compatibility" %in% artifact_manifest$artifact) next

  request <- ffv2_read_json(forecast_plan$config_path[[i]])
  fit_ids <- as.character(unlist(request$fit_job_ids, use.names = FALSE))
  rows <- fit_plan[match(fit_ids, fit_plan$job_id), , drop = FALSE]
  if (nrow(rows) != length(fit_ids) || anyNA(rows$job_id)) {
    stop("Forecast dependency plan is incomplete: ", forecast_id, call. = FALSE)
  }
  fit_status <- lapply(fit_ids, function(id) {
    path <- imrs_v1_status_path(state_root, "fit", id)
    out <- imrs_v1_read_json(path)
    if (!identical(as.character(out$status), "SUCCESS")) {
      stop("Backfill dependency is not successful: ", id, call. = FALSE)
    }
    out
  })
  fit_configs <- lapply(seq_len(nrow(rows)), function(j) {
    path <- normalizePath(rows$config_path[[j]], winslash = "/", mustWork = TRUE)
    if (!identical(ffv2_file_sha256(path), rows$config_sha256[[j]])) {
      stop("Fit configuration hash mismatch: ", rows$job_id[[j]], call. = FALSE)
    }
    ffv2_read_json(path)
  })
  policy_hashes <- vapply(fit_configs, function(x) {
    imrs_v1_object_sha256(x$native_authority$compatibility_policy)
  }, character(1L))
  if (length(unique(policy_hashes)) != 1L) {
    stop("Authority policies differ within source: ", forecast_id, call. = FALSE)
  }
  policy <- imrs_v1_historical_compatibility_policy(
    fit_configs[[1L]]$native_authority$compatibility_policy
  )
  posteriors <- Map(function(row, stat) {
    path <- normalizePath(stat$posterior_capsule_path, winslash = "/",
                          mustWork = TRUE)
    if (!identical(ffv2_file_sha256(path), stat$posterior_capsule_sha256)) {
      stop("Posterior capsule hash mismatch: ", row$job_id, call. = FALSE)
    }
    readRDS(path)
  }, split(rows, seq_len(nrow(rows))), fit_status)
  balanced <- imrs_v1_balance_posteriors(posteriors)

  observed_blocks <- authority_blocks <- vector("list", length(fit_ids))
  for (j in seq_along(fit_ids)) {
    observed <- read_verified(
      fit_status[[j]]$native_metric_draws_path,
      fit_status[[j]]$native_metric_draws_sha256,
      paste0("Native metric draws for ", fit_ids[[j]])
    )
    authority <- read_verified(
      fit_configs[[j]]$native_authority$metric_draws_path,
      fit_configs[[j]]$native_authority$metric_draws_sha256,
      paste0("Historical authority draws for ", fit_ids[[j]])
    )
    idx <- balanced$indices[[j]]
    if (nrow(observed) != nrow(authority) || max(idx) > nrow(observed)) {
      stop("Balanced source-pool draw contract failed: ", fit_ids[[j]],
           call. = FALSE)
    }
    observed_blocks[[j]] <- observed[idx, c(
      "forecast_mae", "forecast_check_loss"
    ), drop = FALSE]
    authority_blocks[[j]] <- authority[idx, c(
      "forecast_mae", "forecast_check_loss"
    ), drop = FALSE]
  }
  compatibility <- imrs_v1_native_authority_compatibility(
    do.call(rbind, observed_blocks), do.call(rbind, authority_blocks), policy
  )
  compatibility$scope <- "balanced_forecast_source_pool"
  compatibility$fit_jobs <- length(fit_ids)
  compatibility$source_id <- request$source_id
  if (!all(compatibility$pass)) {
    stop("Legacy successful source fails the new pooled hard gate: ",
         forecast_id, call. = FALSE)
  }

  if (!dry_run) {
    output_path <- file.path(
      status$output_root, "tables", "source_pool_compatibility.csv"
    )
    original_manifest_sha <- ffv2_file_sha256(manifest_path)
    original_status_sha <- ffv2_file_sha256(status_path)
    archive_dir <- file.path(archive_root, forecast_id)
    dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(manifest_path, file.path(archive_dir, "artifact_manifest.csv"),
                   overwrite = FALSE) ||
        !file.copy(status_path, file.path(archive_dir, "status.json"),
                   overwrite = FALSE)) {
      stop("Could not archive pre-backfill metadata: ", forecast_id, call. = FALSE)
    }
    imrs_v1_atomic_write_csv(compatibility, output_path)
    artifact_manifest <- rbind(artifact_manifest, data.frame(
      artifact = "source_pool_compatibility",
      path = normalizePath(output_path, winslash = "/", mustWork = TRUE),
      bytes = as.numeric(file.info(output_path)$size),
      sha256 = ffv2_file_sha256(output_path), stringsAsFactors = FALSE
    ))
    imrs_v1_atomic_write_csv(artifact_manifest, manifest_path)
    status$artifact_manifest_sha256 <- ffv2_file_sha256(manifest_path)
    status$native_authority_source_pool_metric_count <- nrow(compatibility)
    status$native_authority_source_pool_pass <- TRUE
    status$native_authority_source_pool_max_endpoint_width_ratio <-
      max(compatibility$endpoint_width_ratio)
    status$source_pool_backfill <- list(
      recovery_id = "endpoint_review_source_pool_v1",
      git_commit = system("git rev-parse HEAD", intern = TRUE),
      original_artifact_manifest_sha256 = original_manifest_sha,
      original_status_sha256 = original_status_sha,
      generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )
    imrs_v1_atomic_write_json(status, status_path)
  }

  ledger_i <- ledger_i + 1L
  ledger[[ledger_i]] <- data.frame(
    forecast_id = forecast_id, source_id = request$source_id,
    fit_jobs = length(fit_ids), metrics = nrow(compatibility),
    max_relative_mean_difference = max(compatibility$relative_mean_difference),
    max_ks_ratio = max(
      compatibility$ks_distance / compatibility$familywise_ks_threshold
    ),
    max_endpoint_width_ratio = max(compatibility$endpoint_width_ratio),
    min_interval_overlap = min(compatibility$interval_overlap_fraction),
    pass = all(compatibility$pass), stringsAsFactors = FALSE
  )
}

ledger_path <- file.path(recovery_root, "source_pool_backfill_ledger.csv")
if (dry_run) {
  ledger_out <- if (length(ledger)) do.call(rbind, ledger) else data.frame()
} else if (length(ledger)) {
  ledger_out <- do.call(rbind, ledger)
  imrs_v1_atomic_write_csv(ledger_out, ledger_path)
} else if (file.exists(ledger_path)) {
  ledger_out <- ffv2_read_csv(ledger_path)
} else {
  ledger_out <- data.frame(
    forecast_id = character(), source_id = character(), fit_jobs = integer(),
    metrics = integer(), max_relative_mean_difference = numeric(),
    max_ks_ratio = numeric(), max_endpoint_width_ratio = numeric(),
    min_interval_overlap = numeric(), pass = logical(), stringsAsFactors = FALSE
  )
  imrs_v1_atomic_write_csv(ledger_out, ledger_path)
}
cat(if (dry_run) "SOURCE_POOL_BACKFILL_DRY_RUN " else
      "SOURCE_POOL_BACKFILL_COMPLETE ", "forecasts=", nrow(ledger_out),
    " metrics=", sum(ledger_out$metrics), "\n", sep = "")
