`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_tmv1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_tmv1_safe_token <- function(x) {
  out <- tolower(trimws(as.character(x)[1L]))
  out <- gsub("[^a-z0-9]+", "_", out)
  out <- gsub("^_+|_+$", "", out)
  if (!nzchar(out)) "x" else out
}

qdesn_tmv1_targets <- function() {
  data.frame(
    target_cell_id = c(
      "al_normal_t0p05",
      "exal_gausmix_t0p25",
      "exal_laplace_t0p25"
    ),
    likelihood_target = c("al", "exal", "exal"),
    family = c("normal", "gausmix", "laplace"),
    tau = c(0.05, 0.25, 0.25),
    parent_profile_id = c(
      "tor1_15_mcvbc_055_al",
      "tor1_23_arfc1_parent_exal_gausmix_t0p25_r01_full_3ed",
      "tor1_28_mcvbc_045_exal"
    ),
    target_role = c(
      "priority_fit_and_forecast_gap",
      "priority_fit_and_forecast_gap",
      "solved_negative_control"
    ),
    primary_target = c(TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE
  )
}

qdesn_tmv1_resolve_parents <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  targets <- qdesn_tmv1_targets()
  catalog_path <- file.path(
    repo_root, "config", "validation",
    "qdesn_dynamic_fitforecast_v2_500obs_trainonly_rebaseline_v1_profiles.csv"
  )
  if (!file.exists(catalog_path)) {
    stop(sprintf("Missing corrected train-only parent catalog: %s", catalog_path), call. = FALSE)
  }
  catalog <- utils::read.csv(catalog_path, check.names = FALSE, stringsAsFactors = FALSE)
  keep <- c(
    "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha",
    "rho", "pi_w", "pi_in", "washout", "add_bias", "readout_y_lags",
    "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "x_feature_count",
    "legacy_candidate_id", "legacy_run_tag", "source_fit_request_path",
    "source_fit_request_sha256", "source_registry_hash_value"
  )
  missing <- setdiff(keep, names(catalog))
  if (length(missing)) {
    stop(sprintf("Parent catalog is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  parents <- catalog[catalog$screening_profile_id %in% targets$parent_profile_id, keep, drop = FALSE]
  parents <- parents[match(targets$parent_profile_id, parents$screening_profile_id), , drop = FALSE]
  if (nrow(parents) != nrow(targets) || anyNA(parents$D)) {
    stop("Could not resolve all three corrected-protocol parent designs.", call. = FALSE)
  }
  out <- cbind(targets, parents[, setdiff(names(parents), "screening_profile_id"), drop = FALSE])

  expected <- data.frame(
    D = c(1L, 1L, 1L),
    n_each = c(6L, 4L, 4L),
    m = c(1L, 2L, 1L),
    alpha = c(0.00075, 0.001, 0.0025),
    rho = c(0.35, 0.45, 0.45),
    pi_w = c(0.00075, 0.0025, 0.001),
    pi_in = c(0.03, 0.05, 0.03),
    rhs_tau0 = rep(3e-4, 3L)
  )
  numeric_match <- vapply(names(expected), function(nm) {
    all(abs(as.numeric(out[[nm]]) - as.numeric(expected[[nm]])) <= 1e-12)
  }, logical(1L))
  if (!all(numeric_match)) {
    stop(sprintf(
      "Corrected parent definitions changed unexpectedly: %s",
      paste(names(numeric_match)[!numeric_match], collapse = ", ")
    ), call. = FALSE)
  }
  if (any(as.integer(out$D) != 1L)) {
    stop("Mechanism v1 is frozen to the resolved D=1 parent designs.", call. = FALSE)
  }
  out
}

qdesn_tmv1_bundle_contract <- function() {
  data.frame(
    bundle_id = c("raw", "c12", "c123", "sr"),
    bundle_order = 1:4,
    input_mode = c("raw_y_lags", rep("dlm_decomp_lags", 3L)),
    input_builder = c("raw_y_lags", "component_lags", "component_lags", "state_resid_y"),
    harmonics = c("1,2", "1,2", "1,2,3", "1,2"),
    expected_specs = c(42L, 18L, 18L, 12L),
    stringsAsFactors = FALSE
  )
}

qdesn_tmv1_decomposition <- function(bundle_id) {
  bundle_id <- as.character(bundle_id)[1L]
  if (identical(bundle_id, "raw")) return(list(enabled = FALSE))
  harmonics <- if (identical(bundle_id, "c123")) 1:3 else 1:2
  builder <- if (identical(bundle_id, "sr")) "state_resid_y" else "component_lags"
  list(
    enabled = TRUE,
    backend = "r",
    state_estimate = "filtered",
    components = as.list(c("trend", "seasonal", "residual")),
    input_builder = builder,
    trend = list(degree = 1L),
    seasonal = list(period = 90L, harmonics = as.list(harmonics), auto = list(enabled = FALSE)),
    regression = list(enabled = FALSE, dynamic = FALSE),
    transfer = list(enabled = FALSE),
    input_lags_mode = "component",
    input_lags = list(
      trend = as.list(1:2),
      seasonal = as.list(1:3),
      residual = as.list(1:2)
    ),
    state_resid_y = list(
      state_lags = as.list(0:1),
      residual_lags = as.list(0:2),
      y_lags = as.list(1:2),
      include_xreg = FALSE
    ),
    discount = list(
      trend = 0.99,
      seasonal = 0.99,
      regression = 1.0,
      transfer_zeta = 0.99,
      transfer_psi = 1.0
    ),
    variance = list(mode = "unknown_constant", l0 = 1, S0 = 1),
    forecast = list(residual_recursion = "sampled_path"),
    sim_xreg = list(policy = "repeat_last")
  )
}

.qdesn_tmv1_arm_rows <- function(parent) {
  primary <- isTRUE(parent$primary_target[[1L]])
  raw <- if (primary) {
    data.frame(
      bundle_id = "raw",
      arm_code = c("parent_exact", "topology_repair", "compact_raw"),
      arm_class = c("parent_control", "mechanism_repair", "mechanism_compact"),
      topology_mode = c("parent", "repair_parent", "compact_active"),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      bundle_id = "raw", arm_code = "parent_exact", arm_class = "parent_control",
      topology_mode = "parent", stringsAsFactors = FALSE
    )
  }
  decomp <- data.frame(
    bundle_id = c("c12", "c123"),
    arm_code = c("compact_c12", "compact_c123"),
    arm_class = "mechanism_decomposition",
    topology_mode = "compact_active",
    stringsAsFactors = FALSE
  )
  if (primary) {
    decomp <- rbind(decomp, data.frame(
      bundle_id = "sr", arm_code = "compact_state_resid",
      arm_class = "mechanism_decomposition", topology_mode = "compact_active",
      stringsAsFactors = FALSE
    ))
  }
  rbind(raw, decomp)
}

qdesn_tmv1_build_plan <- function(repo_root = ".") {
  parents <- qdesn_tmv1_resolve_parents(repo_root)
  reservoir_seeds <- c(910001L, 910002L)
  profiles <- list()
  assignments <- list()
  profile_i <- 0L

  for (i in seq_len(nrow(parents))) {
    parent <- parents[i, , drop = FALSE]
    arms <- .qdesn_tmv1_arm_rows(parent)
    for (j in seq_len(nrow(arms))) {
      arm <- arms[j, , drop = FALSE]
      for (r in seq_along(reservoir_seeds)) {
        profile_i <- profile_i + 1L
        compact <- grepl("^compact_", arm$arm_code[[1L]])
        repair <- identical(arm$arm_code[[1L]], "topology_repair")
        n_each <- if (compact) 12L else as.integer(parent$n_each[[1L]])
        m <- if (compact) 3L else as.integer(parent$m[[1L]])
        alpha <- if (compact) 0.01 else as.numeric(parent$alpha[[1L]])
        rho <- if (compact) 0.60 else as.numeric(parent$rho[[1L]])
        pi_w <- if (compact || repair) min(1, 2 / n_each) else as.numeric(parent$pi_w[[1L]])
        pi_in <- if (compact || repair) min(1, 2 / (m + 1L)) else as.numeric(parent$pi_in[[1L]])
        readout_y_lags <- if (compact) 3L else as.integer(parent$readout_y_lags[[1L]])
        profile_id <- sprintf(
          "qtm1_%s_%s_%s_r%02d",
          arm$bundle_id[[1L]], qdesn_tmv1_safe_token(parent$target_cell_id[[1L]]),
          qdesn_tmv1_safe_token(arm$arm_code[[1L]]), r
        )
        profiles[[profile_i]] <- data.frame(
          screening_profile_id = profile_id,
          screening_stage = "mcmc_trainonly_mechanism_v1",
          screening_wave = "trainonly_mechanism_v1_2026_08_05",
          profile_role = as.character(arm$arm_code[[1L]]),
          enabled = TRUE,
          D = 1L,
          n_each = n_each,
          n_tilde_each = 0L,
          m = m,
          alpha = alpha,
          rho = rho,
          pi_w = pi_w,
          pi_in = pi_in,
          washout = 300L,
          add_bias = TRUE,
          seed = reservoir_seeds[[r]],
          readout_y_lags = readout_y_lags,
          reservoir_lags = 0L,
          rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
          dimension_p_estimate = as.integer(1L + readout_y_lags + n_each),
          p_over_n_tt500 = (1 + readout_y_lags + n_each) / 500,
          x_feature_count = 5L,
          target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":"),
          target_cell_id = as.character(parent$target_cell_id[[1L]]),
          target_role = as.character(parent$target_role[[1L]]),
          primary_target = as.logical(parent$primary_target[[1L]]),
          target_family = as.character(parent$family[[1L]]),
          target_tau = as.numeric(parent$tau[[1L]]),
          likelihood_target = as.character(parent$likelihood_target[[1L]]),
          parent_profile_id = as.character(parent$parent_profile_id[[1L]]),
          parent_candidate_id = as.character(parent$legacy_candidate_id[[1L]]),
          parent_run_tag = as.character(parent$legacy_run_tag[[1L]]),
          parent_fit_request_path = as.character(parent$source_fit_request_path[[1L]]),
          parent_fit_request_sha256 = as.character(parent$source_fit_request_sha256[[1L]]),
          parent_source_registry_hash = as.character(parent$source_registry_hash_value[[1L]]),
          bundle_id = as.character(arm$bundle_id[[1L]]),
          arm_code = as.character(arm$arm_code[[1L]]),
          arm_class = as.character(arm$arm_class[[1L]]),
          topology_mode = as.character(arm$topology_mode[[1L]]),
          reservoir_replicate = as.integer(r),
          paired_reservoir_seed = reservoir_seeds[[r]],
          stringsAsFactors = FALSE
        )
        assignments[[profile_i]] <- data.frame(
          assignment_key = paste(profile_id, parent$family[[1L]], qdesn_tmv1_tau_key(parent$tau[[1L]]), sep = "\r"),
          family = as.character(parent$family[[1L]]),
          tau = as.numeric(parent$tau[[1L]]),
          likelihood_target = as.character(parent$likelihood_target[[1L]]),
          cell_status = as.character(parent$target_role[[1L]]),
          target_profile_rank = j,
          screening_profile_id = profile_id,
          target_cell_id = as.character(parent$target_cell_id[[1L]]),
          bundle_id = as.character(arm$bundle_id[[1L]]),
          arm_code = as.character(arm$arm_code[[1L]]),
          reservoir_replicate = as.integer(r),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  profiles <- do.call(rbind, profiles)
  assignments <- do.call(rbind, assignments)
  rownames(profiles) <- NULL
  rownames(assignments) <- NULL
  counts <- table(profiles$bundle_id) * 3L
  expected <- setNames(qdesn_tmv1_bundle_contract()$expected_specs, qdesn_tmv1_bundle_contract()$bundle_id)
  if (!identical(as.integer(counts[names(expected)]), as.integer(expected))) {
    stop("Mechanism v1 bundle counts do not match the frozen 90-spec contract.", call. = FALSE)
  }
  if (nrow(profiles) != 30L || nrow(assignments) != 30L) {
    stop("Mechanism v1 must contain 30 profiles and 30 cell assignments.", call. = FALSE)
  }
  list(
    targets = qdesn_tmv1_targets(),
    parents = parents,
    bundles = qdesn_tmv1_bundle_contract(),
    profiles = profiles,
    assignments = assignments
  )
}

qdesn_tmv1_topology_audit <- function(profiles) {
  if (!exists(".qdesn_arv1_build_d1_reservoir", mode = "function")) {
    stop("Source qdesn_alpha_rho_topology_v1.R before running the topology audit.", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    reservoir <- .qdesn_arv1_build_d1_reservoir(
      n = as.integer(p$n_each[[1L]]),
      m = as.integer(p$m[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      pi_w = as.numeric(p$pi_w[[1L]]),
      pi_in = as.numeric(p$pi_in[[1L]]),
      seed = as.integer(p$seed[[1L]])
    )
    W <- reservoir$W
    Win <- reservoir$Win
    data.frame(
      screening_profile_id = p$screening_profile_id[[1L]],
      target_cell_id = p$target_cell_id[[1L]],
      bundle_id = p$bundle_id[[1L]],
      arm_code = p$arm_code[[1L]],
      arm_class = p$arm_class[[1L]],
      reservoir_replicate = as.integer(p$reservoir_replicate[[1L]]),
      seed = as.integer(p$seed[[1L]]),
      recurrent_nnz = sum(W != 0),
      recurrent_zero_rows = sum(rowSums(W != 0) == 0),
      input_nnz = sum(Win != 0),
      input_zero_rows = sum(rowSums(Win != 0) == 0),
      recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
      input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
      total_topology_valid = sum(W != 0) > 0 && sum(Win != 0) > 0,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  nonparent <- out[out$arm_code != "parent_exact", , drop = FALSE]
  if (any(!nonparent$total_topology_valid)) {
    stop("At least one proposed mechanism arm has zero recurrent or input connectivity.", call. = FALSE)
  }
  pair_key <- paste(out$target_cell_id, out$reservoir_replicate, sep = "\r")
  compact <- out[grepl("^compact_", out$arm_code), , drop = FALSE]
  invariant <- vapply(split(seq_len(nrow(compact)), pair_key[grepl("^compact_", out$arm_code)]), function(idx) {
    length(unique(compact$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(compact$input_mask_sha256[idx])) == 1L
  }, logical(1L))
  if (!all(invariant)) {
    stop("Compact mechanism arms do not share topology within a paired cell/seed block.", call. = FALSE)
  }
  out
}
