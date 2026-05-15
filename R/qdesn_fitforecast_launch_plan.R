`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_fitforecast_phase_plan <- function(phase = c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full")) {
  phase <- match.arg(as.character(phase)[1L], c("smoke", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full"))
  list(
    phase = phase,
    phase_tag = gsub("_", "-", phase, fixed = TRUE),
    batch = if (identical(phase, "smoke")) "smoke" else "full",
    methods = switch(
      phase,
      smoke = "vb,mcmc",
      vb_full = "vb",
      mcmc_tt500 = "mcmc",
      mcmc_tt5000 = "mcmc",
      full = "vb,mcmc"
    ),
    fit_sizes = switch(
      phase,
      smoke = integer(0),
      vb_full = integer(0),
      mcmc_tt500 = 500L,
      mcmc_tt5000 = 5000L,
      full = integer(0)
    ),
    allow_grid_subset_default = !identical(phase, "full")
  )
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
