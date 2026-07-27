#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(required, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
materialization_git_sha <- trimws(system("git rev-parse HEAD", intern = TRUE))
materialization_git_branch <- trimws(system("git branch --show-current", intern = TRUE))
tracked_source_dirty_before_materialization <-
  system("git diff --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L ||
  system("git diff --cached --quiet", ignore.stdout = TRUE, ignore.stderr = TRUE) != 0L

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
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
  jsonlite::write_json(
    x,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_label <- function(x) sub("0+$", "", sub("[.]$", "", sprintf("%.2f", as.numeric(x))))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
model_to_likelihood <- function(x) {
  out <- rep(NA_character_, length(x))
  out[as.character(x) == "qdesn_al_rhs_ns"] <- "al"
  out[as.character(x) == "qdesn_exal_rhs_ns"] <- "exal"
  out
}
metric_anchor_id <- function(row) {
  gap <- as.character(row$primary_gap[[1L]])
  id <- switch(
    gap,
    fit = row$fit_source_candidate_id[[1L]],
    forecast_mae = row$forecast_mae_source_candidate_id[[1L]],
    forecast_check = row$forecast_check_source_candidate_id[[1L]],
    stop(sprintf("Unsupported primary gap `%s`.", gap), call. = FALSE)
  )
  sub("__seed_[0-9]+$", "", as.character(id))
}
md_table <- function(x, cols, max_rows = 80L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    values <- vapply(y[i, , drop = TRUE], function(value) {
      value <- as.character(value)
      value[is.na(value)] <- ""
      gsub("\n", " ", value, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(values, collapse = " | "), "|"))
  }
  out
}

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v4_targeted"
))[1L]
stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
workers <- int(get_arg("--workers", "24"))[1L]
if (!is.finite(workers) || workers < 1L) workers <- 24L
workers <- min(workers, 32L)
unresolved_threshold <- num(get_arg("--unresolved-threshold", "1.10"))[1L]
if (!is.finite(unresolved_threshold) || unresolved_threshold < 1) unresolved_threshold <- 1.10
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

handoff_path <- resolve_path(get_arg(
  "--handoff",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_targeted_screening_handoff.csv"
  )
))
source_profiles_path <- resolve_path(get_arg(
  "--source-profiles",
  file.path(
    "config", "validation",
    "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_profiles.csv"
  )
))
source_candidates_path <- resolve_path(get_arg(
  "--source-candidates",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727_all_candidates.csv"
  )
))
base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path(
    "config", "validation",
    "qdesn_dynamic_fitforecast_v2_tt500_mcmc_percase_rhs_v2_defaults.yaml"
  )
))
out_root <- resolve_path(get_arg(
  "--out-root",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_", stamp)
  )
), must_work = FALSE)

profiles_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_profiles.csv")),
  must_work = FALSE
)
assignments_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")),
  must_work = FALSE
)
defaults_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_defaults.yaml")),
  must_work = FALSE
)
grid_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_grid.csv")),
  must_work = FALSE
)
target_specs_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv")),
  must_work = FALSE
)
manifest_out <- resolve_path(
  file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")),
  must_work = FALSE
)

handoff <- read_csv(handoff_path)
source_profiles <- read_csv(source_profiles_path)
source_candidates <- read_csv(source_candidates_path)

required_handoff <- c(
  "model_variant", "family", "tau", "primary_gap", "worst_ratio_to_external_best",
  "fit_ratio_to_external_best", "forecast_mae_ratio_to_external_best",
  "forecast_check_ratio_to_external_best", "fit_source_candidate_id",
  "forecast_mae_source_candidate_id", "forecast_check_source_candidate_id",
  "source_registry_hash_value", "priority"
)
missing_handoff <- setdiff(required_handoff, names(handoff))
if (length(missing_handoff)) {
  stop(
    sprintf("Handoff is missing column(s): %s", paste(missing_handoff, collapse = ", ")),
    call. = FALSE
  )
}

handoff$likelihood_target <- model_to_likelihood(handoff$model_variant)
handoff$worst_ratio_to_external_best <- num(handoff$worst_ratio_to_external_best)
gap_audit <- handoff[
  handoff$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  ,
  drop = FALSE
]
gap_audit$unresolved <- is.finite(gap_audit$worst_ratio_to_external_best) &
  gap_audit$worst_ratio_to_external_best >= unresolved_threshold
