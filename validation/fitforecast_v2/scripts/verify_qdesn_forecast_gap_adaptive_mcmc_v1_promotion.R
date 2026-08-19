#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required.", call. = FALSE)
}

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

promotion_id <-
  "qdesn_dqlm_500obs_trainonly_article_v8_forecast_gap_adaptive_20260819"
base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818"
article_base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
promotion_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                           promotion_id)
base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
article_base_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", article_base_id
)

paths <- list(
  interface = file.path(promotion_dir, paste0(promotion_id, "_interface.csv")),
  manifest = file.path(promotion_dir, paste0(promotion_id, "_manifest.json")),
  ledger = file.path(promotion_dir, "source_ledger.csv"),
  decision = file.path(promotion_dir, "promotion_decision_ledger.csv"),
  delta = file.path(promotion_dir, "article_delta_from_rendered_v6.csv"),
  gaps = file.path(promotion_dir, "remaining_gap_ledger.csv"),
  output_manifest = file.path(promotion_dir, "output_file_manifest.csv"),
  base = file.path(base_dir, paste0(base_id, "_interface.csv")),
  article_base = file.path(
    article_base_dir, paste0(article_base_id, "_interface.csv")
  ),
  frozen_plan = file.path(
    promotion_dir, "evidence", "control", "frozen_confirmation_plan.csv"
  )
)

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE,
                                    stringsAsFactors = FALSE)
read_json <- function(path) jsonlite::read_json(path, simplifyVector = TRUE)
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
resolve <- function(path) {
  if (grepl("^/", path)) path else file.path(repo_root, path)
}

if (any(!file.exists(unlist(paths, use.names = FALSE)))) {
  stop("The v8 promotion package is incomplete.", call. = FALSE)
}

interface <- read_csv(paths$interface)
base <- read_csv(paths$base)
article_base <- read_csv(paths$article_base)
manifest <- read_json(paths$manifest)
ledger <- read_csv(paths$ledger)
decision <- read_csv(paths$decision)
delta <- read_csv(paths$delta)
gaps <- read_csv(paths$gaps)
output_manifest <- read_csv(paths$output_manifest)
plan <- read_csv(paths$frozen_plan)

expected_promotions <- data.frame(
  target_cell_id = c(
    "al_gausmix_t0p50", "al_gausmix_t0p50", "al_normal_t0p05"
  ),
  metric = c(
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
    "forecast_check_loss_H1000"
  ),
  candidate_id = c(
    "fgav1_al_gausmix_t0p50_04_fe9ec1233d",
    "fgav1_al_gausmix_t0p50_04_fe9ec1233d",
    "fgav1_al_normal_t0p05_06_8f438fd6ae"
  ),
  stringsAsFactors = FALSE
)
promotion_key <- function(x) paste(x$target_cell_id, x$metric, x$candidate_id)
registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
scientific_design_commit <- "e842a6438839a7f70345dc7df1c448f887e5eeed"
execution_commit <- "a17b16836efc21393b2000202206a3edf67617ae"
canonical_signoff_counts <- as.integer(unlist(
  manifest$canonical_chain_signoff_counts[c("PASS", "WARN", "FAIL", "MISSING")]
))
metric_role_signoff_counts <- as.integer(unlist(
  manifest$metric_role_chain_signoff_counts[
    c("PASS", "WARN", "FAIL", "MISSING")
  ]
))

