#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
bind_rows <- function(xs) {
  xs <- Filter(function(x) is.data.frame(x) && nrow(x), xs)
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}
slug <- function(x) {
  x <- tolower(trimws(as.character(x)[1L]))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "x" else x
}
slug_num <- function(x, digits = 5L) {
  x <- suppressWarnings(as.numeric(x)[1L])
  if (!is.finite(x)) return("na")
  out <- formatC(x, digits = digits, format = "fg", flag = "#")
  out <- sub("0+$", "", out)
  out <- sub("\\.$", "", out)
  gsub("-", "m", gsub("\\.", "p", out))
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_token <- function(x) paste0("tau", gsub("\\.", "p", sprintf("%.2f", as.numeric(x))))
finite_num <- function(x, default = NA_real_) {
  val <- suppressWarnings(as.numeric(x)[1L])
  if (is.finite(val)) val else default
}
finite_int <- function(x, default = NA_integer_) {
  val <- suppressWarnings(as.integer(x)[1L])
  if (is.finite(val)) val else default
}
nearest <- function(x, grid, k = 3L) {
  grid <- sort(unique(as.numeric(grid)))
  x <- finite_num(x, NA_real_)
  if (!is.finite(x)) return(utils::head(grid, k))
  grid[order(abs(grid - x), grid)][seq_len(min(length(grid), k))]
}
metric_ratio_cols <- c("r_fit_rmse", "r_fit_check", "r_forecast_mae", "r_forecast_check")

read_screen_tables <- function(baseline_path) {
  baseline <- utils::read.csv(resolve_path(baseline_path), check.names = FALSE, stringsAsFactors = FALSE)
  baseline$tau <- suppressWarnings(as.numeric(baseline$tau))
  baseline_best <- bind_rows(lapply(split(baseline, paste(baseline$family, baseline$tau)), function(z) {
    data.frame(
      family = as.character(z$family[[1L]]),
      tau = as.numeric(z$tau[[1L]]),
      b_fit_rmse = min(as.numeric(z$fit_qtrue_rmse), na.rm = TRUE),
      b_fit_check = min(as.numeric(z$fit_check_loss), na.rm = TRUE),
      b_forecast_mae = min(as.numeric(z$forecast_qtrue_mae_lead_weighted), na.rm = TRUE),
      b_forecast_check = min(as.numeric(z$forecast_check_loss_lead_weighted), na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))

  files <- list.files(
    file.path("reports", "qdesn_mcmc_validation"),
    pattern = "qdesn_tt500_vb_screen_fit_forecast_summary[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  files <- files[!grepl("smoke|pilot", files, ignore.case = TRUE)]
  read_one <- function(path) {
    x <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE), error = function(e) NULL)
    required <- c(
      "family", "tau", "likelihood_family", "status", "train_qtrue_rmse",
      "train_pinball_tau", "forecast_all_qtrue_mae", "forecast_all_pinball_mean"
    )
    if (is.null(x) || !all(required %in% names(x))) return(NULL)
    parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
    x$file <- path
    x$stage <- parts[[length(parts) - 4L]]
    x$run_tag <- parts[[length(parts) - 3L]]
    x$stamp <- parts[[length(parts) - 2L]]
    x
  }
  screens <- Filter(Negate(is.null), lapply(files, read_one))
  if (!length(screens)) stop("No compatible Q-DESN VB screen summaries found.", call. = FALSE)
  screen <- bind_rows(screens)
  screen <- screen[toupper(as.character(screen$status)) == "SUCCESS", , drop = FALSE]
  screen$tau <- suppressWarnings(as.numeric(screen$tau))
  screen <- merge(screen, baseline_best, by = c("family", "tau"), all.x = TRUE)
  screen$r_fit_rmse <- suppressWarnings(as.numeric(screen$train_qtrue_rmse) / screen$b_fit_rmse)
  screen$r_fit_check <- suppressWarnings(as.numeric(screen$train_pinball_tau) / screen$b_fit_check)
  screen$r_forecast_mae <- suppressWarnings(as.numeric(screen$forecast_all_qtrue_mae) / screen$b_forecast_mae)
  screen$r_forecast_check <- suppressWarnings(as.numeric(screen$forecast_all_pinball_mean) / screen$b_forecast_check)
  screen$joint_worst_ratio <- do.call(pmax, c(screen[metric_ratio_cols], list(na.rm = TRUE)))
  screen$cell_like <- paste(screen$family, tau_key(screen$tau), screen$likelihood_family, sep = "\r")
  screen
}

best_row <- function(screen, family, tau, likelihood, metric = "joint_worst_ratio") {
  z <- screen[
    as.character(screen$family) == family &
      abs(as.numeric(screen$tau) - as.numeric(tau)) < 1e-8 &
      as.character(screen$likelihood_family) == likelihood,
    ,
    drop = FALSE
  ]
  if (!nrow(z)) return(NULL)
  vals <- suppressWarnings(as.numeric(z[[metric]]))
  z[order(vals, z$joint_worst_ratio, z$screening_profile_id), , drop = FALSE][1L, , drop = FALSE]
}

row_to_profile <- function(row,
                           role,
                           stage,
                           lane,
                           design_axis,
                           family,
                           tau,
                           likelihood,
                           blocker,
                           seed,
                           mutate = list(),
                           requires_runner_feature_support = FALSE) {
  get <- function(name, default = NA) {
    if (!is.null(mutate[[name]])) return(mutate[[name]])
    if (!is.null(row) && name %in% names(row)) return(row[[name]][[1L]])
    default
  }
  D <- finite_int(get("D", 1L), 1L)
  n_each <- finite_int(get("n_each", 8L), 8L)
  n_tilde_each <- finite_int(get("n_tilde_each", 0L), 0L)
  m <- finite_int(get("m", get("readout_y_lags", 1L)), 1L)
  alpha <- finite_num(get("alpha", 0.0025), 0.0025)
  rho <- finite_num(get("rho", 0.45), 0.45)
  pi_w <- finite_num(get("pi_w", 0.0025), 0.0025)
  pi_in <- finite_num(get("pi_in", 0.05), 0.05)
  rhs_tau0 <- finite_num(get("rhs_tau0", 3e-4), 3e-4)
  seasonal_mode <- as.character(mutate$seasonal_feature_mode %||% "none")
  seasonal_period <- finite_int(mutate$seasonal_period %||% 90L, 90L)
  seasonal_lag_block <- as.character(mutate$seasonal_lag_block %||% "")
  raw_lag_block <- as.character(mutate$raw_lag_block %||% paste(seq_len(max(1L, min(m, 6L))), collapse = "|"))
  seasonal_feature_count <- if (identical(seasonal_mode, "none")) 0L else length(strsplit(seasonal_lag_block, "\\|")[[1L]]) + 2L
  dim_p <- finite_int(
    get("dimension_p_estimate", NA_integer_),
    as.integer(D * n_each + max(1L, m) + seasonal_feature_count + if (isTRUE(get("add_bias", TRUE))) 1L else 0L + 5L)
  )
  p_over_n <- finite_num(get("p_over_n_tt500", dim_p / 500), dim_p / 500)
  profile_id <- sprintf(
    "tt500vb_break_%s_%s_%s_%s_%s_d%d_n%d_a%s_r%s_m%d_tau0%s_s%d",
    lane, family, tau_token(tau), likelihood, slug(role), D, n_each,
    slug_num(alpha), slug_num(rho), m, slug_num(rhs_tau0), as.integer(seed)
  )
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = stage,
    screening_wave = paste0(stage, "_2026_07_13"),
    profile_role = role,
    enabled = TRUE,
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    m = m,
    alpha = alpha,
    rho = rho,
    pi_w = pi_w,
    pi_in = pi_in,
    washout = finite_int(get("washout", 300L), 300L),
    add_bias = as.logical(get("add_bias", TRUE)),
    seed = as.integer(seed),
    readout_y_lags = finite_int(get("readout_y_lags", m), m),
    reservoir_lags = finite_int(get("reservoir_lags", 0L), 0L),
    rhs_tau0 = rhs_tau0,
    dimension_p_estimate = dim_p,
    p_over_n_tt500 = p_over_n,
    x_feature_count = finite_int(get("x_feature_count", max(1L, D * n_each)), max(1L, D * n_each)),
    target_family = family,
    target_tau = as.numeric(tau),
    likelihood_target = likelihood,
    design_lane = lane,
    design_axis = design_axis,
    seasonal_feature_mode = seasonal_mode,
    seasonal_period = seasonal_period,
    seasonal_lag_block = seasonal_lag_block,
    raw_lag_block = raw_lag_block,
    reservoir_width_mode = as.character(mutate$reservoir_width_mode %||% ifelse(n_each <= 8L, "micro", ifelse(n_each <= 20L, "compact", "moderate"))),
    blocker_target = blocker,
    source_frontier_row = as.character(mutate$source_frontier_row %||% NA_character_),
    target_source_profile = as.character((row$screening_profile_id %||% row$screening_profile_base %||% NA_character_)[[1L]]),
    target_source_stage = as.character((row$stage %||% NA_character_)[[1L]]),
    target_source_run_tag = as.character((row$run_tag %||% NA_character_)[[1L]]),
    target_source_likelihood_family = likelihood,
    target_source_worst_ratio = finite_num(row$joint_worst_ratio %||% NA_real_),
    target_source_fit_rmse_ratio = finite_num(row$r_fit_rmse %||% NA_real_),
    target_source_fit_check_ratio = finite_num(row$r_fit_check %||% NA_real_),
    target_source_forecast_mae_ratio = finite_num(row$r_forecast_mae %||% NA_real_),
    target_source_forecast_check_ratio = finite_num(row$r_forecast_check %||% NA_real_),
    requires_runner_feature_support = isTRUE(requires_runner_feature_support),
    launch_gate = if (isTRUE(requires_runner_feature_support)) "blocked_until_runner_feature_support_verified" else "requires_explicit_human_launch_approval",
    stringsAsFactors = FALSE
  )
}

bridge_profiles_for_cell <- function(screen, frow, seed_base) {
  family <- as.character(frow$family)
  tau <- as.numeric(frow$tau)
  likelihood <- as.character(frow$likelihood_family)
  blocker <- as.character(frow$metricwise_blockers)
  anchors <- list(
    joint = best_row(screen, family, tau, likelihood, "joint_worst_ratio"),
    fit_rmse = best_row(screen, family, tau, likelihood, "r_fit_rmse"),
    fit_check = best_row(screen, family, tau, likelihood, "r_fit_check"),
    forecast_mae = best_row(screen, family, tau, likelihood, "r_forecast_mae"),
    forecast_check = best_row(screen, family, tau, likelihood, "r_forecast_check")
  )
  roles <- c("bridge_joint_anchor", "bridge_fit_guard", "bridge_check_guard", "bridge_forecast_mae_guard", "bridge_forecast_check_guard")
  out <- list()
  for (i in seq_along(anchors)) {
    if (!is.null(anchors[[i]])) {
      out[[length(out) + 1L]] <- row_to_profile(
        anchors[[i]], roles[[i]], "vb_break_surface_bridge", "bridge",
        "local_metric_bridge", family, tau, likelihood, blocker, seed_base + i,
        mutate = list(
          source_frontier_row = paste(family, tau_key(tau), likelihood, sep = ":"),
          raw_lag_block = "1|2|3",
          seasonal_feature_mode = "none",
          reservoir_width_mode = "source_anchor"
        )
      )
    }
  }
  joint <- anchors$joint
  fit <- anchors$fit_rmse %||% joint
  check <- anchors$fit_check %||% joint
  if (!is.null(joint) && !is.null(fit) && !is.null(check)) {
    alpha_grid <- sort(unique(c(nearest(joint$alpha, c(5e-4, 7.5e-4, 1e-3, 2.5e-3, 5e-3, 1e-2, 2e-2, 5e-2), 2L), nearest(check$alpha, c(1e-3, 2.5e-3, 5e-3, 1e-2, 2e-2, 5e-2, 1e-1), 2L))))
    rho_grid <- sort(unique(c(nearest(joint$rho, c(0.25, 0.35, 0.45, 0.6, 0.7), 2L), nearest(check$rho, c(0.35, 0.45, 0.6, 0.7, 0.8), 2L))))
    m_grid <- sort(unique(c(nearest(joint$m, c(1, 2, 3, 5, 8, 15, 30, 45, 60, 90), 2L), nearest(check$m, c(3, 5, 8, 15, 30, 45, 60, 90), 2L))))
    seed <- seed_base + 20L
    for (j in seq_len(min(4L, length(alpha_grid) * length(rho_grid) * length(m_grid)))) {
      alpha <- alpha_grid[((j - 1L) %% length(alpha_grid)) + 1L]
      rho <- rho_grid[((j - 1L) %% length(rho_grid)) + 1L]
      m <- m_grid[((j - 1L) %% length(m_grid)) + 1L]
      out[[length(out) + 1L]] <- row_to_profile(
        fit, paste0("bridge_blend_", j), "vb_break_surface_bridge", "bridge",
        "local_metric_bridge", family, tau, likelihood, blocker, seed + j,
        mutate = list(
          alpha = alpha,
          rho = rho,
          m = as.integer(m),
          readout_y_lags = as.integer(m),
          pi_w = min(max(finite_num(fit$pi_w, 0.0025), 5e-4), 0.05),
          pi_in = min(max(finite_num(check$pi_in, 0.05), 0.02), 0.3),
          rhs_tau0 = finite_num(fit$rhs_tau0, 3e-4),
          dimension_p_estimate = NA_integer_,
          p_over_n_tt500 = NA_real_,
          source_frontier_row = paste(family, tau_key(tau), likelihood, sep = ":"),
          raw_lag_block = paste(seq_len(max(1L, min(as.integer(m), 6L))), collapse = "|"),
          seasonal_feature_mode = "none",
          reservoir_width_mode = "bridge_blend"
        )
      )
    }
  }
  bind_rows(out)
}

newaxis_profiles_for_cell <- function(screen, frow, seed_base) {
  family <- as.character(frow$family)
  tau <- as.numeric(frow$tau)
  likelihood <- as.character(frow$likelihood_family)
  blocker <- as.character(frow$metricwise_blockers)
  fit <- best_row(screen, family, tau, likelihood, "r_fit_rmse")
  joint <- best_row(screen, family, tau, likelihood, "joint_worst_ratio") %||% fit
  if (is.null(fit)) fit <- joint
  axes <- data.frame(
    role = c("seasonal_harmonic_core", "sparse_lag90_core", "hybrid_short_seasonal", "forecast_seasonal_guard", "tail_fit_sparse_guard", "solver_confirmation_anchor"),
    design_axis = c("seasonal_harmonic_readout", "sparse_seasonal_lag90", "hybrid_short_plus_seasonal", "forecast_seasonal_guard", "tail_sparse_fit_guard", "solver_confirmation_only"),
    D = c(1L, 1L, 1L, 2L, 1L, finite_int(joint$D %||% 1L, 1L)),
    n_each = c(6L, 8L, 12L, 12L, 4L, finite_int(joint$n_each %||% 8L, 8L)),
    m = c(3L, 1L, 6L, 30L, 1L, finite_int(joint$m %||% 1L, 1L)),
    alpha = c(0.001, 0.00075, 0.0025, 0.02, 0.0005, finite_num(joint$alpha %||% 0.001, 0.001)),
    rho = c(0.35, 0.45, 0.45, 0.60, 0.35, finite_num(joint$rho %||% 0.45, 0.45)),
    pi_w = c(0.001, 0.001, 0.0025, 0.01, 0.00075, finite_num(joint$pi_w %||% 0.0025, 0.0025)),
    pi_in = c(0.03, 0.05, 0.10, 0.20, 0.03, finite_num(joint$pi_in %||% 0.05, 0.05)),
    rhs_tau0 = c(3e-4, 3e-4, 1e-4, 1e-4, 3e-4, finite_num(joint$rhs_tau0 %||% 3e-4, 3e-4)),
    seasonal_feature_mode = c("sin_cos_period90", "lag90_summary", "short_plus_period90", "sin_cos_plus_lag90", "none", "none"),
    seasonal_lag_block = c("90", "90", "45|90", "30|60|90", "", ""),
    raw_lag_block = c("1|2|3", "1", "1|2|3|6", "1|2|3|6|12", "1", paste(seq_len(max(1L, min(finite_int(joint$m %||% 1L, 1L), 6L))), collapse = "|")),
    reservoir_width_mode = c("harmonic_lowdim", "sparse_lag90", "hybrid_compact", "forecast_guard", "tail_micro", "source_anchor"),
    requires_runner_feature_support = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  out <- list()
  for (i in seq_len(nrow(axes))) {
    src <- if (grepl("forecast", axes$role[[i]])) joint else fit
    out[[length(out) + 1L]] <- row_to_profile(
      src, axes$role[[i]], "vb_break_surface_newaxis", "newaxis",
      axes$design_axis[[i]], family, tau, likelihood, blocker, seed_base + i,
      mutate = as.list(axes[i, setdiff(names(axes), c("role", "design_axis", "requires_runner_feature_support")), drop = FALSE]),
      requires_runner_feature_support = axes$requires_runner_feature_support[[i]]
    )
  }
  bind_rows(out)
}

make_plan <- function(lane, frontier, screen) {
  if (identical(lane, "bridge")) {
    frontier <- frontier[frontier$recommended_lane %in% c("small_metric_bridge_screen", "narrow_check_loss_bridge"), , drop = FALSE]
    stage <- "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge"
    desc <- "Q-DESN 500-observation VB break-surface Lane A bridge grid for near-pass family/tau/likelihood cells."
  } else if (identical(lane, "newaxis")) {
    frontier <- frontier[frontier$recommended_lane == "new_design_axis_required", , drop = FALSE]
    stage <- "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis"
    desc <- "Q-DESN 500-observation VB break-surface Lane B new-design-axis grid for hard family/tau/likelihood cells."
  } else {
    stop("lane must be bridge or newaxis", call. = FALSE)
  }
  if (!nrow(frontier)) stop(sprintf("No frontier rows selected for lane `%s`.", lane), call. = FALSE)
  profiles <- list()
  for (i in seq_len(nrow(frontier))) {
    seed_base <- if (identical(lane, "bridge")) 71000L + 100L * i else 81000L + 100L * i
    profiles[[i]] <- if (identical(lane, "bridge")) {
      bridge_profiles_for_cell(screen, frontier[i, , drop = FALSE], seed_base)
    } else {
      newaxis_profiles_for_cell(screen, frontier[i, , drop = FALSE], seed_base)
    }
  }
  profiles <- bind_rows(profiles)
  profiles <- profiles[!duplicated(as.character(profiles$screening_profile_id)), , drop = FALSE]
  profiles$dimension_p_estimate[!is.finite(suppressWarnings(as.numeric(profiles$dimension_p_estimate)))] <-
    as.integer(profiles$D[!is.finite(suppressWarnings(as.numeric(profiles$dimension_p_estimate)))] *
      profiles$n_each[!is.finite(suppressWarnings(as.numeric(profiles$dimension_p_estimate)))] +
      profiles$m[!is.finite(suppressWarnings(as.numeric(profiles$dimension_p_estimate)))] + 6L)
  profiles$p_over_n_tt500[!is.finite(suppressWarnings(as.numeric(profiles$p_over_n_tt500)))] <-
    as.numeric(profiles$dimension_p_estimate[!is.finite(suppressWarnings(as.numeric(profiles$p_over_n_tt500)))]) / 500
  profiles$case_specific_profile_rank <- ave(seq_len(nrow(profiles)), paste(profiles$target_family, profiles$target_tau, profiles$likelihood_target), FUN = seq_along)
  profiles$target_cells <- paste(profiles$target_family, sprintf("%.2f", profiles$target_tau), profiles$likelihood_target, sep = ":")
  profiles$target_cell_statuses <- ifelse(identical(lane, "bridge"), "near_bridge", "new_axis_required")
  profiles$target_bottleneck_metrics <- profiles$blocker_target

  assignments <- data.frame(
    assignment_key = paste(profiles$screening_profile_id, profiles$target_family, tau_key(profiles$target_tau), sep = "\r"),
    family = profiles$target_family,
    tau = profiles$target_tau,
    likelihood_target = profiles$likelihood_target,
    cell_status = profiles$target_cell_statuses,
    priority_rank = match(paste(profiles$target_family, profiles$target_tau, profiles$likelihood_target), unique(paste(profiles$target_family, profiles$target_tau, profiles$likelihood_target))),
    target_profile_rank = profiles$case_specific_profile_rank,
    screening_profile_id = profiles$screening_profile_id,
    source_profile = profiles$target_source_profile,
    source_worst_ratio = profiles$target_source_worst_ratio,
    bottleneck_metric = profiles$blocker_target,
    design_lane = profiles$design_lane,
    design_axis = profiles$design_axis,
    blocker_target = profiles$blocker_target,
    requires_runner_feature_support = profiles$requires_runner_feature_support,
    assignment_id = sprintf("%s_cell_%04d", lane, seq_len(nrow(profiles))),
    stringsAsFactors = FALSE
  )
  cell_plan <- unique(assignments[, c("family", "tau", "likelihood_target", "cell_status", "priority_rank", "bottleneck_metric", "design_lane"), drop = FALSE])
  list(
    profiles = profiles,
    assignments = assignments,
    cell_plan = cell_plan,
    stage_stub = stage,
    stage_desc = desc,
    manifest = list(
      lane = lane,
      selected_frontier_rows = nrow(frontier),
      n_profiles = nrow(profiles),
      n_assignments = nrow(assignments),
      stage_stub = stage,
      launch_policy = "no launch from this script; explicit approval and dry-audit pass required",
      newaxis_runner_feature_support_required = any(as.logical(profiles$requires_runner_feature_support))
    )
  )
}

materialize_lane <- function(plan, lane, base_defaults_path, workers, refresh_grid, refresh_materialized) {
  stage <- plan$stage_stub
  profiles_out <- file.path("config", "validation", paste0(stage, "_profiles.csv"))
  assignments_out <- file.path("config", "validation", paste0(stage, "_cell_assignments.csv"))
  defaults_out <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
  grid_out <- file.path("config", "validation", paste0(stage, "_grid.csv"))
  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    base_defaults_path = base_defaults_path,
    profiles_out = profiles_out,
    assignments_out = assignments_out,
    defaults_out = defaults_out,
    grid_out = grid_out,
    workers = workers,
    refresh_grid = refresh_grid,
    refresh_materialized = refresh_materialized,
    stage_stub = stage,
    stage_desc = plan$stage_desc,
    stage = paste0("break_surface_", lane),
    priors = "rhs_ns"
  )

  defaults <- yaml::read_yaml(defaults_out)
  defaults$execution <- defaults$execution %||% list()
  defaults$execution$methods <- "vb"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$study_contract <- defaults$study_contract %||% list()
  defaults$study_contract$break_surface_redesign <- list(
    lane = lane,
    no_launch_from_materializer = TRUE,
    explicit_human_approval_required = TRUE,
    current_baseline_all_primary_dominance_required_before_mcmc = TRUE,
    runner_feature_support_required = any(as.logical(plan$profiles$requires_runner_feature_support))
  )
  defaults$screening_profiles <- defaults$screening_profiles %||% list()
  defaults$screening_profiles$break_surface_redesign <- list(
    lane = lane,
    likelihood_target_policy = "profiles and assignments are likelihood-target-labeled; execution still uses the stage likelihood_families until a launcher filter is approved",
    required_metadata = as.list(c(
      "design_axis", "seasonal_feature_mode", "seasonal_period", "seasonal_lag_block",
      "raw_lag_block", "reservoir_width_mode", "likelihood_target", "blocker_target",
      "source_frontier_row"
    ))
  )
  defaults$pipeline <- defaults$pipeline %||% list()
  defaults$pipeline$outputs <- defaults$pipeline$outputs %||% list()
  defaults$pipeline$outputs$save_forecast_objects <- FALSE
  defaults$pipeline$outputs$keep_draws <- FALSE
  defaults$pipeline$outputs$retain_success_payload_objects <- FALSE
  yaml::write_yaml(defaults, defaults_out)

  diag_root <- file.path(
    "reports", "qdesn_mcmc_validation", "posthoc",
    "qdesn_tt500_vb_break_surface_redesign_20260713",
    "materialization", lane
  )
  profiles_diag <- write_csv(plan$profiles, file.path(diag_root, "tables", paste0(stage, "_profiles.csv")))
  assignments_diag <- write_csv(plan$assignments, file.path(diag_root, "tables", paste0(stage, "_cell_assignments.csv")))
  cell_plan_diag <- write_csv(plan$cell_plan, file.path(diag_root, "tables", paste0(stage, "_cell_plan.csv")))
  file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
    profiles_out, assignments_out, defaults_out, grid_out,
    profiles_diag, assignments_diag, cell_plan_diag
  ))
  manifest <- c(plan$manifest, list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
    materialized = mat,
    paths = list(
      profiles = resolve_path(profiles_out),
      assignments = resolve_path(assignments_out),
      defaults = resolve_path(defaults_out),
      grid = resolve_path(grid_out),
      diagnostics_root = resolve_path(diag_root, must_work = FALSE)
    ),
    file_manifest = file_manifest
  ))
  manifest_path <- write_json(manifest, file.path("config", "validation", paste0(stage, "_materialization_manifest.json")))
  summary_lines <- c(
    sprintf("# %s", plan$stage_desc),
    "",
    sprintf("- generated_at: `%s`", manifest$generated_at),
    sprintf("- lane: `%s`", lane),
    sprintf("- profiles: `%d`", nrow(plan$profiles)),
    sprintf("- assignments/roots: `%d`", nrow(plan$assignments)),
    sprintf("- grid_rows: `%d`", mat$n_grid_rows),
    sprintf("- runner_feature_support_required: `%s`", any(as.logical(plan$profiles$requires_runner_feature_support))),
    "- launch_state: `not launched; explicit approval required`",
    "",
    "## Files",
    "",
    sprintf("- profiles: `%s`", resolve_path(profiles_out)),
    sprintf("- assignments: `%s`", resolve_path(assignments_out)),
    sprintf("- defaults: `%s`", resolve_path(defaults_out)),
    sprintf("- grid: `%s`", resolve_path(grid_out)),
    sprintf("- manifest: `%s`", manifest_path)
  )
  summary_path <- resolve_path(file.path(diag_root, "summary", paste0(stage, "_materialization.md")), must_work = FALSE)
  dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(summary_lines, summary_path)
  list(lane = lane, stage_stub = stage, materialized = mat, manifest_path = manifest_path, summary_path = summary_path)
}

