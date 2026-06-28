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

##################################
######## "exdqlm" objects ########
##################################
# included: is(), as(), "+", print(), summary()

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
  cat("\nDynamic quantile state-space model specification (exdqlm)\n\n")
  
  refnn <- c("m0","C0","FF","GG")
  descrip = c("Prior mean of the state vector:", 
              "Prior covariance of the state vector:",
              "Observational vector:",
              "Evolution matrix:")
  nn <- names(x)
  check <- !sapply(x, is.null)
  ind <- match(refnn,nn)
  ind <- ind[!is.na(ind)]
  final.ind = match(nn[ind][check[ind]],nn)
  # print
  for (i in 1:4){
    cat(descrip[i],"\n")
    print(x[final.ind[i]])
    cat("\n")
  }
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
  cat("\nComponent dimensions:\n")
  print(out, row.names = FALSE)
  
  TT <- if (length(dim(object$FF)) >= 2L) ncol(as.matrix(object$FF)) else 1L
  gg_time <- length(dim(object$GG)) == 3L
  
  cat("\nTime-varying FF:", .exdqlm_yes_no(TT > 1L), "\n")
  cat("Time-varying GG:", .exdqlm_yes_no(gg_time), "\n")
  
  invisible(out)
}