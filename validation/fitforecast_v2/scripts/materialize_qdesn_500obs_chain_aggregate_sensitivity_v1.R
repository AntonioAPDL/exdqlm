#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required.", call. = FALSE)
  }
})

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
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

sensitivity_id <- "qdesn_500obs_mcmc_chain_aggregate_sensitivity_v1_20260808"
run_id <- "qdesn_mcmc_chain_aggregate_confirm_v1_20260808_161301"
run_tag <- "qdesn-cagc1-full-20260808_161301__git-8cfd304"
source_branch <- "validation/qdesn-mcmc-chain-aggregate-confirm-v1-1.0.0"
source_commit <- "8cfd304c5d2eb9af76195998a3ef097ec79b801f"
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
estimator_id <- "median_of_chain_posterior_point_paths_v1"

base_id <- "qdesn_dqlm_500obs_trainonly_article_v3_20260807"
base_path <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", base_id,
  paste0(base_id, "_interface.csv")
)
state_root <- normalizePath(get_arg(
  "--state-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
), winslash = "/", mustWork = TRUE)
closeout_dir <- file.path(state_root, "closeout")
output_dir <- normalizePath(get_arg(
  "--output-dir",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", sensitivity_id)
), winslash = "/", mustWork = FALSE)

paths <- list(
  gate = file.path(closeout_dir, "confirmation_gate.json"),
  closeout_manifest = file.path(closeout_dir, "closeout_manifest.json"),
  file_manifest = file.path(closeout_dir, "file_manifest.csv"),
  aggregate_metrics = file.path(closeout_dir, "five_chain_aggregate_metrics.csv"),
  promotion_candidates = file.path(closeout_dir, "promotion_candidates.csv"),
  metric_winners = file.path(closeout_dir, "metric_winners.csv"),
  inventory = file.path(closeout_dir, "five_chain_inventory.csv"),
  fresh_metrics = file.path(closeout_dir, "fresh_metrics.csv"),
  storage_audit = file.path(closeout_dir, "storage_audit.csv"),
  stage_status = file.path(state_root, "stage_status.csv")
)
if (!file.exists(base_path) || any(!file.exists(unlist(paths)))) {
  stop("The frozen chain-aggregate input set is incomplete.", call. = FALSE)
}

expected_hashes <- c(
  base_interface = "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393",
  gate = "2b115d9d47d8c0e246e06c2b819c76a6642d16dd9f9c23bb7670c05e02168b70",
  closeout_manifest = "17c26adaa1fedb70f7c6a6c07a3c97a1a171c5761da0d4ea6932842ec372ed93",
  file_manifest = "032a9240a387c1f92491bcb1a46c2a0ce7afe951faa7c3299754b311b95a7a21",
  aggregate_metrics = "2007165bcd9df4241100755658cec68869c918bcaf349aa226b38fe9f4f3cd45",
  promotion_candidates = "15041a08983ebb21035ad4da6236d76a42f428d7dea0749275a924bc3b5e4da8",
  metric_winners = "e354ea2651c6279a3b6331ec72f52ce89a608567b365decf747e9a4ee56ac55a",
  inventory = "2954a370ae408af1612b1da145d7299ff497e2d8653c435956b2021b48e81ed9",
  fresh_metrics = "62c4033df963009a7c538cd37a55e172a9e14ef190221a8b4a8f838366447847",
  storage_audit = "f74ab2f7fa49a56440be489528c50fc1d9802dac7677339232bc5449a80a2eaf",
  stage_status = "6dd7d7bc9ed52e2a054cc0e8e1d041117e3c0350ef71e0a75651824c538c87ed"
)
actual_hashes <- c(
  base_interface = sha256(base_path),
  vapply(paths, sha256, character(1L))
)
if (!identical(unname(actual_hashes[names(expected_hashes)]),
               unname(expected_hashes))) {
  mismatch <- names(expected_hashes)[
    actual_hashes[names(expected_hashes)] != expected_hashes
  ]
  stop(sprintf("Frozen input hash mismatch: %s", paste(mismatch, collapse = ", ")),
       call. = FALSE)
}

gate <- jsonlite::read_json(paths$gate, simplifyVector = TRUE)
source_manifest <- jsonlite::read_json(paths$closeout_manifest,
                                       simplifyVector = TRUE)
