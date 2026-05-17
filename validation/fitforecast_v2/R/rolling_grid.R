ffv2_rolling_grid <- function(initial_origin_source_index = 9000L,
                              forecast_block_start_source_index = 9001L,
                              forecast_block_end_source_index = 10000L,
                              hmax = 30L,
                              origin_stride = hmax,
                              forecast_protocol = "rolling_origin_no_refit_state_update") {
  scalar_int <- function(x, nm) {
    x <- suppressWarnings(as.integer(x)[1L])
    if (!is.finite(x) || is.na(x)) stop(sprintf("%s must be a finite integer.", nm), call. = FALSE)
    x
  }
  initial_origin_source_index <- scalar_int(initial_origin_source_index, "initial_origin_source_index")
  forecast_block_start_source_index <- scalar_int(forecast_block_start_source_index, "forecast_block_start_source_index")
  forecast_block_end_source_index <- scalar_int(forecast_block_end_source_index, "forecast_block_end_source_index")
  hmax <- scalar_int(hmax, "hmax")
  origin_stride <- scalar_int(origin_stride, "origin_stride")

  if (hmax < 1L) stop("hmax must be >= 1.", call. = FALSE)
  if (origin_stride < 1L) stop("origin_stride must be >= 1.", call. = FALSE)
  if (forecast_block_start_source_index != initial_origin_source_index + 1L) {
    stop("forecast_block_start_source_index must equal initial_origin_source_index + 1.",
         call. = FALSE)
  }
  if (forecast_block_end_source_index < forecast_block_start_source_index) {
    stop("forecast_block_end_source_index must be >= forecast_block_start_source_index.",
         call. = FALSE)
  }

  forecast_block_size <- forecast_block_end_source_index - forecast_block_start_source_index + 1L
  if (hmax > forecast_block_size) {
    stop("hmax must be <= forecast block size.", call. = FALSE)
  }

  origins <- seq.int(initial_origin_source_index, forecast_block_end_source_index - 1L, by = origin_stride)
  leads <- seq_len(hmax)
  grid <- expand.grid(
    forecast_origin_source_index = origins,
    forecast_lead = leads,
    KEEP.OUT.ATTRS = FALSE
  )
  grid$target_source_index <- as.integer(grid$forecast_origin_source_index + grid$forecast_lead)
  grid <- grid[
    grid$target_source_index >= forecast_block_start_source_index &
      grid$target_source_index <= forecast_block_end_source_index,
    ,
    drop = FALSE
  ]
  grid <- grid[order(grid$forecast_origin_source_index, grid$forecast_lead), , drop = FALSE]
  rownames(grid) <- NULL

  lead_counts <- table(grid$forecast_lead)
  origin_ids <- match(grid$forecast_origin_source_index, origins)
  grid <- data.frame(
    forecast_protocol = as.character(forecast_protocol),
    initial_forecast_origin_source_index = initial_origin_source_index,
    forecast_block_start_source_index = forecast_block_start_source_index,
    forecast_block_end_source_index = forecast_block_end_source_index,
    forecast_block_size = forecast_block_size,
    max_lead_configured = hmax,
    origin_stride = origin_stride,
    origin_sequence_id = as.integer(origin_ids),
    forecast_origin_source_index = as.integer(grid$forecast_origin_source_index),
    forecast_lead = as.integer(grid$forecast_lead),
    target_source_index = as.integer(grid$target_source_index),
    target_offset_in_block = as.integer(grid$target_source_index - forecast_block_start_source_index + 1L),
    n_origins_for_lead = as.integer(lead_counts[as.character(grid$forecast_lead)]),
    stringsAsFactors = FALSE
  )
  ffv2_validate_rolling_grid(grid)
  grid
}

ffv2_rolling_grid_from_defaults <- function(defaults,
                                            hmax = 30L,
                                            origin_stride = hmax,
                                            forecast_protocol = "rolling_origin_no_refit_state_update") {
  source <- defaults$source %||% defaults
  ffv2_rolling_grid(
    initial_origin_source_index = source$forecast_origin_source_index,
    forecast_block_start_source_index = source$forecast_start_source_index,
    forecast_block_end_source_index = source$forecast_end_source_index,
    hmax = hmax,
    origin_stride = origin_stride,
    forecast_protocol = forecast_protocol
  )
}

