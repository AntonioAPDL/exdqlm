# Output and provenance helpers for the residual Q-DESN ablation.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.qdesn_git_sha <- function() {
  out <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) character(0)
  )
  if (length(out) && nzchar(out[1L])) out[1L] else NA_character_
}

.qdesn_write_ablation_manifest <- function(result, output_dir, run_signature, y_hash,
                                            candidates_hash, seeds) {
  manifest <- data.frame(
    key = c(
      "study_id", "created_utc", "run_signature_sha256", "implementation_sha256",
      "series_sha256", "candidates_sha256", "rhs_tau0", "quantiles", "screening_seeds",
      "confirmation_additional_seeds", "confirmation_all_seeds", "final_seeds", "screening_paths",
      "confirmation_paths", "final_paths", "workers", "quick",
      "git_sha", "R_version"
    ),
    value = c(
      "qdesn_residual_skip_single_origin_v1",
      format(Sys.time(), tz = "UTC", usetz = TRUE),
      run_signature,
      result$implementation_sha256,
      y_hash,
      candidates_hash,
      as.character(result$protocol$rhs_tau0),
      paste(result$protocol$p_vec, collapse = ","),
      paste(seeds$screening, collapse = ","),
      paste(seeds$confirmation_additional, collapse = ","),
      paste(seeds$confirmation_all, collapse = ","),
      paste(seeds$final, collapse = ","),
      as.character(result$execution$nd_screen),
      as.character(result$execution$nd_confirm),
      as.character(result$execution$nd_final),
      as.character(result$execution$workers),
      as.character(result$execution$quick),
      .qdesn_git_sha(),
      R.version.string
    ),
    stringsAsFactors = FALSE
  )
  utils::write.csv(manifest, file.path(output_dir, "run_manifest.csv"), row.names = FALSE)
  invisible(manifest)
}

