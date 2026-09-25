.qdesn_mean_readout_state_basis_payload <- function(object) {
  if (!is.list(object) || is.null(object$reservoir) || is.null(object$meta)) {
    stop("mean-readout-state basis hashing requires a fitted Q-DESN object.", call. = FALSE)
  }

  meta_keep <- c(
    "D", "m", "m_input", "add_bias", "input_mode", "input_mode_requested",
    "lag_center", "lag_scale", "standardize_inputs", "input_center_scale",
    "input_bound", "input_bound_divisor",
    "win_scale_global", "win_scale_bias", "win_scale_lags", "p_res",
    "readout_spec", "readout_scale"
  )
  meta <- object$meta[intersect(meta_keep, names(object$meta))]
  reservoir <- object$reservoir[c(
    "W", "Win", "Q", "Q_is_identity", "alpha", "act_f", "act_k"
  )]
  states <- object$states[c("H_all", "H_tilde")]

  list(
    schema_version = "qdesn_mean_readout_state_basis_v1",
    meta = meta,
    reservoir = reservoir,
    states = states,
    y_fit = as.numeric(object$y_fit)
  )
}

.qdesn_mean_readout_state_basis_hash <- function(object) {
  digest::digest(
    .qdesn_mean_readout_state_basis_payload(object),
    algo = "sha256",
    serialize = TRUE
  )
}

.qdesn_mean_readout_state_rms <- function(x, center) {
  x <- as.matrix(x)
  center <- as.numeric(center)
  if (!nrow(x) || !ncol(x)) return(0)
  centered <- if (length(center) == nrow(x)) {
    sweep(x, 1L, center, "-")
  } else if (length(center) == ncol(x)) {
    sweep(x, 2L, center, "-")
  } else {
    stop("mean-readout-state dispersion center has incompatible length.", call. = FALSE)
  }
  sqrt(mean(centered^2))
}

.qdesn_tile_origin_draws <- function(draws_by_origin, origins, targets) {
  if (!is.list(draws_by_origin) || !length(draws_by_origin)) {
    stop("Tiled origin draws require a nonempty matrix list.", call. = FALSE)
  }
  origins <- as.integer(origins)
  targets <- as.integer(targets)
  if (length(draws_by_origin) != length(origins) || anyNA(origins) ||
      anyNA(targets) || anyDuplicated(targets)) {
    stop("Tiled origin draws have invalid origin/target coordinates.", call. = FALSE)
  }
  draws_by_origin <- lapply(draws_by_origin, as.matrix)
  nd <- unique(vapply(draws_by_origin, ncol, integer(1L)))
  if (length(nd) != 1L || nd < 1L) {
    stop("Tiled origin-draw matrices must share a positive draw count.",
         call. = FALSE)
  }

  out <- matrix(NA_real_, nrow = length(targets), ncol = nd)
  assigned <- integer(length(targets))
  target_row <- setNames(seq_along(targets), as.character(targets))
  for (i in seq_along(draws_by_origin)) {
    block <- draws_by_origin[[i]]
    block_targets <- origins[[i]] + seq_len(nrow(block))
    keep <- match(as.character(block_targets), names(target_row), nomatch = 0L)
    if (!any(keep > 0L)) next
    source_rows <- which(keep > 0L)
    destination_rows <- unname(target_row[as.character(block_targets[source_rows])])
    if (any(assigned[destination_rows] > 0L)) {
      stop("Tiled origin draws overlap on one or more requested targets.",
           call. = FALSE)
    }
    out[destination_rows, ] <- block[source_rows, , drop = FALSE]
    assigned[destination_rows] <- assigned[destination_rows] + 1L
  }
  if (any(assigned != 1L) || any(!is.finite(out))) {
    stop("Tiled origin draws do not cover every requested target exactly once.",
         call. = FALSE)
  }
  out
}

.qdesn_resolve_analysis_source_index <- function(data, rows,
                                                  explicit_source_index = NULL) {
  if (!is.data.frame(data)) {
    stop("Analysis source-index resolution requires a data frame.", call. = FALSE)
  }
  rows <- as.integer(rows)
  if (!length(rows) || anyNA(rows) || any(rows < 1L) ||
      any(rows > nrow(data)) || anyDuplicated(rows)) {
    stop("Analysis source-index rows are invalid.", call. = FALSE)
  }

  if (!is.null(explicit_source_index)) {
    if (length(explicit_source_index) != nrow(data)) {
      stop("Explicit analysis source coordinates must match the data rows.",
           call. = FALSE)
    }
    coordinate_name <- "explicit_source_index"
    coordinate <- suppressWarnings(as.numeric(explicit_source_index[rows]))
  } else {
    coordinate_name <- intersect(c("source_index", "t"), names(data))
    if (!length(coordinate_name)) return(rows)
    coordinate_name <- coordinate_name[[1L]]
    coordinate <- suppressWarnings(as.numeric(data[[coordinate_name]][rows]))
  }
  integer_like <- is.finite(coordinate) &
    abs(coordinate - round(coordinate)) <= sqrt(.Machine$double.eps)
  if (length(coordinate) != length(rows) || any(!integer_like) ||
      anyDuplicated(coordinate) || any(diff(coordinate) <= 0)) {
    stop(
      sprintf("Analysis source coordinate '%s' must be finite, integer-valued, unique, and strictly increasing.",
              coordinate_name),
      call. = FALSE
    )
  }
  as.integer(round(coordinate))
}
