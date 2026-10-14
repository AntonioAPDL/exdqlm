fpr2_branch <- "validation/independent-forecast-prefix-recovery-v2-20261014"
fpr2_schema <- "independent_forecast_prefix_recovery_v2"

fpr2_classify <- function(plan, states) {
  fpf_assert(length(states) == nrow(plan) && !anyDuplicated(plan$task_id), "Invalid recovery task identities.")
  fpf_assert(all(states %in% c("COMPLETE", "FAILED_RETAIN_EVIDENCE", "QUEUED")),
    "Original attempt must be stopped, with no running or unknown tasks.")
  ifelse(states == "COMPLETE", "REFERENCE_COMPLETE",
    ifelse(states == "FAILED_RETAIN_EVIDENCE", "RESCORE_CACHED_FORECAST", "NEW_CHAIN"))
}
fpr2_helpers <- function(contract) {
  fpr_assert_hashes(fpr_table(contract$code_manifest))
  helpers <- new.env(parent = baseenv())
  needed <- c("%||%", ".qdesn_validation_lead_export_scale_spec",
    ".qdesn_validation_apply_lead_export_scale", ".qdesn_validation_even_draw_indices")
  files <- file.path(contract$source_root, c("R/qdesn_mcmc_validation.R", "R/qdesn_validation_metric_intervals.R"))
  for (file in files) for (expr in parse(file)) {
    if (is.call(expr) && identical(expr[[1L]], as.name("<-")) && is.symbol(expr[[2L]]) &&
      as.character(expr[[2L]]) %in% needed) eval(expr, helpers)
  }
  fpf_assert(all(vapply(needed, exists, logical(1), envir = helpers, inherits = FALSE)),
    "Pinned scale/draw helpers are incomplete.")
  helpers
}
fpr2_verify_complete <- function(row) {
  root <- row$job_root
  state <- fpf_json(file.path(root, "task_status.json"))
  fpf_assert(state$status == "COMPLETE" && state$contract_sha256 == row$contract_sha256 &&
    fpf_sha(row$contract_path) == row$contract_sha256, "Complete task contract changed.")
  manifest <- file.path(root, "retention_manifest.csv")
  fpf_assert(fpf_sha(manifest) == state$retention_manifest_sha256 &&
    fpf_sha(file.path(root, "prefix_draws.csv.gz")) == state$prefix_draws_sha256,
    "Complete task export changed.")
  fpr_assert_hashes(fpf_read(manifest))
  invisible(TRUE)
}
fpr2_materialize <- function(repo, original, output) {
  fpf_assert(identical(system2("git", c("-C", shQuote(repo), "branch", "--show-current"), stdout = TRUE),
    fpr2_branch), "Recovery requires its dedicated IND branch.")
  fpf_assert(length(system2("git", c("-C", shQuote(repo), "status", "--porcelain"), stdout = TRUE)) == 0L,
    "Commit recovery code before freezing the new bundle.")
  fpf_assert(!dir.exists(output), "Refusing to overwrite a recovery bundle.")
  original <- normalizePath(original, mustWork = TRUE)
  original_manifest <- fpf_json(file.path(original, "run_manifest.json"))
  fpf_assert(original_manifest$launch_head == "07e18bfe6f76c0f13d60d7dcf8ae3cb31888f135" &&
    fpf_json(file.path(original, "controller_status.json"))$status == "TASK_FAILED_RETAIN_ALL_OUTPUTS",
    "Unexpected original reconstruction authority or controller state.")
  fpr_assert_hashes(fpf_read(file.path(original, "input_manifest.csv")))
  plan <- fpf_read(file.path(original, "task_plan.csv"))
  states <- vapply(plan$task_id, function(id) {
    p <- file.path(original, "jobs", id, "task_status.json")
    if (file.exists(p)) fpf_json(p)$status else "QUEUED"
  }, character(1))
  plan$action <- fpr2_classify(plan, states)
  fpf_assert(nrow(plan) == 132L && length(unique(plan$replay_id)) == 44L &&
    sum(plan$action == "REFERENCE_COMPLETE") == 24L &&
    sum(plan$action == "RESCORE_CACHED_FORECAST") == 11L && sum(plan$action == "NEW_CHAIN") == 97L,
    "Frozen 24-reference/11-recovery/97-new surface changed; re-audit before launch.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output)
  plan$original_status <- states
  plan$original_contract_path <- plan$contract_path
  plan$original_contract_sha256 <- plan$contract_sha256
  plan$original_job_root <- file.path(original, "jobs", plan$task_id)
  plan$job_root <- ifelse(plan$action == "REFERENCE_COMPLETE", plan$original_job_root,
    file.path(output, "jobs", plan$task_id))
  frozen <- c(file.path(original, c("input_manifest.csv", "task_plan.csv", "run_manifest.json",
    "controller_status.json", "protected_source_input_manifest.csv")))
  preflight <- list()
  runtime_checked <- character()
  for (i in seq_len(nrow(plan))) {
    cat("PREFLIGHT", i, plan$task_id[i], plan$action[i], "\n")
    contract <- fpr_json(plan$original_contract_path[i])
    fpf_assert(fpf_sha(plan$original_contract_path[i]) == plan$original_contract_sha256[i] &&
      contract$task$task_id == plan$task_id[i], "Original contract identity changed.")
    if (!contract$source_root %in% runtime_checked) {
      fpr_assert_hashes(fpr_table(contract$code_manifest))
      runtime_checked <- c(runtime_checked, contract$source_root)
    }
    if (contract$engine == "qdesn") {
      source <- fpf_read(contract$root_spec$source_series_wide_path)
      alignment <- fpr_source_alignment(source, targets = fpf_read(contract$task$path))
      fpf_assert(contract$config$inference$mcmc$n_burn == 5000L &&
        contract$config$inference$mcmc$n_mcmc == 20000L && contract$package_version == "1.0.0",
        "Historical Q-DESN budget/runtime changed.")
      if (plan$model_variant[i] == "qdesn_exal_rhs_ns") fpf_assert(
        contract$config$inference$mcmc$slice$core_update_mode == "m0_v_collapsed_support_logit", "M0 changed.")
      preflight[[length(preflight) + 1L]] <- data.frame(task_id = plan$task_id[i],
        column = alignment$column, source_sha256 = fpf_sha(contract$root_spec$source_series_wide_path),
        first_local_origin = alignment$local_origin[1L], last_local_origin = tail(alignment$local_origin, 1L),
        n_origins = length(alignment$local_origin), n_targets = length(alignment$local_target), pass = TRUE)
    } else {
      fpf_assert(contract$config$budget$mcmc$n_burn == 5000L &&
        contract$config$budget$mcmc$n_mcmc == 20000L, "Historical dynamic budget changed.")
      if (plan$model_variant[i] == "exdqlm") {
        fpf_assert(contract$package_version == "1.1.1" &&
          contract$config$budget$mcmc$mh_proposal == "collapsed_slice", "Historical exDQLM runtime/transition changed.")
        fpr_assert_hashes(fpr_table(contract$package_manifest))
      }
    }
    state_path <- file.path(plan$original_job_root[i], "task_status.json")
    if (file.exists(state_path)) frozen <- c(frozen, state_path)
    if (plan$action[i] == "NEW_CHAIN") fpf_assert(
      identical(list.files(plan$original_job_root[i], recursive = TRUE, all.files = TRUE), "contract.json"),
      "A supposedly unstarted original task contains other artifacts; audit before fitting.")
    if (plan$action[i] == "REFERENCE_COMPLETE") {
      fpr2_verify_complete(plan[i, ])
      frozen <- c(frozen, file.path(plan$job_root[i], c("retention_manifest.csv", "protected_capsule.json")))
      next
    }
    old <- contract
    contract <- fpr_relocate(old, old$output_root, plan$job_root[i])
    fpf_assert(isTRUE(all.equal(fpr_relocate(contract, plan$job_root[i], old$output_root), old, tolerance = 0)),
      "Recovery relocation changed a scientific field.")
    contract$source_input_backup_manifest <- file.path(original, "protected_source_input_manifest.csv")
    contract$recovery <- list(action = plan$action[i], original_contract_path = plan$original_contract_path[i],
      original_contract_sha256 = plan$original_contract_sha256[i], original_job_root = plan$original_job_root[i])
    if (plan$action[i] == "RESCORE_CACHED_FORECAST") {
      fpf_assert(contract$engine == "qdesn", "Only audited Q-DESN cache recovery is supported.")
      retained <- file.path(plan$original_job_root[i], c("task_status.json", "contract.json", "environment.json",
        "quantile/manifest/status.txt", "quantile/models/forecast_objects.rds", "quantile/tables/metric_draws.csv.gz"))
      fpf_assert(all(file.exists(retained)) &&
        identical(trimws(readLines(retained[4L], warn = FALSE)), "SUCCESS"), "Native cached job did not finish.")
      expected <- fpf_read(file.path(original, "healthchecks/health_20261014_0415_UTC/failed_job_protected_evidence_manifest.csv"))
      expected <- expected[expected$task_id == plan$task_id[i], ]
      fpr_assert_hashes(expected)
      contract$recovery$input_manifest <- fpr_hashes(retained)
      frozen <- c(frozen, retained[basename(retained) != "forecast_objects.rds"])
      contract$refit_authorized <- FALSE
    }
    plan$contract_path[i] <- file.path(plan$job_root[i], "contract.json")
    fpr_write_json(contract, plan$contract_path[i])
    plan$contract_sha256[i] <- fpf_sha(plan$contract_path[i])
    frozen <- c(frozen, plan$contract_path[i])
  }
  fpf_assert(length(preflight) == 78L, "Every Q-DESN task must pass schema/target preflight.")
  fpf_write(do.call(rbind, preflight), file.path(output, "source_schema_preflight.csv"))
  fpf_write(plan, file.path(output, "task_plan.csv"))
  for (name in c("article_baseline.csv", "frozen_article_style.R", "exdqlm_1.1.1.tar.gz",
    "protected_source_input_manifest.csv")) {
    fpf_assert(file.copy(file.path(original, name), file.path(output, name)), "Cannot freeze a reference artifact.")
    frozen <- c(frozen, file.path(output, name))
  }
  own_code <- file.path(repo, c("validation/fitforecast_v2/R/forecast_prefix_metric_intervals_v1.R",
    "validation/fitforecast_v2/R/forecast_prefix_reconstruction_v1.R",
    "validation/fitforecast_v2/R/forecast_prefix_recovery_v2.R",
    "validation/fitforecast_v2/scripts/run_forecast_prefix_recovery_v2.R",
    "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"))
  fpr_write_json(list(schema = fpr2_schema, branch = fpr2_branch,
    launch_head = system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE),
    original_run = original, original_head = original_manifest$launch_head, jobs = 132L,
    references = 24L, cached_rescorings = 11L, new_chains = 97L, selected_sources = 44L,
    workers = 15L, threads_per_worker = 1L, cpus = 32:46, schema_preflight_passed = 78L,
    original_failure_records_preserved = TRUE, automatic_pruning_allowed = FALSE,
    native_score_tolerance = 1e-6, historical_realization_difference_is_exclusion = FALSE,
    status = "PREPARED_RECOVERY_REQUIRED", article_changed = FALSE, automatic_promotion = FALSE),
    file.path(output, "run_manifest.json"))
  fpf_write(fpr_hashes(c(frozen, own_code, file.path(output, c("task_plan.csv", "source_schema_preflight.csv",
    "run_manifest.json")))), file.path(output, "input_manifest.csv"))
  invisible(plan)
}

