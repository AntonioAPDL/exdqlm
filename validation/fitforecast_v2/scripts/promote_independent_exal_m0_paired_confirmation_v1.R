#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE, digits = 17)

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("jsonlite is required.", call. = FALSE)
  }
})

script_path <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]),
  winslash = "/", mustWork = TRUE
)
repo_root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."),
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)

promotion_id <- "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
base_id <- "qdesn_dqlm_500obs_trainonly_article_v5_rolling_rebaseline_20260811"
run_id <- "independent_exal_m0_paired_confirmation_v1_full_20260811_0f0634e"
run_tag <- "ind-exal-m0-paired-confirm-v1-full-20260811__git-0f0634e"
execution_commit <- "0f0634e40b5d1e320b61ad7af1464beb56546fb3"
validation_branch <- "validation/independent-exal-m0-structural-screen-v2-1.0.0"
registry_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", base_id)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration", run_id)
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_independent_exal_m0_structural_screen_v2",
  run_tag
)
output_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                        promotion_id)

paths <- list(
  base_interface = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_manifest = file.path(base_dir, paste0(base_id, "_manifest.json")),
  base_ledger = file.path(base_dir, "source_ledger.csv"),
  run_env = file.path(state_root, "run.env"),
  runtime_verification = file.path(state_root, "runtime_verification.json"),
  confirmation_plan = file.path(state_root, "materialization", "confirmation_plan.csv"),
  materialization_manifest = file.path(
    state_root, "materialization", "materialization_manifest.json"
  ),
  source_registry = file.path(
    state_root, "materialization", "canonical_source_registry.csv"
  ),
  window_registry = file.path(
    state_root, "materialization", "canonical_window_registry.csv"
  ),
  closeout_manifest = file.path(
    state_root, "closeout", "paired_confirmation_closeout_manifest.json"
  ),
  chain_evidence = file.path(
    state_root, "closeout", "confirmation_chain_metric_evidence.csv"
  ),
  metric_summary = file.path(
    state_root, "closeout", "confirmation_metric_summary.csv"
  ),
  patch_review = file.path(
    state_root, "closeout", "article_metric_patch_review.csv"
  ),
  cell_summary = file.path(
    state_root, "closeout", "confirmation_cell_summary.csv"
  )
)

expected_base_hashes <- c(
  base_interface = "f9a2fbe2a791c28bb4d09a190888f90c6172270085d19627855150cfb3872f28",
  base_manifest = "9ce5667a4f38d220ed60d71cc1d96f47417d3cbebddee5b0a8e51d62d0e4e128",
  base_ledger = "00f58c5c20ac50fea256c433f66da213f2e440adc2f59d29af21f33f3a6bedf4"
)

sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
read_csv <- function(path) read.csv(path, check.names = FALSE,
                                    stringsAsFactors = FALSE)
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
read_json <- function(path) jsonlite::read_json(path, simplifyVector = TRUE)
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, na = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
copy_verified <- function(source, destination, expected_sha = sha256(source)) {
  if (!file.exists(source) || !identical(sha256(source), expected_sha)) {
    stop(sprintf("Source is missing or changed: %s", source), call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, destination, overwrite = FALSE)) {
    stop(sprintf("Could not freeze source: %s", source), call. = FALSE)
  }
  if (!identical(sha256(destination), expected_sha)) {
    stop(sprintf("Frozen source hash mismatch: %s", destination), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}

missing <- names(paths)[!file.exists(unlist(paths, use.names = FALSE))]
if (length(missing)) {
  stop(sprintf("Missing promotion inputs: %s", paste(missing, collapse = ", ")),
       call. = FALSE)
}
if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE,
                                                no.. = TRUE))) {
  stop(sprintf("Refusing to overwrite nonempty promotion directory: %s", output_dir),
       call. = FALSE)
}
branch <- system("git branch --show-current", intern = TRUE)
implementation_commit <- system("git rev-parse HEAD", intern = TRUE)
if (!identical(branch, validation_branch) ||
    length(system("git status --porcelain", intern = TRUE)) != 0L) {
  stop("Promotion requires the clean committed validation branch.", call. = FALSE)
}
for (name in names(expected_base_hashes)) {
  if (!identical(sha256(paths[[name]]), expected_base_hashes[[name]])) {
    stop(sprintf("Pinned v5 input changed: %s", name), call. = FALSE)
  }
}

