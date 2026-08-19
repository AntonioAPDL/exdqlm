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
run_id <- "qdesn_forecast_gap_adaptive_mcmc_v1_20260818_214229"
run_tag <- "qdesn-forecast-gap-adaptive-v1-20260818_214229__git-e842a64"
validation_branch <-
  "validation/qdesn-forecast-gap-adaptive-mcmc-v1-1.0.0"
scientific_design_commit <- "e842a6438839a7f70345dc7df1c448f887e5eeed"
confirmation_execution_commit <- "a17b16836efc21393b2000202206a3edf67617ae"
registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
article_base_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", article_base_id
)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
                        run_id)
confirmation_root <- file.path(state_root, "confirmation")
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1",
  run_tag
)
output_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                        promotion_id)
target_path <- file.path(
  repo_root, "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_target_cells.csv"
)

paths <- list(
  base_interface = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_manifest = file.path(base_dir, paste0(base_id, "_manifest.json")),
  base_ledger = file.path(base_dir, "source_ledger.csv"),
  article_base_interface = file.path(
    article_base_dir, paste0(article_base_id, "_interface.csv")
  ),
  target_cells = target_path,
  plan = file.path(confirmation_root, "confirmation_plan.csv"),
  materialization = file.path(
    confirmation_root, "confirmation_materialization_manifest.json"
  ),
  source_registry = file.path(confirmation_root, "canonical_source_registry.csv"),
  window_registry = file.path(confirmation_root, "canonical_window_registry.csv"),
  metric_map = file.path(confirmation_root, "confirmation_metric_map.csv"),
  chain_metrics = file.path(confirmation_root, "confirmation_chain_metrics.csv"),
  decision = file.path(confirmation_root, "confirmation_promotion_ledger.csv"),
  closeout = file.path(confirmation_root, "confirmation_closeout.json"),
  verification = file.path(state_root, "confirmation_verification.json"),
  verification_runtime = file.path(
    state_root, "confirmation_verification_runtime.csv"
  ),
  recovery_closeout = file.path(
    state_root, "confirmation_resume_closeout_20260819_033312.json"
  ),
  sealed_eligible = file.path(
    state_root, "adaptive", "sealed_eligible_metrics.csv"
  ),
  stage_status = file.path(state_root, "stage_status.csv"),
  run_tags = file.path(state_root, "run_tags.env")
)
base_hashes <- c(
  base_interface =
    "362a27fbd91ee18ae07b0b238e20cf1488892238103ac8fc5e8eee7dc3e8d325",
  base_manifest =
    "9876be4496961321d6d4d703799d1073ed18b90e1a5826ae753cb936bb318c9d",
  base_ledger =
    "a238bfac83d90f142ee7c62bf7d729d7e8baad17b9ff729e9a2822a410d8187f"
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
repo_relative <- function(path) {
  normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
  prefix <- paste0(repo_root, "/")
  if (startsWith(normalized, prefix)) substring(normalized, nchar(prefix) + 1L) else
    normalized
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
git_is_ancestor <- function(commit) {
  status <- system2("git", c("merge-base", "--is-ancestor", commit, "HEAD"),
                    stdout = FALSE, stderr = FALSE)
  identical(status, 0L)
}
worst_grade <- function(x) {
  order <- c(MISSING = 4L, FAIL = 3L, WARN = 2L, PASS = 1L)
  x <- toupper(as.character(x))
  x[!x %in% names(order)] <- "MISSING"
  x[[which.max(unname(order[x]))]]
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
    length(system("git status --porcelain", intern = TRUE)) ||
    !git_is_ancestor(scientific_design_commit) ||
    !git_is_ancestor(confirmation_execution_commit)) {
  stop("Promotion requires the clean committed recovery branch and lineage.",
       call. = FALSE)
}
for (name in names(base_hashes)) {
  if (!identical(sha256(paths[[name]]), base_hashes[[name]])) {
    stop(sprintf("Frozen v7 input changed: %s", name), call. = FALSE)
  }
}

base <- read_csv(paths$base_interface)
article_base <- read_csv(paths$article_base_interface)
base_manifest <- read_json(paths$base_manifest)
targets <- read_csv(paths$target_cells)
plan <- read_csv(paths$plan)
materialization <- read_json(paths$materialization)
windows <- read_csv(paths$window_registry)
metric_map <- read_csv(paths$metric_map)
chains <- read_csv(paths$chain_metrics)
decision <- read_csv(paths$decision)
closeout <- read_json(paths$closeout)
verification <- read_json(paths$verification)
runtime <- read_csv(paths$verification_runtime)
recovery <- read_json(paths$recovery_closeout)

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
promoted <- decision[as_bool(decision$promote), , drop = FALSE]
if (nrow(base) != 72L || nrow(article_base) != 72L || nrow(plan) != 24L ||
    nrow(metric_map) != 11L || nrow(chains) != 33L || nrow(decision) != 11L ||
    nrow(runtime) != 24L || nrow(promoted) != 3L ||
    !setequal(promotion_key(promoted), promotion_key(expected_promotions)) ||
    any(promoted$chains != 3L) || any(promoted$chains_improved != 3L) ||
    any(!as_bool(promoted$all_finite)) || any(!as_bool(promoted$all_success)) ||
    any(promoted$mean_value >= promoted$current_value) ||
    any(chains$status != "SUCCESS") || any(chains$diagnostic_status == "MISSING") ||
    !setequal(unique(chains$diagnostic_status), c("PASS", "WARN")) ||
    !identical(closeout$decision,
               "CONFIRMED_FORECAST_GAINS_READY_FOR_INTEGRATION") ||
    as.integer(closeout$promoted_metrics) != 3L ||
    isTRUE(closeout$diagnostics_used_as_promotion_veto) ||
    !identical(verification$decision, "PASS") ||
    any(runtime$status != "SUCCESS") || any(!as_bool(runtime$metric_finite)) ||
    any(runtime$binary_count != 0L) ||
    !identical(recovery$integration_status, "READY_FOR_INTEGRATION") ||
    as.integer(recovery$prior_jobs_preserved) != 354L ||
    as.integer(recovery$confirmation_jobs_completed) != 24L ||
    !identical(materialization$validation_commit, scientific_design_commit) ||
    as.integer(materialization$confirmation_jobs) != 24L ||
    !identical(base_manifest$source_registry_hash_value, registry_hash)) {
  stop("Forecast-gap evidence violates the v8 promotion contract.",
       call. = FALSE)
}

for (i in seq_len(nrow(metric_map))) {
  target <- targets[targets$target_cell_id == metric_map$target_cell_id[[i]], ]
  model_variant <- if (target$likelihood[[1L]] == "exal") {
    "qdesn_exal_rhs_ns"
  } else "qdesn_al_rhs_ns"
  base_row <- base[
    base$inference == "mcmc" &
      base$model_variant == model_variant &
      base$family == target$family[[1L]] &
      abs(base$tau - target$tau[[1L]]) < 1e-12,
    , drop = FALSE
  ]
  if (nrow(target) != 1L || nrow(base_row) != 1L ||
      abs(base_row[[metric_map$metric[[i]]]][[1L]] -
          metric_map$current_value[[i]]) > 1e-12) {
    stop("The confirmation map is not anchored to the exact v7 authority.",
         call. = FALSE)
  }
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
ledger_rows <- list()
add_ledger <- function(source_id, path, source_sha = sha256(path), role) {
  ledger_rows[[length(ledger_rows) + 1L]] <<- data.frame(
    source_id = source_id, path = repo_relative(path), sha256 = source_sha,
    role = role, stringsAsFactors = FALSE
  )
}
add_ledger("base_v7_interface", paths$base_interface,
           base_hashes[["base_interface"]], "inherited_authority")
add_ledger("base_v7_manifest", paths$base_manifest,
           base_hashes[["base_manifest"]], "inherited_authority")
add_ledger("base_v7_source_ledger", paths$base_ledger,
           base_hashes[["base_ledger"]], "inherited_authority")
add_ledger("article_rendered_v6_interface", paths$article_base_interface,
           role = "article_delta_baseline")
add_ledger("campaign_target_cells", paths$target_cells,
           role = "campaign_design")

frozen <- list()
control_names <- setdiff(names(paths), c(
  "base_interface", "base_manifest", "base_ledger", "article_base_interface",
  "target_cells"
))
for (name in control_names) {
  frozen[[name]] <- copy_verified(
    paths[[name]], file.path(output_dir, "evidence", "control",
                             basename(paths[[name]]))
  )
  add_ledger(paste0("fgav1_", name), frozen[[name]], role =
               if (name == "decision") "article_metric_source" else
                 "confirmation_control")
}

frozen_windows <- windows
input_columns <- c(
  series_wide = "source_series_wide_path",
  selection_indices = "source_selection_indices_path",
  observed = "observed_path",
  q_true = "qtrue_path"
)
input_hash_columns <- c(
  series_wide = "source_series_wide_sha256",
  selection_indices = "source_selection_indices_sha256",
  observed = "observed_sha256",
  q_true = "qtrue_sha256"
)
for (i in seq_len(nrow(windows))) {
  for (name in names(input_columns)) {
    source <- windows[[input_columns[[name]]]][[i]]
    expected <- windows[[input_hash_columns[[name]]]][[i]]
    destination <- file.path(
      output_dir, "evidence", "inputs", windows$target_cell_id[[i]],
      windows$candidate_id[[i]], paste0(name, ".csv")
    )
    copied <- copy_verified(source, destination, expected)
    frozen_windows[[input_columns[[name]]]][[i]] <- repo_relative(copied)
    add_ledger(
      paste("fgav1_input", windows$target_cell_id[[i]],
            windows$candidate_id[[i]], name, sep = "__"),
      copied, expected, "canonical_confirmation_input"
    )
  }
}
frozen_window_path <- write_csv(
  frozen_windows, file.path(output_dir, "evidence", "control",
                            "frozen_canonical_window_registry.csv")
)
add_ledger("fgav1_frozen_window_registry", frozen_window_path,
           role = "portable_confirmation_control")

frozen_plan <- plan
job_evidence_names <- c(
  job_started = "job_started.json",
  fit_request = "fit_request.json",
  fit_summary = "fit_summary_row.csv",
  job_status = "job_status.json",
  signoff = "signoff_summary.csv",
  chain_summary = "chain_summary.csv",
  health_summary = "health_summary.csv",
  forecast_summary = file.path("tables", "forecast_horizon_summary.csv"),
  lead_metrics = file.path("tables", "forecast_lead_metrics.csv"),
  timing_summary = file.path("tables", "timing_summary.csv"),
  rhs_summary = file.path("models", "rhs_run_summary.csv"),
  run_manifest = file.path("manifest", "run_manifest.json"),
  retention = file.path("manifest", "output_retention.json")
)
for (i in seq_len(nrow(plan))) {
  config <- read_json(plan$config_path[[i]])
  likelihood <- plan$likelihood_target[[i]]
  if (as.integer(config$config$inference$mcmc$n_burn) != 5000L ||
      as.integer(config$config$inference$mcmc$n_mcmc) != 20000L ||
      as.integer(config$config$cpp$postpred_threads) != 1L ||
      (likelihood == "exal" &&
       !identical(config$config$inference$mcmc$slice$core_update_mode,
                  "m0_v_collapsed_support_logit")) ||
      (likelihood == "al" &&
       !identical(config$inference_method_id, "sigma_then_gamma")) ||
      !identical(sha256(plan$config_path[[i]]), plan$config_sha256[[i]])) {
    stop(sprintf("Invalid canonical config: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  frozen_config <- copy_verified(
    plan$config_path[[i]],
    file.path(output_dir, "evidence", "configs", basename(plan$config_path[[i]])),
    plan$config_sha256[[i]]
  )
  frozen_plan$config_path[[i]] <- repo_relative(frozen_config)
  add_ledger(paste0("fgav1_config__", plan$job_id[[i]]), frozen_config,
             plan$config_sha256[[i]], "confirmation_config")

  job_root <- file.path(result_root, "jobs", plan$job_id[[i]])
  job_files <- file.path(job_root, unname(job_evidence_names))
  names(job_files) <- names(job_evidence_names)
  if (any(!file.exists(job_files))) {
    stop(sprintf("Incomplete job evidence: %s", plan$job_id[[i]]), call. = FALSE)
  }
  started <- read_json(job_files[["job_started"]])
  request <- read_json(job_files[["fit_request"]])
  status <- read_json(job_files[["job_status"]])
  signoff <- read_csv(job_files[["signoff"]])
  if (!identical(started$git_commit, confirmation_execution_commit) ||
      !identical(request$execution$launch_commit, confirmation_execution_commit) ||
      !identical(status$status, "SUCCESS") ||
      as.integer(status$binary_payloads_remaining) != 0L ||
      !identical(status$config_sha256, plan$config_sha256[[i]]) ||
      nrow(signoff) != 1L ||
      !signoff$signoff_grade[[1L]] %in% c("PASS", "WARN")) {
    stop(sprintf("Invalid execution evidence: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  for (file_name in names(job_files)) {
    frozen_job <- copy_verified(
      job_files[[file_name]],
      file.path(output_dir, "evidence", "jobs", plan$job_id[[i]],
                basename(job_files[[file_name]]))
    )
    add_ledger(paste("fgav1_job", plan$job_id[[i]], file_name, sep = "__"),
               frozen_job, role = "confirmation_job_evidence")
  }
}
frozen_plan_path <- write_csv(
  frozen_plan, file.path(output_dir, "evidence", "control",
                         "frozen_confirmation_plan.csv")
)
add_ledger("fgav1_frozen_confirmation_plan", frozen_plan_path,
           role = "portable_confirmation_control")

article <- base
article$article_interface_id <- promotion_id
article$promotion_validation_branch <- validation_branch
article$promotion_validation_commit <- implementation_commit
article$rolling_evidence_promotion_id[
  grepl("^qdesn_", article$model_variant)
] <- promotion_id
metric_source_sha <- sha256(frozen$decision)

for (i in seq_len(nrow(promoted))) {
  target <- targets[targets$target_cell_id == promoted$target_cell_id[[i]], ]
  model_variant <- if (target$likelihood[[1L]] == "exal") {
    "qdesn_exal_rhs_ns"
  } else "qdesn_al_rhs_ns"
  row_index <- which(
    article$inference == "mcmc" & article$model_variant == model_variant &
      article$family == target$family[[1L]] &
      abs(article$tau - target$tau[[1L]]) < 1e-12
  )
  if (nrow(target) != 1L || length(row_index) != 1L) {
    stop("A promoted metric does not resolve to one interface row.", call. = FALSE)
  }
  metric <- promoted$metric[[i]]
  article[[metric]][[row_index]] <- promoted$mean_value[[i]]
  chain_subset <- chains[
    chains$target_cell_id == promoted$target_cell_id[[i]] &
      chains$metric == metric & chains$candidate_id == promoted$candidate_id[[i]],
    , drop = FALSE
  ]
  metric_grade <- worst_grade(chain_subset$diagnostic_status)
  prefix <- if (metric == "forecast_qtrue_mae_H1000") {
    "forecast_mae"
  } else "forecast_check"
  article[[paste0(prefix, "_source_candidate_id")]][[row_index]] <-
    promoted$candidate_id[[i]]
  article[[paste0(prefix, "_source_run_tag")]][[row_index]] <- run_tag
  article[[paste0(prefix, "_source_signoff_grade")]][[row_index]] <- metric_grade
  article[[paste0(prefix, "_source_status")]][[row_index]] <- "SUCCESS"
  article[[paste0(prefix, "_source_path")]][[row_index]] <-
    repo_relative(frozen$decision)
  article[[paste0(prefix, "_source_sha256")]][[row_index]] <- metric_source_sha
  article$metric_source_mixed[[row_index]] <- TRUE
  article$signoff_grade[[row_index]] <- worst_grade(c(
    article$fit_source_signoff_grade[[row_index]],
    article$forecast_mae_source_signoff_grade[[row_index]],
    article$forecast_check_source_signoff_grade[[row_index]]
  ))
  article$validation_branch[[row_index]] <- validation_branch
  article$validation_commit[[row_index]] <- confirmation_execution_commit
  article$validation_closeout_commit[[row_index]] <- implementation_commit
  article$source_promotion_id[[row_index]] <- promotion_id
  article$metric_estimator_contract[[row_index]] <- paste(
    "case_specific_metric_source; promoted_forecasts_mean_of_three",
    "full_budget_mcmc_chains; other_metrics_inherited"
  )
  article$confirmation_chain_count[[row_index]] <- 3L
  article$confirmation_execution_commit[[row_index]] <-
    confirmation_execution_commit
  article$confirmation_closeout_commit[[row_index]] <- implementation_commit
  article$confirmation_state[[row_index]] <-
    "FORECAST_GAP_ADAPTIVE_MCMC_V1_CONFIRMATION"
}

metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(article[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 1L, 2L)) ||
    any(!as_bool(article$article_consumption_allowed)) ||
    any(article$source_registry_hash_value != registry_hash) ||
    any(grepl("ridge", article$model_variant))) {
  stop("The v8 interface changed outside the three approved forecast roles.",
       call. = FALSE)
}
interface_path <- write_csv(
  article, file.path(output_dir, paste0(promotion_id, "_interface.csv"))
)

decision$promoted_to_v8 <- as_bool(decision$promote)
decision$promoted_value <- ifelse(
  decision$promoted_to_v8, decision$mean_value, decision$current_value
)
decision_path <- write_csv(
  decision, file.path(output_dir, "promotion_decision_ledger.csv")
)

delta_rows <- list()
k <- 0L
for (metric in metric_columns) {
  changed <- which(abs(article[[metric]] - article_base[[metric]]) > 1e-12)
  for (i in changed) {
    k <- k + 1L
    delta_rows[[k]] <- data.frame(
      inference = article$inference[[i]], model_variant = article$model_variant[[i]],
      family = article$family[[i]], tau = article$tau[[i]], metric = metric,
      rendered_v6_value = article_base[[metric]][[i]],
      authoritative_v8_value = article[[metric]][[i]],
      relative_gain_pct = 100 *
        (1 - article[[metric]][[i]] / article_base[[metric]][[i]]),
      source_promotion_id = article$source_promotion_id[[i]],
      stringsAsFactors = FALSE
    )
  }
}
article_delta <- do.call(rbind, delta_rows)
if (nrow(article_delta) != 5L ||
    any(article_delta$authoritative_v8_value >= article_delta$rendered_v6_value)) {
  stop("The article integration delta must contain exactly five strict gains.",
       call. = FALSE)
}
article_delta_path <- write_csv(
  article_delta, file.path(output_dir, "article_delta_from_rendered_v6.csv")
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
resolved_ledger_paths <- ifelse(
  grepl("^/", ledger$path), ledger$path, file.path(repo_root, ledger$path)
)
if (anyDuplicated(ledger$source_id) || any(!file.exists(resolved_ledger_paths)) ||
    !identical(unname(tools::sha256sum(resolved_ledger_paths)),
               unname(ledger$sha256))) {
  stop("The v8 source ledger is incomplete or stale.", call. = FALSE)
}
ledger_path <- write_csv(ledger, file.path(output_dir, "source_ledger.csv"))

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_FORECAST_GAP_ADAPTIVE_MCMC_V1",
  scientific_decision = "PROMOTE_THREE_CASE_SPECIFIC_FORECAST_CHAIN_MEANS",
  package_version = "1.0.0",
  exal_method_id = "M0_v_collapsed_support_logit",
  al_method_id = "sigma_then_gamma",
  source_registry_hash_value = registry_hash,
  expected_rows = 72L, observed_rows = nrow(article),
  base_promotion_id = base_id,
  base_interface_sha256 = base_hashes[["base_interface"]],
  rendered_article_base_id = article_base_id,
  validation_branch = validation_branch,
  scientific_design_commit = scientific_design_commit,
  confirmation_execution_commit = confirmation_execution_commit,
  closeout_implementation_commit = implementation_commit,
  run_id = run_id, run_tag = run_tag,
  campaign_jobs = list(
    smoke = 2L, calibration = 8L, discovery = 184L, replication = 64L,
    sealed = 96L, confirmation = 24L, total = 378L, failures = 0L
  ),
  confirmed_candidates = 8L, confirmed_metric_roles = 11L,
  canonical_chains = 24L, burn_iterations_per_chain = 5000L,
  retained_iterations_per_chain = 20000L,
  promoted_metric_roles = 3L,
  promoted_estimator = "arithmetic_mean_of_three_full_budget_mcmc_chains",
  promotion_policy = paste(
    "case-specific strict finite three-chain forecast mean below frozen v7;",
    "diagnostics retained but never used as a metric-promotion veto"
  ),
  diagnostics_used_as_promotion_gate = FALSE,
  observed_signoff_grades = as.list(sort(unique(chains$diagnostic_status))),
  observed_signoff_counts = as.list(table(factor(
    chains$diagnostic_status, levels = c("PASS", "WARN", "FAIL", "MISSING")
  ))),
  fit_metric_policy = "retain_v7_all_fit_metrics",
  unchanged_numeric_roles_from_v7 = nrow(article) * length(metric_columns) - 3L,
  article_numeric_updates_from_rendered_v6 = 5L,
  forecast_protocol = "rolling_origin_no_refit_state_update",
  forecast_max_lead_configured = 30L, forecast_origin_stride = 30L,
  binary_payload_count = 0L, storage_policy_pass = TRUE,
  article_interface_path = repo_relative(interface_path),
  article_interface_sha256 = sha256(interface_path),
  promotion_decision_ledger_path = repo_relative(decision_path),
  promotion_decision_ledger_sha256 = sha256(decision_path),
  article_delta_path = repo_relative(article_delta_path),
  article_delta_sha256 = sha256(article_delta_path),
  remaining_gap_ledger_path = repo_relative(gap_path),
  remaining_gap_ledger_sha256 = sha256(gap_path),
  source_ledger_path = repo_relative(ledger_path),
  source_ledger_sha256 = sha256(ledger_path),
  article_update_status = "READY_FOR_INTEGRATION_NO_DIRECT_ARTICLE_WRITE"
)
manifest_path <- write_json(
  manifest, file.path(output_dir, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Independent Q-DESN forecast-gap adaptive MCMC promotion v8",
  "",
  "This immutable v8 handoff inherits the complete 72-row v7 authority and",
  "changes exactly three case-specific MCMC forecast roles. Every promoted",
  "value is the arithmetic mean of three successful full-budget chains.",
  "Fit metrics and all nonwinning forecast roles remain unchanged.",
  "",
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Scientific design commit: `%s`", scientific_design_commit),
  sprintf("- Confirmation execution commit: `%s`", confirmation_execution_commit),
  sprintf("- Closeout implementation commit: `%s`", implementation_commit),
  "- Canonical confirmation: 24/24 jobs; 0 failures",
  "- Promoted forecast roles: 3",
  "- Article deltas from the currently rendered v6 authority: 5",
  "- Diagnostics: 11 PASS and 13 WARN chains; descriptive, not a promotion gate",
  "- Fitted-model binary payloads: 0",
  "- Article publication: delegated to the integration lane"
)
readme_path <- file.path(output_dir, "README.md")
writeLines(readme, readme_path, useBytes = TRUE)

artifact_paths <- c(interface_path, decision_path, article_delta_path, gap_path,
                    ledger_path, manifest_path, readme_path)
artifact_manifest <- data.frame(
  path = vapply(artifact_paths, repo_relative, character(1L)),
  bytes = file.info(artifact_paths)$size,
  sha256 = unname(tools::sha256sum(artifact_paths)), stringsAsFactors = FALSE
)
write_csv(artifact_manifest, file.path(output_dir, "output_file_manifest.csv"))

heavy <- list.files(output_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
all_files <- list.files(output_dir, recursive = TRUE, full.names = TRUE)
if (length(heavy) || any(file.info(all_files)$size > 10 * 1024^2)) {
  stop("The v8 promotion violates the storage-light contract.", call. = FALSE)
}

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=3\n")
cat("ARTICLE_DELTAS_FROM_RENDERED_V6=5\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_INTEGRATION=READY\nSTORAGE_POLICY=PASS\n")
