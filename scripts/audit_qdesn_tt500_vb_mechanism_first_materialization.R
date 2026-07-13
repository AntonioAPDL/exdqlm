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
as_vec <- function(x) as.character(unlist(x %||% character(0), use.names = FALSE))
has_home_fallback <- function(x) any(grepl("/home/jaguir26/local/src", as.character(x), fixed = TRUE), na.rm = TRUE)
all_canonical_paths <- function(x) {
  vals <- as.character(x)
  vals <- vals[nzchar(vals) & grepl("^/", vals)]
  if (!length(vals)) return(TRUE)
  all(grepl("^/data/jaguir26/local/src", vals))
}
boolish <- function(x) tolower(as.character(x)) %in% c("true", "t", "yes", "y", "1")
tau_key <- function(x) sprintf("%.8f", as.numeric(x))

stage_prefix <- get_arg("--stage-prefix", "qdesn_dynamic_fitforecast_v2_tt500_vb_mechanism_first")
index_path <- resolve_path(get_arg("--index", file.path("config", "validation", paste0(stage_prefix, "_bundle_index.csv"))), must_work = TRUE)
out_root <- resolve_path(
  get_arg(
    "--out-root",
    "reports/qdesn_mcmc_validation/posthoc/qdesn_tt500_vb_mechanism_first_20260713/materialization_audit"
  ),
  must_work = FALSE
)

index <- utils::read.csv(index_path, check.names = FALSE, stringsAsFactors = FALSE)
if (!nrow(index)) stop("Mechanism-first bundle index is empty.", call. = FALSE)