gap_audit$screen_disposition <- ifelse(
  gap_audit$unresolved,
  "target_metricgap_v4",
  "freeze_current_envelope"
)
gap_audit$anchor_source_candidate_id <- vapply(
  seq_len(nrow(gap_audit)),
  function(i) metric_anchor_id(gap_audit[i, , drop = FALSE]),
  character(1L)
)
unresolved <- gap_audit[gap_audit$unresolved, , drop = FALSE]
unresolved <- unresolved[order(num(unresolved$priority)), , drop = FALSE]

if (nrow(gap_audit) != 18L || nrow(unresolved) != 15L) {
  stop(
    sprintf(
      "Expected 18 Q-DESN rows and 15 unresolved rows at threshold %.2f; found %d and %d.",
      unresolved_threshold,
      nrow(gap_audit),
      nrow(unresolved)
    ),
    call. = FALSE
  )
}
if (any(!unresolved$likelihood_target %in% c("al", "exal"))) {
  stop("One or more unresolved rows have an unsupported likelihood target.", call. = FALSE)
}
if (length(unique(gap_audit$source_registry_hash_value)) != 1L) {
  stop("The handoff does not carry one frozen source-registry hash.", call. = FALSE)
}

profile_required <- c(
  "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
  "reservoir_lags", "rhs_tau0", "x_feature_count"
)
missing_profile <- setdiff(profile_required, names(source_profiles))
if (length(missing_profile)) {
  stop(
    sprintf("Source profile table is missing column(s): %s", paste(missing_profile, collapse = ", ")),
    call. = FALSE
  )
}

profile_dimension <- function(D, n_each, n_tilde_each, readout_y_lags, add_bias, x_feature_count) {
  exdqlm:::.qdesn_dynamic_fitforecast_profile_dimension(
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    readout_y_lags = readout_y_lags,
    add_bias = add_bias
  ) + as.integer(x_feature_count)
}

copy_params <- function(row) {
  out <- as.list(row[1L, profile_required, drop = FALSE])
  names(out) <- profile_required
  out$screening_profile_id <- NULL
  out
}
fixed_params <- function(D, n_each, m, alpha, rho, pi_w, pi_in, rhs_tau0,
                         seed, n_tilde_each = if (D <= 1L) 0L else n_each,
                         washout = 300L) {
  list(
    D = as.integer(D),
    n_each = as.integer(n_each),
    n_tilde_each = as.integer(n_tilde_each),
    m = as.integer(m),
    alpha = as.numeric(alpha),
    rho = as.numeric(rho),
    pi_w = as.numeric(pi_w),
    pi_in = as.numeric(pi_in),
    washout = as.integer(washout),
    add_bias = TRUE,
    seed = as.integer(seed),
    readout_y_lags = as.integer(m),
    reservoir_lags = 0L,
    rhs_tau0 = as.numeric(rhs_tau0),
    x_feature_count = 5L
  )
}
profile_row <- function(cell_index, arm_index, target, role, params,
                        source_profile_id, source_reason, source_kind) {
  D <- int(params$D)[1L]
  n_each <- int(params$n_each)[1L]
  n_tilde_each <- int(params$n_tilde_each)[1L]
  readout_y_lags <- int(params$readout_y_lags)[1L]
  add_bias <- as_bool(params$add_bias)[1L]
  x_feature_count <- int(params$x_feature_count)[1L]
  dimension_p <- profile_dimension(
    D, n_each, n_tilde_each, readout_y_lags, add_bias, x_feature_count
  )
  likelihood <- as.character(target$likelihood_target[[1L]])
  arm_token <- c("anchor", "tau1em06", "hmem", "deep", "wide")[[arm_index]]
  profile_id <- sprintf("mgv4_%02d_%s_%s", as.integer(cell_index), likelihood, arm_token)
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = "mcmc_metricgap_v4_targeted_screen",
    screening_wave = "mcmc_metricgap_v4_2026_07_27",
    profile_role = as.character(role),
    enabled = TRUE,
    D = D,
    n_each = n_each,
    n_tilde_each = n_tilde_each,
    m = int(params$m)[1L],
    alpha = num(params$alpha)[1L],
    rho = num(params$rho)[1L],
    pi_w = num(params$pi_w)[1L],
    pi_in = num(params$pi_in)[1L],
    washout = int(params$washout)[1L],
    add_bias = add_bias,
    seed = int(params$seed)[1L],
    readout_y_lags = readout_y_lags,
    reservoir_lags = int(params$reservoir_lags)[1L],
    rhs_tau0 = num(params$rhs_tau0)[1L],
    dimension_p_estimate = int(dimension_p),
    p_over_n_tt500 = num(dimension_p) / 500,
    x_feature_count = x_feature_count,
    target_cells = paste(
      target$family[[1L]],
      tau_label(target$tau[[1L]]),
      likelihood,
      sep = ":"
    ),
    source_screening_profile_id = as.character(source_profile_id),
    candidate_source = as.character(source_kind),
    selection_reason = as.character(source_reason),
    target_family = as.character(target$family[[1L]]),
    target_tau = num(target$tau)[1L],
    likelihood_target = likelihood,
    primary_gap = as.character(target$primary_gap[[1L]]),
    current_worst_ratio = num(target$worst_ratio_to_external_best)[1L],
    fit_ratio_to_external_best = num(target$fit_ratio_to_external_best)[1L],
    forecast_mae_ratio_to_external_best = num(target$forecast_mae_ratio_to_external_best)[1L],
    forecast_check_ratio_to_external_best = num(target$forecast_check_ratio_to_external_best)[1L],
    arm_rank = int(arm_index),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )
}

