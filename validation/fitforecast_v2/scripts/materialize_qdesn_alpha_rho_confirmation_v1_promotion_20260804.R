#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/",
  mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)
source(file.path(
  repo_root,
  "validation",
  "fitforecast_v2",
  "R",
  "qdesn_alpha_rho_confirmation_v1_promotion.R"
), local = TRUE)

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
read_csv <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing input: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
as_bool <- function(value) {
  if (is.logical(value)) return(value)
  toupper(trimws(as.character(value))) %in% c("TRUE", "T", "1", "YES")
}
num <- function(value) suppressWarnings(as.numeric(value))
git_value <- function(arguments) {
  value <- system2("git", c("-C", repo_root, arguments), stdout = TRUE)
  if (!length(value)) NA_character_ else value[[1L]]
}
relative_to_repo <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  prefix <- paste0(repo_root, "/")
  if (!startsWith(path, prefix)) {
    stop(sprintf("Tracked authority path is outside the repository: %s", path), call. = FALSE)
  }
  substring(path, nchar(prefix) + 1L)
}
verify_path_hashes <- function(paths, hashes, label) {
  if (!length(paths) || length(paths) != length(hashes) || any(!file.exists(paths))) {
    stop(sprintf("%s contains missing or malformed paths.", label), call. = FALSE)
  }
  observed <- unname(tools::sha256sum(paths))
  if (!identical(observed, unname(as.character(hashes)))) {
    stop(sprintf("%s hash verification failed.", label), call. = FALSE)
  }
  invisible(TRUE)
}
cell_key <- function(model_variant, family, tau, fit_size) {
  paste(model_variant, family, sprintf("%.8f", num(tau)), as.integer(fit_size), sep = "\r")
}
parse_env <- function(path) {
  lines <- readLines(path, warn = FALSE)
  keys <- sub("=.*", "", lines)
  values <- sub("^[^=]*=", "", lines)
  stats::setNames(values, keys)
}

promotion_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260804"
previous_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
review_id <- "qdesn_500obs_mcmc_alpha_rho_confirmation_v1_manual_review_20260804"
freeze_id <- "qdesn_500obs_mcmc_alpha_rho_confirmation_v1_evidence_freeze_20260804"
expected_full_tag <- "qdesn-arfc1-full-20260803_152952__git-3ed1d0c"
expected_run_commit <- "3ed1d0cdba4dd5e858d8abe667b49aef731fc9aa"
expected_registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected_profile <- "arfc1_parent_exal_gausmix_t0p25_r01"
expected_decision <- "PROMOTE_COHERENT_STATUS_AGNOSTIC_METRIC_ENVELOPE"

default_closeout <- file.path(
  "/data/jaguir26/local/src/exdqlm__wt__qdesn_alpha_rho_cellwise_v2_1p0p0",
  "reports", "shared_fitforecast_v2_orchestration",
  "qdesn_alpha_rho_confirmation_v1_20260803_153000", "closeout"
)
closeout_root <- normalizePath(
  get_arg("--run-closeout", default_closeout),
  winslash = "/",
  mustWork = TRUE
)
orchestration_root <- dirname(closeout_root)
run_tags_path <- file.path(orchestration_root, "run_tags.env")
previous_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", previous_id
)
promotion_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", promotion_id
)
freeze_root <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", freeze_id
)

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Promotion requires the exdqlm 1.0.0 validation repository.", call. = FALSE)
}
git_branch <- git_value(c("branch", "--show-current"))
git_commit <- git_value(c("rev-parse", "HEAD"))
allowed_branches <- c(
  "validation/shared-fitforecast-v2-1.0.0",
  "validation/qdesn-alpha-rho-cellwise-v2-1.0.0"
)
if (!git_branch %in% allowed_branches) {
  stop(sprintf("Unexpected validation branch: %s", git_branch), call. = FALSE)
}
tracked_dirty <- length(system2(
  "git", c("-C", repo_root, "diff", "--name-only"), stdout = TRUE
)) > 0L || length(system2(
  "git", c("-C", repo_root, "diff", "--cached", "--name-only"), stdout = TRUE
)) > 0L
untracked_before <- system2(
  "git", c("-C", repo_root, "ls-files", "--others", "--exclude-standard"),
  stdout = TRUE
)
if (tracked_dirty || length(untracked_before)) {
  stop("Promotion materialization requires a clean committed validation worktree.", call. = FALSE)
}

