#' Option A model selection (alias of distribution-first workflow)
#'
#' Thin wrapper so scripts can call \code{exdqlm::model_selection_optionA()}.
#' It forwards all arguments to \code{model_selection_distribution_first()}.
#'
#' @inheritParams model_selection_distribution_first
#' @return See \code{model_selection_distribution_first()}.
#' @export
model_selection_optionA <- function(...) {
  model_selection_distribution_first(...)
}
