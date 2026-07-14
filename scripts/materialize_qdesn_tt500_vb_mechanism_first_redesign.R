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
sha256_file <- function(path) {
  path <- resolve_path(path, must_work = TRUE)
  unname(tools::sha256sum(path))
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
rel_path <- function(path) sub(paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", repo_root), "/?"), "", resolve_path(path, must_work = FALSE))

base_defaults <- get_arg("--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml")
stage_prefix <- get_arg("--stage-prefix", "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first")
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
refresh_grid <- !has_flag("--no-refresh-grid")
short_path_mode <- has_flag("--short-path-mode") || identical(stage_prefix, "qvbm1")

hard_cells <- data.frame(
  family = c("laplace", "normal", "gausmix", "normal", "normal", "normal", "laplace", "gausmix"),
  tau = c(0.05, 0.05, 0.05, 0.05, 0.50, 0.50, 0.05, 0.05),
  likelihood_target = c("exal", "exal", "exal", "al", "al", "exal", "al", "al"),
  priority_rank = seq_len(8L),
  blocker_target = c(
    "fit_rmse_fit_check",
    "fit_rmse_forecast_mae",
    "fit_rmse",
    "fit_rmse_forecast_mae",
    "forecast_mae_forecast_check",
    "forecast_mae_forecast_check",
    "fit_rmse_forecast_mae_forecast_check",
    "fit_rmse"
  ),
  current_best_joint_worst_ratio = c(1.759805, 1.723917, 1.616767, 1.558946, 1.550843, 1.439108, 1.387678, 1.173839),
  stringsAsFactors = FALSE
)

profile_templates <- data.frame(
  profile_role = c("structured_micro", "structured_compact", "structured_forecast_guard", "structured_tail_guard"),
  D = c(1L, 1L, 1L, 1L),
  n_each = c(4L, 8L, 12L, 6L),
  n_tilde_each = c(0L, 0L, 0L, 0L),
  m = c(3L, 6L, 12L, 1L),
  alpha = c(0.0010, 0.0025, 0.0100, 0.00075),
  rho = c(0.35, 0.45, 0.60, 0.35),
  pi_w = c(0.0010, 0.0025, 0.0050, 0.00075),
  pi_in = c(0.03, 0.05, 0.10, 0.03),
  rhs_tau0 = c(3e-4, 3e-4, 1e-4, 3e-4),
  washout = c(300L, 300L, 300L, 300L),
  readout_y_lags = c(3L, 6L, 12L, 1L),
  reservoir_lags = c(0L, 0L, 0L, 0L),
  x_feature_count = c(4L, 8L, 12L, 6L),
  stringsAsFactors = FALSE
)

period_cols <- function(harmonics = c(1L, 2L)) {
  unique(c(
    unlist(lapply(as.integer(harmonics), function(h) c(paste0("period90_sin_h", h), paste0("period90_cos_h", h))), use.names = FALSE),
    "period90_trend_z"
  ))
}

decomp_cfg <- function(bundle_id) {
  h12 <- c(1L, 2L)
  h123 <- c(1L, 2L, 3L)
  if (identical(bundle_id, "raw_period90_control")) {
    return(list(
      readout_input_mode = "raw_y_lags",
      deterministic_harmonics = h12,
      decomposition = list(enabled = FALSE),
      mechanism_summary = "raw_y_lags control with staged period-90 deterministic features"
    ))
  }
  builder <- if (grepl("^decomp_component", bundle_id)) "component_lags" else "state_resid_y"
  harmonics <- if (grepl("h123", bundle_id)) h123 else h12
  xreg_cols <- period_cols(harmonics)
  components <- if (grepl("xreg", bundle_id)) {
    c("trend", "seasonal", "regression", "transfer", "residual")
  } else {
    c("trend", "seasonal", "residual")
  }
  recursion <- if (grepl("plugin", bundle_id)) "deterministic_plugin" else "sampled_path"
  list(
    readout_input_mode = "dlm_decomp_lags",
    deterministic_harmonics = harmonics,
    decomposition = list(
      enabled = TRUE,
      backend = "r",
      state_estimate = "filtered",
      components = as.list(components),
      input_builder = builder,
      trend = list(degree = 1L),
      seasonal = list(period = 90L, harmonics = as.list(harmonics), auto = list(enabled = FALSE)),
      regression = list(
        enabled = grepl("xreg", bundle_id),
        dynamic = FALSE,
        x_cols = as.list(xreg_cols),
        features = list(include_raw = TRUE, lags = as.list(0L), include_squares = FALSE, include_interactions = FALSE)
      ),
      transfer = list(
        enabled = grepl("xreg", bundle_id),
        x_cols = as.list(xreg_cols),
        lambda = 0.90,
        features = list(include_raw = TRUE, lags = as.list(0L), include_squares = FALSE, include_interactions = FALSE)
      ),
      input_lags_mode = "component",
      input_lags = list(
        trend = as.list(1:2),
        seasonal = as.list(1:3),
        residual = as.list(1:2),
        regression = as.list(0:1),
        transfer = as.list(0:1)
      ),
      state_resid_y = list(
        state_lags = as.list(0:1),
        residual_lags = as.list(0:2),
        y_lags = as.list(1:2),
        include_xreg = grepl("xreg", bundle_id),
        xreg_lags = as.list(0:1),
        xreg_source = as.list(c("regression", "transfer"))
      ),
      discount = list(trend = 0.99, seasonal = 0.99, regression = 1.0, transfer_zeta = 0.99, transfer_psi = 1.0),
      variance = list(mode = "unknown_constant", l0 = 1, S0 = 1),
      forecast = list(residual_recursion = recursion),
      sim_xreg = list(policy = "repeat_last")
    ),
    mechanism_summary = paste0(builder, " DLM decomposition with period-90 harmonics ", paste(harmonics, collapse = ","), " and ", recursion, " forecast residual recursion")
  )
}

bundles <- data.frame(
  bundle_id = c(
    "raw_period90_control",
    "decomp_component_p90_h12",
    "decomp_component_p90_h123",
    "decomp_state_resid_y_p90_h12",
    "decomp_state_resid_y_plugin_p90_h12",
    "decomp_state_resid_y_xreg_p90_h12"
  ),
  bundle_code = c("raw", "c12", "c123", "sr", "srp", "srx"),
  bundle_order = seq_len(6L),
  stringsAsFactors = FALSE
)

bundle_code_for <- function(bundle_id) {
  out <- bundles$bundle_code[match(bundle_id, bundles$bundle_id)]
  if (is.na(out) || !nzchar(out)) slug(bundle_id) else out
}

make_profiles <- function(bundle_id) {
  rows <- list()
  row_i <- 0L
  bcode <- bundle_code_for(bundle_id)
  for (ci in seq_len(nrow(hard_cells))) {
    cell <- hard_cells[ci, , drop = FALSE]
    for (ti in seq_len(nrow(profile_templates))) {
      tmpl <- profile_templates[ti, , drop = FALSE]
      row_i <- row_i + 1L
      sid <- if (isTRUE(short_path_mode)) {
        sprintf("m1%s_c%02d_p%02d", bcode, as.integer(cell$priority_rank), ti)
      } else {
        sprintf(
          "tt500vb_mech_%s_%s_%s_%s_%s_d%d_n%d_a%s_r%s_m%d_tau0%s_s%d",
          slug(bundle_id), as.character(cell$family), tau_token(cell$tau),
          as.character(cell$likelihood_target), slug(tmpl$profile_role),
          as.integer(tmpl$D), as.integer(tmpl$n_each), slug_num(tmpl$alpha),
          slug_num(tmpl$rho), as.integer(tmpl$m), slug_num(tmpl$rhs_tau0),
          73000L + 100L * as.integer(cell$priority_rank) + ti
        )
      }
      p_est <- as.integer(tmpl$D * tmpl$n_each + if (as.integer(tmpl$D) > 1L) tmpl$n_tilde_each * (tmpl$D - 1L) else 0L + 1L)
      rows[[length(rows) + 1L]] <- data.frame(
        screening_profile_id = sid,
        screening_stage = paste0("vb_mechanism_first_", bundle_id),
        screening_wave = "mechanism_first_2026_07_13",
        profile_role = as.character(tmpl$profile_role),
        enabled = TRUE,
        D = as.integer(tmpl$D),
        n_each = as.integer(tmpl$n_each),
        n_tilde_each = as.integer(tmpl$n_tilde_each),
        m = as.integer(tmpl$m),
        alpha = as.numeric(tmpl$alpha),
        rho = as.numeric(tmpl$rho),
        pi_w = as.numeric(tmpl$pi_w),
        pi_in = as.numeric(tmpl$pi_in),
        washout = as.integer(tmpl$washout),
        add_bias = TRUE,
        seed = 73000L + 100L * as.integer(cell$priority_rank) + ti,
        readout_y_lags = as.integer(tmpl$readout_y_lags),
        reservoir_lags = as.integer(tmpl$reservoir_lags),
        rhs_tau0 = as.numeric(tmpl$rhs_tau0),
        dimension_p_estimate = p_est,
        p_over_n_tt500 = p_est / 500,
        x_feature_count = as.integer(tmpl$x_feature_count),
        target_family = as.character(cell$family),
        target_tau = as.numeric(cell$tau),
        likelihood_target = as.character(cell$likelihood_target),
        design_bundle = bundle_id,
        design_bundle_code = bcode,
        design_axis = "mechanism_first_decomposition",
        blocker_target = as.character(cell$blocker_target),
        current_best_joint_worst_ratio = as.numeric(cell$current_best_joint_worst_ratio),
        launch_gate = "explicit_human_approved_current_request",
        stringsAsFactors = FALSE
      )
    }
  }
  bind_rows(rows)
}

make_assignments <- function(profiles) {
  profiles$assignment_key <- paste(profiles$screening_profile_id, profiles$target_family, tau_key(profiles$target_tau), sep = "\r")
  data.frame(
    assignment_key = profiles$assignment_key,
    family = profiles$target_family,
    tau = profiles$target_tau,
    likelihood_target = profiles$likelihood_target,
    cell_status = "mechanism_hard_cell",
    priority_rank = match(paste(profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, sep = "\r"),
                          paste(hard_cells$family, tau_key(hard_cells$tau), hard_cells$likelihood_target, sep = "\r")),
    target_profile_rank = ave(seq_len(nrow(profiles)), profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, FUN = seq_along),
    screening_profile_id = profiles$screening_profile_id,
    design_bundle = profiles$design_bundle,
    design_bundle_code = profiles$design_bundle_code,
    design_axis = profiles$design_axis,
    blocker_target = profiles$blocker_target,
    current_best_joint_worst_ratio = profiles$current_best_joint_worst_ratio,
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
    tau = as.numeric(grid$tau),
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
    stop("Failed to resolve one or more target atomic spec IDs.", call. = FALSE)
  }
  out <- data.frame(
    root_id = as.character(merged$root_id),
    likelihood_target = as.character(merged$likelihood_target),
    screening_profile_id = as.character(merged$screening_profile_id.x %||% merged$screening_profile_id),
    family = as.character(merged$family.x %||% merged$family),
    tau = as.numeric(merged$tau.x %||% merged$tau),
    spec_id = as.character(merged$spec_id),
    method = as.character(merged$method %||% "vb"),
    prior = as.character(merged$prior %||% "rhs_ns"),
    stringsAsFactors = FALSE
  )
  out[order(out$family, out$tau, out$likelihood_target, out$screening_profile_id), , drop = FALSE]
}

materialize_bundle <- function(bundle_id, bundle_order, bundle_code) {
  stage_stub <- if (isTRUE(short_path_mode)) {
    paste(stage_prefix, bundle_code, sep = "_")
  } else {
    paste(stage_prefix, slug(bundle_id), sep = "_")
  }
  paths <- list(
    profiles = file.path("config", "validation", paste0(stage_stub, "_profiles.csv")),
    assignments = file.path("config", "validation", paste0(stage_stub, "_cell_assignments.csv")),
    defaults = file.path("config", "validation", paste0(stage_stub, "_defaults.yaml")),
    grid = file.path("config", "validation", paste0(stage_stub, "_grid.csv")),
    target_specs = file.path("config", "validation", paste0(stage_stub, "_target_spec_ids.csv")),
    manifest = file.path("config", "validation", paste0(stage_stub, "_materialization_manifest.json"))
  )
  profiles <- make_profiles(bundle_id)
  assignments <- make_assignments(profiles)
  plan <- list(
    profiles = profiles,
    assignments = assignments,
    cell_plan = transform(hard_cells, cell_status = "extreme_hard")
  )
  stage_desc <- sprintf("Q-DESN 500-observation VB mechanism-first bundle `%s`.", bundle_id)
  mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    stage = "mechanism_first",
    stage_stub = stage_stub,
    stage_desc = stage_desc,
    base_defaults_path = resolve_path(base_defaults),
    profiles_out = resolve_path(paths$profiles, must_work = FALSE),
    assignments_out = resolve_path(paths$assignments, must_work = FALSE),
    defaults_out = resolve_path(paths$defaults, must_work = FALSE),
    grid_out = resolve_path(paths$grid, must_work = FALSE),
    refresh_grid = refresh_grid,
    refresh_materialized = FALSE,
    priors = "rhs_ns",
    workers = workers
  )
  defaults <- yaml::read_yaml(resolve_path(paths$defaults))
  bundle_cfg <- decomp_cfg(bundle_id)
  defaults$campaign$name <- stage_stub
  if (isTRUE(short_path_mode)) {
    defaults$campaign$results_root <- file.path("results", stage_prefix, bundle_code)
    defaults$campaign$reports_root <- file.path("reports", stage_prefix, bundle_code)
  } else {
    defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_stub)
    defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_stub)
  }
  defaults$execution$methods <- "vb"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$study_contract$core_lane <- TRUE
  defaults$study_contract$id <- paste0(stage_stub, "_2026_07_13")
  defaults$study_contract$description <- paste(
    stage_desc,
    "This is a targeted hard-cell mechanism screen, not article-facing until strict audit and explicit promotion."
  )
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$pipeline <- defaults$pipeline %||% list()
  defaults$pipeline$readout <- defaults$pipeline$readout %||% list()
  defaults$pipeline$readout$input_mode <- bundle_cfg$readout_input_mode
  defaults$pipeline$decomposition <- bundle_cfg$decomposition
  defaults$pipeline$validation_guardrails <- defaults$pipeline$validation_guardrails %||% list()
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags <- !identical(bundle_id, "raw_period90_control")
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags_reason <- if (identical(bundle_id, "raw_period90_control")) {
    "raw control keeps the standard validation raw_y_lags guard"
  } else {
    "qvbm1 mechanism-first VB screen explicitly evaluates DLM decomposition lag inputs"
  }
  defaults$pipeline$outputs <- utils::modifyList(
    defaults$pipeline$outputs %||% list(),
    list(save_forecast_objects = FALSE, keep_draws = FALSE, save_fit_objects = FALSE)
  )
  defaults$deterministic_features <- defaults$deterministic_features %||% list()
  defaults$deterministic_features$enabled <- TRUE
  defaults$deterministic_features$period <- 90L
  defaults$deterministic_features$harmonics <- as.list(as.integer(bundle_cfg$deterministic_harmonics))
  defaults$deterministic_features$include_trend <- TRUE
  defaults$deterministic_features$prefix <- "period90"
  defaults$screening_profiles$mechanism_first_design <- list(
    bundle_id = bundle_id,
    bundle_code = bundle_code,
    bundle_order = as.integer(bundle_order),
    mechanism_summary = bundle_cfg$mechanism_summary,
    target_cells = nrow(hard_cells),
    profiles_per_cell = nrow(profile_templates),
    target_likelihood_policy = "one exact likelihood per root via target_spec_ids",
    promotion_policy = "do not promote to MCMC unless a strict current-protocol VB audit finds a per-cell winner or compelling near-winner"
  )
  yaml::write_yaml(defaults, resolve_path(paths$defaults, must_work = FALSE))

  grid <- utils::read.csv(resolve_path(paths$grid), check.names = FALSE, stringsAsFactors = FALSE)
  assignments2 <- utils::read.csv(resolve_path(paths$assignments), check.names = FALSE, stringsAsFactors = FALSE)
  defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(resolve_path(paths$defaults))
  target_specs <- target_specs_for(grid, assignments2, defaults_loaded)
  write_csv(target_specs, paths$target_specs)
  defaults_loaded$execution <- defaults_loaded$execution %||% list()
  defaults_loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(defaults_loaded, resolve_path(paths$defaults, must_work = FALSE))

  manifest <- list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
    bundle_id = bundle_id,
    bundle_order = as.integer(bundle_order),
    stage_stub = stage_stub,
    base_defaults = resolve_path(base_defaults),
    mechanism_summary = bundle_cfg$mechanism_summary,
    hard_cells = hard_cells,
    materialization = mat,
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
      n_hard_cells = nrow(hard_cells),
      max_root_id_chars = max(nchar(as.character(grid$root_id)), na.rm = TRUE),
      max_profile_id_chars = max(nchar(as.character(profiles$screening_profile_id)), na.rm = TRUE)
    ),
    launch_policy = list(
      launch_approved_by_current_user_request = TRUE,
      vb_only = TRUE,
      storage_light = TRUE,
      exact_spec_id_filter_required = TRUE,
      article_facing = FALSE
    )
  )
  write_json(manifest, paths$manifest)
  data.frame(
    bundle_id = bundle_id,
    bundle_code = bundle_code,
    bundle_order = as.integer(bundle_order),
    stage_stub = stage_stub,
    defaults_path = resolve_path(paths$defaults, must_work = TRUE),
    grid_path = resolve_path(paths$grid, must_work = TRUE),
    profiles_path = resolve_path(paths$profiles, must_work = TRUE),
    assignments_path = resolve_path(paths$assignments, must_work = TRUE),
    target_spec_ids_path = resolve_path(paths$target_specs, must_work = TRUE),
    manifest_path = resolve_path(paths$manifest, must_work = TRUE),
    n_profiles = nrow(profiles),
    n_assignments = nrow(assignments2),
    n_grid_rows = nrow(grid),
    n_target_specs = nrow(target_specs),
    max_root_id_chars = max(nchar(as.character(grid$root_id)), na.rm = TRUE),
    max_profile_id_chars = max(nchar(as.character(profiles$screening_profile_id)), na.rm = TRUE),
    mechanism_summary = bundle_cfg$mechanism_summary,
    stringsAsFactors = FALSE
  )
}

index <- bind_rows(lapply(seq_len(nrow(bundles)), function(i) {
  materialize_bundle(bundles$bundle_id[[i]], bundles$bundle_order[[i]], bundles$bundle_code[[i]])
}))
index_path <- write_csv(index, file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv")))
index_manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
    stage_prefix = stage_prefix,
    short_path_mode = isTRUE(short_path_mode),
    base_defaults = resolve_path(base_defaults),
    index_path = index_path,
    bundles = index,
    hard_cells = hard_cells,
    total_target_specs = sum(as.integer(index$n_target_specs)),
    launch_policy = list(
      run_mode = "targeted_vb_screen",
      no_mcmc = TRUE,
      one_likelihood_per_root = TRUE,
      run_in_background_via_orchestrator = TRUE
    )
  ),
  file.path("config", "validation", paste0(stage_prefix, "_bundle_index_manifest.json"))
)

message("Materialized Q-DESN VB mechanism-first bundles:")
message("  index: ", index_path)
message("  manifest: ", index_manifest_path)
message("  bundles: ", nrow(index), "; target specs: ", sum(as.integer(index$n_target_specs)))
message("  max root_id chars: ", max(as.integer(index$max_root_id_chars), na.rm = TRUE))
