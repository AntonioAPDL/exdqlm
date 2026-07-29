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

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(path))) return(NULL)
  if (!grepl("^(/|~)", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(value, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_lines <- function(value, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(value, path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256_file <- function(path) {
  unname(tools::sha256sum(resolve_path(path)))
}
int_arg <- function(flag, default) {
  value <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(value)) value else as.integer(default)
}
fmt_tau <- function(x) {
  exdqlm:::.qdesn_dynamic_fitforecast_tau_key(as.numeric(x))
}
num_or <- function(x, fallback) {
  value <- suppressWarnings(as.numeric(x)[1L])
  if (is.finite(value)) value else fallback
}
compact_num <- function(x) {
  out <- format(as.numeric(x), scientific = TRUE, digits = 8L, trim = TRUE)
  gsub("[+]", "", gsub("e-0", "em", gsub("e-", "em", gsub("e\\+0?", "e", out))))
}
clean_token <- function(x) {
  x <- tolower(as.character(x)[1L])
  x <- gsub("[.]", "p", x)
  x <- gsub("-", "m", x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x
}
variant_likelihood <- function(model_variant) {
  ifelse(grepl("exal", as.character(model_variant), fixed = TRUE), "exal", "al")
}
metric_col <- function(data, name, fallback = NA_character_) {
  if (name %in% names(data)) as.character(data[[name]]) else rep(fallback, nrow(data))
}
numeric_col <- function(data, name, fallback = NA_real_) {
  if (name %in% names(data)) suppressWarnings(as.numeric(data[[name]])) else rep(fallback, nrow(data))
}
file_manifest <- function(paths) {
  paths <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  data.frame(
    path = paths,
    size_bytes = file.info(paths)$size,
    sha256 = vapply(paths, sha256_file, character(1L)),
    stringsAsFactors = FALSE
  )
}
profile_signature <- function(df, include_target = TRUE) {
  fields <- c(
    "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
    "readout_y_lags", "reservoir_lags", "rhs_tau0"
  )
  missing <- setdiff(fields, names(df))
  if (length(missing)) {
    for (nm in missing) df[[nm]] <- NA
  }
  core <- paste(
    as.integer(df$D),
    as.integer(df$n_each),
    as.integer(df$n_tilde_each),
    as.integer(df$m),
    sprintf("%.8g", as.numeric(df$alpha)),
    sprintf("%.8g", as.numeric(df$rho)),
    sprintf("%.8g", as.numeric(df$pi_w)),
    sprintf("%.8g", as.numeric(df$pi_in)),
    as.integer(df$readout_y_lags),
    as.integer(df$reservoir_lags),
    sprintf("%.8g", as.numeric(df$rhs_tau0)),
    sep = "|"
  )
  if (!isTRUE(include_target)) return(core)
  target <- if ("target_cells" %in% names(df)) as.character(df$target_cells) else rep("", nrow(df))
  paste(target, core, sep = "|")
}
load_prior_profiles <- function() {
  paths <- list.files(
    file.path(repo_root, "config", "validation"),
    pattern = "^qdesn_dynamic_fitforecast_v2_tt500_.*profiles.*[.]csv$",
    full.names = TRUE
  )
  paths <- paths[!grepl("newhypothesis_v1", basename(paths), fixed = TRUE)]
  rows <- lapply(paths, function(path) {
    out <- tryCatch(
      utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(...) data.frame(stringsAsFactors = FALSE)
    )
    if (!nrow(out)) return(out)
    out$profile_source_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
    out
  })
  exdqlm:::.qdesn_validation_bind_rows(rows)
}
with_dimensions <- function(df, x_feature_count = 5L) {
  df$x_feature_count <- as.integer(x_feature_count)
  df$dimension_p_estimate <- as.integer(
    df$D * df$n_each + df$n_tilde_each + df$readout_y_lags +
      df$reservoir_lags + 1L + df$x_feature_count
  )
  df$p_over_n_tt500 <- df$dimension_p_estimate / 500
  df
}

source_hash_expected <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_mcmc_newhypothesis_v1"
promotion_id <- "qdesn_tt500_mcmc_newhypothesis_v1_design_20260729"
parent_closeout_id <- "qdesn_tt500_mcmc_postv4_percell_closeout_20260728"
parent_closeout_root <- file.path("validation", "fitforecast_v2", "promotions", parent_closeout_id)
promotion_root <- file.path("validation", "fitforecast_v2", "promotions", promotion_id)
workers <- int_arg("--workers", 16L)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

base_defaults_path <- resolve_path(
  get_arg(
    "--base-defaults",
    file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_postv4_percell_defaults.yaml")
  )
)
handoff_path <- resolve_path(
  get_arg(
    "--handoff",
    file.path(parent_closeout_root, paste0(parent_closeout_id, "_next_screen_handoff.csv"))
  )
)
parent_summary_path <- resolve_path(file.path(parent_closeout_root, paste0(parent_closeout_id, "_summary.csv")))
unresolved_path <- resolve_path(file.path(parent_closeout_root, paste0(parent_closeout_id, "_unresolved_cells.csv")))
nonrepeat_parent_path <- resolve_path(file.path(parent_closeout_root, paste0(parent_closeout_id, "_nonrepeat_audit.csv")))

defaults_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
profiles_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_profiles.csv")), must_work = FALSE)
assignments_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv")), must_work = FALSE)
grid_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
target_specs_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv")), must_work = FALSE)
manifest_out <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)
doc_out <- resolve_path(
  file.path("validation", "fitforecast_v2", "docs", "QDESN_500OBS_MCMC_NEWHYPOTHESIS_V1_OVERNIGHT_PLAN_2026-07-29.md"),
  must_work = FALSE
)

parent_summary <- read_csv(parent_summary_path)
handoff <- read_csv(handoff_path)
unresolved <- read_csv(unresolved_path)
nonrepeat_parent <- read_csv(nonrepeat_parent_path)

if (nrow(parent_summary) != 1L ||
    !identical(as.character(parent_summary$source_registry_hash_value[[1L]]), source_hash_expected) ||
    as.integer(parent_summary$unresolved_cells[[1L]]) != 15L) {
  stop("Parent post-v4 closeout does not match the frozen 15-cell source contract.", call. = FALSE)
}
if (!nrow(handoff) || nrow(handoff) != 15L ||
    nrow(unique(handoff[c("model_variant", "family", "tau", "fit_size")])) != 15L) {
  stop("New-hypothesis v1 requires exactly 15 unresolved handoff cells.", call. = FALSE)
}
if (any(as.character(handoff$source_registry_hash_value) != source_hash_expected)) {
  stop("Handoff source registry hash drifted.", call. = FALSE)
}
if (any(grepl("/home/jaguir26/local/src", unlist(handoff), fixed = TRUE))) {
  stop("Handoff contains stale /home/jaguir26/local/src paths.", call. = FALSE)
}

handoff$likelihood_target <- variant_likelihood(handoff$model_variant)
handoff$primary_gap <- metric_col(handoff, "primary_remaining_gap_postv4",
  metric_col(handoff, "primary_remaining_gap", "unknown")
)
handoff$worst_ratio <- numeric_col(handoff, "worst_ratio_postv4",
  numeric_col(handoff, "worst_ratio_refreshed", NA_real_)
)
handoff$fit_ratio <- numeric_col(handoff, "fit_ratio_postv4", numeric_col(handoff, "fit_ratio_refreshed", NA_real_))
handoff$forecast_mae_ratio <- numeric_col(
  handoff,
  "forecast_mae_ratio_postv4",
  numeric_col(handoff, "forecast_mae_ratio_refreshed", NA_real_)
)
handoff$forecast_check_ratio <- numeric_col(
  handoff,
  "forecast_check_ratio_postv4",
  numeric_col(handoff, "forecast_check_ratio_refreshed", NA_real_)
)
handoff$priority <- suppressWarnings(as.integer(handoff$priority))
if (any(!is.finite(handoff$priority))) {
  handoff$priority <- rank(-handoff$worst_ratio, ties.method = "first")
}
handoff <- handoff[order(handoff$priority, -handoff$worst_ratio), , drop = FALSE]
handoff$target_cell_id <- sprintf(
  "%s__%s__tau_%s__%s",
  handoff$model_variant,
  handoff$family,
  fmt_tau(handoff$tau),
  handoff$primary_gap
)

arm_template <- function(gap_class, top_cell = FALSE) {
  if (identical(gap_class, "forecast")) {
    arms <- data.frame(
      arm_role = c(
        "forecast_compact_local_tau2em8",
        "forecast_period30_tau7em8",
        "forecast_period30_reservoirlag_tau2em7",
        "forecast_period45_lowalpha_tau7em8",
        "forecast_period60_midcapacity_tau2em8",
        "forecast_period60_deepmemory_tau7em7"
      ),
      D = c(1L, 1L, 1L, 2L, 2L, 3L),
      n_each = c(8L, 12L, 16L, 18L, 24L, 28L),
      n_tilde_each = c(0L, 0L, 0L, 9L, 12L, 14L),
      m = c(3L, 30L, 30L, 45L, 60L, 60L),
      alpha = c(0.0017, 0.0075, 0.0047, 0.0032, 0.0115, 0.0012),
      rho = c(0.52, 0.68, 0.84, 0.91, 0.77, 0.97),
      pi_w = c(0.012, 0.014, 0.018, 0.009, 0.016, 0.006),
      pi_in = c(0.22, 0.18, 0.16, 0.12, 0.20, 0.10),
      readout_y_lags = c(3L, 30L, 30L, 45L, 60L, 60L),
      reservoir_lags = c(0L, 0L, 1L, 1L, 1L, 1L),
      rhs_tau0 = c(2e-8, 7e-8, 2e-7, 7e-8, 2e-8, 7e-7),
      hypothesis = c(
        "overshrunk local-memory fit guard",
        "period-submultiple memory without recurrent feedback",
        "period-submultiple memory with one reservoir lag",
        "low-alpha high-rho intermediate memory",
        "moderate capacity with rolling-origin memory",
        "deeper low-alpha high-rho memory below p/n cap"
      ),
      stringsAsFactors = FALSE
    )
    if (isTRUE(top_cell)) {
      arms <- rbind(
        arms,
        data.frame(
          arm_role = "forecast_period90_seasonal_sentinel_tau7em8",
          D = 1L,
          n_each = 10L,
          n_tilde_each = 0L,
          m = 90L,
          alpha = 0.021,
          rho = 0.63,
          pi_w = 0.011,
          pi_in = 0.18,
          readout_y_lags = 90L,
          reservoir_lags = 1L,
          rhs_tau0 = 7e-8,
          hypothesis = "explicit period-length memory sentinel under strong shrinkage",
          stringsAsFactors = FALSE
        )
      )
    }
    return(arms)
  }

  arms <- data.frame(
    arm_role = c(
      "fit_overshrunk_m1_tau2em8",
      "fit_overshrunk_m3_tau7em8",
      "fit_smallbasis_m15_tau2em7",
      "fit_m15_reservoirlag_tau7em8",
      "fit_m30_midcapacity_tau2em8",
      "fit_m45_deepmemory_tau7em7"
    ),
    D = c(1L, 1L, 1L, 1L, 2L, 3L),
    n_each = c(4L, 8L, 12L, 18L, 18L, 24L),
    n_tilde_each = c(0L, 0L, 0L, 0L, 9L, 12L),
    m = c(1L, 3L, 15L, 15L, 30L, 45L),
    alpha = c(0.0009, 0.0013, 0.0027, 0.0042, 0.0024, 0.0011),
    rho = c(0.37, 0.49, 0.58, 0.73, 0.86, 0.93),
    pi_w = c(0.018, 0.014, 0.017, 0.012, 0.010, 0.007),
    pi_in = c(0.30, 0.24, 0.20, 0.18, 0.14, 0.11),
    readout_y_lags = c(1L, 3L, 15L, 15L, 30L, 45L),
    reservoir_lags = c(0L, 0L, 0L, 1L, 1L, 1L),
    rhs_tau0 = c(2e-8, 7e-8, 2e-7, 7e-8, 2e-8, 7e-7),
    hypothesis = c(
      "nearly linear overshrunk fit rescue",
      "compact nonlinear local-memory fit rescue",
      "small-basis short-memory fit rescue",
      "short-memory reservoir-lag fit rescue",
      "moderate capacity fit rescue below p/n cap",
      "deep low-alpha fit rescue below p/n cap"
    ),
    stringsAsFactors = FALSE
  )
  if (isTRUE(top_cell)) {
    arms <- rbind(
      arms,
      data.frame(
        arm_role = "fit_m60_midcapacity_guard_tau2em7",
        D = 2L,
        n_each = 28L,
        n_tilde_each = 14L,
        m = 60L,
        alpha = 0.0055,
        rho = 0.81,
        pi_w = 0.012,
        pi_in = 0.16,
        readout_y_lags = 60L,
        reservoir_lags = 1L,
        rhs_tau0 = 2e-7,
        hypothesis = "larger-memory fit guard for highest-priority cells",
        stringsAsFactors = FALSE
      )
    )
  }
  arms
}

profile_rows <- list()
assignment_rows <- list()
for (i in seq_len(nrow(handoff))) {
  cell <- handoff[i, , drop = FALSE]
  gap_class <- if (identical(as.character(cell$primary_gap[[1L]]), "fit")) "fit" else "forecast"
  arms <- arm_template(gap_class, top_cell = i <= 6L)
  arms <- with_dimensions(arms)
  if (any(arms$m > 90L | arms$readout_y_lags > 90L)) {
    stop("New-hypothesis v1 cannot exceed the frozen period90/m90 source materialization.", call. = FALSE)
  }
  if (any(arms$p_over_n_tt500 > 0.35)) {
    stop("New-hypothesis v1 p/n cap was exceeded.", call. = FALSE)
  }
  for (j in seq_len(nrow(arms))) {
    arm <- arms[j, , drop = FALSE]
    cell_token <- sprintf(
      "%s_%s_t%s",
      if (identical(as.character(cell$likelihood_target[[1L]]), "exal")) "exal" else "al",
      clean_token(cell$family[[1L]]),
      clean_token(sprintf("%.2f", as.numeric(cell$tau[[1L]])))
    )
    profile_id <- sprintf("nhv1_%03d_%s_%s", length(profile_rows) + 1L, cell_token, clean_token(arm$arm_role[[1L]]))
    target_cells <- sprintf(
      "%s:%s:%s",
      as.character(cell$family[[1L]]),
      fmt_tau(cell$tau[[1L]]),
      as.character(cell$likelihood_target[[1L]])
    )
    profile_rows[[length(profile_rows) + 1L]] <- data.frame(
      screening_profile_id = profile_id,
      screening_stage = "mcmc_newhypothesis_v1",
      screening_wave = "mcmc_newhypothesis_v1_2026_07_29",
      profile_role = as.character(arm$arm_role[[1L]]),
      enabled = TRUE,
      D = as.integer(arm$D[[1L]]),
      n_each = as.integer(arm$n_each[[1L]]),
      n_tilde_each = as.integer(arm$n_tilde_each[[1L]]),
      m = as.integer(arm$m[[1L]]),
      alpha = as.numeric(arm$alpha[[1L]]),
      rho = as.numeric(arm$rho[[1L]]),
      pi_w = as.numeric(arm$pi_w[[1L]]),
      pi_in = as.numeric(arm$pi_in[[1L]]),
      washout = 300L,
      add_bias = TRUE,
      seed = as.integer(61000L + i * 100L + j),
      readout_y_lags = as.integer(arm$readout_y_lags[[1L]]),
      reservoir_lags = as.integer(arm$reservoir_lags[[1L]]),
      rhs_tau0 = as.numeric(arm$rhs_tau0[[1L]]),
      dimension_p_estimate = as.integer(arm$dimension_p_estimate[[1L]]),
      p_over_n_tt500 = as.numeric(arm$p_over_n_tt500[[1L]]),
      x_feature_count = as.integer(arm$x_feature_count[[1L]]),
      target_cells = target_cells,
      source_screening_profile_id = NA_character_,
      candidate_source = "new_hypothesis_v1",
      selection_reason = as.character(arm$hypothesis[[1L]]),
      stringsAsFactors = FALSE
    )
    assignment_key <- paste(
      profile_id,
      as.character(cell$family[[1L]]),
      fmt_tau(as.numeric(cell$tau[[1L]])),
      sep = "\r"
    )
    assignment_rows[[length(assignment_rows) + 1L]] <- data.frame(
      assignment_key = assignment_key,
      assignment_id = sprintf("newhypothesis_v1_%03d", length(assignment_rows) + 1L),
      family = as.character(cell$family[[1L]]),
      tau = as.numeric(cell$tau[[1L]]),
      likelihood_target = as.character(cell$likelihood_target[[1L]]),
      cell_status = ifelse(identical(gap_class, "fit"), "fit_dominated", "forecast_dominated"),
      priority_rank = as.integer(cell$priority[[1L]]),
      target_profile_rank = as.integer(j),
      screening_profile_id = profile_id,
      source_profile = NA_character_,
      candidate_source = "new_hypothesis_v1",
      selection_reason = as.character(arm$hypothesis[[1L]]),
      primary_gap = as.character(cell$primary_gap[[1L]]),
      current_worst_ratio = as.numeric(cell$worst_ratio[[1L]]),
      fit_ratio_to_external_best = as.numeric(cell$fit_ratio[[1L]]),
      forecast_mae_ratio_to_external_best = as.numeric(cell$forecast_mae_ratio[[1L]]),
      forecast_check_ratio_to_external_best = as.numeric(cell$forecast_check_ratio[[1L]]),
      bottleneck_metric = as.character(cell$primary_gap[[1L]]),
      launch_status = "prepared_launchable_after_materialization",
      stringsAsFactors = FALSE
    )
  }
}

profiles <- exdqlm:::.qdesn_validation_bind_rows(profile_rows)
assignments <- exdqlm:::.qdesn_validation_bind_rows(assignment_rows)
if (nrow(profiles) != 96L || nrow(assignments) != 96L) {
  stop(sprintf("Expected exactly 96 new-hypothesis roots; got profiles=%d assignments=%d.", nrow(profiles), nrow(assignments)), call. = FALSE)
}
if (anyDuplicated(profiles$screening_profile_id) || anyDuplicated(assignments$assignment_key)) {
  stop("Generated profile or assignment keys are not unique.", call. = FALSE)
}

prior_profiles <- load_prior_profiles()
prior_sig <- if (nrow(prior_profiles)) unique(profile_signature(prior_profiles, include_target = TRUE)) else character(0)
profiles$profile_signature <- profile_signature(profiles, include_target = TRUE)
profiles$numeric_signature <- profile_signature(profiles, include_target = FALSE)
profiles$duplicate_prior_target_signature <- profiles$profile_signature %in% prior_sig
if (any(profiles$duplicate_prior_target_signature)) {
  duplicated_rows <- profiles[profiles$duplicate_prior_target_signature, c("screening_profile_id", "target_cells", "profile_role"), drop = FALSE]
  stop(sprintf(
    "New-hypothesis v1 generated prior target-specific duplicate profile(s): %s",
    paste(duplicated_rows$screening_profile_id, collapse = ", ")
  ), call. = FALSE)
}
profiles$profile_signature <- NULL
profiles$numeric_signature <- NULL
profiles$duplicate_prior_target_signature <- NULL

cell_plan <- handoff[, c(
  "model_variant", "family", "tau", "fit_size", "likelihood_target", "primary_gap",
  "worst_ratio", "fit_ratio", "forecast_mae_ratio", "forecast_check_ratio",
  "priority", "target_cell_id"
), drop = FALSE]
cell_plan$cell_status <- ifelse(cell_plan$primary_gap == "fit", "fit_dominated", "forecast_dominated")
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(i) {
  ids <- assignments$screening_profile_id[
    assignments$family == cell_plan$family[[i]] &
      abs(as.numeric(assignments$tau) - as.numeric(cell_plan$tau[[i]])) <= 1e-8 &
      assignments$likelihood_target == cell_plan$likelihood_target[[i]]
  ]
  paste(ids, collapse = ",")
}, character(1L))

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = transform(
    cell_plan,
    cell_status = cell_status,
    priority_rank = priority
  ),
  manifest = list(
    generated_at = as.character(Sys.time()),
    stage = stage_file,
    promotion_id = promotion_id,
    parent_closeout_id = parent_closeout_id,
    source_registry_hash_value = source_hash_expected,
    n_cells = nrow(cell_plan),
    n_profiles = nrow(profiles),
    n_assignments = nrow(assignments)
  )
)

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
  stage_stub = stage_file,
  stage_desc = paste(
    "Q-DESN/exQ-DESN TT500 MCMC new-hypothesis v1 screen for the 15 unresolved",
    "post-v4 RHS cells. It avoids replaying v3/v4/post-v4 numeric surfaces and",
    "tests low-p/n memory, lag, shrinkage, and reservoir-lag hypotheses."
  ),
  stage = "mcmc_newhypothesis_v1",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution <- defaults$execution %||% list()
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(c("al", "exal"))
defaults$study_contract <- defaults$study_contract %||% list()
defaults$study_contract$id <- paste0(stage_file, "_2026_07_29")
defaults$study_contract$description <- paste(
  "Q-DESN/exQ-DESN TT500 MCMC new-hypothesis v1 screen. Calibration unit is",
  "model variant x family x quantile. This is a validation-only screen and is",
  "not article-facing until a closeout promotion explicitly accepts metric-wise",
  "or coherent improvements."
)
defaults$study_contract$source_registry_hash_value <- source_hash_expected
defaults$study_contract$budget <- defaults$study_contract$budget %||% list()
defaults$study_contract$budget$posterior_metric_draws <- 100L
defaults$study_contract$budget$vb_sampling_nd_draws <- 100L
defaults$study_contract$budget$vb_synthesis_n_samp <- 100L
defaults$study_contract$budget$mcmc_n_burn <- 2000L
defaults$study_contract$budget$mcmc_n_mcmc <- 8000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$newhypothesis_v1 <- list(
  parent_closeout_id = parent_closeout_id,
  parent_handoff_path = handoff_path,
  source_registry_hash_value = source_hash_expected,
  unresolved_cells = 15L,
  selected_roots = 96L,
  nonrepeat_policy = "no target-specific exact repeats from prior TT500 Q-DESN profile catalogs",
  p_over_n_cap = 0.35,
  max_m_and_readout_y_lags = 90L,
  article_update_policy = "never update article from a raw screening launch"
)
defaults$reference_contract <- defaults$reference_contract %||% list()
defaults$reference_contract$expected_selected_qdesn_roots <- nrow(assignments)
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) *
  as.integer(defaults$screening_profiles$canonical_dataset_cell_count %||% 9L)
defaults$runtime <- defaults$runtime %||% list()
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$screening_profiles$dimension_gate <- list(
  primary_p_over_n_max = 0.35,
  exploratory_p_over_n_max = 0.35
)
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$selected_assignment_root_count <- nrow(assignments)
defaults$screening_profiles$newhypothesis_v1 <- list(
  target_cells = 15L,
  target_roots = nrow(assignments),
  top_priority_cells_with_extra_arm = 6L,
  roots_per_top_priority_cell = 7L,
  roots_per_remaining_cell = 6L
)
defaults$pipeline <- defaults$pipeline %||% list()
defaults$pipeline$inference <- defaults$pipeline$inference %||% list()
defaults$pipeline$inference$mcmc <- defaults$pipeline$inference$mcmc %||% list()
defaults$pipeline$inference$mcmc$n_burn <- 2000L
defaults$pipeline$inference$mcmc$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides <- defaults$pipeline$inference$mcmc$prior_overrides %||% list()
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns <- defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns %||% list()
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 2000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 8000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control <- defaults$pipeline$inference$mcmc$vb_warm_start_control %||% list()
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$pipeline$outputs <- defaults$pipeline$outputs %||% list()
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
defaults$smoke <- defaults$smoke %||% list()
defaults$smoke$family <- as.character(handoff$family[[1L]])
defaults$smoke$tau <- as.numeric(handoff$tau[[1L]])
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$max_roots <- 1L
defaults$smoke$screening_profile_ids <- as.list(as.character(assignments$screening_profile_id[[1L]]))
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

grid <- read_csv(grid_out)
spec_grid <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults,
  methods = "mcmc",
  likelihood_families = c("al", "exal")
)
assignments$target_key <- paste(
  assignments$screening_profile_id,
  assignments$family,
  fmt_tau(assignments$tau),
  assignments$likelihood_target,
  sep = "\r"
)
spec_grid$target_key <- paste(
  spec_grid$screening_profile_id,
  spec_grid$family,
  fmt_tau(spec_grid$tau),
  spec_grid$likelihood_family,
  sep = "\r"
)
assignments$target_order <- seq_len(nrow(assignments))
target_specs <- merge(
  assignments,
  spec_grid,
  by = "target_key",
  all.x = TRUE,
  sort = FALSE
)
target_specs <- target_specs[order(target_specs$target_order), , drop = FALSE]
if (nrow(target_specs) != nrow(assignments) ||
    any(is.na(target_specs$spec_id)) ||
    anyDuplicated(target_specs$spec_id)) {
  stop("Could not materialize a unique MCMC atomic spec for every assignment.", call. = FALSE)
}
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_out)
target_specs_path <- write_csv(target_specs, target_specs_out)

