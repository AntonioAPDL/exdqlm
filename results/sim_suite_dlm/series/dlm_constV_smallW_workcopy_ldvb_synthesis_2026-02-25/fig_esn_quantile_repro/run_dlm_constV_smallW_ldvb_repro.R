#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  req <- c("devtools", "Matrix", "ggplot2", "jsonlite")
  miss <- setdiff(req, rownames(installed.packages()))
  if (length(miss)) {
    stop("Missing required packages: ", paste(miss, collapse = ", "))
  }
  invisible(lapply(req, require, character.only = TRUE))
})

repo_root <- "/data/muscat_data/jaguir26/exdqlm__wt__0.3.0-cpp"
dataset_dir <- file.path(repo_root, "results/sim_suite_dlm/series/dlm_constV_smallW_workcopy_20260225")
output_root <- file.path(dataset_dir, "fig_esn_quantile_repro")

fig_dir <- file.path(output_root, "figs")
tab_dir <- file.path(output_root, "tables")
mod_dir <- file.path(output_root, "models")
man_dir <- file.path(output_root, "manifest")

for (d in c(output_root, fig_dir, tab_dir, mod_dir, man_dir)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

time_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

steps <- c(
  "Validate dataset files and schema (series_long.csv, series_wide.csv, sim_output.rds, meta.txt)",
  "Confirm DGP assumptions from code (scripts/sim_suite_dlm.R, R/simulate_ts_mc_quantiles.R)",
  "Define run config (quantiles, split, model hyperparams, synthesis settings)",
  "Implement/prepare fitting pipeline (one model per quantile)",
  "Generate posterior predictive draws with dimension/orientation checks",
  "Run synthesis (exdqlm_synthesize_from_draws) with validation checks",
  "Produce comparison tables (true vs fitted vs synthesized vs observed)",
  "Produce diagnostics (coverage, rolling coverage, pinball, CRPS, calibration)",
  "Save outputs into organized dirs (figs/, tables/, models/, manifest/)",
  "Write markdown run summary and terminal final summary"
)
status <- rep("pending", length(steps))
status_log <- character(0)
tracker_file <- file.path(man_dir, "TRACKER_PROGRESS.md")

append_log <- function(msg) {
  status_log <<- c(status_log, sprintf("- [%s] %s", time_now(), msg))
}

write_tracker <- function() {
  lines <- c(
    "# Tracker Progress: dlm_constV_smallW Quantile Fit + Synthesis",
    "",
    sprintf("- repo: `%s`", repo_root),
    sprintf("- dataset_source: `%s`", dataset_dir),
    sprintf("- output_root: `%s`", output_root),
    "",
    "## Steps"
  )
  for (i in seq_along(steps)) {
    tick <- if (identical(status[i], "completed")) "x" else " "
    lines <- c(lines, sprintf("%d. [%s] status: `%s` | %s", i, tick, status[i], steps[i]))
  }
  lines <- c(lines, "", "## Status Log")
  if (length(status_log)) {
    lines <- c(lines, status_log)
  } else {
    lines <- c(lines, "- (no entries yet)")
  }
  writeLines(lines, tracker_file)
}

set_step <- function(i, st, note = NULL) {
  status[i] <<- st
  if (!is.null(note) && nzchar(note)) {
    append_log(sprintf("step %d -> %s | %s", i, st, note))
  } else {
    append_log(sprintf("step %d -> %s", i, st))
  }
  write_tracker()
}

run_step <- function(i, expr, done_note = NULL) {
  set_step(i, "in_progress")
  out <- try(eval.parent(substitute(expr)), silent = TRUE)
  if (inherits(out, "try-error")) {
    err <- conditionMessage(attr(out, "condition"))
    set_step(i, "in_progress", paste("FAILED:", err))
    stop(sprintf("Step %d failed: %s", i, err), call. = FALSE)
  }
  set_step(i, "completed", done_note)
  invisible(out)
}

write_tracker()

ctx <- new.env(parent = emptyenv())

row_quantile <- function(M, prob) {
  M <- as.matrix(M)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    as.numeric(matrixStats::rowQuantiles(M, probs = prob, na.rm = TRUE))
  } else {
    apply(M, 1L, stats::quantile, probs = prob, na.rm = TRUE)
  }
}

