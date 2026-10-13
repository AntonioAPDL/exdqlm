iqfp_v10_schema <- "independent_qdesn_frozen_preprocessing_v10"

iqfp_v10_source <- function(repo) {
  source(file.path(repo,"validation/fitforecast_v2/R/independent_qdesn_mcmc_bridge_v9.R"),local=FALSE)
  iqmb_v9_source(repo)
}

iqfp_v10_check <- function(name,error,tolerance=1e-6) {
  data.frame(field=name,maximum_absolute_error=error,tolerance=tolerance,
    pass=is.finite(error) & error<=tolerance)
}

iqfp_v10_assert_prefix <- function(training,rollout,preprocess) {
  rows <- seq_len(nrow(training$X))
  errors <- c(center=max(abs(rollout$meta$lag_center-rep_len(preprocess$center,length(rollout$meta$lag_center)))),
    scale=max(abs(rollout$meta$lag_scale-rep_len(preprocess$scale,length(rollout$meta$lag_scale)))),
    training_prefix=max(abs(training$X-rollout$X[rows,,drop=FALSE])))
  for(d in seq_along(training$states$H_all)) {
    n <- nrow(training$states$H_all[[d]])
    errors[paste0("state_prefix_L",d)] <- max(abs(training$states$H_all[[d]]-
      rollout$states$H_all[[d]][seq_len(n),,drop=FALSE]))
  }
  x <- iqfp_v10_check(names(errors),errors)
  if(!all(x$pass))stop("Effective preprocessing or causal feature prefix differs.")
  x
}

iqfp_v10_context <- function(ref) {
  stopifnot(iqfr_v2_sha256(ref$source$frozen_path)==ref$source$frozen_sha256)
  src <- iqfr_v2_source_rows(ref$source$frozen_path)
  rows <- src$t>=8501L & src$t<=ref$fit_end
  tr <- iqcf_v3_response_transport(src,rows)
  y <- tr$forward(src$y)
  # Historical fits standardized their entire available prefix, including warmup.
  prep <- iqfr_v2_training_preprocess(y[src$t<=ref$fit_end],ref$candidate$center_scale)
  list(source=src,rows=rows,transport=tr,y=y,preprocess=prep)
}

iqfp_v10_design <- function(ref,context,last,fit=FALSE,vb_args=list()) {
  a <- iqfr_v2_design_args(context$y[context$source$t<=last],ref$candidate,
    context$preprocess,ref$probability,fit)
  a$normal_args <- NULL;a$vb_args <- vb_args
  z <- do.call(qdesn_fit_vb,a)
  iqfr_v2_assert_design(z,ref$candidate,last-8500L)
  z
}

iqfp_v10_parameters <- function(path) {
  p <- read.csv(path,check.names=FALSE)
  stopifnot(all(c("draw","sigma","gamma") %in% names(p)),!anyDuplicated(p$draw),
    identical(as.integer(p$draw),seq_len(nrow(p))))
  columns <- grep("^beta_[0-9]+$",names(p),value=TRUE)
  stopifnot(identical(columns,paste0("beta_",seq_along(columns))))
  beta <- as.matrix(p[columns])
  stopifnot(all(is.finite(beta)),all(is.finite(p$sigma)),all(p$sigma>0),all(is.finite(p$gamma)))
  structure(list(samp.beta=beta,samp.sigma=p$sigma,samp.gamma=p$gamma,
    summary=list(beta_mean=colMeans(beta)),misc=list()),class="exal_mcmc")
}

