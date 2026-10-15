ifr_models <- c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")
ifr_families <- c("normal", "laplace", "gausmix")
ifr_levels <- c(.05, .25, .5)
ifr_metrics <- c("forecast_mae", "forecast_check")
ifr_summary_fields <- c("posterior_mean", "cri_lower", "posterior_median", "cri_upper", "n_draws", "n_chains")

ifr_policy <- function(path) {
  p <- jsonlite::read_json(path, simplifyVector = TRUE)
  fpf_assert(p$schema == "independent_forecast_reporting_v1" &&
    p$primary_cutoff == 300L && p$sensitivity_cutoff == 500L &&
    p$deprecated_cutoff == 1000L && p$deprecated_status == "DEPRECATED_FOR_REPORTING" &&
    isTRUE(p$retrospective_scope_change) && isTRUE(p$retain_historical_evidence) &&
    identical(p$allow_refit, FALSE) && identical(p$allow_forecast_resimulation, FALSE) &&
    identical(p$allow_winner_reselection, FALSE) && p$fit_start == 8501L && p$fit_end == 9000L &&
    p$origin_stride == 30L && p$maximum_lead == 30L && p$interval_probability == .95 &&
    p$numerical_tolerance > 0 && p$numerical_tolerance <= 1e-6,
    "Reporting policy is outside the authorized scope.")
  p
}

ifr_key <- function(x, window = TRUE) {
  fields <- c("inference", "family", "tau", "model_variant", "metric_role", if (window) "cutoff")
  do.call(paste, c(x[fields], sep = "|"))
}

ifr_check_display <- function(x, policy) {
  fpf_assert(all(c("inference", "family", "tau", "model_variant", "metric_role", "cutoff",
    "replay_id", "forecast_pairs", "forecast_origins", "last_target", ifr_summary_fields) %in% names(x)),
    "Incomplete publication schema.")
  expected <- expand.grid(inference = "mcmc", family = ifr_families, tau = ifr_levels,
    model_variant = ifr_models, metric_role = ifr_metrics,
    cutoff = c(policy$primary_cutoff, policy$sensitivity_cutoff), stringsAsFactors = FALSE)
  fpf_assert(nrow(x) == 144L && !anyDuplicated(ifr_key(x)) && setequal(ifr_key(x), ifr_key(expected)),
    "Publication surface must contain all 144 approved MCMC cells and no deprecated window.")
  fpf_assert(all(is.finite(as.matrix(x[ifr_summary_fields]))) && all(x$n_chains == 3L) &&
    all(x$n_draws > 0 & x$n_draws %% 3L == 0L) && all(x$cri_lower <= x$posterior_median) &&
    all(x$posterior_median <= x$cri_upper) && all(x$forecast_pairs == x$cutoff) &&
    all(x$forecast_origins == ceiling(x$cutoff / 30)) && all(x$last_target == 9000 + x$cutoff),
    "Publication draws, intervals, or forecast grid are invalid.")
  sources <- split(x$replay_id, ifr_key(x, FALSE))
  fpf_assert(all(vapply(sources, function(z) length(unique(z)) == 1L, logical(1))),
    "Source selection changed between primary and sensitivity windows.")
  invisible(TRUE)
}

ifr_check_fit <- function(x) {
  expected <- expand.grid(inference = c("mcmc", "vb"), family = ifr_families, tau = ifr_levels,
    model_variant = ifr_models, metric_role = "fit_rmse", stringsAsFactors = FALSE)
  fpf_assert(nrow(x) == 72L && !anyDuplicated(ifr_key(x, FALSE)) &&
    setequal(ifr_key(x, FALSE), ifr_key(expected, FALSE)) &&
    all(is.finite(as.matrix(x[ifr_summary_fields]))), "Published fit surface is incomplete.")
  invisible(TRUE)
}