row_quantiles <- function(M, probs) {
  M <- as.matrix(M)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    matrixStats::rowQuantiles(M, probs = probs, na.rm = TRUE)
  } else {
    t(apply(M, 1L, stats::quantile, probs = probs, na.rm = TRUE))
  }
}

orient_draws <- function(M, T_expected, label) {
  M <- as.matrix(M)
  if (nrow(M) == T_expected) return(M)
  if (ncol(M) == T_expected) return(t(M))
  stop(sprintf("%s has shape %dx%d; cannot orient to T=%d", label, nrow(M), ncol(M), T_expected))
}

pinball_mean <- function(y, qhat, p) {
  mean((y - qhat) * (p - as.numeric(y < qhat)))
}

crps_row <- function(y, z) {
  z <- sort(z)
  m <- length(z)
  mean(abs(z - y)) - sum((2 * seq_len(m) - m - 1) * z) / (m^2)
}

crps_vec <- function(y, draws_mat) {
  stopifnot(length(y) == nrow(draws_mat))
  vapply(seq_len(nrow(draws_mat)), function(i) crps_row(y[i], draws_mat[i, ]), numeric(1))
}

rolling_mean <- function(x, k) {
  n <- length(x)
  out <- rep(NA_real_, n)
  if (k <= 1L) return(x)
  if (k > n) return(out)
  cs <- cumsum(c(0, x))
  out[k:n] <- (cs[(k + 1):(n + 1)] - cs[1:(n - k + 1)]) / k
  out
}

run_start <- time_now()

run_step(1, {
  files <- c("series_long.csv", "series_wide.csv", "sim_output.rds", "meta.txt")
  fpath <- file.path(dataset_dir, files)
  exists_vec <- file.exists(fpath)
  if (!all(exists_vec)) {
    miss <- files[!exists_vec]
    stop("Missing required input files: ", paste(miss, collapse = ", "))
  }

  long <- read.csv(file.path(dataset_dir, "series_long.csv"))
  wide <- read.csv(file.path(dataset_dir, "series_wide.csv"))
  sim <- readRDS(file.path(dataset_dir, "sim_output.rds"))
  meta <- readLines(file.path(dataset_dir, "meta.txt"), warn = FALSE)

  needed_cols <- c("t", "p", "q", "y", "mu")
  if (!all(needed_cols %in% names(long))) {
    stop("series_long.csv missing columns: ", paste(setdiff(needed_cols, names(long)), collapse = ", "))
  }

  dup_tp <- any(duplicated(long[, c("t", "p")]))
  if (dup_tp) stop("series_long.csv contains duplicate (t,p) rows")

  monotone_ok <- all(tapply(seq_len(nrow(long)), long$t, function(ix) {
    v <- long$q[ix][order(long$p[ix])]
    all(diff(v) >= -1e-10)
  }))
  if (!monotone_ok) stop("Quantiles are not monotone in p for at least one time index")

  p_grid <- sort(unique(long$p))
  if (length(p_grid) != 21L) {
    stop(sprintf("Expected 21 quantile levels in series_long.csv, found %d", length(p_grid)))
  }

  ctx$long <- long
  ctx$wide <- wide
  ctx$sim <- sim
  ctx$meta <- meta

  checks <- data.frame(
    check = c(
      "files_exist",
      "series_long_required_cols",
      "series_long_duplicate_t_p",
      "series_long_p_in_01",
      "series_long_monotone_q_by_t",
      "series_long_quantile_levels"
    ),
    value = c(
      all(exists_vec),
      all(needed_cols %in% names(long)),
      !dup_tp,
      all(long$p > 0 & long$p < 1),
      monotone_ok,
      length(p_grid) == 21L
    )
  )
  write.csv(checks, file.path(tab_dir, "data_integrity_checks.csv"), row.names = FALSE)
}, done_note = "dataset integrity checks passed")

