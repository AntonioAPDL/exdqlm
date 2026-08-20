testthat::test_that("canonical-gap v2 frozen design is case-specific and novel", {
  repo <- normalizePath(system("git rev-parse --show-toplevel", intern=TRUE), winslash="/")
  source(file.path(repo,"validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"),local=TRUE)
  stub<-file.path(repo,"config/validation",qdesn_cgcv2_stage)
  t<-qdesn_ssv2_read_csv(paste0(stub,"_target_cells.csv"));p<-qdesn_ssv2_read_csv(paste0(stub,"_candidate_profiles.csv"))
  h<-qdesn_ssv2_read_csv(file.path(repo,"config/validation/qdesn_dynamic_fitforecast_v2_500obs_forecast_gap_adaptive_mcmc_v1_history_signature_ledger.csv"))
  testthat::expect_equal(nrow(t),4L);testthat::expect_equal(nrow(p),64L)
  testthat::expect_equal(as.integer(table(p$target_cell_id)),rep(16L,4));testthat::expect_false(any(p$profile_signature%in%h$profile_signature))
  testthat::expect_lte(max(p$effective_readout_dimension),900L);testthat::expect_equal(sort(unique(p$likelihood_target)),c("al","exal"))
  testthat::expect_true(max(p$max_alpha)>.99);testthat::expect_true(min(p$min_alpha)<.1)
})

testthat::test_that("canonical-gap budgets and promotion policy are frozen", {
  repo<-normalizePath(system("git rev-parse --show-toplevel",intern=TRUE),winslash="/")
  source(file.path(repo,"validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"),local=TRUE)
  testthat::expect_equal(qdesn_cgcv2_budget("confirmation")$n_mcmc,20000L)
  testthat::expect_equal(qdesn_cgcv2_method_id,"m0_v_collapsed_support_logit")
  testthat::expect_equal(qdesn_cgcv2_timeout_seconds("confirmation"),604800L)
})
