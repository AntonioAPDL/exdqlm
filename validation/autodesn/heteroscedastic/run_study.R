# Run from the repository root; source once, then leave inference files frozen.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
source("validation/autodesn/heteroscedastic/dgp.R")
source("validation/autodesn/heteroscedastic/forecasting.R")
main <- function() {
  out <- Sys.getenv("AUTODESN_HETERO_OUT", "validation/autodesn/heteroscedastic/artifacts")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  specs <- lh_specs()
  cfg <- list(schema = "autodesn_500_2000_100_heteroscedastic_v1", washout = 500L,
    conditioning = 500L, n_train = 2000L, H = 100L, repetitions = 3L,
    kinds = hh_kinds, chains = 3L, outer_draws = 192L, inner_paths = 64L,
    max_inner_paths = 128L, quantile_type = 8L,
    cores = as.integer(Sys.getenv("AUTODESN_HETERO_CORES", "1")),
    diagnostic_attempts = data.frame(n_burn = c(2000L,4000L,6000L), n_mcmc = c(6000L,16000L,32000L)),
    retry_rule = "Before any future forecast scoring: retry only if Rhat>1.01, spectral ESS<400 or model chain range>.05. Record every attempt; never tune on scores.",
    specifications = specs$specifications, fixed_index = specs$fixed_index,
    source_revision_at_launch = system2("/usr/bin/git", c("rev-parse","HEAD"), stdout = TRUE),
    fixed_origin = "Issue once at 2500; simulated response feedback only.",
    prequential = "Issue each one-step forecast before observing its target. Feed observed target back afterwards; no refitting or posterior/model-weight updates.",
    likelihood = "AutoDESN Gaussian constant innovation variance; independent Gaussian ridge prior, no RHS.",
    gjr_reference = "AR(1)-GJR(1,1) plugin conditional Gaussian maximum likelihood; 3 fixed optimization starts; no parameter uncertainty.",
    oracle_reference = "Known parameters; observation-filtered hidden regime, never simulated latent states.")
  stopifnot(cfg$cores >= 1L)
  if (file.exists(file.path(out,"configuration.R"))) stop("Frozen output exists; choose a new directory")
  dput(cfg,file.path(out,"configuration.R"))
  write.csv(specs$grid,file.path(out,"specifications.csv"),row.names=FALSE)
  sources <- c(list.files("R",pattern="\\.R$",full.names=TRUE),
    "validation/autodesn/load_checkout.R", "validation/autodesn/long_horizon/helpers.R",
    list.files("validation/autodesn/heteroscedastic",pattern="\\.R$",full.names=TRUE))
  write.csv(data.frame(path=sources,md5=unname(tools::md5sum(sources))),file.path(out,"launch_source_manifest.csv"),row.names=FALSE)
  started <- proc.time()[[3L]]
  scores <- probability <- diagnostics <- observed <- audit <- sensitivity <- gjr_fits <- gjr_starts <- list()
  save_all <- function() {
    for(name in c("scores","probability","diagnostics","observed","audit","sensitivity","gjr_fits","gjr_starts")) {
      x <- get(name, envir = parent.frame())
      if(length(x)) write.csv(do.call(rbind,x),file.path(out,paste0(name,".csv")),row.names=FALSE)
    }
  }
  fit_checked <- function(bank,seed,kind,r,method) {
    for(attempt in seq_len(nrow(cfg$diagnostic_attempts))) {
      control <- cfg
      control$n_burn <- cfg$diagnostic_attempts$n_burn[attempt]
      control$n_mcmc <- cfg$diagnostic_attempts$n_mcmc[attempt]
      cat(sprintf("  %s attempt %d: 3 chains, %d burn + %d retained each\n",method,attempt,control$n_burn,control$n_mcmc));flush.console()
      if (attempt > 1L) { rm(fitted); invisible(gc()) }
      fitted <- hh_fit(bank,control,seed+(attempt-1L)*10000L,cfg$cores)
      dg <- fitted$diagnostics
      diagnostics[[length(diagnostics)+1L]] <<- cbind(dgp=kind,repetition=r,method=method,
        attempt=attempt,diagnostic_screen_pass=hh_qualify(dg),n_burn=control$n_burn,
        retained_per_chain=control$n_mcmc,max_model_chain_range=max(dg$models$chain_range),dg$parameters)
      write.csv(do.call(rbind,diagnostics),file.path(out,"diagnostics.csv"),row.names=FALSE)
      if(hh_qualify(dg)) break
    }
    fitted
  }
  origin <- cfg$washout+cfg$n_train; N <- cfg$outer_draws*cfg$inner_paths
  for(kind in cfg$kinds) for(r in seq_len(cfg$repetitions)) {
    case_started <- proc.time()[[3L]]; id <- sprintf("%s_r%02d",kind,r)
    seed <- 863000L+match(kind,cfg$kinds)*1000L+r*20L
    cat(sprintf("\n%s: warmup 1:500; fit 501:2500; test 2501:2600\n",id));flush.console()
    dgp <- hh_simulate(kind,origin+cfg$H,seed)
    history <- dgp$y[seq_len(origin)]
    bank <- autodesn_build_bank(history,cfg$specifications,conditioning=500L,washout=500L)
    stopifnot(identical(bank$keep_idx,501:2500),bank$n==2000L,
      all(vapply(bank$templates,function(z) all(z$reservoir$Q_is_identity),TRUE)),
      all(vapply(bank$templates,function(z) ncol(z$X)==sum(z$reservoir$n)+1L,TRUE)))
    auto_fit <- fit_checked(bank,seed+100L,kind,r,"AutoDESN")
    probability[[length(probability)+1L]] <- cbind(dgp=kind,repetition=r,auto_fit$diagnostics$models,
      specs$grid[,c("width","profile")])
    fixed_bank <- autodesn_build_bank(history,cfg$specifications[cfg$fixed_index],conditioning=500L,washout=500L)
    fixed_fit <- fit_checked(fixed_bank,seed+200L,kind,r,"Fixed_DESN")
    ids <- .autodesn_seed(seed+300L,function() sample.int(nrow(auto_fit$fit$draws),cfg$outer_draws,replace=TRUE))
    fixed_ids <- .autodesn_seed(seed+301L,function() sample.int(nrow(fixed_fit$fit$draws),cfg$outer_draws,replace=TRUE))
    noise <- .autodesn_seed(seed+400L,function() matrix(rnorm(cfg$H*cfg$outer_draws*cfg$max_inner_paths),cfg$H))
    select_K <- function(K) as.vector(outer(seq_len(K),(seq_len(cfg$outer_draws)-1L)*cfg$max_inner_paths,"+"))
    z <- noise[,select_K(cfg$inner_paths)]
    gaussian <- list(Gaussian_AR1=hh_gaussian_fit(bank,1L,N,seed+701L),
      Gaussian_AR12=hh_gaussian_fit(bank,12L,N,seed+712L),
      Constant=hh_gaussian_fit(bank,0L,N,seed+700L))
    gjr <- hh_gjr_fit(history,bank$keep_idx)
    gjr_fits[[length(gjr_fits)+1L]] <- data.frame(dgp=kind,repetition=r,
      as.list(gjr$parameters),objective=gjr$objective,convergence=gjr$convergence,selected_start=gjr$selected_start)
    gjr_starts[[length(gjr_starts)+1L]] <- cbind(dgp=kind,repetition=r,gjr$starts)
    actual <- dgp$y[origin+seq_len(cfg$H)]; latent <- dgp$mu[origin+seq_len(cfg$H)]
    filtered <- hh_filter(kind,history)
    boundaries <- quantile(filtered$predictive_sd[bank$keep_idx],c(.25,.75),type=8)
    one_oracle <- hh_oracle(kind,history,cfg$H,N,seed+600L,actual)
    volatility <- as.character(cut(one_oracle$exact_sd,c(-Inf,boundaries,Inf),labels=c("low","middle","high")))
    for(mode in c("fixed_origin","one_step")) {
      feedback <- if(mode=="one_step") actual else NULL
      auto <- hh_auto(auto_fit$fit,cfg$H,ids,cfg$inner_paths,z,feedback)
      fixed <- hh_auto(fixed_fit$fit,cfg$H,fixed_ids,cfg$inner_paths,z,feedback)
      oracle <- if(mode=="one_step") one_oracle else hh_oracle(kind,history,cfg$H,N,seed+600L)
      candidates <- c(list(AutoDESN=auto,Fixed_DESN=fixed),
        lapply(gaussian,function(g) hh_gaussian(g,cfg$H,z,feedback)),
        list(AR1_GJR_GARCH=hh_gjr(gjr,cfg$H,z,feedback),Oracle_DGP=oracle))
      stopifnot(length(candidates)==7L,auto$origin==2500L)
      for(method in names(candidates)) {
        score <- hh_score(candidates[[method]],actual,latent,rowMeans(oracle$mu_draws))
        score$oracle_one_step_sd <- one_oracle$exact_sd
        score$volatility_group <- volatility
        score$sd_to_oracle_one_step <- if(mode=="one_step") score$predictive_sd/one_oracle$exact_sd else NA_real_
        scores[[length(scores)+1L]] <- cbind(dgp=kind,repetition=r,mode=mode,method=method,score)
      }
      if(mode=="fixed_origin") {
        show <- as.integer(round(seq.int(1L,N,length.out=64L)))
        write.csv(data.frame(horizon=seq_len(cfg$H),auto$yrep[,show]),file.path(out,paste0(id,"_paths.csv")),row.names=FALSE)
        write.csv(data.frame(path=seq_along(show),column=show,source_draw=auto$draw_index[show],
          outer_draw=auto$outer_draw_index[show],inner_path=auto$inner_path_index[show],model=auto$model[show]),
          file.path(out,paste0(id,"_path_indices.csv")),row.names=FALSE)
        write.csv(data.frame(horizon=seq_len(cfg$H),auto$mean_conditional_location),
          file.path(out,paste0(id,"_mean_location_by_draw.csv")),row.names=FALSE)
        if(kind==hh_kinds[1L] && r==1L) for(K in c(32L,64L,128L)) {
          fc <- if(K==cfg$inner_paths) auto else hh_auto(auto_fit$fit,cfg$H,ids,K,noise[,select_K(K)])
          qs <- t(apply(fc$yrep,1L,quantile,probs=c(.05,.5,.95),type=8))
          sensitivity[[length(sensitivity)+1L]] <- data.frame(K=K,horizon=seq_len(cfg$H),
            mean=rowMeans(fc$mu_draws),lower90=qs[,1L],median=qs[,2L],upper90=qs[,3L])
        }
      }
      stopifnot(all(vapply(candidates,function(x) all(is.finite(x$yrep)) && all(x$sd_draws>0),TRUE)))
      rm(candidates,auto,fixed,oracle);invisible(gc())
    }
    observed[[length(observed)+1L]] <- data.frame(dgp=kind,repetition=r,time=seq_along(dgp$y),
      y=dgp$y,realized_location=dgp$mu,realized_innovation_sd=dgp$sd,simulated_hidden_state=dgp$state,
      split=c(rep("washout",500),rep("training",2000),rep("forecast",100)))
    audit[[length(audit)+1L]] <- data.frame(dgp=kind,repetition=r,dgp_seed=seed,
      conditioning_start=1L,conditioning_end=500L,fit_start=min(bank$keep_idx),fit_end=max(bank$keep_idx),
      n_train=bank$n,forecast_origin=origin,horizon=cfg$H,outer_draws=cfg$outer_draws,
      inner_paths=cfg$inner_paths,total_paths=N,center=bank$preprocessing$center,scale=bank$preprocessing$scale,
      volatility_q25=boundaries[1L],volatility_q75=boundaries[2L],
      auto_diagnostic_pass=hh_qualify(auto_fit$diagnostics),fixed_diagnostic_pass=hh_qualify(fixed_fit$diagnostics),
      gjr_converged=gjr$convergence==0L,elapsed_seconds=proc.time()[[3L]]-case_started)
    save_all()
    cat(sprintf("%s complete in %.1f seconds\n",id,proc.time()[[3L]]-case_started));flush.console()
    rm(bank,auto_fit,fixed_bank,fixed_fit,gaussian,one_oracle,noise,z);invisible(gc())
  }
  tab <- do.call(rbind,scores)
  tab$band <- cut(tab$horizon,c(0,10,30,60,100),labels=c("1-10","11-30","31-60","61-100"))
  fields <- c("squared_error","absolute_error","crps","covered90","width90","covered50","width50",
    "negative_log_score","predictive_sd","innovation_sd","oracle_mean_squared_error")
  summarize <- function(x,groups) {
    a <- aggregate(x[fields],x[groups],mean)
    a$rmse <- sqrt(a$squared_error)
    a$count <- aggregate(x["horizon"],x[groups],length)$horizon
    a
  }
  write.csv(summarize(tab,c("dgp","mode","method")),file.path(out,"summary.csv"),row.names=FALSE)
  write.csv(summarize(tab,c("dgp","mode","method","repetition")),file.path(out,"by_replication.csv"),row.names=FALSE)
  write.csv(summarize(tab,c("dgp","mode","method","band")),file.path(out,"lead_bands.csv"),row.names=FALSE)
  write.csv(summarize(tab[tab$mode=="one_step",],c("dgp","method","volatility_group")),file.path(out,"volatility_groups.csv"),row.names=FALSE)
  stopifnot(nrow(tab)==3L*3L*2L*7L*100L,!anyDuplicated(tab[c("dgp","repetition","mode","method","horizon")]))
  writeLines(c(sprintf("Elapsed seconds: %.3f",proc.time()[[3L]]-started),
    "500 washout + 2000 likelihood contributions + 100 held-out observations.",
    "Three independent series per DGP; 100 horizons and MC paths are not independent replications.",
    "Fixed-origin and one-step scores reuse the same 100 held-out observations.",
    "AutoDESN and fixed DESN retain constant Gaussian innovation variance.",
    "Known-DGP reference uses true parameters, but not hidden states or future outcomes at issue time.",
    "Quantiles pool paths using type 8. Predictive means average Gaussian component locations.",
    "GJR reference omits parameter uncertainty. All convergence attempts retained.",
    R.version.string,capture.output(sessionInfo())),file.path(out,"session.txt"))
  print(read.csv(file.path(out,"summary.csv"))[,c("dgp","mode","method","rmse","crps","covered90")],row.names=FALSE)
}
main()
