`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_fitforecast_phase_plan <- function(phase = c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full")) {
  phase <- match.arg(as.character(phase)[1L], c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full"))
  list(
    phase = phase,
    phase_tag = gsub("_", "-", phase, fixed = TRUE),
    batch = if (identical(phase, "smoke")) "smoke" else "full",
    methods = switch(
      phase,
      smoke = "vb",
      vb_full = "vb",
      mcmc_tt500 = "mcmc",
      mcmc_tt5000 = "mcmc",
      full = "vb,mcmc"
    ),
    likelihoods = switch(
      phase,
      smoke = "exal",
      vb_full = "",
      mcmc_tt500 = "",
      mcmc_tt5000 = "",
      full = ""
    ),
    fit_sizes = switch(
      phase,
      smoke = 500L,
      vb_full = integer(0),
      mcmc_tt500 = 500L,
      mcmc_tt5000 = 5000L,
      full = integer(0)
    ),
    allow_grid_subset_default = !identical(phase, "full")
  )
}

qdesn_dynamic_fitforecast_approval_state <- function(phase,
                                                     launch_env = Sys.getenv("QDESN_FFV2_LAUNCH_APPROVED", "false"),
                                                     tt5000_env = Sys.getenv("QDESN_FFV2_TT5000_APPROVED", "false")) {
  phase <- match.arg(as.character(phase)[1L], c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full"))
  truthy <- function(x) {
    tolower(trimws(as.character(x)[1L])) %in% c("1", "true", "yes", "y")
  }
  list(
    phase = phase,
    launch_approved = truthy(launch_env),
    tt5000_approved = truthy(tt5000_env),
    requires_tt5000_approval = phase %in% c("mcmc_tt5000", "full")
  )
}

qdesn_dynamic_fitforecast_assert_launch_approved <- function(phase) {
  state <- qdesn_dynamic_fitforecast_approval_state(phase)
  if (!isTRUE(state$launch_approved)) {
    stop(
      paste(
        "Refusing to launch Q-DESN fit+forecast v2 compute.",
        "Set QDESN_FFV2_LAUNCH_APPROVED=true for an approved staged run."
      ),
      call. = FALSE
    )
  }
  if (isTRUE(state$requires_tt5000_approval) && !isTRUE(state$tt5000_approved)) {
    stop(
      paste(
        "Refusing to launch Q-DESN TT5000/full fit+forecast v2 compute.",
        "Set QDESN_FFV2_TT5000_APPROVED=true after fresh human approval."
      ),
      call. = FALSE
    )
  }
  invisible(state)
}

qdesn_dynamic_fitforecast_required_packages <- function() {
  unique(c(
    "pkgload", "jsonlite", "yaml",
    "ggplot2", "dplyr", "tidyr", "tibble", "scales",
    "MASS", "numDeriv", "matrixStats", "purrr", "readr",
    "patchwork", "stringr", "truncnorm"
  ))
}

qdesn_dynamic_fitforecast_assert_required_packages <- function(packages = qdesn_dynamic_fitforecast_required_packages()) {
  packages <- unique(as.character(packages))
  packages <- packages[nzchar(packages)]
  missing <- packages[!vapply(packages, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing)) {
    stop(
      sprintf(
        "Missing required Q-DESN fit+forecast v2 packages: %s. Install them once before launching; validation smoke/full runs must not auto-install packages.",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(packages)
}

qdesn_validation_filter_dynamic_grid <- function(grid_df,
                                                 fit_sizes = integer(0),
                                                 families = character(0),
                                                 taus = numeric(0),
                                                 priors = character(0),
                                                 root_ids = character(0)) {
  out <- as.data.frame(grid_df, stringsAsFactors = FALSE)
  if (!nrow(out)) return(out)
  fit_sizes <- as.integer(fit_sizes %||% integer(0))
  fit_sizes <- fit_sizes[is.finite(fit_sizes)]
  families <- as.character(families %||% character(0))
  families <- families[nzchar(families)]
  taus <- as.numeric(taus %||% numeric(0))
  taus <- taus[is.finite(taus)]
  priors <- as.character(priors %||% character(0))
  priors <- priors[nzchar(priors)]
  root_ids <- as.character(root_ids %||% character(0))
  root_ids <- root_ids[nzchar(root_ids)]

  if (length(fit_sizes) && "fit_size" %in% names(out)) {
    out <- out[as.integer(out$fit_size) %in% fit_sizes, , drop = FALSE]
  }
  if (length(families) && "source_family" %in% names(out)) {
    out <- out[as.character(out$source_family) %in% families, , drop = FALSE]
  }
  if (length(taus) && "tau" %in% names(out)) {
    out <- out[as.numeric(out$tau) %in% taus, , drop = FALSE]
  }
  if (length(priors) && "beta_prior_type" %in% names(out)) {
    out <- out[as.character(out$beta_prior_type) %in% priors, , drop = FALSE]
  }
  if (length(root_ids) && "root_id" %in% names(out)) {
    out <- out[as.character(out$root_id) %in% root_ids, , drop = FALSE]
  }
  rownames(out) <- NULL
  out
}
