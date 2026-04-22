#' Static exAL LDVB with upstream 0.4.0 naming
#'
#' Canonical `0.4.0` wrapper around [exal_static_LDVB()]. The lower-snake-case
#' name remains available on this validation branch as a compatibility alias,
#' but package-facing documentation should prefer `exalStaticLDVB()`.
#'
#' @inheritParams exal_static_LDVB
#' @return See [exal_static_LDVB()].
#' @export
exalStaticLDVB <- function(...) {
  exal_static_LDVB(...)
}

#' Static exAL MCMC with upstream 0.4.0 naming
#'
#' Canonical `0.4.0` wrapper around [exal_static_mcmc()]. The lower-snake-case
#' name remains available on this validation branch as a compatibility alias,
#' but package-facing documentation should prefer `exalStaticMCMC()`.
#'
#' @inheritParams exal_static_mcmc
#' @return See [exal_static_mcmc()].
#' @export
exalStaticMCMC <- function(...) {
  exal_static_mcmc(...)
}

#' Static exAL diagnostics with upstream 0.4.0 naming
#'
#' Canonical `0.4.0` wrapper around [exalDiagnostics()].
#'
#' @inheritParams exalDiagnostics
#' @return See [exalDiagnostics()].
#' @export
exalStaticDiagnostics <- function(...) {
  exalDiagnostics(...)
}

#' Dynamic transfer wrappers with upstream 0.4.0 naming
#'
#' Canonical `0.4.0` wrappers around the validation-branch transfer helpers.
#'
#' @name exdqlmTransferWrappers
NULL

#' @rdname exdqlmTransferWrappers
#' @inheritParams transfn_exdqlmISVB
#' @return See [transfn_exdqlmISVB()].
#' @export
exdqlmTransferISVB <- function(...) {
  transfn_exdqlmISVB(...)
}

#' @rdname exdqlmTransferWrappers
#' @inheritParams transfn_exdqlmLDVB
#' @return See [transfn_exdqlmLDVB()].
#' @export
exdqlmTransferLDVB <- function(...) {
  transfn_exdqlmLDVB(...)
}

#' @rdname exdqlmTransferWrappers
#' @inheritParams transfn_exdqlmMCMC
#' @return See [transfn_exdqlmMCMC()].
#' @export
exdqlmTransferMCMC <- function(...) {
  transfn_exdqlmMCMC(...)
}

#' Quantile synthesis with upstream 0.4.0 naming
#'
#' Canonical `0.4.0` wrapper around [exdqlm_synthesize_from_draws()].
#'
#' @inheritParams exdqlm_synthesize_from_draws
#' @return See [exdqlm_synthesize_from_draws()].
#' @export
quantileSynthesis <- function(...) {
  exdqlm_synthesize_from_draws(...)
}

#' Upstream 0.4.0-style static exAL class predicates
#'
#' Compatibility predicates for the restored `0.4.0` public names. These map to
#' the current validation-branch classes while still recognizing restored
#' upstream alias classes carried on fitted objects.
#'
#' @param x,m An object to test.
#' @return Logical scalar.
#' @name exalStaticPredicates
NULL

#' @rdname exalStaticPredicates
#' @export
is.exalStaticDiagnostic <- function(x) {
  is.exalDiagnostic(x) || inherits(x, "exalStaticDiagnostic")
}

#' @rdname exalStaticPredicates
#' @export
is.exalStaticLDVB <- function(m) {
  is.exal_ldvb(m) || inherits(m, "exalStaticLDVB")
}

#' @rdname exalStaticPredicates
#' @export
is.exalStaticMCMC <- function(m) {
  is.exal_mcmc(m) || inherits(m, "exalStaticMCMC")
}
