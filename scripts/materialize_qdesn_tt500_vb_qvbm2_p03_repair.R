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
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

stage_prefix <- get_arg("--stage-prefix", "qvbm2p3")
source_prefix <- get_arg("--source-prefix", "qvbm2")
safe_tau0 <- suppressWarnings(as.numeric(get_arg("--safe-tau0", "0.0001"))[1L])
if (!is.finite(safe_tau0) || safe_tau0 <= 0) stop("--safe-tau0 must be finite and positive.", call. = FALSE)

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

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))

make_new_profile_id <- function(x, bundle_code) {
  sub(sprintf("^m2%s_", bundle_code), sprintf("m2p3%s_", bundle_code), as.character(x))
}

update_root_id <- function(root_id, old_profile, new_profile) {
  sub(paste0("profile_", old_profile, "$"), paste0("profile_", new_profile), as.character(root_id))
}

target_specs_for <- function(grid, assignments, defaults) {
  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    grid,
    defaults = defaults,
    methods = defaults$execution$methods %||% "vb",
    likelihood_families = defaults$execution$likelihood_families %||% c("al", "exal")
  )
  key_grid <- paste(as.character(grid$screening_profile_id), as.character(grid$source_family), sprintf("%.8f", as.numeric(grid$tau)), sep = "\r")
  key_assign <- paste(as.character(assignments$screening_profile_id), as.character(assignments$family), sprintf("%.8f", as.numeric(assignments$tau)), sep = "\r")
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
    stop("Failed to resolve one or more p03 repair target atomic spec IDs.", call. = FALSE)
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

source_index_path <- resolve_path(file.path("config", "validation", paste0(source_prefix, "_bundle_index.csv")))
source_index <- utils::read.csv(source_index_path, stringsAsFactors = FALSE, check.names = FALSE)
source_index <- source_index[as.character(source_index$bundle_code) %in% c("c12", "c123"), , drop = FALSE]

