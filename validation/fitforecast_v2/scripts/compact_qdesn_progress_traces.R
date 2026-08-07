#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
run_root <- get_arg("--run-root")
output_dir <- get_arg("--output-dir")
stride <- as.integer(get_arg("--stride", "50"))
if (is.null(run_root) || !dir.exists(run_root) || is.null(output_dir) ||
    !is.finite(stride) || stride < 1L) {
  stop("--run-root, --output-dir, and a positive --stride are required.", call. = FALSE)
}
run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
trace_paths <- list.files(
  run_root, pattern = "^(progress_trace|progress_trace_long)[.]csv$",
  recursive = TRUE, full.names = TRUE
)
rows <- lapply(trace_paths, function(path) {
  before_hash <- unname(tools::sha256sum(path)[[1L]])
  before_bytes <- as.numeric(file.info(path)$size)
  trace <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  if (!"step" %in% names(trace) || !nrow(trace)) {
    return(data.frame(
      path = path, rows_before = nrow(trace), rows_after = nrow(trace),
      bytes_before = before_bytes, bytes_after = before_bytes,
      sha256_before = before_hash, sha256_after = before_hash,
      disposition = "kept_unmodified_no_step_rows", stringsAsFactors = FALSE
    ))
  }
  step <- suppressWarnings(as.integer(trace$step))
  finite_step <- step[is.finite(step)]
  keep <- seq_len(nrow(trace)) %in% c(1L, nrow(trace)) |
    (is.finite(step) & step %% stride == 0L)
  if (length(finite_step)) keep <- keep | step == min(finite_step) | step == max(finite_step)
  compact <- trace[keep, , drop = FALSE]
  temporary <- paste0(path, ".compact.tmp")
  utils::write.csv(compact, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) {
    unlink(temporary)
    stop(sprintf("Could not atomically replace trace: %s", path), call. = FALSE)
  }
  data.frame(
    path = path, rows_before = nrow(trace), rows_after = nrow(compact),
    bytes_before = before_bytes, bytes_after = as.numeric(file.info(path)$size),
    sha256_before = before_hash, sha256_after = unname(tools::sha256sum(path)[[1L]]),
    disposition = "compacted_keep_first_final_and_stride", stringsAsFactors = FALSE
  )
})
audit <- if (length(rows)) do.call(rbind, rows) else data.frame(
  path = character(), rows_before = integer(), rows_after = integer(),
  bytes_before = numeric(), bytes_after = numeric(), sha256_before = character(),
  sha256_after = character(), disposition = character()
)
audit_path <- file.path(output_dir, "progress_trace_compaction_audit.csv")
utils::write.csv(audit, audit_path, row.names = FALSE, na = "")
status_paths <- list.files(run_root,
                          pattern = "(root_status|fit_status|failure|heartbeat)[.](txt|csv|json)$",
                          recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
manifest <- list(
  generated_at = as.character(Sys.time()), run_root = run_root, stride = stride,
  trace_files = nrow(audit), rows_before = sum(audit$rows_before),
  rows_after = sum(audit$rows_after), bytes_before = sum(audit$bytes_before),
  bytes_after = sum(audit$bytes_after), bytes_recovered = sum(audit$bytes_before - audit$bytes_after),
  status_heartbeat_failure_files_preserved = length(status_paths),
  status_heartbeat_failure_files_modified = 0L,
  audit_path = normalizePath(audit_path, winslash = "/", mustWork = TRUE),
  audit_sha256 = unname(tools::sha256sum(audit_path)[[1L]])
)
jsonlite::write_json(manifest, file.path(output_dir, "progress_trace_compaction_manifest.json"),
                     pretty = TRUE, auto_unbox = TRUE, digits = NA)
cat(sprintf("TRACE_FILES=%d\nROWS=%d->%d\nBYTES_RECOVERED=%d\n",
            nrow(audit), sum(audit$rows_before), sum(audit$rows_after),
            sum(audit$bytes_before - audit$bytes_after)))
