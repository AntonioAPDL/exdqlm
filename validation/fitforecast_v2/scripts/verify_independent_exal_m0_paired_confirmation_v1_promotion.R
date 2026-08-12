#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
base_id <- "qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811"
promotion_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                           promotion_id)
base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", base_id)
interface_path <- file.path(promotion_dir, paste0(promotion_id, "_interface.csv"))
manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
ledger_path <- file.path(promotion_dir, "source_ledger.csv")
decision_path <- file.path(promotion_dir, "promotion_decision_ledger.csv")
gap_path <- file.path(promotion_dir, "remaining_gap_ledger.csv")
base_path <- file.path(base_dir, paste0(base_id, "_interface.csv"))

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE,
                                    stringsAsFactors = FALSE)
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}

required <- c(interface_path, manifest_path, ledger_path, decision_path, gap_path,
              base_path)
if (any(!file.exists(required))) {
  stop("The paired-confirmation promotion is incomplete.", call. = FALSE)
}
interface <- read_csv(interface_path)
base <- read_csv(base_path)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
ledger <- read_csv(ledger_path)
decision <- read_csv(decision_path)
gaps <- read_csv(gap_path)

registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
execution_commit <- "0f0634e40b5d1e320b61ad7af1464beb56546fb3"
ready_metrics <- c(
  "normal_t0p05/forecast_qtrue_mae_H1000",
  "normal_t0p05/forecast_check_loss_H1000"
)
if (!identical(manifest$promotion_id, promotion_id) ||
    !identical(manifest$promotion_status, "AUTHORITATIVE_PAIRED_CONFIRMATION_V1") ||
    !identical(manifest$scientific_decision,
               "PROMOTE_TWO_NORMAL_P005_EXAL_FORECAST_CHAIN_MEANS") ||
    !identical(manifest$execution_commit, execution_commit) ||
    !grepl("^[0-9a-f]{40}$", manifest$closeout_commit) ||
    !grepl("^[0-9a-f]{40}$", manifest$promotion_implementation_commit) ||
    !identical(manifest$source_registry_hash_value, registry_hash) ||
    as.integer(manifest$observed_rows) != 72L ||
    as.integer(manifest$promoted_metric_roles) != 2L ||
    as.integer(manifest$unchanged_numeric_roles) != 214L ||
    as.integer(manifest$binary_payload_count) != 0L ||
    !isTRUE(manifest$storage_policy_pass) ||
    !setequal(unname(manifest$promoted_metrics), ready_metrics) ||
    !identical(sha256(interface_path), manifest$article_interface_sha256) ||
    !identical(sha256(ledger_path), manifest$source_ledger_sha256) ||
    !identical(sha256(decision_path), manifest$promotion_decision_ledger_sha256) ||
    !identical(sha256(gap_path), manifest$remaining_gap_ledger_sha256)) {
  stop("The v6 promotion manifest does not verify.", call. = FALSE)
}

expected <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
)
key <- with(interface, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected, paste(inference, model_variant, family, sprintf("%.2f", tau)))
metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
if (nrow(interface) != 72L || nrow(base) != 72L || anyDuplicated(key) ||
    !setequal(key, expected_key) || any(interface$status != "SUCCESS") ||
    !all(as_bool(interface$comparison_eligible)) ||
    !all(as_bool(interface$article_consumption_allowed)) ||
    any(interface$source_registry_hash_value != registry_hash) ||
    any(!is.finite(as.numeric(unlist(interface[metric_columns], use.names = FALSE)))) ||
    any(grepl("ridge", interface$model_variant))) {
  stop("The v6 article interface violates the fixed grid.", call. = FALSE)
}

numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(interface[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
target <- interface$inference == "mcmc" &
  interface$model_variant == "qdesn_exal_rhs_ns" &
  interface$family == "normal" & abs(interface$tau - 0.05) < 1e-12
if (!identical(unname(numeric_changes), c(0L, 1L, 1L)) || sum(target) != 1L ||
    interface$forecast_qtrue_mae_H1000[target] >=
      base$forecast_qtrue_mae_H1000[target] ||
    interface$forecast_check_loss_H1000[target] >=
      base$forecast_check_loss_H1000[target] ||
    interface$metric_estimator_contract[target] !=
      "fit_inherited_forecasts_mean_of_three_full_budget_mcmc_chains" ||
    interface$confirmation_chain_count[target] != 3L ||
    interface$confirmation_execution_commit[target] != execution_commit ||
    interface$confirmation_closeout_commit[target] != manifest$closeout_commit ||
    interface$signoff_grade[target] != "WARN") {
  stop("The v6 metric patch is not exactly the approved two-role promotion.",
       call. = FALSE)
}

promoted <- decision[as_bool(decision$promoted_to_v6), ]
if (nrow(promoted) != 2L ||
    !setequal(paste0(promoted$target_cell_id, "/", promoted$metric), ready_metrics) ||
    any(abs(promoted$promoted_value - promoted$chain_mean) > 1e-12) ||
    any(!as_bool(promoted$mean_below_current)) ||
    any(!as_bool(promoted$median_below_current)) ||
    any(promoted$successful_chains != 3L) || any(promoted$finite_chains != 3L)) {
  stop("The v6 decision ledger violates the predeclared promotion rule.",
       call. = FALSE)
}

if (!all(c("source_id", "path", "sha256", "role") %in% names(ledger)) ||
    anyDuplicated(ledger$source_id) || any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("The v6 source ledger is incomplete or stale.", call. = FALSE)
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
  stop("A v6 metric source is missing or changed.", call. = FALSE)
}
if (!nrow(gaps) || !all(c("relative_gap_pct", "lower_tail_priority", "next_action") %in%
                        names(gaps)) ||
    !any(as_bool(gaps$lower_tail_priority))) {
  stop("The lower-tail continuation ledger is incomplete.", call. = FALSE)
}
heavy <- list.files(promotion_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
if (length(heavy)) stop("The v6 promotion contains a forbidden binary payload.",
                        call. = FALSE)

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\n")
cat("PROMOTED_METRIC_ROLES=2\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat(sprintf("LOWER_TAIL_PRIORITY_ROLES=%d\n",
            sum(as_bool(gaps$lower_tail_priority))))
cat("ARTICLE_CONSUMPTION=PASS\n")
cat("STORAGE_POLICY=PASS\n")
