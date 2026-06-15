##################################
######## "exdqlm" objects ########
##################################

#' \code{exdqlm} objects
#'
#' \code{is.exdqlm} tests if its argument is a \code{exdqlm} object. 
#' 
#' @usage is.exdqlm(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlm = function(m){ return(methods::is(m,"exdqlm")) }

.exdqlm_fit_class <- function(primary) {
  c(primary, "exdqlmFit")
}

.exal_static_fit_class <- function(primary) {
  c(primary, "exalStaticFit")
}

#' \code{exdqlmFit} objects
#'
#' \code{is.exdqlmFit} tests if its argument is a fitted dynamic
#' \code{exdqlm} object, including MCMC, LDVB, and legacy ISVB fits.
#'
#' @usage is.exdqlmFit(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlmFit <- function(m){ return(methods::is(m, "exdqlmFit")) }

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

#' \code{exdqlm} objects
#'
#' \code{as.exdqlm} attempts to turn a list into an \code{exdqlm} object. Works for time-invariant \code{dlm} objects created using the \pkg{dlm} package. 
#' 
#' @usage as.exdqlm(m)
#'
#' @param m a list containing named elements m0, C0, FF and GG.
#'
#' @return An object of class "\code{exdqlm}" containing the state space model components:
#' \itemize{
#'   \item FF - Observational vector.
#'   \item GG - Evolution matrix.
#'   \item m0 - Prior mean of the state vector.
#'   \item C0 - Prior covariance of the state vector.
#' }
#' @export
as.exdqlm <- function(m){
  if(is.exdqlm(m)){
    return(m)
  }
  if(!is.list(m)){
    stop("Input must be a list with named elements m0, C0, FF and GG.")
  }
  if(methods::is(m,"dlm")){
    if(!is.null(m$JFF) | !is.null(m$JGG) |
       !is.null(m$JV) | !is.null(m$JW)){
      stop("'dlm' object input must be a time-invariant")
    }
    m$FF = t(m$FF)
  }
  
  # check for required components & remove extras
  refnn <- c("m0","C0","FF","GG")
  nn <- names(m)
  check <- !sapply(m, is.null)
  ind <- match(refnn,nn)
  if(anyNA(ind)){
    stop(paste("Component(s)",paste(refnn[is.na(ind)], collapse = ", "), "is (are) missing."))
  }
  final.ind = match(nn[ind][check[ind]],nn)
  model = m[final.ind]
  
  class(model) <- "exdqlm"
  model = check_mod(model)
  
  return(model)
}

#' Addition for \code{exdqlm} objects
#'
#' Combines two state space blocks into a single state space model for an exDQLM.
#' 
#' @method + exdqlm
#' @rdname plus-exdqlm
#'
#' @param m1 object of class "\code{exdqlm}" containing the first model to be combined.
#' @param m2 object of class "\code{exdqlm}" containing the second model to be combined.
#'
#' @return An object of class "\code{exdqlm}" containing the new combined state space model components:
#' \itemize{
#'   \item FF - Observational vector.
#'   \item GG - Evolution matrix.
#'   \item m0 - Prior mean of the state vector.
#'   \item C0 - Prior covariance of the state vector.
#' }
#'
#' @examples
#' trend.comp = polytrendMod(2, rep(0, 2), 10*diag(2))
#' seas.comp = seasMod(365, c(1,2,4), C0 = 10*diag(6))
#' model = trend.comp + seas.comp
#'
#' @export
"+.exdqlm" <- function(m1, m2){
  m1 = check_mod(m1)
  m2 = check_mod(m2)
  n = length(m1$m0) + length(m2$m0)
  model<- NULL
  if(ncol(m1$FF)>1 | ncol(m2$FF)>1){
    if(ncol(m1$FF)>1 & ncol(m2$FF)>1 & ncol(m1$FF) != ncol(m2$FF)){
      stop("incompatible number of columns in m1$FF and m2$FF")
    }
    model$FF = matrix(0,n,max(ncol(m1$FF),ncol(m2$FF)))
    model$FF[1:nrow(m1$FF),] = m1$FF
    model$FF[(nrow(m1$FF)+1):n,] = m2$FF
  }else{
    model$FF = matrix(c(m1$FF,m2$FF),n,1)
  }
  if(!is.na(dim(m1$GG)[3]) | !is.na(dim(m2$GG)[3])){
    if(!is.na(dim(m1$GG)[3]) & !is.na(dim(m2$GG)[3]) & dim(m1$GG)[3] != dim(m2$GG)[3]){
      stop("incompatible third dimensions of m1$GG and m2$GG")
    }
    model$GG = array(0,c(n,n,max(dim(m1$GG)[3],dim(m2$GG)[3],na.rm = TRUE)))
    model$GG[1:dim(m1$GG)[1],1:dim(m1$GG)[1],] = m1$GG
    model$GG[(dim(m1$GG)[1]+1):n,(dim(m1$GG)[1]+1):n,] = m2$GG
  }else{
    model$GG = magic::adiag(m1$GG,m2$GG)
  }
  model$m0 = matrix(c(m1$m0,m2$m0),n,1)
  model$C0 = magic::adiag(m1$C0,m2$C0)
  
  class(model) <- "exdqlm"
  return(model)
}

