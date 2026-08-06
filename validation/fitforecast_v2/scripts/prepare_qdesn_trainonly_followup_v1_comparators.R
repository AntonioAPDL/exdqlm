#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else {
  "validation/fitforecast_v2/scripts/prepare_qdesn_trainonly_followup_v1_comparators.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
repo_root <- ffv2_repo_root()
run_tag_prefix <- as.character(args$`run-tag-prefix` %||% "qdesn-tfv1-comparator")[1L]
state_root <- ffv2_resolve_path(args$`state-root` %||% file.path(
  repo_root, "reports", "shared_fitforecast_v2_orchestration", "qdesn_trainonly_followup_v1_manual"
), must_work = FALSE)
dry_run <- ffv2_truthy(args$`dry-run` %||% FALSE)
overwrite <- ffv2_truthy(args$overwrite %||% FALSE)
smoke_mode <- ffv2_truthy(args$smoke %||% FALSE)
dir.create(state_root, recursive = TRUE, showWarnings = FALSE)

base_path <- file.path(harness_root, "config", "exdqlm_dynamic_fitforecast_v2_defaults.yaml")
candidate_path <- ffv2_default_vb_calibration_candidates_path()
candidate <- ffv2_c13_mcmc_candidate(ffv2_read_vb_calibration_candidates(candidate_path))

source_rows <- data.frame(
  source_role = c("article", "dev04"),
  scenario_id = c(
    "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast",
    "dlm_constV_p90_trainonly_followup_dev04_TTmain10000_fitforecast"
  ),
  source_root = c(
    "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources",
    file.path(repo_root, "results", "qdesn_mcmc_validation",
              "qdesn_dynamic_fitforecast_v2_500obs_trainonly_followup_v1", "source_replicates")
  ),
  stringsAsFactors = FALSE
)

prepare_one <- function(source_row) {
  d <- ffv2_load_defaults(base_path)
  d <- ffv2_c13_mcmc_defaults(
    d, run_tag = paste(run_tag_prefix, source_row$source_role, sep = "-"),
    candidate = candidate, workers = 2L, gate_rows = FALSE
  )
  d$study$scenario_id <- as.character(source_row$scenario_id)
  d$source$root <- as.character(source_row$source_root)
  d$source$families <- "normal"
  d$source$taus <- 0.05
  d$source$fit_sizes <- 500L
  d$models$model_variants <- c("dqlm", "exdqlm")
  d$models$inference_methods <- "mcmc"
  if (smoke_mode) {
    d$budget$stored_draws <- 20L
    d$budget$forecast_draws <- 20L
    d$budget$mcmc$n_burn <- 4L
    d$budget$mcmc$n_mcmc <- 4L
    d$budget$mcmc$thin <- 1L
    d$budget$mcmc$init_from_vb <- FALSE
    d$runtime$progress_every <- 1L
    d$runtime$trace_every <- 1L
    d$runtime$heartbeat_seconds <- 30L
  }
  d$smoke$rows <- list()
  d$pilot$rows <- list()
  registry <- ffv2_collect_source_registry(d, require_sources = TRUE)
  verification <- ffv2_verify_source_windows(registry, stop_on_fail = TRUE)
  if (nrow(registry) != 1L || any(verification$status != "PASS")) {
    stop(sprintf("Comparator source %s did not verify.", source_row$source_role), call. = FALSE)
  }
  manifest <- ffv2_prepare_manifest(
    defaults = d, registry = registry, dry_run = dry_run, overwrite = overwrite
  )
  keep <- manifest$family == "normal" & abs(as.numeric(manifest$tau) - 0.05) < 1e-12 &
    as.integer(manifest$fit_size) == 500L & manifest$model_variant %in% c("dqlm", "exdqlm") &
    manifest$inference == "mcmc"
  manifest <- manifest[keep, , drop = FALSE]
  if (nrow(manifest) != 2L) {
    stop(sprintf("Expected two comparator rows for %s; found %d.", source_row$source_role, nrow(manifest)), call. = FALSE)
  }
  for (i in seq_len(nrow(manifest))) {
    row <- as.list(manifest[i, , drop = FALSE])
    row <- ffv2_stamp_c13_mcmc_row(row, candidate)
    if (!dry_run) {
      cfg <- ffv2_read_json(row$row_config_path[[1L]])
      cfg <- ffv2_stamp_c13_mcmc_config(cfg, candidate)
      cfg$screen_stage <- "trainonly_followup_v1_matched_comparator"
      cfg$source_role <- as.character(source_row$source_role)
      ffv2_write_json(cfg, row$row_config_path[[1L]])
      row <- utils::modifyList(row, cfg[c(
        "candidate_id", "screen_stage", "calibration_id", "model_spec_hash", "spec_id"
      )], keep.null = TRUE)
    } else {
      row <- ffv2_sync_model_provenance(row)
      row$spec_id <- ffv2_make_spec_id(row, model_family = "exdqlm_dqlm")
    }
    for (nm in names(row)) {
      if (!nm %in% names(manifest)) manifest[[nm]] <- NA
      if (length(row[[nm]]) == 1L) manifest[[nm]][[i]] <- row[[nm]]
    }
  }
  manifest$source_role <- as.character(source_row$source_role)
  if (!dry_run) ffv2_write_csv(manifest, unique(manifest$row_manifest_path)[[1L]])
  manifest
}

manifests <- lapply(seq_len(nrow(source_rows)), function(i) prepare_one(source_rows[i, , drop = FALSE]))
index <- do.call(rbind, lapply(manifests, function(x) data.frame(
  source_role = x$source_role[[1L]], run_tag = x$run_tag[[1L]], run_root = x$run_root[[1L]],
  manifest_path = x$row_manifest_path[[1L]], expected_rows = nrow(x), stringsAsFactors = FALSE
)))
index_name <- if (dry_run) "comparator_dry_run_index.csv" else if (smoke_mode) "comparator_smoke_index.csv" else "comparator_index.csv"
index_path <- file.path(state_root, index_name)
ffv2_write_csv(index, index_path)
tsv_path <- sub("[.]csv$", ".tsv", index_path)
utils::write.table(index, tsv_path, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)
cat(sprintf("Comparator rows: %d\n", sum(index$expected_rows)))
cat(sprintf("Comparator index: %s\n", index_path))
print(index)
