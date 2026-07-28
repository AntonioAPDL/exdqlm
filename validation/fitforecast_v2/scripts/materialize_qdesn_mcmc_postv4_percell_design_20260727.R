#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
script_path <- if (!is.na(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(
    "validation", "fitforecast_v2", "scripts",
    "materialize_qdesn_mcmc_postv4_percell_design_20260727.R"
  ), winslash = "/", mustWork = TRUE)
}
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

read_csv <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(path)[[1L]])
num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
str_value <- function(x, default = "") {
  if (is.null(x) || !length(x)) return(default)
  x <- as.character(x)
  x[is.na(x)] <- default
  x
}
bind_rows_fill <- function(values) {
  values <- Filter(Negate(is.null), values)
  if (!length(values)) return(data.frame())
  columns <- unique(unlist(lapply(values, names), use.names = FALSE))
  values <- lapply(values, function(value) {
    missing <- setdiff(columns, names(value))
    for (column in missing) value[[column]] <- NA
    value[, columns, drop = FALSE]
  })
  do.call(rbind, values)
}
tau_key <- function(x) sprintf("%.8f", num(x))
cell_key <- function(model_variant, family, tau, fit_size = 500L) {
  paste(model_variant, family, tau_key(tau), as.integer(fit_size), sep = "\r")
}
metric_role_to_column <- function(role) {
  switch(
    role,
    fit = "fit_qtrue_rmse",
    forecast_mae = "forecast_qtrue_mae_H1000",
    forecast_check = "forecast_check_loss_H1000",
    role
  )
}
metric_role_to_external <- function(role) {
  switch(
    role,
    fit = "external_best_fit_rmse",
    forecast_mae = "external_best_forecast_mae",
    forecast_check = "external_best_forecast_check",
    role
  )
}
metric_label <- function(metric) {
  switch(
    metric,
    fit_qtrue_rmse = "fit",
    forecast_qtrue_mae_H1000 = "forecast_mae",
    forecast_check_loss_H1000 = "forecast_check",
    metric
  )
}
md_table <- function(value, columns, max_rows = 80L) {
  columns <- intersect(columns, names(value))
  if (!length(columns) || !nrow(value)) return(c("| none |", "|---|"))
  value <- utils::head(value[, columns, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(columns, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(columns)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(value))) {
    row <- vapply(value[i, columns, drop = TRUE], function(x) {
      x <- as.character(x)
      x[is.na(x)] <- ""
      gsub("\n", " ", x, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(row, collapse = " | "), "|"))
  }
  out
}
git_value <- function(args) {
  value <- system2("git", c("-C", repo_root, args), stdout = TRUE)
  if (!length(value)) NA_character_ else value[[1L]]
}

date_stamp <- "20260727"
promotion_id <- paste0("qdesn_tt500_mcmc_postv4_percell_design_", date_stamp)
parent_closeout_id <- "qdesn_tt500_mcmc_metricgap_v4_targeted_closeout_20260727"
parent_envelope_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
source_hash_expected <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"

promotion_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", promotion_id)
parent_closeout_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", parent_closeout_id)
parent_envelope_root <- file.path(repo_root, "validation", "fitforecast_v2", "promotions", parent_envelope_id)

description <- read.dcf(file.path(repo_root, "DESCRIPTION"))
if (!identical(as.character(description[1L, "Package"]), "exdqlm") ||
    !identical(as.character(description[1L, "Version"]), "1.0.0")) {
  stop("Post-v4 per-cell design requires the exdqlm 1.0.0 validation worktree.", call. = FALSE)
}

git_branch <- git_value(c("branch", "--show-current"))
git_commit <- git_value(c("rev-parse", "HEAD"))

summary_v4 <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_summary.csv")))
next_handoff <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_next_screen_handoff.csv")))
unresolved <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_unresolved_cells.csv")))
v4_candidates <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_v4_candidate_metrics.csv")))
v4_combined <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_combined_candidate_ledger.csv")))
v4_promotions <- read_csv(file.path(parent_closeout_root, paste0(parent_closeout_id, "_metricwise_promotions.csv")))
parent_envelope <- read_csv(file.path(parent_envelope_root, paste0(parent_envelope_id, "_article_envelope.csv")))

if (nrow(summary_v4) != 1L ||
    as.integer(summary_v4$planned_roots[[1L]]) != 75L ||
    as.integer(summary_v4$completed_roots[[1L]]) != 75L ||
    as.integer(summary_v4$failed_roots[[1L]]) != 0L ||
    as.integer(summary_v4$unresolved_cells[[1L]]) != 15L) {
  stop("Parent v4 closeout is not complete and clean enough for post-v4 design.", call. = FALSE)
}
if (!identical(as.character(summary_v4$source_registry_hash_value[[1L]]), source_hash_expected)) {
  stop("Parent v4 closeout does not carry the frozen source-registry hash.", call. = FALSE)
}
if (nrow(next_handoff) != 15L || nrow(unresolved) != 15L) {
  stop("Post-v4 design requires exactly 15 unresolved handoff rows.", call. = FALSE)
}

ledger_paths <- c(
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_current_best_20260723",
    "qdesn_dqlm_500obs_mcmc_current_best_all_candidates_20260723.csv"
  ),
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_rhsrepair_v1c_status_agnostic_closeout_20260725",
    "qdesn_dqlm_500obs_mcmc_status_agnostic_all_candidates_20260725.csv"
  ),
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726_all_candidates.csv"
  ),
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_tt500_mcmc_metricgap_v3_combined_closeout_20260727",
    "qdesn_tt500_mcmc_metricgap_v3_combined_closeout_20260727_all_candidates.csv"
  ),
  file.path(parent_envelope_root, paste0(parent_envelope_id, "_all_candidates.csv")),
  file.path(parent_closeout_root, paste0(parent_closeout_id, "_combined_candidate_ledger.csv"))
)
ledger_paths <- ledger_paths[file.exists(ledger_paths)]

