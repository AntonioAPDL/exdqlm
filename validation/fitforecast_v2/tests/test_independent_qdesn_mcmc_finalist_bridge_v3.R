repo <- normalizePath(Sys.getenv("IFBV3_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_sentinel_mechanism_recovery_v1.R",
    "independent_qdesn_causal_adaptation_v2.R",
    "independent_qdesn_mcmc_finalist_bridge_v3.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

testthat::test_that("all full-MCMC finalists are represented exactly once", {
  testthat::expect_identical(ifbv3_all_candidates, c(
    "23eb3c867723c85379f2", "3a7a6653cb244f49813c",
    "1b071df459e29d74d20f"))
  testthat::expect_setequal(ifbv3_new_candidates, c(
    "23eb3c867723c85379f2", "1b071df459e29d74d20f"))
})

testthat::test_that("rank and gates use paired direct MCMC evidence", {
  make <- function(id, ratios, static = rep(.8, 12), check = rep(.95, 12))
    data.frame(candidate_id = id, adapted_mae = ratios,
      adapted_static_mae_ratio = static,
      adapted_baseline_mae_ratio = ratios,
      adapted_baseline_check_ratio = check)
  a <- make("a", c(rep(.9, 7), rep(1.1, 5)))
  b <- make("b", c(rep(.95, 6), rep(1.05, 6)))
  rank <- ifbv3_order_rank(ifbv3_rank(rbind(a, b)))
  testthat::expect_identical(rank$candidate_id[1L], "a")
  testthat::expect_true(rank$closes_baseline_gap[1L])
  testthat::expect_false(rank$closes_baseline_gap[2L])
  testthat::expect_true(all(rank$adaptation_supported))
})

testthat::test_that("confirmation aggregation requires exactly three chains", {
  make <- function(chain) expand.grid(candidate_id = "a", fold = ism1_folds,
    refit_origin = 1:3, metric = c("forecast_mae", "forecast_check_loss"),
    stringsAsFactors = FALSE)
  z <- do.call(rbind, lapply(1:3, function(chain) {
    x <- make(chain); x$chain <- chain; x$mean <- chain; x
  }))
  out <- ifbv3_aggregate_confirmation(z[z$chain == 1, ],
    z[z$chain > 1, ], "a")
  testthat::expect_true(all(out$mean$mean == 2))
  testthat::expect_true(all(out$spread$chain_range == 2))
  testthat::expect_error(ifbv3_aggregate_confirmation(z[z$chain == 1, ],
    z[z$chain == 2, ], "a"))
})

testthat::test_that("all bridge offsets remain in the internal block", {
  for (fold in ism1_folds) {
    end <- c(S1 = 8000L, S2 = 8250L, S3 = 8500L, S4 = 8750L)[fold]
    testthat::expect_lte(max(end + icav2_bridge_offsets + 30L), 9000L)
  }
})

testthat::test_that("bridge worker verifies its configured stage plan", {
  worker <- paste(deparse(body(icav2_bridge_worker)), collapse = "\n")
  testthat::expect_match(worker, "cfg\\$stage")
  testthat::expect_false(grepl("mcmc_bridge_hashes[.]csv", worker))
})