ffv2_required_rolling_grid_columns <- function() {
  c(
    "forecast_protocol", "initial_forecast_origin_source_index",
    "forecast_block_start_source_index", "forecast_block_end_source_index",
    "forecast_block_size", "max_lead_configured", "origin_stride",
    "origin_sequence_id", "forecast_origin_source_index", "forecast_lead",
    "target_source_index", "target_offset_in_block", "n_origins_for_lead"
  )
}

ffv2_validate_rolling_grid <- function(grid, require_complete_targets = FALSE) {
  missing <- setdiff(ffv2_required_rolling_grid_columns(), names(grid))
  if (length(missing)) {
    stop(sprintf("Rolling grid missing column(s): %s", paste(missing, collapse = ", ")),
         call. = FALSE)
  }
  if (!nrow(grid)) stop("Rolling grid is empty.", call. = FALSE)
  if (!all(is.finite(grid$forecast_origin_source_index)) ||
      !all(is.finite(grid$forecast_lead)) ||
      !all(is.finite(grid$target_source_index))) {
    stop("Rolling grid contains non-finite origin, lead, or target values.", call. = FALSE)
  }
  if (!all(as.integer(grid$target_source_index) ==
           as.integer(grid$forecast_origin_source_index) + as.integer(grid$forecast_lead))) {
    stop("Rolling grid target_source_index must equal forecast_origin_source_index + forecast_lead.",
         call. = FALSE)
  }

  block_start <- unique(as.integer(grid$forecast_block_start_source_index))
  block_end <- unique(as.integer(grid$forecast_block_end_source_index))
  hmax <- unique(as.integer(grid$max_lead_configured))
  stride <- unique(as.integer(grid$origin_stride))
  if (length(block_start) != 1L || length(block_end) != 1L ||
      length(hmax) != 1L || length(stride) != 1L) {
    stop("Rolling grid must have one block start/end, hmax, and origin_stride.", call. = FALSE)
  }
  if (any(grid$target_source_index < block_start | grid$target_source_index > block_end)) {
    stop("Rolling grid contains targets outside the forecast block.", call. = FALSE)
  }
  if (any(grid$forecast_lead < 1L | grid$forecast_lead > hmax)) {
    stop("Rolling grid contains leads outside 1:hmax.", call. = FALSE)
  }

  if (isTRUE(require_complete_targets)) {
    expected <- seq.int(block_start, block_end)
    observed <- sort(unique(as.integer(grid$target_source_index)))
    if (!identical(observed, expected)) {
      stop("Rolling grid does not cover every forecast target exactly at least once.",
           call. = FALSE)
    }
  }

  if (stride == hmax) {
    targets <- as.integer(grid$target_source_index)
    if (anyDuplicated(targets)) {
      stop("S = Hmax rolling grid should not duplicate target source indices.", call. = FALSE)
    }
    expected <- seq.int(block_start, block_end)
    if (!identical(sort(targets), expected)) {
      stop("S = Hmax rolling grid must cover the forecast block exactly once.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

ffv2_rolling_grid_lead_summary <- function(grid) {
  ffv2_validate_rolling_grid(grid)
  pieces <- lapply(split(grid, grid$forecast_lead), function(x) {
    data.frame(
      forecast_protocol = as.character(x$forecast_protocol[[1L]]),
      max_lead_configured = as.integer(x$max_lead_configured[[1L]]),
      origin_stride = as.integer(x$origin_stride[[1L]]),
      forecast_lead = as.integer(x$forecast_lead[[1L]]),
      n_origins_scored = nrow(x),
      origin_start_source_index = min(as.integer(x$forecast_origin_source_index)),
      origin_end_source_index = max(as.integer(x$forecast_origin_source_index)),
      target_start_source_index = min(as.integer(x$target_source_index)),
      target_end_source_index = max(as.integer(x$target_source_index)),
      stringsAsFactors = FALSE
    )
  })
  out <- ffv2_bind_rows(pieces)
  out[order(out$forecast_lead), , drop = FALSE]
}
