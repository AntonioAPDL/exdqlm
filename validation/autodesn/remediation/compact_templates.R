# Recover exact numeric forecasting maps without loading construction closures.
source('validation/autodesn/load_checkout.R');root<-'validation/autodesn/remediation'
old<-'validation/autodesn/nonlinear_heteroscedastic';raw<-file.path(old,'artifacts/raw_bank')
contract<-readRDS(file.path(raw,'contract.rds'));grid<-read.csv(file.path(old,'input/specification_grid.csv'))
metadata<-read.csv(file.path(root,'artifacts/F1/production_32000_cache1/model_metadata.csv'))
ids<-match(metadata$candidate,grid$candidate);stopifnot(length(ids)==426L,!anyNA(ids),!anyDuplicated(ids))
parts_mode<-'--parts'%in%commandArgs(TRUE);bank<-NULL
if(!parts_mode){
 stats<-readLines('/sys/fs/cgroup/memory.stat');anon<-as.numeric(sub('anon ','',stats[grepl('^anon ',stats)]));stopifnot(anon<1500000000)
 bank<-readRDS(file.path(old,'artifacts/standardized_bank/bank.rds'));stopifnot(identical(bank$model_info$candidate,metadata$candidate));history<-bank$history_scaled
} else history<-readRDS(file.path(raw,'parts/part_0001.rds'))$base$history_scaled
templates<-vector('list',length(ids));sources<-vector('list',length(ids));maximum_error<-0
maximum_feature_error<-0
for(m in seq_along(ids)){
 path<-file.path(raw,'parts',sprintf('part_%04d.rds',ids[m]))
 if(parts_mode){part<-readRDS(path);stopifnot(identical(part$bank_id,contract$id),isTRUE(part$audit$admitted));original<-part$template} else original<-bank$templates[[m]]
 h<-.ext_template_initial(original)
 clean<-original;clean$reservoir[c('w_dist','in_dist')]<-NULL
 stopifnot(is.character(clean$reservoir$act_f),is.character(clean$reservoir$act_k))
 clean$meta<-clean$meta[intersect(names(clean$meta),c('D','n','n_tilde','m','m_input','add_bias','input_mode','standardize_inputs','lag_center','lag_scale','input_bound','input_bound_divisor','win_scale_bias','win_scale_global','win_scale_lags','readout_spec'))]
 clean$states<-list(H_last=h)
 for(backend in c('serial','batched')){
  a<-.normal_desn_transition_engine(original,backend);b<-.normal_desn_transition_engine(clean,backend)
  H<-if(backend=='serial')h else lapply(h,function(v)matrix(v,length(v),2))
  u<-a$input(history);if(backend=='batched')u<-matrix(u,length(u),2)
  A<-a$step(H,u);B<-b$step(H,u);stopifnot(identical(A,B));maximum_error<-max(maximum_error,max(abs(A$x-B$x)))
 }
 if(!parts_mode){
  # Last observed features must reproduce the frozen training design row.
  tmp<-list(templates=list(clean));r<-.ext_origin_features(tmp,1,h)
  fitted<-.autodesn_feature_apply(bank$models[[m]],matrix(r,1))
  error<-max(abs(fitted-bank$models[[m]]$X[bank$n,-1]));stopifnot(error<1e-11);maximum_feature_error<-max(maximum_feature_error,error)
  bank$templates[m]<-list(NULL)
 }
 templates[[m]]<-clean;sources[[m]]<-list(model=m,candidate=metadata$candidate[m],path=if(parts_mode)path else NULL,sha256=if(parts_mode)digest::digest(file=path,algo='sha256') else NULL)
 if(parts_mode)rm(part)
 rm(original,clean,a,b,A,B)
 if(m%%50L==0L){gc(FALSE);cat('Exact compact maps',m,'of',length(ids),'\n');flush.console()}
}
out<-file.path(root,'artifacts/forecast_templates.rds');temporary<-paste0(out,'.writing');saveRDS(templates,temporary);stopifnot(file.rename(temporary,out))
identities<-NULL
if(!parts_mode){bank$templates<-templates;identities<-list();manifest<-jsonlite::fromJSON(file.path(root,'artifacts/inference_cache_manifest.json'));for(family in c('F1','F2','F2flat')){e<-autodesn_extend_bank(bank,list(lags=1:90,prior=if(family=='F2')'grouped' else 'flat',cache_size=32),if(family=='F1')NULL else list(periods=20:120,harmonics=16));stopifnot(identical(e$extension$id,manifest$bank_ids[[family]]));identities[[family]]<-list(conditional_bank_id=e$extension$id,forecast_map_id=e$extension$forecast_map_id);rm(e);gc(FALSE)}}
record<-list(complete=TRUE,reservoirs=length(templates),terminal_state_formats='H_last resolved per layer',maximum_serial_and_batched_transition_error=maximum_error,maximum_training_feature_error=if(!parts_mode)maximum_feature_error else NULL,templates_path=out,templates_sha256=digest::digest(file=out,algo='sha256'),bytes=unname(file.info(out)$size),source_bank_id=contract$id,source_bank_sha256=if(!parts_mode)digest::digest(file=file.path(old,'artifacts/standardized_bank/bank.rds'),algo='sha256') else NULL,source_parts=sources,identities=identities,forecast_issued=FALSE,scope='Identical numeric weights/reducers/activations/input transforms/terminal states; removed only unused construction-distribution closures and metadata. Deterministic transition check, not a posterior forecast or scientific qualification.')
jsonlite::write_json(record,file.path(root,'evidence/compact_forecast_templates.json'),pretty=TRUE,auto_unbox=TRUE)
print(record[c('complete','reservoirs','maximum_serial_and_batched_transition_error','bytes','forecast_issued')])