#' Print exDQLM model details
#'
#' Print the details of the exDQLM model.
#' @param x a \code{exdqlm} object.
#' @param ... further arguments (unused).
#' 
#' @export
print.exdqlm <- function(x,...){
  p <- length(x$m0)
  ff_dim <- .exdqlm_dim_label(x$FF)
  gg_dim <- .exdqlm_dim_label(x$GG)
  TT <- if (length(dim(x$FF)) >= 2L) ncol(as.matrix(x$FF)) else 1L
  gg_time <- length(dim(x$GG)) == 3L

  cat("Dynamic quantile state-space model specification (exdqlm)\n")
  cat("State dimension:", p, "\n")
  cat("Observation vector FF:", ff_dim, "\n")
  cat("Evolution matrix GG:", gg_dim, "\n")
  cat("Time-varying FF:", .exdqlm_yes_no(TT > 1L), "\n")
  cat("Time-varying GG:", .exdqlm_yes_no(gg_time), "\n")
  cat("Use with: exdqlmMCMC(), exdqlmLDVB(), exdqlmTransferMCMC(), or exdqlmTransferLDVB()\n")
  invisible(x)
}

#' Summary exDQLM model details
#'
#' Print the details of the exDQLM model.
#' @param object a \code{exdqlm} object.
#' @param ... further arguments (unused).
#' 
#' @export
summary.exdqlm <- function(object,...){
  out <- data.frame(
    Component = c("m0", "C0", "FF", "GG"),
    Description = c(
      "prior state mean",
      "prior state covariance",
      "observation vector/matrix",
      "evolution matrix/array"
    ),
    Dimension = c(
      .exdqlm_dim_label(object$m0),
      .exdqlm_dim_label(object$C0),
      .exdqlm_dim_label(object$FF),
      .exdqlm_dim_label(object$GG)
    ),
    check.names = FALSE
  )
  print.exdqlm(object, ...)
  cat("\nComponent dimensions:\n")
  print(out, row.names = FALSE)
  invisible(out)
}



##################################
###### "exdqlmFit" objects #######
##################################

.exdqlm_fit_print <- function(x) {
  conv <- .exdqlm_convergence_info(x)
  cat("Dynamic quantile state-space fit\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Model:", .exdqlm_model_family(x), "\n")
  cat("Inference engine:", .exdqlm_dynamic_engine(x), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(.exdqlm_safe_p0(x)), "\n")
  cat("Observations:", length(x$y), "\n")
  cat("State dimension:", length(x$model$m0), "\n")
  cat("Discount factors (dimensions):", .exdqlm_discount_label(x$df, x$dim.df), "\n")
  if (is.exdqlmMCMC(x)) {
    cat("Burn-in:", x$n.burn, "\n")
    cat("Posterior draws:", x$n.mcmc, "\n")
  } else {
    cat("Converged:", if (is.na(conv$converged)) "NA" else .exdqlm_yes_no(conv$converged), "\n")
    cat("Iterations:", if (is.null(conv$iter)) "NA" else conv$iter, "\n")
  }
  cat("State draws:", .exdqlm_array_dim(x$samp.theta), "\n")
  cat("Posterior predictive draws:", .exdqlm_draw_dim(x$samp.post.pred), "\n")
  cat("Run-time:", .exdqlm_runtime_label(x$run.time), "\n")
  cat("Use with: summary(), plot(), exdqlmDiagnostics(), exdqlmForecast()\n")
  invisible(x)
}