make_designs <- function(target, anchor_params, cell_index) {
  family <- as.character(target$family[[1L]])
  tau <- num(target$tau)[1L]
  gap <- as.character(target$primary_gap[[1L]])
  shared_seed <- 84000L + cell_index

  anchor <- anchor_params
  anchor$seed <- shared_seed

  tight_anchor <- anchor_params
  tight_anchor$rhs_tau0 <- 1e-6
  tight_anchor$seed <- shared_seed

  tail_cell <- tau <= 0.05
  median_cell <- tau >= 0.5
  mixture_cell <- identical(family, "gausmix")
  laplace_cell <- identical(family, "laplace")

  if (gap == "fit") {
    hmem_m <- if (tail_cell) 80L else 100L
    deep_m <- if (tail_cell) 100L else 120L
    wide_m <- if (tail_cell) 50L else 80L
    hmem <- fixed_params(
      D = 1L,
      n_each = if (mixture_cell) 180L else 160L,
      m = hmem_m,
      alpha = if (tail_cell) 0.0010 else 0.0015,
      rho = if (tail_cell) 0.88 else 0.90,
      pi_w = 0.001,
      pi_in = 0.04,
      rhs_tau0 = 1e-6,
      seed = shared_seed
    )
    deep <- fixed_params(
      D = 3L,
      n_each = if (mixture_cell) 100L else 90L,
      m = deep_m,
      alpha = if (tail_cell) 0.0010 else 0.0020,
      rho = if (tail_cell) 0.90 else 0.92,
      pi_w = 0.001,
      pi_in = 0.04,
      rhs_tau0 = 1e-6,
      seed = shared_seed
    )
    wide <- fixed_params(
      D = 2L,
      n_each = if (mixture_cell) 180L else 150L,
      m = wide_m,
      alpha = if (tail_cell) 0.0020 else 0.0030,
      rho = if (tail_cell) 0.82 else 0.86,
      pi_w = 0.002,
      pi_in = 0.08,
      rhs_tau0 = 3e-6,
      seed = shared_seed
    )
    roles <- c(
      "metric_source_anchor",
      "anchor_with_tau0_1e_minus_6",
      "fit_high_memory_sparse",
      "fit_deep_sparse",
      "fit_wide_tight_shrinkage"
    )
  } else {
    hmem_m <- if (median_cell) 150L else if (tail_cell) 100L else 130L
    deep_m <- if (median_cell) 150L else if (tail_cell) 120L else 140L
    wide_m <- if (median_cell) 120L else if (tail_cell) 80L else 100L
    hmem <- fixed_params(
      D = 1L,
      n_each = if (mixture_cell) 200L else 180L,
      m = hmem_m,
      alpha = if (tail_cell) 0.0015 else if (median_cell) 0.0030 else 0.0020,
      rho = if (tail_cell) 0.90 else if (median_cell) 0.95 else 0.93,
      pi_w = 0.001,
      pi_in = 0.04,
      rhs_tau0 = 1e-6,
      seed = shared_seed
    )
    deep <- fixed_params(
      D = if (laplace_cell) 4L else 3L,
      n_each = if (mixture_cell) 100L else 90L,
      m = deep_m,
      alpha = if (tail_cell) 0.0015 else if (median_cell) 0.0030 else 0.0020,
      rho = if (tail_cell) 0.90 else if (median_cell) 0.95 else 0.93,
      pi_w = 0.001,
      pi_in = 0.04,
      rhs_tau0 = 1e-6,
      seed = shared_seed
    )
    wide <- fixed_params(
      D = 2L,
      n_each = if (mixture_cell) 220L else 180L,
      m = wide_m,
      alpha = if (tail_cell) 0.0020 else if (median_cell) 0.0040 else 0.0030,
      rho = if (tail_cell) 0.86 else if (median_cell) 0.92 else 0.90,
      pi_w = 0.002,
      pi_in = 0.08,
      rhs_tau0 = 3e-6,
      seed = shared_seed
    )
    roles <- c(
      "metric_source_anchor",
      "anchor_with_tau0_1e_minus_6",
      "forecast_high_memory_sparse",
      "forecast_deep_persistent",
      "forecast_wide_tight_shrinkage"
    )
  }

  list(
    designs = list(anchor, tight_anchor, hmem, deep, wide),
    roles = roles
  )
}