lane_arg <- tolower(as.character(get_arg("--lane", "both"))[1L])
if (!lane_arg %in% c("both", "bridge", "newaxis")) stop("--lane must be one of: both, bridge, newaxis", call. = FALSE)
lanes <- if (identical(lane_arg, "both")) c("bridge", "newaxis") else lane_arg
baseline_path <- get_arg("--baseline", "validation/fitforecast_v2/docs/validation_local_exdqlm_dqlm_vb_baseline_20260708.csv")
frontier_path <- get_arg(
  "--frontier",
  "reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/tables/qdesn_tt500_vb_current_baseline_frontier.csv"
)
base_defaults_path <- get_arg("--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml")
workers <- finite_int(get_arg("--workers", "20"), 20L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

frontier <- utils::read.csv(resolve_path(frontier_path), check.names = FALSE, stringsAsFactors = FALSE)
frontier$tau <- suppressWarnings(as.numeric(frontier$tau))
screen <- read_screen_tables(baseline_path)
results <- list()
for (lane in lanes) {
  plan <- make_plan(lane, frontier, screen)
  results[[lane]] <- materialize_lane(
    plan = plan,
    lane = lane,
    base_defaults_path = base_defaults_path,
    workers = workers,
    refresh_grid = refresh_grid,
    refresh_materialized = refresh_materialized
  )
}
combined <- data.frame(
  lane = names(results),
  stage_stub = vapply(results, `[[`, character(1), "stage_stub"),
  manifest_path = vapply(results, `[[`, character(1), "manifest_path"),
  summary_path = vapply(results, `[[`, character(1), "summary_path"),
  stringsAsFactors = FALSE
)
combined_path <- write_csv(
  combined,
  "reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization/qdesn_tt500_vb_break_surface_materialization_index.csv"
)
message("Wrote materialization index: ", combined_path)