standardize_candidate <- function(path) {
  x <- read_csv(path)
  n <- nrow(x)
  model_variant <- if ("model_variant" %in% names(x)) {
    str_value(x$model_variant)
  } else if ("likelihood_target" %in% names(x)) {
    paste0("qdesn_", str_value(x$likelihood_target), "_rhs_ns")
  } else {
    rep(NA_character_, n)
  }
  candidate_id <- if ("candidate_id" %in% names(x)) {
    str_value(x$candidate_id)
  } else if ("current_candidate_id" %in% names(x)) {
    str_value(x$current_candidate_id)
  } else if ("screening_profile_id" %in% names(x)) {
    str_value(x$screening_profile_id)
  } else {
    rep(NA_character_, n)
  }
  run_tag <- if ("run_tag" %in% names(x)) str_value(x$run_tag) else rep("", n)
  source_registry_hash_value <- if ("source_registry_hash_value" %in% names(x)) {
    str_value(x$source_registry_hash_value)
  } else {
    rep(source_hash_expected, n)
  }
  source_key <- if ("source_key" %in% names(x)) {
    str_value(x$source_key)
  } else if ("evidence_source" %in% names(x)) {
    str_value(x$evidence_source)
  } else {
    rep(basename(dirname(path)), n)
  }
  source_path <- if ("source_path" %in% names(x)) {
    str_value(x$source_path)
  } else {
    rep(normalizePath(path, winslash = "/", mustWork = TRUE), n)
  }
  source_table_sha256 <- if ("source_table_sha256" %in% names(x)) {
    str_value(x$source_table_sha256)
  } else {
    rep(sha256(path), n)
  }
  screening_profile_id <- if ("screening_profile_id" %in% names(x)) {
    str_value(x$screening_profile_id)
  } else {
    candidate_id
  }
  data.frame(
    history_source_file = normalizePath(path, winslash = "/", mustWork = TRUE),
    history_source_id = basename(dirname(path)),
    model_variant = model_variant,
    family = str_value(x$family),
    tau = num(x$tau),
    fit_size = if ("fit_size" %in% names(x)) int(x$fit_size) else rep(500L, n),
    candidate_id = candidate_id,
    spec_id = if ("spec_id" %in% names(x)) str_value(x$spec_id) else rep("", n),
    screening_profile_id = screening_profile_id,
    fit_qtrue_rmse = if ("fit_qtrue_rmse" %in% names(x)) num(x$fit_qtrue_rmse) else rep(NA_real_, n),
    forecast_qtrue_mae_H1000 = if ("forecast_qtrue_mae_H1000" %in% names(x)) num(x$forecast_qtrue_mae_H1000) else rep(NA_real_, n),
    forecast_check_loss_H1000 = if ("forecast_check_loss_H1000" %in% names(x)) num(x$forecast_check_loss_H1000) else rep(NA_real_, n),
    status = if ("status" %in% names(x)) str_value(x$status) else rep("", n),
    signoff_grade = if ("signoff_grade" %in% names(x)) str_value(x$signoff_grade) else rep("", n),
    comparison_eligible = if ("comparison_eligible" %in% names(x)) str_value(x$comparison_eligible) else rep("", n),
    run_tag = run_tag,
    source_key = source_key,
    source_path = source_path,
    source_table_sha256 = source_table_sha256,
    source_registry_hash_value = source_registry_hash_value,
    stringsAsFactors = FALSE
  )
}

