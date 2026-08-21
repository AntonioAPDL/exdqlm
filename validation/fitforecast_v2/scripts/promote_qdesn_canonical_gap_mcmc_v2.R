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
run_id <- "qdesn_canonical_gap_mcmc_v2_20260820_003025"
run_tag <- "qdesn-canonical-gap-v2-20260820_003025__git-ec9a921"
validation_branch <- "validation/qdesn-canonical-gap-mcmc-v2-1.0.0"
scientific_design_commit <- "ec9a921c9adf4e183a4ce4e61ba7714a91f7f779"
registry_hash <-
  "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

base_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                      base_id)
article_base_dir <- file.path(
  repo_root, "validation", "fitforecast_v2", "promotions", article_base_id
)
state_root <- file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
                        run_id)
materialization_root <- file.path(state_root, "materialization")
adaptive_root <- file.path(materialization_root, "adaptive")
result_root <- file.path(
  repo_root, "results", "qdesn_mcmc_validation",
  "qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2", run_tag
)
output_dir <- file.path(repo_root, "validation", "fitforecast_v2", "promotions",
                        promotion_id)
design_stub <- file.path(
  repo_root, "config", "validation",
  "qdesn_dynamic_fitforecast_v2_500obs_canonical_gap_mcmc_v2"
)

paths <- list(
  base_interface = file.path(base_dir, paste0(base_id, "_interface.csv")),
  base_manifest = file.path(base_dir, paste0(base_id, "_manifest.json")),
  base_ledger = file.path(base_dir, "source_ledger.csv"),
  article_base_interface = file.path(
    article_base_dir, paste0(article_base_id, "_interface.csv")
  ),
  targets = paste0(design_stub, "_target_cells.csv"),
  profiles = paste0(design_stub, "_candidate_profiles.csv"),
  protocol = file.path(
    repo_root, "validation", "fitforecast_v2", "docs",
    "QDESN_CANONICAL_GAP_MCMC_V2_PROTOCOL_2026-08-20.md"
  ),
  materialization = file.path(materialization_root, "materialization_manifest.json"),
  source_registry = file.path(materialization_root, "canonical_source_registry.csv"),
  windows = file.path(materialization_root, "source_window_registry.csv"),
  plan = file.path(materialization_root, "confirmation_plan.csv"),
  results = file.path(adaptive_root, "confirmation_results.csv"),
  candidate_summary = file.path(adaptive_root, "confirmation_candidate_summary.csv"),
  decision = file.path(adaptive_root, "confirmation_decision_ledger.csv"),
  closeout = file.path(adaptive_root, "closeout.json"),
  verification = file.path(state_root, "confirmation_verification.json"),
  verification_runtime = file.path(state_root, "confirmation_verification_runtime.csv"),
  stage_status = file.path(state_root, "stage_status.csv"),
  run_tags = file.path(state_root, "run_tags.env")
)
base_hashes <- c(
  base_interface =
    "56d930b97a66a69f2a2ddfc945eeaeea2518c479490acf04611a9a2941593acc",
  base_manifest =
    "49daad634ac060f6d845a248b8bc57e0ccb77971a7fd6b543b4c010fb63f4cd1",
  base_ledger =
    "de65a25ba53b9372ea02a49fbf994d05e5996e32349ccbf20227f0b125f7a37c",
  article_base_interface =
    "d269be9219d969908b63ef818398ce31387dcaf1bc929e74b39e383f99661fb3",
  targets =
    "097c13a8b9891701bcc89e1283b7325adc5b83785198437195ab65250b2629ab",
  profiles =
    "748473d570b8be87cf4417e53bd4663f8a09783c2e32902c6d17fb36a29a24cf",
  protocol =
    "332b09b9a62ee80fded2070212c1771d15662a25d3a3741bcbe781e4e0aca56a"
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
  if (!startsWith(normalized, prefix)) {
    stop(sprintf("Path escapes repository root: %s", normalized), call. = FALSE)
  }
  substring(normalized, nchar(prefix) + 1L)
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
  identical(system2("git", c("merge-base", "--is-ancestor", commit, "HEAD"),
                    stdout = FALSE, stderr = FALSE), 0L)
}
worst_grade <- function(x) {
  severity <- c(MISSING = 4L, FAIL = 3L, WARN = 2L, PASS = 1L)
  x <- toupper(as.character(x))
  x[!x %in% names(severity)] <- "MISSING"
  x[[which.max(unname(severity[x]))]]
}
target_parts <- function(target_cell_id) {
  pieces <- strsplit(target_cell_id, "_", fixed = TRUE)[[1L]]
  list(
    likelihood = pieces[[1L]],
    family = pieces[[2L]],
    tau = as.numeric(sub("t([0-9]+)p([0-9]+)", "\\1.\\2", pieces[[3L]]))
  )
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
    !git_is_ancestor(scientific_design_commit)) {
  stop("Promotion requires a clean committed canonical-gap task branch.",
       call. = FALSE)
}
for (name in names(base_hashes)) {
  if (!identical(sha256(paths[[name]]), base_hashes[[name]])) {
    stop(sprintf("Frozen promotion input changed: %s", name), call. = FALSE)
  }
}

