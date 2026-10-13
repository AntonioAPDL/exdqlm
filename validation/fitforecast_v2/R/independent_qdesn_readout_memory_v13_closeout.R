irm13_closeout_schema <- "independent_qdesn_readout_memory_v13_selection_closeout_v1"

irm13_closeout_validate <- function(health, audit, tests, summary, paired) {
  expected <- c(smoke = 2L, selection_warm = 20L, selection = 20L,
    confirmation_warm = 6L, confirmation = 18L, fresh_warm = 12L, fresh = 36L)
  stopifnot(identical(as.character(health$stage), names(expected)),
    identical(as.integer(health$complete), c(2L, 20L, 20L, 0L, 0L, 0L, 0L)),
    all(health$failed == 0L), all(health$running == 0L), all(health$pending == 0L),
    identical(as.integer(health$gated), c(0L, 0L, 0L, 6L, 18L, 12L, 36L)),
    audit$verified_surfaces == 28L, audit$finite_outer_draws_per_surface == 300L,
    audit$first_step_guards == 192L, audit$first_step_guards_pass == 192L,
    length(audit$fitted_binary_payloads) == 0L, isFALSE(audit$average_accuracy_gain_over_static),
    isFALSE(audit$selection$strict_check_gain_over_static), isFALSE(audit$selection$article_changed),
    isFALSE(audit$selection$diagnostic_exclusion), isFALSE(audit$selection$oracle_ranking),
    tests$status == "PASS", tests$checks >= 55L, tests$package_version == "1.1.2")
  errors <- unlist(audit[c("independent_mean_error", "independent_endpoint_error",
    "independent_mean_path_error")], use.names = FALSE)
  stopifnot(length(errors) == 3L, all(is.finite(errors)), all(errors >= 0), all(errors < 1e-6),
    nrow(summary) == 140L, all(is.finite(summary$mean)),
    all(is.finite(summary$lower)), all(is.finite(summary$upper)),
    all(summary$lower <= summary$upper), all(is.finite(summary$mean_path_score)),
    !anyDuplicated(summary[c("cell", "arm", "metric")]))
  means <- aggregate(summary$mean, summary[c("arm", "metric")], mean)
  names(means)[3L] <- "mean"
  for (metric in c("forecast_mae", "forecast_check_loss")) {
    z <- means[means$metric == metric, ]
    stopifnot(nrow(z) == 7L, setequal(z$arm, c("dqlm", "static", irm13_arms)),
      all(z$mean[z$arm %in% irm13_arms] > z$mean[z$arm == "static"]))
  }
  static <- paired[paired$arm_control == "static", ]
  stopifnot(nrow(static) == 100L,
    identical(static$strict_gain, static$mean_candidate < static$mean_control),
    sum(static$strict_gain) == 20L,
    sum(static$strict_gain & grepl("^forecast", static$metric)) == 9L,
    audit$finite_cell_metric_gains_vs_static == 20L,
    audit$finite_forecast_metric_gains_vs_static == 9L)
  invisible(TRUE)
}

