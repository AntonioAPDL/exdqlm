#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/smoke_independent_qdesn_fixed_comparator_forecast_recovery_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/",
                              mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)
suppressPackageStartupMessages(library(exdqlm))

args <- ffv2_parse_args()
source_run_root <- ffv2_resolve_path(
  args$`source-run-root` %||% "", must_work = TRUE
)
output_path <- ffv2_resolve_path(args$output %||% "", must_work = FALSE)
source <- iqfcr_v1_source_audit(
  source_run_root, verify_payload_hashes = FALSE
)
selected <- source$jobs[
  source$jobs$family == "normal" & abs(source$jobs$tau - 0.25) < 1e-12 &
    source$jobs$chain_id == 1L,
  , drop = FALSE
]
if (nrow(selected) != 2L ||
    !setequal(selected$model_variant, c("dqlm", "exdqlm"))) {
  stop("Could not select one DQLM and one exDQLM recovery smoke fit.", call. = FALSE)
}

rows <- lapply(seq_len(nrow(selected)), function(i) {
  started <- Sys.time()
  row <- selected[i, , drop = FALSE]
  config <- ffv2_read_json(row$source_config_path[[1L]])
  fit <- ffv2_read_handoff(
    row$source_handoff_path[[1L]],
    row$source_handoff_manifest_path[[1L]],
    expected_role = "fit"
  )
  data <- ffv2_load_row_data(config)
  first <- ffv2_extend_fit_to_source_origin(fit, config, data, 9001L)
  incremental <- ffv2_advance_fit_between_source_origins(
    first, config, data, 9001L, 9002L
  )
  recomputed <- ffv2_extend_fit_to_source_origin(
    fit, config, data, 9002L
  )
  equality <- c(
    y = identical(incremental$y, recomputed$y),
    fm = isTRUE(all.equal(
      incremental$theta.out$fm, recomputed$theta.out$fm,
      tolerance = 0, check.attributes = TRUE
    )),
    fC = isTRUE(all.equal(
      incremental$theta.out$fC, recomputed$theta.out$fC,
      tolerance = 0, check.attributes = TRUE
    ))
  )
  if (!all(equality)) {
    stop(sprintf("Incremental equivalence failed for %s: %s",
                 row$model_variant[[1L]],
                 paste(names(equality)[!equality], collapse = ", ")), call. = FALSE)
  }
  early_future <- ffv2_make_future_model_arrays(incremental$model, 30L)
  early_incremental <- exdqlmForecast(
    start.t = length(incremental$y), k = 30L, m1 = incremental,
    fFF = early_future$fFF, fGG = early_future$fGG, plot = FALSE,
    return.draws = TRUE, n.samp = 5L,
    seed = as.integer(config$seed) + 9002L
  )
  early_recomputed <- exdqlmForecast(
    start.t = length(recomputed$y), k = 30L, m1 = recomputed,
    fFF = early_future$fFF, fGG = early_future$fGG, plot = FALSE,
    return.draws = TRUE, n.samp = 5L,
    seed = as.integer(config$seed) + 9002L
  )
  early_forecast_equal <- c(
    ff = isTRUE(all.equal(early_incremental$ff, early_recomputed$ff,
                          tolerance = 0, check.attributes = TRUE)),
    fQ = isTRUE(all.equal(early_incremental$fQ, early_recomputed$fQ,
                          tolerance = 0, check.attributes = TRUE)),
    draws = isTRUE(all.equal(
      early_incremental$samp.fore, early_recomputed$samp.fore,
      tolerance = 0, check.attributes = TRUE
    ))
  )
  if (!all(early_forecast_equal)) {
    stop(sprintf("Early forecast equivalence failed for %s: %s",
                 row$model_variant[[1L]],
                 paste(names(early_forecast_equal)[!early_forecast_equal],
                       collapse = ", ")), call. = FALSE)
  }

  late_incremental <- incremental
  for (origin in 9003:9970) {
    late_incremental <- ffv2_advance_fit_between_source_origins(
      late_incremental, config, data, origin - 1L, origin
    )
  }
  late_recomputed <- ffv2_extend_fit_to_source_origin(fit, config, data, 9970L)
  late_state_equal <- c(
    y = identical(late_incremental$y, late_recomputed$y),
    fm = isTRUE(all.equal(
      late_incremental$theta.out$fm, late_recomputed$theta.out$fm,
      tolerance = 0, check.attributes = TRUE
    )),
    fC = isTRUE(all.equal(
      late_incremental$theta.out$fC, late_recomputed$theta.out$fC,
      tolerance = 0, check.attributes = TRUE
    ))
  )
  if (!all(late_state_equal)) {
    stop(sprintf("Terminal state equivalence failed for %s: %s",
                 row$model_variant[[1L]],
                 paste(names(late_state_equal)[!late_state_equal], collapse = ", ")),
         call. = FALSE)
  }
  future <- ffv2_make_future_model_arrays(late_incremental$model, 30L)
  forecast_incremental <- exdqlmForecast(
    start.t = length(late_incremental$y), k = 30L, m1 = late_incremental,
    fFF = future$fFF, fGG = future$fGG, plot = FALSE,
    return.draws = TRUE, n.samp = 5L,
    seed = as.integer(config$seed) + 999999L
  )
  forecast_recomputed <- exdqlmForecast(
    start.t = length(late_recomputed$y), k = 30L, m1 = late_recomputed,
    fFF = future$fFF, fGG = future$fGG, plot = FALSE,
    return.draws = TRUE, n.samp = 5L,
    seed = as.integer(config$seed) + 999999L
  )
  terminal_forecast_equal <- c(
    ff = isTRUE(all.equal(
      forecast_incremental$ff, forecast_recomputed$ff,
      tolerance = 0, check.attributes = TRUE
    )),
    fQ = isTRUE(all.equal(
      forecast_incremental$fQ, forecast_recomputed$fQ,
      tolerance = 0, check.attributes = TRUE
    )),
    draws = isTRUE(all.equal(
      forecast_incremental$samp.fore, forecast_recomputed$samp.fore,
      tolerance = 0, check.attributes = TRUE
    ))
  )
  checks <- c(
    origins_equal = all(equality),
    early_forecast_equal = all(early_forecast_equal),
    terminal_state_equal = all(late_state_equal),
    terminal_forecast_equal = all(terminal_forecast_equal),
    late_length = length(late_incremental$y) == 9970L - 8500L,
    forecast_means = length(forecast_incremental$ff) == 30L &&
      all(is.finite(forecast_incremental$ff)),
    forecast_draws = identical(dim(forecast_incremental$samp.fore), c(30L, 5L)) &&
      all(is.finite(forecast_incremental$samp.fore))
  )
  if (!all(checks)) {
    stop(sprintf("Forecast recovery smoke failed for %s: %s",
                 row$model_variant[[1L]],
                 paste(names(checks)[!checks], collapse = ", ")), call. = FALSE)
  }
  out <- data.frame(
    model_variant = row$model_variant[[1L]],
    family = row$family[[1L]], tau = row$tau[[1L]],
    chain_id = row$chain_id[[1L]],
    package_version = as.character(packageVersion("exdqlm")),
    namespace_helper = "make_df_mat",
    incremental_equivalence = all(equality),
    terminal_origin = 9970L, terminal_horizon = 30L,
    finite_terminal_forecast = all(checks),
    runtime_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
    source_handoff_sha256 = row$source_handoff_sha256[[1L]],
    stringsAsFactors = FALSE
  )
  rm(
    fit, first, incremental, recomputed, early_future, early_incremental,
    early_recomputed, late_incremental, late_recomputed, future,
    forecast_incremental, forecast_recomputed
  )
  gc()
  out
})
result <- do.call(rbind, rows)
ffv2_write_csv(result, output_path)
cat(sprintf("RECOVERY_SMOKE_PASS models=%d output=%s\n", nrow(result), output_path))
