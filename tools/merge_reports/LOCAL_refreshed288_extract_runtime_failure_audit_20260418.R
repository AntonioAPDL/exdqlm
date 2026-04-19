#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressWarnings({
  suppressPackageStartupMessages({
    library(utils)
  })
})

run_root <- "tools/merge_reports/full288_refreshed288_paperaligned_20260417_canonical_v1"
manifest_path <- "tools/merge_reports/LOCAL_refreshed288_full_manifest_20260417_canonical_v1.csv"
method_registry_path <- "tools/merge_reports/LOCAL_refreshed288_method_registry_20260417_canonical_v1.csv"
out_dir <- "tools/merge_reports"
report_dir <- "reports/static_exal_tuning_20260418"

snapshot_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

status_files <- Sys.glob(file.path(run_root, "rows", "row_*_status.csv"))
if (!length(status_files)) {
  stop(sprintf("No row status files found under %s", run_root), call. = FALSE)
}

manifest <- read.csv(manifest_path, check.names = FALSE)
method_registry <- read.csv(method_registry_path, check.names = FALSE)
row_status <- do.call(rbind, lapply(status_files, read.csv, check.names = FALSE))

row_status$row_id <- as.integer(row_status$row_id)

runtime_mode_from_error <- function(msg) {
  if (is.na(msg) || !nzchar(msg)) return(NA_character_)
  if (grepl("ldvb_q_t1 is NA", msg, fixed = TRUE)) return("ldvb_q_t1_na")
  if (grepl("invalid state before chi update", msg, fixed = TRUE)) return("invalid_pre_chi")
  if (grepl("chi has", msg, fixed = TRUE)) return("nonfinite_chi")
  "other"
}

read_vb_init_audit <- function(path) {
  empty <- list(
    vb_init_exists = "missing",
    vb_init_fit_class = NA_character_,
    vb_init_iter = NA_integer_,
    vb_init_converged = NA,
    vb_init_theta_finite = NA,
    vb_init_post_pred_finite = NA,
    vb_init_sfe_finite = NA,
    vb_init_sigma_min = NA_real_,
    vb_init_sigma_max = NA_real_,
    vb_init_gamma_min = NA_real_,
    vb_init_gamma_max = NA_real_
  )

  if (is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(empty)
  }

  obj <- tryCatch(readRDS(path), error = function(e) e)
  if (inherits(obj, "error")) {
    empty$vb_init_exists <- "unreadable"
    return(empty)
  }

  fit <- if (is.list(obj) && "fit" %in% names(obj)) obj$fit else obj
  sigma_name <- intersect("samp.sigma", names(fit))
  gamma_name <- intersect("samp.gamma", names(fit))
  theta_name <- intersect("samp.theta", names(fit))
  post_name <- intersect("samp.post.pred", names(fit))
  sfe_name <- intersect("map.standard.forecast.errors", names(fit))

  list(
    vb_init_exists = "exists",
    vb_init_fit_class = paste(class(fit), collapse = "|"),
    vb_init_iter = if (!is.null(fit$iter)) as.integer(fit$iter[[1]]) else NA_integer_,
    vb_init_converged = if (!is.null(fit$converged)) isTRUE(fit$converged[[1]]) else NA,
    vb_init_theta_finite = if (length(theta_name)) all(is.finite(fit[[theta_name]])) else NA,
    vb_init_post_pred_finite = if (length(post_name)) all(is.finite(fit[[post_name]])) else NA,
    vb_init_sfe_finite = if (length(sfe_name)) all(is.finite(fit[[sfe_name]])) else NA,
    vb_init_sigma_min = if (length(sigma_name)) suppressWarnings(min(fit[[sigma_name]], na.rm = TRUE)) else NA_real_,
    vb_init_sigma_max = if (length(sigma_name)) suppressWarnings(max(fit[[sigma_name]], na.rm = TRUE)) else NA_real_,
    vb_init_gamma_min = if (length(gamma_name)) suppressWarnings(min(fit[[gamma_name]], na.rm = TRUE)) else NA_real_,
    vb_init_gamma_max = if (length(gamma_name)) suppressWarnings(max(fit[[gamma_name]], na.rm = TRUE)) else NA_real_
  )
}