previous_all_path <- file.path(previous_root, paste0(previous_id, "_all_candidates.csv"))
previous_envelope_path <- file.path(previous_root, paste0(previous_id, "_article_envelope.csv"))
previous_manifest_path <- file.path(previous_root, paste0(previous_id, "_manifest.json"))
previous_confirmation_path <- file.path(previous_root, paste0(previous_id, "_coherent_confirmation.csv"))
previous_all <- read_csv(previous_all_path)
previous_envelope <- read_csv(previous_envelope_path)
previous_manifest <- jsonlite::read_json(previous_manifest_path, simplifyVector = TRUE)
if (nrow(previous_all) != 129L || nrow(previous_envelope) != 36L ||
    previous_manifest$promotion_id != previous_id ||
    previous_manifest$source_registry_hash_value != expected_registry_hash) {
  stop("The previous 129-candidate/36-cell authority is not intact.", call. = FALSE)
}
verify_path_hashes(
  previous_manifest$files$path,
  previous_manifest$files$sha256,
  "Previous promotion output manifest"
)

closeout_manifest_path <- file.path(closeout_root, "closeout_manifest.json")
gate_path <- file.path(closeout_root, "confirmation_gate.json")
runtime_file_manifest_path <- file.path(closeout_root, "file_manifest.csv")
metrics_path <- file.path(closeout_root, "confirmation_metrics.csv")
execution_audit_path <- file.path(closeout_root, "execution_contract_audit.csv")
paired_metrics_path <- file.path(closeout_root, "paired_metrics.csv")
cell_summary_path <- file.path(closeout_root, "cell_confirmation_summary.csv")
storage_audit_path <- file.path(closeout_root, "storage_audit.csv")
for (path in c(
  closeout_manifest_path, gate_path, runtime_file_manifest_path, metrics_path,
  execution_audit_path, paired_metrics_path, cell_summary_path,
  storage_audit_path, run_tags_path
)) {
  if (!file.exists(path)) stop(sprintf("Missing closeout evidence: %s", path), call. = FALSE)
}
runtime_file_manifest <- read_csv(runtime_file_manifest_path)
verify_path_hashes(
  runtime_file_manifest$path,
  runtime_file_manifest$sha256,
  "Runtime closeout file manifest"
)
gate <- jsonlite::read_json(gate_path, simplifyVector = TRUE)
closeout_manifest <- jsonlite::read_json(closeout_manifest_path, simplifyVector = TRUE)
run_tags <- parse_env(run_tags_path)
if (gate$run_tag != expected_full_tag ||
    closeout_manifest$run_tag != expected_full_tag ||
    closeout_manifest$git_commit != expected_run_commit ||
    closeout_manifest$package_version != "1.0.0" ||
    closeout_manifest$source_registry_hash_value != expected_registry_hash ||
    as.integer(gate$expected_specs) != 8L ||
    as.integer(gate$observed_specs) != 8L ||
    as.integer(gate$complete_metric_specs) != 8L ||
    as.integer(gate$missing_specs) != 0L ||
    as.integer(gate$unexpected_specs) != 0L ||
    as.integer(gate$seed_contract_passes) != 8L ||
    as.integer(gate$source_registry_hash_passes) != 8L ||
    as.integer(gate$unexpected_binary_payloads) != 0L ||
    isTRUE(gate$article_updated) ||
    run_tags[["FULL_TAG"]] != expected_full_tag ||
    run_tags[["GIT_COMMIT"]] != expected_run_commit) {
  stop("Runtime closeout does not satisfy the frozen eight-root contract.", call. = FALSE)
}
if (nrow(read_csv(storage_audit_path)) != 0L) {
  stop("Runtime closeout contains unexpected binary payloads.", call. = FALSE)
}

metrics <- read_csv(metrics_path)
review <- qdesn_arfc1_promotion_review(metrics, previous_envelope)
approved <- qdesn_arfc1_approved_promotion(review)
if (approved$observed_source_registry_hash[[1L]] != expected_registry_hash ||
    approved$spec_id[[1L]] != "qdesn__gausmix__0p25__tt500__rhs_ns__mcmc__exal__8cda647284e157" ||
    approved$signoff_grade[[1L]] != "FAIL" ||
    approved$stop_reason[[1L]] != "high_autocorrelation; half_chain_drift") {
  stop("Approved root provenance or diagnostic disposition changed.", call. = FALSE)
}

