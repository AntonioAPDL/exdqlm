.exal_static_fit_class <- function(primary) {
  c(primary, "exalStaticFit")
}

.exdqlm_static_engine <- function(x) {
  if (is.exalStaticMCMC(x)) return("MCMC")
  if (is.exalStaticLDVB(x)) return("LDVB")
  "unknown"
}

.exal_static_fit_print <- function(x) {
  n <- if (!is.null(x$X)) nrow(as.matrix(x$X)) else if (!is.null(x$misc$n)) as.integer(x$misc$n) else NA_integer_
  p <- if (!is.null(x$X)) ncol(as.matrix(x$X)) else if (!is.null(x$misc$p)) as.integer(x$misc$p) else NA_integer_
  conv <- .exdqlm_convergence_info(x)
  beta_prior <- if (!is.null(x$beta_prior$type)) x$beta_prior$type else "not stored"
  
  cat("Static Bayesian quantile regression fit\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Model:", .exdqlm_static_model_label(x$dqlm.ind), "\n")
  cat("Inference engine:", .exdqlm_static_engine(x), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(.exdqlm_safe_p0(x)), "\n")
  cat("Observations:", n, "\n")
  cat("Predictors:", p, "\n")
  cat("Beta prior:", beta_prior, "\n")
  if (is.exalStaticMCMC(x)) {
    cat("Burn-in:", x$n.burn, "\n")
    cat("Posterior draws:", x$n.mcmc, "\n")
  } else {
    cat("Converged:", if (is.na(conv$converged)) "NA" else .exdqlm_yes_no(conv$converged), "\n")
    cat("Iterations:", if (is.null(conv$iter)) "NA" else conv$iter, "\n")
  }
  cat("Coefficient draws:", .exdqlm_draw_dim(x$samp.beta), "\n")
  cat("Run-time:", .exdqlm_runtime_label(x$run.time), "\n")
  cat("Use with: summary(), plot(), exalStaticDiagnostics()\n")
  invisible(x)
}

.exal_static_beta_summary <- function(x, max.coef = 6L) {
  max.coef <- suppressWarnings(as.integer(max.coef)[1L])
  if (!is.finite(max.coef) || max.coef < 1L) max.coef <- 6L
  
  if (!is.null(x$samp.beta)) {
    b <- as.matrix(x$samp.beta)
    mean_b <- colMeans(b)
    lb <- apply(b, 2, stats::quantile, probs = 0.025, na.rm = TRUE)
    ub <- apply(b, 2, stats::quantile, probs = 0.975, na.rm = TRUE)
  } else if (!is.null(x$qbeta$m)) {
    mean_b <- as.numeric(x$qbeta$m)
    if (!is.null(x$qbeta$V)) {
      sd_b <- sqrt(pmax(diag(as.matrix(x$qbeta$V)), 0))
      z <- stats::qnorm(0.975)
      lb <- mean_b - z * sd_b
      ub <- mean_b + z * sd_b
    } else {
      lb <- rep(NA_real_, length(mean_b))
      ub <- rep(NA_real_, length(mean_b))
    }
  } else {
    return(data.frame(Coefficient = character(), Mean = numeric(), `2.5%` = numeric(), `97.5%` = numeric()))
  }
  
  p <- length(mean_b)
  nms <- if (!is.null(x$X) && !is.null(colnames(x$X))) colnames(x$X) else paste0("beta", seq_len(p) - 1L)
  keep <- seq_len(min(p, max.coef))
  data.frame(
    Coefficient = nms[keep],
    Mean = as.numeric(mean_b[keep]),
    `2.5%` = as.numeric(lb[keep]),
    `97.5%` = as.numeric(ub[keep]),
    check.names = FALSE,
    row.names = NULL
  )
}