.exdqlm_fit_summary <- function(x) {
  draw_info <- data.frame(
    Quantity = c("state draws", "posterior predictive draws", "sigma draws", "gamma draws"),
    Dimension = c(
      .exdqlm_array_dim(x$samp.theta),
      .exdqlm_draw_dim(x$samp.post.pred),
      .exdqlm_draw_dim(x$samp.sigma),
      if (is.null(x$samp.gamma)) "not stored" else .exdqlm_draw_dim(x$samp.gamma)
    ),
    check.names = FALSE
  )
  conv <- .exdqlm_convergence_info(x)
  conv_info <- data.frame(
    Quantity = c("converged", "stop reason", "iterations"),
    Value = c(
      if (is.na(conv$converged)) "NA" else .exdqlm_yes_no(conv$converged),
      if (is.null(conv$stop_reason) || is.na(conv$stop_reason)) "not stored" else as.character(conv$stop_reason),
      if (is.null(conv$iter)) "NA" else as.character(conv$iter)
    ),
    check.names = FALSE
  )
  scalar_info <- .exdqlm_scalar_summary(x)

  .exdqlm_fit_print(x)
  cat("\nStored draws:\n")
  print(draw_info, row.names = FALSE)
  if (nrow(scalar_info)) {
    cat("\nScalar posterior summaries:\n")
    print(scalar_info, row.names = FALSE, digits = 4)
  }
  if (!is.exdqlmMCMC(x)) {
    cat("\nConvergence summary:\n")
    print(conv_info, row.names = FALSE)
  }

  invisible(list(draws = draw_info, scalar = scalar_info, convergence = conv_info))
}

#' Print Method for \code{exdqlmFit} Objects
#'
#' @param x A fitted dynamic \code{exdqlmFit} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exdqlmFit <- function(x, ...) {
  .exdqlm_fit_print(x)
}

#' Summary Method for \code{exdqlmFit} Objects
#'
#' @param object A fitted dynamic \code{exdqlmFit} object.
#' @param ... Additional arguments (unused).
#'
#' @export
summary.exdqlmFit <- function(object, ...) {
  .exdqlm_fit_summary(object)
}


##################################
###### "exdqlmMCMC" objects ######
##################################

#' \code{exdqlmMCMC} objects
#'
#' \code{is.exdqlmMCMC} tests if its argument is a \code{exdqlmMCMC} object. 
#' 
#' @usage is.exdqlmMCMC(m)
#'
#' @param m an \strong{R} object
#'
#' @export
is.exdqlmMCMC = function(m){ return(methods::is(m,"exdqlmMCMC")) }


#' Print Method for \code{exdqlmMCMC} Objects
#'
#' @param x An \code{exdqlmMCMC} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' print(M2)                
#' }
#'
print.exdqlmMCMC <- function(x, ...) {
  print.exdqlmFit(x, ...)
}