iqfp_v10_prepare <- function(cfg) {
  ref <- iqfr_v2_read_json(cfg$reference_config_path)
  stopifnot(iqfr_v2_sha256(ref$config_path)==cfg$reference_config_sha256,
    iqcb_v4_status_valid(ref$config_path,ref$status_path))
  cx <- iqfp_v10_context(ref)
  saved <- iqfr_v2_read_json(file.path(ref$run_root,"fit_diagnostics",ref$job_id,"summary.json"))
  training <- iqfp_v10_design(ref,cx,ref$fit_end)
  stopifnot(digest::digest(training$X,algo="sha256")==saved$design_sha256)
  checks <- iqfp_v10_check("response_transport",max(abs(c(cx$transport$center-saved$response_center,
    cx$transport$scale-saved$response_scale))))
  paths <- c(ref$config_path,ref$status_path,ref$source$frozen_path,
    file.path(ref$run_root,"fit_diagnostics",ref$job_id,"summary.json"))
  if(cfg$inference=="mcmc") {
    root <- file.path(ref$run_root,"mcmc_diagnostics",ref$job_id)
    parameter_path <- file.path(root,"parameter_draws.csv.gz")
    fitted <- iqfp_v10_parameters(parameter_path)
    kernel <- iqfr_v2_read_json(file.path(root,"summary.json"))
    expected <- if(ref$likelihood_family=="exal")"m0_v_collapsed_support_logit" else "sigma_then_gamma"
    stopifnot(kernel$kernel==expected,nrow(fitted$samp.beta)==ref$mcmc_retained)
    fitted$misc$p0 <- ref$probability
    fit <- iqfr_v2_attach_mcmc_readout(training,list(fit=fitted))
    rollout <- iqfp_v10_design(ref,cx,ref$rollout_end)
    rollout <- iqfr_v2_attach_mcmc_readout(rollout,fit)
    draws <- exal_posterior_draws(fitted,nd=ref$outer_draws,
      seed=iqfr_v2_seed(ref$seed,"posterior_draws"))
    fitdraw_path <- file.path(root,"fit_quantile_draws.csv.gz")
    paths <- c(paths,parameter_path,file.path(root,"summary.json"),fitdraw_path)
  } else {
    replay <- ref;replay$run_root <- cfg$run_root;replay$job_id <- cfg$job_id
    frozen <- iqct_v6_load_initializer(replay)
    v <- list(likelihood_family=ref$likelihood_family,
      al_fixed_gamma=if(ref$likelihood_family=="al")0 else NULL,
      beta_prior_type="rhs_ns",beta_rhs=list(tau0=ref$candidate$rhs_tau0,
        s2=ref$rhs_s2,shrink_intercept=FALSE,n_inner=2L),init=frozen$init,
      max_iter=ref$budget$max_iter,min_iter_elbo=10L,tol=ref$budget$tol,
      tol_par=ref$budget$tol,n_samp_xi=ref$budget$n_samp_xi,verbose=FALSE,
      sigmagam=exal_make_vb_sigmagam_control(),
      beta_covariance=list(approximation="full",label_uncertainty=TRUE))
    fit <- iqfp_v10_design(ref,cx,ref$fit_end,TRUE,v)
    rollout <- iqfp_v10_design(ref,cx,ref$rollout_end)
    rollout <- iqfr_v2_attach_quantile_readout(rollout,fit)
    draws <- exal_posterior_draws(fit$fit,nd=ref$outer_draws,seed=iqfr_v2_seed(ref$seed,"posterior_draws"))
    iqbs_v5_capture_fit(replay,fit,draws,cx$source,cx$rows,cx$transport)
    checks <- rbind(checks,iqps_v8_fit_check(ref,replay))
    fitdraw_path <- file.path(ref$run_root,"fit_diagnostics",ref$job_id,"fit_quantile_draws.csv.gz")
    paths <- c(paths,fitdraw_path,ref$frozen_initializer_path,
      file.path(ref$run_root,"fit_diagnostics",ref$job_id,c("beta_moments.csv","beta_covariance.csv.gz")))
  }
  checks <- rbind(checks,iqfp_v10_assert_prefix(training,rollout,cx$preprocess))
  saved_draws <- as.matrix(read.csv(fitdraw_path)[-1L])
  q <- cx$transport$inverse(training$X%*%t(draws$beta))
  stopifnot(identical(dim(q),dim(saved_draws)))
  checks <- rbind(checks,iqfp_v10_check("saved_training_draws",max(abs(q-saved_draws))))
  oldmetric <- read.csv(ref$metric_draw_path)
  original <- oldmetric[oldmetric$estimator=="mean_conditional_location",]
  original <- original[order(original$posterior_draw),]
  stopifnot(identical(as.integer(original$posterior_source_draw_index),
    as.integer(draws$source_draw_index %||% seq_len(draws$nd))),all(checks$pass))
  paths <- unique(c(paths,ref$result_path,ref$metric_draw_path))
  list(ref=ref,context=cx,training=fit,rollout=rollout,draws=draws,checks=checks,input_paths=paths)
}

iqfp_v10_config <- function(ref,inference,repo,run) {
  id <- paste("frozen_preprocessing_v10",inference,ref$job_id,sep="__")
  list(schema_version=iqfp_v10_schema,job_id=id,inference=inference,
    case_id=ref$case_id,pair_role=ref$pair_role,source_stage=ref$stage,
    reference_config_path=ref$config_path,reference_config_sha256=iqfr_v2_sha256(ref$config_path),
    preprocessing_policy="saved_training_basis_including_observed_warmup",
    scientific_role="compatibility_repair_not_article_replacement",repo_root=repo,run_root=run,
    config_path=file.path(run,"configs",paste0(id,".json")),
    status_path=file.path(run,"status",paste0(id,".json")),
    result_path=file.path(run,"results",paste0(id,".csv")))
}

