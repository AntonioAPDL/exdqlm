source("validation/autodesn/c1_comparison/helpers.R")
cfg <- c1_config();y <- c1_data()$y;out <- file.path(c1_root,"artifacts/desn")
dir.create(out,recursive=TRUE,showWarnings=FALSE);started <- proc.time()[3]
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
cpfile <- file.path(out,"posterior_checkpoint.rds")
if(file.exists(cpfile)) cp <- readRDS(cpfile) else {
  bank <- c1_build_bank(y[1:cfg$fit_end],cfg,out);sampler <- c1_sampler(bank);gc()
  for(attempt in seq_len(nrow(cfg$desn_attempts))) {
    controls <- cfg$desn_attempts[attempt,];adir <- file.path(out,paste0("attempt_",attempt))
    dir.create(adir,showWarnings=FALSE)
    run <- function(k) {
      path <- file.path(adir,paste0("chain_",k,".rds"))
      if(file.exists(path)) return(readRDS(path))
      f <- sampler(bank,n_burn=controls$n_burn,n_mcmc=controls$n_mcmc,
        initial_variance=c(.1,1,5)[k],ridge_precision=c(.1,1,10)[k],
        seed=cfg$desn_seed+10000L*(attempt-1L)+k)
      small <- f;small$bank <- NULL;c1_save(small,path);small
    }
    cat("Gibbs attempt",attempt,"3 chains,",controls$n_burn,"burn +",controls$n_mcmc,"retained\n");flush.console()
    fits <- parallel::mclapply(1:3,run,mc.cores=cfg$desn_chain_workers,mc.set.seed=FALSE)
    if(any(vapply(fits,function(x) inherits(x,"try-error")||!inherits(x,"autodesn_fit"),FALSE)))
      stop("Gibbs chain failed; resume from the completed individual chain checkpoints")
    fits <- lapply(fits,function(f) {f$bank <- bank;f})
    dg <- autodesn_diagnostics(fits)
    write.csv(dg$parameters,file.path(adir,"diagnostics.csv"),row.names=FALSE)
    write.csv(dg$models,file.path(adir,"model_probabilities.csv"),row.names=FALSE)
    qualified <- hh_qualify(dg);c1_json(list(qualified=qualified,attempt=attempt),file.path(adir,"status.json"))
    if(qualified) break
    rm(fits);gc()
  }
  if(!qualified) stop("AutoDESN failed the frozen convergence screens; retain evidence, do not label complete")
  fit <- lh_pool(fits)
  ids <- .autodesn_seed(cfg$desn_seed+200L,function() sample.int(nrow(fit$draws),cfg$checkpoint_draws))
  cp <- c1_compact(fit,ids,dg);c1_save(cp,cpfile)
  write.csv(dg$models,file.path(out,"model_probabilities.csv"),row.names=FALSE)
  write.csv(dg$parameters,file.path(out,"diagnostics.csv"),row.names=FALSE)
  rm(bank,fit,fits,sampler);gc()
}
origins <- cfg$first_origin:cfg$last_origin
states <- hr_origin_states(cp,y[1:max(origins)],origins)
primary <- cp;primary$draws <- cp$draws[1:cfg$outer_draws,];primary$beta <- cp$beta[1:cfg$outer_draws]
primary$source_ids <- cp$source_ids[1:cfg$outer_draws]
for(start in seq(1,length(origins),by=8)) {
  ids <- seq.int(start,min(length(origins),start+7L))
  run <- function(i) {
    origin <- origins[i];path <- file.path(out,sprintf("origin_%04d.csv",origin))
    if(file.exists(path)) return(NULL)
    fc <- hr_auto(primary,states$states[[i]],states$history_scaled[1:origin],cfg$H,cfg$inner_paths,
      c1_noise(cfg$desn_seed,origin,cfg$inner_paths,cfg$outer_draws,cfg$H))
    score <- c1_desn_score(fc,y[origin+1:cfg$H],origin)
    write.csv(score,path,row.names=FALSE)
    if(origin%in%c(2500L,2735L,2970L)) c1_save(fc,file.path(out,paste0("forecast_",origin,".rds")))
    NULL
  }
  result <- parallel::mclapply(ids,run,mc.cores=cfg$desn_origin_workers,mc.set.seed=FALSE)
  if(any(vapply(result,inherits,FALSE,"try-error"))) stop("Rolling forecast failed")
  cat("AutoDESN origins",max(ids),"/",length(origins),"complete\n");flush.console()
}
scores <- do.call(rbind,lapply(origins,function(origin) read.csv(file.path(out,sprintf("origin_%04d.csv",origin)))))
write.csv(scores,file.path(out,"scores.csv"),row.names=FALSE)
sensitivity <- list()
for(origin in c(2500L,2735L,2970L)) for(N in c(192L,384L)) for(K in c(4L,8L,16L,32L)) {
  p <- cp;p$draws <- cp$draws[1:N,];p$beta <- cp$beta[1:N];p$source_ids <- cp$source_ids[1:N]
  i <- match(origin,origins)
  fc <- hr_auto(p,states$states[[i]],states$history_scaled[1:origin],cfg$H,K,c1_noise(cfg$desn_seed,origin,K,N,cfg$H))
  z <- c1_desn_score(fc,y[origin+1:cfg$H],origin);z$outer_draws <- N;z$inner_paths <- K
  sensitivity[[length(sensitivity)+1L]] <- z
}
write.csv(do.call(rbind,sensitivity),file.path(out,"mc_sensitivity.csv"),row.names=FALSE)
c1_json(list(complete=TRUE,model="AutoDESN",origins=length(origins),fit_rows=2000,
  qualified=TRUE,elapsed_seconds=unname(proc.time()[3]-started),outer_draws=cfg$outer_draws,
  inner_paths=cfg$inner_paths,source_manifest=.autodesn_source_manifest),file.path(out,"status.json"))
