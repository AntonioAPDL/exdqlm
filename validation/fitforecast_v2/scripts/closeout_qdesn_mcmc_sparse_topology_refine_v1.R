#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
num <- function(x) suppressWarnings(as.numeric(x))
cell <- function(value, name, default = NA) {
  if (!is.data.frame(value) || !name %in% names(value) || !nrow(value)) return(default)
  value[[name]][[1L]] %||% default
}
finite_median <- function(x) {
  x <- num(x); x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_min <- function(x) {
  x <- num(x); x <- x[is.finite(x)]
  if (length(x)) min(x) else NA_real_
}
safe_count_table <- function(x) {
  if (!length(x)) return(list())
  as.list(table(ifelse(is.na(x) | !nzchar(as.character(x)), "MISSING", as.character(x))))
}

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_mcmc_dynamic_alpha_confirm_v1.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_mcmc_sparse_topology_refine_v1.R"
))
resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path)[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_sparse_topology_refine_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
runner_exit_code <- suppressWarnings(as.integer(get_arg("--runner-exit-code", "0"))[1L])
if (!is.finite(runner_exit_code)) runner_exit_code <- NA_integer_
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path(
    "reports", "qdesn_mcmc_validation", stage,
    paste0(run_tag, "_closeout")
  )
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

paths <- list(
  defaults = paste0(stub, "_defaults.yaml"),
  grid = paste0(stub, "_grid.csv"),
  profiles = paste0(stub, "_profiles.csv"),
  targets = paste0(stub, "_target_spec_ids.csv"),
  pairs = paste0(stub, "_pair_map.csv"),
  topology_seeds = paste0(stub, "_topology_seed_contract.csv"),
  topology_audit = paste0(stub, "_topology_audit.csv"),
  article_context = paste0(stub, "_current_article_metric_context.csv"),
  promotion_contract = paste0(stub, "_promotion_contract.csv"),
  source_registry = paste0(stub, "_source_registry.csv"),
  materialization = paste0(stub, "_materialization_manifest.json")
)
missing_contract <- unlist(paths)[!file.exists(unlist(paths))]
if (length(missing_contract)) {
  stop(sprintf("Missing closeout contract files: %s", paste(missing_contract, collapse = ", ")), call. = FALSE)
}
defaults <- yaml::read_yaml(resolve_path(paths$defaults))
grid <- read_csv(paths$grid)
profiles <- read_csv(paths$profiles)
targets <- read_csv(paths$targets)
pair_map <- read_csv(paths$pairs)
topology_seeds <- read_csv(paths$topology_seeds)
topology_audit <- read_csv(paths$topology_audit)
article_context <- read_csv(paths$article_context)
promotion_contract <- read_csv(paths$promotion_contract)
source_registry <- read_csv(paths$source_registry)
materialization <- jsonlite::read_json(resolve_path(paths$materialization), simplifyVector = TRUE)
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
if (nrow(grid) != 168L || nrow(profiles) != 168L || nrow(targets) != 168L ||
    nrow(pair_map) != 144L || nrow(topology_seeds) != 6L ||
    nrow(topology_audit) != 168L || !all(as_bool(topology_audit$topology_valid)) ||
    nrow(article_context) != 2L ||
    !identical(materialization$source_registry_hash_value, expected_registry_hash)) {
  stop("The closeout inputs do not match the frozen 168-fit contract.", call. = FALSE)
}

results_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
reports_root <- resolve_path(file.path(defaults$campaign$reports_root, run_tag), FALSE)
if (!dir.exists(results_root)) {
  stop(sprintf("Run root does not exist: %s", results_root), call. = FALSE)
}

fit_paths <- list.files(
  results_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE,
  full.names = TRUE
)
fit_rows <- lapply(fit_paths, function(path) {
  fit <- tryCatch(
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(fit) || !nrow(fit)) return(NULL)
  fit <- fit[1L, , drop = FALSE]
  method_dir <- dirname(path)
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(
      utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
  } else NULL
  h1000 <- NULL
  if (!is.null(horizon) && nrow(horizon)) {
    index <- which(
      suppressWarnings(as.integer(horizon$horizon)) == 1000L |
        as.character(horizon$window) == "forecast_H1000"
    )
    if (length(index)) h1000 <- horizon[index[[1L]], , drop = FALSE]
  }
  request_path <- file.path(method_dir, "fit_request.json")
  request <- if (file.exists(request_path)) {
    tryCatch(jsonlite::read_json(request_path, simplifyVector = TRUE),
             error = function(e) list())
  } else list()
  fit$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  fit$fit_summary_sha256 <- unname(tools::sha256sum(path))
  fit$forecast_horizon_path <- if (file.exists(horizon_path)) {
    normalizePath(horizon_path, winslash = "/", mustWork = TRUE)
  } else NA_character_
  fit$forecast_horizon_sha256 <- if (file.exists(horizon_path)) {
    unname(tools::sha256sum(horizon_path))
  } else NA_character_
  fit$fit_request_path <- if (file.exists(request_path)) {
    normalizePath(request_path, winslash = "/", mustWork = TRUE)
  } else NA_character_
  fit$fit_request_sha256 <- if (file.exists(request_path)) {
    unname(tools::sha256sum(request_path))
  } else NA_character_
  fit$observed_desn_seed <- as.integer(request$config$desn$seed %||% NA_integer_)
  fit$observed_mcmc_seed <- as.integer(
    request$config$inference$mcmc$control$seed %||% NA_integer_
  )
  fit$observed_mcmc_rng_seed <- as.integer(
    request$config$inference$mcmc$control$rng_seed %||% NA_integer_
  )
  fit$observed_vb_warm_start_seed <- as.integer(
    request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_
  )
  fit$observed_synthesis_seed <- as.integer(
    request$config$synthesis$seed %||% NA_integer_
  )
  fit$observed_n_burn <- as.integer(
    request$config$inference$mcmc$n_burn %||% NA_integer_
  )
  fit$observed_n_mcmc <- as.integer(
    request$config$inference$mcmc$n_mcmc %||% NA_integer_
  )
  fit$observed_source_registry_hash <- as.character(
    request$study_contract$source_registry_hash_value %||%
      request$config$study_contract$source_registry_hash_value %||%
      NA_character_
  )
  fit$observed_source_series_sha256 <- as.character(
    request$root_spec$source_series_wide_sha256 %||% NA_character_
  )
  fit$observed_train_start <- as.integer(
    request$root_spec$train_start_source_index %||% NA_integer_
  )
  fit$observed_train_end <- as.integer(
    request$root_spec$train_end_source_index %||% NA_integer_
  )
  fit$observed_forecast_start <- as.integer(
    request$root_spec$forecast_start_source_index %||% NA_integer_
  )
  fit$observed_forecast_end <- as.integer(
    request$root_spec$forecast_end_source_index %||% NA_integer_
  )
  fit$fit_qtrue_rmse <- num(cell(fit, "train_qtrue_rmse", NA_real_))
  fit$forecast_qtrue_mae_H1000 <- num(cell(h1000, "qtrue_mae", NA_real_))
  fit$forecast_check_loss_H1000 <- num(cell(h1000, "pinball_tau", NA_real_))
  fit$metric_complete <- all(is.finite(c(
    fit$fit_qtrue_rmse, fit$forecast_qtrue_mae_H1000,
    fit$forecast_check_loss_H1000
  )))
  fit
})
fit_rows <- Filter(Negate(is.null), fit_rows)
metrics <- if (length(fit_rows)) do.call(rbind, fit_rows) else data.frame()
if (nrow(metrics)) metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]

