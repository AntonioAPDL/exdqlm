source("validation/autodesn/c1_comparison/helpers.R")
library(forecast)
cfg <- c1_config();y <- c1_data()$y;out <- file.path(c1_root,"artifacts/arima")
dir.create(out,recursive=TRUE,showWarnings=FALSE);started <- proc.time()[3]
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
train <- y[cfg$fit_start:cfg$fit_end];period <- findfrequency(train)
path <- file.path(out,"fit.rds")
if(file.exists(path)) fit <- readRDS(path) else {
  cat("AutoARIMA training-only estimated frequency:",period,"\n");flush.console()
  fit <- auto.arima(ts(train,frequency=period),max.p=cfg$arima_max_p,max.q=cfg$arima_max_q,
    max.P=cfg$arima_max_P,max.Q=cfg$arima_max_Q,max.order=cfg$arima_max_order,
    stepwise=FALSE,approximation=FALSE,method="ML",parallel=TRUE,num.cores=2)
  c1_save(fit,path)
}
rows <- list();variance_diffs <- numeric()
for(origin in cfg$first_origin:cfg$last_origin) {
  updated <- Arima(ts(y[cfg$fit_start:origin],frequency=period),model=fit)
  stopifnot(identical(coef(updated),coef(fit)))
  variance_diffs <- c(variance_diffs,updated$sigma2-fit$sigma2)
  updated$sigma2 <- fit$sigma2
  fc <- forecast(updated,h=cfg$H,level=c(50,90))
  if(origin==cfg$first_origin) {
    base <- forecast(fit,h=cfg$H,level=c(50,90))
    stopifnot(max(abs(base$mean-fc$mean))<1e-8,max(abs(base$upper-fc$upper))<1e-8)
  }
  sd <- as.numeric((fc$upper[,2]-fc$mean)/qnorm(.95))
  stopifnot(all(is.finite(sd)),all(sd>0))
  rows[[length(rows)+1L]] <- data.frame(origin=origin,horizon=1:cfg$H,target=origin+1:cfg$H,
    actual=y[origin+1:cfg$H],component=1L,weight=1,mean=as.numeric(fc$mean),sd=sd)
  if(origin%%50L==0) {cat("AutoARIMA origin",origin,"complete\n");flush.console()}
}
write.csv(do.call(rbind,rows),file.path(out,"components.csv"),row.names=FALSE)
c1_json(list(complete=TRUE,model="AutoARIMA",period=period,orders=arimaorder(fit),
  coefficients=coef(fit),innovation_variance=fit$sigma2,aicc=fit$aicc,
  max_native_variance_change=unname(max(abs(variance_diffs))),
  package_version=as.character(packageVersion("forecast")),origins=471,fit_rows=2000,
  elapsed_seconds=unname(proc.time()[3]-started)),file.path(out,"status.json"))
