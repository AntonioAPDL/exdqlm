#' Recursive posterior predictive paths
#' @param object Fitted DESN object.
#' @param ... Arguments forwarded to the fitted object's forecast method.
#' @return Method-specific posterior predictive paths.
#' @export
forecast_paths <- function(object,...)UseMethod("forecast_paths")

#' Fitted posterior mean function
#' @param object Fitted DESN object.
#' @param ... Method-specific arguments.
#' @return Fitted conditional means.
#' @export
predict_mu <- function(object,...)UseMethod("predict_mu")

#' Fixed-design posterior predictive samples
#' @param object Fitted DESN object.
#' @param ... Method-specific arguments.
#' @return Method-specific posterior predictive samples.
#' @export
posterior_predict <- function(object,...)UseMethod("posterior_predict")