#' Summary Method for \code{exdqlmMCMC} Objects
#'
#' @param object An \code{exdqlmMCMC} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' summary(M2)                
#' }
#'
summary.exdqlmMCMC <- function(object, ...) {
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmMCMC} Objects
#'
#' @param x An \code{exdqlmMCMC} object.
#' @param ... Additional arguments.
#' 
#' @export
#'
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M2 = exdqlmMCMC(y, p0=0.85, model, df = c(0.98), dim.df = c(1),
#'                 gam.init = -3.5, sig.init = 15,
#'                 n.burn = 20, n.mcmc = 20,
#'                 init.from.vb = FALSE, verbose = FALSE)
#' plot(M2)                
#' }
#'
plot.exdqlmMCMC<- function(x, ...) {
  exdqlmPlot(x,...)
}



##################################
###### "exdqlmISVB" objects ######
##################################

#' \code{exdqlmISVB} objects
#'
#' \code{is.exdqlmISVB} tests if its argument is a \code{exdqlmISVB} object. 
#' 
#' @usage is.exdqlmISVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
#' 
#' 
is.exdqlmISVB = function(m){ return(methods::is(m,"exdqlmISVB")) }

#' Print Method for \code{exdqlmISVB} Objects
#'
#' @param x An \code{exdqlmISVB} object.
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
#' # Legacy ISVB object retained for backward-compatible inspection methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' print(M0)
#' options(old)
#' }
#'
print.exdqlmISVB <- function(x, ...) {
  print.exdqlmFit(x, ...)
}

#' Summary Method for \code{exdqlmISVB} Objects
#'
#' @param object An \code{exdqlmISVB} object.
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
#' # Legacy ISVB object retained for backward-compatible inspection methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' summary(M0)
#' options(old)
#' }
#'
summary.exdqlmISVB <- function(object, ...) {
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmISVB} Objects
#'
#' @param x An \code{exdqlmISVB} object.
#' @param ... Additional arguments. 
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' # Legacy ISVB object retained for backward-compatible plotting methods
#' M0 = exdqlmISVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.IS = 20, n.samp = 20, tol = 0.2,
#'                    verbose = FALSE)
#' plot(M0)
#' options(old)
#' }
#'
plot.exdqlmISVB <- function(x, ...) {
  exdqlmPlot(x,...)
}



##################################
###### "exdqlmLDVB" objects ######
##################################

#' \code{exdqlmLDVB} objects
#'
#' \code{is.exdqlmLDVB} tests if its argument is a \code{exdqlmLDVB} object. 
#' 
#' @usage is.exdqlmLDVB(m)
#'
#' @param m an \strong{R} object
#'
#' @export
#' 
#' 
is.exdqlmLDVB = function(m){ return(methods::is(m,"exdqlmLDVB")) }

#' Print Method for \code{exdqlmLDVB} Objects
#'
#' @param x An \code{exdqlmLDVB} object.
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
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.samp = 20, tol = 0.2, verbose = FALSE)
#' print(M0)
#' options(old)
#' }
#'
print.exdqlmLDVB <- function(x, ...) {
  print.exdqlmFit(x, ...)
}

#' Summary Method for \code{exdqlmLDVB} Objects
#'
#' @param object An \code{exdqlmLDVB} object.
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
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.samp = 20, tol = 0.2, verbose = FALSE)
#' summary(M0)
#' options(old)
#' }
#'
summary.exdqlmLDVB <- function(object, ...) {
  summary.exdqlmFit(object, ...)
}

#' Plot Method for \code{exdqlmLDVB} Objects
#'
#' @param x An \code{exdqlmLDVB} object.
#' @param ... Additional arguments. 
#' 
#' @export
#' 
#' @examples
#' \donttest{
#' data("scIVTmag", package = "exdqlm")
#' old = options(exdqlm.max_iter = 15L)
#' y = scIVTmag[1:60]
#' model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#' M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                    gam.init = -3.5, sig.init = 15,
#'                    n.samp = 20, tol = 0.2, verbose = FALSE)
#' plot(M0)
#' options(old)
#' }
#'
plot.exdqlmLDVB <- function(x, ...) {
  exdqlmPlot(x,...)
}


##################################
#### "exalStaticMCMC" / "exalStaticLDVB" ###
##################################

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
#' @export
summary.exalStaticFit <- function(object, max.coef = 6L, ...) {
  .exal_static_fit_summary(object, max.coef = max.coef)
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

##################################
### "exdqlmDiagnostic" objects ###
##################################

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
#' M0.diags = exdqlmDiagnostics(M0, plot=FALSE)
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
#' M0.diags = exdqlmDiagnostics(M0, plot = FALSE)
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
#' M0.diags = exdqlmDiagnostics(M0, plot = FALSE)
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
}




