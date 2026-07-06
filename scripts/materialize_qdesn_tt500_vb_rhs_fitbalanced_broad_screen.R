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
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}
num_arg <- function(flag, default) {
  val <- suppressWarnings(as.numeric(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.numeric(default)
}
slug_num <- function(x) {
  out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
  out <- sub("0+$", "", out)
  out <- sub("\\.$", "", out)
  gsub("\\.", "p", out)
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
bind_rows <- function(xs) {
  xs <- xs[vapply(xs, is.data.frame, logical(1L)) & vapply(xs, nrow, integer(1L)) > 0L]
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitbalanced_broad"
default_q_report_root <- file.path(
  "reports", "qdesn_mcmc_validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement",
  "qdesn-tt500-vb-rhs-fitaware-refinement-20260706__git-42c2727",
  "20260706-024112__git-0d22ebc"
)
q_report_root <- resolve_path(get_arg("--qdesn-report-root", default_q_report_root), must_work = TRUE)
source_profiles_path <- resolve_path(get_arg(
  "--source-profiles",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_rhs_fitaware_refinement_profiles.csv")
), must_work = TRUE)
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_stage4_remaining_cells_transfer_defaults.yaml")
), must_work = TRUE)
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
manifest_path <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg(
  "--diagnostic-out",
  file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")
), must_work = FALSE)

workers <- int_arg("--workers", 40L)
max_profiles <- int_arg("--max-profiles", 144L)
max_anchor_profiles <- int_arg("--max-anchor-profiles", 36L)
max_p_over_n <- num_arg("--max-p-over-n", 0.45)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
screening_wave <- as.character(get_arg("--screening-wave", paste0("rhs_fitbalanced_broad_", format(Sys.Date(), "%Y_%m_%d"))))[1L]

q_cell_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_cell_summary.csv")
q_profile_ranking_path <- file.path(q_report_root, "tables", "qdesn_tt500_vb_dominance_profile_ranking.csv")
q_audit_path <- file.path(q_report_root, "audit", "tables", "qdesn_tt500_vb_screen_audit_summary.csv")
missing <- c(q_cell_path, q_profile_ranking_path, q_audit_path)[!file.exists(c(q_cell_path, q_profile_ranking_path, q_audit_path))]
if (length(missing)) {
  stop(sprintf("Missing latest Q-DESN fit-aware evidence path(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
}

q_cell <- utils::read.csv(q_cell_path, stringsAsFactors = FALSE, check.names = FALSE)
q_ranking <- utils::read.csv(q_profile_ranking_path, stringsAsFactors = FALSE, check.names = FALSE)
q_audit <- utils::read.csv(q_audit_path, stringsAsFactors = FALSE, check.names = FALSE)
source_profiles <- utils::read.csv(source_profiles_path, stringsAsFactors = FALSE, check.names = FALSE)

required_cell <- c(
  "family", "tau", "screening_profile_base", "screening_profile_id_representative",
  "forecast_mae_ratio_vs_best_vb_baseline", "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline", "fit_pinball_ratio_vs_best_vb_baseline"
)
missing_cell <- setdiff(required_cell, names(q_cell))
if (length(missing_cell)) {
  stop(sprintf("Q-DESN latest cell summary missing column(s): %s", paste(missing_cell, collapse = ", ")), call. = FALSE)
}
if (!"screening_profile_id" %in% names(source_profiles)) {
  stop("Source profile registry is missing `screening_profile_id`.", call. = FALSE)
}

ratio_cols <- c(
  forecast_mae = "forecast_mae_ratio_vs_best_vb_baseline",
  forecast_check = "forecast_pinball_ratio_vs_best_vb_baseline",
  fit_rmse = "fit_rmse_ratio_vs_best_vb_baseline",
  fit_check = "fit_pinball_ratio_vs_best_vb_baseline"
)
for (nm in ratio_cols) q_cell[[nm]] <- as.numeric(q_cell[[nm]])
q_cell$primary_worst_ratio <- do.call(pmax, c(q_cell[ratio_cols], list(na.rm = TRUE)))
cell_keys <- unique(paste(q_cell$family, tau_key(q_cell$tau), sep = "\r"))

pick_one <- function(df, order_cols) {
  ord_args <- lapply(order_cols, function(col) {
    if (col %in% names(df)) {
      if (is.numeric(df[[col]])) df[[col]] else as.character(df[[col]])
    } else {
      rep(NA_real_, nrow(df))
    }
  })
  df[do.call(order, ord_args), , drop = FALSE][1L, , drop = FALSE]
}

cell_plan <- bind_rows(lapply(cell_keys, function(key) {
  sub <- q_cell[paste(q_cell$family, tau_key(q_cell$tau), sep = "\r") == key, , drop = FALSE]
  best_check <- pick_one(sub, c("forecast_pinball_ratio_vs_best_vb_baseline", "primary_worst_ratio", "fit_rmse_ratio_vs_best_vb_baseline", "screening_profile_base"))
  best_mae <- pick_one(sub, c("forecast_mae_ratio_vs_best_vb_baseline", "primary_worst_ratio", "fit_rmse_ratio_vs_best_vb_baseline", "screening_profile_base"))
  best_fit <- pick_one(sub, c("fit_rmse_ratio_vs_best_vb_baseline", "primary_worst_ratio", "forecast_pinball_ratio_vs_best_vb_baseline", "screening_profile_base"))
  best_balanced <- pick_one(sub, c("primary_worst_ratio", "forecast_pinball_ratio_vs_best_vb_baseline", "forecast_mae_ratio_vs_best_vb_baseline", "fit_rmse_ratio_vs_best_vb_baseline", "screening_profile_base"))
  ratios <- c(
    forecast_mae = best_balanced$forecast_mae_ratio_vs_best_vb_baseline[[1L]],
    forecast_check = best_balanced$forecast_pinball_ratio_vs_best_vb_baseline[[1L]],
    fit_rmse = best_balanced$fit_rmse_ratio_vs_best_vb_baseline[[1L]],
    fit_check = best_balanced$fit_pinball_ratio_vs_best_vb_baseline[[1L]]
  )
  worst <- max(ratios, na.rm = TRUE)
  status <- if (!is.finite(worst)) {
    "unknown"
  } else if (worst >= 2) {
    "severe_fit_bottleneck"
  } else if (worst >= 1.25) {
    "hard_fit_bottleneck"
  } else if (worst >= 1) {
    "near_competitive"
  } else {
    "confirmation"
  }
  data.frame(
    family = as.character(best_balanced$family[[1L]]),
    tau = as.numeric(best_balanced$tau[[1L]]),
    fit_size = 500L,
    cell_status = status,
    primary_worst_ratio = worst,
    bottleneck_metric = names(which.max(ratios))[[1L]],
    best_check_profile = as.character(best_check$screening_profile_id_representative[[1L]]),
    best_mae_profile = as.character(best_mae$screening_profile_id_representative[[1L]]),
    best_fit_profile = as.character(best_fit$screening_profile_id_representative[[1L]]),
    best_balanced_profile = as.character(best_balanced$screening_profile_id_representative[[1L]]),
    best_balanced_check_ratio = best_balanced$forecast_pinball_ratio_vs_best_vb_baseline[[1L]],
    best_balanced_mae_ratio = best_balanced$forecast_mae_ratio_vs_best_vb_baseline[[1L]],
    best_balanced_fit_rmse_ratio = best_balanced$fit_rmse_ratio_vs_best_vb_baseline[[1L]],
    best_balanced_fit_check_ratio = best_balanced$fit_pinball_ratio_vs_best_vb_baseline[[1L]],
    stringsAsFactors = FALSE
  )
}))
status_order <- c(severe_fit_bottleneck = 1L, hard_fit_bottleneck = 2L, near_competitive = 3L, confirmation = 4L, unknown = 5L)
cell_plan$priority <- unname(status_order[as.character(cell_plan$cell_status)])
cell_plan$priority[!is.finite(cell_plan$priority)] <- 99L
cell_plan <- cell_plan[order(cell_plan$priority, -cell_plan$primary_worst_ratio, cell_plan$family, cell_plan$tau), , drop = FALSE]
cell_plan$priority_rank <- seq_len(nrow(cell_plan))
if (nrow(cell_plan) != 9L) {
  stop(sprintf("Expected 9 family x tau cells, observed %d.", nrow(cell_plan)), call. = FALSE)
}

anchor_ids <- unique(c(
  cell_plan$best_check_profile,
  cell_plan$best_mae_profile,
  cell_plan$best_fit_profile,
  cell_plan$best_balanced_profile,
  utils::head(q_ranking$screening_profile_base %||% character(0), 30L)
))
anchor_ids <- anchor_ids[nzchar(anchor_ids) & !is.na(anchor_ids)]
anchor_idx <- match(anchor_ids, as.character(source_profiles$screening_profile_id))
anchor_missing <- anchor_ids[is.na(anchor_idx)]
anchor_profiles <- source_profiles[anchor_idx[!is.na(anchor_idx)], , drop = FALSE]
if (nrow(anchor_profiles) > max_anchor_profiles) {
  anchor_profiles <- utils::head(anchor_profiles, max_anchor_profiles)
}
if (nrow(anchor_profiles)) {
  anchor_profiles$screening_stage <- "vb_rhs_fitbalanced_broad"
  anchor_profiles$screening_wave <- screening_wave
  anchor_profiles$profile_role <- paste0("anchor_from_latest_fitaware_", seq_len(nrow(anchor_profiles)))
  anchor_profiles$source_anchor_stage <- "qdesn_rhs_fitaware_refinement_20260706"
  anchor_profiles$source_anchor_profile_id <- anchor_profiles$screening_profile_id
  anchor_profiles$source_anchor_reason <- "best_check_or_best_fit_or_top_dominance"
}

make_profile <- function(D, n_each, alpha, rho, m, readout_y_lags, reservoir_lags, pi_w, pi_in,
                         rhs_tau0, seed = 123L, role = "fitbalanced_grid") {
  D <- as.integer(D)
  n_each <- as.integer(n_each)
  n_tilde_each <- if (D > 1L) n_each else 0L
  p_est <- D * n_each + max(0L, D - 1L) * n_tilde_each + as.integer(readout_y_lags) + 1L + 5L
  data.frame(
    screening_profile_id = sprintf(
      "tt500vb_fitbal_d%d_n%d_a%s_r%s_m%d_lag%d_rl%d_pw%s_pin%s_tau%s_s%d",
      D, n_each, slug_num(alpha), slug_num(rho), as.integer(m), as.integer(readout_y_lags),
      as.integer(reservoir_lags), slug_num(pi_w), slug_num(pi_in), slug_num(rhs_tau0), as.integer(seed)
    ),
    screening_stage = "vb_rhs_fitbalanced_broad",
    screening_wave = screening_wave,
    profile_role = role,
    enabled = TRUE,
    D = D,
    n_each = n_each,
    n_tilde_each = as.integer(n_tilde_each),
    m = as.integer(m),
    alpha = as.numeric(alpha),
    rho = as.numeric(rho),
    pi_w = as.numeric(pi_w),
    pi_in = as.numeric(pi_in),
    washout = 300L,
    add_bias = TRUE,
    seed = as.integer(seed),
    readout_y_lags = as.integer(readout_y_lags),
    reservoir_lags = as.integer(reservoir_lags),
    rhs_tau0 = as.numeric(rhs_tau0),
    dimension_p_estimate = as.integer(p_est),
    p_over_n_tt500 = as.numeric(p_est) / 500,
    x_feature_count = 5L,
    source_anchor_stage = NA_character_,
    source_anchor_profile_id = NA_character_,
    source_anchor_reason = NA_character_,
    stringsAsFactors = FALSE
  )
}

ar_pairs <- data.frame(
  alpha = c(0.0025, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20),
  rho = c(0.20, 0.25, 0.35, 0.45, 0.50, 0.60, 0.70, 0.78, 0.85)
)
sparsity_pairs <- data.frame(
  pi_w = c(0.02, 0.03, 0.05, 0.08, 0.10),
  pi_in = c(0.20, 0.30, 0.30, 0.50, 0.50)
)
make_grid_role <- function(role, D, n_each, ar_id, memories, tau0, sparse_id = 2L, seeds = 123L) {
  grid <- expand.grid(
    D = D,
    n_each = n_each,
    ar_id = ar_id,
    memory = memories,
    rhs_tau0 = tau0,
    sparse_id = sparse_id,
    seed = seeds,
    stringsAsFactors = FALSE
  )
  bind_rows(lapply(seq_len(nrow(grid)), function(i) {
    ar <- ar_pairs[grid$ar_id[[i]], , drop = FALSE]
    sp <- sparsity_pairs[grid$sparse_id[[i]], , drop = FALSE]
    make_profile(
      D = grid$D[[i]],
      n_each = grid$n_each[[i]],
      alpha = ar$alpha[[1L]],
      rho = ar$rho[[1L]],
      m = grid$memory[[i]],
      readout_y_lags = grid$memory[[i]],
      reservoir_lags = 0L,
      pi_w = sp$pi_w[[1L]],
      pi_in = sp$pi_in[[1L]],
      rhs_tau0 = grid$rhs_tau0[[i]],
      seed = grid$seed[[i]],
      role = role
    )
  }))
}
candidate_profiles <- bind_rows(list(
  make_grid_role(
    role = "period90_memory_probe",
    D = c(1L, 2L),
    n_each = c(15L, 20L, 30L, 40L),
    ar_id = c(2L, 3L, 4L, 5L, 6L),
    memories = c(45L, 60L, 90L),
    tau0 = c(1e-4, 3e-4, 1e-3),
    sparse_id = c(2L, 3L)
  ),
  make_grid_role(
    role = "low_capacity_fit_probe",
    D = 1L,
    n_each = c(10L, 15L, 20L, 25L, 30L),
    ar_id = c(1L, 2L, 3L, 4L),
    memories = c(15L, 30L, 45L, 60L),
    tau0 = c(3e-5, 1e-4, 3e-4, 1e-3),
    sparse_id = c(1L, 2L, 3L)
  ),
  make_grid_role(
    role = "compact_depth_probe",
    D = c(2L, 3L),
    n_each = c(10L, 15L, 20L, 25L, 30L),
    ar_id = c(2L, 3L, 4L, 5L, 6L),
    memories = c(30L, 60L, 90L),
    tau0 = c(1e-4, 3e-4, 1e-3),
    sparse_id = c(1L, 2L)
  ),
  make_grid_role(
    role = "rhs_shrinkage_probe",
    D = c(1L, 2L),
    n_each = c(20L, 30L, 40L),
    ar_id = c(3L, 4L, 5L),
    memories = c(30L, 60L, 90L),
    tau0 = c(3e-5, 1e-4, 3e-4, 1e-3, 3e-3),
    sparse_id = c(1L, 2L, 3L)
  ),
  make_grid_role(
    role = "high_inertia_guardrail_probe",
    D = c(1L, 2L),
    n_each = c(20L, 30L, 40L, 50L),
    ar_id = c(7L, 8L, 9L),
    memories = c(30L, 60L, 90L),
    tau0 = c(1e-4, 3e-4, 1e-3),
    sparse_id = c(2L, 3L)
  ),
  make_grid_role(
    role = "seed_stability_probe",
    D = c(1L, 2L),
    n_each = c(20L, 30L),
    ar_id = c(3L, 4L, 5L, 6L),
    memories = c(60L, 90L),
    tau0 = c(1e-4, 3e-4),
    sparse_id = 2L,
    seeds = c(777L, 2027L)
  )
))
candidate_profiles <- candidate_profiles[candidate_profiles$p_over_n_tt500 <= max_p_over_n, , drop = FALSE]
candidate_profiles <- candidate_profiles[!duplicated(as.character(candidate_profiles$screening_profile_id)), , drop = FALSE]

role_quota <- c(
  period90_memory_probe = 34L,
  low_capacity_fit_probe = 20L,
  compact_depth_probe = 22L,
  rhs_shrinkage_probe = 22L,
  high_inertia_guardrail_probe = 14L,
  seed_stability_probe = 8L
)
generated_budget <- max(0L, as.integer(max_profiles) - nrow(anchor_profiles))
allocate_quota <- function(desired, budget) {
  desired <- as.integer(desired)
  names(desired) <- names(role_quota)
  budget <- as.integer(budget)[1L]
  if (!is.finite(budget) || budget <= 0L) return(setNames(rep(0L, length(desired)), names(desired)))
  if (sum(desired) <= budget) return(desired)
  raw <- desired * budget / sum(desired)
  quota <- pmax(1L, floor(raw))
  names(quota) <- names(desired)
  while (sum(quota) > budget) {
    reducible <- which(quota > 1L)
    if (!length(reducible)) break
    j <- reducible[which.max(quota[reducible])]
    quota[[j]] <- quota[[j]] - 1L
  }
  while (sum(quota) < budget) {
    room <- desired - quota
    if (!any(room > 0L)) break
    frac <- raw - floor(raw)
    frac[room <= 0L] <- -Inf
    j <- which.max(frac)
    quota[[j]] <- quota[[j]] + 1L
  }
  quota
}
role_quota <- allocate_quota(role_quota, generated_budget)
role_rank <- setNames(seq_along(role_quota), names(role_quota))
candidate_profiles$role_rank <- unname(role_rank[as.character(candidate_profiles$profile_role)])
candidate_profiles$role_rank[is.na(candidate_profiles$role_rank)] <- 99L
candidate_profiles$selection_score <- with(
  candidate_profiles,
  role_rank * 1e6 +
    abs(as.numeric(m) - 90) * 1000 +
    as.numeric(p_over_n_tt500) * 100 +
    as.numeric(D) * 10 +
    as.numeric(n_each)
)
selected_by_role <- bind_rows(lapply(names(role_quota), function(role) {
  sub <- candidate_profiles[as.character(candidate_profiles$profile_role) == role, , drop = FALSE]
  sub <- sub[order(sub$selection_score, sub$p_over_n_tt500, sub$screening_profile_id), , drop = FALSE]
  utils::head(sub, role_quota[[role]])
}))

profiles <- bind_rows(list(anchor_profiles, selected_by_role))
profiles <- profiles[!duplicated(as.character(profiles$screening_profile_id)), , drop = FALSE]
profiles$selection_score <- profiles$selection_score %||% NA_real_
profiles$role_rank <- profiles$role_rank %||% NA_integer_
profiles <- profiles[order(
  is.na(profiles$source_anchor_profile_id),
  profiles$role_rank,
  profiles$selection_score,
  profiles$p_over_n_tt500,
  profiles$screening_profile_id
), , drop = FALSE]
if (nrow(profiles) > max_profiles) {
  anchor_mask <- !is.na(profiles$source_anchor_profile_id) & nzchar(as.character(profiles$source_anchor_profile_id))
  anchors <- profiles[anchor_mask, , drop = FALSE]
  rest <- profiles[!anchor_mask, , drop = FALSE]
  profiles <- rbind(anchors, utils::head(rest, max(0L, max_profiles - nrow(anchors))))
}
profiles$fitbalanced_profile_rank <- seq_len(nrow(profiles))
profiles$target_cells <- paste(paste(cell_plan$family, sprintf("%.2f", cell_plan$tau), sep = ":"), collapse = ";")
profiles$target_cell_statuses <- paste(unique(cell_plan$cell_status), collapse = ";")
profiles$target_bottleneck_metrics <- paste(unique(cell_plan$bottleneck_metric), collapse = ";")
profiles$role_rank <- NULL
profiles$selection_score <- NULL

assignments <- bind_rows(lapply(seq_len(nrow(cell_plan)), function(i) {
  cell <- cell_plan[i, , drop = FALSE]
  bind_rows(lapply(seq_len(nrow(profiles)), function(j) {
    prof <- profiles[j, , drop = FALSE]
    data.frame(
      assignment_key = paste(prof$screening_profile_id[[1L]], cell$family[[1L]], tau_key(cell$tau[[1L]]), sep = "\r"),
      family = as.character(cell$family[[1L]]),
      tau = as.numeric(cell$tau[[1L]]),
      cell_status = as.character(cell$cell_status[[1L]]),
      priority_rank = as.integer(cell$priority_rank[[1L]]),
      target_profile_rank = as.integer(j),
      screening_profile_id = as.character(prof$screening_profile_id[[1L]]),
      source_profile = as.character(prof$source_anchor_profile_id[[1L]] %||% prof$profile_role[[1L]]),
      source_worst_ratio = as.numeric(cell$primary_worst_ratio[[1L]]),
      bottleneck_metric = as.character(cell$bottleneck_metric[[1L]]),
      assignment_id = sprintf("rhs_fitbalanced_cell_%04d", (i - 1L) * nrow(profiles) + j),
      stringsAsFactors = FALSE
    )
  }))
}))

plan <- list(
  cell_plan = cell_plan,
  candidate_ledger = candidate_profiles,
  profiles = profiles,
  assignments = assignments,
  manifest = list(
    stage = "vb_rhs_fitbalanced_broad",
    screening_wave = screening_wave,
    source_qdesn_report_root = q_report_root,
    source_profiles_path = source_profiles_path,
    target_cells = nrow(cell_plan),
    selected_profiles = nrow(profiles),
    selected_assignments = nrow(assignments),
    likelihoods_per_root = c("al", "exal"),
    design = "Q-DESN RHS VB fit-balanced broad screen: anchored by latest evidence, broadened around fit-RMSE and period-90 memory bottlenecks."
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)
diagnostic_paths <- list(
  cell_plan = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitbalanced_broad_cell_plan.csv"),
  source_latest_cell_summary = q_cell_path,
  source_latest_profile_ranking = q_profile_ranking_path,
  source_latest_audit = q_audit_path,
  candidate_ledger = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitbalanced_broad_candidate_ledger.csv"),
  selected_profiles = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitbalanced_broad_profiles.csv"),
  cell_assignments = file.path(diag_tables, "qdesn_tt500_vb_rhs_fitbalanced_broad_cell_assignments.csv"),
  summary = file.path(diag_summary, "qdesn_tt500_vb_rhs_fitbalanced_broad.md"),
  manifest = file.path(diag_manifest, "qdesn_tt500_vb_rhs_fitbalanced_broad_manifest.json")
)
exdqlm:::.qdesn_validation_write_df(cell_plan, diagnostic_paths$cell_plan)
exdqlm:::.qdesn_validation_write_df(candidate_profiles, diagnostic_paths$candidate_ledger)
exdqlm:::.qdesn_validation_write_df(profiles, diagnostic_paths$selected_profiles)
exdqlm:::.qdesn_validation_write_df(assignments, diagnostic_paths$cell_assignments)

materialized <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = "Q-DESN 500-observation VB RHS fit-balanced broad screen over all family x tau cells.",
  stage = "rhs_fitbalanced_broad",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "vb"
defaults$execution$likelihood_families <- c("al", "exal")
defaults$reference_contract$expected_selected_qdesn_roots <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$selected_assignment_root_count <- as.integer(materialized$expected_qdesn_roots)
defaults$screening_profiles$design <- sprintf(
  "Q-DESN RHS VB fit-balanced broad screen. Profiles: %d; selected roots: %d; likelihoods per root: AL and exAL.",
  nrow(profiles),
  as.integer(materialized$expected_qdesn_roots)
)
defaults$study_contract$description <- paste(
  "Q-DESN RHS VB fit-balanced broad screen over all 500-observation family/quantile cells.",
  "This stage is anchored by latest fit-aware evidence and adds period-90 memory plus fit-RMSE probes.",
  "It is screening-only until explicit promotion."
)
defaults$screening_profiles$fitbalanced_design <- list(
  source_qdesn_report_root = q_report_root,
  source_profiles_path = source_profiles_path,
  max_profiles = as.integer(max_profiles),
  max_p_over_n = as.numeric(max_p_over_n),
  period_aware_memory_lags = as.list(c(45L, 60L, 90L)),
  no_smoke_required_for_direct_launch = TRUE
)
yaml::write_yaml(defaults, defaults_out)

cell_table <- cell_plan[, c(
  "priority_rank", "family", "tau", "cell_status", "bottleneck_metric",
  "primary_worst_ratio", "best_balanced_check_ratio", "best_balanced_mae_ratio",
  "best_balanced_fit_rmse_ratio", "best_balanced_fit_check_ratio"
), drop = FALSE]
profile_table <- profiles[, intersect(c(
  "fitbalanced_profile_rank", "screening_profile_id", "profile_role", "D", "n_each",
  "alpha", "rho", "m", "readout_y_lags", "pi_w", "pi_in", "rhs_tau0",
  "seed", "dimension_p_estimate", "p_over_n_tt500", "source_anchor_profile_id"
), names(profiles)), drop = FALSE]
summary_lines <- c(
  "# Q-DESN 500-Observation VB RHS Fit-Balanced Broad Screen",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- latest_qdesn_report_root: `%s`", q_report_root),
  sprintf("- source_profiles_path: `%s`", source_profiles_path),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", as.integer(workers)),
  sprintf("- max_profiles: `%d`", as.integer(max_profiles)),
  sprintf("- max_p_over_n: `%s`", as.character(max_p_over_n)),
  sprintf("- source_audit_strict_ready: `%s`", paste(unique(q_audit$strict_ready), collapse = ",")),
  sprintf("- target_cells: `%d`", nrow(cell_plan)),
  sprintf("- selected_profiles: `%d`", nrow(profiles)),
  sprintf("- selected_roots: `%d`", as.integer(materialized$expected_qdesn_roots)),
  sprintf("- likelihoods_per_root: `%s`", "al, exal"),
  "",
  "## Rationale",
  "",
  "The latest Q-DESN RHS fit-aware screen is technically clean but still fails all-primary dominance mostly through fit RMSE. The source scenario is period-90, so this broad screen keeps the latest anchors and adds period-aware memory probes at 45, 60, and 90 lags, compact/deeper low-dimension variants, RHS shrinkage probes, high-inertia guardrails, and a small seed-stability set.",
  "",
  "## Cell Plan",
  exdqlm:::.qdesn_validation_df_to_markdown(cell_table),
  "",
  "## Selected Profiles",
  exdqlm:::.qdesn_validation_df_to_markdown(profile_table),
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- manifest: `%s`", manifest_path)
)
exdqlm:::.qdesn_validation_write_lines(diagnostic_paths$summary, summary_lines)

file_manifest <- exdqlm:::qdesn_validation_file_manifest(c(
  q_cell_path, q_profile_ranking_path, q_audit_path, source_profiles_path,
  base_defaults_path, profiles_out, assignments_out, defaults_out, grid_out,
  diagnostic_paths$cell_plan, diagnostic_paths$candidate_ledger,
  diagnostic_paths$selected_profiles, diagnostic_paths$cell_assignments,
  diagnostic_paths$summary
))
manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  qdesn_report_root = q_report_root,
  source_profiles_path = source_profiles_path,
  base_defaults_path = base_defaults_path,
  diagnostic_output_paths = diagnostic_paths,
  plan = plan$manifest,
  materialized = materialized,
  file_manifest = file_manifest,
  screening_wave = screening_wave,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  anchor_profiles_missing_from_source_registry = as.list(anchor_missing)
)
exdqlm:::.qdesn_validation_write_json(diagnostic_paths$manifest, manifest)
exdqlm:::.qdesn_validation_write_json(manifest_path, manifest)

cat(sprintf("diagnostics: %s\n", diagnostic_out))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("n_profiles: %d\n", as.integer(materialized$n_profiles)))
cat(sprintf("n_assignments: %d\n", as.integer(materialized$n_assignments)))
cat(sprintf("n_grid_rows: %d\n", as.integer(materialized$n_grid_rows)))
cat(sprintf("expected_qdesn_roots: %d\n", as.integer(materialized$expected_qdesn_roots)))
cat(sprintf("anchor_profiles_missing: %d\n", length(anchor_missing)))