base <- read_csv(paths$base_interface)
article_base <- read_csv(paths$article_base_interface)
base_manifest <- read_json(paths$base_manifest)
targets <- read_csv(paths$targets)
profiles <- read_csv(paths$profiles)
materialization <- read_json(paths$materialization)
windows <- read_csv(paths$windows)
plan <- read_csv(paths$plan)
results <- read_csv(paths$results)
candidate_summary <- read_csv(paths$candidate_summary)
decision <- read_csv(paths$decision)
closeout <- read_json(paths$closeout)
verification <- read_json(paths$verification)
verification_runtime <- read_csv(paths$verification_runtime)

expected_promotions <- data.frame(
  target_cell_id = c(
    "al_normal_t0p05", "al_normal_t0p05",
    "exal_gausmix_t0p50", "exal_gausmix_t0p50"
  ),
  metric = rep(c("forecast_qtrue_mae_H1000",
                 "forecast_check_loss_H1000"), 2L),
  candidate_id = c(
    rep("cgcv2_al_normal_t0p05_01_64121b0e9b", 2L),
    rep("cgcv2_exal_gausmix_t0p50_01_4c129b0c50", 2L)
  ),
  confirmation_value = c(
    6.91659380458911, 1.20016989478546,
    1.4196448639744, 5.48673029777657
  ),
  stringsAsFactors = FALSE
)
promotion_key <- function(x) paste(x$target_cell_id, x$metric, x$candidate_id)
promoted <- decision[as_bool(decision$strict_improvement), , drop = FALSE]

if (nrow(base) != 72L || nrow(article_base) != 72L || nrow(targets) != 4L ||
    nrow(profiles) != 64L || nrow(plan) != 6L || nrow(results) != 6L ||
    nrow(candidate_summary) != 2L || nrow(decision) != 4L ||
    nrow(promoted) != 4L || anyDuplicated(plan$job_id) ||
    !setequal(promotion_key(promoted), promotion_key(expected_promotions)) ||
    max(abs(promoted$confirmation_value[
      match(promotion_key(expected_promotions), promotion_key(promoted))
    ] - expected_promotions$confirmation_value)) > 1e-12 ||
    any(promoted$confirmation_value >= promoted$current_value) ||
    any(results$status != "SUCCESS") ||
    any(!is.finite(as.numeric(unlist(results[c(
      "fit_qtrue_rmse", "forecast_qtrue_mae_H1000",
      "forecast_check_loss_H1000"
    )], use.names = FALSE)))) ||
    !identical(closeout$decision, "STRICT_GAINS_ELIGIBLE_FOR_PROMOTION") ||
    as.integer(closeout$confirmed_jobs) != 6L ||
    as.integer(closeout$promotable_metrics) != 4L ||
    isTRUE(closeout$diagnostics_are_veto) ||
    !identical(verification$decision, "PASS") ||
    nrow(verification_runtime) != 6L ||
    any(verification_runtime$status != "SUCCESS") ||
    any(!as_bool(verification_runtime$finite)) ||
    any(verification_runtime$binary != 0L) ||
    !identical(materialization$git_commit, scientific_design_commit) ||
    !identical(materialization$exact_exal_method,
               "m0_v_collapsed_support_logit") ||
    !identical(materialization$canonical_source_registry_sha256,
               sha256(paths$source_registry))) {
  stop("Canonical-gap evidence violates the v9 promotion contract.",
       call. = FALSE)
}

stage_counts <- c(smoke = 2L, calibration = 4L, screen = 128L,
                  refine = 36L, confirmation = 6L)
