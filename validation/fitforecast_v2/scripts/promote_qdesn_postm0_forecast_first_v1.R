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
  "qdesn_dqlm_500obs_trainonly_article_v7_postm0_forecast_20260818"
base_id <-
  "qdesn_dqlm_500obs_trainonly_article_v6_paired_confirmation_20260811"
run_id <- "qdesn_postm0_legacy_recheck_v1_20260814_prod1"
run_tag <- "qdesn-postm0-legacy-recheck-v1-20260814-prod1__git-9db909c"
validation_branch <- "validation/qdesn-postm0-legacy-recheck-v1-1.0.0"
execution_commit <- "5d683342bdcb253ce6f470e1346f78b0b67f7898"
registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
candidate_id <- "plrv1_exal_gausmix_t0p25_08_576957a0bd"
target_cell_id <- "exal_gausmix_t0p25"
promoted_metrics <- c(
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)

base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
                        run_id)
confirmation_root <- file.path(state_root, "forecast_first_confirmation")
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_postm0_legacy_recheck_v1", run_tag
)
output_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                        promotion_id)

paths <- list(
  base_interface = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_manifest = file.path(base_dir, paste0(base_id, "_manifest.json")),
  base_ledger = file.path(base_dir, "source_ledger.csv"),
  plan = file.path(confirmation_root, "confirmation_plan.csv"),
  materialization = file.path(
    confirmation_root, "confirmation_materialization_manifest.json"
  ),
  source_registry = file.path(confirmation_root, "canonical_source_registry.csv"),
  window_registry = file.path(confirmation_root, "canonical_window_registry.csv"),
  chain_metrics = file.path(confirmation_root, "confirmation_chain_metrics.csv"),
  lead_metrics = file.path(confirmation_root, "confirmation_lead_metrics.csv"),
  decision = file.path(confirmation_root, "confirmation_promotion_ledger.csv"),
  closeout = file.path(confirmation_root, "confirmation_closeout.json"),
  artifact_manifest = file.path(
    confirmation_root, "confirmation_artifact_manifest.csv"
  ),
  verification = file.path(state_root, "forecast_first_confirmation_verification.json"),
  verification_runtime = file.path(
    state_root, "forecast_first_confirmation_verification_runtime.csv"
  ),
  health = file.path(state_root, "forecast_first_confirmation_health.csv")
)
base_hashes <- c(
  base_interface =
    "d269be9219d969908b63ef818398ce31387dcaf1bc929e74b39e383f99661fb3",
  base_manifest =
    "e11dd70df84f0af781b41533c271b323333d895735d993f7a86959ef51efdbf0",
  base_ledger =
    "cd7b0159f98943c98c1f669cebaf38862c60af9eaea31b68cdbc6eee39594c96"
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
as_bool <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  tolower(as.character(x)) %in% c("true", "t", "1", "yes")
}
copy_verified <- function(source, destination, expected = sha256(source)) {
  if (!file.exists(source) || !identical(sha256(source), expected)) {
    stop(sprintf("Missing or changed source: %s", source), call. = FALSE)
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(source, destination, overwrite = FALSE) ||
      !identical(sha256(destination), expected)) {
    stop(sprintf("Could not freeze source: %s", source), call. = FALSE)
  }
  normalizePath(destination, winslash = "/", mustWork = TRUE)
}

missing <- names(paths)[!file.exists(unlist(paths, use.names = FALSE))]
if (length(missing)) {
  stop(sprintf("Missing promotion inputs: %s", paste(missing, collapse = ", ")),
       call. = FALSE)
}
if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE,
                                                no.. = TRUE))) {
  stop(sprintf("Refusing to overwrite: %s", output_dir), call. = FALSE)
}
branch <- system("git branch --show-current", intern = TRUE)
implementation_commit <- system("git rev-parse HEAD", intern = TRUE)
if (!identical(branch, validation_branch) ||
    length(system("git status --porcelain", intern = TRUE))) {
  stop("Promotion requires a clean committed task branch.", call. = FALSE)
}
for (name in names(base_hashes)) {
  if (!identical(sha256(paths[[name]]), base_hashes[[name]])) {
    stop(sprintf("Frozen v6 input changed: %s", name), call. = FALSE)
  }
}

