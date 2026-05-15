#' Build Q-DESN design matrix (reservoir -> readout features) without fitting readout
#' @export
qdesn_build_design <- function(y, desn_args, drop = NULL) {
  if (is.null(desn_args)) desn_args <- list()
  if (!is.list(desn_args)) stop("desn_args must be a list.", call. = FALSE)

  # If user supplied a custom drop, implement it by setting washout so that
  # drop_effective = max(m, washout) equals that value (up to the constraint drop>=m).
  if (!is.null(drop)) {
    drop <- as.integer(drop)[1L]
    m_in <- if (!is.null(desn_args$m)) as.integer(desn_args$m)[1L] else 12L  # matches qdesn_fit_vb default
    # enforce drop >= m_in, since qdesn_fit_vb will do max(m, washout)
    desn_args$washout <- max(drop, m_in)
  }

  # Prevent user args from overriding "design-only" guarantees
  desn_args[c("y", "p0", "fit_readout")] <- NULL

  fit <- do.call(qdesn_fit_vb, c(
    list(
      y = y,
      p0 = 0.50,                 # irrelevant for design; kept for interface stability
      fit_readout = FALSE        # <-- KEY FIX: no readout fit, ever
    ),
    desn_args
  ))

  list(
    X        = as.matrix(fit$X),
    keep_idx = as.integer(fit$meta$keep_idx),
    meta     = fit$meta
  )
}