##################################
#### "exdqlmForecast" objects ####
##################################

#' \code{exdqlmForecast} objects
#'
#' \code{is.exdqlmForecast} tests if its argument is a \code{exdqlmForecast} object. 
#' 
#' @usage is.exdqlmForecast(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmForecast = function(x){ return(methods::is(x,"exdqlmForecast")) }

#' Print Method for \code{exdqlmForecast} Objects
#'
#' @param x An \code{exdqlmForecast} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  print(M0.forecast)
#'  options(old)
#' }
#'
print.exdqlmForecast <- function(x, ...) {
  cat("Dynamic quantile forecast\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Fitted model class:", .exdqlm_primary_class(x$m1), "\n")
  cat("Quantile level (p0):", .exdqlm_format_number(.exdqlm_safe_p0(x$m1)), "\n")
  cat("Observations in fitted model:", length(x$m1$y), "\n")
  cat("State dimension:", length(x$m1$model$m0), "\n")
  cat("Forecast start index:", x$start.t, "\n")
  cat("Forecast horizon:", x$k, "\n")
  cat("Credible interval mass:", .exdqlm_format_number(x$cr.percent), "\n")
  cat("Posterior forecast draws:", if (is.null(x$samp.fore)) "not stored" else ncol(as.matrix(x$samp.fore)), "\n")
  cat("Use with: summary(), plot(), exdqlmForecastDiagnostics()\n")
  invisible(x)
}

#' Summary Method for \code{exdqlmForecast} Objects
#'
#' @param object An \code{exdqlmForecast} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  summary(M0.forecast)
#'  options(old)
#' }
#'
summary.exdqlmForecast <- function(object, ...) {
  half.alpha <- (1 - object$cr.percent) / 2
  zlb <- stats::qnorm(half.alpha)
  zub <- stats::qnorm(object$cr.percent + half.alpha)
  out <- data.frame(
    step = seq_len(object$k),
    forecast_quantile = as.numeric(object$ff),
    forecast_variance = as.numeric(object$fQ),
    lower = as.numeric(object$ff + zlb * sqrt(pmax(object$fQ, 0))),
    upper = as.numeric(object$ff + zub * sqrt(pmax(object$fQ, 0))),
    check.names = FALSE
  )
  print.exdqlmForecast(object, ...)
  cat("\nForecast summary:\n")
  print(out, row.names = FALSE, digits = 4)
  invisible(out)
}

#' Plot Method for \code{exdqlmForecast} Objects
#'
#' @param x An \code{exdqlmForecast} object.
#' @param ... Additional arguments (unused).
#' 
#' @export
#' 
#' @examples
#' \donttest{
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 15L)
#'  y = scIVTmag[1:60]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15,
#'                   n.samp = 20, tol = 0.2, verbose = FALSE)
#'  M0.forecast = exdqlmForecast(start.t = 50, k = 5, m1 = M0)
#'  plot(M0.forecast)
#'  options(old)
#' }
#'
plot.exdqlmForecast <- function(x, ...) {
  aa = list(...)
  if(is.null(aa$cols)){cols=c("purple","magenta")}else{cols = aa$cols}
  if(is.null(aa$add)){add=FALSE}else{add=aa$add}
  
  y = x$m1$y
  p = dim(x$m1$model$GG)[1]
  TT = dim(x$m1$model$GG)[3]
  half.alpha = (1 - x$cr.percent)/2
  
  # filtered estimate for reference
  FF.start.t = matrix(x$m1$model$FF[,1:x$start.t], p, x$start.t)
  fm.start.t = matrix(x$m1$theta.out$fm[,1:x$start.t], p, x$start.t)
  qmap = colSums(matrix(FF.start.t*fm.start.t,p,x$start.t))
  fC.start.t = array(x$m1$theta.out$fC[,,1:x$start.t], c(p,p,x$start.t))
  temp.var = matrix(NA,p,x$start.t)
  for(t in 1:x$start.t){ temp.var[,t] = fC.start.t[,,t] %*% FF.start.t[,t] }
  qvar = colSums(FF.start.t * temp.var)
  qsd = sqrt(qvar)
  zlb = stats::qnorm(half.alpha)
  zub = stats::qnorm(x$cr.percent + half.alpha)
  qlb = qmap + zlb * qsd
  qub = qmap + zub * qsd
  # forecast estimates
  fqlb = x$ff + zlb * sqrt(x$fQ)
  fqub = x$ff + zub * sqrt(x$fQ)
  # filtered and forecasted quantiles & CrIs
  ts.xy = grDevices::xy.coords(y)
  if(!add){
    stats::plot.ts(y,xlim=c(ts.xy$x[x$start.t]-2*x$k*diff(ts.xy$x)[1],ts.xy$x[x$start.t]+x$k*diff(ts.xy$x)[1]),ylim=range(c(y,qlb,qub,fqlb,fqub)),type="l",ylab="quantile forecast",col="dark grey",xlab="time")
  }
  graphics::lines(ts.xy$x[1:x$start.t],qlb,col=cols[1],lty=3)
  graphics::lines(ts.xy$x[1:x$start.t],qub,col=cols[1],lty=3)
  graphics::lines(ts.xy$x[1:x$start.t],qmap,col=cols[1],lwd=1.5)
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qmap[x$start.t],x$ff),col=cols[2])
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qub[x$start.t],fqub),col=cols[2],lty=3)
  graphics::lines(seq(from = ts.xy$x[x$start.t], by = diff(ts.xy$x)[1], length.out = x$k+1),c(qlb[x$start.t],fqlb),col=cols[2],lty=3)
  
}