if (!identical(manifest$promotion_id, promotion_id) ||
    !identical(manifest$promotion_status,
               "AUTHORITATIVE_FORECAST_GAP_ADAPTIVE_MCMC_V1") ||
    !identical(manifest$scientific_decision,
               "PROMOTE_THREE_CASE_SPECIFIC_FORECAST_CHAIN_MEANS") ||
    !identical(manifest$scientific_design_commit, scientific_design_commit) ||
    !identical(manifest$confirmation_execution_commit, execution_commit) ||
    !grepl("^[0-9a-f]{40}$", manifest$closeout_implementation_commit) ||
    !identical(manifest$source_registry_hash_value, registry_hash) ||
    as.integer(manifest$observed_rows) != 72L ||
    as.integer(manifest$promoted_metric_roles) != 3L ||
    as.integer(manifest$unchanged_numeric_roles_from_v7) != 213L ||
    as.integer(manifest$article_numeric_updates_from_rendered_v6) != 5L ||
    as.integer(manifest$binary_payload_count) != 0L ||
    isTRUE(manifest$diagnostics_used_as_promotion_gate) ||
    !isTRUE(manifest$storage_policy_pass) ||
    !identical(sha256(paths$interface), manifest$article_interface_sha256) ||
    !identical(sha256(paths$ledger), manifest$source_ledger_sha256) ||
    !identical(sha256(paths$decision),
               manifest$promotion_decision_ledger_sha256) ||
    !identical(sha256(paths$delta), manifest$article_delta_sha256) ||
    !identical(sha256(paths$gaps), manifest$remaining_gap_ledger_sha256) ||
    as.integer(manifest$campaign_jobs$total) != 378L ||
    as.integer(manifest$campaign_jobs$failures) != 0L ||
    as.integer(manifest$canonical_chains) != 24L ||
    !identical(canonical_signoff_counts, c(11L, 13L, 0L, 0L)) ||
    !identical(metric_role_signoff_counts, c(13L, 20L, 0L, 0L))) {
  stop("The v8 promotion manifest does not verify.", call. = FALSE)
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
if (nrow(interface) != 72L || nrow(base) != 72L ||
    nrow(article_base) != 72L || anyDuplicated(key) ||
    !setequal(key, expected_key) || any(interface$status != "SUCCESS") ||
    !all(as_bool(interface$comparison_eligible)) ||
    !all(as_bool(interface$article_consumption_allowed)) ||
    any(interface$source_registry_hash_value != registry_hash) ||
    any(!is.finite(as.numeric(unlist(interface[metric_columns], use.names = FALSE)))) ||
    any(grepl("ridge", interface$model_variant))) {
  stop("The v8 article interface violates the fixed grid.", call. = FALSE)
}

numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(interface[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 1L, 2L))) {
  stop("The v8 interface changed outside the approved forecast roles.",
       call. = FALSE)
}

promoted <- decision[as_bool(decision$promoted_to_v8), , drop = FALSE]
if (nrow(decision) != 11L || nrow(promoted) != 3L ||
    !setequal(promotion_key(promoted), promotion_key(expected_promotions)) ||
    any(abs(promoted$promoted_value - promoted$mean_value) > 1e-12) ||
    any(promoted$mean_value >= promoted$current_value) ||
    any(promoted$chains != 3L) || any(promoted$chains_improved != 3L) ||
    any(!as_bool(promoted$all_finite)) || any(!as_bool(promoted$all_success)) ||
    any(promoted$diagnostics == "MISSING")) {
  stop("The v8 decision ledger violates the metric-specific rule.",
       call. = FALSE)
}

for (i in seq_len(nrow(promoted))) {
  model <- if (startsWith(promoted$target_cell_id[[i]], "exal_")) {
    "qdesn_exal_rhs_ns"
  } else "qdesn_al_rhs_ns"
  family <- sub("^.*_(normal|laplace|gausmix)_.*$", "\\1",
                promoted$target_cell_id[[i]])
  tau <- as.numeric(sub(".*_t([0-9]+)p([0-9]+)$", "\\1.\\2",
                        promoted$target_cell_id[[i]]))
  target <- interface$inference == "mcmc" & interface$model_variant == model &
    interface$family == family & abs(interface$tau - tau) < 1e-12
  if (sum(target) != 1L ||
      abs(interface[[promoted$metric[[i]]]][target] -
          promoted$mean_value[[i]]) > 1e-12 ||
      interface$confirmation_chain_count[target] != 3L ||
      interface$confirmation_execution_commit[target] != execution_commit ||
      interface$confirmation_state[target] !=
        "FORECAST_GAP_ADAPTIVE_MCMC_V1_CONFIRMATION") {
    stop("A promoted metric is not wired to its case-specific interface row.",
         call. = FALSE)
  }
}

if (nrow(delta) != 5L ||
    any(delta$authoritative_v8_value >= delta$rendered_v6_value)) {
  stop("The article delta ledger is not the approved five-role update.",
       call. = FALSE)
}
delta_keys <- with(delta, paste(inference, model_variant, family,
                                sprintf("%.2f", tau), metric))