.exal_static_fit_summary <- function(x, max.coef = 6L) {
  scalar_info <- .exdqlm_scalar_summary(x)
  beta_info <- .exal_static_beta_summary(x, max.coef = max.coef)
  draw_info <- data.frame(
    Quantity = c("coefficient draws", "sigma draws", "gamma draws"),
    Dimension = c(
      .exdqlm_draw_dim(x$samp.beta),
      .exdqlm_draw_dim(x$samp.sigma),
      if (is.null(x$samp.gamma)) "not stored" else .exdqlm_draw_dim(x$samp.gamma)
    ),
    check.names = FALSE
  )
  
  .exal_static_fit_print(x)
  cat("\nStored draws:\n")
  print(draw_info, row.names = FALSE)
  if (nrow(scalar_info)) {
    cat("\nScalar posterior summaries:\n")
    print(scalar_info, row.names = FALSE, digits = 4)
  }
  if (nrow(beta_info)) {
    cat("\nCoefficient summaries")
    p <- if (!is.null(x$X)) ncol(as.matrix(x$X)) else nrow(beta_info)
    if (p > nrow(beta_info)) cat(" (first ", nrow(beta_info), " of ", p, ")", sep = "")
    cat(":\n")
    print(beta_info, row.names = FALSE, digits = 4)
  }
  
  invisible(list(draws = draw_info, scalar = scalar_info, coefficients = beta_info))
}

.plot_exal_static_quantiles <- function(map.quant, lb.quant, ub.quant, add = FALSE, col = "purple",
                                        cr.percent = 0.95, ...) {
  idx <- seq_along(map.quant)
  if (!isTRUE(add)) {
    yr <- range(c(map.quant, lb.quant, ub.quant), finite = TRUE)
    if (!all(is.finite(yr))) yr <- range(map.quant, finite = TRUE)
    if (!all(is.finite(yr))) yr <- c(-1, 1)
    if (diff(yr) == 0) yr <- yr + c(-1, 1) * 1e-6
    graphics::plot(idx, map.quant, type = "n",
                   xlab = "index",
                   ylab = sprintf("fitted quantile %.0f%% CrIs", 100 * cr.percent),
                   ylim = yr, ...)
  }
  graphics::lines(idx, map.quant, col = col, lwd = 1.5)
  if (all(is.finite(lb.quant))) graphics::lines(idx, lb.quant, col = col, lwd = 0.75, lty = 2)
  if (all(is.finite(ub.quant))) graphics::lines(idx, ub.quant, col = col, lwd = 0.75, lty = 2)
  invisible(list(map.quant = map.quant, lb.quant = lb.quant, ub.quant = ub.quant))
}

##################################
#### "exalStaticFit" #############
##################################
# included for Fit: is(), print(), summary()
# included for LDVB: is(), print(), summary(), plot()
# inlcuded for MCMC: is(), print(), summary(), plot()


#' \code{exalStaticFit} objects
#'
#' \code{is.exalStaticFit} tests if its argument is a fitted static exAL
#' regression object, including MCMC and LDVB fits.
#'
#' @usage is.exalStaticFit(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exalStaticFit <- function(m){ return(methods::is(m, "exalStaticFit")) }


#' Print Method for \code{exalStaticFit} Objects
#'
#' @param x A fitted static \code{exalStaticFit} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exalStaticFit <- function(x, ...) {
  .exal_static_fit_print(x)
}

#' Summary Method for \code{exalStaticFit} Objects
#'
#' @param object A fitted static \code{exalStaticFit} object.
#' @param max.coef Maximum number of coefficients to print in the coefficient
#'   summary table.
#' @param ... Additional arguments (unused).
#'
#' @return Invisibly returns a list with data frames describing stored draws,
#'   scalar posterior summaries, and coefficient summaries.
#'
#' @description
#' Prints a compact summary of a fitted static AL/exAL quantile-regression model
#' and returns the displayed summary tables for programmatic inspection.
#'
#' @export
summary.exalStaticFit <- function(object, max.coef = 6L, ...) {
  .exal_static_fit_summary(object, max.coef = max.coef)
}


#' Diagnostics Method for \code{exalStaticFit} Objects
#' 
#' Diagnostics for a fitted static quantile model. This is an S3 method wrapper
#' around \code{\link{exalStaticDiagnostics}}; use \code{plot()} on the returned
#' \code{exalStaticDiagnostic} object to visualize the result.
#'
#' @param object A fitted static \code{exalStaticFit} object.
#' @param ... Additional arguments passed to \code{\link{exalStaticDiagnostics}}.
#'
#' @return An object of class \code{exalStaticDiagnostic}.
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
#' out <- diagnostics(fit_ldvb, ref = q_true)
#' plot(out)
#' plot(out, type = "coefficients")
#' }
#'
#' @export
diagnostics.exalStaticFit <- function(object, ...) {
  exalStaticDiagnostics(object, ...)
}

