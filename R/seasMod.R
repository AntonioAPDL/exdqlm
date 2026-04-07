#' Create Fourier representation of a periodic exDQLM component
#'
#' The function creates a Fourier form periodic component for given period and harmonics.
#'
#' @param p Numeric period.
#' @param h  Numeric vector of harmonics to be included.
#' @param m0 Optional numeric prior mean. Defaults to \eqn{q \times 1} vector of zeros where \eqn{q} is the dimension of the period component. 
#' @param C0 Optional numeric prior covariance. Defaults to matrix \eqn{10^3 I_q}.
#' @param backend Backend selection for matrix construction:
#'   `"auto"` (default), `"R"`, or `"cpp"`.
#'
#' @return A object of class "\code{exdqlm}" containing the following:
#' \itemize{
#'   \item \code{FF} - \eqn{q \times 1} observational vector.
#'   \item \code{GG} - \eqn{q \times q} evolution matrix.
#'   \item \code{m0} - \eqn{q \times 1} prior mean of the state vector.
#'   \item \code{C0} - \eqn{q \times q} prior covariance matrix of the state vector.
#' }
#' @export
#'
#' @examples
#' # create a seasonal component with first, second and fourth harmonics of a period of 365
#' seas.comp = seasMod(365, c(1, 2, 4), C0 = 10*diag(6))
#'
seasMod = function(p, h, m0, C0, backend = c("auto", "R", "cpp")){
  backend <- match.arg(backend)
  build_r <- function(p, h) {
    nh = length(h)
    w = h * 2 * pi / p
    if( max(w) == pi){
      G = array(0,c(nh-1,2,2))
      for(i in 1:(nh-1)){
        G[i,1,1] =  cos(w[i])
        G[i,1,2] =  sin(w[i])
        G[i,2,1] = -sin(w[i])
        G[i,2,2] =  cos(w[i])
      }
      for(i in 1:(nh-1)){
        if(i == 1){ GG = G[1,,]}
        else{GG = magic::adiag(GG,G[i,,])}
      }
      GG = magic::adiag(GG,-1)
      FF = as.matrix(numeric(2*nh - 1))
      FF[1:(2*nh-1) %% 2 == 1] = 1
    }else{
      G = array(0,c(nh,2,2))
      for(i in 1:nh){
        G[i,1,1] =  cos(w[i])
        G[i,1,2] =  sin(w[i])
        G[i,2,1] = -sin(w[i])
        G[i,2,2] =  cos(w[i])
      }
      for(i in 1:nh){
        if(i == 1){ GG = G[1,,]}
        else{GG = magic::adiag(GG,G[i,,])}
      }
      FF = as.matrix(numeric(2*nh))
      FF[1:(2*nh) %% 2 == 1,] = 1
    }
    list(FF = FF, GG = GG)
  }

  build_cpp <- function(p, h) {
    if (!exists("cpp_build_seas_FF_GG", mode = "function")) {
      stop("C++ builder function cpp_build_seas_FF_GG() is not available.")
    }
    out <- cpp_build_seas_FF_GG(as.numeric(p), as.numeric(h))
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
      built <- build_cpp(p, h)
    } else {
      built <- tryCatch(
        build_cpp(p, h),
        error = function(e) {
          warning("C++ seas builder failed, falling back to R: ", conditionMessage(e))
          NULL
        }
      )
    }
  }
  if (is.null(built)) {
    built <- build_r(p, h)
  }

  FF <- built$FF
  GG <- built$GG
  if(!missing(m0)){
    if(length(m0) != nrow(GG)){stop("length of m0 does not match specified seasonal component(s)")}
    m0 = as.matrix(m0,nrow(GG),1)
  }else{
    m0 = as.matrix(numeric(nrow(GG)))
  }
  if(!missing(C0)){
    C0 = as.matrix(C0)
    if((nrow(C0) != nrow(GG)) || (ncol(C0) != nrow(GG))){stop("dimensions of C0 do not match specified seasonal component(s)")}
  }else{
    C0 = 1e3*diag(nrow(GG))
  }
  mod = list(FF = FF, GG = GG, m0 = m0, C0 = C0)
  
  class(mod) <- "exdqlm"
  return(mod)
}