review_columns <- c(
  "target_cell_id", "family", "tau", "comparison_role",
  "reservoir_replicate", "screening_profile_id", "spec_id",
  "source_screening_profile_id", "D", "n_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "rhs_tau0", "observed_desn_seed",
  "observed_mcmc_seed", "observed_mcmc_rng_seed",
  "observed_vb_warm_start_seed", "observed_synthesis_seed",
  "observed_source_registry_hash", "status", "signoff_grade", "stop_reason",
  "metric_complete", "seed_contract_match", "source_registry_hash_match",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000", "current_fit_qtrue_rmse",
  "current_forecast_qtrue_mae_H1000",
  "current_forecast_check_loss_H1000", "fit_ratio_to_current",
  "forecast_mae_ratio_to_current", "forecast_check_ratio_to_current",
  "companion_max_ratio", "all_metrics_improve_current",
  "promotion_approved", "manual_disposition", "manual_reason", "runtime_sec",
  "fit_summary_path", "fit_summary_sha256", "forecast_horizon_path",
  "forecast_horizon_sha256", "fit_request_path", "fit_request_sha256"
)
missing_review <- setdiff(review_columns, names(review))
if (length(missing_review)) {
  stop(sprintf("Review snapshot is missing: %s", paste(missing_review, collapse = ", ")), call. = FALSE)
}
review_snapshot <- review[, review_columns, drop = FALSE]
review_snapshot <- review_snapshot[order(
  review_snapshot$target_cell_id,
  review_snapshot$reservoir_replicate,
  review_snapshot$comparison_role
), , drop = FALSE]

standard_columns <- c(
  "model_variant", "family", "tau", "fit_size", "candidate_id", "spec_id",
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
  "forecast_check_loss_H1000", "status", "signoff_grade",
  "comparison_eligible", "run_tag", "source_key", "source_path",
  "source_table_sha256", "source_registry_hash_value"
)
if (!all(standard_columns %in% names(previous_all))) {
  stop("Previous candidate ledger schema changed.", call. = FALSE)
}
approved_candidate_id <- paste0(expected_profile, "__full_3ed1d0c")
approved_candidate <- data.frame(
  model_variant = "qdesn_exal_rhs_ns",
  family = as.character(approved$family[[1L]]),
  tau = as.numeric(approved$tau[[1L]]),
  fit_size = 500L,
  candidate_id = approved_candidate_id,
  spec_id = as.character(approved$spec_id[[1L]]),
  fit_qtrue_rmse = as.numeric(approved$fit_qtrue_rmse[[1L]]),
  forecast_qtrue_mae_H1000 = as.numeric(approved$forecast_qtrue_mae_H1000[[1L]]),
  forecast_check_loss_H1000 = as.numeric(approved$forecast_check_loss_H1000[[1L]]),
  status = "SUCCESS",
  signoff_grade = as.character(approved$signoff_grade[[1L]]),
  comparison_eligible = "TRUE",
  run_tag = expected_full_tag,
  source_key = review_id,
  source_path = normalizePath(
    approved$fit_summary_path[[1L]], winslash = "/", mustWork = TRUE
  ),
  source_table_sha256 = as.character(approved$fit_summary_sha256[[1L]]),
  source_registry_hash_value = expected_registry_hash,
  stringsAsFactors = FALSE
)
if (sha256(approved_candidate$source_path[[1L]]) !=
    approved_candidate$source_table_sha256[[1L]]) {
  stop("Approved fit-summary hash no longer verifies.", call. = FALSE)
}
all_candidates <- rbind(
  previous_all[, standard_columns, drop = FALSE],
  approved_candidate[, standard_columns, drop = FALSE]
)
if (nrow(all_candidates) != 130L ||
    sum(all_candidates$candidate_id == approved_candidate_id) != 1L) {
  stop("Refreshed candidate ledger must add exactly one approved root.", call. = FALSE)
}