attach_method_profile <- function(df) {
  cols <- c(
    "method_profile_id",
    "vb_max_iter",
    "vb_min_iter",
    "vb_tol",
    "vb_n_samp_internal",
    "sigmagam_vb_warmup_iters",
    "sigmagam_vb_min_postwarmup_updates",
    "vb_init_max_iter",
    "vb_init_min_iter",
    "vb_init_tol",
    "vb_init_n_samp",
    "vb_init_sigmagam_warmup_iters",
    "vb_init_sigmagam_min_postwarmup_updates",
    "n_burn",
    "n_mcmc",
    "sigmagam_mcmc_warmup_iters",
    "mh_proposal",
    "slice_width",
    "slice_max_steps"
  )
  out <- merge(df, method_registry[, cols], by = "method_profile_id", all.x = TRUE, sort = FALSE)
  names(out)[match(cols[-1], names(out))] <- paste0("current_", cols[-1])
  out
}

runtime_fail <- row_status[row_status$status == "failed_runtime", ]
runtime_fail$runtime_mode <- vapply(runtime_fail$error, runtime_mode_from_error, character(1))
runtime_fail$recommended_rerun_lane <- ifelse(
  identical(runtime_fail$inference, "vb") | runtime_fail$inference == "vb",
  "dynamic_vb_runtime_rerun",
  ifelse(runtime_fail$model == "exdqlm", "dynamic_mcmc_exdqlm_runtime_rerun", "dynamic_mcmc_dqlm_runtime_rerun")
)
runtime_fail$recommended_secondary_arm <- ifelse(
  runtime_fail$inference == "mcmc" & runtime_fail$model == "exdqlm",
  "secondary_exdqlm_slice_width_sensitivity",
  NA_character_
)
runtime_fail$snapshot_time <- snapshot_time

runtime_fail <- attach_method_profile(runtime_fail)
runtime_audit <- lapply(runtime_fail$vb_init_fit_path, read_vb_init_audit)
runtime_audit_df <- as.data.frame(do.call(rbind, lapply(runtime_audit, as.data.frame)), stringsAsFactors = FALSE)
runtime_fail <- cbind(runtime_fail, runtime_audit_df)
runtime_fail <- runtime_fail[order(runtime_fail$row_id), ]

active_watchlist <- row_status[
  row_status$status == "running" &
    row_status$block == "dynamic" &
    row_status$inference == "mcmc",
]
if (nrow(active_watchlist)) {
  active_watchlist$runtime_mode <- NA_character_
  active_watchlist$recommended_rerun_lane <- "watch_only_until_row_finishes"
  active_watchlist$recommended_secondary_arm <- NA_character_
  active_watchlist$snapshot_time <- snapshot_time
  active_watchlist <- attach_method_profile(active_watchlist)
  watch_audit <- lapply(active_watchlist$vb_init_fit_path, read_vb_init_audit)
  watch_audit_df <- as.data.frame(do.call(rbind, lapply(watch_audit, as.data.frame)), stringsAsFactors = FALSE)
  active_watchlist <- cbind(active_watchlist, watch_audit_df)
  active_watchlist <- active_watchlist[order(active_watchlist$row_id), ]
} else {
  active_watchlist <- runtime_fail[0, , drop = FALSE]
}

runtime_summary <- rbind(
  data.frame(
    snapshot_time = snapshot_time,
    summary_group = "runtime_fail_by_mode",
    key = names(table(runtime_fail$runtime_mode)),
    value = as.integer(table(runtime_fail$runtime_mode)),
    stringsAsFactors = FALSE
  ),
  data.frame(
    snapshot_time = snapshot_time,
    summary_group = "runtime_fail_by_phase",
    key = names(table(runtime_fail$phase)),
    value = as.integer(table(runtime_fail$phase)),
    stringsAsFactors = FALSE
  ),
  data.frame(
    snapshot_time = snapshot_time,
    summary_group = "runtime_fail_by_status",
    key = names(table(row_status$status)),
    value = as.integer(table(row_status$status)),
    stringsAsFactors = FALSE
  )
)