fpr2_rescore <- function(contract_path) {
  contract <- fpr_json(contract_path)
  fpf_assert(contract$recovery$action == "RESCORE_CACHED_FORECAST" &&
    identical(contract$refit_authorized, FALSE), "Cache recovery must prohibit refitting.")
  root <- contract$output_root
  state_path <- file.path(root, "task_status.json")
  fpf_assert(!file.exists(state_path), "Existing recovery state cannot be overwritten.")
  lock <- file.path(root, "worker.lock")
  fpf_assert(dir.create(lock, showWarnings = FALSE), "A worker already owns this recovery.")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  started <- Sys.time()
  base <- list(schema = fpr2_schema, task_id = contract$task$task_id, pid = Sys.getpid(),
    contract_sha256 = fpf_sha(contract_path), started_utc = format(started, tz = "UTC", usetz = TRUE),
    fit_calls = 0L, forecast_calls = 0L, action = "RESCORE_CACHED_FORECAST")
  fpr_write_json(c(base, list(status = "RUNNING")), state_path)
  answer <- tryCatch({
    retained <- fpr_table(contract$recovery$input_manifest)
    fpr_assert_hashes(retained)
    fpr_assert_hashes(fpr_table(contract$input_manifest))
    original <- contract$recovery$original_job_root
    fpf_assert(fpf_sha(contract$recovery$original_contract_path) == contract$recovery$original_contract_sha256 &&
      fpf_json(file.path(original, "task_status.json"))$status == "FAILED_RETAIN_EVIDENCE",
      "Original failed task history changed.")
    payload <- file.path(original, "quantile/models/forecast_objects.rds")
    object <- readRDS(payload)
    fpf_assert(!is.null(object$fits_fc[[1L]]$fit_train$fit), "Cached fitted posterior is absent.")
    native <- fpf_read(file.path(original, "quantile/tables/metric_draws.csv.gz"))
    paths <- fpr_q_paths(list(forecast_objects = object), contract,
      source = fpf_read(contract$root_spec$source_series_wide_path), helpers = fpr2_helpers(contract))
    fpr_write_json(fpr_json(file.path(original, "environment.json")), file.path(root, "environment.json"))
    exported <- fpr_export_paths(contract, contract_path, paths, payload, native)
    fpr_assert_hashes(retained)
    c(base, list(status = "COMPLETE", original_task_status = "FAILED_RETAIN_EVIDENCE",
      elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))), exported)
  }, error = function(e) c(base, list(status = "FAILED_RETAIN_EVIDENCE", message = conditionMessage(e),
    elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))))
  fpr_write_json(answer, state_path)
  cat("RECOVERY_STATUS", answer$status, contract$task$task_id, "\n")
  invisible(answer)
}

