# Independent restoration/replay from the compact on-disk posterior objects.
source("validation/autodesn/load_checkout.R")
source("validation/autodesn/long_horizon/helpers.R")
source("validation/autodesn/heteroscedastic/dgp.R")
source("validation/autodesn/heteroscedastic/forecasting.R")
source("validation/autodesn/heteroscedastic/rolling/helpers.R")
root <- Sys.getenv("AUTODESN_ROLLING_OUT","validation/autodesn/heteroscedastic/rolling/artifacts")
cases <- read.csv(file.path(root,"cases.csv"));all_paths <- all_draws <- all_prob <- list()
for(i in seq_len(nrow(cases))) {
  row <- cases[i,];id <- sprintf("%s_r%02d",row$dgp,row$repetition);dest <- file.path(root,id)
  cp <- readRDS(file.path(dest,"auto_checkpoint.rds"))
  indices <- read.csv(file.path("validation/autodesn/heteroscedastic/artifacts",paste0(id,"_path_indices.csv")))
  old <- as.matrix(read.csv(file.path("validation/autodesn/heteroscedastic/artifacts",paste0(id,"_paths.csv")))[,-1L])
  # Only the 64 archived illustrative trajectories are needed for this replay.
  selected <- cp;selected$draws <- cp$draws[indices$outer_draw,,drop=FALSE]
  selected$beta <- cp$beta[indices$outer_draw];selected$source_ids <- cp$source_ids[indices$outer_draw]
  stopifnot(identical(as.integer(selected$source_ids),as.integer(indices$source_draw)))
  noise <- .autodesn_seed(row$dgp_seed+400L,function() matrix(rnorm(100L*192L*128L),100L))
  cols <- (indices$outer_draw-1L)*128L+indices$inner_path
  states <- hr_origin_states(selected,cp$bank$history,2500L)
  fc <- hr_auto(selected,states$states[[1L]],cp$bank$history_scaled,30L,1L,noise[1:30,cols,drop=FALSE])
  stopifnot(max(abs(fc$yrep-old[1:30,,drop=FALSE]))<1e-10)
  all_paths[[i]] <- data.frame(dgp=row$dgp,repetition=row$repetition,
    horizon=rep(1:30,64L),path=rep(1:64,each=30L),
    reference=as.vector(old[1:30,,drop=FALSE]),replay=as.vector(fc$yrep))
  for(method in c("AutoDESN","Fixed_DESN")) {
    x <- readRDS(file.path(dest,if(method=="AutoDESN") "auto_checkpoint.rds" else "fixed_checkpoint.rds"))
    stopifnot(nrow(x$draws)==192L,hh_qualify(x$diagnostics),x$bank$n==2000L,
      identical(x$bank$keep_idx,501:2500),identical(as.numeric(x$bank$history),as.numeric(cp$bank$history)))
    all_draws[[length(all_draws)+1L]] <- cbind(dgp=row$dgp,repetition=row$repetition,method=method,
      outer_draw=1:192,source_draw=x$source_ids,x$draws)
  }
  all_prob[[i]] <- cbind(dgp=row$dgp,repetition=row$repetition,cp$model_summary)
}
write.csv(do.call(rbind,all_paths),file.path(root,"checkpoint_path_replay.csv"),row.names=FALSE)
write.csv(do.call(rbind,all_draws),file.path(root,"posterior_joint_draws.csv"),row.names=FALSE)
write.csv(do.call(rbind,all_prob),file.path(root,"posterior_model_probabilities.csv"),row.names=FALSE)
cat("Restored all 18 checkpoints; replayed all 64 archived paths over 30 leads in every case.\n")