run_step(2, {
  code_files <- c(
    file.path(repo_root, "scripts/sim_suite_dlm.R"),
    file.path(repo_root, "R/simulate_ts_mc_quantiles.R")
  )
  code_exists <- file.exists(code_files)

  params <- ctx$sim$info$params
  dgp <- data.frame(
    field = c("scenario", "seed", "R_mc", "burnin", "period", "V", "alpha", "no_trend", "state_dim", "n_quantiles"),
    observed = c(
      as.character(ctx$sim$info$scenario),
      as.character(ctx$sim$info$seed),
      as.character(ctx$sim$info$R_mc),
      as.character(ctx$sim$info$burnin),
      as.character(params$period),
      as.character(params$V),
      as.character(params$alpha),
      as.character(params$no_trend),
      as.character(length(params$m0)),
      as.character(length(ctx$sim$p))
    ),
    stringsAsFactors = FALSE
  )

  dgp$expected <- c(
    "dlm_constV_smallW", "123", "5000", "2000", "50", "9", "1e-04", "TRUE", "6", "21"
  )
  dgp$matches_expected <- dgp$observed == dgp$expected

  code_check <- data.frame(
    file = code_files,
    exists_in_branch = code_exists,
    stringsAsFactors = FALSE
  )

  write.csv(dgp, file.path(tab_dir, "dgp_assumption_checks.csv"), row.names = FALSE)
  write.csv(code_check, file.path(tab_dir, "dgp_code_file_presence.csv"), row.names = FALSE)

  ctx$dgp_code_missing <- !all(code_exists)

  if (!all(dgp$matches_expected)) {
    bad <- dgp$field[!dgp$matches_expected]
    stop("DGP checks failed for fields: ", paste(bad, collapse = ", "))
  }
}, done_note = "DGP assumptions validated from sim_output/meta; code-file presence recorded")

run_step(3, {
  cfg <- list(
    scenario = "dlm_constV_smallW",
    p_vec = c(0.05, 0.50, 0.95),
    split = list(train_end = 4000L, forecast_start = 4001L),
    model = list(
      state_dim = 6L,
      period = 50,
      FF = c(1, 0, 1, 0, 1, 0),
      m0 = rep(0, 6),
      C0_diag = rep(25, 6),
      no_trend = TRUE
    ),
    fit = list(
      method = "exdqlmLDVB",
      df = c(1, 1, 1),
      dim_df = c(2, 2, 2),
      fix_sigma = TRUE,
      sig_init = 3,
      fix_gamma = TRUE,
      gam_init = 0,
      dqlm_ind = TRUE,
      tol = 0.2,
      n_samp = 200,
      seed_base = 20260226
    ),
    synthesis = list(
      enforce_isotonic = TRUE,
      rearrange = TRUE,
      grid_M = 1001L,
      n_samp = 1000L,
      seed = 20260227L
    ),
    diagnostics = list(
      rolling_window = 200L,
      plot_last_train = 500L
    ),
    paths = list(
      repo_root = repo_root,
      dataset_dir = dataset_dir,
      output_root = output_root
    )
  )

  if (cfg$split$train_end >= nrow(ctx$wide)) {
    stop("Invalid split: train_end must be < series length")
  }

  ctx$cfg <- cfg
  write_json(cfg, path = file.path(man_dir, "run_config.json"), pretty = TRUE, auto_unbox = TRUE)
}, done_note = "run config defined and saved")