assignment_with_roots <- read_csv(assignments_out)
if (nrow(assignment_with_roots) != nrow(assignments) ||
    any(is.na(assignment_with_roots$root_id)) ||
    any(!nzchar(assignment_with_roots$root_id))) {
  stop("Assignment materialization did not preserve the 96 root IDs.", call. = FALSE)
}

nonrepeat_audit <- data.frame(
  screening_profile_id = profiles$screening_profile_id,
  target_cells = profiles$target_cells,
  profile_role = profiles$profile_role,
  p_over_n_tt500 = profiles$p_over_n_tt500,
  exact_prior_target_duplicate = FALSE,
  nonrepeat_status = "PASS",
  reason = "no target-specific exact repeat detected in prior TT500 Q-DESN profile catalogs",
  stringsAsFactors = FALSE
)
candidate_design <- merge(
  profiles,
  assignments[, c(
    "screening_profile_id", "family", "tau", "likelihood_target", "primary_gap",
    "current_worst_ratio", "fit_ratio_to_external_best",
    "forecast_mae_ratio_to_external_best", "forecast_check_ratio_to_external_best",
    "target_profile_rank"
  ), drop = FALSE],
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE
)
candidate_design <- candidate_design[order(candidate_design$screening_profile_id), , drop = FALSE]
candidate_design$launch_status <- "materialized_launchable_pending_smoke"

