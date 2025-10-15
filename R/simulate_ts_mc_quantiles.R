#' Simulate time series and per-time conditional quantiles
#'
#' Generates an observed time series \eqn{y_{1:T}} under several dynamics and,
#' for each step \eqn{t}, returns conditional quantiles
#' \eqn{Q_p\!\big(y_t \mid \mathcal F_{t-1}\big)} computed either analytically
#' (when available) or by Monte Carlo from the model-specific one-step predictive
#' distribution \eqn{y_t \mid y_{1:t-1}}.
#'
#' @section Scenarios:
#' \itemize{
#' \item \code{"ar1_exal"}:\; \eqn{y_t = \phi_1 y_{t-1} + \epsilon_t^{exAL}(p_0,\sigma,\gamma)}.
#' \item \code{"sin_exal"}:\; \eqn{y_t = a_1 y_{t-1} + b_1 \sin(2\pi t/P) + c + \epsilon_t^{exAL}}.
#' \item \code{"hetero_exal"}:\; \eqn{y_t = a_1 y_{t-1} + \epsilon_t^{exAL}(\sigma_t)},
#'   with \(\sigma_t = \sigma_0 + \sigma_1\,\mathrm{logit}^{-1}(\kappa y_{t-1})\).
#' \item \code{"regime_exal"}:\; \eqn{y_t = a_1 y_{t-1} + b\,\max(0,\sin(2\pi t/P)) + \epsilon_t^{exAL}}.
#' \item \code{"ar1_t"}:\; \eqn{y_t = \phi_1 y_{t-1} + \tau\,t_\nu} (Student-t noise).
#' \item \code{"dlm_constV_smallW"}:\; Gaussian DLM (linear trend + two harmonics) with
#'   constant observation variance \(V\) and small state noise \(W=\alpha\,\Sigma\).
#' \item \code{"dlm_constV_bigW"}:\; same DLM, larger \(\alpha\).
#' \item \code{"dlm_ar1V"}:\; same DLM but \(\log V_t\) follows AR(1), so quantiles are via MC.
#' }
#'
#' @details
#' \strong{exAL noise.} For \code{*_exal} scenarios, exAL\((p_0,\sigma,\gamma)\) is sampled via the
#' Gaussian mean–variance mixture with \(s\sim \mathcal N^+(0,1)\) and \(v\sim \mathrm{Exp}(1/\sigma)\),
#' yielding draws from \(\mathcal N\bigl(\mu_t + \lambda(\gamma)\sigma s + A(\gamma)v,\; B(\gamma)\sigma v\bigr)\).
#'
#' \strong{DLM specification.} The state \(\theta_t\in\mathbb R^6\) is
#' \([\text{level},\text{slope},\cos_1,\sin_1,\cos_2,\sin_2]^\top\),
#' with \(F=(1,0,1,0,1,0)^\top\) and \(G=\mathrm{bdiag}\!\bigl(\begin{smallmatrix}1&1\\0&1\end{smallmatrix},
#' R(\lambda_1),R(\lambda_2)\bigr)\), \(R(\lambda)=\begin{smallmatrix}(\cos\lambda,\sin\lambda;-\sin\lambda,\cos\lambda)\end{smallmatrix}\).
#' \(\theta_t \mid \theta_{t-1}\sim\mathcal N(G\theta_{t-1},W)\), \(y_t\mid\theta_t,V_t\sim\mathcal N(F^\top\theta_t,V_t)\).
#' For \code{dlm_constV_*}, \(V_t\equiv V\) and quantiles are analytic; for \code{dlm_ar1V},
#' \(\log V_t = \mu_v + \phi_v(\log V_{t-1}-\mu_v) + s_v\eta_t\) with \(\eta_t\sim\mathcal N(0,1)\) (quantiles via MC).
#'
#' \strong{Defaults (override via \code{params}).}
#' \itemize{
#' \item \code{ar1_exal}: \code{list(p0=0.5, phi1=0.6, sigma=1.0, gamma=0.0)}
#' \item \code{sin_exal}: \code{list(p0=0.5, a1=0.5, b1=0.3, period=50, c=0.0, sigma=1.0, gamma=0.0)}
#' \item \code{hetero_exal}: \code{list(p0=0.5, a1=0.5, sigma0=0.3, sigma1=0.4, kappa=1.0, gamma=0.0)}
#' \item \code{regime_exal}: \code{list(p0=0.5, a1=0.6, b=0.8, period=20, sigma=1.0, gamma=0.0)}
#' \item \code{ar1_t}: \code{list(phi1=0.6, tau=1.0, nu=5)}
#' \item \code{dlm\_*} (shared): \code{list(period=50L, m0=rep(0,6), C0=diag(25,6), V=0.5^2, alpha=1e-4 or 3e-3)};
#'   \code{dlm_ar1V} adds \code{list(mu_v=log(V), phi_v=0.95, s_v=0.25)}.
#' }
#'
#' @param T Integer; desired post-burn-in length.
#' @param p_grid Numeric vector of quantile levels in \((0,1)\). Duplicates are removed,
#'   sorted, and used for each \eqn{t}. Default: \code{c(0.10, 0.15, ..., 0.95, 0.50)}.
#' @param R_mc Integer; Monte Carlo draws per time step for quantiles when needed.
#' @param scenario Character; one of
#'   \code{c("ar1_exal","sin_exal","hetero_exal","regime_exal","ar1_t",
#'           "dlm_constV_smallW","dlm_constV_bigW","dlm_ar1V")}.
#' @param params Named list of scenario parameters (see Details for defaults).
#' @param burnin Integer; extra steps simulated and discarded as washout (default \code{500}).
#' @param seed Integer; RNG seed.
#' @param keep_latents Logical; if \code{TRUE}, returns conditional means \eqn{\mu_t}
#'   (and, for exAL scenarios, \(\sigma_t\)).
#' @param keep_draws Logical; if \code{TRUE}, returns the per-time Monte Carlo draws (large).
#'
#' @return A list with:
#' \itemize{
#' \item \code{y}: numeric vector (length \code{T}) of the observed series (post-burn-in).
#' \item \code{q}: \code{T x K} matrix of conditional quantiles (columns match \code{p}).
#' \item \code{p}: the quantile levels actually used.
#' \item \code{info}: list with \code{scenario}, \code{params}, \code{burnin}, \code{R_mc}, \code{seed}.
#' \item \code{extras} (optional): \code{mu} (and \code{sigma_t} for exAL); and if \code{keep_draws=TRUE},
#'   a list of length \code{T} with the Monte Carlo draws per time step.
#' }
#'
#' @note For \code{dlm_constV_*}, the one-step predictive is Normal with variance
#' \(F^\top R_t F + V\) (quantiles via \code{qnorm}). For \code{dlm_ar1V}, the predictive
#' is a Normal scale-mixture due to random \(V_t\) (quantiles via Monte Carlo).
#'
#' @references
#' West, M. & Harrison, J. (1997). \emph{Bayesian Forecasting and Dynamic Models}.  
#' Koenker, R. (2005). \emph{Quantile Regression}.
#'
#' @examples
#' set.seed(1)
#' out <- simulate_ts_mc_quantiles(
#'   T = 300, R_mc = 500, burnin = 200,
#'   scenario = "dlm_constV_smallW",
#'   params = list(V = 0.25, alpha = 1e-4)
#' )
#' str(out$q)
#'
#' @importFrom stats rnorm rt pnorm plogis qnorm quantile
#' @importFrom utils modifyList
#' @export
simulate_ts_mc_quantiles <- function(
  T,
  p_grid = sort(unique(c(seq(0.10, 0.95, by = 0.05), 0.50))),
  R_mc = 2000L,
  scenario = c("ar1_exal","sin_exal","hetero_exal","regime_exal","ar1_t",
             "dlm_constV_smallW","dlm_constV_bigW","dlm_ar1V"),
  params = NULL,
  burnin = 500L,
  seed = 123L,
  keep_latents = FALSE,
  keep_draws = FALSE
){
  # ---- checks ---------------------------------------------------------------
  T <- as.integer(T);           if (T <= 1L) stop("T must be >= 2.")
  burnin <- as.integer(burnin); if (burnin < 0L) stop("burnin must be >= 0.")
  R_mc <- as.integer(R_mc);     if (R_mc <= 0L) stop("R_mc must be >= 1.")
  scenario <- match.arg(scenario)
  p_grid <- sort(unique(as.numeric(p_grid)))
  if (any(p_grid <= 0 | p_grid >= 1)) stop("p_grid must be in (0,1).")

  set.seed(as.integer(seed))

  # ---- exAL helper functions (your definitions) -----------------------------
  # g(γ), p(γ), A(γ), B(γ), C(γ), λ(γ) with implicit dependence on p0
  make_exal_coeffs <- function(p0) {
    if (!(p0 > 0 && p0 < 1)) stop("p0 must be in (0,1).")
    g_fun <- function(gamma) 2 * pnorm(-abs(gamma)) * exp(gamma^2 / 2)
    p_fun <- function(gamma) as.numeric(gamma < 0) + (p0 - as.numeric(gamma < 0)) / g_fun(gamma)
    A_fun <- function(gamma) {
      p <- p_fun(gamma); (1 - 2 * p) / (p * (1 - p))
    }
    B_fun <- function(gamma) {
      p <- p_fun(gamma); 2 / (p * (1 - p))
    }
    C_fun <- function(gamma) {
      p <- p_fun(gamma); 1 / (as.numeric(gamma > 0) - p)
    }
    lambda_fun <- function(gamma) abs(gamma) * C_fun(gamma)
    list(A = A_fun, B = B_fun, lambda = lambda_fun)
  }

  # Draw exAL noise via mixture given (mu, sigma, gamma, p0), returns vector length n
  rexal_cond <- function(n, mu, sigma, gamma, p0, coeffs = NULL) {
    if (is.null(coeffs)) coeffs <- make_exal_coeffs(p0)
    A <- coeffs$A(gamma); B <- coeffs$B(gamma); lam <- coeffs$lambda(gamma)
    # s ~ N^+(0,1), v ~ Exp(rate = 1/sigma), Z ~ N(0,1)
    s <- abs(rnorm(n))
    v <- rexp(n, rate = 1 / sigma)
    z <- rnorm(n)
    mu + lam * sigma * s + A * v + sqrt(pmax(B * sigma * v, 0)) * z
  }

  # ---- defaults per scenario -----------------------------------------------
  # --- DLM shared defaults (trend + 2 harmonics) ---
  # period is user-tunable; m0, C0 are diffuse-ish; V for const-variance models
  dlm_defaults <- list(
    period = 50L,
    m0 = rep(0, 6),
    C0 = diag(25, 6),
    V  = 50^2,         # obs variance baseline
    alpha_small = 1e-4, # W = alpha * Sigma
    alpha_big   = 1
  )

  default_params <- switch(
    scenario,
    "ar1_exal"   = list(p0 = 0.5, phi1 = 0.6, sigma = 1.0, gamma = 0.0),
    "sin_exal"   = list(p0 = 0.5, a1 = 0.5, b1 = 0.3, period = 50, c = 0.0, sigma = 1.0, gamma = 0.0),
    "hetero_exal"= list(p0 = 0.5, a1 = 0.5, sigma0 = 0.3, sigma1 = 0.4, kappa = 1.0, gamma = 0.0),
    "regime_exal"= list(p0 = 0.5, a1 = 0.6, b = 0.8, period = 20, sigma = 1.0, gamma = 0.0),
    "ar1_t"      = list(phi1 = 0.6, tau = 1.0, nu = 5),

    "dlm_constV_smallW" = modifyList(dlm_defaults, list(alpha = dlm_defaults$alpha_small)),
    "dlm_constV_bigW"   = modifyList(dlm_defaults, list(alpha = dlm_defaults$alpha_big)),
    "dlm_ar1V"          = modifyList(dlm_defaults, list(
      # AR(1) for log-variance: log V_t = mu_v + phi (log V_{t-1} - mu_v) + s_v * eta_t
      alpha = dlm_defaults$alpha_small,
      mu_v  = log(dlm_defaults$V),
      phi_v = 0.95,
      s_v   = 0.1
    ))
  )

  if (is.null(params)) params <- default_params else {
    # Fill any missing entries from defaults
    for (nm in setdiff(names(default_params), names(params))) params[[nm]] <- default_params[[nm]]
  }

  # Pre-build exAL coeffs if needed
  exal_coeffs <- if (grepl("exal$", scenario)) make_exal_coeffs(params$p0) else NULL

  # ---- scenario-specific conditional draw & mu/sigma calculators ------------
  # Returns: list(y_draw = function(n, t, y_hist) -> numeric(n),
  #               mu_of = function(t, y_hist) -> numeric(1) or NA,
  #               sigma_of = function(t, y_hist) -> numeric(1) or NA)
  make_conditional <- function(scn, pr) {
    if (scn == "ar1_exal") {
      mu_of <- function(t, y_hist) pr$phi1 * tail(y_hist, 1L)
      sigma_of <- function(t, y_hist) pr$sigma
      y_draw <- function(n, t, y_hist) {
        mu <- mu_of(t, y_hist)
        rexal_cond(n, mu = mu, sigma = pr$sigma, gamma = pr$gamma, p0 = pr$p0, coeffs = exal_coeffs)
      }
      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of))
    }
    if (scn == "sin_exal") {
      mu_of <- function(t, y_hist) pr$a1 * tail(y_hist, 1L) + pr$b1 * sin(2 * pi * t / pr$period) + pr$c
      sigma_of <- function(t, y_hist) pr$sigma
      y_draw <- function(n, t, y_hist) {
        mu <- mu_of(t, y_hist)
        rexal_cond(n, mu = mu, sigma = pr$sigma, gamma = pr$gamma, p0 = pr$p0, coeffs = exal_coeffs)
      }
      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of))
    }
    if (scn == "hetero_exal") {
      mu_of <- function(t, y_hist) pr$a1 * tail(y_hist, 1L)
      sigma_of <- function(t, y_hist) pr$sigma0 + pr$sigma1 * plogis(pr$kappa * tail(y_hist, 1L))
      y_draw <- function(n, t, y_hist) {
        mu <- mu_of(t, y_hist); sig <- sigma_of(t, y_hist)
        rexal_cond(n, mu = mu, sigma = sig, gamma = pr$gamma, p0 = pr$p0, coeffs = exal_coeffs)
      }
      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of))
    }
    if (scn == "regime_exal") {
      mu_of <- function(t, y_hist) pr$a1 * tail(y_hist, 1L) + pr$b * max(0, sin(2 * pi * t / pr$period))
      sigma_of <- function(t, y_hist) pr$sigma
      y_draw <- function(n, t, y_hist) {
        mu <- mu_of(t, y_hist)
        rexal_cond(n, mu = mu, sigma = pr$sigma, gamma = pr$gamma, p0 = pr$p0, coeffs = exal_coeffs)
      }
      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of))
    }
    if (scn == "ar1_t") {
      mu_of <- function(t, y_hist) pr$phi1 * tail(y_hist, 1L)
      sigma_of <- function(t, y_hist) pr$tau
      y_draw <- function(n, t, y_hist) {
        mu <- mu_of(t, y_hist)
        mu + pr$tau * rt(n, df = pr$nu)
      }
      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of))
    }

    if (scn %in% c("dlm_constV_smallW","dlm_constV_bigW","dlm_ar1V")) {
      # Build F,G,Sigma (known), and set W = alpha * Sigma
      built <- build_dlm_trend2harm(pr$period)
      Fvec  <- built$F
      Gmat  <- built$G
      Sigma <- built$Sigma
      d     <- built$d
      alpha <- if (!is.null(pr$alpha)) as.numeric(pr$alpha) else 1e-4
      W     <- alpha * Sigma


      # env keeps forward-sim path for theta, logV, V
      env <- new.env(parent = emptyenv())
      env$theta_prev <- NULL
      env$V_path     <- NULL
      env$logV_path  <- NULL
      env$inited     <- FALSE

      # ----- initialization before forward simulation -----
      init <- function(T_tot) {
        # initial state ~ N(m0, C0)
        env$theta_prev <- as.numeric(rmvnorm_chol(1L, pr$m0, pr$C0))
        env$V_path     <- numeric(T_tot); env$V_path[] <- pr$V
        env$logV_path  <- numeric(T_tot); env$logV_path[] <- log(pr$V)
        env$inited     <- TRUE
      }

      # ----- draw y_t in two modes:
      # (A) SIMULATION mode (n=1): propagate theta, (log)V forward
      # (B) QUANTILES mode (n=R): sample from predictive y_t | y_{1:t-1}
      y_draw <- function(n, t, y_hist) {
        stopifnot(env$inited)

        # Mode A: generate the data forward (n==1 used by outer loop)
        if (n == 1L) {
          # Evolve theta_t
          a_th   <- as.numeric(Gmat %*% env$theta_prev)
          theta  <- as.numeric(rmvnorm_chol(1L, a_th, W))

          # Observation variance
          if (scn == "dlm_ar1V") {
            mu_v    <- pr$mu_v; phi <- pr$phi_v; s_v <- pr$s_v
            logV_t  <- mu_v + phi * (env$logV_path[t - 1L] - mu_v) + s_v * rnorm(1)
            V_t     <- as.numeric(exp(logV_t))
            env$logV_path[t] <- logV_t; env$V_path[t] <- V_t
          } else {
            V_t     <- pr$V
            env$V_path[t] <- V_t
          }

          # Emit y_t
          mu_y <- sum(Fvec * theta)
          y    <- rnorm(1L, mean = mu_y, sd = sqrt(V_t))

          # Book-keeping
          env$theta_prev <- theta

          return(y)
        }

        # Mode B: predictive draws for quantiles (n>1)
        # 1) Filter y_{1:t-1} to obtain a_t, R_t
        V_seq <- if (scn == "dlm_ar1V") env$V_path[1:(t - 1L)] else pr$V
        kfp   <- kf_predict_from_yhist(y_hist, Fvec, Gmat, W, V_seq, pr$m0, pr$C0)
        a_t   <- kfp$a
        R_t   <- kfp$R
        f_t   <- kfp$f
        # For const-V models, S = F' R F + V is known -> we could sample directly,
        # but we’ll sample theta & (maybe) V_t for code uniformity.

        # 2) Draw theta_t ~ N(a_t, R_t)
        L_R   <- chol(R_t, pivot = FALSE)
        Z     <- matrix(rnorm(d * n), d, n)
        thetas <- sweep(L_R %*% Z, 1L, a_t, `+`)       # (d x n)
        Ft_th  <- as.numeric(crossprod(Fvec, thetas))  # length n

        # 3) Draw V_t
        if (scn == "dlm_ar1V") {
          mu_v   <- pr$mu_v; phi <- pr$phi_v; s_v <- pr$s_v
          logV_1 <- env$logV_path[t - 1L]
          logV   <- mu_v + phi * (logV_1 - mu_v) + s_v * rnorm(n)
          Vdraw  <- as.numeric(exp(logV))
        } else {
          Vdraw  <- rep.int(pr$V, n)
        }

        # 4) Draw y_t | theta_t, V_t
        rnorm(n, mean = Ft_th, sd = sqrt(Vdraw))
      }

      # ----- conditional mean/variance at time t given y_{1:t-1} -----
      # For plotting (mu) and for analytic quantiles when V is constant
      mu_of <- function(t, y_hist) {
        V_seq <- if (scn == "dlm_ar1V") env$V_path[1:(t - 1L)] else pr$V
        kf <- kf_predict_from_yhist(y_hist, Fvec, Gmat, W, V_seq, pr$m0, pr$C0)
        kf$f
      }

      # For constant-V models: exact quantiles via Normal(f, S_woV + V)
      q_of <- NULL
      if (scn %in% c("dlm_constV_smallW","dlm_constV_bigW")) {
        q_of <- function(p_vec, t, y_hist) {
          kf <- kf_predict_from_yhist(y_hist, Fvec, Gmat, W, pr$V, pr$m0, pr$C0)
          f  <- kf$f
          S  <- kf$S_woV + pr$V
          stats::qnorm(p_vec, mean = f, sd = sqrt(S))
        }
      }

      # sigma_of not very meaningful here (was exAL’s scale); omit/NA
      sigma_of <- function(t, y_hist) NA_real_

      return(list(y_draw = y_draw, mu_of = mu_of, sigma_of = sigma_of,
                  q_of = q_of, init = init))
    }

    stop("Unknown scenario.")
  }

  cond <- make_conditional(scenario, params)

  if (!is.null(cond$init) && is.function(cond$init)) {
    cond$init(burnin + T)
  }

  # ---- simulate forward (burn-in + T) ---------------------------------------
  T_tot <- burnin + T
  y <- numeric(T_tot)
  # Reasonable initialization
  y[1] <- 0
  for (t in 2:T_tot) {
    # draw 1 observation given history (uses same conditional draw function)
    y[t] <- cond$y_draw(n = 1L, t = t, y_hist = y[1:(t - 1)])[1]
  }
  # Drop burn-in
  y_obs <- y[(burnin + 1):T_tot]
  # Build full history vector to pass when computing per-time quantiles
  # (includes burn-in so that t's history is correct)
  y_full <- y

  # ---- per-time Monte Carlo quantiles ---------------------------------------
  K <- length(p_grid)
  Q_mat <- matrix(NA_real_, nrow = T, ncol = K)
  colnames(Q_mat) <- sprintf("q_%g", p_grid)

  # Optional collectors
  mu_vec <- if (keep_latents) numeric(T) else NULL
  sig_vec <- if (keep_latents && !is.null(exal_coeffs)) numeric(T) else NULL
  draws_list <- if (keep_draws) vector("list", length = T) else NULL

  for (tt in seq_len(T)) {
    # Map tt (post-burn-in index) to absolute time index in y_full
    t_abs <- burnin + tt
    y_hist <- y_full[1:(t_abs - 1)]

    # For bookkeeping
    if (keep_latents) {
      mu_vec[tt] <- cond$mu_of(t_abs, y_hist)
      if (!is.null(sig_vec)) sig_vec[tt] <- cond$sigma_of(t_abs, y_hist)
    }

    if (!is.null(cond$q_of) && is.function(cond$q_of)) {
      # Exact Normal quantiles (DLM with constant V)
      Q_mat[tt, ] <- cond$q_of(p_grid, t_abs, y_hist)
    } else {
      # Monte Carlo (exAL scenarios and DLM with AR(1) variance)
      draws <- cond$y_draw(n = R_mc, t = t_abs, y_hist = y_hist)
      Q_mat[tt, ] <- as.numeric(stats::quantile(draws, probs = p_grid, names = FALSE, type = 7))
      if (keep_draws) draws_list[[tt]] <- draws
    }
  }

  out <- list(
    y   = y_obs,
    q   = Q_mat,
    p   = p_grid,
    info = list(scenario = scenario, params = params, burnin = burnin, R_mc = R_mc, seed = seed)
  )

  if (keep_latents || keep_draws) {
    extras <- list()
    if (keep_latents) {
      extras$mu <- mu_vec
      if (!is.null(sig_vec)) extras$sigma_t <- sig_vec
    }
    if (keep_draws) extras$draws <- draws_list
    out$extras <- extras
  }

  class(out) <- "ts_mc_quantiles"
  out
}

