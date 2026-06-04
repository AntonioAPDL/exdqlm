exdqlm_test_thread_env <- c(
  OMP_NUM_THREADS = "1",
  OMP_THREAD_LIMIT = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  BLIS_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  RCPP_PARALLEL_NUM_THREADS = "1"
)

do.call(Sys.setenv, as.list(exdqlm_test_thread_env))

options(
  exdqlm.cpp_threads = 1L,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE
)
