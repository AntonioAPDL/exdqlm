#' Diagnostic Generic
#'
#' Calculates diagnostic metrics for a variety of objects.
#'
#' @param object An object of class \code{exdqlmFit}, \code{exdqlmForecast}, or 
#' \code{exalStaticFit}.
#' @param ... Additional arguments passed to specific methods.
#'
#' @return The output depends on the underlying method.
#' @export
diagnostics <- function(object, ...) { UseMethod("diagnostics") }

.exdqlm_primary_class <- function(x) {
  class(x)[1L]
}

.exdqlm_dim_label <- function(x) {
  d <- dim(x)
  if (is.null(d)) {
    as.character(length(x))
  } else {
    paste(d, collapse = " x ")
  }
}

.exdqlm_yes_no <- function(x) {
  if (isTRUE(x)) "yes" else "no"
}

.exdqlm_validate_plot_flag <- function(plot) {
  if (!is.logical(plot) || length(plot) != 1L || is.na(plot)) {
    stop("plot must be TRUE or FALSE.", call. = FALSE)
  }
  plot
}

.exdqlm_format_number <- function(x, digits = 4) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(x)) return("NA")
  format(signif(x, digits = digits), trim = TRUE)
}

.exdqlm_runtime_label <- function(x) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(x)) return("NA")
  paste0(format(round(x, 3), trim = TRUE), " seconds")
}

.exdqlm_model_family <- function(x) {
  if (isTRUE(x$dqlm.ind)) "DQLM (AL special case)" else "exDQLM (exAL)"
}

.exdqlm_dynamic_engine <- function(x) {
  if (is.exdqlmMCMC(x)) return("MCMC")
  if (is.exdqlmLDVB(x)) return("LDVB")
  if (is.exdqlmISVB(x)) return("legacy ISVB")
  "unknown"
}

.exdqlm_static_engine <- function(x) {
  if (is.exalStaticMCMC(x)) return("MCMC")
  if (is.exalStaticLDVB(x)) return("LDVB")
  "unknown"
}

.exdqlm_discount_label <- function(df, dim.df) {
  if (is.null(df)) return("not stored")
  if (is.null(dim.df)) return(paste(df, collapse = ", "))
  paste(df, "(", dim.df, ")", collapse = ", ")
}

.exdqlm_draw_dim <- function(x) {
  if (is.null(x)) return("not stored")
  .exdqlm_dim_label(as.matrix(x))
}

.exdqlm_array_dim <- function(x) {
  if (is.null(x)) return("not stored")
  .exdqlm_dim_label(x)
}

.exdqlm_convergence_info <- function(x) {
  conv <- x$diagnostics$convergence
  if (is.null(conv)) {
    return(list(converged = NA, stop_reason = NA_character_, iter = x$iter))
  }
  list(
    converged = conv$converged,
    stop_reason = conv$stop_reason,
    iter = conv$iter
  )
}

.exdqlm_scalar_summary <- function(x) {
  out <- list()
  if (!is.null(x$samp.sigma)) {
    sig <- as.numeric(x$samp.sigma)
    sig <- sig[is.finite(sig)]
    if (length(sig)) {
      out[["sigma"]] <- c(mean = mean(sig), sd = stats::sd(sig))
    }
  } else if (!is.null(x$qsig$E_sigma)) {
    out[["sigma"]] <- c(mean = as.numeric(x$qsig$E_sigma)[1L], sd = NA_real_)
  } else if (!is.null(x$qsiggam$sigma_mean)) {
    out[["sigma"]] <- c(mean = as.numeric(x$qsiggam$sigma_mean)[1L], sd = NA_real_)
  }
  if (!is.null(x$samp.gamma)) {
    gam <- as.numeric(x$samp.gamma)
    gam <- gam[is.finite(gam)]
    if (length(gam)) {
      out[["gamma"]] <- c(mean = mean(gam), sd = stats::sd(gam))
    }
  } else if (!isTRUE(x$dqlm.ind) && !is.null(x$qsiggam$gamma_mean)) {
    out[["gamma"]] <- c(mean = as.numeric(x$qsiggam$gamma_mean)[1L], sd = NA_real_)
  }
  if (!length(out)) {
    return(data.frame(Parameter = character(), Mean = numeric(), SD = numeric()))
  }
  data.frame(
    Parameter = names(out),
    Mean = vapply(out, function(z) z[["mean"]], numeric(1)),
    SD = vapply(out, function(z) z[["sd"]], numeric(1)),
    row.names = NULL,
    check.names = FALSE
  )
}

.exdqlm_safe_p0 <- function(x) {
  if (!is.null(x$p0)) return(as.numeric(x$p0)[1L])
  if (!is.null(x$misc$p0)) return(as.numeric(x$misc$p0)[1L])
  if (!is.null(x$m1$p0)) return(as.numeric(x$m1$p0)[1L])
  NA_real_
}
