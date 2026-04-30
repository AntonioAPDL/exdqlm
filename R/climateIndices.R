#' Monthly climate indices for streamflow examples
#'
#' Monthly atmospheric and oceanic climate indices used as external predictors
#' in the Big Trees streamflow examples. Values are stored on their original
#' scales; examples that combine indices standardize the relevant columns within
#' the analysis code.
#'
#' @format A data frame with 516 rows and 3 variables:
#' \describe{
#'   \item{date}{First day of the calendar month.}
#'   \item{noi}{Northern Oscillation Index.}
#'   \item{amo}{Atlantic Multidecadal Oscillation index.}
#' }
#' The data frame spans January 1980 through December 2022.
#'
#' @source Compiled from the NOAA Physical Sciences Laboratory monthly climate
#'   indices collection, \url{https://psl.noaa.gov/data/climateindices/}.
"climateIndices"