current_dynamic_profiles <- method_registry[
  method_registry$block == "dynamic" &
    method_registry$method_profile_id %in% c(
      "dynamic__dqlm__mcmc",
      "dynamic__exdqlm__mcmc",
      "dynamic__exdqlm__vb"
    ),
]

contract_rows <- list(
  list(
    rerun_arm = "primary_dynamic_vb_runtime_rerun",
    method_profile_id = "dynamic__exdqlm__vb",
    launch_priority = 1L,
    target_failure_mode = "ldvb_q_t1_na",
    target_rows = "11",
    change_focus = "Stronger direct LDVB stabilization before considering any sampler changes",
    proposed_vb_max_iter = 800L,
    proposed_vb_min_iter = 80L,
    proposed_vb_tol = 0.01,
    proposed_vb_n_samp_internal = 20000L,
    proposed_sigmagam_vb_warmup_iters = 50L,
    proposed_sigmagam_vb_min_postwarmup_updates = 5L,
    proposed_sigmagam_vb_postwarmup_damping = 0.50,
    proposed_sigmagam_vb_postwarmup_damping_iters = 5L,
    proposed_vb_init_max_iter = NA_integer_,
    proposed_vb_init_min_iter = NA_integer_,
    proposed_vb_init_tol = NA_real_,
    proposed_vb_init_n_samp = NA_integer_,
    proposed_vb_init_sigmagam_warmup_iters = NA_integer_,
    proposed_vb_init_sigmagam_min_postwarmup_updates = NA_integer_,
    proposed_vb_init_sigmagam_postwarmup_damping = NA_real_,
    proposed_vb_init_sigmagam_postwarmup_damping_iters = NA_integer_,
    proposed_sigmagam_mcmc_warmup_iters = NA_integer_,
    proposed_slice_width = NA_real_,
    proposed_slice_max_steps = NA_real_,
    proposed_pre_mcmc_vb_validation_gate = FALSE,
    notes = "Keep sampler settings out of this lane; this row failed before any MCMC step existed."
  ),
  list(
    rerun_arm = "primary_dynamic_mcmc_runtime_rerun",
    method_profile_id = "dynamic__dqlm__mcmc",
    launch_priority = 2L,
    target_failure_mode = "invalid_pre_chi",
    target_rows = paste(runtime_fail$row_id[runtime_fail$model == "dqlm" & runtime_fail$inference == "mcmc"], collapse = ","),
    change_focus = "Strengthen VB init and early sigmagam warmup before the first U/st + chi path",
    proposed_vb_max_iter = NA_integer_,
    proposed_vb_min_iter = NA_integer_,
    proposed_vb_tol = NA_real_,
    proposed_vb_n_samp_internal = NA_integer_,
    proposed_sigmagam_vb_warmup_iters = NA_integer_,
    proposed_sigmagam_vb_min_postwarmup_updates = NA_integer_,
    proposed_sigmagam_vb_postwarmup_damping = NA_real_,
    proposed_sigmagam_vb_postwarmup_damping_iters = NA_integer_,
    proposed_vb_init_max_iter = 800L,
    proposed_vb_init_min_iter = 80L,
    proposed_vb_init_tol = 0.01,
    proposed_vb_init_n_samp = 5000L,
    proposed_vb_init_sigmagam_warmup_iters = 50L,
    proposed_vb_init_sigmagam_min_postwarmup_updates = 5L,
    proposed_vb_init_sigmagam_postwarmup_damping = 0.50,
    proposed_vb_init_sigmagam_postwarmup_damping_iters = 5L,
    proposed_sigmagam_mcmc_warmup_iters = 500L,
    proposed_slice_width = 0.10,
    proposed_slice_max_steps = Inf,
    proposed_pre_mcmc_vb_validation_gate = TRUE,
    notes = "Primary arm keeps slice width unchanged because the crash occurs before the slice gamma step."
  ),
  list(
    rerun_arm = "primary_dynamic_mcmc_runtime_rerun",
    method_profile_id = "dynamic__exdqlm__mcmc",
    launch_priority = 2L,
    target_failure_mode = "nonfinite_chi|ldvb_q_t1_na",
    target_rows = paste(runtime_fail$row_id[runtime_fail$model == "exdqlm" & runtime_fail$inference == "mcmc"], collapse = ","),
    change_focus = "Strengthen VB init quality and require a clean finite init before entering MCMC",
    proposed_vb_max_iter = NA_integer_,
    proposed_vb_min_iter = NA_integer_,
    proposed_vb_tol = NA_real_,
    proposed_vb_n_samp_internal = NA_integer_,
    proposed_sigmagam_vb_warmup_iters = NA_integer_,
    proposed_sigmagam_vb_min_postwarmup_updates = NA_integer_,
    proposed_sigmagam_vb_postwarmup_damping = NA_real_,
    proposed_sigmagam_vb_postwarmup_damping_iters = NA_integer_,
    proposed_vb_init_max_iter = 800L,
    proposed_vb_init_min_iter = 80L,
    proposed_vb_init_tol = 0.01,
    proposed_vb_init_n_samp = 5000L,
    proposed_vb_init_sigmagam_warmup_iters = 50L,
    proposed_vb_init_sigmagam_min_postwarmup_updates = 5L,
    proposed_vb_init_sigmagam_postwarmup_damping = 0.50,
    proposed_vb_init_sigmagam_postwarmup_damping_iters = 5L,
    proposed_sigmagam_mcmc_warmup_iters = 500L,
    proposed_slice_width = 0.10,
    proposed_slice_max_steps = Inf,
    proposed_pre_mcmc_vb_validation_gate = TRUE,
    notes = "Primary arm keeps slice width unchanged; the first goal is to stop non-finite chi from a bad init."
  ),
  list(
    rerun_arm = "secondary_slice_sensitivity",
    method_profile_id = "dynamic__exdqlm__mcmc",
    launch_priority = 3L,
    target_failure_mode = "nonfinite_chi",
    target_rows = paste(runtime_fail$row_id[runtime_fail$model == "exdqlm" & runtime_fail$inference == "mcmc"], collapse = ","),
    change_focus = "Only use if the stronger-init primary arm still fails with non-finite chi.",
    proposed_vb_max_iter = NA_integer_,
    proposed_vb_min_iter = NA_integer_,
    proposed_vb_tol = NA_real_,
    proposed_vb_n_samp_internal = NA_integer_,
    proposed_sigmagam_vb_warmup_iters = NA_integer_,
    proposed_sigmagam_vb_min_postwarmup_updates = NA_integer_,
    proposed_sigmagam_vb_postwarmup_damping = NA_real_,
    proposed_sigmagam_vb_postwarmup_damping_iters = NA_integer_,
    proposed_vb_init_max_iter = 800L,
    proposed_vb_init_min_iter = 80L,
    proposed_vb_init_tol = 0.01,
    proposed_vb_init_n_samp = 5000L,
    proposed_vb_init_sigmagam_warmup_iters = 50L,
    proposed_vb_init_sigmagam_min_postwarmup_updates = 5L,
    proposed_vb_init_sigmagam_postwarmup_damping = 0.50,
    proposed_vb_init_sigmagam_postwarmup_damping_iters = 5L,
    proposed_sigmagam_mcmc_warmup_iters = 500L,
    proposed_slice_width = 0.05,
    proposed_slice_max_steps = Inf,
    proposed_pre_mcmc_vb_validation_gate = TRUE,
    notes = "Secondary sensitivity arm for exdqlm only. Do not make this the first rerun lever."
  )
)

