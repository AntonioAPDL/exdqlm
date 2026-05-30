test_that("Normal/Q-DESN manuscript plotting script writes figures and manifest", {
  script <- test_path("../../scripts/plot_normal_qdesn_manuscript_comparison_20260529.R")
  if (!file.exists(script)) {
    script <- file.path(getwd(), "scripts", "plot_normal_qdesn_manuscript_comparison_20260529.R")
  }
  skip_if_not(file.exists(script))

  input_dir <- tempfile("normal-qdesn-plot-input-")
  manuscript_dir <- file.path(input_dir, "manuscript_ready")
  output_dir <- file.path(manuscript_dir, "figures")
  dir.create(manuscript_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(input_dir, recursive = TRUE, force = TRUE), add = TRUE)

  utils::write.csv(
    data.frame(head = "git:testhead", dirty = FALSE, stringsAsFactors = FALSE),
    file.path(input_dir, "repo_state.csv"),
    row.names = FALSE
  )

  compact <- data.frame(
    schema_version = "normal_qdesn_manuscript_methods_v2",
    component = c("normal_source", "qdesn_implemented_modes", "qdesn_implemented_modes"),
    method_id = c("normal_scaled_ridge", "qdesn_al_rhs_ns_full", "qdesn_al_ridge_hybrid"),
    table_label = c("Normal DESN, ridge", "Q-DESN AL, RHS_NS", "Q-DESN AL, ridge hybrid"),
    role = c("primary_baseline", "primary_baseline", "approximate_candidate"),
    target_group = c("Normal exact baseline", "full-data baseline", "approximate full-data fit"),
    likelihood_family = c("normal", "al", "al"),
    prior_family = c("ridge", "rhs_ns", "ridge"),
    primary_spine = c(TRUE, TRUE, FALSE),
    rhs_ns_default = c(FALSE, TRUE, FALSE),
    legacy_rhs_footnote = c(FALSE, FALSE, FALSE),
    diagnostic_only = c(FALSE, FALSE, FALSE),
    target_changing_nonprimary = c(FALSE, FALSE, FALSE),
    finite_state = c(TRUE, TRUE, TRUE),
    elapsed_sec = c(0.1, 0.2, 0.3),
    pinball = c(1.0, 1.1, 1.05),
    rmse = c(2.0, 2.1, 2.05),
    stringsAsFactors = FALSE
  )
  utils::write.csv(compact, file.path(manuscript_dir, "manuscript_compact_methods.csv"), row.names = FALSE)

  utils::write.csv(
    data.frame(
      reference_method = "qdesn_al_rhs_ns_full",
      candidate_method = "qdesn_al_rhs_ns_exact",
      exact_chunked_method = "",
      tolerance = 1e-6,
      max_gate_diff = 1e-10,
      passed = TRUE,
      stringsAsFactors = FALSE
    ),
    file.path(manuscript_dir, "manuscript_exact_gate_summary.csv"),
    row.names = FALSE
  )

  utils::write.csv(
    data.frame(
      comparison_type = "hybrid_al",
      reference_method = "qdesn_al_rhs_ns_full",
      candidate_method = "qdesn_al_ridge_hybrid",
      finite_state = TRUE,
      pinball_diff_vs_reference = -0.01,
      stringsAsFactors = FALSE
    ),
    file.path(manuscript_dir, "manuscript_approximate_summary.csv"),
    row.names = FALSE
  )

  rows <- seq_len(12L)
  utils::write.csv(
    rbind(
      data.frame(
        method = "normal_scaled_ridge",
        method_id = "",
        row_id = rows,
        y = sin(rows / 3),
        point = sin(rows / 3) + 0.1,
        source_index = rows,
        q_target = sin(rows / 3),
        mu = sin(rows / 3),
        fitted_median = NA_real_
      ),
      data.frame(
        method = "",
        method_id = "qdesn_al_rhs_ns_full",
        row_id = rows,
        y = sin(rows / 3),
        point = NA_real_,
        source_index = rows,
        q_target = sin(rows / 3),
        mu = sin(rows / 3),
        fitted_median = sin(rows / 3) + 0.05
      )
    ),
    file.path(input_dir, "predictions_by_method.csv"),
    row.names = FALSE
  )

  status <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(script, "--input-dir", input_dir, "--manuscript-dir", manuscript_dir, "--output-dir", output_dir),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_equal(attr(status, "status") %||% 0L, 0L, info = paste(status, collapse = "\n"))

  expected <- file.path(output_dir, c(
    "figure_predictive_metrics.png",
    "figure_runtime_vs_loss.png",
    "figure_prediction_overlay.png",
    "figure_exact_gates.png",
    "figure_manifest.csv",
    "figure_input_hashes.csv"
  ))
  expect_true(all(file.exists(expected)))
  expect_true(all(file.info(expected)$size > 0))

  manifest <- utils::read.csv(file.path(output_dir, "figure_manifest.csv"))
  expect_setequal(
    manifest$figure_id,
    c("predictive_metrics", "runtime_vs_loss", "prediction_overlay", "exact_gates")
  )
})