ifr_vb_audit <- function(repo, article_data, archive_root) {
  base <- file.path(repo, "validation/fitforecast_v2/promotions")
  paths <- file.path(base, c("qdesn_dqlm_500obs_metric_intervals_v10_20260824/job_artifact_audit.csv",
    "independent_exdqlm_1p1p1_scoped_compatibility_v2_20260828/job_artifact_audit.csv"))
  a <- fpf_read(paths[1L]); b <- fpf_read(paths[2L])
  fields <- c("job_id", "replay_id", "inference", "model_variant", "metric_draws_path")
  a <- rbind(a[a$inference == "vb" & a$model_variant != "exdqlm", fields], b[b$inference == "vb", fields])
  roles <- article_data[article_data$inference == "vb" & article_data$metric_role %in% ifr_metrics, ]
  fpf_assert(nrow(roles) == 72L && all(roles$replay_id %in% a$replay_id), "VB source provenance is incomplete.")
  jobs <- a[match(unique(roles$replay_id), a$replay_id), ]
  roots <- unique(dirname(dirname(jobs$metric_draws_path)))
  roots <- unique(c(roots, file.path(archive_root, "jobs", jobs$job_id)))
  inventory <- do.call(rbind, lapply(roots, function(root) {
    files <- list.files(root, recursive = TRUE, full.names = TRUE)
    data.frame(root = root, exists = dir.exists(root), files = length(files),
      native_candidates = sum(grepl("[.](rds|rda|rdata|ffv2handoff)$|forecast_objects|quantile_draw|origin_horizon_group_draw|coefficient_draw",
        files, ignore.case = TRUE)))
  }))
  fpf_assert(sum(inventory$native_candidates) == 0L,
    "Potential VB posterior evidence found: inspect and adapt it before omitting VB forecasts.")
  ledger <- roles[c("inference", "family", "tau", "model_variant", "metric_role", "replay_id")]
  ledger$status <- "OMITTED_NO_AUTHENTIC_PREFIX_DRAWS"
  ledger$reason <- "Only full-window aggregate metric draws remain; they cannot identify prefix credible intervals. No refit authorized."
  list(roles = ledger, inventory = inventory, inputs = paths,
    selected_sources = nrow(jobs), inspected_files = sum(inventory$files))
}

ifr_references <- function(plan, baseline) {
  keys <- unique(plan[c("family", "p", "path")])
  keys <- keys[!duplicated(keys[c("family", "p")]), ]
  fpf_assert(nrow(keys) == 9L, "Nine DGP cases are required.")
  answer <- list()
  for (i in seq_len(nrow(keys))) {
    k <- keys[i, ]; target <- fpf_read(k$path)
    expected <- idor_v1_expected_check_analytic(k$family, k$p)
    numerical <- idor_v1_expected_check_numerical(k$family, k$p)
    fpf_assert(abs(expected - numerical) <= 1e-6, "DGP expectation quadrature disagrees.")
    old <- baseline[baseline$inference == "mcmc" & baseline$family == k$family & baseline$tau == k$p &
      baseline$metric_role == "forecast_check", ]
    fpf_assert(nrow(old) == 4L && max(abs(old$expected_reference_value - expected)) <= 1e-6,
      "Frozen population reference and DGP contract disagree.")
    for (n in c(300L, 500L)) for (metric in ifr_metrics) {
      value <- if (metric == "forecast_check") expected else 0
      realized <- if (metric == "forecast_check") mean(fpf_loss(target$y[seq_len(n)], target$q_true[seq_len(n)], k$p)) else 0
      answer[[length(answer) + 1L]] <- data.frame(family = k$family, tau = k$p, cutoff = n,
        metric_role = metric, plot_reference_type = if (metric == "forecast_check") "population_expected_check_loss" else "exact_dgp_oracle",
        plot_reference_value = value, expected_reference_value = value, realized_reference_value = realized,
        formula = idor_v1_formula(metric, k$family), expected_quadrature_error = abs(expected - numerical),
        expectation_time_constant = TRUE, source_series_sha256 = old$source_series_sha256[1L])
    }
  }
  do.call(rbind, answer)
}

ifr_comparisons <- function(x) {
  rows <- list()
  groups <- split(x, interaction(x$family, x$tau, x$metric_role, x$cutoff, drop = TRUE))
  for (d in groups) {
    dynamic <- d[d$model_variant %in% c("dqlm", "exdqlm"), ]
    best <- dynamic[which.min(dynamic$posterior_mean), ]
    for (model in c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns")) {
      q <- d[d$model_variant == model, ]
      rows[[length(rows) + 1L]] <- data.frame(family = q$family, tau = q$tau, metric_role = q$metric_role,
        cutoff = q$cutoff, model_variant = model, mean = q$posterior_mean,
        best_dynamic = best$model_variant, best_dynamic_mean = best$posterior_mean,
        beats_best_dynamic_mean = q$posterior_mean < best$posterior_mean,
        interval_width_ratio = (q$cri_upper - q$cri_lower) / (best$cri_upper - best$cri_lower))
    }
  }
  do.call(rbind, rows)
}