iqfp_v10_forecast <- function(prepared,origins=NULL,H=NULL,outer=NULL,inner=NULL) {
  ref <- prepared$ref;cx <- prepared$context
  origins <- origins %||% (seq.int(ref$origins$start,ref$origins$end,by=ref$origins$stride)-8110L)
  H <- H %||% ref$horizon;inner <- inner %||% as.integer(ref$inner_path_grid)
  draws <- prepared$draws
  if(!is.null(outer))draws <- iqcf_v3_subset_draws(draws,seq_len(outer))
  bank <- iqcf_v3_make_noise_bank(draws,H,length(origins),inner,iqfr_v2_seed(ref$seed,"inner_paths"))
  lattice <- iqcf_v3_nested_lattice(prepared$rollout,cx$y[cx$source$t<=ref$rollout_end],
    origins,H,draws,ref$probability,inner,iqfr_v2_seed(ref$seed,"inner_paths"),noise_bank=bank,
    include_mean_readout_state=FALSE)
  lattice <- iqcf_v3_inverse_lattice(lattice,cx$transport)
  score <- iqcf_v3_score_nested_lattice(lattice,cx$source,8110L)
  rows <- origins+1L-390L
  expected <- cx$transport$inverse(prepared$rollout$X[rows,,drop=FALSE]%*%t(draws$beta))
  actual <- do.call(rbind,lapply(lattice$oracle_location$mean_conditional_location,
    function(x)x[1L,,drop=FALSE]))
  check <- iqfp_v10_check("analytical_H1",max(abs(expected-actual)))
  stopifnot(all(check$pass))
  list(lattice=lattice,score=score,check=check)
}

iqfp_v10_worker <- function(path,io_smoke=FALSE) {
  cfg <- iqfr_v2_read_json(path);start <- Sys.time()
  kind <- cfg$execution_kind %||% "production"
  stopifnot(identical(kind,if(io_smoke)"io_smoke" else "production"))
  if(io_smoke)stopifnot(cfg$scientific_role=="operational_io_smoke_not_scientific_result")
  iqbs_v5_verify_manifest(file.path(cfg$run_root,"source_hashes.csv"))
  stopifnot(iqfr_v2_sha256(path)==read.csv(file.path(cfg$run_root,"plan.csv"))$config_sha256[
    match(cfg$job_id,read.csv(file.path(cfg$run_root,"plan.csv"))$job_id)])
  if(file.exists(cfg$status_path))stop("Refusing to overwrite a replay status.")
  iqfr_v2_write_json(list(job_id=cfg$job_id,status="RUNNING",pid=Sys.getpid()),cfg$status_path)
  tryCatch({
    prepared <- iqfp_v10_prepare(cfg)
    root <- file.path(cfg$run_root,"evidence",cfg$job_id)
    paths <- iqbs_v5_hash_manifest(prepared$input_paths,file.path(root,"input_hashes.csv"))
    output <- if(io_smoke)iqfp_v10_forecast(prepared,
      origins=c(prepared$ref$origins$start,prepared$ref$origins$start+prepared$ref$origins$stride)-8110L,
      H=2L,outer=4L,inner=4L) else iqfp_v10_forecast(prepared)
    score <- output$score
    point <- score$point_metrics
    point$job_id <- cfg$job_id
    point$case_id <- cfg$case_id;point$pair_role <- cfg$pair_role
    point$inference <- cfg$inference;point$source_stage <- cfg$source_stage
    point$execution_kind <- kind
    point$preprocessing_policy <- cfg$preprocessing_policy
    beta_mean <- if(cfg$inference=="mcmc")prepared$training$fit$summary$beta_mean else
      prepared$training$fit$qbeta$m
    point$fit_point_rmse <- sqrt(mean((prepared$context$transport$inverse(as.numeric(
      prepared$training$X%*%beta_mean))-prepared$context$source$q_target[prepared$context$rows])^2))
    artifacts <- c(result=iqfr_v2_write_csv(point,cfg$result_path),
      checks=iqfr_v2_write_csv(rbind(prepared$checks,output$check),file.path(root,"checks.csv")),
      metric_draws=iqfr_v2_write_csv_gz(score$metric_draws,file.path(root,"forecast_metric_draws.csv.gz")),
      origin_lead=iqfr_v2_write_csv_gz(score$origin_lead,file.path(root,"origin_lead.csv.gz")),
      lead_profile=iqfr_v2_write_csv(score$lead_profile,file.path(root,"lead_profile.csv")),
      origin_profile=iqfr_v2_write_csv(score$origin_profile,file.path(root,"origin_profile.csv")))
    d <- prepared$draws
    pars <- data.frame(posterior_draw=seq_len(d$nd),source_draw_index=d$source_draw_index %||% seq_len(d$nd),
      sigma=d$sigma,gamma=d$gamma,as.data.frame(d$beta))
    names(pars)[-(1:4)] <- paste0("beta_",seq_len(ncol(d$beta)))
    artifacts <- c(artifacts,selected_parameters=iqfr_v2_write_csv_gz(pars,file.path(root,"selected_parameters.csv.gz")))
    flat <- do.call(rbind,output$lattice$oracle_location$mean_conditional_location)
    profile <- score$origin_lead[score$origin_lead$estimator=="mean_conditional_location",]
    artifacts <- c(artifacts,forecast_location_draws=iqfr_v2_write_csv_gz(cbind(
      profile[c("source_origin","lead","source_target")],as.data.frame(flat)),file.path(root,"forecast_location_draws.csv.gz")),
      preprocessing=iqfr_v2_write_json(list(policy=cfg$preprocessing_policy,center=prepared$context$preprocess$center,
        scale=prepared$context$preprocess$scale,design_sha256=digest::digest(prepared$training$X,algo="sha256"),
        preprocessing_fit_last=prepared$ref$fit_end,teacher_forced=TRUE,recursive_within_origin=TRUE,
        MCMC_refit=FALSE,VB_reconstruction=cfg$inference=="vb",article_promotion=FALSE),file.path(root,"preprocessing.json")))
    iqbs_v5_verify_manifest(file.path(root,"input_hashes.csv"))
    iqbs_v5_hash_manifest(c(artifacts,file.path(root,"input_hashes.csv")),file.path(root,"artifacts.csv"))
    iqfr_v2_write_json(list(job_id=cfg$job_id,status="SUCCESS",pid=Sys.getpid(),
      seconds=as.numeric(difftime(Sys.time(),start,units="secs")),manifest=file.path(root,"artifacts.csv"),
      input_manifest=file.path(root,"input_hashes.csv"),result_path=cfg$result_path,
      execution_kind=kind,fitted_model_binaries=0),cfg$status_path)
  },error=function(e) {
    iqfr_v2_write_json(list(job_id=cfg$job_id,status="FAILED",error=conditionMessage(e)),cfg$status_path)
    stop(e)
  })
}

