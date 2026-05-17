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

qdesn_dynamic_fitforecast_hash_string <- function(x, n = 14L) {
  tmp <- tempfile("qdesn_ffv2_spec_")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(enc2utf8(as.character(x)), tmp, useBytes = TRUE)
  exe <- Sys.which("sha256sum")
  if (nzchar(exe)) {
    hash <- strsplit(system2(exe, shQuote(tmp), stdout = TRUE)[[1L]], "\\s+")[[1L]][[1L]]
  } else {
    hash <- unname(tools::md5sum(tmp))
  }
  substr(hash, 1L, as.integer(n)[1L])
}

qdesn_dynamic_fitforecast_clean_token <- function(x, fallback = "na") {
  x <- as.character(x %||% fallback)[1L]
  if (is.na(x) || !nzchar(trimws(x))) x <- fallback
  x <- tolower(trimws(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) fallback else x
}

qdesn_dynamic_fitforecast_atomic_spec_id <- function(root_spec,
                                                     method = c("vb", "mcmc"),
                                                     likelihood_family = c("exal", "al")) {
  method <- match.arg(tolower(as.character(method)[1L]), c("vb", "mcmc"))
  likelihood_family <- match.arg(tolower(as.character(likelihood_family)[1L]), c("exal", "al"))
  root_spec <- as.list(root_spec)
  fields <- c(
    model_family = "qdesn",
    method = method,
    likelihood_family = likelihood_family,
    scenario_id = as.character(root_spec$scenario %||% root_spec$source_scenario %||% ""),
    family = as.character(root_spec$source_family %||% root_spec$family %||% ""),
    tau = as.character(root_spec$tau %||% ""),
    fit_size = as.character(root_spec$fit_size %||% root_spec$effective_fit_size %||% ""),
    effective_fit_size = as.character(root_spec$effective_fit_size %||% root_spec$fit_size %||% ""),
    beta_prior_type = as.character(root_spec$beta_prior_type %||% root_spec$prior %||% ""),
    root_id = as.character(root_spec$root_id %||% ""),
    dataset_cell_id = as.character(root_spec$dataset_cell_id %||% ""),
    source_hash = as.character(root_spec$source_sim_sha256 %||% root_spec$series_wide_sha256 %||% ""),
    forecast_protocol = as.character(root_spec$forecast_protocol %||% "rolling_origin_no_refit_state_update"),
    max_lead_configured = as.character(root_spec$max_lead_configured %||% root_spec$rolling_hmax %||% 30L),
    origin_stride = as.character(root_spec$origin_stride %||% root_spec$max_lead_configured %||% 30L)
  )
  digest <- qdesn_dynamic_fitforecast_hash_string(paste(names(fields), fields, sep = "=", collapse = "\n"))
  tau_label <- gsub("\\.", "p", format(as.numeric(root_spec$tau %||% NA_real_), nsmall = 2L, digits = 4L, trim = TRUE))
  paste(
    "qdesn",
    qdesn_dynamic_fitforecast_clean_token(root_spec$source_family %||% root_spec$family, "family"),
    qdesn_dynamic_fitforecast_clean_token(tau_label, "tau"),
    paste0("tt", qdesn_dynamic_fitforecast_clean_token(root_spec$fit_size %||% root_spec$effective_fit_size, "fit")),
    qdesn_dynamic_fitforecast_clean_token(root_spec$beta_prior_type %||% root_spec$prior, "prior"),
    method,
    likelihood_family,
    digest,
    sep = "__"
  )
}

qdesn_dynamic_fitforecast_atomic_spec_grid <- function(grid_df,
                                                       defaults,
                                                       methods = NULL,
                                                       likelihood_families = NULL) {
  scope <- .qdesn_static_crossstudy_execution_scope(defaults)
  methods <- methods %||% scope$methods
  likelihood_families <- likelihood_families %||% scope$likelihood_families
  rows <- list()
  for (i in seq_len(nrow(grid_df))) {
    root_spec <- qdesn_dynamic_crossstudy_enrich_root_spec(as.list(grid_df[i, , drop = FALSE]), defaults)
    for (likelihood_family in as.character(likelihood_families)) {
      for (method in as.character(methods)) {
        rows[[length(rows) + 1L]] <- data.frame(
          spec_id = qdesn_dynamic_fitforecast_atomic_spec_id(root_spec, method, likelihood_family),
          root_id = as.character(root_spec$root_id),
          dataset_cell_id = as.character(root_spec$dataset_cell_id %||% NA_character_),
          family = as.character(root_spec$source_family %||% NA_character_),
          tau = as.numeric(root_spec$tau),
          fit_size = as.integer(root_spec$fit_size),
          prior = as.character(root_spec$beta_prior_type %||% NA_character_),
          method = as.character(method),
          inference = as.character(method),
          likelihood_family = as.character(likelihood_family),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
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
