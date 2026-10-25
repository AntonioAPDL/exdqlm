args<-commandArgs(TRUE);stopifnot(length(args)==2L)
snapshot<-args[1];out<-args[2];dir.create(out,recursive=TRUE,showWarnings=FALSE)
source(file.path(snapshot,'dgp.R'));source(file.path(snapshot,'oracle_forecastability.R'))
registration<-jsonlite::fromJSON(file.path(snapshot,'registration.json'))
truth<-read.csv('validation/autodesn/nonlinear_heteroscedastic/input/dgp_truth.csv',nrows=2500L)
input<-read.csv('validation/autodesn/nonlinear_heteroscedastic/input/series.csv',nrows=2500L)
stopifnot(nrow(truth)==2500L,identical(input$y,truth$y))
response_sd<-sd(input$y[501:2500]);results<-list();screens<-list();checks<-0L
# Independent scalar continuation checks every simulated response/mean/variance,
# plus perturbation of all unavailable data. Neither is a fitted-model forecast.
origin<-registration$origins[1];prefix<-truth[seq_len(origin),];state<-nh_oracle_state(prefix)
Z<-matrix(sin(seq_len(30*7)),30,7);vector<-nh_oracle_paths(state,origin,Z,TRUE)
reference<-lapply(1:7,function(j){lag<-state$lags;v<-state$variance;e<-state$error;a<-matrix(0,30,3)
 for(h in 1:30){t<-origin+h
  phase<-((t-1)%%60)/60;distance<-function(c)pmin(abs(phase-c),1-abs(phase-c))
  omega<-.008+.018*max(0,1-distance(.18)/.10)+.012*max(0,1-distance(.64)/.18)+.008*tanh(lag[1])^2
  v<-omega+.06*e^2+.10*e^2*(e<0)+.82*v
  mu<-(if(lag[1]<0).58 else .22)*lag[1]+.28*tanh(1.4*lag[2])-.25*tanh(lag[12])+.22*tanh(lag[60])+.20*tanh(1.5*lag[1]*lag[2])
  e<-sqrt(v)*Z[h,j];x<-mu+e;a[h,]<-c(x+nh_season(t),mu+nh_season(t),v);lag<-c(x,head(lag,59))
 };a})
for(j in 1:7)for(k in 1:3){stopifnot(max(abs(reference[[j]][,k]-vector$paths[[k]][,j]))<1e-12);checks<-checks+1L}
changed<-truth;changed[(origin+1L):2500L,setdiff(names(changed),'time')]<-0
stopifnot(identical(nh_oracle_paths(nh_oracle_state(changed[seq_len(origin),]),origin,Z,TRUE),vector));checks<-checks+1L
maximum_h1_error<-0
for(level in seq_along(registration$path_ladder)){
 N<-registration$path_ladder[level];rows<-list()
 for(i in seq_along(registration$origins)){
  origin<-registration$origins[i];state<-nh_oracle_state(truth[seq_len(origin),])
  seed<-registration$seed_base+100L*level+i;set.seed(seed)
  result<-nh_oracle_paths(state,origin,matrix(rnorm(30L*N),30L,N))$summary;result$seed<-seed
  error<-max(abs(result$oracle_mean[1]-truth$conditional_mean[origin+1L]),abs(result$predictive_variance[1]-truth$conditional_sd[origin+1L]^2))
  maximum_h1_error<-max(maximum_h1_error,error);stopifnot(error<1e-10)
  result$oracle_rmse_floor<-sqrt(result$predictive_variance)
  rows[[i]]<-result;cat('ORACLE',N,'origin',origin,'complete\n');flush.console()
 }
 table<-do.call(rbind,rows);write.csv(table,file.path(out,paste0('paths_',N,'.csv')),row.names=FALSE)
 results[[level]]<-table
 individual<-all(table$mean_mcse<=registration$mean_mcse_response_sd*response_sd)&all(table$variance_mcse/table$predictive_variance<=registration$relative_variance_mcse)
 screen<-list(paths=N,individual_mcse_passed=individual)
 if(level>1L){
  a<-results[[level-1L]];b<-table;stopifnot(identical(a$origin,b$origin),identical(a$horizon,b$horizon))
  critical<-qnorm(1-.01/(2*nrow(b)*2))
  differences<-data.frame(origin=b$origin,horizon=b$horizon,
   mean_difference=abs(b$oracle_mean-a$oracle_mean),mean_practical_tolerance=registration$mean_stability_response_sd*response_sd,
   mean_mc_tolerance=critical*sqrt(a$mean_mcse^2+b$mean_mcse^2)+1e-10,
   variance_difference=abs(b$predictive_variance-a$predictive_variance),
   variance_practical_tolerance=registration$relative_variance_stability*(a$predictive_variance+b$predictive_variance)/2,
   variance_mc_tolerance=critical*sqrt(a$variance_mcse^2+b$variance_mcse^2)+1e-10)
  write.csv(differences,file.path(out,paste0('stability_',N,'.csv')),row.names=FALSE)
  stable<-all(differences$mean_difference<=differences$mean_practical_tolerance)&all(differences$mean_difference<=differences$mean_mc_tolerance)&all(differences$variance_difference<=differences$variance_practical_tolerance)&all(differences$variance_difference<=differences$variance_mc_tolerance)
  screen$successive_mc_passed<-individual&&screens[[level-1L]]$individual_mcse_passed&&stable
 }
 screens[[level]]<-screen
 if(isTRUE(screen$successive_mc_passed))break
}
latest<-results[[length(results)]];pooled<-aggregate(cbind(predictive_variance,expected_innovation_variance,dynamic_mean_variance)~horizon,latest,mean)
pooled$oracle_rmse_floor<-sqrt(pooled$predictive_variance);pooled$rmse_floor_over_training_sd<-pooled$oracle_rmse_floor/response_sd
write.csv(pooled,file.path(out,'horizon_summary.csv'),row.names=FALSE)
record<-list(complete=TRUE,known_state_oracle=TRUE,privileged_diagnostic=TRUE,training_only=TRUE,heldout_outcomes_read=FALSE,
 rows_read=2500L,training_response_sd=response_sd,prefix_truth_sha256=digest::digest(truth,algo='sha256'),
 origins=registration$origins,horizons=1:30,path_screens=screens,monte_carlo_screen_passed=isTRUE(tail(screens,1)[[1]]$successive_mc_passed),
 independent_scalar_checks=checks,maximum_analytic_h1_error=maximum_h1_error,
 source_snapshot=basename(snapshot),candidate_models_fitted=0L,independent_DGP_replications=0L,
 scope='Known DGP parameters, deterministic season and true origin volatility/error state. Irreducible conditional squared-error risk over a fixed training-origin panel, not a candidate-model forecast, a population bound, or twelve independent series. Future responses are simulated recursively; unavailable observations never enter a path. Monte Carlo SEs use independent simulated paths, not rolling forecast pairs.')
jsonlite::write_json(record,file.path(out,'status.json'),auto_unbox=TRUE,pretty=TRUE,digits=16)
cat('ORACLE_FORECASTABILITY_COMPLETE\n')