rows <- lapply(seq_len(nrow(source_index)), function(i) {
  src <- source_index[i, , drop = FALSE]
  bundle_code <- as.character(src$bundle_code[[1L]])
  stage_stub <- paste(stage_prefix, bundle_code, sep = "_")

  profiles <- utils::read.csv(resolve_path(src$profiles_path[[1L]]), stringsAsFactors = FALSE, check.names = FALSE)
  assignments <- utils::read.csv(resolve_path(src$assignments_path[[1L]]), stringsAsFactors = FALSE, check.names = FALSE)
  grid <- utils::read.csv(resolve_path(src$grid_path[[1L]]), stringsAsFactors = FALSE, check.names = FALSE)
  old_profiles <- profiles[grepl("_p03$", profiles$screening_profile_id), , drop = FALSE]
  if (nrow(old_profiles) != 8L) {
    stop(sprintf("Expected 8 p03 profiles for bundle %s, found %d.", bundle_code, nrow(old_profiles)), call. = FALSE)
  }

  old_to_new <- setNames(make_new_profile_id(old_profiles$screening_profile_id, bundle_code), old_profiles$screening_profile_id)
  profiles_out <- old_profiles
  profiles_out$repair_original_screening_profile_id <- profiles_out$screening_profile_id
  profiles_out$repair_original_rhs_tau0 <- profiles_out$rhs_tau0
  profiles_out$screening_profile_id <- unname(old_to_new[profiles_out$screening_profile_id])
  profiles_out$screening_stage <- paste0("vb_qvbm2_p03_safe_floor_repair_", bundle_code)
  profiles_out$screening_wave <- "qvbm2_p03_safe_floor_repair_2026_07_15"
  profiles_out$profile_role <- "check_guard_strong_shrink_safe_floor"
  profiles_out$design_focus <- "protect_check_loss_with_stable_rhs_tau0_floor"
  profiles_out$profile_suffix <- "p03"
  profiles_out$rhs_tau0 <- safe_tau0
  profiles_out$launch_gate <- "explicit_human_approved_p03_repair_current_request"
  profiles_out$repair_policy <- "original_qvbm2_p03_roots_refused; rerun strong-shrink design at stable rhs_tau0 floor"

  assignments_out <- assignments[as.character(assignments$screening_profile_id) %in% names(old_to_new), , drop = FALSE]
  assignments_out$repair_original_screening_profile_id <- assignments_out$screening_profile_id
  assignments_out$screening_profile_id <- unname(old_to_new[assignments_out$screening_profile_id])
  assignments_out$assignment_key <- paste(assignments_out$screening_profile_id, assignments_out$family, sprintf("%.8f", as.numeric(assignments_out$tau)), sep = "\r")
  assignments_out$design_axis <- "qvbm2_p03_safe_floor_repair"
  assignments_out$profile_suffix <- "p03"

  grid_out <- grid[as.character(grid$screening_profile_id) %in% names(old_to_new), , drop = FALSE]
  grid_out$repair_original_screening_profile_id <- grid_out$screening_profile_id
  grid_out$repair_original_root_id <- grid_out$root_id
  grid_out$screening_profile_id <- unname(old_to_new[grid_out$screening_profile_id])
  grid_out$reservoir_profile <- grid_out$screening_profile_id
  grid_out$root_id <- mapply(update_root_id, grid_out$root_id, grid_out$repair_original_screening_profile_id, grid_out$screening_profile_id, USE.NAMES = FALSE)
  grid_out$rhs_tau0 <- safe_tau0
  grid_out$profile_role <- "check_guard_strong_shrink_safe_floor"
  grid_out$profile_suffix <- "p03"
  grid_out$screening_stage <- paste0("vb_qvbm2_p03_safe_floor_repair_", bundle_code)
  grid_out$screening_wave <- "qvbm2_p03_safe_floor_repair_2026_07_15"

  defaults <- yaml::read_yaml(resolve_path(src$defaults_path[[1L]]))
  seed_policy_cfg <- (defaults$execution %||% list())$seed_policy %||% list()
  family_levels <- as.character((defaults$reference_contract %||% list())$families %||% sort(unique(as.character(grid_out$source_family))))
  tau_levels <- as.numeric((defaults$reference_contract %||% list())$taus %||% sort(unique(as.numeric(grid_out$tau))))
  fit_levels <- as.integer((defaults$reference_contract %||% list())$fit_sizes %||% sort(unique(as.integer(grid_out$fit_size))))
  base_seed <- as.integer(seed_policy_cfg$base_seed %||% 41000L)[1L]
  profile_offset <- match(as.character(grid_out$screening_profile_id), as.character(profiles_out$screening_profile_id)) - 1L
  family_idx <- match(as.character(grid_out$source_family), family_levels)
  tau_idx <- match(as.numeric(grid_out$tau), tau_levels)
  fit_idx <- match(as.integer(grid_out$fit_size), fit_levels)
  prior_idx <- match(as.character(grid_out$beta_prior_type), c("ridge", "rhs_ns"))
  grid_out$seed <- as.integer(
    base_seed +
      10000L * (family_idx - 1L) +
      1000L * (tau_idx - 1L) +
      100L * (fit_idx - 1L) +
      10L * (prior_idx - 1L) +
      profile_offset
  )
  profile_seed_map <- setNames(as.integer(grid_out$seed), as.character(grid_out$screening_profile_id))
  profiles_out$seed <- unname(profile_seed_map[as.character(profiles_out$screening_profile_id)])
  defaults$campaign$name <- stage_stub
  defaults$campaign$results_root <- file.path("results", stage_prefix, bundle_code)
  defaults$campaign$reports_root <- file.path("reports", stage_prefix, bundle_code)
  defaults$study_contract$id <- paste0(stage_stub, "_2026_07_15")
  defaults$study_contract$description <- paste(
    "Q-DESN qvbm2 p03 safe-floor repair.",
    "The original qvbm2 p03 roots are refused; this reruns the same structural profile with rhs_tau0 set to the stable lower bound."
  )
  defaults$execution$methods <- "vb"
  defaults$execution$likelihood_families <- as.list(c("al", "exal"))
  defaults$runtime$campaign_workers <- as.integer(get_arg("--workers", "16"))
  defaults$runtime$workers <- as.integer(get_arg("--workers", "16"))
  canonical_dataset_cells <- as.integer((defaults$reference_contract %||% list())$expected_unique_dataset_cells %||% 9L)
  if (!is.finite(canonical_dataset_cells) || canonical_dataset_cells < 1L) canonical_dataset_cells <- 9L
  canonical_p03_roots <- as.integer(nrow(profiles_out) * canonical_dataset_cells)
  selected_p03_roots <- as.integer(nrow(grid_out))
  defaults$reference_contract$expected_qdesn_roots <- canonical_p03_roots
  defaults$reference_contract$expected_selected_qdesn_roots <- selected_p03_roots
  defaults$screening_profiles$csv <- rel_path(file.path("config", "validation", paste0(stage_stub, "_profiles.csv")))
  defaults$screening_profiles$cell_assignments_csv <- rel_path(file.path("config", "validation", paste0(stage_stub, "_cell_assignments.csv")))
  defaults$screening_profiles$design <- "qvbm2 p03 repair: strong-shrink profile with safe rhs_tau0 floor"
  defaults$screening_profiles$canonical_profile_count <- as.integer(nrow(profiles_out))
  defaults$screening_profiles$canonical_qdesn_root_count <- canonical_p03_roots
  defaults$screening_profiles$selected_assignment_root_count <- selected_p03_roots
  defaults$screening_profiles$parent_screening_profile_count <- 64L
  defaults$screening_profiles$parent_qdesn_root_count <- 576L
  defaults$screening_profiles$qvbm2_p03_repair <- list(
    source_stage = source_prefix,
    source_bundle_code = bundle_code,
    original_profile_suffix = "p03",
    original_rhs_tau0 = 3e-05,
    safe_rhs_tau0 = safe_tau0,
    canonical_p03_qdesn_roots = canonical_p03_roots,
    selected_p03_repair_roots = selected_p03_roots,
    parent_qvbm2_qdesn_roots = 576L,
    original_consume_policy = "refuse",
    article_facing = FALSE
  )

  profiles_path <- write_csv(profiles_out, file.path("config", "validation", paste0(stage_stub, "_profiles.csv")))
  assignments_path <- write_csv(assignments_out, file.path("config", "validation", paste0(stage_stub, "_cell_assignments.csv")))
  grid_path <- write_csv(grid_out, file.path("config", "validation", paste0(stage_stub, "_grid.csv")))
  defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_stub, "_defaults.yaml")), must_work = FALSE)
  yaml::write_yaml(defaults, defaults_path)
  defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  target_specs <- target_specs_for(grid_out, assignments_out, defaults_loaded)
  target_specs_path <- write_csv(target_specs, file.path("config", "validation", paste0(stage_stub, "_target_spec_ids.csv")))
  defaults_loaded$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
  yaml::write_yaml(defaults_loaded, defaults_path)

  manifest_path <- write_json(
    list(
      generated_at = as.character(Sys.time()),
      repo_root = repo_root,
      git_sha = system("git rev-parse HEAD", intern = TRUE)[[1L]],
      git_branch = system("git branch --show-current", intern = TRUE)[[1L]],
      stage_stub = stage_stub,
      bundle_id = as.character(src$bundle_id[[1L]]),
      bundle_code = bundle_code,
      source_manifest = as.character(src$manifest_path[[1L]]),
      repair_policy = list(
        original_profile_suffix = "p03",
        original_rhs_tau0 = 3e-05,
        safe_rhs_tau0 = safe_tau0,
        original_roots_untouched = TRUE,
        original_consume_policy = "refuse",
        article_facing = FALSE
      ),
      counts = list(
        n_profiles = nrow(profiles_out),
        n_assignments = nrow(assignments_out),
        n_grid_rows = nrow(grid_out),
        n_target_specs = nrow(target_specs),
        max_root_id_chars = max(nchar(grid_out$root_id)),
        max_profile_id_chars = max(nchar(profiles_out$screening_profile_id))
      ),
      paths = list(
        defaults = defaults_path,
        profiles = profiles_path,
        assignments = assignments_path,
        grid = grid_path,
        target_specs = target_specs_path
      ),
      hashes = list(
        defaults_sha256 = sha256_file(defaults_path),
        profiles_sha256 = sha256_file(profiles_path),
        assignments_sha256 = sha256_file(assignments_path),
        grid_sha256 = sha256_file(grid_path),
        target_specs_sha256 = sha256_file(target_specs_path)
      )
    ),
    file.path("config", "validation", paste0(stage_stub, "_materialization_manifest.json"))
  )

  data.frame(
    bundle_id = as.character(src$bundle_id[[1L]]),
    bundle_code = bundle_code,
    bundle_order = as.integer(src$bundle_order[[1L]]),
    stage_stub = stage_stub,
    defaults_path = defaults_path,
    grid_path = grid_path,
    profiles_path = profiles_path,
    assignments_path = assignments_path,
    target_spec_ids_path = target_specs_path,
    manifest_path = manifest_path,
    n_profiles = nrow(profiles_out),
    n_assignments = nrow(assignments_out),
    n_grid_rows = nrow(grid_out),
    n_target_specs = nrow(target_specs),
    max_root_id_chars = max(nchar(grid_out$root_id)),
    max_profile_id_chars = max(nchar(profiles_out$screening_profile_id)),
    mechanism_summary = paste0("qvbm2 p03 repair for ", bundle_code, " with rhs_tau0=", format(safe_tau0, scientific = FALSE)),
    stringsAsFactors = FALSE
  )
})