profile_fields <- c(
  "screening_profile_id", "source_screening_profile_id",
  "confirmation_design_id", "target_cell_id", "target_family", "target_tau",
  "likelihood_target", "comparison_role", "control_key",
  "selection_tier", "selection_role", "reservoir_replicate",
  "sampler_replicate", "sampler_pair_id", "D", "n_each", "m", "alpha",
  "rho", "pi_w", "pi_in", "rhs_tau0", "seed", "topology_class",
  "recurrent_edges_target", "base_design_id"
)
profile_lookup <- profiles[, profile_fields, drop = FALSE]
if (nrow(metrics)) {
  index <- match(metrics$screening_profile_id, profile_lookup$screening_profile_id)
  for (field in setdiff(profile_fields, "screening_profile_id")) {
    metrics[[field]] <- profile_lookup[[field]][index]
  }
  metrics$family <- as.character(metrics$target_family)
  metrics$tau <- num(metrics$target_tau)
}

expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(metrics)) unique(as.character(metrics$spec_id)) else character()
missing_ids <- setdiff(expected_ids, observed_ids)
unexpected_ids <- setdiff(observed_ids, expected_ids)
missing_path <- write_csv(data.frame(spec_id = missing_ids), file.path(output_root, "missing_spec_ids.csv"))
unexpected_path <- write_csv(data.frame(spec_id = unexpected_ids), file.path(output_root, "unexpected_spec_ids.csv"))

