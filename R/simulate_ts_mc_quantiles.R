#' Simulate Time Series + Monte Carlo Conditional Quantiles (per time t)
#'
#' Generates an observed time series \eqn{y_{1:T}} under several non-trivial
#' dynamics and, for each time step \eqn{t}, approximates the conditional
#' quantiles \eqn{Q_p(y_t \mid \mathcal F_{t-1})} by Monte Carlo draws from the
#' model-specific conditional distribution of \eqn{y_t} given the realized past.
#'
#' Built-in scenarios (set via `scenario`):
#' * `"ar1_exal"`:       \eqn{y_t = \phi_1 y_{t-1} + \epsilon_t^{exAL}(p_0, \sigma, \gamma)}
#' * `"sin_exal"`:       \eqn{y_t = a_1 y_{t-1} + b_1 \sin(2\pi t/P) + c + \epsilon_t^{exAL}}
#' * `"hetero_exal"`:    \eqn{y_t = a_1 y_{t-1} + \epsilon_t^{exAL}(\sigma_t)}, \ \(\sigma_t = \sigma_0 + \sigma_1\,\mathrm{logit}^{-1}(\kappa y_{t-1})\)
#' * `"regime_exal"`:    \eqn{y_t = a_1 y_{t-1} + b\,\max(0, \sin(2\pi t/P)) + \epsilon_t^{exAL}}
#' * `"ar1_t"`:          \eqn{y_t = \phi_1 y_{t-1} + \tau\,t_\nu} (Student-t noise; shows non-exAL)
#'
#' For `*_exal` scenarios, the exAL(p0, sigma, gamma) noise is simulated via the
#' Gaussian–mean–variance mixture:
#' \deqn{ s \sim \mathcal N^+(0,1),\quad v \sim \mathrm{Exp}(\text{rate}=1/\sigma),\quad
#'        y_t \mid \cdot \sim \mathcal N\!\big(\mu_t + \lambda(\gamma)\sigma s + A(\gamma)v,\; B(\gamma)\sigma v\big), }
#' where \eqn{A,B,\lambda} follow your definitions and implicitly depend on \eqn{p_0}.
#'
#' @param T Integer; desired post-burn-in length.
#' @param p_grid Numeric vector of quantile levels in (0,1). Duplicates are removed,
#'   sorted, and used for each t. Defaults to c(0.10, 0.15, ..., 0.90, 0.95, 0.50).
#' @param R_mc Integer; Monte Carlo draws per time t to estimate the conditional quantiles.
#' @param scenario Character; one of c("ar1_exal","sin_exal","hetero_exal","regime_exal","ar1_t").
#' @param params Named list of scenario parameters. See Details below for defaults.
#' @param burnin Integer; extra steps simulated and discarded as washout (default 500).
#' @param seed Integer; RNG seed for reproducibility.
#' @param keep_latents Logical; if TRUE and exAL scenario, returns \eqn{\mu_t}, \eqn{\sigma_t}.
#' @param keep_draws Logical; if TRUE, returns per-time Monte Carlo draws (large!).
#'
#' @details
#' **Defaults per scenario (override via `params`):**
#' * `ar1_exal`:  `list(p0=0.5, phi1=0.6, sigma=1.0, gamma=0.0)`
#' * `sin_exal`:  `list(p0=0.5, a1=0.5, b1=0.3, period=50, c=0.0, sigma=1.0, gamma=0.0)`
#' * `hetero_exal`: `list(p0=0.5, a1=0.5, sigma0=0.3, sigma1=0.4, kappa=1.0, gamma=0.0)`
#' * `regime_exal`: `list(p0=0.5, a1=0.6, b=0.8, period=20, sigma=1.0, gamma=0.0)`
#' * `ar1_t`:     `list(phi1=0.6, tau=1.0, nu=5)`
#'
#' Quantiles are computed by `stats::quantile(..., type = 7, names = FALSE)`.
#'
#' @return A list with
#' \itemize{
#'   \item \code{y}: numeric vector (length T) of the observed series (post-burn-in).
#'   \item \code{q}: numeric matrix (T x K) of MC quantile estimates; columns match \code{p}.
#'   \item \code{p}: the quantile levels actually used.
#'   \item \code{info}: list with `scenario`, `params`, `burnin`, `R_mc`, `seed`.
#'   \item \code{extras} (optional): for exAL scenarios and \code{keep_latents=TRUE},
#'         returns `mu`, `sigma_t`; and if \code{keep_draws=TRUE}, a list of length T
#'         with the MC draws for each t (warning: large).
#' }
#' @export
simulate_ts_mc_quantiles <- function(
  T,
  p_grid = sort(unique(c(seq(0.10, 0.95, by = 0.05), 0.50))),
  R_mc = 2000L,
  scenario = c("ar1_exal","sin_exal","hetero_exal","regime_exal","ar1_t"),
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
  default_params <- switch(
    scenario,
    "ar1_exal" = list(p0 = 0.5, phi1 = 0.6, sigma = 1.0, gamma = 0.0),
    "sin_exal" = list(p0 = 0.5, a1 = 0.5, b1 = 0.3, period = 50, c = 0.0, sigma = 1.0, gamma = 0.0),
    "hetero_exal" = list(p0 = 0.5, a1 = 0.5, sigma0 = 0.3, sigma1 = 0.4, kappa = 1.0, gamma = 0.0),
    "regime_exal" = list(p0 = 0.5, a1 = 0.6, b = 0.8, period = 20, sigma = 1.0, gamma = 0.0),
    "ar1_t" = list(phi1 = 0.6, tau = 1.0, nu = 5)
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
    stop("Unknown scenario.")
  }

  cond <- make_conditional(scenario, params)

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

    # Draw R_mc samples of y_t | history
    draws <- cond$y_draw(n = R_mc, t = t_abs, y_hist = y_hist)

    # Empirical quantiles for all p
    Q_mat[tt, ] <- as.numeric(stats::quantile(draws, probs = p_grid, names = FALSE, type = 7))

    if (keep_draws) draws_list[[tt]] <- draws
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