file_manifest <- read_csv(paths$file_manifest)
if (!identical(gate$decision,
               "CHAIN_AGGREGATE_CONFIRMATION_COMPLETE_IMPROVEMENTS_PENDING_REVIEW") ||
    gate$runner_exit_code != 0L || gate$expected_specs != 12L ||
    gate$observed_specs != 12L || gate$complete_metric_specs != 12L ||
    gate$execution_contract_passes != 12L ||
    gate$complete_five_chain_designs != 11L ||
    gate$expected_five_chain_designs != 11L ||
    gate$article_metric_winners != 5L ||
    gate$unexpected_binary_payloads != 0L ||
    !identical(gate$estimator_id, estimator_id) ||
    isTRUE(gate$posterior_pooling_claim) ||
    !identical(source_manifest$run_tag, run_tag) ||
    !identical(source_manifest$git_branch, source_branch) ||
    !identical(source_manifest$git_commit, source_commit) ||
    !identical(source_manifest$source_registry_hash_value, registry_hash)) {
  stop("The completed chain-aggregate gate violates the review contract.",
       call. = FALSE)
}
if (any(!file.exists(file_manifest$path)) ||
    !identical(unname(tools::sha256sum(file_manifest$path)),
               unname(file_manifest$sha256))) {
  stop("The chain-aggregate closeout file manifest is stale.", call. = FALSE)
}

article <- read_csv(base_path)
metrics <- read_csv(paths$aggregate_metrics)
candidates <- read_csv(paths$promotion_candidates)
winners <- read_csv(paths$metric_winners)
inventory <- read_csv(paths$inventory)
storage <- read_csv(paths$storage_audit)
metric_names <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
                  "forecast_check_loss_H1000")

article_key <- with(article, paste(inference, model_variant, family,
                                   sprintf("%.2f", tau)))
if (nrow(article) != 72L || anyDuplicated(article_key) ||
    any(article$source_registry_hash_value != registry_hash) ||
    any(article$package_version != "1.0.0")) {
  stop("The article-v3 authority violates its frozen 72-row contract.",
       call. = FALSE)
}
if (nrow(metrics) != 11L || any(metrics$chain_count != 5L) ||
    !all(metrics$complete_five_chain_design) ||
    any(metrics$estimator_id != estimator_id) ||
    any(metrics$posterior_pooling_claim) ||
    nrow(inventory) != 55L || nrow(winners) != 5L || nrow(storage) != 0L ||
    any(!is.finite(as.numeric(unlist(metrics[metric_names], use.names = FALSE))))) {
  stop("The five-chain evidence violates its estimator or storage contract.",
       call. = FALSE)
}

expected_winner_key <- c(
  "qdesn_al_rhs_ns fit_qtrue_rmse",
  "qdesn_al_rhs_ns forecast_qtrue_mae_H1000",
  "qdesn_exal_rhs_ns fit_qtrue_rmse",
  "qdesn_exal_rhs_ns forecast_qtrue_mae_H1000",
  "qdesn_exal_rhs_ns forecast_check_loss_H1000"
)
winner_key <- paste(winners$model_variant, winners$metric)
if (!setequal(winner_key, expected_winner_key) || anyDuplicated(winner_key) ||
    !all(winners$improves_authority) ||
    !all(winners$complete_five_chain_design) ||
    any(winners$estimator_id != estimator_id) ||
    any(!(winners$candidate_value < winners$current_value))) {
  stop("The five metric winners differ from the reviewed closeout.",
       call. = FALSE)
}

authority <- article[
  article$inference == "mcmc" & article$family == "normal" &
    abs(article$tau - 0.25) <= 1e-12 &
    article$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  c("model_variant", metric_names), drop = FALSE
]
authority <- authority[match(c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
                             authority$model_variant), , drop = FALSE]
if (nrow(authority) != 2L || anyNA(authority$model_variant)) {
  stop("Could not locate the two frozen article authority rows.", call. = FALSE)
}

