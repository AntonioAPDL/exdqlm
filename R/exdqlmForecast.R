#' k-step-ahead quantile forecasts
#'
#' Computes filtered and \code{k}-step-ahead forecast quantiles from a fitted
#' dynamic quantile model and optionally adds them to an existing plot.
#'
#' @param start.t Integer index at which forecasts start (must be within the span of the fitted model in \code{m1}).
#' @param k Integer number of steps ahead to forecast.
#' @param m1 A fitted exDQLM model object, returned by [exdqlmLDVB()],
#'   [exdqlmMCMC()], or legacy [exdqlmISVB()].
#' @param fFF Optional state vector(s) for the forecast steps. A numeric matrix with
#'   \eqn{q} rows and either 1 column (non–time-varying) or \code{k} columns (time-varying).
#'   Its dimension must match the fitted model in \code{m1}.
#' @param fGG Optional evolution matrix/matrices for the forecast steps. Either a numeric
#'   \eqn{q \times q} matrix (non–time-varying) or a \eqn{q \times q \times k} array (time-varying).
#'   Its dimensions must match the fitted model in \code{m1}.
#' @param plot Logical value indicating whether to plot filtered and forecast quantiles with
#'   equal–tailed credible intervals. Default is \code{TRUE}.
#' @param add Logical value indicating whether to add the forecasted quantiles to the current plot.
#'   Default is \code{FALSE}.
#' @param cols Character vector of length 2 giving the colors for filtered and forecasted
#'   quantiles respectively. Default \code{c("purple","magenta")}.
#' @param cr.percent Numeric in \code{(0, 1)} indicating the probability mass for the credible
#'   intervals (e.g., \code{0.95}). Default \code{0.95}.
#' @param return.draws Logical; if \code{TRUE}, the function also returns a
#'   matrix of posterior predictive forecast draws in \code{samp.fore}. Default
#'   is \code{FALSE}.
#' @param n.samp Optional positive integer specifying how many forecast draws to
#'   return when \code{return.draws = TRUE}. If omitted, all available posterior
#'   \eqn{(\sigma,\gamma)} draws from \code{m1} are used.
#' @param seed Optional integer random seed used only for forecast-draw
#'   generation when \code{return.draws = TRUE}. If provided, the previous
#'   \proglang{R} RNG state is restored on exit.
#'
#' @return An object of class "\code{exdqlmForecast}" containing the following:
#' \itemize{
#'   \item \code{start.t} Integer index at which forecasts start (within the span of the fitted model in \code{m1}).
#'   \item \code{k} Integer number of steps ahead forecasted.
#'   \item \code{m1} The fitted exDQLM model object used to initialize the forecast.
#'   \item \code{cr.percent} The probability mass for the credible
#'   intervals (e.g., \code{0.95}).
#'   \item \code{fa} Forecast state mean vectors (\eqn{q \times k} matrix).
#'   \item \code{fR} Forecast state covariance matrices (\eqn{q \times q \times k} array).
#'   \item \code{ff} Forecast quantile means (length-\code{k} numeric).
#'   \item \code{fQ} Forecast quantile variances (length-\code{k} numeric).
#'   \item \code{samp.fore} Optional posterior predictive forecast draws
#'   (\code{k x n.samp}) returned when \code{return.draws = TRUE}.
#' }
#'
#' @examples
#' \donttest{
#'  # Toy example
#'  data("scIVTmag", package = "exdqlm")
#'  old = options(exdqlm.max_iter = 20L)
#'  y = scIVTmag[1:100]
#'  model = polytrendMod(1, stats::quantile(y, 0.85), 10)
#'  M0 = exdqlmLDVB(y, p0 = 0.85, model, df = c(0.98), dim.df = c(1),
#'                   gam.init = -3.5, sig.init = 15, n.samp = 30,
#'                   verbose = FALSE)
#'  exdqlmForecast(start.t = 90, k = 10, m1 = M0)
#'  M0.forecast = exdqlmForecast(start.t = 90, k = 10, m1 = M0,
#'                               return.draws = TRUE, n.samp = 50, seed = 123)
#'  dim(M0.forecast$samp.fore)
#'  options(old)
#' }
#'
#' @export

