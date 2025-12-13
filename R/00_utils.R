.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)

`%||%` <- function(x, y) if (!is.null(x)) x else y

assert_scalar_numeric <- function(x, nm) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) .stopf("%s must be a finite numeric scalar.", nm)
  invisible(TRUE)
}

assert_in <- function(x, set, nm) {
  if (!x %in% set) .stopf("%s must be one of: %s. Got: %s", nm, paste(set, collapse=", "), x)
  invisible(TRUE)
}

assert_matrix <- function(X, nm) {
  if (!is.matrix(X) || !is.numeric(X)) .stopf("%s must be a numeric matrix.", nm)
  invisible(TRUE)
}

is_diag_matrix <- function(M, tol = 0) {
  if (!is.matrix(M)) return(FALSE)
  off <- M
  diag(off) <- 0
  all(abs(off) <= tol)
}

.require_fun <- function(name) {
  if (exists(name, mode = "function", inherits = TRUE)) {
    return(get(name, mode = "function", inherits = TRUE))
  }
  .stopf("Required function '%s' not found. Is the file that defines it loaded/sourced?", name)
}