candidate_history <- bind_rows_fill(lapply(ledger_paths, standardize_candidate))
candidate_history <- candidate_history[
  candidate_history$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns") &
    candidate_history$fit_size == 500L &
    is.finite(candidate_history$tau) &
    nzchar(candidate_history$family) &
    nzchar(candidate_history$candidate_id),
  ,
  drop = FALSE
]
candidate_history$history_cell_key <- cell_key(
  candidate_history$model_variant,
  candidate_history$family,
  candidate_history$tau,
  candidate_history$fit_size
)
candidate_history$source_registry_hash_ok <- candidate_history$source_registry_hash_value == source_hash_expected |
  !nzchar(candidate_history$source_registry_hash_value)
candidate_history <- candidate_history[!duplicated(
  paste(
    candidate_history$model_variant,
    candidate_history$family,
    tau_key(candidate_history$tau),
    candidate_history$candidate_id,
    candidate_history$spec_id,
    candidate_history$run_tag,
    candidate_history$history_source_id,
    sep = "\r"
  )
), , drop = FALSE]

required_cell_keys <- cell_key(next_handoff$model_variant, next_handoff$family, next_handoff$tau, next_handoff$fit_size)
if (!all(required_cell_keys %in% candidate_history$history_cell_key)) {
  stop("At least one unresolved cell has no historical candidate rows.", call. = FALSE)
}

diagnostic <- next_handoff
diagnostic$fit_gap_pct <- round((num(diagnostic$fit_ratio_refreshed) - 1) * 100, 2)
diagnostic$forecast_mae_gap_pct <- round((num(diagnostic$forecast_mae_ratio_refreshed) - 1) * 100, 2)
diagnostic$forecast_check_gap_pct <- round((num(diagnostic$forecast_check_ratio_refreshed) - 1) * 100, 2)
diagnostic$worst_gap_pct <- round((num(diagnostic$worst_ratio_refreshed) - 1) * 100, 2)
diagnostic$dominant_gap_class <- ifelse(
  diagnostic$primary_remaining_gap == "fit",
  "fit_dominated",
  "forecast_dominated"
)
diagnostic$scientific_priority <- ifelse(
  num(diagnostic$tau) <= 0.25,
  "primary_lower_quantile_goal",
  "secondary_median_context"
)
diagnostic$next_action <- ifelse(
  diagnostic$dominant_gap_class == "fit_dominated",
  "fit-first per-cell MCMC redesign with forecast guardrail",
  "forecast-first per-cell MCMC redesign with fit guardrail"
)

metrics <- c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")
metric_winners <- do.call(rbind, lapply(seq_len(nrow(diagnostic)), function(i) {
  row <- diagnostic[i, , drop = FALSE]
  key <- cell_key(row$model_variant, row$family, row$tau, row$fit_size)
  pool <- candidate_history[candidate_history$history_cell_key == key, , drop = FALSE]
  do.call(rbind, lapply(metrics, function(metric) {
    values <- num(pool[[metric]])
    finite <- is.finite(values)
    if (!any(finite)) return(NULL)
    best_index <- which(finite)[which.min(values[finite])]
    best <- pool[best_index, , drop = FALSE]
    current_value <- num(row[[paste0(metric, "_refreshed")]])
    if (!is.finite(current_value)) current_value <- num(row[[metric]])
    external_value <- num(row[[switch(
      metric,
      fit_qtrue_rmse = "external_best_fit_rmse",
      forecast_qtrue_mae_H1000 = "external_best_forecast_mae",
      forecast_check_loss_H1000 = "external_best_forecast_check"
    )]])
    data.frame(
      model_variant = row$model_variant,
      family = row$family,
      tau = num(row$tau),
      fit_size = int(row$fit_size),
      metric = metric,
      metric_role = metric_label(metric),
      historical_best_value = values[[best_index]],
      current_refreshed_value = current_value,
      external_best_value = external_value,
      ratio_to_current = values[[best_index]] / current_value,
      ratio_to_external_best = values[[best_index]] / external_value,
      candidate_id = best$candidate_id,
      spec_id = best$spec_id,
      screening_profile_id = best$screening_profile_id,
      run_tag = best$run_tag,
      signoff_grade = best$signoff_grade,
      status = best$status,
      history_source_id = best$history_source_id,
      source_path = best$source_path,
      source_registry_hash_value = best$source_registry_hash_value,
      stringsAsFactors = FALSE
    )
  }))
}))

