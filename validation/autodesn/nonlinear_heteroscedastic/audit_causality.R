# Hold every posterior draw and innovation fixed, alter only unavailable data.
source("validation/autodesn/nonlinear_heteroscedastic/helpers.R")
args <- commandArgs(trailingOnly=TRUE);stopifnot(length(args)==1L)
sc <- args[1];study <- jsonlite::fromJSON(file.path(nh_root,"study.json"))
method <- study$scenarios$method[match(sc,study$scenarios$id)]
d <- file.path(nh_root,"artifacts",sc,method)
cp <- readRDS(file.path(d,"posterior_checkpoint.rds"));stopifnot(isTRUE(cp$qualified))
cfg <- jsonlite::fromJSON(file.path(nh_root,"artifacts",sc,"configuration.json"))
y <- c1_data()$y;thin <- cp;ids <- 1:24
thin$draws <- cp$draws[ids,,drop=FALSE];thin$beta <- cp$beta[ids];thin$source_ids <- cp$source_ids[ids]
rows <- list()
for(o in c(2500L,2735L,2970L)) {
 other <- y;other[(o+1L):3000L] <- other[(o+1L):3000L]+100
 a <- hr_origin_states(thin,y,o);b <- hr_origin_states(thin,other,o)
 stopifnot(identical(a$states,b$states))
 noise <- c1_noise(cfg$innovation_seed,o,4L,24L,30L)
 f <- hr_auto(thin,a$states[[1]],a$history_scaled[seq_len(o)],30L,4L,noise)
 g <- hr_auto(thin,b$states[[1]],b$history_scaled[seq_len(o)],30L,4L,noise)
 error <- max(abs(f$yrep-g$yrep),abs(f$mu_draws-g$mu_draws));stopifnot(error==0)
 rows[[length(rows)+1L]] <- data.frame(origin=o,max_path_error=error)
}
write.csv(do.call(rbind,rows),file.path(d,"future_perturbation.csv"),row.names=FALSE)
rhs_json(list(complete=TRUE,origins=c(2500L,2735L,2970L),future_observations_added=100,
 same_posterior_and_innovations=TRUE,max_path_error=0),file.path(d,"causality_audit.json"))
cat(sc,"future-data perturbation audit passed at all three origins\n")
