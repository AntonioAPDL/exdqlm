#!/usr/bin/env Rscript

## --- Force-load package from source; also install for workers ---
suppressWarnings(suppressMessages({
  pkg_root <- normalizePath(Sys.getenv("EXDQLM_PKG_ROOT", getwd()), mustWork = FALSE)
  if (!file.exists(file.path(pkg_root, "DESCRIPTION"))) {
    stop("No DESCRIPTION at: ", pkg_root, "\nRun from repo root or set EXDQLM_PKG_ROOT=/path/to/repo")
  }
  # Ensure workers can find the same source path
  Sys.setenv(EXDQLM_PKG_ROOT = pkg_root)

  if (!requireNamespace("pkgload", quietly = TRUE)) {
    install.packages("pkgload", repos = "https://cloud.r-project.org")
  }
  pkgload::load_all(pkg_root, quiet = TRUE)

  # Also install into the user library so PSOCK workers that do library(exdqlm) get THIS version
  # (quietly; ignore output)
  try(system(sprintf("R CMD INSTALL %s", shQuote(pkg_root)), ignore.stdout = TRUE, ignore.stderr = TRUE), silent = TRUE)

  message("Loaded exdqlm from source: ", pkg_root)
  message("qdesn_fit_vb formals: ", paste(names(formals(exdqlm::qdesn_fit_vb)), collapse = ", "))
}))

## Pin threads in the launcher session too (workers are pinned inside the selector)
Sys.setenv(
  OMP_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  BLAS_NUM_THREADS = "1"
)

args <- commandArgs(trailingOnly = TRUE)
arg_get <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
arg_flag <- function(name, default = "FALSE") {
  tolower(arg_get(name, default)) %in% c("1","true","t","yes","y")
}

## ---- Locate data ----
csv_env <- Sys.getenv("EXDQLM_DATA", Sys.getenv("QDESN_DATA", NA))
if (!is.na(csv_env) && dir.exists(csv_env)) csv_env <- file.path(csv_env, "data_USGS_ppt_soil.csv")
csv_candidates <- c(
  if (!is.na(csv_env)) csv_env,
  file.path(getwd(), "data-raw", "external", "data_USGS_ppt_soil.csv"),
  "/data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv",
  "C:/Users/anton/Downloads/data_USGS_ppt_soil.csv",
  "/mnt/c/Users/anton/Downloads/data_USGS_ppt_soil.csv",
  path.expand("~/Downloads/data_USGS_ppt_soil.csv"),
  file.path(getwd(), "data_USGS_ppt_soil.csv")
)
csv_path <- arg_get("data", NA)
if (!is.na(csv_path) && !file.exists(csv_path)) stop("--data provided but not found: ", csv_path)
if (is.na(csv_path)) for (p in csv_candidates) if (file.exists(p)) { csv_path <- p; break }
if (is.na(csv_path)) {
  cat("Working directory:", getwd(), "\n")
  cat("Tried:\n", paste(" -", csv_candidates), sep = "\n")
  stop("Could not locate data_USGS_ppt_soil.csv (or pass --data=/path/to/csv)")
} else message("Using data file: ", csv_path)

## ---- Read + sanitize ----
dat_raw <- read.csv(csv_path, check.names = FALSE, stringsAsFactors = FALSE)
nm <- trimws(tolower(gsub("\ufeff", "", names(dat_raw), fixed = TRUE)))
names(dat_raw) <- nm
syn_map <- c("precip"="ppt","prcp"="ppt","rain"="ppt","soil_moisture"="soil","soilmoist"="soil","sm"="soil")
for (old in names(syn_map)) if (old %in% names(dat_raw)) names(dat_raw)[names(dat_raw)==old] <- syn_map[[old]]
stopifnot(all(c("usgs","ppt","soil") %in% names(dat_raw)))
dat <- dat_raw[, c("usgs","ppt","soil")]; dat[] <- lapply(dat, as.numeric)
y <- dat$usgs; ppt <- dat$ppt; soil <- dat$soil

## ---- CLI knobs ----
stage            <- arg_get("stage", "coarse")
parallel_run     <- arg_flag("parallel", "TRUE")
workers_in       <- arg_get("workers", NA)
keep_art         <- arg_flag("keep_artifacts", "TRUE")
do_plot          <- arg_flag("plot", "FALSE")
progress_every   <- as.integer(arg_get("progress_every", "1"))