coherent_candidates <- do.call(rbind, lapply(seq_len(nrow(diagnostic)), function(i) {
  row <- diagnostic[i, , drop = FALSE]
  key <- cell_key(row$model_variant, row$family, row$tau, row$fit_size)
  pool <- candidate_history[candidate_history$history_cell_key == key, , drop = FALSE]
  pool <- pool[
    is.finite(pool$fit_qtrue_rmse) &
      is.finite(pool$forecast_qtrue_mae_H1000) &
      is.finite(pool$forecast_check_loss_H1000),
    ,
    drop = FALSE
  ]
  if (!nrow(pool)) return(NULL)
  pool$fit_ratio_to_external_best <- pool$fit_qtrue_rmse / num(row$external_best_fit_rmse)
  pool$forecast_mae_ratio_to_external_best <- pool$forecast_qtrue_mae_H1000 / num(row$external_best_forecast_mae)
  pool$forecast_check_ratio_to_external_best <- pool$forecast_check_loss_H1000 / num(row$external_best_forecast_check)
  pool$worst_ratio_to_external_best <- pmax(
    pool$fit_ratio_to_external_best,
    pool$forecast_mae_ratio_to_external_best,
    pool$forecast_check_ratio_to_external_best,
    na.rm = TRUE
  )
  pool <- pool[order(pool$worst_ratio_to_external_best), , drop = FALSE]
  pool <- utils::head(pool, 3L)
  pool$rank_within_cell <- seq_len(nrow(pool))
  pool[, c(
    "model_variant", "family", "tau", "fit_size", "rank_within_cell",
    "candidate_id", "spec_id", "screening_profile_id", "fit_qtrue_rmse",
    "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
    "fit_ratio_to_external_best", "forecast_mae_ratio_to_external_best",
    "forecast_check_ratio_to_external_best", "worst_ratio_to_external_best",
    "status", "signoff_grade", "run_tag", "history_source_id",
    "source_path", "source_registry_hash_value"
  ), drop = FALSE]
}))

profile_paths <- list.files(
  file.path(repo_root, "config", "validation"),
  pattern = "mcmc.*profiles[.]csv$",
  full.names = TRUE
)
profile_tables <- lapply(profile_paths, function(path) {
  x <- read_csv(path)
  x$profile_source_file <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x
})
profiles <- bind_rows_fill(profile_tables)
profile_columns <- c(
  "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
  "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500",
  "profile_source_file"
)
profiles <- profiles[, intersect(profile_columns, names(profiles)), drop = FALSE]
profiles <- profiles[!duplicated(profiles$screening_profile_id), , drop = FALSE]

resolve_profile <- function(profile_id) {
  profile_id <- sub("__seed_[0-9]+$", "", as.character(profile_id))
  hit <- profiles[profiles$screening_profile_id == profile_id, , drop = FALSE]
  if (!nrow(hit)) return(NULL)
  hit[1L, , drop = FALSE]
}
profile_value <- function(profile, column, default = NA_real_) {
  if (is.null(profile) || !(column %in% names(profile))) return(default)
  value <- profile[[column]][[1L]]
  if (is.na(value) || !nzchar(as.character(value))) default else value
}

