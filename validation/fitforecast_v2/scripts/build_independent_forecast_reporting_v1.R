#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE, digits = 17)
Sys.setenv(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1)
data.table::setDTthreads(1L)
file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
repo <- normalizePath(file.path(dirname(file), "../../.."))
for (name in c("forecast_prefix_metric_intervals_v1", "forecast_prefix_reconstruction_v1",
  "independent_dgp_oracle_reference_v1", "independent_forecast_reporting_v1"))
  source(file.path(repo, "validation/fitforecast_v2/R", paste0(name, ".R")))
args <- commandArgs(TRUE)
arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  fpf_assert(i < length(args), paste("Missing value for", flag)); args[i + 1L]
}
run <- normalizePath(arg("--source-run", Sys.getenv("IND_PREFIX_RECOVERY_RUN")), mustWork = TRUE)
article <- normalizePath(arg("--article-root", Sys.getenv("IND_ARTICLE_ROOT")), mustWork = TRUE)
policy <- file.path(repo, "validation/fitforecast_v2/config/independent_forecast_reporting_300_500_v1.json")
output <- arg("--output", file.path(repo, "validation/fitforecast_v2/promotions/independent_forecast_300_500_v1"))
archive <- arg("--archive-root", "/data/jaguir26/local/artifacts/independent_qdesn_validation/metric_intervals_v10_evidence_bundle_v1_20260824")
ifr_build(repo, run, article, output, policy, archive)
cat("COMPLETE: 144 forecast cells; 72 unchanged fit cells; no fits or forecasts launched.\n")