irm13_closeout_processes <- function() {
  pattern <- paste0("[i]ndependent_qdesn_readout_memory_v13.R worker|",
    "[r]un_independent_qdesn_readout_memory_v13.sh")
  found <- suppressWarnings(system2("pgrep", c("-af", shQuote(pattern)),
    stdout = TRUE, stderr = TRUE))
  status <- attr(found, "status") %||% 0L
  if (status != 1L) stop("Cannot close campaign: active lane process or process-query failure: ",
    paste(found, collapse = "\n"))
  list(pattern = pattern, exit_status = status, active_jobs = 0L,
    checked_at_UTC = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"))
}

irm13_closeout_create <- function(repo, run, audit_dir, output) {
  repo <- normalizePath(repo, mustWork = TRUE); run <- normalizePath(run, mustWork = TRUE)
  audit_dir <- normalizePath(audit_dir, mustWork = TRUE)
  stopifnot(!dir.exists(output), !file.exists(file.path(run, "closeout.json")),
    !file.exists(file.path(run, "closeout_manifest.csv")),
    !file.exists(file.path(run, "STOP_NEW_SCHEDULING")))
  irm13_verify(run)
  iqt12_verify(file.path(audit_dir, "analysis/audit_hashes.csv"))
  iqt12_verify(file.path(audit_dir, "report_hashes.csv"))
  audit <- iqt12_read(file.path(audit_dir, "analysis/audit.json"))
  tests <- iqt12_read(file.path(audit_dir, "focused_tests.json"))
  health <- irm13_health(run)
  summary <- read.csv(file.path(audit_dir, "analysis/summary.csv"))
  paired <- read.csv(file.path(audit_dir, "analysis/paired.csv"))
  irm13_closeout_validate(health, audit, tests, summary, paired)
  process <- irm13_closeout_processes()
  state <- iqt12_read(file.path(run, "campaign.json"))
  stopifnot(identical(state$head, audit$source_head))
  sources <- file.path(repo, "validation/fitforecast_v2", c(
    "R/independent_qdesn_readout_memory_v13_closeout.R",
    "scripts/close_independent_qdesn_readout_memory_v13.R",
    "scripts/audit_independent_qdesn_readout_memory_v13_completed.R",
    "tests/test_independent_qdesn_readout_memory_v13_closeout.R"))
  stopifnot(all(file.exists(sources)))
  regression <- iqt12_read(file.path(audit_dir, "closeout_tests.json"))
  regression_hashes <- do.call(rbind, lapply(regression$source_hashes, as.data.frame))
  stopifnot(regression$status == "PASS", regression$checks >= 19L,
    identical(regression_hashes$path, sources),
    identical(regression_hashes$sha256, unname(tools::sha256sum(sources))))
  original_manifests <- c(file.path(run, paste0(c("source", "package", "input", "frozen",
    "control_import"), "_hashes.csv")),
    list.files(file.path(run, "plans"), "_hashes[.]csv$", full.names = TRUE),
    list.files(file.path(run, "evidence"), "manifest[.]csv$", recursive = TRUE, full.names = TRUE),
    file.path(run, "selection_review_hashes.csv"))
  protected <- sort(unique(c(run, state$parent, state$library,
    dirname(read.csv(file.path(run, "controls.csv"))$manifest))))
  closeout <- list(schema = irm13_closeout_schema, status = "CLOSED",
    scientific_decision = "NO_AVERAGE_PRIMARY_FORECAST_GAIN_RETAIN_EXISTING_ARTICLE_AUTHORITY",
    scientific_head = state$head,
    closeout_source_head = system2("git", c("-C", shQuote(repo), "rev-parse", "HEAD"), stdout = TRUE),
    run = run, audit_directory = audit_dir,
    completed_at_UTC = "2026-10-13T06:57:35Z",
    frozen_at_UTC = format(Sys.time(), tz = "UTC", format = "%Y-%m-%dT%H:%M:%SZ"),
    family = "gausmix", likelihood = "al", prior = "RHS_NS", p = .05, gamma_fixed = TRUE,
    completed_jobs = 42L, implementation_failures = 0L, active_jobs = 0L,
    launched_jobs_remaining = 0L, imported_controls = 8L,
    conditional_jobs_declined_without_launch = 72L,
    health = health, selected_new_arm = "tau_half", overall_primary_winner = "static",
    finite_metric_cell_gains_over_static = 20L, finite_forecast_metric_cell_gains_over_static = 9L,
    diagnostic_exclusion = FALSE, minimum_gain_threshold = 0,
    reproduction_tolerance = 1e-6, verification = audit[c("verified_surfaces",
      "independent_mean_error", "independent_endpoint_error", "independent_mean_path_error",
      "first_step_guards", "first_step_guards_pass", "manifest_count", "manifest_rows")],
    tests = list(focused_v13_checks = tests$checks, closeout_checks = regression$checks,
      status = tests$status),
    process_check = process, package_version = "1.1.2", package_repository = "CRAN", R_version = "4.6.0",
    article_changed = FALSE, article_files_to_publish = character(),
    integration_scope = "shared_validation_code_and_closeout_only_no_article_replacement",
    next_experiment_authorized = FALSE, protected_runtime_paths = protected,
    storage_MiB_before_closeout = audit$run_size_MiB, fitted_model_binary_payloads = 0L,
    uncertainty_caveat = "QDESN shared_beta and DQLM latent_marginal/product coupling differ",
    exclusions = c("local_trackers", "posterior draws", "source trajectories", "review PDFs",
      "R library", "compiled runtime cache", "logs", "future pilot and confirmation jobs"))
  dir.create(output, recursive = TRUE)
  for (name in c("summary", "means", "paired", "counts", "relative", "attribution", "parts",
      "diagnostics", "lead", "origin", "cell_origin", "cell_lead", "phase_means", "timing")) {
    path <- file.path(audit_dir, "analysis", paste0(name, ".csv"))
    stopifnot(file.copy(path, file.path(output, basename(path)), overwrite = FALSE))
  }
  stopifnot(file.copy(file.path(run, "environment.json"), file.path(output, "environment.json")))
  iqt12_csv(health, file.path(output, "health.csv"))
  iqt12_json(audit, file.path(output, "independent_score_audit.json"))
  iqt12_json(tests, file.path(output, "focused_tests.json"))
  iqt12_json(regression, file.path(output, "closeout_tests.json"))
  iqt12_hash(original_manifests, file.path(output, "runtime_manifest_index.csv"))
  iqt12_json(closeout, file.path(output, "closeout.json"))
  iqt12_json(closeout, file.path(run, "closeout.json"))
  writeLines(c("CLOSED: no average primary forecast gain; 72 conditional jobs declined.",
    "No automatic restart. New scientific design requires separate user authorization."),
    file.path(run, "STOP_NEW_SCHEDULING"))
  files <- list.files(output, full.names = TRUE)
  iqt12_csv(data.frame(path = basename(files), bytes = file.info(files)$size,
    sha256 = unname(tools::sha256sum(files))), file.path(output, "artifact_manifest.csv"))
  iqt12_hash(c(files, file.path(output, "artifact_manifest.csv"), sources, original_manifests,
    file.path(audit_dir, c("analysis/audit_hashes.csv", "report_hashes.csv")),
    file.path(run, c("closeout.json", "STOP_NEW_SCHEDULING"))),
    file.path(run, "closeout_manifest.csv"))
  irm13_closeout_verify(run, output)
  invisible(closeout)
}

irm13_closeout_artifacts <- function(output) {
  m <- read.csv(file.path(output, "artifact_manifest.csv"))
  paths <- file.path(output, m$path)
  stopifnot(nrow(m) > 0L, !anyDuplicated(m$path), identical(m$path, basename(m$path)),
    all(file.exists(paths)), identical(as.numeric(file.info(paths)$size), as.numeric(m$bytes)),
    identical(unname(tools::sha256sum(paths)), m$sha256))
  invisible(TRUE)
}

irm13_closeout_verify <- function(run, output) {
  irm13_verify(run)
  irm13_closeout_artifacts(output)
  iqt12_verify(file.path(output, "runtime_manifest_index.csv"))
  a <- iqt12_read(file.path(output, "closeout.json"))
  b <- iqt12_read(file.path(run, "closeout.json"))
  stopifnot(identical(a, b), a$schema == irm13_closeout_schema, a$status == "CLOSED",
    a$completed_jobs == 42L, a$implementation_failures == 0L, a$active_jobs == 0L,
    a$conditional_jobs_declined_without_launch == 72L, isFALSE(a$article_changed),
    length(a$article_files_to_publish) == 0L, isFALSE(a$next_experiment_authorized),
    file.exists(file.path(run, "STOP_NEW_SCHEDULING")))
  irm13_closeout_validate(irm13_health(run), iqt12_read(file.path(output, "independent_score_audit.json")),
    iqt12_read(file.path(output, "focused_tests.json")), read.csv(file.path(output, "summary.csv")),
    read.csv(file.path(output, "paired.csv")))
  invisible(TRUE)
}