fpr2_health <- function(output) {
  plan <- fpf_read(file.path(output, "task_plan.csv"))
  plan$status <- vapply(plan$job_root, function(root) {
    p <- file.path(root, "task_status.json")
    if (file.exists(p)) fpf_json(p)$status else "QUEUED"
  }, character(1))
  fpf_write(plan[c("task_id", "replay_id", "family", "p", "model_variant", "chain_id", "action", "status")],
    file.path(output, "job_health.csv"))
  groups <- split(plan$status, plan$replay_id)
  result <- list(checked_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), jobs = nrow(plan),
    complete = sum(plan$status == "COMPLETE"), running = sum(plan$status == "RUNNING"),
    queued = sum(plan$status == "QUEUED"), failed = sum(plan$status == "FAILED_RETAIN_EVIDENCE"),
    completed_sources = sum(vapply(groups, function(x) length(x) == 3L && all(x == "COMPLETE"), logical(1))),
    cached_recoveries_complete = sum(plan$action == "RESCORE_CACHED_FORECAST" & plan$status == "COMPLETE"),
    new_chains_complete = sum(plan$action == "NEW_CHAIN" & plan$status == "COMPLETE"),
    article_changed = FALSE)
  fpr_write_json(result, file.path(output, "health.json"))
  result
}

