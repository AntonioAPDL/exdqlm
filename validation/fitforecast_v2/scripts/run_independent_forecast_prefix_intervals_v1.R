#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE, digits = 17)
Sys.setenv(OMP_NUM_THREADS = 1, OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1, BLIS_NUM_THREADS = 1)
script <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
repo <- normalizePath(file.path(dirname(script), "../../.."))
source(file.path(repo, "validation/fitforecast_v2/R/forecast_prefix_metric_intervals_v1.R"))
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) fpf_stop(paste("Value required:", flag))
  args[i + 1L]
}
mode <- arg("--mode", "audit-rescore")
out <- arg("--output")
fpf_assert(!is.null(out), "--output is required.")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
out <- normalizePath(out)
if (mode == "forecast-pool") {
  tasks <- fpf_read(arg("--registry"))
  capsules <- fpf_read(arg("--capsule-registry"))
  results <- fpf_run_pool(tasks, capsules, out, as.integer(arg("--workers", "1")))
  print(table(results$status))
  quit(status = if (all(results$status %in% c("VERIFIED", "VERIFIED_REUSED"))) 0L else 1L)
}
if (mode == "forecast-only") {
  registry <- fpf_read(arg("--registry"))
  task <- registry[registry$task_id == arg("--task-id"), ]
  fpf_assert(nrow(task) == 1L, "Expected one registered task.")
  fpf_assert(!file.exists(file.path(out, "task_status.json")), "Output task already exists; verify it instead of overwriting.")
  lock <- file.path(out, "task.lock")
  fpf_assert(dir.create(lock, showWarnings = FALSE), "Task is already locked.")
  tryCatch(fpf_run_task(task, arg("--capsule"), arg("--capsule-sha256"), out),
    finally = unlink(lock, recursive = TRUE))
  cat("FORECAST_ONLY_VERIFIED fit_calls=0\n")
  quit(status = 0L)
}
fpf_assert(mode == "audit-rescore", "Unknown mode.")
review <- normalizePath(arg("--review-root"), mustWork = TRUE)
bundle <- normalizePath(arg("--bundle-root"), mustWork = TRUE)
input_manifest <- fpf_read(file.path(review, "input_hash_manifest.csv"))
fpf_assert(all(file.exists(input_manifest$path)) &&
  all(vapply(input_manifest$path, fpf_sha, character(1)) == input_manifest$sha256), "Frozen review input hashes changed.")
