repo <- normalizePath(Sys.getenv("IFD11_REPO", "."), mustWork = TRUE)
for (file in c("independent_qdesn_training1000_runtime_v1.R",
    "independent_qdesn_training1000_campaign_v1.R",
    "independent_qdesn_sentinel_mechanism_v1.R",
    "independent_qdesn_training_size_mechanism_v6.R",
    "independent_qdesn_gausmix_conditioning_v7.R",
    "independent_qdesn_forecast_uncertainty_v8.R",
    "independent_qdesn_rhs_uncertainty_v9.R",
    "independent_qdesn_layerwise_readout_v10.R",
    "independent_qdesn_fresh_dgp_v11.R"))
  source(file.path(repo, "validation/fitforecast_v2/R", file))

stopifnot(identical(ifd11_arm_id("s", 1L, 2L, 1L, .25),
    ifd11_arm_id("s", 1.0, 2.0, 1.0, .25)),
  ifd11_arm_id("s", 1, 2, 1, .25) != ifd11_arm_id("s", 1, 2, 1, 1))
w <- ifd11_window("F1")
g <- iqt12_grid(w)
stopifnot(w$N == 2000L, length(w$washout) == 500L,
  identical(w$train, 7001:9000), length(w$origins) == 34L,
  nrow(g) == 1000L, identical(as.integer(g$target), 9001:10000),
  !anyDuplicated(g$target), sum(g$origin == 9990L) == 10L,
  nrow(iqt12_grid(ifd11_window("F1", "warm"))) == 1L,
  nrow(iqt12_grid(ifd11_window("F1", "smoke"))) == 2L)
guard <- data.frame(origin = 9000L,
  current_prediction_max_absolute_error = 1e-12,
  shared_state_prediction_max_absolute_error = 2e-12, pass = TRUE)
stopifnot(iqt12_guard_summary(guard)$pass,
  length(iqt12_guard_summary(guard)$maximum_errors) == 2L,
  all(is.finite(unlist(iqt12_guard_summary(guard)$maximum_errors))),
  inherits(try(iqt12_guard_summary(transform(guard, pass = FALSE)),
    silent = TRUE), "try-error"))
stopifnot(identical(ifd11_cpu_list("0-2,7,9-10"), c(0:2, 7L, 9:10)))

parent_plan <- read.csv(file.path(ifd11_parent, "plans/confirmation.csv"))
template <- iqt12_read(parent_plan$config_path[1L])
tmp <- tempfile("ifd11_test_"); dir.create(tmp)
state <- list(template = template, repo = repo, run = tmp,
  library = template$library, sources = list(F1 = list(path = "fresh.csv", sha256 = "sha")))
anchor <- ifd11_config(state, "anchor", "F1", "warm")
retained <- ifd11_config(state, "retained", "F1", "warm")
fields <- c("n", "m", "alpha", "rho", "input_gain", "input_fanin",
  "recurrent_indegree", "interlayer_fanin", "matrix_seed", "tau_source", "slab_source")
stopifnot(identical(anchor$candidate[fields], template$candidate[fields]),
  identical(anchor$candidate[fields], retained$candidate[fields]),
  anchor$seed == retained$seed, anchor$layer2_scale == 1,
  retained$layer2_scale == .25, anchor$scale_id != retained$scale_id,
  anchor$window$N == 2000L, anchor$likelihood == "al",
  identical(anchor$baseline$models, template$baseline$models),
  anchor$baseline$train_start_source_index == 7001L,
  is.null(anchor$baseline$row_config_path))
iqt12_json(anchor, file.path(tmp, "roundtrip.json"))
roundtrip <- iqt12_read(file.path(tmp, "roundtrip.json"))
stopifnot(roundtrip$scale_id == ifd11_arm_id(roundtrip$candidate$structure_id,
  roundtrip$candidate$tau_source, roundtrip$candidate$slab_source,
  roundtrip$layer1_scale, roundtrip$layer2_scale))

set.seed(10)
fit <- matrix(rnorm(2000 * 4), 2000L)
forecast <- matrix(rnorm(1000 * 4), 1000L)
source <- data.frame(t = 1:10000, y = 0, q_target = 0)
scores <- ifd11_score_companions(fit, forecast, source, w, .05)
stopifnot(nrow(scores$summary) == 5L, all(is.finite(scores$summary$mean)),
  all(scores$summary$width >= 0), nrow(scores$profile) == 1000L,
  max(abs(scores$draws$forecast_mae - colMeans(abs(forecast)))) < 1e-12,
  scores$attribution$total_metric_variance >= 0)
coherent <- matrix(rep(c(-3, -1, 1, 3), each = 1000L), 1000L)
attribution <- ifd11_score_companions(fit, coherent, source, w, .05)$attribution
stopifnot(abs(attribution$variance_ratio_to_independent_marginals - 1000) < 1e-8)

.libPaths(c(template$library, .libPaths()))
helper <- ifd11_dgp_helper(repo)
a <- ifd11_dgp(helper, 81112001L, 81112002L)
b <- ifd11_dgp(helper, 81112001L, 81112002L)
c <- ifd11_dgp(helper, 81113001L, 81113002L)
historical <- ifd11_dgp(helper, 32011L, 32012L)$source
original <- read.csv(paste0("/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/",
  "sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast/",
  "gausmix/tau_0p05/series_wide.csv"))