profile_rows <- list()
for (cell_index in seq_len(nrow(unresolved))) {
  target <- unresolved[cell_index, , drop = FALSE]
  anchor_id <- as.character(target$anchor_source_candidate_id[[1L]])
  anchor <- source_profiles[
    as.character(source_profiles$screening_profile_id) == anchor_id,
    ,
    drop = FALSE
  ]
  if (nrow(anchor) != 1L) {
    stop(
      sprintf("Could not uniquely resolve anchor profile `%s`.", anchor_id),
      call. = FALSE
    )
  }
  arm_plan <- make_designs(target, copy_params(anchor), cell_index)
  reasons <- c(
    sprintf("Exact current metric-source anchor `%s`, reseeded for this campaign.", anchor_id),
    sprintf("Same structure as `%s` with RHS tau0 tightened to 1e-6.", anchor_id),
    "Breakout high-memory sparse arm with low alpha, high rho, and tau0=1e-6.",
    "Breakout deep persistent arm with tight RHS shrinkage.",
    "Wide two-layer compromise arm with tau0=3e-6."
  )
  kinds <- c(
    "current_metric_envelope_anchor",
    "anchor_tau0_shrinkage_probe",
    "high_memory_sparse_breakout",
    "deep_sparse_breakout",
    "wide_tight_breakout"
  )
  rows <- lapply(seq_along(arm_plan$designs), function(arm_index) {
    profile_row(
      cell_index = cell_index,
      arm_index = arm_index,
      target = target,
      role = arm_plan$roles[[arm_index]],
      params = arm_plan$designs[[arm_index]],
      source_profile_id = anchor_id,
      source_reason = reasons[[arm_index]],
      source_kind = kinds[[arm_index]]
    )
  })
  profile_rows <- c(profile_rows, rows)
}

profiles <- do.call(rbind, profile_rows)
rownames(profiles) <- NULL
if (nrow(profiles) != 75L || anyDuplicated(profiles$screening_profile_id)) {
  stop("Expected 75 unique v4 targeted profile arms.", call. = FALSE)
}
if (any(!is.finite(profiles$p_over_n_tt500)) || any(profiles$p_over_n_tt500 > 1.60)) {
  stop("One or more profiles violate the v4 p/n <= 1.60 exploration gate.", call. = FALSE)
}