.qdesn_write_ablation_plots <- function(result, output_dir) {
  plot_dir <- file.path(output_dir, "figures")
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  pointwise <- result$final_pointwise
  if (!nrow(pointwise)) return(invisible(NULL))

  primary <- pointwise[pointwise$model_id %in% c(
    "M0_plain_selected", "M1_residual_same_hyperparameters"
  ), , drop = FALSE]
  if (!nrow(primary)) return(invisible(NULL))

  agg_key <- interaction(primary$model_id, primary$p0, primary$horizon, drop = TRUE)
  agg_rows <- lapply(split(primary, agg_key), function(z) {
    data.frame(
      model_id = z$model_id[1L],
      p0 = z$p0[1L],
      horizon = z$horizon[1L],
      y = z$y[1L],
      qhat = stats::median(z$qhat, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  agg <- do.call(rbind, agg_rows)
  if (is.null(agg) || !nrow(agg)) return(invisible(NULL))
  agg <- agg[order(agg$model_id, agg$p0, agg$horizon), , drop = FALSE]

  grDevices::png(file.path(plot_dir, "final_quantile_paths.png"), width = 1400, height = 800, res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  y_true <- agg$y[agg$model_id == "M0_plain_selected" & agg$p0 == min(agg$p0)]
  if (!length(y_true) || any(!is.finite(y_true))) {
    grDevices::dev.off()
    on.exit(NULL, add = FALSE)
    return(invisible(NULL))
  }
  graphics::plot(seq_along(y_true), y_true, type = "l", lwd = 2,
       xlab = "Forecast horizon", ylab = "Response",
       main = "Single-origin 100-step quantile forecasts")
  palette <- c("black", "grey40", "grey70")
  for (model_id in c("M0_plain_selected", "M1_residual_same_hyperparameters")) {
    for (ip in seq_along(sort(unique(agg$p0)))) {
      p0 <- sort(unique(agg$p0))[ip]
      z <- agg[agg$model_id == model_id & agg$p0 == p0, , drop = FALSE]
      graphics::lines(z$horizon, z$qhat, lty = if (model_id == "M0_plain_selected") 2 else 1,
            lwd = 2, col = palette[ip])
    }
  }
  graphics::legend("topleft",
         legend = c("Observed", "Plain: dashed", "Residual: solid", "q=.50", "q=.75", "q=.95"),
         lty = c(1, 2, 1, 1, 1, 1),
         lwd = c(2, 2, 2, 2, 2, 2),
         col = c("black", "black", "black", palette), bty = "n")
  grDevices::dev.off()
  on.exit(NULL, add = FALSE)

  wide <- merge(
    primary[primary$model_id == "M0_plain_selected",
            c("reservoir_seed", "p0", "horizon", "pinball")],
    primary[primary$model_id == "M1_residual_same_hyperparameters",
            c("reservoir_seed", "p0", "horizon", "pinball")],
    by = c("reservoir_seed", "p0", "horizon"),
    suffixes = c("_M0", "_M1")
  )
  if (nrow(wide)) {
    diff_h <- stats::aggregate(
      I(pinball_M1 - pinball_M0) ~ horizon,
      data = wide,
      FUN = mean
    )
    names(diff_h)[2L] <- "mean_difference"
    diff_h$cumulative_difference <- cumsum(diff_h$mean_difference)

    grDevices::png(file.path(plot_dir, "cumulative_pinball_difference.png"), width = 1200, height = 700, res = 140)
    graphics::plot(diff_h$horizon, diff_h$cumulative_difference, type = "l", lwd = 2,
         xlab = "Forecast horizon", ylab = "Cumulative pinball difference (residual - plain)",
         main = "Cumulative paired loss difference")
    graphics::abline(h = 0, lty = 2)
    grDevices::dev.off()
  }

  paired <- result$final_paired_differences
  if (!is.null(paired) && nrow(paired)) {
    grDevices::png(file.path(plot_dir, "paired_seed_differences.png"), width = 1100, height = 700, res = 140)
    graphics::plot(paired$reservoir_seed, paired$difference_M1_minus_M0,
         pch = 19, xlab = "Reservoir seed",
         ylab = "Scaled loss difference (residual - plain)",
         main = "Paired final loss differences by reservoir seed")
    graphics::abline(h = 0, lty = 2)
    grDevices::dev.off()
  }
  invisible(NULL)
}

.qdesn_write_ablation_tables <- function(result, output_dir) {
  table_dir <- file.path(output_dir, "tables")
  dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(result$screening_summary,
                   file.path(table_dir, "screening_cells.csv"), row.names = FALSE)
  utils::write.csv(result$screening_ranking,
                   file.path(table_dir, "screening_ranking.csv"), row.names = FALSE)
  utils::write.csv(result$confirmation_summary,
                   file.path(table_dir, "confirmation_cells.csv"), row.names = FALSE)
  utils::write.csv(result$confirmation_ranking,
                   file.path(table_dir, "confirmation_ranking.csv"), row.names = FALSE)
  utils::write.csv(result$selected_models,
                   file.path(table_dir, "selected_models.csv"), row.names = FALSE)
  utils::write.csv(result$final_summary,
                   file.path(table_dir, "final_summary.csv"), row.names = FALSE)
  utils::write.csv(result$final_aggregate,
                   file.path(table_dir, "final_aggregate.csv"), row.names = FALSE)
  utils::write.csv(result$final_horizon_blocks,
                   file.path(table_dir, "final_horizon_blocks.csv"), row.names = FALSE)
  utils::write.csv(result$final_paired_differences,
                   file.path(table_dir, "final_paired_differences.csv"), row.names = FALSE)
  utils::write.csv(result$final_pointwise,
                   file.path(table_dir, "final_pointwise.csv"), row.names = FALSE)
  saveRDS(result, file.path(output_dir, "qdesn_residual_ablation_result.rds"))
  invisible(NULL)
}