rerun_contract <- as.data.frame(do.call(rbind, lapply(contract_rows, as.data.frame)), stringsAsFactors = FALSE)
rerun_contract <- merge(
  rerun_contract,
  current_dynamic_profiles[, c(
    "method_profile_id",
    "vb_max_iter",
    "vb_min_iter",
    "vb_tol",
    "vb_n_samp_internal",
    "sigmagam_vb_warmup_iters",
    "sigmagam_vb_min_postwarmup_updates",
    "vb_init_max_iter",
    "vb_init_min_iter",
    "vb_init_tol",
    "vb_init_n_samp",
    "vb_init_sigmagam_warmup_iters",
    "vb_init_sigmagam_min_postwarmup_updates",
    "n_burn",
    "n_mcmc",
    "sigmagam_mcmc_warmup_iters",
    "mh_proposal",
    "slice_width",
    "slice_max_steps"
  )],
  by = "method_profile_id",
  all.x = TRUE,
  sort = FALSE
)
names(rerun_contract)[match(
  c(
    "vb_max_iter",
    "vb_min_iter",
    "vb_tol",
    "vb_n_samp_internal",
    "sigmagam_vb_warmup_iters",
    "sigmagam_vb_min_postwarmup_updates",
    "vb_init_max_iter",
    "vb_init_min_iter",
    "vb_init_tol",
    "vb_init_n_samp",
    "vb_init_sigmagam_warmup_iters",
    "vb_init_sigmagam_min_postwarmup_updates",
    "n_burn",
    "n_mcmc",
    "sigmagam_mcmc_warmup_iters",
    "mh_proposal",
    "slice_width",
    "slice_max_steps"
  ),
  names(rerun_contract)
)] <- paste0(
  "current_",
  c(
    "vb_max_iter",
    "vb_min_iter",
    "vb_tol",
    "vb_n_samp_internal",
    "sigmagam_vb_warmup_iters",
    "sigmagam_vb_min_postwarmup_updates",
    "vb_init_max_iter",
    "vb_init_min_iter",
    "vb_init_tol",
    "vb_init_n_samp",
    "vb_init_sigmagam_warmup_iters",
    "vb_init_sigmagam_min_postwarmup_updates",
    "n_burn",
    "n_mcmc",
    "sigmagam_mcmc_warmup_iters",
    "mh_proposal",
    "slice_width",
    "slice_max_steps"
  )
)
rerun_contract$snapshot_time <- snapshot_time

