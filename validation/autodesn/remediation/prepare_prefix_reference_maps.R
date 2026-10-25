# A fold may read fixed maps and first-500 input transforms, never old terminal
# reservoir states. Extract an explicit narrow reference before fold fitting.
r<-'validation/autodesn/remediation'
source<-file.path(r,'artifacts/forecast_templates.rds');templates<-readRDS(source)
metadata<-read.csv(file.path(r,'artifacts/F1/production_256000_joint128_recoverable/model_metadata.csv'))
reservoir_fields<-c('W','Win','Q','Q_is_identity','alpha','act_f','act_k')
input_fields<-c('D','n','n_tilde','m','m_input','add_bias','input_mode','standardize_inputs','lag_center','lag_scale','input_bound','input_bound_divisor','win_scale_bias','win_scale_global','win_scale_lags')
maps<-lapply(templates,function(t)list(reservoir=t$reservoir[intersect(reservoir_fields,names(t$reservoir))],meta=t$meta[intersect(input_fields,names(t$meta))]))
names(maps)<-metadata$candidate
allowed<-function(x)is.null(x)||is.atomic(x)||is.list(x)&&all(vapply(x,allowed,TRUE))
stopifnot(length(maps)==426L,all(vapply(maps,allowed,TRUE)),all(vapply(maps,function(t)is.null(t$states),TRUE)))
out<-file.path(r,'artifacts/prefix_reference_maps');dir.create(out,recursive=TRUE,showWarnings=FALSE)
path<-file.path(out,'maps.rds');stopifnot(!file.exists(path));saveRDS(maps,path)
jsonlite::write_json(list(complete=TRUE,path=path,sha256=digest::digest(file=path,algo='sha256'),source_map_sha256=digest::digest(file=source,algo='sha256'),reservoir_fields=reservoir_fields,input_fields=input_fields,candidate_names=names(maps),terminal_states_present=FALSE,response_history_present=FALSE,functions_present=FALSE,scope='Fixed seeded numeric reservoir maps and first500 input transforms only; no post-washout response/state values are passed to fold construction'),file.path(r,'evidence/prefix_reference_maps.json'),pretty=TRUE,auto_unbox=TRUE)
