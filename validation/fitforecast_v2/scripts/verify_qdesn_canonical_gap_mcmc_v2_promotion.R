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
  "qdesn_dqlm_500obs_trainonly_article_v9_canonical_gap_20260821"
base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v8_forecast_gap_adaptive_20260819"
article_base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
promotion_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                           promotion_id)
base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
article_base_dir <- file.path(repo_root, "validation", "fitforecast_v2",
                              "promotions", article_base_id)

paths <- list(
  interface = file.path(promotion_dir, paste0(promotion_id, "_interface.csv")),
  manifest = file.path(promotion_dir, paste0(promotion_id, "_manifest.json")),
  ledger = file.path(promotion_dir, "source_ledger.csv"),
  decision = file.path(promotion_dir, "promotion_decision_ledger.csv"),
  effect = file.path(promotion_dir, "promotion_effect_from_v8.csv"),
  delta = file.path(promotion_dir, "article_delta_from_rendered_v6.csv"),
  gaps = file.path(promotion_dir, "remaining_gap_ledger.csv"),
  specifications = file.path(promotion_dir, "promoted_candidate_specifications.csv"),
  chains = file.path(promotion_dir, "confirmation_chain_evidence.csv"),
  rollback = file.path(promotion_dir, "rollback_ledger.csv"),
  output_manifest = file.path(promotion_dir, "output_file_manifest.csv"),
  base = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_ledger = file.path(base_dir, "source_ledger.csv"),
  article_base = file.path(article_base_dir,
                           paste0(article_base_id, "_interface.csv")),
  frozen_plan = file.path(promotion_dir, "evidence", "control",
                          "frozen_confirmation_plan.csv"),
  frozen_windows = file.path(promotion_dir, "evidence", "control",
                             "frozen_canonical_window_registry.csv")
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
  stop("The v9 promotion package is incomplete.", call. = FALSE)
}

interface <- read_csv(paths$interface)
base <- read_csv(paths$base)
article_base <- read_csv(paths$article_base)
manifest <- read_json(paths$manifest)
ledger <- read_csv(paths$ledger)
base_ledger <- read_csv(paths$base_ledger)
decision <- read_csv(paths$decision)
effect <- read_csv(paths$effect)
delta <- read_csv(paths$delta)
gaps <- read_csv(paths$gaps)
specifications <- read_csv(paths$specifications)
chains <- read_csv(paths$chains)
rollback <- read_csv(paths$rollback)
output_manifest <- read_csv(paths$output_manifest)
plan <- read_csv(paths$frozen_plan)
windows <- read_csv(paths$frozen_windows)

registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
design_commit <- "ec9a921c9adf4e183a4ce4e61ba7714a91f7f779"
expected_signoffs <- c(PASS = 0L, WARN = 5L, FAIL = 1L, MISSING = 0L)
manifest_signoffs <- as.integer(unlist(
  manifest$canonical_chain_signoff_counts[names(expected_signoffs)]
))

if (!identical(manifest$promotion_id, promotion_id) ||
    !identical(manifest$promotion_status,
               "AUTHORITATIVE_CANONICAL_GAP_MCMC_V2") ||
    !identical(manifest$scientific_decision,
               "PROMOTE_FOUR_CASE_SPECIFIC_FORECAST_CHAIN_MEANS") ||
    !identical(manifest$base_promotion_id, base_id) ||
    !identical(manifest$rendered_article_base_id, article_base_id) ||
    !identical(manifest$scientific_design_commit, design_commit) ||
    !identical(manifest$confirmation_execution_commit, design_commit) ||
    !grepl("^[0-9a-f]{40}$", manifest$closeout_implementation_commit) ||
    !identical(manifest$source_registry_hash_value, registry_hash) ||
    as.integer(manifest$observed_rows) != 72L ||
    as.integer(manifest$promoted_metric_roles) != 4L ||
    as.integer(manifest$unchanged_numeric_roles_from_v8) != 212L ||
    as.integer(manifest$article_numeric_updates_from_rendered_v6) != 8L ||
    as.integer(manifest$canonical_chains) != 6L ||
    as.integer(manifest$campaign_jobs$total) != 176L ||
    as.integer(manifest$campaign_jobs$failures) != 0L ||
    !identical(manifest_signoffs, unname(expected_signoffs)) ||
    as.integer(manifest$binary_payload_count) != 0L ||
    isTRUE(manifest$diagnostics_used_as_promotion_gate) ||
    !isTRUE(manifest$storage_policy_pass) ||
    !identical(sha256(paths$interface), manifest$article_interface_sha256) ||
    !identical(sha256(paths$ledger), manifest$source_ledger_sha256) ||
    !identical(sha256(paths$decision),
               manifest$promotion_decision_ledger_sha256) ||
    !identical(sha256(paths$effect), manifest$promotion_effect_from_v8_sha256) ||
    !identical(sha256(paths$delta), manifest$article_delta_sha256) ||
    !identical(sha256(paths$gaps), manifest$remaining_gap_ledger_sha256) ||
    !identical(sha256(paths$specifications),
               manifest$promoted_specifications_sha256) ||
    !identical(sha256(paths$chains), manifest$chain_evidence_sha256) ||
    !identical(sha256(paths$rollback), manifest$rollback_ledger_sha256)) {
  stop("The v9 promotion manifest does not verify.", call. = FALSE)
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
    any(interface$article_interface_id != promotion_id) ||
    any(interface$source_registry_hash_value != registry_hash) ||
    any(!is.finite(as.numeric(unlist(interface[metric_columns], use.names = FALSE)))) ||
    any(grepl("ridge", interface$model_variant))) {
  stop("The v9 article interface violates the fixed 72-row grid.",
       call. = FALSE)
}

numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(interface[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 2L, 2L))) {
  stop("The v9 interface changed outside the approved forecast roles.",
       call. = FALSE)
}

expected_promotions <- data.frame(
  model_variant = c(
    "qdesn_al_rhs_ns", "qdesn_al_rhs_ns",
    "qdesn_exal_rhs_ns", "qdesn_exal_rhs_ns"
  ),
  family = c("normal", "normal", "gausmix", "gausmix"),
  tau = c(0.05, 0.05, 0.50, 0.50),
  metric = rep(c("forecast_qtrue_mae_H1000",
                 "forecast_check_loss_H1000"), 2L),
  value = c(6.91659380458911, 1.20016989478546,
            1.4196448639744, 5.48673029777657),
  stringsAsFactors = FALSE
)
for (i in seq_len(nrow(expected_promotions))) {
  row <- expected_promotions[i, , drop = FALSE]
  index <- which(
    interface$inference == "mcmc" &
      interface$model_variant == row$model_variant &
      interface$family == row$family & abs(interface$tau - row$tau) < 1e-12
  )
  if (length(index) != 1L ||
      abs(interface[[row$metric]][[index]] - row$value) > 1e-12 ||
      interface$confirmation_chain_count[[index]] != 3L ||
      interface$confirmation_execution_commit[[index]] != design_commit ||
      interface$confirmation_state[[index]] !=
        "CANONICAL_GAP_MCMC_V2_CONFIRMATION" ||
      interface$source_promotion_id[[index]] != promotion_id) {
    stop("A promoted role is not wired to its case-specific row.", call. = FALSE)
  }
}

decision_promoted <- decision[as_bool(decision$promoted_to_v9), , drop = FALSE]
decision_key <- with(decision_promoted,
                     paste(target_cell_id, metric, candidate_id))
expected_decision_key <- c(
  "al_normal_t0p05 forecast_qtrue_mae_H1000 cgcv2_al_normal_t0p05_01_64121b0e9b",
  "al_normal_t0p05 forecast_check_loss_H1000 cgcv2_al_normal_t0p05_01_64121b0e9b",
  "exal_gausmix_t0p50 forecast_qtrue_mae_H1000 cgcv2_exal_gausmix_t0p50_01_4c129b0c50",
  "exal_gausmix_t0p50 forecast_check_loss_H1000 cgcv2_exal_gausmix_t0p50_01_4c129b0c50"
)
if (nrow(decision) != 4L || nrow(decision_promoted) != 4L ||
    !setequal(decision_key, expected_decision_key) ||
    any(abs(decision_promoted$promoted_value -
            decision_promoted$confirmation_value) > 1e-12) ||
    any(decision_promoted$confirmation_value >= decision_promoted$current_value) ||
    any(as_bool(decision_promoted$diagnostics_used_as_promotion_gate))) {
  stop("The v9 decision ledger violates the case-specific rule.",
       call. = FALSE)
}

effect_key <- with(effect, paste(inference, model_variant, family,
                                 sprintf("%.2f", tau), metric))
expected_effect_key <- with(expected_promotions, paste(
  "mcmc", model_variant, family, sprintf("%.2f", tau), metric
))
if (nrow(effect) != 4L || !setequal(effect_key, expected_effect_key) ||
    any(effect$authoritative_v9_value >= effect$authoritative_v8_value) ||
    any(effect$absolute_gain <= 0) || any(effect$relative_gain_pct <= 0)) {
  stop("The v9 effect ledger is not the approved four-role update.",
       call. = FALSE)
}

