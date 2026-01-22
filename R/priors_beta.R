if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.call_with_supported_args <- function(fn, ...) {
  if (is.character(fn) && length(fn) == 1L) {
    fn <- get(fn, mode = "function", inherits = TRUE)
  }
  if (!is.function(fn)) {
    .stopf(".call_with_supported_args: 'fn' must be a function (got %s).", typeof(fn))
  }

  dots <- list(...)
  if (!length(dots)) return(do.call(fn, list()))

  nm <- names(dots)
  if (is.null(nm) || any(nm == "")) return(do.call(fn, dots))

  fmls <- names(formals(fn))
  if (is.null(fmls) || "..." %in% fmls) return(do.call(fn, dots))

  keep <- intersect(nm, fmls)
  do.call(fn, dots[keep])
}


#' Construct beta prior object used by LDVB engine
#' @param type "ridge" or "rhs"
#' @param ridge list(tau2=...)
#' @param rhs list(tau0, nu, s or s2,
#'   shrink_intercept, intercept_prec,
#'   init_lambda or init_log_lambda,
#'   init_tau or init_log_tau,
#'   init_c2 or init_log_c2,
#'   n_inner, eta_bounds, h_curv, var_floor, verbose)
#' @export
beta_prior <- function(type = c("ridge", "rhs"), ridge = list(), rhs = list()) {
  type <- tolower(match.arg(type))
  if (type == "ridge") beta_prior_ridge(ridge$tau2 %||% 1e4)
  else beta_prior_rhs(rhs)
}

beta_prior_ridge <- function(tau2) {
  assert_scalar_numeric(tau2, "ridge$tau2")

  list(
    type = "ridge",
    hypers = list(tau2 = tau2),

    init = function(p) list(),

    expected_prec = function(state, p) rep(1 / tau2, p),

    update = function(state, qb) state,

    elbo = function(state, qb) list(elbo = 0)
  )
}

beta_prior_rhs <- function(rhs) {

  tau0 <- as.numeric(rhs$tau0 %||% 1.0)[1L]
  nu   <- as.numeric(rhs$nu   %||% 4.0)[1L]

  # support rhs$s (sd scale) or rhs$s2 (variance scale); prefer s2 if both provided
  s_provided  <- if (!is.null(rhs$s))  as.numeric(rhs$s)[1L]  else NA_real_
  s2_provided <- if (!is.null(rhs$s2)) as.numeric(rhs$s2)[1L] else NA_real_
  has_s  <- !is.null(rhs$s)
  has_s2 <- !is.null(rhs$s2)

  if (has_s2) {
    s2_used <- s2_provided
    s_used  <- sqrt(s2_used)
    s_source <- "s2"
  } else if (has_s) {
    s_used  <- s_provided
    s2_used <- s_used^2
    s_source <- "s"
  } else {
    s2_used <- 1.0
    s_used  <- sqrt(s2_used)
    s_source <- "default"
  }

  if (has_s && has_s2) {
    s_from_s2 <- sqrt(s2_provided)
    if (is.finite(s_provided) && is.finite(s_from_s2)) {
      rel <- abs(s_provided - s_from_s2) / max(1, abs(s_provided), abs(s_from_s2))
      if (rel > 1e-8 && !isTRUE(getOption("exdqlm.warned_rhs_s_s2"))) {
        warning("RHS: both s and s2 were provided and are inconsistent; using s2 and setting s=sqrt(s2).",
                call. = FALSE)
        options(exdqlm.warned_rhs_s_s2 = TRUE)
      }
    }
  }

  s <- s_used

  hypers <- list(
    tau0 = tau0,
    nu   = nu,
    s    = s_used,
    s2   = s2_used,
    s_source = s_source,
    s_provided = s_provided,
    s2_provided = s2_provided,
    shrink_intercept = isTRUE(rhs$shrink_intercept %||% TRUE),
    intercept_prec   = as.numeric(rhs$intercept_prec %||% 1e-16)[1L]
  )

  # init supports log- or natural-scale keys
  init_lambda <- rhs$init_lambda
  if (is.null(init_lambda) && !is.null(rhs$init_log_lambda)) init_lambda <- exp(rhs$init_log_lambda)

  init_tau <- rhs$init_tau
  if (is.null(init_tau) && !is.null(rhs$init_log_tau)) init_tau <- exp(rhs$init_log_tau)

  init_c2 <- rhs$init_c2
  if (is.null(init_c2) && !is.null(rhs$init_log_c2)) init_c2 <- exp(rhs$init_log_c2)

  init <- list(
    lambda = init_lambda %||% 1,
    tau    = init_tau    %||% tau0,
    c2     = init_c2     %||% (s^2)
  )

  control <- list(
    n_inner    = as.integer(rhs$n_inner %||% rhs$rhs_maxit %||% 1L),
    eta_bounds = rhs$eta_bounds %||% list(
      lambda = c(-12, 12),
      tau    = c(-12, 12),
      c2     = c(-12, 12)
    ),
    h_curv     = as.numeric(rhs$h_curv %||% 1e-16)[1L],
    var_floor  = as.numeric(rhs$var_floor %||% 1e-16)[1L],
    verbose    = isTRUE(rhs$verbose %||% FALSE)
  )

  obj <- .call_with_supported_args(qdesn_rhs_prior_obj,
                                  hypers = hypers, init = init, control = control)

  # Guarantee LDVB engine contract: elbo() exists and returns list(elbo=scalar)
  if (is.null(obj$elbo) || !is.function(obj$elbo)) {
    obj$elbo <- function(...) list(elbo = 0)
  }

  obj
}
