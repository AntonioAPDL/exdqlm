#' Cache fixed augmented-design sufficient statistics
#'
#' Precompute unweighted cross-products without retaining additional design
#' matrices. Every uncached architecture/period remains available and is computed
#' on demand. The cache does not change the conditional bank identity, model
#' prior, proposal, likelihood, or random stream. Weighted SV cross-products
#' continue to be recomputed whenever observation variances change.
#'
#' @param bank An augmented AutoDESN bank with frozen training geometry.
#' @param max_bytes Bound on cached numeric matrix/vector payload bytes; small
#'   list/index overhead is additional. Entries are considered in period/model
#'   order and entries exceeding the remaining budget are left uncached.
#' @return The same bank with a bounded computational statistics cache.
#' @export
autodesn_cache_statistics <- function(bank, max_bytes = 512 * 1024^2) {
  if (!inherits(bank, "autodesn_extended_bank")) stop("Supply an augmented AutoDESN bank.", call. = FALSE)
  .autodesn_positive(max_bytes, "max_bytes")
  bank$extension$statistics_cache <- NULL
  entries <- list()
  used <- 0
  for (p in seq_along(bank$extension$periods)) for (m in seq_along(bank$models)) {
    dimension <- 1 + ncol(bank$extension$lag$X) + bank$models[[m]]$d + ncol(bank$extension$calendar[[p]]$X)
    bytes <- 8 * (dimension^2 + dimension)
    if (bytes > max_bytes - used) next
    design <- .ext_design(bank, m, p)
    entries[[paste(m, p, sep = ":")]] <- list(XtX = design$XtX, Xty = design$Xty)
    used <- used + bytes
  }
  bank$extension$statistics_cache <- list(version = 1L, bank_id = bank$extension$id,
    entries = entries, payload_bytes = used, max_bytes = max_bytes,
    total_pairs = length(bank$models) * length(bank$extension$periods))
  bank
}