delta_required <- c(
  "inference", "model_variant", "family", "tau", "metric",
  "rendered_v6_value", "authoritative_value", "authority_version",
  "relative_gain_pct", "source_promotion_id"
)
if (!all(delta_required %in% names(delta)) || nrow(delta) != 8L ||
    any(delta$authority_version != "v9") ||
    any(delta$authoritative_value >= delta$rendered_v6_value) ||
    any(delta$relative_gain_pct <= 0)) {
  stop("The cumulative article delta is not the approved eight-role update.",
       call. = FALSE)
}
delta_keys <- with(delta, paste(inference, model_variant, family,
                                sprintf("%.2f", tau), metric))
expected_delta_keys <- character()
for (metric in metric_columns) {
  changed <- which(abs(interface[[metric]] - article_base[[metric]]) > 1e-12)
  if (length(changed)) {
    expected_delta_keys <- c(expected_delta_keys, with(interface[changed, ], paste(
      inference, model_variant, family, sprintf("%.2f", tau), metric
    )))
  }
}
if (!setequal(delta_keys, expected_delta_keys)) {
  stop("The cumulative article delta is incomplete.", call. = FALSE)
}

if (nrow(chains) != 6L || anyDuplicated(chains$job_id) ||
    any(chains$status != "SUCCESS") ||
    !identical(as.integer(table(factor(
      chains$signoff_grade, levels = names(expected_signoffs)
    ))), unname(expected_signoffs)) ||
    any(!is.finite(as.numeric(unlist(chains[metric_columns], use.names = FALSE))))) {
  stop("The canonical chain evidence does not verify.", call. = FALSE)
}
chain_means <- aggregate(chains[metric_columns], by = list(
  target_cell_id = chains$target_cell_id,
  candidate_id = chains$candidate_id
), FUN = mean)
for (i in seq_len(nrow(decision_promoted))) {
  x <- chain_means[
    chain_means$target_cell_id == decision_promoted$target_cell_id[[i]] &
      chain_means$candidate_id == decision_promoted$candidate_id[[i]],
    , drop = FALSE
  ]
  if (nrow(x) != 1L ||
      abs(x[[decision_promoted$metric[[i]]]][[1L]] -
          decision_promoted$confirmation_value[[i]]) > 1e-12) {
    stop("A promoted value is not the arithmetic mean of its three chains.",
         call. = FALSE)
  }
}

if (nrow(specifications) != 2L ||
    !setequal(specifications$target_cell_id,
              c("al_normal_t0p05", "exal_gausmix_t0p50")) ||
    any(specifications$D != 1L) || any(specifications$n != 40L) ||
    any(specifications$m != 12L) ||
    any(abs(specifications$alpha - 0.08) > 1e-12) ||
    any(abs(specifications$rho - 0.35) > 1e-12) ||
    any(abs(specifications$rhs_tau0 - 1e-8) > 1e-20) ||
    any(specifications$effective_readout_dimension != 47L) ||
    specifications$inference_method_id[
      specifications$likelihood_target == "exal"
    ] != "m0_v_collapsed_support_logit") {
  stop("The promoted specification ledger is incomplete.", call. = FALSE)
}

if (nrow(rollback) != 4L ||
    any(rollback$promoted_value >= rollback$previous_value) ||
    !setequal(with(rollback, paste(inference, model_variant, family,
                                   sprintf("%.2f", tau), metric)),
              expected_effect_key)) {
  stop("The rollback ledger is incomplete.", call. = FALSE)
}

if (nrow(gaps) != 54L ||
    !all(c("authority_id", "relative_gap_pct", "forecast_priority",
           "next_action") %in% names(gaps)) ||
    any(gaps$authority_id != promotion_id)) {
  stop("The v9 remaining-gap ledger is incomplete.", call. = FALSE)
}

ledger_paths <- vapply(ledger$path, resolve, character(1L))
if (!all(c("source_id", "path", "sha256", "role") %in% names(ledger)) ||
    anyDuplicated(ledger$source_id) || any(grepl("^/", ledger$path)) ||
    any(!file.exists(ledger_paths)) ||
    !identical(unname(tools::sha256sum(ledger_paths)), unname(ledger$sha256))) {
  stop("The portable v9 source ledger is incomplete or stale.", call. = FALSE)
}
base_ledger_paths <- vapply(base_ledger$path, resolve, character(1L))
if (anyDuplicated(base_ledger$source_id) || any(!file.exists(base_ledger_paths)) ||
    !identical(unname(tools::sha256sum(base_ledger_paths)),
               unname(base_ledger$sha256))) {
  stop("The inherited v8 source ledger is stale.", call. = FALSE)
}

output_paths <- vapply(output_manifest$path, resolve, character(1L))
if (nrow(output_manifest) != 11L || any(!file.exists(output_paths)) ||
    !identical(unname(tools::sha256sum(output_paths)),
               unname(output_manifest$sha256))) {
  stop("The v9 output manifest is incomplete or stale.", call. = FALSE)
}