index <- do.call(rbind, rows)
index <- index[order(index$bundle_order), , drop = FALSE]
index_path <- write_csv(index, file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv")))
index_manifest <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    stage_prefix = stage_prefix,
    source_prefix = source_prefix,
    safe_rhs_tau0 = safe_tau0,
    index_path = index_path,
    bundles = index,
    total_target_specs = sum(index$n_target_specs),
    launch_policy = list(
      vb_only = TRUE,
      one_likelihood_per_root = TRUE,
      run_with = sprintf("Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R --stage-prefix %s --short-path-mode --skip-materialize --skip-audit --workers 16 --full --launch-approved", stage_prefix),
      article_facing = FALSE
    )
  ),
  file.path("config", "validation", paste0(stage_prefix, "_bundle_index_manifest.json"))
)

doc_path <- resolve_path("validation/fitforecast_v2/docs/QDESN_500OBS_VB_QVBM2_P03_REPAIR_2026-07-15.md", must_work = FALSE)
doc_lines <- c(
  "# Q-DESN qvbm2 p03 Safe-Floor Repair",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- stage_prefix: `%s`", stage_prefix),
  sprintf("- source_prefix: `%s`", source_prefix),
  sprintf("- safe_rhs_tau0: `%s`", format(safe_tau0, scientific = FALSE)),
  sprintf("- index: `%s`", index_path),
  sprintf("- index_manifest: `%s`", index_manifest),
  "",
  "## Purpose",
  "",
  "The original qvbm2 p03 roots all failed with `RHS_NS hypers$tau0 must be > 0.` The p03 structural profile was the strong-shrink check-loss guard, so this repair reruns only that mechanism with a stable lower-bound RHS scale.",
  "",
  "## Policy",
  "",
  "- Original qvbm2 p03 roots remain untouched and refused.",
  "- This repair uses new profile IDs, new root IDs, new results roots, and new run tags.",
  "- The repair is diagnostic only until closeout and explicit promotion.",
  "- No Article-Q-DESN tables should consume this repair directly.",
  "",
  "## Launch",
  "",
  "```bash",
  sprintf("Rscript scripts/orchestrate_qdesn_tt500_vb_mechanism_first_redesign.R --stage-prefix %s --short-path-mode --skip-materialize --skip-audit --workers 16 --full --launch-approved", stage_prefix),
  "```",
  "",
  "## Materialized Bundles",
  "",
  paste(capture.output(print(index[, c("bundle_code", "n_target_specs", "defaults_path", "grid_path")], row.names = FALSE)), collapse = "\n")
)
writeLines(doc_lines, doc_path, useBytes = TRUE)

cat(sprintf("index: %s\n", index_path))
cat(sprintf("index_manifest: %s\n", index_manifest))
cat(sprintf("doc: %s\n", doc_path))
cat(sprintf("total_target_specs: %d\n", sum(index$n_target_specs)))
