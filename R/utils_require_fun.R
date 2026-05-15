#' Internal helper: require a function to exist
#' @keywords internal
.require_fun <- function(fname, pkg = NULL) {
  stopifnot(is.character(fname), length(fname) == 1L, nzchar(fname))

  # 1) Search up from caller (devtools::load_all() + interactive dev often works here)
  if (exists(fname, mode = "function", inherits = TRUE)) {
    return(invisible(TRUE))
  }

  # 2) Search in package namespace (when installed / loaded)
  if (is.null(pkg)) pkg <- utils::packageName()
  if (!is.null(pkg)) {
    ns <- tryCatch(asNamespace(pkg), error = function(e) NULL)
    if (!is.null(ns) && exists(fname, envir = ns, mode = "function", inherits = FALSE)) {
      return(invisible(TRUE))
    }
  }

  stop(
    sprintf(
      "Required internal function '%s()' not found. If developing, run devtools::load_all().\nIf installed, ensure the file defining it is in R/ and included in the build.",
      fname
    ),
    call. = FALSE
  )
}
