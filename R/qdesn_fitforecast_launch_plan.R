`%||%` <- function(a, b) if (is.null(a)) b else a

qdesn_dynamic_fitforecast_phase_plan <- function(phase = c("smoke", "pilot", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full")) {
  phase <- match.arg(as.character(phase)[1L], c("smoke", "pilot", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full"))
  list(
    phase = phase,
    phase_tag = gsub("_", "-", phase, fixed = TRUE),
    batch = if (phase %in% c("smoke", "pilot")) "smoke" else "full",
    methods = switch(
      phase,
      smoke = "vb",
      pilot = "vb,mcmc",
      vb_full = "vb",
      mcmc_tt500 = "mcmc",
      mcmc_tt5000 = "mcmc",
      full = "vb,mcmc"
    ),
    likelihoods = switch(
      phase,
      smoke = "exal",
      pilot = "exal",
      vb_full = "",
      mcmc_tt500 = "",
      mcmc_tt5000 = "",
      full = ""
    ),
    fit_sizes = switch(
      phase,
      smoke = 500L,
      pilot = 500L,
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
  phase <- match.arg(as.character(phase)[1L], c("smoke", "pilot", "vb_full", "mcmc_tt500", "mcmc_tt5000", "full"))
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

qdesn_dynamic_fitforecast_screening_cfg <- function(defaults) {
  defaults$screening_profiles %||% defaults$qdesn_screening_profiles %||% list()
}

qdesn_dynamic_fitforecast_screening_enabled <- function(defaults) {
  isTRUE((qdesn_dynamic_fitforecast_screening_cfg(defaults) %||% list())$enabled %||% FALSE)
}

.qdesn_dynamic_fitforecast_csv_flag <- function(x, default = TRUE) {
  if (is.null(x) || !length(x)) return(rep(default, 0L))
  raw <- tolower(trimws(as.character(x)))
  out <- raw %in% c("true", "t", "yes", "y", "1")
  missing <- is.na(raw) | !nzchar(raw)
  out[missing] <- default
  out
}

qdesn_dynamic_fitforecast_load_screening_profiles <- function(defaults,
                                                              path = NULL,
                                                              only_enabled = TRUE,
                                                              validate = TRUE) {
  cfg <- qdesn_dynamic_fitforecast_screening_cfg(defaults)
  path <- path %||% cfg$csv %||% cfg$path %||% cfg$profiles_csv
  if (is.null(path) || !nzchar(as.character(path)[1L])) {
    if (qdesn_dynamic_fitforecast_screening_enabled(defaults)) {
      stop("screening_profiles.enabled is TRUE but no screening profile CSV path was supplied.", call. = FALSE)
    }
    return(data.frame(stringsAsFactors = FALSE))
  }

  profile_path <- .qdesn_validation_resolve_path(path, must_work = TRUE)
  out <- utils::read.csv(profile_path, stringsAsFactors = FALSE)
  if (!nrow(out)) {
    stop(sprintf("Screening profile CSV is empty: %s", profile_path), call. = FALSE)
  }
  required <- c(
    "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
    "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
    "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500"
  )
  missing <- setdiff(required, names(out))
  if (length(missing)) {
    stop(sprintf(
      "Screening profile CSV is missing required column(s): %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }

  out$screening_profile_id <- as.character(out$screening_profile_id)
  out$enabled <- if ("enabled" %in% names(out)) {
    .qdesn_dynamic_fitforecast_csv_flag(out$enabled, default = TRUE)
  } else {
    rep(TRUE, nrow(out))
  }
  if (isTRUE(only_enabled)) {
    out <- out[out$enabled, , drop = FALSE]
  }
  if (!nrow(out)) {
    stop("No enabled Q-DESN screening profiles remain after filtering.", call. = FALSE)
  }

  int_cols <- c("D", "n_each", "n_tilde_each", "m", "washout", "seed", "readout_y_lags", "reservoir_lags", "dimension_p_estimate")
  dbl_cols <- c("alpha", "rho", "pi_w", "pi_in", "rhs_tau0", "p_over_n_tt500")
  for (nm in intersect(int_cols, names(out))) out[[nm]] <- as.integer(out[[nm]])
  for (nm in intersect(dbl_cols, names(out))) out[[nm]] <- as.numeric(out[[nm]])
  out$profile_role <- as.character(out$profile_role %||% "primary")
  out$screening_stage <- as.character(out$screening_stage %||% NA_character_)
  out$screening_wave <- as.character(out$screening_wave %||% NA_character_)

  problems <- character(0)
  if (any(!nzchar(out$screening_profile_id))) {
    problems <- c(problems, "screening_profile_id must be non-empty")
  }
  if (anyDuplicated(out$screening_profile_id)) {
    problems <- c(problems, "screening_profile_id values must be unique")
  }
  if (any(!is.finite(out$D) | out$D < 1L)) {
    problems <- c(problems, "D must be positive")
  }
  if (any(!is.finite(out$n_each) | out$n_each < 1L)) {
    problems <- c(problems, "n_each must be positive")
  }
  if (any(!is.finite(out$m) | out$m < 0L)) {
    problems <- c(problems, "m must be nonnegative")
  }
  if (any(!is.finite(out$washout) | out$washout < 0L)) {
    problems <- c(problems, "washout must be nonnegative")
  }
  if (any(!is.finite(out$rhs_tau0) | out$rhs_tau0 <= 0)) {
    problems <- c(problems, "rhs_tau0 must be positive")
  }
  if (isTRUE(validate)) {
    gate <- cfg$dimension_gate %||% list()
    primary_max <- as.numeric(gate$primary_p_over_n_max %||% Inf)[1L]
    primary <- tolower(as.character(out$profile_role %||% "primary")) == "primary"
    if (is.finite(primary_max) && any(primary & is.finite(out$p_over_n_tt500) & out$p_over_n_tt500 > primary_max)) {
      problems <- c(problems, sprintf("primary p_over_n_tt500 exceeds %.3f", primary_max))
    }
  }
  if (length(problems)) {
    stop(paste(c("Q-DESN screening profile validation failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }

  rownames(out) <- NULL
  attr(out, "profile_path") <- profile_path
  out
}

qdesn_dynamic_fitforecast_screening_reservoir_cfg <- function(defaults, profile) {
  profiles <- qdesn_dynamic_fitforecast_load_screening_profiles(defaults, only_enabled = FALSE)
  profile <- as.character(profile)[1L]
  row <- profiles[as.character(profiles$screening_profile_id) == profile, , drop = FALSE]
  if (!nrow(row)) return(NULL)
  row <- row[1L, , drop = FALSE]
  D <- as.integer(row$D[1L])
  n_each <- as.integer(row$n_each[1L])
  n_tilde_each <- as.integer(row$n_tilde_each[1L])
  rep_len_safe <- function(value, n) {
    if (n <= 0L) return(numeric(0))
    rep(value, n)
  }
  list(
    D = D,
    n = as.integer(rep_len_safe(n_each, D)),
    n_tilde = as.integer(rep_len_safe(n_tilde_each, max(0L, D - 1L))),
    m = as.integer(row$m[1L]),
    alpha = as.numeric(rep_len_safe(as.numeric(row$alpha[1L]), D)),
    rho = as.numeric(rep_len_safe(as.numeric(row$rho[1L]), D)),
    act_f = rep("tanh", D),
    act_k = rep("identity", D),
    pi_w = as.numeric(rep_len_safe(as.numeric(row$pi_w[1L]), D)),
    pi_in = as.numeric(rep_len_safe(as.numeric(row$pi_in[1L]), D)),
    washout = as.integer(row$washout[1L]),
    add_bias = .qdesn_dynamic_fitforecast_csv_flag(row$add_bias[1L], default = TRUE)[1L],
    seed = as.integer(row$seed[1L])
  )
}

qdesn_dynamic_fitforecast_grid_prior_types <- function(defaults) {
  cfg <- qdesn_dynamic_fitforecast_screening_cfg(defaults)
  priors <- as.character(unlist(cfg$priors %||% (defaults$reference_contract %||% list())$expected_priors %||% c("ridge", "rhs_ns"), use.names = FALSE))
  priors <- unique(tolower(priors[nzchar(priors)]))
  bad <- setdiff(priors, c("ridge", "rhs_ns"))
  if (length(bad)) {
    stop(sprintf("Unsupported Q-DESN prior type(s) requested: %s", paste(bad, collapse = ", ")), call. = FALSE)
  }
  if (!length(priors)) priors <- c("ridge", "rhs_ns")
  priors
}

qdesn_dynamic_fitforecast_apply_screening_overrides <- function(cfg,
                                                                root_spec,
                                                                method = c("vb", "mcmc")) {
  method <- match.arg(method)
  root_spec <- as.list(root_spec)
  if (!is.null(root_spec$readout_y_lags) && is.finite(as.integer(root_spec$readout_y_lags)[1L])) {
    cfg$lags <- modifyList(cfg$lags %||% list(), list(m_y = as.integer(root_spec$readout_y_lags)[1L]))
  }
  if (!is.null(root_spec$reservoir_lags) && is.finite(as.integer(root_spec$reservoir_lags)[1L])) {
    cfg$readout <- modifyList(cfg$readout %||% list(), list(reservoir_lags = as.integer(root_spec$reservoir_lags)[1L]))
  }
  if (identical(as.character(root_spec$beta_prior_type %||% ""), "rhs_ns") &&
      !is.null(root_spec$rhs_tau0) && is.finite(as.numeric(root_spec$rhs_tau0)[1L])) {
    cfg$inference[[method]]$priors <- modifyList(cfg$inference[[method]]$priors %||% list(), list())
    cfg$inference[[method]]$priors$beta <- modifyList(cfg$inference[[method]]$priors$beta %||% list(), list())
    cfg$inference[[method]]$priors$beta$rhs_ns <- modifyList(
      cfg$inference[[method]]$priors$beta$rhs_ns %||% list(),
      list(tau0 = as.numeric(root_spec$rhs_tau0)[1L])
    )
  }
  cfg
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
          reservoir_profile = as.character(root_spec$reservoir_profile %||% NA_character_),
          screening_profile_id = as.character(root_spec$screening_profile_id %||% NA_character_),
          rhs_tau0 = as.numeric(root_spec$rhs_tau0 %||% NA_real_),
          readout_y_lags = as.integer(root_spec$readout_y_lags %||% NA_integer_),
          reservoir_lags = as.integer(root_spec$reservoir_lags %||% NA_integer_),
          dimension_p_estimate = as.integer(root_spec$dimension_p_estimate %||% NA_integer_),
          p_over_n_tt500 = as.numeric(root_spec$p_over_n_tt500 %||% NA_real_),
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
