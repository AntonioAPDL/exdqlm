# A computational recovery of the same prior-predictive cases, not new data.
# Require unchanged source, priors, frozen map, generator seeds and target IDs.
args<-commandArgs(TRUE);stopifnot(length(args)==3L,args[1]%in%c('constant','sv'))
root<-'validation/autodesn/remediation';variance<-args[1];base_budget<-as.integer(args[2]);budget<-as.integer(args[3]);stopifnot(budget>base_budget)
label<-paste0('recursive_sbc_',variance,'_n200_k',base_budget)
base<-file.path(root,'artifacts',label);recovery<-file.path(root,'artifacts',paste0('recursive_sbc_',variance,'_n200_k',budget))
registration<-jsonlite::fromJSON(file.path(root,'evidence',paste0('recursive_',variance,'_recovery_registration.json')))
stopifnot(identical(as.integer(registration$replications),200L),budget%in%registration$recovery_retained_ladder)
old<-readRDS(file.path(base,'contract.rds'));new<-readRDS(file.path(recovery,'contract.rds'))
old_contract<-old$contract;new_contract<-new$contract
old_contract[c('retained','warmup')]<-NULL;new_contract[c('retained','warmup')]<-NULL
stopifnot(identical(old_contract,new_contract))
records<-lapply(1:200,function(k)readRDS(file.path(base,paste0('case_',k,'.rds'))))
stopifnot(all(vapply(records,function(x)identical(x$contract_id,old$id),TRUE)))
ess<-do.call(rbind,lapply(records,`[[`,'ess'));selected<-which(apply(ess,1,min)<400)
stopifnot(identical(as.integer(selected),as.integer(registration$selected_cases)))
paths<-file.path(base,paste0('case_',1:200,'.rds'))
for(k in selected){
 path<-file.path(recovery,paste0('case_',k,'.rds'));z<-readRDS(path)
 stopifnot(identical(z$contract_id,new$id),identical(z$case,records[[k]]$case),identical(z$truth,records[[k]]$truth),identical(z$target_id,records[[k]]$target_id),isTRUE(z$frozen_geometry_verified),isTRUE(z$causal_design_reconstruction_verified))
 records[[k]]<-z;paths[k]<-path
}
U<-do.call(rbind,lapply(records,`[[`,'u'));ESS<-do.call(rbind,lapply(records,`[[`,'ess'))
D<-apply(U,2,function(v){s<-sort(v);max(seq_along(s)/length(s)-s,s-(seq_along(s)-1)/length(s))})
bound<-sqrt(log(2*ncol(U)/.01)/400)
outlabel<-paste0(label,'_recovered',budget);out<-file.path(root,'artifacts',outlabel)
stopifnot(!dir.exists(out));dir.create(out)
write.csv(U,file.path(out,'ranks.csv'),row.names=FALSE);write.csv(ESS,file.path(out,'ess.csv'),row.names=FALSE)
members<-lapply(seq_along(paths),function(k)list(case=k,path=paths[k],sha256=digest::digest(file=paths[k],algo='sha256'),retained=if(k%in%selected)budget else base_budget,target_id=records[[k]]$target_id))
jsonlite::write_json(list(complete=TRUE,original_contract_id=old$id,recovery_contract_id=new$id,source_and_generator_contract_unchanged=TRUE,replications=200L,recomputed_cases=selected,members=members),file.path(out,'assembly.json'),pretty=TRUE,auto_unbox=TRUE)
result<-list(complete=TRUE,replications=200L,retained=base_budget,recovery_retained=budget,recomputed_cases=selected,variance=variance,scope=old_contract$scope,maximum_uniform_ecdf_deviation=max(D),simultaneous_DKW_bound=bound,uniformity_envelope_passed=all(D<=bound),minimum_case_spectral_ess=min(ESS),cases_below_400_ess=sum(apply(ESS,1,min)<400),computational_calibration_resolved=all(D<=bound)&&all(ESS>=400),posterior_production_qualified=FALSE,additional_independent_replications=0,assembly_sha256=digest::digest(file=file.path(out,'assembly.json'),algo='sha256'))
jsonlite::write_json(result,file.path(root,'evidence',paste0(outlabel,'.json')),pretty=TRUE,auto_unbox=TRUE);print(result)