summary <- data.frame(
  promotion_id = promotion_id,
  parent_closeout_id = parent_closeout_id,
  stage = stage_file,
  materialization_branch = trimws(system("git branch --show-current", intern = TRUE)),
  materialization_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  source_registry_hash_value = source_hash_expected,
  unresolved_cells = nrow(handoff),
  fit_dominated_cells = sum(handoff$primary_gap == "fit"),
  forecast_dominated_cells = sum(handoff$primary_gap != "fit"),
  candidate_arm_rows = nrow(candidate_design),
  selected_target_specs = nrow(target_specs),
  top_priority_cells_with_extra_arm = 6L,
  max_p_over_n_tt500 = max(profiles$p_over_n_tt500),
  max_m = max(profiles$m),
  max_readout_y_lags = max(profiles$readout_y_lags),
  mcmc_n_burn = as.integer(defaults$study_contract$budget$mcmc_n_burn),
  mcmc_n_mcmc = as.integer(defaults$study_contract$budget$mcmc_n_mcmc),
  workers = workers,
  launch_status = "materialized_launchable_pending_prepare_smoke_full",
  article_update_decision = "do_not_update_article_from_screening_design_or_raw_launch",
  recommendation = "launch_prepare_smoke_then_full_detached; close_out_only_after_all_roots_finish",
  stringsAsFactors = FALSE
)

