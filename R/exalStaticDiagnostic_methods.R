.exal_diagnostic_vector <- function(x, prefix) {
  c(
    "check loss" = as.numeric(x[[paste0(prefix, "check_loss")]]),
    "ref RMSE" = as.numeric(x[[paste0(prefix, "ref_rmse")]]),
    "ref MAE" = as.numeric(x[[paste0(prefix, "ref_mae")]]),
    "ref max AE" = as.numeric(x[[paste0(prefix, "ref_maxae")]]),
    "run-time (s)" = as.numeric(x[[paste0(prefix, "rt")]])
  )
}

##################################
#### "exalStaticFit" #############
##################################
# included: is(), print(), summary(), plot()

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
  cat("Use with: summary(), plot()\n")
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