iqfp_v10_preflight <- function(repo,legacy,out) {
  if(dir.exists(out))stop("Refusing to overwrite preflight.")
  dir.create(out,recursive=TRUE)
  plan <- read.csv(file.path(legacy,"plan.csv"));plan <- plan[plan$stage=="pilot",]
  results <- list()
  for(path in plan$config_path) {
    r <- iqfr_v2_read_json(path)
    for(inference in c("vb","mcmc")) {
      ref <- if(inference=="vb")iqfr_v2_read_json(r$reference_config_path) else r
      cfg <- iqfp_v10_config(ref,inference,repo,out)
      p <- iqfp_v10_prepare(cfg)
      f <- iqfp_v10_forecast(p,origins=c(ref$origins$start,ref$origins$start+ref$origins$stride)-8110L,
        H=2L,outer=4L,inner=4L)
      checks <- rbind(p$checks,f$check)
      results[[length(results)+1L]] <- data.frame(case_id=r$case_id,pair_role=r$pair_role,
        inference=inference,checks=nrow(checks),max_error=max(checks$maximum_absolute_error),pass=all(checks$pass))
      iqfr_v2_write_csv(checks,file.path(out,paste0(inference,"__",r$case_id,"__",r$pair_role,"__checks.csv")))
    }
  }
  x <- do.call(rbind,results);stopifnot(nrow(x)==8L,all(x$pass))
  iqfr_v2_write_csv(x,file.path(out,"preflight.csv"));x
}

iqfp_v10_io_smoke <- function(repo,production,out) {
  stopifnot(!dir.exists(out))
  iqbs_v5_verify_manifest(file.path(production,"source_hashes.csv"))
  iqbs_v5_verify_manifest(file.path(production,"materialization_hashes.csv"))
  p <- read.csv(file.path(production,"plan.csv"))
  chosen <- p[(p$inference=="mcmc" & p$case_id=="normal_al_p005" & p$pair_role=="control") |
    (p$inference=="vb" & p$case_id=="normal_exal_p025" & p$pair_role=="challenger"),]
  stopifnot(nrow(chosen)==2L)
  dir.create(out,recursive=TRUE)
  rows <- lapply(chosen$config_path,function(path) {
    old <- iqfr_v2_read_json(path);ref <- iqfr_v2_read_json(old$reference_config_path)
    cfg <- iqfp_v10_config(ref,old$inference,repo,out)
    cfg$execution_kind <- "io_smoke"
    cfg$scientific_role <- "operational_io_smoke_not_scientific_result"
    iqfr_v2_write_json(cfg,cfg$config_path)
    data.frame(job_id=cfg$job_id,config_path=cfg$config_path,config_sha256=iqfr_v2_sha256(cfg$config_path))
  })
  plan <- do.call(rbind,rows)
  iqfr_v2_write_csv(plan,file.path(out,"plan.csv"))
  stopifnot(file.copy(file.path(production,"source_hashes.csv"),out,overwrite=FALSE))
  for(path in plan$config_path)iqfp_v10_worker(path,io_smoke=TRUE)
  for(path in plan$config_path) {
    cfg <- iqfr_v2_read_json(path);s <- iqfr_v2_read_json(cfg$status_path)
    stopifnot(s$status=="SUCCESS",s$execution_kind=="io_smoke")
    iqbs_v5_verify_manifest(s$manifest);iqbs_v5_verify_manifest(s$input_manifest)
  }
  iqfr_v2_write_json(list(status="PASS_OPERATIONAL_IO_SMOKE",jobs=2L,H=2L,
    origins=2L,outer_draws=4L,inner_paths=4L,MCMC_refits=0L,article_promotion=FALSE),
    file.path(out,"smoke_report.json"))
  files <- list.files(out,recursive=TRUE,full.names=TRUE)
  iqbs_v5_hash_manifest(files,file.path(out,"final_artifact_manifest.csv"))
  invisible(plan)
}