stopifnot(identical(a, b), !identical(a$source, c$source),
  max(abs(as.matrix(historical) - as.matrix(original))) <= 1e-6,
  max(abs(a$source$q_target - a$source$mu)) == 0,
  max(abs(a$source$y - a$source$mu - a$source$eps)) < 1e-10,
  abs(helper$.dynamic_dgp_gausmix_cdf(a$shift, c(.5, 15), c(.1, .9), 1) - .05) < 1e-10)

# Oracle values and observations beyond the fixed origin cannot affect its design.
e <- ifd11_runtime(repo, template$library)
cfg <- retained; cfg$window <- ifd11_window("F1", "smoke")
cx <- ilr10_design_hook(e, cfg, a$source, cfg$window$end)
changed <- a$source
changed$q_target <- changed$q_target + 9999
changed$y[9002:10000] <- changed$y[9002:10000] + 12345
cy <- ilr10_design_hook(e, cfg, changed, cfg$window$end)
stopifnot(identical(cx$object$X, cy$object$X),
  identical(cx$object$y_fit, cy$object$y_fit),
  identical(cx$all_X[1:(9001L - cx$first + 1L), ],
    cy$all_X[1:(9001L - cy$first + 1L), ]),
  all(cx$object$reservoir$Q_is_identity), ncol(cx$object$X) == 351L,
  !isTRUE(cx$object$meta$readout_spec$include_input))
files <- ifd11_sources(repo, e)
stopifnot(all(file.exists(files)), all(e$iqt12_loaded_files %in% files),
  file.path(repo, "R/exal_online_vbld.R") %in% files)

# Exercise all automatic closeout paths with synthetic, explicitly non-scientific evidence.
fixture <- file.path(tmp, "fixture")
dir.create(file.path(fixture, "review"), recursive = TRUE)
source_path <- iqt12_csv(source, file.path(fixture, "source.csv"))
sentinel <- iqt12_json(list(synthetic_test_only = TRUE), file.path(fixture, "sentinel.json"))
for (name in c("source", "package", "input", "frozen"))
  iqt12_hash(sentinel, file.path(fixture, paste0(name, "_hashes.csv")))
iqt12_json(list(expected_jobs = c(smoke = 2, warm = 6, confirmation = 18)),
  file.path(fixture, "campaign.json"))
for (stage in ifd11_stages) {
  grid <- if (stage == "confirmation")
    expand.grid(replica = c("F1", "F2"), arm = c("dqlm", "anchor", "retained"), chain = 1:3) else
    if (stage == "warm") expand.grid(replica = c("F1", "F2"),
      arm = c("dqlm", "anchor", "retained"), chain = 1L) else
      data.frame(replica = "F1", arm = c("dqlm", "retained"), chain = 1L)
  configs <- lapply(seq_len(nrow(grid)), function(i) {
    cfg <- anchor
    cfg$run <- fixture; cfg$stage <- stage
    cfg$arm <- as.character(grid$arm[i]); cfg$replica <- as.character(grid$replica[i])
    cfg$chain <- grid$chain[i]; cfg$id <- paste(stage, cfg$replica, cfg$arm, cfg$chain, sep = "__")
    cfg$path <- file.path(fixture, "configs", paste0(cfg$id, ".json"))
    cfg$status_path <- file.path(fixture, "status", paste0(cfg$id, ".json"))
    cfg$evidence <- file.path(fixture, "evidence", cfg$id)
    cfg$source_path <- source_path; cfg$window <- w
    if (stage == "confirmation") {
      for (name in c("fit_location_draws", "forecast_location_draws", "metric_draws")) {
        value <- switch(name, fit_location_draws = cbind(source_index = w$train, fit),
          forecast_location_draws = cbind(g, forecast), metric_draws = scores$draws)
        iqt12_csv(value, file.path(cfg$evidence, paste0(name, ".csv.gz")))
      }
      iqt12_json(list(trace_diagnostics = list(sigma_ESS = 100,
        intercept_ESS = if (cfg$arm == "dqlm") NULL else 50)),
        file.path(cfg$evidence, "diagnostics.json"))
      manifest <- iqt12_hash(list.files(cfg$evidence, full.names = TRUE),
        file.path(cfg$evidence, "manifest.csv"))
    } else manifest <- iqt12_hash(sentinel, file.path(fixture,
      "evidence", cfg$id, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", manifest = manifest), cfg$status_path)
    cfg
  })
  ifd11_plan(list(run = fixture), stage, configs)
}
ifd11_closeout(fixture)
ifd11_verify(fixture)
stopifnot(file.info(file.path(fixture, "review/fresh_dgp_v11_review.pdf"))$size > 10000,
  nrow(read.csv(file.path(fixture, "review/summary.csv"))) == 30L,
  sum(ifd11_health(fixture)$complete) == 26L)
if (nzchar(Sys.getenv("IFD11_TEST_PDF")))
  stopifnot(file.copy(file.path(fixture, "review/fresh_dgp_v11_review.pdf"),
    Sys.getenv("IFD11_TEST_PDF"), overwrite = TRUE))
unlink(tmp, recursive = TRUE)
cat("Fresh-DGP v11 focused tests: PASS\n")