assignments <- profiles[, c(
  "target_family", "target_tau", "likelihood_target", "screening_profile_id",
  "source_screening_profile_id", "candidate_source", "selection_reason",
  "primary_gap", "current_worst_ratio", "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
  "arm_rank"
), drop = FALSE]
names(assignments)[names(assignments) == "target_family"] <- "family"
names(assignments)[names(assignments) == "target_tau"] <- "tau"
assignments$assignment_key <- paste(
  assignments$screening_profile_id,
  assignments$family,
  tau_key(assignments$tau),
  sep = "\r"
)
assignments$assignment_id <- sprintf("mcmc_metricgap_v4_%03d", seq_len(nrow(assignments)))
assignments$cell_status <- "unresolved_metricgap_target"
assignments$priority_rank <- match(
  paste(assignments$family, tau_key(assignments$tau), assignments$likelihood_target, sep = "\r"),
  unique(paste(assignments$family, tau_key(assignments$tau), assignments$likelihood_target, sep = "\r"))
)
assignments$target_profile_rank <- assignments$arm_rank
assignments$source_profile <- assignments$source_screening_profile_id
assignments$bottleneck_metric <- assignments$primary_gap
assignments$source_path <- handoff_path
assignments$launch_status <- "prepared_not_launched"
assignments <- assignments[, c(
  "assignment_key", "assignment_id", "family", "tau", "likelihood_target",
  "cell_status", "priority_rank", "target_profile_rank", "screening_profile_id",
  "source_profile", "candidate_source", "selection_reason", "primary_gap",
  "current_worst_ratio", "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
  "bottleneck_metric", "source_path", "launch_status"
), drop = FALSE]

cell_key <- paste(assignments$family, tau_key(assignments$tau), assignments$likelihood_target, sep = "\r")
cell_plan <- do.call(rbind, lapply(split(assignments, cell_key), function(rows) {
  data.frame(
    family = rows$family[[1L]],
    tau = num(rows$tau)[1L],
    likelihood_target = rows$likelihood_target[[1L]],
    primary_gap = rows$primary_gap[[1L]],
    current_worst_ratio = num(rows$current_worst_ratio)[1L],
    n_candidates = nrow(rows),
    cell_status = "unresolved_metricgap_target",
    priority_rank = int(rows$priority_rank)[1L],
    target_profiles = paste(rows$screening_profile_id, collapse = ";"),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )
}))
cell_plan <- cell_plan[order(cell_plan$priority_rank), , drop = FALSE]

profiles_for_plan <- profiles[, setdiff(
  names(profiles),
  c(
    "target_family", "target_tau", "likelihood_target", "primary_gap",
    "current_worst_ratio", "fit_ratio_to_external_best",
    "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
    "arm_rank", "launch_status"
  )
), drop = FALSE]
plan <- list(
  profiles = profiles_for_plan,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    stage_file = stage_file,
    selection_policy = paste(
      "Per-cell MCMC screen of only >10% metric gaps.",
      "No global specification winner and no article promotion from screening-budget runs."
    )
  )
)

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
  stage_desc = paste(
    "Q-DESN 500-observation targeted MCMC metric-gap v4 screen.",
    "Five per-cell arms target each >10% family x tau x likelihood gap."
  ),
  stage = "mcmc_metricgap_v4_targeted_screen",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
