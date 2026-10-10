repo <- normalizePath(Sys.getenv("ITM6_REPO", "."), mustWork = TRUE)
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_runtime_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training1000_campaign_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_sentinel_mechanism_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R",
  "independent_qdesn_training_size_mechanism_v6.R"))

stopifnot(identical(itm6_training_sizes, c(500L, 1000L, 2000L, 5000L)),
  length(itm6_cells) == 3L, length(itm6_folds) == 4L,
  max(itm6_folds) + 240L < 9001L)

candidate <- list(m = 500L)
window <- itm6_window("S1", 5000L, candidate)
stopifnot(length(window$train) == 5000L, length(window$washout) == 500L,
  min(window$buffer) == 1001L, max(window$origins) == 7210L,
  max(iqt12_grid(window)$target) <= 7240L)

set.seed(1)
X <- cbind(1, matrix(rnorm(2400), 200, 12))
truth <- seq_len(ncol(X)) / ncol(X)
y <- as.numeric(X %*% truth + rnorm(nrow(X), sd = 0.05))
fit <- itm6_ridge_fit(X, y)
stopifnot(all(is.finite(fit$beta)), fit$lambda %in% fit$lambda_grid,
  mean(abs(fit$fitted - y)) < 0.1, fit$cg_relative_residual < 1e-5)

fake <- expand.grid(cell = "normal__exal__p005", N = 1000L,
  structure_id = c("small", "large"), fold = c("S1", "S3"),
  estimator = c("oracle_ridge", "gaussian_ridge", "normal_rhs"),
  stringsAsFactors = FALSE)
fake$metric <- "forecast_mae"
fake$mean <- ifelse(fake$structure_id == "small", 2, 1)
fake$normal_observed_mae <- fake$mean
fake$normal_observed_mae[fake$structure_id == "large" &
  fake$estimator == "normal_rhs"] <- NA_real_
fake <- rbind(fake, transform(fake[fake$estimator != "normal_rhs", ],
  metric = "teacher_forced_mae"))
score <- itm6_representative_candidates(fake)
stopifnot(nrow(score) == 2L, all(is.finite(score$composite)),
  score$composite[score$structure_id == "large"] <
    score$composite[score$structure_id == "small"])

topology <- itm6_resources(2L)
stopifnot(length(topology) == 2L, !anyDuplicated(topology))

pending_run <- tempfile("itm6_pending_")
dir.create(file.path(pending_run, "plans"), recursive = TRUE)
pending_plan <- data.frame(id = c("job_a", "job_b"),
  config_path = c("/tmp/config_a.json", "/tmp/config_b.json"),
  status_path = file.path(pending_run, "status", c("a.json", "b.json")),
  timeout = c(60, 120), stringsAsFactors = FALSE)
write.csv(pending_plan, file.path(pending_run, "plans", "smoke.csv"),
  row.names = FALSE)
pending_output <- system2(file.path(R.home("bin"), "Rscript"),
  c(file.path(repo, "validation/fitforecast_v2/scripts",
      "independent_qdesn_training_size_mechanism_v6.R"),
    "pending", repo, pending_run, "smoke"), stdout = TRUE)
stopifnot(length(pending_output) == 2L,
  identical(vapply(strsplit(pending_output, "\t", fixed = TRUE), length,
    integer(1L)), c(3L, 3L)))
unlink(pending_run, recursive = TRUE)
cat("independent_qdesn_training_size_mechanism_v6: PASS\n")
