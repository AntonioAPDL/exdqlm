# Internal shared defaults for the package-native warmup baseline.
.exal_default_vb_sigmagam_profile <- function() {
  list(
    freeze_warmup_iters = 10L,
    force_after_warmup = TRUE,
    postwarmup_damping = 0.6,
    postwarmup_damping_iters = 5L,
    min_postwarmup_updates = 1L
  )
}

.exal_default_mcmc_sigmagam_profile <- function() {
  list(
    freeze_burnin_iters = 25L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE,
    delay_adapt_until_after_warmup = TRUE,
    delay_laplace_refresh_until_after_warmup = TRUE
  )
}

.exal_list_with_defaults <- function(defaults, overrides = NULL) {
  overrides <- overrides %||% list()
  if (!is.list(overrides)) overrides <- list()
  utils::modifyList(defaults, overrides)
}

.exal_clamp_nonnegative_iters <- function(x, upper) {
  x <- suppressWarnings(as.integer(x)[1L])
  upper <- suppressWarnings(as.integer(upper)[1L])
  if (!is.finite(x) || x < 0L) x <- 0L
  if (!is.finite(upper) || upper < 0L) return(as.integer(x))
  as.integer(min(x, upper))
}

.exal_clamp_vb_sigmagam_control <- function(sigmagam_cfg, max_iter, min_active_iters = 10L) {
  sigmagam_cfg <- sigmagam_cfg %||% .exal_sigmagam_vb_controls(NULL)
  max_iter <- suppressWarnings(as.integer(max_iter)[1L])
  min_active_iters <- suppressWarnings(as.integer(min_active_iters)[1L])
  if (!is.finite(max_iter) || max_iter < 1L) return(sigmagam_cfg)
  if (!is.finite(min_active_iters) || min_active_iters < 0L) min_active_iters <- 10L

  warmup_budget <- max(0L, max_iter - min_active_iters)
  sigmagam_cfg$freeze_warmup_iters <- .exal_clamp_nonnegative_iters(
    sigmagam_cfg$freeze_warmup_iters,
    warmup_budget
  )

  postwarmup_budget <- max(0L, max_iter - sigmagam_cfg$freeze_warmup_iters)
  sigmagam_cfg$postwarmup_damping_iters <- .exal_clamp_nonnegative_iters(
    sigmagam_cfg$postwarmup_damping_iters,
    postwarmup_budget
  )
  sigmagam_cfg$min_postwarmup_updates <- .exal_clamp_nonnegative_iters(
    sigmagam_cfg$min_postwarmup_updates,
    postwarmup_budget
  )
  sigmagam_cfg
}

.exal_clamp_mcmc_sigmagam_control <- function(sigmagam_cfg, n_burn, min_active_burn_iters = 5L) {
  sigmagam_cfg <- sigmagam_cfg %||% .exal_sigmagam_mcmc_controls(NULL)
  n_burn <- suppressWarnings(as.integer(n_burn)[1L])
  min_active_burn_iters <- suppressWarnings(as.integer(min_active_burn_iters)[1L])
  if (!is.finite(n_burn) || n_burn < 0L) return(sigmagam_cfg)
  if (!is.finite(min_active_burn_iters) || min_active_burn_iters < 0L) min_active_burn_iters <- 5L

  warmup_budget <- max(0L, n_burn - min_active_burn_iters)
  sigmagam_cfg$freeze_burnin_iters <- .exal_clamp_nonnegative_iters(
    sigmagam_cfg$freeze_burnin_iters,
    warmup_budget
  )
  sigmagam_cfg
}

#' Build VB sigmagam warmup control
#'
#' Returns a normalized `sigmagam` block for `vb_control` lists used by
#' [exalStaticLDVB()], [exdqlmLDVB()], and VB warm-start paths in
#' [exalStaticMCMC()] and [exdqlmMCMC()].
#'
#' @param freeze_warmup_iters Non-negative integer; number of early VB iterations
#'   during which the `(sigma, gamma)` block is held fixed.
#' @param force_after_warmup Logical; force one immediate post-warmup update.
#' @param postwarmup_damping Numeric in `(0, 1]`; damping applied after warmup.
#' @param postwarmup_damping_iters Non-negative integer; number of damped
#'   post-warmup iterations.
#' @param min_postwarmup_updates Non-negative integer; minimum number of
#'   post-warmup updates required before convergence-style gates can fire.
#'
#' @return A normalized list suitable for `vb_control$sigmagam`.
#'
#' When called with no arguments, this returns the package's conservative
#' default exAL `(sigma, gamma)` warmup profile.
#' @export
exal_make_vb_sigmagam_control <- function(
    freeze_warmup_iters = NULL,
    force_after_warmup = NULL,
    postwarmup_damping = NULL,
    postwarmup_damping_iters = NULL,
    min_postwarmup_updates = NULL) {
  cfg <- list()
  if (!is.null(freeze_warmup_iters)) cfg$freeze_warmup_iters <- freeze_warmup_iters
  if (!is.null(force_after_warmup)) cfg$force_after_warmup <- force_after_warmup
  if (!is.null(postwarmup_damping)) cfg$postwarmup_damping <- postwarmup_damping
  if (!is.null(postwarmup_damping_iters)) cfg$postwarmup_damping_iters <- postwarmup_damping_iters
  if (!is.null(min_postwarmup_updates)) cfg$min_postwarmup_updates <- min_postwarmup_updates
  .exal_sigmagam_vb_controls(cfg)
}

