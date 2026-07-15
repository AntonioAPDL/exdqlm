#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

git_sha_at_start <- trimws(system("git rev-parse HEAD", intern = TRUE))
git_branch_at_start <- trimws(system("git branch --show-current", intern = TRUE))
git_dirty_at_start <- length(system("git status --porcelain", intern = TRUE)) > 0L

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

rel_path <- function(path) sub(paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?"), "", resolve_path(path, must_work = FALSE))

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

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
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

base_defaults <- get_arg("--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml")
stage_prefix <- get_arg("--stage-prefix", "qvbm3_capacity")
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

audit_manifest <- get_arg(
  "--audit-manifest",
  "reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/manifest/qvbm3_capacity_prelaunch_audit_manifest.json"
)
cell_blockers_path <- get_arg(
  "--cell-blockers",
  "reports/qvbm3_capacity/audit/qvbm3_capacity_prelaunch_20260715/tables/qvbm3_current_cell_blockers.csv"
)

if (!file.exists(resolve_path(audit_manifest, must_work = FALSE))) {
  stop("Run scripts/audit_qdesn_tt500_vb_qvbm3_capacity_expansion.R before materializing qvbm3.", call. = FALSE)
}
if (!file.exists(resolve_path(cell_blockers_path, must_work = FALSE))) {
  stop("Missing qvbm3 cell blockers table.", call. = FALSE)
}

cell_blockers <- utils::read.csv(resolve_path(cell_blockers_path), stringsAsFactors = FALSE, check.names = FALSE)
required_cells <- c("family", "tau", "likelihood_target", "qvbm1_bundle", "qvbm1_profile", "external_joint_worst_ratio", "failed_external_metrics", "cell_class")
if (!all(required_cells %in% names(cell_blockers))) {
  stop(sprintf("Cell blockers table is missing: %s", paste(setdiff(required_cells, names(cell_blockers)), collapse = ", ")), call. = FALSE)
}

cell_blockers <- cell_blockers[order(-num(cell_blockers$external_joint_worst_ratio), cell_blockers$family, num(cell_blockers$tau), cell_blockers$likelihood_target), , drop = FALSE]
cell_blockers$priority_rank <- seq_len(nrow(cell_blockers))
cell_blockers$stress_rank <- rank(-num(cell_blockers$external_joint_worst_ratio), ties.method = "first")
cell_blockers$allow_global_extreme <- cell_blockers$stress_rank <= 2L

capacity_templates <- data.frame(
  profile_role = c(
    "green_deep_balanced",
    "green_deep_long",
    "amber_deep_long",
    "amber_wide_balanced",
    "amber_four_layer",
    "amber_four_layer_long",
    "red_edge_sparse",
    "red_four_layer_sparse",
    "red_extreme_single"
  ),
  D = c(3L, 3L, 3L, 3L, 4L, 4L, 3L, 4L, 4L),
  n_each = c(100L, 100L, 100L, 150L, 100L, 100L, 200L, 200L, 300L),
  n_tilde_each = c(50L, 50L, 50L, 75L, 50L, 50L, 100L, 100L, 150L),
  m = c(60L, 90L, 150L, 60L, 90L, 150L, 150L, 90L, 150L),
  readout_y_lags = c(60L, 90L, 150L, 60L, 90L, 150L, 150L, 90L, 150L),
  reservoir_lags = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 1L),
  alpha_base = c(0.005, 0.0025, 0.001, 0.005, 0.0025, 0.001, 0.001, 0.001, 0.0005),
  rho_base = c(0.65, 0.80, 0.90, 0.65, 0.80, 0.90, 0.90, 0.97, 0.97),
  pi_w = c(0.0025, 0.001, 0.0005, 0.001, 0.001, 0.0005, 0.0005, 0.0005, 0.0005),
  pi_in = c(0.10, 0.05, 0.03, 0.05, 0.05, 0.03, 0.03, 0.03, 0.03),
  rhs_tau0 = c(3e-4, 3e-4, 1e-4, 3e-4, 3e-4, 1e-4, 1e-4, 1e-4, 1e-4),
  template_policy = c(
    "broad_canary_all_target_cells",
    "broad_canary_all_target_cells",
    "broad_canary_all_target_cells",
    "broad_canary_all_target_cells",
    "broad_canary_all_target_cells",
    "targeted_hard_cells_only",
    "targeted_hard_cells_only",
    "targeted_hard_cells_only",
    "global_stress_canary_only"
  ),
  stringsAsFactors = FALSE
)
capacity_templates$dimension_p_estimate <- 1L + capacity_templates$D * capacity_templates$n_each + capacity_templates$readout_y_lags + 5L
capacity_templates$p_over_n_tt500 <- capacity_templates$dimension_p_estimate / 500
capacity_templates$capacity_tier <- ifelse(capacity_templates$p_over_n_tt500 <= 0.75, "green",
  ifelse(capacity_templates$p_over_n_tt500 <= 1.50, "amber", "red"))