map <- fpf_read(file.path(review, "selected_source_map.csv"))
article <- fpf_read(file.path(review, "article_inputs/qdesn_validation_500obs_dgp_oracle_figure_data_v14.csv"))
roles <- article[article$inference == "mcmc" & article$metric_role %in% c("forecast_mae", "forecast_check"), ]
registry <- fpf_registry(map, roles)
fpf_assert(nrow(registry) == 132L && nrow(roles) == 72L, "Article analysis surface changed.")
fpf_write(registry, file.path(out, "task_registry.csv"))
fpf_write(roles, file.path(out, "display_role_registry.csv"))
inventory <- fpf_audit_recovery(registry, bundle, out)
archives <- list.files(dirname(bundle), pattern = "[.](tar[.]gz|tgz)$", full.names = TRUE)
archive_rows <- lapply(archives, function(p) {
  members <- system2("tar", c("-tzf", shQuote(p)), stdout = TRUE)
  fpf_assert(is.null(attr(members, "status")), "Archive index could not be read.")
  hits <- grep("(forecast_objects|rhs_trace|posterior|fit_object|forecast_location_draw).*(rds|ffv2handoff|csv.gz)$",
    members, value = TRUE, ignore.case = TRUE)
  data.frame(path = normalizePath(p), sha256 = fpf_sha(p), bytes = file.info(p)$size,
    member_count = length(members), candidate_member_count = length(hits), candidate_members = paste(hits, collapse = "|"))
})
if (length(archive_rows)) fpf_write(do.call(rbind, archive_rows), file.path(out, "archive_member_audit.csv"))
evidence <- list()
full_draws <- list()
recovered <- list()
for (i in seq_len(nrow(registry))) {
  r <- registry[i, ]
  ref <- fpf_read(r$metric_draws_path)
  fpf_assert(fpf_sha(r$metric_draws_path) == r$full_metric_draws_sha256 && nrow(ref) == r$n_draws,
    "Changed reference evidence.")
  ref$replay_id <- r$replay_id
  ref$cutoff <- 1000L
  ref$n_pairs <- 1000L
  ref$n_origins <- 34L
  ref$last_target <- 10000L
  full_draws[[i]] <- ref[c("chain_id", "draw_id", "source_draw_index", "forecast_mae",
    "forecast_check_loss", "replay_id", "cutoff", "n_pairs", "n_origins", "last_target")]
  group <- inventory$group_draws_path[match(r$task_id, inventory$task_id)]
  if (nzchar(group)) {
    result <- tryCatch({
      scores <- fpf_score_origin_groups(fpf_read(group), ref)
      error <- fpf_verify_full(scores, ref)
      scores$replay_id <- r$replay_id
      path <- file.path(out, "evidence", r$task_id, "recovered_origin_prefix_draws.csv.gz")
      fpf_write(scores, path)
      recovered[[length(recovered) + 1L]] <- scores
      data.frame(task_id = r$task_id, status = "VERIFIED_ORIGIN_PREFIX_RECOVERY",
        cutoffs = paste(sort(unique(scores$cutoff)), collapse = "|"), max_draw_error = error,
        input_path = group, input_sha256 = fpf_sha(group), output_path = normalizePath(path),
        output_sha256 = fpf_sha(path), message = "draw_id aligned; parent coefficient index namespace retained")
    }, error = function(e) data.frame(task_id = r$task_id, status = "GROUP_RECOVERY_REVIEW_REQUIRED",
      cutoffs = "", max_draw_error = NA_real_, input_path = group, input_sha256 = fpf_sha(group),
      output_path = "", output_sha256 = "", message = conditionMessage(e)))
    evidence[[length(evidence) + 1L]] <- result
  }
}
if (length(evidence)) fpf_write(do.call(rbind, evidence), file.path(out, "origin_group_recovery_checks.csv"))
all_full <- do.call(rbind, full_draws)
short <- if (length(recovered)) do.call(rbind, recovered) else NULL
# A subsequent forecast-only pool can supply the remaining verified snapshots.
pool_root <- arg("--verified-pool-root")
if (!is.null(pool_root)) {
  extra <- list()
  for (i in seq_len(nrow(registry))) {
    r <- registry[i, ]
    p <- file.path(pool_root, r$task_id, "task_status.json")
    if (!file.exists(p)) next
    status <- fpf_json(p)
    draws <- file.path(dirname(p), "prefix_draws.csv.gz")
    fpf_assert(identical(status$status, "VERIFIED") && identical(status$task_id, r$task_id) &&
      identical(status$reference_sha256, r$full_metric_draws_sha256) &&
      file.exists(draws) && identical(fpf_sha(draws), status$prefix_draws_sha256), "Unverified pool evidence.")
    z <- fpf_read(draws)
    fpf_verify_full(z, fpf_read(r$metric_draws_path))
    z <- z[z$cutoff %in% c(300L, 500L), ]
    z$replay_id <- r$replay_id
    extra[[length(extra) + 1L]] <- z
  }
  if (length(extra)) {
    fields <- c("chain_id", "draw_id", "cutoff", "n_pairs", "n_origins", "last_target",
      "forecast_mae", "forecast_check_loss", "replay_id")
    z <- do.call(rbind, lapply(extra, function(x) x[fields]))
    if (!is.null(short)) {
      old <- short[fields]
      key <- function(x) paste(x$replay_id, x$chain_id, x$cutoff, sep = "|")
      old <- old[!key(old) %in% key(z), ]
      z <- rbind(old, z)
    }
    short <- z
  }
}
summary_rows <- list()
for (id in unique(registry$replay_id)) {
  r <- registry[registry$replay_id == id, ][1, ]
  z <- all_full[all_full$replay_id == id, ]
  if (!is.null(short)) {
    a <- short[short$replay_id == id & short$cutoff != 1000L, ]
    if (nrow(a)) z <- rbind(z[c("chain_id", "draw_id", "cutoff", "n_pairs", "n_origins", "last_target",
      "forecast_mae", "forecast_check_loss")],
      a[c("chain_id", "draw_id", "cutoff", "n_pairs", "n_origins", "last_target", "forecast_mae", "forecast_check_loss")])
  }
  pooled <- fpf_pool(z, r$quantile_type)
  pooled$replay_id <- id
  summary_rows[[length(summary_rows) + 1L]] <- pooled
}
pooled <- do.call(rbind, summary_rows)
fpf_write(pooled, file.path(out, "source_interval_summaries.csv"))
display <- missing <- checks <- list()
for (i in seq_len(nrow(roles))) for (n in c(1000L, 500L, 300L)) {
  role <- roles[i, ]
  metric <- if (role$metric_role == "forecast_mae") "forecast_mae" else "forecast_check_loss"
  row <- pooled[pooled$replay_id == role$replay_id & pooled$metric == metric & pooled$cutoff == n, ]
  if (nrow(row) == 1L && row$n_chains == 3L) {
    ans <- role
    for (field in c("posterior_mean", "cri_lower", "posterior_median", "cri_upper", "n_draws", "n_chains"))
      ans[[field]] <- row[[field]]
    ans$cutoff <- n
    ans$forecast_origins <- row$n_origins
    ans$forecast_pairs <- row$n_pairs
    ans$quantile_type <- row$quantile_type
    display[[length(display) + 1L]] <- ans
    if (n == 1000L) {
      fields <- c("posterior_mean", "cri_lower", "posterior_median", "cri_upper")
      error <- max(abs(unlist(ans[fields]) - unlist(role[fields])))
      fpf_assert(error <= 1e-6, "Published full-window interval mismatch.")
      checks[[length(checks) + 1L]] <- data.frame(family = role$family, p = role$tau,
        model_variant = role$model_variant, metric_role = role$metric_role,
        max_error = error, pass = TRUE)
    }
  } else missing[[length(missing) + 1L]] <- data.frame(family = role$family, p = role$tau,
    model_variant = role$model_variant, metric_role = role$metric_role, cutoff = n,
    replay_id = role$replay_id, reason = "Matching joint paths or forecast-capable posterior not recovered")
}
display <- do.call(rbind, display)
fpf_write(display, file.path(out, "available_display_intervals.csv"))
fpf_write(do.call(rbind, missing), file.path(out, "missing_display_intervals.csv"))
fpf_write(do.call(rbind, checks), file.path(out, "full_window_article_checks.csv"))
state <- list(status = if (nrow(display) == 216L) "READY_FOR_INTERVAL_REVIEW" else "RECOVERY_INCOMPLETE_NO_REFITS_LAUNCHED",
  branch = system2("git", c("branch", "--show-current"), stdout = TRUE),
  launch_head = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  task_sources = nrow(registry), full_window_display_rows = sum(display$cutoff == 1000L),
  first500_display_rows = sum(display$cutoff == 500L), first300_display_rows = sum(display$cutoff == 300L),
  missing_display_rows = length(missing), fit_calls = 0L, forecasts_launched = 0L,
  recovery_audit_scope = "Selected job directories, directly source-request-linked roots, configured handoffs, identified portable archive",
  external_undocumented_backups_audited = FALSE, article_modified = FALSE,
  complete_figure_packet_ready = nrow(display) == 216L)
jsonlite::write_json(state, file.path(out, "health.json"), pretty = TRUE, auto_unbox = TRUE, digits = 17)
files <- list.files(out, recursive = TRUE, full.names = TRUE)
files <- files[!dir.exists(files) & basename(files) != "artifact_manifest.csv"]
fpf_write(data.frame(path = normalizePath(files), sha256 = vapply(files, fpf_sha, character(1)),
  bytes = file.info(files)$size), file.path(out, "artifact_manifest.csv"))
cat(sprintf("PREFIX_AUDIT full=%d/72 first500=%d/72 first300=%d/72 fit_calls=0 forecasts=0\n",
  state$full_window_display_rows, state$first500_display_rows, state$first300_display_rows))
