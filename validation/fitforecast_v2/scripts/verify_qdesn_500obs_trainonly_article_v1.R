#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

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
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] == length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v1_20260805"
promotion_dir <- get_arg(
  "--promotion-dir",
  file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
)
interface_path <- file.path(promotion_dir, paste0(promotion_id, "_interface.csv"))
manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
ledger_path <- file.path(promotion_dir, "source_ledger.csv")

required_files <- c(interface_path, manifest_path, ledger_path)
if (any(!file.exists(required_files))) {
  stop("The corrected article handoff is incomplete.", call. = FALSE)
}

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
interface <- read.csv(interface_path, check.names = FALSE, stringsAsFactors = FALSE)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
ledger <- read.csv(ledger_path, check.names = FALSE, stringsAsFactors = FALSE)

expected_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
expected <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("gausmix", "laplace", "normal"),
  tau = c(0.05, 0.25, 0.50),
  stringsAsFactors = FALSE
)
key <- with(interface, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected, paste(inference, model_variant, family, sprintf("%.2f", tau)))
metric_cols <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")

checks <- c(
  identical(as.character(manifest$promotion_id), promotion_id),
  identical(as.integer(manifest$observed_rows), 72L),
  identical(as.integer(manifest$ridge_rows), 0L),
  identical(as.character(manifest$article_interface_sha256), sha256(interface_path)),
  identical(as.character(manifest$source_ledger_sha256), sha256(ledger_path)),
  identical(as.character(manifest$source_registry_hash_value), expected_hash),
  nrow(interface) == 72L,
  !anyDuplicated(key),
  setequal(key, expected_key),
  all(interface$fit_size == 500L),
  all(interface$effective_fit_size == 500L),
  all(interface$source_registry_hash_value == expected_hash),
  all(interface$train_start_source_index == 8501L),
  all(interface$train_end_source_index == 9000L),
  all(interface$forecast_origin_source_index == 9000L),
  all(interface$forecast_block_start_source_index == 9001L),
  all(interface$forecast_block_end_source_index == 10000L),
  all(interface$forecast_max_lead_configured == 30L),
  all(interface$forecast_origin_stride == 30L),
  all(is.finite(as.numeric(unlist(interface[metric_cols], use.names = FALSE)))),
  all(interface$preprocessing_scope[grepl("^qdesn_", interface$model_variant)] == "train_only"),
  !any(grepl("ridge", interface$model_variant)),
  !any(grepl("/home/jaguir26/local/src", unlist(interface, use.names = FALSE), fixed = TRUE)),
  nrow(ledger) == 9L,
  all(c("source_id", "path", "sha256") %in% names(ledger)),
  all(file.exists(ledger$path)),
  identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))
)
if (!all(checks)) stop("Corrected article handoff contract failed.", call. = FALSE)

metric_sources <- unique(rbind(
  interface[, c("fit_source_path", "fit_source_sha256")],
  setNames(interface[, c("forecast_mae_source_path", "forecast_mae_source_sha256")],
           c("fit_source_path", "fit_source_sha256")),
  setNames(interface[, c("forecast_check_source_path", "forecast_check_source_sha256")],
           c("fit_source_path", "fit_source_sha256"))
))
names(metric_sources) <- c("path", "sha256")
if (any(!file.exists(metric_sources$path)) ||
    !identical(unname(tools::sha256sum(metric_sources$path)), unname(metric_sources$sha256))) {
  stop("A metric-level source path or hash is invalid.", call. = FALSE)
}

heavy <- list.files(
  promotion_dir,
  pattern = "[.](rds|rda|RData)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(heavy)) stop("The article handoff contains forbidden binary payloads.", call. = FALSE)

cat("HANDOFF_CONTRACT=PASS\n")
cat(sprintf("ROWS=%d\n", nrow(interface)))
cat(sprintf("VB_ROWS=%d\n", sum(interface$inference == "vb")))
cat(sprintf("MCMC_ROWS=%d\n", sum(interface$inference == "mcmc")))
cat(sprintf("SIGNOFF=%s\n", paste(names(table(interface$signoff_grade)), table(interface$signoff_grade), collapse = ",")))
cat("BINARY_PAYLOADS=0\n")
