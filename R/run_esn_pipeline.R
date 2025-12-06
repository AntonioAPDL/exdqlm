# R/run_esn_pipeline.R
# High-level helper to run the ESN quantile pipeline from an in-memory cfg list.
# This uses the existing scripts/pipeline_sim_main.R entrypoint via system2(),
# so we don't have to duplicate the long body inside the package namespace.

#' Run ESN quantile pipeline from a configuration list
#'
#' This is a thin wrapper around \code{scripts/pipeline_sim_main.R} that:
#' \itemize{
#'   \item accepts a parsed YAML/JSON configuration list \code{cfg},
#'   \item serializes it to JSON and passes it via \code{EXDQLM_CFG_JSON},
#'   \item sets file paths and output directory via environment variables,
#'   \item runs the pipeline script in a separate R process,
#'   \item optionally checks for errors and returns invisibly.
#' }
#'
#' It is primarily used by the ESN model-selection routines.
#'
#' @param cfg list; full configuration (defaults + spec + overrides).
#' @param file_long character; path to the long-format data file used by the pipeline.
#' @param file_obs  character or NULL; optional observed-data file (for real-data mode).
#' @param out_dir   character; directory where the pipeline should write outputs.
#' @param repo_root character or NULL; root of the git repo. If NULL, attempt to
#'   detect it via \code{git rev-parse --show-toplevel}.
#' @param save_outputs logical; whether to allow the pipeline to write figures/tables.
#'   This sets the \code{EXDQLM_SAVE_OUTPUTS} flag; the YAML \code{cfg$outputs}
#'   can still override it.
#' @param rscript character; path to the Rscript executable (default "Rscript").
#' @param pipeline_script character; relative path from \code{repo_root} to the
#'   main pipeline script (default "scripts/pipeline_sim_main.R").
#' @param verbose logical; if TRUE, print the command and capture+echo the script
#'   output line by line.
#'
#' @return Invisibly, a list with components \code{status} (integer exit status),
#'   \code{cmd} (character vector with the Rscript command), and \code{stdout}
#'   (captured output as character vector) when \code{verbose = TRUE}.
#'   On non-zero exit status, a warning is emitted.
#' @export
run_esn_pipeline_from_cfg <- function(
  cfg,
  file_long,
  file_obs = NULL,
  out_dir,
  repo_root = NULL,
  save_outputs = TRUE,
  rscript = "Rscript",
  pipeline_script = file.path("scripts", "pipeline_sim_main.R"),
  verbose = TRUE
) {
  stopifnot(is.list(cfg), is.character(file_long), length(file_long) == 1L)
  stopifnot(is.character(out_dir), length(out_dir) == 1L)

  if (is.null(repo_root)) {
    repo_root <- tryCatch(
      normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
      error = function(...) normalizePath(".", mustWork = TRUE)
    )
  }
  pipeline_path <- normalizePath(file.path(repo_root, pipeline_script), mustWork = TRUE)

  if (!file.exists(file_long)) {
    stop("run_esn_pipeline_from_cfg(): file_long not found: ", file_long)
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # Serialize cfg to JSON for the pipeline script
  cfg_json <- jsonlite::toJSON(cfg, auto_unbox = TRUE, null = "null")

  # Env vars for the child R process
  env_vars <- c(
    EXDQLM_FILE_LONG    = normalizePath(file_long),
    EXDQLM_FILE_OBS     = if (!is.null(file_obs)) normalizePath(file_obs) else "",
    EXDQLM_OUT_DIR      = normalizePath(out_dir),
    EXDQLM_CFG_JSON     = cfg_json,
    EXDQLM_SAVE_OUTPUTS = if (isTRUE(save_outputs)) "1" else "0"
  )

  # Build command
  cmd <- c(pipeline_path)

  if (isTRUE(verbose)) {
    message("[run_esn_pipeline_from_cfg] Running pipeline script:")
    message("  repo_root: ", repo_root)
    message("  script   : ", pipeline_path)
    message("  out_dir  : ", out_dir)
  }

  # Execute Rscript with the given environment
  # Use stdout capture to return logs to the caller
  res <- tryCatch(
    {
      out <- system2(
        command = rscript,
        args    = cmd,
        stdout  = TRUE,
        stderr  = TRUE,
        env     = env_vars
      )
      list(status = 0L, stdout = out)
    },
    warning = function(w) {
      list(status = 1L, stdout = conditionMessage(w))
    },
    error = function(e) {
      list(status = 1L, stdout = conditionMessage(e))
    }
  )

  if (!identical(res$status, 0L)) {
    warning(
      "run_esn_pipeline_from_cfg(): pipeline script exited with non-zero status. ",
      "See $stdout for details."
    )
  }

  if (isTRUE(verbose)) {
    cat(paste0("[pipeline_stdout] ", res$stdout, collapse = "\n"), "\n")
  }

  invisible(list(
    status = res$status,
    cmd    = c(rscript, cmd),
    stdout = res$stdout
  ))
}
