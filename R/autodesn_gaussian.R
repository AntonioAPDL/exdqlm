# Gaussian AutoDESN: finite-bank Gaussian readout selection.
# Model: y | beta,m,s2 ~ N(X_m beta, s2 I);
# beta[1] ~ N(0,v0); beta[-1] | lambda ~ N(0,I/lambda);
# s2 ~ IG(a_sigma,b_sigma); lambda ~ Gamma(a_lambda,b_lambda), rate form.
# Features are divided by sqrt(the number of slopes) BEFORE applying this prior.
# The finite candidate bank, its probabilities, and preprocessing are fixed.

.autodesn_seed <- function(seed, fun) {
  if (is.null(seed)) return(fun())
  .autodesn_integer(seed, "seed", 0L)
  had <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had) old <- get(".Random.seed", envir = .GlobalEnv)
  on.exit(if (had) assign(".Random.seed", old, envir = .GlobalEnv) else
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(".Random.seed", envir = .GlobalEnv))
  if (!is.null(seed)) set.seed(seed)
  fun()
}

.autodesn_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(name, " must be TRUE or FALSE.", call. = FALSE)
  }
}

.autodesn_positive <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0)
    stop(name, " must be one positive finite number.")
}

.autodesn_integer <- function(x, name, lower = 1L) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x != floor(x) || x < lower)
    stop(name, " must be an integer >= ", lower, ".")
}

.autodesn_softmax <- function(x) {
  if (!any(is.finite(x))) stop("No candidate has finite log weight.")
  z <- exp(x - max(x))
  z / sum(z)
}

#' Prepare a finite bank of Gaussian readout designs
#'
#' The matrices contain slopes only; one proper Gaussian intercept is added.
#' Autoregressive designs define a conditional likelihood. The caller must use
#' common response rows and frozen preprocessing for every candidate.
#'
#' @param y Finite numeric response on a common conditioning window.
#' @param features Nonempty list of numeric slope matrices with length(y) rows.
#' @param model_info Optional data frame with one row per candidate.
#' @param model_prior Positive prior masses, normalized to sum to one.
#' @param normalize_features Divide slopes by the square root of their count.
#' @param standardize_features Center and scale each slope using the supplied training rows.
#'   Constant columns (SD <= feature_sd_tol) are excluded with a frozen mask.
#' @param feature_sd_tol Positive threshold for constant training columns.
#' @return An `autodesn_bank`. Use [autodesn_build_bank()] for recursive forecasts.
#' @export
autodesn_prepare_bank <- function(y, features, model_info = NULL, model_prior = NULL,
                                  normalize_features = TRUE, standardize_features = FALSE,
                                  feature_sd_tol = 1e-8) {
  .autodesn_flag(normalize_features, "normalize_features")
  .autodesn_flag(standardize_features, "standardize_features")
  .autodesn_positive(feature_sd_tol, "feature_sd_tol")
  y <- as.numeric(y)
  if (length(y) < 2L || any(!is.finite(y))) stop("y must be finite, length >= 2.")
  if (!is.list(features) || !length(features)) stop("features must be a nonempty list.")
  n <- length(y)
  models <- lapply(seq_along(features), function(j) {
    H <- as.matrix(features[[j]])
    if (!is.numeric(H)) stop("Feature matrices must be numeric.", call. = FALSE)
    if (nrow(H) != n || any(!is.finite(H)))
      stop("Every feature matrix must be finite and have length(y) rows.")
    geometry <- .autodesn_feature_fit(H, standardize_features, feature_sd_tol)
    H <- geometry$features
    d <- ncol(H)
    divisor <- if (normalize_features && d > 0L) sqrt(d) else 1
    F <- H / divisor
    X <- cbind(intercept = 1, F)
    if (d > 0L) {
      decomp <- svd(F, nu = min(n, d), nv = 0L)
      U <- decomp$u
      uy <- as.vector(crossprod(U, y))
      u1 <- as.vector(crossprod(U, rep(1, n)))
      ry <- y - as.vector(U %*% uy)
      r1 <- rep(1, n) - as.vector(U %*% u1)
      spectrum <- decomp$d^2
    } else {
      uy <- u1 <- spectrum <- numeric(0)
      ry <- y
      r1 <- rep(1, n)
    }
    geometry$features <- NULL
    c(list(X = X, d = d, divisor = divisor, XtX = crossprod(X),
         Xty = as.vector(crossprod(X, y)), spectrum = spectrum,
         uy = uy, u1 = u1, ry2 = sum(ry^2), r12 = sum(r1^2),
         r1y = sum(r1 * ry), n = n), geometry)
  })
  M <- length(models)
  if (is.null(model_prior)) model_prior <- rep(1 / M, M)
  prior <- model_prior
  if (!is.numeric(prior) || length(prior) != M || any(!is.finite(prior)) || any(prior <= 0))
    stop("prior must have one strictly positive value per candidate.")
  total_prior <- sum(prior)
  if (!is.finite(total_prior)) {
    prior <- prior / max(prior)
    total_prior <- sum(prior)
  }
  prior <- prior / total_prior
  if (is.null(model_info)) model_info <- data.frame(model = seq_len(M))
  if (!is.data.frame(model_info) || nrow(model_info) != M) stop("model_info must have one row per candidate.")
  structure(list(y = y, models = models, model_info = model_info,
                 prior = prior, n = n, normalize_features = normalize_features,
                 standardize_features = standardize_features, feature_sd_tol = feature_sd_tol),
            class = "autodesn_bank")
}