stage_controls <- list()
for (stage in names(stage_counts)) {
  verification_path <- file.path(state_root, paste0(stage, "_verification.json"))
  runtime_path <- file.path(state_root,
                            paste0(stage, "_verification_runtime.csv"))
  if (!file.exists(verification_path) || !file.exists(runtime_path)) {
    stop(sprintf("Missing %s verification evidence.", stage), call. = FALSE)
  }
  stage_verification <- read_json(verification_path)
  stage_runtime <- read_csv(runtime_path)
  status_column <- if ("status" %in% names(stage_runtime)) "status" else NA_character_
  binary_column <- intersect(c("binary", "binary_count"), names(stage_runtime))
  finite_column <- intersect(c("finite", "metric_finite"), names(stage_runtime))
  if (!identical(stage_verification$decision, "PASS") ||
      nrow(stage_runtime) != stage_counts[[stage]] ||
      (!is.na(status_column) && any(stage_runtime[[status_column]] != "SUCCESS")) ||
      (length(binary_column) && any(stage_runtime[[binary_column[[1L]]]] != 0L)) ||
      (length(finite_column) && any(!as_bool(stage_runtime[[finite_column[[1L]]]])))) {
    stop(sprintf("The %s stage is not a complete success.", stage), call. = FALSE)
  }
  stage_controls[[paste0(stage, "_verification")]] <- verification_path
  stage_controls[[paste0(stage, "_runtime")]] <- runtime_path
}

