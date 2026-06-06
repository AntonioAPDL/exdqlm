# R/qdesn_model_selection_facade.R

#' Authoritative Q-DESN model-selection entry point
#'
#' `qdesn_model_selection()` is the public facade for Q-DESN model selection.
#' Modern staged configurations with `model_selection$stages` are routed to the
#' v2 engine. Legacy configurations with `model_selection$esn_space` are routed
#' to the historical ESN-pipeline selector for backward compatibility.
#'
#' @param dataset_id Character identifier used for logging and output naming.
#' @param file_long Optional path to long-format input data. Required for legacy
#'   model selection and accepted as a shorthand dataset source for v2.
#' @param file_obs Optional observed-data file for legacy real-data workflows.
#' @param base_cfg Base configuration list for legacy workflows, or a partial
#'   base configuration to merge with `ms_cfg` when `cfg` is not supplied.
#' @param ms_cfg Configuration list containing `model_selection`.
#' @param out_root Output root. Used to derive `run_dir` when `run_dir` is not
#'   supplied.
#' @param repo_root Repository root forwarded to the legacy selector.
#' @param verbose Emit progress messages.
#' @param cfg Full modern v2 configuration. Preferred for new code.
#' @param ds Dataset descriptor for v2, with at least `input_path` and `mode`.
#' @param run_dir Explicit v2 run directory.
#' @param engine One of `"auto"`, `"v2"`, or `"legacy"`.
#'
#' @return Legacy runs return the historical tuning list. V2 runs return the
#'   result from `run_model_selection_v2()` with `engine`, `run_dir`, and
#'   `dataset_id` metadata added.
#' @export
qdesn_model_selection <- function(
  dataset_id = NULL,
  file_long  = NULL,
  file_obs   = NULL,
  base_cfg   = NULL,
  ms_cfg     = NULL,
  out_root   = NULL,
  repo_root  = NULL,
  verbose    = TRUE,
  cfg        = NULL,
  ds         = NULL,
  run_dir    = NULL,
  engine     = "auto"
) {
  engine <- .qdesn_ms_resolve_engine(engine = engine, cfg = cfg, ms_cfg = ms_cfg)

  if (identical(engine, "legacy")) {
    return(.qdesn_model_selection_legacy(
      dataset_id = dataset_id,
      file_long  = file_long,
      file_obs   = file_obs,
      base_cfg   = base_cfg,
      ms_cfg     = ms_cfg,
      out_root   = out_root,
      repo_root  = repo_root,
      verbose    = verbose
    ))
  }

  cfg <- .qdesn_ms_resolve_v2_cfg(cfg = cfg, base_cfg = base_cfg, ms_cfg = ms_cfg)
  if (is.null(cfg$model_selection) || is.null(cfg$model_selection$stages)) {
    stop(
      "qdesn_model_selection(): v2 engine requires cfg$model_selection$stages. ",
      "Use engine = 'legacy' only for configs with model_selection$esn_space."
    )
  }

  ds <- .qdesn_ms_resolve_v2_dataset(ds = ds, file_long = file_long, dataset_id = dataset_id, cfg = cfg)

  if (is.null(run_dir)) {
    if (is.null(out_root)) {
      stop("qdesn_model_selection(): v2 engine requires run_dir or out_root.")
    }
    run_name <- cfg$model_selection$tune_name %||% ds$slug %||% dataset_id %||% "qdesn_model_selection_v2"
    run_dir <- file.path(out_root, "model_selection", run_name)
  }

  if (isTRUE(verbose)) {
    message(sprintf(
      "[qdesn_model_selection] engine=v2 | dataset=%s | run_dir=%s",
      ds$slug %||% dataset_id %||% "dataset",
      run_dir
    ))
  }

  res <- run_model_selection_v2(cfg = cfg, ds = ds, run_dir = run_dir)
  res$engine <- "v2"
  res$run_dir <- run_dir
  res$dataset_id <- ds$slug %||% dataset_id %||% "dataset"
  res
}

.qdesn_ms_resolve_engine <- function(engine = "auto", cfg = NULL, ms_cfg = NULL) {
  engine <- tolower(as.character(engine %||% "auto")[1L])
  valid <- c("auto", "v2", "legacy")
  if (!engine %in% valid) {
    stop("qdesn_model_selection(): engine must be one of ", paste(valid, collapse = ", "), ".")
  }
  if (!identical(engine, "auto")) {
    return(engine)
  }

  ms_block <- NULL
  if (!is.null(cfg) && !is.null(cfg$model_selection)) {
    ms_block <- cfg$model_selection
  } else if (!is.null(ms_cfg) && !is.null(ms_cfg$model_selection)) {
    ms_block <- ms_cfg$model_selection
  }

  if (is.null(ms_block)) {
    stop("qdesn_model_selection(): could not infer engine; no model_selection block was supplied.")
  }
  if (!is.null(ms_block$stages)) {
    return("v2")
  }
  if (!is.null(ms_block$esn_space)) {
    return("legacy")
  }
  stop(
    "qdesn_model_selection(): could not infer engine. Modern configs need ",
    "model_selection$stages; legacy configs need model_selection$esn_space."
  )
}

.qdesn_ms_resolve_v2_cfg <- function(cfg = NULL, base_cfg = NULL, ms_cfg = NULL) {
  if (!is.null(cfg)) {
    if (!is.list(cfg)) stop("qdesn_model_selection(): cfg must be a list.")
    return(ms_fix_cfg_keys(cfg))
  }
  if (is.null(base_cfg) && is.null(ms_cfg)) {
    stop("qdesn_model_selection(): v2 engine requires cfg or base_cfg/ms_cfg.")
  }
  if (!is.null(base_cfg) && !is.list(base_cfg)) {
    stop("qdesn_model_selection(): base_cfg must be a list.")
  }
  if (!is.null(ms_cfg) && !is.list(ms_cfg)) {
    stop("qdesn_model_selection(): ms_cfg must be a list.")
  }
  ms_fix_cfg_keys(ms_deep_merge(base_cfg %||% list(), ms_cfg %||% list()))
}

.qdesn_ms_resolve_v2_dataset <- function(ds = NULL, file_long = NULL, dataset_id = NULL, cfg = NULL) {
  if (!is.null(ds)) {
    if (!is.list(ds)) stop("qdesn_model_selection(): ds must be a list.")
    if (is.null(ds$input_path)) stop("qdesn_model_selection(): ds$input_path is required for v2.")
    if (is.null(ds$mode)) ds$mode <- cfg$pipeline$mode %||% "sim"
    if (is.null(ds$slug)) ds$slug <- dataset_id %||% "dataset"
    return(ds)
  }
  if (is.null(file_long)) {
    stop("qdesn_model_selection(): v2 engine requires ds or file_long.")
  }
  list(
    slug = dataset_id %||% "dataset",
    mode = cfg$pipeline$mode %||% "sim",
    input_path = file_long
  )
}
