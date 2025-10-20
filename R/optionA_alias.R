#' Option A model selection (alias of distribution-first workflow)
#'
#' Thin wrapper so scripts can call \code{exdqlm::model_selection_optionA()}.
#' It forwards all arguments to \code{model_selection_distribution_first()},
#' while swallowing Option-A-only knobs that the underlying selector
#' may not use yet (e.g., split, weight_leads).
#'
#' @inheritParams model_selection_distribution_first
#' @return See \code{model_selection_distribution_first()}.
#' @export
model_selection_optionA <- function(...) {
  dots <- list(...)
  # Swallow Option-A-only CLI knobs (no-ops for distribution_first)
  dots$split <- NULL
  dots$weight_leads <- NULL
  # Forward everything else
  do.call(model_selection_distribution_first, dots)
}
