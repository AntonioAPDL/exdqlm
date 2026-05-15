repo_root <- normalizePath(
  system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
  winslash = "/",
  mustWork = TRUE
)
harness_root <- file.path(repo_root, "validation", "fitforecast_v2")
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))

ffv2_test_defaults <- function(source_root = tempfile("ffv2_sources_"),
                               run_root = tempfile("ffv2_run_")) {
  defaults <- ffv2_load_defaults()
  defaults$source$root <- source_root
  defaults$study$results_root <- dirname(run_root)
  defaults$study$run_tag <- basename(run_root)
  defaults
}

ffv2_test_write_sources <- function(defaults, n = 10000L) {
  scenario <- defaults$study$scenario_id
  for (family in as.character(defaults$source$families)) {
    for (tau in as.numeric(defaults$source$taus)) {
      tau_label <- ffv2_tau_label(tau)
      root <- file.path(defaults$source$root, scenario, family, sprintf("tau_%s", tau_label))
      dir.create(root, recursive = TRUE, showWarnings = FALSE)
      t <- seq_len(n)
      y <- sin(t / 30) + tau
      q_true <- sin(t / 30)
      utils::write.csv(
        data.frame(t = t, y = y, mu = q_true, q_target = q_true, eps = y - q_true),
        file.path(root, "series_wide.csv"),
        row.names = FALSE
      )
      utils::write.csv(
        data.frame(t = t, tau = tau, q_true = q_true),
        file.path(root, "true_quantile_grid.csv"),
        row.names = FALSE
      )
      writeLines(c(
        sprintf("scenario_id: %s", scenario),
        sprintf("family: %s", family),
        sprintf("tau: %.2f", tau),
        "TT_main: 10000",
        "TT_warmup: 2000",
        "period: 90",
        "harmonics: 1, 2",
        "C0_scale: 0.010000",
        "level0: 40.000000",
        "slope0: 0.012000",
        "harmonic1_amp_phase: 24.000000 @ 0.350000",
        "harmonic2_amp_phase: 8.000000 @ -0.800000",
        "state_noise_sd: 0.005, 0.00002, 0.004, 0.004, 0.003, 0.003"
      ), file.path(root, "meta.txt"))
    }
  }
  invisible(defaults$source$root)
}