grid_contract <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
  "source_series_wide_sha256", "train_start_source_index",
  "train_end_source_index", "forecast_start_source_index",
  "forecast_end_source_index"
), drop = FALSE]
names(grid_contract) <- c(
  "root_id", "screening_profile_id", "expected_desn_seed", "expected_mcmc_seed",
  "expected_mcmc_rng_seed", "expected_vb_warm_start_seed",
  "expected_synthesis_seed", "expected_source_series_sha256",
  "expected_train_start", "expected_train_end", "expected_forecast_start",
  "expected_forecast_end"
)
if (nrow(metrics)) {
  metrics <- merge(
    metrics, grid_contract, by = c("root_id", "screening_profile_id"),
    all.x = TRUE, sort = FALSE
  )
  metrics$expected_spec_match <- as.character(metrics$spec_id) %in% expected_ids &
    as.character(metrics$likelihood_family) == as.character(metrics$likelihood_target)
  metrics$seed_contract_match <- with(metrics,
    observed_desn_seed == expected_desn_seed &
      observed_mcmc_seed == expected_mcmc_seed &
      observed_mcmc_rng_seed == expected_mcmc_rng_seed &
      observed_vb_warm_start_seed == expected_vb_warm_start_seed &
      observed_synthesis_seed == expected_synthesis_seed
  )
  metrics$source_registry_hash_match <-
    metrics$observed_source_registry_hash == expected_registry_hash
  metrics$source_file_hash_match <- with(metrics,
    observed_source_series_sha256 == expected_source_series_sha256
  )
  metrics$source_window_match <- with(metrics,
    observed_train_start == expected_train_start &
      observed_train_end == expected_train_end &
      observed_forecast_start == expected_forecast_start &
      observed_forecast_end == expected_forecast_end
  )
  metrics$expected_spec_match <- metrics$expected_spec_match &
    metrics$source_file_hash_match & metrics$source_window_match
  metrics$budget_contract_match <- with(metrics,
    observed_n_burn == 5000L & observed_n_mcmc == 20000L
  )
  metrics$execution_contract_match <- with(metrics,
    expected_spec_match & seed_contract_match & source_registry_hash_match &
      source_file_hash_match & source_window_match & budget_contract_match
  )
}
metrics_path <- write_csv(metrics, file.path(output_root, "confirmation_metrics.csv"))
execution_columns <- c(
  "spec_id", "root_id", "screening_profile_id", "confirmation_design_id",
  "target_cell_id", "comparison_role", "sampler_replicate", "sampler_pair_id",
  "status", "signoff_grade", "metric_complete", "expected_spec_match",
  "seed_contract_match", "source_registry_hash_match", "source_file_hash_match",
  "source_window_match", "budget_contract_match", "execution_contract_match",
  "observed_n_burn", "observed_n_mcmc", "fit_request_path", "fit_request_sha256"
)
execution_audit <- if (nrow(metrics)) {
  metrics[, intersect(execution_columns, names(metrics)), drop = FALSE]
} else data.frame()
execution_audit_path <- write_csv(
  execution_audit, file.path(output_root, "execution_contract_audit.csv")
)

