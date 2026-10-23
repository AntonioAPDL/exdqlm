# Same frozen C1 data, reservoirs, admission, state timing and forecast budget.
# Readout standardization is fitted on rows 501:2500 only. This is an
# exploratory sensitivity because the original test scores are already known.
source("validation/autodesn/rhs_comparison/helpers.R")
source("validation/autodesn/rhs_comparison/runner.R")
root <- "validation/autodesn/standardized_rhs"
args <- commandArgs(trailingOnly=TRUE)
value <- function(key,default) {
 at <- which(args==paste0("--",key))
 if(!length(at)) return(default)
 if(length(at)!=1L || at==length(args)) stop("Invalid option: ",key)
 args[at+1L]
}
options <- rhs_options(character());cfg <- rhs_configuration(options)
study <- jsonlite::fromJSON(file.path(root,"configuration.json"))
cfg$attempts <- as.data.frame(study$attempts)
base <- value("out",file.path(root,"artifacts"))
stage <- value("stage","all")
scenario_id <- value("scenario","requested")
stopifnot(stage%in%c("build","fit","forecast","all"),scenario_id%in%study$scenarios$id)
sc <- study$scenarios[match(scenario_id,study$scenarios$id),,drop=FALSE]
options$method <- sc$method;options$backend <- "cpp";options$mode <- "full"
options$out <- file.path(base,scenario_id)
raw_dir <- file.path(base,"raw_bank");scaled_dir <- file.path(base,"standardized_bank")
dir.create(base,recursive=TRUE,showWarnings=FALSE)
rhs_json(study,file.path(base,"configuration.json"))

standardized_bank <- function() {
 # Production code and input hashes participate in the raw bank contract.
 raw_contract_path <- file.path(raw_dir,"contract.rds")
 if(file.exists(raw_contract_path)) {
  saved <- readRDS(raw_contract_path);scs <- rhs_specifications(cfg)
  old <- saved$contract
  stopifnot(identical(old$input_sha256,cfg$input_sha256),
   isTRUE(all.equal(old$specifications,scs$specs,check.environment=FALSE)),old$fit_start==cfg$fit_start,
   old$fit_end==cfg$fit_end,old$washout==cfg$washout,old$tolerance==cfg$washout_tolerance)
  hashes <- vapply(names(old$builder_sha256),function(p) digest::digest(file=p,algo="sha256"),"")
  stopifnot(identical(hashes,old$builder_sha256))
  raw_id <- saved$id
 } else {
  raw <- rhs_build_bank(cfg,raw_dir);raw_id <- raw$id
 }
 id <- rhs_guard(scaled_dir,list(raw_bank_id=raw_id,
   standardize_features=TRUE,normalize_features=FALSE,feature_sd_tol=study$feature_sd_tol,
   scaling_sha256=digest::digest(file="R/autodesn_scaling.R",algo="sha256")))
 path <- file.path(scaled_dir,"bank.rds")
 if(file.exists(path)) {
  bank <- readRDS(path);stopifnot(identical(attr(bank,"comparison_bank_id"),id))
  return(list(bank=bank,id=id,load_seconds=0))
 }
 if(!exists("raw",inherits=FALSE)) raw <- rhs_build_bank(cfg,raw_dir)
 began <- proc.time()[3];b <- raw$bank
 features <- lapply(b$models,function(m) m$X[,-1L,drop=FALSE]*m$divisor)
 normalized <- autodesn_prepare_bank(b$y,features,model_info=b$model_info,
   model_prior=b$prior,normalize_features=FALSE,standardize_features=TRUE,
   feature_sd_tol=study$feature_sd_tol)
 b$models <- normalized$models;b$normalize_features <- FALSE
 b$standardize_features <- TRUE;b$feature_sd_tol <- study$feature_sd_tol
 attr(b,"comparison_bank_id") <- id
 audit <- do.call(rbind,lapply(seq_along(b$models),function(j) {
  m <- b$models[[j]];F <- m$X[,-1L,drop=FALSE]
  data.frame(model=j,candidate=b$model_info$candidate[j],raw_slopes=m$raw_d,
   fitted_slopes=m$d,dropped=length(m$dropped_features),
   max_abs_mean=if(m$d) max(abs(colMeans(F))) else 0,
   max_sd_error=if(m$d) max(abs(apply(F,2,sd)-1)) else 0)
 }))
 stopifnot(b$n==2000L,identical(b$keep_idx,501:2500),
   max(audit$max_abs_mean)<1e-9,max(audit$max_sd_error)<1e-9)
 write.csv(audit,file.path(scaled_dir,"feature_audit.csv"),row.names=FALSE)
 rhs_json(list(complete=TRUE,fit_start=501L,fit_end=2500L,
   unit_variance=TRUE,dimension_normalization=FALSE,admitted=nrow(audit),
   max_abs_mean=max(audit$max_abs_mean),max_sd_error=max(audit$max_sd_error),
   excluded_constant_columns=sum(audit$dropped),
   standardization_seconds=unname(proc.time()[3]-began),
   feature_geometry_sha256=digest::digest(lapply(b$models,function(m)
    m[c("feature_center","feature_scale","active_features","raw_d")]),algo="sha256")),
   file.path(scaled_dir,"status.json"))
 rm(raw,normalized,features);gc(FALSE)
 rhs_save(b,path);list(bank=b,id=id,load_seconds=0)
}