promotion_paths <- c(
  summary = write_csv(summary, file.path(promotion_root, paste0(promotion_id, "_summary.csv"))),
  handoff = write_csv(handoff, file.path(promotion_root, paste0(promotion_id, "_parent_handoff_snapshot.csv"))),
  unresolved = write_csv(unresolved, file.path(promotion_root, paste0(promotion_id, "_parent_unresolved_snapshot.csv"))),
  candidate_design = write_csv(candidate_design, file.path(promotion_root, paste0(promotion_id, "_candidate_arm_design.csv"))),
  nonrepeat_audit = write_csv(nonrepeat_audit, file.path(promotion_root, paste0(promotion_id, "_nonrepeat_audit.csv")))
)

source_manifest <- data.frame(
  source_role = c(
    "base_defaults",
    "parent_summary",
    "parent_next_screen_handoff",
    "parent_unresolved_cells",
    "parent_nonrepeat_audit"
  ),
  path = normalizePath(
    c(base_defaults_path, parent_summary_path, handoff_path, unresolved_path, nonrepeat_parent_path),
    winslash = "/",
    mustWork = TRUE
  ),
  stringsAsFactors = FALSE
)
source_manifest$sha256 <- vapply(source_manifest$path, sha256_file, character(1L))
source_manifest_path <- write_csv(source_manifest, file.path(promotion_root, "source_manifest.csv"))

