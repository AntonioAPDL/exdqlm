`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

qdesn_arv1_tau_key <- function(x) sprintf("%.8f", as.numeric(x))

qdesn_arv1_safe_token <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_|_$", "", x)
}

qdesn_arv1_targets <- function() {
  data.frame(
    target_cell_id = c(
      "al_gausmix_t0p05",
      "al_normal_t0p05",
      "exal_laplace_t0p05",
      "exal_gausmix_t0p25",
      "exal_laplace_t0p25"
    ),
    likelihood_target = c("al", "al", "exal", "exal", "exal"),
    family = c("gausmix", "normal", "laplace", "gausmix", "laplace"),
    tau = c(0.05, 0.05, 0.05, 0.25, 0.25),
    parent_profile_id = c(
      "mcvbc_004_al",
      "mcvbc_057_al",
      "tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
      "mcvbc_018_exal",
      "mcvbc_045_exal"
    ),
    target_role = c(
      "hard_fit_gap",
      "hard_fit_and_forecast_gap",
      "hard_fit_gap_strong_forecast",
      "hard_fit_and_transport_gap",
      "resolved_negative_control"
    ),
    stringsAsFactors = FALSE
  )
}

.qdesn_arv1_read_profiles <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing parent profile catalog: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}

qdesn_arv1_resolve_parent_profiles <- function(repo_root = ".") {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  targets <- qdesn_arv1_targets()
  catalogs <- c(
    file.path(
      repo_root, "config", "validation",
      "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_profiles.csv"
    ),
    file.path(
      repo_root, "config", "validation",
      "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4b_gausmix005_pinball_refinement_profiles.csv"
    )
  )
  keep_cols <- c(
    "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
    "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
    "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500"
  )
  profile_rows <- do.call(rbind, lapply(catalogs, function(path) {
    rows <- .qdesn_arv1_read_profiles(path)
    missing_cols <- setdiff(keep_cols, names(rows))
    if (length(missing_cols)) {
      stop(sprintf("Parent profile catalog '%s' is missing: %s", path, paste(missing_cols, collapse = ", ")), call. = FALSE)
    }
    rows[, keep_cols, drop = FALSE]
  }))
  profile_rows <- profile_rows[profile_rows$screening_profile_id %in% targets$parent_profile_id, , drop = FALSE]

  resolved <- lapply(targets$parent_profile_id, function(profile_id) {
    rows <- profile_rows[profile_rows$screening_profile_id == profile_id, , drop = FALSE]
    if (!nrow(rows)) stop(sprintf("Could not resolve parent profile '%s'.", profile_id), call. = FALSE)
    signature_cols <- setdiff(names(rows), "screening_profile_id")
    signatures <- unique(do.call(paste, c(rows[signature_cols], sep = "\r")))
    if (length(signatures) != 1L) {
      stop(sprintf("Parent profile '%s' has inconsistent definitions.", profile_id), call. = FALSE)
    }
    rows[1L, , drop = FALSE]
  })
  resolved <- do.call(rbind, resolved)
  rownames(resolved) <- NULL
  out <- merge(targets, resolved, by.x = "parent_profile_id", by.y = "screening_profile_id", sort = FALSE)
  out <- out[match(targets$target_cell_id, out$target_cell_id), , drop = FALSE]
  if (nrow(out) != nrow(targets) || anyNA(out$D)) {
    stop("Failed to resolve every alpha/rho topology target parent.", call. = FALSE)
  }
  if (any(as.integer(out$D) != 1L)) {
    stop("Alpha/rho topology v1 is frozen to the five D=1 coherent parent designs.", call. = FALSE)
  }
  out
}

qdesn_arv1_alpha_levels <- function() {
  c(0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.10, 0.25, 0.50, 0.80, 0.95)
}

qdesn_arv1_rho_levels <- function() {
  c(0.05, 0.15, 0.30, 0.50, 0.70, 0.85, 0.93, 0.97, 0.99, 0.997)
}

.qdesn_arv1_transform_points <- function(df) {
  alpha_bounds <- range(log10(qdesn_arv1_alpha_levels()))
  rho_bounds <- range(stats::qlogis(qdesn_arv1_rho_levels()))
  data.frame(
    x = (log10(as.numeric(df$alpha)) - alpha_bounds[[1L]]) / diff(alpha_bounds),
    y = (stats::qlogis(as.numeric(df$rho)) - rho_bounds[[1L]]) / diff(rho_bounds)
  )
}

.qdesn_arv1_maximin <- function(candidates, anchors, n_select = 24L) {
  candidates <- candidates[order(candidates$alpha, candidates$rho), , drop = FALSE]
  selected <- anchors
  chosen <- vector("list", n_select)
  for (i in seq_len(n_select)) {
    candidate_xy <- .qdesn_arv1_transform_points(candidates)
    selected_xy <- .qdesn_arv1_transform_points(selected)
    min_distance <- vapply(seq_len(nrow(candidate_xy)), function(j) {
      min((candidate_xy$x[[j]] - selected_xy$x)^2 + (candidate_xy$y[[j]] - selected_xy$y)^2)
    }, numeric(1L))
    pick <- which(min_distance == max(min_distance))[1L]
    chosen[[i]] <- candidates[pick, , drop = FALSE]
    selected <- rbind(selected, candidates[pick, , drop = FALSE])
    candidates <- candidates[-pick, , drop = FALSE]
  }
  do.call(rbind, chosen)
}

qdesn_arv1_arm_design <- function() {
  controls <- data.frame(
    arm_code = c("parent_exact", "recurrence_only", "input_only", "full_topology"),
    arm_class = "mechanism_control",
    topology_mode = c("parent", "repair_w", "repair_win", "repair_w_win"),
    alpha = NA_real_,
    rho = NA_real_,
    stringsAsFactors = FALSE
  )
  boundary <- data.frame(
    arm_code = sprintf("boundary_%02d", seq_len(8L)),
    arm_class = "broad_boundary",
    topology_mode = "repair_w_win",
    alpha = c(0.0001, 0.0001, 0.001, 0.003, 0.03, 0.25, 0.80, 0.95),
    rho = c(0.05, 0.997, 0.30, 0.97, 0.99, 0.93, 0.85, 0.15),
    stringsAsFactors = FALSE
  )
  full <- expand.grid(
    alpha = qdesn_arv1_alpha_levels(),
    rho = qdesn_arv1_rho_levels(),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  boundary_key <- paste(boundary$alpha, boundary$rho, sep = "\r")
  full_key <- paste(full$alpha, full$rho, sep = "\r")
  candidates <- full[!full_key %in% boundary_key, , drop = FALSE]
  space_fill <- .qdesn_arv1_maximin(candidates, boundary[, c("alpha", "rho")], n_select = 24L)
  space_fill <- data.frame(
    arm_code = sprintf("spacefill_%02d", seq_len(nrow(space_fill))),
    arm_class = "broad_spacefill",
    topology_mode = "repair_w_win",
    alpha = space_fill$alpha,
    rho = space_fill$rho,
    stringsAsFactors = FALSE
  )
  out <- rbind(controls, boundary, space_fill)
  out$arm_index <- seq_len(nrow(out))
  if (nrow(out) != 36L) stop("Alpha/rho topology arm design must contain 36 arms.", call. = FALSE)
  broad <- out[out$arm_class != "mechanism_control", , drop = FALSE]
  if (anyDuplicated(paste(broad$alpha, broad$rho, sep = "\r"))) {
    stop("Broad alpha/rho points must be unique.", call. = FALSE)
  }
  out
}

qdesn_arv1_build_plan <- function(repo_root = ".") {
  parents <- qdesn_arv1_resolve_parent_profiles(repo_root)
  arms <- qdesn_arv1_arm_design()
  profiles <- list()
  assignments <- list()
  counter <- 0L

  for (target_i in seq_len(nrow(parents))) {
    parent <- parents[target_i, , drop = FALSE]
    n_each <- as.integer(parent$n_each[[1L]])
    m <- as.integer(parent$m[[1L]])
    repaired_pi_w <- min(1, 4 / n_each)
    repaired_pi_in <- max(as.numeric(parent$pi_in[[1L]]), min(1, 2 / (m + 1)))
    seeds <- c(as.integer(parent$seed[[1L]]), as.integer(parent$seed[[1L]]) + 900001L)

    for (arm_i in seq_len(nrow(arms))) {
      arm <- arms[arm_i, , drop = FALSE]
      for (reservoir_replicate in seq_along(seeds)) {
        counter <- counter + 1L
        alpha <- if (is.finite(arm$alpha[[1L]])) arm$alpha[[1L]] else as.numeric(parent$alpha[[1L]])
        rho <- if (is.finite(arm$rho[[1L]])) arm$rho[[1L]] else as.numeric(parent$rho[[1L]])
        pi_w <- if (arm$topology_mode[[1L]] %in% c("repair_w", "repair_w_win")) {
          repaired_pi_w
        } else {
          as.numeric(parent$pi_w[[1L]])
        }
        pi_in <- if (arm$topology_mode[[1L]] %in% c("repair_win", "repair_w_win")) {
          repaired_pi_in
        } else {
          as.numeric(parent$pi_in[[1L]])
        }
        profile_id <- sprintf(
          "arv1_%s_%s_r%02d",
          qdesn_arv1_safe_token(parent$target_cell_id[[1L]]),
          qdesn_arv1_safe_token(arm$arm_code[[1L]]),
          reservoir_replicate
        )
        profile <- data.frame(
          screening_profile_id = profile_id,
          screening_stage = "mcmc_alpha_rho_topology_v1",
          screening_wave = "alpha_rho_topology_v1_2026_07_31",
          profile_role = arm$arm_code[[1L]],
          enabled = TRUE,
          D = as.integer(parent$D[[1L]]),
          n_each = n_each,
          n_tilde_each = as.integer(parent$n_tilde_each[[1L]]),
          m = m,
          alpha = alpha,
          rho = rho,
          pi_w = pi_w,
          pi_in = pi_in,
          washout = as.integer(parent$washout[[1L]]),
          add_bias = as.logical(parent$add_bias[[1L]]),
          seed = seeds[[reservoir_replicate]],
          readout_y_lags = as.integer(parent$readout_y_lags[[1L]]),
          reservoir_lags = as.integer(parent$reservoir_lags[[1L]]),
          rhs_tau0 = as.numeric(parent$rhs_tau0[[1L]]),
          dimension_p_estimate = as.integer(parent$dimension_p_estimate[[1L]]),
          p_over_n_tt500 = as.numeric(parent$p_over_n_tt500[[1L]]),
          x_feature_count = 5L,
          target_cells = paste(parent$family[[1L]], sprintf("%.2f", parent$tau[[1L]]), parent$likelihood_target[[1L]], sep = ":"),
          target_cell_id = parent$target_cell_id[[1L]],
          target_role = parent$target_role[[1L]],
          likelihood_target = parent$likelihood_target[[1L]],
          target_family = parent$family[[1L]],
          target_tau = as.numeric(parent$tau[[1L]]),
          parent_profile_id = parent$parent_profile_id[[1L]],
          arm_index = as.integer(arm$arm_index[[1L]]),
          arm_code = arm$arm_code[[1L]],
          arm_class = arm$arm_class[[1L]],
          topology_mode = arm$topology_mode[[1L]],
          reservoir_replicate = as.integer(reservoir_replicate),
          parent_pi_w = as.numeric(parent$pi_w[[1L]]),
          parent_pi_in = as.numeric(parent$pi_in[[1L]]),
          repaired_pi_w = repaired_pi_w,
          repaired_pi_in = repaired_pi_in,
          expected_recurrent_edges = n_each * n_each * pi_w,
          expected_recurrent_indegree = n_each * pi_w,
          expected_input_edges = n_each * (m + 1L) * pi_in,
          expected_input_indegree = (m + 1L) * pi_in,
          source_screening_profile_id = parent$parent_profile_id[[1L]],
          candidate_source = "broad_alpha_rho_with_factorial_topology_controls",
          selection_reason = "Hold the coherent parent design and RHS scale fixed while diagnosing recurrent/input connectivity before broad alpha/rho search.",
          stringsAsFactors = FALSE
        )
        profiles[[counter]] <- profile
        assignments[[counter]] <- data.frame(
          assignment_id = sprintf("arv1_%04d", counter),
          family = parent$family[[1L]],
          tau = as.numeric(parent$tau[[1L]]),
          likelihood_target = parent$likelihood_target[[1L]],
          target_cell_id = parent$target_cell_id[[1L]],
          target_role = parent$target_role[[1L]],
          screening_profile_id = profile_id,
          parent_profile_id = parent$parent_profile_id[[1L]],
          arm_index = as.integer(arm$arm_index[[1L]]),
          arm_code = arm$arm_code[[1L]],
          arm_class = arm$arm_class[[1L]],
          topology_mode = arm$topology_mode[[1L]],
          reservoir_replicate = as.integer(reservoir_replicate),
          launch_phase = if (arm$arm_class[[1L]] == "mechanism_control") "mechanism" else "broad",
          stringsAsFactors = FALSE
        )
      }
    }
  }
  profiles <- do.call(rbind, profiles)
  assignments <- do.call(rbind, assignments)
  rownames(profiles) <- rownames(assignments) <- NULL
  if (nrow(profiles) != 360L || nrow(assignments) != 360L) {
    stop("Alpha/rho topology v1 must produce 360 cell-arm-reservoir profiles.", call. = FALSE)
  }
  list(parents = parents, arms = arms, profiles = profiles, assignments = assignments)
}

.qdesn_arv1_build_d1_reservoir <- function(n, m, alpha, rho, pi_w, pi_in, seed) {
  n <- as.integer(n)
  m <- as.integer(m)
  set.seed(as.integer(seed))
  make_sparse_weights <- function(nr, nc, pi) {
    mask <- matrix(stats::runif(nr * nc) < pi, nrow = nr, ncol = nc)
    mask * matrix(stats::rnorm(nr * nc), nrow = nr, ncol = nc)
  }
  spectral_radius <- function(x) max(Mod(eigen(x, only.values = TRUE)$values))
  Win <- make_sparse_weights(n, m + 1L, pi_in)
  W <- make_sparse_weights(n, n, pi_w)
  sr <- suppressWarnings(try(spectral_radius(W), silent = TRUE))
  if (inherits(sr, "try-error") || !is.finite(sr) || sr <= 0) sr <- 1
  W <- (rho / sr) * W
  J <- (1 - alpha) * diag(n) + alpha * W
  rJ <- spectral_radius(J)
  if (rJ >= 1 - 1e-6) {
    scale <- 0.99 / rJ
    W <- (scale * J - (1 - alpha) * diag(n)) / alpha
  }
  list(W = W, Win = Win)
}

qdesn_arv1_topology_audit <- function(profiles) {
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package 'digest' is required.", call. = FALSE)
  rows <- lapply(seq_len(nrow(profiles)), function(i) {
    p <- profiles[i, , drop = FALSE]
    if (as.integer(p$D[[1L]]) != 1L) stop("Fast topology audit only supports the frozen D=1 design.", call. = FALSE)
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
    J <- (1 - as.numeric(p$alpha[[1L]])) * diag(nrow(W)) + as.numeric(p$alpha[[1L]]) * W
    spectral_radius <- function(x) max(Mod(eigen(x, only.values = TRUE)$values))
    data.frame(
      screening_profile_id = p$screening_profile_id[[1L]],
      target_cell_id = p$target_cell_id[[1L]],
      arm_code = p$arm_code[[1L]],
      arm_class = p$arm_class[[1L]],
      topology_mode = p$topology_mode[[1L]],
      reservoir_replicate = as.integer(p$reservoir_replicate[[1L]]),
      seed = as.integer(p$seed[[1L]]),
      alpha = as.numeric(p$alpha[[1L]]),
      rho = as.numeric(p$rho[[1L]]),
      pi_w = as.numeric(p$pi_w[[1L]]),
      pi_in = as.numeric(p$pi_in[[1L]]),
      recurrent_nnz = sum(W != 0),
      recurrent_zero_rows = sum(rowSums(W != 0) == 0),
      input_nnz = sum(Win != 0),
      input_zero_rows = sum(rowSums(Win != 0) == 0),
      recurrent_mask_sha256 = digest::digest(W != 0, algo = "sha256"),
      input_mask_sha256 = digest::digest(Win != 0, algo = "sha256"),
      realized_w_spectral_radius = spectral_radius(W),
      realized_leaky_radius = spectral_radius(J),
      total_topology_valid = sum(W != 0) > 0 && sum(Win != 0) > 0,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  full <- out[out$topology_mode == "repair_w_win", , drop = FALSE]
  key <- paste(full$target_cell_id, full$reservoir_replicate, sep = "\r")
  invariant <- vapply(split(seq_len(nrow(full)), key), function(idx) {
    length(unique(full$recurrent_mask_sha256[idx])) == 1L &&
      length(unique(full$input_mask_sha256[idx])) == 1L
  }, logical(1L))
  if (!all(invariant)) stop("Broad alpha/rho arms do not share a common topology within cell and reservoir replicate.", call. = FALSE)
  if (any(!full$total_topology_valid)) stop("A topology-repaired broad arm has zero recurrent or input connectivity.", call. = FALSE)
  out
}
