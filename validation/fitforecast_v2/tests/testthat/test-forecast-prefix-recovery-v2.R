testthat::test_that("source alignment supports both explicit schemas and rejects ambiguity", {
  g <- fpf_grid(0, 9, 3, 3)
  s <- data.frame(t = 0:9, y = 0:9, q_target = (0:9) / 2)
  targets <- data.frame(y = 1:9, q_true = (1:9) / 2)
  a <- fpr_source_alignment(s, g, targets)
  testthat::expect_identical(a$column, "t")
  testthat::expect_equal(a$local_origin, c(1, 4, 7))
  testthat::expect_equal(a$local_target, 2:10)
  s$source_index <- s$t
  testthat::expect_equal(fpr_source_alignment(s, g, targets)$local_target, a$local_target)
  s$t[1] <- 100
  testthat::expect_error(fpr_source_alignment(s, g), "disagree")
  s$t <- NULL
  s$source_index[2] <- s$source_index[1]
  testthat::expect_error(fpr_source_alignment(s, g), "unique")
  s$source_index <- 0:9
  s$source_index[1] <- .5
  testthat::expect_error(fpr_source_alignment(s, g), "integers")
  s$source_index[1] <- NA_real_
  testthat::expect_error(fpr_source_alignment(s, g), "integers")
  testthat::expect_error(fpr_source_alignment(s[FALSE, ], g), "alignment")
  s$source_index <- 0:9
  targets$y[1] <- 100
  testthat::expect_error(fpr_source_alignment(s, g, targets), "targets changed")
  testthat::expect_error(fpr_source_alignment(s["y"], g), "Explicit")
})

fpr2_test_fixture <- function() {
  root <- tempfile("prefix_recovery_fixture_")
  original <- file.path(root, "original")
  output <- file.path(root, "recovery")
  source_root <- file.path(root, "source")
  dir.create(file.path(original, "quantile/models"), recursive = TRUE)
  dir.create(file.path(original, "quantile/tables"), recursive = TRUE)
  dir.create(file.path(source_root, "R"), recursive = TRUE)
  dir.create(output)
  native_helpers <- file.path(source_root, c("R/qdesn_mcmc_validation.R", "R/qdesn_validation_metric_intervals.R"))
  writeLines(c("`%||%` <- function(a,b) if (is.null(a)) b else a",
    ".qdesn_validation_lead_export_scale_spec <- function(fc) fc$lead_export_scale",
    ".qdesn_validation_apply_lead_export_scale <- function(x,s) if (s$transform == 'identity') x else x*s$scale+s$center"),
    native_helpers[1])
  writeLines(".qdesn_validation_even_draw_indices <- function(count,n) seq_len(min(count,n))", native_helpers[2])
  source <- data.frame(t = 8500:10000, y = 1, q_target = 0)
  source_path <- file.path(root, "source.csv")
  fpf_write(source, source_path)
  targets <- data.frame(y = rep(1, 1000), q_true = rep(0, 1000))
  target_path <- file.path(root, "targets.csv")
  fpf_write(targets, target_path)
  index <- match(unique(fpf_grid()$origin), source$t)
  entry <- list(mu_draws_tr = matrix(0, 500, 4), fit_train = list(fit = list(sentinel = TRUE)),
    forecast_full = list(origins = index, mu_by_origin = replicate(34,
      matrix(rep(1:4, each = 30), 30, 4), simplify = FALSE),
      lead_export_scale = list(transform = "identity", center = 100, scale = 4)))
  object <- list(fits_fc = list(entry))
  payload <- file.path(original, "quantile/models/forecast_objects.rds")
  fpr_save(object, payload)
  scores <- fpf_score_paths(matrix(rep(1:4, each = 1000), 1000, 4), fpf_grid(),
    targets$y, targets$q_true, .25)
  native <- scores[scores$cutoff == 1000, ]
  native_path <- file.path(original, "quantile/tables/metric_draws.csv.gz")
  old_path <- file.path(root, "old.csv.gz")
  fpf_write(native, native_path)
  historical <- native
  historical$forecast_mae <- historical$forecast_mae + 1
  fpf_write(historical[4:1, ], old_path)
  fpr_write_json(list(status = "FAILED_RETAIN_EVIDENCE"), file.path(original, "task_status.json"))
  fpr_write_json(list(package_version = "fixture"), file.path(original, "environment.json"))
  fpr_write_json(list(frozen = TRUE), file.path(original, "contract.json"))
  task <- list(task_id = "fixture__c01", replay_id = "fixture", chain_id = 1,
    n_draws = 4, p = .25, path = target_path, metric_draws_path = old_path,
    point_path_sha256 = fpf_sha(target_path), full_metric_draws_sha256 = fpf_sha(old_path))
  retained <- c(payload, native_path, file.path(original, c("task_status.json", "environment.json", "contract.json")))
  contract <- list(schema = fpr_schema, engine = "qdesn", task = task, output_root = output,
    root_spec = list(source_series_wide_path = source_path), source_root = source_root,
    code_manifest = fpr_hashes(native_helpers), input_manifest = fpr_hashes(c(target_path, old_path, source_path)),
    package_version = "fixture", source_commit = "fixture", refit_authorized = FALSE,
    recovery = list(action = "RESCORE_CACHED_FORECAST", original_job_root = original,
      original_contract_path = file.path(original, "contract.json"),
      original_contract_sha256 = fpf_sha(file.path(original, "contract.json")), input_manifest = fpr_hashes(retained)))
  path <- file.path(output, "contract.json")
  fpr_write_json(contract, path)
  list(root = root, original = original, output = output, contract = contract, path = path,
    source = source, object = object, native = native)
}