if (nrow(plan) != 6L || anyDuplicated(plan$job_id) ||
    !identical(sort(as.integer(table(plan$candidate_id))), c(3L, 3L))) {
  stop("The frozen canonical confirmation plan is incomplete.", call. = FALSE)
}
config_paths <- vapply(plan$config_path, resolve, character(1L))
if (any(!file.exists(config_paths)) ||
    !identical(unname(tools::sha256sum(config_paths)),
               unname(plan$config_sha256))) {
  stop("A frozen canonical config changed.", call. = FALSE)
}
config_ok <- vapply(seq_len(nrow(plan)), function(i) {
  x <- read_json(config_paths[[i]])
  method_ok <- if (plan$likelihood_target[[i]] == "exal") {
    identical(x$config$inference$mcmc$slice$core_update_mode,
              "m0_v_collapsed_support_logit")
  } else {
    identical(x$inference_method_id, "sigma_then_gamma")
  }
  method_ok && as.integer(x$config$inference$mcmc$n_burn) == 5000L &&
    as.integer(x$config$inference$mcmc$n_mcmc) == 20000L &&
    as.integer(x$config$cpp$postpred_threads) == 1L
}, logical(1L))
if (!all(config_ok)) {
  stop("A canonical config violates the execution contract.", call. = FALSE)
}

input_columns <- c(
  "source_series_wide_path", "source_selection_indices_path",
  "observed_path", "qtrue_path"
)
input_hash_columns <- c(
  "source_series_wide_sha256", "source_selection_indices_sha256",
  "observed_sha256", "qtrue_sha256"
)
if (nrow(windows) != 2L || any(grepl("^/", unlist(windows[input_columns]))) ||
    any(!startsWith(windows$source_sim_path, "sha256:"))) {
  stop("The frozen canonical windows are not portable.", call. = FALSE)
}
for (i in seq_len(nrow(windows))) {
  resolved_inputs <- vapply(windows[i, input_columns, drop = FALSE], resolve,
                            character(1L))
  if (any(!file.exists(resolved_inputs)) ||
      !identical(unname(tools::sha256sum(resolved_inputs)),
                 unname(as.character(windows[i, input_hash_columns])))) {
    stop("A frozen canonical input changed.", call. = FALSE)
  }
}

stage_counts <- c(smoke = 2L, calibration = 4L, screen = 128L,
                  refine = 36L, confirmation = 6L)
for (stage in names(stage_counts)) {
  verification_id <- paste0("canonical_gap_", stage, "_verification")
  runtime_id <- paste0("canonical_gap_", stage, "_runtime")
  verification_path <- ledger_paths[ledger$source_id == verification_id]
  runtime_path <- ledger_paths[ledger$source_id == runtime_id]
  if (length(verification_path) != 1L || length(runtime_path) != 1L ||
      !identical(read_json(verification_path)$decision, "PASS") ||
      nrow(read_csv(runtime_path)) != stage_counts[[stage]]) {
    stop(sprintf("The frozen %s stage evidence is incomplete.", stage),
         call. = FALSE)
  }
}

status_paths <- ledger_paths[
  ledger$role == "canonical_confirmation_job_evidence" &
    grepl("__job_status$", ledger$source_id)
]
signoff_paths <- ledger_paths[
  ledger$role == "canonical_confirmation_job_evidence" &
    grepl("__signoff$", ledger$source_id)
]
if (length(status_paths) != 6L || length(signoff_paths) != 6L) {
  stop("The v9 package lacks complete compact job evidence.", call. = FALSE)
}
status_ok <- vapply(status_paths, function(path) {
  x <- read_json(path)
  identical(x$status, "SUCCESS") && as.integer(x$binary_payloads_remaining) == 0L
}, logical(1L))
signoffs <- do.call(rbind, lapply(signoff_paths, read_csv))
if (!all(status_ok) || nrow(signoffs) != 6L ||
    !identical(as.integer(table(factor(
      signoffs$signoff_grade, levels = names(expected_signoffs)
    ))), unname(expected_signoffs))) {
  stop("The frozen status or diagnostic evidence does not verify.",
       call. = FALSE)
}

heavy <- list.files(promotion_dir, pattern = "[.](rds|rda|RData)$",
                    recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
all_files <- list.files(promotion_dir, recursive = TRUE, full.names = TRUE)
if (length(heavy) || any(file.info(all_files)$size > 10 * 1024^2)) {
  stop("The v9 promotion violates the storage-light contract.", call. = FALSE)
}

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=4\n")
cat("ARTICLE_DELTAS_FROM_RENDERED_V6=8\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_CONSUMPTION=PASS\nSTORAGE_POLICY=PASS\n")
