repo <- normalizePath(Sys.getenv("ILR10_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R",
    "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

stopifnot(identical(ilr10_stages, c("smoke", "warm", "discovery",
    "confirm_warm", "confirmation")), max(itm6_folds) + 240L < 9001L)

panel <- ilr10_maximin_panel()
stopifnot(nrow(panel) == 12L, !anyDuplicated(panel$scale_id),
  sum(panel$role == "unmodified_v9_anchor") == 1L,
  all(panel$layer1_scale %in% ilr10_scale_grid),
  all(panel$layer2_scale %in% ilr10_scale_grid),
  any(panel$layer1_scale == .4 & panel$layer2_scale == .7),
  any(panel$layer1_scale == .55 & panel$layer2_scale == .55))

n <- c(141, 119, 90)
blocks <- ifu9_block_indices(n)
multiplier <- ilr10_multiplier_vector(n, .4, .7)
stopifnot(length(multiplier) == 351L, multiplier[1L] == 1,
  all(multiplier[blocks$layer_1] == .4),
  all(multiplier[blocks$layer_2] == .7),
  all(multiplier[blocks$layer_3] == 1))

# Scaling a standardized block by g while retaining the common coefficient
# prior is exactly a relative prior scale g on the original coefficient.
set.seed(10)
X <- matrix(rnorm(5 * length(multiplier)), 5L)
theta <- rnorm(length(multiplier))
scaled <- ilr10_apply_multiplier(X, multiplier)
stopifnot(max(abs(scaled %*% theta - X %*% (multiplier * theta))) < 1e-12)

anchor <- panel[panel$role == "unmodified_v9_anchor", , drop = FALSE]
other <- head(panel[panel$role != "unmodified_v9_anchor", ], 3L)
keys <- rbind(anchor, other)
fake_results <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i)
  data.frame(metric = rep(c("forecast_mae", "forecast_check_loss"), each = 2L),
    mean = c(rep(3 + i / 100, 2L), rep(1.5, 2L)),
    lower = c(rep(2.5, 2L), rep(1.4, 2L)),
    upper = c(rep(3.5 - i / 20, 2L), rep(1.6, 2L)),
    fold = rep(c("S1", "S3"), 2L), scale_id = keys$scale_id[i],
    layer1_scale = keys$layer1_scale[i],
    layer2_scale = keys$layer2_scale[i])))
fake_uncertainty <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i)
  data.frame(estimator = "current_recursive", metric = "forecast_mae",
    mean_interval_score = 2 + i / 100, pointwise_interval_width = 5,
    fold = c("S1", "S3"), scale_id = keys$scale_id[i],
    layer1_scale = keys$layer1_scale[i],
    layer2_scale = keys$layer2_scale[i])))

tmp <- tempfile("ilr10_test_")
dir.create(file.path(tmp, "references"), recursive = TRUE)
baseline <- expand.grid(fold = c("S1", "S3"),
  metric = c("forecast_mae", "forecast_check_loss"),
  stringsAsFactors = FALSE)
baseline$source_stage <- "validation"
baseline$mean <- ifelse(baseline$metric == "forecast_mae", 3, 1.5)
write.csv(baseline, file.path(tmp, "references", "dqlm_baseline_scores.csv"),
  row.names = FALSE)
selection <- ilr10_scale_rank(tmp, fake_results, fake_uncertainty)
stopifnot(nrow(selection$selected) == 3L,
  any(selection$selected$layer1_scale == 1 &
    selection$selected$layer2_scale == 1),
  sum(selection$rank$selected) == 3L)
unlink(tmp, recursive = TRUE)

shell <- file.path(repo, "validation/fitforecast_v2/scripts",
  "run_independent_qdesn_layerwise_readout_v10.sh")
stopifnot(file.exists(shell), system2("bash", c("-n", shell)) == 0L)
for (path in file.path(repo, "validation/fitforecast_v2", c(
    "R/independent_qdesn_layerwise_readout_v10.R",
    "scripts/independent_qdesn_layerwise_readout_v10.R")))
  invisible(parse(path))

cat("independent_qdesn_layerwise_readout_v10: PASS\n")
