#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

flag_value <- function(name) {
  any(args %in% paste0("--", name))
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", "20260430_p90_dynamic72_qdesn_comparable_v3_repair")
variant_tag <- arg_value("variant-tag", "p90_dynamic72_qdesn_comparable_v3_repair")
overlay_profile <- arg_value("overlay-profile", "slice_warmup_v1")
report_dir <- file.path(repo_root, "reports/static_exal_tuning_20260430")
dry_run <- flag_value("dry-run")

overlay <- switch(
  overlay_profile,
  slice_warmup_v1 = list(
    repair_overlay_id = "dynamic_exdqlm_mcmc_tt500_sigmagam_slice_repair_v1",
    repair_overlay_reason = paste(
      "v2 source-index smoke completed without runtime crashes, but",
      "exDQLM MCMC TT500 rows failed sigma/gamma sampler-health gates."
    ),
    n_burn = 10000L,
    n_mcmc = 20000L,
    mh_proposal = "slice",
    joint_sample = FALSE,
    slice_width = 0.25,
    slice_max_steps = Inf,
    mh_laplace_refresh_interval = NULL,
    mh_laplace_refresh_start = NULL,
    mh_laplace_refresh_weight = NULL,
    sigmagam_controls = list(
      freeze_burnin_iters = 500L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      delay_adapt_until_after_warmup = TRUE,
      delay_laplace_refresh_until_after_warmup = TRUE
    ),
    theta_state_controls = list(
      freeze_burnin_iters = 500L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE
    ),
    latent_state_controls = list(
      mode = "u_st_pair",
      freeze_burnin_iters = 500L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      min_postwarmup_updates = 0L
    )
  ),
  laplace_rw_refresh_v2 = list(
    repair_overlay_id = "dynamic_exdqlm_mcmc_tt500_laplace_rw_refresh_repair_v2",
    repair_overlay_reason = paste(
      "The first v3 slice/warmup repair completed without runtime crashes but",
      "still failed exDQLM TT500 sigma/gamma ESS gates; switch to the",
      "historical Laplace-refresh random-walk sigma/gamma corridor."
    ),
    n_burn = 10000L,
    n_mcmc = 20000L,
    mh_proposal = "laplace_rw",
    joint_sample = TRUE,
    slice_width = 0.25,
    slice_max_steps = Inf,
    mh_laplace_refresh_interval = 10L,
    mh_laplace_refresh_start = 50L,
    mh_laplace_refresh_weight = 0.9,
    sigmagam_controls = list(
      freeze_burnin_iters = 250L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      delay_adapt_until_after_warmup = TRUE,
      delay_laplace_refresh_until_after_warmup = TRUE
    ),
    theta_state_controls = list(
      freeze_burnin_iters = 250L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE
    ),
    latent_state_controls = list(
      mode = "u_st_pair",
      freeze_burnin_iters = 250L,
      freeze_only_during_burn = TRUE,
      force_after_warmup = TRUE,
      min_postwarmup_updates = 0L
    )
  ),
  stop("Unknown overlay-profile: ", overlay_profile, call. = FALSE)
)
overlay_id <- overlay$repair_overlay_id

manifest_path <- function(kind) {
  file.path(repo_root, sprintf("tools/merge_reports/LOCAL_refreshed288_%s_manifest_%s.csv", kind, run_tag))
}

read_manifest <- function(kind) {
  path <- manifest_path(kind)
  if (!file.exists(path)) {
    stop("Missing manifest for overlay: ", path, call. = FALSE)
  }
  read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

apply_to_cfg <- function(cfg) {
  cfg$repair_overlay_id <- overlay$repair_overlay_id
  cfg$repair_overlay_reason <- overlay$repair_overlay_reason
  cfg$n_burn <- overlay$n_burn
  cfg$n_mcmc <- overlay$n_mcmc
  cfg$mh_proposal <- overlay$mh_proposal
  cfg$joint_sample <- overlay$joint_sample
  cfg$slice_width <- overlay$slice_width
  cfg$slice_max_steps <- overlay$slice_max_steps
  cfg$mh_laplace_refresh_interval <- overlay$mh_laplace_refresh_interval
  cfg$mh_laplace_refresh_start <- overlay$mh_laplace_refresh_start
  cfg$mh_laplace_refresh_weight <- overlay$mh_laplace_refresh_weight
  cfg$sigmagam_controls <- overlay$sigmagam_controls
  cfg$theta_state_controls <- overlay$theta_state_controls
  cfg$latent_state_controls <- overlay$latent_state_controls
  cfg
}

apply_manifest <- function(kind) {
  manifest <- read_manifest(kind)
  target <- manifest$block == "dynamic" &
    manifest$model == "exdqlm" &
    manifest$inference == "mcmc" &
    suppressWarnings(as.integer(manifest$fit_size)) == 500L

  rows <- manifest[target, , drop = FALSE]
  if (!nrow(rows)) {
    return(data.frame())
  }

  out <- lapply(seq_len(nrow(rows)), function(i) {
    row <- rows[i, , drop = FALSE]
    if (!file.exists(row$config_path)) {
      stop("Missing row config: ", row$config_path, call. = FALSE)
    }
    cfg <- readRDS(row$config_path)
    before <- list(
      n_burn = cfg$n_burn,
      n_mcmc = cfg$n_mcmc,
      slice_width = cfg$slice_width,
      slice_max_steps = cfg$slice_max_steps,
      repair_overlay_id = cfg$repair_overlay_id %||% NA_character_
    )
    cfg <- apply_to_cfg(cfg)
    cfg$variant_tag <- variant_tag
    if (!dry_run) saveRDS(cfg, row$config_path)

    data.frame(
      manifest_kind = kind,
      row_id = row$row_id,
      original_case_key = row$original_case_key,
      family = row$family,
      tau_label = row$tau_label,
      fit_size = row$fit_size,
      model = row$model,
      inference = row$inference,
      config_path = row$config_path,
      before_n_burn = before$n_burn %||% NA_integer_,
      after_n_burn = overlay$n_burn,
      before_n_mcmc = before$n_mcmc %||% NA_integer_,
      after_n_mcmc = overlay$n_mcmc,
      before_slice_width = before$slice_width %||% NA_real_,
      after_slice_width = overlay$slice_width,
      after_slice_max_steps = "Inf",
      after_mh_proposal = overlay$mh_proposal,
      after_joint_sample = overlay$joint_sample,
      laplace_refresh_interval = overlay$mh_laplace_refresh_interval %||% NA_integer_,
      laplace_refresh_start = overlay$mh_laplace_refresh_start %||% NA_integer_,
      laplace_refresh_weight = overlay$mh_laplace_refresh_weight %||% NA_real_,
      sigmagam_freeze_burnin_iters = overlay$sigmagam_controls$freeze_burnin_iters,
      theta_freeze_burnin_iters = overlay$theta_state_controls$freeze_burnin_iters,
      latent_freeze_burnin_iters = overlay$latent_state_controls$freeze_burnin_iters,
      latent_mode = overlay$latent_state_controls$mode,
      overlay_id = overlay_id,
      dry_run = dry_run,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, out)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
summary <- rbind(apply_manifest("smoke"), apply_manifest("full"))

out_csv <- file.path(report_dir, sprintf("refreshed288_dynamic72_repair_overlay_%s.csv", run_tag))
out_md <- file.path(report_dir, sprintf("refreshed288_dynamic72_repair_overlay_%s.md", run_tag))
utils::write.csv(summary, out_csv, row.names = FALSE)

smoke_n <- sum(summary$manifest_kind == "smoke")
full_n <- sum(summary$manifest_kind == "full")

md <- c(
  "# Dynamic 72 Repair Overlay",
  "",
  sprintf("- Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Variant tag: `%s`", variant_tag),
  sprintf("- Overlay id: `%s`", overlay_id),
  sprintf("- Overlay profile: `%s`", overlay_profile),
  sprintf("- Dry run: `%s`", dry_run),
  "",
  "## Why This Overlay Exists",
  "",
  "The v2 source-index smoke completed all dynamic rows without runtime crashes or manual stops. However, the three `TT500` exDQLM MCMC smoke rows failed sigma/gamma sampler-health gates with very low ESS per 1k and high autocorrelation. The v3 repair keeps the corrected Q-DESN-comparable tail-window contract and applies a localized repair only to `dynamic + exdqlm + mcmc + TT500` rows.",
  "",
  "## Repair Contract",
  "",
  "| Setting | Value |",
  "| --- | --- |",
  "| Target rows | `dynamic exdqlm mcmc TT500` |",
  "| MCMC burn-in | `10000` |",
  "| MCMC retained draws | `20000` |",
  sprintf("| MH proposal | `%s` |", overlay$mh_proposal),
  sprintf("| Joint sigma/gamma sample | `%s` |", overlay$joint_sample),
  sprintf("| Slice width | `%s` |", overlay$slice_width),
  "| Slice max steps | `Inf` |",
  sprintf("| Laplace refresh interval | `%s` |", overlay$mh_laplace_refresh_interval %||% "not_applicable"),
  sprintf("| Laplace refresh start | `%s` |", overlay$mh_laplace_refresh_start %||% "not_applicable"),
  sprintf("| Laplace refresh weight | `%s` |", overlay$mh_laplace_refresh_weight %||% "not_applicable"),
  sprintf("| sigmagam freeze burn-in | `%s` |", overlay$sigmagam_controls$freeze_burnin_iters),
  sprintf("| theta freeze burn-in | `%s` |", overlay$theta_state_controls$freeze_burnin_iters),
  sprintf("| latent freeze burn-in | `%s` |", overlay$latent_state_controls$freeze_burnin_iters),
  "| latent freeze mode | `u_st_pair` |",
  "| OMP/OpenBLAS/MKL threads | `1` per worker via launcher |",
  "",
  "## Applied Rows",
  "",
  "| Manifest | Rows |",
  "| --- | ---: |",
  sprintf("| smoke | %d |", smoke_n),
  sprintf("| full | %d |", full_n),
  "",
  "CSV detail:",
  "",
  sprintf("`%s`", out_csv),
  ""
)
writeLines(md, out_md)

cat(sprintf("overlay_id=%s\n", overlay_id))
cat(sprintf("overlay_profile=%s\n", overlay_profile))
cat(sprintf("run_tag=%s\n", run_tag))
cat(sprintf("smoke_rows=%d\n", smoke_n))
cat(sprintf("full_rows=%d\n", full_n))
cat(sprintf("dry_run=%s\n", dry_run))
cat(sprintf("csv=%s\n", out_csv))
cat(sprintf("md=%s\n", out_md))