testthat::test_that("native extraction preserves scaling, local origins and selected draw IDs", {
  f <- fpr2_test_fixture()
  on.exit(unlink(f$root, recursive = TRUE), add = TRUE)
  helpers <- fpr2_helpers(f$contract)
  paths <- fpr_q_paths(list(forecast_objects = f$object), f$contract, f$source, helpers)
  testthat::expect_equal(dim(paths$q), c(1000, 4))
  testthat::expect_equal(paths$q[1, ], 1:4)
  testthat::expect_equal(paths$q[1000, ], 1:4)
  testthat::expect_equal(paths$draw_index, 1:4)
  f$source$source_index <- f$source$t
  f$source$t <- NULL
  testthat::expect_equal(fpr_q_paths(list(forecast_objects = f$object), f$contract, f$source, helpers)$q, paths$q)
  f$object$fits_fc[[1]]$forecast_full$lead_export_scale$transform <- "affine"
  testthat::expect_equal(fpr_q_paths(list(forecast_objects = f$object), f$contract, f$source, helpers)$q,
    paths$q * 4 + 100)
  f$object$fits_fc[[1]]$forecast_full$origins[2] <- f$object$fits_fc[[1]]$forecast_full$origins[1]
  testthat::expect_error(fpr_q_paths(list(forecast_objects = f$object), f$contract, f$source, helpers), "duplicated")
  f$object$fits_fc[[1]]$forecast_full$origins <- match(unique(fpf_grid()$origin), f$source$source_index)
  f$object$fits_fc[[1]]$forecast_full$mu_by_origin[[1]] <- matrix(0, 10, 4)
  testthat::expect_error(fpr_q_paths(list(forecast_objects = f$object), f$contract, f$source, helpers), "Incomplete")
})