exdqlmForecast = function(start.t,k,m1,fFF=NULL,fGG=NULL,plot=TRUE,add=FALSE,cols=c("purple","magenta"),cr.percent=0.95,
                          return.draws=FALSE,n.samp=NULL,seed=NULL){

  # check inputs
  y = m1$y
  p = dim(m1$model$GG)[1]
  TT = dim(m1$model$GG)[3]
  if(!is.exdqlmMCMC(m1) && !is.exdqlmISVB(m1) && !is.exdqlmLDVB(m1)){
    stop("m1 must be an output from 'exdqlmLDVB()', 'exdqlmMCMC()', or legacy 'exdqlmISVB()'")
  }
  if(cr.percent<=0 | cr.percent>=1){
    stop("cr.percent must be between 0 and 1")
  }
  if(!is.logical(return.draws) || length(return.draws)!=1 || is.na(return.draws)){
    stop("return.draws must be TRUE or FALSE")
  }
  if(!is.null(n.samp)){
    n.samp = suppressWarnings(as.integer(n.samp)[1])
    if(!is.finite(n.samp) || n.samp<=0){
      stop("n.samp must be a positive integer")
    }
  }
  if(!is.null(seed)){
    seed = suppressWarnings(as.integer(seed)[1])
    if(!is.finite(seed)){
      stop("seed must be a finite integer")
    }
  }
  half.alpha = (1 - cr.percent)/2
  if(is.null(fFF)){
     if(TT-start.t < k){ stop("fFF and fGG must be provided for forecasts extending past the length of the estimated exdqlm")}
     fFF = m1$model$FF[,(start.t+1):(start.t+k),drop=FALSE]
     fGG = m1$model$GG[,,(start.t+1):(start.t+k),drop=FALSE]
  }else{
    if(is.null(fGG)){ stop("fGG must be provided when fFF is provided") }
    if(is.null(dim(fFF))){
      fFF = matrix(fFF,nrow=p)
    }else{
      fFF = as.matrix(fFF)
    }
    if(nrow(fFF) != p){ stop("dimension of fFF must match the estimated exdqlm") }
    if(!any(ncol(fFF) == c(1,k))){ stop("fFF must have either 1 (non-time-varying) or k (time-varying) columns")}
  }
  if(ncol(fFF) == 1 && k > 1){
    fFF = matrix(rep(fFF[,1],k),p,k)
  }else{
    fFF = matrix(fFF,p,k)
  }
  fGG.dim = dim(fGG)
  if(is.null(fGG.dim)){
    stop("fGG must be either a matrix (non-time-varying) or an array of depth k (time-varying)")
  }
  if(length(fGG.dim) == 2){
    if(any(fGG.dim != c(p,p))){ stop("dimension of fGG must match the estimated exdqlm") }
    fGG = array(rep(as.matrix(fGG),k),c(p,p,k))
  }else if(length(fGG.dim) == 3){
    if(any(fGG.dim[1:2] != c(p,p))){ stop("dimension of fGG must match the estimated exdqlm") }
    if(fGG.dim[3] != k){
      stop("fGG must be either a matrix (non-time-varying) or an array of depth k (time-varying)")
    }
    fGG = array(fGG,c(p,p,k))
  }else{
    stop("fGG must be either a matrix (non-time-varying) or an array of depth k (time-varying)")
  }

  #### forecast k steps
  df.mat = make_df_mat(m1$df,m1$dim.df,p)
  fm = m1$theta.out$fm[,start.t]
  fC = m1$theta.out$fC[,,start.t]
  fa = matrix(NA,p,k)
  fR = array(NA,c(p,p,k))
  ff = rep(NA,k)
  fQ = rep(NA,k)
  for(i in 1:k){
    if(i == 1){
      fa[,1] = fGG[,,i]%*%fm
      fR[,,1] = fGG[,,i]%*%fC%*%t(fGG[,,i]) + df.mat*fC
      ff[1] = t(fFF[,i])%*%fa[,1]
      fQ[1] = t(fFF[,i])%*%fR[,,1]%*%fFF[,i]
    }else{
      fa[,i] = fGG[,,i]%*%fa[,(i-1)]
      fR[,,i] = fGG[,,i]%*%fR[,,(i-1)]%*%t(fGG[,,i]) + df.mat*fR[,,(i-1)]
      ff[i] = t(fFF[,i])%*%fa[,i]
      fQ[i] = t(fFF[,i])%*%fR[,,i]%*%fFF[,i]
    }
  }

  samp.fore = NULL
  if(return.draws){
    sigma.draws = as.numeric(m1$samp.sigma)
    if(length(sigma.draws)==0){
      stop("m1 must contain posterior sigma draws when return.draws = TRUE")
    }
    if(isTRUE(m1$dqlm.ind) || is.null(m1$samp.gamma)){
      gamma.draws = rep(0,length(sigma.draws))
    }else{
      gamma.draws = as.numeric(m1$samp.gamma)
    }
    if(length(gamma.draws)==0){
      gamma.draws = rep(0,length(sigma.draws))
    }
    n.available = min(length(sigma.draws),length(gamma.draws))
    sigma.draws = sigma.draws[1:n.available]
    gamma.draws = gamma.draws[1:n.available]
    if(is.null(n.samp)){ n.samp = n.available }

    if(!is.null(seed)){
      has.seed = exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
      if(has.seed){
        old.seed = get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
      }
      on.exit({
        if(has.seed){
          assign(".Random.seed", old.seed, envir = .GlobalEnv)
        }else if(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)){
          rm(".Random.seed", envir = .GlobalEnv)
        }
      }, add = TRUE)
      set.seed(seed)
    }

    draw.index = if(n.samp <= n.available){
      1:n.samp
    }else{
      sample.int(n.available,size=n.samp,replace=TRUE)
    }
    sigma.draws = sigma.draws[draw.index]
    gamma.draws = gamma.draws[draw.index]

    q.fore = sweep(matrix(stats::rnorm(k*n.samp),k,n.samp),1,sqrt(pmax(fQ,0)),"*") + ff
    samp.fore = vapply(1:n.samp, function(j){
      rexal(k, p0 = m1$p0, mu = q.fore[,j], sigma = sigma.draws[j], gamma = gamma.draws[j])
    }, numeric(k))
    samp.fore = matrix(samp.fore, nrow = k, ncol = n.samp)
  }

  retlist = list(start.t=start.t,k=k,cr.percent=cr.percent,m1=m1,fa=fa,fR=fR,ff=ff,fQ=fQ,samp.fore=samp.fore)
  class(retlist) <- "exdqlmForecast"

  # plot forecast
  if(plot){ plot(retlist, cols = cols, add = add) }

  # return forecast distributions
  return(invisible(retlist))
}
