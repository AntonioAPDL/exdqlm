#' exAL Diagnostics
#'
#' Static diagnostics companion for \code{exalStaticLDVB()} and
#' \code{exalStaticMCMC()}. The function summarizes fitted quantiles on a
#' shared design matrix, reports mean check loss against observed responses when
#' available, and can optionally compare the fitted quantile curve against a
#' known reference quantile function. The returned diagnostic object also stores
#' posterior summaries for the static regression coefficients, which can be
#' plotted with \code{plot(..., type = "coefficients")}.
#'
#' @param m1 A fitted static \code{exalStaticFit} object, such as an object
#'   returned by \code{\link{exalStaticLDVB}} or
#'   \code{\link{exalStaticMCMC}}.
#' @param m2 Optional second fitted static \code{exalStaticFit} object to
#'   compare against \code{m1}.
#' @param X Optional design matrix. If omitted, the function uses \code{m1$X}
#'   when available.
#' @param y Optional response vector. If omitted, the function uses \code{m1$y}
#'   when available.
#' @param ref Optional reference quantile vector on the same rows as \code{X}.
#' @param plot Logical; if \code{TRUE}, immediately plot the returned
#'   static-diagnostic object as a convenience shortcut. Default is
#'   \code{FALSE}; the preferred workflow is to save the object and then call
#'   \code{plot()} on it.
#' @param cols Character vector of length 1 or 2 giving colors for plotted
#'   diagnostics.
#' @param cr.percent Credible-interval mass used when summarizing fitted
#'   quantiles.
#'
#' @details
#' Unlike \code{\link{exdqlmDiagnostics}}, which is built around one-step-ahead
#' dynamic forecast diagnostics, \code{exalStaticDiagnostics()} is designed for the
#' static regression setting. It reports fitted quantile summaries on a common
#' design matrix, optional mean check loss against observed responses, optional
#' reference-curve errors, coefficient posterior summaries, and compact
#' comparison plots. The returned object can be printed, summarized, or plotted
#' with standard methods. The \code{ref} argument is a reference conditional quantile
#' evaluated on the rows of \code{X}; it is distinct from the optional
#' \code{beta.ref} argument of \code{\link{plot.exalStaticDiagnostic}}, which is
#' used only to overlay known coefficient values in simulation examples.
#'
#' @return An object of class \code{"exalStaticDiagnostic"} containing fitted-quantile
#'   summaries, residual summaries (when \code{y} is provided), optional
#'   reference-curve error metrics, coefficient posterior summaries, and
#'   run-time metadata for \code{m1} and \code{m2} (if supplied).
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' x <- seq(-2, 2, length.out = 60)
#' X <- cbind(1, x)
#' y <- 0.5 * x + (1.2 + 0.35 * x) * stats::rnorm(length(x))
#' q_true <- 0.5 * x + (1.2 + 0.35 * x) * stats::qnorm(0.25)
#'
#' fit_ldvb <- exalStaticLDVB(
#'   y = y, X = X, p0 = 0.25,
#'   max_iter = 60, tol = 1e-3,
#'   verbose = FALSE
#' )
#' fit_mcmc <- exalStaticMCMC(
#'   y = y, X = X, p0 = 0.25,
#'   n.burn = 60, n.mcmc = 60,
#'   mh.proposal = "slice",
#'   verbose = FALSE
#' )
#' out <- exalStaticDiagnostics(fit_ldvb, fit_mcmc, ref = q_true)
#' out
#' plot(out)
#' plot(out, type = "coefficients")
#' }
#' @export
exalStaticDiagnostics <- function(m1, m2 = NULL, X = NULL, y = NULL, ref = NULL,
                            plot = FALSE, cols = c("red", "blue"),
                            cr.percent = 0.95) {
  plot <- .exdqlm_validate_plot_flag(plot)

  is_static_fit <- is.exalStaticFit

  resolve_X <- function(fit, X_arg) {
    X_use <- if (!is.null(X_arg)) X_arg else fit$X
    if (is.null(X_use)) {
      stop(
        "Design matrix X must be supplied either explicitly or inside the fitted object.",
        call. = FALSE
      )
    }
    as.matrix(X_use)
  }

  x_axis_from_X <- function(X_use) {
    if (ncol(X_use) >= 2L && all(is.finite(X_use[, 2L]))) {
      as.numeric(X_use[, 2L])
    } else {
      seq_len(nrow(X_use))
    }
  }

  beta_names_from_X <- function(X_use, p) {
    nms <- colnames(X_use)
    if (is.null(nms) || length(nms) != p || any(!nzchar(nms))) {
      nms <- paste0("beta", seq_len(p) - 1L)
      if (p > 0L) nms[1L] <- "(Intercept)"
    }
    nms
  }

  summarize_fit <- function(fit, X_use, y_use, ref_use, cr.percent) {
    if (cr.percent <= 0 || cr.percent >= 1) {
      stop("cr.percent must be between 0 and 1.", call. = FALSE)
    }
    if (nrow(X_use) < 1L) {
      stop("X must have at least one row.", call. = FALSE)
    }

    half.alpha <- (1 - cr.percent) / 2
    upper <- 1 - half.alpha

    if (is.exalStaticMCMC(fit)) {
      beta_draws <- as.matrix(fit$samp.beta)
      if (ncol(beta_draws) != ncol(X_use)) {
        stop("Number of beta coefficients in the fitted object must match ncol(X).", call. = FALSE)
      }
      q_draws <- beta_draws %*% t(X_use)
      map_quant <- as.numeric(colMeans(q_draws))
      lb_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
      ub_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
      beta_mean <- as.numeric(colMeans(beta_draws))
      beta_lb <- as.numeric(apply(beta_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
      beta_ub <- as.numeric(apply(beta_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
    } else if (is.exalStaticLDVB(fit)) {
      if (!is.null(fit$samp.beta)) {
        beta_draws <- as.matrix(fit$samp.beta)
        if (ncol(beta_draws) != ncol(X_use)) {
          stop("Number of beta coefficients in the fitted object must match ncol(X).", call. = FALSE)
        }
        q_draws <- beta_draws %*% t(X_use)
        map_quant <- as.numeric(colMeans(q_draws))
        lb_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
        ub_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
        beta_mean <- as.numeric(colMeans(beta_draws))
        beta_lb <- as.numeric(apply(beta_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
        beta_ub <- as.numeric(apply(beta_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
      } else {
        beta_mean <- as.numeric(fit$qbeta$m)
        if (length(beta_mean) != ncol(X_use)) {
          stop("Number of beta coefficients in the fitted object must match ncol(X).", call. = FALSE)
        }
        map_quant <- as.numeric(drop(X_use %*% beta_mean))
        if (!is.null(fit$qbeta$V)) {
          Vb <- as.matrix(fit$qbeta$V)
          z <- stats::qnorm((1 + cr.percent) / 2)
          sd_path <- sqrt(pmax(rowSums((X_use %*% Vb) * X_use), 0))
          lb_quant <- map_quant - z * sd_path
          ub_quant <- map_quant + z * sd_path
          beta_sd <- sqrt(pmax(diag(Vb), 0))
          beta_lb <- beta_mean - z * beta_sd
          beta_ub <- beta_mean + z * beta_sd
        } else {
          lb_quant <- rep(NA_real_, length(map_quant))
          ub_quant <- rep(NA_real_, length(map_quant))
          beta_lb <- rep(NA_real_, length(beta_mean))
          beta_ub <- rep(NA_real_, length(beta_mean))
        }
      }
    } else {
      stop("Unsupported static fit supplied to exalStaticDiagnostics().", call. = FALSE)
    }

    if (!is.null(y_use) && length(y_use) != length(map_quant)) {
      stop("Length of y must match nrow(X).", call. = FALSE)
    }
    if (!is.null(ref_use) && length(ref_use) != length(map_quant)) {
      stop("Length of ref must match nrow(X).", call. = FALSE)
    }

    resid <- if (!is.null(y_use)) as.numeric(y_use - map_quant) else NULL
    check_loss <- if (!is.null(y_use) && !is.null(fit$p0)) {
      mean(CheckLossFn(fit$p0, y_use - map_quant))
    } else {
      NA_real_
    }

    list(
      map.quant = map_quant,
      lb.quant = lb_quant,
      ub.quant = ub_quant,
      beta.mean = beta_mean,
      beta.lb = beta_lb,
      beta.ub = beta_ub,
      residuals = resid,
      check_loss = as.numeric(check_loss),
      ref_rmse = if (!is.null(ref_use)) sqrt(mean((map_quant - ref_use)^2)) else NA_real_,
      ref_mae = if (!is.null(ref_use)) mean(abs(map_quant - ref_use)) else NA_real_,
      ref_maxae = if (!is.null(ref_use)) max(abs(map_quant - ref_use)) else NA_real_,
      rt = if (!is.null(fit$run.time)) as.numeric(fit$run.time)[1] else NA_real_
    )
  }

  if (!is_static_fit(m1)) {
    stop("m1 must be a fitted static exalStaticFit object from exalStaticLDVB() or exalStaticMCMC().", call. = FALSE)
  }
  if (!is.null(m2) && !is_static_fit(m2)) {
    stop("m2 must be a fitted static exalStaticFit object from exalStaticLDVB() or exalStaticMCMC().", call. = FALSE)
  }

  X_use <- resolve_X(m1, X)
  y_use <- if (!is.null(y)) {
    as.numeric(y)
  } else if (!is.null(m1$y) && length(m1$y) == nrow(X_use)) {
    as.numeric(m1$y)
  } else {
    NULL
  }
  if (!is.null(y_use) && length(y_use) != nrow(X_use)) {
    stop("Length of y must match nrow(X).", call. = FALSE)
  }
  ref_use <- if (is.null(ref)) NULL else as.numeric(ref)
  if (!is.null(ref_use) && length(ref_use) != nrow(X_use)) {
    stop("Length of ref must match nrow(X).", call. = FALSE)
  }

  x_eval <- x_axis_from_X(X_use)
  ord <- order(x_eval, na.last = TRUE)

  m1_sum <- summarize_fit(m1, X_use, y_use, ref_use, cr.percent)
  ret <- list(
    x = x_eval[ord],
    y = if (is.null(y_use)) NULL else y_use[ord],
    ref = if (is.null(ref_use)) NULL else ref_use[ord],
    p0 = if (!is.null(m1$p0)) as.numeric(m1$p0)[1] else NA_real_,
    n = nrow(X_use),
    m1.class = class(m1)[1],
    m1.map.quant = m1_sum$map.quant[ord],
    m1.lb.quant = m1_sum$lb.quant[ord],
    m1.ub.quant = m1_sum$ub.quant[ord],
    m1.beta.mean = m1_sum$beta.mean,
    m1.beta.lb = m1_sum$beta.lb,
    m1.beta.ub = m1_sum$beta.ub,
    m1.residuals = if (is.null(m1_sum$residuals)) NULL else m1_sum$residuals[ord],
    m1.check_loss = m1_sum$check_loss,
    m1.ref_rmse = m1_sum$ref_rmse,
    m1.ref_mae = m1_sum$ref_mae,
    m1.ref_maxae = m1_sum$ref_maxae,
    m1.rt = m1_sum$rt,
    beta.names = beta_names_from_X(X_use, length(m1_sum$beta.mean)),
    cr.percent = cr.percent
  )

  if (!is.null(m2)) {
    if (is.null(X)) {
      X_m2 <- if (!is.null(m2$X)) as.matrix(m2$X) else X_use
      same_X <- all(dim(X_m2) == dim(X_use)) &&
        isTRUE(all.equal(unname(X_m2), unname(X_use), tolerance = sqrt(.Machine$double.eps)))
    } else {
      same_X <- TRUE
    }
    if (!same_X) {
      stop("m1 and m2 must be evaluated on the same design matrix X.", call. = FALSE)
    }
    if (!is.null(m2$p0) && !is.null(m1$p0) && !isTRUE(all.equal(m1$p0, m2$p0))) {
      stop("m1 and m2 must target the same quantile level p0.", call. = FALSE)
    }

    m2_sum <- summarize_fit(m2, X_use, y_use, ref_use, cr.percent)
    ret$m2.class <- class(m2)[1]
    ret$m2.map.quant <- m2_sum$map.quant[ord]
    ret$m2.lb.quant <- m2_sum$lb.quant[ord]
    ret$m2.ub.quant <- m2_sum$ub.quant[ord]
    ret$m2.beta.mean <- m2_sum$beta.mean
    ret$m2.beta.lb <- m2_sum$beta.lb
    ret$m2.beta.ub <- m2_sum$beta.ub
    ret$m2.residuals <- if (is.null(m2_sum$residuals)) NULL else m2_sum$residuals[ord]
    ret$m2.check_loss <- m2_sum$check_loss
    ret$m2.ref_rmse <- m2_sum$ref_rmse
    ret$m2.ref_mae <- m2_sum$ref_mae
    ret$m2.ref_maxae <- m2_sum$ref_maxae
    ret$m2.rt <- m2_sum$rt
  }

  class(ret) <- "exalStaticDiagnostic"
  if (isTRUE(plot)) plot(ret, cols = cols)
  return(ret)
}


