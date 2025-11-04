#!/usr/bin/env Rscript

## ================================================================
## DLM simulation suite → CSV/RDS + two PNGs per scenario
## Prints progress with flushing so tmux/tee show logs live.
## Also writes a per-scenario summary.csv (elapsed, status, etc.).
## ================================================================

P_GRID <- c(0.01, seq(0.05, 0.95, by = 0.05), 0.99)

options(warn = 1)  # print warnings immediately

log_time <- function() format(Sys.time(), "%F %T")
logi <- function(..., .sep = " ") {
  cat(log_time(), "|", paste(..., collapse = .sep), "\n", file = stderr())
  flush(stderr())
}

# Fail loud + exit non-zero on unexpected error
options(error = function() {
  cat("\n--- ERROR ---\n", file = stderr())
  tb <- try(utils::capture.output(traceback()), silent = TRUE)
  if (!inherits(tb, "try-error") && length(tb)) {
    writeLines(tb, con = stderr())
  } else {
    writeLines("No traceback available", con = stderr())
  }
  flush(stderr()); q(status = 1, save = "no")
})

## ------------------------------------------------------------------
## Script metadata (so you can verify the exact file/version running)
## ------------------------------------------------------------------
.this_file <- tryCatch({
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE, useBytes = TRUE)
  if (length(arg)) normalizePath(sub("^--file=", "", arg[1]), mustWork = FALSE) else NA_character_
}, error = function(e) NA_character_)
if (!is.na(.this_file)) {
  fi <- tryCatch(file.info(.this_file), error = function(e) NULL)
  if (!is.null(fi)) {
    logi("Running script:", .this_file, "| mtime:", as.character(fi$mtime))
  } else {
    logi("Running script:", .this_file)
  }
} else {
  logi("Running script: <unknown Rscript entrypoint>")
}

## ------------------------------------------------------------------
## Setup
## ------------------------------------------------------------------
req_pkgs <- c("devtools", "ggplot2", "dplyr", "tidyr", "tibble", "scales", "Matrix", "rlang")
need <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(need)) {
  logi("Installing packages:", paste(need, collapse = ", "))
  install.packages(need, dependencies = TRUE)
}
invisible(sapply(
  req_pkgs,
  function(pk) suppressPackageStartupMessages(library(pk, character.only = TRUE)),
  USE.NAMES = FALSE
))

# Load your package code
EXDQLM_DIR <- "/data/muscat_data/jaguir26/exdqlm"
logi("Loading exdqlm from:", EXDQLM_DIR)
devtools::load_all(EXDQLM_DIR)

# Log repo commit if available (non-fatal)
git_rev <- tryCatch(
  suppressWarnings(system2("git", c("-C", EXDQLM_DIR, "rev-parse", "--short", "HEAD"),
                           stdout = TRUE, stderr = TRUE)),
  error = function(e) NULL
)
if (length(git_rev) && nzchar(git_rev[1])) logi("exdqlm git:", git_rev[1])

## ------------------------------------------------------------------
## Helpers: checks, tidy df, plotting
## ------------------------------------------------------------------

assert_out_ok <- function(out, scenario) {
  stopifnot(is.list(out), is.numeric(out$y), is.matrix(out$q), is.numeric(out$p))
  T <- length(out$y); K <- ncol(out$q)
  if (nrow(out$q) != T) stop("q must be T x K.")
  mono_ok <- all(apply(out$q, 1L, function(r) all(diff(r) >= -1e-10)))
  if (!mono_ok) stop("Row-wise quantile monotonicity violated.")
  logi(sprintf("OK: shapes T=%d, K=%d; monotonicity passed. (%s)", T, K, scenario))
  invisible(TRUE)
}

# Robust central band builder (no tidyselect .data inside select/pivot)
make_band_df <- function(df_long, band = c(0.10, 0.90)) {
  band <- sort(band)
  if (!all(is.finite(band)) || length(band) != 2L) return(NULL)

  avail <- sort(unique(df_long$p))
  if (!length(avail)) return(NULL)

  lo_use <- avail[which.min(abs(avail - band[1]))]
  hi_use <- avail[which.min(abs(avail - band[2]))]
  if (!is.finite(lo_use) || !is.finite(hi_use) || abs(lo_use - hi_use) < 1e-12) return(NULL)

  tmp <- df_long |>
    dplyr::filter(p %in% c(lo_use, hi_use)) |>
    dplyr::select(t, p, q) |>
    dplyr::distinct(t, p, .keep_all = TRUE) |>
    tidyr::pivot_wider(
      names_from = "p",
      values_from = "q",
      values_fn  = dplyr::first
    )

  # After pivot, p values became column names (character); pick closest
  nm_char <- names(tmp)
  nm_num  <- suppressWarnings(as.numeric(nm_char))
  keep    <- is.finite(nm_num)                  # drop "t" (and any non-numeric)
  nm_num  <- nm_num[keep]
  nm_char <- nm_char[keep]

  nm_lo <- nm_char[ which.min(abs(nm_num - lo_use)) ]
  nm_hi <- nm_char[ which.min(abs(nm_num - hi_use)) ]

  tmp |>
    dplyr::rename(q_lo = !!rlang::sym(nm_lo),
                  q_hi = !!rlang::sym(nm_hi)) |>
    dplyr::select(t, q_lo, q_hi)

}