review_rows <- do.call(rbind, lapply(seq_len(nrow(metrics)), function(i) {
  row <- metrics[i, , drop = FALSE]
  model_variant <- if (row$likelihood_family == "al") {
    "qdesn_al_rhs_ns"
  } else "qdesn_exal_rhs_ns"
  current <- authority[authority$model_variant == model_variant, , drop = FALSE]
  ratios <- as.numeric(row[metric_names]) / as.numeric(current[metric_names])
  data.frame(
    model_variant = model_variant,
    source_base_design_id = row$source_base_design_id,
    likelihood_family = row$likelihood_family,
    D = row$D, n_each = row$n_each, m = row$m,
    alpha = row$alpha, rho = row$rho, pi_w = row$pi_w, pi_in = row$pi_in,
    rhs_tau0 = row$rhs_tau0, chain_count = row$chain_count,
    sampler_replicates = row$sampler_replicates,
    fit_qtrue_rmse = row$fit_qtrue_rmse,
    forecast_qtrue_mae_H1000 = row$forecast_qtrue_mae_H1000,
    forecast_check_loss_H1000 = row$forecast_check_loss_H1000,
    fit_ratio_to_article_v3 = ratios[[1L]],
    forecast_mae_ratio_to_article_v3 = ratios[[2L]],
    forecast_check_ratio_to_article_v3 = ratios[[3L]],
    metrics_improved = sum(ratios < 1 - 1e-12),
    improves_all_three = all(ratios < 1 - 1e-12),
    worst_ratio_to_article_v3 = max(ratios),
    estimator_id = estimator_id,
    posterior_pooling_claim = FALSE,
    stringsAsFactors = FALSE
  )
}))
coherent_best <- do.call(rbind, lapply(
  split(review_rows, review_rows$model_variant),
  function(part) part[order(part$worst_ratio_to_article_v3,
                            -part$metrics_improved,
                            part$source_base_design_id)[1L], , drop = FALSE]
))
rownames(coherent_best) <- NULL

metric_review <- winners
metric_review$relative_improvement <-
  (metric_review$current_value - metric_review$candidate_value) /
  metric_review$current_value
