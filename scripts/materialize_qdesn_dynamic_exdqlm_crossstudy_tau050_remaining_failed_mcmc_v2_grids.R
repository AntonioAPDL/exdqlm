#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  {
    script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
    normalizePath(
      file.path(dirname(normalizePath(script_file, winslash = "/", mustWork = TRUE)), ".."),
      winslash = "/",
      mustWork = TRUE
    )
  },
  error = function(...) normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

subset_and_write <- function(grid_df, root_ids, output_path, label) {
  subset_grid <- grid_df[match(root_ids, grid_df$root_id, nomatch = 0L), , drop = FALSE]
  if (nrow(subset_grid) != length(root_ids)) {
    missing_ids <- setdiff(root_ids, as.character(subset_grid$root_id))
    stop(
      sprintf(
        "Failed to recover %d %s roots: %s",
        length(missing_ids),
        label,
        paste(missing_ids, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  subset_grid <- subset_grid[order(subset_grid$root_id), , drop = FALSE]
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(subset_grid, output_path, row.names = FALSE)
  subset_grid
}

al_source_path <- resolve_path(
  get_arg(
    "--source-al-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_grid.csv")
  ),
  must_work = TRUE
)
exal_source_path <- resolve_path(
  get_arg(
    "--source-exal-grid",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_grid.csv")
  ),
  must_work = TRUE
)
al_v2_output_path <- resolve_path(
  get_arg(
    "--al-v2-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_grid.csv")
  ),
  must_work = FALSE
)
exal_v2_output_path <- resolve_path(
  get_arg(
    "--exal-v2-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_grid.csv")
  ),
  must_work = FALSE
)
al_canary_output_path <- resolve_path(
  get_arg(
    "--al-canary-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_canary_grid.csv")
  ),
  must_work = FALSE
)
exal_canary_output_path <- resolve_path(
  get_arg(
    "--exal-canary-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_canary_grid.csv")
  ),
  must_work = FALSE
)
al_residual_output_path <- resolve_path(
  get_arg(
    "--al-residual-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_al_v2_residual_grid.csv")
  ),
  must_work = FALSE
)
exal_residual_output_path <- resolve_path(
  get_arg(
    "--exal-residual-output",
    file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_remaining_failed_mcmc_exal_v2_residual_grid.csv")
  ),
  must_work = FALSE
)

al_grid <- utils::read.csv(al_source_path, stringsAsFactors = FALSE)
exal_grid <- utils::read.csv(exal_source_path, stringsAsFactors = FALSE)

al_canary_root_ids <- c(
  "root__dynamic__dlm_constV_smallW__gausmix__tau_0p25__lasttt_5000__qdesn_rhs_ns",
  "root__dynamic__dlm_constV_smallW__normal__tau_0p50__lasttt_5000__qdesn_ridge"
)
exal_canary_root_ids <- c(
  "root__dynamic__dlm_constV_smallW__gausmix__tau_0p50__lasttt_5000__qdesn_rhs_ns",
  "root__dynamic__dlm_constV_smallW__laplace__tau_0p25__lasttt_5000__qdesn_ridge",
  "root__dynamic__dlm_constV_smallW__normal__tau_0p05__lasttt_5000__qdesn_ridge"
)

al_v2_grid <- subset_and_write(al_grid, as.character(al_grid$root_id), al_v2_output_path, "AL v2")
exal_v2_grid <- subset_and_write(exal_grid, as.character(exal_grid$root_id), exal_v2_output_path, "EXAL v2")
al_canary_grid <- subset_and_write(al_grid, al_canary_root_ids, al_canary_output_path, "AL canary")
exal_canary_grid <- subset_and_write(exal_grid, exal_canary_root_ids, exal_canary_output_path, "EXAL canary")
al_residual_grid <- subset_and_write(
  al_grid,
  setdiff(as.character(al_grid$root_id), al_canary_root_ids),
  al_residual_output_path,
  "AL residual"
)
exal_residual_grid <- subset_and_write(
  exal_grid,
  setdiff(as.character(exal_grid$root_id), exal_canary_root_ids),
  exal_residual_output_path,
  "EXAL residual"
)

cat(sprintf("source_al_grid=%s\n", al_source_path))
cat(sprintf("source_exal_grid=%s\n", exal_source_path))
cat(sprintf("al_v2_output=%s\n", al_v2_output_path))
cat(sprintf("al_v2_roots=%d\n", nrow(al_v2_grid)))
cat(sprintf("al_canary_output=%s\n", al_canary_output_path))
cat(sprintf("al_canary_roots=%d\n", nrow(al_canary_grid)))
cat(sprintf("al_residual_output=%s\n", al_residual_output_path))
cat(sprintf("al_residual_roots=%d\n", nrow(al_residual_grid)))
cat(sprintf("exal_v2_output=%s\n", exal_v2_output_path))
cat(sprintf("exal_v2_roots=%d\n", nrow(exal_v2_grid)))
cat(sprintf("exal_canary_output=%s\n", exal_canary_output_path))
cat(sprintf("exal_canary_roots=%d\n", nrow(exal_canary_grid)))
cat(sprintf("exal_residual_output=%s\n", exal_residual_output_path))
cat(sprintf("exal_residual_roots=%d\n", nrow(exal_residual_grid)))
