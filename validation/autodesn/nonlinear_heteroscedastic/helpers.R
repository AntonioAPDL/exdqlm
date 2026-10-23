# Dataset-specific bindings around the unchanged validated comparison adapters.
source("validation/autodesn/rhs_comparison/helpers.R")
source("validation/autodesn/rhs_comparison/runner.R")
nh_root <- "validation/autodesn/nonlinear_heteroscedastic"
c1_root <- nh_root # only the imported reservoir specification lookup uses this
c1_data <- function() {
  x <- read.csv(file.path(nh_root,"input/series.csv"))
  stopifnot(identical(names(x),c("time","y")),identical(x$time,1:3000),all(is.finite(x$y)))
  x
}
nh_configuration <- function() {
  cfg <- jsonlite::fromJSON(file.path(nh_root,"configuration.json"))
  for(name in names(cfg$input_sha256))
    stopifnot(identical(digest::digest(file=file.path(nh_root,"input",name),algo="sha256"),cfg$input_sha256[[name]]))
  stopifnot(identical(digest::digest(file=file.path(nh_root,"dgp.R"),algo="sha256"),cfg$dgp_source_sha256))
  cfg$mode <- "full";cfg
}
rhs_configuration <- function(options) {
  stopifnot(options$mode=="full");nh_configuration()
}
