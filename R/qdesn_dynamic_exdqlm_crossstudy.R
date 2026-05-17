`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_crossstudy_load_defaults <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"),
                                                   repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- yaml::read_yaml(yaml_path)
  if (!is.list(out)) {
    stop("Dynamic exdqlm cross-study defaults YAML must parse to a list.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_crossstudy_path_rewrites <- function(defaults) {
  path_cfg <- (defaults %||% list())$paths %||% list()
  rewrites <- path_cfg$rewrites %||% (defaults %||% list())$path_rewrites %||% list()
  auto_local_src <- isTRUE(path_cfg$rewrite_home_local_src_to_repo_root %||% FALSE)

  if (!length(rewrites)) {
    out <- data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
  } else if (is.data.frame(rewrites)) {
    out <- rewrites
  } else if (is.list(rewrites) && all(vapply(rewrites, is.list, logical(1)))) {
    out <- .qdesn_validation_bind_rows(lapply(rewrites, function(x) {
      data.frame(
        from = as.character(x$from %||% x$old %||% "")[1L],
        to = as.character(x$to %||% x$new %||% "")[1L],
        stringsAsFactors = FALSE
      )
    }))
  } else {
    out <- data.frame(
      from = names(rewrites) %||% character(0),
      to = as.character(unlist(rewrites, use.names = FALSE)),
      stringsAsFactors = FALSE
    )
  }

  if (isTRUE(auto_local_src)) {
    repo_root <- .qdesn_validation_repo_root()
    home_root <- Sys.getenv("HOME", unset = "")
    if (nzchar(home_root)) {
      out <- rbind(
        out,
        data.frame(
          from = file.path(home_root, "local", "src", basename(repo_root)),
          to = repo_root,
          stringsAsFactors = FALSE
        )
      )
    }
  }

  if (!nrow(out)) return(data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE))
  out$from <- as.character(out$from)
  out$to <- as.character(out$to)
  out <- out[nzchar(out$from) & nzchar(out$to), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.qdesn_dynamic_crossstudy_rewrite_paths <- function(x, defaults) {
  rewrites <- .qdesn_dynamic_crossstudy_path_rewrites(defaults)
  if (!nrow(rewrites)) return(x)

  rewrite_chr <- function(value) {
    out <- as.character(value)
    for (i in seq_len(nrow(rewrites))) {
      out <- sub(
        paste0("^", gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", rewrites$from[[i]])),
        rewrites$to[[i]],
        out
      )
    }
    out
  }

  if (is.data.frame(x)) {
    char_cols <- names(x)[vapply(x, is.character, logical(1))]
    for (nm in char_cols) x[[nm]] <- rewrite_chr(x[[nm]])
    return(x)
  }
  if (is.character(x)) return(rewrite_chr(x))
  x
}

qdesn_dynamic_crossstudy_load_grid <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"),
                                               repo_root = NULL) {
  grid_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  out <- utils::read.csv(grid_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop("Dynamic exdqlm cross-study grid CSV is empty.", call. = FALSE)
  }
  out
}

.qdesn_dynamic_crossstudy_grid_source_mode <- function(defaults) {
  grid_cfg <- defaults$grid %||% list()
  mode <- tolower(as.character(grid_cfg$source_mode %||% "reference_inventory")[1L])
  if (!mode %in% c("reference_inventory", "materialized_source_inputs")) {
    stop(sprintf("Unsupported dynamic cross-study grid source_mode '%s'.", mode), call. = FALSE)
  }
  mode
}

.qdesn_dynamic_crossstudy_prob_label <- function(x) {
  gsub("\\.", "p", format(as.numeric(x)[1L], nsmall = 2, digits = 4, trim = TRUE))
}

.qdesn_dynamic_crossstudy_parse_tau_label <- function(x) {
  raw <- sub("^tau_", "", as.character(x)[1L])
  raw <- gsub("p", ".", raw, fixed = TRUE)
  as.numeric(raw)
}

.qdesn_dynamic_crossstudy_parse_fit_size <- function(x, prefix) {
  as.integer(sub(sprintf("^%s", prefix), "", as.character(x)[1L]))
}

.qdesn_dynamic_crossstudy_parse_reference_root <- function(root_dir, reference_root) {
  root_dir <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
  reference_root <- normalizePath(reference_root, winslash = "/", mustWork = TRUE)
  rel <- sub(paste0("^", reference_root, "/?"), "", root_dir)
  parts <- strsplit(rel, "/", fixed = TRUE)[[1L]]
  if (length(parts) < 5L) {
    stop(sprintf("Dynamic reference root has unexpected structure: %s", root_dir), call. = FALSE)
  }
  scenario <- as.character(parts[[1L]])
  family <- as.character(parts[[2L]])
  tau <- .qdesn_dynamic_crossstudy_parse_tau_label(parts[[3L]])
  fit_size <- .qdesn_dynamic_crossstudy_parse_fit_size(parts[[4L]], "fit_input_lastTT")
  validation_tt <- .qdesn_dynamic_crossstudy_parse_fit_size(parts[[5L]], "validation_dynamic_tt")
  if (!is.finite(tau) || !is.finite(fit_size) || !is.finite(validation_tt)) {
    stop(sprintf("Failed to parse dynamic reference root metadata from: %s", root_dir), call. = FALSE)
  }
  if (!identical(as.integer(fit_size), as.integer(validation_tt))) {
    stop(sprintf(
      "Dynamic reference root mismatch: fit_input_lastTT=%d but validation_dynamic_tt=%d for %s",
      as.integer(fit_size), as.integer(validation_tt), root_dir
    ), call. = FALSE)
  }
  fit_input_dir <- dirname(root_dir)
  data.frame(
    root_dir = root_dir,
    scenario = scenario,
    root_kind = "dynamic",
    family = family,
    tau = tau,
    fit_size = as.integer(fit_size),
    fit_input_dir = normalizePath(fit_input_dir, winslash = "/", mustWork = TRUE),
    series_wide_path = normalizePath(file.path(fit_input_dir, "series_wide.csv"), winslash = "/", mustWork = TRUE),
    selection_indices_path = normalizePath(file.path(fit_input_dir, "selection_indices.csv"), winslash = "/", mustWork = TRUE),
    sim_path = normalizePath(file.path(fit_input_dir, "sim_output.rds"), winslash = "/", mustWork = FALSE),
    report_summary_path = normalizePath(file.path(root_dir, "tables", "report_summary.md"), winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_crossstudy_collect_reference_inventory <- function(reference_root) {
  reference_root <- .qdesn_validation_resolve_path(reference_root, must_work = TRUE)
  signoff_paths <- list.files(reference_root, pattern = "root_signoff_summary.csv", recursive = TRUE, full.names = TRUE)
  if (!length(signoff_paths)) {
    stop(sprintf("No dynamic reference root_signoff_summary.csv files found under %s", reference_root), call. = FALSE)
  }
  root_dirs <- sort(unique(dirname(dirname(signoff_paths))))
  cell_inventory <- .qdesn_validation_bind_rows(lapply(root_dirs, function(root_dir) {
    .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
  }))

  build_fit_rows <- function(root_dir) {
    meta_path <- file.path(root_dir, "tables", "root_signoff_summary.csv")
    signoff_long_path <- file.path(root_dir, "tables", "method_signoff_long.csv")
    fit_summary_path <- file.path(root_dir, "tables", "fit_summary.csv")
    if (!file.exists(meta_path) || !file.exists(signoff_long_path)) return(NULL)
    meta <- utils::read.csv(meta_path, stringsAsFactors = FALSE)
    if (!nrow(meta)) return(NULL)
    signoff_long <- utils::read.csv(signoff_long_path, stringsAsFactors = FALSE)
    if (!nrow(signoff_long)) return(NULL)
    fit_summary <- if (file.exists(fit_summary_path)) utils::read.csv(fit_summary_path, stringsAsFactors = FALSE) else data.frame(stringsAsFactors = FALSE)
    out <- if (nrow(fit_summary)) {
      merge(
        signoff_long,
        fit_summary,
        by = intersect(c("inference", "model", "tau"), intersect(names(signoff_long), names(fit_summary))),
        all.x = TRUE,
        sort = FALSE,
        suffixes = c("", "_fit")
      )
    } else {
      signoff_long
    }
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    for (nm in c("root_id", "root_kind", "family", "tau", "fit_size", "prior")) {
      if (nm %in% names(meta) && !nm %in% names(out)) out[[nm]] <- meta[[nm]][1L]
    }
    out$scenario <- as.character(parsed$scenario[1L])
    if (!("runtime_sec" %in% names(out)) && "runtime_sec_fit" %in% names(out)) {
      out$runtime_sec <- out$runtime_sec_fit
    }
    out
  }

  build_pair_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "algorithm_pair_signoff.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    if (!("algorithm_pair_signoff_grade" %in% names(df)) && "pair_signoff_grade" %in% names(df)) {
      df$algorithm_pair_signoff_grade <- df$pair_signoff_grade
    }
    if (!("algorithm_pair_comparison_eligible" %in% names(df)) && "pair_comparison_eligible" %in% names(df)) {
      df$algorithm_pair_comparison_eligible <- df$pair_comparison_eligible
    }
    df
  }

  build_model_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "model_pair_signoff.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    df
  }

  build_root_rows <- function(root_dir) {
    path <- file.path(root_dir, "tables", "root_signoff_summary.csv")
    if (!file.exists(path)) return(NULL)
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    if (!nrow(df)) return(NULL)
    parsed <- .qdesn_dynamic_crossstudy_parse_reference_root(root_dir, reference_root)
    df$scenario <- as.character(parsed$scenario[1L])
    df
  }

  list(
    reference_root = reference_root,
    root_dirs = root_dirs,
    cell_inventory = cell_inventory,
    fit_summary = .qdesn_validation_bind_rows(lapply(root_dirs, build_fit_rows)),
    pairwise_vb_vs_mcmc = .qdesn_validation_bind_rows(lapply(root_dirs, build_pair_rows)),
    model_pair_signoff = .qdesn_validation_bind_rows(lapply(root_dirs, build_model_rows)),
    root_signoff_summary = .qdesn_validation_bind_rows(lapply(root_dirs, build_root_rows))
  )
}

qdesn_dynamic_crossstudy_validate_reference_inventory <- function(reference_inventory, defaults) {
  contract <- defaults$reference_contract %||% list()
  root_summary <- reference_inventory$root_signoff_summary %||% data.frame(stringsAsFactors = FALSE)
  problems <- character(0)
  if (!nrow(root_summary)) {
    problems <- c(problems, "reference root_signoff_summary inventory is empty")
  } else {
    scenarios <- sort(unique(as.character(root_summary$scenario)))
    families <- sort(unique(as.character(root_summary$family)))
    taus <- sort(unique(as.numeric(root_summary$tau)))
    fit_sizes <- sort(unique(as.integer(root_summary$fit_size)))
    root_kinds <- sort(unique(as.character(root_summary$root_kind)))
    unique_cells <- unique(paste(root_summary$scenario, root_summary$family, root_summary$tau, root_summary$fit_size, sep = "||"))
    if (!identical(scenarios, sort(as.character(contract$scenarios %||% scenarios)))) {
      problems <- c(problems, sprintf("scenario set mismatch: %s", paste(scenarios, collapse = ", ")))
    }
    if (!identical(families, sort(as.character(contract$families %||% families)))) {
      problems <- c(problems, sprintf("family set mismatch: %s", paste(families, collapse = ", ")))
    }
    if (!identical(as.numeric(taus), sort(as.numeric(contract$taus %||% taus)))) {
      problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
    }
    if (!identical(as.integer(fit_sizes), sort(as.integer(contract$fit_sizes %||% fit_sizes)))) {
      problems <- c(problems, sprintf("fit_size set mismatch: %s", paste(fit_sizes, collapse = ", ")))
    }
    if (!identical(root_kinds, sort(as.character(contract$root_kind %||% root_kinds)))) {
      problems <- c(problems, sprintf("root_kind set mismatch: %s", paste(root_kinds, collapse = ", ")))
    }
    if (!is.null(contract$expected_reference_roots) &&
        !identical(nrow(root_summary), as.integer(contract$expected_reference_roots))) {
      problems <- c(problems, sprintf(
        "expected %d reference roots, found %d",
        as.integer(contract$expected_reference_roots), nrow(root_summary)
      ))
    }
    if (!is.null(contract$expected_unique_dataset_cells) &&
        !identical(length(unique_cells), as.integer(contract$expected_unique_dataset_cells))) {
      problems <- c(problems, sprintf(
        "expected %d unique dataset cells, found %d",
        as.integer(contract$expected_unique_dataset_cells), length(unique_cells)
      ))
    }
  }
  if (length(problems)) {
    stop(paste(c("Dynamic reference inventory validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    reference_root = reference_inventory$reference_root,
    reference_root_dirs_n = length(reference_inventory$root_dirs %||% character(0)),
    reference_root_rows_n = nrow(root_summary),
    reference_roots = nrow(root_summary),
    reference_unique_dataset_cells = if (nrow(root_summary)) length(unique(paste(root_summary$scenario, root_summary$family, root_summary$tau, root_summary$fit_size, sep = "||"))) else 0L,
    unique_dataset_cells = if (nrow(root_summary)) length(unique(paste(root_summary$scenario, root_summary$family, root_summary$tau, root_summary$fit_size, sep = "||"))) else 0L,
    scenarios = if (nrow(root_summary)) sort(unique(as.character(root_summary$scenario))) else character(0),
    families = if (nrow(root_summary)) sort(unique(as.character(root_summary$family))) else character(0),
    taus = if (nrow(root_summary)) sort(unique(as.numeric(root_summary$tau))) else numeric(0),
    fit_sizes = if (nrow(root_summary)) sort(unique(as.integer(root_summary$fit_size))) else integer(0),
    root_kinds = if (nrow(root_summary)) sort(unique(as.character(root_summary$root_kind))) else character(0)
  )
}

.qdesn_dynamic_crossstudy_context_sizes <- function(defaults) {
  external_cfg <- defaults$external_data %||% list()
  holdout_n <- as.integer(external_cfg$holdout_n %||% 1L)[1L]
  if (!is.finite(holdout_n) || holdout_n < 1L) holdout_n <- 1L

  lags_cfg <- defaults$lags %||% list()
  lags_y <- if (!is.null(lags_cfg$y)) {
    as.integer(unlist(lags_cfg$y, use.names = FALSE))
  } else {
    m_y <- as.integer(lags_cfg$m_y %||% 0L)[1L]
    if (is.finite(m_y) && m_y > 0L) seq_len(m_y) else integer(0)
  }
  lags_x <- if (!is.null(lags_cfg$x)) {
    as.integer(unlist(lags_cfg$x, use.names = FALSE))
  } else {
    m_x <- as.integer(lags_cfg$m_x %||% 0L)[1L]
    if (is.finite(m_x) && m_x > 0L) 0L:m_x else integer(0)
  }
  lag_max <- max(c(0L, lags_y, lags_x), na.rm = TRUE)

  reservoir_name <- as.character((defaults$pilot %||% list())$reservoir_profile %||% "tiny_d1_n8")[1L]
  washout <- as.integer((((defaults$reservoir_profiles %||% list())[[reservoir_name]] %||% list())$washout %||% 0L)[1L])
  if (!is.finite(washout) || washout < 0L) washout <- 0L

  list(
    holdout_n = as.integer(holdout_n),
    lag_max = as.integer(lag_max),
    washout = as.integer(washout)
  )
}

.qdesn_dynamic_crossstudy_required_source_total_size <- function(defaults, effective_fit_size) {
  sizes <- .qdesn_dynamic_crossstudy_context_sizes(defaults)
  as.integer(effective_fit_size) + sizes$holdout_n + sizes$lag_max + sizes$washout
}

.qdesn_dynamic_crossstudy_source_split_contract <- function(defaults,
                                                            effective_fit_size,
                                                            source_total_size,
                                                            source_index = NULL) {
  material_cfg <- defaults$source_materialization %||% list()
  sizes <- .qdesn_dynamic_crossstudy_context_sizes(defaults)
  effective_fit_size <- as.integer(effective_fit_size)[1L]
  source_total_size <- as.integer(source_total_size)[1L]
  train_end <- suppressWarnings(as.integer(
    material_cfg$train_end_source_index %||%
      material_cfg$forecast_origin_source_index %||%
      NA_integer_
  )[1L])

  source_index <- as.integer(source_index %||% integer(0))
  if ((!is.finite(train_end) || train_end < 1L) && length(source_index)) {
    source_end <- max(source_index, na.rm = TRUE)
    if (is.finite(source_end)) {
      train_end <- as.integer(source_end - sizes$holdout_n)
    }
  }

  expected_total <- .qdesn_dynamic_crossstudy_required_source_total_size(defaults, effective_fit_size)
  if (is.finite(source_total_size) && !identical(source_total_size, expected_total)) {
    stop(sprintf(
      "source_total_size=%d does not match expected total %d for effective_fit_size=%d.",
      source_total_size, expected_total, effective_fit_size
    ), call. = FALSE)
  }

  if (!is.finite(train_end) || train_end < 1L) {
    return(list(
      mode = "tail",
      effective_fit_size = effective_fit_size,
      source_total_size = source_total_size,
      holdout_n = sizes$holdout_n,
      lag_max = sizes$lag_max,
      washout = sizes$washout,
      raw_start_source_index = NA_integer_,
      raw_end_source_index = NA_integer_,
      train_start_source_index = NA_integer_,
      train_end_source_index = NA_integer_,
      forecast_start_source_index = NA_integer_,
      forecast_end_source_index = NA_integer_
    ))
  }

  train_start <- as.integer(train_end - effective_fit_size + 1L)
  forecast_start <- as.integer(train_end + 1L)
  forecast_end <- as.integer(train_end + sizes$holdout_n)
  raw_start <- as.integer(train_start - sizes$lag_max - sizes$washout)
  raw_end <- forecast_end
  if (raw_start < 1L) {
    stop(sprintf(
      "Source-index split requests raw_start_source_index=%d; increase source length or reduce washout/lags.",
      raw_start
    ), call. = FALSE)
  }
  if (length(source_index) && !all(seq.int(raw_start, raw_end) %in% source_index)) {
    stop(sprintf(
      "Full source is missing requested source-index range %d:%d.",
      raw_start, raw_end
    ), call. = FALSE)
  }

  list(
    mode = "source_index",
    effective_fit_size = effective_fit_size,
    source_total_size = expected_total,
    holdout_n = sizes$holdout_n,
    lag_max = sizes$lag_max,
    washout = sizes$washout,
    raw_start_source_index = raw_start,
    raw_end_source_index = raw_end,
    train_start_source_index = train_start,
    train_end_source_index = as.integer(train_end),
    forecast_start_source_index = forecast_start,
    forecast_end_source_index = forecast_end
  )
}

.qdesn_dynamic_crossstudy_materialization_windows <- function(defaults) {
  material_cfg <- defaults$source_materialization %||% list()
  windows <- material_cfg$windows %||% list()
  if (!length(windows)) {
    stop("Dynamic source materialization requires a non-empty source_materialization.windows list.", call. = FALSE)
  }
  out <- lapply(seq_along(windows), function(i) {
    win <- windows[[i]] %||% list()
    effective_fit_size <- as.integer(win$effective_fit_size %||% win$fit_size %||% NA_integer_)[1L]
    if (!is.finite(effective_fit_size) || effective_fit_size < 1L) {
      stop(sprintf("Materialization window %d is missing a valid effective_fit_size.", i), call. = FALSE)
    }
    required_total_size <- .qdesn_dynamic_crossstudy_required_source_total_size(defaults, effective_fit_size)
    source_total_size <- as.integer(win$source_total_size %||% win$total_size %||% required_total_size)[1L]
    if (!is.finite(source_total_size) || source_total_size < effective_fit_size) {
      stop(sprintf(
        "Materialization window %d is missing a valid source_total_size >= effective_fit_size.",
        i
      ), call. = FALSE)
    }
    if (isTRUE(material_cfg$enforce_effective_train_size %||% TRUE) &&
        !identical(as.integer(source_total_size), as.integer(required_total_size))) {
      stop(sprintf(
        paste0(
          "Materialization window %d has source_total_size=%d, but the current split contract requires %d ",
          "to preserve effective post-washout train size %d ",
          "(holdout_n + lag_max + washout are part of the contract)."
        ),
        i, source_total_size, required_total_size, effective_fit_size
      ), call. = FALSE)
    }
    list(
      effective_fit_size = effective_fit_size,
      source_total_size = source_total_size,
      split_contract = .qdesn_dynamic_crossstudy_source_split_contract(defaults, effective_fit_size, source_total_size),
      source_dir_name = as.character(
        win$source_dir_name %||% sprintf("fit_input_effTT%d_totalTT%d", effective_fit_size, source_total_size)
      )[1L],
      label = as.character(
        win$label %||% sprintf("effTT%d_totalTT%d", effective_fit_size, source_total_size)
      )[1L]
    )
  })
  names(out) <- vapply(out, `[[`, character(1), "label")
  out
}

.qdesn_dynamic_crossstudy_load_source_sim_object <- function(family_root,
                                                             tau,
                                                             series_df = NULL) {
  family_root <- .qdesn_validation_resolve_path(family_root, must_work = TRUE)
  if (is.null(series_df)) {
    series_path <- file.path(family_root, "series_wide.csv")
    if (!file.exists(series_path)) {
      stop(sprintf("Missing full-source series_wide.csv for %s.", family_root), call. = FALSE)
    }
    series_df <- utils::read.csv(series_path, stringsAsFactors = FALSE)
  }
  if (!nrow(series_df)) {
    stop(sprintf("Full-source series_wide.csv is empty: %s", family_root), call. = FALSE)
  }

  sim_path <- file.path(family_root, "sim_output.rds")
  if (file.exists(sim_path)) {
    sim_obj <- readRDS(sim_path)
    q_mat <- as.matrix(sim_obj$q %||% matrix(numeric(0), 0L, 0L))
    y_vec <- as.numeric(sim_obj$y %||% numeric(0))
    if (length(y_vec) && nrow(q_mat)) {
      return(sim_obj)
    }
  }

  truth_path <- file.path(family_root, "true_quantile_grid.csv")
  if (!file.exists(truth_path)) {
    stop(sprintf(
      "Missing both sim_output.rds and true_quantile_grid.csv for %s.",
      family_root
    ), call. = FALSE)
  }
  truth_df <- utils::read.csv(truth_path, stringsAsFactors = FALSE)
  q_col <- if ("q_true" %in% names(truth_df)) {
    "q_true"
  } else if ("q_target" %in% names(truth_df)) {
    "q_target"
  } else {
    NA_character_
  }
  if (!nzchar(q_col) || !nrow(truth_df)) {
    stop(sprintf("Fallback truth grid is missing a usable quantile column for %s.", family_root), call. = FALSE)
  }

  q_true <- if ("t" %in% names(series_df) && "t" %in% names(truth_df)) {
    idx <- match(series_df$t, truth_df$t)
    if (anyNA(idx)) {
      stop(sprintf("Fallback truth grid is missing t values needed for %s.", family_root), call. = FALSE)
    }
    as.numeric(truth_df[[q_col]][idx])
  } else {
    if (!identical(nrow(series_df), nrow(truth_df))) {
      stop(sprintf(
        "Fallback truth grid row count mismatch for %s: series=%d truth=%d.",
        family_root,
        nrow(series_df),
        nrow(truth_df)
      ), call. = FALSE)
    }
    as.numeric(truth_df[[q_col]])
  }

  list(
    y = as.numeric(series_df$y %||% numeric(0)),
    q = matrix(q_true, ncol = 1L),
    p = as.numeric(tau)[1L],
    info = list(
      scenario = "dynamic_dlm_family_qspec",
      quantile_target = as.numeric(tau)[1L],
      quantile_truth_method = "true_quantile_grid_csv_fallback",
      source_root = family_root
    ),
    extras = list(
      source_index = if ("t" %in% names(series_df)) as.integer(series_df$t) else seq_len(nrow(series_df)),
      reconstructed_from = "series_wide_and_true_quantile_grid"
    )
  )
}

.qdesn_dynamic_crossstudy_slice_sim_output <- function(sim_obj,
                                                       idx,
                                                       source_root,
                                                       target_n,
                                                       effective_fit_size,
                                                       washout,
                                                       source_index = NULL,
                                                       split_contract = NULL) {
  idx <- as.integer(idx)
  source_index <- as.integer(source_index %||% idx)
  y <- as.numeric(sim_obj$y %||% numeric(0))
  q <- as.matrix(sim_obj$q %||% matrix(numeric(0), 0L, 0L))
  if (!length(y) || !nrow(q)) {
    stop("Materialized dynamic source requires sim_output.rds entries y and q.", call. = FALSE)
  }
  if (length(y) < max(idx) || nrow(q) < max(idx)) {
    stop("Materialized dynamic source slice exceeds source sim_output length.", call. = FALSE)
  }

  info <- sim_obj$info %||% list()
  params <- info$params %||% list()
  params$TT <- as.integer(target_n)
  params$TT_effective <- as.integer(effective_fit_size)
  params$washout <- as.integer(washout)
  params$TT_warmup <- as.integer(length(y) - target_n)
  info$params <- params
  info$subsample <- list(
    source_root = as.character(source_root),
    source_n = as.integer(length(y)),
    target_n = as.integer(target_n),
    effective_target_n = as.integer(effective_fit_size),
    washout = as.integer(washout),
    selection_method = as.character((split_contract %||% list())$mode %||% "last_T"),
    sorted_by = "time"
  )

  list(
    y = y[idx],
    q = q[idx, , drop = FALSE],
    p = sim_obj$p %||% NA_real_,
    info = info,
    extras = list(
      source_index = source_index,
      materialized_for = "qdesn_dynamic_effective_fit_validation"
    )
  )
}

qdesn_dynamic_crossstudy_materialize_source_inputs <- function(defaults,
                                                               refresh = FALSE,
                                                               verbose = FALSE) {
  material_cfg <- defaults$source_materialization %||% list()
  source_root <- .qdesn_validation_resolve_path(material_cfg$dynamic_root, must_work = TRUE)
  staged_root <- .qdesn_validation_resolve_path(material_cfg$staged_root, must_work = FALSE)
  inventory_path <- file.path(staged_root, "materialized_source_inventory.csv")
  scenario_set <- as.character(material_cfg$scenarios %||% (defaults$reference_contract %||% list())$scenarios)
  family_set <- as.character(material_cfg$families %||% (defaults$reference_contract %||% list())$families)
  tau_set <- as.numeric(material_cfg$taus %||% (defaults$reference_contract %||% list())$taus)
  windows <- .qdesn_dynamic_crossstudy_materialization_windows(defaults)
  reservoir_name <- as.character((defaults$pilot %||% list())$reservoir_profile %||% "tiny_d1_n8")[1L]
  washout <- as.integer((((defaults$reservoir_profiles %||% list())[[reservoir_name]] %||% list())$washout %||% 0L)[1L])

  if (!isTRUE(refresh) && file.exists(inventory_path)) {
    inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE)
    required_cols <- c(
      "source_scenario",
      "source_family",
      "tau",
      "fit_size",
      "effective_fit_size",
      "source_total_size",
      "source_window_label",
      "source_fit_input_dir",
      "source_report_root",
      "source_series_wide_path",
      "source_selection_indices_path",
      "source_sim_path",
      "source_series_wide_sha256",
      "source_selection_indices_sha256",
      "source_sim_sha256"
    )
    if (nrow(inventory) && all(required_cols %in% names(inventory))) {
      return(.qdesn_dynamic_crossstudy_rewrite_paths(inventory, defaults))
    }
  }

  if (!length(scenario_set) || !length(family_set) || !length(tau_set)) {
    stop("Dynamic source materialization requires non-empty scenarios, families, and taus.", call. = FALSE)
  }

  .qdesn_validation_dir_create(staged_root)
  rows <- list()

  for (scenario in sort(unique(scenario_set))) {
    for (family in sort(unique(family_set))) {
      for (tau in sort(unique(tau_set))) {
        tau_dir <- sprintf("tau_%s", .qdesn_dynamic_crossstudy_prob_label(tau))
        family_root <- file.path(source_root, scenario, family, tau_dir)
        series_path <- file.path(family_root, "series_wide.csv")
        if (!file.exists(series_path)) {
          stop(sprintf("Missing full-source series_wide.csv for %s / %s / tau=%s.", scenario, family, as.character(tau)), call. = FALSE)
        }

        series_df <- utils::read.csv(series_path, stringsAsFactors = FALSE)
        if (!nrow(series_df)) {
          stop(sprintf("Full-source series_wide.csv is empty: %s", series_path), call. = FALSE)
        }
        full_source_index <- if ("t" %in% names(series_df)) as.integer(series_df$t) else seq_len(nrow(series_df))
        sim_obj <- .qdesn_dynamic_crossstudy_load_source_sim_object(
          family_root = family_root,
          tau = tau,
          series_df = series_df
        )

        for (win in windows) {
          total_n <- as.integer(win$source_total_size)
          effective_fit_size <- as.integer(win$effective_fit_size)
          if (nrow(series_df) < total_n) {
            stop(sprintf(
              "Full-source length %d is smaller than requested source_total_size=%d for %s / %s / tau=%s.",
              nrow(series_df), total_n, scenario, family, as.character(tau)
            ), call. = FALSE)
          }
          split_contract <- .qdesn_dynamic_crossstudy_source_split_contract(
            defaults = defaults,
            effective_fit_size = effective_fit_size,
            source_total_size = total_n,
            source_index = full_source_index
          )
          idx_source <- if (identical(split_contract$mode, "source_index")) {
            seq.int(split_contract$raw_start_source_index, split_contract$raw_end_source_index)
          } else {
            full_source_index[seq.int(nrow(series_df) - total_n + 1L, nrow(series_df))]
          }
          idx <- match(idx_source, full_source_index)
          if (anyNA(idx)) {
            stop(sprintf(
              "Full-source series for %s / %s / tau=%s is missing requested source indices %s.",
              scenario, family, as.character(tau), paste(idx_source[is.na(idx)], collapse = ", ")
            ), call. = FALSE)
          }
          stage_dir <- file.path(staged_root, scenario, family, tau_dir, win$source_dir_name)
          if (isTRUE(refresh) && dir.exists(stage_dir)) {
            unlink(stage_dir, recursive = TRUE, force = TRUE)
          }
          .qdesn_validation_dir_create(stage_dir)

          stage_series_path <- file.path(stage_dir, "series_wide.csv")
          stage_selection_path <- file.path(stage_dir, "selection_indices.csv")
          stage_sim_path <- file.path(stage_dir, "sim_output.rds")
          stage_meta_path <- file.path(stage_dir, "materialization_metadata.json")

          if (isTRUE(refresh) || !file.exists(stage_series_path) || !file.exists(stage_selection_path) || !file.exists(stage_sim_path)) {
            sliced_df <- series_df[idx, , drop = FALSE]
            source_index <- idx_source
            split_role <- rep("pretrain_context", length(source_index))
            split_role[source_index >= split_contract$train_start_source_index &
                         source_index <= split_contract$train_end_source_index] <- "train"
            split_role[source_index >= split_contract$forecast_start_source_index &
                         source_index <= split_contract$forecast_end_source_index] <- "forecast"
            selection_df <- data.frame(
              t = seq_len(nrow(sliced_df)),
              source_index = source_index,
              split_role = split_role,
              effective_train = split_role == "train",
              forecast_eval = split_role == "forecast",
              stringsAsFactors = FALSE
            )
            utils::write.csv(sliced_df, stage_series_path, row.names = FALSE)
            utils::write.csv(selection_df, stage_selection_path, row.names = FALSE)
            saveRDS(
              .qdesn_dynamic_crossstudy_slice_sim_output(
                sim_obj = sim_obj,
                idx = idx,
                source_root = family_root,
                target_n = total_n,
                effective_fit_size = effective_fit_size,
                washout = washout,
                source_index = source_index,
                split_contract = split_contract
              ),
              stage_sim_path
            )
            .qdesn_validation_write_json(stage_meta_path, list(
              generated_at = as.character(Sys.time()),
              source_root = family_root,
              scenario = scenario,
              family = family,
              tau = as.numeric(tau),
              source_total_size = total_n,
              effective_fit_size = effective_fit_size,
              washout = washout,
              lag_max = split_contract$lag_max,
              source_dir_name = win$source_dir_name,
              split_contract_mode = split_contract$mode,
              source_index_first = source_index[1L],
              source_index_last = source_index[length(source_index)],
              raw_start_source_index = split_contract$raw_start_source_index,
              raw_end_source_index = split_contract$raw_end_source_index,
              train_start_source_index = split_contract$train_start_source_index,
              train_end_source_index = split_contract$train_end_source_index,
              forecast_start_source_index = split_contract$forecast_start_source_index,
              forecast_end_source_index = split_contract$forecast_end_source_index
            ))
          }

          rows[[length(rows) + 1L]] <- data.frame(
            source_scenario = scenario,
            source_family = family,
            tau = as.numeric(tau),
            fit_size = effective_fit_size,
            effective_fit_size = effective_fit_size,
            source_total_size = total_n,
            source_window_label = as.character(win$label),
            raw_start_source_index = as.integer(split_contract$raw_start_source_index),
            raw_end_source_index = as.integer(split_contract$raw_end_source_index),
            train_start_source_index = as.integer(split_contract$train_start_source_index),
            train_end_source_index = as.integer(split_contract$train_end_source_index),
            forecast_start_source_index = as.integer(split_contract$forecast_start_source_index),
            forecast_end_source_index = as.integer(split_contract$forecast_end_source_index),
            lag_max = as.integer(split_contract$lag_max),
            washout = as.integer(split_contract$washout),
            holdout_n = as.integer(split_contract$holdout_n),
            source_fit_input_dir = normalizePath(stage_dir, winslash = "/", mustWork = TRUE),
            source_report_root = normalizePath(stage_dir, winslash = "/", mustWork = TRUE),
            source_series_wide_path = normalizePath(stage_series_path, winslash = "/", mustWork = TRUE),
            source_series_wide_sha256 = .qdesn_validation_sha256(stage_series_path),
            source_series_wide_md5 = .qdesn_validation_md5(stage_series_path),
            source_selection_indices_path = normalizePath(stage_selection_path, winslash = "/", mustWork = TRUE),
            source_selection_indices_sha256 = .qdesn_validation_sha256(stage_selection_path),
            source_selection_indices_md5 = .qdesn_validation_md5(stage_selection_path),
            source_sim_path = normalizePath(stage_sim_path, winslash = "/", mustWork = TRUE),
            source_sim_sha256 = .qdesn_validation_sha256(stage_sim_path),
            source_sim_md5 = .qdesn_validation_md5(stage_sim_path),
            stringsAsFactors = FALSE
          )

          if (isTRUE(verbose)) {
            message(sprintf(
              "[dynamic-source-materialize] %s / %s / tau=%.2f / eff=%d / total=%d -> %s",
              scenario, family, as.numeric(tau), effective_fit_size, total_n, stage_dir
            ))
          }
        }
      }
    }
  }

  inventory <- .qdesn_validation_bind_rows(rows)
  inventory <- inventory[order(inventory$source_scenario, inventory$source_family, inventory$tau, inventory$fit_size), , drop = FALSE]
  .qdesn_validation_write_df(inventory, inventory_path)
  .qdesn_validation_write_json(file.path(staged_root, "materialized_source_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    source_root = source_root,
    staged_root = staged_root,
    scenarios = sort(unique(as.character(inventory$source_scenario))),
    families = sort(unique(as.character(inventory$source_family))),
    taus = sort(unique(as.numeric(inventory$tau))),
    effective_fit_sizes = sort(unique(as.integer(inventory$fit_size))),
    source_total_sizes = sort(unique(as.integer(inventory$source_total_size))),
    n_materialized_cells = nrow(inventory),
    source_hash_columns = c("source_series_wide_sha256", "source_selection_indices_sha256", "source_sim_sha256")
  ))
  inventory
}

qdesn_dynamic_fitforecast_verify_source_windows <- function(inventory,
                                                            expected_train_end = NULL,
                                                            expected_forecast_end = NULL,
                                                            stop_on_fail = TRUE) {
  if (is.character(inventory) && length(inventory) == 1L) {
    inventory <- utils::read.csv(.qdesn_validation_resolve_path(inventory, must_work = TRUE), stringsAsFactors = FALSE)
  }
  inventory <- as.data.frame(inventory, stringsAsFactors = FALSE)
  if (!nrow(inventory)) {
    stop("Source-window verification requires a non-empty materialized source inventory.", call. = FALSE)
  }
  required_cols <- c(
    "source_selection_indices_path",
    "effective_fit_size",
    "holdout_n",
    "train_start_source_index",
    "train_end_source_index",
    "forecast_start_source_index",
    "forecast_end_source_index"
  )
  missing_cols <- setdiff(required_cols, names(inventory))
  if (length(missing_cols)) {
    stop(sprintf("Materialized source inventory is missing required column(s): %s.", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  expected_train_end <- suppressWarnings(as.integer(expected_train_end %||% NA_integer_)[1L])
  expected_forecast_end <- suppressWarnings(as.integer(expected_forecast_end %||% NA_integer_)[1L])
  rows <- lapply(seq_len(nrow(inventory)), function(i) {
    cell <- inventory[i, , drop = FALSE]
    selection_path <- as.character(cell$source_selection_indices_path[1L])
    status <- "PASS"
    reasons <- character(0)
    sel <- tryCatch(utils::read.csv(selection_path, stringsAsFactors = FALSE), error = function(e) {
      reasons <<- c(reasons, sprintf("selection_read_error:%s", conditionMessage(e)))
      NULL
    })
    if (is.null(sel)) {
      status <- "FAIL"
      sel <- data.frame(source_index = integer(0), split_role = character(0), stringsAsFactors = FALSE)
    }
    if (!("source_index" %in% names(sel))) {
      status <- "FAIL"
      reasons <- c(reasons, "missing_source_index")
      sel$source_index <- integer(0)
    }
    if (!("split_role" %in% names(sel))) {
      status <- "FAIL"
      reasons <- c(reasons, "missing_split_role")
      sel$split_role <- rep(NA_character_, nrow(sel))
    }
    source_index <- as.integer(sel$source_index)
    train_idx <- source_index[as.character(sel$split_role) == "train"]
    forecast_idx <- source_index[as.character(sel$split_role) == "forecast"]
    train_start <- as.integer(cell$train_start_source_index[1L])
    train_end <- as.integer(cell$train_end_source_index[1L])
    forecast_start <- as.integer(cell$forecast_start_source_index[1L])
    forecast_end <- as.integer(cell$forecast_end_source_index[1L])
    effective_fit_size <- as.integer(cell$effective_fit_size[1L])
    holdout_n <- as.integer(cell$holdout_n[1L])

    if (!identical(train_idx, seq.int(train_start, train_end))) {
      status <- "FAIL"
      reasons <- c(reasons, "train_indices_not_contiguous_or_mismatched")
    }
    if (!identical(forecast_idx, seq.int(forecast_start, forecast_end))) {
      status <- "FAIL"
      reasons <- c(reasons, "forecast_indices_not_contiguous_or_mismatched")
    }
    if (length(train_idx) != effective_fit_size) {
      status <- "FAIL"
      reasons <- c(reasons, sprintf("train_n_%d_expected_%d", length(train_idx), effective_fit_size))
    }
    if (length(forecast_idx) != holdout_n) {
      status <- "FAIL"
      reasons <- c(reasons, sprintf("forecast_n_%d_expected_%d", length(forecast_idx), holdout_n))
    }
    if (is.finite(expected_train_end) && train_end != expected_train_end) {
      status <- "FAIL"
      reasons <- c(reasons, sprintf("train_end_%d_expected_%d", train_end, expected_train_end))
    }
    if (is.finite(expected_forecast_end) && forecast_end != expected_forecast_end) {
      status <- "FAIL"
      reasons <- c(reasons, sprintf("forecast_end_%d_expected_%d", forecast_end, expected_forecast_end))
    }

    data.frame(
      row_id = i,
      source_scenario = as.character(cell$source_scenario[1L] %||% NA_character_),
      source_family = as.character(cell$source_family[1L] %||% NA_character_),
      tau = as.numeric(cell$tau[1L] %||% NA_real_),
      fit_size = effective_fit_size,
      status = status,
      reason = if (length(reasons)) paste(unique(reasons), collapse = ";") else "ok",
      train_start_source_index = train_start,
      train_end_source_index = train_end,
      forecast_start_source_index = forecast_start,
      forecast_end_source_index = forecast_end,
      train_n = length(train_idx),
      forecast_n = length(forecast_idx),
      selection_indices_path = selection_path,
      stringsAsFactors = FALSE
    )
  })

  out <- .qdesn_validation_bind_rows(rows)
  if (isTRUE(stop_on_fail) && any(as.character(out$status) != "PASS")) {
    stop(sprintf(
      "Source-window verification failed for %d row(s).",
      sum(as.character(out$status) != "PASS")
    ), call. = FALSE)
  }
  out
}

qdesn_dynamic_crossstudy_build_grid_from_materialized_sources <- function(defaults,
                                                                          materialized_inventory = NULL) {
  pilot_cfg <- defaults$pilot %||% list()
  seed_policy_cfg <- ((defaults$execution %||% list())$seed_policy) %||% list()
  if (is.null(materialized_inventory)) {
    materialized_inventory <- qdesn_dynamic_crossstudy_materialize_source_inputs(defaults, refresh = FALSE, verbose = FALSE)
  }
  if (!nrow(materialized_inventory)) {
    stop("Materialized dynamic source inventory is empty.", call. = FALSE)
  }

  rows <- list()
  for (i in seq_len(nrow(materialized_inventory))) {
    cell <- materialized_inventory[i, , drop = FALSE]
    dataset_cell_id <- sprintf(
      "dynamic__%s__%s__tau_%s__efftt_%s",
      as.character(cell$source_scenario[1L]),
      as.character(cell$source_family[1L]),
      .qdesn_dynamic_crossstudy_prob_label(cell$tau[1L]),
      as.integer(cell$fit_size[1L])
    )
    for (beta_prior_type in c("ridge", "rhs_ns")) {
      root_seed <- as.integer(pilot_cfg$seed %||% 123L)[1L]
      if (identical(tolower(as.character(seed_policy_cfg$mode %||% "shared")[1L]), "deterministic_per_root")) {
        family_levels <- as.character((defaults$reference_contract %||% list())$families %||% sort(unique(as.character(materialized_inventory$source_family))))
        tau_levels <- as.numeric((defaults$reference_contract %||% list())$taus %||% sort(unique(as.numeric(materialized_inventory$tau))))
        fit_levels <- as.integer((defaults$reference_contract %||% list())$fit_sizes %||% sort(unique(as.integer(materialized_inventory$fit_size))))
        family_idx <- match(as.character(cell$source_family[1L]), family_levels)
        tau_idx <- match(as.numeric(cell$tau[1L]), tau_levels)
        fit_idx <- match(as.integer(cell$fit_size[1L]), fit_levels)
        prior_idx <- match(beta_prior_type, c("ridge", "rhs_ns"))
        root_seed <- as.integer(seed_policy_cfg$base_seed %||% 41000L)[1L] +
          10000L * (family_idx - 1L) +
          1000L * (tau_idx - 1L) +
          100L * (fit_idx - 1L) +
          10L * (prior_idx - 1L)
      }
      row <- data.frame(
        enabled = TRUE,
        dataset_cell_id = dataset_cell_id,
        source_root_kind = "dynamic",
        source_scenario = as.character(cell$source_scenario[1L]),
        source_family = as.character(cell$source_family[1L]),
        tau = as.numeric(cell$tau[1L]),
        fit_size = as.integer(cell$fit_size[1L]),
        effective_fit_size = as.integer(cell$effective_fit_size[1L] %||% cell$fit_size[1L]),
        source_total_size = as.integer(cell$source_total_size[1L]),
        source_window_label = as.character(cell$source_window_label[1L]),
        raw_start_source_index = as.integer(cell$raw_start_source_index[1L] %||% NA_integer_),
        raw_end_source_index = as.integer(cell$raw_end_source_index[1L] %||% NA_integer_),
        train_start_source_index = as.integer(cell$train_start_source_index[1L] %||% NA_integer_),
        train_end_source_index = as.integer(cell$train_end_source_index[1L] %||% NA_integer_),
        forecast_start_source_index = as.integer(cell$forecast_start_source_index[1L] %||% NA_integer_),
        forecast_end_source_index = as.integer(cell$forecast_end_source_index[1L] %||% NA_integer_),
        beta_prior_type = beta_prior_type,
        source_fit_input_dir = as.character(cell$source_fit_input_dir[1L]),
        source_report_root = as.character(cell$source_report_root[1L]),
        source_series_wide_path = as.character(cell$source_series_wide_path[1L]),
        source_series_wide_sha256 = as.character(cell$source_series_wide_sha256[1L] %||% NA_character_),
        source_series_wide_md5 = as.character(cell$source_series_wide_md5[1L] %||% NA_character_),
        source_selection_indices_path = as.character(cell$source_selection_indices_path[1L]),
        source_selection_indices_sha256 = as.character(cell$source_selection_indices_sha256[1L] %||% NA_character_),
        source_selection_indices_md5 = as.character(cell$source_selection_indices_md5[1L] %||% NA_character_),
        source_sim_path = as.character(cell$source_sim_path[1L]),
        source_sim_sha256 = as.character(cell$source_sim_sha256[1L] %||% NA_character_),
        source_sim_md5 = as.character(cell$source_sim_md5[1L] %||% NA_character_),
        source_reference_root_count = 1L,
        source_reference_priors = "default",
        source_current_rhsns_member = FALSE,
        source_legacy_rhs_member = FALSE,
        reservoir_profile = as.character(pilot_cfg$reservoir_profile %||% "tiny_d1_n8"),
        seed = root_seed,
        stringsAsFactors = FALSE
      )
      row$root_id <- qdesn_dynamic_crossstudy_build_root_id(row)
      rows[[length(rows) + 1L]] <- row
    }
  }
  .qdesn_validation_bind_rows(rows)
}
qdesn_dynamic_crossstudy_build_root_id <- function(root_spec) {
  sprintf(
    "root__dynamic__%s__%s__tau_%s__lasttt_%s__qdesn_%s",
    as.character(root_spec$source_scenario)[1L],
    as.character(root_spec$source_family)[1L],
    .qdesn_dynamic_crossstudy_prob_label(root_spec$tau),
    as.integer(root_spec$fit_size)[1L],
    as.character(root_spec$beta_prior_type)[1L]
  )
}

qdesn_dynamic_crossstudy_build_grid_from_reference <- function(defaults) {
  reference_cfg <- defaults$reference %||% list()
  reference_root <- .qdesn_validation_resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
  reference_inventory <- qdesn_dynamic_crossstudy_collect_reference_inventory(reference_root)
  qdesn_dynamic_crossstudy_validate_reference_inventory(reference_inventory, defaults)
  pilot_cfg <- defaults$pilot %||% list()

  cells <- unique(reference_inventory$cell_inventory[, c(
    "scenario", "root_kind", "family", "tau", "fit_size",
    "fit_input_dir", "root_dir", "series_wide_path", "selection_indices_path", "sim_path"
  ), drop = FALSE])
  cells <- cells[order(cells$scenario, cells$family, cells$tau, cells$fit_size), , drop = FALSE]

  rows <- list()
  for (i in seq_len(nrow(cells))) {
    cell <- cells[i, , drop = FALSE]
    dataset_cell_id <- sprintf(
      "dynamic__%s__%s__tau_%s__lasttt_%s",
      as.character(cell$scenario[1L]),
      as.character(cell$family[1L]),
      .qdesn_dynamic_crossstudy_prob_label(cell$tau[1L]),
      as.integer(cell$fit_size[1L])
    )
    for (beta_prior_type in c("ridge", "rhs_ns")) {
      row <- data.frame(
        enabled = TRUE,
        dataset_cell_id = dataset_cell_id,
        source_root_kind = "dynamic",
        source_scenario = as.character(cell$scenario[1L]),
        source_family = as.character(cell$family[1L]),
        tau = as.numeric(cell$tau[1L]),
        fit_size = as.integer(cell$fit_size[1L]),
        effective_fit_size = as.integer(cell$fit_size[1L]),
        source_total_size = as.integer(cell$fit_size[1L]),
        source_window_label = as.character(sprintf("lastTT%d", as.integer(cell$fit_size[1L]))),
        beta_prior_type = beta_prior_type,
        source_fit_input_dir = as.character(cell$fit_input_dir[1L]),
        source_report_root = as.character(cell$root_dir[1L]),
        source_series_wide_path = as.character(cell$series_wide_path[1L]),
        source_selection_indices_path = as.character(cell$selection_indices_path[1L]),
        source_sim_path = as.character(cell$sim_path[1L]),
        source_reference_root_count = 1L,
        source_reference_priors = "default",
        source_current_rhsns_member = FALSE,
        source_legacy_rhs_member = FALSE,
        reservoir_profile = as.character(pilot_cfg$reservoir_profile %||% "tiny_d1_n8"),
        seed = as.integer(pilot_cfg$seed %||% 123L),
        stringsAsFactors = FALSE
      )
      row$root_id <- qdesn_dynamic_crossstudy_build_root_id(row)
      rows[[length(rows) + 1L]] <- row
    }
  }
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_crossstudy_build_grid <- function(defaults,
                                                refresh_materialized = FALSE,
                                                verbose = FALSE) {
  mode <- .qdesn_dynamic_crossstudy_grid_source_mode(defaults)
  if (identical(mode, "materialized_source_inputs")) {
    materialized_inventory <- qdesn_dynamic_crossstudy_materialize_source_inputs(
      defaults = defaults,
      refresh = refresh_materialized,
      verbose = verbose
    )
    return(qdesn_dynamic_crossstudy_build_grid_from_materialized_sources(
      defaults = defaults,
      materialized_inventory = materialized_inventory
    ))
  }
  qdesn_dynamic_crossstudy_build_grid_from_reference(defaults)
}

qdesn_dynamic_crossstudy_validate_grid <- function(grid_df, defaults, allow_subset = FALSE) {
  contract <- defaults$reference_contract %||% list()
  problems <- character(0)
  enabled <- if ("enabled" %in% names(grid_df)) {
    tolower(as.character(grid_df$enabled)) %in% c("true", "1", "t", "yes", "y")
  } else {
    rep(TRUE, nrow(grid_df))
  }
  grid_df <- grid_df[enabled, , drop = FALSE]
  if (!nrow(grid_df)) {
    stop("Dynamic cross-study grid has no enabled rows.", call. = FALSE)
  }
  scenarios <- sort(unique(as.character(grid_df$source_scenario)))
  families <- sort(unique(as.character(grid_df$source_family)))
  taus <- sort(unique(as.numeric(grid_df$tau)))
  fit_sizes <- sort(unique(as.integer(grid_df$fit_size)))
  root_kinds <- sort(unique(as.character(grid_df$source_root_kind)))
  priors <- sort(unique(as.character(grid_df$beta_prior_type)))
  unique_cells <- unique(as.character(grid_df$dataset_cell_id))

  if (!isTRUE(allow_subset) && !identical(scenarios, sort(as.character(contract$scenarios %||% scenarios)))) {
    problems <- c(problems, sprintf("scenario set mismatch: %s", paste(scenarios, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !identical(families, sort(as.character(contract$families %||% families)))) {
    problems <- c(problems, sprintf("family set mismatch: %s", paste(families, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !identical(as.numeric(taus), sort(as.numeric(contract$taus %||% taus)))) {
    problems <- c(problems, sprintf("tau set mismatch: %s", paste(taus, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !identical(as.integer(fit_sizes), sort(as.integer(contract$fit_sizes %||% fit_sizes)))) {
    problems <- c(problems, sprintf("fit_size set mismatch: %s", paste(fit_sizes, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !identical(root_kinds, sort(as.character(contract$root_kind %||% root_kinds)))) {
    problems <- c(problems, sprintf("root_kind set mismatch: %s", paste(root_kinds, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !identical(priors, sort(as.character(contract$expected_priors %||% priors)))) {
    problems <- c(problems, sprintf("beta_prior_type set mismatch: %s", paste(priors, collapse = ", ")))
  }
  if (!isTRUE(allow_subset) && !is.null(contract$expected_unique_dataset_cells) &&
      !identical(length(unique_cells), as.integer(contract$expected_unique_dataset_cells))) {
    problems <- c(problems, sprintf(
      "expected %d unique dataset cells, found %d",
      as.integer(contract$expected_unique_dataset_cells), length(unique_cells)
    ))
  }
  if (!isTRUE(allow_subset) && !is.null(contract$expected_qdesn_roots) &&
      !identical(nrow(grid_df), as.integer(contract$expected_qdesn_roots))) {
    problems <- c(problems, sprintf(
      "expected %d QDESN roots, found %d",
      as.integer(contract$expected_qdesn_roots), nrow(grid_df)
    ))
  }
  if (length(problems)) {
    stop(paste(c("Dynamic cross-study grid validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  list(
    enabled_roots = nrow(grid_df),
    unique_dataset_cells = length(unique_cells),
    scenarios = scenarios,
    families = families,
    taus = taus,
    fit_sizes = fit_sizes,
    root_kinds = root_kinds,
    priors = priors
  )
}

qdesn_dynamic_crossstudy_enrich_root_spec <- function(root_spec, defaults) {
  pilot_cfg <- defaults$pilot %||% list()
  contract <- defaults$reference_contract %||% list()
  source_root_kind <- as.character(root_spec$source_root_kind %||% pilot_cfg$source_root_kind %||% "dynamic")[1L]
  source_scenario <- as.character(root_spec$source_scenario %||% pilot_cfg$source_scenario %||% NA_character_)[1L]
  source_family <- as.character(root_spec$source_family %||% pilot_cfg$source_family %||% NA_character_)[1L]
  tau <- as.numeric(root_spec$tau %||% pilot_cfg$tau %||% NA_real_)[1L]
  fit_size <- as.integer(root_spec$fit_size %||% pilot_cfg$fit_size %||% NA_integer_)[1L]
  effective_fit_size <- as.integer(root_spec$effective_fit_size %||% fit_size)[1L]
  source_total_size <- as.integer(root_spec$source_total_size %||% effective_fit_size)[1L]
  source_window_label <- as.character(root_spec$source_window_label %||% sprintf("lastTT%s", as.character(source_total_size)))[1L]
  beta_prior_type <- tolower(as.character(root_spec$beta_prior_type %||% pilot_cfg$beta_prior_type %||% "rhs_ns")[1L])
  source_fit_input_dir <- .qdesn_validation_resolve_path(root_spec$source_fit_input_dir %||% pilot_cfg$source_fit_input_dir, must_work = TRUE)
  source_report_root <- .qdesn_validation_resolve_path(root_spec$source_report_root %||% pilot_cfg$source_report_root, must_work = TRUE)
  source_series_wide_path <- .qdesn_validation_resolve_path(root_spec$source_series_wide_path %||% pilot_cfg$source_series_wide_path, must_work = TRUE)
  source_selection_indices_path <- .qdesn_validation_resolve_path(root_spec$source_selection_indices_path %||% pilot_cfg$source_selection_indices_path, must_work = TRUE)
  source_sim_path <- .qdesn_validation_resolve_path(root_spec$source_sim_path %||% pilot_cfg$source_sim_path, must_work = TRUE)
  reservoir_profile <- as.character(root_spec$reservoir_profile %||% pilot_cfg$reservoir_profile %||% "tiny_d1_n8")[1L]
  enabled <- .qdesn_validation_as_flag(root_spec$enabled %||% pilot_cfg$enabled, default = TRUE)
  reference_root_count <- as.integer(root_spec$source_reference_root_count %||% pilot_cfg$source_reference_root_count %||% 1L)[1L]
  reference_priors <- as.character(root_spec$source_reference_priors %||% pilot_cfg$source_reference_priors %||% "default")[1L]
  current_member <- .qdesn_validation_as_flag(root_spec$source_current_rhsns_member %||% FALSE, default = FALSE)
  legacy_member <- .qdesn_validation_as_flag(root_spec$source_legacy_rhs_member %||% FALSE, default = FALSE)

  problems <- character(0)
  if (!identical(source_root_kind, as.character(contract$root_kind %||% "dynamic")[1L])) {
    problems <- c(problems, sprintf("unsupported source_root_kind '%s'", source_root_kind))
  }
  if (!source_scenario %in% as.character(contract$scenarios %||% source_scenario)) {
    problems <- c(problems, sprintf("unsupported source_scenario '%s'", source_scenario))
  }
  if (!source_family %in% as.character(contract$families %||% source_family)) {
    problems <- c(problems, sprintf("unsupported source_family '%s'", source_family))
  }
  if (!is.finite(tau) || !tau %in% as.numeric(contract$taus %||% tau)) {
    problems <- c(problems, sprintf("unsupported tau '%s'", as.character(tau)))
  }
  if (!is.finite(fit_size) || !fit_size %in% as.integer(contract$fit_sizes %||% fit_size)) {
    problems <- c(problems, sprintf("unsupported fit_size '%s'", as.character(fit_size)))
  }
  if (!is.finite(source_total_size) || source_total_size < fit_size) {
    problems <- c(problems, sprintf("invalid source_total_size '%s'", as.character(source_total_size)))
  }
  if (!beta_prior_type %in% c("ridge", "rhs_ns")) {
    problems <- c(problems, sprintf("unsupported beta_prior_type '%s'", beta_prior_type))
  }
  if (!is.finite(reference_root_count) || reference_root_count < 1L) {
    problems <- c(problems, "source_reference_root_count must be >= 1")
  }
  if (length(problems)) {
    stop(paste(c("Dynamic cross-study root spec invalid:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  out <- list(
    source_root_kind = source_root_kind,
    source_scenario = source_scenario,
    source_family = source_family,
    tau = tau,
    fit_size = fit_size,
    effective_fit_size = effective_fit_size,
    source_total_size = source_total_size,
    source_window_label = source_window_label,
    raw_start_source_index = as.integer(root_spec$raw_start_source_index %||% NA_integer_)[1L],
    raw_end_source_index = as.integer(root_spec$raw_end_source_index %||% NA_integer_)[1L],
    train_start_source_index = as.integer(root_spec$train_start_source_index %||% NA_integer_)[1L],
    train_end_source_index = as.integer(root_spec$train_end_source_index %||% NA_integer_)[1L],
    forecast_start_source_index = as.integer(root_spec$forecast_start_source_index %||% NA_integer_)[1L],
    forecast_end_source_index = as.integer(root_spec$forecast_end_source_index %||% NA_integer_)[1L],
    beta_prior_type = beta_prior_type,
    source_fit_input_dir = source_fit_input_dir,
    source_report_root = source_report_root,
    source_series_wide_path = source_series_wide_path,
    source_series_wide_sha256 = as.character(root_spec$source_series_wide_sha256 %||% NA_character_)[1L],
    source_selection_indices_path = source_selection_indices_path,
    source_selection_indices_sha256 = as.character(root_spec$source_selection_indices_sha256 %||% NA_character_)[1L],
    source_sim_path = source_sim_path,
    source_sim_sha256 = as.character(root_spec$source_sim_sha256 %||% NA_character_)[1L],
    source_reference_root_count = reference_root_count,
    source_reference_priors = reference_priors,
    source_current_rhsns_member = current_member,
    source_legacy_rhs_member = legacy_member,
    reservoir_profile = reservoir_profile,
    enabled = enabled
  )
  out$dataset_cell_id <- as.character(root_spec$dataset_cell_id %||%
    sprintf(
      "dynamic__%s__%s__tau_%s__lasttt_%s",
      source_scenario,
      source_family,
      .qdesn_dynamic_crossstudy_prob_label(tau),
      fit_size
    ))[1L]
  out$scenario <- source_scenario
  profile_seed <- ((defaults$reservoir_profiles %||% list())[[reservoir_profile]]$seed %||% 123L)
  out$seed <- as.integer(root_spec$seed %||% profile_seed)[1L]
  out$desn_seed <- as.integer(root_spec$desn_seed %||% profile_seed)[1L]
  out$root_id <- as.character(root_spec$root_id %||% qdesn_dynamic_crossstudy_build_root_id(out))[1L]
  out
}

.qdesn_dynamic_crossstudy_source_truth_bundle <- function(root_spec) {
  series_df <- utils::read.csv(root_spec$source_series_wide_path, stringsAsFactors = FALSE)
  if (!nrow(series_df)) {
    stop(sprintf("Dynamic source series_wide.csv is empty: %s", root_spec$source_series_wide_path), call. = FALSE)
  }
  y <- as.numeric(series_df$y %||% numeric(0))
  q_true <- if ("q_target" %in% names(series_df)) {
    as.numeric(series_df$q_target)
  } else if ("q_true" %in% names(series_df)) {
    as.numeric(series_df$q_true)
  } else {
    sim_obj <- readRDS(root_spec$source_sim_path)
    q_mat <- as.matrix(sim_obj$q %||% matrix(numeric(0), 0L, 0L))
    if (!nrow(q_mat)) stop(sprintf("Dynamic source sim object missing q matrix: %s", root_spec$source_sim_path), call. = FALSE)
    as.numeric(q_mat[, 1L])
  }
  if (length(q_true) != length(y)) {
    stop(sprintf("q_true length mismatch for %s.", root_spec$root_id), call. = FALSE)
  }
  selection_df <- utils::read.csv(root_spec$source_selection_indices_path, stringsAsFactors = FALSE)
  source_index <- if (nrow(selection_df) == length(y) && "source_index" %in% names(selection_df)) {
    as.integer(selection_df$source_index)
  } else {
    rep(NA_integer_, length(y))
  }
  mu <- if ("mu" %in% names(series_df)) as.numeric(series_df$mu) else rep(NA_real_, length(y))
  list(
    y = y,
    q_true = q_true,
    source_index = source_index,
    mu = mu,
    n_obs = length(y)
  )
}

qdesn_dynamic_crossstudy_stage_dataset <- function(root_spec, root_dir, defaults) {
  truth_bundle <- .qdesn_dynamic_crossstudy_source_truth_bundle(root_spec)
  y <- truth_bundle$y
  expected_source_n <- as.integer(root_spec$source_total_size %||% root_spec$fit_size)
  if (length(y) != expected_source_n) {
    stop(sprintf(
      "Dynamic source dataset length mismatch for %s: expected source_total_size=%d, got y=%d.",
      root_spec$root_id,
      expected_source_n,
      length(y)
    ), call. = FALSE)
  }
  q_true <- truth_bundle$q_true
  source_index <- truth_bundle$source_index
  mu <- truth_bundle$mu

  data_dir <- file.path(root_dir, "data")
  .qdesn_validation_dir_create(data_dir)
  obs_path <- file.path(data_dir, "observed.csv")
  q_true_path <- file.path(data_dir, "q_true.csv")
  .qdesn_validation_write_df(data.frame(y = y, stringsAsFactors = FALSE), obs_path)
  .qdesn_validation_write_df(
    data.frame(
      t = seq_along(y),
      source_index = source_index,
      q_true = q_true,
      y = y,
      mu = mu,
      stringsAsFactors = FALSE
    ),
    q_true_path
  )
  .qdesn_validation_write_json(file.path(data_dir, "source_metadata.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_scenario = root_spec$source_scenario,
    source_family = root_spec$source_family,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    effective_fit_size = as.integer(root_spec$effective_fit_size %||% root_spec$fit_size),
    source_total_size = expected_source_n,
    source_window_label = as.character(root_spec$source_window_label %||% NA_character_),
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_report_root = root_spec$source_report_root,
    source_series_wide_path = root_spec$source_series_wide_path,
    source_selection_indices_path = root_spec$source_selection_indices_path,
    source_sim_path = root_spec$source_sim_path,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    generated_at = as.character(Sys.time())
  ))
  list(
    observed_path = obs_path,
    q_true_path = q_true_path,
    q_true = q_true,
    y = y,
    x_cols = character(0),
    n_obs = length(y)
  )
}

.qdesn_dynamic_crossstudy_root_summary <- function(root_spec,
                                                   fit_summary,
                                                   pairwise_vb_vs_mcmc,
                                                   model_pair_summary,
                                                   root_status) {
  out <- .qdesn_static_crossstudy_root_summary(
    root_spec = root_spec,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_status = root_status
  )
  out$scenario <- root_spec$scenario
  out[, c(
    "root_id", "dataset_cell_id", "scenario", "root_kind", "family", "tau", "fit_size", "prior",
    setdiff(names(out), c("root_id", "dataset_cell_id", "scenario", "root_kind", "family", "tau", "fit_size", "prior"))
  ), drop = FALSE]
}

.qdesn_dynamic_crossstudy_multiseed_cfg <- function(defaults) {
  cfg <- defaults$multiseed %||% list()
  list(
    enabled = isTRUE(cfg$enabled),
    mcmc_seed_reps = max(1L, as.integer(cfg$mcmc_seed_reps %||% 1L)[1L]),
    parallel_seed_workers = max(1L, as.integer(cfg$parallel_seed_workers %||% 1L)[1L]),
    selection_metric = as.character(cfg$selection_metric %||% "forecast_CRPS_mean")[1L],
    prune_nonwinning_heavy_outputs = isTRUE(cfg$prune_nonwinning_heavy_outputs),
    prune_rel_paths = as.character(unlist(
      cfg$prune_rel_paths %||% c(
        "models/forecast_objects.rds",
        "models/rhs_trace.rds",
        "models/timing_summary.rds"
      ),
      use.names = FALSE
    )),
    seed_base = as.integer(cfg$seed_base %||% 500000L)[1L],
    model_offsets = cfg$model_offsets %||% list(al = 0L, exal = 5000L),
    desn_offset = as.integer(cfg$desn_offset %||% 30000L)[1L],
    mcmc_seed_offset = as.integer(cfg$mcmc_seed_offset %||% 0L)[1L],
    mcmc_rng_offset = as.integer(cfg$mcmc_rng_offset %||% 0L)[1L],
    vb_warm_start_offset = as.integer(cfg$vb_warm_start_offset %||% 10000L)[1L],
    synthesis_offset = as.integer(cfg$synthesis_offset %||% 20000L)[1L]
  )
}

.qdesn_dynamic_crossstudy_hash_int <- function(text, modulus = 50000L) {
  raw <- utf8ToInt(enc2utf8(as.character(text %||% "")[1L]))
  if (!length(raw)) return(0L)
  acc <- 0
  for (val in raw) {
    acc <- (acc * 131 + as.numeric(val)) %% as.numeric(modulus)
  }
  as.integer(acc)
}

.qdesn_dynamic_crossstudy_seed_bundle <- function(root_spec,
                                                  likelihood_family,
                                                  seed_rep,
                                                  multiseed_cfg) {
  seed_rep <- as.integer(seed_rep)[1L]
  root_hash <- .qdesn_dynamic_crossstudy_hash_int(root_spec$root_id, modulus = 50000L)
  model_offset <- as.integer((multiseed_cfg$model_offsets %||% list())[[likelihood_family]] %||% 0L)[1L]
  base_seed <- as.integer(
    multiseed_cfg$seed_base +
      100L * root_hash +
      model_offset +
      as.integer(root_spec$seed %||% 0L)
  )[1L]
  list(
    seed_rep = seed_rep,
    seed_base = base_seed,
    model = as.character(likelihood_family)[1L],
    desn_seed = as.integer(base_seed + multiseed_cfg$desn_offset + seed_rep)[1L],
    mcmc_seed = as.integer(base_seed + multiseed_cfg$mcmc_seed_offset + seed_rep)[1L],
    mcmc_rng_seed = as.integer(base_seed + multiseed_cfg$mcmc_rng_offset + seed_rep)[1L],
    vb_warm_start_seed = as.integer(base_seed + multiseed_cfg$vb_warm_start_offset + seed_rep)[1L],
    synthesis_seed = as.integer(base_seed + multiseed_cfg$synthesis_offset + seed_rep)[1L]
  )
}

.qdesn_dynamic_crossstudy_safe_num <- function(x, default = Inf) {
  out <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(out)) default else out
}

.qdesn_dynamic_crossstudy_seed_metric_row <- function(root_spec,
                                                      likelihood_family,
                                                      run_res,
                                                      seed_bundle,
                                                      selection_metric,
                                                      seed_method_dir) {
  fit_row <- run_res$fit_summary[1L, , drop = FALSE]
  if (!nrow(fit_row)) {
    fit_row <- data.frame(stringsAsFactors = FALSE)
  }
  fit_row$seed_rep <- as.integer(seed_bundle$seed_rep)
  fit_row$seed_base <- as.integer(seed_bundle$seed_base)
  fit_row$desn_seed <- as.integer(seed_bundle$desn_seed)
  fit_row$mcmc_seed <- as.integer(seed_bundle$mcmc_seed)
  fit_row$mcmc_rng_seed <- as.integer(seed_bundle$mcmc_rng_seed)
  fit_row$vb_warm_start_seed <- as.integer(seed_bundle$vb_warm_start_seed)
  fit_row$synthesis_seed <- as.integer(seed_bundle$synthesis_seed)
  fit_row$selection_metric_name <- as.character(selection_metric)[1L]
  fit_row$selection_metric_value <- .qdesn_dynamic_crossstudy_safe_num(
    fit_row[[selection_metric]],
    default = Inf
  )
  fit_row$selection_runtime_sec <- .qdesn_dynamic_crossstudy_safe_num(
    fit_row$runtime_sec %||% fit_row$fit_runtime_seconds %||% run_res$health$wall_seconds,
    default = Inf
  )
  grade_score <- .qdesn_validation_multichain_grade_score(fit_row$signoff_grade %||% NA_character_)
  fit_row$seed_grade_score <- if (is.na(grade_score[1L])) -1 else as.numeric(grade_score[1L])
  fit_row$seed_method_dir <- normalizePath(seed_method_dir, winslash = "/", mustWork = FALSE)
  fit_row$selected_seed <- FALSE
  fit_row$seed_selection_rank <- NA_integer_
  fit_row$model <- as.character(fit_row$model[1L] %||% likelihood_family)[1L]
  fit_row$root_id <- as.character(fit_row$root_id[1L] %||% root_spec$root_id)[1L]
  fit_row
}

.qdesn_dynamic_crossstudy_rank_seed_metrics <- function(seed_metrics_df) {
  seed_metrics_df <- as.data.frame(seed_metrics_df, stringsAsFactors = FALSE)
  if (!nrow(seed_metrics_df)) return(seed_metrics_df)
  ord <- order(
    -as.numeric(seed_metrics_df$seed_grade_score %||% -1),
    as.numeric(seed_metrics_df$selection_metric_value %||% Inf),
    as.numeric(seed_metrics_df$selection_runtime_sec %||% Inf),
    as.integer(seed_metrics_df$seed_rep %||% seq_len(nrow(seed_metrics_df)))
  )
  out <- seed_metrics_df[ord, , drop = FALSE]
  out$seed_selection_rank <- seq_len(nrow(out))
  out$selected_seed <- seq_len(nrow(out)) == 1L
  out
}

.qdesn_dynamic_crossstudy_copy_selected_seed_artifacts <- function(selected_seed_dir,
                                                                   canonical_method_dir) {
  rel_paths <- c(
    "fit_request.json",
    "fit_summary_row.csv",
    "health_summary.csv",
    "signoff_summary.csv",
    "progress_trace.csv",
    "chain_summary.csv",
    file.path("manifest", "manifest_real.json"),
    file.path("logs", "pipeline_stdout.log"),
    file.path("tables", "timing_breakdown.csv"),
    file.path("tables", "timing_summary.csv")
  )
  for (rel_path in rel_paths) {
    src <- file.path(selected_seed_dir, rel_path)
    if (!file.exists(src)) next
    dst <- file.path(canonical_method_dir, rel_path)
    .qdesn_validation_dir_create(dirname(dst))
    ok <- file.copy(src, dst, overwrite = TRUE)
    if (!isTRUE(ok)) {
      stop(sprintf("Failed to copy selected seed artifact '%s' to '%s'.", src, dst), call. = FALSE)
    }
  }
}

.qdesn_dynamic_crossstudy_prune_seed_artifacts <- function(seed_method_dir, rel_paths) {
  rel_paths <- as.character(rel_paths)
  for (rel_path in rel_paths[nzchar(rel_paths)]) {
    target <- file.path(seed_method_dir, rel_path)
    if (file.exists(target)) {
      unlink(target, recursive = TRUE, force = TRUE)
    }
  }
  invisible(seed_method_dir)
}

.qdesn_dynamic_crossstudy_run_selected_mcmc_fit <- function(root_spec,
                                                            defaults,
                                                            staged_data,
                                                            root_dir,
                                                            likelihood_family,
                                                            verbose = TRUE,
                                                            fit_spec_id = NULL) {
  multiseed_cfg <- .qdesn_dynamic_crossstudy_multiseed_cfg(defaults)
  canonical_method_dir <- file.path(root_dir, "fits", paste("mcmc", likelihood_family, sep = "_"))
  .qdesn_validation_dir_create(canonical_method_dir)
  fit_spec_id <- as.character(fit_spec_id %||% qdesn_dynamic_fitforecast_atomic_spec_id(root_spec, "mcmc", likelihood_family))[1L]

  if (!isTRUE(multiseed_cfg$enabled) || multiseed_cfg$mcmc_seed_reps <= 1L) {
    res <- .qdesn_static_crossstudy_run_one_fit(
      root_spec = root_spec,
      defaults = defaults,
      staged_data = staged_data,
      root_dir = root_dir,
      method = "mcmc",
      method_dir = canonical_method_dir,
      likelihood_family = likelihood_family,
      fit_spec_id = fit_spec_id
    )
    return(c(res, list(seed_selection = data.frame(stringsAsFactors = FALSE))))
  }

  run_seed_once <- function(seed_rep) {
    bundle <- .qdesn_dynamic_crossstudy_seed_bundle(
      root_spec = root_spec,
      likelihood_family = likelihood_family,
      seed_rep = seed_rep,
      multiseed_cfg = multiseed_cfg
    )
    seed_root_spec <- modifyList(root_spec, list(
      seed = bundle$desn_seed,
      desn_seed = bundle$desn_seed,
      mcmc_seed = bundle$mcmc_seed,
      mcmc_rng_seed = bundle$mcmc_rng_seed,
      vb_warm_start_seed = bundle$vb_warm_start_seed,
      synthesis_seed = bundle$synthesis_seed
    ))
    seed_method_dir <- file.path(canonical_method_dir, "seeds", sprintf("seed_%02d", seed_rep))
    if (isTRUE(verbose)) {
      message(sprintf(
        "[qdesn_dynamic_crossstudy_run_root] %s | %s | mcmc | seed_rep=%02d | desn_seed=%d | mcmc_rng_seed=%d",
        root_spec$root_id,
        likelihood_family,
        seed_rep,
        bundle$desn_seed,
        bundle$mcmc_rng_seed
      ))
    }
    res_i <- .qdesn_static_crossstudy_run_one_fit(
      root_spec = seed_root_spec,
      defaults = defaults,
      staged_data = staged_data,
      root_dir = root_dir,
      method = "mcmc",
      method_dir = seed_method_dir,
      likelihood_family = likelihood_family,
      fit_spec_id = fit_spec_id
    )
    seed_metric <- .qdesn_dynamic_crossstudy_seed_metric_row(
      root_spec = root_spec,
      likelihood_family = likelihood_family,
      run_res = res_i,
      seed_bundle = bundle,
      selection_metric = multiseed_cfg$selection_metric,
      seed_method_dir = seed_method_dir
    )
    list(
      result = res_i,
      bundle = bundle,
      seed_method_dir = seed_method_dir,
      seed_metric = seed_metric
    )
  }

  can_parallel <- multiseed_cfg$parallel_seed_workers > 1L &&
    multiseed_cfg$mcmc_seed_reps > 1L &&
    identical(.Platform$OS.type, "unix")
  seed_results <- if (isTRUE(can_parallel)) {
    parallel::mclapply(
      X = seq_len(multiseed_cfg$mcmc_seed_reps),
      FUN = run_seed_once,
      mc.cores = min(multiseed_cfg$parallel_seed_workers, multiseed_cfg$mcmc_seed_reps),
      mc.preschedule = FALSE
    )
  } else {
    lapply(seq_len(multiseed_cfg$mcmc_seed_reps), run_seed_once)
  }
  seed_rows <- lapply(seed_results, function(x) x$seed_metric)
  seed_runs <- stats::setNames(seed_results, sprintf("%d", seq_len(multiseed_cfg$mcmc_seed_reps)))

  ranked_seed_df <- .qdesn_dynamic_crossstudy_rank_seed_metrics(
    .qdesn_validation_bind_rows(seed_rows)
  )
  selected_seed_rep <- as.integer(ranked_seed_df$seed_rep[1L])
  selected_seed <- seed_runs[[as.character(selected_seed_rep)]]
  .qdesn_dynamic_crossstudy_copy_selected_seed_artifacts(
    selected_seed_dir = selected_seed$seed_method_dir,
    canonical_method_dir = canonical_method_dir
  )
  .qdesn_validation_write_df(
    ranked_seed_df,
    file.path(canonical_method_dir, "mcmc_seed_selection.csv")
  )
  .qdesn_validation_write_json(
    file.path(canonical_method_dir, "manifest", "selected_seed_manifest.json"),
    list(
      generated_at = as.character(Sys.time()),
      selection_rule = list(
        grade_order = c("PASS", "WARN", "FAIL"),
        primary_metric = multiseed_cfg$selection_metric,
        tiebreakers = c("runtime_sec", "seed_rep")
      ),
      selected_seed_rep = selected_seed_rep,
      selected_seed_dir = normalizePath(selected_seed$seed_method_dir, winslash = "/", mustWork = FALSE),
      selected_seed_bundle = selected_seed$bundle,
      prune_nonwinning_heavy_outputs = isTRUE(multiseed_cfg$prune_nonwinning_heavy_outputs),
      prune_rel_paths = multiseed_cfg$prune_rel_paths
    )
  )

  if (isTRUE(multiseed_cfg$prune_nonwinning_heavy_outputs)) {
    losing_reps <- setdiff(as.integer(ranked_seed_df$seed_rep), selected_seed_rep)
    for (seed_rep in losing_reps) {
      .qdesn_dynamic_crossstudy_prune_seed_artifacts(
        seed_method_dir = seed_runs[[as.character(seed_rep)]]$seed_method_dir,
        rel_paths = multiseed_cfg$prune_rel_paths
      )
    }
  }

  c(selected_seed$result, list(seed_selection = ranked_seed_df))
}

qdesn_dynamic_crossstudy_run_root <- function(root_spec,
                                              defaults,
                                              output_root,
                                              create_plots = FALSE,
                                              verbose = TRUE) {
  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Dynamic cross-study root already exists and is not empty: %s", root_dir), call. = FALSE)
  }
  for (d in c("manifest", "config", "data", "fits", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), "RUNNING")
  execution_scope <- .qdesn_static_crossstudy_execution_scope(defaults)
  allowed_fit_spec_ids <- unique(as.character((defaults$execution %||% list())$allowed_fit_spec_ids %||% character(0)))
  allowed_fit_spec_ids <- allowed_fit_spec_ids[nzchar(allowed_fit_spec_ids)]
  rescue_cfg <- .qdesn_static_crossstudy_rescue_overlays_cfg(defaults)
  rescue_patch <- .qdesn_static_crossstudy_root_patch(defaults, root_spec$root_id)
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "root_manifest.json"), list(
    root_id = root_spec$root_id,
    dataset_cell_id = root_spec$dataset_cell_id,
    source_root_kind = root_spec$source_root_kind,
    source_scenario = root_spec$source_scenario,
    source_family = root_spec$source_family,
    scenario = root_spec$scenario,
    tau = as.numeric(root_spec$tau),
    fit_size = as.integer(root_spec$fit_size),
    effective_fit_size = as.integer(root_spec$effective_fit_size %||% root_spec$fit_size),
    source_total_size = as.integer(root_spec$source_total_size %||% root_spec$fit_size),
    raw_start_source_index = as.integer(root_spec$raw_start_source_index %||% NA_integer_),
    raw_end_source_index = as.integer(root_spec$raw_end_source_index %||% NA_integer_),
    train_start_source_index = as.integer(root_spec$train_start_source_index %||% NA_integer_),
    train_end_source_index = as.integer(root_spec$train_end_source_index %||% NA_integer_),
    forecast_start_source_index = as.integer(root_spec$forecast_start_source_index %||% NA_integer_),
    forecast_end_source_index = as.integer(root_spec$forecast_end_source_index %||% NA_integer_),
    beta_prior_type = root_spec$beta_prior_type,
    source_fit_input_dir = root_spec$source_fit_input_dir,
    source_report_root = root_spec$source_report_root,
    source_series_wide_path = root_spec$source_series_wide_path,
    source_selection_indices_path = root_spec$source_selection_indices_path,
    source_sim_path = root_spec$source_sim_path,
    source_reference_root_count = as.integer(root_spec$source_reference_root_count),
    source_reference_priors = root_spec$source_reference_priors,
    reservoir_profile = root_spec$reservoir_profile,
    seed = as.integer(root_spec$seed),
    multiseed = defaults$multiseed %||% list(),
    execution = execution_scope,
    allowed_fit_spec_ids = as.list(allowed_fit_spec_ids),
    study_contract = .qdesn_static_crossstudy_study_contract(defaults),
    rescue_overlay = list(
      enabled = isTRUE(rescue_cfg$enabled %||% FALSE),
      mode = as.character(rescue_cfg$mode %||% "none")[1L],
      inventory_csv = as.character(rescue_cfg$inventory_csv %||% NA_character_)[1L],
      root_override_applied = isTRUE(length(rescue_patch) > 0L)
    ),
    git_sha = .qdesn_validation_git_sha(),
    started_at = as.character(Sys.time())
  ))

  staged_data <- qdesn_dynamic_crossstudy_stage_dataset(root_spec, root_dir, defaults)
  fit_rows <- list()
  progress_rows <- list()
  seed_selection_rows <- list()
  attempted_fits <- 0L
  for (likelihood_family in execution_scope$likelihood_families) {
    for (method in execution_scope$methods) {
      fit_spec_id <- qdesn_dynamic_fitforecast_atomic_spec_id(root_spec, method, likelihood_family)
      if (length(allowed_fit_spec_ids) && !fit_spec_id %in% allowed_fit_spec_ids) {
        if (isTRUE(verbose)) {
          message(sprintf(
            "[qdesn_dynamic_crossstudy_run_root] skip spec %s | %s | %s | %s",
            fit_spec_id,
            root_spec$root_id,
            likelihood_family,
            method
          ))
        }
        next
      }
      attempted_fits <- attempted_fits + 1L
      if (isTRUE(verbose)) {
        message(sprintf(
          "[qdesn_dynamic_crossstudy_run_root] %s | %s | %s | spec=%s",
          root_spec$root_id,
          likelihood_family,
          method,
          fit_spec_id
        ))
      }
      if (identical(method, "vb")) {
        vb_res <- .qdesn_static_crossstudy_run_one_fit(
          root_spec = root_spec,
          defaults = defaults,
          staged_data = staged_data,
          root_dir = root_dir,
          method = "vb",
          likelihood_family = likelihood_family,
          fit_spec_id = fit_spec_id
        )
        fit_rows[[length(fit_rows) + 1L]] <- vb_res$fit_summary
        if (nrow(vb_res$progress_trace)) {
          progress_rows[[length(progress_rows) + 1L]] <- vb_res$progress_trace
        }
      } else {
        mcmc_res <- .qdesn_dynamic_crossstudy_run_selected_mcmc_fit(
          root_spec = root_spec,
          defaults = defaults,
          staged_data = staged_data,
          root_dir = root_dir,
          likelihood_family = likelihood_family,
          verbose = verbose,
          fit_spec_id = fit_spec_id
        )
        fit_rows[[length(fit_rows) + 1L]] <- mcmc_res$fit_summary
        if (nrow(mcmc_res$progress_trace)) {
          progress_rows[[length(progress_rows) + 1L]] <- mcmc_res$progress_trace
        }
        if (nrow(mcmc_res$seed_selection %||% data.frame(stringsAsFactors = FALSE))) {
          seed_selection_rows[[length(seed_selection_rows) + 1L]] <- mcmc_res$seed_selection
        }
      }
    }
  }

  fit_summary <- .qdesn_validation_bind_rows(fit_rows)
  pairwise_vb_vs_mcmc <- .qdesn_static_crossstudy_algorithm_pair_summary(fit_summary, root_spec)
  model_pair_summary <- .qdesn_static_crossstudy_model_pair_summary(fit_summary, root_spec)
  status_vec <- if ("status" %in% names(fit_summary)) as.character(fit_summary$status) else character(0)
  status_vec[is.na(status_vec) | !nzchar(status_vec)] <- "FAIL"
  expected_fits <- if (length(allowed_fit_spec_ids)) {
    as.integer(attempted_fits)
  } else {
    as.integer(execution_scope$requested_fits %||% 4L)[1L]
  }
  root_status <- if (nrow(fit_summary) >= expected_fits &&
    expected_fits > 0L &&
    length(status_vec) >= expected_fits &&
    all(status_vec[seq_len(expected_fits)] == "SUCCESS")) {
    "SUCCESS"
  } else {
    "FAIL"
  }
  root_summary <- .qdesn_dynamic_crossstudy_root_summary(
    root_spec = root_spec,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_status = root_status
  )

  .qdesn_validation_write_df(fit_summary, file.path(root_dir, "tables", "fit_summary.csv"))
  .qdesn_validation_write_df(pairwise_vb_vs_mcmc, file.path(root_dir, "tables", "pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(model_pair_summary, file.path(root_dir, "tables", "model_pair_signoff.csv"))
  .qdesn_validation_write_df(root_summary, file.path(root_dir, "tables", "root_signoff_summary.csv"))
  if (length(seed_selection_rows)) {
    .qdesn_validation_write_df(
      .qdesn_validation_bind_rows(seed_selection_rows),
      file.path(root_dir, "tables", "mcmc_seed_selection.csv")
    )
  }
  if (length(progress_rows)) {
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(progress_rows), file.path(root_dir, "tables", "progress_trace_long.csv"))
  }
  .qdesn_validation_write_lines(file.path(root_dir, "manifest", "root_status.txt"), root_status)
  .qdesn_validation_write_json(file.path(root_dir, "manifest", "runtime_summary.json"), list(
    root_status = root_status,
    finished_at = as.character(Sys.time()),
    root_id = root_spec$root_id
  ))
  list(
    root_dir = root_dir,
    root_status = root_status,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_summary = model_pair_summary,
    root_summary = root_summary
  )
}

.qdesn_dynamic_crossstudy_reference_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("scenario", "root_kind", "family", "tau", "fit_size"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("scenario", "root_kind", "family", "tau", "fit_size"), drop = FALSE]
    row$n_roots <- nrow(sub)
    row$comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    row
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_dynamic_crossstudy_qdesn_root_group_summary <- function(df) {
  if (!nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  split_idx <- split(
    seq_len(nrow(df)),
    interaction(df[, c("scenario", "root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE], drop = TRUE, lex.order = TRUE)
  )
  rows <- lapply(split_idx, function(idx) {
    sub <- df[idx, , drop = FALSE]
    row <- sub[1L, c("scenario", "root_kind", "family", "tau", "fit_size", "prior"), drop = FALSE]
    row$n_roots <- nrow(sub)
    row$n_success <- sum(as.character(sub$root_status) == "SUCCESS", na.rm = TRUE)
    row$n_fail <- sum(as.character(sub$root_status) == "FAIL", na.rm = TRUE)
    row$root_success_rate <- if (nrow(sub)) row$n_success / nrow(sub) else NA_real_
    row$root_comparison_eligible_any_rate <- mean(as.logical(sub$root_comparison_eligible_any), na.rm = TRUE)
    row$root_comparison_eligible_full_rate <- mean(as.logical(sub$root_comparison_eligible_full), na.rm = TRUE)
    row$method_comparison_eligible_rate_mean <- mean(as.numeric(sub$method_comparison_eligible_rate), na.rm = TRUE)
    row$algorithm_pair_comparison_eligible_rate_mean <- mean(as.numeric(sub$algorithm_pair_comparison_eligible_rate), na.rm = TRUE)
    row$model_pair_comparison_eligible_rate_mean <- mean(as.numeric(sub$model_pair_comparison_eligible_rate), na.rm = TRUE)
    row
  })
  .qdesn_validation_bind_rows(rows)
}

qdesn_dynamic_crossstudy_write_reference_compare <- function(reference_inventory,
                                                             qdesn_tables,
                                                             output_root) {
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  if (is.null(reference_inventory) ||
      !is.list(reference_inventory) ||
      !nrow(reference_inventory$fit_summary %||% data.frame(stringsAsFactors = FALSE))) {
    q_fit_group <- .qdesn_static_crossstudy_group_summary(
      qdesn_tables$fit_summary,
      group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
      grade_col = "signoff_grade",
      eligible_col = "comparison_eligible",
      extra_numeric = c("runtime_sec", "train_mae", "train_rmse", "holdout_mae", "holdout_rmse")
    )
    q_pair_group <- .qdesn_static_crossstudy_group_summary(
      qdesn_tables$pairwise_vb_vs_mcmc,
      group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
      grade_col = "algorithm_pair_signoff_grade",
      eligible_col = "algorithm_pair_comparison_eligible",
      extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
    )
    q_root_group <- .qdesn_dynamic_crossstudy_qdesn_root_group_summary(qdesn_tables$root_summary)
    .qdesn_validation_write_df(q_fit_group, file.path(output_root, "tables", "qdesn_fit_group_summary.csv"))
    .qdesn_validation_write_df(q_pair_group, file.path(output_root, "tables", "qdesn_pair_group_summary.csv"))
    .qdesn_validation_write_df(q_root_group, file.path(output_root, "tables", "qdesn_root_group_summary.csv"))
    .qdesn_validation_write_lines(
      file.path(output_root, "comparison_summary.md"),
      c(
        "# QDESN Dynamic Cross-Study vs exdqlm Reference",
        "",
        "- comparison_available: `FALSE`",
        "- reason: the active relaunch surface is using materialized dynamic source inputs with",
        "  `tau = 0.50`, but the legacy mirrored exdqlm reference signoff inventory is only available",
        "  for the older `0.05 / 0.25 / 0.95` surface.",
        "- action: use the staged-source contract and the QDESN campaign summaries for this relaunch;",
        "  do not interpret this run as having a directly mirrored legacy reference compare yet.",
        "",
        "## QDESN Root Group Summary",
        .qdesn_validation_df_to_markdown(q_root_group),
        "",
        "## QDESN Pair Group Summary",
        .qdesn_validation_df_to_markdown(q_pair_group)
      )
    )
    .qdesn_validation_write_json(file.path(output_root, "manifest", "comparison_manifest.json"), list(
      generated_at = as.character(Sys.time()),
      output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
      comparison_available = FALSE,
      reason = "materialized_source_contract_without_mirrored_reference_inventory"
    ))
    return(invisible(list(
      comparison_available = FALSE,
      reference_fit_group = data.frame(stringsAsFactors = FALSE),
      reference_pair_group = data.frame(stringsAsFactors = FALSE),
      reference_root_group = data.frame(stringsAsFactors = FALSE),
      qdesn_fit_group = q_fit_group,
      qdesn_pair_group = q_pair_group,
      qdesn_root_group = q_root_group,
      surface_delta = data.frame(stringsAsFactors = FALSE)
    )))
  }

  ref_fit_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec")
  )
  q_fit_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse", "holdout_mae", "holdout_rmse")
  )
  ref_pair_group <- .qdesn_static_crossstudy_group_summary(
    reference_inventory$pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb")
  )
  q_pair_group <- .qdesn_static_crossstudy_group_summary(
    qdesn_tables$pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  ref_root_group <- .qdesn_dynamic_crossstudy_reference_root_group_summary(reference_inventory$root_signoff_summary)
  q_root_group <- .qdesn_dynamic_crossstudy_qdesn_root_group_summary(qdesn_tables$root_summary)
  surface_delta <- merge(
    q_root_group,
    ref_root_group,
    by = c("scenario", "root_kind", "family", "tau", "fit_size"),
    all.x = TRUE,
    suffixes = c("_qdesn", "_reference"),
    sort = TRUE
  )
  if (nrow(surface_delta)) {
    surface_delta$comparison_eligible_any_rate_delta <- as.numeric(
      surface_delta$root_comparison_eligible_any_rate - surface_delta$comparison_eligible_any_rate
    )
    surface_delta$comparison_eligible_full_rate_delta <- as.numeric(
      surface_delta$root_comparison_eligible_full_rate - surface_delta$comparison_eligible_full_rate
    )
  }

  .qdesn_validation_write_df(reference_inventory$fit_summary, file.path(output_root, "tables", "reference_fit_summary.csv"))
  .qdesn_validation_write_df(reference_inventory$pairwise_vb_vs_mcmc, file.path(output_root, "tables", "reference_pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(reference_inventory$model_pair_signoff, file.path(output_root, "tables", "reference_model_pair_signoff.csv"))
  .qdesn_validation_write_df(reference_inventory$root_signoff_summary, file.path(output_root, "tables", "reference_root_signoff_summary.csv"))
  .qdesn_validation_write_df(ref_fit_group, file.path(output_root, "tables", "reference_fit_group_summary.csv"))
  .qdesn_validation_write_df(ref_pair_group, file.path(output_root, "tables", "reference_pair_group_summary.csv"))
  .qdesn_validation_write_df(ref_root_group, file.path(output_root, "tables", "reference_root_group_summary.csv"))
  .qdesn_validation_write_df(q_fit_group, file.path(output_root, "tables", "qdesn_fit_group_summary.csv"))
  .qdesn_validation_write_df(q_pair_group, file.path(output_root, "tables", "qdesn_pair_group_summary.csv"))
  .qdesn_validation_write_df(q_root_group, file.path(output_root, "tables", "qdesn_root_group_summary.csv"))
  .qdesn_validation_write_df(surface_delta, file.path(output_root, "tables", "qdesn_vs_reference_surface_delta.csv"))

  compare_lines <- c(
    "# QDESN Dynamic Cross-Study vs exdqlm Reference",
    "",
    "## Reference Surface",
    sprintf("- reference_root_dirs: `%d`", length(reference_inventory$root_dirs)),
    sprintf("- reference_fit_rows: `%d`", nrow(reference_inventory$fit_summary)),
    sprintf("- reference_pair_rows: `%d`", nrow(reference_inventory$pairwise_vb_vs_mcmc)),
    "",
    "## QDESN Surface",
    sprintf("- qdesn_root_rows: `%d`", nrow(qdesn_tables$root_summary)),
    sprintf("- qdesn_fit_rows: `%d`", nrow(qdesn_tables$fit_summary)),
    sprintf("- qdesn_pair_rows: `%d`", nrow(qdesn_tables$pairwise_vb_vs_mcmc)),
    "",
    "## Important Interpretation Note",
    "",
    "- This comparison is valid on the shared mirrored dynamic dataset surface.",
    "- The exdqlm side remains the canonical dynamic reference.",
    "- The QDESN side preserves the additional prior axis (`ridge` / `rhs_ns`) explicitly.",
    "",
    "## Reference Root Group Summary",
    .qdesn_validation_df_to_markdown(ref_root_group),
    "",
    "## QDESN Root Group Summary",
    .qdesn_validation_df_to_markdown(q_root_group),
    "",
    "## Reference Pair Group Summary",
    .qdesn_validation_df_to_markdown(ref_pair_group),
    "",
    "## QDESN Pair Group Summary",
    .qdesn_validation_df_to_markdown(q_pair_group),
    "",
    "## QDESN vs Reference Surface Delta",
    .qdesn_validation_df_to_markdown(utils::head(surface_delta, 24L))
  )
  .qdesn_validation_write_lines(file.path(output_root, "comparison_summary.md"), compare_lines)
  .qdesn_validation_write_json(file.path(output_root, "manifest", "comparison_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    reference_root_n = length(reference_inventory$root_dirs),
    qdesn_root_n = nrow(qdesn_tables$root_summary)
  ))
  invisible(list(
    reference_fit_group = ref_fit_group,
    reference_pair_group = ref_pair_group,
    reference_root_group = ref_root_group,
    qdesn_fit_group = q_fit_group,
    qdesn_pair_group = q_pair_group,
    qdesn_root_group = q_root_group,
    surface_delta = surface_delta
  ))
}

qdesn_dynamic_crossstudy_collect_campaign <- function(results_root,
                                                      report_root,
                                                      defaults,
                                                      reference_inventory,
                                                      create_plots = FALSE) {
  roots_dir <- file.path(results_root, "roots")
  root_dirs <- if (dir.exists(roots_dir)) sort(list.dirs(roots_dir, recursive = FALSE, full.names = TRUE)) else character(0)
  fit_summary <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "fit_summary.csv")
  pairwise_vb_vs_mcmc <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "pairwise_vb_vs_mcmc.csv")
  model_pair_signoff <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "model_pair_signoff.csv")
  root_summary <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "root_signoff_summary.csv")
  seed_selection <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "mcmc_seed_selection.csv")
  progress_rows <- .qdesn_static_crossstudy_collect_root_tables(root_dirs, "progress_trace_long.csv")

  .qdesn_validation_dir_create(file.path(report_root, "tables"))
  .qdesn_validation_write_df(root_summary, file.path(report_root, "tables", "campaign_root_signoff_summary.csv"))
  .qdesn_validation_write_df(fit_summary, file.path(report_root, "tables", "campaign_fit_summary.csv"))
  .qdesn_validation_write_df(pairwise_vb_vs_mcmc, file.path(report_root, "tables", "campaign_pairwise_vb_vs_mcmc.csv"))
  .qdesn_validation_write_df(model_pair_signoff, file.path(report_root, "tables", "campaign_model_pair_signoff.csv"))
  if (nrow(seed_selection)) {
    .qdesn_validation_write_df(seed_selection, file.path(report_root, "tables", "campaign_mcmc_seed_selection.csv"))
    .qdesn_validation_write_df(
      seed_selection[as.logical(seed_selection$selected_seed), , drop = FALSE],
      file.path(report_root, "tables", "campaign_mcmc_seed_winners.csv")
    )
  }
  if (nrow(progress_rows)) {
    .qdesn_validation_write_df(progress_rows, file.path(report_root, "tables", "campaign_progress_trace_long.csv"))
  }

  fit_group <- .qdesn_static_crossstudy_group_summary(
    fit_summary,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference", "model"),
    grade_col = "signoff_grade",
    eligible_col = "comparison_eligible",
    extra_numeric = c("runtime_sec", "train_mae", "train_rmse", "holdout_mae", "holdout_rmse")
  )
  pair_group <- .qdesn_static_crossstudy_group_summary(
    pairwise_vb_vs_mcmc,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "model"),
    grade_col = "algorithm_pair_signoff_grade",
    eligible_col = "algorithm_pair_comparison_eligible",
    extra_numeric = c("runtime_ratio_mcmc_vs_vb", "mae_delta_mcmc_minus_vb")
  )
  model_group <- .qdesn_static_crossstudy_group_summary(
    model_pair_signoff,
    group_cols = c("scenario", "root_kind", "family", "tau", "fit_size", "prior", "inference"),
    grade_col = "pair_signoff_grade",
    eligible_col = "pair_comparison_eligible",
    extra_numeric = c("train_mae_delta_extended_minus_baseline")
  )
  root_status_mix <- if (nrow(root_summary)) {
    .qdesn_static_crossstudy_count_table_df(as.character(root_summary$root_status), "root_status")
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  fit_signoff_mix <- if (nrow(fit_summary)) {
    as.data.frame(table(
      inference = as.character(fit_summary$inference),
      model = as.character(fit_summary$model),
      signoff_grade = as.character(fit_summary$signoff_grade)
    ), stringsAsFactors = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }
  pair_signoff_mix <- if (nrow(pairwise_vb_vs_mcmc)) {
    as.data.frame(table(
      model = as.character(pairwise_vb_vs_mcmc$model),
      algorithm_pair_signoff_grade = as.character(pairwise_vb_vs_mcmc$algorithm_pair_signoff_grade)
    ), stringsAsFactors = FALSE)
  } else {
    data.frame(stringsAsFactors = FALSE)
  }

  .qdesn_validation_write_df(fit_group, file.path(report_root, "tables", "campaign_fit_group_summary.csv"))
  .qdesn_validation_write_df(pair_group, file.path(report_root, "tables", "campaign_pair_group_summary.csv"))
  .qdesn_validation_write_df(model_group, file.path(report_root, "tables", "campaign_model_group_summary.csv"))
  .qdesn_validation_write_df(root_status_mix, file.path(report_root, "tables", "campaign_root_status_mix.csv"))
  .qdesn_validation_write_df(fit_signoff_mix, file.path(report_root, "tables", "campaign_fit_signoff_mix.csv"))
  .qdesn_validation_write_df(pair_signoff_mix, file.path(report_root, "tables", "campaign_pair_signoff_mix.csv"))

  compare_root <- file.path(report_root, "comparison_vs_reference")
  compare_obj <- qdesn_dynamic_crossstudy_write_reference_compare(
    reference_inventory = reference_inventory,
    qdesn_tables = list(
      fit_summary = fit_summary,
      pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
      model_pair_signoff = model_pair_signoff,
      root_summary = root_summary
    ),
    output_root = compare_root
  )

  recommendation <- if (nrow(root_summary) && all(as.character(root_summary$root_status) == "SUCCESS") &&
      nrow(fit_summary) && !any(as.character(fit_summary$signoff_grade) == "FAIL")) {
    "COMPARISON_READY_QDESN_DYNAMIC_EXDQLM_COMPLETE"
  } else if (nrow(root_summary) && all(as.character(root_summary$root_status) == "SUCCESS")) {
    "COMPARISON_READY_WITH_DOCUMENTED_DYNAMIC_FAIL_BAND"
  } else {
    "HOLD_QDESN_DYNAMIC_EXDQLM_WITH_GAPS"
  }

  summary_lines <- c(
    "# QDESN Dynamic exdqlm Cross-Study Campaign Summary",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- results_root: `%s`", normalizePath(results_root, winslash = "/", mustWork = FALSE)),
    sprintf("- report_root: `%s`", normalizePath(report_root, winslash = "/", mustWork = FALSE)),
    sprintf("- recommendation: `%s`", recommendation),
    "",
    "## Root Status Mix",
    .qdesn_validation_df_to_markdown(root_status_mix),
    "",
    "## Fit Signoff Mix",
    .qdesn_validation_df_to_markdown(fit_signoff_mix),
    "",
    "## Algorithm Pair Signoff Mix",
    .qdesn_validation_df_to_markdown(pair_signoff_mix),
    "",
    if (nrow(seed_selection)) "## MCMC Seed Winners" else NULL,
    if (nrow(seed_selection)) .qdesn_validation_df_to_markdown(seed_selection[as.logical(seed_selection$selected_seed), , drop = FALSE]) else NULL,
    if (nrow(seed_selection)) "" else NULL,
    "## Fit Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(fit_group, 24L)),
    "",
    "## Pair Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(pair_group, 24L)),
    "",
    "## Model Group Summary",
    .qdesn_validation_df_to_markdown(utils::head(model_group, 24L)),
    "",
    sprintf("- comparison_root: `%s`", compare_root)
  )
  .qdesn_validation_write_lines(file.path(report_root, "summary", "qdesn_dynamic_crossstudy_summary.md"), summary_lines)
  .qdesn_validation_write_json(file.path(report_root, "manifest", "campaign_summary_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
    recommendation = recommendation,
    n_roots = nrow(root_summary),
    n_fits = nrow(fit_summary)
  ))

  invisible(list(
    root_summary = root_summary,
    fit_summary = fit_summary,
    pairwise_vb_vs_mcmc = pairwise_vb_vs_mcmc,
    model_pair_signoff = model_pair_signoff,
    mcmc_seed_selection = seed_selection,
    fit_group = fit_group,
    pair_group = pair_group,
    model_group = model_group,
    compare = compare_obj,
    recommendation = recommendation
  ))
}

qdesn_dynamic_crossstudy_run_campaign <- function(grid = NULL,
                                                  defaults = NULL,
                                                  grid_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_grid.csv"),
                                                  defaults_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_defaults.yaml"),
                                                  results_root = NULL,
                                                  report_root = NULL,
                                                  verbose = TRUE,
                                                  workers = NULL,
                                                  create_plots = FALSE,
                                                  reference_inventory = NULL) {
  defaults <- defaults %||% qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  grid <- grid %||% qdesn_dynamic_crossstudy_load_grid(grid_path)
  campaign_cfg <- defaults$campaign %||% list()
  runtime_cfg <- defaults$runtime %||% list()
  workers <- as.integer(workers %||% runtime_cfg$campaign_workers %||% runtime_cfg$workers %||% 1L)[1L]
  if (!is.finite(workers) || workers < 1L) workers <- 1L
  root_scheduler <- tolower(as.character(runtime_cfg$root_scheduler %||% runtime_cfg$scheduler %||% "static")[1L])
  if (!root_scheduler %in% c("static", "load_balanced")) root_scheduler <- "static"

  results_root <- results_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"),
    must_work = FALSE
  )
  report_root <- report_root %||% .qdesn_validation_resolve_path(
    campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_validation"),
    must_work = FALSE
  )
  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  run_stub <- sprintf("%s__git-%s", timestamp, .qdesn_validation_git_sha() %||% "unknown")
  results_run_root <- file.path(results_root, run_stub)
  report_run_root <- file.path(report_root, run_stub)
  for (d in c(results_run_root, file.path(results_run_root, "roots"), report_run_root, file.path(report_run_root, "tables"), file.path(report_run_root, "summary"), file.path(report_run_root, "plots"), file.path(report_run_root, "manifest"))) {
    .qdesn_validation_dir_create(d)
  }
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_manifest.json"), list(
    campaign_name = campaign_cfg$name %||% "qdesn_dynamic_exdqlm_crossstudy_validation",
    started_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    grid_path = grid_path,
    defaults_path = defaults_path,
    git_sha = .qdesn_validation_git_sha(),
    workers = workers,
    root_scheduler = root_scheduler
  ))

  if (is.null(reference_inventory)) {
    grid_source_mode <- .qdesn_dynamic_crossstudy_grid_source_mode(defaults)
    if (identical(grid_source_mode, "reference_inventory")) {
      reference_cfg <- defaults$reference %||% list()
      reference_inventory <- qdesn_dynamic_crossstudy_collect_reference_inventory(
        reference_root = .qdesn_validation_resolve_path(reference_cfg$dynamic_root, must_work = TRUE)
      )
    }
  }

  targets <- list()
  for (i in seq_len(nrow(grid))) {
    root_spec <- qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid[i, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    targets[[length(targets) + 1L]] <- root_spec
  }
  n_targets <- length(targets)
  if (n_targets >= 1L) workers <- min(workers, n_targets)
  run_one <- function(root_spec, seq_id, n_total) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_dynamic_crossstudy_run_campaign] root %d/%d | %s", seq_id, n_total, root_spec$root_id))
    }
    res <- tryCatch(
      qdesn_dynamic_crossstudy_run_root(
        root_spec = root_spec,
        defaults = defaults,
        output_root = file.path(results_run_root, "roots"),
        create_plots = create_plots,
        verbose = verbose
      ),
      error = function(e) {
        root_status_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_status.txt")
        root_error_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_error.txt")
        if (file.exists(root_status_path)) {
          .qdesn_validation_write_lines(root_status_path, "FAIL")
        }
        .qdesn_validation_write_lines(root_error_path, conditionMessage(e))
        data.frame(
          root_id = root_spec$root_id,
          dataset_cell_id = root_spec$dataset_cell_id,
          scenario = root_spec$scenario,
          root_kind = root_spec$source_root_kind,
          family = root_spec$source_family,
          tau = as.numeric(root_spec$tau),
          fit_size = as.integer(root_spec$fit_size),
          prior = root_spec$beta_prior_type,
          root_status = "FAIL",
          error_message = conditionMessage(e),
          stringsAsFactors = FALSE
        )
      }
    )
    if (is.data.frame(res)) return(res)
    out <- res$root_summary
    out$error_message <- ""
    out
  }

  status_rows <- list()
  if (workers > 1L && n_targets > 1L) {
    repo_root <- .qdesn_validation_repo_root()
    cl <- parallel::makePSOCKcluster(workers, outfile = "")
    on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterExport(
      cl,
      varlist = c(
        "repo_root",
        "targets",
        "defaults",
        "results_run_root",
        "create_plots",
        "verbose",
        "n_targets"
      ),
      envir = environment()
    )
    parallel::clusterEvalQ(cl, {
      suppressPackageStartupMessages(library(pkgload))
      pkgload::load_all(repo_root, quiet = TRUE)
      NULL
    })
    apply_fun <- if (identical(root_scheduler, "load_balanced")) parallel::parLapplyLB else parallel::parLapply
    status_rows <- apply_fun(
      cl,
      X = seq_len(n_targets),
      fun = function(j) {
        root_spec <- targets[[j]]
        tryCatch(
          {
            res <- exdqlm:::qdesn_dynamic_crossstudy_run_root(
              root_spec = root_spec,
              defaults = defaults,
              output_root = file.path(results_run_root, "roots"),
              create_plots = create_plots,
              verbose = verbose
            )
            out <- res$root_summary
            out$error_message <- ""
            out
          },
          error = function(e) {
            root_status_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_status.txt")
            root_error_path <- file.path(results_run_root, "roots", root_spec$root_id, "manifest", "root_error.txt")
            if (file.exists(root_status_path)) {
              exdqlm:::.qdesn_validation_write_lines(root_status_path, "FAIL")
            }
            exdqlm:::.qdesn_validation_write_lines(root_error_path, conditionMessage(e))
            data.frame(
              root_id = root_spec$root_id,
              dataset_cell_id = root_spec$dataset_cell_id,
              scenario = root_spec$scenario,
              root_kind = root_spec$source_root_kind,
              family = root_spec$source_family,
              tau = as.numeric(root_spec$tau),
              fit_size = as.integer(root_spec$fit_size),
              prior = root_spec$beta_prior_type,
              root_status = "FAIL",
              error_message = conditionMessage(e),
              stringsAsFactors = FALSE
            )
          }
        )
      }
    )
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
  } else {
    for (j in seq_len(n_targets)) {
      row <- run_one(targets[[j]], j, n_targets)
      status_rows[[length(status_rows) + 1L]] <- row
      .qdesn_validation_write_df(.qdesn_validation_bind_rows(status_rows), file.path(report_run_root, "tables", "campaign_progress.csv"))
      qdesn_dynamic_crossstudy_collect_campaign(
        results_root = results_run_root,
        report_root = report_run_root,
        defaults = defaults,
        reference_inventory = reference_inventory,
        create_plots = create_plots
      )
    }
  }

  final <- qdesn_dynamic_crossstudy_collect_campaign(
    results_root = results_run_root,
    report_root = report_run_root,
    defaults = defaults,
    reference_inventory = reference_inventory,
    create_plots = create_plots
  )
  .qdesn_validation_write_json(file.path(report_run_root, "manifest", "campaign_completed.json"), list(
    finished_at = as.character(Sys.time()),
    results_root = results_run_root,
    report_root = report_run_root,
    n_roots = nrow(final$root_summary),
    n_fits = nrow(final$fit_summary),
    recommendation = final$recommendation
  ))
  invisible(list(
    results_root = results_run_root,
    report_root = report_run_root,
    summary = final
  ))
}
