args<-commandArgs(TRUE);stopifnot(length(args)==3L)
source('validation/autodesn/rhs_comparison/helpers.R')
expressions<-parse(args[3]);selected<-which(vapply(expressions,function(x)is.call(x)&&identical(x[[1]],as.name('<-'))&&identical(x[[2]],as.name('.normal_desn_transition_engine')),TRUE))
stopifnot(length(selected)==1L);eval(expressions[[selected]],envir=.GlobalEnv)
source(args[1]);out<-args[2];dir.create(out,recursive=TRUE,showWarnings=FALSE)
specs<-autodesn_candidates(D=1:2,n=6,m=2,alpha=.7,rho=.4,seed=11,washout=30,act_k='identity')
grid<-data.frame(candidate=names(specs),D=vapply(specs,`[[`,0L,'D'),m=2L)
y<-sin(seq_len(100)/3)+.2*cos(seq_len(100)/7)
identity_spec<-specs[2];identity_spec[[1]]$n_tilde<-identity_spec[[1]]$n[1]
identity_bank<-autodesn_build_bank(y[1:60],identity_spec,conditioning=30L,washout=30L)
stopifnot(identical(remediation_prefix_warmup(identity_bank$templates[[1]],identity_bank$history_scaled,30L),c1_warmup(identity_bank$templates[[1]],identity_bank$history_scaled,30L)))
a<-remediation_prefix_bank(y,60L,specs,grid,file.path(out,'prefix60'),washout=30L)
changed<-y;changed[61:100]<-100+seq_len(40)^2
b<-remediation_prefix_bank(changed,60L,specs,grid,file.path(out,'perturbed60'),washout=30L)
c<-remediation_prefix_bank(changed,80L,specs,grid,file.path(out,'prefix80'),washout=30L)
stopifnot(identical(attr(a,'comparison_bank_id'),attr(b,'comparison_bank_id')),
  identical(a$prior,b$prior),identical(a$preprocessing,b$preprocessing),
  identical(a$models,b$models),identical(a$history,b$history),length(a$history)==60L)
raw_a<-readRDS(file.path(out,'prefix60/raw_bank/bank.rds'))
raw_c<-readRDS(file.path(out,'prefix80/raw_bank/bank.rds'))
stopifnot(identical(a$model_info$candidate,c$model_info$candidate),identical(a$preprocessing,c$preprocessing))
for(m in seq_along(a$models)){
  stopifnot(identical(raw_a$models[[m]]$X,raw_c$models[[m]]$X[seq_len(a$n),,drop=FALSE]))
  for(field in c('W','Win','Q','Q_is_identity'))stopifnot(identical(a$templates[[m]]$reservoir[[field]],c$templates[[m]]$reservoir[[field]]))
}
stopifnot(!identical(a$models[[1]]$feature_center,c$models[[1]]$feature_center),
  !identical(attr(a,'comparison_bank_id'),attr(c,'comparison_bank_id')))
result<-list(complete=TRUE,scope='Small two-architecture original-builder fold reconstruction, not the full456-candidate folds or qualified forecasts',future_perturbation_bank_unchanged=TRUE,raw_states_prefix_invariant=TRUE,seeded_maps_unchanged=TRUE,scalers_refitted=TRUE,identity_warmup_matches_original_exactly=TRUE,reduced_bridge_warmup_uses_raw_transition_states=TRUE,cutoffs=c(60L,80L),washout=30L,architectures=length(specs),heldout_values_used=FALSE,production_qualified=FALSE)
jsonlite::write_json(result,file.path(out,'result.json'),pretty=TRUE,auto_unbox=TRUE)
cat('PREFIX_REBUILD_CHECKS_COMPLETE\n')