#### "exdqlmSynthesis" objects ####
####################################

#' \code{exdqlmSynthesis} objects
#'
#' \code{is.exdqlmSynthesis} tests if its argument is an
#' \code{exdqlmSynthesis} object returned by \code{\link{quantileSynthesis}}.
#'
#' @usage is.exdqlmSynthesis(x)
#'
#' @param x an \strong{R} object
#'
#' @export
is.exdqlmSynthesis <- function(x) {
  return(methods::is(x, "exdqlmSynthesis"))
}

#' Print Method for \code{exdqlmSynthesis} Objects
#'
#' @param x An \code{exdqlmSynthesis} object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.exdqlmSynthesis <- function(x, ...) {
  cat("Posterior predictive synthesis from separately fitted quantiles\n")
  cat("Class:", paste(class(x), collapse = ", "), "\n")
  cat("Time points:", nrow(as.matrix(x$draws)), "\n")
  cat("Synthesized draws per time:", ncol(as.matrix(x$draws)), "\n")
  cat("Number of input quantile levels:", length(x$levels), "\n")
  cat("Input quantile levels:", paste(format(x$levels), collapse = ", "), "\n")
  if (!is.null(x$method)) {
    cat("Isotonic correction:", isTRUE(x$method$isotonic), "\n")
    cat("Monotone rearrangement:", isTRUE(x$method$rearrange), "\n")
  }
  invisible(x)
}

#' Summary Method for \code{exdqlmSynthesis} Objects
#'
#' @param object An \code{exdqlmSynthesis} object.
#' @param time Optional vector of time values. If supplied, it must have length
#'   equal to the number of rows in \code{object$draws}.
#' @param ... Additional arguments (unused).
#'
#' @return A data frame containing pointwise summaries of the synthesized
#'   posterior predictive draws.
#'
#' @export
summary.exdqlmSynthesis <- function(object, time = NULL, ...) {
  TT <- nrow(as.matrix(object$draws))
  if (is.null(time)) {
    time <- seq_len(TT)
  } else if (length(time) != TT) {
    stop("time must have length equal to the number of synthesized time points")
  }
  data.frame(
    time = time,
    mean = as.numeric(object$summary$mean),
    q025 = as.numeric(object$summary$q025),
    q250 = as.numeric(object$summary$q250),
    q500 = as.numeric(object$summary$q500),
    q750 = as.numeric(object$summary$q750),
    q975 = as.numeric(object$summary$q975)
  )
}

