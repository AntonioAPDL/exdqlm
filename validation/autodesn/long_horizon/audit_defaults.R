# Audit the default serial forecast against the previously delivered revision.
# Requires this Git checkout, but no historical fitted-model binary.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
main <- function() {
  revision <- "1b4c7595089ae0506fe7dc4a318fc054db2e2ec6"
  old <- system2("/usr/bin/git", c("show", paste0(revision, ":R/qdesn_normal.R")), stdout = TRUE)
  path <- tempfile(fileext = ".R"); writeLines(old, path)
  on.exit(unlink(path))
  e <- new.env(parent = .GlobalEnv); sys.source(path, e)
  specs <- lh_specs()$specifications[c(1L, 20L, 69L)]
  y <- sin(seq_len(1000) / 7) + .02 * cos(seq_len(1000) / 13)
  bank <- autodesn_build_bank(y, specs, conditioning = 500L, washout = 500L)
  checks <- list()
  for (j in seq_along(specs)) {
    object <- bank$templates[[j]]; object$fit <- list(target_label = "parity")
    class(object) <- c("qdesn_normal_fit", "list")
    draw <- .autodesn_seed(j, function() list(
      beta = matrix(stats::rnorm(5 * ncol(object$X), sd = .1), 5), omega2 = seq(.1, .5, length.out = 5)))
    before <- e$forecast_paths.qdesn_normal_fit(object, H = 100L, y_hist = bank$history_scaled,
      draws = draw, seed = 11L)
    after <- forecast_paths.qdesn_normal_fit(object, H = 100L, y_hist = bank$history_scaled,
      draws = draw, seed = 11L)
    batched <- forecast_paths.qdesn_normal_fit(object, H = 100L, y_hist = bank$history_scaled,
      draws = draw, seed = 11L, backend = "batched")
    checks[[j]] <- data.frame(D = specs[[j]]$D, width = specs[[j]]$n[1L], m = specs[[j]]$m,
      default_y_max_abs = max(abs(before$yrep - after$yrep)),
      default_mu_max_abs = max(abs(before$mu_draws - after$mu_draws)),
      batched_y_max_abs = max(abs(batched$yrep - after$yrep)),
      batched_mu_max_abs = max(abs(batched$mu_draws - after$mu_draws)))
  }
  tab <- do.call(rbind, checks)
  out <- Sys.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(tab, file.path(out, "default_forecast_parity.csv"), row.names = FALSE)
  stopifnot(all(tab$default_y_max_abs == 0), all(tab$default_mu_max_abs == 0),
    all(tab$batched_y_max_abs < 1e-10), all(tab$batched_mu_max_abs < 1e-10))
  print(tab, row.names = FALSE)
}
main()
