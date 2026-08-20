#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("digest", "jsonlite", "pkgload")) {
    if (!requireNamespace(pkg, quietly=TRUE)) stop("Missing package: ", pkg)
  }
})
args <- commandArgs(trailingOnly=TRUE)
arg <- function(flag, default=NULL) { i <- which(args == flag); if (!length(i)) default else args[i[1]+1] }
repo <- normalizePath(system("git rev-parse --show-toplevel", intern=TRUE), winslash="/", mustWork=TRUE)
setwd(repo); pkgload::load_all(repo, quiet=TRUE)
source(file.path(repo, "validation/fitforecast_v2/R/qdesn_canonical_gap_mcmc_v2.R"))
out <- normalizePath(arg("--output-root", file.path(repo, "reports/shared_fitforecast_v2_orchestration/canonical_gap_v2_materialization")), winslash="/", mustWork=FALSE)
dir.create(out, recursive=TRUE, showWarnings=FALSE)
stub <- file.path(repo, "config/validation", qdesn_cgcv2_stage)
targets <- qdesn_ssv2_read_csv(paste0(stub, "_target_cells.csv"))
profiles <- qdesn_ssv2_read_csv(paste0(stub, "_candidate_profiles.csv"))

v8_registry_path <- "/data/jaguir26/local/src/exdqlm__wt__qdesn_forecast_gap_adaptive_mcmc_v1_1p0p0/reports/shared_fitforecast_v2_orchestration/qdesn_forecast_gap_adaptive_mcmc_v1_20260818_214229/confirmation/canonical_source_registry.csv"
if (!file.exists(v8_registry_path)) stop("Frozen v8 canonical source registry is unavailable.")
v8 <- qdesn_ssv2_read_csv(v8_registry_path)
rows <- lapply(seq_len(nrow(targets)), function(i) {
  t <- targets[i,,drop=FALSE]
  x <- v8[v8$family == t$family & abs(v8$tau-t$tau)<1e-10,,drop=FALSE]
  if (!nrow(x)) stop("No canonical source for ", t$target_cell_id)
  x <- x[1,,drop=FALSE]
  x$target_cell_id <- t$target_cell_id
  x$parent_request_path <- file.path(repo, t$parent_request_path)
  x$parent_request_sha256 <- t$parent_request_sha256
  x
})
registry <- do.call(rbind, rows)
for (i in seq_len(nrow(registry))) {
  if (!file.exists(registry$series_wide_path[i]) ||
      qdesn_ssv2_sha256(registry$series_wide_path[i]) != registry$series_wide_sha256[i] ||
      !file.exists(registry$parent_request_path[i]) ||
      qdesn_ssv2_sha256(registry$parent_request_path[i]) != registry$parent_request_sha256[i]) {
    stop("Canonical source/request hash failed for ", registry$target_cell_id[i])
  }
}
registry_path <- qdesn_ssv2_write_csv(registry, file.path(out, "canonical_source_registry.csv"))

windows <- new.env(parent=emptyenv()); window_rows <- list()
resolve_window <- function(profile, target) {
  key <- paste(target$family, target$tau, profile$m, profile$washout, sep="|")
  if (exists(key, windows, inherits=FALSE)) return(get(key, windows))
  root <- registry[registry$target_cell_id == target$target_cell_id,,drop=FALSE]
  staged <- qdesn_cgcv2_stage_canonical_window(root, profile$m, profile$washout,
    file.path(repo, "results/qdesn_mcmc_validation", qdesn_cgcv2_stage, "staged_source_windows"))
  assign(key, staged, windows); window_rows[[length(window_rows)+1L]] <<- staged
  staged
}
write_job <- function(profile, target, stage, chain, seed_id) {
  job <- qdesn_cgcv2_make_job(repo, profile, target, resolve_window(profile,target),
    stage, registry_path, chain, seed_id)
  job <- qdesn_cgcv2_apply_seeds(job)
  path <- file.path(out, "configs", stage, paste0(job$job_id, ".json"))
  qdesn_ssv2_write_json(job, path)
  data.frame(job_id=job$job_id, stage=stage, target_cell_id=job$target_cell_id,
    likelihood_target=job$likelihood_target, target_metrics=paste(job$target_metrics,collapse=";"),
    candidate_id=job$candidate_id, chain_id=job$chain_id,
    reservoir_seed_id=job$reservoir_seed_id, source_id=job$source_id,
    objective_metric=job$objective_metric, current_value=job$current_value,
    comparator_value=job$comparator_value, config_path=path,
    config_sha256=qdesn_ssv2_sha256(path), expected_n_burn=job$config$inference$mcmc$n_burn,
    expected_n_mcmc=job$config$inference$mcmc$n_mcmc,
    effective_readout_dimension=job$root_spec$effective_readout_dimension,
    timeout_seconds=job$config$validation$timeout_seconds, stringsAsFactors=FALSE)
}
target_map <- split(targets, targets$target_cell_id)
profile_map <- split(profiles, profiles$target_cell_id)
al_cell <- targets$target_cell_id[targets$likelihood_target=="al"][1]
ex_cell <- targets$target_cell_id[targets$likelihood_target=="exal"][1]
smoke <- rbind(
  write_job(profile_map[[al_cell]][1,,drop=FALSE], target_map[[al_cell]], "smoke", 1, "smoke_r01"),
  write_job(profile_map[[ex_cell]][1,,drop=FALSE], target_map[[ex_cell]], "smoke", 1, "smoke_r01"))
calibration <- do.call(rbind, lapply(names(profile_map), function(cell) {
  p <- profile_map[[cell]]; p <- p[which.max(p$effective_readout_dimension),,drop=FALSE]
  write_job(p, target_map[[cell]], "calibration", 1, "calibration_r01")
}))
screen <- do.call(rbind, lapply(names(profile_map), function(cell) do.call(rbind,
  lapply(seq_len(nrow(profile_map[[cell]])), function(i) do.call(rbind,
    lapply(1:2, function(chain) write_job(profile_map[[cell]][i,,drop=FALSE],
      target_map[[cell]], "screen", chain, sprintf("screen_r%02d",chain))))))))
qdesn_ssv2_write_csv(smoke, file.path(out,"smoke_plan.csv"))
qdesn_ssv2_write_csv(calibration, file.path(out,"calibration_plan.csv"))
qdesn_ssv2_write_csv(screen, file.path(out,"screen_plan.csv"))
window_registry <- do.call(rbind, window_rows)
qdesn_ssv2_write_csv(window_registry, file.path(out,"source_window_registry.csv"))
manifest <- list(schema_version="qdesn_canonical_gap_mcmc_v2_materialization_v1",
  generated_at=as.character(Sys.time()), git_commit=system("git rev-parse HEAD",intern=TRUE),
  canonical_source_registry_path=registry_path,
  canonical_source_registry_sha256=qdesn_ssv2_sha256(registry_path),
  target_cells=nrow(targets), candidate_profiles=nrow(profiles),
  stage_counts=list(smoke=nrow(smoke),calibration=nrow(calibration),screen=nrow(screen)),
  planned_maximum=list(refine=36L,confirmation=24L), exact_exal_method=qdesn_cgcv2_method_id)
qdesn_ssv2_write_json(manifest,file.path(out,"materialization_manifest.json"))
cat(sprintf("MATERIALIZATION_OK smoke=%d calibration=%d screen=%d windows=%d\n",
            nrow(smoke),nrow(calibration),nrow(screen),nrow(window_registry)))
