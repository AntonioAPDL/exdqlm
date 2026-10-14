fpr_schema <- "independent_forecast_prefix_reconstruction_v1"
fpr_branch <- "validation/independent-forecast-prefix-reconstruction-v1-20261013"
fpr_json <- function(path) jsonlite::read_json(path, simplifyVector = FALSE)
fpr_table <- function(x) {
  if (is.data.frame(x)) return(x)
  do.call(rbind, lapply(x, function(row) as.data.frame(row, stringsAsFactors = FALSE)))
}
fpr_write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".", Sys.getpid(), ".tmp")
  jsonlite::write_json(x, tmp, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)
  fpf_assert(file.rename(tmp, path), "Cannot atomically save reconstruction metadata.")
}
fpr_save <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(path, ".", Sys.getpid(), ".tmp")
  saveRDS(x, tmp, compress = "gzip")
  fpf_assert(file.rename(tmp, path), "Cannot atomically save protected posterior evidence.")
}
fpr_hashes <- function(paths) {
  paths <- unique(normalizePath(paths, mustWork = TRUE))
  data.frame(path = paths, sha256 = vapply(paths, fpf_sha, character(1)), bytes = file.info(paths)$size)
}
fpr_assert_hashes <- function(m) {
  fpf_assert(all(file.exists(m$path)) && all(vapply(m$path, fpf_sha, character(1)) == m$sha256),
    "Frozen reconstruction input or code has changed.")
  invisible(TRUE)
}
fpr_source_files <- function(root) {
  c(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(root, "validation/fitforecast_v2/R"), pattern = "[.]R$", full.names = TRUE),
    list.files(file.path(root, "src"), pattern = "[.](cpp|h|hpp|so)$|Makevars", full.names = TRUE),
    file.path(root, c("DESCRIPTION", "NAMESPACE", "scripts/pipeline_real_main.R")))
}
fpr_relocate <- function(x, old, new) {
  if (is.list(x)) return(lapply(x, fpr_relocate, old = old, new = new))
  if (is.character(x)) {
    use <- startsWith(x, paste0(old, "/")) | x == old
    x[use] <- paste0(new, substring(x[use], nchar(old) + 1L))
  }
  x
}
fpr_q_config <- function(original) {
  x <- original
  x$outputs$keep_draws <- TRUE
  x$outputs$save_forecast_objects <- TRUE
  x$outputs$keep_mcmc_vb_init <- TRUE
  x$outputs$retain_full_rds_on_failure <- TRUE
  x$outputs$retention_profile <- "protected_selected_source_reconstruction"
  # Restore output controls to demonstrate that no scientific field changed.
  normalized <- x
  normalized$outputs <- original$outputs
  fpf_assert(isTRUE(all.equal(normalized, original, tolerance = 0)), "Q-DESN scientific config changed.")
  x
}
fpr_materialize <- function(repo, output) {
  fpf_assert(identical(system2("git", c("-C", shQuote(repo), "branch", "--show-current"), stdout = TRUE),
    fpr_branch), "Reconstruction requires its dedicated IND branch.")
  fpf_assert(!file.exists(file.path(output, "run_manifest.json")), "Refusing to overwrite a frozen run.")
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output)
  audit <- file.path(repo, "validation/fitforecast_v2/audits/independent_forecast_prefix_intervals_v1_20261013")
  tasks <- fpf_read(file.path(audit, "pending_selected_source_reconstruction_manifest.csv"))
  locators <- fpf_read(file.path(audit, "recovery_inventory.csv"))
  fpf_assert(nrow(tasks) == 132L && !anyDuplicated(tasks$task_id), "Selected-source task surface changed.")
  sources <- file.path(repo, "validation/fitforecast_v2/local_trackers/prefix_reconstruction_sources")
  libraries <- file.path(sources, "cran_1p1p1_Rlib")
  fpf_assert(file.exists(file.path(libraries, "exdqlm/DESCRIPTION")), "Private CRAN 1.1.1 runtime missing.")
  source_hashes <- lapply(c("c72e19f3", "d6bc4c5e", "7ace661"), function(id)
    fpr_hashes(fpr_source_files(file.path(sources, id))))
  names(source_hashes) <- c("c72e19f3", "d6bc4c5e", "7ace661")
  package_hashes <- fpr_hashes(list.files(file.path(libraries, "exdqlm"), recursive = TRUE, full.names = TRUE))
  rows <- list()
  evidence <- c(file.path(audit, c("pending_selected_source_reconstruction_manifest.csv", "recovery_inventory.csv")))
  for (i in seq_len(nrow(tasks))) {
    task <- tasks[i, ]
    p <- locators$config_path[match(task$task_id, locators$task_id)]
    original <- fpr_json(p)
    engine <- if (grepl("^qdesn", task$model_variant)) "qdesn" else "dqlm"
    snapshot_id <- if (task$model_variant == "exdqlm") "7ace661" else
      if (task$replay_id == "idolp_v2_winner_three_chain_pool") "d6bc4c5e" else "c72e19f3"
    snapshot <- normalizePath(file.path(sources, snapshot_id), mustWork = TRUE)
    job <- file.path(output, "jobs", task$task_id)
    dir.create(job, recursive = TRUE, showWarnings = FALSE)
    if (engine == "qdesn") {
      root_spec <- original$root_spec
      config <- fpr_q_config(original$config)
      inputs <- c(original$observed_path, root_spec$source_series_wide_path)
      contract <- list(engine = engine, task = as.list(task), root_spec = root_spec,
        config = config, observed_path = original$observed_path, output_root = job,
        source_config_path = normalizePath(p), source_config_sha256 = fpf_sha(p),
        source_root = snapshot, source_commit = system2("git", c("-C", shQuote(snapshot), "rev-parse", "HEAD"), stdout = TRUE),
        package_version = "1.0.0", library = NULL)
      fpf_assert(config$inference$mcmc$n_burn == 5000 && config$inference$mcmc$n_mcmc == 20000,
        "Unexpected frozen MCMC budget.")
      fpf_assert(task$model_variant != "qdesn_exal_rhs_ns" ||
        config$inference$mcmc$slice$core_update_mode == "m0_v_collapsed_support_logit", "exAL M0 changed.")
    } else {
      config <- fpr_relocate(original, original$run_root, file.path(job, "dynamic"))
      config$repo_root <- snapshot
      config$harness_root <- file.path(snapshot, "validation/fitforecast_v2")
      config$handoff$prune_fit_on_success <- FALSE
      inputs <- c(original$series_wide_path, original$true_quantile_grid_path)
      contract <- list(engine = engine, task = as.list(task), config = config, output_root = job,
        source_config_path = normalizePath(p), source_config_sha256 = fpf_sha(p),
        source_root = snapshot, source_commit = system2("git", c("-C", shQuote(snapshot), "rev-parse", "HEAD"), stdout = TRUE),
        package_version = if (task$model_variant == "exdqlm") "1.1.1" else "1.0.0",
        library = if (task$model_variant == "exdqlm") libraries else NULL)
      fpf_assert(original$budget$mcmc$n_burn == 5000 && original$budget$mcmc$n_mcmc == 20000,
        "Unexpected frozen dynamic MCMC budget.")
      fpf_assert(task$model_variant != "exdqlm" || config$budget$mcmc$mh_proposal == "collapsed_slice",
        "Corrected exDQLM transition changed.")
    }
    fpf_assert(all(file.exists(inputs)), paste("Required source data missing:", task$task_id))
    contract$schema <- fpr_schema
    contract$refit_authorized <- TRUE
    contract$selection_policy <- "frozen_v14_sources_no_screening_no_holdout_reselection"
    contract$input_manifest <- fpr_hashes(c(inputs, p, task$path, task$metric_draws_path))
    contract$code_manifest <- source_hashes[[snapshot_id]]
    if (!is.null(contract$library)) contract$package_manifest <- package_hashes
    contract_path <- file.path(job, "contract.json")
    fpr_write_json(contract, contract_path)
    row <- task
    row$engine <- engine
    row$contract_path <- contract_path
    row$contract_sha256 <- fpf_sha(contract_path)
    row$package_version <- contract$package_version
    row$source_commit <- contract$source_commit
    row$pilot <- !any(vapply(rows, function(r) identical(r$model_variant, row$model_variant), logical(1)))
    row$refit_authorized <- TRUE
    rows[[i]] <- row
    evidence <- c(evidence, contract_path, contract$input_manifest$path)
  }
  plan <- do.call(rbind, rows)
  fpf_write(plan, file.path(output, "task_plan.csv"))
  roles <- fpf_read(file.path(audit, "available_display_intervals.csv"))
  roles <- roles[roles$cutoff == 1000L, ]
  fpf_assert(nrow(roles) == 72L, "Article role mapping incomplete.")
  fpf_write(roles, file.path(output, "article_baseline.csv"))
  style <- "/data/jaguir26/local/src/Article-Q-DESN/.worktrees/ind_qdesn_readout_memory_v13_20261013/validation/fitforecast_v2/local_trackers/article_forecast_prefix_review_20261013/article_inputs/qdesn_evaluation_figure_style.R"
  fpf_assert(file.copy(style, file.path(output, "frozen_article_style.R")), "Cannot freeze article plotting style.")
  tarball <- "/data/jaguir26/local/src/exdqlm__wt__independent_exdqlm_mcmc_rolling_state_fix_v1_1p0p0/validation/fitforecast_v2/local_trackers/independent_exdqlm_mcmc_rolling_state_fix_v1/package/exdqlm_1.1.1.tar.gz"
  fpf_assert(fpf_sha(tarball) == "3f3ed643ded7602fd62357d7f62024ca9071e0096214456650ed2de79722443e",
    "Historical CRAN source hash changed.")
  fpf_assert(file.copy(tarball, file.path(output, "exdqlm_1.1.1.tar.gz")), "Cannot retain historical CRAN source.")
  originals <- unique(evidence[!startsWith(evidence, paste0(output, "/"))])
  backups <- lapply(originals, function(p) {
    sha <- fpf_sha(p)
    target <- file.path(output, "protected_source_inputs", sha, basename(p))
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (!file.exists(target)) fpf_assert(file.copy(p, target), "Cannot protect a source input.")
    fpf_assert(fpf_sha(target) == sha, "Protected source-input copy differs.")
    data.frame(original_path = normalizePath(p), path = normalizePath(target), sha256 = sha,
      bytes = file.info(target)$size)
  })
  backup_manifest <- file.path(output, "protected_source_input_manifest.csv")
  backups <- do.call(rbind, backups)
  fpf_write(backups, backup_manifest)
  own_code <- file.path(repo, c("validation/fitforecast_v2/R/forecast_prefix_metric_intervals_v1.R",
    "validation/fitforecast_v2/R/forecast_prefix_reconstruction_v1.R",
    "validation/fitforecast_v2/scripts/run_forecast_prefix_reconstruction_v1.R",
    "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"))
  fpf_write(fpr_hashes(c(evidence, backups$path, backup_manifest, own_code, file.path(output, c("task_plan.csv", "article_baseline.csv",
    "frozen_article_style.R", "exdqlm_1.1.1.tar.gz")))), file.path(output, "input_manifest.csv"))
  fpr_write_json(list(schema = fpr_schema, status = "PREPARED_NOT_LAUNCHED", jobs = 132L,
    selected_sources = 44L, pilot_jobs = 4L, workers = 15L, threads_per_worker = 1L,
    launch_head = system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE),
    branch = fpr_branch, authoritative_article_modified = FALSE,
    posterior_protection = "retain_all_selected_source_capsules_and_joint_forecast_paths",
    old_score_agreement_tolerance = 1e-6, old_score_agreement_is_promotion_gate = FALSE),
    file.path(output, "run_manifest.json"))
  invisible(plan)
}
fpr_q_paths <- function(summary, contract) {
  entry <- summary$forecast_objects$fits_fc[[1L]]
  n <- as.integer(contract$task$n_draws)
  source <- getFromNamespace(".qdesn_validation_read_source_series", "exdqlm")(contract$root_spec)
  grid <- fpf_grid()
  origins <- unique(grid$origin)
  local <- match(origins, source$source_index)
  fpf_assert(!anyNA(local), "Quantile source/origin alignment failed.")
  fc <- entry$forecast_full
  scale <- getFromNamespace(".qdesn_validation_lead_export_scale_spec", "exdqlm")(fc)
  count <- min(ncol(as.matrix(entry$mu_draws_tr)),
    vapply(fc$mu_by_origin, function(x) ncol(as.matrix(x)), integer(1)))
  idx <- getFromNamespace(".qdesn_validation_even_draw_indices", "exdqlm")(count, n)
  fpf_assert(length(idx) == n, "Reconstructed quantile draw budget differs.")
  q <- do.call(rbind, lapply(seq_along(origins), function(i) {
    j <- match(local[i], fc$origins)
    fpf_assert(!is.na(j), "Selected origin absent from quantile lattice.")
    as.matrix(fc$mu_by_origin[[j]])[seq_len(sum(grid$origin == origins[i])), idx, drop = FALSE] *
      scale$scale + scale$center
  }))
  list(q = q, draw_index = idx)
}
fpr_d_paths <- function(fit, config, data, task) {
  grid <- fpf_grid()
  origins <- unique(grid$origin)
  fit_origin <- fit
  previous <- 9000L
  q <- do.call(rbind, lapply(seq_along(origins), function(i) {
    origin <- origins[i]
    fit_origin <<- if (identical(config$state_update_strategy, "incremental_teacher_forced"))
      ffv2_advance_fit_between_source_origins(fit_origin, config, data, previous, origin) else
      ffv2_extend_fit_to_source_origin(fit, config, data, origin)
    previous <<- origin
    k <- sum(grid$origin == origin)
    future <- ffv2_make_future_model_arrays(fit_origin$model, k)
    forecast <- exdqlm::exdqlmForecast(start.t = length(fit_origin$y), k = k, m1 = fit_origin,
      fFF = future$fFF, fGG = future$fGG, plot = FALSE, return.draws = TRUE,
      n.samp = as.integer(config$budget$forecast_draws), seed = as.integer(config$seed) + 1L + i)
    cat(sprintf("PREFIX_FORECAST origin=%d/34 source_index=%d\n", i, origin))
    ffv2_latent_forecast_draws(forecast, as.integer(task$n_draws), as.integer(config$seed) + 100001L + i)
  }))
  list(q = q, draw_index = seq_len(as.integer(task$n_draws)))
}
fpr_dynamic_diagnostics <- function(fit, cfg) {
  summarize <- function(x) {
    x <- as.numeric(x)
    if (!length(x)) return(list(n = 0L))
    fpf_assert(all(is.finite(x)), "Non-finite dynamic parameter draws.")
    list(n = length(x), mean = mean(x), sd = stats::sd(x),
      ess = if (stats::sd(x) > 0) as.numeric(coda::effectiveSize(x)) else length(x))
  }
  list(gamma_fixed = isTRUE(cfg$dqlm_ind), gamma = summarize(fit$samp.gamma),
    sigma = summarize(fit$samp.sigma), requested_proposal = cfg$budget$mcmc$mh_proposal,
    observed_proposal = fit$mh.diagnostics$proposal, state_update_method = cfg$state_update_method)
}
fpr_worker <- function(contract_path) {
  contract <- fpr_json(contract_path)
  fpf_assert(contract$schema == fpr_schema && isTRUE(contract$refit_authorized), "Refit is not authorized.")
  root <- contract$output_root
  task <- as.data.frame(contract$task, stringsAsFactors = FALSE)
  state_path <- file.path(root, "task_status.json")
  fpf_assert(!file.exists(state_path), "Existing task state requires explicit audited resume, not a second refit.")
  lock <- file.path(root, "worker.lock")
  fpf_assert(dir.create(lock, showWarnings = FALSE), "A worker already owns this source.")
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  started <- Sys.time()
  base <- list(schema = fpr_schema, task_id = task$task_id, pid = Sys.getpid(),
    contract_sha256 = fpf_sha(contract_path), started_utc = format(started, tz = "UTC", usetz = TRUE))
  fpr_write_json(c(base, list(status = "RUNNING")), state_path)
  answer <- tryCatch({
    fpr_assert_hashes(fpr_table(contract$input_manifest))
    fpr_assert_hashes(fpr_table(contract$code_manifest))
    if (!is.null(contract$package_manifest)) fpr_assert_hashes(fpr_table(contract$package_manifest))
    source_root <- contract$source_root
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(source_root)
    if (is.null(contract$library)) pkgload::load_all(source_root, quiet = TRUE) else {
      .libPaths(c(contract$library, .libPaths()))
      suppressPackageStartupMessages(library(exdqlm))
      fpf_assert(utils::packageDescription("exdqlm")$Repository == "CRAN", "CRAN runtime identity changed.")
    }
    fpf_assert(as.character(utils::packageVersion("exdqlm")) == contract$package_version, "Wrong package version.")
    harness <- file.path(source_root, "validation/fitforecast_v2")
    source(file.path(harness, "R/utils.R"))
    ffv2_source_all(harness)
    if (!is.null(contract$library)) {
      # The historical state helper used pkgload's unexported symbol exposure.
      assign("make_df_mat", getFromNamespace("make_df_mat", "exdqlm"), envir = .GlobalEnv)
    }
    runtime <- list(R = R.version.string, package_version = as.character(utils::packageVersion("exdqlm")),
      package_path = find.package("exdqlm"), source_commit = contract$source_commit,
      RNGkind = RNGkind(), session_info = capture.output(sessionInfo()),
      thread_environment = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))))
    fpr_write_json(runtime, file.path(root, "environment.json"))
    original_targets <- fpf_read(task$path)
    fpf_assert(nrow(original_targets) == 1000L, "Original target evidence incomplete.")
    if (contract$engine == "qdesn") {
      run <- getFromNamespace(".qdesn_validation_run_one_method", "exdqlm")(
        method = "mcmc", root_spec = contract$root_spec,
        defaults = list(pipeline = list(outputs = contract$config$outputs), metrics = contract$config$metrics),
        file_long = contract$observed_path, method_dir = file.path(root, "quantile"),
        cfg_override = contract$config, fit_request_extra = list(reconstruction = base))
      fpf_assert(run$status == "SUCCESS", paste("Frozen quantile source failed:", run$error_message))
      path <- file.path(root, "quantile/models/forecast_objects.rds")
      fpf_assert(file.exists(path), "Selected posterior was not retained.")
      native <- fpf_read(file.path(root, "quantile/tables/metric_draws.csv.gz"))
      paths <- fpr_q_paths(run$summary, contract)
      payload <- path
    } else {
      cfg <- contract$config
      for (field in names(cfg)) if (endsWith(field, "_path") && is.character(cfg[[field]]) &&
        startsWith(cfg[[field]], root)) dir.create(dirname(cfg[[field]]), recursive = TRUE, showWarnings = FALSE)
      data <- ffv2_load_row_data(cfg)
      model <- ffv2_build_dynamic_model(cfg, nrow(data$train))
      payload <- file.path(root, "protected_fitted_posterior.rds")
      if (!is.null(contract$recovered_fit_path)) {
        fpf_assert(fpf_sha(contract$recovered_fit_path) == contract$recovered_fit_sha256,
          "Retained fitted posterior hash mismatch.")
        recovered <- readRDS(contract$recovered_fit_path)
        fields <- c("budget", "models", "model_spec_hash", "dqlm_ind", "tau", "seed", "state_update_method")
        fpf_assert(isTRUE(all.equal(recovered$config[fields], cfg[fields], tolerance = 0)) &&
          identical(recovered$data, data), "Retained fit belongs to another scientific configuration.")
        fit <- recovered$fit
        payload <- contract$recovered_fit_path
      } else {
        set.seed(as.integer(cfg$seed))
        fit <- ffv2_fit_row(cfg, data, model, started_at = started)
        fpr_save(list(fit = fit, config = cfg, data = data, task = task,
          RNGkind = RNGkind(), source_commit = contract$source_commit), payload)
      }
      fpr_write_json(fpr_dynamic_diagnostics(fit, cfg), file.path(root, "inference_diagnostics.json"))
      fpf_assert(max(abs(data$forecast$y - original_targets$y)) <= 1e-6 &&
        max(abs(data$forecast$q_true - original_targets$q_true)) <= 1e-6, "Dynamic targets changed.")
      paths <- fpr_d_paths(fit, cfg, data, task)
      native <- NULL
    }
    scores <- fpf_score_paths(paths$q, fpf_grid(), original_targets$y, original_targets$q_true,
      task$p, chain = task$chain_id, source_draw_index = paths$draw_index)
    full_check <- scores[scores$cutoff == 1000L, ]
    direct_mae <- colMeans(abs(sweep(paths$q, 1L, original_targets$q_true, "-")))
    direct_check <- colMeans((original_targets$y - paths$q) * (task$p - (original_targets$y < paths$q)))
    fpf_assert(max(abs(full_check$forecast_mae - direct_mae),
      abs(full_check$forecast_check_loss - direct_check)) <= 1e-6, "Independent direct scoring check failed.")
    if (!is.null(native)) {
      native$chain_id <- task$chain_id
      fpf_verify_full(scores, native)
    }
    fpr_save(list(schema = "independent_joint_quantile_forecast_paths_v1", q = paths$q,
      grid = fpf_grid(), y = original_targets$y, oracle = original_targets$q_true,
      p = task$p, chain_id = task$chain_id, source_draw_index = paths$draw_index,
      reconstruction_id = task$task_id, coupling = if (contract$engine == "qdesn")
        "native_shared_readout_draws" else "historical_latent_gaussian_product_coupling"),
      file.path(root, "protected_joint_forecast_paths.rds"))
    fpf_write(scores, file.path(root, "prefix_draws.csv.gz"))
    old <- fpf_read(task$metric_draws_path)
    full <- scores[scores$cutoff == 1000L, ]
    comparison <- do.call(rbind, lapply(c("forecast_mae", "forecast_check_loss"), function(metric) {
      data.frame(task_id = task$task_id, metric = metric, old_mean = mean(old[[metric]]),
        new_mean = mean(full[[metric]]), mean_change = mean(full[[metric]]) - mean(old[[metric]]),
        max_draw_difference = max(abs(full[[metric]] - old[[metric]])),
        exact_score_reproduction_1e6 = max(abs(full[[metric]] - old[[metric]])) <= 1e-6)
    }))
    fpf_write(comparison, file.path(root, "original_score_comparison.csv"))
    capsule <- list(schema = "independent_prefix_refit_capsule_v1", task_id = task$task_id,
      engine = contract$engine, task = contract$task, contract_path = contract_path,
      fitted_payload_path = normalizePath(payload), fitted_payload_sha256 = fpf_sha(payload),
      protected_joint_paths_path = file.path(root, "protected_joint_forecast_paths.rds"),
      protected_joint_paths_sha256 = fpf_sha(file.path(root, "protected_joint_forecast_paths.rds")),
      source_input_backup_manifest = file.path(dirname(dirname(root)), "protected_source_input_manifest.csv"),
      package_version = contract$package_version, source_commit = contract$source_commit,
      automatic_pruning_allowed = FALSE, old_realization_reproduced = all(comparison$exact_score_reproduction_1e6))
    fpr_write_json(capsule, file.path(root, "protected_capsule.json"))
    files <- c(payload, file.path(root, c("protected_joint_forecast_paths.rds", "prefix_draws.csv.gz",
      "original_score_comparison.csv", "protected_capsule.json", "environment.json")))
    fpf_write(fpr_hashes(files), file.path(root, "retention_manifest.csv"))
    fpr_assert_hashes(fpr_table(contract$input_manifest))
    c(base, list(status = "COMPLETE", fit_calls = if (is.null(contract$recovered_fit_path)) 1L else 0L,
      forecasts_completed = 34L,
      package_version = contract$package_version, prefix_draws_sha256 = fpf_sha(file.path(root, "prefix_draws.csv.gz")),
      retention_manifest_sha256 = fpf_sha(file.path(root, "retention_manifest.csv")),
      old_realization_reproduced = capsule$old_realization_reproduced,
      elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs"))))
  }, error = function(e) c(base, list(status = "FAILED_RETAIN_EVIDENCE", message = conditionMessage(e),
    elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))))
  fpr_write_json(answer, state_path)
  cat("RECONSTRUCTION_STATUS", answer$status, task$task_id, "\n")
  invisible(answer)
}
fpr_summarize <- function(output) {
  plan <- fpf_read(file.path(output, "task_plan.csv"))
  baseline <- fpf_read(file.path(output, "article_baseline.csv"))
  complete <- vapply(plan$task_id, function(id) {
    p <- file.path(output, "jobs", id, "task_status.json")
    file.exists(p) && identical(fpf_json(p)$status, "COMPLETE")
  }, logical(1))
  fpf_assert(all(complete), "Complete reconstruction required before producing comparison figures.")
  draws <- lapply(plan$task_id, function(id) {
    root <- file.path(output, "jobs", id)
    state <- fpf_json(file.path(root, "task_status.json"))
    fpf_assert(state$contract_sha256 == plan$contract_sha256[match(id, plan$task_id)] &&
      fpf_sha(file.path(root, "retention_manifest.csv")) == state$retention_manifest_sha256,
      "Completed source does not match its frozen contract or retention manifest.")
    fpr_assert_hashes(fpf_read(file.path(root, "retention_manifest.csv")))
    p <- file.path(root, "prefix_draws.csv.gz")
    fpf_assert(fpf_sha(p) == state$prefix_draws_sha256, "Reconstructed draw hash mismatch.")
    x <- fpf_read(p)
    x$replay_id <- plan$replay_id[match(id, plan$task_id)]
    x
  })
  summaries <- lapply(unique(plan$replay_id), function(id) {
    z <- do.call(rbind, draws[plan$replay_id == id])
    z <- z[z$cutoff %in% c(300L, 500L, 1000L), ]
    x <- fpf_pool(z, plan$quantile_type[match(id, plan$replay_id)])
    fpf_assert(all(x$n_chains == 3L), "Incomplete repeated-chain source summary.")
    x$replay_id <- id
    x
  })
  summary <- do.call(rbind, summaries)
  result <- list()
  for (i in seq_len(nrow(baseline))) for (n in c(1000L, 500L, 300L)) {
    role <- baseline[i, ]
    metric <- if (role$metric_role == "forecast_mae") "forecast_mae" else "forecast_check_loss"
    x <- summary[summary$replay_id == role$replay_id & summary$metric == metric & summary$cutoff == n, ]
    fpf_assert(nrow(x) == 1L, "Source-specific figure mapping failed.")
    for (field in c("posterior_mean", "posterior_median", "cri_lower", "cri_upper", "n_draws", "n_chains"))
      role[[field]] <- x[[field]]
    role$cutoff <- n
    result[[length(result) + 1L]] <- role
  }
  fpf_write(do.call(rbind, result), file.path(output, "reconstructed_display_intervals.csv"))
  comparisons <- do.call(rbind, lapply(plan$task_id, function(id)
    fpf_read(file.path(output, "jobs", id, "original_score_comparison.csv"))))
  fpf_write(comparisons, file.path(output, "all_original_score_comparisons.csv"))
  fpr_write_json(list(status = "COMPLETE_RECONSTRUCTION_REVIEW_ONLY", jobs = sum(complete),
    display_cells = length(result), article_changed = FALSE, automatic_promotion = FALSE),
    file.path(output, "closeout.json"))
  invisible(result)
}
