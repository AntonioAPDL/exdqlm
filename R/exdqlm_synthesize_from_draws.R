#' Synthesize posterior predictive from multiple quantile-model draws
#'
#' The function synthesizes posterior predictive draws from multiple fitted
#' quantile models using a two-step correction:
#' (i) isotonic regression at the grid of target quantiles to enforce non-crossing,
#' (ii) distributional alignment (shift each model's draws so its tau-quantile matches the isotone anchor),
#' then builds a single predictive quantile function per time by
#' piecewise-linear blending across adjacent quantile models with optional
#' global monotone rearrangement.
#'
#' @param draws_list List of length \code{L}; each element is a numeric matrix of posterior
#'   predictive draws from a fitted quantile model at level \code{p[i]}. Each matrix
#'   may be \code{T × ns} or \code{ns × T}; rows will be coerced to time.
#' @param p Numeric vector of target quantile levels in \code{(0,1)} of length \code{L}
#'   (same order as \code{draws_list}, not necessarily sorted). Duplicate levels are not allowed.
#' @param enforce_isotonic Logical; apply isotonic regression (PAVA) over the grid \code{p}
#'   at each time t to remove crossing. Default \code{TRUE}.
#' @param rearrange Logical; apply monotone rearrangement (evaluate -> sort -> reinterpolate)
#'   on a dense grid over \code{u in (0,1)}. Default \code{TRUE}.
#' @param grid_M Integer; size of dense grid \code{M} for rearrangement (\code{u_k = k/(M+1)}).
#'   Default \code{1001L}.
#' @param n_samp Integer; number of synthesized draws per time. Default \code{1000L}.
#' @param seed NULL or integer for reproducible synthesized draws. Default \code{NULL}.
#' @param T_expected Optional integer; if provided, forces the time dimension to \code{T_expected}
#'   when orienting each matrix to \code{T × ns}. This avoids accidental transposes.
#'
#' @return A list containing:
#' \itemize{
#'   \item \code{draws} - Numeric matrix \code{T × n_samp} of synthesized draws.
#'   \item \code{levels} - Sorted copy of \code{p} (length \code{L}).
#'   \item \code{quantiles} - Numeric matrix \code{T × L} of isotone anchors \code{m^*_{i,t}}.
#'   \item \code{summary} - List with row-wise summaries of \code{draws}
#'   (\code{mean}, \code{q025}, \code{q250}, \code{q500}, \code{q750}, \code{q975}).
#'   \item \code{method} - List of synthesis settings used
#'   (\code{name}, \code{isotonic}, \code{rearrange}, \code{grid_M}, \code{T_inferred}).
#' }
#' @export
#' 
#' @examples
#' \donttest{
#' # short example
#' TT = 100
#' y = scIVTmag[1:TT]
#' 
#' # create trend & seasonal model
#' trend.comp = polytrendMod(1,mean(y),10)
#' seas.comp = seasMod(365,c(1,2,4),C0=10*diag(6))
#' model = trend.comp + seas.comp
#' 
#' # fit five quantiles using LDVB algorithm & save individual posterior predictive samples
#' fits <- draws <- NULL
#' p0s = c(0.05, 0.25, 0.50, 0.75, 0.95)
#' for(i in 1:length(p0s)){
#'   fits[[i]] = exdqlmLDVB(y, p0=p0s[i], model, df=c(1,1), dim.df = c(1,6), sig.init=15, tol=0.05)
#'   draws[[i]] = fits[[i]]$samp.post.pred
#' }
#' 
#' # synthesize posterior predictive from all quantiles
#' syn = exdqlm_synthesize_from_draws(
#'   draws_list = draws,
#'   p = p0s,
#'   T_expected = TT )
#' }
exdqlm_synthesize_from_draws <- function(draws_list, p,
                                         enforce_isotonic = TRUE,
                                         rearrange = TRUE,
                                         grid_M = 1001L,
                                         n_samp = 1000L,
                                         seed = NULL,
                                         T_expected = NULL) {

  stopifnot(is.list(draws_list), is.numeric(p), length(draws_list) == length(p))
  L <- length(p)
  if (L < 2L) stop("Need at least two quantile models to synthesize.")

  # ---- Robust orientation to T × ns ----
  dims_r <- vapply(draws_list, function(M) nrow(as.matrix(M)), 1L)
  dims_c <- vapply(draws_list, function(M) ncol(as.matrix(M)), 1L)

  if (is.null(T_expected)) {
    # choose the most common dimension across all rows+cols as T
    cand_tab <- sort(table(c(dims_r, dims_c)), decreasing = TRUE)
    Tt <- as.integer(names(cand_tab)[1])
  } else {
    Tt <- as.integer(T_expected)
  }

  mats <- lapply(draws_list, function(M) {
    M <- as.matrix(M)
    if (nrow(M) == Tt) {
      M
    } else if (ncol(M) == Tt) {
      t(M)  # ns x T -> T x ns
    } else {
      stop(sprintf("A draws matrix has shape %dx%d; neither dimension matches inferred/expected T=%d.",
                   nrow(M), ncol(M), Tt))
    }
  })

  # sanity: all oriented to Tt × ns_i
  stopifnot(length(unique(vapply(mats, nrow, 1L))) == 1L)

  # ---- Order by ascending p (taus) ----
  ord  <- order(p)
  taus <- as.numeric(p[ord])
  mats <- mats[ord]

  if (any(!is.finite(taus)) || any(taus <= 0 | taus >= 1))
    stop("All p must be in (0,1) and finite.")
  if (any(diff(taus) <= 0))
    stop("p must be strictly increasing (no duplicates).")

  # Per-fit sample sizes and empirical probability grids (for inverse-CDF via interpolation)
  ns_vec  <- vapply(mats, ncol, 1L)
  pp_list <- lapply(ns_vec, function(ns) (seq_len(ns)) / (ns + 1))

  # Helper: row quantiles with optional matrixStats
  rowQ <- function(M, prob) {
    if (requireNamespace("matrixStats", quietly = TRUE)) {
      as.numeric(matrixStats::rowQuantiles(M, probs = prob, na.rm = TRUE))
    } else {
      apply(M, 1L, stats::quantile, probs = prob, na.rm = TRUE, type = 7)
    }
  }

  # A) anchors v_{i,t} at each model's own tau_i  ->  T × L
  v_mat <- do.call(cbind, lapply(seq_len(L), function(i) rowQ(mats[[i]], taus[i])))

  # B) isotone adjustment at the grid {taus} (per time t)
  if (isTRUE(enforce_isotonic)) {
    m_adj <- t(apply(v_mat, 1L, function(vrow) stats::isoreg(x = taus, y = vrow)$yf))
  } else {
    m_adj <- v_mat
  }

  # C) distributional alignment (shift so each model's tau_i-quantile hits m_adj[,i]); sort row-wise
  adj_list <- vector("list", L)
  for (i in seq_len(L)) {
    Mi   <- mats[[i]]        # T × ns_i
    v_i  <- v_mat[, i]
    m_i  <- m_adj[, i]
    sh   <- m_i - v_i        # length T
    ns_i <- ncol(Mi)

    adj  <- matrix(NA_real_, nrow = Tt, ncol = ns_i)
    for (t in seq_len(Tt)) {
      adj[t, ] <- sort(Mi[t, ] + sh[t])  # sorted => valid CDF grid for approx
    }
    adj_list[[i]] <- adj
  }

  # D) Build Q_t^{init}(u) by blending adjusted quantile functions between adjacent taus
  grid_u <- (seq_len(grid_M)) / (grid_M + 1)

  eval_Qinit_at_t <- function(t) {
    q_init <- numeric(length(grid_u))

    # Left region u <= tau_1 : use model 1
    idx_left  <- which(grid_u <= taus[1L])
    if (length(idx_left)) {
      q_init[idx_left] <- stats::approx(pp_list[[1L]], adj_list[[1L]][t, ],
                                        xout = grid_u[idx_left],
                                        rule = 2, ties = "ordered")$y
    }

    # Interior regions: linear blend between model i and i+1
    for (i in 1:(L - 1L)) {
      ids <- which(grid_u > taus[i] & grid_u < taus[i + 1L])
      if (!length(ids)) next
      u  <- grid_u[ids]
      w  <- (u - taus[i]) / (taus[i + 1L] - taus[i])
      qi  <- stats::approx(pp_list[[i]],   adj_list[[i]][t,   ], xout = u, rule = 2, ties = "ordered")$y
      qi1 <- stats::approx(pp_list[[i+1]], adj_list[[i+1]][t, ], xout = u, rule = 2, ties = "ordered")$y
      q_init[ids] <- (1 - w) * qi + w * qi1
    }

    # Right region u >= tau_L : use model L
    idx_right <- which(grid_u >= taus[L])
    if (length(idx_right)) {
      q_init[idx_right] <- stats::approx(pp_list[[L]], adj_list[[L]][t, ],
                                         xout = grid_u[idx_right],
                                         rule = 2, ties = "ordered")$y
    }

    q_init
  }

  # E) Rearrangement + inverse-CDF sampling
  if (!is.null(seed)) set.seed(as.integer(seed))
  U     <- matrix(stats::runif(Tt * n_samp), nrow = Tt, ncol = n_samp)
  draws <- matrix(NA_real_, nrow = Tt, ncol = n_samp)

  for (t in seq_len(Tt)) {
    q_init <- eval_Qinit_at_t(t)
    if (isTRUE(rearrange)) {
      q_sorted <- sort(q_init)                               # enforce global monotonicity
      draws[t, ] <- stats::approx(x = grid_u, y = q_sorted, xout = U[t, ], rule = 2)$y
    } else {
      draws[t, ] <- stats::approx(x = grid_u, y = q_init,   xout = U[t, ], rule = 2)$y
    }
  }

  # Summaries (rowwise)
  summary <- list(
    mean = rowMeans(draws),
    q025 = apply(draws, 1L, function(z) stats::quantile(z, 0.025)),
    q250 = apply(draws, 1L, function(z) stats::quantile(z, 0.250)),
    q500 = apply(draws, 1L, function(z) stats::quantile(z, 0.500)),
    q750 = apply(draws, 1L, function(z) stats::quantile(z, 0.750)),
    q975 = apply(draws, 1L, function(z) stats::quantile(z, 0.975))
  )

  list(
    draws     = draws,      # T × n_samp
    levels    = taus,       # sorted p
    quantiles = m_adj,      # T × L after isotone
    summary   = summary,
    method    = list(
      name       = "cdf-spline",
      isotonic   = isTRUE(enforce_isotonic),
      rearrange  = isTRUE(rearrange),
      grid_M     = grid_M,
      T_inferred = Tt
    )
  )
}
