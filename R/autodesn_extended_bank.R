# Resolve both complete and previously compacted Q-DESN terminal-state formats.
.ext_template_initial <- function(template) {
  state <- template$states
  if (!is.null(state$H_all) && length(state$H_all)) {
    h <- lapply(state$H_all, function(x) as.numeric(x[nrow(x), ]))
  } else if (is.list(state$H_last)) {
    h <- lapply(state$H_last, as.numeric)
  } else if (is.matrix(state$H_last) && length(template$reservoir$W) == 1L) {
    h <- list(as.numeric(state$H_last[nrow(state$H_last), ]))
  } else if (is.null(template$reservoir)) {
    return(list()) # Explicit inference-only placeholders cannot forecast.
  } else stop("Reservoir template has no valid terminal state.", call. = FALSE)
  if (!is.null(template$reservoir)) {
    widths <- vapply(template$reservoir$W, nrow, 0L)
    if (!identical(unname(lengths(h)), unname(widths)) || any(!is.finite(unlist(h)))) stop("Reservoir terminal state dimensions or values are invalid.", call. = FALSE)
  }
  h
}

.ext_forecast_map_id <- function(bank, models = seq_along(bank$models)) {
  # Weight-generating distributions are deliberately absent: the frozen numeric
  # weights define propagation, and these unused closures can retain whole fits.
  maps <- lapply(bank$templates[models], function(t) list(
    reservoir = t$reservoir[intersect(names(t$reservoir), c("W", "Win", "Q", "Q_is_identity", "alpha", "act_f", "act_k"))],
    meta = t$meta[intersect(names(t$meta), c("D", "add_bias", "m", "m_input", "standardize_inputs", "lag_center", "lag_scale", "input_bound", "input_bound_divisor", "win_scale_bias", "win_scale_global", "win_scale_lags"))],
    initial = .ext_template_initial(t)))
  digest::digest(list(conditional_bank_id = bank$extension$id, maps = maps,
    preprocessing = bank$preprocessing, training_history = bank$extension$training_history), algo = "sha256")
}

.ext_origin_states <- function(bank) {
  e <- bank$extension
  if (!is.null(e$current_states)) return(e$current_states)
  # Older augmented checkpoints can have empty initial_states from H_last-only
  # templates. Resolve the actual frozen templates rather than clone zeros.
  if (!is.null(e$initial_states) && all(lengths(e$initial_states) > 0L)) return(e$initial_states)
  lapply(bank$templates, .ext_template_initial)
}
