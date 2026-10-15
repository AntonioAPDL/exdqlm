#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE, digits = 17)
Sys.setenv(OMP_NUM_THREADS = 1, OMP_THREAD_LIMIT = 1, OMP_DYNAMIC = "FALSE",
  OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1, BLIS_NUM_THREADS = 1,
  VECLIB_MAXIMUM_THREADS = 1, NUMEXPR_NUM_THREADS = 1, EXDQLM_REQUIRE_PACKAGES_ONLY = 1)
file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
repo <- normalizePath(file.path(dirname(file), "../../.."))
for (name in c("forecast_prefix_metric_intervals_v1", "forecast_prefix_reconstruction_v1", "forecast_prefix_recovery_v2"))
  source(file.path(repo, "validation/fitforecast_v2/R", paste0(name, ".R")))
args <- commandArgs(TRUE)
arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  fpf_assert(i < length(args), paste("Missing value:", flag))
  args[i + 1L]
}
mode <- arg("--mode")
if (mode == "worker") {
  path <- normalizePath(arg("--contract"))
  contract <- fpr_json(path)
  fpf_assert(identical(contract$recovery$action, "NEW_CHAIN"), "Worker may only fit an unstarted chain.")
  state <- fpr_worker(path)
  quit(status = if (state$status == "COMPLETE") 0L else 1L)
}
output <- arg("--output")
fpf_assert(!is.null(output), "--output required.")
if (mode == "prepare") {
  fpr2_materialize(repo, arg("--original"), output)
} else if (mode == "health") {
  print(fpr2_health(normalizePath(output)))
} else if (mode == "rescore") {
  output <- normalizePath(output)
  fpr_assert_hashes(fpf_read(file.path(output, "input_manifest.csv")))
  plan <- fpf_read(file.path(output, "task_plan.csv"))
  for (i in which(plan$action == "RESCORE_CACHED_FORECAST")) {
    state <- file.path(plan$job_root[i], "task_status.json")
    if (!file.exists(state)) fpr2_rescore(plan$contract_path[i])
    fpf_assert(fpf_json(state)$status == "COMPLETE", "Cached rescore failed; retain evidence and stop.")
    fpr2_verify_complete(plan[i, ])
  }
  print(fpr2_health(output))
} else if (mode == "controller") {
  fpr2_controller(repo, normalizePath(output), file, as.integer(arg("--workers", "15")),
    as.integer(strsplit(arg("--cpus", paste(32:46, collapse = ",")), ",", fixed = TRUE)[[1L]]))
} else if (mode == "summarize") {
  out <- normalizePath(output)
  fpr_summarize(out)
  source(file.path(repo, "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"))
} else stop("Unknown recovery mode.", call. = FALSE)
