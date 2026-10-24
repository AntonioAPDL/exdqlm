# Convert the already stripped augmented matrix view into a common raw view.
# Dummy templates retain only the exact terminal states used in the bank identity.
# They are never valid forecasting templates; forecasts reattach the original bank.
root<-'validation/autodesn/remediation';source('validation/autodesn/load_checkout.R')
view_path<-file.path(root,'artifacts/inference_bank_F2flat.rds')
e<-if(file.exists(view_path))readRDS(view_path) else autodesn_extend_bank(readRDS('validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds'),list(lags=1:90),list(periods=20:120,harmonics=16));raw<-e;initial<-e$extension$initial_states;raw$extension<-NULL;class(raw)<-setdiff(class(raw),'autodesn_extended_bank')
raw$templates<-lapply(initial,function(states)list(states=list(H_all=lapply(states,function(v)matrix(v,1)))))
identities<-list()
for(family in c('F1','F2','F2flat')) {
 a<-autodesn_extend_bank(raw,list(lags=1:90,prior=if(family=='F2')'grouped' else 'flat',cache_size=32),if(family=='F1')NULL else list(periods=20:120,harmonics=16))
 expected<-if(family=='F2flat')e$extension$id else jsonlite::fromJSON(file.path(root,'artifacts',family,'pilot/configuration.json'))$bank_id
 stopifnot(identical(a$extension$id,expected));identities[[family]]<-expected
}
raw$meta$inference_only<-TRUE;path<-file.path(root,'artifacts/inference_raw_bank.rds');temporary<-paste0(path,'.writing');saveRDS(raw,temporary,compress='gzip');stopifnot(file.rename(temporary,path))
# Verify serialized matrices and recomputed target identity after loading.
check<-readRDS(path);test<-autodesn_extend_bank(check,list(lags=1:90),NULL);stopifnot(identical(test$extension$id,identities$F1),identical(lapply(check$models,`[[`,'X'),lapply(raw$models,`[[`,'X')),identical(check$prior,raw$prior))
manifest<-list(complete=TRUE,path=path,sha256=digest::digest(file=path,algo='sha256'),bytes=unname(file.info(path)$size),source_bank_path='validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds',source_bank_sha256=digest::digest(file='validation/autodesn/nonlinear_heteroscedastic/artifacts/standardized_bank/bank.rds',algo='sha256'),bank_ids=identities,admitted=length(raw$models),forecast_templates_valid=FALSE,scope='Exact inference matrix view; all 426 priors, training rows, scalers and terminal-state identities retained. Reattach the original bank for forecasting.')
jsonlite::write_json(manifest,file.path(root,'artifacts/inference_cache_manifest.json'),pretty=TRUE,auto_unbox=TRUE)
jsonlite::write_json(manifest,file.path(root,'evidence/inference_cache_validation.json'),pretty=TRUE,auto_unbox=TRUE)
print(manifest[c('complete','admitted','bank_ids','forecast_templates_valid')])