run_step(4, {
  devtools::load_all(repo_root, quiet = TRUE)
  options(
    exdqlm.use_cpp_kf = FALSE,
    exdqlm.use_cpp_samplers = FALSE,
    exdqlm.use_cpp_postpred = FALSE,
    exdqlm.use_cpp_builders = FALSE
  )

  build_model <- function(period = 50L) {
    w1 <- 2 * pi * 1 / period
    w2 <- 2 * pi * 2 / period
    G1 <- matrix(c(cos(w1), sin(w1), -sin(w1), cos(w1)), 2, 2, byrow = TRUE)
    G2 <- matrix(c(cos(w2), sin(w2), -sin(w2), cos(w2)), 2, 2, byrow = TRUE)
    GG <- as.matrix(Matrix::bdiag(diag(2), G1, G2))
    FF <- matrix(c(1, 0, 1, 0, 1, 0), ncol = 1)
    as.exdqlm(list(m0 = matrix(0, 6, 1), C0 = diag(25, 6), FF = FF, GG = GG))
  }

  y <- ctx$wide$y
  model <- build_model(period = ctx$cfg$model$period)

  fits <- vector("list", length(ctx$cfg$p_vec))
  names(fits) <- sprintf("p_%s", formatC(ctx$cfg$p_vec, format = "f", digits = 2))

  fit_summary <- data.frame(
    p = numeric(0),
    iter = integer(0),
    run_time_seconds = numeric(0),
    elbo_last = numeric(0),
    draw_rows = integer(0),
    draw_cols = integer(0)
  )

  for (i in seq_along(ctx$cfg$p_vec)) {
    p0 <- ctx$cfg$p_vec[i]
    set.seed(ctx$cfg$fit$seed_base + i)
    t0 <- Sys.time()
    fit <- exdqlmLDVB(
      y = y,
      p0 = p0,
      model = model,
      df = ctx$cfg$fit$df,
      dim.df = ctx$cfg$fit$dim_df,
      fix.gamma = ctx$cfg$fit$fix_gamma,
      gam.init = ctx$cfg$fit$gam_init,
      fix.sigma = ctx$cfg$fit$fix_sigma,
      sig.init = ctx$cfg$fit$sig_init,
      dqlm.ind = ctx$cfg$fit$dqlm_ind,
      tol = ctx$cfg$fit$tol,
      n.samp = ctx$cfg$fit$n_samp,
      verbose = FALSE
    )
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    if (is.null(fit$samp.post.pred)) {
      stop(sprintf("LDVB fit at p=%.2f did not return samp.post.pred", p0))
    }

    sp <- as.matrix(fit$samp.post.pred)
    if (!(nrow(sp) == length(y) || ncol(sp) == length(y))) {
      stop(sprintf("Posterior draws at p=%.2f have incompatible shape %dx%d", p0, nrow(sp), ncol(sp)))
    }

    fits[[i]] <- fit
    saveRDS(fit, file.path(mod_dir, sprintf("fit_ldvb_p%s.rds", gsub("\\.", "", formatC(p0, format = "f", digits = 2)))))

    fit_summary <- rbind(
      fit_summary,
      data.frame(
        p = p0,
        iter = as.integer(fit$iter),
        run_time_seconds = dt,
        elbo_last = tail(fit$diagnostics$elbo, 1),
        draw_rows = nrow(sp),
        draw_cols = ncol(sp)
      )
    )
  }

  ctx$fits <- fits
  ctx$fit_summary <- fit_summary
  write.csv(fit_summary, file.path(tab_dir, "fit_summary_ldvb.csv"), row.names = FALSE)
}, done_note = "LDVB fits completed for all configured quantiles")

run_step(5, {
  Tt <- nrow(ctx$wide)
  draws_list <- vector("list", length(ctx$fits))

  for (i in seq_along(ctx$fits)) {
    draws_i <- orient_draws(ctx$fits[[i]]$samp.post.pred, T_expected = Tt,
                            label = sprintf("fit[%d] samp.post.pred", i))
    if (!all(is.finite(draws_i))) {
      stop(sprintf("Non-finite posterior draws detected for model index %d", i))
    }
    draws_list[[i]] <- draws_i
  }

  train_idx <- seq_len(ctx$cfg$split$train_end)
  fc_idx <- (ctx$cfg$split$forecast_start):Tt

  ctx$draws_list <- draws_list
  ctx$train_idx <- train_idx
  ctx$fc_idx <- fc_idx

  dd <- do.call(rbind, lapply(seq_along(draws_list), function(i) {
    data.frame(
      model_index = i,
      p = ctx$cfg$p_vec[i],
      draw_rows = nrow(draws_list[[i]]),
      draw_cols = ncol(draws_list[[i]])
    )
  }))
  write.csv(dd, file.path(tab_dir, "draw_dimensions_models.csv"), row.names = FALSE)
}, done_note = "posterior draws validated and train/forecast slices defined")

