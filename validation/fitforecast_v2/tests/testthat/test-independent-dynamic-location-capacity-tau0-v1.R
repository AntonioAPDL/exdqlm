testthat::test_that("dynamic-location V1 freezes the four case-specific targets", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_dynamic_location_capacity_tau0_v1.R"
  ), local = TRUE)
  targets <- idlc_v1_read_targets(repo)
  testthat::expect_equal(nrow(targets), 4L)
  testthat::expect_equal(
    sort(targets$target_cell_id),
    sort(c("al_normal_t0p05", "exal_normal_t0p05",
           "al_normal_t0p50", "exal_normal_t0p50"))
  )
  testthat::expect_equal(sort(unique(targets$likelihood_target)), c("al", "exal"))
  testthat::expect_true(all(file.exists(file.path(repo, targets$parent_request_path))))
  testthat::expect_equal(nrow(idlc_v1_assert_authorities(repo)), 4L)
})

testthat::test_that("dynamic-location V1 is an exact 4 by 4 matched crossing", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_dynamic_location_capacity_tau0_v1.R"
  ), local = TRUE)
  profiles <- idlc_v1_build_candidate_profiles(repo)
  testthat::expect_equal(nrow(profiles), 64L)
  testthat::expect_equal(as.integer(table(profiles$target_cell_id)), rep(16L, 4L))
  testthat::expect_true(all(table(
    paste(profiles$target_cell_id, profiles$selection_arm)
  ) == 4L))
  testthat::expect_equal(
    sort(unique(profiles$selection_arm)),
    sort(c("P0_parent", "P1_compact_persistent",
           "P2_multiscale_moderate", "P3_deep_selective"))
  )
  testthat::expect_equal(anyDuplicated(profiles$candidate_id), 0L)
  testthat::expect_equal(anyDuplicated(profiles$exact_signature), 0L)
})

testthat::test_that("capacity, topology, persistence, and tau0 gates are enforced", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_dynamic_location_capacity_tau0_v1.R"
  ), local = TRUE)
  profiles <- idlc_v1_build_candidate_profiles(repo)
  testthat::expect_lte(max(profiles$effective_readout_dimension), 400L)
  testthat::expect_true(all(profiles$rhs_tau0 >= 1e-9))
  testthat::expect_equal(min(profiles$rhs_tau0), 1e-9)
  testthat::expect_true(all(vapply(
    profiles$pi_w, function(x) all(qdesn_ssv2_vec(x, "numeric") > 0), logical(1L)
  )))
  testthat::expect_true(all(vapply(
    profiles$pi_in, function(x) all(qdesn_ssv2_vec(x, "numeric") > 0), logical(1L)
  )))
  by_cell <- split(profiles, profiles$target_cell_id)
  testthat::expect_true(all(vapply(
    by_cell, function(x) any(x$max_alpha >= .70 & x$max_rho >= .90), logical(1L)
  )))
})

testthat::test_that("parent controls are recovered from exact frozen requests", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_dynamic_location_capacity_tau0_v1.R"
  ), local = TRUE)
  targets <- idlc_v1_read_targets(repo)
  profiles <- idlc_v1_build_candidate_profiles(repo)
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, , drop = FALSE]
    request <- qdesn_ssv2_read_json(file.path(repo, target$parent_request_path[[1L]]))
    expected <- idlc_v1_profile_from_request(request)
    actual <- profiles[
      profiles$target_cell_id == target$target_cell_id[[1L]] &
        profiles$selection_arm == "P0_parent" &
        abs(profiles$rhs_tau0 - target$parent_tau0[[1L]]) < 1e-15,
      , drop = FALSE
    ]
    testthat::expect_equal(nrow(actual), 1L)
    testthat::expect_identical(actual$profile_signature[[1L]],
                               expected$profile_signature[[1L]])
  }
})

testthat::test_that("MCMC budgets and exact exAL transition are frozen", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE),
                        winslash = "/")
  source(file.path(
    repo, "validation", "fitforecast_v2", "R",
    "independent_dynamic_location_capacity_tau0_v1.R"
  ), local = TRUE)
  testthat::expect_equal(idlc_v1_budget("screen")$n_burn, 1000L)
  testthat::expect_equal(idlc_v1_budget("screen")$n_mcmc, 4000L)
  testthat::expect_equal(idlc_v1_budget("confirmation")$n_mcmc, 20000L)
  testthat::expect_identical(qdesn_ssv2_method_id,
                             "m0_v_collapsed_support_logit")
  testthat::expect_equal(idlc_v1_reconstruction_tolerance, 1e-6)
})
