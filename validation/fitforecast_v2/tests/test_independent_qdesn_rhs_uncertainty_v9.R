repo <- normalizePath(Sys.getenv("IFU9_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R",
    "independent_qdesn_rhs_uncertainty_v9.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

stopifnot(identical(ifu9_stages, c("smoke", "attribution", "warm",
    "discovery", "confirm_warm", "confirmation")),
  max(itm6_folds) + 240L < 9001L)

panel <- ifu9_maximin_panel(2)
stopifnot(nrow(panel) == 12L, !anyDuplicated(panel$prior_id),
  sum(panel$role == "v8_parent_anchor") == 1L,
  any(panel$tau_multiplier == 2 & panel$slab_multiplier == 0.5),
  all(panel$tau_multiplier %in% ifu9_tau_grid),
  all(panel$slab_multiplier %in% ifu9_slab_grid))

# effective_p0 and a compensating multiplier are exactly redundant because
# only their induced tau_source enters the fitted prior.
p <- 350
p0_a <- 34
p0_b <- 17
multiplier_a <- 2
multiplier_b <- multiplier_a * (p0_a / (p - p0_a)) /
  (p0_b / (p - p0_b))
tau_a <- p0_a / (p - p0_a) * multiplier_a
tau_b <- p0_b / (p - p0_b) * multiplier_b
stopifnot(abs(tau_a - tau_b) < 1e-12)

fake <- data.frame(tau_multiplier = c(2, 3),
  qdesn_forecast_mae = c(3, 3.1), dqlm_forecast_mae = c(3, 3),
  ratio_to_dqlm = c(1, 1.033), worst_fold_ratio = c(1.1, 1.1),
  forecast_mae_width = c(1.2, 1.8), dqlm_forecast_mae_width = c(.4, .4),
  v7_forecast_mae = c(3.2, 3.2), v7_forecast_mae_width = c(2, 2),
  forecast_check_loss = c(1, 1), dqlm_forecast_check_loss = c(1, 1),
  v7_forecast_check_loss = c(1, 1), interval_score = c(2, 2),
  v7_interval_score = c(2, 2), chains = c(6, 6), eligible = c(TRUE, TRUE))
classification <- ifu9_parent_classification(fake)
stopifnot(classification$classification == "FULL_RESCUE",
  !classification$run_required,
  abs(classification$excess_width_gap_closed - 0.5) < 1e-12)

blocks <- ifu9_block_indices(c(141, 119, 90))
stopifnot(identical(names(blocks), c("intercept", "layer_3", "layer_1",
    "layer_2")), sum(lengths(blocks)) == 351L,
  identical(blocks$intercept, 1L), !anyDuplicated(unlist(blocks)))

anchor <- panel[panel$role == "v8_parent_anchor", , drop = FALSE]
keys <- rbind(anchor, head(panel[panel$role != "v8_parent_anchor", ], 2L))
fake_results <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
  rows <- data.frame(metric = rep(c("forecast_mae", "forecast_check_loss"),
      each = 2L), mean = c(rep(3 + i / 100, 2L), rep(1.5, 2L)),
    lower = c(rep(2.5, 2L), rep(1.4, 2L)),
    upper = c(rep(3.5, 2L), rep(1.6, 2L)),
    fold = rep(c("S1", "S3"), 2L),
    tau_multiplier = keys$tau_multiplier[i],
    slab_multiplier = keys$slab_multiplier[i], prior_id = keys$prior_id[i])
  rows
}))
fake_uncertainty <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i)
  data.frame(estimator = "current_recursive", metric = "forecast_mae",
    mean_interval_score = 2 + i / 100, pointwise_interval_width = 5,
    fold = c("S1", "S3"), tau_multiplier = keys$tau_multiplier[i],
    slab_multiplier = keys$slab_multiplier[i], prior_id = keys$prior_id[i])))
parent_tau <- keys$tau_multiplier[1L]
selection <- ifu9_select_priors(fake_results, fake_uncertainty, parent_tau)
stopifnot(nrow(selection$selected) == 2L,
  sum(selection$rank$selected) == 2L)

shell <- file.path(repo, "validation/fitforecast_v2/scripts",
  "run_independent_qdesn_rhs_uncertainty_v9.sh")
stopifnot(file.exists(shell), system2("bash", c("-n", shell)) == 0L)

for (path in file.path(repo, "validation/fitforecast_v2", c(
    "R/independent_qdesn_rhs_uncertainty_v9.R",
    "scripts/independent_qdesn_rhs_uncertainty_v9.R")))
  invisible(parse(path))

cat("independent_qdesn_rhs_uncertainty_v9: PASS\n")