iqfp_v10_materialize <- function(repo,legacy,run,preflight,testpath) {
  if(dir.exists(run))stop("Refusing to overwrite replay run.")
  smoke <- read.csv(file.path(preflight,"preflight.csv"));tests <- read.csv(testpath)
  stopifnot(nrow(smoke)==8L,all(smoke$pass),all(tests$failed==0),!any(tests$error),all(tests$warning==0))
  p <- read.csv(file.path(legacy,"plan.csv"))
  gate <- read.csv(file.path(legacy,"confirmation_gate.csv"))
  chosen <- p[p$stage=="pilot" | (p$stage=="confirmation" & p$case_id %in% gate$case_id[gate$selected]),]
  configs <- lapply(chosen$config_path,function(path)iqfp_v10_config(iqfr_v2_read_json(path),"mcmc",repo,run))
  pilots <- p[p$stage=="pilot",]
  configs <- c(configs,lapply(pilots$config_path,function(path) {
    r <- iqfr_v2_read_json(path);iqfp_v10_config(iqfr_v2_read_json(r$reference_config_path),"vb",repo,run)
  }))
  plan <- do.call(rbind,lapply(configs,function(c) {
    iqfr_v2_write_json(c,c$config_path)
    data.frame(job_id=c$job_id,inference=c$inference,case_id=c$case_id,pair_role=c$pair_role,
      source_stage=c$source_stage,config_path=c$config_path,config_sha256=iqfr_v2_sha256(c$config_path),
      status_path=c$status_path,result_path=c$result_path)
  }))
  plan <- plan[order(plan$inference,plan$source_stage,plan$case_id,plan$pair_role),]
  iqfr_v2_write_csv(plan,file.path(run,"plan.csv"))
  previous <- iqfr_v2_read_json(file.path(legacy,"environment.json"))
  paired <- iqfr_v2_read_json(file.path(previous$baseline_run,"environment.json"))
  comparator_path <- paired$comparator_path
  baselines <- read.csv(comparator_path)
  baseline_rows <- baseline_inputs <- list()
  for(path in pilots$config_path[!duplicated(pilots$case_id)]) {
    ref <- iqfr_v2_read_json(path);cx <- iqfp_v10_context(ref)
    b <- baselines[baselines$family==ref$candidate$family &
      baselines$likelihood_family==ref$likelihood_family & baselines$probability==ref$probability,]
    stopifnot(nrow(b)==1L,b$inference=="vb",iqfr_v2_sha256(b$config_path)==b$config_sha256)
    bc <- iqfr_v2_read_json(b$config_path)
    stopifnot(bc$train_start_source_index==8501L,bc$train_end_source_index==ref$fit_end,
      bc$forecast_horizon_max==ref$horizon,bc$origin_stride==ref$origins$stride)
    z <- read.csv(bc$forecast_path_summary_path)
    names(z)[match(c("forecast_origin_source_index","forecast_lead","target_source_index","q_true"),names(z))] <-
      c("source_origin","lead","source_target","q_target")
    keys <- iqcf_v3_pair_frame(seq.int(ref$origins$start,ref$origins$end,
      by=ref$origins$stride)-8110L,ref$horizon,8110L)
    stopifnot(nrow(z)==nrow(keys),!anyDuplicated(z[c("source_origin","lead")]))
    z <- z[match(paste(keys$source_origin,keys$lead),paste(z$source_origin,z$lead)),]
    stopifnot(!anyNA(z$source_target),identical(as.integer(z$source_target),as.integer(keys$source_target)))
    truth <- cx$source$q_target[match(z$source_target,cx$source$t)]
    observed <- cx$source$y[match(z$source_target,cx$source$t)]
    stopifnot(max(abs(z$y-observed))<=1e-6,max(abs(z$q_target-truth))<=1e-6)
    stopifnot(abs(mean(abs(z$qhat-truth))-b$forecast_qtrue_mae)<=1e-6,
      abs(sqrt(mean((z$qhat-truth)^2))-b$forecast_qtrue_rmse)<=1e-6,
      abs(mean(iqcf_v3_check_loss(observed,z$qhat,ref$probability))-b$forecast_check_loss)<=1e-6)
    baseline_rows[[length(baseline_rows)+1L]] <- cbind(case_id=ref$case_id,b)
    baseline_inputs[[length(baseline_inputs)+1L]] <- c(b$config_path,bc$forecast_path_summary_path)
  }
  iqfr_v2_write_csv(do.call(rbind,baseline_rows),file.path(run,"retained_VB_comparators.csv"))
  files <- c(list.files(file.path(repo,"R"),pattern="[.]R$",full.names=TRUE),file.path(repo,"src/exdqlm.so"),
    list.files(file.path(repo,"validation/fitforecast_v2/R"),pattern="[.]R$",full.names=TRUE),
    list.files(file.path(repo,"validation/fitforecast_v2/scripts"),pattern="frozen_preprocessing_v10",full.names=TRUE),
    file.path(repo,"validation/fitforecast_v2/docs/INDEPENDENT_FROZEN_PREPROCESSING_V10_PLAN_20261003.md"),
    file.path(repo,c("DESCRIPTION","NAMESPACE",
      "validation/fitforecast_v2/scripts/resource_independent_qdesn_mcmc_bridge_v9.R",
      "tests/testthat/test-qdesn-frozen-input-overrides.R","tests/testthat/test-qdesn-normal.R",
      "tests/testthat/test-qdesn-forecast-recursion-diagnostic.R",
      "tests/testthat/test-qdesn-mean-readout-state-forecast.R",
      "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-frozen-preprocessing-v10.R",
      "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-frozen-preprocessing-v10-launcher.R",
      "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-corrected-forecast-v3.R",
      "validation/fitforecast_v2/tests/testthat/test-independent-qdesn-beta-solver-v5.R")))
  iqbs_v5_hash_manifest(files,file.path(run,"source_hashes.csv"))
  iqfr_v2_write_json(list(schema=iqfp_v10_schema,HEAD=system2("git",c("rev-parse","HEAD"),stdout=TRUE),
    source_diff=capture.output(system2("git",c("diff","--stat"),stdout=TRUE)),legacy_run=legacy,
    jobs=nrow(plan),concurrency=6L,CPUs=25:30,package_version=as.character(packageVersion("exdqlm")),
    runtime="exdqlm_1.1.1_pinned_validation_source_with_frozen_preprocessing_repair",
    MCMC_refits=0L,VB_selected_reconstructions=4L,article_promotion=FALSE,
    session_info=capture.output(sessionInfo()),R_version=R.version.string,
    threads=as.list(Sys.getenv(c("OMP_NUM_THREADS","OPENBLAS_NUM_THREADS","MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS","RCPP_PARALLEL_NUM_THREADS"))),
    compiler=system2(file.path(R.home("bin"),"R"),c("CMD","config","CXX"),stdout=TRUE),
    compiled_sha256=iqfr_v2_sha256(file.path(repo,"src/exdqlm.so")),
    response_basis="historical_saved_training_basis_not_new_training_window_refit"),file.path(run,"environment.json"))
  iqbs_v5_hash_manifest(c(plan$config_path,file.path(run,c("plan.csv","source_hashes.csv","environment.json")),
    file.path(preflight,"preflight.csv"),testpath,file.path(legacy,c("plan.csv","confirmation_gate.csv")),
    file.path(run,"retained_VB_comparators.csv"),comparator_path,unlist(baseline_inputs)),
    file.path(run,"materialization_hashes.csv"))
  plan
}