#' Build dynamic VB latent-state warmup control
#'
#' Returns a normalized `sts` block for `vb_control` lists used by
#' [exdqlmLDVB()].
#'
#' @param freeze_warmup_iters Non-negative integer; number of early VB iterations
#'   during which the latent `s_t` block is held fixed.
#' @param force_after_warmup Logical; force one immediate post-warmup update.
#' @param min_postwarmup_updates Non-negative integer; minimum number of
#'   post-warmup updates required before convergence-style gates can fire.
#'
#' @return A normalized list suitable for `vb_control$sts`.
#' @export
exal_make_vb_sts_control <- function(
    freeze_warmup_iters = 0L,
    force_after_warmup = TRUE,
    min_postwarmup_updates = 0L) {
  .exdqlm_sts_vb_controls(list(
    freeze_warmup_iters = freeze_warmup_iters,
    force_after_warmup = force_after_warmup,
    min_postwarmup_updates = min_postwarmup_updates
  ))
}

#' Build advanced VB control
#'
#' Returns a readable `vb_control` list for [exalStaticLDVB()] and
#' [exdqlmLDVB()]. This keeps the warmup surface explicit instead of relying on
#' ad hoc nested lists.
#'
#' @param max_iter,tol,n_samp_xi,verbose Core VB controls.
#' @param sigmagam Optional list, usually from
#'   [exal_make_vb_sigmagam_control()].
#' @param sts Optional list, usually from [exal_make_vb_sts_control()], for
#'   the dynamic latent `s_t` block in [exdqlmLDVB()].
#' @param control Optional existing control list to update.
#'
#' @return A normalized list suitable for `vb_control`.
#' @export
exal_make_vb_control <- function(
    max_iter = 150L,
    tol = 1e-4,
    n_samp_xi = 200L,
    verbose = FALSE,
    sigmagam = NULL,
    sts = NULL,
    control = NULL) {
  out <- control %||% list()
  if (!is.list(out)) out <- list()

  if (!is.null(max_iter)) out$max_iter <- as.integer(max_iter)[1L]
  if (!is.null(tol)) out$tol <- as.numeric(tol)[1L]
  if (!is.null(n_samp_xi)) out$n_samp_xi <- as.integer(n_samp_xi)[1L]
  if (!is.null(verbose)) out$verbose <- isTRUE(verbose)
  if (!is.null(sigmagam)) out$sigmagam <- .exal_sigmagam_vb_controls(sigmagam)
  if (!is.null(sts)) out$sts <- .exdqlm_sts_vb_controls(sts)

  out
}

#' Build MCMC sigmagam warmup control
#'
#' Returns a normalized `mcmc_control$sigmagam` block for [exalStaticMCMC()] and
#' [exdqlmMCMC()].
#'
#' @param freeze_burnin_iters Non-negative integer; number of burn-in iterations
#'   to hold the `(sigma, gamma)` block fixed.
#' @param freeze_only_during_burn Logical; if `TRUE`, hard freeze only applies
#'   during burn-in.
#' @param force_after_warmup Logical; force one post-warmup update.
#' @param delay_adapt_until_after_warmup Logical; keep proposal adaptation off
#'   until warmup ends.
#' @param delay_laplace_refresh_until_after_warmup Logical; keep Laplace refresh
#'   off until warmup ends.
#'
#' @return A normalized list suitable for `mcmc_control$sigmagam`.
#'
#' When called with no arguments, this returns the package's conservative
#' default exAL `(sigma, gamma)` MCMC warmup profile.
#' @export
exal_make_mcmc_sigmagam_control <- function(
    freeze_burnin_iters = NULL,
    freeze_only_during_burn = NULL,
    force_after_warmup = NULL,
    delay_adapt_until_after_warmup = NULL,
    delay_laplace_refresh_until_after_warmup = NULL) {
  cfg <- list()
  if (!is.null(freeze_burnin_iters)) cfg$freeze_burnin_iters <- freeze_burnin_iters
  if (!is.null(freeze_only_during_burn)) cfg$freeze_only_during_burn <- freeze_only_during_burn
  if (!is.null(force_after_warmup)) cfg$force_after_warmup <- force_after_warmup
  if (!is.null(delay_adapt_until_after_warmup)) cfg$delay_adapt_until_after_warmup <- delay_adapt_until_after_warmup
  if (!is.null(delay_laplace_refresh_until_after_warmup)) {
    cfg$delay_laplace_refresh_until_after_warmup <- delay_laplace_refresh_until_after_warmup
  }
  .exal_sigmagam_mcmc_controls(cfg)
}