metric_names <- c(
  fit_qtrue_rmse = "fit",
  forecast_qtrue_mae_H1000 = "forecast_mae",
  forecast_check_loss_H1000 = "forecast_check"
)
keys <- cell_key(
  all_candidates$model_variant,
  all_candidates$family,
  all_candidates$tau,
  all_candidates$fit_size
)
winner_rows <- list()
for (key in sort(unique(keys))) {
  block <- all_candidates[keys == key, , drop = FALSE]
  for (metric in names(metric_names)) {
    values <- num(block[[metric]])
    if (!any(is.finite(values))) stop("A metric-envelope cell has no finite evidence.", call. = FALSE)
    winner <- block[order(values, block$run_tag, block$candidate_id, na.last = TRUE)[[1L]], , drop = FALSE]
    winner$metric_name <- metric
    winner$metric_role <- metric_names[[metric]]
    winner$metric_value <- num(winner[[metric]])
    winner_rows[[length(winner_rows) + 1L]] <- winner
  }
}
metric_winners <- do.call(rbind, winner_rows)
winner_keys <- cell_key(
  metric_winners$model_variant,
  metric_winners$family,
  metric_winners$tau,
  metric_winners$fit_size
)
envelope_rows <- lapply(sort(unique(winner_keys)), function(key) {
  block <- metric_winners[winner_keys == key, , drop = FALSE]
  pick <- function(metric) block[block$metric_name == metric, , drop = FALSE][1L, , drop = FALSE]
  fit <- pick("fit_qtrue_rmse")
  mae <- pick("forecast_qtrue_mae_H1000")
  check <- pick("forecast_check_loss_H1000")
  grades <- c(fit$signoff_grade, mae$signoff_grade, check$signoff_grade)
  grade <- if ("FAIL" %in% grades) "FAIL" else if ("WARN" %in% grades) "WARN" else "PASS"
  mixed <- length(unique(c(fit$candidate_id, mae$candidate_id, check$candidate_id))) > 1L
  data.frame(
    model_variant = fit$model_variant,
    family = fit$family,
    tau = fit$tau,
    fit_size = fit$fit_size,
    comparison_eligible = "STATUS_AGNOSTIC",
    status = "SUCCESS",
    signoff_grade = grade,
    metric_source_mixed = ifelse(mixed, "TRUE", "FALSE"),
    fit_qtrue_rmse = fit$metric_value,
    forecast_qtrue_mae_H1000 = mae$metric_value,
    forecast_check_loss_H1000 = check$metric_value,
    fit_source_candidate_id = fit$candidate_id,
    fit_source_run_tag = fit$run_tag,
    fit_source_signoff_grade = fit$signoff_grade,
    fit_source_status = fit$status,
    fit_source_path = fit$source_path,
    fit_source_sha256 = fit$source_table_sha256,
    forecast_mae_source_candidate_id = mae$candidate_id,
    forecast_mae_source_run_tag = mae$run_tag,
    forecast_mae_source_signoff_grade = mae$signoff_grade,
    forecast_mae_source_status = mae$status,
    forecast_mae_source_path = mae$source_path,
    forecast_mae_source_sha256 = mae$source_table_sha256,
    forecast_check_source_candidate_id = check$candidate_id,
    forecast_check_source_run_tag = check$run_tag,
    forecast_check_source_signoff_grade = check$signoff_grade,
    forecast_check_source_status = check$status,
    forecast_check_source_path = check$source_path,
    forecast_check_source_sha256 = check$source_table_sha256,
    source_key = "status_agnostic_metricwise_calibrated_envelope",
    source_promotion_id = promotion_id,
    source_table_sha256 = paste(sort(unique(c(
      fit$source_table_sha256,
      mae$source_table_sha256,
      check$source_table_sha256
    ))), collapse = ";"),
    source_registry_hash_value = expected_registry_hash,
    stringsAsFactors = FALSE
  )
})
envelope <- do.call(rbind, envelope_rows)
envelope <- envelope[order(envelope$model_variant, envelope$family, envelope$tau), , drop = FALSE]
if (nrow(envelope) != 36L) stop("Refreshed envelope is not the complete 36-cell grid.", call. = FALSE)

previous_key <- cell_key(
  previous_envelope$model_variant,
  previous_envelope$family,
  previous_envelope$tau,
  previous_envelope$fit_size
)
envelope_key <- cell_key(envelope$model_variant, envelope$family, envelope$tau, envelope$fit_size)
match_previous <- match(envelope_key, previous_key)
if (anyNA(match_previous)) stop("Refreshed envelope differs structurally from its parent.", call. = FALSE)
metric_comparison <- do.call(rbind, lapply(seq_len(nrow(envelope)), function(index) {
  current <- envelope[index, , drop = FALSE]
  previous <- previous_envelope[match_previous[[index]], , drop = FALSE]
  data.frame(
    model_variant = current$model_variant,
    family = current$family,
    tau = current$tau,
    fit_size = current$fit_size,
    metric = names(metric_names),
    previous_value = c(
      previous$fit_qtrue_rmse,
      previous$forecast_qtrue_mae_H1000,
      previous$forecast_check_loss_H1000
    ),
    refreshed_value = c(
      current$fit_qtrue_rmse,
      current$forecast_qtrue_mae_H1000,
      current$forecast_check_loss_H1000
    ),
    stringsAsFactors = FALSE
  )
}))
metric_comparison$ratio_to_previous <-
  num(metric_comparison$refreshed_value) / num(metric_comparison$previous_value)
metric_comparison$changed <- abs(
  num(metric_comparison$refreshed_value) - num(metric_comparison$previous_value)
) > 1e-12
metric_promotions <- metric_comparison[metric_comparison$changed, , drop = FALSE]
if (nrow(metric_promotions) != 3L ||
    any(metric_promotions$model_variant != "qdesn_exal_rhs_ns") ||
    any(metric_promotions$family != "gausmix") ||
    any(abs(num(metric_promotions$tau) - 0.25) > 1e-12) ||
    !setequal(metric_promotions$metric, names(metric_names)) ||
    any(metric_promotions$ratio_to_previous >= 1)) {
  stop("Expected exactly three improving Gaussian-mixture p=0.25 metrics.", call. = FALSE)
}

