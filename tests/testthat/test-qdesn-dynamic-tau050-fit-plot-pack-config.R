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
