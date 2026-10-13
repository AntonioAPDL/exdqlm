test_that("representation-screen protocol freezes broad identity-Q search", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1.R"))
  protocol <- iqrs_v1_read_protocol(repo_root)
  checks <- iqrs_v1_protocol_checks(protocol)
  expect_true(all(checks$pass), info = paste(checks$check[!checks$pass],
                                             collapse = ", "))
  catalog <- iqrs_v1_architecture_catalog(protocol)
  expect_equal(max(catalog$total_states), 1800L)
  expect_true(any(catalog$total_states >= 1200L))
  expect_equal(max(protocol$search$response_lag_values), 300L)
})

test_that("structure generator is deterministic, broad, unseen, and identity", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1.R"))
  protocol <- iqrs_v1_read_protocol(repo_root)
  first <- iqrs_v1_generate_structures(protocol)
  second <- iqrs_v1_generate_structures(protocol)
  expect_identical(first$structure_signature, second$structure_signature)
  counts <- table(first$family)
  expect_equal(as.integer(counts[c("gausmix", "laplace", "normal")]),
               c(320L, 320L, 320L))
  expect_true(any(first$total_states >= 1200L))
  expect_true(any(first$m == 300L))
  expect_true(any(first$alpha > 0.95))
  expect_true(any(first$rho > 0.99))
  expect_true(all(first$matrix_seed == 920001L))
  identity <- vapply(seq_len(nrow(first)), function(i) {
    n <- iqfr_v2_unpack_integer(first$n[[i]])
    n_tilde <- iqfr_v2_unpack_integer(first$n_tilde[[i]])
    if (first$D[[i]] == 1L) !length(n_tilde) else
      identical(n_tilde, n[seq_len(first$D[[i]] - 1L)])
  }, logical(1L))
  expect_true(all(identity))
})

test_that("robust selectors remain family and scale specific", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1_runtime.R"))
  grid <- expand.grid(
    family = iqrs_v1_families, structure = seq_len(50L),
    prior_scale = c(0.01, 0.1), fold_id = c("a", "b"),
    stringsAsFactors = FALSE
  )
  grid$structure_id <- paste(grid$family, grid$structure, sep = "_")
  grid$stage <- "synthetic"
  grid$job_id <- grid$structure_id
  grid$structure_signature <- grid$structure_id
  grid$generation <- "test"
  grid$D <- 1L + grid$structure %% 4L
  grid$n <- "20"
  grid$n_tilde <- ""
  grid$total_states <- 20L + 30L * grid$structure
  grid$readout_dimension <- grid$total_states + 1L
  grid$m <- c(15L, 60L, 150L, 300L)[1L + grid$structure %% 4L]
  grid$alpha <- 0.1 + grid$structure / 100
  grid$rho <- 0.5 + grid$structure / 200
  grid$center_scale <- "mean_sd"
  grid$input_bound <- "none"
  grid$input_gain <- 1
  grid$recurrent_indegree <- 5L
  grid$input_fanin_fraction <- 0.25
  grid$input_fanin <- 5L
  grid$interlayer_fanin <- 5L
  grid$matrix_seed <- 920001L
  grid$exact_identity_projection <- TRUE
  grid$fit_oracle_location_rmse <- grid$structure / 10 + grid$prior_scale
  grid$fit_oracle_location_mae <- grid$fit_oracle_location_rmse
  grid$forecast_oracle_location_mae <- grid$structure / 8 + grid$prior_scale
  grid$forecast_oracle_location_rmse <- grid$forecast_oracle_location_mae
  grid$forecast_observed_mae <- grid$forecast_oracle_location_mae
  grid$lead_1_mae <- grid$forecast_oracle_location_mae
  grid$leads_2_5_mae <- grid$forecast_oracle_location_mae
  grid$leads_6_15_mae <- grid$forecast_oracle_location_mae
  grid$leads_16_30_mae <- grid$forecast_oracle_location_mae
  grid$normal_iterations <- 1L
  grid$normal_converged <- TRUE
  grid$forecast_origins <- 10L
  grid$forecast_pairs <- 300L
  ranked <- iqrs_v1_aggregate_normal(grid)
  selected <- iqrs_v1_select_diverse(ranked, 20L)
  counts <- table(selected$family)
  expect_equal(as.integer(counts[c("gausmix", "laplace", "normal")]),
               c(20L, 20L, 20L))
  expect_equal(length(unique(selected$prior_scale)), 1L)
})

test_that("representation collector accepts valid multirow stage outputs", {
  repo_root <- normalizePath(
    system("git rev-parse --show-toplevel", intern = TRUE),
    winslash = "/", mustWork = TRUE
  )
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_full_redesign_v2_runtime.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1.R"))
  source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                   "independent_qdesn_representation_screen_v1_runtime.R"))
  root <- tempfile("iqrs1-collect-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  result_path <- file.path(root, "result.csv")
  status_path <- file.path(root, "status.json")
  plan_path <- file.path(root, "plan.csv")
  result <- expand.grid(
    job_id = "job_1", fold_id = c("fold_a", "fold_b"),
    prior_scale = c(0.01, 0.1), stringsAsFactors = FALSE
  )
  result$stage <- "ridge_screen"
  iqfr_v2_write_csv(result, result_path)
  iqfr_v2_write_json(list(status = "SUCCESS"), status_path)
  iqfr_v2_write_csv(data.frame(
    stage = "ridge_screen", job_id = "job_1",
    result_path = result_path, status_path = status_path
  ), plan_path)
  collected <- iqrs_v1_collect_results(plan_path, require_complete = TRUE)
  expect_equal(nrow(collected), 4L)

  duplicated_result <- rbind(result, result[1L, , drop = FALSE])
  iqfr_v2_write_csv(duplicated_result, result_path)
  expect_error(
    iqrs_v1_collect_results(plan_path, require_complete = TRUE),
    "Duplicate stage-specific result rows"
  )
})

test_that("representation collector keys quantile and MCMC rows correctly", {
  expect_identical(
    iqrs_v1_result_key_columns("quantile_vb"),
    c("job_id", "fold_id", "likelihood_family", "tau")
  )
  expect_identical(
    iqrs_v1_result_key_columns("confirmation"),
    c("job_id", "estimator")
  )
})
