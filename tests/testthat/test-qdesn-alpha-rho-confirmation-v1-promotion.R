test_that("alpha/rho confirmation promotion selects one coherent parent root", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  source(file.path(
    root,
    "validation",
    "fitforecast_v2",
    "R",
    "qdesn_alpha_rho_confirmation_v1_promotion.R"
  ), local = TRUE)

  profiles <- c(
    "arfc1_candidate_exal_gausmix_t0p25_r01",
    "arfc1_candidate_exal_gausmix_t0p25_r02",
    "arfc1_parent_exal_gausmix_t0p25_r01",
    "arfc1_parent_exal_gausmix_t0p25_r02",
    "arfc1_candidate_exal_laplace_t0p05_r01",
    "arfc1_candidate_exal_laplace_t0p05_r02",
    "arfc1_parent_exal_laplace_t0p05_r01",
    "arfc1_parent_exal_laplace_t0p05_r02"
  )
  metrics <- data.frame(
    target_cell_id = c(rep("exal_gausmix_t0p25", 4), rep("exal_laplace_t0p05", 4)),
    family = c(rep("gausmix", 4), rep("laplace", 4)),
    tau = c(rep(0.25, 4), rep(0.05, 4)),
    comparison_role = rep(c("candidate", "candidate", "parent_exact", "parent_exact"), 2),
    reservoir_replicate = rep(c(1L, 2L, 1L, 2L), 2),
    screening_profile_id = profiles,
    spec_id = paste0("spec_", seq_along(profiles)),
    status = "SUCCESS",
    signoff_grade = c(rep("FAIL", 4), rep("WARN", 4)),
    stop_reason = c(rep("high_autocorrelation", 4), rep("chain_marginal_but_usable", 4)),
    metric_complete = TRUE,
    seed_contract_match = TRUE,
    source_registry_hash_match = TRUE,
    fit_qtrue_rmse = c(1.93548, 1.91454, 1.90443, 1.96662, 6.92193, 6.92937, 6.98844, 6.95883),
    forecast_qtrue_mae_H1000 = c(4.27647, 3.89136, 3.65624, 4.21776, 2.55953, 2.59552, 2.45447, 2.58300),
    forecast_check_loss_H1000 = c(4.67508, 4.68039, 4.64372, 4.71417, 1.86722, 1.85143, 1.85119, 1.84170),
    stringsAsFactors = FALSE
  )
  current <- expand.grid(
    model_variant = "qdesn_exal_rhs_ns",
    family = c("normal", "laplace", "gausmix"),
    tau = c(0.05, 0.25, 0.50),
    stringsAsFactors = FALSE
  )
  current$fit_qtrue_rmse <- 10
  current$forecast_qtrue_mae_H1000 <- 10
  current$forecast_check_loss_H1000 <- 10
  current$source_registry_hash_value <- "hash"
  current[current$family == "gausmix" & current$tau == 0.25, c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
  )] <- c(1.96405608813142, 3.97421046865994, 4.6589631672939)
  current[current$family == "laplace" & current$tau == 0.05, c(
    "fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000"
  )] <- c(6.44646101617768, 2.14300659272038, 1.85639152179471)

  review <- qdesn_arfc1_promotion_review(metrics, current)
  approved <- qdesn_arfc1_approved_promotion(review)
  expect_equal(nrow(review), 8L)
  expect_equal(sum(review$promotion_approved), 1L)
  expect_identical(
    approved$screening_profile_id[[1L]],
    "arfc1_parent_exal_gausmix_t0p25_r01"
  )
  expect_true(approved$all_metrics_improve_current[[1L]])
  expect_lt(approved$companion_max_ratio[[1L]], 1)
  expect_false(any(
    review$promotion_approved[review$target_cell_id == "exal_laplace_t0p05"]
  ))
})

test_that("alpha/rho promotion materializer is parseable and storage-light", {
  root <- normalizePath(
    file.path(testthat::test_path(), "..", ".."),
    winslash = "/",
    mustWork = TRUE
  )
  script <- file.path(
    root,
    "validation",
    "fitforecast_v2",
    "scripts",
    "materialize_qdesn_alpha_rho_confirmation_v1_promotion_20260804.R"
  )
  expect_true(file.exists(script))
  expect_silent(parse(script))
  text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_match(text, "PROMOTE_COHERENT_STATUS_AGNOSTIC_METRIC_ENVELOPE", fixed = TRUE)
  expect_match(text, "unexpected_binary_payloads", fixed = TRUE)
  expect_match(text, "Source manifest contains a stale /home path", fixed = TRUE)
})