make_numeric_arm <- function(row, role, arm_rank, source, profile, axis, seed_offset = 0L) {
  base_D <- int(profile_value(profile, "D", 1L))
  base_n <- int(profile_value(profile, "n_each", 30L))
  base_m <- int(profile_value(profile, "readout_y_lags", profile_value(profile, "m", 15L)))
  base_alpha <- num(profile_value(profile, "alpha", 0.003))
  base_rho <- num(profile_value(profile, "rho", 0.90))
  base_tau0 <- num(profile_value(profile, "rhs_tau0", 1e-6))
  base_seed <- int(profile_value(profile, "seed", 90000L))
  lower_tau <- num(row$tau) <= 0.25
  if (role == "local_tau0_3em7") {
    rhs_tau0 <- 3e-7
    D <- base_D
    n_each <- base_n
    m <- base_m
    alpha <- max(min(base_alpha, 0.004), 0.0008)
    rho <- min(max(base_rho, 0.86), 0.96)
    pi_w <- num(profile_value(profile, "pi_w", 0.002))
    pi_in <- num(profile_value(profile, "pi_in", 0.06))
  } else if (role == "local_tau0_1em7") {
    rhs_tau0 <- 1e-7
    D <- base_D
    n_each <- base_n
    m <- base_m
    alpha <- max(min(base_alpha, 0.003), 0.0005)
    rho <- min(max(base_rho, 0.88), 0.97)
    pi_w <- num(profile_value(profile, "pi_w", 0.0015))
    pi_in <- num(profile_value(profile, "pi_in", 0.04))
  } else if (axis == "fit") {
    rhs_tau0 <- if (lower_tau) 3e-7 else 1e-6
    D <- min(max(base_D, 2L), 3L)
    n_each <- min(max(base_n, 80L), 160L)
    m <- min(max(base_m, 40L), 100L)
    alpha <- if (lower_tau) 0.001 else 0.0015
    rho <- if (lower_tau) 0.90 else 0.92
    pi_w <- 0.001
    pi_in <- 0.04
  } else {
    rhs_tau0 <- if (lower_tau) 3e-7 else 1e-6
    D <- min(max(base_D, 2L), 4L)
    n_each <- min(max(base_n, 90L), 180L)
    m <- min(max(base_m, 100L), 160L)
    alpha <- if (lower_tau) 0.0015 else 0.0025
    rho <- if (lower_tau) 0.92 else 0.96
    pi_w <- 0.001
    pi_in <- 0.04
  }
  n_tilde_each <- if (D <= 1L) 0L else n_each
  dimension_p <- (D * n_each) + n_tilde_each + as.integer(m) + 1L + 5L
  data.frame(
    model_variant = row$model_variant,
    family = row$family,
    tau = num(row$tau),
    fit_size = int(row$fit_size),
    design_cell_key = cell_key(row$model_variant, row$family, row$tau, row$fit_size),
    arm_rank = arm_rank,
    arm_role = role,
    arm_axis = axis,
    source_candidate_id = source$candidate_id,
    source_spec_id = source$spec_id,
    source_screening_profile_id = source$screening_profile_id,
    source_run_tag = source$run_tag,
    source_signoff_grade = source$signoff_grade,
    source_status = source$status,
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    m = m,
    alpha = alpha,
    rho = rho,
    pi_w = pi_w,
    pi_in = pi_in,
    readout_y_lags = m,
    reservoir_lags = 0L,
    rhs_tau0 = rhs_tau0,
    seed = base_seed + seed_offset + arm_rank,
    dimension_p_estimate = dimension_p,
    p_over_n_tt500 = dimension_p / 500,
    proposed_budget = "screening_mcmc_2000_burn_8000_draws_then_full_confirmation_only_for_promotions",
    launch_status = "not_materialized_not_launched_review_required",
    review_gate = "requires_explicit_user_approval_before_orchestrator_materialization",
    rationale = switch(
      role,
      replay_primary_metric_winner = "Replay the best historical row for the current bottleneck metric before changing the search surface.",
      replay_coherent_best = "Replay the most balanced historical row to guard against mixed-envelope overfitting.",
      local_tau0_3em7 = "Local stronger-shrinkage perturbation; tests whether prior scale, not capacity, is the limiting factor.",
      local_tau0_1em7 = "More aggressive local shrinkage perturbation; capped by review because over-shrinkage can hurt forecasts.",
      axis_specific_breakout_a = "Axis-specific breakaway arm designed from the remaining fit/forecast bottleneck.",
      axis_specific_breakout_b = "Second axis-specific breakaway arm with the same cell objective but a different capacity-shrinkage balance.",
      "case-specific candidate arm"
    ),
    stringsAsFactors = FALSE
  )
}