bank_result <- standardized_bank();bank <- bank_result$bank
cat("Shared standardized bank:",length(bank$models),"models,",bank$n,"training rows\n");flush.console()
if(stage=="build") quit(status=0)
directory <- file.path(options$out,sc$method);dir.create(directory,recursive=TRUE,showWarnings=FALSE)
config <- cfg
config$readout_standardization <- study[c("standardize_features","normalize_features","feature_sd_tol","interpretation")]
config$scenario <- as.list(sc)
if(sc$method=="rhs") config$rhs_control <- c(list(tau0=sc$tau0,slab_scale=sc$slab_scale,slab_df=sc$slab_df),study$sampler)
config[[paste0(sc$method,"_seed")]] <- sc$seed
config$model_control <- list(method="mh",moves=study$model_moves,rb_every=study$rb_every)
contract <- list(bank_id=bank_result$id,configuration=config,
 production_source=rhs_source_manifest(),runner_sha256=digest::digest(file=file.path(root,"run.R"),algo="sha256"))
id <- rhs_guard(directory,contract)
write.csv(contract$production_source,file.path(directory,"source_manifest.csv"),row.names=FALSE)
rhs_json(list(contract_id=id,configuration=config,production_source=contract$production_source,
 git_revision=.autodesn_checkout_revision),file.path(directory,"provenance.json"))
rhs_json(config,file.path(options$out,"configuration.json"))
Rcpp::sourceCpp("src/autodesn_rhs.cpp",cacheDir=file.path(base,"cpp_cache"),rebuild=FALSE,showOutput=FALSE)

fit_one <- function(burn,draws,seed,chain,proposal=NULL) {
 a <- list(bank=bank,n_burn=burn,n_mcmc=draws,seed=seed,
   initial_variance=c(.1,1,5)[chain])
 if(sc$method=="ridge") {
  a$ridge_precision <- c(.1,1,10)[chain]
  f <- c1_sampler(bank)
 } else {
  a$beta_prior <- "rhs";a$backend <- "cpp";a$rhs_control <- config$rhs_control
  a$rhs_control$initial_global <- c(.1,1,10)[chain]
  a$model_control <- config$model_control
  a$model_control$initial_model <- as.integer(round(seq(1,length(bank$models),length.out=3))[chain])
  a$model_control$proposal <- if(is.null(proposal)) bank$prior else proposal
  f <- autodesn_fit_bank
 }
 began <- proc.time()[3];fit <- do.call(f,a);seconds <- unname(proc.time()[3]-began)
 fit$bank <- NULL;list(fit=fit,inference_seconds=seconds,contract_id=id)
}

pilot_seconds <- 0
proposal <- NULL
if(sc$method=="rhs") {
 pp <- file.path(directory,"pilot");dir.create(pp,showWarnings=FALSE)
 occupancy <- list()
 for(k in 1:3) {
  path <- file.path(pp,paste0("chain_",k,".rds"))
  if(file.exists(path)) r <- readRDS(path) else {
   cat(scenario_id,"training-only pilot chain",k,"\n");flush.console()
   r <- fit_one(study$pilot$n_burn,study$pilot$n_mcmc,sc$seed-10000L+k,k)
   rhs_save(r,path)
  }
  stopifnot(identical(r$contract_id,id))
  occupancy[[k]] <- r$fit$model_summary$occupancy
  pilot_seconds <- pilot_seconds+r$inference_seconds
 }
 proposal <- study$proposal_prior_fraction*bank$prior+
   (1-study$proposal_prior_fraction)*rowMeans(do.call(cbind,occupancy))
 stopifnot(all(proposal>0),abs(sum(proposal)-1)<1e-10)
 write.csv(data.frame(model=seq_along(proposal),prior=bank$prior,proposal=proposal),
   file.path(directory,"training_only_proposal.csv"),row.names=FALSE)
 rhs_json(list(frozen_before_chain=TRUE,test_outcomes_used=FALSE,
   pilot_inference_seconds=pilot_seconds,proposal_sha256=digest::digest(proposal,algo="sha256")),
   file.path(directory,"proposal_status.json"))
 rm(occupancy,r);gc(FALSE)
}