#' @noRd
#' @keywords internal
rmvnorm_chol <- function(n, mean, Sigma) {
  d <- length(mean)
  L <- chol(Sigma, pivot = FALSE)
  Z <- matrix(rnorm(d * n), d, n)
  sweep(L %*% Z, 1L, mean, FUN = `+`)
}

#' @noRd
#' @keywords internal
# State order: [level, slope, (cos1, sin1), (cos2, sin2)]
build_dlm_trend2harm <- function(period) {
  stopifnot(period > 2)
  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1

  # F is constant; select the 1st element in each harmonic pair
  F <- c(1, 0, 1, 0, 1, 0)         # length 6

  # G is block-diagonal: local linear trend + two rotation blocks
  G_trend <- matrix(c(1, 1,
                      0, 1), 2, 2, byrow = TRUE)
  R1 <- matrix(c(cos(lam1),  sin(lam1),
                -sin(lam1),  cos(lam1)), 2, 2, byrow = TRUE)
  R2 <- matrix(c(cos(lam2),  sin(lam2),
                -sin(lam2),  cos(lam2)), 2, 2, byrow = TRUE)

  G <- as.matrix(Matrix::bdiag(G_trend, R1, R2))
  d <- length(F)

  # Default Sigma (known, scaled by alpha in W = alpha * Sigma)
  Sigma <- diag(d)

  list(F = F, G = G, Sigma = Sigma, d = d)
}