design_rows <- list()
for (i in seq_len(nrow(diagnostic))) {
  row <- diagnostic[i, , drop = FALSE]
  key <- cell_key(row$model_variant, row$family, row$tau, row$fit_size)
  metric <- metric_role_to_column(as.character(row$primary_remaining_gap[[1L]]))
  metric_win <- metric_winners[
    cell_key(metric_winners$model_variant, metric_winners$family, metric_winners$tau, metric_winners$fit_size) == key &
      metric_winners$metric == metric,
    ,
    drop = FALSE
  ]
  coherent <- coherent_candidates[
    cell_key(coherent_candidates$model_variant, coherent_candidates$family, coherent_candidates$tau, coherent_candidates$fit_size) == key &
      coherent_candidates$rank_within_cell == 1L,
    ,
    drop = FALSE
  ]
  if (nrow(metric_win) != 1L || nrow(coherent) != 1L) {
    stop("Could not resolve metric and coherent anchors for every unresolved cell.", call. = FALSE)
  }
  metric_profile <- resolve_profile(metric_win$screening_profile_id[[1L]])
  coherent_profile <- resolve_profile(coherent$screening_profile_id[[1L]])
  if (is.null(metric_profile)) metric_profile <- coherent_profile
  if (is.null(coherent_profile)) coherent_profile <- metric_profile
  axis <- if (row$dominant_gap_class[[1L]] == "fit_dominated") "fit" else "forecast"
  design_rows <- c(design_rows, list(
    make_numeric_arm(row, "replay_primary_metric_winner", 1L, metric_win, metric_profile, axis, i * 100L),
    make_numeric_arm(row, "replay_coherent_best", 2L, coherent, coherent_profile, axis, i * 100L),
    make_numeric_arm(row, "local_tau0_3em7", 3L, metric_win, metric_profile, axis, i * 100L),
    make_numeric_arm(row, "local_tau0_1em7", 4L, metric_win, metric_profile, axis, i * 100L),
    make_numeric_arm(row, "axis_specific_breakout_a", 5L, metric_win, metric_profile, axis, i * 100L),
    make_numeric_arm(row, "axis_specific_breakout_b", 6L, coherent, coherent_profile, axis, i * 100L)
  ))
}
design <- do.call(rbind, design_rows)

design$blocked_reason <- ifelse(
  design$p_over_n_tt500 > 1.60,
  "exceeds_current_safe_p_over_n_review_gate",
  ""
)
design$launch_ready_after_review <- design$blocked_reason == ""

review_checklist <- data.frame(
  check_id = sprintf("postv4_check_%02d", seq_len(10L)),
  required_before_launch = TRUE,
  status = c(
    "complete",
    "complete",
    "complete",
    "complete",
    "complete",
    "pending_review",
    "pending_review",
    "pending_review",
    "pending_review",
    "pending_review"
  ),
  check = c(
    "v4 closeout complete with 75/75 roots and 0 failures",
    "frozen source-registry hash preserved",
    "unresolved-cell handoff has exactly 15 rows",
    "candidate design is per-cell rather than global",
    "all candidate arms are prepared-not-launched",
    "review candidate arms for scientific plausibility",
    "decide whether to allow p/n arms above the conservative launch comfort band",
    "materialize orchestrator configs only after review",
    "run one-cell smoke before full reduced-budget launch",
    "commit/push reviewed design before launch"
  ),
  evidence = c(
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_summary.csv")),
    source_hash_expected,
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_next_screen_handoff.csv")),
    paste0(nrow(unique(design[c("model_variant", "family", "tau", "fit_size")])) , " per-cell designs"),
    "launch_status = not_materialized_not_launched_review_required",
    "human/scientific review not yet recorded",
    "review threshold remains p_over_n_tt500 <= 1.60 unless explicitly changed",
    "no config/validation post-v4 launch grid generated by this script",
    "not run",
    "not run"
  ),
  stringsAsFactors = FALSE
)

if (nrow(diagnostic) != 15L ||
    nrow(unique(diagnostic[c("model_variant", "family", "tau", "fit_size")])) != 15L) {
  stop("Diagnostic table must contain exactly 15 unresolved cells.", call. = FALSE)
}
if (nrow(metric_winners) != 45L) {
  stop("Expected three historical metric winners for each of 15 cells.", call. = FALSE)
}
if (nrow(design) != 90L || any(table(design$design_cell_key) != 6L)) {
  stop("Expected six candidate arms for each of 15 unresolved cells.", call. = FALSE)
}
if (any(design$launch_status != "not_materialized_not_launched_review_required")) {
  stop("Post-v4 design must not launch or mark candidates as launch-ready automatically.", call. = FALSE)
}
if (any(grepl("/home/jaguir26/local/src", unlist(design), fixed = TRUE))) {
  stop("Post-v4 design contains stale /home/jaguir26/local/src paths.", call. = FALSE)
}

