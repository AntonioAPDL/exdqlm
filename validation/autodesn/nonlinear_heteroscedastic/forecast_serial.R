# Resume forecasts without loading the large inference designs or using forks.
# This changes scheduling only. All posterior draws, coefficient transports,
# origins, innovations, observed-state timing and predictive budgets are frozen.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
sc<-args[1];study<-jsonlite::fromJSON("validation/autodesn/nonlinear_heteroscedastic/study.json")
stopifnot(sc%in%study$scenarios$id)
method<-study$scenarios$method[match(sc,study$scenarios$id)]
base<-file.path("validation/autodesn/nonlinear_heteroscedastic/artifacts",sc)
d<-file.path(base,method);cfg<-jsonlite::fromJSON(file.path(base,"configuration.json"))
st<-jsonlite::fromJSON(file.path(d,"status.json"));stopifnot(isTRUE(st$qualified))
stopifnot(identical(digest::digest(file=file.path(nh_root,"helpers.R"),algo="sha256"),cfg$dataset_adapter_sha256))
stopifnot(isTRUE(jsonlite::fromJSON(file.path(d,"independent_screen.json"))$passed))
prov<-jsonlite::fromJSON(file.path(d,"provenance.json"))
for(key in c("input_sha256","fit_start","fit_end","first_origin","last_origin","H","outer_draws","inner_paths","innovation_seed"))
 stopifnot(identical(cfg[[key]],prov$configuration[[key]]))
for(name in names(cfg$input_sha256))
 stopifnot(identical(digest::digest(file=file.path(c1_root,"input",name),algo="sha256"),cfg$input_sha256[[name]]))
for(i in seq_len(nrow(prov$production_source))) {
 p<-prov$production_source[i,];stopifnot(identical(digest::digest(file=p$path,algo="sha256"),p$sha256))
}
if(!is.null(prov$harness_source)) for(i in seq_len(nrow(prov$harness_source))) {
 p<-prov$harness_source[i,];stopifnot(identical(digest::digest(file=p$path,algo="sha256"),p$sha256))
}
cp<-readRDS(file.path(d,"posterior_checkpoint.rds"))
stopifnot(isTRUE(cp$qualified),identical(cp$comparison_contract_id,st$contract_id))
cfg$origin_workers<-1L
rhs_json(list(scheduling_override=1L,statistical_configuration_changed=FALSE,
 reason="Serial execution avoids fork-worker failures and omits unused inference matrices.",
 source_sha256=digest::digest(file="validation/autodesn/nonlinear_heteroscedastic/forecast_serial.R",algo="sha256"),
 harness_source_sha256=vapply(c("validation/autodesn/rhs_comparison/helpers.R","validation/autodesn/rhs_comparison/runner.R"),function(p) digest::digest(file=p,algo="sha256"),""),
 completed_origins_before_invocation=length(list.files(d,pattern="^origin_[0-9]+[.]rds$"))),file.path(d,"serial_execution.json"))
rhs_forecast(cp,cfg,d,st$contract_id)
