#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

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
read_csv <- function(path) utils::read.csv(path, check.names = FALSE,
                                            stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE,
                       null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
worst_grade <- function(x) {
  x <- toupper(x[!is.na(x) & nzchar(x)])
  if ("FAIL" %in% x) return("FAIL")
  if ("WARN" %in% x) return("WARN")
  if ("PASS" %in% x) return("PASS")
  "UNKNOWN"
}

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v2_20260807"
base_id <- "qdesn_dqlm_500obs_trainonly_article_v1_20260805"
base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", base_id)
base_path <- file.path(base_dir, paste0(base_id, "_interface.csv"))
closeout_dir <- normalizePath(get_arg(
  "--confirmation-closeout",
  "/data/jaguir26/local/src/exdqlm__wt__qdesn_mcmc_dynamic_alpha_confirm_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/qdesn_mcmc_dynamic_alpha_confirm_v1_20260807_033752/closeout"
), winslash = "/", mustWork = TRUE)
output_dir <- normalizePath(get_arg(
  "--output-dir",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
), winslash = "/", mustWork = FALSE)

expected <- list(
  base = "dff814fab1e920c10760645ac9e8d37dfa7f33ae2afba34ee8ed2a5509f4952a",
  gate = "ebe8d4ef54b724e871db12822e82516f148279096760a6e6375e8c65b58943d8",
  winners = "03b18c56430a5e26a56ec1a989e0332414a8198bd7dbf17309705f7a9c15348a",
  preview = "ec219c08cfccbb2d1c74cecd17cb3cc7dec1f59b2678f370302efea08af15f83",
  metrics = "b2d374f72a7b54a58a31e572b8356a5e5f25f143881720764544a7c1db5d5c7d",
  registry = "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275",
  run_tag = "qdesn-dacf1-full-20260807_033752__git-a73bd05",
  launch_commit = "a73bd05b7a14a8ac26a43f0d7ab27611d967c3c3",
  closeout_commit = "b2e0472631e8f57ca61e51a4e697de733c9ec1e8"
)
closeout_paths <- list(
  gate = file.path(closeout_dir, "confirmation_gate.json"),
  manifest = file.path(closeout_dir, "closeout_manifest.json"),
  file_manifest = file.path(closeout_dir, "file_manifest.csv"),
  winners = file.path(closeout_dir, "article_metric_winners.csv"),
  preview = file.path(closeout_dir, "article_interface_preview.csv"),
  candidates = file.path(closeout_dir, "article_metric_promotion_candidates.csv"),
  metrics = file.path(closeout_dir, "confirmation_metrics.csv")
)
if (!file.exists(base_path) || any(!file.exists(unlist(closeout_paths)))) {
  stop("Promotion input set is incomplete.", call. = FALSE)
}
if (sha256(base_path) != expected$base || sha256(closeout_paths$gate) != expected$gate ||
    sha256(closeout_paths$winners) != expected$winners ||
    sha256(closeout_paths$preview) != expected$preview ||
    sha256(closeout_paths$metrics) != expected$metrics) {
  stop("A frozen promotion input hash differs from the audited closeout.", call. = FALSE)
}

gate <- jsonlite::read_json(closeout_paths$gate, simplifyVector = TRUE)
manifest <- jsonlite::read_json(closeout_paths$manifest, simplifyVector = TRUE)
file_manifest <- read_csv(closeout_paths$file_manifest)
if (!identical(gate$decision,
               "PROMOTION_READY_METRIC_IMPROVEMENTS_PENDING_ARTICLE_REVIEW") ||
    gate$expected_specs != 30L || gate$observed_specs != 30L ||
    gate$complete_metric_specs != 30L || gate$execution_contract_passes != 30L ||
    gate$complete_candidate_parent_pairs != 18L || gate$unexpected_binary_payloads != 0L ||
    manifest$run_tag != expected$run_tag || manifest$git_commit != expected$closeout_commit ||
    manifest$source_registry_hash_value != expected$registry) {
  stop("The completed confirmation gate does not satisfy the frozen promotion contract.",
       call. = FALSE)
}
observed_file_hashes <- unname(tools::sha256sum(file_manifest$path))
if (any(!file.exists(file_manifest$path)) ||
    !identical(observed_file_hashes, unname(file_manifest$sha256))) {
  stop("The confirmation closeout file manifest is no longer valid.", call. = FALSE)
}

article <- read_csv(base_path)
winners <- read_csv(closeout_paths$winners)
candidates <- read_csv(closeout_paths$candidates)
expected_winners <- data.frame(
  model_variant = c("qdesn_al_rhs_ns", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  metric = c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
             "forecast_qtrue_mae_H1000"),
  candidate_value = c(2.18278410658838, 2.48114774294354, 2.85827834381593),
  stringsAsFactors = FALSE
)
winner_key <- paste(winners$model_variant, winners$metric)
expected_key <- paste(expected_winners$model_variant, expected_winners$metric)
winner_index <- match(expected_key, winner_key)
if (nrow(winners) != 3L || anyNA(winner_index) || anyDuplicated(winner_key) ||
    any(abs(winners$candidate_value[winner_index] - expected_winners$candidate_value) > 1e-12) ||
    !all(winners$contract_eligible[winner_index]) ||
    !all(winners$metric_improves_current[winner_index])) {
  stop("The winner set differs from the three audited strict improvements.", call. = FALSE)
}
winners <- winners[winner_index, , drop = FALSE]

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
evidence_dir <- file.path(output_dir, "confirmation_closeout")
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
evidence_files <- list.files(closeout_dir, full.names = TRUE)
evidence_files <- evidence_files[!file.info(evidence_files)$isdir]
if (!all(file.copy(evidence_files, evidence_dir, overwrite = TRUE))) {
  stop("Could not freeze the confirmation closeout evidence.", call. = FALSE)
}
frozen_closeout_paths <- file.path(evidence_dir, basename(unlist(closeout_paths)))
names(frozen_closeout_paths) <- names(closeout_paths)
if (any(!file.exists(frozen_closeout_paths)) ||
    !identical(
      unname(tools::sha256sum(frozen_closeout_paths)),
      unname(tools::sha256sum(unlist(closeout_paths)))
    )) {
  stop("Frozen confirmation closeout evidence differs from its source.", call. = FALSE)
}

source_dir <- file.path(output_dir, "metric_sources")
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
source_rows <- list()
for (i in seq_len(nrow(winners))) {
  winner <- winners[i, , drop = FALSE]
  source_id <- sprintf("winner_%02d_%s_%s", i, winner$model_variant, winner$metric)
  source_files <- c(
    fit_summary = winner$fit_summary_path,
    forecast_horizon = winner$forecast_horizon_path,
    fit_request = winner$fit_request_path
  )
  source_hashes <- c(
    fit_summary = winner$fit_summary_sha256,
    forecast_horizon = winner$forecast_horizon_sha256,
    fit_request = winner$fit_request_sha256
  )
  if (any(!file.exists(source_files)) ||
      !identical(unname(tools::sha256sum(source_files)), unname(source_hashes))) {
    stop(sprintf("Winner source bundle is missing or changed: %s", source_id), call. = FALSE)
  }
  bundle_dir <- file.path(source_dir, source_id)
  dir.create(file.path(bundle_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
  destinations <- c(
    fit_summary = file.path(bundle_dir, "fit_summary_row.csv"),
    forecast_horizon = file.path(bundle_dir, "tables", "forecast_horizon_summary.csv"),
    fit_request = file.path(bundle_dir, "fit_request.json")
  )
  if (!all(file.copy(source_files, destinations, overwrite = TRUE)) ||
      !identical(unname(tools::sha256sum(destinations)), unname(source_hashes))) {
    stop("Could not freeze an exact winner source bundle.", call. = FALSE)
  }
  artifact_name <- if (winner$metric == "fit_qtrue_rmse") "fit_summary" else
    "forecast_horizon"
  source_rows[[i]] <- data.frame(
    source_id = source_id, model_variant = winner$model_variant,
    metric = winner$metric, spec_id = winner$spec_id,
    source_path = normalizePath(source_files[[artifact_name]], winslash = "/", mustWork = TRUE),
    frozen_path = normalizePath(destinations[[artifact_name]], winslash = "/", mustWork = TRUE),
    sha256 = source_hashes[[artifact_name]],
    frozen_fit_summary_path = normalizePath(destinations[["fit_summary"]], winslash = "/", mustWork = TRUE),
    frozen_fit_summary_sha256 = source_hashes[["fit_summary"]],
    frozen_forecast_horizon_path = normalizePath(destinations[["forecast_horizon"]], winslash = "/", mustWork = TRUE),
    frozen_forecast_horizon_sha256 = source_hashes[["forecast_horizon"]],
    frozen_fit_request_path = normalizePath(destinations[["fit_request"]], winslash = "/", mustWork = TRUE),
    frozen_fit_request_sha256 = source_hashes[["fit_request"]],
    status = winner$status,
    signoff_grade = winner$signoff_grade, stringsAsFactors = FALSE
  )
}
metric_sources <- do.call(rbind, source_rows)

article$article_interface_id <- promotion_id
for (i in seq_len(nrow(winners))) {
  winner <- winners[i, , drop = FALSE]
  row_index <- which(
    article$inference == "mcmc" & article$family == "normal" &
      abs(article$tau - 0.25) <= 1e-12 &
      article$model_variant == winner$model_variant
  )
  if (length(row_index) != 1L) stop("Could not identify one target article row.", call. = FALSE)
  metric <- winner$metric
  if (!(winner$candidate_value < article[[metric]][row_index] - 1e-10)) {
    stop("A candidate is not a strict improvement over the frozen authority.", call. = FALSE)
  }
  prefix <- if (metric == "fit_qtrue_rmse") "fit_source" else
    if (metric == "forecast_qtrue_mae_H1000") "forecast_mae_source" else
      "forecast_check_source"
  frozen <- metric_sources$frozen_path[
    metric_sources$model_variant == winner$model_variant & metric_sources$metric == metric
  ]
  article[[metric]][row_index] <- winner$candidate_value
  article[[paste0(prefix, "_candidate_id")]][row_index] <- winner$spec_id
  article[[paste0(prefix, "_run_tag")]][row_index] <- expected$run_tag
  article[[paste0(prefix, "_signoff_grade")]][row_index] <- winner$signoff_grade
  article[[paste0(prefix, "_status")]][row_index] <- winner$status
  article[[paste0(prefix, "_path")]][row_index] <- frozen
  article[[paste0(prefix, "_sha256")]][row_index] <- sha256(frozen)
  article$validation_branch[row_index] <-
    "validation/qdesn-mcmc-dynamic-alpha-confirm-v1-1.0.0"
  article$validation_commit[row_index] <- expected$launch_commit
  article$validation_closeout_commit[row_index] <- expected$closeout_commit
  article$source_promotion_id[row_index] <-
    "qdesn_500obs_mcmc_dynamic_alpha_confirm_v1_closeout_20260807"
}
target_rows <- article$inference == "mcmc" & article$family == "normal" &
  abs(article$tau - 0.25) <= 1e-12 &
  article$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
for (i in which(target_rows)) {
  ids <- unlist(article[i, c("fit_source_candidate_id",
                            "forecast_mae_source_candidate_id",
                            "forecast_check_source_candidate_id")], use.names = FALSE)
  grades <- unlist(article[i, c("fit_source_signoff_grade",
                               "forecast_mae_source_signoff_grade",
                               "forecast_check_source_signoff_grade")], use.names = FALSE)
  statuses <- unlist(article[i, c("fit_source_status", "forecast_mae_source_status",
                                 "forecast_check_source_status")], use.names = FALSE)
  article$metric_source_mixed[i] <- length(unique(ids)) > 1L
  article$signoff_grade[i] <- worst_grade(grades)
  article$status[i] <- if (all(statuses == "SUCCESS")) "SUCCESS" else
    paste(sort(unique(statuses)), collapse = ";")
}

metric_cols <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
                 "forecast_check_loss_H1000")
key <- with(article, paste(inference, model_variant, family, sprintf("%.2f", tau)))
if (nrow(article) != 72L || anyDuplicated(key) ||
    any(!is.finite(as.numeric(unlist(article[metric_cols], use.names = FALSE)))) ||
    any(article$source_registry_hash_value != expected$registry)) {
  stop("The promoted interface violates its 72-row contract.", call. = FALSE)
}

base <- read_csv(base_path)
comparison <- merge(
  base[, c("inference", "model_variant", "family", "tau", metric_cols)],
  article[, c("inference", "model_variant", "family", "tau", metric_cols)],
  by = c("inference", "model_variant", "family", "tau"),
  suffixes = c("_v1", "_v2"), sort = FALSE
)
changed <- do.call(cbind, lapply(metric_cols, function(metric) {
  comparison[[paste0(metric, "_v2")]] < comparison[[paste0(metric, "_v1")]] - 1e-10
}))
increased <- do.call(cbind, lapply(metric_cols, function(metric) {
  comparison[[paste0(metric, "_v2")]] > comparison[[paste0(metric, "_v1")]] + 1e-10
}))
changed_rows <- which(rowSums(changed) > 0L)
expected_changed_rows <- which(
  comparison$inference == "mcmc" & comparison$family == "normal" &
    abs(comparison$tau - 0.25) <= 1e-12 &
    comparison$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
)
if (sum(changed) != 3L || any(increased) ||
    !setequal(changed_rows, expected_changed_rows)) {
  stop("Promotion changed something other than the three frozen metric cells.", call. = FALSE)
}

interface_path <- write_csv(
  article, file.path(output_dir, paste0(promotion_id, "_interface.csv"))
)
comparison_path <- write_csv(comparison, file.path(output_dir, "v1_vs_v2_metrics.csv"))
winner_path <- write_csv(winners, file.path(output_dir, "promoted_metric_winners.csv"))
candidate_path <- write_csv(
  candidates[candidates$contract_eligible & candidates$metric_improves_current, , drop = FALSE],
  file.path(output_dir, "all_strict_improving_observations.csv")
)
source_path <- write_csv(metric_sources, file.path(output_dir, "metric_source_ledger.csv"))

metric_bundle_ledger <- do.call(rbind, lapply(seq_len(nrow(metric_sources)), function(i) {
  data.frame(
    source_id = paste0(metric_sources$source_id[[i]], c("__fit", "__forecast", "__request")),
    path = c(metric_sources$frozen_fit_summary_path[[i]],
             metric_sources$frozen_forecast_horizon_path[[i]],
             metric_sources$frozen_fit_request_path[[i]]),
    sha256 = c(metric_sources$frozen_fit_summary_sha256[[i]],
               metric_sources$frozen_forecast_horizon_sha256[[i]],
               metric_sources$frozen_fit_request_sha256[[i]]),
    stringsAsFactors = FALSE
  )
}))
source_ledger <- rbind(data.frame(
  source_id = c("base_interface", names(closeout_paths)),
  path = c(normalizePath(base_path, winslash = "/", mustWork = TRUE),
           normalizePath(frozen_closeout_paths, winslash = "/", mustWork = TRUE)),
  sha256 = c(sha256(base_path), vapply(unlist(closeout_paths), sha256, character(1L))),
  stringsAsFactors = FALSE
), metric_bundle_ledger)
ledger_path <- write_csv(source_ledger, file.path(output_dir, "source_ledger.csv"))
output_files <- c(interface = interface_path, comparison = comparison_path,
                  winners = winner_path, improving_candidates = candidate_path,
                  metric_sources = source_path, source_ledger = ledger_path)
output_manifest <- data.frame(
  role = names(output_files), path = unname(output_files),
  sha256 = vapply(output_files, sha256, character(1L)), stringsAsFactors = FALSE
)
output_manifest_path <- write_csv(output_manifest,
                                  file.path(output_dir, "output_file_manifest.csv"))
manifest_path <- write_json(list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_METRIC_ENVELOPE_HANDOFF",
  generated_from_closeout_utc = as.character(gate$generated_at),
  package_version = "1.0.0",
  source_registry_hash_name = "source_registry_hash_value",
  source_registry_hash_value = expected$registry,
  base_interface_id = base_id,
  base_interface_sha256 = expected$base,
  confirmation_run_tag = expected$run_tag,
  confirmation_launch_commit = expected$launch_commit,
  confirmation_closeout_commit = expected$closeout_commit,
  metric_selection_policy = "strictly_lower_finite_value_status_agnostic",
  promoted_metric_count = 3L,
  expected_rows = 72L,
  observed_rows = nrow(article),
  ridge_rows = 0L,
  ridge_policy = "EXCLUDED_UNTIL_SEPARATELY_REPLAYED_UNDER_TRAIN_ONLY_PREPROCESSING",
  article_interface_path = interface_path,
  article_interface_sha256 = sha256(interface_path),
  source_ledger_path = ledger_path,
  source_ledger_sha256 = sha256(ledger_path),
  output_file_manifest_path = output_manifest_path,
  article_update_automatic = FALSE
), file.path(output_dir, paste0(promotion_id, "_manifest.json")))

writeLines(c(
  "# Dynamic-Alpha Confirmation Article Handoff",
  "",
  "This immutable, storage-light handoff extends the corrected 500-observation",
  "single-quantile interface with exactly three strict MCMC metric improvements",
  "from the completed dynamic-alpha confirmation. Diagnostic status is retained",
  "for provenance but is not a metric-selection filter.",
  "",
  sprintf("- Interface: `%s`", basename(interface_path)),
  sprintf("- Interface SHA-256: `%s`", sha256(interface_path)),
  sprintf("- Source registry SHA-256: `%s`", expected$registry),
  sprintf("- Confirmation run tag: `%s`", expected$run_tag),
  "- Promoted metrics: 3",
  "- Article files are not modified by this promotion script."
), file.path(output_dir, "README.md"), useBytes = TRUE)

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE=%s\n", interface_path))
cat(sprintf("INTERFACE_SHA256=%s\n", sha256(interface_path)))
cat("ROWS=72\nPROMOTED_METRICS=3\n")