pair_metrics <- if (nrow(metrics)) {
  qdesn_dacf1_pair_metrics(metrics, pair_map)
} else data.frame()
pair_metrics_path <- write_csv(pair_metrics, file.path(output_root, "paired_metrics.csv"))

candidate_pairs <- pair_metrics[pair_metrics$pair_complete, , drop = FALSE]
design_summary <- if (nrow(candidate_pairs)) {
  do.call(rbind, lapply(split(candidate_pairs, candidate_pairs$confirmation_design_id), function(x) {
    data.frame(
      confirmation_design_id = x$confirmation_design_id[[1L]],
      target_cell_id = x$target_cell_id[[1L]],
      desn_seed = x$desn_seed[[1L]],
      n_complete_pairs = nrow(x),
      median_fit_ratio_to_parent = finite_median(x$fit_qtrue_rmse_ratio),
      median_forecast_mae_ratio_to_parent = finite_median(x$forecast_qtrue_mae_H1000_ratio),
      median_forecast_check_ratio_to_parent = finite_median(x$forecast_check_loss_H1000_ratio),
      min_fit_ratio_to_parent = finite_min(x$fit_qtrue_rmse_ratio),
      min_forecast_mae_ratio_to_parent = finite_min(x$forecast_qtrue_mae_H1000_ratio),
      min_forecast_check_ratio_to_parent = finite_min(x$forecast_check_loss_H1000_ratio),
      stringsAsFactors = FALSE
    )
  }))
} else data.frame()
design_summary_path <- write_csv(
  design_summary, file.path(output_root, "candidate_parent_design_summary.csv")
)

promotion <- if (nrow(metrics)) {
  qdesn_dacf1_metric_promotion(metrics, article_context, tolerance = 1e-10)
} else list(candidates = data.frame(), winners = data.frame())
promotion_candidates <- promotion$candidates
if (nrow(promotion_candidates)) {
  extra_fields <- c(
    "spec_id", "comparison_role", "confirmation_design_id", "sampler_replicate",
    "status", "signoff_grade", "fit_summary_path", "fit_summary_sha256",
    "forecast_horizon_path", "forecast_horizon_sha256", "fit_request_path",
    "fit_request_sha256", "alpha", "rho", "seed", "rhs_tau0"
  )
  extra <- metrics[, intersect(extra_fields, names(metrics)), drop = FALSE]
  promotion_candidates <- merge(
    promotion_candidates, extra, by = "spec_id", all.x = TRUE, sort = FALSE
  )
  promotion_candidates <- promotion_candidates[order(
    promotion_candidates$model_variant, promotion_candidates$metric,
    !promotion_candidates$contract_eligible, promotion_candidates$candidate_value,
    promotion_candidates$screening_profile_id
  ), , drop = FALSE]
}
promotion_candidates_path <- write_csv(
  promotion_candidates, file.path(output_root, "article_metric_promotion_candidates.csv")
)
winners <- promotion$winners
if (nrow(winners)) {
  winner_extra <- metrics[, intersect(c(
    "spec_id", "comparison_role", "confirmation_design_id", "sampler_replicate",
    "status", "signoff_grade", "fit_summary_path", "fit_summary_sha256",
    "forecast_horizon_path", "forecast_horizon_sha256", "fit_request_path",
    "fit_request_sha256", "alpha", "rho", "seed", "rhs_tau0"
  ), names(metrics)), drop = FALSE]
  winners <- merge(winners, winner_extra, by = "spec_id", all.x = TRUE, sort = FALSE)
  winners <- winners[order(winners$model_variant, winners$metric), , drop = FALSE]
}
winners_path <- write_csv(
  winners, file.path(output_root, "article_metric_winners.csv")
)

