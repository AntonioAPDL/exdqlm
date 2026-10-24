root <- "validation/autodesn/nonlinear_heteroscedastic"
source(file.path(root,"dgp.R"))
out <- file.path(root,"input");dir.create(out,recursive=TRUE,showWarnings=FALSE)
seed <- 1766021L;burn <- 6000L;n <- 3000L
data <- nh_simulate(n,seed,burn)
stopifnot(all(is.finite(as.matrix(data))),all(data$conditional_sd>0))
write.csv(data[c("time","y")],file.path(out,"series.csv"),row.names=FALSE)
# Oracle quantities are isolated from the only two-column model input.
write.csv(data,file.path(out,"dgp_truth.csv"),row.names=FALSE)
legacy <- "validation/autodesn/c1_comparison/input"
for(name in c("specifications.rds","specification_grid.csv","specification_recovery_audit.json"))
  stopifnot(file.copy(file.path(legacy,name),file.path(out,name),overwrite=TRUE))
meta <- list(name="NHS1: threshold dynamics, asymmetric seasonal pulses and GJR volatility",
 seed=seed,burnin=burn,retained=n,period=60L,short_period=12L,trend=FALSE,
 generated_once_before_fitting=TRUE,seed_selection="Single predeclared seed; no seed search or test-outcome selection",
 source_sha256=digest::digest(file=file.path(root,"dgp.R"),algo="sha256"),
 conditional_second_moment_bound=list(omega_max=.046,expected_volatility_coefficient=.93,
 mean_square_innovation_upper_bound=.046/(1-.93)),
 truth_use="Reporting only; model adapters read only input/series.csv time,y")
jsonlite::write_json(meta,file.path(out,"dgp_manifest.json"),auto_unbox=TRUE,pretty=TRUE,digits=16)
cfg <- jsonlite::fromJSON("validation/autodesn/rhs_comparison/configuration.json",simplifyVector=FALSE)
cfg$series <- "NHS1";cfg$dgp_source_sha256 <- meta$source_sha256
cfg$source_protocol <- "Frozen C1 temporal protocol, fresh data and fresh fits"
cfg$source_commit <- "d67aabe912e7a81b02d3d19920bfcb2b8cb6d9d1"
cfg$feature_workers <- 1L;cfg$origin_workers <- 1L
cfg$input_sha256 <- as.list(vapply(list.files(out),function(name) digest::digest(file=file.path(out,name),algo="sha256"),""))
jsonlite::write_json(cfg,file.path(root,"configuration.json"),auto_unbox=TRUE,pretty=TRUE,digits=16)
cat("Frozen NHS1 input created; seed",seed,"; no fits or scores computed.\n")
