# A new custom DGP, frozen before fitting or comparing forecasts.
# x has threshold/nonlinear dynamics; y adds a centered nonsinusoidal season.
nh_season <- function(t) {
  wave <- function(k) {
    p <- ((k-1) %% 60)/60
    distance <- function(center) pmin(abs(p-center),1-abs(p-center))
    pulse <- function(center,width) pmax(0,1-distance(center)/width)
    1.0*pulse(.18,.10)-.8*pulse(.64,.18)+.35*(2*p-1)+
      .18*ifelse(((k-1) %% 12)<4,1,-.5)
  }
  wave(t)-mean(wave(1:60))
}
nh_pulse <- function(t,center,width) {
  p <- ((t-1) %% 60)/60;d <- pmin(abs(p-center),1-abs(p-center))
  pmax(0,1-d/width)
}
nh_location <- function(lag) {
  a <- lag[1,];b <- lag[2,]
  ifelse(a<0,.58,.22)*a+.28*tanh(1.4*b)-.25*tanh(lag[12,])+
    .22*tanh(lag[60,])+.20*tanh(1.5*a*b)
}
nh_variance <- function(t,xlag,error,variance) {
  omega <- .008+.018*nh_pulse(t,.18,.10)+.012*nh_pulse(t,.64,.18)+
    .008*tanh(xlag)^2
  omega+.06*error^2+.10*error^2*(error<0)+.82*variance
}
nh_simulate <- function(n=3000L,seed=1766021L,burn=6000L) {
  stopifnot(n>=1L,burn>=60L,burn%%60L==0L)
  oldkind <- RNGkind();exists_seed <- exists(".Random.seed",.GlobalEnv,inherits=FALSE)
  if(exists_seed) oldseed <- get(".Random.seed",.GlobalEnv)
  on.exit({do.call(RNGkind,as.list(oldkind));if(exists_seed) assign(".Random.seed",oldseed,.GlobalEnv)
    else if(exists(".Random.seed",.GlobalEnv,inherits=FALSE)) rm(".Random.seed",envir=.GlobalEnv)},add=TRUE)
  RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(seed)
  total <- n+burn;z <- rnorm(total)
  lag <- matrix(0,60L,1L);variance <- .2;error <- 0
  x <- mu <- sd <- numeric(total)
  for(t in seq_len(total)) {
    variance <- nh_variance(t,lag[1,],error,variance)
    mu[t] <- nh_location(lag);sd[t] <- sqrt(variance)
    error <- sd[t]*z[t];x[t] <- mu[t]+error
    lag <- rbind(x[t],lag[1:59,,drop=FALSE])
  }
  at <- burn+seq_len(n);season <- nh_season(seq_len(n))
  data.frame(time=seq_len(n),y=season+x[at],season=season,residual=x[at],
    conditional_mean=season+mu[at],conditional_sd=sd[at],innovation=z[at])
}
