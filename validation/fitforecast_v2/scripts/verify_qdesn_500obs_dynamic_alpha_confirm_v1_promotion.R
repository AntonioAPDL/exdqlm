#!/usr/bin/env Rscript

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                           winslash = "/", mustWork = TRUE)
id <- "qdesn_dqlm_500obs_trainonly_article_v2_20260807"
root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", id)
interface_path <- file.path(root, paste0(id, "_interface.csv"))
manifest_path <- file.path(root, paste0(id, "_manifest.json"))
ledger_path <- file.path(root, "source_ledger.csv")
if (any(!file.exists(c(interface_path, manifest_path, ledger_path)))) {
  stop("The dynamic-alpha promotion is incomplete.", call. = FALSE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
interface <- read.csv(interface_path, check.names = FALSE, stringsAsFactors = FALSE)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
ledger <- read.csv(ledger_path, check.names = FALSE, stringsAsFactors = FALSE)
registry <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
metrics <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
             "forecast_check_loss_H1000")
target <- interface[
  interface$inference == "mcmc" & interface$family == "normal" &
    abs(interface$tau - 0.25) <= 1e-12 &
    interface$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  , drop = FALSE
]
checks <- c(
  nrow(interface) == 72L,
  all(interface$article_interface_id == id),
  all(interface$source_registry_hash_value == registry),
  all(is.finite(as.numeric(unlist(interface[metrics], use.names = FALSE)))),
  nrow(target) == 2L,
  abs(target$fit_qtrue_rmse[target$model_variant == "qdesn_al_rhs_ns"] - 2.18278410658838) < 1e-12,
  abs(target$forecast_qtrue_mae_H1000[target$model_variant == "qdesn_al_rhs_ns"] - 2.48114774294354) < 1e-12,
  abs(target$forecast_qtrue_mae_H1000[target$model_variant == "qdesn_exal_rhs_ns"] - 2.85827834381593) < 1e-12,
  identical(manifest$metric_selection_policy,
            "strictly_lower_finite_value_status_agnostic"),
  manifest$promoted_metric_count == 3L,
  manifest$ridge_rows == 0L,
  identical(
    manifest$ridge_policy,
    "EXCLUDED_UNTIL_SEPARATELY_REPLAYED_UNDER_TRAIN_ONLY_PREPROCESSING"
  ),
  manifest$article_interface_sha256 == sha256(interface_path),
  manifest$source_ledger_sha256 == sha256(ledger_path),
  all(file.exists(ledger$path)),
  identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256)),
  all(startsWith(
    normalizePath(ledger$path[-1L], winslash = "/", mustWork = TRUE),
    paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/")
  )),
  !length(list.files(root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                     full.names = TRUE, ignore.case = TRUE)),
  !any(grepl("/home/jaguir26/local/src", unlist(interface), fixed = TRUE))
)
if (!all(checks)) stop("Dynamic-alpha promotion verification failed.", call. = FALSE)
cat("PROMOTION_CONTRACT=PASS\nROWS=72\nPROMOTED_METRICS=3\nBINARY_PAYLOADS=0\n")