template_allowed_for_cell <- function(tmpl, cell) {
  policy <- as.character(tmpl$template_policy[[1L]])
  cls <- as.character(cell$cell_class[[1L]])
  if (identical(policy, "broad_canary_all_target_cells")) return(TRUE)
  if (identical(policy, "targeted_hard_cells_only")) return(cls %in% c("hard", "near_hard"))
  if (identical(policy, "global_stress_canary_only")) return(isTRUE(cell$allow_global_extreme[[1L]]))
  FALSE
}

bundle_cfg <- function(bundle_code) {
  harmonics <- if (identical(bundle_code, "c123")) c(1L, 2L, 3L) else c(1L, 2L)
  list(
    bundle_id = if (identical(bundle_code, "c123")) "decomp_component_p90_h123" else "decomp_component_p90_h12",
    bundle_code = bundle_code,
    readout_input_mode = "dlm_decomp_lags",
    deterministic_harmonics = harmonics,
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      components = as.list(c("trend", "seasonal", "residual")),
      input_builder = "component_lags",
      trend = list(degree = 1L),
      seasonal = list(period = 90L, harmonics = as.list(harmonics), auto = list(enabled = FALSE)),
      regression = list(enabled = FALSE),
      transfer = list(enabled = FALSE),
      input_lags_mode = "component",
      input_lags = list(
        trend = as.list(1:2),
        seasonal = as.list(1:3),
        residual = as.list(1:2)
      ),
      discount = list(trend = 0.99, seasonal = 0.99),
      variance = list(mode = "unknown_constant", l0 = 1, S0 = 1),
      forecast = list(residual_recursion = "sampled_path"),
      sim_xreg = list(policy = "repeat_last")
    )
  )
}