summary <- data.frame(
  promotion_id = promotion_id,
  parent_closeout_id = parent_closeout_id,
  parent_envelope_id = parent_envelope_id,
  materialization_branch = git_branch,
  materialization_commit = git_commit,
  source_registry_hash_value = source_hash_expected,
  historical_ledger_files = length(ledger_paths),
  historical_candidate_rows = nrow(candidate_history),
  unresolved_cells = nrow(diagnostic),
  fit_dominated_cells = sum(diagnostic$dominant_gap_class == "fit_dominated"),
  forecast_dominated_cells = sum(diagnostic$dominant_gap_class == "forecast_dominated"),
  lower_quantile_primary_goal_cells = sum(diagnostic$scientific_priority == "primary_lower_quantile_goal"),
  metric_winner_rows = nrow(metric_winners),
  coherent_candidate_rows = nrow(coherent_candidates),
  candidate_arm_rows = nrow(design),
  candidate_arms_per_cell = 6L,
  launch_status = "prepared_not_launched_review_required",
  article_update_decision = "do_not_update_article_from_design_only",
  recommendation = "review_post_v4_per_cell_design_then_materialize_orchestrator_only_after_user_approval",
  stringsAsFactors = FALSE
)

diagnostic_path <- write_csv(
  diagnostic,
  file.path(promotion_root, paste0(promotion_id, "_unresolved_cell_diagnostic.csv"))
)
history_path <- write_csv(
  candidate_history,
  file.path(promotion_root, paste0(promotion_id, "_historical_candidate_pool.csv"))
)
metric_winners_path <- write_csv(
  metric_winners,
  file.path(promotion_root, paste0(promotion_id, "_historical_metric_winners_by_cell.csv"))
)
coherent_path <- write_csv(
  coherent_candidates,
  file.path(promotion_root, paste0(promotion_id, "_historical_coherent_candidates_by_cell.csv"))
)
design_path <- write_csv(
  design,
  file.path(promotion_root, paste0(promotion_id, "_candidate_arm_design.csv"))
)
review_path <- write_csv(
  review_checklist,
  file.path(promotion_root, paste0(promotion_id, "_launch_review_checklist.csv"))
)
summary_path <- write_csv(
  summary,
  file.path(promotion_root, paste0(promotion_id, "_summary.csv"))
)

source_manifest <- data.frame(
  source_role = c(
    "parent_v4_closeout_summary",
    "parent_v4_next_handoff",
    "parent_v4_unresolved_cells",
    "parent_v4_candidate_metrics",
    "parent_v4_combined_ledger",
    "parent_v4_metric_promotions",
    "parent_envelope_article",
    paste0("historical_ledger_", seq_along(ledger_paths))
  ),
  path = c(
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_summary.csv")),
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_next_screen_handoff.csv")),
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_unresolved_cells.csv")),
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_v4_candidate_metrics.csv")),
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_combined_candidate_ledger.csv")),
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_metricwise_promotions.csv")),
    file.path(parent_envelope_root, paste0(parent_envelope_id, "_article_envelope.csv")),
    ledger_paths
  ),
  stringsAsFactors = FALSE
)
source_manifest$path <- normalizePath(source_manifest$path, winslash = "/", mustWork = TRUE)
source_manifest$sha256 <- vapply(source_manifest$path, sha256, character(1L))
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

manifest <- list(
  promotion_id = promotion_id,
  parent_closeout_id = parent_closeout_id,
  parent_envelope_id = parent_envelope_id,
  materializer = "validation/fitforecast_v2/scripts/materialize_qdesn_mcmc_postv4_percell_design_20260727.R",
  materialization_branch = git_branch,
  materialization_commit = git_commit,
  source_registry_hash_value = source_hash_expected,
  n_historical_ledger_files = length(ledger_paths),
  n_historical_candidate_rows = nrow(candidate_history),
  n_unresolved_cells = nrow(diagnostic),
  n_metric_winner_rows = nrow(metric_winners),
  n_candidate_arm_rows = nrow(design),
  launch_status = "prepared_not_launched_review_required",
  article_update_decision = "do_not_update_article_from_design_only",
  generated_paths = list(
    summary = summary_path,
    unresolved_cell_diagnostic = diagnostic_path,
    historical_candidate_pool = history_path,
    historical_metric_winners = metric_winners_path,
    historical_coherent_candidates = coherent_path,
    candidate_arm_design = design_path,
    launch_review_checklist = review_path,
    source_manifest = source_manifest_path
  )
)
manifest_path <- write_json(
  manifest,
  file.path(promotion_root, paste0(promotion_id, "_manifest.json"))
)