expected_delta <- character()
for (metric in metric_columns) {
  changed <- which(abs(interface[[metric]] - article_base[[metric]]) > 1e-12)
  if (length(changed)) {
    expected_delta <- c(expected_delta, with(interface[changed, ], paste(
      inference, model_variant, family, sprintf("%.2f", tau), metric
    )))
  }
}
if (!setequal(delta_keys, expected_delta)) {
  stop("The article delta ledger is incomplete.", call. = FALSE)
}

ledger_paths <- vapply(ledger$path, resolve, character(1L))
if (!all(c("source_id", "path", "sha256", "role") %in% names(ledger)) ||
    anyDuplicated(ledger$source_id) || any(!file.exists(ledger_paths)) ||
    !identical(unname(tools::sha256sum(ledger_paths)), unname(ledger$sha256))) {
  stop("The portable v8 source ledger is incomplete or stale.", call. = FALSE)
}
output_paths <- vapply(output_manifest$path, resolve, character(1L))
if (nrow(output_manifest) != 7L || any(!file.exists(output_paths)) ||
    !identical(unname(tools::sha256sum(output_paths)),
               unname(output_manifest$sha256))) {
  stop("The v8 output manifest is incomplete or stale.", call. = FALSE)
}
if (!nrow(gaps) ||
    !all(c("relative_gap_pct", "forecast_priority", "next_action") %in%
         names(gaps))) {
  stop("The v8 continuation ledger is incomplete.", call. = FALSE)
}

if (nrow(plan) != 24L || anyDuplicated(plan$job_id) ||
    !identical(sort(as.integer(table(plan$candidate_id))), rep(3L, 8L))) {
  stop("The frozen canonical plan is incomplete.", call. = FALSE)
}
config_paths <- vapply(plan$config_path, resolve, character(1L))
if (any(!file.exists(config_paths)) ||
    !identical(unname(tools::sha256sum(config_paths)),
               unname(plan$config_sha256))) {
  stop("A frozen canonical config changed.", call. = FALSE)
}
config_ok <- vapply(seq_len(nrow(plan)), function(i) {
  x <- read_json(config_paths[[i]])
  mode_ok <- plan$likelihood_target[[i]] != "exal" ||
    identical(x$config$inference$mcmc$slice$core_update_mode,
              "m0_v_collapsed_support_logit")
  mode_ok && as.integer(x$config$inference$mcmc$n_burn) == 5000L &&
    as.integer(x$config$inference$mcmc$n_mcmc) == 20000L &&
    as.integer(x$config$cpp$postpred_threads) == 1L
}, logical(1L))
if (!all(config_ok)) stop("A canonical config violates the execution contract.")

status_paths <- ledger_paths[
  ledger$role == "confirmation_job_evidence" &
    grepl("__job_status$", ledger$source_id)
]
signoff_paths <- ledger_paths[
  ledger$role == "confirmation_job_evidence" &
    grepl("__signoff$", ledger$source_id)
]
if (length(status_paths) != 24L || length(signoff_paths) != 24L) {
  stop("The v8 package lacks complete compact job evidence.", call. = FALSE)
}
status_ok <- vapply(status_paths, function(path) {
  x <- read_json(path)
  identical(x$status, "SUCCESS") && as.integer(x$binary_payloads_remaining) == 0L
}, logical(1L))
signoffs <- do.call(rbind, lapply(signoff_paths, read_csv))
if (!all(status_ok) || nrow(signoffs) != 24L ||
    !identical(as.integer(table(signoffs$signoff_grade)[c("PASS", "WARN")]),
               c(11L, 13L))) {
  stop("The frozen status or diagnostic evidence does not verify.",
       call. = FALSE)
}

heavy <- list.files(promotion_dir, pattern = "[.](rds|rda|RData)$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
all_files <- list.files(promotion_dir, recursive = TRUE, full.names = TRUE)
if (length(heavy) || any(file.info(all_files)$size > 10 * 1024^2)) {
  stop("The v8 promotion violates the storage-light contract.", call. = FALSE)
}

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=3\n")
cat("ARTICLE_DELTAS_FROM_RENDERED_V6=5\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_CONSUMPTION=PASS\nSTORAGE_POLICY=PASS\n")
