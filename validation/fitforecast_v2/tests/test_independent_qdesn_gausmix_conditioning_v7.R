repo <- normalizePath(Sys.getenv("IGC7_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_sentinel_mechanism_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training_size_mechanism_v6.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_gausmix_conditioning_v7.R"))

stopifnot(identical(igc7_stages,
    c("smoke", "representation", "quantile", "validation", "mcmc")),
  identical(igc7_conditioning_modes, c("none", "fold_zscore")),
  identical(igc7_tau_multipliers, c(0.5, 1, 2, 3)),
  max(igc7_folds) + 240L < 9001L)

set.seed(1)
X <- cbind(1, matrix(rnorm(400), 40, 10) * rep(seq_len(10), each = 40))
scaled <- igc7_condition_fit(X, "fold_zscore")
stopifnot(identical(scaled$X[, 1L], X[, 1L]),
  max(abs(colMeans(scaled$X[, -1L, drop = FALSE]))) < 1e-12,
  max(abs(apply(scaled$X[, -1L, drop = FALSE], 2L, sd) - 1)) < 1e-12,
  identical(igc7_condition_apply(X, scaled), scaled$X))

beta_scaled <- rnorm(ncol(X))
beta_raw <- beta_scaled
beta_raw[-1L] <- beta_scaled[-1L] / scaled$scale
beta_raw[1L] <- beta_scaled[1L] - sum(scaled$center * beta_raw[-1L])
stopifnot(max(abs(as.numeric(scaled$X %*% beta_scaled) -
    as.numeric(X %*% beta_raw))) < 1e-10)

reference <- list(candidate = list(sigma_b_source = 1, response_scale = 1,
  slab_source = 1, omega_b_source = 1))
first <- igc7_new_candidate(reference, 1L)
stopifnot(first$D >= 3L, first$D <= 6L, first$total_states >= 250L,
  first$total_states <= 600L, first$m >= 240L, first$m <= 500L,
  first$alpha >= 0.04, first$alpha <= 0.60,
  first$rho >= 0.97, first$rho <= 0.9995,
  first$readout_dimension == first$total_states + 1L,
  first$matrix_seed == 920001L)
roundtrip_path <- tempfile(fileext = ".json")
iqt12_json(list(candidate = first), roundtrip_path)
roundtrip <- iqt12_read(roundtrip_path)$candidate
rebuilt <- itm6_candidate(igc7_normalize_candidate(roundtrip), reference,
  roundtrip$role)
stopifnot(rebuilt$structure_id == first$structure_id)

fake <- expand.grid(structure_id = c("a", "b"), tau_multiplier = c(0.5, 1),
  readout_conditioning = igc7_conditioning_modes, fold = c("S1", "S3"),
  metric = c("forecast_mae", "forecast_check_loss"),
  stringsAsFactors = FALSE)
fake$mean <- ifelse(fake$structure_id == "a", 2, 3) +
  ifelse(fake$readout_conditioning == "fold_zscore", -0.2, 0) +
  ifelse(fake$metric == "forecast_check_loss", 0.1, 0)
fake$total_states <- ifelse(fake$structure_id == "a", 300L, 400L)
fake$output_lags <- ifelse(fake$structure_id == "a", 240L, 300L)
fake$config_path <- paste(fake$structure_id, fake$tau_multiplier,
  fake$readout_conditioning, fake$fold, sep = "_")
rank <- igc7_quantile_rank(fake)
stopifnot(nrow(rank) == 8L,
  rank$structure_id[1L] == "a",
  rank$readout_conditioning[1L] == "fold_zscore")

history_repo <- tempfile("igc7_history_")
dir.create(file.path(history_repo, "validation/fitforecast_v2/promotions"),
  recursive = TRUE)
write.csv(data.frame(structure_id = c("prior_a", "prior_b")),
  file.path(history_repo, "validation/fitforecast_v2/promotions/prior.csv"),
  row.names = FALSE)
history <- igc7_historical_structures(history_repo,
  data.frame(structure_id = c("parent_a", "prior_a")))
stopifnot(setequal(history$structure_id,
    c("parent_a", "prior_a", "prior_b")),
  any(history$source == "v6_parent_candidate_bank"))

validation_run <- tempfile("igc7_validation_")
dir.create(file.path(validation_run, "references"), recursive = TRUE)
write.csv(data.frame(source_stage = "validation", metric = "forecast_mae",
    fold = c("S1", "S2", "S3", "S4"), mean = 1),
  file.path(validation_run, "references/v6_baseline_scores.csv"),
  row.names = FALSE)
validation <- expand.grid(candidate_id = "same_candidate",
  structure_id = "same_structure", tau_multiplier = 1,
  readout_conditioning = igc7_conditioning_modes,
  fold = c("S1", "S2", "S3", "S4"), stringsAsFactors = FALSE)
validation$metric <- "forecast_mae"
validation$mean <- ifelse(validation$readout_conditioning == "none", 2, 4)
validation$total_states <- 300L
validation$output_lags <- 240L
validation_rank <- igc7_validation_rank(validation_run, validation)
stopifnot(nrow(validation_rank) == 2L,
  validation_rank$ratio[validation_rank$readout_conditioning == "none"] == 2,
  validation_rank$ratio[
    validation_rank$readout_conditioning == "fold_zscore"] == 4)

cat("independent_qdesn_gausmix_conditioning_v7: PASS\n")