runtime_manifest_path <- file.path(out_dir, "LOCAL_refreshed288_runtime_failure_manifest_20260418.csv")
runtime_watchlist_path <- file.path(out_dir, "LOCAL_refreshed288_runtime_failure_watchlist_20260418.csv")
runtime_summary_path <- file.path(out_dir, "LOCAL_refreshed288_runtime_failure_summary_20260418.csv")
rerun_contract_path <- file.path(out_dir, "LOCAL_refreshed288_runtime_failure_rerun_contract_20260418.csv")

write.csv(runtime_fail, runtime_manifest_path, row.names = FALSE, na = "")
write.csv(active_watchlist, runtime_watchlist_path, row.names = FALSE, na = "")
write.csv(runtime_summary, runtime_summary_path, row.names = FALSE, na = "")
write.csv(rerun_contract, rerun_contract_path, row.names = FALSE, na = "")

cat(sprintf("snapshot_time=%s\n", snapshot_time))
cat(sprintf("runtime_fail_rows=%d\n", nrow(runtime_fail)))
cat(sprintf("active_watchlist_rows=%d\n", nrow(active_watchlist)))
cat(sprintf("wrote=%s\n", runtime_manifest_path))
cat(sprintf("wrote=%s\n", runtime_watchlist_path))
cat(sprintf("wrote=%s\n", runtime_summary_path))
cat(sprintf("wrote=%s\n", rerun_contract_path))
