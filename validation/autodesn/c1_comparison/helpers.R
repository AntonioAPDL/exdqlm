# Study adapters only: production inference and reservoir transitions stay intact.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
source("validation/autodesn/heteroscedastic/forecasting.R")
source("validation/autodesn/heteroscedastic/rolling/helpers.R")
c1_root <- "validation/autodesn/c1_comparison"
c1_config <- function() jsonlite::fromJSON(file.path(c1_root,"configuration.json"), simplifyVector=TRUE)
c1_data <- function() {
  x <- read.csv(file.path(c1_root,"input/C1.csv"))
  stopifnot(identical(x$time,1:3000), all(is.finite(x$y)))
  x
}
c1_save <- function(x,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  tmp <- paste0(path,".partial")
  saveRDS(x,tmp,compress=FALSE)
  stopifnot(isTRUE(all.equal(x,readRDS(tmp),check.environment=FALSE)))
  stopifnot(file.rename(tmp,path))
}
c1_json <- function(x,path) jsonlite::write_json(x,path,auto_unbox=TRUE,pretty=TRUE,digits=16,na="null")

# Vectorize only the exact conditional model scores. Gibbs update order, priors,
# coefficient sampling and the RNG stream are inherited from autodesn_fit_bank.
c1_score_cache <- function(bank) {
  lapply(split(seq_along(bank$models),lengths(lapply(bank$models,`[[`,"spectrum"))),function(ids) {
    mm <- bank$models[ids]
    list(ids=ids,spectrum=do.call(cbind,lapply(mm,`[[`,"spectrum")),
      u1=do.call(cbind,lapply(mm,`[[`,"u1")),uy=do.call(cbind,lapply(mm,`[[`,"uy")),
      ry2=vapply(mm,`[[`,0,"ry2"),r12=vapply(mm,`[[`,0,"r12"),
      r1y=vapply(mm,`[[`,0,"r1y"),n=bank$n)
  })
}
c1_grouped <- function(cache,bank,variance,ridge_precision,intercept_variance=10) {
  out <- numeric(length(bank$models)); v0 <- intercept_variance
  for(g in cache) {
    den <- variance+g$spectrum/ridge_precision
    q1 <- g$r12/variance+colSums(g$u1^2/den)
    c1y <- g$r1y/variance+colSums(g$u1*g$uy/den)
    mu0 <- c1y/(1/v0+q1)
    r <- g$ry2-2*mu0*g$r1y+mu0^2*g$r12
    stopifnot(all(r >= -1e-10*pmax(1,g$ry2,mu0^2*g$r12)))
    quadratic <- pmax(0,r)/variance+colSums((g$uy-sweep(g$u1,2,mu0,"*"))^2/den)+mu0^2/v0
    logdet <- (g$n-nrow(den))*log(variance)+colSums(log(den))+log1p(v0*q1)
    out[g$ids] <- -.5*(g$n*log(2*pi)+logdet+quadratic)
  }
  .autodesn_softmax(log(bank$prior)+out)
}
c1_sampler <- function(bank) {
  cache <- c1_score_cache(bank)
  e <- new.env(parent=environment(autodesn_fit_bank))
  e$.autodesn_model_probabilities <- function(bank,variance,ridge_precision,intercept_variance=10)
    c1_grouped(cache,bank,variance,ridge_precision,intercept_variance)
  f <- autodesn_fit_bank;environment(f) <- e;f
}
c1_extract_states <- function(x,n) {
  D <- length(n); order <- c(D,seq_len(D-1L)); result <- vector("list",D); at <- 2L
  for(d in order) {result[[d]] <- as.numeric(x[at+seq_len(n[d])-1L]);at <- at+n[d]}
  result
}
c1_lean_template <- function(x) {
  out <- list(reservoir=x$reservoir,meta=x$meta,
    fit=list(target_label="normal_independent_ridge_autodesn"),
    states=list(H_last=lapply(x$states$H_all,function(h) as.numeric(h[nrow(h),]))))
  class(out) <- c("qdesn_normal_fit","list");out
}
c1_warmup <- function(template,z,drop=500L) {
  n <- template$reservoir$n; m <- as.integer(template$meta$m_input)
  stopifnot(m < drop)
  expected <- unlist(lapply(template$states$H_all,function(h) as.numeric(h[drop,])))
  errors <- vapply(c(-1,1),function(sign) {
    fc <- forecast_paths.qdesn_normal_fit(c1_lean_template(template),H=drop-m,
      y_hist=z[seq_len(m)],origin_state=lapply(n,function(k) rep(sign,k)),
      y_future_obs=z[m+seq_len(drop-m)],draws=list(beta=matrix(0,1,1+sum(n)),omega2=1),
      innovations=matrix(0,drop-m,1),return_design=TRUE,backend="batched")
    state <- c1_extract_states(fc$design[drop-m,1,],n)
    max(abs(unlist(state)-expected))
  },0)
  max(errors)
}
c1_build_bank <- function(y,cfg,outdir) {
  recovered <- readRDS(file.path(c1_root,"input/specifications.rds"))
  specs <- recovered[["3_specifications"]]; grid <- recovered[["2_grid"]]
  stopifnot(length(specs)==456L,identical(names(specs),grid$candidate))
  build <- function(j) {
    one <- autodesn_build_bank(y,specs[j],conditioning=cfg$washout,washout=cfg$washout)
    template <- one$templates[[1]];model <- one$models[[1]]
    error <- c1_warmup(template,one$history_scaled,cfg$washout)
    h <- do.call(cbind,template$states$H_all)[one$keep_idx,,drop=FALSE]
    audit <- data.frame(candidate=grid$candidate[j],warmup_error=error,
      admitted=is.finite(error)&&error<=cfg$washout_tolerance,
      saturation_fraction=mean(abs(h)>.99),constant_features=sum(apply(h,2,sd)<1e-8),
      feature_rank=qr(model$X)$rank,slopes=model$d,finite=all(is.finite(model$X)))
    base <- one[c("y","n","normalize_features","keep_idx","history","history_scaled","preprocessing","meta")]
    list(model=model,template=c1_lean_template(template),audit=audit,base=if(j==1L) base else NULL)
  }
  # Small batches bound temporary full-history states and survive interruptions.
  cache_dir <- file.path(outdir,"bank_parts");dir.create(cache_dir,recursive=TRUE,showWarnings=FALSE)
  for(start in seq(1,length(specs),by=8)) {
    ids <- seq.int(start,min(length(specs),start+7))
    missing <- ids[!file.exists(file.path(cache_dir,sprintf("part_%03d.rds",ids)))]
    if(length(missing)) {
      parts <- parallel::mclapply(missing,build,mc.cores=cfg$desn_feature_workers,mc.set.seed=FALSE)
      for(i in seq_along(parts)) {
        if(inherits(parts[[i]],"try-error")) stop(parts[[i]])
        c1_save(parts[[i]],file.path(cache_dir,sprintf("part_%03d.rds",missing[i])))
      }
    }
    cat("Built/audited",max(ids),"/",length(specs),"specifications\n");flush.console()
  }
  parts <- lapply(seq_along(specs),function(j) readRDS(file.path(cache_dir,sprintf("part_%03d.rds",j))))
  audit <- do.call(rbind,lapply(parts,`[[`,"audit"))
  write.csv(cbind(grid,audit[,-1]),file.path(outdir,"specification_audit.csv"),row.names=FALSE)
  keep <- which(audit$admitted);stopifnot(length(keep)>0,all(audit$finite))
  bank <- parts[[1]]$base
  bank$models <- lapply(parts[keep],`[[`,"model");bank$templates <- lapply(parts[keep],`[[`,"template")
  bank$specifications <- specs[keep];bank$model_info <- cbind(model=seq_along(keep),grid[keep,])
  counts <- table(bank$model_info$D)
  bank$prior <- 1/(length(counts)*as.numeric(counts[as.character(bank$model_info$D)]))
  class(bank) <- "autodesn_bank";stopifnot(identical(bank$keep_idx,501:2500),bank$n==2000L)
  # Individual numerical feature checkpoints can be reconstructed; keep them
  # locally for resume but omit their large X matrices from CI artifacts.
  bank
}
c1_compact <- function(fit,ids,dg) {
  bank <- fit$bank
  templates <- lapply(bank$templates,function(x) if(!is.null(x$states$H_all)) c1_lean_template(x) else x)
  list(draws=fit$draws[ids,,drop=FALSE],beta=fit$beta[ids],source_ids=ids,diagnostics=dg,
    model_summary=fit$model_summary,bank=list(templates=templates,
      divisors=vapply(bank$models,`[[`,0,"divisor"),history=bank$history,
      history_scaled=bank$history_scaled,preprocessing=bank$preprocessing,keep_idx=bank$keep_idx,n=bank$n))
}
c1_noise <- function(seed,origin,K,n_outer,H=30L) {
  .autodesn_seed(seed+100000L+origin,function() {
    all <- matrix(rnorm(H*384L*32L),H)
    cols <- as.vector(outer(seq_len(K),(seq_len(n_outer)-1L)*32L,"+"))
    all[,cols,drop=FALSE]
  })
}
c1_desn_score <- function(fc,actual,origin) {
  hh_logmean <- function(x) {a <- max(x);a+log(mean(exp(x-a)))}
  environment(hh_score) <- environment()
  x <- hh_score(fc,actual,rep(NA_real_,length(actual)),rep(NA_real_,length(actual)))
  x$origin <- origin;x$target <- origin+x$horizon;x$model <- "AutoDESN"
  x[,!names(x)%in%c("latent","latent_squared_error","oracle_mean_squared_error")]
}
