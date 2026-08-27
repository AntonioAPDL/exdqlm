#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Missing jsonlite")
})
args <- commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) default else args[[i[[1L]] + 1L]]
}
repo <- normalizePath(
  arg("--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)),
  winslash = "/", mustWork = TRUE
)
source(file.path(
  repo, "validation", "fitforecast_v2", "R",
  "independent_dynamic_location_capacity_tau0_v1.R"
))
run_tag <- arg("--run-tag")
mat <- normalizePath(arg("--materialization-root"), winslash = "/", mustWork = TRUE)
out <- normalizePath(arg("--output-root", file.path(mat, "closeout")),
                     winslash = "/", mustWork = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
plan <- qdesn_ssv2_read_csv(file.path(mat, "screen_plan.csv"))
targets <- idlc_v1_read_targets(repo)
results <- do.call(rbind, lapply(seq_len(nrow(plan)), function(i) {
  idlc_v1_collect_result(repo, run_tag, plan[i, , drop = FALSE])
}))
qdesn_ssv2_write_csv(results, file.path(out, "point_metric_results.csv"))

bind_artifact <- function(paths, id_columns) {
  rows <- lapply(seq_along(paths), function(i) {
    if (!file.exists(paths[[i]])) return(NULL)
    x <- qdesn_ssv2_read_csv(paths[[i]])
    for (name in names(id_columns)) x[[name]] <- id_columns[[name]][[i]]
    x
  })
  rows <- rows[vapply(rows, function(x) !is.null(x) && nrow(x), logical(1L))]
  if (!length(rows)) return(data.frame())
  fields <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (field in setdiff(fields, names(x))) x[[field]] <- NA
    x[, fields, drop = FALSE]
  })
  do.call(rbind, rows)
}
ids <- list(
  job_id = results$job_id, target_cell_id = results$target_cell_id,
  candidate_id = results$candidate_id, profile_role = results$profile_role,
  rhs_tau0 = results$rhs_tau0
)
intervals <- bind_artifact(results$metric_interval_summary_path, ids)
location <- bind_artifact(results$common_shift_effects_path, ids)
conditioning <- bind_artifact(results$design_conditioning_path, ids)
qdesn_ssv2_write_csv(intervals, file.path(out, "posterior_metric_intervals.csv"))
qdesn_ssv2_write_csv(location, file.path(out, "location_shape_diagnostics.csv"))
qdesn_ssv2_write_csv(conditioning,
                     file.path(out, "design_conditioning_diagnostics.csv"))

ranking_rows <- list()
finalist_rows <- list()
for (i in seq_len(nrow(targets))) {
  target <- targets[i, , drop = FALSE]
  cell <- results[results$target_cell_id == target$target_cell_id[[1L]] &
                    results$status == "SUCCESS", , drop = FALSE]
  for (metric in idlc_v1_promotion_metrics) {
    current <- as.numeric(target[[paste0("current_", metric)]][[1L]])
    finite <- cell[is.finite(cell[[metric]]), , drop = FALSE]
    finite <- finite[order(finite[[metric]], finite$candidate_id), , drop = FALSE]
    if (!nrow(finite)) next
    finite$metric <- metric
    finite$rank <- seq_len(nrow(finite))
    finite$current_authority_value <- current
    finite$delta <- finite[[metric]] - current
    finite$strict_improvement <- finite[[metric]] < current -
      idlc_v1_reconstruction_tolerance
    ranking_rows[[length(ranking_rows) + 1L]] <- finite
    selected <- finite$rank <= min(2L, nrow(finite)) |
      finite$strict_improvement | finite$profile_role == "P0_parent"
    z <- finite[selected, , drop = FALSE]
    z$selection_reason <- ifelse(
      z$strict_improvement, "strict_point_metric_improvement",
      ifelse(z$profile_role == "P0_parent", "matched_parent_control",
             "top_two_metric_candidate")
    )
    finalist_rows[[length(finalist_rows) + 1L]] <- z
  }
}
rankings <- if (length(ranking_rows)) do.call(rbind, ranking_rows) else data.frame()
finalists <- if (length(finalist_rows)) do.call(rbind, finalist_rows) else data.frame()
qdesn_ssv2_write_csv(rankings, file.path(out, "cell_metric_rankings.csv"))
qdesn_ssv2_write_csv(finalists, file.path(out, "metric_specific_finalists.csv"))

