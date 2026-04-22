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
#' @param seed_vec Integer vector of reservoir seeds to average across (reduces variance). Default: \code{c(42L, 101L)}.
#' @param parallel Logical, use base parallel (PSOCK) across candidate specs. Default: \code{FALSE}.
#' @param n_workers Integer, number of workers if \code{parallel=TRUE}. Default: \code{max(1, parallel::detectCores()-1)}.
#' @param keep_artifacts Logical, keep exemplar fit objects/draws for the winner. Default: \code{TRUE}.
#' @param plot Logical, make quick ggplot diagnostics for winner (requires \pkg{ggplot2}). Default: \code{FALSE}.
#' @param progress_console Logical, print progress to console. Default: \code{FALSE}.
#' @param progress_log Optional path to a logfile to append progress lines. Default: \code{NULL}.
#' @param progress_every Integer, how often to log in non-parallel mode (by spec index). Default: \code{1L}.
#' @param grid_preset Character, one of \code{"default"}, \code{"small"}, \code{"tiny"}, \code{"micro"} for built-in grids. Default: \code{"default"}.
#' @param max_specs Integer, optional cap to randomly sample at most this many specs from the grid. Default: \code{Inf}.
#' @param grid_seed Integer RNG seed used when subsampling the grid. Default: \code{123L}.
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
#' \code{posterior_predict.qdesn_fit()}, \code{exalStaticLDVB()},
#' and \code{quantileSynthesis()}.
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
  plot = FALSE,
  progress_console = FALSE,
  progress_log = NULL,
  progress_every = 1L,
  grid_preset = c("default","small","tiny","micro"),
  max_specs = Inf,
  grid_seed = 123L
) {
  stage <- match.arg(stage)
  grid_preset <- match.arg(grid_preset)

  stopifnot(is.numeric(y), is.numeric(ppt), is.numeric(soil))
  if (!all(length(y) == c(length(ppt), length(soil))))
    stop("y, ppt, soil must have the same length.")

  T_full <- length(y)

  ## ---- Config derived from stage ----
  vb_args <- list(
    max_iter   = if (stage == "coarse")  900 else 2000,
    tol        = 1e-4,
    n_samp_xi  = if (stage == "coarse")  400 else 1200,
    verbose    = FALSE
  )
  # Increase posterior/synthesis sampling and grid resolution
  nd_draws       <- if (stage == "coarse") 1000L else 4000L
  chunk_sz       <- 256L
  synth_grid_M   <- if (stage == "coarse")  801L else 2001L
  synth_nsamp    <- if (stage == "coarse") 2500L else 8000L
  synth_isotonic <- TRUE
  synth_rearrange<- if (stage == "coarse") FALSE else TRUE
  synth_seed     <- 999L
  score_last_N   <- if (stage == "coarse") 800L else 1500L


  ## ---- Progress helper ----
  progress_every <- as.integer(progress_every)
  log_line <- function(txt) {
    stamp <- format(Sys.time(), "%F %T")
    line <- paste0("[", stamp, "] ", txt, "\n")
    if (isTRUE(progress_console)) cat(line)
    if (!is.null(progress_log)) {
      cat(line, file = progress_log, append = TRUE)
    }
    invisible(NULL)
  }

  ## ---- Fail-safe result builder (so errors don't kill the run) ----
  fail_result <- function(i, row, reason = "") {
    key <- try(spec_key(row), silent = TRUE)
    if (inherits(key, "try-error")) key <- paste0("idx", i)
    list(
      spec_idx = i, spec_key = key, spec_row = row,
      mean_crps = Inf, se_crps = NA_real_,
      cov_tbl = data.frame(p0 = p_vec, cov = NA_real_, avg_bw = NA_real_),
      pit = list(mean = NA_real_, var = NA_real_, dev_mean = NA_real_, dev_var = NA_real_),
      exemplar = NULL, elapsed_sec = NA_real_,
      complexity = list(sum_n = sum(row$n), D = row$D,
                        lags_tot = row$lags_ppt + row$lags_soil),
      error_reason = reason
    )
  }

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
    m <- as.numeric(qbeta$m)
    V <- as.matrix(qbeta$V)
    V <- 0.5 * (V + t(V))           # symmetrize
    diag(V) <- pmax(diag(V), 1e-10) # jitter
    mu <- as.numeric(X %*% m)
    XV <- X %*% V
    var <- rowSums(XV * X)
    se  <- sqrt(pmax(var, 1e-12))   # avoid 0
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
  # target fan-out ≈ 10; cap sparsity to [0.02, 0.2] to avoid extremes on tiny/huge n
  pi_w_from_fanout <- function(n_vec, target = 10) {
    p <- target / median(as.numeric(n_vec))
    p <- max(min(p, 0.20), 0.02)
    as.numeric(p)
  }
  # input matrix denser than W
  default_pi_in <- function() 0.60

  spec_key <- function(row) {
    paste0(
      "D", row$D,
      "_n", paste0(row$n, collapse = "-"),
      "_r", row$rho_kind,
      "_rs", sprintf("%.2f", if (!is.null(row$rho_scale)) row$rho_scale else 1),
      "_a", sprintf("%.2f", row$alpha),
      "_m", row$m,
      "_w", row$washout,
      "_f", row$act_f,
      "_b", as.integer(row$add_bias),
      "_lp", row$lags_ppt,
      "_ls", row$lags_soil,
      "_std", as.integer(isTRUE(row$standardize_inputs)),
      "_ib", substr(row$input_bound, 1, 1),
      "_sg", sprintf("%.2f", row$win_scale_global),
      "_sb", sprintf("%.2f", row$win_scale_bias)
    )
  }

  ## ---- Candidate grid (shared spec across quantiles) ----
  # Goal: D <= 3, but *default* exploration focuses on D=1 and a few D=2.
  # Reservoir sizes in 100..500 as requested; reducers only used for D>1.
  D_vals     <- c(1L, 2L)  # default: mostly D=1, with a bit of D=2
  n_packs    <- list(
    # D=1 (main focus)
    c(100L), c(200L), c(300L), c(400L), c(500L),
    # D=2 (light exploration)
    c(200L,100L), c(300L,150L), c(400L,200L)
    # (You can always add c(500L,250L) later if needed)
  )
  red_ratios <- c(0.20, 0.30)  # reducer ratios for D>1
  # Leaking rates — cover fast & slower memory; keep scalar for now
  alpha_vals <- c(0.20, 0.30, 0.50)
  rho_kinds  <- c("flat","decay")
  act_f_vals <- c("tanh","relu")
  m_vals     <- c(12L, 24L, 36L)
  wash_vals  <- c(200L)
  bias_vals  <- c(FALSE, TRUE)
  lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L), c(14L,14L))

  # Input preprocessing knobs (guided by the doc)
  standardize_vals   <- c(TRUE)
  input_bound_vals   <- c("tanh")
  win_scale_global_v <- c(0.5, 1.0, 2.0)  # co-tune with rho scale
  win_scale_bias_v   <- c(0.2, 0.5)

  # Spectral co-tuning — modest range keeps ESP & avoids saturation
  rho_scale_vals     <- c(0.8, 1.0)

  # Presets to shrink/shape exploration quickly
  if (grid_preset == "small") {
    D_vals   <- c(1L, 2L)
    n_packs  <- list(
      c(200L), c(300L), c(400L),           # D=1
      c(300L,150L)                          # D=2 (one popular baseline)
    )
    red_ratios <- c(0.30)
    alpha_vals <- c(0.20, 0.30)
    rho_kinds  <- c("flat","decay")
    act_f_vals <- c("tanh")
    m_vals     <- c(12L, 24L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L))
    standardize_vals   <- c(TRUE)
    input_bound_vals   <- c("tanh")
    win_scale_global_v <- c(0.5, 1.0)
    win_scale_bias_v   <- c(0.2)
    rho_scale_vals     <- c(0.8, 1.0)
  } else if (grid_preset == "tiny") {
    # Minimal smoke test: D=1 only
    D_vals   <- c(1L)
    n_packs  <- list(c(200L), c(300L), c(400L))
    red_ratios <- c(0.30)
    alpha_vals <- c(0.30)
    rho_kinds  <- c("flat")
    act_f_vals <- c("tanh")
    m_vals     <- c(24L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(0L,0L), c(3L,3L))
    standardize_vals   <- c(TRUE)
    input_bound_vals   <- c("tanh")
    win_scale_global_v <- c(1.0)
    win_scale_bias_v   <- c(0.2)
    rho_scale_vals     <- c(1.0)
  } else if (grid_preset == "micro") {
    # Micro sanity run: primarily D=1; include a *couple* D=2 baselines.
    D_vals   <- c(1L, 2L)
    n_packs  <- list(
      # D=1
      c(200L), c(300L), c(400L), c(500L),
      # D=2 (very light)
      c(300L,150L), c(400L,200L)
    )
    red_ratios <- c(0.30)
    alpha_vals <- c(0.20, 0.30)   # two sensible leaky rates
    rho_kinds  <- c("flat","decay")
    act_f_vals <- c("tanh","relu")
    m_vals     <- c(24L, 36L)
    wash_vals  <- c(200L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(3L,3L), c(7L,7L))
    standardize_vals   <- c(TRUE)
    input_bound_vals   <- c("tanh")
    win_scale_global_v <- c(0.5, 1.0, 2.0)
    win_scale_bias_v   <- c(0.2, 0.5)
    rho_scale_vals     <- c(0.8, 1.0)
  } else if (grid_preset == "default") {
    # Allow D up to 3, but still bias toward smaller D’s
    D_vals   <- c(1L, 2L, 3L)
    n_packs  <- list(
      # D=1
      c(200L), c(300L), c(400L), c(500L),
      # D=2
      c(200L,100L), c(300L,150L), c(400L,200L),
      # D=3 (a couple of sensible stacks)
      c(300L,200L,150L), c(400L,300L,200L)
    )
    red_ratios <- c(0.20, 0.30)
    alpha_vals <- c(0.20, 0.30, 0.50)
    rho_kinds  <- c("flat","decay")
    act_f_vals <- c("tanh","relu")
    m_vals     <- c(12L, 24L, 36L)
    wash_vals  <- c(200L)
    bias_vals  <- c(FALSE, TRUE)
    lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L), c(14L,14L))
    standardize_vals   <- c(TRUE)
    input_bound_vals   <- c("tanh")
    win_scale_global_v <- c(0.5, 1.0, 2.0)
    win_scale_bias_v   <- c(0.2, 0.5)
    rho_scale_vals     <- c(0.8, 1.0)
  }

  # Build the full spec list
  specs_list <- vector("list", 0L)
  for (D in D_vals) {
    for (n in n_packs) {
      if (length(n) != D) next
      for (rr in red_ratios) {
        n_tilde <- make_n_tilde(n, rr)
        for (alpha in alpha_vals) {
          for (rk in rho_kinds) {
            for (rs in rho_scale_vals) {
              rho <- rs * rho_pattern(D, rk)
              for (af in act_f_vals) {
                for (m in m_vals) for (wo in wash_vals) for (ab in bias_vals) {
                  for (lp in lags_pairs) {
                    if (af == "relu" && alpha < 0.20) next
                    for (std_in in standardize_vals)
                      for (ib in input_bound_vals)
                        for (sg in win_scale_global_v)
                          for (sb in win_scale_bias_v) {
                            specs_list[[length(specs_list)+1L]] <- list(
                              D = D, n = as.integer(n), n_tilde = as.integer(n_tilde),
                              alpha = alpha, rho = as.numeric(rho),
                              act_f = af, act_k = "identity",
                              m = as.integer(m), washout = as.integer(wo),
                              add_bias = isTRUE(ab),
                              lags_ppt = as.integer(lp[1]), lags_soil = as.integer(lp[2]),
                              red_ratio = rr, rho_kind = rk, rho_scale = rs,
                              standardize_inputs = isTRUE(std_in),
                              input_bound = ib,
                              win_scale_global = as.numeric(sg),
                              win_scale_bias   = as.numeric(sb)
                            )
                          }
                  }
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

  # Compute *after* any filtering
  n_specs_full <- length(specs_list)

  # Optional uniform subsample…
  if (is.finite(max_specs) && max_specs > 0L && max_specs < n_specs_full) {
    set.seed(as.integer(grid_seed))
    keep_idx <- sort(sample.int(n_specs_full, max_specs))
    specs_list <- specs_list[keep_idx]
  }
  n_specs <- length(specs_list)
  if (n_specs == 0L) {
    stop(sprintf("Grid '%s' produced zero candidate specs. Check D_vals/n_packs or preset filters.", grid_preset))
  }

  # Header
  log_line(sprintf("Stage=%s | grid=%s | candidates=%d (of %d) | seeds=%s",
                   stage, grid_preset, n_specs, n_specs_full, paste(seed_vec, collapse=",")))

  ## ---- Core worker: fit one spec for one seed ----
  fit_spec_once <- function(spec, seed) {
    t0 <- proc.time()[3]
    D <- spec$D; n <- spec$n; n_tilde <- spec$n_tilde
    alpha <- spec$alpha; rho <- spec$rho
    act_f <- spec$act_f; act_k <- spec$act_k
    m <- spec$m; washout <- spec$washout
    add_bias <- isTRUE(spec$add_bias)
    lags_ppt <- spec$lags_ppt; lags_soil <- spec$lags_soil

    # Sparsity: target fan-out ≈ 10, with caps; make W_in denser
    pi_w <- pi_w_from_fanout(n)
    pi_in <- default_pi_in()

    desn_args <- list(
      D=D, n=n, n_tilde=n_tilde,
      m=m, alpha=alpha, rho=rho,
      act_f=act_f, act_k=act_k,
      pi_w=pi_w, pi_in=pi_in,
      washout=washout, add_bias=add_bias,
      # NEW: input preprocessing knobs (from spec)
      standardize_inputs = isTRUE(spec$standardize_inputs),
      input_bound        = spec$input_bound,
      win_scale_global   = spec$win_scale_global,
      win_scale_bias     = spec$win_scale_bias,
      seed=seed
    )


    X_ppt  <- lag_mat(ppt,  lags_ppt)
    X_soil <- lag_mat(soil, lags_soil)
    X_cov_full <- cbind(X_ppt, X_soil)
    maxlag_cov <- max(lags_ppt, lags_soil)

    fit_q <- function(p0) {
      fit0 <- do.call(qdesn_fit_vb, c(list(y=y, p0=p0, vb_args=vb_args), desn_args))
      keep_idx <- fit0$meta$keep_idx
      y_fit    <- fit0$y_fit
      X_res    <- fit0$X

      trim_n <- sum(keep_idx <= maxlag_cov)
      if (trim_n > 0) {
        keep_idx <- keep_idx[-seq_len(trim_n)]
        y_fit    <- y_fit[-seq_len(trim_n)]
        X_res    <- X_res[-seq_len(trim_n), , drop=FALSE]
      }
      X_cov <- if (ncol(X_cov_full)) X_cov_full[keep_idx, , drop=FALSE] else
        matrix(numeric(0), nrow=length(keep_idx), ncol=0)
      X_aug <- cbind(X_res, X_cov)

      p_res_cols <- ncol(X_res)  

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
          keep_idx = keep_idx,
          drop = max(m, washout, maxlag_cov),
          T = T_full, p0 = p0, D = D, n = n, n_tilde = n_tilde,
          m = m, alpha = alpha, rho = rho, add_bias = add_bias,
          # reproducibility
          pi_w = pi_w, pi_in = pi_in,

          # keep the original preproc flags (unchanged)
          preproc = list(
            standardize_inputs = isTRUE(spec$standardize_inputs),
            input_bound        = spec$input_bound,
            win_scale_global   = spec$win_scale_global,
            win_scale_bias     = spec$win_scale_bias,
            rho_kind           = spec$rho_kind,
            rho_scale          = spec$rho_scale
          ),

          # NEW (used by forecast_paths):
          p_res       = p_res_cols,
          lags_ppt    = lags_ppt,
          lags_soil   = lags_soil,
          covar_order = c("ppt","soil"),

          # carry over lag standardization stats from base DESN fit
          standardize_inputs = isTRUE(spec$standardize_inputs),
          input_bound        = spec$input_bound,
          win_scale_global   = spec$win_scale_global,
          win_scale_bias     = spec$win_scale_bias,
          win_scale_lags     = fit0$meta$win_scale_lags,  # <-- from fit0
          lag_center = fit0$meta$lag_center,
          lag_scale  = fit0$meta$lag_scale,

          # keep diagnostics as its own field (like the base fit)
          diagnostics = fit0$meta$diagnostics,

          # Readout spec for forecasting (reservoir + exogenous lags)
          readout_spec = {
            xn <- character(0); xl <- list()
            if (length(lags_ppt))  { xn <- c(xn, "ppt");  xl[["ppt"]]  <- as.integer(lags_ppt) }
            if (length(lags_soil)) { xn <- c(xn, "soil"); xl[["soil"]] <- as.integer(lags_soil) }
            list(
              include_input  = FALSE,
              input_position = "after_reservoir",
              input_lags_y   = integer(0),
              input_lags_x   = list(),
              reservoir_lags = 0L,
              y_lags         = integer(0),
              x_names        = xn,
              x_lags         = xl,
              p_res          = p_res_cols,
              scale_info     = NULL
            )
          }
        )
      )

      class(fit_exog) <- "qdesn_fit"
      list(fit=fit_exog, df_mu=df_mu)
    }

    fits <- lapply(p_vec, fit_q); names(fits) <- paste0("p=", p_vec)

    T_common <- min(vapply(fits, function(o) nrow(o$df_mu), 1L))
    fits <- lapply(fits, function(o) { o$df_mu <- utils::tail(o$df_mu, T_common); o })
    y_aligned <- fits[[1]]$df_mu$y

    ki_mat <- do.call(cbind, lapply(fits, function(o) utils::tail(o$fit$meta$keep_idx, T_common)))
    if (!all(apply(ki_mat, 1, function(r) length(unique(r))==1)))
      stop("keep_idx alignment mismatch across p.")

    pp_draws <- lapply(fits, function(x)
      posterior_predict.qdesn_fit(x$fit, nd=nd_draws, chunk=chunk_sz)$yrep
    )
    pp_draws <- lapply(pp_draws, function(M) utils::tail(M, T_common))

    lastN <- min(T_common, score_last_N)
    idx_tail <- (T_common - lastN + 1L):T_common
    pp_draws <- lapply(pp_draws, function(M) M[idx_tail, , drop=FALSE])
    y_aligned <- y_aligned[idx_tail]
    T_common  <- nrow(pp_draws[[1]])

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
      complexity = list(sum_n = sum(n), D = D,
                        lags_tot = lags_ppt + lags_soil)
    )
  }
  
  ## ---- Map over candidate specs (seeds averaged inside) ----
  run_one_spec <- function(i) {
    row <- specs_list[[i]]
    key <- spec_key(row)

    # Run each seed safely; keep the ones that succeed
    seed_runs <- lapply(seed_vec, function(sd) {
      tryCatch(
        fit_spec_once(row, seed = sd),
        error = function(e) {
          if (!is.null(progress_log)) {
            stamp <- format(Sys.time(), "%F %T")
            line <- sprintf("[%s] FAIL (seed=%s) %d/%d: %s | %s\n",
                            stamp, as.character(sd), i, length(specs_list), key, conditionMessage(e))
            cat(line, file = progress_log, append = TRUE)
          }
          NULL
        }
      )
    })
    ok <- vapply(seed_runs, function(x) !is.null(x), FALSE)

    if (!any(ok)) {
      # All seeds failed for this spec
      return(fail_result(i, row, reason = "all seeds failed"))
    }

    seed_runs <- seed_runs[ok]

    crps_means <- vapply(seed_runs, function(x) x$mean_crps, 1.0)
    mean_crps  <- mean(crps_means, na.rm = TRUE)
    se_crps    <- if (length(seed_runs) > 1L)
      stats::sd(crps_means, na.rm = TRUE) / sqrt(length(seed_runs)) else NA_real_

    cov_tbl <- do.call(rbind, lapply(seed_runs, function(z) z$coverage))
    cov_out <- do.call(rbind, lapply(split(cov_tbl, cov_tbl$p0), function(df) {
      data.frame(p0 = df$p0[1],
                 cov = mean(df$cov, na.rm = TRUE),
                 avg_bw = stats::median(df$avg_bw, na.rm = TRUE))
    }))
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
                        lags_tot = row$lags_ppt + row$lags_soil)
    )
  }


  if (!parallel) {
    results <- vector("list", n_specs)
    for (i in seq_len(n_specs)) {
      key_i <- spec_key(specs_list[[i]])
      if ((i == 1L) || (i %% progress_every == 0L) || (i == n_specs)) {
        log_line(sprintf("start %d/%d: %s", i, n_specs, key_i))
      }

      results[[i]] <- tryCatch(
        run_one_spec(i),
        error = function(e) {
          log_line(sprintf("FAIL  %d/%d: %s | %s", i, n_specs, key_i, conditionMessage(e)))
          fail_result(i, specs_list[[i]], reason = conditionMessage(e))
        }
      )

      if ((i == 1L) || (i %% progress_every == 0L) || (i == n_specs)) {
        log_line(sprintf("done  %d/%d: %s | meanCRPS=%.6f",
                         i, n_specs, results[[i]]$spec_key, results[[i]]$mean_crps))
      }
    }
  } else {
    cl <- parallel::makePSOCKcluster(n_workers)
    on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)

    parallel::clusterEvalQ(cl, {
      library(exdqlm)
      Sys.setenv(
        OMP_NUM_THREADS = "1",
        MKL_NUM_THREADS = "1",
        OPENBLAS_NUM_THREADS = "1",
        VECLIB_MAXIMUM_THREADS = "1",
        BLAS_NUM_THREADS = "1"
      )
      NULL
    })
    try(parallel::clusterSetRNGStream(cl, 12345), silent = TRUE)

    # NEW: PSOCK needs all free vars/closures explicitly exported.
    parallel::clusterExport(
      cl,
      c(
        # closures
        "run_one_spec", "fit_spec_once",
        # config/objects they capture
        "specs_list", "seed_vec", "keep_artifacts", "p_vec",
        "vb_args", "nd_draws", "chunk_sz",
        "synth_grid_M", "synth_nsamp", "synth_isotonic",
        "synth_rearrange", "synth_seed", "score_last_N",
        "y", "ppt", "soil", "T_full",
        "progress_log",
        # helper utilities used in fail paths/CRPS
        "fail_result", "spec_key",
        "slice_last", "slice_last_rows",
        "crps_from_draws_1", "crps_from_draws_window"
      ),
      envir = environment()
    )

    worker_fun <- function(i) {
      stamp <- format(Sys.time(), "%F %T")
      tryCatch({
        res <- run_one_spec(i)
        if (!is.null(progress_log)) {
          line <- sprintf("[%s] done  %d/%d: %s | meanCRPS=%.6f\n",
                          stamp, i, length(specs_list), res$spec_key, res$mean_crps)
          cat(line, file = progress_log, append = TRUE)
        }
        res
      }, error = function(e) {
        fr <- fail_result(i, specs_list[[i]], reason = conditionMessage(e))
        if (!is.null(progress_log)) {
          line <- sprintf("[%s] FAIL  %d/%d: %s | %s\n",
                          stamp, i, length(specs_list), fr$spec_key, conditionMessage(e))
          cat(line, file = progress_log, append = TRUE)
        }
        fr
      })
    }

    results <- parallel::parLapply(cl, seq_len(n_specs), worker_fun)
  }


  ## ---- Leaderboard & winner ----
  leaderboard <- do.call(rbind, lapply(results, function(r) {
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
  leaderboard <- leaderboard[is.finite(leaderboard$mean_CRPS), , drop = FALSE]
  if (nrow(leaderboard) == 0L) {
    stop("All candidate specs failed. See FAIL lines in the progress log for details.")
  }
  o <- order(leaderboard$mean_CRPS, leaderboard$sum_n, leaderboard$D, leaderboard$lags_tot)
  leaderboard <- leaderboard[o, , drop = FALSE]

  best_row <- leaderboard[1, , drop = FALSE]

  best     <- results[[ best_row$spec_idx ]]

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

#' Option A: Split-once, path-forecast validation selection, then refit & test
#'
#' Implements the end-to-end workflow:
#'   Train (~80%) | Validate (~15%) | Test (~5%).
#'   Fit once per quantile on Train; recursive multi-horizon forecasts on Val;
#'   synthesize (p = {0.05,0.50,0.95}); score CRPS by lead and aggregate;
#'   select best spec; refit on Train∪Val; forecast Test; report Test CRPS.
#'
#' @param y,ppt,soil Numeric vectors (same length).
#' @param p_vec Quantiles to fit/synthesize. Default: c(0.05,0.50,0.95).
#' @param split Proportions c(train, val, test). Default: c(.80,.15,.05).
#' @param weight_leads "uniform" or "inverse_h" aggregation across horizons.
#' @param stage "coarse" or "final" affects VB and sampling budgets.
#' @param grid_preset As in your other selector ("default","small","tiny","micro").
#' @param seed_vec Vector of reservoir seeds to average per spec (variance reduction).
#' @param parallel,n_workers Same semantics as before.
#' @param keep_artifacts Keep winner's fits, forecasts, and draws (TRUE/FALSE).
#' @param progress_console,progress_log,progress_every Logging controls.
#' @return list with leaderboard (validation), winner (key), selection_bundle with
#'         validation details, and test_bundle (refit Train∪Val, score on Test).
#' @export
model_selection_optionA <- function(
  y, ppt = NULL, soil = NULL,
  p_vec = c(0.05, 0.50, 0.95),
  split = c(0.80, 0.15, 0.05),
  weight_leads = c("uniform","inverse_h"),
  stage = c("coarse","final"),
  grid_preset = c("default","small","tiny","micro"),
  seed_vec = c(42L, 101L),
  parallel = FALSE,
  n_workers = max(1L, parallel::detectCores() - 1L),
  keep_artifacts = TRUE,
  progress_console = FALSE,
  progress_log = NULL,
  progress_every = 1L
) {
  stage <- match.arg(stage)
  grid_preset <- match.arg(grid_preset)
  weight_leads <- match.arg(weight_leads)

  stopifnot(is.numeric(y))
  T_full <- length(y)
  if (!is.null(ppt) && length(ppt) != T_full) stop("ppt length must match y.")
  if (!is.null(soil) && length(soil) != T_full) stop("soil length must match y.")
  if (is.null(ppt))  ppt  <- rep(0, T_full)
  if (is.null(soil)) soil <- rep(0, T_full)

  # ---------- split once ----------
  split <- as.numeric(split); split <- split / sum(split)
  n_tr  <- max(1L, floor(split[1] * T_full))
  n_va  <- max(1L, floor(split[2] * T_full))
  n_te  <- max(1L, T_full - n_tr - n_va)
  idx_tr <- 1:n_tr
  idx_va <- (n_tr + 1):(n_tr + n_va)
  idx_te <- (n_tr + n_va + 1):T_full

  y_tr <- y[idx_tr]; ppt_tr <- ppt[idx_tr]; soil_tr <- soil[idx_tr]
  y_va <- y[idx_va]; ppt_va <- ppt[idx_va]; soil_va <- soil[idx_va]
  y_te <- y[idx_te]; ppt_te <- ppt[idx_te]; soil_te <- soil[idx_te]

  H_val  <- length(y_va)
  H_test <- length(y_te)

  # ---------- budgets by stage ----------
  vb_args <- list(
    max_iter   = if (stage == "coarse")  900 else 2000,
    tol        = 1e-4,
    n_samp_xi  = if (stage == "coarse")  400 else 1200,
    verbose    = FALSE
  )
  nd_draws       <- if (stage == "coarse") 1000L else 4000L
  chunk_sz       <- 256L
  synth_grid_M   <- if (stage == "coarse")  801L else 2001L
  synth_nsamp    <- if (stage == "coarse") 2500L else 8000L
  synth_isotonic <- TRUE
  synth_rearrange<- if (stage == "coarse") FALSE else TRUE
  synth_seed     <- 999L

  # ---------- helpers ----------
  lag_mat <- function(x, L) {
    T <- length(x); L <- as.integer(L)
    if (L <= 0) return(matrix(numeric(0), nrow = T, ncol = 0))
    M <- matrix(0, nrow = T, ncol = L)
    for (j in 1:L) M[(j+1):T, j] <- x[1:(T - j)]
    M
  }
  agg_weights <- function(H, kind) {
    if (kind == "inverse_h") {
      w <- 1/seq_len(H); w / sum(w)
    } else {
      rep(1/H, H)
    }
  }
  crps_1 <- function(y_true, draws_vec) {
    x <- sort(as.numeric(draws_vec)); N <- length(x); if (N < 5) return(NA_real_)
    tau <- (seq_len(N)) / (N + 1)
    res <- y_true - x
    rho <- (tau - as.numeric(res < 0)) * res
    (2 / N) * sum(rho)
  }

  # ---------- candidate grid (copied/adapted from your function) ----------
  rho_pattern <- function(D, kind = c("flat","decay")) {
    kind <- match.arg(kind)
    if (kind == "flat")  rep(0.90, D) else head(c(0.95, 0.90, 0.85), D)
  }
  make_n_tilde <- function(n, ratio = 0.2) {
    if (length(n) <= 1) integer(0) else pmax(1L, as.integer(round(head(n, -1) * ratio)))
  }
  pi_w_from_fanout <- function(n_vec, target = 10) {
    p <- target / median(as.numeric(n_vec)); max(min(p, 0.20), 0.02)
  }
  default_pi_in <- function() 0.60

  D_vals     <- c(1L, 2L, 3L)
  n_packs    <- list(
    c(200L), c(300L), c(400L), c(500L),
    c(200L,100L), c(300L,150L), c(400L,200L),
    c(300L,200L,150L), c(400L,300L,200L)
  )
  red_ratios <- c(0.20, 0.30)
  alpha_vals <- c(0.20, 0.30, 0.50)
  rho_kinds  <- c("flat","decay")
  act_f_vals <- c("tanh","relu")
  m_vals     <- c(12L, 24L, 36L)
  wash_vals  <- c(200L)
  bias_vals  <- c(FALSE, TRUE)
  lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L), c(14L,14L))
  standardize_vals   <- c(TRUE)
  input_bound_vals   <- c("tanh")
  win_scale_global_v <- c(0.5, 1.0, 2.0)
  win_scale_bias_v   <- c(0.2, 0.5)
  rho_scale_vals     <- c(0.8, 1.0)

  if (grid_preset == "small") {
    D_vals   <- c(1L, 2L)
    n_packs  <- list(c(200L), c(300L), c(400L), c(300L,150L))
    red_ratios <- c(0.30)
    alpha_vals <- c(0.20, 0.30)
    rho_kinds  <- c("flat","decay")
    act_f_vals <- c("tanh")
    m_vals     <- c(12L, 24L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L))
    win_scale_global_v <- c(0.5, 1.0)
    win_scale_bias_v   <- c(0.2)
    rho_scale_vals     <- c(0.8, 1.0)
  } else if (grid_preset == "tiny") {
    D_vals   <- c(1L)
    n_packs  <- list(c(200L), c(300L), c(400L))
    red_ratios <- c(0.30)
    alpha_vals <- c(0.30)
    rho_kinds  <- c("flat")
    act_f_vals <- c("tanh")
    m_vals     <- c(24L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(0L,0L), c(3L,3L))
    win_scale_global_v <- c(1.0)
    win_scale_bias_v   <- c(0.2)
    rho_scale_vals     <- c(1.0)
  } else if (grid_preset == "micro") {
    D_vals   <- c(1L, 2L)
    n_packs  <- list(c(200L), c(300L), c(400L), c(500L),
                     c(300L,150L), c(400L,200L))
    red_ratios <- c(0.30)
    alpha_vals <- c(0.20, 0.30)
    rho_kinds  <- c("flat","decay")
    act_f_vals <- c("tanh","relu")
    m_vals     <- c(24L, 36L)
    wash_vals  <- c(200L)
    bias_vals  <- c(TRUE)
    lags_pairs <- list(c(3L,3L), c(7L,7L))
    win_scale_global_v <- c(0.5, 1.0, 2.0)
    win_scale_bias_v   <- c(0.2, 0.5)
    rho_scale_vals     <- c(0.8, 1.0)
  }

  specs_list <- vector("list", 0L)
  for (D in D_vals) for (n in n_packs) if (length(n) == D) {
    for (rr in red_ratios) {
      n_tilde <- make_n_tilde(n, rr)
      for (alpha in alpha_vals) for (rk in rho_kinds) for (rs in rho_scale_vals) {
        rho <- rs * rho_pattern(D, rk)
        for (af in act_f_vals) for (m in m_vals) for (wo in wash_vals) for (ab in bias_vals)
          for (lp in lags_pairs) for (std_in in standardize_vals)
            for (ib in input_bound_vals) for (sg in win_scale_global_v)
              for (sb in win_scale_bias_v) {
                if (af == "relu" && alpha < 0.20) next
                specs_list[[length(specs_list)+1L]] <- list(
                  D=D, n=as.integer(n), n_tilde=as.integer(n_tilde),
                  alpha=alpha, rho=as.numeric(rho),
                  act_f=af, act_k="identity",
                  m=as.integer(m), washout=as.integer(wo),
                  add_bias=isTRUE(ab),
                  lags_ppt=as.integer(lp[1]), lags_soil=as.integer(lp[2]),
                  red_ratio=rr, rho_kind=rk, rho_scale=rs,
                  standardize_inputs=isTRUE(std_in),
                  input_bound=ib, win_scale_global=as.numeric(sg), win_scale_bias=as.numeric(sb)
                )
              }
      }
    }
  }
  # de-dup
  key_vec <- vapply(specs_list, function(s) paste(unlist(s), collapse="|"), "")
  specs_list <- specs_list[!duplicated(key_vec)]
  n_specs <- length(specs_list)
  if (n_specs == 0L) stop("Spec grid empty.")

  # ---------- logging helper ----------
  progress_every <- as.integer(progress_every)
  log_line <- function(txt) {
    stamp <- format(Sys.time(), "%F %T"); line <- paste0("[", stamp, "] ", txt, "\n")
    if (isTRUE(progress_console)) cat(line)
    if (!is.null(progress_log)) cat(line, file = progress_log, append = TRUE)
    invisible(NULL)
  }
  log_line(sprintf("OptionA stage=%s | grid=%s | candidates=%d | seeds=%s | Hval=%d | Htest=%d",
                   stage, grid_preset, n_specs, paste(seed_vec, collapse=","), H_val, H_test))

  # ---------- core: fit one spec for one seed (on Train), forecast Val recursively ----------
  fit_one_seed <- function(spec, seed, y_tr, ppt_tr, soil_tr) {
    D <- spec$D; n <- spec$n; n_tilde <- spec$n_tilde
    pi_w <- pi_w_from_fanout(n)
    pi_in <- default_pi_in()

    # Build base DESN on Train only
    base_args <- list(
      y = y_tr, p0 = NA_real_ # placeholder; we call separately by quantile
    )

    # prepare covariate lags matrices (Train)
    X_ppt_tr  <- lag_mat(ppt_tr,  spec$lags_ppt)
    X_soil_tr <- lag_mat(soil_tr, spec$lags_soil)
    maxlag_cov_tr <- max(spec$lags_ppt, spec$lags_soil)

    # helper: fit a single quantile readout on Train with augmented design
    fit_q <- function(p0) {
      fit0 <- qdesn_fit_vb(
        y = y_tr, p0 = p0,
        D = D, n = n, n_tilde = n_tilde,
        m = spec$m, alpha = spec$alpha, rho = spec$rho,
        act_f = spec$act_f, act_k = spec$act_k,
        pi_w = pi_w, pi_in = pi_in,
        washout = spec$washout, add_bias = isTRUE(spec$add_bias),
        # preprocessing knobs (must be carried into meta for forecasting)
        standardize_inputs = isTRUE(spec$standardize_inputs),
        input_bound        = spec$input_bound,
        win_scale_global   = spec$win_scale_global,
        win_scale_bias     = spec$win_scale_bias,
        seed = seed,
        vb_args = vb_args
      )

      keep_idx <- fit0$meta$keep_idx
      y_fit    <- fit0$y_fit
      X_res    <- fit0$X

      # trim earliest rows to align with exog lags
      trim_n <- sum(keep_idx <= maxlag_cov_tr)
      if (trim_n > 0) {
        keep_idx <- keep_idx[-seq_len(trim_n)]
        y_fit    <- y_fit[-seq_len(trim_n)]
        X_res    <- X_res[-seq_len(trim_n), , drop = FALSE]
      }
      X_cov <- cbind(
        if (ncol(X_ppt_tr))  X_ppt_tr [keep_idx, , drop=FALSE] else NULL,
        if (ncol(X_soil_tr)) X_soil_tr[keep_idx, , drop=FALSE] else NULL
      )
      X_aug <- cbind(X_res, X_cov)

      fit_readout <- exal_static_LDVB(
        y = y_fit, X = X_aug, p0 = p0,
        max_iter = vb_args$max_iter, tol = vb_args$tol,
        b0 = rep(0, ncol(X_aug)), V0 = diag(1e4, ncol(X_aug)),
        a_sigma = 1, b_sigma = 1,
        n_samp_xi = vb_args$n_samp_xi,
        verbose = FALSE
      )

      # wrap as qdesn_fit with augmented meta required for forecasting
      fit_exog <- list(
        fit  = fit_readout,
        X    = X_aug, y_fit = y_fit,
        mu_hat = as.numeric(X_aug %*% fit_readout$qbeta$m),
        reservoir = fit0$reservoir,
        states    = fit0$states,
        meta = list(
          keep_idx = keep_idx,
          drop = max(spec$m, spec$washout, maxlag_cov_tr),
          T = length(y_tr), p0 = p0,
          D = D, n = n, n_tilde = n_tilde,
          m = spec$m, alpha = spec$alpha, rho = spec$rho, add_bias = isTRUE(spec$add_bias),
          # reproducibility of sparsities
          pi_w = pi_w, pi_in = pi_in,

          # readout column bookkeeping for forecaster
          p_res       = ncol(X_res),
          lags_ppt    = spec$lags_ppt,
          lags_soil   = spec$lags_soil,
          covar_order = c("ppt","soil"),

          # carry preprocessing flags + z-score stats
          standardize_inputs = isTRUE(spec$standardize_inputs),
          input_bound        = spec$input_bound,
          win_scale_global   = spec$win_scale_global,
          win_scale_bias     = spec$win_scale_bias,
          win_scale_lags     = fit0$meta$win_scale_lags,
          lag_center = fit0$meta$lag_center,
          lag_scale  = fit0$meta$lag_scale,

          diagnostics = fit0$meta$diagnostics,

          # Readout spec for forecasting (reservoir + exogenous lags)
          readout_spec = {
            xn <- character(0); xl <- list()
            if (length(spec$lags_ppt))  { xn <- c(xn, "ppt");  xl[["ppt"]]  <- as.integer(spec$lags_ppt) }
            if (length(spec$lags_soil)) { xn <- c(xn, "soil"); xl[["soil"]] <- as.integer(spec$lags_soil) }
            list(
              include_input  = FALSE,
              input_position = "after_reservoir",
              input_lags_y   = integer(0),
              input_lags_x   = list(),
              reservoir_lags = 0L,
              y_lags         = integer(0),
              x_names        = xn,
              x_lags         = xl,
              p_res          = ncol(X_res),
              scale_info     = NULL
            )
          }
        )
      )
      class(fit_exog) <- "qdesn_fit"
      fit_exog
    }

    fits <- lapply(p_vec, fit_q); names(fits) <- paste0("p=", p_vec)

    # recursive path forecasts on VALIDATION window
    m_lag <- spec$m
    yhist <- if (m_lag > 0) tail(y_tr, m_lag) else numeric(0)
    xhist <- list(
      ppt  = if (spec$lags_ppt  > 0) tail(ppt_tr,  spec$lags_ppt)  else NULL,
      soil = if (spec$lags_soil > 0) tail(soil_tr, spec$lags_soil) else NULL
    )
    xhist <- Filter(Negate(is.null), xhist)

    xfuture_val <- list(
      ppt  = if (spec$lags_ppt  > 0) ppt_va  else NULL,
      soil = if (spec$lags_soil > 0) soil_va else NULL
    )
    xfuture_val <- Filter(Negate(is.null), xfuture_val)

    yrep_list <- lapply(fits, function(ft)
      forecast_paths.qdesn_fit(
        ft, H = H_val, nd = nd_draws,
        method = "recursive",
        y_hist = yhist,
        xreg_hist = xhist,
        xreg_future = xfuture_val,
        chunk = chunk_sz
      )$yrep
    )

    # synthesize per horizon and score CRPS by lead
    synth <- exdqlm_synthesize_from_draws(
      draws_list = yrep_list,
      p = p_vec,
      enforce_isotonic = synth_isotonic,
      rearrange        = synth_rearrange,
      grid_M           = synth_grid_M,
      n_samp           = synth_nsamp,
      seed             = synth_seed,
      T_expected       = H_val
    )

    crps_h <- vapply(seq_len(H_val), function(h) crps_1(y_va[h], synth$draws[h, ]), 1.0)
    w <- agg_weights(H_val, weight_leads)
    score <- sum(w * crps_h)

    list(
      score = score,
      crps_by_h = crps_h,
      fits = if (keep_artifacts) fits else NULL,
      yrep_list = if (keep_artifacts) yrep_list else NULL,
      synth = if (keep_artifacts) synth else NULL
    )
  }

  # ---------- run all specs ----------
  run_one_spec <- function(i) {
    spec <- specs_list[[i]]
    key  <- paste0(
      "D", spec$D, "_n", paste(spec$n, collapse="-"),
      "_r", spec$rho_kind, "_rs", sprintf("%.2f", spec$rho_scale),
      "_a", sprintf("%.2f", spec$alpha), "_m", spec$m, "_w", spec$washout,
      "_f", spec$act_f, "_b", as.integer(spec$add_bias),
      "_lp", spec$lags_ppt, "_ls", spec$lags_soil,
      "_std", as.integer(isTRUE(spec$standardize_inputs)),
      "_ib", substr(spec$input_bound,1,1),
      "_sg", sprintf("%.2f", spec$win_scale_global),
      "_sb", sprintf("%.2f", spec$win_scale_bias)
    )

    if ((i == 1L) || (i %% progress_every == 0L) || (i == n_specs)) {
      log_line(sprintf("start %d/%d: %s", i, n_specs, key))
    }

    seed_runs <- lapply(seed_vec, function(sd) {
      tryCatch(
        fit_one_seed(spec, sd, y_tr, ppt_tr, soil_tr),
        error = function(e) {
          if (!is.null(progress_log)) {
            stamp <- format(Sys.time(), "%F %T")
            cat(sprintf("[%s] FAIL (seed=%s) %d/%d: %s | %s\n",
                        stamp, as.character(sd), i, n_specs, key, conditionMessage(e)),
                file = progress_log, append = TRUE)
          }
          NULL
        }
      )
    })
    ok <- vapply(seed_runs, function(x) !is.null(x), FALSE)
    if (!any(ok)) {
      list(
        spec_idx = i, spec_key = key,
        mean_score = Inf, se_score = NA_real_,
        exemplar = NULL
      )
    } else {
      seed_runs <- seed_runs[ok]
      scr <- vapply(seed_runs, `[[`, 1.0, "score")
      list(
        spec_idx = i, spec_key = key,
        mean_score = mean(scr), se_score = if (length(scr) > 1) stats::sd(scr)/sqrt(length(scr)) else NA_real_,
        exemplar = if (keep_artifacts) seed_runs[[1]] else NULL,
        spec_row = spec
      )
    }
  }

  results <- if (!parallel) {
    out <- vector("list", n_specs)
    for (i in seq_len(n_specs)) {
      out[[i]] <- run_one_spec(i)
      if ((i == 1L) || (i %% progress_every == 0L) || (i == n_specs)) {
        log_line(sprintf("done  %d/%d: %s | valScore=%.6f",
                         i, n_specs, out[[i]]$spec_key, out[[i]]$mean_score))
      }
    }
    out
  } else {
    cl <- parallel::makePSOCKcluster(n_workers)
    on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
    parallel::clusterEvalQ(cl, { library(exdqlm); NULL })
    parallel::clusterExport(cl, c("specs_list","seed_vec","fit_one_seed","y_tr","ppt_tr","soil_tr",
                                  "H_val","keep_artifacts","progress_log","n_specs"), envir = environment())
    parallel::parLapply(cl, seq_len(n_specs), run_one_spec)
  }

  # ---------- leaderboard & winner (validation) ----------
  leaderboard <- do.call(rbind, lapply(results, function(r)
    data.frame(
      spec_idx = r$spec_idx,
      spec_key = r$spec_key,
      mean_CRPS_val = r$mean_score,
      se_CRPS_val   = r$se_score,
      stringsAsFactors = FALSE
    )))
  leaderboard <- leaderboard[is.finite(leaderboard$mean_CRPS_val), , drop = FALSE]
  if (!nrow(leaderboard)) stop("All specs failed on validation.")
  o <- order(leaderboard$mean_CRPS_val)
  leaderboard <- leaderboard[o, , drop = FALSE]
  best_row <- leaderboard[1, , drop = FALSE]
  best     <- results[[ best_row$spec_idx ]]

  selection_bundle <- list(
    winner_key = best$spec_key,
    winner_spec = best$spec_row,
    leaderboard = leaderboard,
    validation = if (keep_artifacts) best$exemplar else NULL,
    config = list(
      p_vec = p_vec,
      split = c(train = n_tr, val = n_va, test = n_te),
      weight_leads = weight_leads,
      vb_args = vb_args,
      nd_draws = nd_draws,
      synth = list(grid_M = synth_grid_M, nsamp = synth_nsamp,
                   isotonic = synth_isotonic, rearrange = synth_rearrange, seed = synth_seed)
    )
  )

  # ---------- REFIT winner on Train∪Val, forecast Test, report Test CRPS ----------
  spec <- best$spec_row
  refit_score <- NA_real_
  test_detail <- NULL
  if (H_test > 0L) {
    # reuse the single-seed path with the first seed (or average over seeds if you want)
    single <- fit_one_seed(spec, seed_vec[1], y_tr = c(y_tr, y_va), ppt_tr = c(ppt_tr, ppt_va), soil_tr = c(soil_tr, soil_va))

    # now simulate over TEST horizon using Train∪Val as origin
    m_lag <- spec$m
    yhist <- if (m_lag > 0) tail(c(y_tr, y_va), m_lag) else numeric(0)
    xhist <- list(
      ppt  = if (spec$lags_ppt  > 0) tail(c(ppt_tr, ppt_va),  spec$lags_ppt)  else NULL,
      soil = if (spec$lags_soil > 0) tail(c(soil_tr, soil_va), spec$lags_soil) else NULL
    )
    xhist <- Filter(Negate(is.null), xhist)

    xfuture_test <- list(
      ppt  = if (spec$lags_ppt  > 0) ppt_te  else NULL,
      soil = if (spec$lags_soil > 0) soil_te else NULL
    )
    xfuture_test <- Filter(Negate(is.null), xfuture_test)

    yrep_list_test <- lapply(single$fits, function(ft)
      forecast_paths.qdesn_fit(
        ft, H = H_test, nd = nd_draws,
        method = "recursive",
        y_hist = yhist,
        xreg_hist = xhist,
        xreg_future = xfuture_test,
        chunk = chunk_sz
      )$yrep
    )

    synth_test <- exdqlm_synthesize_from_draws(
      draws_list = yrep_list_test,
      p = p_vec,
      enforce_isotonic = synth_isotonic,
      rearrange        = synth_rearrange,
      grid_M           = synth_grid_M,
      n_samp           = synth_nsamp,
      seed             = synth_seed,
      T_expected       = H_test
    )

    crps_h_test <- vapply(seq_len(H_test), function(h) crps_1(y_te[h], synth_test$draws[h, ]), 1.0)
    wtest <- agg_weights(H_test, weight_leads)
    refit_score <- sum(wtest * crps_h_test)

    test_detail <- if (keep_artifacts) list(
      yrep_list = yrep_list_test,
      synth = synth_test,
      crps_by_h = crps_h_test,
      agg = refit_score
    ) else NULL
  }

  list(
    leaderboard = leaderboard,
    winner = best$spec_key,
    selection_bundle = selection_bundle,
    test_bundle = list(
      H_test = H_test,
      agg_CRPS_test = refit_score,
      detail = test_detail
    )
  )
}