interface_preview <- article_context
if (nrow(winners)) {
  for (i in seq_len(nrow(winners))) {
    winner <- winners[i, , drop = FALSE]
    row_index <- which(interface_preview$model_variant == winner$model_variant[[1L]])
    metric <- as.character(winner$metric[[1L]])
    interface_preview[[metric]][row_index] <- winner$candidate_value[[1L]]
    if (identical(metric, "fit_qtrue_rmse")) {
      prefix <- "fit_source"
      artifact_path <- winner$fit_summary_path[[1L]]
      artifact_hash <- winner$fit_summary_sha256[[1L]]
    } else if (identical(metric, "forecast_qtrue_mae_H1000")) {
      prefix <- "forecast_mae_source"
      artifact_path <- winner$forecast_horizon_path[[1L]]
      artifact_hash <- winner$forecast_horizon_sha256[[1L]]
    } else {
      prefix <- "forecast_check_source"
      artifact_path <- winner$forecast_horizon_path[[1L]]
      artifact_hash <- winner$forecast_horizon_sha256[[1L]]
    }
    interface_preview[[paste0(prefix, "_candidate_id")]][row_index] <- winner$spec_id[[1L]]
    interface_preview[[paste0(prefix, "_run_tag")]][row_index] <- run_tag
    interface_preview[[paste0(prefix, "_signoff_grade")]][row_index] <- winner$signoff_grade[[1L]]
    interface_preview[[paste0(prefix, "_status")]][row_index] <- winner$status[[1L]]
    interface_preview[[paste0(prefix, "_path")]][row_index] <- artifact_path
    interface_preview[[paste0(prefix, "_sha256")]][row_index] <- artifact_hash
  }
}
for (i in seq_len(nrow(interface_preview))) {
  source_ids <- as.character(unlist(interface_preview[i, c(
    "fit_source_candidate_id", "forecast_mae_source_candidate_id",
    "forecast_check_source_candidate_id"
  ), drop = FALSE], use.names = FALSE))
  interface_preview$metric_source_mixed[[i]] <- length(unique(source_ids)) > 1L
}
interface_preview_path <- write_csv(
  interface_preview, file.path(output_root, "article_interface_preview.csv")
)

progress_paths <- if (dir.exists(reports_root)) {
  list.files(reports_root, pattern = "^campaign_progress[.]csv$", recursive = TRUE,
             full.names = TRUE)
} else character()
progress <- if (length(progress_paths)) {
  utils::read.csv(progress_paths[[length(progress_paths)]], check.names = FALSE,
                  stringsAsFactors = FALSE)
} else data.frame()
progress_path <- write_csv(progress, file.path(output_root, "campaign_progress_snapshot.csv"))