for (i in seq_len(nrow(decision))) {
  parts <- target_parts(decision$target_cell_id[[i]])
  model_variant <- if (parts$likelihood == "exal") {
    "qdesn_exal_rhs_ns"
  } else {
    "qdesn_al_rhs_ns"
  }
  base_row <- base[
    base$inference == "mcmc" & base$model_variant == model_variant &
      base$family == parts$family & abs(base$tau - parts$tau) < 1e-12,
    , drop = FALSE
  ]
  if (nrow(base_row) != 1L ||
      abs(base_row[[decision$metric[[i]]]][[1L]] -
          decision$current_value[[i]]) > 1e-12) {
    stop("A canonical-gap decision is not anchored to v8.", call. = FALSE)
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
add_ledger("base_v8_interface", paths$base_interface,
           base_hashes[["base_interface"]], "inherited_authority")
add_ledger("base_v8_manifest", paths$base_manifest,
           base_hashes[["base_manifest"]], "inherited_authority")
add_ledger("base_v8_source_ledger", paths$base_ledger,
           base_hashes[["base_ledger"]], "inherited_authority")
add_ledger("rendered_v6_interface", paths$article_base_interface,
           base_hashes[["article_base_interface"]], "article_delta_baseline")
add_ledger("canonical_gap_target_cells", paths$targets,
           base_hashes[["targets"]], "campaign_design")
add_ledger("canonical_gap_candidate_profiles", paths$profiles,
           base_hashes[["profiles"]], "campaign_design")
add_ledger("canonical_gap_protocol", paths$protocol,
           base_hashes[["protocol"]], "campaign_protocol")

control_paths <- c(paths[c(
  "materialization", "source_registry", "results", "candidate_summary",
  "decision", "closeout", "verification", "verification_runtime",
  "stage_status", "run_tags"
)], stage_controls)
frozen_controls <- list()
for (name in names(control_paths)) {
  frozen_controls[[name]] <- copy_verified(
    control_paths[[name]],
    file.path(output_dir, "evidence", "control", basename(control_paths[[name]]))
  )
  add_ledger(paste0("canonical_gap_", name), frozen_controls[[name]],
             role = if (name == "decision") "article_metric_decision" else
               "campaign_control")
}

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
chain_rows <- list()
selected_windows <- list()

for (i in seq_len(nrow(plan))) {
  config <- read_json(plan$config_path[[i]])
  likelihood <- plan$likelihood_target[[i]]
  if (!identical(sha256(plan$config_path[[i]]), plan$config_sha256[[i]]) ||
      as.integer(config$config$inference$mcmc$n_burn) != 5000L ||
      as.integer(config$config$inference$mcmc$n_mcmc) != 20000L ||
      as.integer(config$config$cpp$postpred_threads) != 1L ||
      config$profile$D != 1L || as.integer(config$profile$n) != 40L ||
      config$profile$m != 12L || abs(as.numeric(config$profile$alpha) - 0.08) > 1e-12 ||
      abs(as.numeric(config$profile$rho) - 0.35) > 1e-12 ||
      abs(config$profile$rhs_tau0 - 1e-8) > 1e-20 ||
      (likelihood == "exal" &&
       !identical(config$config$inference$mcmc$slice$core_update_mode,
                  "m0_v_collapsed_support_logit")) ||
      (likelihood == "al" &&
       !identical(config$inference_method_id, "sigma_then_gamma"))) {
    stop(sprintf("Invalid canonical confirmation config: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  frozen_config <- copy_verified(
    plan$config_path[[i]],
    file.path(output_dir, "evidence", "configs", basename(plan$config_path[[i]])),
    plan$config_sha256[[i]]
  )
  frozen_plan$config_path[[i]] <- repo_relative(frozen_config)
  add_ledger(paste0("canonical_gap_config__", plan$job_id[[i]]), frozen_config,
             plan$config_sha256[[i]], "canonical_confirmation_config")

  matching_window <- windows[
    windows$observed_sha256 == config$observed_sha256 &
      windows$family == config$profile$family &
      abs(windows$tau - config$profile$tau) < 1e-12 &
      windows$m == config$profile$m & windows$washout == config$profile$washout,
    , drop = FALSE
  ]
  if (nrow(matching_window) != 1L) {
    stop(sprintf("Could not resolve canonical input window: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  selected_windows[[paste(
    matching_window$family, matching_window$tau, matching_window$m,
    matching_window$washout, sep = "|"
  )]] <- matching_window

  job_root <- file.path(result_root, "jobs", plan$job_id[[i]])
  job_files <- file.path(job_root, unname(job_evidence_names))
  names(job_files) <- names(job_evidence_names)
  if (any(!file.exists(job_files))) {
    stop(sprintf("Incomplete canonical job evidence: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  started <- read_json(job_files[["job_started"]])
  request <- read_json(job_files[["fit_request"]])
  status <- read_json(job_files[["job_status"]])
  signoff <- read_csv(job_files[["signoff"]])
  result_row <- results[results$job_id == plan$job_id[[i]], , drop = FALSE]
  if (!identical(started$git_commit, scientific_design_commit) ||
      !identical(request$execution$launch_commit, scientific_design_commit) ||
      !identical(status$status, "SUCCESS") ||
      as.integer(status$binary_payloads_remaining) != 0L ||
      !identical(status$config_sha256, plan$config_sha256[[i]]) ||
      nrow(signoff) != 1L || nrow(result_row) != 1L ||
      !signoff$signoff_grade[[1L]] %in% c("PASS", "WARN", "FAIL")) {
    stop(sprintf("Invalid canonical execution evidence: %s", plan$job_id[[i]]),
         call. = FALSE)
  }
  frozen_job_paths <- list()
  for (file_name in names(job_files)) {
    frozen_job <- copy_verified(
      job_files[[file_name]],
      file.path(output_dir, "evidence", "jobs", plan$job_id[[i]],
                basename(job_files[[file_name]]))
    )
    frozen_job_paths[[file_name]] <- frozen_job
    add_ledger(paste("canonical_gap_job", plan$job_id[[i]], file_name,
                     sep = "__"), frozen_job,
               role = "canonical_confirmation_job_evidence")
  }
  chain_rows[[i]] <- data.frame(
    job_id = plan$job_id[[i]], target_cell_id = plan$target_cell_id[[i]],
    candidate_id = plan$candidate_id[[i]], likelihood_target = likelihood,
    chain_id = plan$chain_id[[i]], reservoir_seed_id = plan$reservoir_seed_id[[i]],
    fit_qtrue_rmse = result_row$fit_qtrue_rmse[[1L]],
    forecast_qtrue_mae_H1000 = result_row$forecast_qtrue_mae_H1000[[1L]],
    forecast_check_loss_H1000 = result_row$forecast_check_loss_H1000[[1L]],
    status = status$status, signoff_grade = signoff$signoff_grade[[1L]],
    comparison_eligible = signoff$comparison_eligible[[1L]],
    signoff_reason = signoff$signoff_reason[[1L]],
    config_sha256 = plan$config_sha256[[i]],
    signoff_path = repo_relative(frozen_job_paths[["signoff"]]),
    job_status_path = repo_relative(frozen_job_paths[["job_status"]]),
    stringsAsFactors = FALSE
  )
}

frozen_plan_path <- write_csv(
  frozen_plan,
  file.path(output_dir, "evidence", "control", "frozen_confirmation_plan.csv")
)
add_ledger("canonical_gap_frozen_confirmation_plan", frozen_plan_path,
           role = "portable_confirmation_control")

selected_window_table <- do.call(rbind, unname(selected_windows))
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
for (i in seq_len(nrow(selected_window_table))) {
  for (name in names(input_columns)) {
    source <- selected_window_table[[input_columns[[name]]]][[i]]
    expected <- selected_window_table[[input_hash_columns[[name]]]][[i]]
    copied <- copy_verified(
      source,
      file.path(output_dir, "evidence", "inputs",
                selected_window_table$family[[i]],
                sprintf("tau_%0.2f", selected_window_table$tau[[i]]),
                paste0(name, ".csv")),
      expected
    )
    selected_window_table[[input_columns[[name]]]][[i]] <- repo_relative(copied)
    add_ledger(
      paste("canonical_gap_input", selected_window_table$family[[i]],
            sprintf("%0.2f", selected_window_table$tau[[i]]), name, sep = "__"),
      copied, expected, "canonical_confirmation_input"
    )
  }
}
selected_window_table$source_sim_origin_path <-
  basename(selected_window_table$source_sim_path)
selected_window_table$source_sim_path <-
  paste0("sha256:", selected_window_table$source_sim_sha256)
frozen_window_path <- write_csv(
  selected_window_table,
  file.path(output_dir, "evidence", "control",
            "frozen_canonical_window_registry.csv")
)
add_ledger("canonical_gap_frozen_window_registry", frozen_window_path,
           role = "portable_confirmation_control")

chain_evidence <- do.call(rbind, chain_rows)
chain_evidence <- chain_evidence[order(chain_evidence$target_cell_id,
                                       chain_evidence$chain_id), ]
chain_evidence_path <- write_csv(
  chain_evidence, file.path(output_dir, "confirmation_chain_evidence.csv")
)

article <- base
article$article_interface_id <- promotion_id
article$promotion_validation_branch <- validation_branch
article$promotion_validation_commit <- implementation_commit
article$rolling_evidence_promotion_id[grepl("^qdesn_", article$model_variant)] <-
  promotion_id
metric_source_sha <- sha256(chain_evidence_path)
rollback_rows <- list()

for (i in seq_len(nrow(promoted))) {
  parts <- target_parts(promoted$target_cell_id[[i]])
  model_variant <- if (parts$likelihood == "exal") {
    "qdesn_exal_rhs_ns"
  } else {
    "qdesn_al_rhs_ns"
  }
  row_index <- which(
    article$inference == "mcmc" & article$model_variant == model_variant &
      article$family == parts$family & abs(article$tau - parts$tau) < 1e-12
  )
  if (length(row_index) != 1L) {
    stop("A promoted role does not resolve to one interface row.", call. = FALSE)
  }
  metric <- promoted$metric[[i]]
  prefix <- if (metric == "forecast_qtrue_mae_H1000") {
    "forecast_mae"
  } else {
    "forecast_check"
  }
  chain_subset <- chain_evidence[
    chain_evidence$target_cell_id == promoted$target_cell_id[[i]] &
      chain_evidence$candidate_id == promoted$candidate_id[[i]],
    , drop = FALSE
  ]
  metric_grade <- worst_grade(chain_subset$signoff_grade)
  rollback_rows[[i]] <- data.frame(
    inference = article$inference[[row_index]], model_variant = model_variant,
    family = parts$family, tau = parts$tau, metric = metric,
    base_promotion_id = base_id, previous_value = article[[metric]][[row_index]],
    promoted_value = promoted$confirmation_value[[i]],
    previous_source_candidate_id = article[[paste0(prefix, "_source_candidate_id")]][[row_index]],
    previous_source_run_tag = article[[paste0(prefix, "_source_run_tag")]][[row_index]],
    previous_source_signoff_grade = article[[paste0(prefix, "_source_signoff_grade")]][[row_index]],
    previous_source_path = article[[paste0(prefix, "_source_path")]][[row_index]],
    previous_source_sha256 = article[[paste0(prefix, "_source_sha256")]][[row_index]],
    stringsAsFactors = FALSE
  )
  article[[metric]][[row_index]] <- promoted$confirmation_value[[i]]
  article[[paste0(prefix, "_source_candidate_id")]][[row_index]] <-
    promoted$candidate_id[[i]]
  article[[paste0(prefix, "_source_run_tag")]][[row_index]] <- run_tag
  article[[paste0(prefix, "_source_signoff_grade")]][[row_index]] <- metric_grade
  article[[paste0(prefix, "_source_status")]][[row_index]] <- "SUCCESS"
  article[[paste0(prefix, "_source_path")]][[row_index]] <-
    repo_relative(chain_evidence_path)
  article[[paste0(prefix, "_source_sha256")]][[row_index]] <- metric_source_sha
  article$metric_source_mixed[[row_index]] <- TRUE
  article$signoff_grade[[row_index]] <- worst_grade(c(
    article$fit_source_signoff_grade[[row_index]],
    article$forecast_mae_source_signoff_grade[[row_index]],
    article$forecast_check_source_signoff_grade[[row_index]]
  ))
  article$validation_branch[[row_index]] <- validation_branch
  article$validation_commit[[row_index]] <- scientific_design_commit
  article$validation_closeout_commit[[row_index]] <- implementation_commit
  article$source_promotion_id[[row_index]] <- promotion_id
  article$metric_estimator_contract[[row_index]] <- paste(
    "case_specific_metric_source; promoted_forecasts_mean_of_three",
    "full_budget_mcmc_chains; fit_metric_inherited"
  )
  article$confirmation_chain_count[[row_index]] <- 3L
  article$confirmation_execution_commit[[row_index]] <- scientific_design_commit
  article$confirmation_closeout_commit[[row_index]] <- implementation_commit
  article$confirmation_state[[row_index]] <-
    "CANONICAL_GAP_MCMC_V2_CONFIRMATION"
}

metric_columns <- c(
  "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
)
numeric_changes <- vapply(metric_columns, function(metric) {
  sum(abs(article[[metric]] - base[[metric]]) > 1e-12)
}, integer(1L))
if (!identical(unname(numeric_changes), c(0L, 2L, 2L)) ||
    any(!as_bool(article$article_consumption_allowed)) ||
    any(article$source_registry_hash_value != registry_hash) ||
    any(grepl("ridge", article$model_variant))) {
  stop("The v9 interface changed outside the four approved forecast roles.",
       call. = FALSE)
}
interface_path <- write_csv(
  article, file.path(output_dir, paste0(promotion_id, "_interface.csv"))
)

decision$promoted_to_v9 <- as_bool(decision$strict_improvement)
decision$promoted_value <- ifelse(
  decision$promoted_to_v9, decision$confirmation_value, decision$current_value
)
decision$diagnostics_used_as_promotion_gate <- FALSE
decision_path <- write_csv(
  decision, file.path(output_dir, "promotion_decision_ledger.csv")
)

v8_effect_rows <- list()
for (metric in metric_columns) {
  changed <- which(abs(article[[metric]] - base[[metric]]) > 1e-12)
  for (index in changed) {
    v8_effect_rows[[length(v8_effect_rows) + 1L]] <- data.frame(
      inference = article$inference[[index]],
      model_variant = article$model_variant[[index]],
      family = article$family[[index]], tau = article$tau[[index]],
      metric = metric, authoritative_v8_value = base[[metric]][[index]],
      authoritative_v9_value = article[[metric]][[index]],
      absolute_gain = base[[metric]][[index]] - article[[metric]][[index]],
      relative_gain_pct = 100 *
        (1 - article[[metric]][[index]] / base[[metric]][[index]]),
      source_promotion_id = promotion_id, stringsAsFactors = FALSE
    )
  }
}
v8_effect <- do.call(rbind, v8_effect_rows)
if (nrow(v8_effect) != 4L || any(v8_effect$absolute_gain <= 0)) {
  stop("The v9 effect ledger must contain exactly four strict gains.",
       call. = FALSE)
}
v8_effect_path <- write_csv(
  v8_effect, file.path(output_dir, "promotion_effect_from_v8.csv")
)

delta_rows <- list()
for (metric in metric_columns) {
  changed <- which(abs(article[[metric]] - article_base[[metric]]) > 1e-12)
  for (index in changed) {
    delta_rows[[length(delta_rows) + 1L]] <- data.frame(
      inference = article$inference[[index]],
      model_variant = article$model_variant[[index]],
      family = article$family[[index]], tau = article$tau[[index]],
      metric = metric, rendered_v6_value = article_base[[metric]][[index]],
      authoritative_value = article[[metric]][[index]],
      authority_version = "v9",
      relative_gain_pct = 100 *
        (1 - article[[metric]][[index]] / article_base[[metric]][[index]]),
      source_promotion_id = article$source_promotion_id[[index]],
      stringsAsFactors = FALSE
    )
  }
}
article_delta <- do.call(rbind, delta_rows)
if (nrow(article_delta) != 8L ||
    any(article_delta$authoritative_value >= article_delta$rendered_v6_value)) {
  stop("The cumulative article delta must contain eight strict gains.",
       call. = FALSE)
}
article_delta_path <- write_csv(
  article_delta, file.path(output_dir, "article_delta_from_rendered_v6.csv")
)

external <- article[
  article$inference == "mcmc" & article$model_variant %in% c("dqlm", "exdqlm"),
  , drop = FALSE
]
qmodels <- article[
  article$inference == "mcmc" & article$model_variant %in%
    c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  , drop = FALSE
]
gap_rows <- list()
for (i in seq_len(nrow(qmodels))) {
  comparators <- external[
    external$family == qmodels$family[[i]] &
      abs(external$tau - qmodels$tau[[i]]) < 1e-12,
    , drop = FALSE
  ]
  for (metric in metric_columns) {
    comparator <- min(comparators[[metric]])
    value <- qmodels[[metric]][[i]]
    ratio <- value / comparator
    gap_rows[[length(gap_rows) + 1L]] <- data.frame(
      authority_id = promotion_id, model_variant = qmodels$model_variant[[i]],
      family = qmodels$family[[i]], tau = qmodels$tau[[i]], metric = metric,
      value = value, best_dqlm_exdqlm_value = comparator,
      ratio_to_best_dqlm_exdqlm = ratio, relative_gap_pct = 100 * (ratio - 1),
      forecast_priority = grepl("^forecast_", metric) && ratio > 1,
      next_action = if (grepl("^forecast_", metric) && ratio > 1) {
        "TARGETED_FORECAST_CALIBRATION"
      } else {
        "RETAIN_CURRENT"
      },
      stringsAsFactors = FALSE
    )
  }
}
gaps <- do.call(rbind, gap_rows)
gaps <- gaps[order(!gaps$forecast_priority, -gaps$relative_gap_pct,
                   gaps$model_variant, gaps$family, gaps$tau), ]
gap_path <- write_csv(gaps, file.path(output_dir, "remaining_gap_ledger.csv"))

promoted_candidates <- unique(promoted[, c("target_cell_id", "candidate_id")])
spec_rows <- lapply(seq_len(nrow(promoted_candidates)), function(i) {
  profile <- profiles[
    profiles$target_cell_id == promoted_candidates$target_cell_id[[i]] &
      profiles$candidate_id == promoted_candidates$candidate_id[[i]],
    , drop = FALSE
  ]
  if (nrow(profile) != 1L) stop("Promoted candidate specification is missing.")
  data.frame(
    target_cell_id = profile$target_cell_id,
    candidate_id = profile$candidate_id,
    family = profile$family, tau = profile$tau,
    likelihood_target = profile$likelihood_target,
    D = profile$D, n = profile$n, n_tilde = profile$n_tilde, m = profile$m,
    alpha = profile$alpha, rho = profile$rho, pi_w = profile$pi_w,
    pi_in = profile$pi_in, rhs_tau0 = profile$rhs_tau0,
    readout_y_lags = profile$readout_y_lags,
    reservoir_lags = profile$reservoir_lags, washout = profile$washout,
    effective_readout_dimension = profile$effective_readout_dimension,
    inference_method_id = if (profile$likelihood_target == "exal") {
      "m0_v_collapsed_support_logit"
    } else {
      "sigma_then_gamma"
    },
    stringsAsFactors = FALSE
  )
})
specification_path <- write_csv(
  do.call(rbind, spec_rows),
  file.path(output_dir, "promoted_candidate_specifications.csv")
)
rollback_path <- write_csv(
  do.call(rbind, rollback_rows), file.path(output_dir, "rollback_ledger.csv")
)

ledger <- unique(do.call(rbind, ledger_rows))
ledger <- ledger[order(ledger$source_id, ledger$path), ]
row.names(ledger) <- NULL
resolved_ledger_paths <- file.path(repo_root, ledger$path)
if (anyDuplicated(ledger$source_id) || any(!file.exists(resolved_ledger_paths)) ||
    !identical(unname(tools::sha256sum(resolved_ledger_paths)),
               unname(ledger$sha256))) {
  stop("The v9 source ledger is incomplete or stale.", call. = FALSE)
}
ledger_path <- write_csv(ledger, file.path(output_dir, "source_ledger.csv"))

readme <- c(
  "# Independent Q-DESN canonical-gap MCMC promotion v9",
  "",
  "This storage-light authority inherits the complete 72-row v8 interface",
  "and changes exactly four case-specific MCMC forecast roles. Promoted",
  "values are arithmetic means of three successful full-budget chains.",
  "Diagnostics remain fully recorded and are not a metric-promotion gate.",
  "All fit metrics and every nonwinning forecast role are inherited exactly.",
  "",
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Scientific design and execution commit: `%s`", scientific_design_commit),
  sprintf("- Closeout implementation commit: `%s`", implementation_commit),
  "- Campaign completion: 176/176 jobs; 0 failures",
  "- Canonical confirmation: 6/6 chains; 0 execution failures",
  "- Promoted forecast roles: 4",
  "- Diagnostic grades: 5 WARN and 1 FAIL; descriptive only",
  "- Fitted-model binary payloads: 0",
  "- Article publication: delegated to ARTICLE QDESN INTEGRATION"
)
readme_path <- file.path(output_dir, "README.md")
writeLines(readme, readme_path, useBytes = TRUE)

manifest <- list(
  promotion_id = promotion_id,
  promotion_status = "AUTHORITATIVE_CANONICAL_GAP_MCMC_V2",
  scientific_decision = "PROMOTE_FOUR_CASE_SPECIFIC_FORECAST_CHAIN_MEANS",
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
  confirmation_execution_commit = scientific_design_commit,
  closeout_implementation_commit = implementation_commit,
  run_id = run_id, run_tag = run_tag,
  campaign_jobs = as.list(c(stage_counts, total = sum(stage_counts), failures = 0L)),
  confirmed_candidates = 2L, canonical_chains = 6L,
  burn_iterations_per_chain = 5000L,
  retained_iterations_per_chain = 20000L,
  promoted_metric_roles = 4L,
  promoted_estimator = "arithmetic_mean_of_three_full_budget_mcmc_chains",
  promotion_policy = paste(
    "case-specific strict finite three-chain forecast mean below frozen v8;",
    "diagnostics retained but never used as a metric-promotion veto"
  ),
  diagnostics_used_as_promotion_gate = FALSE,
  canonical_chain_signoff_counts = as.list(table(factor(
    chain_evidence$signoff_grade,
    levels = c("PASS", "WARN", "FAIL", "MISSING")
  ))),
  fit_metric_policy = "retain_v8_all_fit_metrics",
  unchanged_numeric_roles_from_v8 = nrow(article) * length(metric_columns) - 4L,
  article_numeric_updates_from_rendered_v6 = nrow(article_delta),
  forecast_protocol = "rolling_origin_no_refit_state_update",
  forecast_max_lead_configured = 30L, forecast_origin_stride = 30L,
  binary_payload_count = 0L, storage_policy_pass = TRUE,
  article_interface_path = repo_relative(interface_path),
  article_interface_sha256 = sha256(interface_path),
  promotion_decision_ledger_path = repo_relative(decision_path),
  promotion_decision_ledger_sha256 = sha256(decision_path),
  promotion_effect_from_v8_path = repo_relative(v8_effect_path),
  promotion_effect_from_v8_sha256 = sha256(v8_effect_path),
  article_delta_path = repo_relative(article_delta_path),
  article_delta_sha256 = sha256(article_delta_path),
  remaining_gap_ledger_path = repo_relative(gap_path),
  remaining_gap_ledger_sha256 = sha256(gap_path),
  promoted_specifications_path = repo_relative(specification_path),
  promoted_specifications_sha256 = sha256(specification_path),
  chain_evidence_path = repo_relative(chain_evidence_path),
  chain_evidence_sha256 = sha256(chain_evidence_path),
  rollback_ledger_path = repo_relative(rollback_path),
  rollback_ledger_sha256 = sha256(rollback_path),
  source_ledger_path = repo_relative(ledger_path),
  source_ledger_sha256 = sha256(ledger_path),
  article_update_status = "READY_FOR_INTEGRATION_NO_DIRECT_MAIN_WRITE"
)
manifest_path <- write_json(
  manifest, file.path(output_dir, paste0(promotion_id, "_manifest.json"))
)

artifact_paths <- c(
  interface_path, decision_path, v8_effect_path, article_delta_path, gap_path,
  specification_path, chain_evidence_path, rollback_path, ledger_path,
  manifest_path, readme_path
)
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
  stop("The v9 promotion violates the storage-light contract.", call. = FALSE)
}

cat(sprintf("PROMOTION_ID=%s\n", promotion_id))
cat("INTERFACE_ROWS=72\nPROMOTED_FORECAST_ROLES=4\n")
cat("ARTICLE_DELTAS_FROM_RENDERED_V6=8\n")
cat(sprintf("SOURCE_LEDGER_ROWS=%d\n", nrow(ledger)))
cat("ARTICLE_INTEGRATION=READY\nSTORAGE_POLICY=PASS\n")
