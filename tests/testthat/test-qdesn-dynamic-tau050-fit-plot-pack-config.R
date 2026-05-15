test_that("tau050 fit plot pack manifest resolves to two complete 4-fit cases", {
  manifest <- exdqlm:::qdesn_dynamic_fitplotpack_load_manifest(
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_fit_plot_pack_manifest.yaml")
  )
  source_state <- exdqlm:::.qdesn_dynamic_fitplotpack_resolve_source_state(manifest)
  case_table <- exdqlm:::.qdesn_dynamic_fitplotpack_case_table(manifest, source_state)
  source_fit_table <- exdqlm:::.qdesn_dynamic_fitplotpack_source_fit_table(case_table, source_state)

  expect_equal(nrow(case_table), 2L)
  expect_equal(sort(case_table$case_id), sort(c("clean_ridge_short", "stress_rhs_short")))
  expect_equal(nrow(source_fit_table), 8L)
  expect_true(all(exdqlm:::.qdesn_dynamic_fitplotpack_panel_order() %in% source_fit_table$fit_key))

  counts <- stats::setNames(
    as.integer(table(source_fit_table$case_id)),
    names(table(source_fit_table$case_id))
  )
  expect_equal(unname(counts[["clean_ridge_short"]]), 4L)
  expect_equal(unname(counts[["stress_rhs_short"]]), 4L)
})

test_that("fit plot pack analysis writer emits summary and manifest", {
  tmp_root <- tempfile("fitplotpack_")
  dir.create(tmp_root, recursive = TRUE, showWarnings = FALSE)
  train_plot <- file.path(tmp_root, "train_mu_band.png")
  file.create(train_plot)

  source_state <- list(
    source_run_root = "/tmp/source_run_root",
    comparison_root = "/tmp/comparison_root"
  )
  case_table <- data.frame(
    case_id = "demo_case",
    case_label = "Demo case",
    root_id = "root__demo",
    family = "gausmix",
    tau = 0.25,
    fit_size = 500L,
    prior = "ridge",
    rationale = "demo rationale",
    stringsAsFactors = FALSE
  )
  source_fit_table <- data.frame(
    case_id = "demo_case",
    case_label = "Demo case",
    panel_label = "VB / AL",
    signoff_grade = "PASS",
    holdout_qtrue_mae = 1.23,
    holdout_pinball_tau = 0.45,
    runtime_sec = 12.3,
    stringsAsFactors = FALSE
  )
  rerun_status <- data.frame(
    case_id = "demo_case",
    case_label = "Demo case",
    root_id = "root__demo",
    fit_key = "vb_al",
    panel_label = "VB / AL",
    method = "vb",
    model = "al",
    source_fit_dir = "/tmp/source_fit",
    rerun_fit_dir = "/tmp/rerun_fit",
    pipeline_status = 0L,
    summary_status = "SUCCESS",
    rerun_wall_seconds = 12.3,
    rerun_total_stage_seconds = 11.9,
    train_plot_exists = TRUE,
    train_plot_path = train_plot,
    forecast_plot_exists = FALSE,
    forecast_plot_path = NA_character_,
    stringsAsFactors = FALSE
  )
  out_root <- file.path(tmp_root, "report")

  exdqlm:::qdesn_dynamic_fitplotpack_write_analysis(
    source_state = source_state,
    case_table = case_table,
    source_fit_table = source_fit_table,
    rerun_status = rerun_status,
    output_root = out_root,
    manifest = list(plotting = list(train_last_window = 100L))
  )

  expect_true(file.exists(file.path(out_root, "summary", "qdesn_tau050_fit_plot_comparison_pack.md")))
  expect_true(file.exists(file.path(out_root, "manifest", "analysis_manifest.json")))
})
