#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_dynamic_tt5000_postfix_smoke_helpers_20260415.R")

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_dynamic_tt5000_postfix_smoke()
for (path in unname(paths[c("run_root", "config_dir", "rows_dir", "health_dir", "metrics_dir", "draws_dir", "logs_dir", "fits_dir")])) {
  ensure_dir_original288_dynamic_tt5000_exactspec_repair(path)
}

manifest <- read.csv(paths$source_manifest, stringsAsFactors = FALSE, check.names = FALSE)
manifest <- subset(
  manifest,
  phase == smoke_phase_original288_dynamic_tt5000_postfix_smoke() &
    base_row_id %in% representative_base_rows_original288_dynamic_tt5000_postfix_smoke() &
    seed_slot %in% representative_seed_slots_original288_dynamic_tt5000_postfix_smoke()
)
manifest <- manifest[order(manifest$base_row_id, manifest$seed_slot), , drop = FALSE]
rownames(manifest) <- NULL

if (!nrow(manifest)) {
  stop("post-fix smoke selection produced zero rows")
}

out_rows <- vector("list", nrow(manifest))
for (i in seq_len(nrow(manifest))) {
  row <- manifest[i, , drop = FALSE]
  cfg <- readRDS(row$run_config_path[1])

  new_row_id <- i
  new_fit_path <- candidate_fit_path_original288_dynamic_tt5000_postfix_smoke(
    run_root = paths$run_root,
    inference = row$inference[1],
    model = row$model[1],
    family = row$family[1],
    tau_label = row$tau_label[1],
    base_row_id = row$base_row_id[1],
    seed_slot = row$seed_slot[1]
  )
  new_config_path <- config_path_original288_dynamic_tt5000_postfix_smoke(new_row_id)
  new_row_status_path <- row_status_path_original288_dynamic_tt5000_postfix_smoke(new_row_id)
  new_health_path <- health_path_original288_dynamic_tt5000_postfix_smoke(new_row_id)
  new_metrics_path <- metrics_path_original288_dynamic_tt5000_postfix_smoke(new_row_id)
  new_draws_path <- draws_path_original288_dynamic_tt5000_postfix_smoke(new_row_id)

  cfg$fit_path <- new_fit_path
  cfg$config_path <- new_config_path
  cfg$row_status_path <- new_row_status_path
  cfg$health_path <- new_health_path
  cfg$metrics_path <- new_metrics_path
  cfg$draws_path <- new_draws_path
  cfg$smoke_context <- list(
    tag = run_tag_original288_dynamic_tt5000_postfix_smoke(),
    purpose = "post_fix_runtime_stability_check",
    source_manifest = paths$source_manifest,
    source_row_id = row$row_id[1]
  )

  if (identical(row$inference[1], "mcmc")) {
    mc_budget <- smoke_mcmc_budget_original288_dynamic_tt5000_postfix_smoke()
    cfg$mcmc$burn <- mc_budget$burn
    cfg$mcmc$n <- mc_budget$n
    cfg$mcmc$trace_every <- mc_budget$trace_every
    cfg$mcmc$progress_every <- mc_budget$progress_every
    if (is.null(cfg$mcmc$mh) || !is.list(cfg$mcmc$mh)) cfg$mcmc$mh <- list()
    cfg$mcmc$mh$trace_every <- mc_budget$trace_every
    cfg$mcmc$mh$progress_every <- mc_budget$progress_every
  } else {
    vb_budget <- smoke_vb_budget_original288_dynamic_tt5000_postfix_smoke()
    if (is.null(cfg$vb) || !is.list(cfg$vb)) cfg$vb <- list()
    cfg$vb$max_iter <- vb_budget$max_iter
    cfg$vb$n_samp <- vb_budget$n_samp
    cfg$vb$min_iter <- vb_budget$min_iter
    cfg$vb$patience <- vb_budget$patience
    cfg$vb$allow_elbo_drop <- vb_budget$allow_elbo_drop
    if (is.null(cfg$vb$ld) || !is.list(cfg$vb$ld)) cfg$vb$ld <- list()
    cfg$vb$ld$store_trace <- FALSE
  }

  saveRDS(cfg, new_config_path)

  row$row_id <- new_row_id
  row$phase <- smoke_phase_original288_dynamic_tt5000_postfix_smoke()
  row$run_root <- paths$run_root
  row$run_config_path <- new_config_path
  row$candidate_fit_path <- new_fit_path
  row$row_status_path <- new_row_status_path
  row$health_path <- new_health_path
  row$metrics_path <- new_metrics_path
  row$draws_path <- new_draws_path
  out_rows[[i]] <- row
}

smoke_manifest <- do.call(rbind, out_rows)
rownames(smoke_manifest) <- NULL
write.csv(smoke_manifest, paths$manifest, row.names = FALSE)

stage_counts <- aggregate(
  row_id ~ family + tau_label + model + inference,
  data = smoke_manifest,
  FUN = length
)
names(stage_counts)[names(stage_counts) == "row_id"] <- "rows"
write.csv(stage_counts, paths$stage_counts, row.names = FALSE)

cat(sprintf(
  "POSTFIX_SMOKE_PREP total_rows=%d unique_cases=%d source_manifest=%s\n",
  nrow(smoke_manifest),
  length(unique(smoke_manifest$base_row_id)),
  paths$source_manifest
))
