#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

promotion_id <-
  "qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818"
base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
promotion_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                           promotion_id)
base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
interface_path <- file.path(promotion_dir, paste0(promotion_id, "_interface.csv"))
manifest_path <- file.path(promotion_dir, paste0(promotion_id, "_manifest.json"))
ledger_path <- file.path(promotion_dir, "source_ledger.csv")
decision_path <- file.path(promotion_dir, "promotion_decision_ledger.csv")
gap_path <- file.path(promotion_dir, "remaining_gap_ledger.csv")
output_manifest_path <- file.path(promotion_dir, "output_file_manifest.csv")
base_path <- file.path(base_dir, paste0(base_id, "_interface.csv"))

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE,
                                    stringsAsFactors = FALSE)
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
required <- c(interface_path, manifest_path, ledger_path, decision_path,
              gap_path, output_manifest_path, base_path)
if (any(!file.exists(required))) stop("The v7 promotion is incomplete.")

interface <- read_csv(interface_path)
base <- read_csv(base_path)
manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)
ledger <- read_csv(ledger_path)
decision <- read_csv(decision_path)
gaps <- read_csv(gap_path)
output_manifest <- read_csv(output_manifest_path)
promoted_metrics <- c(
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
execution_commit <- "5d683342bdcb253ce6f470e1346f78b0b67f7898"

if (!identical(manifest$promotion_id, promotion_id) ||
    !identical(manifest$promotion_status,
               "AUTHORITATIVE_POSTM0_FORECAST_CONFIRMATION_V1") ||
    !identical(manifest$scientific_decision,
               "PROMOTE_GAUSMIX_P025_EXAL_TWO_FORECAST_CHAIN_MEANS") ||
    !identical(manifest$execution_commit, execution_commit) ||
    !grepl("^[0-9a-f]{40}$", manifest$closeout_implementation_commit) ||
    !identical(manifest$source_registry_hash_value, registry_hash) ||
    as.integer(manifest$observed_rows) != 72L ||
    as.integer(manifest$promoted_metric_roles) != 2L ||
    as.integer(manifest$unchanged_numeric_roles) != 214L ||
    as.integer(manifest$binary_payload_count) != 0L ||
    isTRUE(manifest$diagnostics_used_as_promotion_gate) ||
    !isTRUE(manifest$storage_policy_pass) ||
    !setequal(unname(manifest$promoted_metrics), promoted_metrics) ||
    !identical(sha256(interface_path), manifest$article_interface_sha256) ||
    !identical(sha256(ledger_path), manifest$source_ledger_sha256) ||
    !identical(sha256(decision_path), manifest$promotion_decision_ledger_sha256) ||
    !identical(sha256(gap_path), manifest$remaining_gap_ledger_sha256)) {
  stop("The v7 promotion manifest does not verify.", call. = FALSE)
}

expected <- expand.grid(
  inference = c("vb", "mcmc"),
  model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  family = c("normal", "laplace", "gausmix"),
  tau = c(0.05, 0.25, 0.50), stringsAsFactors = FALSE
)
key <- with(interface, paste(inference, model_variant, family, sprintf("%.2f", tau)))
expected_key <- with(expected, paste(inference, model_variant, family,
                                     sprintf("%.2f", tau)))
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
  stop("The v7 article interface violates the fixed grid.", call. = FALSE)
}

numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(interface[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
target <- interface$inference == "mcmc" &
  interface$model_variant == "qdesn_exal_rhs_ns" &
  interface$family == "gausmix" & abs(interface$tau - 0.25) < 1e-12
if (!identical(unname(numeric_changes), c(0L, 1L, 1L)) || sum(target) != 1L ||
    any(interface[target, promoted_metrics] >= base[target, promoted_metrics]) ||
    interface$fit_qtrue_rmse[target] != base$fit_qtrue_rmse[target] ||
    interface$metric_estimator_contract[target] !=
      "fit_inherited_forecasts_mean_of_three_full_budget_mcmc_chains" ||
    interface$confirmation_chain_count[target] != 3L ||
    interface$confirmation_execution_commit[target] != execution_commit ||
    interface$confirmation_state[target] !=
      "POSTM0_FORECAST_FIRST_CONFIRMATION_V1" ||
    interface$signoff_grade[target] != "FAIL") {
  stop("The v7 patch is not exactly the approved forecast promotion.",
       call. = FALSE)
}

promoted <- decision[as_bool(decision$promoted_to_v7), , drop = FALSE]
if (nrow(promoted) != 2L || !setequal(promoted$metric, promoted_metrics) ||
    any(abs(promoted$promoted_value - promoted$mean_value) > 1e-12) ||
    any(promoted$mean_value >= promoted$current_value) ||
    any(promoted$chains != 3L) || any(promoted$chains_improved != 3L) ||
    any(!as_bool(promoted$execution_valid)) ||
    any(as_bool(promoted$diagnostics_used_as_promotion_gate))) {
  stop("The v7 decision ledger violates the forecast-first rule.",
       call. = FALSE)
}

if (!all(c("source_id", "path", "sha256", "role") %in% names(ledger)) ||
    anyDuplicated(ledger$source_id) || any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("The v7 source ledger is incomplete or stale.", call. = FALSE)
}
if (nrow(output_manifest) != 6L || any(!file.exists(output_manifest$path)) ||
    !identical(unname(tools::sha256sum(output_manifest$path)),
               unname(output_manifest$sha256))) {
  stop("The v7 output manifest is incomplete or stale.", call. = FALSE)
}
if (!nrow(gaps) ||
    !all(c("relative_gap_pct", "forecast_priority", "next_action") %in%
         names(gaps))) {
  stop("The v7 continuation ledger is incomplete.", call. = FALSE)
}

configs <- ledger$path[ledger$role == "postm0_confirmation_config"]
statuses <- ledger$path[grepl("_job_status$", ledger$source_id)]
if (length(configs) != 3L || length(statuses) != 3L) {
  stop("The v7 frozen three-chain evidence is incomplete.", call. = FALSE)
}
config_ok <- vapply(configs, function(path) {
  x <- jsonlite::read_json(path, simplifyVector = TRUE)
  identical(x$config$inference$mcmc$slice$core_update_mode,
            "m0_v_collapsed_support_logit") &&
    as.integer(x$config$inference$mcmc$n_burn) == 5000L &&
    as.integer(x$config$inference$mcmc$n_mcmc) == 20000L
}, logical(1L))
status_ok <- vapply(statuses, function(path) {
  x <- jsonlite::read_json(path, simplifyVector = TRUE)
  identical(x$status, "SUCCESS") && as.integer(x$binary_payloads_remaining) == 0L
}, logical(1L))
if (!all(config_ok) || !all(status_ok)) {
  stop("A frozen canonical chain violates the execution contract.", call. = FALSE)
}

heavy <- list.files(promotion_dir, pattern = "[.](rds|rda|RData)$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (length(heavy)) stop("The v7 promotion contains a binary payload.")

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=2\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_CONSUMPTION=PASS\nSTORAGE_POLICY=PASS\n")
