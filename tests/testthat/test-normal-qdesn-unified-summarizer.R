test_that("Normal/Q-DESN unified summarizer produces manuscript-ready outputs", {
  script <- test_path("../../scripts/summarize_normal_qdesn_unified_report_20260529.R")
  if (!file.exists(script)) {
    script <- file.path(getwd(), "scripts", "summarize_normal_qdesn_unified_report_20260529.R")
  }
  skip_if_not(file.exists(script))

  input_dir <- tempfile("normal-qdesn-summary-input-")
  output_dir <- tempfile("normal-qdesn-summary-output-")
  dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(c(input_dir, output_dir), recursive = TRUE, force = TRUE), add = TRUE)

  utils::write.csv(
    data.frame(
      repo = "repo",
      branch = "branch",
      head = "git:abc1234",
      dirty = FALSE,
      source_dir = "source",
      D = 1,
      reservoir_n = 5,
      m = 1,
      washout = 2,
      seed = 20260529,
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "repo_state.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      component = c("normal_source", "qdesn_implemented_modes", "qdesn_implemented_modes"),
      method_id = c("normal_scaled_ridge", "qdesn_al_ridge_full", "qdesn_al_ridge_stochastic"),
      likelihood_family = c("normal", "al", "al"),
      prior_family = c("ridge", "ridge", "ridge"),
      target_label = c("normal_scaled_ridge_exact", "full_data_exact", "full_data_approx_stochastic"),
      exact_status = c("full_data_exact_or_cavi", "", ""),
      covariance_form = c("", "full", "full"),
      chunking_mode = c("none", "none", "stochastic"),
      preserves_full_data_target = c(TRUE, TRUE, TRUE),
      approximate = c(FALSE, FALSE, TRUE),
      target_changes = c(FALSE, FALSE, FALSE),
      converged = c(TRUE, TRUE, TRUE),
      finite_state = c(TRUE, TRUE, TRUE),
      elapsed_sec = c(0.1, 0.2, 0.3),
      pinball_tau_0p50 = c(1.1, NA, NA),
      pinball_y = c(NA, 1.2, 1.3),
      rmse_q_target = c(NA, 2.0, 2.1),
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "method_summary.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      component = "qdesn_implemented_modes",
      comparison_type = "exact_chunking",
      reference_method = "qdesn_al_ridge_full",
      candidate_method = "qdesn_al_ridge_exact",
      max_gate_diff = 1e-10,
      relative_gate_diff = 1e-12,
      passed = TRUE,
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "exact_equivalence.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      comparison_type = "stochastic_al",
      reference_method = "qdesn_al_ridge_full",
      candidate_method = "qdesn_al_ridge_stochastic",
      finite_state = TRUE,
      reproducible_beta_mean_max_abs_diff = 0,
      fitted_median_max_abs_diff_vs_reference = 0.1,
      pinball_diff_vs_reference = 0.01,
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "approximate_diagnostics.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      reference_method = "qdesn_al_ridge_full",
      candidate_method = "qdesn_al_ridge_fixed_subset",
      candidate_subset_rows = 10,
      candidate_original_rows = 20,
      fitted_median_max_abs_diff_vs_reference = 0.2,
      pinball_diff_vs_reference = 0.02,
      finite_state = TRUE,
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "target_changing_diagnostics.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      component = "normal_init_warm_start",
      warm_start_id = "normal_scaled_ridge",
      normal_target = "normal_scaled_ridge_exact",
      exact_status = "exact",
      prior_family = "scaled_ridge",
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "initializer_diagnostics.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      method = "qdesn_exal_stochastic",
      attempted = TRUE,
      failed_early = TRUE,
      message = "forbidden",
      reason = "",
      stringsAsFactors = FALSE
    ),
    file.path(input_dir, "forbidden_modes.csv"),
    row.names = FALSE
  )

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(script, "--input-dir", input_dir, "--output-dir", output_dir),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(attr(status, "status") %||% 0L, 0L, info = paste(status, collapse = "\n"))

  expected <- file.path(output_dir, c(
    "manuscript_method_table.csv",
    "manuscript_compact_methods.csv",
    "manuscript_exact_gate_summary.csv",
    "manuscript_approximate_summary.csv",
    "normal_qdesn_manuscript_ready_summary.md",
    "manuscript_pinball_overview.pdf"
  ))
  expect_true(all(file.exists(expected)))

  table <- utils::read.csv(file.path(output_dir, "manuscript_method_table.csv"))
  compact <- utils::read.csv(file.path(output_dir, "manuscript_compact_methods.csv"))

  expect_true(any(table$role == "primary_baseline"))
  expect_true(any(table$role == "approximate_candidate"))
  expect_true("qdesn_al_ridge_full" %in% compact$method_id)
  expect_false(any(compact$component == "normal_init"))
  expect_true(file.info(file.path(output_dir, "manuscript_pinball_overview.pdf"))$size > 0)
})