readme <- c(
  "# Q-DESN 500-Observation MCMC Post-v4 Per-cell Design",
  "",
  sprintf("- Promotion id: `%s`", promotion_id),
  sprintf("- Parent v4 closeout: `%s`", parent_closeout_id),
  sprintf("- Parent metric envelope: `%s`", parent_envelope_id),
  sprintf("- Materialization commit: `%s`", git_commit),
  sprintf("- Source registry SHA-256: `%s`", source_hash_expected),
  sprintf("- Historical candidate rows mined: `%d`", nrow(candidate_history)),
  sprintf("- Unresolved cells: `%d`", nrow(diagnostic)),
  sprintf("- Candidate arms: `%d` arms, six per unresolved cell", nrow(design)),
  "- Launch status: `prepared_not_launched_review_required`",
  "- Article update decision: `do_not_update_article_from_design_only`",
  "",
  "## Why this design exists",
  "",
  "The v4 targeted MCMC screen produced valid but modest metric-wise gains and",
  "left all 15 targeted Q-DESN/exQ-DESN RHS cells outside the 1.10",
  "external-best tolerance. The next step should therefore be a per-cell design",
  "review rather than another broad global grid.",
  "",
  "## Unresolved gap summary",
  "",
  md_table(
    diagnostic[, c(
      "model_variant", "family", "tau", "primary_remaining_gap",
      "fit_ratio_refreshed", "forecast_mae_ratio_refreshed",
      "forecast_check_ratio_refreshed", "worst_ratio_refreshed",
      "dominant_gap_class", "scientific_priority"
    ), drop = FALSE],
    c(
      "model_variant", "family", "tau", "primary_remaining_gap",
      "fit_ratio_refreshed", "forecast_mae_ratio_refreshed",
      "forecast_check_ratio_refreshed", "worst_ratio_refreshed",
      "dominant_gap_class", "scientific_priority"
    ),
    max_rows = 20L
  ),
  "",
  "## Candidate-arm rule",
  "",
  "Each unresolved cell receives six arms:",
  "",
  "1. replay the historical winner for the bottleneck metric;",
  "2. replay the most coherent/balanced historical candidate;",
  "3. local `tau0 = 3e-7` perturbation;",
  "4. local `tau0 = 1e-7` perturbation;",
  "5. axis-specific breakout arm A;",
  "6. axis-specific breakout arm B.",
  "",
  "This is intentionally not a global specification search. The calibration unit",
  "is model variant x family x quantile x bottleneck metric.",
  "",
  "## Gate",
  "",
  "No orchestrator config is generated by this materializer. Launch requires a",
  "separate reviewed materialization step, one-cell smoke, and explicit user",
  "approval.",
  "",
  "## Files",
  "",
  sprintf("- Summary: `%s`", basename(summary_path)),
  sprintf("- Unresolved diagnostic: `%s`", basename(diagnostic_path)),
  sprintf("- Historical pool: `%s`", basename(history_path)),
  sprintf("- Metric winners: `%s`", basename(metric_winners_path)),
  sprintf("- Coherent candidates: `%s`", basename(coherent_path)),
  sprintf("- Candidate-arm design: `%s`", basename(design_path)),
  sprintf("- Launch review checklist: `%s`", basename(review_path)),
  sprintf("- Manifest: `%s`", basename(manifest_path))
)
readme_path <- file.path(promotion_root, "README.md")
writeLines(readme, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)

file_manifest_paths <- c(
  summary_path,
  diagnostic_path,
  history_path,
  metric_winners_path,
  coherent_path,
  design_path,
  review_path,
  manifest_path,
  source_manifest_path,
  readme_path
)
file_manifest <- data.frame(
  path = normalizePath(file_manifest_paths, winslash = "/", mustWork = TRUE),
  size_bytes = file.info(file_manifest_paths)$size,
  sha256 = vapply(file_manifest_paths, sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(file_manifest, file.path(promotion_root, "file_manifest.csv"))

cat(sprintf("promotion_id: %s\n", promotion_id))
cat(sprintf("unresolved_cells: %d\n", nrow(diagnostic)))
cat(sprintf("candidate_arm_rows: %d\n", nrow(design)))
cat(sprintf("launch_status: %s\n", summary$launch_status[[1L]]))
cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("file_manifest: %s\n", file_manifest_path))
