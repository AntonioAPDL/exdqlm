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
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

slug_tau0 <- function(x) {
  x <- as.numeric(x)[1L]
  if (abs(x - 1e-4) < 1e-12) return("1e4")
  if (abs(x - 7.5e-5) < 1e-12) return("75e6")
  out <- formatC(x, digits = 3L, format = "fg", flag = "#")
  gsub("[^0-9a-zA-Z]+", "", gsub("e-", "e", out, fixed = TRUE))
}

map_lowtau <- function(rhs_tau0) {
  x <- num(rhs_tau0)
  out <- rep(NA_real_, length(x))
  out[abs(x - 3e-4) < 1e-12] <- 1e-4
  out[abs(x - 1e-4) < 1e-12] <- 7.5e-5
  other <- !is.finite(out)
  out[other] <- pmax(7.5e-5, x[other] * 0.5)
  out
}

base_defaults <- get_arg("--base-defaults", "config/validation/qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_defaults.yaml")
source_bundle_index <- get_arg("--source-bundle-index", "config/validation/qvbm3_capacity_bundle_index.csv")
stage_prefix <- get_arg("--stage-prefix", "qvbm3_lowtau")
workers <- suppressWarnings(as.integer(get_arg("--workers", "20"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 20L
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")
tau0_override_raw <- as.character(get_arg("--tau0-override", ""))[1L]
tau0_override <- suppressWarnings(as.numeric(tau0_override_raw))
use_tau0_override <- nzchar(trimws(tau0_override_raw)) && is.finite(tau0_override)
allow_ultra_low_tau0 <- has_flag("--allow-ultra-low-tau0")
if (nzchar(trimws(tau0_override_raw)) && !isTRUE(use_tau0_override)) {
  stop("--tau0-override must be numeric when supplied.", call. = FALSE)
}
if (isTRUE(use_tau0_override) && tau0_override <= 0) {
  stop("--tau0-override must be positive.", call. = FALSE)
}
if (isTRUE(use_tau0_override) && tau0_override <= 3e-5 && !isTRUE(allow_ultra_low_tau0)) {
  stop("--tau0-override at or below 3e-05 requires --allow-ultra-low-tau0.", call. = FALSE)
}

source_index <- utils::read.csv(resolve_path(source_bundle_index), stringsAsFactors = FALSE, check.names = FALSE)
required_index <- c("bundle_code", "bundle_id", "defaults_path", "profiles_path")
if (!all(required_index %in% names(source_index))) {
  stop(sprintf("Source qvbm3 bundle index is missing: %s", paste(setdiff(required_index, names(source_index)), collapse = ", ")), call. = FALSE)
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
    stop("Failed to resolve one or more qvbm3-lowtau target atomic spec IDs.", call. = FALSE)
  }
  data.frame(
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
}

make_lowtau_profiles <- function(source_profiles, bundle_code) {
  required_profile <- c(
    "screening_profile_id", "screening_stage", "screening_wave", "rhs_tau0",
    "target_family", "target_tau", "likelihood_target", "design_bundle",
    "design_bundle_code", "capacity_tier", "capacity_policy", "blocker_target",
    "source_frontier_row", "external_joint_worst_ratio"
  )
  if (!all(required_profile %in% names(source_profiles))) {
    stop(sprintf("Source qvbm3 profiles are missing: %s", paste(setdiff(required_profile, names(source_profiles)), collapse = ", ")), call. = FALSE)
  }
  out <- source_profiles
  original_id <- as.character(out$screening_profile_id)
  original_tau0 <- num(out$rhs_tau0)
  new_tau0 <- if (isTRUE(use_tau0_override)) rep(tau0_override, length(original_tau0)) else map_lowtau(original_tau0)
  if (any(!is.finite(new_tau0) | new_tau0 <= 3e-5) && !isTRUE(allow_ultra_low_tau0)) {
    stop("qvbm3-lowtau mapping produced tau0 at or below the known failed p03 value.", call. = FALSE)
  }
  if (any(new_tau0 >= original_tau0, na.rm = TRUE)) {
    stop("qvbm3-lowtau mapping did not reduce every source rhs_tau0.", call. = FALSE)
  }

  out$source_qvbm3_profile_id <- original_id
  out$source_qvbm3_screening_stage <- as.character(out$screening_stage)
  out$source_qvbm3_screening_wave <- as.character(out$screening_wave)
  out$rhs_tau0_original <- original_tau0
  out$rhs_tau0 <- new_tau0
  out$rhs_tau0_ratio_vs_qvbm3 <- new_tau0 / original_tau0
  out$rhs_tau0_relaunch_policy <- if (isTRUE(use_tau0_override)) {
    sprintf("forced_tau0_override_%s", slug_tau0(tau0_override))
  } else {
    ifelse(
      original_tau0 > 1e-4,
      "shift_3e-4_to_prior_safe_floor_1e-4",
      "below_prior_safe_floor_canary_7p5e-5"
    )
  }
  out$screening_profile_id <- paste0(
    sub("^m3", "m3lt", original_id),
    "_lt", vapply(new_tau0, slug_tau0, character(1L))
  )
  out$screening_stage <- paste0("vb_qvbm3_lowtau_relaunch_", bundle_code)
  out$screening_wave <- "qvbm3_lowtau_relaunch_2026_07_15"
  out$design_axis <- "qvbm3_capacity_lowtau_relaunch"
  out$launch_gate <- "materialized_prepare_only_no_compute_launch"
  out$article_facing <- FALSE
  if ("seed" %in% names(out)) out$seed <- int(out$seed) + 17000L
  out
}

make_assignments <- function(profiles) {
  data.frame(
    assignment_key = paste(profiles$screening_profile_id, profiles$target_family, tau_key(profiles$target_tau), sep = "\r"),
    family = profiles$target_family,
    tau = profiles$target_tau,
    likelihood_target = profiles$likelihood_target,
    cell_status = profiles$cell_target_role,
    priority_rank = ave(seq_len(nrow(profiles)), profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, FUN = function(z) min(z)),
    target_profile_rank = ave(seq_len(nrow(profiles)), profiles$target_family, tau_key(profiles$target_tau), profiles$likelihood_target, FUN = seq_along),
    screening_profile_id = profiles$screening_profile_id,
    source_qvbm3_profile_id = profiles$source_qvbm3_profile_id,
    design_bundle = profiles$design_bundle,
    design_bundle_code = profiles$design_bundle_code,
    design_axis = profiles$design_axis,
    capacity_tier = profiles$capacity_tier,
    capacity_policy = profiles$capacity_policy,
    rhs_tau0_original = profiles$rhs_tau0_original,
    rhs_tau0 = profiles$rhs_tau0,
    rhs_tau0_relaunch_policy = profiles$rhs_tau0_relaunch_policy,
    blocker_target = profiles$blocker_target,
    source_frontier_row = profiles$source_frontier_row,
    external_joint_worst_ratio = profiles$external_joint_worst_ratio,
    stringsAsFactors = FALSE
  )
}

materialize_bundle <- function(row) {
  bundle_code <- as.character(row$bundle_code[[1L]])
  bundle_id <- as.character(row$bundle_id[[1L]])
  source_profiles <- utils::read.csv(resolve_path(row$profiles_path[[1L]]), stringsAsFactors = FALSE, check.names = FALSE)
  source_defaults <- yaml::read_yaml(resolve_path(row$defaults_path[[1L]]))
  profiles <- make_lowtau_profiles(source_profiles, bundle_code)
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
  exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
    plan = plan,
    stage = "qvbm3_lowtau_relaunch",
    stage_stub = stage_stub,
    stage_desc = sprintf("Q-DESN VB qvbm3 low-tau relaunch bundle `%s`.", bundle_code),
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
  defaults$runtime$campaign_workers <- workers
  defaults$runtime$workers <- workers
  defaults$runtime$root_scheduler <- "load_balanced"
  defaults$study_contract <- defaults$study_contract %||% list()
  defaults$study_contract$core_lane <- TRUE
  defaults$study_contract$id <- paste0(stage_stub, "_2026_07_15")
  defaults$study_contract$description <- paste(
    "Q-DESN qvbm3 low-tau relaunch.",
    "Same qvbm3 cell/capacity surface with smaller RHS tau0 values.",
    "VB-only; not article-facing; MCMC handoff closed until strict closeout."
  )
  defaults$pipeline <- defaults$pipeline %||% list()
  defaults$pipeline$readout <- defaults$pipeline$readout %||% list()
  defaults$pipeline$readout$input_mode <- (source_defaults$pipeline %||% list())$readout$input_mode %||% "dlm_decomp_lags"
  defaults$pipeline$decomposition <- (source_defaults$pipeline %||% list())$decomposition
  defaults$pipeline$validation_guardrails <- defaults$pipeline$validation_guardrails %||% list()
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags <- TRUE
  defaults$pipeline$validation_guardrails$allow_dlm_decomp_lags_reason <- "qvbm3-lowtau preserves qvbm3 DLM-decomposition bundle while reducing RHS tau0"
  defaults$pipeline$outputs <- utils::modifyList(
    defaults$pipeline$outputs %||% list(),
    list(save_forecast_objects = FALSE, keep_draws = FALSE, save_fit_objects = FALSE)
  )
  defaults$deterministic_features <- (source_defaults$deterministic_features %||% defaults$deterministic_features)
  defaults$screening_profiles$qvbm3_lowtau_relaunch_design <- list(
    source_bundle_index = resolve_path(source_bundle_index),
    source_bundle_code = bundle_code,
    source_qvbm3_bundle_id = bundle_id,
    profiles = nrow(profiles),
    tau0_mapping = list(
      original_3e_minus_4 = 1e-4,
      original_1e_minus_4 = 7.5e-5,
      tau0_override = if (isTRUE(use_tau0_override)) tau0_override else NULL,
      hard_floor_refuse_at_or_below = if (isTRUE(allow_ultra_low_tau0)) NULL else 3e-5,
      ultra_low_tau0_allowed = isTRUE(allow_ultra_low_tau0)
    ),
      min_rhs_tau0 = min(num(profiles$rhs_tau0)),
      max_rhs_tau0 = max(num(profiles$rhs_tau0)),
      below_previous_safe_floor_rows = sum(num(profiles$rhs_tau0) < 1e-4),
      at_or_below_known_failed_tau0_rows = sum(num(profiles$rhs_tau0) <= 3e-5),
      launch_policy = "prepare/materialize only by default; explicit user approval required before full VB relaunch",
    promotion_policy = "do not promote to MCMC unless strict current-protocol VB closeout beats qvbm1/qvbm2/qvbm2p3 and external DQLM/exDQLM gates"
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
    bundle_id = bundle_id,
    source_qvbm3 = list(
      source_bundle_index = resolve_path(source_bundle_index),
      source_defaults = resolve_path(row$defaults_path[[1L]]),
      source_profiles = resolve_path(row$profiles_path[[1L]])
    ),
    base_defaults = resolve_path(base_defaults),
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
      min_rhs_tau0 = min(num(profiles$rhs_tau0)),
      max_rhs_tau0 = max(num(profiles$rhs_tau0)),
      n_below_previous_safe_floor = sum(num(profiles$rhs_tau0) < 1e-4),
      n_at_or_below_known_failed_tau0 = sum(num(profiles$rhs_tau0) <= 3e-5),
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
      approval_required_before_compute = TRUE,
      canary_first_recommended = !isTRUE(allow_ultra_low_tau0),
      ultra_low_tau0_allowed_by_flag = isTRUE(allow_ultra_low_tau0)
    )
  )
  write_json(manifest, paths$manifest)

  data.frame(
    bundle_code = bundle_code,
    bundle_id = bundle_id,
    stage_stub = stage_stub,
    defaults_path = resolve_path(paths$defaults),
    grid_path = resolve_path(paths$grid),
    profiles_path = resolve_path(paths$profiles),
    assignments_path = resolve_path(paths$assignments),
    target_spec_ids_path = resolve_path(paths$target_specs),
    manifest_path = resolve_path(paths$manifest),
    source_qvbm3_profiles_path = resolve_path(row$profiles_path[[1L]]),
    n_profiles = nrow(profiles),
    n_grid_rows = nrow(grid),
    n_target_specs = nrow(target_specs),
    min_rhs_tau0 = min(num(profiles$rhs_tau0)),
    max_rhs_tau0 = max(num(profiles$rhs_tau0)),
    n_below_previous_safe_floor = sum(num(profiles$rhs_tau0) < 1e-4),
    n_at_or_below_known_failed_tau0 = sum(num(profiles$rhs_tau0) <= 3e-5),
    max_p_over_n_tt500 = max(num(profiles$p_over_n_tt500)),
    stringsAsFactors = FALSE
  )
}

source_index <- source_index[order(source_index$bundle_code), , drop = FALSE]
index <- bind_rows(lapply(seq_len(nrow(source_index)), function(i) materialize_bundle(source_index[i, , drop = FALSE])))
index_path <- write_csv(index, file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv")))
index_manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = git_sha_at_start,
    git_branch = git_branch_at_start,
    git_dirty = git_dirty_at_start,
    stage_prefix = stage_prefix,
    source_bundle_index = resolve_path(source_bundle_index),
    index_path = index_path,
    bundles = index,
    total_profiles = sum(int(index$n_profiles)),
    total_target_specs = sum(int(index$n_target_specs)),
    min_rhs_tau0 = min(num(index$min_rhs_tau0)),
    max_rhs_tau0 = max(num(index$max_rhs_tau0)),
    total_below_previous_safe_floor = sum(int(index$n_below_previous_safe_floor)),
    total_at_or_below_known_failed_tau0 = sum(int(index$n_at_or_below_known_failed_tau0)),
    tau0_override = if (isTRUE(use_tau0_override)) tau0_override else NULL,
    launch_policy = list(
      run_mode = "qvbm3_lowtau_vb_relaunch",
      no_mcmc = TRUE,
      no_article_update = TRUE,
      one_likelihood_per_root = TRUE,
      approval_required_before_compute = TRUE,
      canary_first_recommended = !isTRUE(allow_ultra_low_tau0),
      ultra_low_tau0_allowed_by_flag = isTRUE(allow_ultra_low_tau0)
    )
  ),
  file.path("config", "validation", paste0(stage_prefix, "_bundle_index_manifest.json"))
)

cat(sprintf("bundle_index: %s\n", index_path))
cat(sprintf("bundle_index_manifest: %s\n", index_manifest_path))
cat(sprintf("bundles: %d\n", nrow(index)))
cat(sprintf("target_specs: %d\n", sum(int(index$n_target_specs))))
cat(sprintf("rhs_tau0_min: %.8g\n", min(num(index$min_rhs_tau0))))
cat(sprintf("rhs_tau0_max: %.8g\n", max(num(index$max_rhs_tau0))))
cat(sprintf("below_previous_safe_floor: %d\n", sum(int(index$n_below_previous_safe_floor))))
cat("qvbm3_lowtau_materialization=PASS\n")