families <- sort(unique(as.character(assignments$family)))
taus <- sort(unique(num(assignments$tau)))
selected_dataset_cells <- length(unique(paste(assignments$family, tau_key(assignments$tau), sep = "\r")))
canonical_dataset_cells <- length(families) * length(taus)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$study_contract$id <- paste0(stage_file, "_2026_07_27")
defaults$study_contract$description <- paste(
  "Targeted reduced-budget MCMC screen for Q-DESN/exQ-DESN RHS rows still",
  "more than 10 percent worse than the external DQLM/exDQLM reference on at",
  "least one article metric."
)
defaults$study_contract$budget$posterior_metric_draws <- 100L
defaults$study_contract$budget$vb_sampling_nd_draws <- 100L
defaults$study_contract$budget$vb_synthesis_n_samp <- 100L
defaults$study_contract$budget$mcmc_n_burn <- 2000L
defaults$study_contract$budget$mcmc_n_mcmc <- 8000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$mcmc <- defaults$study_contract$mcmc %||% list()
defaults$study_contract$mcmc$require_init_from_vb <- TRUE
defaults$study_contract$screening_policy <- list(
  unit = "family_tau_likelihood",
  unresolved_threshold = unresolved_threshold,
  candidates_per_cell = 5L,
  comparison_policy = "status_agnostic_metrics_with_status_retained",
  promotion_policy = "screening_selects_candidates_for_full_confirmation_only",
  launch_status = "prepared_not_launched"
)
defaults$study_contract$confirmation_budget <- list(
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L,
  candidates_per_cell = 1L,
  required_before_article_promotion = TRUE
)
defaults$study_contract$exploration_policy <- list(
  reason = "prior compact searches plateaued; v4 tests larger memory/depth/width with stronger RHS shrinkage",
  p_over_n_gate = 1.60,
  rhs_tau0_values = as.list(c(1e-6, 3e-6)),
  alpha_policy = "low_alpha_to_control_high_capacity_variance",
  rho_policy = "high_rho_for_persistent_forecast_gaps"
)
defaults$source_materialization$families <- as.list(families)
defaults$source_materialization$taus <- as.list(taus)
defaults$reference_contract$families <- as.list(families)
defaults$reference_contract$taus <- as.list(taus)
defaults$reference_contract$expected_unique_dataset_cells <- canonical_dataset_cells
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) * canonical_dataset_cells
defaults$reference_contract$expected_selected_qdesn_roots <- nrow(assignments)
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_dataset_cell_count <- canonical_dataset_cells
defaults$screening_profiles$canonical_qdesn_root_count <- nrow(profiles) * canonical_dataset_cells
defaults$screening_profiles$selected_assignment_root_count <- nrow(assignments)
defaults$screening_profiles$design <- paste(
  "Metric-gap v4 targeted: 15 unresolved family/tau/likelihood rows x 5 arms;",
  "anchor, tau0-tightened anchor, high-memory sparse, deep sparse, and wide tight-shrinkage arms."
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pilot$source_family <- as.character(assignments$family[[1L]])
defaults$pilot$tau <- num(assignments$tau)[1L]
defaults$smoke$family <- as.character(assignments$family[[1L]])
defaults$smoke$tau <- num(assignments$tau)[1L]
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$screening_profile_ids <- as.list(assignments$screening_profile_id[[1L]])
defaults$smoke$max_roots <- 1L
defaults$smoke$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
defaults$smoke$pipeline <- list(
  inference = list(
    mcmc = list(
      n_burn = 4L,
      n_mcmc = 4L,
      thin = 1L,
      progress_every = 1L,
      init_from_vb = TRUE
    )
  )
)
defaults$pipeline$inference$mcmc$n_burn <- 2000L
defaults$pipeline$inference$mcmc$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 2000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$keep_mcmc_vb_init <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$save_metric_summaries <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "per_cell_metric_gap",
  prune_nonwinning_heavy_outputs = TRUE
)
yaml::write_yaml(defaults, defaults_out)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_out)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = refresh_materialized,
  verbose = FALSE
)
canonical_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau),
  sep = "\r"
)
assignment_keys <- unique(assignments$assignment_key)
missing_assignment_keys <- setdiff(assignment_keys, canonical_key)
if (length(missing_assignment_keys)) {
  stop(
    sprintf(
      "Canonical grid is missing %d assignment(s), including `%s`.",
      length(missing_assignment_keys),
      missing_assignment_keys[[1L]]
    ),
    call. = FALSE
  )
}
selected_mask <- canonical_key %in% assignment_keys
grid <- canonical_grid[selected_mask, , drop = FALSE]
grid$assignment_key <- canonical_key[selected_mask]
grid <- grid[order(grid$source_family, grid$tau, grid$screening_profile_id), , drop = FALSE]
root_lookup <- grid[, c("assignment_key", "root_id"), drop = FALSE]
grid$assignment_key <- NULL
write_csv(grid, grid_out)

assignments_after <- merge(
  assignments,
  root_lookup,
  by = "assignment_key",
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(assignments_after$root_id)))) {
  stop("Failed to attach canonical root IDs to every assignment.", call. = FALSE)
}
assignments_after <- assignments_after[order(
  assignments_after$priority_rank,
  assignments_after$target_profile_rank
), , drop = FALSE]
write_csv(assignments_after, assignments_out)

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults = defaults_loaded,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
target_map <- assignments_after[, c(
  "assignment_key", "root_id", "family", "tau", "likelihood_target",
  "screening_profile_id", "candidate_source", "selection_reason",
  "primary_gap", "current_worst_ratio", "fit_ratio_to_external_best",
  "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
  "launch_status"
), drop = FALSE]
target_specs <- merge(
  target_map,
  atomic,
  by.x = c("root_id", "likelihood_target"),
  by.y = c("root_id", "likelihood_family"),
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(target_specs$spec_id)))) {
  stop("Failed to resolve one or more MCMC atomic spec IDs.", call. = FALSE)
}
target_specs <- target_specs[order(
  target_specs$family.x,
  target_specs$tau.x,
  target_specs$likelihood_target,
  target_specs$screening_profile_id.x
), , drop = FALSE]
target_specs_out <- write_csv(target_specs, target_specs_out)
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_out)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
gap_audit_path <- write_csv(
  gap_audit,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_gap_audit_", stamp, ".csv"))
)
design_path <- write_csv(
  profiles,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_design_", stamp, ".csv"))
)
cell_plan_path <- write_csv(
  cell_plan,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_cell_plan_", stamp, ".csv"))
)