fpr2_controller <- function(repo, output, script, workers = 15L, cpus = 32:46) {
  fpf_assert(identical(system2("git", c("-C", shQuote(repo), "branch", "--show-current"), stdout = TRUE),
    fpr2_branch) && length(system2("git", c("-C", shQuote(repo), "status", "--porcelain"), stdout = TRUE)) == 0L,
    "Controller requires the clean dedicated recovery branch.")
  manifest <- fpf_json(file.path(output, "run_manifest.json"))
  fpf_assert(system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE) == manifest$launch_head,
    "Commit changed after bundle freeze.")
  fpr_assert_hashes(fpf_read(file.path(output, "input_manifest.csv")))
  plan <- fpf_read(file.path(output, "task_plan.csv"))
  fpf_assert(workers >= 1L && workers <= 15L && length(cpus) == workers && !anyDuplicated(cpus) &&
    all(cpus >= 32L & cpus <= 63L), "Use at most 15 logical CPUs outside the reserved lower range.")
  lock <- file.path(output, "controller.lock")
  fpf_assert(dir.create(lock, showWarnings = FALSE), "Another recovery controller is active.")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  fpf_assert(requireNamespace("processx", quietly = TRUE), "processx required.")
  status <- function(i) {
    p <- file.path(plan$job_root[i], "task_status.json")
    if (file.exists(p)) fpf_json(p)$status else "QUEUED"
  }
  # Cache-only work is completed and validated before any expensive inference.
  for (i in which(plan$action == "RESCORE_CACHED_FORECAST")) {
    if (status(i) == "QUEUED") fpr2_rescore(plan$contract_path[i])
    if (status(i) != "COMPLETE") {
      fpr_write_json(list(status = "CACHE_RECOVERY_FAILED_NO_REFITS", task_id = plan$task_id[i]),
        file.path(output, "controller_status.json"))
      stop("Cache recovery failed; no new fits were scheduled.", call. = FALSE)
    }
  }
  for (i in which(plan$action != "NEW_CHAIN")) fpr2_verify_complete(plan[i, ])
  pending <- which(plan$action == "NEW_CHAIN")
  slots <- vector("list", workers)
  failed <- FALSE
  repeat {
    for (slot in seq_len(workers)) {
      current <- slots[[slot]]
      if (!is.null(current) && !current$process$is_alive()) {
        i <- current$index
        success <- status(i) == "COMPLETE" && current$process$get_exit_status() == 0L
        if (!success) failed <- TRUE
        cat(format(Sys.time(), tz = "UTC", usetz = TRUE), plan$task_id[i], if (success) "COMPLETE" else "FAILED", "\n")
        slots[slot] <- list(NULL)
      }
      if (is.null(slots[[slot]]) && length(pending) && !failed) {
        i <- pending[1L]
        state <- status(i)
        if (state == "COMPLETE") {
          fpr2_verify_complete(plan[i, ])
          pending <- pending[-1L]
          next
        }
        if (state != "QUEUED") { failed <- TRUE; next }
        disk <- strsplit(trimws(system2("df", c("-Pk", shQuote(output)), stdout = TRUE)[2L]), "[[:space:]]+")[[1L]]
        memory <- readLines("/proc/meminfo")
        available <- as.numeric(strsplit(trimws(sub("MemAvailable:", "", memory[startsWith(memory, "MemAvailable:")])),
          "[[:space:]]+")[[1L]][1L])
        if (as.numeric(disk[4L]) < 80 * 1024^2 || available < 64 * 1024^2) next
        pending <- pending[-1L]
        launched <- tryCatch({
          fpf_assert(fpf_sha(plan$contract_path[i]) == plan$contract_sha256[i], "Worker contract hash changed.")
          contract <- fpr_json(plan$contract_path[i])
          fpf_assert(contract$recovery$action == "NEW_CHAIN" && isTRUE(contract$refit_authorized),
            "Only never-started chain contracts may invoke inference.")
          environment <- Sys.getenv()
          if (!is.null(contract$library)) environment[["R_LIBS_USER"]] <- contract$library
          log <- file.path(plan$job_root[i], "worker.log")
          process <- processx::process$new("taskset", c("-c", as.character(cpus[slot]),
            file.path(R.home("bin"), "Rscript"), script, "--mode", "worker", "--contract", plan$contract_path[i]),
            stdout = log, stderr = "2>&1", wd = repo, env = environment, cleanup = FALSE)
          list(process = process, index = i)
        }, error = function(e) {
          failed <<- TRUE
          fpr_write_json(list(task_id = plan$task_id[i], status = "LAUNCH_FAILED", message = conditionMessage(e)),
            file.path(output, "launch_failure.json"))
          NULL
        })
        if (!is.null(launched)) {
          slots[[slot]] <- launched
          cat("LAUNCHED", plan$task_id[i], "cpu", cpus[slot], "pid", launched$process$get_pid(), "\n")
        }
      }
    }
    if (failed) pending <- integer()
    active <- sum(vapply(slots, Negate(is.null), logical(1)))
    fpr_write_json(list(status = if (failed) "DRAINING_AFTER_FAILURE" else "RUNNING", pid = Sys.getpid(),
      workers = workers, cpus = cpus, active = active, queued_in_stage = length(pending),
      updated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(output, "controller_status.json"))
    fpr2_health(output)
    if (!length(pending) && active == 0L) break
    Sys.sleep(10)
  }
  if (failed) {
    fpr_write_json(list(status = "TASK_FAILED_RETAIN_ALL_OUTPUTS", active = 0L),
      file.path(output, "controller_status.json"))
    stop("A worker failed; active work drained and all evidence retained.", call. = FALSE)
  }
  fpr_assert_hashes(fpf_read(file.path(output, "input_manifest.csv")))
  fpr_summarize(output)
  out <- output
  source(file.path(repo, "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"), local = TRUE)
  fpr2_health(output)
  fpr_write_json(list(status = "COMPLETE_REVIEW_ONLY", active = 0L, jobs = 132L,
    source_groups = 44L, display_cells = 216L, article_changed = FALSE,
    pdf = file.path(output, "review/full_500_300_reconstruction_comparison.pdf")),
    file.path(output, "controller_status.json"))
}
