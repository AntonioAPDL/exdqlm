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
#' @param m1 An object of class \code{"exalStaticLDVB"} or \code{"exalStaticMCMC"}.
#' @param m2 Optional second fitted static model to compare against \code{m1}.
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

  is_static_fit <- function(m) {
    is.exalStaticLDVB(m) || is.exalStaticMCMC(m)
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

#' \code{exalStaticDiagnostic} objects
#'
#' \code{is.exalStaticDiagnostic} tests if its argument is an \code{exalStaticDiagnostic}
#' object.
#'
#' @usage is.exalStaticDiagnostic(x)
#' @param x an \strong{R} object
#' @export
is.exalStaticDiagnostic <- function(x) {
  methods::is(x, "exalStaticDiagnostic")
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

#' Print Method for \code{exalStaticDiagnostic} Objects
#'
#' @param x An \code{exalStaticDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
print.exalStaticDiagnostic <- function(x, ...) {
  cat("Static exAL diagnostics\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Quantile level (p0):", x$p0, "\n")
  cat("Evaluation rows:", if (is.null(x$n)) length(x$x) else x$n, "\n")
  cat("Models:", if (is.null(x$m1.class)) "M1" else x$m1.class)
  if (!is.null(x$m2.class)) cat(" vs ", x$m2.class, sep = "")
  cat("\n")
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
  cat("Plot types: quantile, coefficients\n")
  invisible(x)
}

#' Summary Method for \code{exalStaticDiagnostic} Objects
#'
#' @param object An \code{exalStaticDiagnostic} object.
#' @param ... Additional arguments (unused).
#' @export
summary.exalStaticDiagnostic <- function(object, ...) {
  m1 <- .exal_diagnostic_vector(object, "m1.")
  out <- if (is.null(object$m2.rt)) {
    data.frame(Diagnostic = names(m1), M1 = unname(m1), check.names = FALSE)
  } else {
    m2 <- .exal_diagnostic_vector(object, "m2.")
    data.frame(Diagnostic = names(m1), M1 = unname(m1), M2 = unname(m2), check.names = FALSE)
  }
  cat("Static exAL diagnostics summary\n")
  cat("Quantile level (p0):", object$p0, "\n")
  cat("Evaluation rows:", if (is.null(object$n)) length(object$x) else object$n, "\n")
  print(out, row.names = FALSE, digits = 4)
  invisible(out)
}

#' Plot Method for \code{exalStaticDiagnostic} Objects
#'
#' @param x An \code{exalStaticDiagnostic} object.
#' @param cols Character vector of length 1 or 2 giving color(s) used to plot
#'   diagnostics.
#' @param type Character string; \code{"quantile"} plots fitted conditional
#'   quantile summaries, and \code{"coefficients"} plots posterior coefficient
#'   intervals.
#' @param beta.ref Optional coefficient reference vector for
#'   \code{type = "coefficients"}. This is typically available only in
#'   simulation benchmarks. It is used as a plotting overlay, not as a package
#'   diagnostic metric.
#' @param include.intercept Logical; if \code{FALSE}, omit the first coefficient
#'   from \code{type = "coefficients"} plots.
#' @param coef.names Optional names for coefficients in
#'   \code{type = "coefficients"} plots.
#' @param xlab,ylab Optional axis labels.
#' @param ylim Optional y-axis limits.
#' @param legend.labels Optional labels for the first and second model
#'   intervals in \code{type = "coefficients"} plots.
#' @param beta.ref.label Label for the optional \code{beta.ref} overlay.
#' @param legend Logical; if \code{TRUE}, add a legend to coefficient plots.
#' @param ... Additional arguments passed to plotting functions.
#' @export
plot.exalStaticDiagnostic <- function(x, cols = c("red", "blue"),
                                      type = c("quantile", "coefficients"),
                                      beta.ref = NULL,
                                      include.intercept = TRUE,
                                      coef.names = NULL,
                                      xlab = NULL,
                                      ylab = NULL,
                                      ylim = NULL,
                                      legend.labels = NULL,
                                      beta.ref.label = "reference",
                                      legend = TRUE, ...) {
  type <- match.arg(type)
  cols <- rep(cols, length.out = 2L)

  if (identical(type, "coefficients")) {
    p <- length(x$m1.beta.mean)
    keep <- seq_len(p)
    if (!isTRUE(include.intercept)) {
      if (p < 2L) {
        stop("include.intercept = FALSE requires at least two coefficients.", call. = FALSE)
      }
      keep <- keep[-1L]
    }

    if (!is.null(beta.ref)) {
      beta.ref <- as.numeric(beta.ref)
      if (length(beta.ref) != p) {
        stop("Length of beta.ref must match the full coefficient vector.", call. = FALSE)
      }
      beta.ref <- beta.ref[keep]
    }

    if (is.null(coef.names)) {
      coef.names <- x$beta.names
    }
    if (is.null(coef.names) || length(coef.names) != p) {
      coef.names <- paste0("beta", seq_len(p) - 1L)
      if (p > 0L) coef.names[1L] <- "(Intercept)"
    }
    coef.names <- coef.names[keep]

    m1_mean <- x$m1.beta.mean[keep]
    m1_lb <- x$m1.beta.lb[keep]
    m1_ub <- x$m1.beta.ub[keep]
    has_m2 <- !is.null(x$m2.beta.mean)
    m2_mean <- if (has_m2) x$m2.beta.mean[keep] else NULL
    m2_lb <- if (has_m2) x$m2.beta.lb[keep] else NULL
    m2_ub <- if (has_m2) x$m2.beta.ub[keep] else NULL
    if (is.null(legend.labels)) {
      legend.labels <- if (has_m2) c("M1 interval", "M2 interval") else "M1 interval"
    }
    legend.labels <- as.character(legend.labels)
    expected_legend_labels <- if (has_m2) 2L else 1L
    if (length(legend.labels) != expected_legend_labels || any(!nzchar(legend.labels))) {
      stop(
        sprintf("legend.labels must contain %d non-empty label%s.",
                expected_legend_labels,
                if (expected_legend_labels == 1L) "" else "s"),
        call. = FALSE
      )
    }
    beta.ref.label <- as.character(beta.ref.label)
    if (length(beta.ref.label) != 1L || !nzchar(beta.ref.label)) {
      stop("beta.ref.label must be one non-empty string.", call. = FALSE)
    }

    if (is.null(ylim)) {
      y_range <- range(c(beta.ref, m1_lb, m1_ub, m2_lb, m2_ub, m1_mean, m2_mean), finite = TRUE)
      if (!all(is.finite(y_range))) y_range <- c(-1, 1)
      if (diff(y_range) == 0) y_range <- y_range + c(-1, 1) * 1e-6
      y_pad <- 0.08 * diff(y_range)
      y_range <- y_range + c(-y_pad, y_pad)
    } else {
      y_range <- as.numeric(ylim)
      if (length(y_range) != 2L || !all(is.finite(y_range)) || y_range[1L] >= y_range[2L]) {
        stop("ylim must be a numeric vector of length 2 with increasing finite values.", call. = FALSE)
      }
    }

    x_pos <- seq_along(keep)
    offset <- if (has_m2) 0.12 else 0
    xlab_use <- if (is.null(xlab)) "" else xlab
    ylab_use <- if (is.null(ylab)) "coefficient value" else ylab
    graphics::plot(
      x_pos, m1_mean, type = "n", xaxt = "n",
      xlab = xlab_use, ylab = ylab_use, ylim = y_range, ...
    )
    graphics::abline(h = 0, col = "grey85", lty = 2)
    graphics::axis(1, at = x_pos, labels = coef.names, las = 2)
    graphics::segments(x_pos - offset, m1_lb, x_pos - offset, m1_ub, col = cols[1], lwd = 2)
    graphics::points(x_pos - offset, m1_mean, pch = 16, col = cols[1])
    if (has_m2) {
      graphics::segments(x_pos + offset, m2_lb, x_pos + offset, m2_ub, col = cols[2], lwd = 2)
      graphics::points(x_pos + offset, m2_mean, pch = 16, col = cols[2])
    }
    if (!is.null(beta.ref)) {
      graphics::points(x_pos, beta.ref, pch = 18, cex = 1.1, col = "black")
    }
    if (isTRUE(legend)) {
      leg <- if (!is.null(beta.ref)) beta.ref.label else character()
      leg_col <- if (!is.null(beta.ref)) "black" else character()
      leg_pch <- if (!is.null(beta.ref)) 18 else numeric()
      leg_lty <- if (!is.null(beta.ref)) 0 else numeric()
      leg_lwd <- if (!is.null(beta.ref)) 0 else numeric()
      leg <- c(leg, legend.labels[1L])
      leg_col <- c(leg_col, cols[1])
      leg_pch <- c(leg_pch, 16)
      leg_lty <- c(leg_lty, 1)
      leg_lwd <- c(leg_lwd, 2)
      if (has_m2) {
        leg <- c(leg, legend.labels[2L])
        leg_col <- c(leg_col, cols[2])
        leg_pch <- c(leg_pch, 16)
        leg_lty <- c(leg_lty, 1)
        leg_lwd <- c(leg_lwd, 2)
      }
      graphics::legend(
        "topleft", legend = leg, col = leg_col, pch = leg_pch,
        lty = leg_lty, lwd = leg_lwd, bty = "n"
      )
    }

    plot_summary <- list(
      type = "coefficients",
      coefficient = coef.names,
      index = keep,
      m1.mean = m1_mean,
      m1.lb = m1_lb,
      m1.ub = m1_ub,
      m2.mean = m2_mean,
      m2.lb = m2_lb,
      m2.ub = m2_ub,
      beta.ref = beta.ref,
      cr.percent = x$cr.percent
    )
    return(invisible(plot_summary))
  }

  op <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  graphics::par(mfrow = c(1, 2))
  xlab_quant <- if (is.null(xlab)) "x / index" else xlab
  ylab_quant <- if (is.null(ylab)) "conditional quantile" else ylab

  if (is.null(ylim)) {
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
  } else {
    yr <- as.numeric(ylim)
    if (length(yr) != 2L || !all(is.finite(yr)) || yr[1L] >= yr[2L]) {
      stop("ylim must be a numeric vector of length 2 with increasing finite values.", call. = FALSE)
    }
  }

  graphics::plot(
    x$x, x$m1.map.quant, type = "n", ylim = yr,
    xlab = xlab_quant, ylab = ylab_quant, ...
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
      xlab = xlab_quant, ylab = "absolute error vs truth",
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
      xlab = xlab_quant, ylab = "residuals", ylim = yr2, ...
    )
    graphics::abline(h = 0, col = "grey60", lty = 2)
    if (!is.null(resid2)) {
      graphics::points(x$x, resid2, col = cols[2], pch = 1, cex = 0.6)
    }
  } else {
    graphics::plot.new()
    graphics::title("No residual/reference panel available")
  }
  invisible(list(type = "quantile"))
}
