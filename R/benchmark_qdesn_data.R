# Helpers for benchmark-side Q-DESN evaluation on processed benchmark panels.

bench_qdesn_load_processed <- function(context) {
  paths <- context$paths

  list(
    context = context,
    metadata = data.table::as.data.table(readRDS(file.path(paths$metadata_dir, "series_metadata.rds"))),
    splits = data.table::as.data.table(readRDS(file.path(paths$splits_dir, "split_definitions.rds"))),
    panel_manifest = data.table::as.data.table(readRDS(file.path(paths$metadata_dir, "panel_manifest.rds"))),
    panel_cache = new.env(parent = emptyenv())
  )
}

bench_qdesn_select_datasets <- function(loaded, cfg) {
  requested <- cfg$evaluation$datasets %||% NULL
  available <- sort(unique(loaded$metadata$dataset))

  if (is.null(requested) || !length(requested)) {
    return(available)
  }

  requested <- as.character(unlist(requested, use.names = FALSE))
  unknown <- setdiff(requested, available)
  if (length(unknown)) {
    stop(
      sprintf(
        "Unknown benchmark datasets requested: %s",
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  requested
}

bench_qdesn_load_panel <- function(loaded, dataset_name) {
  cache_key <- as.character(dataset_name)[1L]
  if (exists(cache_key, envir = loaded$panel_cache, inherits = FALSE)) {
    return(get(cache_key, envir = loaded$panel_cache, inherits = FALSE))
  }

  idx <- match(cache_key, loaded$panel_manifest$dataset)
  if (is.na(idx)) {
    stop(sprintf("No panel partition registered for dataset '%s'.", cache_key), call. = FALSE)
  }

  panel_path <- bench_abs_path(
    loaded$panel_manifest$panel_path[[idx]],
    repo_root = loaded$context$paths$repo_root,
    must_work = TRUE
  )
  panel_dt <- data.table::as.data.table(readRDS(panel_path))
  data.table::setkey(panel_dt, series_id, t_index)
  assign(cache_key, panel_dt, envir = loaded$panel_cache)
  panel_dt
}

bench_qdesn_select_series_ids <- function(meta_dt, n_target = NULL, purpose = c("selection", "evaluation", "audit")) {
  purpose <- match.arg(purpose)
  meta_dt <- data.table::as.data.table(meta_dt)
  meta_dt <- unique(meta_dt[, .(
    series_id,
    n_obs = as.integer(n_obs),
    y_sd = as.numeric(y_sd),
    has_missing = as.logical(has_missing)
  )])
  data.table::setorder(meta_dt, series_id)

  if (!nrow(meta_dt)) {
    return(character(0))
  }

  if (is.null(n_target) || !is.finite(n_target) || n_target <= 0L || n_target >= nrow(meta_dt)) {
    return(meta_dt$series_id)
  }

  n_target <- as.integer(n_target)[1L]
  ids <- character(0)

  pick_one <- function(idx) {
    if (!length(idx)) return(invisible(NULL))
    sid <- meta_dt$series_id[idx[[1L]]]
    if (!sid %in% ids) {
      ids <<- c(ids, sid)
    }
    invisible(NULL)
  }

  nearest_idx <- function(x, target) {
    which.min(abs(x - target))
  }

  if (purpose %in% c("selection", "audit")) {
    pick_one(1L)
    pick_one(nrow(meta_dt))
    pick_one(nearest_idx(meta_dt$n_obs, stats::median(meta_dt$n_obs, na.rm = TRUE)))
    pick_one(which.max(meta_dt$n_obs))
    pick_one(which.max(ifelse(is.finite(meta_dt$y_sd), meta_dt$y_sd, -Inf)))
    finite_sd <- which(is.finite(meta_dt$y_sd) & meta_dt$y_sd > 0)
    if (length(finite_sd)) {
      pick_one(finite_sd[[which.min(meta_dt$y_sd[finite_sd])]])
    }
  }

  if (length(ids) < n_target) {
    probs <- if (n_target > 1L) seq(0, 1, length.out = n_target) else 0.5
    for (prob in probs) {
      target_n <- as.numeric(stats::quantile(meta_dt$n_obs, probs = prob, names = FALSE, na.rm = TRUE))
      pick_one(nearest_idx(meta_dt$n_obs, target_n))
      if (length(ids) >= n_target) break
    }
  }

  if (length(ids) < n_target) {
    step_idx <- unique(as.integer(round(seq(1, nrow(meta_dt), length.out = n_target))))
    for (idx in step_idx) {
      pick_one(idx)
      if (length(ids) >= n_target) break
    }
  }

  ids[seq_len(min(length(ids), n_target))]
}

bench_qdesn_m4_validation_horizon <- function(split_row, cfg) {
  base_h <- as.integer(split_row$forecast_horizon[[1L]])
  train_end <- as.integer(split_row$official_train_end[[1L]])
  min_train <- as.integer(cfg$evaluation$selection$min_train_points %||% cfg$split$validation$min_train_points %||% 24L)
  val_h <- min(base_h, max(1L, floor(train_end / 5L)))
  while (val_h > 1L && (train_end - val_h) < min_train) {
    val_h <- val_h - 1L
  }
  if ((train_end - val_h) < min_train) {
    stop(
      sprintf(
        "Series has insufficient official-train length for M4 validation: train_end=%d, min_train=%d.",
        train_end,
        min_train
      ),
      call. = FALSE
    )
  }
  val_h
}

bench_qdesn_split_plan <- function(split_row, source_family, stage = c("validation", "test"), cfg) {
  stage <- match.arg(stage)
  split_row <- data.table::as.data.table(split_row)
  source_family <- as.character(source_family)[1L]

  if (!nrow(split_row)) {
    stop("split_row must contain exactly one row.", call. = FALSE)
  }

  if (source_family == "monash") {
    if (stage == "validation") {
      fit_end <- as.integer(split_row$train_end[[1L]])
      eval_start <- as.integer(split_row$val_start[[1L]])
      eval_end <- as.integer(split_row$val_end[[1L]])
      protocol <- "stored_monash_validation"
    } else {
      fit_end <- as.integer(split_row$val_end[[1L]])
      if (!is.finite(fit_end) || is.na(fit_end)) {
        fit_end <- as.integer(split_row$train_end[[1L]])
      }
      eval_start <- as.integer(split_row$test_start[[1L]])
      eval_end <- as.integer(split_row$test_end[[1L]])
      protocol <- "stored_monash_test"
    }
  } else if (source_family == "m4") {
    official_train_end <- as.integer(split_row$official_train_end[[1L]])
    if (stage == "validation") {
      val_h <- bench_qdesn_m4_validation_horizon(split_row, cfg)
      fit_end <- official_train_end - val_h
      eval_start <- fit_end + 1L
      eval_end <- official_train_end
      protocol <- sprintf("m4_train_tail_val_%d", val_h)
    } else {
      fit_end <- official_train_end
      eval_start <- as.integer(split_row$official_test_start[[1L]])
      eval_end <- as.integer(split_row$official_test_end[[1L]])
      protocol <- "official_m4_test"
    }
  } else {
    stop(sprintf("Unsupported source_family '%s'.", source_family), call. = FALSE)
  }

  if (!is.finite(fit_end) || !is.finite(eval_start) || !is.finite(eval_end) ||
      fit_end < 1L || eval_start < 1L || eval_end < eval_start) {
    stop("Invalid split plan resolved for benchmark series.", call. = FALSE)
  }

  list(
    fit_idx = seq_len(fit_end),
    eval_idx = seq.int(eval_start, eval_end),
    fit_end = fit_end,
    eval_start = eval_start,
    eval_end = eval_end,
    selection_protocol = protocol
  )
}

bench_qdesn_build_series_bundle <- function(loaded, dataset_name, series_id, stage = c("validation", "test"), cfg) {
  stage <- match.arg(stage)
  dataset_name_local <- as.character(dataset_name)[1L]
  series_id_local <- as.character(series_id)[1L]
  meta_row <- loaded$metadata[dataset == dataset_name_local & series_id == series_id_local]
  split_row <- loaded$splits[dataset == dataset_name_local & series_id == series_id_local]

  if (nrow(meta_row) != 1L) {
    stop(sprintf("Expected one metadata row for %s/%s.", dataset_name, series_id), call. = FALSE)
  }
  if (nrow(split_row) != 1L) {
    stop(sprintf("Expected one split row for %s/%s.", dataset_name, series_id), call. = FALSE)
  }

  panel_dt <- bench_qdesn_load_panel(loaded, dataset_name_local)[series_id == series_id_local]
  data.table::setorder(panel_dt, t_index)
  if (!nrow(panel_dt)) {
    stop(sprintf("No panel rows found for %s/%s.", dataset_name, series_id), call. = FALSE)
  }

  y <- as.numeric(panel_dt$y)
  if (any(!is.finite(y))) {
    stop(sprintf("Series %s/%s contains non-finite values.", dataset_name, series_id), call. = FALSE)
  }

  plan <- bench_qdesn_split_plan(
    split_row = split_row,
    source_family = meta_row$source_family[[1L]],
    stage = stage,
    cfg = cfg
  )

  list(
    dataset = meta_row$dataset[[1L]],
    dataset_label = meta_row$dataset_label[[1L]],
    source_family = meta_row$source_family[[1L]],
    benchmark_pool = meta_row$benchmark_pool[[1L]],
    series_id = meta_row$series_id[[1L]],
    frequency_label = meta_row$frequency_label[[1L]],
    seasonal_period = as.integer(meta_row$seasonal_period[[1L]]),
    forecast_horizon = as.integer(meta_row$forecast_horizon[[1L]]),
    stage = stage,
    benchmark_split_protocol = split_row$split_protocol[[1L]],
    selection_protocol = plan$selection_protocol,
    fit_idx = plan$fit_idx,
    eval_idx = plan$eval_idx,
    fit_y = y[plan$fit_idx],
    eval_y = y[plan$eval_idx],
    y = y,
    timestamp = panel_dt$timestamp,
    t_index = as.integer(panel_dt$t_index)
  )
}

bench_qdesn_lapply <- function(X, FUN, workers = 1L) {
  workers <- as.integer(workers)[1L]
  if (is.finite(workers) && workers > 1L && .Platform$OS.type != "windows") {
    return(parallel::mclapply(X, FUN, mc.cores = workers))
  }
  lapply(X, FUN)
}