make_profile_rows <- function(bundle_code) {
  cells <- cell_blockers[as.character(cell_blockers$qvbm1_bundle) == bundle_code, , drop = FALSE]
  rows <- list()
  for (ci in seq_len(nrow(cells))) {
    cell <- cells[ci, , drop = FALSE]
    local_i <- 0L
    for (ti in seq_len(nrow(capacity_templates))) {
      tmpl <- capacity_templates[ti, , drop = FALSE]
      if (!template_allowed_for_cell(tmpl, cell)) next
      local_i <- local_i + 1L
      family <- as.character(cell$family[[1L]])
      tau <- num(cell$tau[[1L]])
      likelihood <- as.character(cell$likelihood_target[[1L]])
      tau_lbl <- gsub("\\.", "p", sprintf("%.2f", tau))
      seed <- 83000L + 100L * as.integer(cell$priority_rank[[1L]]) + local_i
      role <- as.character(tmpl$profile_role[[1L]])
      alpha <- tmpl$alpha_base[[1L]]
      rho <- tmpl$rho_base[[1L]]
      if (grepl("forecast", as.character(cell$failed_external_metrics[[1L]]))) {
        rho <- min(0.99, rho + 0.03)
        alpha <- max(0.0005, alpha / 2)
      }
      if (grepl("fit_rmse", as.character(cell$failed_external_metrics[[1L]]))) {
        alpha <- min(0.05, alpha * 1.5)
      }
      sid <- sprintf(
        "m3%s_c%02d_p%02d_%s_d%d_n%d_m%d_a%s_r%s",
        bundle_code, as.integer(cell$priority_rank[[1L]]), local_i,
        if (identical(likelihood, "exal")) "x" else "a",
        as.integer(tmpl$D), as.integer(tmpl$n_each), as.integer(tmpl$m),
        slug_num(alpha), slug_num(rho)
      )
      rows[[length(rows) + 1L]] <- data.frame(
        screening_profile_id = sid,
        screening_stage = paste0("vb_qvbm3_capacity_expansion_", bundle_code),
        screening_wave = "qvbm3_capacity_expansion_2026_07_15",
        profile_role = role,
        enabled = TRUE,
        D = as.integer(tmpl$D),
        n_each = as.integer(tmpl$n_each),
        n_tilde_each = as.integer(tmpl$n_tilde_each),
        m = as.integer(tmpl$m),
        alpha = as.numeric(alpha),
        rho = as.numeric(rho),
        pi_w = as.numeric(tmpl$pi_w),
        pi_in = as.numeric(tmpl$pi_in),
        washout = 300L,
        add_bias = TRUE,
        seed = as.integer(seed),
        readout_y_lags = as.integer(tmpl$readout_y_lags),
        reservoir_lags = as.integer(tmpl$reservoir_lags),
        rhs_tau0 = as.numeric(tmpl$rhs_tau0),
        dimension_p_estimate = as.integer(tmpl$dimension_p_estimate),
        p_over_n_tt500 = as.numeric(tmpl$p_over_n_tt500),
        x_feature_count = as.integer(tmpl$D * tmpl$n_each),
        capacity_tier = as.character(tmpl$capacity_tier),
        capacity_policy = as.character(tmpl$template_policy),
        target_family = family,
        target_tau = tau,
        likelihood_target = likelihood,
        design_bundle = bundle_cfg(bundle_code)$bundle_id,
        design_bundle_code = bundle_code,
        design_axis = "qvbm3_capacity_depth_width_lag_expansion",
        cell_target_role = as.character(cell$cell_class[[1L]]),
        blocker_target = as.character(cell$failed_external_metrics[[1L]]),
        source_baseline_screen = "qvbm1_decomp_guardfix_20260713_main__git-8c6eda9",
        source_frontier_row = paste(family, sprintf("%.2f", tau), likelihood, as.character(cell$qvbm1_profile[[1L]]), sep = "|"),
        qvbm1_winner_bundle = bundle_code,
        qvbm1_winner_profile = as.character(cell$qvbm1_profile[[1L]]),
        external_joint_worst_ratio = as.numeric(cell$external_joint_worst_ratio[[1L]]),
        qvbm1_joint_worst_ratio = as.numeric(cell$qvbm1_joint_worst_ratio[[1L]]),
        launch_gate = "dry_materialization_only_no_compute_launch",
        article_facing = FALSE,
        stringsAsFactors = FALSE
      )
    }
  }
  bind_rows(rows)
}

make_assignments <- function(profiles) {
  data.frame(
    assignment_key = paste(profiles$screening_profile_id, profiles$target_family, tau_key(profiles$target_tau), sep = "\r"),
    family = profiles$target_family,
    tau = profiles$target_tau,
    likelihood_target = profiles$likelihood_target,
    cell_status = profiles$cell_target_role,
    priority_rank = match(
      paste(profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, sep = "\r"),
      paste(cell_blockers$family, tau_key(cell_blockers$tau), cell_blockers$likelihood_target, sep = "\r")
    ),
    target_profile_rank = ave(seq_len(nrow(profiles)), profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, FUN = seq_along),
    screening_profile_id = profiles$screening_profile_id,
    design_bundle = profiles$design_bundle,
    design_bundle_code = profiles$design_bundle_code,
    design_axis = profiles$design_axis,
    capacity_tier = profiles$capacity_tier,
    capacity_policy = profiles$capacity_policy,
    blocker_target = profiles$blocker_target,
    source_frontier_row = profiles$source_frontier_row,
    external_joint_worst_ratio = profiles$external_joint_worst_ratio,
    stringsAsFactors = FALSE
  )
}