run_step(6, {
  syn <- exdqlm_synthesize_from_draws(
    draws_list = ctx$draws_list,
    p = ctx$cfg$p_vec,
    enforce_isotonic = ctx$cfg$synthesis$enforce_isotonic,
    rearrange = ctx$cfg$synthesis$rearrange,
    grid_M = ctx$cfg$synthesis$grid_M,
    n_samp = ctx$cfg$synthesis$n_samp,
    seed = ctx$cfg$synthesis$seed,
    T_expected = nrow(ctx$wide)
  )

  syn_draws <- orient_draws(syn$draws, T_expected = nrow(ctx$wide), label = "synthesis draws")
  if (!all(is.finite(syn_draws))) stop("Synthesized draws contain non-finite values")
  if (!all(is.finite(syn$quantiles))) stop("Synthesized quantile anchors contain non-finite values")

  monotone_levels <- all(apply(syn$quantiles, 1L, function(v) all(diff(v) >= -1e-10)))
  if (!monotone_levels) stop("Synthesis anchors are not monotone for at least one time index")

  syn_checks <- data.frame(
    check = c("draws_finite", "anchors_finite", "anchors_monotone", "draw_rows_match_T"),
    value = c(TRUE, TRUE, monotone_levels, nrow(syn_draws) == nrow(ctx$wide))
  )
  write.csv(syn_checks, file.path(tab_dir, "synthesis_checks.csv"), row.names = FALSE)

  ctx$syn <- syn
  ctx$syn_draws <- syn_draws
  saveRDS(syn, file.path(mod_dir, "synthesis_full.rds"))
}, done_note = "synthesis completed and validated")

run_step(7, {
  y <- ctx$wide$y
  mu <- ctx$wide$mu
  q_cols <- grep("^q_", names(ctx$wide), value = TRUE)
  if (!length(q_cols)) stop("series_wide.csv has no q_* columns")

  p_true <- as.numeric(sub("^q_", "", q_cols)) / 100
  ord <- order(p_true)
  p_true <- p_true[ord]
  q_true <- as.matrix(ctx$wide[, q_cols[ord], drop = FALSE])

  if (!all(dim(q_true) == c(length(y), length(p_true)))) {
    stop("Unexpected true-quantile matrix dimensions")
  }

  syn_q_all <- row_quantiles(ctx$syn_draws, p_true)

  win_list <- list(train = ctx$train_idx, forecast = ctx$fc_idx)

  model_anchor_metrics <- data.frame()
  synth_metrics <- data.frame()

  for (wname in names(win_list)) {
    idx <- win_list[[wname]]
    y_w <- y[idx]

    for (i in seq_along(ctx$cfg$p_vec)) {
      p0 <- ctx$cfg$p_vec[i]
      q_model <- row_quantile(ctx$draws_list[[i]][idx, , drop = FALSE], p0)
      j <- which.min(abs(p_true - p0))
      q_true_anchor <- q_true[idx, j]

      model_anchor_metrics <- rbind(model_anchor_metrics, data.frame(
        window = wname,
        p = p0,
        coverage = mean(y_w <= q_model),
        coverage_error = mean(y_w <= q_model) - p0,
        pinball = pinball_mean(y_w, q_model, p0),
        rmse_true_q = sqrt(mean((q_model - q_true_anchor)^2)),
        stringsAsFactors = FALSE
      ))
    }

    q_syn_w <- syn_q_all[idx, , drop = FALSE]
    cover <- colMeans(sweep(q_syn_w, 1L, y_w, FUN = function(q, yy) yy <= q))
    pinb <- vapply(seq_along(p_true), function(j) pinball_mean(y_w, q_syn_w[, j], p_true[j]), numeric(1))
    rmse <- vapply(seq_along(p_true), function(j) sqrt(mean((q_syn_w[, j] - q_true[idx, j])^2)), numeric(1))

    synth_metrics <- rbind(
      synth_metrics,
      data.frame(
        window = wname,
        p = p_true,
        coverage = cover,
        coverage_error = cover - p_true,
        pinball = pinb,
        rmse_true_q = rmse,
        stringsAsFactors = FALSE
      )
    )
  }

  sel_p <- c(0.05, 0.50, 0.95)
  sel_j <- vapply(sel_p, function(p0) which.min(abs(p_true - p0)), integer(1))
  compare <- data.frame(
    t = seq_along(y),
    y = y,
    mu = mu,
    q_true_05 = q_true[, sel_j[1]],
    q_true_50 = q_true[, sel_j[2]],
    q_true_95 = q_true[, sel_j[3]],
    q_syn_05 = syn_q_all[, sel_j[1]],
    q_syn_50 = syn_q_all[, sel_j[2]],
    q_syn_95 = syn_q_all[, sel_j[3]],
    window = ifelse(seq_along(y) <= ctx$cfg$split$train_end, "train", "forecast")
  )

  for (i in seq_along(ctx$cfg$p_vec)) {
    p0 <- ctx$cfg$p_vec[i]
    nm <- gsub("\\.", "", formatC(p0, format = "f", digits = 2))
    compare[[paste0("q_model_p", nm)]] <- row_quantile(ctx$draws_list[[i]], p0)
  }

  write.csv(model_anchor_metrics, file.path(tab_dir, "comparison_model_anchor_metrics.csv"), row.names = FALSE)
  write.csv(synth_metrics, file.path(tab_dir, "comparison_synthesis_metrics_by_p.csv"), row.names = FALSE)
  write.csv(compare, file.path(tab_dir, "comparison_series_selected_quantiles.csv"), row.names = FALSE)

  ctx$p_true <- p_true
  ctx$q_true <- q_true
  ctx$syn_q_all <- syn_q_all
  ctx$compare <- compare
  ctx$model_anchor_metrics <- model_anchor_metrics
  ctx$synth_metrics <- synth_metrics
}, done_note = "comparison tables written")