cp_path <- file.path(directory,"posterior_checkpoint.rds")
if(!file.exists(cp_path) && stage=="forecast") stop("No qualified posterior checkpoint")
if(file.exists(cp_path)) {
 cp <- readRDS(cp_path);stopifnot(identical(cp$comparison_contract_id,id))
} else {
 total <- 0;passed <- FALSE
 for(attempt in seq_len(nrow(config$attempts))) {
  ctl <- config$attempts[attempt,];adir <- file.path(directory,paste0("attempt_",attempt))
  dir.create(adir,showWarnings=FALSE);fits <- vector("list",3)
  for(k in 1:3) {
   path <- file.path(adir,paste0("chain_",k,".rds"))
   if(file.exists(path)) r <- readRDS(path) else {
    cat(scenario_id,"attempt",attempt,"chain",k,":",ctl$n_burn,"burn +",ctl$n_mcmc,"retained\n");flush.console()
    r <- fit_one(ctl$n_burn,ctl$n_mcmc,sc$seed+10000L*(attempt-1L)+k,k,proposal)
    rhs_save(r,path)
   }
   stopifnot(identical(r$contract_id,id));total <- total+r$inference_seconds
   fits[[k]] <- r$fit;fits[[k]]$bank <- bank
  }
  dg <- autodesn_diagnostics(fits)
  big <- dg$models$posterior_probability>=.01
  architecture_pass <- all(is.finite(dg$models$rhat_indicator[big])) &&
   all(is.finite(dg$models$ess_indicator_spectral[big])) &&
   max(dg$models$rhat_indicator[big])<=1.01 && min(dg$models$ess_indicator_spectral[big])>=400
  passed <- rhs_diagnostic_gate(dg,config) && architecture_pass
  write.csv(dg$parameters,file.path(adir,"diagnostics.csv"),row.names=FALSE)
  write.csv(dg$models,file.path(adir,"model_probabilities.csv"),row.names=FALSE)
  rhs_json(list(complete=TRUE,qualified=passed,attempt=attempt,n_burn=ctl$n_burn,n_mcmc=ctl$n_mcmc,
   inference_seconds_all_attempts=total,pilot_seconds=pilot_seconds),file.path(adir,"status.json"))
  cat("Diagnostic gates:",passed,"\n");print(dg$parameters);flush.console()
  if(passed) break
  rm(fits);gc(FALSE)
 }
 write.csv(dg$parameters,file.path(directory,"diagnostics.csv"),row.names=FALSE)
 write.csv(dg$models,file.path(directory,"model_probabilities.csv"),row.names=FALSE)
 status <- list(complete=FALSE,fit_complete=TRUE,qualified=passed,diagnostic_gates_passed=passed,
  scenario=scenario_id,model=if(sc$method=="rhs") "AutoDESN RHS" else "AutoDESN ridge",
  method=sc$method,mode="full",chains=3L,selected_attempt=attempt,
  fit_rows=2000L,origins=471L,outer_draws=192L,inner_paths=8L,
  posterior_updates=FALSE,model_weight_updates=FALSE,bank_id=bank_result$id,contract_id=id,
  timings=list(inference_seconds_all_attempts=total,training_pilot_seconds=pilot_seconds))
 rhs_json(status,file.path(directory,"status.json"))
 if(!passed) stop("Posterior did not qualify; all chains retained, no forecasts issued")
 cp <- rhs_compact(fits,bank,dg,config,sc$seed)
 cp$readout_beta <- cp$beta
 cp$beta <- lapply(seq_along(cp$beta),function(k)
   as.vector(.autodesn_raw_beta(bank$models[[cp$draws$model[k]]],matrix(cp$readout_beta[[k]],1))))
 cp$bank$divisors[] <- 1
 cp$comparison_contract_id <- id;cp$qualified <- TRUE;cp$mode <- "full";cp$beta_prior <- sc$method
 cp$coefficient_transport <- "frozen standardized coefficients to raw reservoir basis, including intercept shift"
 # Independent production/rolling adapter parity before accessing test scores.
 public <- fits[[1]];public$draws <- cp$draws;public$beta <- cp$readout_beta
 ids <- 1:192;noise <- c1_noise(config$innovation_seed,2500L,8L,192L,30L)
 direct <- forecast_paths.autodesn_fit(public,30L,draw_index=ids,inner_paths=8L,innovations=noise,backend="batched")
 thin_cp <- cp;thin_cp$draws <- cp$draws[ids,,drop=FALSE];thin_cp$beta <- cp$beta[ids]
 states <- lapply(cp$bank$templates,function(x) x$states$H_last)
 ref <- hr_auto(thin_cp,states,bank$history_scaled,30L,8L,noise)
 error <- max(abs(direct$yrep-ref$yrep),abs(direct$mu_draws-ref$mu_draws))
 stopifnot(error<1e-10)
 rhs_json(list(complete=TRUE,max_path_error=error,future_observations_used=FALSE),file.path(directory,"transport_parity.json"))
 rhs_save(cp,cp_path);rm(fits,public,direct,ref,thin_cp);gc(FALSE)
}
if(stage%in%c("all","forecast")) rhs_forecast(cp,config,directory,id)
cat(scenario_id,"stage",stage,"finished\n")
