#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/verify_independent_metric_intervals_v1_plan.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
state_root <- normalizePath(args$`state-root` %||% "", winslash = "/", mustWork = TRUE)
plan <- ffv2_read_csv(file.path(state_root, "manifests", "job_plan.csv"))
materialization <- ffv2_read_json(file.path(state_root, "manifests", "materialization_manifest.json"))
smoke <- isTRUE(materialization$smoke)

config_hash_ok <- vapply(seq_len(nrow(plan)), function(i) {
  identical(ffv2_file_sha256(plan$config_path[[i]]), plan$config_sha256[[i]])
}, logical(1L))
configs <- lapply(plan$config_path, ffv2_read_json)
is_qdesn <- plan$engine == "qdesn"
q <- configs[is_qdesn]
d <- configs[!is_qdesn]

q_mcmc <- plan$engine == "qdesn" & plan$inference == "mcmc"
q_vb <- plan$engine == "qdesn" & plan$inference == "vb"
d_mcmc <- plan$engine == "dqlm" & plan$inference == "mcmc"
d_vb <- plan$engine == "dqlm" & plan$inference == "vb"
q_exal <- q_mcmc & plan$model_variant == "qdesn_exal_rhs_ns"

q_value <- function(indices, fun) {
  if (!length(indices)) return(logical(0))
  vapply(configs[indices], fun, logical(1L))
}
d_value <- q_value

reservoir_contract <- TRUE
for (replay_id in unique(plan$replay_id[is_qdesn])) {
  idx <- which(plan$replay_id == replay_id)
  seeds <- vapply(configs[idx], function(x) as.integer(x$config$desn$seed), integer(1L))
  reservoir_contract <- reservoir_contract && length(unique(seeds)) == 1L
}

checks <- c(
  expected_jobs = nrow(plan) == if (smoke) 4L else 198L,
  unique_job_ids = !anyDuplicated(plan$job_id),
  config_hashes = all(config_hash_ok),
  expected_wave_counts = if (smoke) TRUE else
    sum(plan$inference == "vb") == 36L && sum(d_mcmc) == 54L && sum(q_mcmc) == 108L,
  one_thread = all(c(
    q_value(which(is_qdesn), function(x) TRUE),
    d_value(which(!is_qdesn), function(x) identical(as.integer(x$runtime$threads), 1L))
  )),
  fixed_qdesn_reservoir_per_replay = reservoir_contract,
  unique_job_seeds = length(unique(vapply(configs, function(x) {
    if (identical(as.character(x$engine %||% ""), "qdesn")) {
      as.integer(x$root_spec$mcmc_rng_seed %||% x$root_spec$synthesis_seed)
    } else as.integer(x$seed)
  }, integer(1L)))) == nrow(plan),
  exal_m0 = all(q_value(which(q_exal), function(x) {
    identical(as.character(x$config$inference$mcmc$slice$core_update_mode),
              "m0_v_collapsed_support_logit")
  })),
  qdesn_mcmc_budget = smoke || all(q_value(which(q_mcmc), function(x) {
    identical(as.integer(x$config$inference$mcmc$n_burn), 5000L) &&
      identical(as.integer(x$config$inference$mcmc$n_mcmc), 20000L) &&
      identical(as.integer(x$config$metrics$posterior_metric_intervals$draws), 4000L)
  })),
  qdesn_vb_budget = smoke || all(q_value(which(q_vb), function(x) {
    as.integer(x$config$inference$vb$max_iter) >= 300L &&
      identical(as.integer(x$config$metrics$posterior_metric_intervals$draws), 10000L)
  })),
  dqlm_mcmc_budget = smoke || all(d_value(which(d_mcmc), function(x) {
    identical(as.integer(x$budget$mcmc$n_burn), 5000L) &&
      identical(as.integer(x$budget$mcmc$n_mcmc), 20000L) &&
      identical(as.integer(x$metric_intervals$draws), 4000L)
  })),
  dqlm_vb_budget = smoke || all(d_value(which(d_vb), function(x) {
    identical(as.integer(x$budget$vb$n_samp), 10000L) &&
      identical(as.integer(x$metric_intervals$draws), 10000L)
  })),
  dqlm_no_persistent_vb_handoff = all(d_value(which(!is_qdesn), function(x) {
    isFALSE(x$handoff$vb_init) && isFALSE(x$handoff$reuse_vb_init) &&
      isTRUE(x$handoff$prune_fit_on_success)
  })),
  intervals_required = all(c(
    q_value(which(is_qdesn), function(x) isTRUE(x$config$metrics$posterior_metric_intervals$required)),
    d_value(which(!is_qdesn), function(x) isTRUE(x$metric_intervals$required))
  )),
  no_legacy_home_paths = !any(grepl(
    paste0("/home/jaguir26", "/local/src"), unlist(configs), fixed = TRUE
  ))
)
out <- data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE)
path <- ffv2_write_csv(out, file.path(state_root, "manifests", "plan_verification.csv"))
ffv2_write_json(list(
  schema_version = imi_v1_schema, status = if (all(checks)) "PASS" else "FAIL",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), smoke = smoke,
  jobs = nrow(plan), checks_pass = sum(checks), checks_total = length(checks),
  verification_path = path, verification_sha256 = ffv2_file_sha256(path)
), file.path(state_root, "manifests", "plan_verification.json"))
cat(sprintf("plan verification: %d/%d checks pass; jobs=%d smoke=%s\n",
            sum(checks), length(checks), nrow(plan), smoke))
if (!all(checks)) {
  print(out[!out$pass, , drop = FALSE], row.names = FALSE)
  quit(save = "no", status = 1L)
}
