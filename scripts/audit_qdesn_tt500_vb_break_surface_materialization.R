#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
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
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)

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
md_table <- function(x, cols = names(x)) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return(c("| none |", "|---|"))
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(x))) {
    vals <- vapply(x[i, cols, drop = FALSE], function(z) {
      zz <- as.character(z)
      zz[is.na(zz)] <- "NA"
      zz
    }, character(1))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}
as_vec <- function(x) unlist(x %||% character(0), use.names = FALSE)
path_has_home_fallback <- function(x) any(grepl("/home/jaguir26/local/src", as.character(x), fixed = TRUE), na.rm = TRUE)
path_has_canonical_root <- function(x) {
  vals <- as.character(x)
  vals <- vals[nzchar(vals) & grepl("^/", vals)]
  if (!length(vals)) return(TRUE)
  all(grepl("^/data/jaguir26/local/src", vals))
}

stage_from_lane <- function(lane) {
  switch(
    lane,
    bridge = "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_bridge",
    newaxis = "qdesn_dynamic_fitforecast_v2_tt500_vb_break_surface_newaxis",
    stop("Unknown lane: ", lane, call. = FALSE)
  )
}

audit_stage <- function(lane) {
  stage <- stage_from_lane(lane)
  paths <- list(
    profiles = file.path("config", "validation", paste0(stage, "_profiles.csv")),
    assignments = file.path("config", "validation", paste0(stage, "_cell_assignments.csv")),
    defaults = file.path("config", "validation", paste0(stage, "_defaults.yaml")),
    grid = file.path("config", "validation", paste0(stage, "_grid.csv")),
    manifest = file.path("config", "validation", paste0(stage, "_materialization_manifest.json"))
  )
  paths <- lapply(paths, resolve_path, must_work = TRUE)
  profiles <- utils::read.csv(paths$profiles, check.names = FALSE, stringsAsFactors = FALSE)
  assignments <- utils::read.csv(paths$assignments, check.names = FALSE, stringsAsFactors = FALSE)
  grid <- utils::read.csv(paths$grid, check.names = FALSE, stringsAsFactors = FALSE)
  defaults <- yaml::read_yaml(paths$defaults)
  manifest <- jsonlite::read_json(paths$manifest, simplifyVector = TRUE)

  problems <- character(0)
  warnings <- character(0)
  required_profile <- c(
    "screening_profile_id", "D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in",
    "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "design_axis",
    "seasonal_feature_mode", "seasonal_period", "seasonal_lag_block", "raw_lag_block",
    "reservoir_width_mode", "likelihood_target", "blocker_target", "source_frontier_row",
    "requires_runner_feature_support", "launch_gate"
  )
  required_assignment <- c(
    "assignment_key", "family", "tau", "likelihood_target", "screening_profile_id",
    "design_lane", "design_axis", "blocker_target", "requires_runner_feature_support"
  )
  missing_profile <- setdiff(required_profile, names(profiles))
  missing_assignment <- setdiff(required_assignment, names(assignments))
  if (length(missing_profile)) problems <- c(problems, paste("profiles missing", paste(missing_profile, collapse = ",")))
  if (length(missing_assignment)) problems <- c(problems, paste("assignments missing", paste(missing_assignment, collapse = ",")))
  if (!nrow(profiles)) problems <- c(problems, "profiles are empty")
  if (!nrow(assignments)) problems <- c(problems, "assignments are empty")
  if (!nrow(grid)) problems <- c(problems, "grid is empty")
  if (anyDuplicated(as.character(profiles$screening_profile_id))) problems <- c(problems, "duplicate profile IDs")
  if (anyDuplicated(as.character(grid$root_id))) problems <- c(problems, "duplicate grid root IDs")
  if (!identical(as.character(defaults$execution$methods %||% ""), "vb")) problems <- c(problems, "defaults execution.methods is not exactly vb")
  if ("mcmc" %in% tolower(as_vec(defaults$execution$methods))) problems <- c(problems, "defaults include mcmc")
  if (isTRUE((defaults$pipeline$outputs %||% list())$save_forecast_objects)) problems <- c(problems, "save_forecast_objects is TRUE")
  if (isTRUE((defaults$pipeline$outputs %||% list())$keep_draws)) problems <- c(problems, "keep_draws is TRUE")

  all_path_text <- c(unlist(paths), unlist(defaults), unlist(manifest), as.matrix(profiles), as.matrix(assignments), as.matrix(grid))
  if (path_has_home_fallback(all_path_text)) problems <- c(problems, "active /home/jaguir26/local/src path found")
  absolute_grid_paths <- unlist(grid[grepl("path|root|dir", names(grid), ignore.case = TRUE)], use.names = FALSE)
  if (!path_has_canonical_root(absolute_grid_paths)) problems <- c(problems, "non-canonical absolute grid path found")

  forbidden <- list.files(
    dirname(paths$grid),
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(forbidden)) problems <- c(problems, sprintf("forbidden binary payload(s) under config dir: %d", length(forbidden)))

  runner_feature_support_required <- any(tolower(as.character(profiles$requires_runner_feature_support)) %in% c("true", "t", "yes", "1"))
  if (runner_feature_support_required) {
    warnings <- c(warnings, "runner feature support required before launching rows with seasonal/harmonic metadata")
  }
  if (identical(lane, "bridge") && any(tolower(as.character(profiles$design_lane)) != "bridge")) {
    problems <- c(problems, "bridge audit found non-bridge design_lane")
  }
  if (identical(lane, "newaxis") && any(tolower(as.character(profiles$design_lane)) != "newaxis")) {
    problems <- c(problems, "newaxis audit found non-newaxis design_lane")
  }

  status <- if (length(problems)) {
    "FAIL"
  } else if (runner_feature_support_required) {
    "DRY_PASS_LAUNCH_BLOCKED"
  } else {
    "DRY_PASS"
  }
  data.frame(
    generated_at = as.character(Sys.time()),
    lane = lane,
    stage_stub = stage,
    status = status,
    n_profiles = nrow(profiles),
    n_assignments = nrow(assignments),
    n_grid_rows = nrow(grid),
    n_likelihood_targets = length(unique(as.character(assignments$likelihood_target))),
    runner_feature_support_required = runner_feature_support_required,
    problems = if (length(problems)) paste(problems, collapse = "; ") else "",
    warnings = if (length(warnings)) paste(warnings, collapse = "; ") else "",
    profiles_path = paths$profiles,
    assignments_path = paths$assignments,
    defaults_path = paths$defaults,
    grid_path = paths$grid,
    manifest_path = paths$manifest,
    stringsAsFactors = FALSE
  )
}

