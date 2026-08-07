#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v3_20260807"
base_id <- "qdesn_dqlm_500obs_trainonly_article_v2_20260807"
promotion_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                           promotion_id)
base_path <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                       base_id, paste0(base_id, "_interface.csv"))
interface_path <- file.path(promotion_dir, paste0(promotion_id, "_interface.csv"))
manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
ledger_path <- file.path(promotion_dir, "source_ledger.csv")
output_manifest_path <- file.path(promotion_dir, "output_file_manifest.csv")
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) {
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
as_bool <- function(value) {
  if (is.logical(value)) return(!is.na(value) & value)
  tolower(as.character(value)) %in% c("true", "t", "1", "yes")
}

expected_hashes <- c(
  interface = "90744fae79f8af79c6e844e5862c90330ea14d9bbd2df69f630440887fed1393",
  manifest = "207eb11386d1a97831f6fd12ad6fe83c238654725494febde14d05e78a5f4188",
  ledger = "48317ea3b06d09b0ba8e972986cef2aee740a7aec24b9d37b0930c3a8f6b7726",
  output_manifest = "c5471ee065a0ee863eb1e84e8caa70c7cfb5d080dfbd7292d56d2e58db50eeeb"
)
paths <- c(interface = interface_path, manifest = manifest_path,
           ledger = ledger_path, output_manifest = output_manifest_path)
if (any(!file.exists(paths)) ||
    !identical(unname(tools::sha256sum(paths)), unname(expected_hashes))) {
  stop("A frozen promotion artifact is missing or changed.", call. = FALSE)
}

manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
if (manifest$promotion_id != promotion_id ||
    manifest$promotion_status != "AUTHORITATIVE_METRIC_ENVELOPE_HANDOFF" ||
    manifest$base_interface_id != base_id || manifest$promoted_metric_count != 6L ||
    manifest$expected_rows != 72L || manifest$observed_rows != 72L ||
    manifest$ridge_rows != 0L || manifest$package_version != "1.0.0" ||
    manifest$confirmation_run_tag !=
      "qdesn-strv1-full-20260807_045131__git-acfa0b4" ||
    manifest$confirmation_branch !=
      "validation/qdesn-mcmc-sparse-topology-refine-v1-1.0.0" ||
    manifest$confirmation_launch_commit !=
      "acfa0b4a4b989cd3722ebdde378a9f6b47401652" ||
    manifest$source_registry_hash_value !=
      "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275") {
  stop("Promotion manifest contract failed.", call. = FALSE)
}

ledger <- read_csv(ledger_path)
if (!all(c("source_id", "path", "sha256") %in% names(ledger)) ||
    any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("Promotion source ledger is incomplete or stale.", call. = FALSE)
}
output_manifest <- read_csv(output_manifest_path)
if (any(!file.exists(output_manifest$path)) ||
    !identical(unname(tools::sha256sum(output_manifest$path)),
               unname(output_manifest$sha256))) {
  stop("Promotion output manifest is stale.", call. = FALSE)
}

base <- read_csv(base_path)
current <- read_csv(interface_path)
required <- c(
  "article_interface_id", "inference", "model_variant", "family", "tau",
  "comparison_eligible", "status", "signoff_grade", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "source_registry_hash_value", "preprocessing_scope", "package_version",
  "validation_branch", "validation_commit", "validation_closeout_commit",
  "source_promotion_id"
)
if (nrow(base) != 72L || nrow(current) != 72L ||
    length(setdiff(required, names(current))) ||
    !all(as_bool(current$comparison_eligible)) || !all(current$status == "SUCCESS") ||
    any(grepl("ridge", current$model_variant)) ||
    any(grepl("/home/jaguir26/local/src", unlist(current, use.names = FALSE),
              fixed = TRUE))) {
  stop("The promoted interface violates its structural contract.", call. = FALSE)
}

keys <- c("inference", "model_variant", "family", "tau")
metrics <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
             "forecast_check_loss_H1000")
comparison <- merge(base[, c(keys, metrics)], current[, c(keys, metrics)],
                    by = keys, suffixes = c("_base", "_current"), sort = FALSE)
decreased <- do.call(cbind, lapply(metrics, function(metric) {
  comparison[[paste0(metric, "_current")]] <
    comparison[[paste0(metric, "_base")]] - 1e-10
}))
increased <- do.call(cbind, lapply(metrics, function(metric) {
  comparison[[paste0(metric, "_current")]] >
    comparison[[paste0(metric, "_base")]] + 1e-10
}))
target <- comparison$inference == "mcmc" & comparison$family == "normal" &
  abs(comparison$tau - 0.25) <= 1e-12 &
  comparison$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
if (sum(decreased) != 6L || any(increased) ||
    !setequal(which(rowSums(decreased) > 0L), which(target))) {
  stop("The interface diff is not exactly six strict target-cell improvements.",
       call. = FALSE)
}

target_rows <- current$inference == "mcmc" & current$family == "normal" &
  abs(current$tau - 0.25) <= 1e-12 &
  current$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
if (!all(current$validation_branch[target_rows] ==
         "validation/qdesn-mcmc-sparse-topology-refine-v1-1.0.0") ||
    !all(current$validation_commit[target_rows] ==
         "acfa0b4a4b989cd3722ebdde378a9f6b47401652") ||
    !all(current$validation_closeout_commit[target_rows] ==
         "acfa0b4a4b989cd3722ebdde378a9f6b47401652") ||
    !all(current$source_promotion_id[target_rows] ==
         "qdesn_500obs_mcmc_sparse_topology_refine_v1_closeout_20260807")) {
  stop("Sparse-topology provenance was not installed on both target rows.",
       call. = FALSE)
}

binary <- list.files(promotion_dir, pattern = "[.](rds|rda|RData)$",
                     recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (length(binary)) stop("Promotion contains a forbidden model payload.", call. = FALSE)

cat("SPARSE_TOPOLOGY_PROMOTION_CHECK=PASS\n")
cat(sprintf("ROWS=%d\n", nrow(current)))
cat(sprintf("PROMOTED_METRICS=%d\n", sum(decreased)))
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat(sprintf("INTERFACE_SHA256=%s\n", sha256(interface_path)))