doc_lines <- c(
  "# Q-DESN 500-Observation MCMC New-Hypothesis v1 Overnight Screen",
  "",
  sprintf("- Stage: `%s`", stage_file),
  sprintf("- Promotion/design id: `%s`", promotion_id),
  sprintf("- Parent closeout: `%s`", parent_closeout_id),
  sprintf("- Source registry SHA-256: `%s`", source_hash_expected),
  sprintf("- Roots: `%d` MCMC target specs across `%d` unresolved cells", nrow(target_specs), nrow(handoff)),
  sprintf("- Workers: `%d`, one R worker per root", workers),
  "- MCMC budget: `n_burn = 2000`, `n_mcmc = 8000`, `thin = 1`",
  "- Smoke budget: `n_burn = 4`, `n_mcmc = 4` for a single selected root",
  "- Launch policy: prepare-only, smoke, then explicit full detached launch",
  "- Article policy: no article/table update from raw screening output; promote only after closeout.",
  "",
  "## Why This Is Different",
  "",
  "The post-v4 screen was valid but did not materially resolve 15 cells. This",
  "screen intentionally does not replay the v3/v4/post-v4 high-capacity surface.",
  "It tests lower p/n specifications, stronger RHS shrinkage, period-aware",
  "memory at lags 30, 45, 60, and 90, and one-lag reservoir feedback for",
  "rolling-origin stability.",
  "",
  "## Target Cells",
  "",
  paste(
    sprintf(
      "- `%s`, family `%s`, tau `%s`, primary gap `%s`, worst ratio `%.3f`",
      handoff$model_variant,
      handoff$family,
      fmt_tau(handoff$tau),
      handoff$primary_gap,
      handoff$worst_ratio
    ),
    collapse = "\n"
  ),
  "",
  "## Design Rules",
  "",
  "- Calibration is per model variant, family, and quantile; there is no global winner requirement.",
  "- Every generated profile is assigned to exactly one target cell and one likelihood.",
  "- `m` and `readout_y_lags` are capped at 90 to match the frozen period90/m90 source materialization.",
  "- `p_over_n_tt500` is capped at 0.35 for this overnight screen.",
  "- The non-repeat audit rejects exact target-specific repeats from prior TT500 Q-DESN profile catalogs.",
  "",
  "## Generated Files",
  "",
  sprintf("- Defaults: `%s`", sub(paste0("^", repo_root, "/?"), "", defaults_out)),
  sprintf("- Profiles: `%s`", sub(paste0("^", repo_root, "/?"), "", profiles_out)),
  sprintf("- Cell assignments: `%s`", sub(paste0("^", repo_root, "/?"), "", assignments_out)),
  sprintf("- Grid: `%s`", sub(paste0("^", repo_root, "/?"), "", grid_out)),
  sprintf("- Target spec ids: `%s`", sub(paste0("^", repo_root, "/?"), "", target_specs_out)),
  sprintf("- Manifest: `%s`", sub(paste0("^", repo_root, "/?"), "", manifest_out)),
  sprintf("- Promotion root: `%s`", sub(paste0("^", repo_root, "/?"), "", resolve_path(promotion_root, must_work = FALSE))),
  "",
  "## Next Command",
  "",
  "Use the orchestrator; it materializes, prepares, smokes, and launches full only with explicit approval:",
  "",
  "```bash",
  "Rscript scripts/orchestrate_qdesn_tt500_mcmc_newhypothesis_v1.R --full --launch-approved --workers 16",
  "```"
)
doc_path <- write_lines(doc_lines, doc_out)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_commit = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage = stage_file,
  promotion_id = promotion_id,
  parent_closeout_id = parent_closeout_id,
  source_registry_hash_value = source_hash_expected,
  counts = list(
    unresolved_cells = nrow(handoff),
    profiles = nrow(profiles),
    assignments = nrow(assignments),
    selected_grid_rows = nrow(grid),
    target_specs = nrow(target_specs),
    fit_dominated_cells = sum(handoff$primary_gap == "fit"),
    forecast_dominated_cells = sum(handoff$primary_gap != "fit")
  ),
  constraints = list(
    max_p_over_n_tt500 = max(profiles$p_over_n_tt500),
    p_over_n_cap = 0.35,
    max_m = max(profiles$m),
    max_readout_y_lags = max(profiles$readout_y_lags),
    nonrepeat_policy = "no target-specific exact repeats from prior TT500 Q-DESN profile catalogs"
  ),
  generated_paths = list(
    defaults = defaults_out,
    profiles = profiles_out,
    assignments = assignments_out,
    grid = grid_out,
    target_specs = target_specs_path,
    doc = doc_path,
    promotion_paths = as.list(promotion_paths),
    source_manifest = source_manifest_path
  ),
  materialized = mat,
  launch_status = "materialized_launchable_pending_prepare_smoke_full",
  article_update_decision = "do_not_update_article_from_screening_design_or_raw_launch"
)
manifest_path <- write_json(manifest, manifest_out)