lane_arg <- tolower(as.character(get_arg("--lane", "both"))[1L])
if (!lane_arg %in% c("both", "bridge", "newaxis")) stop("--lane must be one of: both, bridge, newaxis", call. = FALSE)
lanes <- if (identical(lane_arg, "both")) c("bridge", "newaxis") else lane_arg
out_root <- resolve_path(
  get_arg(
    "--out-root",
    "reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_break_surface_redesign_20260713/materialization_audit"
  ),
  must_work = FALSE
)

summary <- do.call(rbind, lapply(lanes, audit_stage))
summary_path <- write_csv(summary, file.path(out_root, "tables", "qdesn_tt500_vb_break_surface_materialization_audit.csv"))
manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    summary_path = summary_path,
    lane_status = summary[, c("lane", "status", "n_profiles", "n_assignments", "n_grid_rows", "runner_feature_support_required")]
  ),
  file.path(out_root, "manifest", "qdesn_tt500_vb_break_surface_materialization_audit_manifest.json")
)
summary_md <- resolve_path(file.path(out_root, "summary", "qdesn_tt500_vb_break_surface_materialization_audit.md"), must_work = FALSE)
dir.create(dirname(summary_md), recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "# Q-DESN VB Break-Surface Materialization Audit",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- repo_root: `%s`", repo_root),
  sprintf("- manifest: `%s`", manifest_path),
  "",
  "## Status",
  "",
  md_table(summary, c("lane", "stage_stub", "status", "n_profiles", "n_assignments", "n_grid_rows", "runner_feature_support_required", "problems", "warnings")),
  "",
  "## Interpretation",
  "",
  "- `DRY_PASS` means the materialized bundle is schema/storage/path safe but still requires explicit human approval before launch.",
  "- `DRY_PASS_LAUNCH_BLOCKED` means the bundle is schema/storage/path safe, but some rows declare design metadata that the current runner must support or explicitly ignore before launch.",
  "- `FAIL` means the bundle should not be launched."
), summary_md)

message("Wrote materialization audit: ", summary_md)
if (any(summary$status == "FAIL")) quit(status = 1L, save = "no")
