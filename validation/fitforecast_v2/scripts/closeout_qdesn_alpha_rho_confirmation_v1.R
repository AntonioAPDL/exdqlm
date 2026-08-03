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

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_alpha_rho_confirmation_v1.R"
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
  jsonlite::write_json(
    value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
finite_median <- function(x) {
  x <- num(x); x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_max <- function(x) {
  x <- num(x); x <- x[is.finite(x)]
  if (length(x)) max(x) else NA_real_
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_confirmation_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    paste0("qdesn_500obs_mcmc_alpha_rho_confirmation_v1_closeout_", format(Sys.Date(), "%Y%m%d"))
  )
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

defaults_path <- paste0(stub, "_defaults.yaml")
grid_path <- paste0(stub, "_grid.csv")
profiles_path <- paste0(stub, "_profiles.csv")
targets_path <- paste0(stub, "_target_spec_ids.csv")
contract_path <- paste0(stub, "_confirmation_contract.csv")
article_context_path <- paste0(stub, "_current_article_metric_context.csv")
source_registry_path <- paste0(stub, "_source_registry.csv")
materialization_path <- paste0(stub, "_materialization_manifest.json")
defaults <- yaml::read_yaml(resolve_path(defaults_path))
grid <- read_csv(grid_path)
profiles <- read_csv(profiles_path)
targets <- read_csv(targets_path)
contract <- read_csv(contract_path)
article_context <- read_csv(article_context_path)
source_registry <- read_csv(source_registry_path)
materialization <- jsonlite::read_json(
  resolve_path(materialization_path), simplifyVector = TRUE
)
if (nrow(grid) != 8L || nrow(targets) != 8L || nrow(profiles) != 8L ||
    !identical(materialization$source_registry_hash_value, paste0(
      "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
    ))) {
  stop("The confirmation closeout contract is not the exact eight-root design.", call. = FALSE)
}

results_root <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
reports_root <- resolve_path(file.path(defaults$campaign$reports_root, run_tag), FALSE)
if (!dir.exists(results_root)) {
  stop(sprintf("Run root does not exist: %s", results_root), call. = FALSE)
}

fit_paths <- list.files(
  results_root, pattern = "^fit_summary_row[.]csv$", recursive = TRUE, full.names = TRUE
)
fit_rows <- lapply(fit_paths, function(path) {
  row <- tryCatch(
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(row) || !nrow(row)) return(NULL)
  row <- row[1L, , drop = FALSE]
  method_dir <- dirname(path)
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(
      utils::read.csv(horizon_path, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
  } else NULL
  h1000 <- if (!is.null(horizon) && nrow(horizon)) {
    index <- which(
      as.integer(horizon$horizon) == 1000L |
        as.character(horizon$window) == "forecast_H1000"
    )
    if (length(index)) horizon[index[[1L]], , drop = FALSE] else NULL
  } else NULL
  request_path <- file.path(method_dir, "fit_request.json")
  request <- if (file.exists(request_path)) {
    jsonlite::read_json(request_path, simplifyVector = TRUE)
  } else list()
  row$fit_summary_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  row$fit_summary_sha256 <- unname(tools::sha256sum(path))
  row$forecast_horizon_path <- if (file.exists(horizon_path)) {
    normalizePath(horizon_path, winslash = "/", mustWork = TRUE)
  } else NA_character_
  row$forecast_horizon_sha256 <- if (file.exists(horizon_path)) {
    unname(tools::sha256sum(horizon_path))
  } else NA_character_
  row$fit_request_path <- if (file.exists(request_path)) {
    normalizePath(request_path, winslash = "/", mustWork = TRUE)
  } else NA_character_
  row$fit_request_sha256 <- if (file.exists(request_path)) {
    unname(tools::sha256sum(request_path))
  } else NA_character_
  row$observed_desn_seed <- as.integer(request$config$desn$seed %||% NA_integer_)
  row$observed_mcmc_seed <- as.integer(
    request$config$inference$mcmc$control$seed %||% NA_integer_
  )
  row$observed_mcmc_rng_seed <- as.integer(
    request$config$inference$mcmc$control$rng_seed %||% NA_integer_
  )
  row$observed_vb_warm_start_seed <- as.integer(
    request$config$inference$mcmc$vb_warm_start_seed %||% NA_integer_
  )
  row$observed_synthesis_seed <- as.integer(
    request$config$synthesis$seed %||% NA_integer_
  )
  row$observed_source_registry_hash <- as.character(
    request$study_contract$alpha_rho_confirmation_v1$source_registry_hash_value %||%
      request$config$study_contract$alpha_rho_confirmation_v1$source_registry_hash_value %||%
      request$root_spec$source_registry_hash_value %||% NA_character_
  )
  row$fit_qtrue_rmse <- num(row$train_qtrue_rmse[[1L]] %||% NA_real_)
  row$forecast_qtrue_mae_H1000 <- if (!is.null(h1000)) {
    num(h1000$qtrue_mae[[1L]])
  } else NA_real_
  row$forecast_check_loss_H1000 <- if (!is.null(h1000)) {
    num(h1000$pinball_tau[[1L]])
  } else NA_real_
  row$metric_complete <- all(is.finite(c(
    row$fit_qtrue_rmse, row$forecast_qtrue_mae_H1000,
    row$forecast_check_loss_H1000
  )))
  row
})
fit_rows <- Filter(Negate(is.null), fit_rows)
metrics <- if (length(fit_rows)) {
  do.call(rbind, fit_rows)
} else data.frame(stringsAsFactors = FALSE)
if (nrow(metrics)) metrics <- metrics[!duplicated(metrics$spec_id), , drop = FALSE]

lookup_fields <- c(
  "screening_profile_id", "target_cell_id", "target_role", "target_family",
  "target_tau", "candidate_id", "comparison_role", "reservoir_replicate",
  "confirmation_pair_id", "source_screening_profile_id", "D", "n_each", "m",
  "alpha", "rho", "pi_w", "pi_in", "rhs_tau0"
)
lookup <- profiles[, lookup_fields, drop = FALSE]
if (nrow(metrics)) {
  lookup_index <- match(metrics$screening_profile_id, lookup$screening_profile_id)
  for (field in setdiff(lookup_fields, "screening_profile_id")) {
    metrics[[field]] <- lookup[[field]][lookup_index]
  }
  metrics$family <- as.character(metrics$target_family)
  metrics$tau <- num(metrics$target_tau)
}

expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(metrics)) unique(as.character(metrics$spec_id)) else character()
missing_ids <- setdiff(expected_ids, observed_ids)
unexpected_ids <- setdiff(observed_ids, expected_ids)
missing_path <- write_csv(data.frame(spec_id = missing_ids), file.path(output_root, "missing_spec_ids.csv"))
unexpected_path <- write_csv(
  data.frame(spec_id = unexpected_ids), file.path(output_root, "unexpected_spec_ids.csv")
)

seed_fields <- c(
  "desn_seed", "mcmc_seed", "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed"
)
grid_seed <- grid[, c("root_id", "screening_profile_id", seed_fields), drop = FALSE]
names(grid_seed)[match(seed_fields, names(grid_seed))] <- paste0("expected_", seed_fields)
if (nrow(metrics)) {
  metrics <- merge(
    metrics, grid_seed, by = c("root_id", "screening_profile_id"),
    all.x = TRUE, sort = FALSE
  )
  metrics$seed_contract_match <- with(metrics,
    observed_desn_seed == expected_desn_seed &
      observed_mcmc_seed == expected_mcmc_seed &
      observed_mcmc_rng_seed == expected_mcmc_rng_seed &
      observed_vb_warm_start_seed == expected_vb_warm_start_seed &
      observed_synthesis_seed == expected_synthesis_seed
  )
  metrics$source_registry_hash_match <-
    metrics$observed_source_registry_hash == materialization$source_registry_hash_value
}
metrics_path <- write_csv(metrics, file.path(output_root, "confirmation_metrics.csv"))
execution_audit_path <- if (nrow(metrics)) {
  write_csv(metrics[, c(
    "spec_id", "root_id", "screening_profile_id", "target_cell_id",
    "comparison_role", "reservoir_replicate", "confirmation_pair_id",
    "status", "signoff_grade", "metric_complete", "seed_contract_match",
    "source_registry_hash_match", "fit_request_path", "fit_request_sha256"
  ), drop = FALSE], file.path(output_root, "execution_contract_audit.csv"))
} else {
  write_csv(data.frame(), file.path(output_root, "execution_contract_audit.csv"))
}

pair_metrics <- if (nrow(metrics) == 8L && all(metrics$metric_complete)) {
  qdesn_arfc1_pair_metrics(metrics)
} else data.frame(stringsAsFactors = FALSE)
pair_metrics_path <- write_csv(pair_metrics, file.path(output_root, "paired_metrics.csv"))

cell_summary <- if (nrow(pair_metrics)) {
  rows <- lapply(split(pair_metrics, pair_metrics$target_cell_id), function(x) {
    data.frame(
      target_cell_id = x$target_cell_id[[1L]],
      family = x$family[[1L]],
      tau = x$tau[[1L]],
      n_pairs = nrow(x),
      median_fit_ratio = finite_median(x$fit_ratio),
      median_forecast_mae_ratio = finite_median(x$forecast_mae_ratio),
      median_forecast_check_ratio = finite_median(x$forecast_check_ratio),
      max_individual_ratio = finite_max(c(
        x$fit_ratio, x$forecast_mae_ratio, x$forecast_check_ratio
      )),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
} else data.frame(stringsAsFactors = FALSE)
if (nrow(cell_summary)) {
  cell_summary <- merge(cell_summary, contract, by = "target_cell_id", sort = FALSE)
  cell_summary$primary_gate_pass <- ifelse(
    cell_summary$primary_objective == "forecast_transport",
    cell_summary$median_forecast_mae_ratio <= cell_summary$primary_ratio_gate,
    cell_summary$median_fit_ratio <= cell_summary$primary_ratio_gate
  )
  cell_summary$companion_gate_pass <- ifelse(
    cell_summary$primary_objective == "forecast_transport",
    pmax(
      cell_summary$median_fit_ratio,
      cell_summary$median_forecast_check_ratio
    ) <= cell_summary$companion_median_ratio_max,
    pmax(
      cell_summary$median_forecast_mae_ratio,
      cell_summary$median_forecast_check_ratio
    ) <= cell_summary$companion_median_ratio_max
  )
  cell_summary$individual_gate_pass <-
    cell_summary$max_individual_ratio <= cell_summary$individual_ratio_max
  cell_summary$paired_confirmation_pass <- with(
    cell_summary,
    n_pairs == 2L & primary_gate_pass & companion_gate_pass & individual_gate_pass
  )
}
cell_summary_path <- write_csv(
  cell_summary, file.path(output_root, "cell_confirmation_summary.csv")
)

current <- article_context[
  article_context$model_variant == "qdesn_exal_rhs_ns",
  c(
    "family", "tau", "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000", "source_registry_hash_value"
  ),
  drop = FALSE
]
names(current)[3:5] <- paste0("current_", names(current)[3:5])
candidates <- if (nrow(metrics)) {
  metrics[metrics$comparison_role == "candidate", , drop = FALSE]
} else data.frame(stringsAsFactors = FALSE)
article_comparison <- if (nrow(candidates)) {
  merge(candidates, current, by = c("family", "tau"), all.x = TRUE, sort = FALSE)
} else data.frame(stringsAsFactors = FALSE)
if (nrow(article_comparison)) {
  article_comparison$fit_ratio_to_current <- with(
    article_comparison, fit_qtrue_rmse / current_fit_qtrue_rmse
  )
  article_comparison$forecast_mae_ratio_to_current <- with(
    article_comparison,
    forecast_qtrue_mae_H1000 / current_forecast_qtrue_mae_H1000
  )
  article_comparison$forecast_check_ratio_to_current <- with(
    article_comparison,
    forecast_check_loss_H1000 / current_forecast_check_loss_H1000
  )
}
article_comparison_path <- write_csv(
  article_comparison, file.path(output_root, "candidate_vs_current_article_metrics.csv")
)

metric_names <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
promotion_rows <- list()
if (nrow(article_comparison)) {
  for (i in seq_len(nrow(article_comparison))) {
    row <- article_comparison[i, , drop = FALSE]
    ratios <- c(
      fit_qtrue_rmse = row$fit_ratio_to_current,
      forecast_qtrue_mae_H1000 = row$forecast_mae_ratio_to_current,
      forecast_check_loss_H1000 = row$forecast_check_ratio_to_current
    )
    for (metric in metric_names) {
      companions <- ratios[names(ratios) != metric]
      promotion_rows[[length(promotion_rows) + 1L]] <- data.frame(
        target_cell_id = row$target_cell_id,
        family = row$family,
        tau = row$tau,
        reservoir_replicate = row$reservoir_replicate,
        screening_profile_id = row$screening_profile_id,
        spec_id = row$spec_id,
        metric = metric,
        candidate_value = num(row[[metric]]),
        current_value = num(row[[paste0("current_", metric)]]),
        ratio_to_current = num(ratios[[metric]]),
        companion_max_ratio = finite_max(companions),
        metric_improves_current = num(ratios[[metric]]) < 1,
        companion_guard_pass = finite_max(companions) <= 1.05,
        source_registry_hash_match = as_bool(row$source_registry_hash_match),
        seed_contract_match = as_bool(row$seed_contract_match),
        diagnostic_status = as.character(row$status),
        signoff_grade = as.character(row$signoff_grade),
        stringsAsFactors = FALSE
      )
    }
  }
}
promotion_candidates <- if (length(promotion_rows)) {
  do.call(rbind, promotion_rows)
} else data.frame(stringsAsFactors = FALSE)
if (nrow(promotion_candidates)) {
  promotion_candidates$promotion_eligible <- with(
    promotion_candidates,
    metric_improves_current & companion_guard_pass &
      source_registry_hash_match & seed_contract_match
  )
  promotion_candidates <- promotion_candidates[order(
    promotion_candidates$target_cell_id,
    promotion_candidates$metric,
    promotion_candidates$ratio_to_current
  ), , drop = FALSE]
}
promotion_candidates_path <- write_csv(
  promotion_candidates, file.path(output_root, "article_metric_promotion_candidates.csv")
)

progress_paths <- if (dir.exists(reports_root)) {
  list.files(
    reports_root, pattern = "^campaign_progress[.]csv$", recursive = TRUE,
    full.names = TRUE
  )
} else character()
progress <- if (length(progress_paths)) {
  utils::read.csv(progress_paths[[length(progress_paths)]], check.names = FALSE,
                  stringsAsFactors = FALSE)
} else data.frame(stringsAsFactors = FALSE)
progress_path <- write_csv(progress, file.path(output_root, "campaign_progress_snapshot.csv"))

binary_paths <- list.files(
  results_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
storage_audit <- if (length(binary_paths)) {
  data.frame(
    path = normalizePath(binary_paths, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(file.info(binary_paths)$size),
    disposition = "unexpected_confirmation_payload",
    stringsAsFactors = FALSE
  )
} else data.frame(path = character(), bytes = numeric(), disposition = character())
storage_audit_path <- write_csv(storage_audit, file.path(output_root, "storage_audit.csv"))

complete_metrics <- if (nrow(metrics)) sum(as_bool(metrics$metric_complete)) else 0L
seed_passes <- if (nrow(metrics)) sum(as_bool(metrics$seed_contract_match)) else 0L
registry_passes <- if (nrow(metrics)) sum(as_bool(metrics$source_registry_hash_match)) else 0L
all_pairs_complete <- nrow(pair_metrics) == 4L
all_cell_gates <- nrow(cell_summary) == 2L && all(cell_summary$paired_confirmation_pass)
promotion_count <- if (nrow(promotion_candidates)) {
  sum(promotion_candidates$promotion_eligible)
} else 0L
decision <- if (length(missing_ids) || length(unexpected_ids) ||
    complete_metrics != 8L) {
  "BLOCK_INCOMPLETE_CONFIRMATION"
} else if (seed_passes != 8L || registry_passes != 8L || !all_pairs_complete) {
  "BLOCK_EXECUTION_CONTRACT_FAILURE"
} else if (nrow(storage_audit)) {
  "BLOCK_STORAGE_POLICY_FAILURE"
} else if (promotion_count > 0L) {
  "ARTICLE_METRIC_PROMOTION_ELIGIBLE_PENDING_MANUAL_REVIEW"
} else if (all_cell_gates) {
  "CONFIRMED_PARENT_RELATIVE_ONLY_NO_ARTICLE_MINIMUM"
} else {
  "NO_TRANSPORT_STOP_ALPHA_RHO_LOCAL_DIRECTION"
}

gate <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  decision = decision,
  expected_specs = 8L,
  observed_specs = length(observed_ids),
  complete_metric_specs = complete_metrics,
  missing_specs = length(missing_ids),
  unexpected_specs = length(unexpected_ids),
  seed_contract_passes = seed_passes,
  source_registry_hash_passes = registry_passes,
  complete_candidate_parent_pairs = nrow(pair_metrics),
  cell_confirmation_passes = if (nrow(cell_summary)) {
    sum(cell_summary$paired_confirmation_pass)
  } else 0L,
  article_metric_promotion_candidates = promotion_count,
  unexpected_binary_payloads = nrow(storage_audit),
  diagnostic_status_counts = if (nrow(metrics)) as.list(table(metrics$status)) else list(),
  diagnostic_signoff_counts = if (nrow(metrics)) as.list(table(metrics$signoff_grade)) else list(),
  article_updated = FALSE,
  next_action = switch(
    decision,
    ARTICLE_METRIC_PROMOTION_ELIGIBLE_PENDING_MANUAL_REVIEW =
      "Review metricwise candidates and update the article only after explicit approval.",
    CONFIRMED_PARENT_RELATIVE_ONLY_NO_ARTICLE_MINIMUM =
      "Freeze confirmation evidence; retain the existing article minima.",
    NO_TRANSPORT_STOP_ALPHA_RHO_LOCAL_DIRECTION =
      "Stop local alpha/rho screening and redesign architecture/readout/shrinkage.",
    "Repair the failed confirmation contract before scientific use."
  ),
  evidence = list(
    metrics = metrics_path,
    execution_audit = execution_audit_path,
    pair_metrics = pair_metrics_path,
    cell_summary = cell_summary_path,
    article_comparison = article_comparison_path,
    promotion_candidates = promotion_candidates_path,
    campaign_progress = progress_path,
    storage_audit = storage_audit_path,
    missing_specs = missing_path,
    unexpected_specs = unexpected_path
  )
)
gate_path <- write_json(gate, file.path(output_root, "confirmation_gate.json"))

source_files <- c(
  defaults = defaults_path,
  grid = grid_path,
  profiles = profiles_path,
  target_specs = targets_path,
  contract = contract_path,
  article_context = article_context_path,
  source_registry = source_registry_path,
  materialization = materialization_path
)
source_manifest <- data.frame(
  role = names(source_files),
  path = vapply(source_files, resolve_path, character(1L)),
  sha256 = vapply(source_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, file.path(output_root, "source_manifest.csv")
)
output_files <- c(
  metrics = metrics_path,
  execution_audit = execution_audit_path,
  pair_metrics = pair_metrics_path,
  cell_summary = cell_summary_path,
  article_comparison = article_comparison_path,
  promotion_candidates = promotion_candidates_path,
  progress = progress_path,
  storage = storage_audit_path,
  gate = gate_path,
  source_manifest = source_manifest_path
)
file_manifest <- data.frame(
  role = names(output_files),
  path = unname(output_files),
  sha256 = vapply(output_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(output_root, "file_manifest.csv"))
manifest <- list(
  generated_at = as.character(Sys.time()),
  stage = stage,
  run_tag = run_tag,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  package_version = as.character(read.dcf("DESCRIPTION")[1L, "Version"]),
  source_registry_hash_value = materialization$source_registry_hash_value,
  decision = decision,
  article_updated = FALSE,
  gate_path = gate_path,
  file_manifest_path = file_manifest_path
)
manifest_path <- write_json(manifest, file.path(output_root, "closeout_manifest.json"))

cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("observed_specs: %d/8\n", length(observed_ids)))
cat(sprintf("complete_metrics: %d/8\n", complete_metrics))
cat(sprintf("paired_comparisons: %d/4\n", nrow(pair_metrics)))
cat(sprintf("article_metric_candidates: %d\n", promotion_count))
cat(sprintf("decision: %s\n", decision))
cat(sprintf("manifest: %s\n", manifest_path))
