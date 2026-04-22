#' exAL Diagnostics
#'
#' Static diagnostics companion for \code{exalStaticLDVB()} and
#' \code{exalStaticMCMC()}. The function summarizes fitted quantiles on a
#' shared design matrix, reports mean check loss against observed responses when
#' available, and can optionally compare the fitted quantile curve against a
#' known reference quantile function.
#'
#' @param m1 An object of class \code{"exal_ldvb"} or \code{"exal_mcmc"}.
#' @param m2 Optional second fitted static model to compare against \code{m1}.
#' @param X Optional design matrix. If omitted, the function uses \code{m1$X}
#'   when available.
#' @param y Optional response vector. If omitted, the function uses \code{m1$y}
#'   when available.
#' @param ref Optional reference quantile vector on the same rows as \code{X}.
#' @param plot Logical; if \code{TRUE}, produce a compact static-diagnostics
#'   plot.
#' @param cols Character vector of length 1 or 2 giving colors for plotted
#'   diagnostics.
#' @param cr.percent Credible-interval mass used when summarizing fitted
#'   quantiles.
#'
#' @details
#' Unlike \code{\link{exdqlmDiagnostics}}, which is built around one-step-ahead
#' dynamic forecast diagnostics, \code{exalDiagnostics()} is designed for the
#' static regression setting. It reports fitted quantile summaries on a common
#' design matrix, optional mean check loss against observed responses, optional
#' truth/reference errors, and compact comparison plots.
#'
#' @return An object of class \code{"exalDiagnostic"} containing fitted-quantile
#'   summaries, residual summaries (when \code{y} is provided), optional
#'   reference-curve error metrics, and run-time metadata for \code{m1} and
#'   \code{m2} (if supplied).
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
#'   max_iter = 150, tol = 1e-3,
#'   verbose = FALSE
#' )
#' fit_mcmc <- exalStaticMCMC(
#'   y = y, X = X, p0 = 0.25,
#'   n.burn = 200, n.mcmc = 150,
#'   mh.proposal = "slice",
#'   verbose = FALSE
#' )
#' out <- exalDiagnostics(fit_ldvb, fit_mcmc, ref = q_true, plot = FALSE)
#' print(out)
#' }
#' @export
exalDiagnostics <- function(m1, m2 = NULL, X = NULL, y = NULL, ref = NULL,
                            plot = TRUE, cols = c("red", "blue"),
                            cr.percent = 0.95) {
  is_static_fit <- function(m) {
    is.exal_ldvb(m) || is.exal_mcmc(m)
  }

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

  summarize_fit <- function(fit, X_use, y_use, ref_use, cr.percent) {
    if (cr.percent <= 0 || cr.percent >= 1) {
      stop("cr.percent must be between 0 and 1.", call. = FALSE)
    }
    if (nrow(X_use) < 1L) {
      stop("X must have at least one row.", call. = FALSE)
    }

    if (is.exal_mcmc(fit)) {
      beta_draws <- as.matrix(fit$samp.beta)
      q_draws <- beta_draws %*% t(X_use)
      map_quant <- as.numeric(colMeans(q_draws))
      half.alpha <- (1 - cr.percent) / 2
      upper <- 1 - half.alpha
      lb_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
      ub_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
      beta_mean <- as.numeric(colMeans(beta_draws))
    } else if (is.exal_ldvb(fit)) {
      if (!is.null(fit$samp.beta)) {
        beta_draws <- as.matrix(fit$samp.beta)
        q_draws <- beta_draws %*% t(X_use)
        map_quant <- as.numeric(colMeans(q_draws))
        half.alpha <- (1 - cr.percent) / 2
        upper <- 1 - half.alpha
        lb_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
        ub_quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = upper, na.rm = TRUE))
        beta_mean <- as.numeric(colMeans(beta_draws))
      } else {
        beta_mean <- as.numeric(fit$qbeta$m)
        map_quant <- as.numeric(drop(X_use %*% beta_mean))
        if (!is.null(fit$qbeta$V)) {
          Vb <- as.matrix(fit$qbeta$V)
          z <- stats::qnorm((1 + cr.percent) / 2)
          sd_path <- sqrt(pmax(rowSums((X_use %*% Vb) * X_use), 0))
          lb_quant <- map_quant - z * sd_path
          ub_quant <- map_quant + z * sd_path
        } else {
          lb_quant <- rep(NA_real_, length(map_quant))
          ub_quant <- rep(NA_real_, length(map_quant))
        }
      }
    } else {
      stop("Unsupported static fit supplied to exalDiagnostics().", call. = FALSE)
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
      residuals = resid,
      check_loss = as.numeric(check_loss),
      ref_rmse = if (!is.null(ref_use)) sqrt(mean((map_quant - ref_use)^2)) else NA_real_,
      ref_mae = if (!is.null(ref_use)) mean(abs(map_quant - ref_use)) else NA_real_,
      ref_maxae = if (!is.null(ref_use)) max(abs(map_quant - ref_use)) else NA_real_,
      rt = if (!is.null(fit$run.time)) as.numeric(fit$run.time)[1] else NA_real_
    )
  }

  if (!is_static_fit(m1)) {
    stop("m1 must be an output from exalStaticLDVB() or exalStaticMCMC().", call. = FALSE)
  }
  if (!is.null(m2) && !is_static_fit(m2)) {
    stop("m2 must be an output from exalStaticLDVB() or exalStaticMCMC().", call. = FALSE)
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
    m1.map.quant = m1_sum$map.quant[ord],
    m1.lb.quant = m1_sum$lb.quant[ord],
    m1.ub.quant = m1_sum$ub.quant[ord],
    m1.beta.mean = m1_sum$beta.mean,
    m1.residuals = if (is.null(m1_sum$residuals)) NULL else m1_sum$residuals[ord],
    m1.check_loss = m1_sum$check_loss,
    m1.ref_rmse = m1_sum$ref_rmse,
    m1.ref_mae = m1_sum$ref_mae,
    m1.ref_maxae = m1_sum$ref_maxae,
    m1.rt = m1_sum$rt
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
    ret$m2.map.quant <- m2_sum$map.quant[ord]
    ret$m2.lb.quant <- m2_sum$lb.quant[ord]
    ret$m2.ub.quant <- m2_sum$ub.quant[ord]
    ret$m2.beta.mean <- m2_sum$beta.mean
    ret$m2.residuals <- if (is.null(m2_sum$residuals)) NULL else m2_sum$residuals[ord]
    ret$m2.check_loss <- m2_sum$check_loss
    ret$m2.ref_rmse <- m2_sum$ref_rmse
    ret$m2.ref_mae <- m2_sum$ref_mae
    ret$m2.ref_maxae <- m2_sum$ref_maxae
    ret$m2.rt <- m2_sum$rt
  }

  class(ret) <- c("exalDiagnostic", "exalStaticDiagnostic")
  if (isTRUE(plot)) plot(ret, cols = cols)
  invisible(ret)
}

