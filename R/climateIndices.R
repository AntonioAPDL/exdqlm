#' Monthly climate-index panel
#'
#' Monthly atmospheric and oceanic climate indices used as candidate external
#' predictors in the Big Trees streamflow examples. Values are stored on their
#' original scales; examples that combine indices standardize the relevant
#' columns within the analysis code.
#'
#' @format A data frame with 516 rows and 18 variables:
#' \describe{
#'   \item{date}{First day of the calendar month.}
#'   \item{nino3}{Nino 3 sea-surface temperature index.}
#'   \item{nao}{North Atlantic Oscillation index.}
#'   \item{nino12}{Nino 1+2 sea-surface temperature index.}
#'   \item{whwp}{Western Hemisphere Warm Pool index.}
#'   \item{gmt}{Global mean temperature anomaly index.}
#'   \item{oni}{Oceanic Nino Index.}
#'   \item{pna}{Pacific/North American pattern index.}
#'   \item{noi}{Northern Oscillation Index.}
#'   \item{wp}{West Pacific pattern index.}
#'   \item{nino34}{Nino 3.4 sea-surface temperature index.}
#'   \item{solar_flux}{Solar flux index.}
#'   \item{amo}{Atlantic Multidecadal Oscillation index.}
#'   \item{espi}{ENSO Precipitation Index.}
#'   \item{tsa}{Tropical Southern Atlantic index.}
#'   \item{nino4}{Nino 4 sea-surface temperature index.}
#'   \item{tna}{Tropical Northern Atlantic index.}
#'   \item{soi}{Southern Oscillation Index.}
#' }
#' The panel spans January 1980 through December 2022.
#'
#' @source Compiled from the NOAA Physical Sciences Laboratory monthly climate
#'   indices collection, \url{https://psl.noaa.gov/data/climateindices/}.
"climateIndices"
