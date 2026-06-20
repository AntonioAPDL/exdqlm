.exdqlm_diagnostic_vector <- function(x, prefix) {
  c(
    "KL" = as.numeric(x[[paste0(prefix, "KL")]]),
    "KL (flipped)" = if (!is.null(x[[paste0(prefix, "KL.flip")]])) as.numeric(x[[paste0(prefix, "KL.flip")]]) else NA_real_,
    "CRPS" = if (!is.null(x[[paste0(prefix, "CRPS")]])) as.numeric(x[[paste0(prefix, "CRPS")]]) else NA_real_,
    "pplc" = as.numeric(x[[paste0(prefix, "pplc")]]),
    "run-time (s)" = as.numeric(x[[paste0(prefix, "rt")]])
  )
}

.exdqlm_diagnostic_table <- function(x) {
  M1 <- .exdqlm_diagnostic_vector(x, "m1.")
  if (is.null(x$m2.KL)) {
    data.frame(Diagnostic = names(M1), M1 = unname(M1), check.names = FALSE)
  } else {
    M2 <- .exdqlm_diagnostic_vector(x, "m2.")
    data.frame(Diagnostic = names(M1), M1 = unname(M1), M2 = unname(M2), check.names = FALSE)
  }
}

##################################
### "exdqlmDiagnostic" objects ###
##################################
# included: is(), print(), summary(), plot()

#' \code{exdqlmDiagnostic} objects
#'
#' \code{is.exdqlmDiagnostic} tests if its argument is a \code{exdqlmDiagnostic} object. 
#' 
#' @usage is.exdqlmDiagnostic(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmDiagnostic = function(x){ return(methods::is(x,"exdqlmDiagnostic")) }

#' Print Method for \code{exdqlmDiagnostic} Objects
#'
#' @param x An \code{exdqlmDiagnostic} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.95), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#' M0.diags = exdqlmDiagnostics(M0)
#' print(M0.diags)
#' options(old)
#' }
#'
print.exdqlmDiagnostic <- function(x, ...) {
  old_opts <- options(scipen = 999)
  on.exit(options(old_opts), add = TRUE)
  cat("Dynamic quantile model diagnostics\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(x$p0), "\n")
  cat("Observations:", if (is.null(x$n)) length(x$y) else x$n, "\n")
  cat("Models:", if (is.null(x$m1.class)) "M1" else x$m1.class)
  if (!is.null(x$m2.class)) cat(" vs ", x$m2.class, sep = "")
  cat("\n")
  print(.exdqlm_diagnostic_table(x), row.names = FALSE, digits = 3)
  cat("Use with: summary(), plot()\n")
  invisible(x)
}

#' Summary Method for \code{exdqlmDiagnostic} Objects
#'
#' @param object An \code{exdqlmDiagnostic} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.95), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#' M0.diags = exdqlmDiagnostics(M0)
#' summary(M0.diags)
#' options(old)
#' }
#'
summary.exdqlmDiagnostic <- function(object, ...) {
  old_opts <- options(scipen = 999)
  on.exit(options(old_opts), add = TRUE)
  out <- .exdqlm_diagnostic_table(object)
  cat("Dynamic quantile model diagnostics summary\n")
  cat("Quantile level (p0):", .exdqlm_format_number(object$p0), "\n")
  cat("Observations:", if (is.null(object$n)) length(object$y) else object$n, "\n")
  print(out, row.names = FALSE, digits = 3)
  invisible(out)
}

#' Plot Method for \code{exdqlmDiagnostic} Objects
#'
#' @param x An \code{exdqlmDiagnostic} object.
#' @param ... Additional graphical arguments. The optional \code{cols} element
#'   controls the colors used for the first and second model when comparing two
#'   fits.
#'
#' @return Invisibly returns \code{x}.
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.95), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#' M0.diags = exdqlmDiagnostics(M0)
#' plot(M0.diags)
#' options(old)
#' }
#'
plot.exdqlmDiagnostic <- function(x, ...) {
  aa = list(...)
  if(is.null(aa$cols)){cols=c("red","blue")}else{cols = aa$cols}
  
  # get ranges
  if(is.null(x$m2.KL)){
    qq.x.range = range(x$m1.qq$x)
    qq.y.range = range(x$m1.qq$y)
    acf.y.range = range(x$m1.acf$acf)
    fe.y.range = range(x$m1.msfe)
  }else{
    qq.x.range = range(c(x$m1.qq$x,x$m2.qq$x))
    qq.y.range = range(c(x$m1.qq$y,x$m2.qq$y))
    acf.y.range = range(c(x$m1.acf$acf,x$m2.acf$acf))
    fe.y.range = range(c(x$m1.msfe,x$m2.msfe))
  }
  # m1 qqplot
  plot(x$m1.qq,main="",col=cols[1],pch=20,xlab="Theoretical Quantiles",ylab="M1 Sample Quantiles",xlim=qq.x.range,ylim=qq.y.range)
  graphics::abline(a=0,b=1)
  # m1 acf
  plot(x$m1.acf,ylab="M1 ACF",col=cols[1],main="",ylim=acf.y.range)
  # m1 forecast errors
  ts.xy = grDevices::xy.coords(x$y)
  graphics::plot(ts.xy$x,x$m1.msfe,ylab="M1 standard forecast errors",xlab="time",col=cols[1],pch=20,type="l",ylim=fe.y.range)
  graphics::abline(h=0,lty=2)
  ### m2
  if(!is.null(x$m2.KL)){
    # m2 qqplot
    plot(x$m2.qq,main="",col=cols[2],pch=20,xlab="Theoretical Quantiles",ylab="M2 Sample Quantiles",xlim=qq.x.range,ylim=qq.y.range)
    graphics::abline(a=0,b=1)
    # m2 acf
    plot(x$m2.acf,ylab="M2 ACF",col=cols[2],main="",ylim=acf.y.range)
    # m2 forecast errors
    graphics::plot(ts.xy$x,x$m2.msfe,ylab="M2 standard forecast errors", xlab="time",col=cols[2],pch=20,type="l",ylim=fe.y.range)
    graphics::abline(h=0,lty=2)
  }
  invisible(x)
}