target_specs_for <- function(grid, assignments, defaults) {
  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    grid,
    defaults = defaults,
    methods = defaults$execution$methods %||% "vb",
    likelihood_families = defaults$execution$likelihood_families %||% c("al", "exal")
  )
  key_grid <- paste(as.character(grid$screening_profile_id), as.character(grid$source_family), tau_key(grid$tau), sep = "\r")
  key_assign <- paste(as.character(assignments$screening_profile_id), as.character(assignments$family), tau_key(assignments$tau), sep = "\r")
  target_lik <- setNames(as.character(assignments$likelihood_target), key_assign)
  wanted <- data.frame(
    root_id = as.character(grid$root_id),
    screening_profile_id = as.character(grid$screening_profile_id),
    family = as.character(grid$source_family),
    tau = num(grid$tau),
    likelihood_target = unname(target_lik[key_grid]),
    stringsAsFactors = FALSE
  )
  wanted <- wanted[nzchar(as.character(wanted$likelihood_target)), , drop = FALSE]
  merged <- merge(
    wanted,
    atomic,
    by.x = c("root_id", "likelihood_target"),
    by.y = c("root_id", "likelihood_family"),
    all.x = TRUE,
    sort = FALSE
  )
  if (any(!nzchar(as.character(merged$spec_id)))) {
    stop("Failed to resolve one or more qvbm3 target atomic spec IDs.", call. = FALSE)
  }
  out <- data.frame(
    root_id = as.character(merged$root_id),
    likelihood_target = as.character(merged$likelihood_target),
    screening_profile_id = as.character(merged$screening_profile_id.x %||% merged$screening_profile_id),
    family = as.character(merged$family.x %||% merged$family),
    tau = num(merged$tau.x %||% merged$tau),
    spec_id = as.character(merged$spec_id),
    method = as.character(merged$method %||% "vb"),
    prior = as.character(merged$prior %||% "rhs_ns"),
    stringsAsFactors = FALSE
  )
  out[order(out$family, out$tau, out$likelihood_target, out$screening_profile_id), , drop = FALSE]
}

