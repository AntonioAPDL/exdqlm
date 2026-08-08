#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(jsonlite)
  library(yaml)
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
num <- function(x) suppressWarnings(as.numeric(x))
cell <- function(value, name, default = NA) {
  if (!is.data.frame(value) || !name %in% names(value) || !nrow(value)) return(default)
  value[[name]][[1L]] %||% default
}
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_mcmc_chain_aggregate_v1.R"))
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
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
bind_rows <- function(values) {
  if (!length(values)) return(data.frame())
  columns <- unique(unlist(lapply(values, names), use.names = FALSE))
  values <- lapply(values, function(value) {
    for (column in setdiff(columns, names(value))) value[[column]] <- NA
    value[columns]
  })
  do.call(rbind, values)
}
resolve_campaign_root <- function(outer_root) {
  if (dir.exists(file.path(outer_root, "roots"))) return(outer_root)
  children <- list.dirs(outer_root, recursive = FALSE, full.names = TRUE)
  hits <- children[dir.exists(file.path(children, "roots"))]
  if (!length(hits)) return(outer_root)
  hits[[which.max(file.info(hits)$mtime)]]
}

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_chain_aggregate_confirm_v1"
stub <- file.path("config", "validation", stage)
run_tag <- as.character(get_arg("--run-tag", ""))[1L]
if (!nzchar(run_tag)) stop("--run-tag is required.", call. = FALSE)
runner_exit_code <- suppressWarnings(as.integer(get_arg("--runner-exit-code", "0")))
output_root <- resolve_path(get_arg(
  "--output-root",
  file.path("reports", "qdesn_mcmc_validation", stage, paste0(run_tag, "_closeout"))
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

contract_paths <- list(
  defaults = paste0(stub, "_defaults.yaml"),
  grid = paste0(stub, "_grid.csv"),
  profiles = paste0(stub, "_profiles.csv"),
  targets = paste0(stub, "_target_spec_ids.csv"),
  selected_designs = paste0(stub, "_selected_designs.csv"),
  chain_handoff = paste0(stub, "_chain_handoff.csv"),
  article_context = paste0(stub, "_current_article_metric_context.csv"),
  source_registry = paste0(stub, "_source_registry.csv"),
  chain_config = "config/validation/qdesn_mcmc_chain_aggregate_v1.yaml",
  materialization = paste0(stub, "_materialization_manifest.json")
)
missing_contract <- unlist(contract_paths)[!file.exists(unlist(contract_paths))]
if (length(missing_contract)) {
  stop(sprintf("Missing closeout contract files: %s",
               paste(missing_contract, collapse = ", ")), call. = FALSE)
}
defaults <- yaml::read_yaml(resolve_path(contract_paths$defaults))
grid <- read_csv(contract_paths$grid)
profiles <- read_csv(contract_paths$profiles)
targets <- read_csv(contract_paths$targets)
selected_designs <- read_csv(contract_paths$selected_designs)
handoff <- read_csv(contract_paths$chain_handoff)
article_context <- read_csv(contract_paths$article_context)
registry <- read_csv(contract_paths$source_registry)
chain_config <- yaml::read_yaml(resolve_path(contract_paths$chain_config))
materialization <- jsonlite::read_json(resolve_path(contract_paths$materialization),
                                       simplifyVector = TRUE)
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
if (nrow(grid) != 12L || nrow(profiles) != 12L || nrow(targets) != 12L ||
    nrow(selected_designs) != 4L || nrow(handoff) != 4L ||
    nrow(article_context) != 2L || nrow(registry) != 1L ||
    !identical(materialization$source_registry_hash_value, registry_hash)) {
  stop("Closeout inputs do not match the frozen 12-fit contract.", call. = FALSE)
}

results_outer <- resolve_path(file.path(defaults$campaign$results_root, run_tag), FALSE)
results_root <- resolve_campaign_root(results_outer)
if (!dir.exists(file.path(results_root, "roots"))) {
  stop(sprintf("Run root does not exist: %s", results_outer), call. = FALSE)
}

fit_paths <- list.files(results_root, pattern = "^fit_summary_row[.]csv$",
                        recursive = TRUE, full.names = TRUE)
fit_rows <- lapply(fit_paths, function(path) {
  fit <- tryCatch(utils::read.csv(path, check.names = FALSE,
                                  stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(fit) || !nrow(fit)) return(NULL)
  fit <- fit[1L, , drop = FALSE]
  method_dir <- dirname(path)
  horizon_path <- file.path(method_dir, "tables", "forecast_horizon_summary.csv")
  horizon <- if (file.exists(horizon_path)) {
    tryCatch(utils::read.csv(horizon_path, check.names = FALSE,
                             stringsAsFactors = FALSE), error = function(e) NULL)
  } else NULL
  h1000 <- NULL
  if (!is.null(horizon) && nrow(horizon)) {
    index <- which(suppressWarnings(as.integer(horizon$horizon)) == 1000L |
                     as.character(horizon$window) == "forecast_H1000")
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
  fit$observed_registry_hash <- as.character(
    request$study_contract$source_registry_hash_value %||%
      request$config$study_contract$source_registry_hash_value %||% NA_character_
  )
  fit$observed_source_sha256 <- as.character(
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
fresh <- bind_rows(Filter(Negate(is.null), fit_rows))
if (nrow(fresh)) fresh <- fresh[!duplicated(fresh$spec_id), , drop = FALSE]

profile_fields <- c(
  "screening_profile_id", "source_base_design_id", "confirmation_design_id",
  "target_cell_id", "target_family", "target_tau", "likelihood_target",
  "comparison_role", "selection_role", "sampler_replicate", "D", "n_each",
  "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0", "seed"
)
profile_lookup <- profiles[, profile_fields, drop = FALSE]
if (nrow(fresh)) {
  index <- match(fresh$screening_profile_id, profile_lookup$screening_profile_id)
  for (field in setdiff(profile_fields, "screening_profile_id")) {
    fresh[[field]] <- profile_lookup[[field]][index]
  }
}
expected_ids <- unique(as.character(targets$spec_id))
observed_ids <- if (nrow(fresh)) unique(as.character(fresh$spec_id)) else character()
missing_ids <- setdiff(expected_ids, observed_ids)
unexpected_ids <- setdiff(observed_ids, expected_ids)

grid_contract <- grid[, c(
  "root_id", "screening_profile_id", "desn_seed", "mcmc_seed",
  "mcmc_rng_seed", "vb_warm_start_seed", "synthesis_seed",
  "source_series_wide_sha256", "train_start_source_index",
  "train_end_source_index", "forecast_start_source_index",
  "forecast_end_source_index"
), drop = FALSE]
names(grid_contract)[-(1:2)] <- paste0("expected_", names(grid_contract)[-(1:2)])
if (nrow(fresh)) {
  fresh <- merge(fresh, grid_contract, by = c("root_id", "screening_profile_id"),
                 all.x = TRUE, sort = FALSE)
  fresh$expected_spec_match <- fresh$spec_id %in% expected_ids &
    fresh$likelihood_family == fresh$likelihood_target
  fresh$seed_contract_match <- with(fresh,
    observed_desn_seed == expected_desn_seed &
      observed_mcmc_seed == expected_mcmc_seed &
      observed_mcmc_rng_seed == expected_mcmc_rng_seed &
      observed_vb_warm_start_seed == expected_vb_warm_start_seed &
      observed_synthesis_seed == expected_synthesis_seed
  )
  fresh$source_contract_match <- with(fresh,
    observed_registry_hash == registry_hash &
      observed_source_sha256 == expected_source_series_wide_sha256 &
      observed_train_start == expected_train_start_source_index &
      observed_train_end == expected_train_end_source_index &
      observed_forecast_start == expected_forecast_start_source_index &
      observed_forecast_end == expected_forecast_end_source_index
  )
  fresh$budget_contract_match <- with(fresh,
    observed_n_burn == 5000L & observed_n_mcmc == 20000L
  )
  fresh$execution_contract_match <- with(fresh,
    expected_spec_match & seed_contract_match & source_contract_match &
      budget_contract_match & metric_complete
  )
}

source_metrics_path <- resolve_path(chain_config$sources$discovery_metrics$path)
if (!identical(sha256(source_metrics_path),
               chain_config$sources$discovery_metrics$sha256)) {
  stop("Frozen two-chain discovery metrics changed.", call. = FALSE)
}
historical <- read_csv(source_metrics_path)
historical$source_base_design_id <- historical$base_design_id
prior_confirmation_path <- resolve_path(
  chain_config$sources$confirmation_metrics$path
)
if (!identical(sha256(prior_confirmation_path),
               chain_config$sources$confirmation_metrics$sha256)) {
  stop("Frozen prior-confirmation metrics changed.", call. = FALSE)
}
prior_confirmation <- read_csv(prior_confirmation_path)
prior_confirmation$execution_contract_match <-
  as_bool(prior_confirmation$execution_contract_match)
prior_confirmation$source_role <- "prior_confirmation"
final_design_ids <- unique(c(
  as.character(handoff$source_base_design_id),
  as.character(prior_confirmation$source_base_design_id)
))
historical <- historical[
  historical$source_base_design_id %in% final_design_ids &
    historical$sampler_replicate %in% 1:2, , drop = FALSE
]
historical$execution_contract_match <- as_bool(historical$execution_contract_match)
historical$source_role <- "historical_discovery"
fresh$source_role <- "fresh_confirmation"
chain_columns <- c(
  "source_base_design_id", "sampler_replicate", "spec_id",
  "screening_profile_id", "likelihood_family", "D", "n_each", "m", "alpha",
  "rho", "pi_w", "pi_in", "rhs_tau0", "fit_quantile_path_train_file",
  "forecast_rolling_origin_path_file", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000", "status",
  "signoff_grade", "execution_contract_match", "source_role"
)
chains <- bind_rows(list(historical[, intersect(chain_columns, names(historical))],
                        prior_confirmation[, intersect(chain_columns, names(prior_confirmation))],
                        fresh[, intersect(chain_columns, names(fresh))]))
chains$chain_key <- paste(chains$source_base_design_id,
                          chains$sampler_replicate, sep = "::")

aggregate_rows <- lapply(final_design_ids, function(design_id) {
  block <- chains[chains$source_base_design_id == design_id, , drop = FALSE]
  complete <- nrow(block) == 5L && !anyDuplicated(block$chain_key) &&
    identical(sort(as.integer(block$sampler_replicate)), 1:5) &&
    all(as_bool(block$execution_contract_match))
  if (!complete) {
    return(data.frame(source_base_design_id = design_id, chain_count = nrow(block),
                      complete_five_chain_design = FALSE, stringsAsFactors = FALSE))
  }
  result <- qdesn_chainagg_aggregate_paths(block, tau = 0.25)
  first <- block[1L, , drop = FALSE]
  data.frame(
    source_base_design_id = design_id,
    likelihood_family = first$likelihood_family,
    D = first$D, n_each = first$n_each, m = first$m,
    alpha = first$alpha, rho = first$rho, pi_w = first$pi_w,
    pi_in = first$pi_in, rhs_tau0 = first$rhs_tau0,
    chain_count = 5L, sampler_replicates = "1;2;3;4;5",
    estimator_id = "median_of_chain_posterior_point_paths_v1",
    posterior_pooling_claim = FALSE,
    complete_five_chain_design = TRUE,
    fit_qtrue_rmse = result$metrics$fit_qtrue_rmse,
    forecast_qtrue_mae_H1000 = result$metrics$forecast_qtrue_mae_H1000,
    forecast_check_loss_H1000 = result$metrics$forecast_check_loss_H1000,
    stringsAsFactors = FALSE
  )
})
aggregates <- bind_rows(aggregate_rows)

metric_names <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
                  "forecast_check_loss_H1000")
promotion_rows <- list()
if (nrow(aggregates)) {
  for (index in seq_len(nrow(aggregates))) {
    likelihood <- aggregates$likelihood_family[[index]]
    variant <- if (identical(likelihood, "al")) "qdesn_al_rhs_ns" else "qdesn_exal_rhs_ns"
    authority <- article_context[article_context$model_variant == variant, , drop = FALSE]
    if (nrow(authority) != 1L) stop("Missing authority row.", call. = FALSE)
    for (metric in metric_names) {
      candidate <- num(aggregates[[metric]][[index]])
      current <- num(authority[[metric]][[1L]])
      promotion_rows[[length(promotion_rows) + 1L]] <- data.frame(
        model_variant = variant,
        source_base_design_id = aggregates$source_base_design_id[[index]],
        metric = metric, candidate_value = candidate, current_value = current,
        delta = candidate - current,
        improves_authority = is.finite(candidate) && candidate < current - 1e-10,
        complete_five_chain_design = aggregates$complete_five_chain_design[[index]],
        estimator_id = "median_of_chain_posterior_point_paths_v1",
        stringsAsFactors = FALSE
      )
    }
  }
}
promotion <- bind_rows(promotion_rows)
winners <- promotion[
  as_bool(promotion$complete_five_chain_design) & as_bool(promotion$improves_authority),
  , drop = FALSE
]
if (nrow(winners)) {
  winners <- do.call(rbind, lapply(split(winners,
    paste(winners$model_variant, winners$metric, sep = "::")), function(value) {
      value[which.min(value$candidate_value), , drop = FALSE]
    }))
  rownames(winners) <- NULL
}

heavy <- list.files(results_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
storage_audit <- if (length(heavy)) data.frame(
  path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
  size_bytes = file.info(heavy)$size, stringsAsFactors = FALSE
) else data.frame(path = character(), size_bytes = numeric())
execution_passes <- if (nrow(fresh)) sum(as_bool(fresh$execution_contract_match)) else 0L
complete_designs <- if (nrow(aggregates)) {
  sum(as_bool(aggregates$complete_five_chain_design))
} else 0L
complete_run <- length(observed_ids) == 12L && !length(missing_ids) &&
  !length(unexpected_ids) && execution_passes == 12L && complete_designs == 11L &&
  !nrow(storage_audit) && identical(runner_exit_code, 0L)
decision <- if (!complete_run) {
  "CHAIN_AGGREGATE_CONFIRMATION_INCOMPLETE_REPAIR_ONLY_INVALID_ROOTS"
} else if (nrow(winners)) {
  "CHAIN_AGGREGATE_CONFIRMATION_COMPLETE_IMPROVEMENTS_PENDING_REVIEW"
} else "CHAIN_AGGREGATE_CONFIRMATION_COMPLETE_NO_IMPROVEMENT"

outputs <- c(
  fresh_metrics = write_csv(fresh, file.path(output_root, "fresh_metrics.csv")),
  chain_inventory = write_csv(chains, file.path(output_root, "five_chain_inventory.csv")),
  aggregate_metrics = write_csv(aggregates, file.path(output_root, "five_chain_aggregate_metrics.csv")),
  promotion_candidates = write_csv(promotion, file.path(output_root, "promotion_candidates.csv")),
  winners = write_csv(winners, file.path(output_root, "metric_winners.csv")),
  storage_audit = write_csv(storage_audit, file.path(output_root, "storage_audit.csv")),
  missing_specs = write_csv(data.frame(spec_id = missing_ids),
                            file.path(output_root, "missing_spec_ids.csv")),
  unexpected_specs = write_csv(data.frame(spec_id = unexpected_ids),
                               file.path(output_root, "unexpected_spec_ids.csv"))
)
gate <- list(
  generated_at = as.character(Sys.time()), stage = stage, run_tag = run_tag,
  runner_exit_code = runner_exit_code, decision = decision,
  expected_specs = 12L, observed_specs = length(observed_ids),
  complete_metric_specs = if (nrow(fresh)) sum(as_bool(fresh$metric_complete)) else 0L,
  execution_contract_passes = execution_passes,
  missing_specs = length(missing_ids), unexpected_specs = length(unexpected_ids),
  complete_five_chain_designs = complete_designs,
  expected_five_chain_designs = 11L,
  article_metric_winners = nrow(winners),
  unexpected_binary_payloads = nrow(storage_audit),
  estimator_id = "median_of_chain_posterior_point_paths_v1",
  posterior_pooling_claim = FALSE,
  diagnostic_policy = "reported_but_not_used_for_metric_selection",
  article_updated = FALSE,
  next_action = if (complete_run && nrow(winners)) {
    "Review five-chain metric winners in a separate hash-verified promotion."
  } else if (complete_run) {
    "Close the estimator experiment without changing the v3 article authority."
  } else "Resume only missing or execution-contract-invalid fresh roots.",
  evidence = as.list(outputs)
)
gate_path <- write_json(gate, file.path(output_root, "confirmation_gate.json"))
outputs <- c(outputs, gate = gate_path)
source_manifest <- data.frame(
  role = names(contract_paths),
  path = vapply(contract_paths, resolve_path, character(1L)),
  sha256 = vapply(contract_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(source_manifest,
                                  file.path(output_root, "source_manifest.csv"))
outputs <- c(outputs, source_manifest = source_manifest_path)
file_manifest <- data.frame(
  role = names(outputs), path = unname(outputs),
  sha256 = unname(tools::sha256sum(outputs)), stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(output_root, "file_manifest.csv"))
manifest_path <- write_json(list(
  generated_at = as.character(Sys.time()), stage = stage, run_tag = run_tag,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  package_version = as.character(read.dcf("DESCRIPTION")[1L, "Version"]),
  source_registry_hash_value = registry_hash, decision = decision,
  estimator_id = "median_of_chain_posterior_point_paths_v1",
  posterior_pooling_claim = FALSE, metric_selection_status_agnostic = TRUE,
  article_updated = FALSE, gate_path = gate_path,
  file_manifest_path = file_manifest_path
), file.path(output_root, "closeout_manifest.json"))

cat(sprintf("run_tag: %s\n", run_tag))
cat(sprintf("fresh_specs: %d/12\n", length(observed_ids)))
cat(sprintf("execution_contract_passes: %d/12\n", execution_passes))
cat(sprintf("complete_five_chain_designs: %d/11\n", complete_designs))
cat(sprintf("article_metric_winners: %d\n", nrow(winners)))
cat(sprintf("decision: %s\n", decision))
cat(sprintf("manifest: %s\n", manifest_path))