target_envelope <- envelope[
  envelope$model_variant == "qdesn_exal_rhs_ns" &
    envelope$family == "gausmix" &
    abs(num(envelope$tau) - 0.25) <= 1e-12,
  ,
  drop = FALSE
]
if (nrow(target_envelope) != 1L ||
    any(c(
      target_envelope$fit_source_candidate_id,
      target_envelope$forecast_mae_source_candidate_id,
      target_envelope$forecast_check_source_candidate_id
    ) != approved_candidate_id)) {
  stop("Approved coherent root does not own all three refreshed envelope metrics.", call. = FALSE)
}
coherent_confirmation <- data.frame(
  candidate_id = approved_candidate_id,
  model_variant = "qdesn_exal_rhs_ns",
  family = "gausmix",
  tau = 0.25,
  fit_size = 500L,
  spec_id = approved$spec_id[[1L]],
  run_tag = expected_full_tag,
  screening_profile_id = expected_profile,
  comparison_role = "parent_exact",
  reservoir_replicate = 1L,
  fit_qtrue_rmse = approved$fit_qtrue_rmse[[1L]],
  forecast_qtrue_mae_H1000 = approved$forecast_qtrue_mae_H1000[[1L]],
  forecast_check_loss_H1000 = approved$forecast_check_loss_H1000[[1L]],
  envelope_fit_qtrue_rmse = target_envelope$fit_qtrue_rmse,
  envelope_forecast_qtrue_mae_H1000 = target_envelope$forecast_qtrue_mae_H1000,
  envelope_forecast_check_loss_H1000 = target_envelope$forecast_check_loss_H1000,
  fit_envelope_winner = TRUE,
  forecast_mae_envelope_winner = TRUE,
  forecast_check_envelope_winner = TRUE,
  all_metrics_improve_previous_envelope = TRUE,
  seed_replicated_within_1p10 = FALSE,
  paired_alpha_rho_transfer_pass = FALSE,
  signoff_grade = approved$signoff_grade[[1L]],
  signoff_reason = approved$stop_reason[[1L]],
  decision = expected_decision,
  source_registry_hash_value = expected_registry_hash,
  source_path = approved_candidate$source_path,
  source_sha256 = approved_candidate$source_table_sha256,
  stringsAsFactors = FALSE
)
remaining_handoff <- data.frame(
  target_cell_id = c("exal_gausmix_t0p25", "exal_laplace_t0p05"),
  family = c("gausmix", "laplace"),
  tau = c(0.25, 0.05),
  current_state = c(
    "metric_envelope_improved_but_seed_sensitive_and_high_autocorrelation",
    "no_fit_or_forecast_mae_improvement"
  ),
  next_scientific_target = c(
    "sampler_stability_and_reservoir_seed_robustness",
    "readout_shrinkage_or_architecture_redesign"
  ),
  prohibited_next_step = c(
    "do_not_claim_global_alpha_rho_transfer",
    "do_not_repeat_local_alpha_rho_grid"
  ),
  launch_status = "NOT_LAUNCHED_REQUIRES_NEW_PROTOCOL",
  stringsAsFactors = FALSE
)

dir.create(promotion_root, recursive = TRUE, showWarnings = FALSE)
all_path <- write_csv(all_candidates, file.path(promotion_root, paste0(promotion_id, "_all_candidates.csv")))
winners_path <- write_csv(metric_winners, file.path(promotion_root, paste0(promotion_id, "_metric_winners.csv")))
comparison_path <- write_csv(metric_comparison, file.path(promotion_root, paste0(promotion_id, "_vs_previous_envelope.csv")))
promotions_path <- write_csv(metric_promotions, file.path(promotion_root, paste0(promotion_id, "_metric_promotions.csv")))
envelope_path <- write_csv(envelope, file.path(promotion_root, paste0(promotion_id, "_article_envelope.csv")))
confirmation_path <- write_csv(coherent_confirmation, file.path(promotion_root, paste0(promotion_id, "_coherent_confirmation.csv")))
review_path <- write_csv(review_snapshot, file.path(promotion_root, "reviewed_root_metrics.csv"))
execution_snapshot_path <- write_csv(read_csv(execution_audit_path), file.path(promotion_root, "execution_contract_audit.csv"))
paired_snapshot_path <- write_csv(read_csv(paired_metrics_path), file.path(promotion_root, "paired_metrics.csv"))
cell_snapshot_path <- write_csv(read_csv(cell_summary_path), file.path(promotion_root, "cell_confirmation_summary.csv"))
handoff_path <- write_csv(remaining_handoff, file.path(promotion_root, "remaining_gap_handoff.csv"))