binary_paths <- list.files(
  results_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
storage_audit <- if (length(binary_paths)) {
  data.frame(
    path = normalizePath(binary_paths, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(file.info(binary_paths)$size),
    disposition = "unexpected_model_payload",
    stringsAsFactors = FALSE
  )
} else data.frame(path = character(), bytes = numeric(), disposition = character())
storage_audit_path <- write_csv(storage_audit, file.path(output_root, "storage_audit.csv"))

complete_metrics <- if (nrow(metrics)) sum(as_bool(metrics$metric_complete)) else 0L
contract_passes <- if (nrow(metrics)) sum(as_bool(metrics$execution_contract_match)) else 0L
complete_pairs <- if (nrow(pair_metrics)) sum(as_bool(pair_metrics$pair_complete)) else 0L
winner_count <- nrow(winners)
decision <- if (length(missing_ids) || length(unexpected_ids) || complete_metrics != 168L) {
  "BLOCK_INCOMPLETE_CONFIRMATION"
} else if (contract_passes != 168L || complete_pairs != 144L) {
  "BLOCK_EXECUTION_CONTRACT_FAILURE"
} else if (nrow(storage_audit)) {
  "BLOCK_STORAGE_POLICY_FAILURE"
} else if (winner_count > 0L) {
  "PROMOTION_READY_METRIC_IMPROVEMENTS_PENDING_ARTICLE_REVIEW"
} else {
  "CONFIRMATION_COMPLETE_NO_ARTICLE_METRIC_IMPROVEMENT"
}

gate <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  runner_exit_code = runner_exit_code,
  decision = decision,
  expected_specs = 168L,
  observed_specs = length(observed_ids),
  complete_metric_specs = complete_metrics,
  missing_specs = length(missing_ids),
  unexpected_specs = length(unexpected_ids),
  execution_contract_passes = contract_passes,
  complete_candidate_parent_pairs = complete_pairs,
  article_metric_winners = winner_count,
  unexpected_binary_payloads = nrow(storage_audit),
  diagnostic_status_counts = if (nrow(metrics) && "status" %in% names(metrics)) {
    safe_count_table(metrics$status)
  } else list(),
  diagnostic_signoff_counts = if (nrow(metrics) && "signoff_grade" %in% names(metrics)) {
    safe_count_table(metrics$signoff_grade)
  } else list(),
  diagnostic_policy = "reported_but_not_used_for_metric_selection",
  article_updated = FALSE,
  next_action = switch(
    decision,
    PROMOTION_READY_METRIC_IMPROVEMENTS_PENDING_ARTICLE_REVIEW =
      "Review metric winners and interface preview before a separate article promotion.",
    CONFIRMATION_COMPLETE_NO_ARTICLE_METRIC_IMPROVEMENT =
      "Freeze the evidence and retain the current article metric envelope.",
    "Repair or resume only the missing or contract-invalid roots; do not rerun valid roots."
  ),
  evidence = list(
    metrics = metrics_path,
    execution_audit = execution_audit_path,
    paired_metrics = pair_metrics_path,
    design_summary = design_summary_path,
    promotion_candidates = promotion_candidates_path,
    winners = winners_path,
    interface_preview = interface_preview_path,
    progress = progress_path,
    storage_audit = storage_audit_path,
    missing_specs = missing_path,
    unexpected_specs = unexpected_path
  )
)
gate_path <- write_json(gate, file.path(output_root, "confirmation_gate.json"))

source_manifest <- data.frame(
  role = names(paths),
  path = vapply(paths, resolve_path, character(1L)),
  sha256 = vapply(paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, file.path(output_root, "source_manifest.csv")
)
output_files <- c(
  metrics = metrics_path,
  execution_audit = execution_audit_path,
  paired_metrics = pair_metrics_path,
  design_summary = design_summary_path,
  promotion_candidates = promotion_candidates_path,
  winners = winners_path,
  interface_preview = interface_preview_path,
  progress = progress_path,
  storage_audit = storage_audit_path,
  gate = gate_path,
  source_manifest = source_manifest_path
)
file_manifest <- data.frame(
  role = names(output_files),
  path = unname(output_files),
  sha256 = vapply(output_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest, file.path(output_root, "file_manifest.csv")
)
manifest_path <- write_json(list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  package_version = as.character(read.dcf("DESCRIPTION")[1L, "Version"]),
  source_registry_hash_value = expected_registry_hash,
  decision = decision,
  metric_selection_status_agnostic = TRUE,
  article_updated = FALSE,
  gate_path = gate_path,
  file_manifest_path = file_manifest_path
), file.path(output_root, "closeout_manifest.json"))

cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("observed_specs: %d/168\n", length(observed_ids)))
cat(sprintf("complete_metrics: %d/168\n", complete_metrics))
cat(sprintf("execution_contract_passes: %d/168\n", contract_passes))
cat(sprintf("paired_comparisons: %d/144\n", complete_pairs))
cat(sprintf("article_metric_winners: %d\n", winner_count))
cat(sprintf("decision: %s\n", decision))
cat(sprintf("manifest: %s\n", manifest_path))

if (startsWith(decision, "BLOCK_")) quit(status = 1L)
