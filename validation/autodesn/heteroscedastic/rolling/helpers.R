# Validation adapters for the repository's rolling_origin_no_refit_state_update
# contract. Reservoir transitions are delegated to the shared Normal API.
hr_checkpoint <- function(fit, source_ids, diagnostics) {
  bank <- fit$bank; models <- fit$draws$model[source_ids]
  templates <- vector("list",length(bank$models))
  for(j in unique(models)) {
    x <- bank$templates[[j]]
    stopifnot(all(x$reservoir$Q_is_identity), identical(x$reservoir$act_k,"identity"))
    states <- lapply(x$states$H_all,function(z) as.numeric(z[nrow(z),]))
    templates[[j]] <- list(reservoir=x$reservoir,meta=x$meta,
      fit=list(target_label="normal_independent_ridge_autodesn"),states=list(H_last=states))
    class(templates[[j]]) <- c("qdesn_normal_fit","list")
  }
  list(draws=fit$draws[source_ids,,drop=FALSE],beta=fit$beta[source_ids],
    source_ids=source_ids,diagnostics=diagnostics,model_summary=fit$model_summary,
    bank=list(templates=templates,divisors=vapply(bank$models,`[[`,numeric(1),"divisor"),
      history=bank$history,history_scaled=bank$history_scaled,preprocessing=bank$preprocessing,
      keep_idx=bank$keep_idx,n=bank$n))
}
hr_probe <- function(template,state,history,new_observation) {
  D <- template$meta$D; n <- template$reservoir$n
  p <- 1L+sum(n)
  f <- forecast_paths.qdesn_normal_fit(template,H=1L,y_hist=history,origin_state=state,
    draws=list(beta=matrix(0,1L,p),omega2=1),innovations=matrix(0,1L,1L),
    y_future_obs=new_observation,return_design=TRUE,backend="batched")
  # Corrected readout order: intercept, last layer, then lower layers.
  x <- as.numeric(f$design[1L,1L,]); order <- c(D,seq_len(D-1L))
  result <- vector("list",D); start <- 2L
  for(d in order) { result[[d]] <- x[start+seq_len(n[d])-1L];start <- start+n[d] }
  result
}
hr_origin_states <- function(checkpoint,y_all,origins) {
  bank <- checkpoint$bank; T <- length(bank$history)
  stopifnot(identical(as.numeric(y_all[seq_len(T)]),as.numeric(bank$history)),
    all(origins>=T),all(origins<=length(y_all)),!is.unsorted(origins),!anyDuplicated(origins))
  z <- (y_all-bank$preprocessing$center)/bank$preprocessing$scale
  result <- vector("list",length(origins)); names(result) <- as.character(origins)
  active <- unique(checkpoint$draws$model)
  current <- lapply(bank$templates,function(x) if(is.null(x)) NULL else x$states$H_last)
  at <- T
  for(i in seq_along(origins)) {
    while(at<origins[i]) {
      for(j in active) current[[j]] <- hr_probe(bank$templates[[j]],current[[j]],z[seq_len(at)],z[at+1L])
      at <- at+1L
    }
    result[[i]] <- current
  }
  list(states=result,history_scaled=z)
}
hr_auto <- function(checkpoint,origin_state,history_scaled,H,K,innovations) {
  ids <- rep(seq_len(nrow(checkpoint$draws)),each=K)
  model <- checkpoint$draws$model[ids]; bank <- checkpoint$bank
  mu <- y <- matrix(NA_real_,H,length(ids))
  for(j in unique(model)) {
    cols <- which(model==j);beta <- do.call(rbind,checkpoint$beta[ids[cols]])
    beta[,-1L] <- beta[,-1L,drop=FALSE]/bank$divisors[j]
    fc <- forecast_paths.qdesn_normal_fit(bank$templates[[j]],H,y_hist=history_scaled,
      origin_state=origin_state[[j]],draws=list(beta=beta,omega2=checkpoint$draws$variance[ids[cols]]),
      innovations=innovations[,cols,drop=FALSE],backend="batched")
    y[,cols] <- fc$yrep;mu[,cols] <- fc$mu_draws
  }
  list(yrep=.autodesn_unscale(bank,y),mu_draws=.autodesn_unscale(bank,mu),
    sd_draws=matrix(sqrt(checkpoint$draws$variance[ids])*bank$preprocessing$scale,H,length(ids),byrow=TRUE),
    model=model,source_draw=checkpoint$source_ids[ids],origin=length(history_scaled))
}
hr_noise <- function(seed,origin,K,H=30L,n_outer=192L) {
  # Origin 2500 replays a subset of the frozen original 100-step noise bank.
  .autodesn_seed(if(origin==2500L) seed+400L else seed+100000L+origin,function() {
    block <- if(origin==2500L) 128L else 32L
    stopifnot(K<=block,H<=100L)
    all <- matrix(rnorm(100L*n_outer*block),100L)
    cols <- as.vector(outer(seq_len(K),(seq_len(n_outer)-1L)*block,"+"))
    all[seq_len(H),cols,drop=FALSE]
  })
}
hr_gjr_origins <- function(object,history,origins,initial_origin=2500L) {
  at <- initial_origin;out <- vector("list",length(origins));p <- object$parameters
  for(i in seq_along(origins)) {
    while(at<origins[i]) {
      object$variance <- unname(p[3]+p[4]*object$error^2+p[5]*object$error^2*(object$error<0)+p[6]*object$variance)
      object$error <- history[at+1L]-p[1]-p[2]*object$last_y
      object$last_y <- history[at+1L];at <- at+1L
    }
    out[[i]] <- object
  }
  out
}