# Exact beta-integrated density conditional on variance and ridge precision.
# SVD plus a rank-one intercept update makes each score O(min(n,d)).
# This is NOT an integral over variance, ridge precision, or unlisted reservoirs.
.autodesn_log_evidence <- function(model, variance, ridge_precision,
                                  intercept_variance = 10) {
  .autodesn_positive(variance, "variance")
  .autodesn_positive(ridge_precision, "ridge_precision")
  .autodesn_positive(intercept_variance, "intercept_variance")
  den <- variance + model$spectrum / ridge_precision
  q1 <- model$r12 / variance + sum(model$u1^2 / den)
  c1y <- model$r1y / variance + sum(model$u1 * model$uy / den)
  mu0 <- c1y / (1 / intercept_variance + q1)
  # Positive decomposition of the quadratic avoids subtracting two large fits.
  residual_q <- model$ry2 - 2 * mu0 * model$r1y + mu0^2 * model$r12
  tolerance <- 1e-10 * max(1, model$ry2, mu0^2 * model$r12)
  if (residual_q < -tolerance) stop("Unstable evidence quadratic.")
  quadratic <- max(0, residual_q) / variance +
    sum((model$uy - mu0 * model$u1)^2 / den) +
    mu0^2 / intercept_variance
  logdet <- (model$n - length(den)) * log(variance) + sum(log(den)) +
    log1p(intercept_variance * q1)
  -0.5 * (model$n * log(2 * pi) + logdet + quadratic)
}

.autodesn_model_probabilities <- function(bank, variance, ridge_precision,
                                         intercept_variance = 10) {
  log_evidence <- vapply(bank$models, .autodesn_log_evidence, numeric(1),
                         variance = variance, ridge_precision = ridge_precision,
                         intercept_variance = intercept_variance)
  .autodesn_softmax(log(bank$prior) + log_evidence)
}

.autodesn_beta_conditional <- function(model, variance, ridge_precision,
                                  intercept_variance, draw = TRUE) {
  P <- model$XtX / variance +
    diag(c(1 / intercept_variance, rep(ridge_precision, model$d)),
         nrow = model$d + 1L)
  R <- chol(P)
  mu <- backsolve(R, forwardsolve(t(R), model$Xty / variance))
  if (!draw) return(list(mean = as.vector(mu), precision_chol = R))
  as.vector(mu + backsolve(R, stats::rnorm(length(mu))))
}