audit_bundle <- function(row) {
  problems <- character(0)
  warnings <- character(0)
  bundle_id <- as.character(row$bundle_id[[1L]])
  defaults_path <- resolve_path(row$defaults_path[[1L]], must_work = TRUE)
  grid_path <- resolve_path(row$grid_path[[1L]], must_work = TRUE)
  profiles_path <- resolve_path(row$profiles_path[[1L]], must_work = TRUE)
  assignments_path <- resolve_path(row$assignments_path[[1L]], must_work = TRUE)
  target_path <- resolve_path(row$target_spec_ids_path[[1L]], must_work = TRUE)
  manifest_path <- resolve_path(row$manifest_path[[1L]], must_work = TRUE)

  defaults <- yaml::read_yaml(defaults_path)
  grid <- utils::read.csv(grid_path, check.names = FALSE, stringsAsFactors = FALSE)
  profiles <- utils::read.csv(profiles_path, check.names = FALSE, stringsAsFactors = FALSE)
  assignments <- utils::read.csv(assignments_path, check.names = FALSE, stringsAsFactors = FALSE)
  target_specs <- utils::read.csv(target_path, check.names = FALSE, stringsAsFactors = FALSE)
  manifest <- jsonlite::read_json(manifest_path, simplifyVector = TRUE)

  required_profile <- c(
    "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
    "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
    "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500",
    "target_family", "target_tau", "likelihood_target", "design_bundle",
    "design_axis", "blocker_target"
  )
  required_assignment <- c(
    "assignment_key", "family", "tau", "likelihood_target", "screening_profile_id",
    "design_bundle", "design_axis", "blocker_target"
  )
  required_target <- c("root_id", "likelihood_target", "screening_profile_id", "family", "tau", "spec_id")
  miss_profile <- setdiff(required_profile, names(profiles))
  miss_assignment <- setdiff(required_assignment, names(assignments))
  miss_target <- setdiff(required_target, names(target_specs))
  if (length(miss_profile)) problems <- c(problems, paste("profiles missing", paste(miss_profile, collapse = ",")))
  if (length(miss_assignment)) problems <- c(problems, paste("assignments missing", paste(miss_assignment, collapse = ",")))
  if (length(miss_target)) problems <- c(problems, paste("target specs missing", paste(miss_target, collapse = ",")))
  if (!nrow(profiles)) problems <- c(problems, "profiles empty")
  if (!nrow(assignments)) problems <- c(problems, "assignments empty")
  if (!nrow(grid)) problems <- c(problems, "grid empty")
  if (!nrow(target_specs)) problems <- c(problems, "target spec list empty")
  if (anyDuplicated(as.character(profiles$screening_profile_id))) problems <- c(problems, "duplicate profile IDs")
  if (anyDuplicated(as.character(grid$root_id))) problems <- c(problems, "duplicate root IDs")
  if (nrow(target_specs) != nrow(grid)) problems <- c(problems, sprintf("target specs %d != grid rows %d", nrow(target_specs), nrow(grid)))

  methods <- tolower(as_vec(defaults$execution$methods))
  likelihoods <- sort(unique(tolower(as_vec(defaults$execution$likelihood_families))))
  allowed <- as_vec((defaults$execution %||% list())$allowed_fit_spec_ids)
  if (!identical(methods, "vb")) problems <- c(problems, paste("methods are not exactly VB:", paste(methods, collapse = ",")))
  if ("mcmc" %in% methods) problems <- c(problems, "MCMC is active")
  if (!identical(likelihoods, c("al", "exal"))) problems <- c(problems, paste("unexpected likelihood scope", paste(likelihoods, collapse = ",")))
  if (!length(allowed)) problems <- c(problems, "allowed_fit_spec_ids missing")
  if (length(setdiff(as.character(target_specs$spec_id), allowed))) problems <- c(problems, "target spec IDs not fully present in defaults allowed_fit_spec_ids")

  pipeline <- defaults$pipeline %||% list()
  readout <- pipeline$readout %||% list()
  decomp <- pipeline$decomposition %||% list()
  input_mode <- tolower(as.character(readout$input_mode %||% "raw_y_lags")[1L])
  decomp_enabled <- isTRUE(decomp$enabled %||% FALSE)
  input_builder <- tolower(as.character(decomp$input_builder %||% "component_lags")[1L])
  residual_recursion <- tolower(as.character(((decomp$forecast %||% list())$residual_recursion %||% "sampled_path")[1L]))
  harmonics <- as.integer(as_vec((decomp$seasonal %||% list())$harmonics %||% integer(0)))
  period <- suppressWarnings(as.integer((decomp$seasonal %||% list())$period %||% NA_integer_)[1L])
  deterministic_harmonics <- as.integer(as_vec((defaults$deterministic_features %||% list())$harmonics %||% integer(0)))

  if (identical(bundle_id, "raw_period90_control")) {
    if (!identical(input_mode, "raw_y_lags")) problems <- c(problems, "raw control does not use raw_y_lags")
    if (isTRUE(decomp_enabled)) problems <- c(problems, "raw control unexpectedly enables decomposition")
  } else {
    if (!identical(input_mode, "dlm_decomp_lags")) problems <- c(problems, "decomposition bundle does not use dlm_decomp_lags")
    if (!isTRUE(decomp_enabled)) problems <- c(problems, "decomposition bundle has decomposition.enabled FALSE")
    if (!input_builder %in% c("component_lags", "state_resid_y")) problems <- c(problems, paste("invalid input_builder", input_builder))
    if (!is.finite(period) || period != 90L) problems <- c(problems, "decomposition seasonal period is not 90")
    if (grepl("h123", bundle_id) && !all(c(1L, 2L, 3L) %in% harmonics)) problems <- c(problems, "h123 bundle missing harmonics 1,2,3")
    if (!grepl("h123", bundle_id) && !all(c(1L, 2L) %in% harmonics)) problems <- c(problems, "h12 bundle missing harmonics 1,2")
    if (grepl("component", bundle_id) && !identical(input_builder, "component_lags")) problems <- c(problems, "component bundle does not use component_lags")
    if (grepl("state_resid_y", bundle_id) && !identical(input_builder, "state_resid_y")) problems <- c(problems, "state_resid_y bundle does not use state_resid_y")
    if (grepl("plugin", bundle_id) && !identical(residual_recursion, "deterministic_plugin")) problems <- c(problems, "plugin bundle does not use deterministic_plugin recursion")
    if (!grepl("plugin", bundle_id) && !identical(residual_recursion, "sampled_path")) problems <- c(problems, "sampled-path bundle changed residual recursion")
  }
  if (!all(c(1L, 2L) %in% deterministic_harmonics)) problems <- c(problems, "deterministic period-90 harmonics 1,2 not active")

  if (isTRUE((pipeline$outputs %||% list())$save_forecast_objects)) problems <- c(problems, "save_forecast_objects TRUE")
  if (isTRUE((pipeline$outputs %||% list())$keep_draws)) problems <- c(problems, "keep_draws TRUE")
  if (isTRUE((pipeline$outputs %||% list())$save_fit_objects)) problems <- c(problems, "save_fit_objects TRUE")

  all_text <- c(
    defaults_path, grid_path, profiles_path, assignments_path, target_path, manifest_path,
    unlist(defaults), unlist(manifest), as.matrix(grid), as.matrix(profiles),
    as.matrix(assignments), as.matrix(target_specs)
  )
  if (has_home_fallback(all_text)) problems <- c(problems, "active /home/jaguir26/local/src path found")
  absolute_text <- all_text[grepl("^/", as.character(all_text))]
  if (!all_canonical_paths(absolute_text)) problems <- c(problems, "non-canonical absolute path found")

  forbidden <- list.files(
    dirname(grid_path),
    pattern = "(__design[.]rds|[.](rds|rda|RData))$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(forbidden)) problems <- c(problems, sprintf("forbidden binary payload(s) under config dir: %d", length(forbidden)))

  defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_path)
  atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
    grid,
    defaults = defaults_loaded,
    methods = defaults_loaded$execution$methods %||% "vb",
    likelihood_families = defaults_loaded$execution$likelihood_families %||% c("al", "exal")
  )
  if (length(setdiff(as.character(target_specs$spec_id), as.character(atomic$spec_id)))) {
    problems <- c(problems, "target spec IDs are not in atomic spec grid")
  }
  target_lik_by_root <- paste(target_specs$root_id, target_specs$likelihood_target, sep = "\r")
  if (anyDuplicated(target_lik_by_root)) problems <- c(problems, "duplicate root/likelihood target spec")
  if (!all(tolower(as.character(target_specs$likelihood_target)) %in% c("al", "exal"))) {
    problems <- c(problems, "target likelihood outside al/exal")
  }

  status <- if (length(problems)) "FAIL" else "DRY_PASS"
  data.frame(
    generated_at = as.character(Sys.time()),
    bundle_id = bundle_id,
    status = status,
    stage_stub = as.character(row$stage_stub[[1L]]),
    input_mode = input_mode,
    decomposition_enabled = decomp_enabled,
    input_builder = input_builder,
    residual_recursion = residual_recursion,
    seasonal_period = period,
    seasonal_harmonics = paste(harmonics, collapse = ","),
    deterministic_harmonics = paste(deterministic_harmonics, collapse = ","),
    n_profiles = nrow(profiles),
    n_assignments = nrow(assignments),
    n_grid_rows = nrow(grid),
    n_target_specs = nrow(target_specs),
    n_allowed_spec_ids = length(allowed),
    n_atomic_specs = nrow(atomic),
    problems = if (length(problems)) paste(problems, collapse = "; ") else "",
    warnings = if (length(warnings)) paste(warnings, collapse = "; ") else "",
    defaults_path = defaults_path,
    grid_path = grid_path,
    profiles_path = profiles_path,
    assignments_path = assignments_path,
    target_spec_ids_path = target_path,
    manifest_path = manifest_path,
    stringsAsFactors = FALSE
  )
}