run_step(8, {
  y <- ctx$wide$y
  win_list <- list(train = ctx$train_idx, forecast = ctx$fc_idx)

  crps_summary <- data.frame()
  rolling_rows <- data.frame()

  for (wname in names(win_list)) {
    idx <- win_list[[wname]]
    y_w <- y[idx]

    syn_crps <- crps_vec(y_w, ctx$syn_draws[idx, , drop = FALSE])
    crps_summary <- rbind(crps_summary, data.frame(
      window = wname,
      method = "synthesis",
      p = NA_real_,
      n = length(syn_crps),
      mean_crps = mean(syn_crps),
      sd_crps = stats::sd(syn_crps),
      median_crps = stats::median(syn_crps)
    ))

    for (i in seq_along(ctx$cfg$p_vec)) {
      p0 <- ctx$cfg$p_vec[i]
      cr <- crps_vec(y_w, ctx$draws_list[[i]][idx, , drop = FALSE])
      crps_summary <- rbind(crps_summary, data.frame(
        window = wname,
        method = "model_anchor",
        p = p0,
        n = length(cr),
        mean_crps = mean(cr),
        sd_crps = stats::sd(cr),
        median_crps = stats::median(cr)
      ))

      q_model <- row_quantile(ctx$draws_list[[i]][idx, , drop = FALSE], p0)
      ind_model <- as.numeric(y_w <= q_model)
      roll_model <- rolling_mean(ind_model, ctx$cfg$diagnostics$rolling_window)

      rolling_rows <- rbind(rolling_rows, data.frame(
        window = wname,
        method = "model_anchor",
        p = p0,
        t_local = seq_along(idx),
        t_global = idx,
        rolling_coverage = roll_model,
        rolling_coverage_error = roll_model - p0
      ))

      q_syn <- row_quantile(ctx$syn_draws[idx, , drop = FALSE], p0)
      ind_syn <- as.numeric(y_w <= q_syn)
      roll_syn <- rolling_mean(ind_syn, ctx$cfg$diagnostics$rolling_window)

      rolling_rows <- rbind(rolling_rows, data.frame(
        window = wname,
        method = "synthesis",
        p = p0,
        t_local = seq_along(idx),
        t_global = idx,
        rolling_coverage = roll_syn,
        rolling_coverage_error = roll_syn - p0
      ))
    }
  }

  write.csv(crps_summary, file.path(tab_dir, "diagnostics_crps_summary.csv"), row.names = FALSE)
  write.csv(rolling_rows, file.path(tab_dir, "diagnostics_rolling_coverage_anchor.csv"), row.names = FALSE)

  # Plots
  p_show <- c(0.05, 0.50, 0.95)
  j_show <- vapply(p_show, function(p0) which.min(abs(ctx$p_true - p0)), integer(1))

  train_tail <- tail(ctx$train_idx, ctx$cfg$diagnostics$plot_last_train)
  forecast_idx <- ctx$fc_idx

  plot_ts <- function(idx, title_txt, out_file) {
    df <- data.frame(
      t = idx,
      y = ctx$wide$y[idx],
      true_lo = ctx$q_true[idx, j_show[1]],
      true_md = ctx$q_true[idx, j_show[2]],
      true_hi = ctx$q_true[idx, j_show[3]],
      syn_lo = ctx$syn_q_all[idx, j_show[1]],
      syn_md = ctx$syn_q_all[idx, j_show[2]],
      syn_hi = ctx$syn_q_all[idx, j_show[3]]
    )

    g <- ggplot(df, aes(x = t)) +
      geom_ribbon(aes(ymin = true_lo, ymax = true_hi), fill = "steelblue", alpha = 0.15) +
      geom_ribbon(aes(ymin = syn_lo, ymax = syn_hi), fill = "darkorange", alpha = 0.18) +
      geom_line(aes(y = true_md), color = "steelblue4", linewidth = 0.7, linetype = "dashed") +
      geom_line(aes(y = syn_md), color = "darkorange4", linewidth = 0.8) +
      geom_line(aes(y = y), color = "black", linewidth = 0.45) +
      labs(
        title = title_txt,
        subtitle = "Black=y, Blue=true q(0.05/0.50/0.95), Orange=synthesized q(0.05/0.50/0.95)",
        x = "t", y = "value"
      ) +
      theme_minimal(base_size = 11)

    ggplot2::ggsave(filename = out_file, plot = g, width = 12, height = 5, dpi = 140)
  }

  plot_ts(train_tail,
          sprintf("Train window (last %d points): synthesized vs true quantiles", length(train_tail)),
          file.path(fig_dir, "train_last_window_syn_vs_true.png"))

  plot_ts(forecast_idx,
          "Forecast slice: synthesized vs true quantiles",
          file.path(fig_dir, "forecast_window_syn_vs_true.png"))

  g_cov <- ggplot(ctx$synth_metrics, aes(x = p, y = coverage, color = window)) +
    geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray45") +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.1) +
    labs(title = "Synthesis calibration by quantile level", x = "Nominal p", y = "Empirical coverage") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "calibration_synthesis_coverage_by_p.png"), g_cov, width = 8, height = 5, dpi = 140)

  g_pin <- ggplot(ctx$synth_metrics, aes(x = p, y = pinball, color = window)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 1.1) +
    labs(title = "Synthesis pinball loss by quantile level", x = "Quantile p", y = "Mean pinball loss") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "diagnostics_synthesis_pinball_by_p.png"), g_pin, width = 8, height = 5, dpi = 140)

  rr <- rolling_rows[rolling_rows$method == "synthesis", ]
  rr <- rr[!is.na(rr$rolling_coverage_error), ]
  g_roll <- ggplot(rr, aes(x = t_global, y = rolling_coverage_error, color = factor(p))) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray45") +
    geom_line(linewidth = 0.6) +
    facet_wrap(~window, scales = "free_x", ncol = 1) +
    labs(title = "Rolling coverage error (synthesis, anchor quantiles)", x = "t", y = "rolling coverage - p", color = "p") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "diagnostics_rolling_coverage_error_synthesis_anchor.png"), g_roll, width = 10, height = 6, dpi = 140)

  g_crps <- ggplot(crps_summary, aes(x = method, y = mean_crps, fill = window)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.65) +
    facet_wrap(~ifelse(is.na(p), "synthesis", sprintf("model p=%.2f", p)), scales = "free_x") +
    labs(title = "Mean CRPS summary", x = "", y = "Mean CRPS") +
    theme_minimal(base_size = 11)
  ggsave(file.path(fig_dir, "diagnostics_crps_mean_summary.png"), g_crps, width = 11, height = 5.5, dpi = 140)

  ctx$crps_summary <- crps_summary
  ctx$rolling_rows <- rolling_rows
}, done_note = "diagnostic tables and plots generated")