#' \code{exalDiagnostic} objects
#'
#' \code{is.exalDiagnostic} tests if its argument is an \code{exalDiagnostic}
#' object.
#'
#' @usage is.exalDiagnostic(x)
#' @param x an \strong{R} object
#' @export
is.exalDiagnostic <- function(x) {
  methods::is(x, "exalDiagnostic")
}

.exal_diagnostic_vector <- function(x, prefix) {
  c(
    "check loss" = as.numeric(x[[paste0(prefix, "check_loss")]]),
    "ref RMSE" = as.numeric(x[[paste0(prefix, "ref_rmse")]]),
    "ref MAE" = as.numeric(x[[paste0(prefix, "ref_mae")]]),
    "ref max AE" = as.numeric(x[[paste0(prefix, "ref_maxae")]]),
    "run-time (s)" = as.numeric(x[[paste0(prefix, "rt")]])
  )
}

#' Print Method for \code{exalDiagnostic} Objects
#'
#' @param x An \code{exalDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
print.exalDiagnostic <- function(x, ...) {
  cat("Static exAL diagnostics\n")
  cat("Quantile level (p0):", x$p0, "\n")
  m1 <- .exal_diagnostic_vector(x, "m1.")
  if (is.null(x$m2.rt)) {
    print(data.frame(Diagnostic = names(m1), M1 = unname(m1)), row.names = FALSE, digits = 4)
  } else {
    m2 <- .exal_diagnostic_vector(x, "m2.")
    print(
      data.frame(Diagnostic = names(m1), M1 = unname(m1), M2 = unname(m2)),
      row.names = FALSE,
      digits = 4
    )
  }
}

#' Summary Method for \code{exalDiagnostic} Objects
#'
#' @param object An \code{exalDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
summary.exalDiagnostic <- function(object, ...) {
  print.exalDiagnostic(object, ...)
}