summary <- do.call(rbind, lapply(seq_len(nrow(index)), function(i) audit_bundle(index[i, , drop = FALSE])))
summary_path <- write_csv(summary, file.path(out_root, "tables", "qdesn_tt500_vb_mechanism_first_materialization_audit.csv"))
manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
    git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
    git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
    index_path = index_path,
    summary_path = summary_path,
    status_counts = as.list(table(summary$status)),
    total_target_specs = sum(as.integer(summary$n_target_specs)),
    bundle_status = summary[, c("bundle_id", "status", "input_mode", "input_builder", "n_grid_rows", "n_target_specs")]
  ),
  file.path(out_root, "manifest", "qdesn_tt500_vb_mechanism_first_materialization_audit_manifest.json")
)
summary_md <- resolve_path(file.path(out_root, "summary", "qdesn_tt500_vb_mechanism_first_materialization_audit.md"), must_work = FALSE)
dir.create(dirname(summary_md), recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "# Q-DESN VB Mechanism-First Materialization Audit",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- repo_root: `%s`", repo_root),
  sprintf("- index: `%s`", index_path),
  sprintf("- manifest: `%s`", manifest_path),
  sprintf("- total_target_specs: `%d`", sum(as.integer(summary$n_target_specs))),
  "",
  "## Status",
  "",
  md_table(summary, c("bundle_id", "status", "input_mode", "decomposition_enabled", "input_builder", "residual_recursion", "seasonal_harmonics", "n_grid_rows", "n_target_specs", "problems")),
  "",
  "## Interpretation",
  "",
  "- `DRY_PASS` means the bundle is VB-only, storage-light, exact-spec scoped, and mechanism settings are active in defaults.",
  "- The audit does not make any result article-facing. Promotion still requires completed run evidence and strict ranking/audit."
), summary_md)

message("Wrote materialization audit: ", summary_md)
if (any(summary$status == "FAIL")) quit(status = 1L, save = "no")