pattern_audit <- data.frame(
  finding = c(
    "source_handoff_rows",
    "targeted_rows_above_10_percent_gap",
    "frozen_rows",
    "arms_per_targeted_row",
    "target_mcmc_specs",
    "max_p_over_n",
    "tau0_anchor_probe",
    "tau0_breakout_probe",
    "launch_policy"
  ),
  value = c(
    nrow(gap_audit),
    nrow(unresolved),
    sum(!gap_audit$unresolved),
    5L,
    nrow(target_specs),
    sprintf("%.3f", max(profiles$p_over_n_tt500)),
    "1e-6",
    "1e-6;3e-6",
    "prepare, smoke, then detached full screen"
  ),
  interpretation = c(
    "Q-DESN/exQ-DESN RHS rows in the current article-facing envelope handoff.",
    "Rows still more than 10 percent worse than the DQLM/exDQLM external reference.",
    "Rows not relaunched because current metric envelope is within the tolerance band.",
    "Each row receives an anchor, tightened anchor, high-memory, deep, and wide arm.",
    "Reduced-budget MCMC specs prepared for overnight calibration.",
    "High-capacity arms are allowed but bounded for TT500 stability.",
    "Tests whether variance can be controlled without changing structure.",
    "Tests larger memory/depth/width under stronger global shrinkage.",
    "No direct article promotion from this screen; full confirmation remains the gate."
  ),
  stringsAsFactors = FALSE
)
pattern_audit_path <- write_csv(
  pattern_audit,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_pattern_audit_", stamp, ".csv"))
)

source_summary <- data.frame(
  source = c("handoff", "source_profiles", "source_candidates", "base_defaults"),
  rows = c(nrow(handoff), nrow(source_profiles), nrow(source_candidates), NA_integer_),
  path = c(handoff_path, source_profiles_path, source_candidates_path, base_defaults_path),
  stringsAsFactors = FALSE
)
source_summary_path <- write_csv(
  source_summary,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_source_summary_", stamp, ".csv"))
)

readme_lines <- c(
  "# Q-DESN 500-Observation MCMC Metric-Gap v4 Targeted Prelaunch",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- launch_status: `prepared_not_launched`"),
  sprintf("- source registry SHA-256: `%s`", unique(gap_audit$source_registry_hash_value)),
  sprintf("- targeted rows above %.0f%% gap: `%d/18`", 100 * (unresolved_threshold - 1), nrow(unresolved)),
  sprintf("- profiles/specs: `%d`", nrow(target_specs)),
  sprintf("- workers prepared: `%d`", workers),
  "",
  "## Decision",
  "",
  "This is not a global-specification search. The unit of calibration is the",
  "family x quantile x likelihood row because the current envelope shows",
  "different failure modes across cells.",
  "",
  "The v4 slate focuses only on rows still more than 10 percent worse than the",
  "current DQLM/exDQLM reference. Cells already within that tolerance band are",
  "frozen. Since earlier compact searches have plateaued, v4 deliberately",
  "tests larger memory, depth, and width, but couples those larger reservoirs",
  "with low alpha, high rho, sparse input/weight probabilities, and much",
  "stronger RHS global shrinkage.",
  "",
  "## Cell Plan",
  "",
  md_table(
    cell_plan,
    c(
      "priority_rank", "family", "tau", "likelihood_target", "primary_gap",
      "current_worst_ratio", "n_candidates", "launch_status"
    ),
    max_rows = 20L
  ),
  "",
  "## Budgets And Gates",
  "",
  "- Screening: `n_burn = 2000`, `n_mcmc = 8000`, `thin = 1`.",
  "- Full confirmation: one selected candidate per improved cell with `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`.",
  "- MCMC uses VB initialization, but VB is not used as the final ranking criterion.",
  "- Screening results select candidates only; article promotion still requires closeout and confirmation.",
  "- Diagnostic status is retained even when metric selection is status-agnostic.",
  "- Storage stays light: no routine draws, forecast objects, VB-init payloads, or failure RDS files.",
  "",
  "## Prepared Inputs",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- target specs: `%s`", target_specs_out),
  sprintf("- materialization manifest: `%s`", manifest_out),
  sprintf("- gap audit: `%s`", gap_audit_path),
  sprintf("- design: `%s`", design_path),
  sprintf("- cell plan: `%s`", cell_plan_path),
  "",
  "No prepare-only, smoke, or full compute command was executed by this materialization."
)
readme_path <- file.path(out_root, "README.md")
writeLines(readme_lines, readme_path, useBytes = TRUE)
readme_path <- normalizePath(readme_path, winslash = "/", mustWork = TRUE)