file_manifest_path <- write_csv(
  file_manifest(c(
    defaults_out,
    profiles_out,
    assignments_out,
    grid_out,
    target_specs_out,
    manifest_out,
    doc_path,
    unname(promotion_paths),
    source_manifest_path
  )),
  file.path(promotion_root, "file_manifest.csv")
)

heavy <- list.files(
  c(dirname(defaults_out), resolve_path(promotion_root, must_work = TRUE)),
  pattern = "[.](rds|rda|RData)$|__design[.]rds$",
  recursive = TRUE,
  full.names = TRUE
)
heavy <- heavy[grepl("newhypothesis_v1|qdesn_tt500_mcmc_newhypothesis_v1", heavy)]
if (length(heavy)) {
  stop(sprintf("Unexpected heavy materialization artifacts: %s", paste(heavy, collapse = ", ")), call. = FALSE)
}

cat(sprintf("stage: %s\n", stage_file))
cat(sprintf("promotion_id: %s\n", promotion_id))
cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("target_specs: %s\n", target_specs_out))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("doc: %s\n", doc_path))
cat(sprintf("promotion_root: %s\n", normalizePath(promotion_root, winslash = "/", mustWork = TRUE)))
cat(sprintf("selected_target_specs: %d\n", nrow(target_specs)))
cat(sprintf("max_p_over_n_tt500: %.3f\n", max(profiles$p_over_n_tt500)))