plot_quantile_lines <- function(df_long,
                                median_p = 0.50,
                                title = NULL,
                                band = c(0.10, 0.90),
                                palette = "Viridis") {

  df_med <- dplyr::filter(df_long, abs(p - median_p) < 1e-12)

  p_vals <- sort(unique(df_long$p))
  pal_cols <- grDevices::hcl.colors(100, palette = palette)
  col_scale <- ggplot2::scale_color_gradientn(
    colors = pal_cols,
    limits = c(min(p_vals), max(p_vals)),
    labels = scales::percent_format(accuracy = 1),
    name   = "quantile p"
  )

  band_df <- if (is.null(band)) NULL else make_band_df(df_long, band)

  g <- ggplot2::ggplot(df_long, ggplot2::aes(x = .data$t)) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   legend.position = "right") +
    ggplot2::labs(x = "time", y = "value", title = title)

  if (!is.null(band_df)) {
    g <- g + ggplot2::geom_ribbon(
      data = band_df,
      ggplot2::aes(x = .data$t, ymin = .data$q_lo, ymax = .data$q_hi),
      inherit.aes = FALSE, fill = "grey60", alpha = 0.18
    )
  }

  g <- g + ggplot2::geom_line(ggplot2::aes(y = .data$y),
                              linewidth = 0.9, color = "black") +
    ggplot2::geom_line(
      ggplot2::aes(y = .data$q, color = .data$p, group = .data$p),
      linewidth = 0.8, alpha = 0.95
    ) + col_scale

  if (nrow(df_med)) {
    g <- g + ggplot2::geom_line(
      data = df_med, ggplot2::aes(y = .data$q, group = NULL),
      linewidth = 1.4, color = "black", alpha = 0.95
    )
  }
  if ("mu" %in% names(df_long)) {
    g <- g + ggplot2::geom_line(
      ggplot2::aes(y = .data$mu),
      linewidth = 1.0, linetype = 2, color = "#2B6CB0"
    )
  }
  g
}

# Safer coverage calc (no recycling)
coverage_table <- function(out) {
  T <- length(out$y); K <- ncol(out$q)
  yy <- matrix(out$y, nrow = T, ncol = K)
  data.frame(
    p   = out$p,
    cov = colMeans(yy <= out$q)
  )
}

plot_calibration <- function(out, title = "Calibration (hit-rate)") {
  tab <- coverage_table(out)
  ggplot2::ggplot(tab, ggplot2::aes(x = .data$p, y = .data$cov)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linewidth = 0.7, alpha = 0.6) +
    ggplot2::geom_point(size = 2.2, color = "black") +
    ggplot2::geom_line(linewidth = 0.7, color = "#2B6CB0") +
    ggplot2::coord_equal(xlim = c(min(out$p), max(out$p)),
                         ylim = c(min(out$p), max(out$p))) +
    ggplot2::scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank()) +
    ggplot2::labs(x = "target p", y = "empirical P{y_t ≤ Q_p}", title = title)
}

# Builders (wide/long) with stable quantile labels (q_000 … q_100)
build_series_wide <- function(out) {
  stopifnot(is.list(out), is.numeric(out$y), is.matrix(out$q))
  T <- length(out$y)
  p_int <- pmin(pmax(as.integer(round(100 * out$p)), 0L), 100L)  # allow 100
  labs  <- sprintf("q_%03d", p_int)
  Q <- as.data.frame(out$q); colnames(Q) <- labs
  df <- tibble::tibble(t = seq_len(T), y = out$y)
  if (!is.null(out$extras) && !is.null(out$extras$mu)) df$mu <- out$extras$mu
  dplyr::bind_cols(df, Q)
}
build_series_long <- function(out) {
  wide <- build_series_wide(out)
  q_cols <- grep("^q_\\d{3}$", names(wide), value = TRUE)
  tibble::as_tibble(wide) |>
    tidyr::pivot_longer(all_of(q_cols), names_to = "q_lab", values_to = "q") |>
    dplyr::mutate(p = as.numeric(sub("^q_(\\d{3})$", "\\1", q_lab)) / 100) |>
    dplyr::select(t, p, q, dplyr::any_of(c("y", "mu")))
}