# Grid & sampling controls
grid_preset_in   <- arg_get("grid", Sys.getenv("GRID", "default"))
limit_specs_in   <- arg_get("limit_specs", Sys.getenv("LIMIT_SPECS", NA))
grid_seed_in     <- arg_get("grid_seed", Sys.getenv("GRID_SEED", "123"))
# Seeds
seeds_csv        <- arg_get("seeds", Sys.getenv("SEEDS", "42,101"))
seed_vec         <- as.integer(strsplit(gsub("\\s+", "", seeds_csv), ",")[[1]])

# NEW: lead weighting + split proportions
weight_leads_in <- arg_get("weight_leads", Sys.getenv("WEIGHT_LEADS", "inverse_h"))  # "inverse_h" or "uniform"
split_in        <- arg_get("split",        Sys.getenv("SPLIT",        "0.80,0.15,0.05"))
split_vec <- as.numeric(strsplit(gsub("\\s+", "", split_in), ",")[[1]])
if (length(split_vec) != 3 || any(!is.finite(split_vec)) || any(split_vec <= 0)) {
  stop("--split must be three positive numbers, e.g. 0.80,0.15,0.05")
}

ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
dir.create("logs", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
progress_log <- arg_get("progress_log", file.path("logs", paste0("progress_", stage, "_", ts, ".log")))

# Workers: honor explicit input if provided, but enforce >= 1
n_cores <- tryCatch(parallel::detectCores(), error = function(e) 1L)
if (is.na(workers_in)) {
  n_workers <- max(1L, n_cores - 1L)
} else {
  n_workers <- max(1L, as.integer(workers_in))
}

message(sprintf("Stage=%s | parallel=%s | workers=%d | keep_artifacts=%s | plot=%s",
                stage, parallel_run, n_workers, keep_art, do_plot))
message("Progress log: ", progress_log)
message(sprintf("Grid=%s | Limit=%s | GridSeed=%s | Seeds=%s | WeightLeads=%s | Split=%s",
                tolower(grid_preset_in),
                ifelse(is.na(limit_specs_in), "Inf (ignored by OptionA)", limit_specs_in),
                grid_seed_in,
                paste(seed_vec, collapse=","),
                tolower(weight_leads_in),
                split_in))
if (!is.na(limit_specs_in) || nzchar(grid_seed_in)) {
  message("NOTE: Option A currently ignores limit/grid_seed; driver will parse but not forward them.")
}


## ---- Call the selector (explicit namespace) ----
res <- exdqlm::model_selection_optionA(
  y=y, ppt=ppt, soil=soil,
  stage=stage,
  p_vec=c(0.05, 0.50, 0.95),
  seed_vec=seed_vec,
  parallel=parallel_run,
  n_workers=n_workers,
  keep_artifacts=keep_art,
  plot=do_plot,
  progress_console=TRUE,
  progress_log=progress_log,
  progress_every=progress_every,
  grid_preset=tolower(grid_preset_in),
  max_specs=if (is.na(limit_specs_in)) Inf else as.integer(limit_specs_in),
  grid_seed=as.integer(grid_seed_in)
)

## ---- Save artifacts ----
## ---- Save artifacts ----
lb_val_path   <- file.path("outputs", paste0("leaderboard_val_", stage, "_", ts, ".csv"))
sel_bundle_path <- file.path("outputs", paste0("selection_bundle_", stage, "_", ts, ".rds"))
test_bundle_path<- file.path("outputs", paste0("test_bundle_", stage, "_", ts, ".rds"))

# Validation leaderboard
write.csv(res$leaderboard, lb_val_path, row.names = FALSE)
# Bundles
saveRDS(res$selection_bundle, sel_bundle_path)
saveRDS(res$test_bundle,      test_bundle_path)

# Optional: write per-lead Test CRPS if present
if (!is.null(res$test_bundle$detail) && !is.null(res$test_bundle$detail$crps_by_h)) {
  test_crps_path <- file.path("outputs", paste0("test_crps_by_h_", stage, "_", ts, ".csv"))
  write.csv(
    data.frame(h = seq_along(res$test_bundle$detail$crps_by_h),
               crps = as.numeric(res$test_bundle$detail$crps_by_h)),
    test_crps_path, row.names = FALSE
  )
}

print(utils::head(res$leaderboard, 10))
message("Winner (validation): ", res$winner)
if (!is.null(res$test_bundle$agg_CRPS_test) && is.finite(res$test_bundle$agg_CRPS_test)) {
  message(sprintf("Test aggregated CRPS: %.6f", res$test_bundle$agg_CRPS_test))
}
message("Saved:\n  ", lb_val_path, "\n  ", sel_bundle_path, "\n  ", test_bundle_path, "\n  ", progress_log)