#' Plot Method for \code{exdqlmSynthesis} Objects
#'
#' Plot the pointwise posterior predictive interval produced by
#' \code{\link{quantileSynthesis}}. The method is intentionally separate from
#' \code{quantileSynthesis()} so the synthesis step remains a computation,
#' while the returned object still has a standard plotting interface.
#'
#' @param x An \code{exdqlmSynthesis} object.
#' @param y Optional observed series to overlay.
#' @param time Optional time vector for the synthesized summaries. If omitted,
#'   \code{seq_len(T)} is used, where \code{T} is the number of synthesized time
#'   points.
#' @param add Logical; add the synthesis interval to an existing plot.
#' @param interval Numeric in \code{(0, 1)} giving the plotted central interval.
#'   Currently \code{0.50} and \code{0.95} are supported from stored summaries.
#' @param show.median Logical; draw the synthesized posterior median.
#' @param show.mean Logical; draw the synthesized posterior mean.
#' @param band.col Fill color for the predictive interval.
#' @param median.col Color for the posterior median line.
#' @param mean.col Color for the posterior mean line.
#' @param y.col Color for the optional observed series.
#' @param border Border color for the predictive interval polygon.
#' @param xlab,ylab,main Graphical labels.
#' @param xlim,ylim Optional axis limits.
#' @param ... Additional graphical arguments passed to the initial
#'   \code{plot()} call when \code{add = FALSE}.
#'
#' @export
plot.exdqlmSynthesis <- function(x, y = NULL, time = NULL, add = FALSE,
                                 interval = 0.95, show.median = TRUE,
                                 show.mean = FALSE,
                                 band.col = grDevices::adjustcolor("lightblue", alpha.f = 0.35),
                                 median.col = "blue",
                                 mean.col = "darkblue",
                                 y.col = "dark grey",
                                 border = NA,
                                 xlab = "time",
                                 ylab = "posterior predictive synthesis",
                                 main = NULL,
                                 xlim = NULL,
                                 ylim = NULL,
                                 ...) {
  if (!is.exdqlmSynthesis(x)) {
    stop("x must be an exdqlmSynthesis object")
  }

  TT <- nrow(as.matrix(x$draws))
  if (is.null(time)) {
    time <- seq_len(TT)
  } else if (length(time) != TT) {
    stop("time must have length equal to the number of synthesized time points")
  }

  interval <- as.numeric(interval)[1]
  if (!is.finite(interval) || !interval %in% c(0.50, 0.95)) {
    stop("interval must be either 0.50 or 0.95")
  }

  if (identical(interval, 0.50)) {
    lower <- as.numeric(x$summary$q250)
    upper <- as.numeric(x$summary$q750)
  } else {
    lower <- as.numeric(x$summary$q025)
    upper <- as.numeric(x$summary$q975)
  }
  median <- as.numeric(x$summary$q500)
  mean <- as.numeric(x$summary$mean)

  y_xy <- NULL
  if (!is.null(y)) {
    y_xy <- grDevices::xy.coords(y)
  }

  if (is.null(xlim)) {
    xlim <- range(time, if (!is.null(y_xy)) y_xy$x else time, finite = TRUE)
  }
  if (is.null(ylim)) {
    ylim <- range(lower, upper,
                  if (show.median) median else NULL,
                  if (show.mean) mean else NULL,
                  if (!is.null(y_xy)) y_xy$y else NULL,
                  finite = TRUE)
  }

  if (!isTRUE(add)) {
    graphics::plot(
      time, median,
      type = "n",
      xlim = xlim,
      ylim = ylim,
      xlab = xlab,
      ylab = ylab,
      main = main,
      ...
    )
  }

  graphics::polygon(c(time, rev(time)), c(lower, rev(upper)),
                    col = band.col, border = border)
  if (!is.null(y_xy)) {
    graphics::lines(y_xy$x, y_xy$y, col = y.col)
  }
  if (isTRUE(show.mean)) {
    graphics::lines(time, mean, col = mean.col, lwd = 1.25)
  }
  if (isTRUE(show.median)) {
    graphics::lines(time, median, col = median.col, lwd = 1.25)
  }

  invisible(x)
}