write_session_info <- function(dir) {
  path <- file.path(dir, "sessionInfo.txt")
  con <- file(path, open = "wt"); on.exit(close(con), add = TRUE)
  utils::capture.output(sessionInfo(), file = con)
}

save_sim_outputs <- function(out, scenario, dir) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  df_wide <- build_series_wide(out)
  df_long <- build_series_long(out)
  utils::write.csv(df_wide, file.path(dir, "series_wide.csv"), row.names = FALSE)
  utils::write.csv(df_long, file.path(dir, "series_long.csv"), row.names = FALSE)
  utils::write.csv(coverage_table(out), file.path(dir, "calibration.csv"), row.names = FALSE)
  saveRDS(out, file.path(dir, "sim_output.rds"))

  sink(file.path(dir, "meta.txt")); on.exit(sink(), add = TRUE)
  cat("Simulation metadata\n--------------------\n")
  cat("scenario: ", scenario, "\n", sep = "")
  cat("seed:     ", out$info$seed, "\n", sep = "")
  cat("R_mc:     ", out$info$R_mc, "\n", sep = "")
  cat("burnin:   ", out$info$burnin, "\n", sep = "")
  cat("p grid:   ", paste(round(100 * out$p), collapse = ", "), "\n", sep = "")
  cat("params:\n"); utils::str(out$info$params, give.attr = FALSE)
}

## ------------------------------------------------------------------
## Run scenarios — ONLY the 3 DLMs
## ------------------------------------------------------------------

scenarios <- c("dlm_constV_smallW", "dlm_constV_bigW", "dlm_ar1V")

# Base output dirs (absolute so you can launch from anywhere)
base_out <- "/data/muscat_data/jaguir26/exdqlm/results/sim_suite_dlm"
plots_dir <- file.path(base_out, "plots")
data_dir  <- file.path(base_out, "series")
logs_dir  <- file.path(base_out, "logs")   # for your tee wrapper
dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(logs_dir,  recursive = TRUE, showWarnings = FALSE)

# Summary CSV (append-friendly)
SUMMARY_PATH <- file.path(base_out, "summary.csv")
append_summary <- function(rec) {
  first <- !file.exists(SUMMARY_PATH)
  utils::write.table(rec, SUMMARY_PATH, sep = ",", row.names = FALSE,
                     col.names = first, append = !first)
}

logi("PID:", Sys.getpid())
logi("Output dirs:", plots_dir, " | ", data_dir)