#' Fit a Gaussian AutoDESN bank with a ridge or RHS readout
#'
#' Each sweep jointly updates model and coefficients by sampling the model
#' with coefficients integrated out, then immediately redrawing coefficients.
#' Variance and prior scales follow. Ridge uses a full categorical model scan;
#' RHS uses collapsed Metropolis model moves by default, with a full categorical
#' scan available as a reference. Coefficient priors
#' are independent of observation variance, unlike `normal_desn_fit()`'s
#' scaled-ridge prior. No reversible-jump or particle approximation is used.
#'
#' @param bank An `autodesn_bank`.
#' @param n_burn Number of discarded sweeps.
#' @param n_mcmc Number of post-burn sweeps before thinning.
#' @param thin Retain every thin-th post-burn sweep, starting with the first.
#' @param variance_control Optional constant/SV controls for a standardized augmented bank.
#' @param intercept_variance Proper intercept prior variance.
#' @param a_sigma,b_sigma Inverse-gamma shape and rate for observation variance.
#' @param a_lambda,b_lambda Gamma shape and rate for global slope precision.
#' @param learn_ridge Update global slope precision if TRUE; otherwise fix it.
#' @param ridge_precision Initial or fixed slope precision.
#' @param initial_variance Optional starting observation variance.
#' @param seed Optional seed, with the caller's RNG state restored.
#' @param beta_prior Readout prior: `"ridge"` (the unchanged default) or the
#'   normalized regularized horseshoe `"rhs"`. Both are independent of the
#'   observation variance; the intercept retains its own proper Gaussian prior.
#' @param rhs_control Named controls from [autodesn_rhs_control()], or a named
#'   list of its arguments. Used only with `beta_prior = "rhs"`.
#' @param model_control RHS architecture sampler controls: `method` (`"mh"` or
#'   `"categorical"`), `moves`, full-support `proposal` probabilities,
#'   `rb_every`, and `initial_model`. See the RHS guide for their meaning.
#' @param backend RHS linear algebra backend: `"auto"`, `"R"`, or `"cpp"`.
#'   Auto uses the compiled implementation when available. Ridge retains its
#'   existing SVD implementation and accepts `"auto"` or `"R"`.
#' @return An `autodesn_fit` with joint draws and model probability estimates.
#' @export
autodesn_fit_bank <- function(bank, n_burn = 1500L, n_mcmc = 3000L, thin = 1L,
                         intercept_variance = 10,
                         a_sigma = 3, b_sigma = 1,
                         a_lambda = 2, b_lambda = 2,
                         learn_ridge = TRUE, ridge_precision = 1,
                         initial_variance = NULL, seed = NULL,
                         beta_prior = c("ridge", "rhs"), rhs_control = list(),
                         model_control = list(), backend = c("auto", "R", "cpp"),
                         variance_control = NULL) {
  beta_prior <- match.arg(beta_prior)
  if (identical(backend, "r")) backend <- "R"
  backend <- match.arg(backend)
  if (inherits(bank, "autodesn_extended_bank") || !is.null(variance_control)) {
    return(.ext_fit(bank, n_burn, n_mcmc, thin, intercept_variance, a_sigma, b_sigma,
      a_lambda, b_lambda, learn_ridge, ridge_precision, initial_variance, seed,
      beta_prior, rhs_control, model_control, backend, variance_control))
  }
  if (beta_prior == "rhs") {
    if (!missing(a_lambda) || !missing(b_lambda) || !missing(learn_ridge) ||
        !missing(ridge_precision)) {
      stop("Ridge-specific controls are not used by RHS; set rhs_control instead.", call. = FALSE)
    }
    return(.autodesn_fit_rhs_bank(bank = bank, n_burn = n_burn,
      n_mcmc = n_mcmc, thin = thin, intercept_variance = intercept_variance,
      a_sigma = a_sigma, b_sigma = b_sigma, initial_variance = initial_variance,
      seed = seed, rhs_control = rhs_control, model_control = model_control,
      backend = backend))
  }
  if (length(rhs_control) || length(model_control)) {
    stop("rhs_control and model_control require beta_prior = 'rhs'.", call. = FALSE)
  }
  if (backend == "cpp") stop("The ridge sampler uses its existing R/SVD backend; use backend = 'auto' or 'R'.", call. = FALSE)
  if (!inherits(bank, "autodesn_bank")) stop("Use autodesn_prepare_bank() or autodesn_build_bank() first.")
  .autodesn_flag(learn_ridge, "learn_ridge")
  .autodesn_integer(n_burn, "n_burn", 0L)
  .autodesn_integer(n_mcmc, "n_mcmc")
  iterations <- n_burn + n_mcmc
  burnin <- n_burn
  .autodesn_integer(iterations, "iterations")
  .autodesn_integer(burnin, "burnin", 0L)
  .autodesn_integer(thin, "thin")
  if (burnin >= iterations) stop("burnin must be smaller than iterations.")
  for (nm in c("intercept_variance", "a_sigma", "b_sigma", "a_lambda",
               "b_lambda", "ridge_precision")) .autodesn_positive(get(nm), nm)
  if (is.null(initial_variance)) initial_variance <- max(stats::var(bank$y), 0.01)
  .autodesn_positive(initial_variance, "initial_variance")
  retained <- seq.int(burnin + 1L, iterations, by = thin)
  keep <- logical(iterations)
  keep[retained] <- TRUE
  K <- length(retained)
  .autodesn_seed(seed, function() {
    draws <- data.frame(iteration = retained, model = integer(K),
                        variance = numeric(K), ridge_precision = numeric(K))
    beta <- vector("list", K)
    conditional_probabilities <- matrix(NA_real_, K, length(bank$models))
    variance <- initial_variance
    lambda <- ridge_precision
    k <- 0L
    for (it in seq_len(iterations)) {
      p <- .autodesn_model_probabilities(bank, variance, lambda, intercept_variance)
      j <- sample.int(length(p), 1L, prob = p)
      model <- bank$models[[j]]
      b <- .autodesn_beta_conditional(model, variance, lambda, intercept_variance)
      residual <- bank$y - as.vector(model$X %*% b)
      variance <- 1 / stats::rgamma(1L, shape = a_sigma + bank$n / 2,
                             rate = b_sigma + sum(residual^2) / 2)
      if (isTRUE(learn_ridge)) lambda <- stats::rgamma(1L, shape = a_lambda + model$d / 2,
                                        rate = b_lambda + sum(b[-1L]^2) / 2)
      if (keep[it]) {
        k <- k + 1L
        draws[k, c("model", "variance", "ridge_precision")] <- c(j, variance, lambda)
        beta[[k]] <- b
        # These probabilities are from the model-update substep. Their average
        # estimates marginal model probabilities; they are not conditional on
        # the variance/lambda values stored AFTER the remaining Gibbs substeps.
        conditional_probabilities[k, ] <- p
      }
    }
    posterior <- colMeans(conditional_probabilities)
    occupancy <- tabulate(draws$model, nbins = length(posterior)) / K
    model_summary <- cbind(bank$model_info, prior_probability = bank$prior,
                            posterior_probability = posterior, occupancy = occupancy)
    structure(list(bank = bank, draws = draws, beta = beta,
                   conditional_probabilities = conditional_probabilities,
                   model_summary = model_summary,
                   controls = list(n_burn = n_burn, n_mcmc = n_mcmc,
                     thin = thin, intercept_variance = intercept_variance,
                     a_sigma = a_sigma, b_sigma = b_sigma,
                     a_lambda = a_lambda, b_lambda = b_lambda,
                     learn_ridge = learn_ridge, ridge_precision = ridge_precision,
                     initial_variance = initial_variance, seed = seed),
                   meta = utils::modifyList(if (is.null(bank$meta)) list() else bank$meta,
                     list(inference_method = "blocked_gibbs",
                     likelihood_family = "normal", target = "conditional_mean",
                     beta_prior_type = "independent_ridge"))),
              class = "autodesn_fit")
  })
}
