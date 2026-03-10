safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_chr <- function(x, default) {
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

safe_bool <- function(x, default = FALSE) {
  z <- tolower(trimws(as.character(x)[1]))
  if (z %in% c("1", "true", "t", "yes", "y")) return(TRUE)
  if (z %in% c("0", "false", "f", "no", "n")) return(FALSE)
  default
}

safe_num_vec <- function(x, default = NULL, length_out = NULL) {
  if (!nzchar(x)) return(default)
  vals <- suppressWarnings(as.numeric(strsplit(x, ",", fixed = TRUE)[[1]]))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(default)
  if (!is.null(length_out) && length(vals) != length_out) return(default)
  vals
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

resolve_target_tau <- function(default = 0.50, env_names = c("EXDQLM_TARGET_TAU", "EXDQLM_SIM_TAU")) {
  for (nm in env_names) {
    val <- Sys.getenv(nm, "")
    if (nzchar(val)) {
      tau <- suppressWarnings(as.numeric(val)[1])
      if (is.finite(tau) && !is.na(tau) && tau > 0 && tau < 1) return(tau)
    }
  }
  as.numeric(default)[1]
}

systematic_rank_subsample <- function(x, target_n) {
  n <- length(x)
  if (target_n >= n) return(seq_len(n))
  pos <- floor(seq(0, n - 1, length.out = target_n)) + 1L
  pos <- unique(pos)
  if (length(pos) < target_n) {
    fill <- setdiff(seq_len(n), pos)
    pos <- c(pos, fill[seq_len(target_n - length(pos))])
    pos <- sort(pos)
  }
  pos[seq_len(target_n)]
}

build_ar1_cov <- function(p, rho) {
  stopifnot(p >= 1L)
  outer(seq_len(p), seq_len(p), function(i, j) rho ^ abs(i - j))
}

rlaplace_loc_scale <- function(n, location = 0, scale = 1) {
  if (!is.finite(scale) || scale <= 0) stop("Laplace scale must be positive")
  u <- stats::runif(n, min = -0.5, max = 0.5)
  location - scale * sign(u) * log1p(-2 * abs(u))
}

qlaplace_loc_scale <- function(p, location = 0, scale = 1) {
  if (!is.finite(scale) || scale <= 0) stop("Laplace scale must be positive")
  p <- as.numeric(p)
  out <- numeric(length(p))
  left <- p < 0.5
  out[left] <- location + scale * log(2 * p[left])
  out[!left] <- location - scale * log(2 * (1 - p[!left]))
  out
}

gausmix_zero_quantile_root <- function(tau, sigma = c(1, sqrt(5)), weights = c(0.1, 0.9), offset = 1) {
  stopifnot(length(sigma) == 2L, length(weights) == 2L)
  root_fun <- function(x0) {
    weights[1] * stats::pnorm(0, mean = x0, sd = sigma[1]) +
      weights[2] * stats::pnorm(0, mean = x0 + offset, sd = sigma[2]) - tau
  }
  stats::uniroot(root_fun, c(-100, 100))$root
}

draw_qspec_error <- function(n, tau, family,
                             normal_sigma = 1,
                             laplace_scale = 3,
                             gausmix_sigma = c(1, sqrt(5)),
                             gausmix_weights = c(0.1, 0.9),
                             gausmix_offset = 1,
                             gpd_xi = 3) {
  family <- tolower(family)

  if (family == "normal") {
    shift <- normal_sigma * stats::qnorm(tau)
    raw <- stats::rnorm(n, mean = 0, sd = normal_sigma)
    return(list(
      eps = raw - shift,
      truth_method = "exact_shifted_normal_closed_form",
      shift = shift,
      family_params = list(sd = normal_sigma)
    ))
  }

  if (family == "laplace") {
    shift <- qlaplace_loc_scale(tau, location = 0, scale = laplace_scale)
    raw <- rlaplace_loc_scale(n, location = 0, scale = laplace_scale)
    return(list(
      eps = raw - shift,
      truth_method = "exact_shifted_laplace_closed_form",
      shift = shift,
      family_params = list(scale = laplace_scale)
    ))
  }

  if (family == "gausmix") {
    root <- gausmix_zero_quantile_root(
      tau = tau,
      sigma = gausmix_sigma,
      weights = gausmix_weights,
      offset = gausmix_offset
    )
    lab <- sample.int(2L, n, replace = TRUE, prob = gausmix_weights)
    loc_vec <- c(root, root + gausmix_offset)[lab]
    scale_vec <- gausmix_sigma[lab]
    return(list(
      eps = stats::rnorm(n, mean = loc_vec, sd = scale_vec),
      truth_method = "paper_gausmix_root_solve",
      shift = root,
      family_params = list(sigma = gausmix_sigma, weights = gausmix_weights, offset = gausmix_offset)
    ))
  }

  if (family == "loggpd") {
    sigma0 <- gpd_xi * (1 - tau)^gpd_xi / (1 - (1 - tau)^gpd_xi)
    u <- stats::runif(n)
    x <- if (abs(gpd_xi) < 1e-12) {
      -sigma0 * log1p(-u)
    } else {
      (sigma0 / gpd_xi) * ((1 - u)^(-gpd_xi) - 1)
    }
    return(list(
      eps = log(x),
      truth_method = "paper_loggpd_scale_construction",
      shift = 0,
      family_params = list(xi = gpd_xi, scale = sigma0)
    ))
  }

  stop("Unsupported qspec error family: ", family)
}

rskewnorm_std <- function(n, shape) {
  delta <- shape / sqrt(1 + shape^2)
  z_raw <- delta * abs(stats::rnorm(n)) + sqrt(1 - delta^2) * stats::rnorm(n)
  mu_z <- delta * sqrt(2 / pi)
  sd_z <- sqrt(1 - 2 * delta^2 / pi)
  (z_raw - mu_z) / sd_z
}

draw_std_noise <- function(n, family, shape = NULL) {
  family <- tolower(family)
  if (family == "normal") {
    stats::rnorm(n)
  } else if (family == "skew_normal") {
    rskewnorm_std(n, shape)
  } else {
    stop("Unsupported noise_family: ", family)
  }
}

compute_noise_quantile <- function(tau, family, shape = NULL, R_mc = 200000L, seed = NULL) {
  family <- tolower(family)
  if (family == "normal") return(stats::qnorm(tau))
  if (!is.null(seed)) set.seed(as.integer(seed)[1])
  stats::quantile(
    draw_std_noise(as.integer(R_mc), family = family, shape = shape),
    probs = tau,
    names = FALSE,
    type = 8
  )[[1]]
}

make_quantile_specific_sim_output <- function(y, tau, q_true, info, extras = list()) {
  q_true <- as.matrix(q_true)
  if (ncol(q_true) != 1L) stop("q_true must have exactly one column")
  list(
    y = as.numeric(y),
    q = q_true,
    p = as.numeric(tau),
    info = info,
    extras = extras
  )
}

write_quantile_specific_subsample <- function(sim_output, out_root, target_n, order_key, sub_label = "xmain_sorted",
                                              series_wide = NULL, series_long = NULL, extra_files = character()) {
  n_total <- length(sim_output$y)
  ord <- order(order_key, seq_len(n_total))
  idx <- ord[systematic_rank_subsample(order_key[ord], target_n)]
  sub_root <- file.path(out_root, sprintf("fit_input_subsample_tt%d_%s", target_n, sub_label))
  dir.create(sub_root, recursive = TRUE, showWarnings = FALSE)

  subset_sim <- sim_output
  subset_sim$y <- as.numeric(sim_output$y[idx])
  subset_sim$q <- as.matrix(sim_output$q[idx, , drop = FALSE])
  if (!is.null(subset_sim$extras$mu)) subset_sim$extras$mu <- as.numeric(subset_sim$extras$mu[idx])
  if (!is.null(subset_sim$extras$sigma)) subset_sim$extras$sigma <- as.numeric(subset_sim$extras$sigma[idx])
  if (!is.null(subset_sim$extras$x_main)) subset_sim$extras$x_main <- as.numeric(subset_sim$extras$x_main[idx])
  if (!is.null(subset_sim$extras$X)) subset_sim$extras$X <- as.matrix(subset_sim$extras$X[idx, , drop = FALSE])
  if (!is.null(subset_sim$extras$z_std)) subset_sim$extras$z_std <- as.numeric(subset_sim$extras$z_std[idx])
  subset_sim$extras$source_index <- as.integer(idx)
  subset_sim$extras$source_n <- as.integer(n_total)
  subset_sim$info$subsample <- list(
    source_root = out_root,
    source_n = as.integer(n_total),
    target_n = as.integer(target_n),
    selection_method = paste0("systematic_rank_", sub_label),
    sorted_by = sub_label
  )
  if (!is.null(subset_sim$info$params$n)) subset_sim$info$params$n <- as.integer(target_n)

  saveRDS(subset_sim, file.path(sub_root, "sim_output.rds"))

  if (!is.null(series_wide)) {
    utils::write.csv(series_wide[idx, , drop = FALSE], file.path(sub_root, "series_wide.csv"), row.names = FALSE)
  }
  if (!is.null(series_long)) {
    sel_rows <- if ("row_id" %in% names(series_long)) series_long$row_id %in% idx else seq_len(nrow(series_long)) %in% idx
    utils::write.csv(series_long[sel_rows, , drop = FALSE], file.path(sub_root, "series_long.csv"), row.names = FALSE)
  }
  utils::write.csv(
    data.frame(row_id = seq_along(idx), source_index = as.integer(idx), order_key = order_key[idx]),
    file.path(sub_root, "selection_indices.csv"), row.names = FALSE
  )
  if (length(extra_files)) {
    for (f in extra_files) {
      if (file.exists(file.path(out_root, f))) file.copy(file.path(out_root, f), file.path(sub_root, basename(f)), overwrite = TRUE)
    }
  }
  sub_root
}

write_dynamic_tail_subsets <- function(sim_output, out_root, target_n_values,
                                       series_wide = NULL, series_long = NULL,
                                       extra_files = character()) {
  n_total <- length(sim_output$y)
  target_n_values <- as.integer(target_n_values)
  target_n_values <- unique(target_n_values[is.finite(target_n_values) & target_n_values > 0L])
  target_n_values <- sort(target_n_values)
  if (!length(target_n_values)) stop("target_n_values must contain at least one positive integer")
  sub_roots <- character(length(target_n_values))
  for (ii in seq_along(target_n_values)) {
    target_n <- target_n_values[ii]
    if (target_n > n_total) stop("target_n cannot exceed available dynamic series length")
    idx <- seq.int(n_total - target_n + 1L, n_total)
    sub_root <- file.path(out_root, sprintf("fit_input_lastTT%d", target_n))
    dir.create(sub_root, recursive = TRUE, showWarnings = FALSE)

    subset_sim <- sim_output
    subset_sim$y <- as.numeric(sim_output$y[idx])
    subset_sim$q <- as.matrix(sim_output$q[idx, , drop = FALSE])
    if (!is.null(subset_sim$extras$mu)) subset_sim$extras$mu <- as.numeric(subset_sim$extras$mu[idx])
    if (!is.null(subset_sim$extras$V_t)) subset_sim$extras$V_t <- as.numeric(subset_sim$extras$V_t[idx])
    if (!is.null(subset_sim$extras$theta) && is.matrix(subset_sim$extras$theta)) {
      subset_sim$extras$theta <- subset_sim$extras$theta[, idx, drop = FALSE]
    }
    if (!is.null(subset_sim$extras$eps_shifted)) subset_sim$extras$eps_shifted <- as.numeric(subset_sim$extras$eps_shifted[idx])
    if (!is.null(subset_sim$extras$eps_raw)) subset_sim$extras$eps_raw <- as.numeric(subset_sim$extras$eps_raw[idx])
    subset_sim$extras$source_index <- as.integer(idx)
    subset_sim$extras$source_n <- as.integer(n_total)
    subset_sim$info$subsample <- list(
      source_root = out_root,
      source_n = as.integer(n_total),
      target_n = as.integer(target_n),
      selection_method = "last_T",
      sorted_by = "time"
    )
    if (!is.null(subset_sim$info$params$TT)) subset_sim$info$params$TT <- as.integer(target_n)

    saveRDS(subset_sim, file.path(sub_root, "sim_output.rds"))

    if (!is.null(series_wide)) {
      utils::write.csv(series_wide[idx, , drop = FALSE], file.path(sub_root, "series_wide.csv"), row.names = FALSE)
    }
    if (!is.null(series_long)) {
      time_col <- if ("t" %in% names(series_long)) "t" else names(series_long)[1]
      utils::write.csv(series_long[series_long[[time_col]] %in% idx, , drop = FALSE], file.path(sub_root, "series_long.csv"), row.names = FALSE)
    }
    utils::write.csv(
      data.frame(t = seq_along(idx), source_index = as.integer(idx)),
      file.path(sub_root, "selection_indices.csv"), row.names = FALSE
    )
    if (length(extra_files)) {
      for (f in extra_files) {
        if (file.exists(file.path(out_root, f))) file.copy(file.path(out_root, f), file.path(sub_root, basename(f)), overwrite = TRUE)
      }
    }
    sub_roots[ii] <- sub_root
  }
  names(sub_roots) <- paste0("TT", target_n_values)
  sub_roots
}
