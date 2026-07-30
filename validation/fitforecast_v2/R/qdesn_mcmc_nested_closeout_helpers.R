qdesn_canonical_seed_selection_files <- function(result_root, expected_roots = NULL) {
  roots_dir <- file.path(result_root, "roots")
  root_dirs <- list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)
  files <- file.path(root_dirs, "tables", "mcmc_seed_selection.csv")
  files <- sort(normalizePath(
    files[file.exists(files)],
    winslash = "/",
    mustWork = TRUE
  ))
  if (!is.null(expected_roots) && length(files) != expected_roots) {
    stop(
      sprintf(
        "Expected %d canonical root seed-selection files under %s; found %d.",
        expected_roots,
        normalizePath(roots_dir, winslash = "/", mustWork = TRUE),
        length(files)
      ),
      call. = FALSE
    )
  }
  files
}

qdesn_validate_seed_selection <- function(selection, selection_path) {
  required <- c("root_id", "seed_rep")
  missing <- setdiff(required, names(selection))
  if (length(missing)) {
    stop(
      sprintf(
        "Seed-selection table %s is missing: %s.",
        selection_path,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  root_ids <- unique(as.character(selection$root_id))
  seed_reps <- sort(unique(as.integer(selection$seed_rep)))
  seed_keys <- paste(selection$root_id, selection$seed_rep, sep = "|")
  if (nrow(selection) != 2L ||
      length(root_ids) != 1L ||
      !identical(seed_reps, 1:2) ||
      anyDuplicated(seed_keys)) {
    stop(
      sprintf(
        paste(
          "Seed-selection table %s must contain exactly one root",
          "and seed_rep values 1 and 2 without duplicates."
        ),
        selection_path
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
