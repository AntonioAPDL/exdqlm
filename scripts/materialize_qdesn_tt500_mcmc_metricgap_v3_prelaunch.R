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
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
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
md_table <- function(x, cols, max_rows = 50L) {
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
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_metricgap_v3"
))[1L]
stamp <- as.character(get_arg("--stamp", "20260726"))[1L]
workers <- int(get_arg("--workers", "20"))[1L]
if (!is.finite(workers) || workers < 1L) workers <- 20L
workers <- min(workers, 32L)
unresolved_threshold <- num(get_arg("--unresolved-threshold", "1.01"))[1L]
if (!is.finite(unresolved_threshold) || unresolved_threshold < 1) unresolved_threshold <- 1.01
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

handoff_path <- resolve_path(get_arg(
  "--handoff",
  file.path(
    "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726",
    "qdesn_dqlm_500obs_mcmc_metric_envelope_20260726_targeted_screening_handoff.csv"
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
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726",
    "qdesn_tt500_mcmc_percase_rhs_v2_closeout_20260726_all_candidates.csv"
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
    paste0("qdesn_tt500_mcmc_metricgap_v3_prelaunch_", stamp)
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
  "source_registry_hash_value"
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
handoff$unresolved <- is.finite(handoff$worst_ratio_to_external_best) &
  handoff$worst_ratio_to_external_best >= unresolved_threshold
gap_audit <- handoff[
  handoff$model_variant %in% c("qdesn_al_rhs_ns", "qdesn_exal_rhs_ns"),
  ,
  drop = FALSE
]
gap_audit$screen_disposition <- ifelse(
  gap_audit$unresolved,
  "target_metricgap_v3",
  "freeze_current_envelope"
)
gap_audit$anchor_source_candidate_id <- vapply(
  seq_len(nrow(gap_audit)),
  function(i) metric_anchor_id(gap_audit[i, , drop = FALSE]),
  character(1L)
)
unresolved <- gap_audit[gap_audit$unresolved, , drop = FALSE]
unresolved <- unresolved[order(unresolved$priority), , drop = FALSE]

if (nrow(gap_audit) != 18L || nrow(unresolved) != 16L) {
  stop(
    sprintf(
      "Expected 18 Q-DESN cells and 16 unresolved cells; found %d and %d.",
      nrow(gap_audit),
      nrow(unresolved)
    ),
    call. = FALSE
  )
}
if (any(!unresolved$likelihood_target %in% c("al", "exal"))) {
  stop("One or more unresolved cells have an unsupported likelihood target.", call. = FALSE)
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
  profile_id <- sprintf(
    "mgv3_%02d_%s_%s",
    as.integer(cell_index),
    likelihood,
    c("anchor", "local", "compact", "deep", "bridge")[[arm_index]]
  )
  data.frame(
    screening_profile_id = profile_id,
    screening_stage = "mcmc_metricgap_v3_screen",
    screening_wave = "mcmc_metricgap_v3_2026_07_26",
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
    arm_rank = int(arm_index),
    launch_status = "prepared_not_launched",
    stringsAsFactors = FALSE
  )
}

copy_params <- function(row) {
  out <- as.list(row[1L, profile_required, drop = FALSE])
  names(out) <- profile_required
  out
}

fixed_params <- function(D, n_each, m, alpha, rho, pi_w, pi_in, rhs_tau0,
                         seed, n_tilde_each = if (D <= 1L) 0L else n_each) {
  list(
    screening_profile_id = NA_character_,
    D = as.integer(D),
    n_each = as.integer(n_each),
    n_tilde_each = as.integer(n_tilde_each),
    m = as.integer(m),
    alpha = as.numeric(alpha),
    rho = as.numeric(rho),
    pi_w = as.numeric(pi_w),
    pi_in = as.numeric(pi_in),
    washout = 300L,
    add_bias = TRUE,
    seed = as.integer(seed),
    readout_y_lags = as.integer(m),
    reservoir_lags = 0L,
    rhs_tau0 = as.numeric(rhs_tau0),
    x_feature_count = 5L
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

  family <- as.character(target$family[[1L]])
  tau <- num(target$tau)[1L]
  gap <- as.character(target$primary_gap[[1L]])
  shared_seed <- 83000L + cell_index
  anchor_params <- copy_params(anchor)
  anchor_params$screening_profile_id <- NULL

  if (gap == "fit") {
    local_params <- anchor_params
    local_params$rhs_tau0 <- if (num(anchor_params$rhs_tau0) >= 3e-4) 1e-4 else 3e-5
    local_params$seed <- shared_seed

    width <- if (family == "normal") 12L else 16L
    compact_params <- fixed_params(
      D = 1L,
      n_each = width,
      m = if (tau <= 0.05) 2L else 3L,
      alpha = if (tau <= 0.05) 0.0015 else 0.0025,
      rho = if (tau <= 0.05) 0.45 else 0.50,
      pi_w = if (tau <= 0.05) 0.0025 else 0.005,
      pi_in = if (tau <= 0.05) 0.05 else 0.10,
      rhs_tau0 = 1e-4,
      seed = shared_seed
    )
    deep_params <- fixed_params(
      D = 2L,
      n_each = if (family == "normal") 6L else 8L,
      m = if (tau <= 0.05) 3L else 5L,
      alpha = if (tau <= 0.05) 0.0015 else 0.0025,
      rho = if (tau <= 0.05) 0.50 else 0.55,
      pi_w = 0.0025,
      pi_in = 0.05,
      rhs_tau0 = 1e-4,
      seed = shared_seed
    )
    bridge_params <- fixed_params(
      D = 1L,
      n_each = if (family == "gausmix") 24L else 20L,
      m = if (tau <= 0.05) 10L else 15L,
      alpha = if (tau <= 0.05) 0.005 else 0.0075,
      rho = if (tau <= 0.05) 0.60 else 0.70,
      pi_w = 0.01,
      pi_in = 0.15,
      rhs_tau0 = 3e-5,
      seed = shared_seed
    )
    roles <- c(
      "metric_source_anchor",
      "fit_local_stronger_shrinkage",
      "fit_compact_width_boundary",
      "fit_compact_two_layer",
      "fit_bridge_tight_shrinkage"
    )
  } else {
    local_params <- anchor_params
    target_memory <- if (tau <= 0.05) 5L else if (tau <= 0.25) 10L else 15L
    local_params$m <- max(int(anchor_params$m), target_memory)
    local_params$readout_y_lags <- local_params$m
    local_params$alpha <- min(
      0.03,
      max(num(anchor_params$alpha), if (tau <= 0.05) 0.0025 else if (tau <= 0.25) 0.005 else 0.0075)
    )
    local_params$rho <- min(
      0.85,
      max(num(anchor_params$rho), if (tau <= 0.05) 0.55 else if (tau <= 0.25) 0.65 else 0.75)
    )
    local_params$rhs_tau0 <- min(num(anchor_params$rhs_tau0), 1e-4)
    local_params$seed <- shared_seed

    width <- if (family == "gausmix") 16L else if (family == "laplace") 14L else 12L
    compact_params <- fixed_params(
      D = 1L,
      n_each = width,
      m = if (tau <= 0.05) 10L else if (tau <= 0.25) 15L else 20L,
      alpha = if (tau <= 0.05) 0.0035 else if (tau <= 0.25) 0.005 else 0.0075,
      rho = if (tau <= 0.05) 0.60 else if (tau <= 0.25) 0.70 else 0.80,
      pi_w = if (tau <= 0.05) 0.005 else 0.01,
      pi_in = if (tau <= 0.05) 0.10 else 0.15,
      rhs_tau0 = 1e-4,
      seed = shared_seed
    )
    deep_params <- fixed_params(
      D = 2L,
      n_each = if (family == "gausmix") 10L else 8L,
      m = if (tau <= 0.05) 10L else if (tau <= 0.25) 15L else 20L,
      alpha = if (tau <= 0.05) 0.0035 else if (tau <= 0.25) 0.005 else 0.0075,
      rho = if (tau <= 0.05) 0.65 else if (tau <= 0.25) 0.70 else 0.80,
      pi_w = 0.005,
      pi_in = 0.10,
      rhs_tau0 = 3e-5,
      seed = shared_seed
    )
    bridge_params <- fixed_params(
      D = 1L,
      n_each = if (family == "gausmix") 30L else 24L,
      m = if (tau <= 0.05) 15L else if (tau <= 0.25) 20L else 30L,
      alpha = if (tau <= 0.05) 0.0075 else if (tau <= 0.25) 0.01 else 0.015,
      rho = if (tau <= 0.05) 0.70 else if (tau <= 0.25) 0.75 else 0.85,
      pi_w = if (tau <= 0.05) 0.01 else 0.02,
      pi_in = if (tau <= 0.05) 0.15 else 0.25,
      rhs_tau0 = 3e-5,
      seed = shared_seed
    )
    roles <- c(
      "metric_source_anchor",
      "forecast_local_memory",
      "forecast_compact_persistent",
      "forecast_compact_two_layer",
      "forecast_bridge_persistent_tight"
    )
  }

  designs <- list(
    anchor_params,
    local_params,
    compact_params,
    deep_params,
    bridge_params
  )
  reasons <- c(
    sprintf("Exact current metric-source anchor `%s`.", anchor_id),
    sprintf("Case-local perturbation around `%s` for the `%s` gap.", anchor_id, gap),
    sprintf("Compact one-layer boundary informed by prior `%s` winners.", gap),
    sprintf("Small two-layer mechanism contrast for the `%s` gap.", gap),
    sprintf("Moderate-memory bridge with tighter RHS shrinkage for the `%s` gap.", gap)
  )
  kinds <- c(
    "current_metric_envelope_anchor",
    "case_local_perturbation",
    "pattern_informed_compact",
    "pattern_informed_two_layer",
    "pattern_informed_bridge"
  )

  rows <- lapply(seq_along(designs), function(arm_index) {
    profile_row(
      cell_index = cell_index,
      arm_index = arm_index,
      target = target,
      role = roles[[arm_index]],
      params = designs[[arm_index]],
      source_profile_id = anchor_id,
      source_reason = reasons[[arm_index]],
      source_kind = kinds[[arm_index]]
    )
  })
  profile_rows <- c(profile_rows, rows)
}

profiles <- do.call(rbind, profile_rows)
rownames(profiles) <- NULL
if (nrow(profiles) != 80L || anyDuplicated(profiles$screening_profile_id)) {
  stop("Expected 80 unique case-specific profile arms.", call. = FALSE)
}
if (any(!is.finite(profiles$p_over_n_tt500)) || any(profiles$p_over_n_tt500 > 0.50)) {
  stop("One or more profiles violate the p/n <= 0.50 screening gate.", call. = FALSE)
}

assignments <- profiles[, c(
  "target_family", "target_tau", "likelihood_target", "screening_profile_id",
  "source_screening_profile_id", "candidate_source", "selection_reason",
  "primary_gap", "current_worst_ratio", "arm_rank"
), drop = FALSE]
names(assignments)[names(assignments) == "target_family"] <- "family"
names(assignments)[names(assignments) == "target_tau"] <- "tau"
assignments$assignment_key <- paste(
  assignments$screening_profile_id,
  assignments$family,
  tau_key(assignments$tau),
  sep = "\r"
)
assignments$assignment_id <- sprintf("mcmc_metricgap_v3_%03d", seq_len(nrow(assignments)))
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
  "current_worst_ratio", "bottleneck_metric", "source_path", "launch_status"
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
    "current_worst_ratio", "arm_rank", "launch_status"
  )
), drop = FALSE]
plan <- list(
  profiles = profiles_for_plan,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    stage_file = stage_file,
    selection_policy = paste(
      "Per-cell MCMC screening of unresolved metric gaps.",
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
    "Q-DESN 500-observation per-cell MCMC metric-gap v3 screen.",
    "Five pattern-informed arms target each unresolved family x tau x likelihood cell."
  ),
  stage = "mcmc_metricgap_v3_screen",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
families <- sort(unique(as.character(assignments$family)))
taus <- sort(unique(num(assignments$tau)))
selected_dataset_cells <- length(unique(paste(
  assignments$family,
  tau_key(assignments$tau),
  sep = "\r"
)))
canonical_dataset_cells <- length(families) * length(taus)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$study_contract$id <- paste0(stage_file, "_2026_07_26")
defaults$study_contract$description <- paste(
  "Reduced-budget, case-specific MCMC screen for unresolved Q-DESN/exQ-DESN",
  "metric gaps. Screening results select one candidate per cell; they are not",
  "article-facing until full-budget confirmation."
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
  candidates_per_cell = 5L,
  comparison_policy = "status_agnostic_metrics_with_status_retained",
  promotion_policy = "screening_selects_candidates_only",
  launch_status = "prepared_not_launched"
)
defaults$study_contract$confirmation_budget <- list(
  mcmc_n_burn = 5000L,
  mcmc_n_mcmc = 20000L,
  mcmc_thin = 1L,
  candidates_per_cell = 1L,
  required_before_article_promotion = TRUE
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
  "Metric-gap v3: 16 unresolved family/tau/likelihood cells x 5 case-specific",
  "MCMC arms; current anchors plus local, compact, two-layer, and bridge contrasts."
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
  "primary_gap", "current_worst_ratio", "launch_status"
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
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_gap_audit_", stamp, ".csv"))
)
design_path <- write_csv(
  profiles,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_design_", stamp, ".csv"))
)
cell_plan_path <- write_csv(
  cell_plan,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_cell_plan_", stamp, ".csv"))
)

source_grade_counts <- as.data.frame(
  table(signoff_grade = source_candidates$signoff_grade),
  stringsAsFactors = FALSE
)
pattern_candidates <- source_candidates
pattern_candidates$profile_join <- sub(
  "__seed_[0-9]+$",
  "",
  as.character(pattern_candidates$screening_profile_id)
)
pattern_params <- source_profiles[, c(
  "screening_profile_id", "D", "n_each", "m"
), drop = FALSE]
names(pattern_params)[names(pattern_params) == "screening_profile_id"] <- "profile_join"
pattern_candidates <- merge(
  pattern_candidates,
  pattern_params,
  by = "profile_join",
  all.x = TRUE,
  sort = FALSE
)
if (nrow(pattern_candidates) != 90L || any(!is.finite(num(pattern_candidates$D)))) {
  stop("Could not reproduce the 90-row prior-profile pattern audit.", call. = FALSE)
}
pattern_candidates$compact <- int(pattern_candidates$D) == 1L &
  int(pattern_candidates$n_each) <= 12L &
  int(pattern_candidates$m) <= 3L
pattern_cell_key <- paste(
  pattern_candidates$model,
  pattern_candidates$family,
  tau_key(pattern_candidates$tau),
  sep = "\r"
)
metric_winner_compact_count <- function(metric) {
  metric <- as.character(metric)[1L]
  winners <- lapply(split(pattern_candidates, pattern_cell_key), function(rows) {
    values <- num(rows[[metric]])
    rows[order(values), , drop = FALSE][1L, , drop = FALSE]
  })
  winners <- do.call(rbind, winners)
  sum(winners$compact)
}
fit_compact_winners <- metric_winner_compact_count("fit_qtrue_rmse")
forecast_mae_compact_winners <- metric_winner_compact_count("forecast_qtrue_mae_H1000")
forecast_check_compact_winners <- metric_winner_compact_count("forecast_check_loss_H1000")
pattern_audit <- data.frame(
  finding = c(
    "prior_candidate_rows",
    "prior_fit_metric_winners_compact",
    "prior_forecast_mae_winners_compact",
    "prior_forecast_check_winners_compact",
    "resolved_cells_frozen",
    "unresolved_cells_targeted",
    "screening_arms_per_cell",
    "target_mcmc_specs"
  ),
  value = c(
    nrow(pattern_candidates),
    fit_compact_winners,
    forecast_mae_compact_winners,
    forecast_check_compact_winners,
    sum(!gap_audit$unresolved),
    nrow(unresolved),
    nrow(profiles) / nrow(unresolved),
    nrow(target_specs)
  ),
  interpretation = c(
    "Completed per-case v2 candidates used for pattern diagnosis.",
    "Every cell's prior fit-RMSE winner was compact.",
    "Compact profiles won forecast MAE in 14 of 18 cells.",
    "Compact profiles won forecast check loss in 13 of 18 cells.",
    "Both Laplace median likelihood cells beat the external reference on all metrics.",
    "At least one metric remains >= 1.01 times the external reference.",
    "Anchor plus four case-specific structural contrasts.",
    "Reduced-budget MCMC screen; full confirmation is a later gate."
  ),
  stringsAsFactors = FALSE
)
pattern_audit_path <- write_csv(
  pattern_audit,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_pattern_audit_", stamp, ".csv"))
)
source_grade_counts_path <- write_csv(
  source_grade_counts,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_source_grade_counts_", stamp, ".csv"))
)

readme_lines <- c(
  "# Q-DESN 500-Observation MCMC Metric-Gap v3 Prelaunch",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- launch_status: `prepared_not_launched`"),
  sprintf("- source registry SHA-256: `%s`", unique(gap_audit$source_registry_hash_value)),
  sprintf("- unresolved cells: `%d/18`", nrow(unresolved)),
  sprintf("- profiles/specs: `%d`", nrow(target_specs)),
  sprintf("- workers prepared: `%d`", workers),
  "",
  "## Decision",
  "",
  "This is a per-cell screen. It does not seek one global DESN specification.",
  "The two Laplace median cells already dominate the external reference on all",
  "three article metrics and are frozen. Every other family/tau/likelihood cell",
  "receives its own five-arm slate.",
  "",
  "The prior v2 evidence strongly rejects another indiscriminate high-capacity",
  "search: compact one-layer profiles supplied all 18 fit-RMSE winners, 14 of",
  "18 forecast-MAE winners, and 13 of 18 forecast-check winners. The new slate",
  "therefore retains a current metric-source anchor, explores the compact",
  "boundary, tests one small two-layer mechanism, and includes one controlled",
  "moderate-memory bridge with tighter RHS shrinkage.",
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
  "- Full confirmation: one selected candidate per unresolved cell with `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`.",
  "- MCMC uses VB initialization, but VB does not rank or gate the final candidates.",
  "- Screening results cannot be promoted directly to the article.",
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
    "source_grade_counts", "readme"
  ),
  path = c(
    handoff_path, source_profiles_path, source_candidates_path, base_defaults_path,
    profiles_out, assignments_out, defaults_out, grid_out, target_specs_out,
    gap_audit_path, design_path, cell_plan_path, pattern_audit_path,
    source_grade_counts_path, readme_path
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
  purpose = "per_cell_qdesn_mcmc_metric_gap_screen",
  launch_status = "prepared_not_launched",
  selection_policy = "family_tau_likelihood_specific; no global specification winner",
  source_registry_hash = unique(gap_audit$source_registry_hash_value),
  thresholds = list(unresolved_worst_ratio = unresolved_threshold),
  budgets = list(
    screening = list(n_burn = 2000L, n_mcmc = 8000L, thin = 1L),
    confirmation = list(n_burn = 5000L, n_mcmc = 20000L, thin = 1L)
  ),
  counts = list(
    article_cells = nrow(gap_audit),
    selected_dataset_cells = selected_dataset_cells,
    canonical_dataset_cells = canonical_dataset_cells,
    resolved_cells_frozen = sum(!gap_audit$unresolved),
    unresolved_cells = nrow(unresolved),
    candidates_per_cell = 5L,
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
    source_grade_counts = source_grade_counts_path,
    readme = readme_path,
    file_manifest = file_manifest_path
  ),
  source_files = as.list(file_manifest[1:4, c("role", "path", "sha256")])
)
write_json(manifest, manifest_out)
write_json(
  manifest,
  file.path(out_root, paste0("qdesn_tt500_mcmc_metricgap_v3_prelaunch_manifest_", stamp, ".json"))
)

cat(sprintf("stage_file: %s\n", stage_file))
cat("launch_status: prepared_not_launched\n")
cat(sprintf("resolved_cells_frozen: %d\n", sum(!gap_audit$unresolved)))
cat(sprintf("unresolved_cells: %d\n", nrow(unresolved)))
cat(sprintf("profiles: %d\n", nrow(profiles)))
cat(sprintf("target_specs: %d\n", nrow(target_specs)))
cat(sprintf("manifest: %s\n", manifest_out))