file_manifest <- data.frame(
  role = c(
    "handoff", "source_profiles", "source_candidates", "base_defaults",
    "profiles", "assignments", "defaults", "grid", "target_specs",
    "gap_audit", "design", "cell_plan", "pattern_audit",
    "source_summary", "readme"
  ),
  path = c(
    handoff_path, source_profiles_path, source_candidates_path, base_defaults_path,
    profiles_out, assignments_out, defaults_out, grid_out, target_specs_out,
    gap_audit_path, design_path, cell_plan_path, pattern_audit_path,
    source_summary_path, readme_path
  ),
  sha256 = NA_character_,
  stringsAsFactors = FALSE
)
file_manifest$sha256 <- vapply(file_manifest$path, sha256_file, character(1L))
file_manifest_path <- write_csv(file_manifest, file.path(out_root, "file_manifest.csv"))

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = materialization_git_sha,
  git_branch = materialization_git_branch,
  git_dirty = tracked_source_dirty_before_materialization,
  git_dirty_scope = "tracked_source_before_materialization",
  git_dirty_at_manifest_write = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  purpose = "per_cell_qdesn_mcmc_metric_gap_v4_targeted_screen",
  launch_status = "prepared_not_launched",
  selection_policy = "family_tau_likelihood_specific; no global specification winner",
  source_registry_hash = unique(gap_audit$source_registry_hash_value),
  thresholds = list(unresolved_worst_ratio = unresolved_threshold),
  budgets = list(
    screening = list(n_burn = 2000L, n_mcmc = 8000L, thin = 1L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, thin = 1L)
  ),
  counts = list(
    article_rows = nrow(gap_audit),
    selected_dataset_cells = selected_dataset_cells,
    canonical_dataset_cells = canonical_dataset_cells,
    frozen_rows = sum(!gap_audit$unresolved),
    targeted_rows = nrow(unresolved),
    candidates_per_row = 5L,
    profiles = nrow(profiles),
    assignments = nrow(assignments_after),
    selected_grid_roots = nrow(grid),
    target_mcmc_atomic_specs = nrow(target_specs)
  ),
  materialized = materialized,
  outputs = list(
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    target_specs = target_specs_out,
    gap_audit = gap_audit_path,
    design = design_path,
    cell_plan = cell_plan_path,
    pattern_audit = pattern_audit_path,
    source_summary = source_summary_path,
    readme = readme_path,
    file_manifest = file_manifest_path
  ),
  source_files = as.list(file_manifest[1:4, c("role", "path", "sha256")])
)
write_json(manifest, manifest_out)
write_json(
  manifest,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v4_targeted_prelaunch_manifest_", stamp, ".json"))
)

cat(sprintf("stage_file: %s\n", stage_file))
cat("launch_status: prepared_not_launched\n")
cat(sprintf("frozen_rows: %d\n", sum(!gap_audit$unresolved)))
cat(sprintf("targeted_rows: %d\n", nrow(unresolved)))
cat(sprintf("profiles: %d\n", nrow(profiles)))
cat(sprintf("target_specs: %d\n", nrow(target_specs)))
cat(sprintf("manifest: %s\n", manifest_out))
