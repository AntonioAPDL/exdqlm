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
repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "qdesn_mcmc_chain_aggregate_v1.R"))
resolve_path <- function(path, must_work = TRUE) {
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

config_path <- resolve_path(get_arg(
  "--config", "config/validation/qdesn_mcmc_chain_aggregate_v1.yaml"
))
output_root <- resolve_path(get_arg(
  "--output-root", "reports/qdesn_mcmc_chain_aggregate_v1/audit_20260808"
), FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
config <- yaml::read_yaml(config_path)

source_specs <- config$sources[c(
  "discovery_metrics", "discovery_gate", "confirmation_metrics",
  "confirmation_gate", "article_authority"
)]
source_audit <- do.call(rbind, lapply(names(source_specs), function(role) {
  spec <- source_specs[[role]]
  path <- resolve_path(spec$path)
  observed <- sha256(path)
  data.frame(
    role = role, path = path, expected_sha256 = spec$sha256,
    observed_sha256 = observed, hash_match = identical(observed, spec$sha256),
    size_bytes = file.info(path)$size, stringsAsFactors = FALSE
  )
}))
if (!all(source_audit$hash_match)) stop("A frozen source hash does not match.", call. = FALSE)

discovery_gate <- jsonlite::read_json(
  resolve_path(config$sources$discovery_gate$path), simplifyVector = TRUE
)
confirmation_gate <- jsonlite::read_json(
  resolve_path(config$sources$confirmation_gate$path), simplifyVector = TRUE
)
gate_complete <- function(value) {
  expected <- as.integer(value$expected_specs %||% NA_integer_)
  identical(as.integer(value$runner_exit_code %||% NA_integer_), 0L) &&
    is.finite(expected) &&
    identical(as.integer(value$observed_specs %||% NA_integer_), expected) &&
    identical(as.integer(value$complete_metric_specs %||% NA_integer_), expected) &&
    identical(as.integer(value$execution_contract_passes %||% NA_integer_), expected) &&
    identical(as.integer(value$missing_specs %||% NA_integer_), 0L) &&
    identical(as.integer(value$unexpected_specs %||% NA_integer_), 0L) &&
    identical(as.integer(value$unexpected_binary_payloads %||% NA_integer_), 0L)
}
if (!gate_complete(discovery_gate) || !gate_complete(confirmation_gate)) {
  stop("Both source campaigns must have structurally complete gates.", call. = FALSE)
}

normalize_metrics <- function(path, campaign, source_role) {
  value <- utils::read.csv(resolve_path(path), check.names = FALSE,
                           stringsAsFactors = FALSE)
  design_column <- if ("source_base_design_id" %in% names(value)) {
    "source_base_design_id"
  } else "base_design_id"
  required <- c(
    "spec_id", design_column, "sampler_replicate", "likelihood_family",
    "D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "rhs_tau0",
    "fit_quantile_path_train_file", "forecast_rolling_origin_path_file",
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
    "forecast_check_loss_H1000", "execution_contract_match"
  )
  qdesn_chainagg_require_columns(value, required, source_role)
  value$chain_aggregate_design_id <- as.character(value[[design_column]])
  value$source_campaign <- campaign
  value$source_role <- source_role
  value$chain_key <- paste(value$chain_aggregate_design_id,
                           value$sampler_replicate, sep = "::")
  value
}

discovery <- normalize_metrics(
  config$sources$discovery_metrics$path,
  config$sources$discovery_metrics$campaign, "discovery"
)
confirmation <- normalize_metrics(
  config$sources$confirmation_metrics$path,
  config$sources$confirmation_metrics$campaign, "confirmation"
)
bind_rows <- function(values) {
  columns <- unique(unlist(lapply(values, names), use.names = FALSE))
  values <- lapply(values, function(value) {
    for (column in setdiff(columns, names(value))) value[[column]] <- NA
    value[columns]
  })
  do.call(rbind, values)
}
chains <- bind_rows(list(discovery, confirmation))
if (anyDuplicated(chains$chain_key)) stop("Duplicate design/chain keys found.", call. = FALSE)
if (!all(qdesn_chainagg_as_bool(chains$execution_contract_match))) {
  stop("At least one source chain violates its execution contract.", call. = FALSE)
}
if (any(!file.exists(chains$fit_quantile_path_train_file)) ||
    any(!file.exists(chains$forecast_rolling_origin_path_file))) {
  stop("At least one compact source path is missing.", call. = FALSE)
}

path_manifest <- rbind(
  data.frame(
    chain_key = chains$chain_key, role = "fit_path",
    path = chains$fit_quantile_path_train_file, stringsAsFactors = FALSE
  ),
  data.frame(
    chain_key = chains$chain_key, role = "forecast_path",
    path = chains$forecast_rolling_origin_path_file, stringsAsFactors = FALSE
  )
)
path_manifest$sha256 <- unname(tools::sha256sum(path_manifest$path))
path_manifest$size_bytes <- file.info(path_manifest$path)$size

target <- config$target
estimator <- config$estimator
design_ids <- sort(unique(chains$chain_aggregate_design_id))
aggregate_rows <- lapply(design_ids, function(design_id) {
  block <- chains[chains$chain_aggregate_design_id == design_id, , drop = FALSE]
  invariant_columns <- c(
    "likelihood_family", "D", "n_each", "m", "alpha", "rho", "pi_w",
    "pi_in", "rhs_tau0"
  )
  for (column in invariant_columns) {
    if (length(unique(block[[column]])) != 1L) {
      stop(sprintf("Design %s is not invariant in %s.", design_id, column),
           call. = FALSE)
    }
  }
  aggregate <- qdesn_chainagg_aggregate_paths(
    block,
    train_start = target$train_start_source_index,
    train_end = target$train_end_source_index,
    forecast_start = target$forecast_start_source_index,
    forecast_end = target$forecast_end_source_index,
    max_lead = target$forecast_max_lead,
    tau = target$tau
  )
  data.frame(
    chain_aggregate_design_id = design_id,
    likelihood_family = block$likelihood_family[[1L]],
    D = block$D[[1L]], n_each = block$n_each[[1L]], m = block$m[[1L]],
    alpha = block$alpha[[1L]], rho = block$rho[[1L]],
    pi_w = block$pi_w[[1L]], pi_in = block$pi_in[[1L]],
    rhs_tau0 = block$rhs_tau0[[1L]],
    chain_count = nrow(block),
    sampler_replicates = paste(sort(block$sampler_replicate), collapse = ";"),
    source_campaign_count = length(unique(block$source_campaign)),
    estimator_id = estimator$id,
    fit_qtrue_rmse = aggregate$metrics$fit_qtrue_rmse,
    forecast_qtrue_mae_H1000 = aggregate$metrics$forecast_qtrue_mae_H1000,
    forecast_check_loss_H1000 = aggregate$metrics$forecast_check_loss_H1000,
    fit_n = aggregate$metrics$fit_n,
    forecast_pair_n = aggregate$metrics$forecast_pair_n,
    individual_fit_median = median(block$fit_qtrue_rmse),
    individual_fit_min = min(block$fit_qtrue_rmse),
    individual_forecast_mae_median = median(block$forecast_qtrue_mae_H1000),
    individual_forecast_mae_min = min(block$forecast_qtrue_mae_H1000),
    individual_forecast_check_median = median(block$forecast_check_loss_H1000),
    individual_forecast_check_min = min(block$forecast_check_loss_H1000),
    stringsAsFactors = FALSE
  )
})
aggregates <- do.call(rbind, aggregate_rows)

authority <- utils::read.csv(resolve_path(config$sources$article_authority$path),
                             check.names = FALSE, stringsAsFactors = FALSE)
authority <- authority[
  tolower(authority$family) == target$family &
    abs(authority$tau - target$tau) < 1e-12 &
    tolower(authority$inference) == "mcmc", , drop = FALSE
]
variant <- ifelse(aggregates$likelihood_family == "al",
                  "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
authority_index <- match(variant, authority$model_variant)
if (anyNA(authority_index)) stop("Missing Q-DESN authority row.", call. = FALSE)
for (metric in c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
                 "forecast_check_loss_H1000")) {
  aggregates[[paste0("authority_", metric)]] <- authority[[metric]][authority_index]
  aggregates[[paste0("delta_", metric)]] <-
    aggregates[[metric]] - aggregates[[paste0("authority_", metric)]]
  aggregates[[paste0("improves_", metric)]] <-
    aggregates[[paste0("delta_", metric)]] < 0
}
improvement_columns <- paste0("improves_", c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
))
aggregates$metrics_improved <- rowSums(aggregates[improvement_columns])
aggregates$confirmation_eligible <-
  aggregates$chain_count >= estimator$minimum_chains_confirmation
aggregates$evidence_tier <- ifelse(
  aggregates$confirmation_eligible, "five_chain_confirmation", "two_chain_discovery"
)
metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
aggregates$pareto_nondominated <- FALSE
for (likelihood in unique(aggregates$likelihood_family)) {
  index <- which(aggregates$likelihood_family == likelihood)
  aggregates$pareto_nondominated[index] <-
    qdesn_chainagg_pareto(aggregates[index, , drop = FALSE], metric_columns)
}
aggregates$relative_gain_sum <- rowSums(sapply(metric_columns, function(metric) {
  pmax(0, -aggregates[[paste0("delta_", metric)]]) /
    aggregates[[paste0("authority_", metric)]]
}))
aggregates <- aggregates[order(
  aggregates$likelihood_family, -aggregates$confirmation_eligible,
  -aggregates$metrics_improved, -aggregates$relative_gain_sum,
  aggregates$chain_aggregate_design_id
), , drop = FALSE]

confirmed <- aggregates[
  aggregates$confirmation_eligible & aggregates$metrics_improved > 0L, , drop = FALSE
]
shortlist <- aggregates[
  !aggregates$confirmation_eligible & aggregates$pareto_nondominated &
    aggregates$metrics_improved >= config$selection$minimum_metrics_improved_for_followup,
  , drop = FALSE
]
if (nrow(shortlist)) {
  shortlist <- do.call(rbind, lapply(split(shortlist, shortlist$likelihood_family),
    function(value) head(value[order(-value$metrics_improved,
                                     -value$relative_gain_sum), , drop = FALSE],
                         config$selection$maximum_followup_designs_per_likelihood)
  ))
  rownames(shortlist) <- NULL
}

chain_inventory_columns <- c(
  "chain_key", "source_role", "source_campaign", "chain_aggregate_design_id",
  "sampler_replicate", "spec_id", "likelihood_family", "D", "n_each", "m",
  "alpha", "rho", "pi_w", "pi_in", "rhs_tau0",
  "fit_quantile_path_train_file", "forecast_rolling_origin_path_file",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "status", "signoff_grade", "execution_contract_match"
)
outputs <- c(
  source_audit = write_csv(source_audit, file.path(output_root, "source_audit.csv")),
  chain_inventory = write_csv(chains[, intersect(chain_inventory_columns, names(chains))],
                              file.path(output_root, "chain_inventory.csv")),
  compact_path_manifest = write_csv(path_manifest,
                                    file.path(output_root, "compact_path_manifest.csv")),
  aggregate_metrics = write_csv(aggregates,
                                file.path(output_root, "aggregate_metrics.csv")),
  confirmed_candidates = write_csv(confirmed,
                                   file.path(output_root, "confirmed_candidates.csv")),
  followup_shortlist = write_csv(shortlist,
                                file.path(output_root, "followup_shortlist.csv"))
)
gate <- list(
  generated_at = as.character(Sys.time()),
  decision = if (nrow(shortlist)) {
    "CHAIN_AGGREGATE_AUDIT_COMPLETE_TARGETED_CONFIRMATION_JUSTIFIED"
  } else "CHAIN_AGGREGATE_AUDIT_COMPLETE_NO_TARGETED_CONFIRMATION",
  estimator_id = estimator$id,
  posterior_pooling_claim = FALSE,
  source_chain_count = nrow(chains),
  source_design_count = nrow(aggregates),
  five_chain_design_count = sum(aggregates$confirmation_eligible),
  confirmed_improvement_design_count = nrow(confirmed),
  followup_design_count = nrow(shortlist),
  article_updated = FALSE,
  source_registry_hash = config$sources$source_registry_hash,
  outputs = as.list(outputs)
)
gate_path <- write_json(gate, file.path(output_root, "audit_gate.json"))
outputs <- c(outputs, audit_gate = gate_path)
file_manifest <- data.frame(
  role = names(outputs), path = unname(outputs),
  sha256 = unname(tools::sha256sum(outputs)), stringsAsFactors = FALSE
)
manifest_path <- write_csv(file_manifest, file.path(output_root, "file_manifest.csv"))
write_json(list(
  generated_at = as.character(Sys.time()), config_path = config_path,
  config_sha256 = sha256(config_path), git_branch = trimws(system(
    "git branch --show-current", intern = TRUE
  )), git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  package_version = as.character(read.dcf("DESCRIPTION")[1L, "Version"]),
  estimator_id = estimator$id, posterior_pooling_claim = FALSE,
  file_manifest = manifest_path
), file.path(output_root, "audit_manifest.json"))

cat(sprintf("source chains: %d\n", nrow(chains)))
cat(sprintf("source designs: %d\n", nrow(aggregates)))
cat(sprintf("five-chain designs: %d\n", sum(aggregates$confirmation_eligible)))
cat(sprintf("confirmed improvement designs: %d\n", nrow(confirmed)))
cat(sprintf("follow-up shortlist: %d\n", nrow(shortlist)))
cat(sprintf("decision: %s\n", gate$decision))
cat(sprintf("manifest: %s\n", manifest_path))
