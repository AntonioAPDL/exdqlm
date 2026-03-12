#' Create an n-th order polynomial exDQLM component
#'
#' The function creates an n-th order polynomial exDQLM component.
#'
#' @param order Numeric order \eqn{n} of the polynomial model.
#' @param m0 Optional numeric prior mean. Defaults to \eqn{n \times 1} vector of zeros.
#' @param C0 Optional numeric prior covariance. Defaults to matrix \eqn{10^3 I_n}.
#' @param backend Backend selection for matrix construction:
#'   `"auto"` (default), `"R"`, or `"cpp"`.
#'
#' @return A object of class "\code{exdqlm}" containing the following:
#' \itemize{
#'   \item \code{FF} - \eqn{n \times 1} observational vector.
#'   \item \code{GG} - \eqn{n \times n} evolution matrix.
#'   \item \code{m0} - \eqn{n \times 1} prior mean of the state vector.
#'   \item \code{C0} - \eqn{n \times n} prior covariance matrix of the state vector.
#' }
#' @export
#'
#' @examples
#' # create a second order polynomial component
#' trend.comp = polytrendMod(2,rep(0,2),10*diag(2))
#' 
polytrendMod = function(order, m0, C0, backend = c("auto", "R", "cpp")){
  backend <- match.arg(backend)

  build_r <- function(order) {
    GG = diag(order)
    FF = as.matrix(numeric(order))
    if(order > 1){GG[(2:order-1)*order + (2:order-1)] = 1}
    FF[1] = 1
    list(FF = FF, GG = GG)
  }

  build_cpp <- function(order) {
    if (!exists("cpp_build_polytrend_FF_GG", mode = "function")) {
      stop("C++ builder function cpp_build_polytrend_FF_GG() is not available.")
    }
    out <- cpp_build_polytrend_FF_GG(as.integer(order))
    list(FF = as.matrix(out$FF), GG = as.matrix(out$GG))
  }

  use_cpp <- switch(
    backend,
    "R" = FALSE,
    "cpp" = TRUE,
    "auto" = isTRUE(getOption("exdqlm.use_cpp_builders", FALSE))
  )

  built <- NULL
  if (use_cpp) {
    if (backend == "cpp") {
      built <- build_cpp(order)
    } else {
      built <- tryCatch(
        build_cpp(order),
        error = function(e) {
          warning("C++ polytrend builder failed, falling back to R: ", conditionMessage(e))
          NULL
        }
      )
    }
  }
  if (is.null(built)) {
    built <- build_r(order)
  }

  FF <- built$FF
  GG <- built$GG
  if(!missing(m0)){
    if(length(m0) != order){stop("length of m0 does not match specified polynomial component")}
    m0 = as.matrix(m0,order,1)
  }else{
    m0 = as.matrix(numeric(order),order,1)
  }
  if(!missing(C0)){
    C0 = as.matrix(C0)
    if((nrow(C0) != order) || (ncol(C0) != order)){stop("dimensions of C0 do not match specified polynomial component")}
  }else{
    C0 = 1e3*diag(order)
  }
  mod = list(FF = FF, GG = GG, m0 = m0, C0 = C0)
  
  class(mod) <- "exdqlm"
  return(mod)
}