metric_review$evidence_role <- "five_chain_robustness_sensitivity"
metric_review$article_drop_in_eligible <- FALSE
metric_review$article_drop_in_reason <- paste(
  "Estimator differs from the single-chain metric envelope;",
  "requires explicit methods disclosure and a matched-estimator table policy."
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
evidence_dir <- file.path(output_dir, "frozen_closeout")
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
evidence_sources <- c(unlist(paths), base_interface = base_path)
evidence_destinations <- file.path(evidence_dir, basename(evidence_sources))
if (anyDuplicated(evidence_destinations)) {
  stop("Frozen evidence basenames are not unique.", call. = FALSE)
}
if (!all(file.copy(evidence_sources, evidence_destinations, overwrite = TRUE)) ||
    !identical(unname(tools::sha256sum(evidence_destinations)),
               unname(tools::sha256sum(evidence_sources)))) {
  stop("Could not freeze the exact chain-aggregate evidence.", call. = FALSE)
}
evidence_ledger <- data.frame(
  role = names(evidence_sources),
  source_path = normalizePath(evidence_sources, winslash = "/"),
  source_sha256 = unname(tools::sha256sum(evidence_sources)),
  frozen_path = normalizePath(evidence_destinations, winslash = "/"),
  frozen_sha256 = unname(tools::sha256sum(evidence_destinations)),
  stringsAsFactors = FALSE
)

review_path <- write_csv(review_rows, file.path(output_dir, "design_review.csv"))
coherent_path <- write_csv(coherent_best,
                           file.path(output_dir, "coherent_design_recommendations.csv"))
metric_path <- write_csv(metric_review,
                         file.path(output_dir, "metric_improvement_review.csv"))
ledger_path <- write_csv(evidence_ledger,
                         file.path(output_dir, "frozen_evidence_ledger.csv"))

decision <- list(
  generated_from_closeout_utc = as.character(gate$generated_at),
  sensitivity_id = sensitivity_id,
  decision = "ROBUST_SENSITIVITY_CONFIRMED_ARTICLE_TABLE_UNCHANGED",
  validation_evidence_complete = TRUE,
  complete_five_chain_designs = nrow(metrics),
  metric_improvements = nrow(winners),
  estimator_id = estimator_id,
  posterior_pooling_claim = FALSE,
  article_v3_authority_sha256 = expected_hashes[["base_interface"]],
  article_table_replacement_recommended = FALSE,
  article_update_performed = FALSE,
  reason = paste(
    "The five-chain median-of-point-path estimator is a valid robustness",
    "sensitivity but is not the same estimator as the current single-chain",
    "metric envelope. Silent metric replacement would mix estimators."
  ),
  allowed_next_use = paste(
    "Use this bundle as supplemental robustness evidence, or first adopt and",
    "disclose one matched estimator policy for every displayed MCMC model."
  ),
  run_id = run_id,
  run_tag = run_tag,
  source_branch = source_branch,
  source_commit = source_commit,
  package_version = "1.0.0",
  source_registry_hash_value = registry_hash
)
decision_path <- write_json(decision, file.path(output_dir, "review_decision.json"))

output_files <- c(
  design_review = review_path,
  coherent_design_recommendations = coherent_path,
  metric_improvement_review = metric_path,
  frozen_evidence_ledger = ledger_path,
  review_decision = decision_path
)
output_manifest <- data.frame(
  role = names(output_files),
  path = unname(output_files),
  sha256 = vapply(output_files, sha256, character(1L)),
  stringsAsFactors = FALSE
)
output_manifest_path <- write_csv(
  output_manifest, file.path(output_dir, "output_file_manifest.csv")
)

manifest_path <- write_json(list(
  sensitivity_id = sensitivity_id,
  status = "AUTHORITATIVE_ROBUSTNESS_SENSITIVITY",
  generated_from_closeout_utc = as.character(gate$generated_at),
  run_id = run_id,
  run_tag = run_tag,
  source_branch = source_branch,
  source_commit = source_commit,
  package_version = "1.0.0",
  source_registry_hash_name = "source_registry_hash_value",
  source_registry_hash_value = registry_hash,
  estimator_id = estimator_id,
  posterior_pooling_claim = FALSE,
  complete_five_chain_designs = nrow(metrics),
  metric_improvements = nrow(winners),
  article_update_automatic = FALSE,
  article_update_performed = FALSE,
  output_file_manifest_path = output_manifest_path,
  output_file_manifest_sha256 = sha256(output_manifest_path),
  frozen_evidence_ledger_path = ledger_path,
  frozen_evidence_ledger_sha256 = sha256(ledger_path)
), file.path(output_dir, paste0(sensitivity_id, "_manifest.json")))

readme_path <- file.path(output_dir, "README.md")
writeLines(c(
  "# Five-Chain Q-DESN Robustness Sensitivity",
  "",
  "This immutable bundle closes the Normal, p=0.25 five-chain confirmation",
  "for independent single-quantile Q-DESN AL-RHS and exAL-RHS models.",
  "",
  "The estimator is the coordinatewise median of five chain-specific posterior",
  "point paths. Metrics are recomputed from that path. It is not pooled",
  "posterior draws and must never be described as such.",
  "",
  "The campaign completed 12/12 fresh fits and 11/11 five-chain designs with",
  "zero unexpected model binaries. Five robust metric values are below the",
  "frozen article-v3 single-chain metric envelope. The article table remains",
  "unchanged because direct replacement would silently mix estimators.",
  "",
  sprintf("Run tag: `%s`", run_tag),
  sprintf("Source branch: `%s`", source_branch),
  sprintf("Source commit: `%s`", source_commit),
  sprintf("Registry hash: `%s`", registry_hash),
  sprintf("Decision: `%s`", decision$decision),
  sprintf("Manifest: `%s`", basename(manifest_path)),
  "",
  "A future article update must either present this as a disclosed robustness",
  "sensitivity or recompute every displayed MCMC model under one matched",
  "multi-chain estimator policy."
), readme_path, useBytes = TRUE)

cat(sprintf("SENSITIVITY_ID=%s\n", sensitivity_id))
cat(sprintf("FIVE_CHAIN_DESIGNS=%d\n", nrow(metrics)))
cat(sprintf("METRIC_IMPROVEMENTS=%d\n", nrow(winners)))
cat(sprintf("DECISION=%s\n", decision$decision))
cat(sprintf("OUTPUT_DIR=%s\n", output_dir))
cat(sprintf("MANIFEST=%s\n", manifest_path))