iqfp_v10_health <- function(run) {
  alive <- function(pid) {
    if(length(pid)!=1L || !is.finite(as.numeric(pid)) || as.numeric(pid)<=0)return(FALSE)
    path <- sprintf("/proc/%s/status",pid)
    tryCatch(file.exists(path) && !any(grepl("^State:[[:space:]]+Z",readLines(path))),
      error=function(e)FALSE)
  }
  valid <- function(path)tryCatch({iqbs_v5_verify_manifest(path);TRUE},error=function(e)FALSE)
  p <- read.csv(file.path(run,"plan.csv"),stringsAsFactors=FALSE)
  exits <- if(file.exists(file.path(run,"launcher_exit_codes.csv")))
    read.csv(file.path(run,"launcher_exit_codes.csv")) else data.frame(job_id=character(),exit_code=integer())
  rows <- lapply(seq_len(nrow(p)),function(i) {
    s <- if(file.exists(p$status_path[i]))tryCatch(iqfr_v2_read_json(p$status_path[i]),
      error=function(e)list(status="UNREADABLE_STATUS")) else list(status="PENDING")
    state <- s$status;pid <- s$pid %||% NA_integer_
    running <- alive(pid)
    if(state=="RUNNING" && !running)state <- "STALE_RUNNING"
    if(state=="SUCCESS" && (!valid(s$manifest) || !valid(s$input_manifest) ||
      !file.exists(p$result_path[i])))state <- "INVALID_EVIDENCE"
    e <- exits$exit_code[exits$job_id==p$job_id[i]]
    if(state=="PENDING" && length(e) && any(e!=0L))state <- "FAILED_BEFORE_STATUS"
    data.frame(job_id=p$job_id[i],state=state,pid=pid,pid_alive=running)
  })
  jobs <- do.call(rbind,rows)
  path <- file.path(run,"pipeline.status")
  lines <- if(file.exists(path))readLines(path) else character()
  value <- function(key) {
    x <- sub(paste0("^",key,"="),"",grep(paste0("^",key,"="),lines,value=TRUE))
    if(length(x)==1L)x else NA_character_
  }
  launcher_alive <- alive(suppressWarnings(as.numeric(value("launcher_pid"))))
  state <- value("status")
  list(snapshot=format(Sys.time(),tz="UTC",usetz=TRUE),planned=nrow(p),
    completed=sum(jobs$state=="SUCCESS"),running=sum(jobs$state=="RUNNING"),
    pending=sum(jobs$state=="PENDING"),failed=sum(jobs$state %in% c("FAILED","FAILED_BEFORE_STATUS")),
    stale_running=sum(jobs$state=="STALE_RUNNING"),
    invalid=sum(jobs$state %in% c("INVALID_EVIDENCE","UNREADABLE_STATUS")),
    global_manifests_valid=all(vapply(file.path(run,c("source_hashes.csv","materialization_hashes.csv")),valid,TRUE)),
    reported_pipeline_state=state,launcher_alive=launcher_alive,
    stale_pipeline=isTRUE(state %in% c("RUNNING_REPLAY","CLOSING_REPLAY","WAITING_FOR_IDLE_CORES",
      "WAITING_FOR_V9_CORES","PREPARING_REPLAY") && !launcher_alive),jobs=jobs)
}

