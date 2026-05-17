test_that("protocol freeze ledger names the active rolling-origin v3 protocol", {
  ledger <- ffv2_read_protocol_freeze()
  active <- ffv2_active_protocol()

  expect_equal(nrow(active), 1L)
  expect_equal(active$protocol_id, "rolling-origin-v3-1.0.0")
  expect_equal(active$new_forecast_protocol, "rolling_origin_no_refit_state_update")
  expect_equal(as.integer(active$primary_hmax), 30L)
  expect_equal(as.integer(active$primary_origin_stride), 30L)
  expect_equal(as.integer(active$source_period), 90L)
  expect_true(any(grepl("qdesn-dynamic-fitforecast-v2", ledger$run_tag, fixed = TRUE)))
  expect_true(any(grepl("20260515_exdqlm_dqlm_dynamic_fitforecast_v2", ledger$run_tag, fixed = TRUE)))
})

test_that("superseded protocol rows are refused for article consumption", {
  ledger <- ffv2_read_protocol_freeze()
  superseded <- ledger[ledger$protocol_role == "superseded_run", , drop = FALSE]

  expect_gt(nrow(superseded), 0L)
  expect_true(all(superseded$status == "aborted_protocol_superseded"))
  expect_true(all(superseded$article_consumption == "refuse"))
  expect_false(any(startsWith(superseded$evidence_path, "/home/jaguir26/local/src")))
})
