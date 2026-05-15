ffv2_storage_audit <- function(run_root,
                               forbidden_extensions = c(".rds", ".rda", ".RData")) {
  run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)
  files <- list.files(run_root, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  info <- file.info(files)
  forbidden_pattern <- paste0("(", paste(gsub("[.]", "[.]", forbidden_extensions), collapse = "|"), ")$")
  forbidden <- files[grepl(forbidden_pattern, files, ignore.case = FALSE)]
  forbidden_info <- file.info(forbidden)
  out <- data.frame(
    run_root = run_root,
    n_files = length(files),
    total_bytes = sum(info$size, na.rm = TRUE),
    forbidden_payloads = length(forbidden),
    forbidden_bytes = sum(forbidden_info$size, na.rm = TRUE),
    status = if (length(forbidden)) "FAIL" else "PASS",
    stringsAsFactors = FALSE
  )
  if (length(forbidden)) {
    out$forbidden_paths <- paste(forbidden, collapse = "|")
  } else {
    out$forbidden_paths <- ""
  }
  out
}