#' Build MCMC theta warmup control
#'
#' Returns a normalized `mcmc_control$theta` block for [exdqlmMCMC()].
#'
#' @param enabled Logical; explicit on/off switch.
#' @param freeze_burnin_iters Non-negative integer; number of burn-in iterations
#'   to hold the theta block fixed.
#' @param freeze_only_during_burn Logical; if `TRUE`, hard freeze only applies
#'   during burn-in.
#' @param sparse_update_every Positive integer; sparse-update period during the
#'   warmup window.
#' @param sparse_update_until_iter Non-negative integer; last iteration where the
#'   sparse schedule is active.
#' @param force_first_postwarmup_update Logical; force one update immediately
#'   after the hard freeze / sparse schedule ends.
#' @param trace Logical; record diagnostics traces.
#'
#' @return A normalized list suitable for `mcmc_control$theta`.
#' @export
exal_make_mcmc_theta_control <- function(
    enabled = FALSE,
    freeze_burnin_iters = 0L,
    freeze_only_during_burn = TRUE,
    sparse_update_every = 1L,
    sparse_update_until_iter = 0L,
    force_first_postwarmup_update = TRUE,
    trace = TRUE) {
  out <- .exdqlm_theta_state_mcmc_controls(list(
    enabled = enabled,
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = freeze_only_during_burn,
    sparse_update_every = sparse_update_every,
    sparse_update_until_iter = sparse_update_until_iter,
    force_first_postwarmup_update = force_first_postwarmup_update,
    trace = trace
  ))
  out$enabled <- isTRUE(enabled)
  out$sparse_update_every <- suppressWarnings(as.integer(sparse_update_every)[1L])
  out$sparse_update_until_iter <- suppressWarnings(as.integer(sparse_update_until_iter)[1L])
  out$force_first_postwarmup_update <- isTRUE(force_first_postwarmup_update)
  out$trace <- isTRUE(trace)
  out
}

#' Build dynamic MCMC latent-state warmup control
#'
#' Returns a normalized `mcmc_control$latent_state` block for [exdqlmMCMC()].
#'
#' @param mode One of `"u_only"` or `"u_st_pair"`.
#' @param freeze_burnin_iters Non-negative integer; number of burn-in iterations
#'   to hold the latent-state block fixed.
#' @param freeze_only_during_burn Logical; if `TRUE`, hard freeze only applies
#'   during burn-in.
#' @param force_after_warmup Logical; force one immediate post-warmup update.
#' @param min_postwarmup_updates Non-negative integer; minimum number of
#'   post-warmup updates required before chain-health style gates can fire.
#' @param trace Logical; record diagnostics traces.
#'
#' @return A normalized list suitable for `mcmc_control$latent_state`.
#' @export
exal_make_mcmc_latent_state_control <- function(
    mode = c("u_only", "u_st_pair"),
    freeze_burnin_iters = 0L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE,
    min_postwarmup_updates = 0L,
    trace = TRUE) {
  mode <- match.arg(mode)
  .exdqlm_latent_state_mcmc_controls(list(
    mode = mode,
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = freeze_only_during_burn,
    force_after_warmup = force_after_warmup,
    min_postwarmup_updates = min_postwarmup_updates,
    trace = trace
  ), default_mode = mode)
}

