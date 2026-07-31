helper_path <- file.path(
  testthat::test_path("..", ".."),
  "validation", "fitforecast_v2", "R", "qdesn_alpha_rho_topology_v1.R"
)
source(helper_path, local = TRUE)

testthat::test_that("alpha/rho arm design is broad, deterministic, and valid", {
  arms <- qdesn_arv1_arm_design()
  testthat::expect_equal(nrow(arms), 36L)
  testthat::expect_equal(sum(arms$arm_class == "mechanism_control"), 4L)
  testthat::expect_equal(sum(arms$arm_class != "mechanism_control"), 32L)
  broad <- arms[arms$arm_class != "mechanism_control", , drop = FALSE]
  testthat::expect_true(all(broad$alpha > 0 & broad$alpha < 1))
  testthat::expect_true(all(broad$rho > 0 & broad$rho < 1))
  testthat::expect_equal(length(unique(paste(broad$alpha, broad$rho))), 32L)
  testthat::expect_true(all(c(0.0001, 0.95) %in% broad$alpha))
  testthat::expect_true(all(c(0.05, 0.997) %in% broad$rho))
})

testthat::test_that("plan stays case-specific and has frozen counts", {
  plan <- qdesn_arv1_build_plan(testthat::test_path("..", ".."))
  testthat::expect_equal(nrow(plan$parents), 5L)
  testthat::expect_true(all(plan$parents$D == 1L))
  testthat::expect_equal(nrow(plan$profiles), 360L)
  testthat::expect_equal(nrow(plan$assignments), 360L)
  testthat::expect_equal(as.integer(table(plan$profiles$target_cell_id)), rep(72L, 5L))
  testthat::expect_equal(sort(unique(plan$profiles$reservoir_replicate)), c(1L, 2L))
  testthat::expect_equal(sum(plan$profiles$arm_code == "parent_exact"), 10L)
  tau0_by_cell <- split(plan$profiles$rhs_tau0, plan$profiles$target_cell_id)
  testthat::expect_true(all(vapply(tau0_by_cell, function(x) {
    length(unique(x)) == 1L && is.finite(x[[1L]]) && x[[1L]] > 0
  }, logical(1L))))
})

testthat::test_that("topology repair activates W and Win on a common skeleton", {
  plan <- qdesn_arv1_build_plan(testthat::test_path("..", ".."))
  audit <- qdesn_arv1_topology_audit(plan$profiles)
  broad <- audit[audit$arm_class != "mechanism_control", , drop = FALSE]
  testthat::expect_equal(nrow(broad), 320L)
  testthat::expect_true(all(broad$total_topology_valid))
  full <- audit[audit$topology_mode == "repair_w_win", , drop = FALSE]
  groups <- split(seq_len(nrow(full)), paste(full$target_cell_id, full$reservoir_replicate))
  testthat::expect_true(all(vapply(groups, function(idx) {
    length(unique(full$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(full$input_mask_sha256[idx])) == 1L
  }, logical(1L))))
  parent <- audit[audit$arm_code == "parent_exact", , drop = FALSE]
  testthat::expect_true(any(!parent$total_topology_valid))
})

testthat::test_that("fast D1 topology builder exactly matches package construction", {
  plan <- qdesn_arv1_build_plan(testthat::test_path("..", ".."))
  p <- plan$profiles[plan$profiles$arm_code == "full_topology", , drop = FALSE][1L, ]
  fast <- .qdesn_arv1_build_d1_reservoir(
    p$n_each, p$m, p$alpha, p$rho, p$pi_w, p$pi_in, p$seed
  )
  fit <- qdesn_fit_vb(
    y = rep(0, max(3L, as.integer(p$m) + 2L)),
    p0 = p$target_tau,
    D = 1L,
    n = p$n_each,
    n_tilde = integer(0),
    m = p$m,
    alpha = p$alpha,
    rho = p$rho,
    pi_w = p$pi_w,
    pi_in = p$pi_in,
    washout = 0L,
    add_bias = p$add_bias,
    seed = p$seed,
    fit_readout = FALSE
  )
  testthat::expect_identical(fast$W, fit$reservoir$W[[1L]])
  testthat::expect_identical(fast$Win, fit$reservoir$Win[[1L]])
})

testthat::test_that("source replicate contract is independent and complete", {
  cfg <- yaml::read_yaml(file.path(
    testthat::test_path("..", ".."), "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_alpha_rho_topology_v1_source_replicates.yaml"
  ))
  testthat::expect_equal(length(cfg$replicates), 3L)
  scenarios <- vapply(cfg$replicates, function(x) x$scenario_id, character(1L))
  testthat::expect_equal(length(unique(scenarios)), 3L)
  all_seeds <- unlist(lapply(cfg$replicates, function(x) {
    unlist(lapply(x$seeds, unlist), use.names = FALSE)
  }), use.names = FALSE)
  testthat::expect_equal(length(unique(all_seeds)), length(all_seeds))
  testthat::expect_equal(cfg$selection_contract$expected_total_specs, 1080L)
})

testthat::test_that("pipeline resource sampler avoids GNU awk reserved names", {
  pipeline_path <- file.path(
    testthat::test_path("..", ".."), "validation", "fitforecast_v2", "scripts",
    "run_qdesn_alpha_rho_topology_v1_pipeline.sh"
  )
  lines <- readLines(pipeline_path, warn = FALSE)
  testthat::expect_false(any(grepl("awk -v load=", lines, fixed = TRUE)))
  testthat::expect_true(any(grepl("PIPELINE_SELF_TEST_OK", lines, fixed = TRUE)))
})