materialize_bundle <- function(bundle_code, bundle_order) {
  cfg <- bundle_cfg(bundle_code)
  profiles <- make_profile_rows(bundle_code)
  if (!nrow(profiles)) return(NULL)
  assignments <- make_assignments(profiles)
  stage_stub <- paste(stage_prefix, bundle_code, sep = "_")
  paths <- list(
    profiles = file.path("config", "validation", paste0(stage_stub, "_profiles.csv")),
    assignments = file.path("config", "validation", paste0(stage_stub, "_cell_assignments.csv")),
    defaults = file.path("config", "validation", paste0(stage_stub, "_defaults.yaml")),
    grid = file.path("config", "validation", paste0(stage_stub, "_grid.csv")),
    target_specs = file.path("config", "validation", paste0(stage_stub, "_target_spec_ids.csv")),
    manifest = file.path("config", "validation", paste0(stage_stub, "_materialization_manifest.json"))
  )
  plan <- list(
    profiles = profiles,
    assignments = assignments,
    cell_plan = unique(data.frame(
      family = profiles$target_family,
      tau = profiles$target_tau,
      likelihood_target = profiles$likelihood_target,
      cell_status = profiles$cell_target_role,
      stringsAsFactors = FALSE
    ))
  )
  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    stage = "qvbm3_capacity_expansion",
    stage_stub = stage_stub,
    stage_desc = sprintf("Q-DESN VB qvbm3 capacity expansion canary bundle `%s`.", bundle_code),
    base_defaults_path = resolve_path(base_defaults),
    profiles_out = resolve_path(paths$profiles, must_work = FALSE),
    assignments_out = resolve_path(paths$assignments, must_work = FALSE),
    defaults_out = resolve_path(paths$defaults, must_work = FALSE),
    grid_out = resolve_path(paths$grid, must_work = FALSE),
    refresh_grid = refresh_grid,
    refresh_materialized = refresh_materialized,
    priors = "rhs_ns",
    workers = workers
  )
  defaults <- yaml::read_yaml(resolve_path(paths$defaults))
  defaults$campaign$name <- stage_stub
  defaults$campaign$results_root <- file.path("results", stage_prefix, bundle_code)
  defaults$campaign$reports_root <- file.path("reports", stage_prefix, bundle_code)
  defaults$execution$methods <- "vb"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$study_contract$core_lane <- TRUE
  defaults$study_contract$id <- paste0(stage_stub, "_2026_07_15")
  defaults$study_contract$description <- paste(
    "Q-DESN qvbm3 capacity expansion canary.",
    "VB-only; not article-facing; MCMC handoff closed until strict closeout."
  )
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$pipeline <- defaults$pipeline %||% list()
  defaults$pipeline$readout <- defaults$pipeline$readout %||% list()
  defaults$pipeline$readout$input_mode <- cfg$readout_input_mode
  defaults$pipeline$decomposition <- cfg$decomposition
  defaults$pipeline$validation_guardrails <- defaults$pipeline$validation_guardrails %||% list()
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags <- TRUE
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags_reason <- "qvbm3 keeps each cell's qvbm1 winning DLM-decomposition bundle while testing larger DESN capacity"
  defaults$pipeline$outputs <- utils::modifyList(
    defaults$pipeline$outputs %||% list(),
    list(save_forecast_objects = FALSE, keep_draws = FALSE, save_fit_objects = FALSE)
  )
  defaults$deterministic_features <- defaults$deterministic_features %||% list()
  defaults$deterministic_features$enabled <- TRUE
  defaults$deterministic_features$period <- 90L
  defaults$deterministic_features$harmonics <- as.list(as.integer(cfg$deterministic_harmonics))
  defaults$deterministic_features$include_trend <- TRUE
  defaults$deterministic_features$prefix <- "period90"
  defaults$screening_profiles$qvbm3_capacity_expansion_design <- list(
    bundle_id = cfg$bundle_id,
    bundle_code = bundle_code,
    target_cells = length(unique(paste(profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target))),
    profiles = nrow(profiles),
    predecessor_screen = "qvbm1_decomp_guardfix_20260713_main__git-8c6eda9",
    diagnostic_screens = as.list(c("qvbm2", "qvbm2p3")),
    design_axis = "capacity_depth_width_lag",
    max_D = max(int(profiles$D)),
    max_n_each = max(int(profiles$n_each)),
    max_m = max(int(profiles$m)),
    red_tier_rows = sum(as.character(profiles$capacity_tier) == "red"),
    launch_policy = "dry_materialization_only; explicit user approval required before VB canary launch",
    promotion_policy = "do not promote to MCMC unless a strict current-protocol VB audit clears fit RMSE, fit check loss, forecast MAE, and forecast check loss gates"
  )
  yaml::write_yaml(defaults, resolve_path(paths$defaults, must_work = FALSE))

  grid <- utils::read.csv(resolve_path(paths$grid), stringsAsFactors = FALSE, check.names = FALSE)
  assignments2 <- utils::read.csv(resolve_path(paths$assignments), stringsAsFactors = FALSE, check.names = FALSE)
  defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(resolve_path(paths$defaults))
  target_specs <- target_specs_for(grid, assignments2, defaults_loaded)
  write_csv(target_specs, paths$target_specs)
  defaults_loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(defaults_loaded, resolve_path(paths$defaults, must_work = FALSE))

  manifest <- list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = git_sha_at_start,
    git_branch = git_branch_at_start,
    git_dirty = git_dirty_at_start,
    stage_stub = stage_stub,
    stage_prefix = stage_prefix,
    bundle_code = bundle_code,
    bundle_id = cfg$bundle_id,
    bundle_order = as.integer(bundle_order),
    base_defaults = resolve_path(base_defaults),
    audit_manifest = resolve_path(audit_manifest),
    paths = lapply(paths, resolve_path, must_work = FALSE),
    hashes = list(
      profiles_sha256 = sha256_file(paths$profiles),
      assignments_sha256 = sha256_file(paths$assignments),
      defaults_sha256 = sha256_file(paths$defaults),
      grid_sha256 = sha256_file(paths$grid),
      target_specs_sha256 = sha256_file(paths$target_specs)
    ),
    counts = list(
      n_profiles = nrow(profiles),
      n_assignments = nrow(assignments2),
      n_grid_rows = nrow(grid),
      n_target_specs = nrow(target_specs),
      n_red_tier_profiles = sum(as.character(profiles$capacity_tier) == "red"),
      n_extreme_profiles = sum(as.character(profiles$profile_role) == "red_extreme_single"),
      max_D = max(int(profiles$D)),
      max_n_each = max(int(profiles$n_each)),
      max_m = max(int(profiles$m)),
      max_p_over_n_tt500 = max(num(profiles$p_over_n_tt500)),
      max_root_id_chars = max(nchar(as.character(grid$root_id)), na.rm = TRUE),
      max_profile_id_chars = max(nchar(as.character(profiles$screening_profile_id)), na.rm = TRUE)
    ),
    launch_policy = list(
      vb_only = TRUE,
      mcmc_closed = TRUE,
      article_facing = FALSE,
      storage_light = TRUE,
      exact_spec_id_filter_required = TRUE,
      approval_required_before_compute = TRUE
    )
  )
  write_json(manifest, paths$manifest)

  data.frame(
    bundle_code = bundle_code,
    bundle_id = cfg$bundle_id,
    bundle_order = as.integer(bundle_order),
    stage_stub = stage_stub,
    defaults_path = resolve_path(paths$defaults),
    grid_path = resolve_path(paths$grid),
    profiles_path = resolve_path(paths$profiles),
    assignments_path = resolve_path(paths$assignments),
    target_spec_ids_path = resolve_path(paths$target_specs),
    manifest_path = resolve_path(paths$manifest),
    n_profiles = nrow(profiles),
    n_assignments = nrow(assignments2),
    n_grid_rows = nrow(grid),
    n_target_specs = nrow(target_specs),
    n_red_tier_profiles = sum(as.character(profiles$capacity_tier) == "red"),
    n_extreme_profiles = sum(as.character(profiles$profile_role) == "red_extreme_single"),
    max_D = max(int(profiles$D)),
    max_n_each = max(int(profiles$n_each)),
    max_m = max(int(profiles$m)),
    max_p_over_n_tt500 = max(num(profiles$p_over_n_tt500)),
    max_root_id_chars = max(nchar(as.character(grid$root_id)), na.rm = TRUE),
    max_profile_id_chars = max(nchar(as.character(profiles$screening_profile_id)), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

bundle_codes <- sort(unique(as.character(cell_blockers$qvbm1_bundle)))
bundle_codes <- intersect(bundle_codes, c("c12", "c123"))
if (!length(bundle_codes)) stop("No c12/c123 qvbm1 bundle cells found for qvbm3.", call. = FALSE)

index <- bind_rows(lapply(seq_along(bundle_codes), function(i) materialize_bundle(bundle_codes[[i]], i)))
index_path <- write_csv(index, file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv")))
index_manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = git_sha_at_start,
    git_branch = git_branch_at_start,
    git_dirty = git_dirty_at_start,
    stage_prefix = stage_prefix,
    base_defaults = resolve_path(base_defaults),
    audit_manifest = resolve_path(audit_manifest),
    cell_blockers_path = resolve_path(cell_blockers_path),
    index_path = index_path,
    bundles = index,
    total_profiles = sum(int(index$n_profiles)),
    total_target_specs = sum(int(index$n_target_specs)),
    total_red_tier_profiles = sum(int(index$n_red_tier_profiles)),
    total_extreme_profiles = sum(int(index$n_extreme_profiles)),
    launch_policy = list(
      run_mode = "qvbm3_capacity_expansion_vb_canary",
      no_mcmc = TRUE,
      no_article_update = TRUE,
      one_likelihood_per_root = TRUE,
      approval_required_before_compute = TRUE
    )
  ),
  file.path("config", "validation", paste0(stage_prefix, "_bundle_index_manifest.json"))
)

cat(sprintf("bundle_index: %s\n", index_path))
cat(sprintf("bundle_index_manifest: %s\n", index_manifest_path))
cat(sprintf("bundles: %d\n", nrow(index)))
cat(sprintf("target_specs: %d\n", sum(int(index$n_target_specs))))
cat(sprintf("red_tier_profiles: %d\n", sum(int(index$n_red_tier_profiles))))
cat(sprintf("extreme_profiles: %d\n", sum(int(index$n_extreme_profiles))))
cat("qvbm3_materialization=PASS\n")
