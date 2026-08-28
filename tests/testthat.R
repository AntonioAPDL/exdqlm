# Cap native test threads before loading the package. CRAN's Debian pretest
# reports a NOTE when CPU time greatly exceeds elapsed time, which can happen
# when OpenMP/BLAS-backed tests run on several cores.
setup_file <- "testthat/setup-cran-thread-controls.R"
if (!file.exists(setup_file)) {
  setup_file <- file.path("tests", setup_file)
}
source(setup_file, local = TRUE)

library(testthat)
library(exdqlm)

test_check("exdqlm")