#' Plot Method for \code{exalDiagnostic} Objects
#'
#' @param x An \code{exalDiagnostic} object.
#' @param cols Character vector of length 1 or 2 giving color(s) used to plot
#'   diagnostics.
#' @param ... Additional arguments passed to plotting functions.
#' @export
plot.exalDiagnostic <- function(x, cols = c("red", "blue"), ...) {
  cols <- rep(cols, length.out = 2L)
  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  graphics::par(mfrow = c(1, 2))

  yr <- range(
    c(x$y, x$ref, x$m1.lb.quant, x$m1.ub.quant, x$m2.lb.quant, x$m2.ub.quant),
    finite = TRUE
  )
  if (!all(is.finite(yr))) {
    yr <- range(c(x$m1.map.quant, x$m2.map.quant), finite = TRUE)
  }
  if (!all(is.finite(yr))) {
    yr <- c(-1, 1)
  }
  if (diff(yr) == 0) {
    yr <- yr + c(-1, 1) * 1e-6
  }

  graphics::plot(
    x$x, x$m1.map.quant, type = "n", ylim = yr,
    xlab = "x / index", ylab = "conditional quantile", ...
  )
  if (!is.null(x$y)) {
    graphics::points(
      x$x, x$y,
      col = grDevices::adjustcolor("grey50", alpha.f = 0.45),
      pch = 16, cex = 0.6
    )
  }
  if (!is.null(x$ref)) {
    graphics::lines(x$x, x$ref, lwd = 2, lty = 2, col = "black")
  }
  graphics::lines(x$x, x$m1.map.quant, col = cols[1], lwd = 2)
  if (all(is.finite(x$m1.lb.quant))) {
    graphics::lines(x$x, x$m1.lb.quant, col = cols[1], lwd = 1, lty = 3)
  }
  if (all(is.finite(x$m1.ub.quant))) {
    graphics::lines(x$x, x$m1.ub.quant, col = cols[1], lwd = 1, lty = 3)
  }

  leg <- c("M1")
  leg_cols <- c(cols[1])
  leg_lty <- c(1)

  if (!is.null(x$m2.map.quant)) {
    graphics::lines(x$x, x$m2.map.quant, col = cols[2], lwd = 2)
    if (all(is.finite(x$m2.lb.quant))) {
      graphics::lines(x$x, x$m2.lb.quant, col = cols[2], lwd = 1, lty = 3)
    }
    if (all(is.finite(x$m2.ub.quant))) {
      graphics::lines(x$x, x$m2.ub.quant, col = cols[2], lwd = 1, lty = 3)
    }
    leg <- c(leg, "M2")
    leg_cols <- c(leg_cols, cols[2])
    leg_lty <- c(leg_lty, 1)
  }
  if (!is.null(x$ref)) {
    leg <- c("truth", leg)
    leg_cols <- c("black", leg_cols)
    leg_lty <- c(2, leg_lty)
  }
  graphics::legend("topleft", legend = leg, col = leg_cols, lty = leg_lty, bty = "n")

  if (!is.null(x$ref)) {
    err1 <- abs(x$m1.map.quant - x$ref)
    err2 <- if (!is.null(x$m2.map.quant)) abs(x$m2.map.quant - x$ref) else NULL
    yr2 <- range(c(err1, err2), finite = TRUE)
    if (!all(is.finite(yr2))) {
      yr2 <- c(0, 1)
    }
    graphics::plot(
      x$x, err1, type = "l", col = cols[1], lwd = 2,
      xlab = "x / index", ylab = "absolute error vs truth",
      ylim = yr2, ...
    )
    if (!is.null(err2)) {
      graphics::lines(x$x, err2, col = cols[2], lwd = 2)
    }
  } else if (!is.null(x$y)) {
    resid1 <- x$m1.residuals
    resid2 <- if (!is.null(x$m2.residuals)) x$m2.residuals else NULL
    yr2 <- range(c(resid1, resid2), finite = TRUE)
    if (!all(is.finite(yr2))) {
      yr2 <- c(-1, 1)
    }
    graphics::plot(
      x$x, resid1, type = "p", col = cols[1], pch = 16, cex = 0.6,
      xlab = "x / index", ylab = "residuals", ylim = yr2, ...
    )
    graphics::abline(h = 0, col = "grey60", lty = 2)
    if (!is.null(resid2)) {
      graphics::points(x$x, resid2, col = cols[2], pch = 1, cex = 0.6)
    }
  } else {
    graphics::plot.new()
    graphics::title("No residual/reference panel available")
  }
}