run_step(9, {
  git_sha <- tryCatch(
    system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE),
    error = function(e) NA_character_
  )
  if (length(git_sha) == 0L) git_sha <- NA_character_

  manifest <- list(
    run_start = run_start,
    run_end = time_now(),
    git_sha = git_sha,
    repo_root = repo_root,
    dataset_dir = dataset_dir,
    output_root = output_root,
    dgp_code_files_present = !isTRUE(ctx$dgp_code_missing),
    n_time = nrow(ctx$wide),
    p_fit = ctx$cfg$p_vec,
    p_eval_count = length(ctx$p_true),
    train_size = length(ctx$train_idx),
    forecast_size = length(ctx$fc_idx),
    model_files = list.files(mod_dir, full.names = FALSE),
    table_files = list.files(tab_dir, full.names = FALSE),
    fig_files = list.files(fig_dir, full.names = FALSE)
  )

  write_json(manifest, path = file.path(man_dir, "run_manifest.json"), pretty = TRUE, auto_unbox = TRUE)

  saveRDS(
    list(
      config = ctx$cfg,
      fit_summary = ctx$fit_summary,
      model_anchor_metrics = ctx$model_anchor_metrics,
      synth_metrics = ctx$synth_metrics,
      crps_summary = ctx$crps_summary
    ),
    file = file.path(mod_dir, "run_objects_lightweight.rds")
  )
}, done_note = "manifest and model metadata artifacts saved")

