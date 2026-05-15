ffv2_stage_rows <- function(manifest,
                            phase = c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "all"),
                            include_completed = FALSE) {
  phase <- match.arg(phase)
  keep <- switch(
    phase,
    smoke = isTRUE(manifest$smoke) | manifest$smoke %in% c("TRUE", "true", "1"),
    vb_full = manifest$inference == "vb",
    mcmc_tt500 = manifest$inference == "mcmc" & as.integer(manifest$fit_size) == 500L,
    mcmc_tt5000 = manifest$inference == "mcmc" & as.integer(manifest$fit_size) == 5000L,
    all = rep(TRUE, nrow(manifest))
  )
  out <- manifest[keep, , drop = FALSE]
  if (!isTRUE(include_completed)) {
    completed <- rep(FALSE, nrow(out))
    for (i in seq_len(nrow(out))) {
      status_path <- out$row_status_path[[i]]
      if (file.exists(status_path)) {
        st <- tryCatch(ffv2_read_csv(status_path), error = function(e) NULL)
        if (!is.null(st) && nrow(st)) {
          completed[[i]] <- tail(st$status, 1L) %in% c("done", "failed_runtime", "running")
        }
      }
    }
    out <- out[!completed, , drop = FALSE]
  }
  out
}

ffv2_status_counts <- function(manifest) {
  statuses <- vapply(seq_len(nrow(manifest)), function(i) {
    path <- manifest$row_status_path[[i]]
    if (!file.exists(path)) return("pending")
    st <- tryCatch(ffv2_read_csv(path), error = function(e) NULL)
    if (is.null(st) || !nrow(st) || !"status" %in% names(st)) return("unknown")
    as.character(tail(st$status, 1L))
  }, character(1))
  as.data.frame(table(statuses), stringsAsFactors = FALSE)
}