status_counts <- as.data.frame(table(results$status), stringsAsFactors = FALSE)
names(status_counts) <- c("status", "jobs")
qdesn_ssv2_write_csv(status_counts, file.path(out, "job_status_summary.csv"))
all_terminal <- all(results$status %in% c("SUCCESS", "FAIL"))
all_success <- all(results$status == "SUCCESS")
strict_gains <- if (nrow(finalists)) sum(finalists$strict_improvement) else 0L
decision <- if (!all_terminal) {
  "INCOMPLETE_WAIT_OR_RESUME"
} else if (!all_success) {
  "COMPLETE_WITH_EXECUTION_FAILURES_RESUME_FAILED_JOBS"
} else if (strict_gains > 0L) {
  "PREPARE_MATCHED_REPLICATION"
} else {
  "NO_DISCOVERY_GAIN_USE_STRUCTURAL_FALLBACK"
}

result_root <- file.path(repo, "results", "qdesn_mcmc_validation", idlc_v1_stage,
                         run_tag)
binaries <- list.files(
  result_root, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
  full.names = TRUE, ignore.case = TRUE
)
storage <- data.frame(
  result_root = result_root,
  retained_binary_payloads = length(binaries),
  retained_binary_bytes = if (length(binaries)) sum(file.info(binaries)$size) else 0,
  storage_contract = if (!length(binaries)) "PASS" else "FAIL",
  stringsAsFactors = FALSE
)
qdesn_ssv2_write_csv(storage, file.path(out, "storage_audit.csv"))
qdesn_ssv2_write_json(list(
  schema_version = "independent_dynamic_location_capacity_tau0_v1_decision_v1",
  generated_at = as.character(Sys.time()), run_tag = run_tag,
  decision = decision, planned_jobs = nrow(plan), successful_jobs =
    sum(results$status == "SUCCESS"), failed_jobs = sum(results$status == "FAIL"),
  nonterminal_jobs = sum(!results$status %in% c("SUCCESS", "FAIL")),
  strict_metric_gains = strict_gains,
  promotion_automatic = FALSE,
  next_action = switch(decision,
    PREPARE_MATCHED_REPLICATION =
      "Materialize per-metric finalists on the second reservoir panel.",
    NO_DISCOVERY_GAIN_USE_STRUCTURAL_FALLBACK =
      "Stop capacity-by-tau0 tuning and design the orthogonalized-readout experiment.",
    COMPLETE_WITH_EXECUTION_FAILURES_RESUME_FAILED_JOBS =
      "Resume only execution-failed jobs using the frozen configs.",
    "Wait for or resume nonterminal jobs."
  )
), file.path(out, "campaign_decision.json"))

files <- setdiff(list.files(out, recursive = TRUE, full.names = TRUE),
                 file.path(out, "file_manifest.csv"))
manifest <- data.frame(
  path = normalizePath(files, winslash = "/", mustWork = TRUE),
  bytes = as.numeric(file.info(files)$size),
  sha256 = vapply(files, qdesn_ssv2_sha256, character(1L)),
  stringsAsFactors = FALSE
)
qdesn_ssv2_write_csv(manifest, file.path(out, "file_manifest.csv"))
cat(sprintf(
  "CLOSEOUT decision=%s success=%d/%d strict_gains=%d binaries=%d output=%s\n",
  decision, sum(results$status == "SUCCESS"), nrow(results), strict_gains,
  length(binaries), out
))
