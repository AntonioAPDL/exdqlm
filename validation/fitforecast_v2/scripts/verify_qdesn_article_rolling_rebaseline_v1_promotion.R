#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/", mustWork = TRUE
)
promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811"
promotion_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", promotion_id
)
interface_path <- file.path(promotion_dir, paste0(promotion_id, "_interface.csv"))
manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
source_ledger_path <- file.path(promotion_dir, "source_ledger.csv")

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
split_list <- function(value) {
  values <- strsplit(as.character(value), ";", fixed = TRUE)[[1L]]
  values[nzchar(values)]
}

required_files <- c(interface_path, manifest_path, source_ledger_path)
if (any(!file.exists(required_files))) {
  stop("The rolling-rebaseline promotion is incomplete.", call. = FALSE)
}
interface <- read_csv(interface_path)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
ledger <- read_csv(source_ledger_path)
expected_grid <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
)
key <- with(interface, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected_grid, paste(inference, model_variant, family, sprintf("%.2f", tau)))
qdesn <- grepl("^qdesn_", interface$model_variant)

if (!identical(manifest$promotion_id, promotion_id) ||
    !identical(manifest$promotion_status, "AUTHORITATIVE_ROLLING_ORIGIN_REBASELINE_V1") ||
    !identical(as.integer(manifest$observed_rows), 72L) ||
    !identical(as.integer(manifest$qdesn_forecast_metric_roles), 72L) ||
    !identical(as.integer(manifest$qdesn_corrected_metric_roles), 71L) ||
    !identical(as.integer(manifest$unresolved_metric_roles), 0L) ||
    !identical(as.integer(manifest$frozen_raw_rolling_sources), 62L) ||
    !isTRUE(manifest$storage_policy_pass) ||
    !identical(as.integer(manifest$binary_payload_count), 0L) ||
    !identical(sha256(interface_path), manifest$article_interface_sha256) ||
    !identical(sha256(source_ledger_path), manifest$source_ledger_sha256)) {
  stop("The promotion manifest does not verify.", call. = FALSE)
}
if (nrow(interface) != 72L || anyDuplicated(key) || !setequal(key, expected_key) ||
    any(interface$status != "SUCCESS") || !all(as_bool(interface$comparison_eligible)) ||
    !all(as_bool(interface$article_consumption_allowed)) ||
    any(interface$rolling_rebaseline_state != "AUTHORITATIVE_ROLLING_REBASELINE_V1") ||
    any(interface$forecast_metric_contract[qdesn] != "raw_rolling_origin_rederived") ||
    any(grepl("ridge", interface$model_variant))) {
  stop("The article interface contract does not verify.", call. = FALSE)
}
if (anyDuplicated(ledger$source_id) || any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("The promotion source ledger is missing or stale.", call. = FALSE)
}

evidence_paths <- unique(c(
  interface$forecast_mae_source_path[qdesn],
  interface$forecast_check_source_path[qdesn]
))
if (length(evidence_paths) != 1L || !file.exists(evidence_paths) ||
    length(unique(interface$forecast_mae_source_sha256[qdesn])) != 1L ||
    length(unique(interface$forecast_check_source_sha256[qdesn])) != 1L ||
    !identical(sha256(evidence_paths), unique(interface$forecast_mae_source_sha256[qdesn])) ||
    !identical(sha256(evidence_paths), unique(interface$forecast_check_source_sha256[qdesn]))) {
  stop("The compact rolling evidence binding does not verify.", call. = FALSE)
}
evidence <- read_csv(evidence_paths)
if (nrow(evidence) != 72L || any(evidence$evidence_status != "RAW_ROLLING_PASS") ||
    sum(abs(evidence$absolute_difference) > 1e-8) != 71L) {
  stop("The compact rolling evidence is incomplete.", call. = FALSE)
}
frozen_paths <- unique(unlist(lapply(evidence$frozen_rolling_path_list, split_list), use.names = FALSE))
frozen_hashes <- unique(unlist(lapply(evidence$frozen_rolling_sha256_list, split_list), use.names = FALSE))
if (length(frozen_paths) != 62L || length(frozen_hashes) != 62L ||
    any(!file.exists(frozen_paths)) ||
    !identical(unname(tools::sha256sum(frozen_paths)), unname(frozen_hashes))) {
  stop("The frozen lead-level rolling paths do not verify.", call. = FALSE)
}
metric_sources <- unique(rbind(
  interface[c("fit_source_path", "fit_source_sha256")],
  setNames(interface[c("forecast_mae_source_path", "forecast_mae_source_sha256")],
           c("fit_source_path", "fit_source_sha256")),
  setNames(interface[c("forecast_check_source_path", "forecast_check_source_sha256")],
           c("fit_source_path", "fit_source_sha256"))
))
if (any(!file.exists(metric_sources$fit_source_path)) ||
    !identical(unname(tools::sha256sum(metric_sources$fit_source_path)),
               unname(metric_sources$fit_source_sha256))) {
  stop("An interface metric source is missing or changed.", call. = FALSE)
}
heavy <- list.files(
  promotion_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
if (length(heavy)) stop("Promotion contains a forbidden binary payload.", call. = FALSE)

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE_ROWS=%d\n", nrow(interface)))
cat(sprintf("QDESN_FORECAST_ROLES=%d\n", nrow(evidence)))
cat(sprintf("CORRECTED_ROLES=%d\n", sum(abs(evidence$absolute_difference) > 1e-8)))
cat(sprintf("FROZEN_ROLLING_SOURCES=%d\n", length(frozen_paths)))
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_CONSUMPTION=PASS\n")
cat("STORAGE_POLICY=PASS\n")
