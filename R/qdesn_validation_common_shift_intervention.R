.qdesn_validation_common_shift_cfg <- function(defaults = NULL) {
  cfg <- defaults$metrics$posterior_metric_intervals$common_shift_intervention %||% list()
  list(
    enabled = isTRUE(cfg$enabled),
    required = isTRUE(cfg$required),
    schema_version = as.character(cfg$schema_version %||%
      "independent_qdesn_common_shift_intervention_v1")
  )
}

.qdesn_validation_common_shift_summary <- function(draws, defaults = NULL) {
  cfg <- .qdesn_validation_common_shift_cfg(defaults)
  if (!isTRUE(cfg$enabled)) return(list(status = "DISABLED"))
  context <- attr(draws, "metric_dispersion_context")
  if (is.null(context)) {
    stop("Common-shift intervention requires metric-dispersion context.", call. = FALSE)
  }
  q <- as.matrix(context$native_q)
  q_true <- as.numeric(context$q_true)
  y <- as.numeric(context$y)
  tau <- as.numeric(context$tau)[1L]
  if (nrow(q) != length(q_true) || nrow(q) != length(y) || ncol(q) != nrow(draws)) {
    stop("Common-shift intervention inputs are not aligned.", call. = FALSE)
  }

  posterior_mean_path <- rowMeans(q)
  common_shift <- colMeans(sweep(q, 1L, posterior_mean_path, "-"))
  oracle_location_error <- colMeans(sweep(q, 1L, q_true, "-"))
  variants <- list(
    observed = q,
    common_shift_removed = sweep(q, 2L, common_shift, "-"),
    oracle_location_corrected = sweep(q, 2L, oracle_location_error, "-")
  )
  summarize <- function(name, value) {
    mae <- colMeans(abs(sweep(value, 1L, q_true, "-")))
    check <- colMeans(.qdesn_validation_metric_check_loss(
      matrix(y, nrow = length(y), ncol = ncol(value)), value, tau
    ))
    do.call(rbind, lapply(list(forecast_mae = mae, forecast_check_loss = check),
      function(metric) {
        quant <- stats::quantile(metric, c(0.025, 0.5, 0.975), names = FALSE,
                                 type = 8, na.rm = TRUE)
        data.frame(
          intervention = name, metric = deparse(substitute(metric)),
          posterior_mean = mean(metric), posterior_sd = stats::sd(metric),
          cri_lower = quant[[1L]], posterior_median = quant[[2L]],
          cri_upper = quant[[3L]], cri_width = quant[[3L]] - quant[[1L]],
          n_draws = length(metric), stringsAsFactors = FALSE
        )
      }))
  }
  rows <- list()
  for (name in names(variants)) {
    value <- variants[[name]]
    mae <- colMeans(abs(sweep(value, 1L, q_true, "-")))
    check <- colMeans(.qdesn_validation_metric_check_loss(
      matrix(y, nrow = length(y), ncol = ncol(value)), value, tau
    ))
    for (metric_name in c("forecast_mae", "forecast_check_loss")) {
      metric <- if (metric_name == "forecast_mae") mae else check
      quant <- stats::quantile(metric, c(0.025, 0.5, 0.975), names = FALSE,
                               type = 8, na.rm = TRUE)
      rows[[length(rows) + 1L]] <- data.frame(
        intervention = name, metric = metric_name,
        posterior_mean = mean(metric), posterior_sd = stats::sd(metric),
        cri_lower = quant[[1L]], posterior_median = quant[[2L]],
        cri_upper = quant[[3L]], cri_width = quant[[3L]] - quant[[1L]],
        n_draws = length(metric), stringsAsFactors = FALSE
      )
    }
  }
  summary <- do.call(rbind, rows)
  observed <- summary[summary$intervention == "observed", ]
  effects <- do.call(rbind, lapply(setdiff(names(variants), "observed"), function(name) {
    candidate <- summary[summary$intervention == name, ]
    candidate <- candidate[match(observed$metric, candidate$metric), ]
    data.frame(
      intervention = name, metric = observed$metric,
      mean_ratio = candidate$posterior_mean / observed$posterior_mean,
      variance_ratio = candidate$posterior_sd^2 / observed$posterior_sd^2,
      width_ratio = candidate$cri_width / observed$cri_width,
      stringsAsFactors = FALSE
    )
  }))
  shift <- data.frame(
    quantity = c("posterior_common_shift", "oracle_location_error"),
    mean = c(mean(common_shift), mean(oracle_location_error)),
    sd = c(stats::sd(common_shift), stats::sd(oracle_location_error)),
    q025 = c(stats::quantile(common_shift, 0.025),
             stats::quantile(oracle_location_error, 0.025)),
    q975 = c(stats::quantile(common_shift, 0.975),
             stats::quantile(oracle_location_error, 0.975)),
    stringsAsFactors = FALSE
  )
  list(status = "PASS", summary = summary, effects = effects, shift = shift)
}

.qdesn_validation_write_common_shift_intervention <- function(draws, method_dir,
                                                               defaults = NULL) {
  cfg <- .qdesn_validation_common_shift_cfg(defaults)
  if (!isTRUE(cfg$enabled)) return(list(status = "DISABLED"))
  out <- .qdesn_validation_common_shift_summary(draws, defaults)
  table_dir <- file.path(method_dir, "tables")
  manifest_dir <- file.path(method_dir, "manifest")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- c(
    summary = file.path(table_dir, "common_shift_intervention_summary.csv"),
    effects = file.path(table_dir, "common_shift_intervention_effects.csv"),
    shift = file.path(table_dir, "common_shift_intervention_shift.csv")
  )
  .qdesn_validation_write_df(out$summary, paths[["summary"]])
  .qdesn_validation_write_df(out$effects, paths[["effects"]])
  .qdesn_validation_write_df(out$shift, paths[["shift"]])
  sha <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
  manifest_path <- file.path(manifest_dir, "common_shift_intervention_manifest.json")
  manifest <- list(
    schema_version = cfg$schema_version, generated_at = as.character(Sys.time()),
    status = "PASS", estimand = "diagnostic_draw_level_counterfactual_risk",
    deployable_forecast = FALSE, article_promotion_authorized = FALSE,
    full_forecast_draw_matrix_retained = FALSE,
    artifact_paths = lapply(paths, normalizePath, winslash = "/", mustWork = TRUE),
    artifact_sha256 = lapply(paths, sha)
  )
  .qdesn_validation_write_json(manifest_path, manifest)
  list(status = "PASS", manifest_path = normalizePath(
    manifest_path, winslash = "/", mustWork = TRUE), manifest_sha256 = sha(manifest_path),
    paths = as.list(paths))
}
