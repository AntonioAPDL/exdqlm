testthat::test_that("paired prefix scoring matches direct target-by-draw arithmetic", {
  grid <- fpf_grid(0L, 9L, 3L, 3L)
  q <- matrix(seq_len(36) / 10, 9, 4)
  y <- seq_len(9) / 3
  oracle <- sin(seq_len(9))
  z <- fpf_score_paths(q, grid, y, oracle, .25, c(3, 5, 9))
  for (n in c(3, 5, 9)) {
    one <- z[z$cutoff == n, ]
    testthat::expect_equal(one$forecast_mae, colMeans(abs(q[1:n, , drop = FALSE] - oracle[1:n])))
    target_check <- vapply(1:4, function(j) mean(fpf_loss(y[1:n], q[1:n, j], .25)), numeric(1))
    testthat::expect_equal(one$forecast_check_loss, target_check)
    testthat::expect_equal(one$n_pairs, rep(n, 4))
  }
  testthat::expect_equal(sort(unique(z$cutoff)), c(3, 5, 6, 9))
  testthat::expect_equal(z$end_lead[z$cutoff == 5], rep(2, 4))
})
testthat::test_that("article cutoffs retain the exact partial origins", {
  grid <- fpf_grid()
  z <- fpf_score_paths(matrix(0, 1000, 3), grid, rep(1, 1000), rep(0, 1000), .05)
  for (i in 1:3) {
    n <- c(300, 500, 1000)[i]
    one <- z[z$cutoff == n, ]
    testthat::expect_equal(unique(one$n_origins), c(10, 17, 34)[i])
    testthat::expect_equal(unique(one$end_lead), c(30, 20, 10)[i])
    testthat::expect_equal(unique(one$last_target), 9000 + n)
  }
  testthat::expect_lt(max(abs(z$forecast_check_loss - .05)), 1e-12)
  testthat::expect_equal(unique(z$forecast_mae), 0)
})
testthat::test_that("invalid grids, draws, and cutoffs are rejected", {
  grid <- fpf_grid(0, 9, 3, 3)
  q <- matrix(0, 9, 4)
  testthat::expect_error(fpf_score_paths(q, grid, 1:9, 1:9, .5, 10), "cutoff")
  testthat::expect_error(fpf_score_paths(q, grid, 1:9, 1:9, .5, 3.1), "cutoff")
  q[1, 1] <- NA_real_
  testthat::expect_error(fpf_score_paths(q, grid, 1:9, 1:9, .5, 3), "input")
  grid$target[2] <- grid$target[1]
  testthat::expect_error(fpf_check_grid(grid), "alignment")
  testthat::expect_error(fpf_grid(stride = 1, horizon = 30), "nonoverlapping")
})
testthat::test_that("origin groups recover only exact whole-origin prefixes", {
  grid <- fpf_grid(0, 9, 3, 3)
  q <- matrix(seq_len(36) / 10, 9, 4)
  y <- seq_len(9) / 2
  oracle <- rep(0, 9)
  direct <- fpf_score_paths(q, grid, y, oracle, .25, c(3, 5, 9))
  ref <- direct[direct$cutoff == 9, ]
  groups <- do.call(rbind, lapply(unique(grid$origin), function(o) {
    k <- which(grid$origin == o)
    data.frame(scope = "all_targets", group_type = "origin", group_value = as.character(o),
      n_targets = length(k), chain_id = 1, draw_id = 1:4, source_draw_index = 1001:1004,
      forecast_mae = colMeans(abs(q[k, , drop = FALSE])),
      forecast_check_loss = vapply(1:4, function(j) mean(fpf_loss(y[k], q[k, j], .25)), numeric(1)))
  }))
  recovered <- fpf_score_origin_groups(groups, ref, grid, c(3, 5, 9))
  testthat::expect_equal(sort(unique(recovered$cutoff)), c(3, 9))
  testthat::expect_equal(recovered$forecast_mae, direct$forecast_mae[direct$cutoff %in% c(3, 9)])
  testthat::expect_equal(recovered$forecast_check_loss,
    direct$forecast_check_loss[direct$cutoff %in% c(3, 9)])
  testthat::expect_equal(unique(recovered$parent_coefficient_draw_index), 1001:1004)
  testthat::expect_equal(fpf_verify_full(recovered, ref, 9), 0, tolerance = 1e-12)
  groups$forecast_mae[1] <- groups$forecast_mae[1] + 1
  testthat::expect_error(fpf_score_origin_groups(groups, ref, grid, c(3, 9)), "mismatch")
})
testthat::test_that("pooling keeps chain balance and historical quantile estimators", {
  g <- fpf_grid(0, 9, 3, 3)
  z <- fpf_score_paths(matrix(seq_len(36), 9, 4), g, rep(1, 9), rep(0, 9), .5, 9)
  z2 <- z
  z2$chain_id <- 2
  joined <- rbind(z, z2)
  for (type in c(7, 8)) {
    pooled <- fpf_pool(joined, type)
    one <- subset(pooled, cutoff == 9 & metric == "forecast_mae")
    testthat::expect_equal(one$posterior_mean, mean(joined$forecast_mae[joined$cutoff == 9]))
    testthat::expect_equal(one$cri_lower, unname(quantile(joined$forecast_mae[joined$cutoff == 9], .025, type = type)))
    testthat::expect_equal(one$n_chains, 2L)
  }
  testthat::expect_error(fpf_pool(rbind(z, z)), "Duplicate")
  testthat::expect_error(fpf_pool(joined[-nrow(joined), ]), "Unequal")
  joined$replay_id <- rep(c("source_A", "source_B"), each = nrow(z))
  testthat::expect_error(fpf_pool(joined), "mixed source")
})
testthat::test_that("forecast-only Q adapter preserves inputs and RNG without fitting", {
  file <- tempfile()
  writeLines("frozen forecast source fixture", file)
  forecaster <- function(object, H, keep_origin_draws, ...) {
    stopifnot(object$sentinel, H == 30, keep_origin_draws)
    list(origins = 1:34, mu_by_origin = replicate(34,
      matrix(rep(1:4, each = 30), 30, 4), simplify = FALSE))
  }
  task <- list(task_id = "fixture__c01", replay_id = "fixture", n_draws = 4L, chain_id = 1L, p = .25)
  cap <- list(schema = "independent_forecast_prefix_capsule_v1", task_id = task$task_id,
    replay_id = task$replay_id, adapter = "qdesn_lattice_v14", fit = list(sentinel = TRUE),
    package_version = as.character(utils::packageVersion("exdqlm")), code_paths = file,
    code_sha256 = fpf_sha(file), n_metric_draws = 4L, chain_id = 1L, p = .25,
    y = rep(1, 1000), oracle = rep(0, 1000), grid = fpf_grid(), rng_kind = RNGkind(), seed = 123L,
    forecast_args = list(H = 30L, keep_origin_draws = TRUE), local_origins = 1:34,
    draw_columns = 1:4, source_draw_index = 1:4, location_center = 0, location_scale = 1,
    forecast_function_sha256 = fpf_function_sha(forecaster))
  set.seed(892)
  before <- .Random.seed
  answer <- fpf_replay_capsule(cap, task, forecaster)
  testthat::expect_identical(.Random.seed, before)
  testthat::expect_equal(answer$forecast_mae[answer$cutoff == 500], 1:4)
  testthat::expect_true(cap$fit$sentinel)
  cap$fit <- NULL
  testthat::expect_error(fpf_replay_capsule(cap, task, forecaster), "refitting is disabled")
  cap$fit <- list(sentinel = TRUE)
  cap$code_sha256 <- "wrong"
  testthat::expect_error(fpf_replay_capsule(cap, task, forecaster), "hashes failed")
  testthat::expect_error(fpf_run_task(task, tempfile(), "wrong", tempfile()), "no fit will be run")
})
testthat::test_that("compressed snapshots roundtrip without losing score precision", {
  file <- tempfile(fileext = ".csv.gz")
  z <- fpf_score_paths(matrix(seq_len(36) / 7, 9, 4), fpf_grid(0, 9, 3, 3),
    rep(1, 9), rep(0, 9), .25, c(3, 5, 9))
  fpf_write(z, file)
  testthat::expect_equal(fpf_read(file), z, tolerance = 1e-12)
  testthat::expect_true(file.exists(file))
})
testthat::test_that("dynamic adapter advances origins without changing its horizons or fitting", {
  helper <- tempfile()
  writeLines(c(
    "ffv2_advance_fit_between_source_origins <- function(fit, config, data, from, to) {",
    " if (to > from) fit$y <- c(fit$y, data$forecast$y[seq.int(from-8999L, to-9000L)])",
    " fit }",
    "ffv2_make_future_model_arrays <- function(model, k) list(fFF=matrix(1,1,k), fGG=array(1,c(1,1,k)))",
    "ffv2_latent_forecast_draws <- function(pred,n,seed) { set.seed(seed); matrix(rnorm(length(pred$ff)*n),length(pred$ff),n) }"
  ), helper)
  seen <- integer()
  ff <- function(start.t, k, m1, ...) {
    seen <<- c(seen, start.t)
    list(ff = rep(0, k), fQ = rep(1, k))
  }
  task <- list(task_id = "dynamic__c01", replay_id = "dynamic", n_draws = 4L, chain_id = 1L, p = .25)
  cap <- list(schema = "independent_forecast_prefix_capsule_v1", task_id = task$task_id,
    replay_id = task$replay_id, adapter = "dqlm_rolling_v14", fit = list(y = rep(0, 500), model = list()),
    package_version = as.character(utils::packageVersion("exdqlm")), code_paths = helper,
    code_sha256 = fpf_sha(helper), helper_sources = helper, n_metric_draws = 4L,
    n_response_draws = 10L, chain_id = 1L, p = .25, y = rep(1, 1000), oracle = rep(0, 1000),
    grid = fpf_grid(), rng_kind = RNGkind(), seed = 341L,
    source_draw_index = 1:4, forecast_function_sha256 = fpf_function_sha(ff),
    config = list(state_update_strategy = "incremental_teacher_forced"),
    data = list(forecast = data.frame(y = 1:1000)))
  set.seed(158)
  before <- .Random.seed
  z <- fpf_replay_capsule(cap, task, d_forecaster = ff)
  testthat::expect_equal(seen, 500L + seq(0L, 990L, 30L))
  testthat::expect_identical(.Random.seed, before)
  testthat::expect_equal(length(cap$fit$y), 500L)
  testthat::expect_equal(unique(z$end_lead[z$cutoff == 500L]), 20L)
  testthat::expect_true(all(is.finite(z$forecast_mae)))
})
testthat::test_that("bounded pool uses verified outputs and never refits on missing capsules", {
  tasks <- data.frame(task_id = c("one", "two"), full_metric_draws_sha256 = c("ref1", "ref2"))
  capsules <- data.frame(task_id = c("one", "two"), capsule_path = c("none1", "none2"),
    capsule_sha256 = c("hash1", "hash2"))
  output <- tempfile()
  called <- 0L
  worker <- function(task, path, hash, root) {
    called <<- called + 1L
    draws <- file.path(root, "prefix_draws.csv.gz")
    fpf_write(data.frame(draw_id = 1:2, value = 1:2), draws)
    jsonlite::write_json(list(status = "VERIFIED", task_id = task$task_id,
      reference_sha256 = task$full_metric_draws_sha256,
      prefix_draws_sha256 = fpf_sha(draws)), file.path(root, "task_status.json"), auto_unbox = TRUE)
  }
  a <- fpf_run_pool(tasks, capsules, output, 1L, worker)
  testthat::expect_true(all(a$status == "VERIFIED"))
  testthat::expect_equal(called, 2L)
  b <- fpf_run_pool(tasks, capsules, output, 1L, worker)
  testthat::expect_true(all(b$status == "VERIFIED_REUSED"))
  testthat::expect_equal(called, 2L)
  testthat::expect_error(fpf_run_pool(tasks, capsules, tempfile(), 16L), "between 1 and 15")
  testthat::expect_error(fpf_run_pool(tasks, capsules[FALSE, ], tempfile()), "empty")
  failed <- fpf_run_pool(tasks, capsules, tempfile(), 1L, function(...) stop("Capsule absent; no fitting"))
  testthat::expect_true(all(failed$status == "FAILED_NO_REFIT"))
  testthat::expect_false(any(dir.exists(file.path(output, c("one", "two"), "task.lock"))))
})