ifr_build <- function(repo, run, article_root, output, policy_path, archive_root) {
  policy <- ifr_policy(policy_path)
  audit <- file.path(run, "healthchecks/closeout_20261015_0345_UTC")
  verification <- jsonlite::read_json(file.path(audit, "verification.json"), simplifyVector = TRUE)
  fpf_assert(verification$complete == 132L && verification$running == 0L && verification$queued == 0L &&
    verification$source_groups == 44L && verification$max_joint_score_error <= policy$numerical_tolerance &&
    verification$max_interval_error <= policy$numerical_tolerance && verification$launch_head == policy$recovery_head,
    "A fully verified recovery bundle is required.")
  fpr_assert_hashes(fpf_read(file.path(audit, "artifact_manifest.csv")))
  fpr_assert_hashes(fpf_read(file.path(run, "input_manifest.csv")))
  plan <- fpf_read(file.path(run, "task_plan.csv"))
  raw <- fpf_read(file.path(run, "reconstructed_display_intervals.csv"))
  baseline_path <- file.path(article_root, "tables/qdesn_validation_500obs_dgp_oracle_figure_data_v14.csv")
  baseline <- fpf_read(baseline_path)
  preserved <- baseline[baseline$metric_role == "fit_rmse", ]
  ifr_check_fit(preserved)
  preserved$forecast_origins <- NA_integer_
  preserved$forecast_pairs <- NA_integer_
  published <- raw[raw$cutoff %in% c(300L, 500L), ]
  ifr_check_display(published, policy)
  pooled <- checks <- list()
  for (id in unique(plan$replay_id)) {
    tasks <- plan[plan$replay_id == id, ]
    draws <- lapply(seq_len(nrow(tasks)), function(i) {
      task <- tasks[i, ]; root <- task$job_root
      state <- jsonlite::read_json(file.path(root, "task_status.json"), simplifyVector = TRUE)
      path <- file.path(root, "prefix_draws.csv.gz")
      fpf_assert(state$status == "COMPLETE" && fpf_sha(path) == state$prefix_draws_sha256 &&
        fpf_sha(task$contract_path) == task$contract_sha256, "A completed export changed.")
      d <- data.table::fread(cmd = paste("gzip -cd", shQuote(path)), nThread = 1L,
        select = c("chain_id", "draw_id", "source_draw_index", "cutoff", "n_pairs", "n_origins", "last_target", "forecast_mae", "forecast_check_loss"),
        showProgress = FALSE, data.table = FALSE)
      d <- d[d$cutoff %in% c(300L, 500L), ]
      fpf_assert(all(d$chain_id == task$chain_id) && nrow(d) == 2L * task$n_draws,
        "A chain budget or draw identity changed.")
      d
    })
    s <- fpf_pool(do.call(rbind, draws), tasks$quantile_type[1L]); s$replay_id <- id
    pooled[[length(pooled) + 1L]] <- s
  }
  pooled <- do.call(rbind, pooled)
  for (i in seq_len(nrow(published))) {
    d <- published[i, ]; metric <- if (d$metric_role == "forecast_check") "forecast_check_loss" else d$metric_role
    s <- pooled[pooled$replay_id == d$replay_id & pooled$cutoff == d$cutoff & pooled$metric == metric, ]
    fpf_assert(nrow(s) == 1L, "A selected role does not map to exactly one pooled source.")
    error <- max(abs(as.numeric(unlist(d[ifr_summary_fields])) - as.numeric(unlist(s[ifr_summary_fields]))))
    fpf_assert(error <= policy$numerical_tolerance, "The authoritative prefix summary failed numerical replay.")
    checks[[i]] <- data.frame(key = ifr_key(d), maximum_error = error, pass = TRUE)
  }
  refs <- ifr_references(plan, baseline)
  reference_key <- function(d) paste(d$family, d$tau, d$cutoff, d$metric_role, sep = "|")
  idx <- match(reference_key(published), reference_key(refs))
  fpf_assert(!anyNA(idx), "A DGP reference is missing.")
  ref_fields <- setdiff(names(refs), c("family", "tau", "cutoff", "metric_role"))
  published[ref_fields] <- refs[idx, ref_fields]
  published$reporting_role <- ifelse(published$cutoff == 300L, "PRIMARY", "SENSITIVITY")
  published$authority_id <- policy$authority_id
  published$diagnostic_grade_origin <- "historical_selected_source_record"
  published$first_target <- 9001L
  published$last_lead <- ifelse(published$cutoff == 300L, 30L, 20L)
  published$metric_name <- paste0(ifelse(published$metric_role == "forecast_mae", "forecast_qtrue_mae", "forecast_check_loss"), "_N", published$cutoff)
  published <- published[order(published$cutoff, published$metric_role, match(published$family, ifr_families),
    published$tau, match(published$model_variant, ifr_models)), ]
  ifr_check_display(published, policy)
  vb <- ifr_vb_audit(repo, baseline, archive_root)
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  fpf_write(published, file.path(output, "forecast_metric_intervals.csv"))
  fpf_write(preserved, file.path(output, "preserved_fit_metric_intervals.csv"))
  fpf_write(pooled, file.path(output, "source_prefix_intervals.csv"))
  fpf_write(refs, file.path(output, "dgp_references.csv"))
  fpf_write(do.call(rbind, checks), file.path(output, "numerical_replay_checks.csv"))
  fpf_write(vb$roles, file.path(output, "vb_forecast_coverage.csv"))
  fpf_write(vb$inventory, file.path(output, "vb_storage_inventory.csv"))
  fpf_write(ifr_comparisons(published), file.path(output, "benchmark_comparisons.csv"))
  transition <- data.frame(cutoff = c(300L, 500L, 1000L),
    status = c("PRIMARY", "SENSITIVITY", policy$deprecated_status),
    active_publication = c(TRUE, TRUE, FALSE), evidence_retained = TRUE,
    retrospective_scope_change = TRUE, new_fit_calls = 0L, new_forecast_calls = 0L)
  fpf_write(transition, file.path(output, "authority_transition.csv"))
  inputs <- c(policy_path, baseline_path, file.path(run, c("input_manifest.csv", "task_plan.csv", "reconstructed_display_intervals.csv")),
    file.path(audit, c("verification.json", "artifact_manifest.csv")), vb$inputs,
    file.path(repo, "validation/fitforecast_v2/R", c("independent_forecast_reporting_v1.R",
      "forecast_prefix_metric_intervals_v1.R", "independent_dgp_oracle_reference_v1.R")),
    file.path(repo, "validation/fitforecast_v2/scripts", c("build_independent_forecast_reporting_v1.R", "test_independent_forecast_reporting_v1.R")),
    file.path(repo, "validation/fitforecast_v2/tests/testthat/test-independent-forecast-reporting-v1.R"),
    file.path(repo, "validation/fitforecast_v2/docs/independent_forecast_reporting_300_500_v1.md"))
  fpf_write(fpr_hashes(inputs), file.path(output, "source_manifest.csv"))
  fpf_write(plan[c("task_id", "replay_id", "chain_id", "job_root", "contract_path", "contract_sha256", "quantile_type", "n_draws")],
    file.path(output, "protected_source_locator.csv"))
  file.copy(policy_path, file.path(output, "reporting_policy.json"), overwrite = TRUE)
  fpr_write_json(list(schema = "independent_forecast_reporting_v1", authority_id = policy$authority_id,
    status = "COMPLETE_COORDINATOR_REVIEW_REQUIRED", source_head = policy$recovery_head,
    primary_cells = 72L, sensitivity_cells = 72L, preserved_fit_cells = 72L,
    selected_sources = 44L, chain_exports = 132L,
    max_summary_error = max(vapply(checks, function(x) x$maximum_error, numeric(1))),
    vb_sources_audited = vb$selected_sources, vb_files_inspected = vb$inspected_files,
    vb_forecast_status = "OMITTED_NO_AUTHENTIC_PREFIX_DRAWS", fit_calls = 0L, forecast_calls = 0L,
    retrospective_scope_change = TRUE, deprecated_reporting_window = 1000L,
    article_main_changed = FALSE, overleaf_changed = FALSE), file.path(output, "closeout.json"))
  files <- list.files(output, full.names = TRUE)
  files <- files[basename(files) != "artifact_manifest.csv"]
  fpf_write(fpr_hashes(files), file.path(output, "artifact_manifest.csv"))
  invisible(published)
}