run_one <- function(scn,
                    T = 5000L, burnin = 2000L, R_mc = 5000L, seed = 123,
                    p_lines = c(0.05, 0.50, 0.95),
                    window_last = 200L,
                    save_dir = NULL, save_data_dir = NULL,
                    band = c(0.10, 0.90), palette = "Viridis",
                    p_grid = P_GRID) {
  logi("Using p grid (K=", length(p_grid), "): ", paste(p_grid, collapse = ", "))

  t0 <- Sys.time()
  logi("→ Running scenario:", scn,
       sprintf("(T=%d, burnin=%d, R_mc=%d, seed=%d)", T, burnin, R_mc, seed))

  ## --- robust simulator call: resolve the quantile argument name ---
  sim_fun  <- getFromNamespace("simulate_ts_mc_quantiles", "exdqlm")
  form_nms <- names(formals(sim_fun))
  q_name_candidates <- c("p", "ps", "probs", "p_grid", "quantiles")
  q_arg <- intersect(q_name_candidates, form_nms)
  if (length(q_arg)) {
    q_arg <- q_arg[1L]
    logi("simulate_ts_mc_quantiles() quantile arg resolved to:", q_arg)
  } else {
    q_arg <- NULL
    logi("! No recognized quantile arg in simulate_ts_mc_quantiles(); using package default grid.")
  }

  args <- list(
    T = T,
    scenario = scn,
    R_mc = R_mc,
    burnin = burnin,
    seed = seed,
    keep_latents = TRUE,
    keep_draws = FALSE
  )
  if (!is.null(q_arg)) args[[q_arg]] <- p_grid

  out <- do.call(sim_fun, args)


  if (length(out$p) != length(p_grid) ||
      any(abs(sort(out$p) - sort(p_grid)) > 1e-12)) {
    logi("! Warning: simulator may have ignored p_grid; got K=", length(out$p),
         " expected ", length(p_grid))
  }


  assert_out_ok(out, scn)

  # Focus plot on last window; full series is always saved
  t_last <- (T - window_last + 1):T

  # Build df_long for just requested quantiles (nearest; dedup)
  p_sel_idx <- unique(vapply(p_lines, function(pp) which.min(abs(out$p - pp)), integer(1)))
  idx <- t_last
  base <- tibble::tibble(t = idx, y = out$y[idx])
  if (!is.null(out$extras) && !is.null(out$extras$mu)) base$mu <- out$extras$mu[idx]
  df_long <- tibble::tibble(
    t = rep(idx, times = length(p_sel_idx)),
    p = rep(out$p[p_sel_idx], each = length(idx)),
    q = as.numeric(out$q[idx, p_sel_idx, drop = FALSE])
  ) |>
    dplyr::left_join(base, by = "t")

  p_ts  <- plot_quantile_lines(df_long, median_p = 0.50,
                               title = paste0(scn, " — last ", window_last, " points"),
                               band = band, palette = palette)
  p_cal <- plot_calibration(out, title = paste0(scn, " — calibration"))

  if (!is.null(save_dir)) {
    if (!dir.exists(save_dir)) dir.create(save_dir, recursive = TRUE)
    fp_ts <- file.path(save_dir, paste0("ts_", scn, ".png"))
    fp_ca <- file.path(save_dir, paste0("calib_", scn, ".png"))
    ggplot2::ggsave(filename = fp_ts, plot = p_ts, width = 11, height = 5.5, dpi = 220)
    ggplot2::ggsave(filename = fp_ca, plot = p_cal, width = 6.5, height = 5.5, dpi = 220)
    logi("Saved figures:", fp_ts, " & ", fp_ca)
  }

  if (is.null(save_data_dir) && !is.null(save_dir)) {
    save_data_dir <- file.path(save_dir, "data")
  }
  if (!is.null(save_data_dir)) {
    scen_dir <- file.path(save_data_dir, scn)
    save_sim_outputs(out, scn, scen_dir)
    # write session info once per scenario directory (handy for repro)
    write_session_info(scen_dir)
    logi("Saved data to:", scen_dir)
  }

  t1 <- Sys.time()
  dt <- round(as.numeric(difftime(t1, t0, units = "secs")), 1)
  logi(sprintf("✓ Done scenario: %s (%.1fs)", scn, dt))

  # append summary row
  rec <- data.frame(
    scenario = scn, T = T, burnin = burnin, R_mc = R_mc, seed = seed,
    start = as.character(t0), end = as.character(t1), elapsed_s = dt,
    status = "ok", git = if (length(git_rev)) git_rev[1] else NA_character_
  )
  append_summary(rec)

  invisible(list(out = out))
}

# Run them serially (one pair of PNGs + CSV/RDS per scenario), resilient to errors
for (scn in scenarios) {
  t0_loop <- Sys.time()
  ok <- tryCatch({
        run_one(
          scn,
          T = 5000L, burnin = 2000L, R_mc = 5000L, seed = 123,
          p_lines = c(0.05, 0.50, 0.95),
          window_last = 200L,
          save_dir = plots_dir,
          save_data_dir = data_dir,
          band = c(0.10, 0.90),
          palette = "Viridis",
          p_grid = P_GRID
        )
    TRUE
  },
  interrupt = function(e) {
    t1 <- Sys.time()
    dt <- round(as.numeric(difftime(t1, t0_loop, units = "secs")), 1)
    logi("INTERRUPTED during:", scn)
    rec <- data.frame(
      scenario = scn, T = 5000L, burnin = 2000L, R_mc = 5000L, seed = 123,
      start = as.character(t0_loop), end = as.character(t1), elapsed_s = dt,
      status = "interrupt", git = if (length(git_rev)) git_rev[1] else NA_character_
    )
    append_summary(rec)
    stop("Interrupted")  # bubble up to terminate entire script
  },
  error = function(e) {
    t1 <- Sys.time()
    dt <- round(as.numeric(difftime(t1, t0_loop, units = "secs")), 1)
    logi("✗ Failed scenario:", scn, "—", conditionMessage(e))
    rec <- data.frame(
      scenario = scn, T = 5000L, burnin = 2000L, R_mc = 5000L, seed = 123,
      start = as.character(t0_loop), end = as.character(t1), elapsed_s = dt,
      status = "error", git = if (length(git_rev)) git_rev[1] else NA_character_
    )
    append_summary(rec)
    FALSE
  })
  if (!ok) next
}

logi("All scenarios finished.")