run_step(10, {
  syn_train <- subset(ctx$synth_metrics, window == "train")
  syn_fc <- subset(ctx$synth_metrics, window == "forecast")

  mae_cov_train <- mean(abs(syn_train$coverage_error))
  mae_cov_fc <- mean(abs(syn_fc$coverage_error))
  rmse_train_mean <- mean(syn_train$rmse_true_q)
  rmse_fc_mean <- mean(syn_fc$rmse_true_q)

  crps_syn <- subset(ctx$crps_summary, method == "synthesis")
  crps_mod <- subset(ctx$crps_summary, method == "model_anchor")

  summary_lines <- c(
    "# Run Summary: dlm_constV_smallW (LDVB + synthesis)",
    "",
    sprintf("- run_start: %s", run_start),
    sprintf("- run_end: %s", time_now()),
    sprintf("- output_root: `%s`", output_root),
    sprintf("- method: `%s`", ctx$cfg$fit$method),
    sprintf("- p_fit: %s", paste(ctx$cfg$p_vec, collapse = ", ")),
    sprintf("- split: train=1:%d, forecast=%d:%d", ctx$cfg$split$train_end, ctx$cfg$split$forecast_start, nrow(ctx$wide)),
    "",
    "## Key checks",
    sprintf("- synthesis anchors monotone: %s", all(apply(ctx$syn$quantiles, 1L, function(v) all(diff(v) >= -1e-10)))),
    sprintf("- synthesized draws finite: %s", all(is.finite(ctx$syn_draws))),
    sprintf("- DGP code files present in this branch: %s", !isTRUE(ctx$dgp_code_missing)),
    "",
    "## Key metrics",
    sprintf("- synthesis mean |coverage error| (train): %.4f", mae_cov_train),
    sprintf("- synthesis mean |coverage error| (forecast): %.4f", mae_cov_fc),
    sprintf("- synthesis mean RMSE vs true quantiles (train): %.4f", rmse_train_mean),
    sprintf("- synthesis mean RMSE vs true quantiles (forecast): %.4f", rmse_fc_mean),
    sprintf("- synthesis mean CRPS (train): %.4f", crps_syn$mean_crps[crps_syn$window == "train"]),
    sprintf("- synthesis mean CRPS (forecast): %.4f", crps_syn$mean_crps[crps_syn$window == "forecast"]),
    sprintf("- best anchor-model mean CRPS (train): %.4f", min(crps_mod$mean_crps[crps_mod$window == "train"])),
    sprintf("- best anchor-model mean CRPS (forecast): %.4f", min(crps_mod$mean_crps[crps_mod$window == "forecast"])),
    "",
    "## Notes / limitations",
    "- Train/forecast diagnostics are reported on fixed index slices (1:4000 vs 4001:5000) from the same LDVB-fit draw matrices.",
    "- In this branch, `scripts/sim_suite_dlm.R` and `R/simulate_ts_mc_quantiles.R` are not present; DGP confirmation used `sim_output.rds` + `meta.txt`.",
    "",
    "## Artifacts",
    "- tables/: integrity checks, fit summaries, comparison metrics, diagnostics",
    "- figs/: train/forecast quantile comparison and calibration diagnostics",
    "- models/: per-quantile LDVB fits and synthesis objects",
    "- manifest/: tracker progress, config, and run manifest"
  )

  writeLines(summary_lines, file.path(output_root, "RUN_SUMMARY.md"))

  cat("\n=== FINAL SUMMARY ===\n")
  cat(paste(summary_lines, collapse = "\n"), "\n")
}, done_note = "run summary written and terminal summary emitted")