##################################
#### "exalStaticMCMC" / "exalStaticLDVB" ###
##################################

#' \code{exalStaticMCMC} objects
#'
#' \code{is.exalStaticMCMC} tests if its argument is an \code{exalStaticMCMC} object.
#'
#' @usage is.exalStaticMCMC(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exalStaticMCMC <- function(m){ return(methods::is(m,"exalStaticMCMC")) }

#' Print Method for \code{exalStaticMCMC} Objects
#'
#' @param x An \code{exalStaticMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exalStaticMCMC <- function(x, ...) {
  print.exalStaticFit(x, ...)
}

#' Summary Method for \code{exalStaticMCMC} Objects
#'
#' @param object An \code{exalStaticMCMC} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exalStaticMCMC <- function(object, ...) {
  summary.exalStaticFit(object, ...)
}

#' Plot Method for \code{exalStaticMCMC} Objects
#'
#' @param x An \code{exalStaticMCMC} object.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exalStaticMCMC <- function(x, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  if (cr.percent <= 0 || cr.percent >= 1) stop("cr.percent must be between 0 and 1")
  X <- as.matrix(x$X)
  beta_draws <- as.matrix(x$samp.beta)
  q_draws <- beta_draws %*% t(X)
  half.alpha <- (1 - cr.percent) / 2
  map.quant <- as.numeric(colMeans(q_draws))
  lb.quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = half.alpha, na.rm = TRUE))
  ub.quant <- as.numeric(apply(q_draws, 2, stats::quantile, probs = cr.percent + half.alpha, na.rm = TRUE))
  .plot_exal_static_quantiles(map.quant, lb.quant, ub.quant, add = add, col = col, cr.percent = cr.percent, ...)
}

#' \code{exalStaticLDVB} objects
#'
#' \code{is.exalStaticLDVB} tests if its argument is an \code{exalStaticLDVB} object.
#'
#' @usage is.exalStaticLDVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exalStaticLDVB <- function(m){ return(methods::is(m,"exalStaticLDVB")) }

#' Print Method for \code{exalStaticLDVB} Objects
#'
#' @param x An \code{exalStaticLDVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exalStaticLDVB <- function(x, ...) {
  print.exalStaticFit(x, ...)
}

#' Summary Method for \code{exalStaticLDVB} Objects
#'
#' @param object An \code{exalStaticLDVB} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exalStaticLDVB <- function(object, ...) {
  summary.exalStaticFit(object, ...)
}

#' Plot Method for \code{exalStaticLDVB} Objects
#'
#' @param x An \code{exalStaticLDVB} object.
#' @param X Optional design matrix used to compute fitted quantiles. If omitted,
#'   the method uses \code{x$X} when available.
#' @param add Logical; add to an existing plot.
#' @param col Character vector of length 1 giving color for fitted quantiles.
#' @param cr.percent Numeric in \code{(0, 1)} for credible-interval mass.
#' @param ... Additional arguments passed to \code{\link[graphics]{plot}} when
#'   \code{add = FALSE}.
#'
#' @return A list with \code{map.quant}, \code{lb.quant}, and \code{ub.quant}.
#'
#' @export
plot.exalStaticLDVB <- function(x, X = NULL, add = FALSE, col = "purple", cr.percent = 0.95, ...) {
  if (cr.percent <= 0 || cr.percent >= 1) stop("cr.percent must be between 0 and 1")
  if (is.null(X)) X <- x$X
  if (is.null(X)) stop("plot.exalStaticLDVB requires design matrix X (missing in object and argument).")
  X <- as.matrix(X)
  beta_mean <- as.numeric(x$qbeta$m)
  map.quant <- as.numeric(drop(X %*% beta_mean))
  if (!is.null(x$qbeta$V)) {
    Vb <- as.matrix(x$qbeta$V)
    z <- stats::qnorm((1 + cr.percent) / 2)
    sd_path <- sqrt(pmax(rowSums((X %*% Vb) * X), 0))
    lb.quant <- map.quant - z * sd_path
    ub.quant <- map.quant + z * sd_path
  } else {
    lb.quant <- rep(NA_real_, length(map.quant))
    ub.quant <- rep(NA_real_, length(map.quant))
  }
  .plot_exal_static_quantiles(map.quant, lb.quant, ub.quant, add = add, col = col, cr.percent = cr.percent, ...)
}