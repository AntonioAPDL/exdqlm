# Replay the compact committed checkpoints against all saved path snapshots.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
root<-"validation/autodesn/nonlinear_heteroscedastic";base<-file.path(root,"artifacts")
cases<-commandArgs(trailingOnly=TRUE)
study<-jsonlite::fromJSON(file.path(root,"study.json"))
if(!length(cases)) cases<-study$scenarios$id
stopifnot(all(cases%in%study$scenarios$id))
y<-c1_data()$y;rows<-list()
for(sc in cases) {
 method<-study$scenarios$method[match(sc,study$scenarios$id)]
 d<-file.path(base,sc,method);cfg<-jsonlite::fromJSON(file.path(base,sc,"configuration.json"))
 cp<-readRDS(file.path(root,"evidence",paste0(sc,"_forecast_checkpoint.rds")))
 origins<-c(2500L,2735L,2970L);s<-hr_origin_states(cp,y[seq_len(max(origins))],origins)
 p<-cp;ids<-seq_len(192L);p$draws<-cp$draws[ids,,drop=FALSE];p$beta<-cp$beta[ids];p$source_ids<-cp$source_ids[ids]
 for(i in seq_along(origins)) {
  o<-origins[i];fc<-hr_auto(p,s$states[[i]],s$history_scaled[seq_len(o)],30L,8L,c1_noise(cfg$innovation_seed,o,8L,192L,30L))
  path<-read.csv(gzfile(file.path(d,paste0("paths_",o,".csv.gz"))))
  error<-max(abs(fc$yrep-matrix(path$yrep,30L)),abs(fc$mu_draws-matrix(path$mu,30L)),abs(fc$sd_draws-matrix(path$sd,30L)))
  stopifnot(error<1e-10)
  rows[[length(rows)+1L]]<-data.frame(scenario=sc,origin=o,max_path_error=error,paths=1536L,horizons=30L)
 }
 cat(sc,"archived checkpoint replayed at all three origins\n");rm(cp,p,s,fc,path);gc(FALSE)
}
out<-file.path(base,"validation/replay_validation.csv")
r<-do.call(rbind,rows)
if(file.exists(out)) {old<-read.csv(out);r<-rbind(old[!old$scenario%in%cases,,drop=FALSE],r)}
write.csv(r,out,row.names=FALSE)
rhs_json(list(complete=nrow(r)==9L&&length(unique(r$scenario))==3L,
 verified_cases=unique(r$scenario),max_path_error=max(r$max_path_error),windows=nrow(r)),sub("csv$","json",out))
