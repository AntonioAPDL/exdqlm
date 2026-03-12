dynamic_dgp_param <- function(params, name) {
  params[[name, exact = TRUE]]
}

coerce_dynamic_dgp_flag <- function(x, name, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  raw <- tolower(trimws(as.character(x)[1]))
  if (raw %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (raw %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Dynamic DGP params$%s must be a scalar logical-like value.", name), call. = FALSE)
}

resolve_dynamic_dgp_m0 <- function(params, state_dim = 6L) {
  m0_raw <- dynamic_dgp_param(params, "m0")
  if (is.null(m0_raw) || !length(m0_raw)) return(rep(0, state_dim))
  m0 <- as.numeric(m0_raw)
  if (length(m0) != state_dim || any(!is.finite(m0))) {
    stop(
      sprintf("Dynamic DGP params$m0 must be a finite numeric vector of length %d.", state_dim),
      call. = FALSE
    )
  }
  m0
}

resolve_dynamic_dgp_C0 <- function(params, state_dim = 6L, default_scale = 25) {
  C0_raw <- dynamic_dgp_param(params, "C0")
  if (is.null(C0_raw) || !length(C0_raw)) {
    scale_raw <- dynamic_dgp_param(params, "C0_scale")
    if (is.null(scale_raw) || !length(scale_raw)) {
      C0_scale <- default_scale
    } else {
      C0_scale <- suppressWarnings(as.numeric(scale_raw)[1])
      if (!is.finite(C0_scale) || C0_scale <= 0) {
        stop(
          "Dynamic DGP params$C0_scale must be a positive finite scalar when params$C0 is absent.",
          call. = FALSE
        )
      }
    }
    return(diag(C0_scale, state_dim))
  }

  C0 <- tryCatch(
    as.matrix(C0_raw),
    error = function(e) {
      stop("Dynamic DGP params$C0 could not be coerced to a matrix.", call. = FALSE)
    }
  )
  if (!identical(dim(C0), c(state_dim, state_dim)) || any(!is.finite(C0))) {
    stop(
      sprintf("Dynamic DGP params$C0 must be a finite %dx%d matrix.", state_dim, state_dim),
      call. = FALSE
    )
  }
  C0
}

build_dynamic_dgp_matched_model <- function(params, TT, state_dim = 6L, default_C0_scale = 25) {
  if (!is.list(params)) stop("Dynamic DGP params must be a list.", call. = FALSE)
  period <- suppressWarnings(as.numeric(dynamic_dgp_param(params, "period"))[1])
  if (!is.finite(period) || period <= 2) {
    stop("Dynamic DGP params$period must be a finite scalar greater than 2.", call. = FALSE)
  }
  no_trend <- coerce_dynamic_dgp_flag(dynamic_dgp_param(params, "no_trend"), "no_trend", default = FALSE)

  lam1 <- 2 * pi / period
  lam2 <- 2 * lam1
  rot <- function(lam) {
    matrix(c(cos(lam), sin(lam), -sin(lam), cos(lam)), nrow = 2, byrow = TRUE)
  }

  GG_trend <- if (no_trend) diag(2) else matrix(c(1, 1, 0, 1), nrow = 2, byrow = TRUE)
  GG_one <- as.matrix(Matrix::bdiag(GG_trend, rot(lam1), rot(lam2)))
  GG <- array(0, dim = c(state_dim, state_dim, TT))
  for (t in seq_len(TT)) GG[, , t] <- GG_one

  FF <- matrix(rep(c(1, 0, 1, 0, 1, 0), TT), nrow = state_dim, ncol = TT)
  m0 <- resolve_dynamic_dgp_m0(params, state_dim = state_dim)
  C0 <- resolve_dynamic_dgp_C0(params, state_dim = state_dim, default_scale = default_C0_scale)
  as.exdqlm(list(FF = FF, GG = GG, m0 = m0, C0 = C0))
}