base <- read_csv(paths$base_interface)
base_manifest <- read_json(paths$base_manifest)
base_ledger <- read_csv(paths$base_ledger)
plan <- read_csv(paths$plan)
chains <- read_csv(paths$chain_metrics)
decision <- read_csv(paths$decision)
closeout <- read_json(paths$closeout)
verification <- read_json(paths$verification)
runtime <- read_csv(paths$verification_runtime)

target <- base$inference == "mcmc" &
  base$model_variant == "qdesn_exal_rhs_ns" & base$family == "gausmix" &
  abs(base$tau - 0.25) < 1e-12
if (nrow(base) != 72L || sum(target) != 1L || nrow(plan) != 3L ||
    nrow(chains) != 3L || nrow(decision) != 2L ||
    !setequal(decision$metric, promoted_metrics) ||
    any(!as_bool(decision$promote)) || any(!as_bool(decision$execution_valid)) ||
    any(decision$chains != 3L) || any(decision$chains_improved != 3L) ||
    any(as_bool(decision$diagnostics_used_as_promotion_gate)) ||
    any(chains$status != "SUCCESS") || any(chains$candidate_id != candidate_id) ||
    any(chains$target_cell_id != target_cell_id) ||
    !identical(sort(as.integer(chains$chain_id)), 1:3) ||
    !identical(closeout$decision,
               "CONFIRMED_FORECAST_GAIN_READY_FOR_METRIC_SPECIFIC_PROMOTION") ||
    as.integer(closeout$promoted_metrics) != 2L ||
    !setequal(unname(closeout$promoted_metric_names), promoted_metrics) ||
    isTRUE(closeout$diagnostics_used_as_promotion_gate) ||
    !identical(verification$decision, "PASS") || nrow(runtime) != 3L ||
    any(runtime$status != "SUCCESS") || any(!as_bool(runtime$metric_finite)) ||
    any(runtime$binary_count != 0L) ||
    !identical(base_manifest$source_registry_hash_value, registry_hash)) {
  stop("Forecast-first evidence violates the promotion contract.", call. = FALSE)
}
for (metric in promoted_metrics) {
  row <- decision[decision$metric == metric, , drop = FALSE]
  observed <- mean(chains[[metric]])
  if (nrow(row) != 1L || abs(row$mean_value[[1L]] - observed) > 1e-12 ||
      row$mean_value[[1L]] >= base[[metric]][target]) {
    stop(sprintf("Metric is not a strict confirmed gain: %s", metric),
         call. = FALSE)
  }
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
ledger_rows <- list()
add_ledger <- function(source_id, path, source_sha = sha256(path), role) {
  ledger_rows[[length(ledger_rows) + 1L]] <<- data.frame(
    source_id = source_id, path = normalizePath(path, winslash = "/",
                                                mustWork = TRUE),
    sha256 = source_sha, role = role, stringsAsFactors = FALSE
  )
}
add_ledger("base_v6_interface", paths$base_interface,
           base_hashes[["base_interface"]], "inherited_authority")
add_ledger("base_v6_manifest", paths$base_manifest,
           base_hashes[["base_manifest"]], "inherited_authority")
add_ledger("base_v6_source_ledger", paths$base_ledger,
           base_hashes[["base_ledger"]], "inherited_authority")
for (i in seq_len(nrow(base_ledger))) {
  add_ledger(paste0("base_v6_", base_ledger$source_id[[i]]),
             base_ledger$path[[i]], base_ledger$sha256[[i]],
             "inherited_metric_source")
}

frozen <- list()
for (name in names(paths)[!grepl("^base_", names(paths))]) {
  frozen[[name]] <- copy_verified(
    paths[[name]], file.path(output_dir, "evidence", "control",
                             basename(paths[[name]]))
  )
  add_ledger(paste0("postm0_", name), frozen[[name]], role =
               if (name == "decision") "article_metric_source" else
                 "postm0_confirmation_control")
}

frozen_plan <- plan
for (i in seq_len(nrow(plan))) {
  config <- read_json(plan$config_path[[i]])
  if (!identical(config$config$inference$mcmc$slice$core_update_mode,
                 "m0_v_collapsed_support_logit") ||
      as.integer(config$config$inference$mcmc$n_burn) != 5000L ||
      as.integer(config$config$inference$mcmc$n_mcmc) != 20000L ||
      !identical(sha256(plan$config_path[[i]]), plan$config_sha256[[i]])) {
    stop(sprintf("Invalid canonical config: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  frozen_config <- copy_verified(
    plan$config_path[[i]],
    file.path(output_dir, "evidence", "configs", basename(plan$config_path[[i]])),
    plan$config_sha256[[i]]
  )
  frozen_plan$config_path[[i]] <- frozen_config
  add_ledger(paste0("postm0_config_", plan$job_id[[i]]), frozen_config,
             plan$config_sha256[[i]], "postm0_confirmation_config")

  job_root <- file.path(result_root, "jobs", plan$job_id[[i]])
  job_files <- c(
    job_started = file.path(job_root, "job_started.json"),
    fit_request = file.path(job_root, "fit_request.json"),
    fit_summary = file.path(job_root, "fit_summary_row.csv"),
    job_status = file.path(job_root, "job_status.json"),
    signoff = file.path(job_root, "signoff_summary.csv"),
    chain_summary = file.path(job_root, "chain_summary.csv"),
    health_summary = file.path(job_root, "health_summary.csv"),
    forecast_summary = file.path(job_root, "tables", "forecast_horizon_summary.csv"),
    lead_metrics = file.path(job_root, "tables", "forecast_lead_metrics.csv"),
    run_manifest = file.path(job_root, "manifest", "run_manifest.json"),
    retention = file.path(job_root, "manifest", "output_retention.json")
  )
  if (any(!file.exists(job_files))) {
    stop(sprintf("Incomplete job evidence: %s", plan$job_id[[i]]), call. = FALSE)
  }
  started <- read_json(job_files[["job_started"]])
  request <- read_json(job_files[["fit_request"]])
  status <- read_json(job_files[["job_status"]])
  if (!identical(started$git_commit, execution_commit) ||
      !identical(request$execution$launch_commit, execution_commit) ||
      !identical(status$status, "SUCCESS") ||
      as.integer(status$binary_payloads_remaining) != 0L ||
      !identical(status$config_sha256, plan$config_sha256[[i]])) {
    stop(sprintf("Invalid execution evidence: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  for (file_name in names(job_files)) {
    frozen_job <- copy_verified(
      job_files[[file_name]],
      file.path(output_dir, "evidence", "jobs", plan$job_id[[i]],
                basename(job_files[[file_name]]))
    )
    add_ledger(paste0("postm0_", plan$job_id[[i]], "_", file_name),
               frozen_job, role = "postm0_confirmation_job_evidence")
  }
}
frozen_plan_path <- write_csv(
  frozen_plan, file.path(output_dir, "evidence", "control",
                         "frozen_confirmation_plan.csv")
)
add_ledger("postm0_frozen_confirmation_plan", frozen_plan_path,
           role = "postm0_confirmation_control")

article <- base
article$article_interface_id <- promotion_id
article$promotion_validation_branch <- validation_branch
article$promotion_validation_commit <- implementation_commit
article$rolling_evidence_promotion_id[
  grepl("^qdesn_", article$model_variant)
] <- promotion_id
target_index <- which(target)
for (metric in promoted_metrics) {
  metric_row <- decision[decision$metric == metric, , drop = FALSE]
  article[[metric]][[target_index]] <- metric_row$mean_value[[1L]]
}
metric_source_sha <- sha256(frozen$decision)
article$metric_source_mixed[[target_index]] <- TRUE
article$signoff_grade[[target_index]] <- "FAIL"
article$forecast_mae_source_candidate_id[[target_index]] <- candidate_id
article$forecast_mae_source_run_tag[[target_index]] <- run_tag
article$forecast_mae_source_signoff_grade[[target_index]] <- "FAIL"
article$forecast_mae_source_status[[target_index]] <- "SUCCESS"
article$forecast_mae_source_path[[target_index]] <- frozen$decision
article$forecast_mae_source_sha256[[target_index]] <- metric_source_sha
article$forecast_check_source_candidate_id[[target_index]] <- candidate_id
article$forecast_check_source_run_tag[[target_index]] <- run_tag
article$forecast_check_source_signoff_grade[[target_index]] <- "FAIL"
article$forecast_check_source_status[[target_index]] <- "SUCCESS"
article$forecast_check_source_path[[target_index]] <- frozen$decision
article$forecast_check_source_sha256[[target_index]] <- metric_source_sha
article$validation_branch[[target_index]] <- validation_branch
article$validation_commit[[target_index]] <- execution_commit
article$validation_closeout_commit[[target_index]] <- implementation_commit
article$source_promotion_id[[target_index]] <- promotion_id
article$metric_estimator_contract[[target_index]] <-
  "fit_inherited_forecasts_mean_of_three_full_budget_mcmc_chains"
article$confirmation_chain_count[[target_index]] <- 3L
article$confirmation_execution_commit[[target_index]] <- execution_commit
article$confirmation_closeout_commit[[target_index]] <- implementation_commit
article$confirmation_state[[target_index]] <-
  "POSTM0_FORECAST_FIRST_CONFIRMATION_V1"

metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(article[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 1L, 1L)) ||
    any(!as_bool(article$article_consumption_allowed)) ||
    any(article$source_registry_hash_value != registry_hash) ||
    any(grepl("ridge", article$model_variant))) {
  stop("The v7 interface changed outside the two forecast roles.", call. = FALSE)
}
interface_path <- write_csv(
  article, file.path(output_dir, paste0(promotion_id, "_interface.csv"))
)

decision$promoted_to_v7 <- as_bool(decision$promote)
decision$promoted_value <- ifelse(decision$promoted_to_v7,
                                  decision$mean_value, decision$current_value)
decision_path <- write_csv(decision, file.path(output_dir,
                                               "promotion_decision_ledger.csv"))

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
      forecast_priority = grepl("^forecast_", metric) && ratio > 1,
      next_action = if (grepl("^forecast_", metric) && ratio > 1) {
        "TARGETED_FORECAST_CALIBRATION"
      } else "RETAIN_CURRENT",
      stringsAsFactors = FALSE
    )
  }
}
gaps <- do.call(rbind, gap_rows)
gaps <- gaps[order(!gaps$forecast_priority, -gaps$relative_gap_pct,
                   gaps$model_variant, gaps$family, gaps$tau), ]
gap_path <- write_csv(gaps, file.path(output_dir, "remaining_gap_ledger.csv"))

ledger <- unique(do.call(rbind, ledger_rows))
ledger <- ledger[order(ledger$source_id, ledger$path), ]
row.names(ledger) <- NULL
if (anyDuplicated(ledger$source_id) || any(!file.exists(ledger$path)) ||
    !identical(unname(tools::sha256sum(ledger$path)), unname(ledger$sha256))) {
  stop("The v7 source ledger is incomplete or stale.", call. = FALSE)
}
ledger_path <- write_csv(ledger, file.path(output_dir, "source_ledger.csv"))

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_POSTM0_FORECAST_CONFIRMATION_V1",
  scientific_decision =
    "PROMOTE_GAUSMIX_P025_EXAL_TWO_FORECAST_CHAIN_MEANS",
  package_version = "1.0.0", method_id = "M0_v_collapsed_support_logit",
  source_registry_hash_value = registry_hash,
  expected_rows = 72L, observed_rows = nrow(article),
  base_promotion_id = base_id,
  base_interface_sha256 = base_hashes[["base_interface"]],
  validation_branch = validation_branch,
  execution_commit = execution_commit,
  closeout_implementation_commit = implementation_commit,
  run_id = run_id, run_tag = run_tag,
  target_cell_id = target_cell_id, candidate_id = candidate_id,
  jobs = 3L, chains = 3L, burn_iterations_per_chain = 5000L,
  retained_iterations_per_chain = 20000L,
  promoted_metric_roles = 2L,
  promoted_metrics = as.list(promoted_metrics),
  promoted_estimator = "arithmetic_mean_of_three_full_budget_mcmc_chains",
  promotion_primary_metric = "forecast_qtrue_mae_H1000",
  promotion_policy = paste(
    "strict finite three-chain mean below frozen v6 for each forecast metric;",
    "diagnostics retained but not used as a promotion gate"
  ),
  fit_metric_policy = "retain_v6_fit_rmse_no_confirmed_improvement",
  diagnostics_used_as_promotion_gate = FALSE,
  observed_signoff_grades = as.list(sort(unique(chains$signoff_grade))),
  unchanged_numeric_roles = nrow(article) * length(metric_columns) - 2L,
  forecast_protocol = "rolling_origin_no_refit_state_update",
  forecast_max_lead_configured = 30L, forecast_origin_stride = 30L,
  binary_payload_count = 0L, storage_policy_pass = TRUE,
  article_interface_path = interface_path,
  article_interface_sha256 = sha256(interface_path),
  promotion_decision_ledger_path = decision_path,
  promotion_decision_ledger_sha256 = sha256(decision_path),
  remaining_gap_ledger_path = gap_path,
  remaining_gap_ledger_sha256 = sha256(gap_path),
  source_ledger_path = ledger_path,
  source_ledger_sha256 = sha256(ledger_path),
  article_update_status = "READY_FOR_INTEGRATION_NO_DIRECT_ARTICLE_WRITE"
)
manifest_path <- write_json(
  manifest, file.path(output_dir, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Independent Q-DESN post-M0 forecast promotion v1",
  "",
  "This immutable v7 handoff inherits the complete 72-row v6 authority and",
  "changes exactly two MCMC forecast roles for Gaussian-mixture p=0.25",
  "exQ-DESN RHS. Both values are arithmetic means of three successful",
  "full-budget exact-M0 chains. Fit RMSE is inherited unchanged from v6.",
  "",
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Execution commit: `%s`", execution_commit),
  sprintf("- Closeout implementation commit: `%s`", implementation_commit),
  sprintf("- Forecast MAE: %.15g -> %.15g", base$forecast_qtrue_mae_H1000[target],
          article$forecast_qtrue_mae_H1000[target]),
  sprintf("- Forecast check loss: %.15g -> %.15g",
          base$forecast_check_loss_H1000[target],
          article$forecast_check_loss_H1000[target]),
  "- Diagnostics: retained as descriptive evidence; not a promotion gate",
  "- Fitted-model binary payloads: 0",
  "- Article publication: delegated to the integration lane"
)
writeLines(readme, file.path(output_dir, "README.md"), useBytes = TRUE)

artifact_paths <- c(interface_path, decision_path, gap_path, ledger_path,
                    manifest_path, file.path(output_dir, "README.md"))
artifact_manifest <- data.frame(
  path = normalizePath(artifact_paths, winslash = "/", mustWork = TRUE),
  bytes = file.info(artifact_paths)$size,
  sha256 = unname(tools::sha256sum(artifact_paths)), stringsAsFactors = FALSE
)
write_csv(artifact_manifest, file.path(output_dir, "output_file_manifest.csv"))

heavy <- list.files(output_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
if (length(heavy)) stop("The v7 promotion contains a binary payload.")

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=2\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_INTEGRATION=READY\nSTORAGE_POLICY=PASS\n")