#' Build DQLM sigma-only MCMC warmup control
#'
#' Returns a normalized `mcmc_control$dqlm_sigma` block for [exdqlmMCMC()] in
#' the reduced AL / DQLM branch.
#'
#' @param freeze_burnin_iters Non-negative integer; number of burn-in iterations
#'   to hold the sigma-only block fixed.
#' @param freeze_only_during_burn Logical; if `TRUE`, hard freeze only applies
#'   during burn-in.
#' @param force_after_warmup Logical; force one immediate post-warmup update.
#' @param trace Logical; record diagnostics traces.
#'
#' @return A normalized list suitable for `mcmc_control$dqlm_sigma`.
#' @export
exal_make_mcmc_dqlm_sigma_control <- function(
    freeze_burnin_iters = 0L,
    freeze_only_during_burn = TRUE,
    force_after_warmup = TRUE,
    trace = TRUE) {
  .exdqlm_dqlm_sigma_mcmc_controls(list(
    freeze_burnin_iters = freeze_burnin_iters,
    freeze_only_during_burn = freeze_only_during_burn,
    force_after_warmup = force_after_warmup,
    trace = trace
  ))
}

#' Build advanced MCMC control
#'
#' Returns a readable `mcmc_control` list for [exalStaticMCMC()] and
#' [exdqlmMCMC()]. This keeps the warmup surface explicit instead of relying on
#' ad hoc nested lists.
#'
#' @param n_burn,n_mcmc,thin,verbose Core MCMC controls.
#' @param progress_every Optional progress cadence for callers that support it.
#' @param init_from_vb Logical; initialize from a VB warm start.
#' @param vb_warm_start_control Optional VB warm-start control list, often from
#'   [exal_make_vb_control()].
#' @param sigmagam Optional list, usually from
#'   [exal_make_mcmc_sigmagam_control()].
#' @param theta Optional list, usually from [exal_make_mcmc_theta_control()].
#' @param latent_state Optional list, usually from
#'   [exal_make_mcmc_latent_state_control()].
#' @param dqlm_sigma Optional list, usually from
#'   [exal_make_mcmc_dqlm_sigma_control()].
#' @param control Optional existing control list to update.
#'
#' @return A normalized list suitable for `mcmc_control`.
#' @export
exal_make_mcmc_control <- function(
    n_burn = 2000L,
    n_mcmc = 1500L,
    thin = 1L,
    verbose = FALSE,
    progress_every = NULL,
    init_from_vb = TRUE,
    vb_warm_start_control = NULL,
    sigmagam = NULL,
    theta = NULL,
    latent_state = NULL,
    dqlm_sigma = NULL,
    control = NULL) {
  out <- control %||% list()
  if (!is.list(out)) out <- list()

  if (!is.null(n_burn)) out$n_burn <- as.integer(n_burn)[1L]
  if (!is.null(n_mcmc)) out$n_mcmc <- as.integer(n_mcmc)[1L]
  if (!is.null(thin)) out$thin <- as.integer(thin)[1L]
  if (!is.null(verbose)) out$verbose <- isTRUE(verbose)
  if (!is.null(progress_every)) out$progress_every <- as.integer(progress_every)[1L]
  if (!is.null(init_from_vb)) out$init_from_vb <- isTRUE(init_from_vb)
  if (!is.null(vb_warm_start_control)) {
    out$vb_warm_start_control <- utils::modifyList(
      out$vb_warm_start_control %||% list(),
      vb_warm_start_control
    )
  }
  if (!is.null(sigmagam)) out$sigmagam <- .exal_sigmagam_mcmc_controls(sigmagam)
  if (!is.null(theta)) out$theta <- exal_make_mcmc_theta_control(
    enabled = isTRUE((theta %||% list())$enabled),
    freeze_burnin_iters = (theta %||% list())$freeze_burnin_iters %||% (theta %||% list())$freeze_theta_burnin_iters %||% 0L,
    freeze_only_during_burn = if (is.null((theta %||% list())$freeze_only_during_burn)) TRUE else isTRUE((theta %||% list())$freeze_only_during_burn),
    sparse_update_every = (theta %||% list())$sparse_update_every %||% 1L,
    sparse_update_until_iter = (theta %||% list())$sparse_update_until_iter %||% 0L,
    force_first_postwarmup_update = if (is.null((theta %||% list())$force_first_postwarmup_update)) TRUE else isTRUE((theta %||% list())$force_first_postwarmup_update),
    trace = if (is.null((theta %||% list())$trace)) TRUE else isTRUE((theta %||% list())$trace)
  )
  if (!is.null(latent_state)) {
    latent_mode <- (latent_state %||% list())$mode %||% "u_only"
    out$latent_state <- .exdqlm_latent_state_mcmc_controls(latent_state, default_mode = latent_mode)
  }
  if (!is.null(dqlm_sigma)) out$dqlm_sigma <- .exdqlm_dqlm_sigma_mcmc_controls(dqlm_sigma)

  out
}