source_paths <- c(
  previous_candidates = previous_all_path,
  previous_envelope = previous_envelope_path,
  previous_manifest = previous_manifest_path,
  previous_confirmation = previous_confirmation_path,
  runtime_closeout_manifest = closeout_manifest_path,
  runtime_gate = gate_path,
  runtime_file_manifest = runtime_file_manifest_path,
  runtime_metrics = metrics_path,
  runtime_execution_audit = execution_audit_path,
  runtime_paired_metrics = paired_metrics_path,
  runtime_cell_summary = cell_summary_path,
  runtime_storage_audit = storage_audit_path,
  approved_fit_summary = approved$fit_summary_path[[1L]],
  approved_forecast_horizon = approved$forecast_horizon_path[[1L]],
  approved_fit_request = approved$fit_request_path[[1L]]
)
source_manifest <- data.frame(
  source_id = names(source_paths),
  path = vapply(source_paths, normalizePath, character(1L), winslash = "/", mustWork = TRUE),
  sha256 = vapply(source_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
if (any(grepl("/home/jaguir26/local/src", source_manifest$path, fixed = TRUE))) {
  stop("Source manifest contains a stale /home path.", call. = FALSE)
}
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

readme_path <- file.path(promotion_root, "README.md")
readme <- c(
  "# Independent Q-DESN MCMC Alpha/Rho Confirmation Authority, 2026-08-04",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Parent promotion: `%s`", previous_id),
  sprintf("- Runtime run tag: `%s`", expected_full_tag),
  sprintf("- Runtime implementation commit: `%s`", expected_run_commit),
  sprintf("- Materialization branch: `%s`", git_branch),
  sprintf("- Materialization commit: `%s`", git_commit),
  sprintf("- Source registry SHA-256: `%s`", expected_registry_hash),
  "- Completed full-budget roots: `8/8`",
  "- Execution/source/seed contract passes: `8/8`",
  "- Unexpected binary payloads: `0`",
  "- Metric-envelope promotions: `3`",
  "",
  "## Decision",
  "",
  "The broad alpha/rho candidate does not transfer robustly across the paired",
  "reservoir seeds. The exact-parent Gaussian-mixture, p=0.25, replicate-1",
  "control nevertheless improves fit RMSE, forecast MAE, and forecast check",
  "loss simultaneously against the frozen article envelope. Under the declared",
  "status-agnostic metric-envelope policy, those three values are promoted from",
  "one coherent completed root.",
  "",
  "The promoted root retains FAIL signoff for high autocorrelation and half-chain",
  "drift. This permits a numerical envelope update but not a convergence claim,",
  "a global alpha/rho recommendation, or a prose claim of seed-robust superiority.",
  "No Laplace metric is promoted because its small check-loss gains accompany",
  "materially worse fit and forecast MAE.",
  "",
  "## Remaining Work",
  "",
  "Further Gaussian-mixture work should target sampler and reservoir-seed",
  "stability. Further Laplace work requires a readout, shrinkage, or architecture",
  "change rather than another local alpha/rho grid. Neither follow-up is launched",
  "by this promotion."
)
writeLines(readme, readme_path, useBytes = TRUE)

output_paths <- c(
  all_path, winners_path, comparison_path, promotions_path, envelope_path,
  confirmation_path, review_path, execution_snapshot_path,
  paired_snapshot_path, cell_snapshot_path, handoff_path, source_manifest_path,
  normalizePath(readme_path, winslash = "/", mustWork = TRUE)
)
file_manifest <- data.frame(
  path = output_paths,
  sha256 = vapply(output_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

promotion_manifest <- list(
  promotion_id = promotion_id,
  review_id = review_id,
  generated_at = as.character(Sys.time()),
  validation_branch = git_branch,
  validation_commit_at_materialization = git_commit,
  tracked_source_dirty_before_materialization = tracked_dirty,
  untracked_before_materialization = unname(untracked_before),
  package_version = "1.0.0",
  source_registry_hash_name = "sha256",
  source_registry_hash_value = expected_registry_hash,
  parent_promotion_id = previous_id,
  confirmation_run_tag = expected_full_tag,
  confirmation_spec_id = approved$spec_id[[1L]],
  confirmation_profile_id = expected_profile,
  confirmation_decision = expected_decision,
  confirmation_signoff_grade = approved$signoff_grade[[1L]],
  confirmation_signoff_reason = approved$stop_reason[[1L]],
  runtime_roots_reviewed = nrow(review_snapshot),
  runtime_roots_promoted = sum(review_snapshot$promotion_approved),
  coherent_confirmation_rows = nrow(coherent_confirmation),
  n_candidates = nrow(all_candidates),
  n_envelope_rows = nrow(envelope),
  n_metric_promotions = nrow(metric_promotions),
  displayed_envelope_changed = TRUE,
  article_integration_status = "ready_for_surgical_article_promotion",
  selection_unit = "model_variant x family x tau x metric",
  selection_rule = paste(
    "minimum observed finite metric among reviewed promotion-eligible evidence;",
    "diagnostic status is retained but not used as a metric-exclusion rule"
  ),
  interpretation = paste(
    "status-agnostic metric-wise envelope; one coherent root supplies the three",
    "new values without implying seed-robust specification transfer"
  ),
  source_manifest = source_manifest,
  files = lapply(seq_len(nrow(file_manifest)), function(index) {
    as.list(file_manifest[index, , drop = FALSE])
  })
)
promotion_manifest_path <- file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
jsonlite::write_json(
  promotion_manifest,
  promotion_manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)
promotion_manifest_path <- normalizePath(promotion_manifest_path, winslash = "/", mustWork = TRUE)

dir.create(freeze_root, recursive = TRUE, showWarnings = FALSE)
run_disposition <- data.frame(
  run_tag = c(run_tags[["PREP_TAG"]], run_tags[["SMOKE_TAG"]], expected_full_tag),
  run_role = c("prepare", "smoke", "full_budget_confirmation"),
  execution_status = c("COMPLETED", "COMPLETED", "COMPLETED_8_OF_8"),
  scientific_disposition = c(
    "NON_SCIENTIFIC_WORKFLOW_ONLY",
    "NON_SCIENTIFIC_WORKFLOW_ONLY",
    "CONSUMABLE_STATUS_AGNOSTIC_METRIC_EVIDENCE"
  ),
  article_use = c("NO", "NO", "GAUSMIX_P025_EXAL_RHS_THREE_METRICS_ONLY"),
  stringsAsFactors = FALSE
)
origin_disposition <- data.frame(
  forecast_origin_source_index = 9000L,
  train_start_source_index = 8501L,
  train_end_source_index = 9000L,
  forecast_start_source_index = 9001L,
  forecast_end_source_index = 10000L,
  max_lead = 30L,
  origin_stride = 30L,
  refit_per_origin = FALSE,
  disposition = "AUTHORITATIVE_MATCHED_PROTOCOL",
  stringsAsFactors = FALSE
)
cell_disposition <- data.frame(
  target_cell_id = c("exal_gausmix_t0p25", "exal_laplace_t0p05"),
  paired_alpha_rho_transfer = c("FAIL", "FAIL"),
  metric_envelope_disposition = c(
    "PROMOTE_PARENT_R01_FIT_MAE_CHECK",
    "NO_PROMOTION"
  ),
  diagnostic_disposition = c(
    "FAIL_RETAIN_HIGH_AUTOCORRELATION_AND_HALF_CHAIN_DRIFT",
    "WARN_RETAIN_CHAIN_MARGINAL_BUT_USABLE"
  ),
  next_action = remaining_handoff$next_scientific_target,
  stringsAsFactors = FALSE
)
run_disposition_path <- write_csv(run_disposition, file.path(freeze_root, "run_disposition.csv"))
origin_disposition_path <- write_csv(origin_disposition, file.path(freeze_root, "origin_disposition.csv"))
cell_disposition_path <- write_csv(cell_disposition, file.path(freeze_root, "cell_disposition.csv"))

ledger_inputs <- c(
  article_numeric_envelope = envelope_path,
  article_numeric_manifest = promotion_manifest_path,
  article_coherent_confirmation = confirmation_path,
  manual_reviewed_root_metrics = review_path,
  manual_metric_promotions = promotions_path,
  manual_execution_contract_audit = execution_snapshot_path,
  manual_paired_metrics = paired_snapshot_path,
  manual_remaining_gap_handoff = handoff_path
)
frozen_ledger <- data.frame(
  role = names(ledger_inputs),
  path_relative = vapply(ledger_inputs, relative_to_repo, character(1L)),
  sha256 = vapply(ledger_inputs, sha256, character(1L)),
  consume_policy = c(
    "ARTICLE_NUMERIC_AUTHORITY",
    "VERIFY_BEFORE_ARTICLE_BUILD",
    "ARTICLE_PROVENANCE_ONLY",
    "REPRODUCIBILITY_EVIDENCE",
    "REPRODUCIBILITY_EVIDENCE",
    "REPRODUCIBILITY_EVIDENCE",
    "REPRODUCIBILITY_EVIDENCE",
    "NEXT_PROTOCOL_INPUT_ONLY"
  ),
  stringsAsFactors = FALSE
)
ledger_path <- write_csv(frozen_ledger, file.path(freeze_root, "frozen_evidence_ledger.csv"))

freeze_readme_path <- file.path(freeze_root, "README.md")
freeze_readme <- c(
  "# Frozen Independent Q-DESN MCMC Evidence, 2026-08-04",
  "",
  sprintf("- Freeze id: `%s`", freeze_id),
  sprintf("- Numerical authority: `%s`", promotion_id),
  sprintf("- Consumable run tag: `%s`", expected_full_tag),
  sprintf("- Source registry SHA-256: `%s`", expected_registry_hash),
  "- Numerical changes: `3` metrics in exAL-RHS, Gaussian mixture, p=0.25",
  "- Other article cells: unchanged",
  "- Article prose claim: unchanged",
  "",
  "This freeze supersedes the 2026-07-30 no-change numerical freeze only for",
  "the three explicitly listed Gaussian-mixture metrics. It preserves all",
  "diagnostic limitations and rejects a global alpha/rho-transfer conclusion."
)
writeLines(freeze_readme, freeze_readme_path, useBytes = TRUE)
freeze_readme_path <- normalizePath(freeze_readme_path, winslash = "/", mustWork = TRUE)

freeze_manifest <- list(
  freeze_id = freeze_id,
  freeze_date = "2026-08-04",
  scope = "independent_qdesn_exqdesn_mcmc_validation_only",
  git_branch = git_branch,
  frozen_evidence_git_sha = git_commit,
  package_name = "exdqlm",
  package_version = "1.0.0",
  closeout_id = review_id,
  authority_contract_version = "1.1.0",
  authoritative_numeric_promotion_id = promotion_id,
  authoritative_numeric_row_count = nrow(envelope),
  authoritative_candidate_row_count = nrow(all_candidates),
  authoritative_displayed_metric_count = 108L,
  authoritative_numeric_article_envelope = list(
    path_relative = relative_to_repo(envelope_path),
    sha256 = sha256(envelope_path)
  ),
  authoritative_numeric_manifest = list(
    path_relative = relative_to_repo(promotion_manifest_path),
    sha256 = sha256(promotion_manifest_path)
  ),
  authoritative_coherent_confirmation = list(
    path_relative = relative_to_repo(confirmation_path),
    sha256 = sha256(confirmation_path)
  ),
  source_registry_hash_name = "source_registry_sha256",
  source_registry_hash_value = expected_registry_hash,
  scientific_decision = expected_decision,
  coherent_promotion_cells = 1L,
  article_refresh_metric_rows = 3L,
  consumable_scientific_run_tags = expected_full_tag,
  permanently_rejected_run_tags =
    "qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__git-6582f87",
  non_scientific_workflow_run_tags = c(run_tags[["PREP_TAG"]], run_tags[["SMOKE_TAG"]]),
  exposed_confirmation_origins = 9000L,
  origin_9000_untouched_confirmation_eligible = TRUE,
  article_update_policy = "PROMOTE_GAUSMIX_P025_EXAL_RHS_THREE_METRICS_ONLY",
  article_numeric_state = "UPDATED_FROM_20260727_AUTHORITY_BY_3_METRICS",
  future_use_policy = paste(
    "ALPHA_RHO_CANDIDATE_TRANSFER_REJECTED; PARENT_REPLICATE_METRICS_ACCEPTED;",
    "NEXT_SCREEN_REQUIRES_NEW_PROTOCOL"
  ),
  bundle_hashes = list(
    readme_sha256 = sha256(freeze_readme_path),
    run_disposition_sha256 = sha256(run_disposition_path),
    origin_disposition_sha256 = sha256(origin_disposition_path),
    cell_disposition_sha256 = sha256(cell_disposition_path),
    frozen_evidence_ledger_sha256 = sha256(ledger_path)
  )
)
freeze_manifest_path <- file.path(freeze_root, "evidence_freeze_manifest.json")
jsonlite::write_json(
  freeze_manifest,
  freeze_manifest_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null",
  digits = NA
)

cat(sprintf("promotion_id: %s\n", promotion_id))
cat(sprintf("reviewed_roots: %d\n", nrow(review_snapshot)))
cat(sprintf("promoted_roots: %d\n", sum(review_snapshot$promotion_approved)))
cat(sprintf("candidate_rows: %d\n", nrow(all_candidates)))
cat(sprintf("envelope_rows: %d\n", nrow(envelope)))
cat(sprintf("metric_promotions: %d\n", nrow(metric_promotions)))
cat(sprintf("freeze_id: %s\n", freeze_id))
cat(sprintf("article_decision: %s\n", expected_decision))