iqfp_v10_closeout <- function(run) {
  p <- read.csv(file.path(run,"plan.csv"));allpoint <- comparisons <- ranges <- horizon_rows <- list()
  iqbs_v5_verify_manifest(file.path(run,"materialization_hashes.csv"))
  iqbs_v5_verify_manifest(file.path(run,"source_hashes.csv"))
  for(i in seq_len(nrow(p))) {
    cfg <- iqfr_v2_read_json(p$config_path[i]);ref <- iqfr_v2_read_json(cfg$reference_config_path)
    stopifnot(identical(cfg$execution_kind %||% "production","production"))
    s <- iqfr_v2_read_json(cfg$status_path);stopifnot(s$status=="SUCCESS")
    iqbs_v5_verify_manifest(s$manifest);iqbs_v5_verify_manifest(s$input_manifest)
    old <- read.csv(ref$result_path);new <- read.csv(cfg$result_path)
    old <- old[old$estimator %in% new$estimator,];old <- old[match(new$estimator,old$estimator),]
    stopifnot(identical(as.character(old$estimator),as.character(new$estimator)))
    for(k in c("forecast_qtrue_mae","forecast_qtrue_rmse","forecast_check_loss")) {
      comparisons[[length(comparisons)+1L]] <- data.frame(job_id=cfg$job_id,inference=cfg$inference,
        source_stage=cfg$source_stage,case_id=cfg$case_id,pair_role=cfg$pair_role,
        estimator=new$estimator,metric=k,old=old[[k]],repaired=new[[k]],
        gain=old[[k]]-new[[k]],strict_improvement=new[[k]]<old[[k]])
    }
    draws <- read.csv(file.path(run,"evidence",cfg$job_id,"forecast_metric_draws.csv.gz"))
    for(est in unique(draws$estimator))for(k in c("forecast_qtrue_mae","forecast_qtrue_rmse","forecast_check_loss")) {
      values <- draws[draws$estimator==est,k]
      q <- quantile(values,c(.025,.975),names=FALSE,type=8)
      ranges[[length(ranges)+1L]] <- data.frame(job_id=cfg$job_id,inference=cfg$inference,
        case_id=cfg$case_id,pair_role=cfg$pair_role,estimator=est,metric=k,
        point_score=new[new$estimator==est,k],posterior_score_mean=mean(values),lower=q[1],upper=q[2])
    }
    allpoint[[i]] <- new
    z <- read.csv(file.path(run,"evidence",cfg$job_id,"origin_lead.csv.gz"))
    for(est in unique(z$estimator))for(h in c(1L,ref$horizon)) {
      a <- z[z$estimator==est & z$lead<=h,]
      horizon_rows[[length(horizon_rows)+1L]] <- data.frame(job_id=cfg$job_id,
        case_id=cfg$case_id,pair_role=cfg$pair_role,inference=cfg$inference,estimator=est,
        horizon_max=h,pairs=nrow(a),forecast_qtrue_mae=mean(a$absolute_oracle_error),
        forecast_qtrue_rmse=sqrt(mean(a$squared_oracle_error)),forecast_check_loss=mean(a$check_loss))
    }
  }
  cmp <- do.call(rbind,comparisons);ints <- do.call(rbind,ranges)
  stopifnot(all(is.finite(cmp$repaired)),all(is.finite(ints$lower)),all(is.finite(ints$upper)))
  iqfr_v2_write_csv(cmp,file.path(run,"old_vs_repaired.csv"))
  iqfr_v2_write_csv(ints,file.path(run,"posterior_score_intervals.csv"))
  points <- do.call(rbind,allpoint)
  iqfr_v2_write_csv(points,file.path(run,"repaired_point_scores.csv"))
  iqfr_v2_write_csv(do.call(rbind,horizon_rows),file.path(run,"H1_vs_H30.csv"))
  baselines <- read.csv(file.path(run,"retained_VB_comparators.csv"))
  gaps <- list()
  for(i in seq_len(nrow(points))) {
    x <- points[i,]
    if(x$estimator!="mean_conditional_location")next
    b <- baselines[baselines$case_id==x$case_id,];stopifnot(nrow(b)==1L)
    for(k in c("forecast_qtrue_mae","forecast_qtrue_rmse","forecast_check_loss")) {
      gaps[[length(gaps)+1L]] <- data.frame(job_id=x$job_id,case_id=x$case_id,
        pair_role=x$pair_role,QDESN_inference=x$inference,comparator=b$model_variant,
        comparator_inference=b$inference,metric=k,repaired_QDESN=x[[k]],retained_comparator=b[[k]],
        difference=x[[k]]-b[[k]],matched_inference=x$inference==b$inference,
        comparison_role="matched_window_reference_not_MCMC_superiority_test")
    }
  }
  iqfr_v2_write_csv(do.call(rbind,gaps),file.path(run,"retained_VB_comparator_gaps.csv"))
  binaries <- list.files(run,recursive=TRUE,pattern="[.](rds|rda|rdata)$",ignore.case=TRUE)
  stopifnot(!length(binaries))
  iqfr_v2_write_json(list(decision="REPAIRED_FORECAST_EVIDENCE_REQUIRES_CASEWISE_REEVALUATION",
    completed=nrow(p),failed=0L,MCMC_refits=0L,article_promoted=FALSE,fitted_binaries=0L,
    note="Saved-basis compatibility replay; intended-training-basis refits and broad screening remain separate decisions."),
    file.path(run,"closeout.json"))
  pdf(file.path(run,"old_vs_repaired_review.pdf"),width=11,height=7,onefile=TRUE)
  on.exit(dev.off(),add=TRUE)
  colors <- c(vb="#0072B2",mcmc="#D55E00")
  for(case in unique(ints$case_id))for(k in unique(ints$metric)) {
    x <- ints[ints$case_id==case & ints$metric==k & ints$estimator=="mean_conditional_location",]
    o <- cmp[cmp$case_id==case & cmp$metric==k & cmp$estimator=="mean_conditional_location",]
    o <- o[match(x$job_id,o$job_id),]
    lim <- range(c(x$lower,x$upper,x$point_score,o$old))
    par(mar=c(4,13,3,1))
    plot(x$point_score,seq_len(nrow(x)),xlim=lim,ylim=c(.5,nrow(x)+.5),yaxt="n",
      xlab=k,ylab="",pch=4,col=colors[x$inference],main=paste(case,"Saved-basis repair"))
    segments(x$lower,seq_len(nrow(x)),x$upper,seq_len(nrow(x)),col=colors[x$inference],lwd=2)
    points(x$point_score,seq_len(nrow(x)),pch=4,col=colors[x$inference],cex=1.2)
    points(o$old,seq_len(nrow(x)),pch=1,col="gray30")
    axis(2,at=seq_len(nrow(x)),labels=paste(x$inference,x$pair_role,seq_len(nrow(x))),las=1,cex.axis=.8)
    legend("topright",c("Repaired point score","Original point score","95% per-draw score range"),
      pch=c(4,1,NA),lty=c(NA,NA,1),bty="n",cex=.8)
  }
  invisible(cmp)
}