base <- read_csv(paths$base_interface)
base_manifest <- read_json(paths$base_manifest)
base_ledger <- read_csv(paths$base_ledger)
closeout <- read_json(paths$closeout_manifest)
metric_summary <- read_csv(paths$metric_summary)
chains <- read_csv(paths$chain_evidence)
plan <- read_csv(paths$confirmation_plan)
runtime <- read_json(paths$runtime_verification)

ready_metrics <- c(
  "normal_t0p05/forecast_qtrue_mae_H1000",
  "normal_t0p05/forecast_check_loss_H1000"
)
observed_ready <- paste0(
  metric_summary$target_cell_id[as_bool(metric_summary$manual_metric_promotion_eligible)],
  "/",
  metric_summary$metric[as_bool(metric_summary$manual_metric_promotion_eligible)]
)
if (nrow(base) != 72L || nrow(plan) != 6L || nrow(chains) != 18L ||
    nrow(metric_summary) != 6L || !setequal(observed_ready, ready_metrics) ||
    !identical(closeout$decision,
               "CONFIRMATION_COMPLETE_METRIC_PROMOTION_REVIEW_REQUIRED") ||
    !identical(closeout$run_tag, run_tag) ||
    !identical(closeout$execution_commit, execution_commit) ||
    !identical(closeout$validation_commit, execution_commit) ||
    !grepl("^[0-9a-f]{40}$", closeout$closeout_commit) ||
    !isTRUE(closeout$all_job_execution_commits_match) ||
    !identical(closeout$source_registry_hash_value, registry_hash) ||
    !identical(runtime$decision, "PASS") ||
    as.integer(runtime$runtime_summary$success_jobs) != 6L ||
    as.integer(runtime$runtime_summary$finite_metric_rows) != 18L ||
    as.integer(runtime$runtime_summary$binary_payloads) != 0L ||
    any(chains$status != "SUCCESS") || any(chains$binary_payloads != 0L) ||
    any(chains$execution_commit != execution_commit) ||
    !identical(base_manifest$source_registry_hash_value, registry_hash)) {
  stop("Paired-confirmation evidence violates the frozen promotion contract.",
       call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
ledger_rows <- list()
add_ledger <- function(source_id, path, source_sha = sha256(path), role = "evidence") {
  ledger_rows[[length(ledger_rows) + 1L]] <<- data.frame(
    source_id = source_id, path = path, sha256 = source_sha, role = role,
    stringsAsFactors = FALSE
  )
}

add_ledger("base_v5_interface", paths$base_interface,
           expected_base_hashes[["base_interface"]], "inherited_authority")
add_ledger("base_v5_manifest", paths$base_manifest,
           expected_base_hashes[["base_manifest"]], "inherited_authority")
add_ledger("base_v5_source_ledger", paths$base_ledger,
           expected_base_hashes[["base_ledger"]], "inherited_authority")
for (i in seq_len(nrow(base_ledger))) {
  add_ledger(paste0("base_v5_", base_ledger$source_id[[i]]),
             base_ledger$path[[i]], base_ledger$sha256[[i]], "inherited_metric_source")
}

control_names <- c(
  "run_env", "runtime_verification", "materialization_manifest",
  "source_registry", "window_registry", "closeout_manifest", "metric_summary",
  "patch_review", "cell_summary"
)
frozen_control <- list()
for (name in control_names) {
  frozen_control[[name]] <- copy_verified(
    paths[[name]], file.path(output_dir, "evidence", "control", basename(paths[[name]]))
  )
  add_ledger(paste0("confirmation_", name), frozen_control[[name]],
             role = "paired_confirmation_control")
}

frozen_plan <- plan
for (i in seq_len(nrow(plan))) {
  frozen_config <- copy_verified(
    plan$config_path[[i]],
    file.path(output_dir, "evidence", "configs", basename(plan$config_path[[i]])),
    plan$config_sha256[[i]]
  )
  frozen_plan$config_path[[i]] <- frozen_config
  add_ledger(paste0("confirmation_config_", plan$job_id[[i]]), frozen_config,
             plan$config_sha256[[i]], "paired_confirmation_config")
}
frozen_plan_path <- write_csv(
  frozen_plan, file.path(output_dir, "evidence", "control", "confirmation_plan.csv")
)
add_ledger("confirmation_plan", frozen_plan_path, role = "paired_confirmation_control")

frozen_source_map <- new.env(parent = emptyenv())
for (i in seq_len(nrow(plan))) {
  job_id <- plan$job_id[[i]]
  job_root <- file.path(result_root, "jobs", job_id)
  job_files <- c(
    fit_request = file.path(job_root, "fit_request.json"),
    fit_summary = file.path(job_root, "fit_summary_row.csv"),
    job_status = file.path(job_root, "job_status.json"),
    signoff = file.path(job_root, "signoff_summary.csv"),
    rolling_paths = file.path(job_root, "tables", "forecast_rolling_origin_paths.csv")
  )
  if (any(!file.exists(job_files))) {
    stop(sprintf("Incomplete job evidence: %s", job_id), call. = FALSE)
  }
  fit_request <- read_json(job_files[["fit_request"]])
  job_status <- read_json(job_files[["job_status"]])
  if (!identical(fit_request$git_commit, execution_commit) ||
      !identical(job_status$status, "SUCCESS") ||
      as.integer(job_status$binary_payloads_remaining) != 0L) {
    stop(sprintf("Invalid execution evidence: %s", job_id), call. = FALSE)
  }
  for (name in names(job_files)) {
    frozen <- copy_verified(
      job_files[[name]],
      file.path(output_dir, "evidence", "jobs", job_id, basename(job_files[[name]]))
    )
    assign(normalizePath(job_files[[name]], winslash = "/", mustWork = TRUE),
           frozen, envir = frozen_source_map)
    add_ledger(paste0("confirmation_", job_id, "_", name), frozen,
               role = "paired_confirmation_job_evidence")
  }
}

frozen_chains <- chains
for (i in seq_len(nrow(frozen_chains))) {
  original <- normalizePath(frozen_chains$source_path[[i]], winslash = "/",
                            mustWork = TRUE)
  if (!exists(original, envir = frozen_source_map, inherits = FALSE)) {
    stop(sprintf("Metric source was not frozen: %s", original), call. = FALSE)
  }
  frozen_chains$source_path[[i]] <- get(original, envir = frozen_source_map,
                                        inherits = FALSE)
  if (!identical(sha256(frozen_chains$source_path[[i]]),
                 frozen_chains$source_sha256[[i]])) {
    stop("Frozen metric source hash mismatch.", call. = FALSE)
  }
}
frozen_chain_path <- write_csv(
  frozen_chains,
  file.path(output_dir, "evidence", "derived", "confirmation_chain_metric_evidence.csv")
)
add_ledger("confirmation_frozen_chain_metric_evidence", frozen_chain_path,
           role = "paired_confirmation_derived")

frozen_summary_path <- copy_verified(
  paths$metric_summary,
  file.path(output_dir, "evidence", "derived", "confirmation_metric_summary.csv")
)
frozen_summary_sha <- sha256(frozen_summary_path)
add_ledger("confirmation_metric_summary_article_source", frozen_summary_path,
           frozen_summary_sha, "article_metric_source")

article <- base
article$article_interface_id <- promotion_id
article$promotion_validation_branch <- validation_branch
article$promotion_validation_commit <- implementation_commit
article$rolling_evidence_promotion_id[grepl("^qdesn_", article$model_variant)] <-
  promotion_id
article$metric_estimator_contract <- "inherited_case_specific_metric_source"
article$confirmation_chain_count <- 0L
article$confirmation_execution_commit <- ""
article$confirmation_closeout_commit <- ""
article$confirmation_state <- "INHERITED_FROM_V5"

target <- article$inference == "mcmc" &
  article$model_variant == "qdesn_exal_rhs_ns" &
  article$family == "normal" & abs(article$tau - 0.05) < 1e-12
if (sum(target) != 1L) stop("The v5 target row is not unique.", call. = FALSE)
target_index <- which(target)
mae <- metric_summary[
  metric_summary$target_cell_id == "normal_t0p05" &
    metric_summary$metric == "forecast_qtrue_mae_H1000", , drop = FALSE
]
check <- metric_summary[
  metric_summary$target_cell_id == "normal_t0p05" &
    metric_summary$metric == "forecast_check_loss_H1000", , drop = FALSE
]
if (nrow(mae) != 1L || nrow(check) != 1L ||
    !as_bool(mae$manual_metric_promotion_eligible[[1L]]) ||
    !as_bool(check$manual_metric_promotion_eligible[[1L]])) {
  stop("The two predeclared promotion metrics are not eligible.", call. = FALSE)
}

article$forecast_qtrue_mae_H1000[[target_index]] <- mae$chain_mean[[1L]]
article$forecast_check_loss_H1000[[target_index]] <- check$chain_mean[[1L]]
article$metric_source_mixed[[target_index]] <- TRUE
article$signoff_grade[[target_index]] <- "WARN"
article$forecast_mae_source_candidate_id[[target_index]] <- mae$candidate_id[[1L]]
article$forecast_mae_source_run_tag[[target_index]] <- run_tag
article$forecast_mae_source_signoff_grade[[target_index]] <- "WARN"
article$forecast_mae_source_status[[target_index]] <- "SUCCESS"
article$forecast_mae_source_path[[target_index]] <- frozen_summary_path
article$forecast_mae_source_sha256[[target_index]] <- frozen_summary_sha
article$forecast_check_source_candidate_id[[target_index]] <- check$candidate_id[[1L]]
article$forecast_check_source_run_tag[[target_index]] <- run_tag
article$forecast_check_source_signoff_grade[[target_index]] <- "WARN"
article$forecast_check_source_status[[target_index]] <- "SUCCESS"
article$forecast_check_source_path[[target_index]] <- frozen_summary_path
article$forecast_check_source_sha256[[target_index]] <- frozen_summary_sha
article$validation_branch[[target_index]] <- validation_branch
article$validation_commit[[target_index]] <- execution_commit
article$validation_closeout_commit[[target_index]] <- closeout$closeout_commit
article$source_promotion_id[[target_index]] <- promotion_id
article$metric_estimator_contract[[target_index]] <-
  "fit_inherited_forecasts_mean_of_three_full_budget_mcmc_chains"
article$confirmation_chain_count[[target_index]] <- 3L
article$confirmation_execution_commit[[target_index]] <- execution_commit
article$confirmation_closeout_commit[[target_index]] <- closeout$closeout_commit
article$confirmation_state[[target_index]] <- "PAIRED_FULL_BUDGET_CONFIRMATION_V1"

metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(article[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 1L, 1L)) ||
    article$forecast_qtrue_mae_H1000[[target_index]] >=
      base$forecast_qtrue_mae_H1000[[target_index]] ||
    article$forecast_check_loss_H1000[[target_index]] >=
      base$forecast_check_loss_H1000[[target_index]] ||
    any(article$source_registry_hash_value != registry_hash) ||
    any(!as_bool(article$article_consumption_allowed)) ||
    any(grepl("ridge", article$model_variant))) {
  stop("The v6 interface changed more than the two approved metric roles.",
       call. = FALSE)
}

interface_path <- write_csv(
  article, file.path(output_dir, paste0(promotion_id, "_interface.csv"))
)

decision <- metric_summary
decision$promoted_to_v6 <- paste0(decision$target_cell_id, "/", decision$metric) %in%
  ready_metrics
decision$promoted_value <- ifelse(decision$promoted_to_v6,
                                  decision$chain_mean,
                                  decision$current_article_value)
decision_path <- write_csv(
  decision, file.path(output_dir, "promotion_decision_ledger.csv")
)

external <- article[article$inference == "mcmc" &
                      article$model_variant %in% c("dqlm", "exdqlm"), ]
qmodels <- article[article$inference == "mcmc" &
                     article$model_variant %in%
                       c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"), ]
gap_rows <- list()
k <- 0L
for (i in seq_len(nrow(qmodels))) {
  comparators <- external[external$family == qmodels$family[[i]] &
                            abs(external$tau - qmodels$tau[[i]]) < 1e-12, ]
  for (metric in metric_columns) {
    k <- k + 1L
    comparator <- min(comparators[[metric]])
    value <- qmodels[[metric]][[i]]
    ratio <- value / comparator
    gap_rows[[k]] <- data.frame(
      model_variant = qmodels$model_variant[[i]], family = qmodels$family[[i]],
      tau = qmodels$tau[[i]], metric = metric, value = value,
      best_dqlm_exdqlm_value = comparator, ratio_to_best_dqlm_exdqlm = ratio,
      relative_gap_pct = 100 * (ratio - 1),
      lower_tail_priority = qmodels$tau[[i]] <= 0.25 && ratio > 1.05,
      next_action = if (qmodels$tau[[i]] <= 0.25 && ratio > 1.05) {
        "TARGETED_CELL_METRIC_CALIBRATION"
      } else "RETAIN_CURRENT",
      stringsAsFactors = FALSE
    )
  }
}
gap_ledger <- do.call(rbind, gap_rows)
gap_ledger <- gap_ledger[order(
  !gap_ledger$lower_tail_priority, -gap_ledger$relative_gap_pct,
  gap_ledger$model_variant, gap_ledger$family, gap_ledger$tau
), ]
gap_path <- write_csv(gap_ledger, file.path(output_dir, "remaining_gap_ledger.csv"))

ledger <- unique(do.call(rbind, ledger_rows))
ledger <- ledger[order(ledger$source_id, ledger$path), ]
row.names(ledger) <- NULL
if (anyDuplicated(ledger$source_id) || any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("The v6 source ledger is incomplete or stale.", call. = FALSE)
}
ledger_path <- write_csv(ledger, file.path(output_dir, "source_ledger.csv"))

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_PAIRED_CONFIRMATION_V1",
  scientific_decision = "PROMOTE_TWO_NORMAL_P005_EXAL_FORECAST_CHAIN_MEANS",
  package_version = "1.0.0",
  method_id = "M0_v_collapsed_support_logit",
  source_registry_hash_name = "000__bundle_manifest.json.sha256",
  source_registry_hash_value = registry_hash,
  expected_rows = 72L,
  observed_rows = nrow(article),
  vb_rows = sum(article$inference == "vb"),
  mcmc_rows = sum(article$inference == "mcmc"),
  ridge_rows = sum(grepl("ridge", article$model_variant)),
  ridge_policy = base_manifest$ridge_policy,
  base_promotion_id = base_id,
  base_interface_sha256 = expected_base_hashes[["base_interface"]],
  validation_branch = validation_branch,
  execution_commit = execution_commit,
  closeout_commit = closeout$closeout_commit,
  promotion_implementation_commit = implementation_commit,
  execution_identity_source = closeout$execution_identity_source,
  run_id = run_id,
  run_tag = run_tag,
  jobs = 6L,
  chains = 6L,
  burn_iterations_per_chain = 5000L,
  retained_iterations_per_chain = 20000L,
  promoted_metric_roles = 2L,
  promoted_metrics = as.list(ready_metrics),
  promoted_estimator = "arithmetic_mean_of_three_full_budget_mcmc_chains",
  promotion_policy = paste(
    "three successful finite chains; mean and median each below frozen v5 value;",
    "diagnostics reported but not used as metric veto"
  ),
  unchanged_numeric_roles = nrow(article) * length(metric_columns) - 2L,
  forecast_protocol = "rolling_origin_no_refit_state_update",
  forecast_max_lead_configured = 30L,
  forecast_origin_stride = 30L,
  storage_policy_pass = TRUE,
  binary_payload_count = 0L,
  article_interface_path = interface_path,
  article_interface_sha256 = sha256(interface_path),
  promotion_decision_ledger_path = decision_path,
  promotion_decision_ledger_sha256 = sha256(decision_path),
  remaining_gap_ledger_path = gap_path,
  remaining_gap_ledger_sha256 = sha256(gap_path),
  source_ledger_path = ledger_path,
  source_ledger_sha256 = sha256(ledger_path),
  article_update_status = "READY_FOR_ARTICLE_REGENERATION",
  next_calibration_status = "PLANNED_NOT_LAUNCHED"
)
manifest_path <- write_json(
  manifest, file.path(output_dir, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Independent Q-DESN paired-confirmation promotion v1",
  "",
  "This immutable v6 handoff inherits the complete 72-row v5 authority and",
  "changes exactly two MCMC metric roles for Gaussian p=0.05 exQ-DESN RHS:",
  "forecast MAE and forecast check loss. Each promoted value is the arithmetic",
  "mean of three successful full-budget MCMC chains. Fit RMSE and every p=0.50",
  "metric remain unchanged.",
  "",
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Execution commit: `%s`", execution_commit),
  sprintf("- Closeout commit: `%s`", closeout$closeout_commit),
  sprintf("- Interface SHA-256: `%s`", manifest$article_interface_sha256),
  sprintf("- Source ledger SHA-256: `%s`", manifest$source_ledger_sha256),
  "- Binary payloads: 0",
  "- Further calibration: planned, not launched"
)
writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

artifact_paths <- c(interface_path, decision_path, gap_path, ledger_path,
                    manifest_path, file.path(output_dir, "README.md"))
artifact_manifest <- data.frame(
  path = normalizePath(artifact_paths, winslash = "/", mustWork = TRUE),
  bytes = file.info(artifact_paths)$size,
  sha256 = unname(tools::sha256sum(artifact_paths)),
  stringsAsFactors = FALSE
)
write_csv(artifact_manifest, file.path(output_dir, "output_file_manifest.csv"))

heavy <- list.files(output_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
if (length(heavy)) stop("The v6 promotion contains a forbidden binary payload.",
                        call. = FALSE)

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat(sprintf("INTERFACE_ROWS=%d\n", nrow(article)))
cat("PROMOTED_METRIC_ROLES=2\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_CONSUMPTION=READY\n")
cat("STORAGE_POLICY=PASS\n")