testthat::test_that("cache-only recovery preserves failures and never filters historical nonidentity", {
  f <- fpr2_test_fixture()
  on.exit(unlink(f$root, recursive = TRUE), add = TRUE)
  original_state_sha <- fpf_sha(file.path(f$original, "task_status.json"))
  payload_sha <- fpf_sha(file.path(f$original, "quantile/models/forecast_objects.rds"))
  forbidden <- new.env(parent = environment(fpr2_rescore))
  forbidden$fpr_worker <- function(...) stop("Fitting forbidden")
  forbidden$fpr_d_paths <- function(...) stop("Forecasting forbidden")
  forbidden$getFromNamespace <- function(...) stop("Package namespace lookup forbidden")
  forbidden$fpr_q_paths <- fpr_q_paths
  environment(forbidden$fpr_q_paths) <- forbidden
  rescore <- fpr2_rescore
  environment(rescore) <- forbidden
  state <- rescore(f$path)
  testthat::expect_identical(state$status, "COMPLETE")
  testthat::expect_identical(state$fit_calls, 0L)
  testthat::expect_identical(state$forecast_calls, 0L)
  testthat::expect_lt(state$native_score_max_error, 1e-6)
  testthat::expect_false(state$old_realization_reproduced)
  testthat::expect_identical(fpf_sha(file.path(f$original, "task_status.json")), original_state_sha)
  testthat::expect_identical(fpf_sha(file.path(f$original, "quantile/models/forecast_objects.rds")), payload_sha)
  testthat::expect_false(file.exists(file.path(f$output, "worker.lock")))
  testthat::expect_error(fpr2_rescore(f$path), "cannot be overwritten")
  comparison <- fpf_read(file.path(f$output, "original_score_comparison.csv"))
  testthat::expect_equal(comparison$max_draw_difference, c(1, 0))
  testthat::expect_silent(fpr2_verify_complete(data.frame(job_root = f$output,
    contract_path = f$path, contract_sha256 = fpf_sha(f$path))))
  native <- f$native
  native$source_draw_index <- 4:1
  testthat::expect_error(fpr_export_paths(f$contract, f$path,
    list(q = matrix(0, 1000, 4), draw_index = 1:4),
    file.path(f$original, "quantile/models/forecast_objects.rds"), native), "draw indices")
})

testthat::test_that("recovery classification never reschedules completed or failed fits", {
  p <- data.frame(task_id = c("done", "cache", "new"))
  testthat::expect_identical(fpr2_classify(p, c("COMPLETE", "FAILED_RETAIN_EVIDENCE", "QUEUED")),
    c("REFERENCE_COMPLETE", "RESCORE_CACHED_FORECAST", "NEW_CHAIN"))
  testthat::expect_error(fpr2_classify(p, c("COMPLETE", "RUNNING", "QUEUED")), "stopped")
  p$task_id[2] <- p$task_id[1]
  testthat::expect_error(fpr2_classify(p, rep("COMPLETE", 3)), "identities")
  p <- data.frame(task_id = "done", job_root = "/frozen/original/done")
  testthat::expect_equal(fpr_plan_job_root(p, 1, "/new"), "/frozen/original/done")
  testthat::expect_equal(fpr_plan_job_root(p["task_id"], 1, "/old"), "/old/jobs/done")
})

testthat::test_that("final summaries use external job roots and require every chain", {
  fixtures <- lapply(1:3, function(chain) {
    f <- fpr2_test_fixture()
    f$contract$task$chain_id <- chain
    f$contract$task$task_id <- sprintf("fixture__c%02d", chain)
    fpr_write_json(f$contract, f$path)
    f
  })
  on.exit(lapply(fixtures, function(f) unlink(f$root, recursive = TRUE)), add = TRUE)
  out <- tempfile("prefix_summary_fixture_")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)
  plan <- do.call(rbind, lapply(fixtures, function(f) data.frame(task_id = f$contract$task$task_id,
    replay_id = "fixture", quantile_type = 8, contract_path = f$path,
    contract_sha256 = fpf_sha(f$path), job_root = f$output)))
  fpf_write(plan, file.path(out, "task_plan.csv"))
  baseline <- expand.grid(family = c("normal", "laplace", "gausmix"), tau = c(.05, .25, .5),
    model_variant = c("dqlm", "exdqlm", "qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
    metric_role = c("forecast_mae", "forecast_check"), stringsAsFactors = FALSE)
  baseline$replay_id <- "fixture"
  baseline$cutoff <- 1000
  fpf_write(baseline, file.path(out, "article_baseline.csv"))
  for (i in 1:2) fpr2_rescore(fixtures[[i]]$path)
  testthat::expect_error(fpr_summarize(out), "Complete reconstruction required")
  fpr2_rescore(fixtures[[3]]$path)
  fpr_summarize(out)
  result <- fpf_read(file.path(out, "reconstructed_display_intervals.csv"))
  testthat::expect_equal(nrow(result), 216L)
  testthat::expect_true(all(result$n_chains == 3L & result$n_draws == 12L))
  testthat::expect_equal(unique(result$posterior_mean[result$metric_role == "forecast_mae"]), 2.5)
  testthat::expect_equal(unique(result$posterior_mean[result$metric_role == "forecast_check"]), 1.125)
  testthat::expect_false(fpf_json(file.path(out, "closeout.json"))$article_changed)
})
