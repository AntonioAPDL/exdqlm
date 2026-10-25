# Execute from the verified original builder tree, with immutable current helpers.
args<-commandArgs(TRUE);stopifnot(length(args)==4L)
cutoff<-as.integer(args[1]);snapshot<-args[2];repository<-args[3];out<-args[4]
stopifnot(cutoff%in%c(1500L,2000L),!file.exists(file.path(out,'manifest.json')))
source('validation/autodesn/rhs_comparison/helpers.R')
expressions<-parse(file.path(snapshot,'R/qdesn_normal.R'))
selected<-which(vapply(expressions,function(x)is.call(x)&&identical(x[[1]],as.name('<-'))&&identical(x[[2]],as.name('.normal_desn_transition_engine')),TRUE))
stopifnot(length(selected)==1L);eval(expressions[[selected]],envir=.GlobalEnv)
source(file.path(snapshot,'validation/autodesn/remediation/prefix_bank.R'))
specification_path<-file.path(repository,'validation/autodesn/nonlinear_heteroscedastic/input/specifications.rds')
definitions<-readRDS(specification_path)
configuration<-jsonlite::fromJSON(file.path(repository,'validation/autodesn/nonlinear_heteroscedastic/configuration.json'))
stopifnot(configuration$washout==500L,configuration$washout_tolerance==.001)
input_path<-file.path(repository,'validation/autodesn/nonlinear_heteroscedastic/input/series.csv')
input<-read.csv(input_path,nrows=cutoff);stopifnot(nrow(input)==cutoff,identical(input$time,seq_len(cutoff)))
bank<-remediation_prefix_bank(input$y,cutoff,definitions[['3_specifications']],definitions[['2_grid']],out,tolerance=configuration$washout_tolerance)
prefix_status<-jsonlite::fromJSON(file.path(out,'standardized_bank/status.json'))
construction_id<-attr(bank,'comparison_bank_id');construction_sha<-digest::digest(file=file.path(out,'standardized_bank/bank.rds'),algo='sha256')
# Current extension functions are loaded only after original-builder admission.
for(p in list.files(file.path(snapshot,'R'),pattern='[.]R$',full.names=TRUE))source(p,local=.GlobalEnv)
old_maps<-readRDS(file.path(repository,'validation/autodesn/remediation/artifacts/prefix_reference_maps/maps.rds'))
stopifnot(identical(bank$model_info$candidate,names(old_maps)),length(old_maps)==length(bank$models))
maximum_transition_error<-maximum_terminal_error<-0;maps<-vector('list',length(bank$models))
for(m in seq_along(maps)){
 original<-bank$templates[[m]];h<-.ext_template_initial(original);clean<-original
 clean$reservoir[c('w_dist','in_dist')]<-NULL
 clean$meta<-clean$meta[intersect(names(clean$meta),c('D','n','n_tilde','m','m_input','add_bias','input_mode','standardize_inputs','lag_center','lag_scale','input_bound','input_bound_divisor','win_scale_bias','win_scale_global','win_scale_lags','readout_spec'))]
 clean$states<-list(H_last=h)
 for(field in c('W','Win','Q','Q_is_identity','alpha','act_f','act_k'))stopifnot(identical(clean$reservoir[[field]],old_maps[[m]]$reservoir[[field]]))
 for(field in c('D','n','n_tilde','m','m_input','add_bias','input_mode','standardize_inputs','lag_center','lag_scale','input_bound','input_bound_divisor','win_scale_bias','win_scale_global','win_scale_lags'))stopifnot(identical(clean$meta[[field]],old_maps[[m]]$meta[[field]]))
 for(backend in c('serial','batched')){
  a<-.normal_desn_transition_engine(original,backend);z<-.normal_desn_transition_engine(clean,backend)
  H<-if(backend=='serial')h else lapply(h,function(v)matrix(v,length(v),2));u<-a$input(bank$history_scaled)
  if(backend=='batched')u<-matrix(u,length(u),2)
  A<-a$step(H,u);Z<-z$step(H,u);stopifnot(identical(A,Z));maximum_transition_error<-max(maximum_transition_error,max(abs(A$x-Z$x)))
 }
 raw<-.ext_origin_features(list(templates=list(clean)),1,h)
 error<-max(abs(.autodesn_feature_apply(bank$models[[m]],matrix(raw,1))-bank$models[[m]]$X[bank$n,-1]))
 stopifnot(error<1e-10);maximum_terminal_error<-max(maximum_terminal_error,error)
 maps[[m]]<-clean;bank$templates[m]<-list(NULL)
}
saveRDS(maps,file.path(out,'forecast_templates.rds'));rm(old_maps,maps);gc(FALSE)
bank$templates<-lapply(bank$models,function(m)list(states=list(H_all=list())))
bank$meta$inference_only<-TRUE
saveRDS(bank,file.path(out,'inference_bank.rds'))
extensions<-list()
for(family in c('F1','F2','F2flat')){
 e<-autodesn_extend_bank(bank,list(lags=1:90,prior=if(family=='F2')'grouped' else 'flat',cache_size=32),if(family=='F1')NULL else list(periods=20:120,harmonics=16))
 e<-if(family=='F1')autodesn_cache_statistics(e,max_bytes=128*1024^2) else autodesn_cache_calendar_blocks(e,max_bytes=128*1024^2)
 path<-file.path(out,paste0('extension_',family,'.rds'));saveRDS(e$extension,path)
 extensions[[family]]<-list(path=path,sha256=digest::digest(file=path,algo='sha256'),bank_id=e$extension$id,cache_version=e$extension$statistics_cache$version,numeric_cache_bytes=e$extension$statistics_cache$payload_bytes)
 rm(e);gc(FALSE)
}
files<-c('inference_bank.rds','forecast_templates.rds')
checks<-readRDS(file.path(out,'inference_bank.rds'));stopifnot(identical(checks$models,bank$models),identical(checks$prior,bank$prior),length(checks$history)==cutoff)
result<-list(complete=TRUE,cutoff=cutoff,washout=500L,scored_rows=c(501L,cutoff),admitted=length(bank$models),construction_bank_id=construction_id,original_standardized_bank_sha256=construction_sha,prefix_status=prefix_status,extensions=extensions,files=lapply(files,function(n)list(path=file.path(out,n),sha256=digest::digest(file=file.path(out,n),algo='sha256'))),source_snapshot=basename(snapshot),maximum_compact_transition_error=maximum_transition_error,maximum_terminal_feature_error=maximum_terminal_error,heldout_read=FALSE,validation_outcomes_read=FALSE,posterior_qualified=FALSE,forecast_allowed=FALSE,scope='Full fixed456-definition chronological-prefix reconstruction with refitted training scalers, compact maps and complete-support inference caches. No family selection, inference, or benchmark forecast executed.')
jsonlite::write_json(result,file.path(out,'manifest.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
file.copy(file.path(out,'manifest.json'),file.path(repository,'validation/autodesn/remediation/evidence',paste0('prefix_bank_',cutoff,'.json')))
# Reproducible construction intermediates are superseded by checked exact
# matrices/maps. Keep admission/scaling/status contracts and all audit CSVs.
unlink(file.path(out,'raw_bank/parts'),recursive=TRUE)
unlink(c(file.path(out,'raw_bank/bank.rds'),file.path(out,'standardized_bank/bank.rds')))
cat('FULL_PREFIX_BANK_COMPLETE',cutoff,'\n')