#' @noRd
#' @keywords internal
# Returns f_t, S_woV, a_t, R_t given y_{1:t-1}
kf_predict_from_yhist <- function(y_hist, F, G, W, V_seq, m0, C0) {
  d <- length(F)
  m <- m0
  C <- C0

  Tm1 <- length(y_hist)
  if (length(V_seq) == 1L) V_seq <- rep(V_seq, Tm1)

  for (k in seq_len(Tm1)) {
    # Predict to k
    a <- as.numeric(G %*% m)
    R <- G %*% C %*% t(G) + W
    f <- sum(F * a)
    S <- as.numeric(crossprod(F, R %*% F) + V_seq[k])

    # Update with y_k
    e <- y_hist[k] - f
    K <- as.numeric(1 / S) * (R %*% F)          # (d x 1)
    m <- a + K * e
    C <- R - tcrossprod(K) * S                  # numerically stable form
  }

  # Predict to time t (= Tm1 + 1)
  a_t <- as.numeric(G %*% m)
  R_t <- G %*% C %*% t(G) + W
  f_t <- sum(F * a_t)
  S_t <- as.numeric(crossprod(F, R_t %*% F))    # NOTE: no V_t here yet

  list(f = f_t, S_woV = S_t, a = a_t, R = R_t)
}
