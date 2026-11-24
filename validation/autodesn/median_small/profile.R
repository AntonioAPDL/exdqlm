source('validation/autodesn/median_small/common.R');ms_load(FALSE)
cfg<-ms_config();d<-ms_generate();grid<-ms_grid();spec<-as.list(grid[nrow(grid),])
start<-proc.time()[3];b<-ms_build(d$y[1:2900],spec,1900);build<-proc.time()[3]-start
start<-proc.time()[3];f<-ms_gaussian(b,1);fit<-proc.time()[3]-start
start<-proc.time()[3];score<-ms_row(b,f,cfg$val_origins,d$y[1:2900],16L,401L);coarse<-proc.time()[3]-start
start<-proc.time()[3];fc<-ms_forecast_gaussian(b,f,2840L,d$y[1:2840],256L,501L);fine<-proc.time()[3]-start
ms_json(list(complete=TRUE,reservoir_build_seconds=unname(build),ridge_fit_seconds=unname(fit),
  ten_origin_coarse_seconds=unname(coarse),one_origin_fine_seconds=unname(fine),
  projected_screen_seconds=unname(144*build+576*(fit+coarse)+16*(build+fit+10*fine)),
  dimension=ncol(b$X_fit),specification=spec,source_sha256=ms_sources(),
  scope='Single representative maximum-dimension configuration; projection is not observed total runtime'),
  file.path(ms_root,'evidence/profile.json'))
