#' Distribution-first model selection for Q-DESN (shared spec across quantiles)
#'
#' For each candidate *shared* specification, fit Q-DESN readouts at
#' \code{p_vec} (default \eqn{\{0.05, 0.50, 0.95\}}), synthesize a single predictive
#' distribution (isotonic + optional rearrangement), and select the spec with the
#' lowest CRPS (approximated via averaged pinball loss on the empirical quantile
#' grid extracted from synthesized draws).
#'
#' @param y Numeric vector, response (USGS).
#' @param ppt Numeric vector, precipitation covariate (same length as \code{y}).
#' @param soil Numeric vector, soil covariate (same length as \code{y}).
#' @param stage Character, either \code{"coarse"} (fast) or \code{"final"} (thorough).
#' @param p_vec Numeric vector of quantiles to fit jointly. Default: \code{c(0.05, 0.50, 0.95)}.
#' @param seed_vec Integer vector of reservoir seeds to average across (reduces variance).
#'   Default: \code{c(42L, 101L)}.
#' @param parallel Logical, use base parallel (PSOCK) across candidate specs. Default: \code{FALSE}.
#' @param n_workers Integer, number of workers if \code{parallel=TRUE}. Default: \code{max(1, parallel::detectCores()-1)}.
#' @param keep_artifacts Logical, keep exemplar fit objects/draws for the winner. Default: \code{TRUE}.
#' @param plot Logical, make quick ggplot diagnostics for winner (requires \pkg{ggplot2}). Default: \code{FALSE}.
#'
#' @return A list with elements:
#' \itemize{
#'   \item \code{leaderboard}: data.frame with CRPS and diagnostics per spec.
#'   \item \code{winner}: key string for the best spec.
#'   \item \code{winner_bundle}: list with winner details (fits/synth on scoring window)
#'         when \code{keep_artifacts=TRUE}; otherwise minimal.
#' }
#'
#' @details
#' This function uses internal helpers only and **does not** attach or install any packages.
#' It relies on objects in this package namespace: \code{qdesn_fit_vb()},
#' \code{posterior_predict.qdesn_fit()}, \code{exal_static_LDVB()},
#' and \code{exdqlm_synthesize_from_draws()}.
#'
#' @export
model_selection_distribution_first <- function(
  y, ppt, soil,
  stage = c("coarse", "final"),
  p_vec = c(0.05, 0.50, 0.95),
  seed_vec = c(42L, 101L),
  parallel = FALSE,
  n_workers = max(1L, parallel::detectCores() - 1L),
  keep_artifacts = TRUE,
  plot = FALSE
) {
  stage <- match.arg(stage)

  stopifnot(is.numeric(y), is.numeric(ppt), is.numeric(soil))
  if (!all(length(y) == c(length(ppt), length(soil))))
    stop("y, ppt, soil must have the same length.")

  T_full <- length(y)

  ## ---- Config derived from stage ----
  vb_args <- list(
    max_iter   = if (stage == "coarse")  800 else 1800,
    tol        = 1e-4,
    n_samp_xi  = if (stage == "coarse")  300 else 1000,
    verbose    = FALSE
  )
  nd_draws       <- if (stage == "coarse")  600L else 2000L
  chunk_sz       <- 200L
  synth_grid_M   <- if (stage == "coarse")  401L else 1001L
  synth_nsamp    <- if (stage == "coarse")  800L else 2000L
  synth_isotonic <- TRUE
  synth_rearrange<- if (stage == "coarse") FALSE else TRUE
  synth_seed     <- 999L
  score_last_N   <- if (stage == "coarse") 800L else 1500L

  ## ---- Helpers (local, no deps) ----
  lag_mat <- function(x, L) {
    T <- length(x); L <- as.integer(L)
    if (L <= 0) return(matrix(numeric(0), nrow = T, ncol = 0))
    M <- matrix(0, nrow = T, ncol = L)
    for (j in 1:L) M[(j+1):T, j] <- x[1:(T - j)]
    colnames(M) <- paste0(deparse(substitute(x)), "_l", 1:L)
    M
  }
  mu_band <- function(X, qbeta, level = 0.95) {
    m <- as.numeric(qbeta$m); V <- as.matrix(qbeta$V)
    mu <- as.numeric(X %*% m)
    XV <- X %*% V
    var <- rowSums(XV * X); se <- sqrt(pmax(var, 0))
    z <- stats::qnorm(0.5 + level/2)
    list(mu = mu, lo = mu - z*se, hi = mu + z*se)
  }
  slice_last <- function(x, N) {
    n <- length(x); i1 <- max(1L, n - as.integer(N) + 1L)
    x[i1:n]
  }
  slice_last_rows <- function(M, N) {
    nr <- nrow(M); i1 <- max(1L, nr - as.integer(N) + 1L)
    M[i1:nr, , drop = FALSE]
  }
  crps_from_draws_1 <- function(y_true, draws_vec) {
    x <- sort(as.numeric(draws_vec))
    N <- length(x); if (N < 5) return(NA_real_)
    tau <- (seq_len(N)) / (N + 1)
    res <- y_true - x
    rho <- (tau - as.numeric(res < 0)) * res
    (2 / N) * sum(rho)
  }
  crps_from_draws_window <- function(draws, y_vec, last_N) {
    stopifnot(nrow(draws) == length(y_vec))
    Dsub <- slice_last_rows(draws, last_N)
    ysub <- slice_last(y_vec, last_N)
    vapply(seq_len(nrow(Dsub)), function(i) crps_from_draws_1(ysub[i], Dsub[i, ]), 1.0)
  }
  rho_pattern <- function(D, kind = c("flat","decay")) {
    kind <- match.arg(kind)
    if (kind == "flat")  rep(0.90, D) else head(c(0.95, 0.90, 0.85), D)
  }
  make_n_tilde <- function(n, ratio = 0.2) {
    if (length(n) <= 1) integer(0) else pmax(1L, as.integer(round(head(n, -1) * ratio)))
  }
  spec_key <- function(row) {
    paste0(
      "D", row$D,
      "_n", paste0(row$n, collapse = "-"),
      "_r", row$rho_kind,
      "_a", sprintf("%.2f", row$alpha),
      "_m", row$m,
      "_w", row$washout,
      "_f", row$act_f,
      "_b", as.integer(row$add_bias),
      "_lp", row$lags_ppt,
      "_ls", row$lags_soil
    )
  }

  ## ---- Candidate grid (shared spec across quantiles) ----
  D_vals     <- c(2L, 3L)
  n_packs    <- list(c(200L,100L),
                     c(300L,150L),
                     c(300L,150L,80L),
                     c(400L,200L,100L))
  red_ratios <- c(0.20, 0.30)
  alpha_vals <- c(0.20, 0.25, 0.30)
  rho_kinds  <- c("flat","decay")
  act_f_vals <- c("tanh","relu")
  m_vals     <- c(12L, 24L, 36L)
  wash_vals  <- c(200L)
  bias_vals  <- c(FALSE, TRUE)
  lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L), c(14L,14L))

  specs_list <- vector("list", 0L)
  for (D in D_vals) {
    for (n in n_packs) {
      if (length(n) != D) next
      for (rr in red_ratios) {
        n_tilde <- make_n_tilde(n, rr)
        for (alpha in alpha_vals) {
          for (rk in rho_kinds) {
            rho <- rho_pattern(D, rk)
            for (af in act_f_vals) {
              for (m in m_vals) for (wo in wash_vals) for (ab in bias_vals) {
                for (lp in lags_pairs) {
                  if (af == "relu" && alpha < 0.20) next
                  specs_list[[length(specs_list)+1L]] <- list(
                    D = D, n = as.integer(n), n_tilde = as.integer(n_tilde),
                    alpha = alpha, rho = as.numeric(rho), act_f = af, act_k = "identity",
                    m = as.integer(m), washout = as.integer(wo), add_bias = isTRUE(ab),
                    lags_ppt = as.integer(lp[1]), lags_soil = as.integer(lp[2]),
                    red_ratio = rr, rho_kind = rk
                  )
                }
              }
            }
          }
        }
      }
    }
  }
  # de-duplicate
  key_vec <- vapply(specs_list, function(s) paste(unlist(s), collapse="|"), "")
  keep    <- !duplicated(key_vec)
  specs_list <- specs_list[keep]
  n_specs    <- length(specs_list)

  ## ---- Core worker: fit one spec for one seed ----
  fit_spec_once <- function(spec, seed) {
    t0 <- proc.time()[3]

    # unpack
    D <- spec$D; n <- spec$n; n_tilde <- spec$n_tilde
    alpha <- spec$alpha; rho <- spec$rho
    act_f <- spec$act_f; act_k <- spec$act_k
    m <- spec$m; washout <- spec$washout
    add_bias <- isTRUE(spec$add_bias)
    lags_ppt <- spec$lags_ppt; lags_soil <- spec$lags_soil

    # fixed sparsity
    pi_w <- 0.05; pi_in <- 0.20

    desn_args <- list(
      D=D, n=n, n_tilde=n_tilde,
      m=m, alpha=alpha, rho=rho,
      act_f=act_f, act_k=act_k,
      pi_w=pi_w, pi_in=pi_in,
      washout=washout, add_bias=add_bias,
      seed=seed
    )

    # exogenous lags (full length)
    X_ppt  <- lag_mat(ppt,  lags_ppt)
    X_soil <- lag_mat(soil, lags_soil)
    X_cov_full <- cbind(X_ppt, X_soil)
    maxlag_cov <- max(lags_ppt, lags_soil)

    # fit a single quantile (append exogenous lags in readout)
    fit_q <- function(p0) {
      fit0 <- do.call(qdesn_fit_vb, c(list(y=y, p0=p0, vb_args=vb_args), desn_args))
      keep_idx <- fit0$meta$keep_idx
      y_fit    <- fit0$y_fit
      X_res    <- fit0$X

      # ensure covariate lags exist
      trim_n <- sum(keep_idx <= maxlag_cov)
      if (trim_n > 0) {
        keep_idx <- keep_idx[-seq_len(trim_n)]
        y_fit    <- y_fit[-seq_len(trim_n)]
        X_res    <- X_res[-seq_len(trim_n), , drop=FALSE]
      }
      X_cov <- if (ncol(X_cov_full)) X_cov_full[keep_idx, , drop=FALSE] else
        matrix(numeric(0), nrow=length(keep_idx), ncol=0)
      X_aug <- cbind(X_res, X_cov)

      fit_readout <- exal_static_LDVB(
        y=y_fit, X=X_aug, p0=p0,
        max_iter=vb_args$max_iter, tol=vb_args$tol,
        b0=rep(0, ncol(X_aug)),
        V0=diag(1e4, ncol(X_aug)),
        a_sigma=1, b_sigma=1,
        n_samp_xi=vb_args$n_samp_xi,
        verbose=FALSE
      )

      mb <- mu_band(X_aug, fit_readout$qbeta, level=0.95)
      df_mu <- data.frame(
        t_aligned = seq_len(nrow(X_aug)),
        y  = y_fit,
        mu = mb$mu, lo = mb$lo, hi = mb$hi,
        p0 = p0
      )

      fit_exog <- list(
        fit = fit_readout,
        X = X_aug, y_fit = y_fit, mu_hat = mb$mu,
        reservoir = fit0$reservoir, states = fit0$states,
        meta = list(
          keep_idx=keep_idx,
          drop=max(m, washout, maxlag_cov),
          T=T_full, p0=p0, D=D, n=n, n_tilde=n_tilde,
          m=m, alpha=alpha, rho=rho, add_bias=add_bias
        )
      )
      class(fit_exog) <- "qdesn_fit"
      list(fit=fit_exog, df_mu=df_mu)
    }

    # fit all quantiles sequentially
    fits <- lapply(p_vec, fit_q); names(fits) <- paste0("p=", p_vec)

    # common trailing alignment length
    T_common <- min(vapply(fits, function(o) nrow(o$df_mu), 1L))
    fits <- lapply(fits, function(o) { o$df_mu <- utils::tail(o$df_mu, T_common); o })
    y_aligned <- fits[[1]]$df_mu$y

    # guard: identical trailing keep_idx across p
    ki_mat <- do.call(cbind, lapply(fits, function(o) utils::tail(o$fit$meta$keep_idx, T_common)))
    if (!all(apply(ki_mat, 1, function(r) length(unique(r))==1)))
      stop("keep_idx alignment mismatch across p.")

    # posterior predictive draws per model
    pp_draws <- lapply(fits, function(x)
      posterior_predict.qdesn_fit(x$fit, nd=nd_draws, chunk=chunk_sz)$yrep
    )
    pp_draws <- lapply(pp_draws, function(M) utils::tail(M, T_common))

    # slice BEFORE synthesis to last score_last_N points
    lastN <- min(T_common, score_last_N)
    idx_tail <- (T_common - lastN + 1L):T_common
    pp_draws <- lapply(pp_draws, function(M) M[idx_tail, , drop=FALSE])
    y_aligned <- y_aligned[idx_tail]
    T_common  <- nrow(pp_draws[[1]])

    # synthesis on sliced window
    synth <- exdqlm_synthesize_from_draws(
      draws_list = pp_draws,
      p          = p_vec,
      enforce_isotonic = synth_isotonic,
      rearrange        = synth_rearrange,
      grid_M           = synth_grid_M,
      n_samp           = synth_nsamp,
      seed             = synth_seed,
      T_expected       = T_common
    )

    crps_vec  <- crps_from_draws_window(synth$draws, y_aligned, last_N = T_common)
    mean_crps <- mean(crps_vec, na.rm = TRUE)

    coverage <- do.call(rbind, lapply(seq_along(p_vec), function(k) {
      d <- utils::tail(fits[[k]]$df_mu, T_common)
      data.frame(
        p0 = p_vec[k],
        cov = mean(d$y <= d$mu, na.rm=TRUE),
        avg_bw = stats::median(d$hi - d$lo, na.rm=TRUE)
      )
    }))

    pit <- rowMeans(synth$draws <= y_aligned)
    pit_mean <- mean(pit); pit_var <- stats::var(pit)
    pit_dev_mean <- pit_mean - 0.5; pit_dev_var <- pit_var - (1/12)

    elapsed_sec <- as.numeric(proc.time()[3] - t0)

    list(
      mean_crps = mean_crps,
      crps = crps_vec,
      y_aligned = y_aligned,
      synth = if (keep_artifacts) synth else NULL,
      fits = if (keep_artifacts) fits else NULL,
      T_common = T_common,
      coverage = coverage,
      pit = list(mean = pit_mean, var = pit_var,
                 dev_mean = pit_dev_mean, dev_var = pit_dev_var),
      elapsed_sec = elapsed_sec,
      complexity = list(sum_n = sum(n), D = D, lags_tot = lags_ppt + lags_soil)
    )
  }

  ## ---- Map over candidate specs (seeds averaged inside) ----
  run_one_spec <- function(i) {
    row <- specs_list[[i]]
    key <- spec_key(row)
    seed_runs <- lapply(seed_vec, function(sd) fit_spec_once(row, seed = sd))

    crps_means <- vapply(seed_runs, function(x) x$mean_crps, 1.0)
    mean_crps  <- mean(crps_means, na.rm = TRUE)
    se_crps    <- stats::sd(crps_means, na.rm = TRUE) / sqrt(length(seed_runs))

    cov_tbl <- do.call(rbind, lapply(seed_runs, function(z) z$coverage))
    # average by p0
    cov_out <- do.call(rbind, lapply(split(cov_tbl, cov_tbl$p0), function(df) {
      data.frame(p0 = df$p0[1],
                 cov = mean(df$cov, na.rm=TRUE),
                 avg_bw = stats::median(df$avg_bw, na.rm=TRUE))
    }))
    # ensure order p0 ascending
    cov_out <- cov_out[order(cov_out$p0), , drop = FALSE]

    pit_tbl <- do.call(rbind, lapply(seed_runs, function(z)
      data.frame(mean = z$pit$mean, var = z$pit$var,
                 dev_mean = z$pit$dev_mean, dev_var = z$pit$dev_var)))
    pit_avg <- colMeans(pit_tbl, na.rm = TRUE)

    elapsed_sec <- sum(vapply(seed_runs, function(x) x$elapsed_sec, 1.0), na.rm = TRUE)

    list(
      spec_idx = i, spec_key = key, spec_row = row,
      mean_crps = mean_crps, se_crps = se_crps,
      cov_tbl = cov_out,
      pit = as.list(pit_avg),
      exemplar = if (keep_artifacts) seed_runs[[1]] else NULL,
      elapsed_sec = elapsed_sec,
      complexity = list(sum_n = sum(row$n), D = row$D,
                        lags_tot = row$lags_tot <- row$lags_ppt + row$lags_soil)
    )
  }

  if (!parallel) {
    results <- lapply(seq_len(n_specs), run_one_spec)
  } else {
    cl <- parallel::makePSOCKcluster(n_workers)
    on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
    results <- parallel::parLapply(cl, seq_len(n_specs), function(i) {
      # re-create needed objects in worker
      environment() # no-op; closures capture needed vars
      run_one_spec(i)
    })
  }

  ## ---- Leaderboard & winner ----
  leaderboard <- do.call(rbind, lapply(results, function(r) {
    # extract coverage by p
    cov05 <- r$cov_tbl$cov[r$cov_tbl$p0 == 0.05]
    cov50 <- r$cov_tbl$cov[r$cov_tbl$p0 == 0.50]
    cov95 <- r$cov_tbl$cov[r$cov_tbl$p0 == 0.95]
    bwmed <- r$cov_tbl$avg_bw[r$cov_tbl$p0 == 0.50]
    data.frame(
      spec_idx = r$spec_idx,
      spec_key = r$spec_key,
      mean_CRPS = r$mean_crps,
      se_CRPS   = r$se_crps,
      cov_05    = ifelse(length(cov05), cov05, NA_real_),
      cov_50    = ifelse(length(cov50), cov50, NA_real_),
      cov_95    = ifelse(length(cov95), cov95, NA_real_),
      bw_med    = ifelse(length(bwmed), bwmed, NA_real_),
      pit_mean  = r$pit$mean,
      pit_var   = r$pit$var,
      elapsed_s = r$elapsed_sec,
      sum_n     = r$complexity$sum_n,
      D         = r$complexity$D,
      lags_tot  = r$complexity$lags_tot,
      stringsAsFactors = FALSE
    )
  }))
  # keep finite CRPS, then order
  leaderboard <- leaderboard[is.finite(leaderboard$mean_CRPS), , drop = FALSE]
  o <- order(leaderboard$mean_CRPS, leaderboard$sum_n, leaderboard$D, leaderboard$lags_tot)
  leaderboard <- leaderboard[o, , drop = FALSE]

  best_row <- leaderboard[1, , drop = FALSE]
  best     <- results[[ best_row$spec_idx ]]

  # Optional quick plots for winner (if requested & ggplot2 present)
  if (isTRUE(plot) && isTRUE(keep_artifacts)) {
    if (requireNamespace("ggplot2", quietly = TRUE)) {
      T_win <- best$exemplar$T_common
      showN <- min(300L, T_win)

      mu_long <- do.call(rbind, lapply(seq_along(p_vec), function(k) {
        d <- best$exemplar$fits[[k]]$df_mu
        d$t_aligned <- seq_len(nrow(d))
        d$p_chr <- as.character(p_vec[k])
        utils::tail(d, showN)
      }))

      col_line <- c("0.05"="#8B0000","0.50"="#006400","0.95"="#0F2E6E")
      gg <- ggplot2::ggplot(mu_long, ggplot2::aes(x=t_aligned)) +
        ggplot2::theme_minimal(13) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin=lo,ymax=hi,fill=p_chr), alpha=0.25, colour=NA) +
        ggplot2::geom_line(ggplot2::aes(y=mu,colour=p_chr), linewidth=0.9) +
        ggplot2::geom_line(ggplot2::aes(y=y, group=1), colour="#222222", alpha=0.6, linewidth=0.7) +
        ggplot2::scale_color_manual(values=col_line, name="quantile p") +
        ggplot2::scale_fill_manual(values=vapply(col_line, function(z) grDevices::adjustcolor(z, alpha.f=0.25), "")) +
        ggplot2::labs(title=paste0("Winner: mu-hat (95% bands) — last ", showN, " points"),
                      x="time (aligned)", y="USGS")
      print(gg)

      draws <- best$exemplar$synth$draws
      yA    <- best$exemplar$y_aligned
      q_mat <- t(apply(utils::tail(draws, showN), 1, stats::quantile, probs=c(0.025,0.50,0.975)))
      dfB <- data.frame(
        t_aligned = (T_win - showN + 1L):T_win,
        y  = utils::tail(yA, showN),
        q05 = q_mat[,1], q50 = q_mat[,2], q95 = q_mat[,3]
      )
      gb <- ggplot2::ggplot(dfB, ggplot2::aes(x=t_aligned)) +
        ggplot2::theme_minimal(13) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin=q05, ymax=q95),
                             fill=grDevices::adjustcolor("#3B82F6", alpha.f=0.22)) +
        ggplot2::geom_line(ggplot2::aes(y=q50), colour="#3B82F6") +
        ggplot2::geom_line(ggplot2::aes(y=y), colour="#111111", linewidth=0.8) +
        ggplot2::labs(title=paste0("Winner: observed y with synthesized 95% band — last ", showN, " points"),
                      x="time (aligned)", y="USGS")
      print(gb)
    } else {
      message("plot=TRUE requested but ggplot2 not available; skipping plots.")
    }
  }

  winner_bundle <- list(
    stage     = stage,
    spec_key  = best$spec_key,
    spec      = best$spec_row,
    leaderboard = leaderboard,
    y_aligned = if (keep_artifacts) best$exemplar$y_aligned else NULL,
    fits      = if (keep_artifacts) best$exemplar$fits else NULL,
    synth     = if (keep_artifacts) best$exemplar$synth else NULL,
    coverage  = if (keep_artifacts) best$exemplar$coverage else NULL,
    pit       = best$pit,
    T_window  = if (keep_artifacts) best$exemplar$T_common else NULL,
    config    = list(
      p_vec = p_vec,
      vb_args = vb_args,
      nd_draws = nd_draws,
      synth = list(grid_M = synth_grid_M, nsamp = synth_nsamp,
                   isotonic = synth_isotonic, rearrange = synth_rearrange, seed = synth_seed),
      scoring = list(last_N = score_last_N, seed_vec = seed_vec)
    )
  )

  list(
    leaderboard   = leaderboard,
    winner        = best$spec_key,
    winner_bundle = winner_bundle
  )
}
