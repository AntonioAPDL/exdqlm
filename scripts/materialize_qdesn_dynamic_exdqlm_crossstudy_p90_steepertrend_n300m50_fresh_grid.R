#!/usr/bin/env Rscript

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

base_defaults_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_defaults.yaml"
)
historical_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_full_grid.csv"
)
fresh_defaults_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_storage_light_defaults.yaml"
)
fresh_full_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_grid.csv"
)
fresh_micro_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_micro_smoke_grid.csv"
)
fresh_smoke_grid_path <- file.path(
  "config", "validation", "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_smoke_grid.csv"
)
manifest_path <- file.path(
  "reports", "qdesn_mcmc_validation",
  "dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_validation",
  "prelaunch",
  "qdesn_dynamic_exdqlm_crossstudy_p90_steepertrend_n300m50_fresh_materialization_manifest.txt"
)

rewrite_local_src_paths <- function(x) {
  if (!is.character(x)) return(x)
  home_root <- Sys.getenv("HOME", unset = "")
  if (!nzchar(home_root)) return(x)
  legacy_repo_root <- file.path(home_root, "local", "src", basename(repo_root))
  sub(
    paste0("^", gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", legacy_repo_root)),
    repo_root,
    x
  )
}

write_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

base_lines <- readLines(base_defaults_path, warn = FALSE)
fresh_lines <- base_lines
replace_once <- function(lines, pattern, replacement) {
  hits <- grep(pattern, lines)
  if (!length(hits)) {
    stop(sprintf("Could not find required defaults line matching: %s", pattern), call. = FALSE)
  }
  lines[hits[1L]] <- replacement
  lines
}
fresh_lines <- replace_once(fresh_lines, "^    retention_profile:", "    retention_profile: analysis")
fresh_lines <- replace_once(fresh_lines, "^    save_forecast_objects:", "    save_forecast_objects: no")
fresh_lines <- replace_once(fresh_lines, "^    save_compact_fit_paths:", "    save_compact_fit_paths: yes")
fresh_lines <- replace_once(fresh_lines, "^    save_metric_summaries:", "    save_metric_summaries: yes")
fresh_lines <- replace_once(fresh_lines, "^    retain_full_rds_on_failure:", "    retain_full_rds_on_failure: no")
if (!any(grepl("^paths:", fresh_lines))) {
  fresh_lines <- c(
    fresh_lines,
    "",
    "paths:",
    "  rewrite_home_local_src_to_repo_root: yes"
  )
}
dir.create(dirname(fresh_defaults_path), recursive = TRUE, showWarnings = FALSE)
writeLines(fresh_lines, fresh_defaults_path, useBytes = TRUE)

full_grid <- utils::read.csv(historical_grid_path, stringsAsFactors = FALSE)
if (!nrow(full_grid)) {
  stop("Historical n300/m50 full grid is empty.", call. = FALSE)
}
char_cols <- names(full_grid)[vapply(full_grid, is.character, logical(1))]
for (nm in char_cols) full_grid[[nm]] <- rewrite_local_src_paths(full_grid[[nm]])

required_cols <- c(
  "enabled", "dataset_cell_id", "source_scenario", "source_family", "tau",
  "fit_size", "effective_fit_size", "source_total_size", "source_window_label",
  "beta_prior_type", "source_fit_input_dir", "source_report_root",
  "source_series_wide_path", "source_selection_indices_path", "source_sim_path",
  "reservoir_profile", "seed", "root_id"
)
missing_cols <- setdiff(required_cols, names(full_grid))
if (length(missing_cols)) {
  stop(paste(c("Fresh grid source is missing required columns:", paste0("- ", missing_cols)), collapse = "\n"), call. = FALSE)
}

path_cols <- intersect(
  c("source_fit_input_dir", "source_report_root", "source_series_wide_path", "source_selection_indices_path", "source_sim_path"),
  names(full_grid)
)
path_values <- unique(unlist(full_grid[, path_cols, drop = FALSE], use.names = FALSE))
legacy_hits <- path_values[grepl("/home/.*/local/src", path_values)]
if (length(legacy_hits)) {
  stop(paste(c("Fresh grid still contains legacy /home/.../local/src paths:", paste0("- ", legacy_hits)), collapse = "\n"), call. = FALSE)
}
missing_paths <- path_values[!file.exists(path_values)]
if (length(missing_paths)) {
  stop(paste(c("Fresh grid references missing source paths:", paste0("- ", missing_paths)), collapse = "\n"), call. = FALSE)
}

micro_grid <- full_grid[
  as.character(full_grid$source_family) == "normal" &
    abs(as.numeric(full_grid$tau) - 0.25) < 1e-8 &
    as.integer(full_grid$fit_size) %in% c(500L, 5000L) &
    as.character(full_grid$beta_prior_type) %in% c("ridge", "rhs_ns"),
  ,
  drop = FALSE
]
smoke_grid <- full_grid[abs(as.numeric(full_grid$tau) - 0.25) < 1e-8, , drop = FALSE]
if (!nrow(micro_grid) || !nrow(smoke_grid)) {
  stop("Failed to build fresh micro-smoke or smoke grid.", call. = FALSE)
}

sort_grid <- function(df) {
  prior_order <- match(as.character(df$beta_prior_type), c("ridge", "rhs_ns"))
  prior_order[is.na(prior_order)] <- length(c("ridge", "rhs_ns")) + 1L
  df[order(df$source_family, as.numeric(df$tau), as.integer(df$fit_size), prior_order), , drop = FALSE]
}
full_grid <- sort_grid(full_grid)
micro_grid <- sort_grid(micro_grid)
smoke_grid <- sort_grid(smoke_grid)

fresh_defaults_abs <- normalizePath(fresh_defaults_path, winslash = "/", mustWork = TRUE)
fresh_full_grid_abs <- write_csv(full_grid, fresh_full_grid_path)
fresh_micro_grid_abs <- write_csv(micro_grid, fresh_micro_grid_path)
fresh_smoke_grid_abs <- write_csv(smoke_grid, fresh_smoke_grid_path)

grid_summary <- function(df) {
  c(
    sprintf("rows=%d", nrow(df)),
    sprintf("dataset_cells=%d", length(unique(as.character(df$dataset_cell_id)))),
    sprintf("families=%s", paste(sort(unique(as.character(df$source_family))), collapse = ",")),
    sprintf("taus=%s", paste(sort(unique(as.numeric(df$tau))), collapse = ",")),
    sprintf("fit_sizes=%s", paste(sort(unique(as.integer(df$fit_size))), collapse = ",")),
    sprintf("priors=%s", paste(sort(unique(as.character(df$beta_prior_type))), collapse = ","))
  )
}

dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
manifest_lines <- c(
  "QDESN n300/m50 fresh prelaunch materialization manifest",
  sprintf("generated_at=%s", as.character(Sys.time())),
  sprintf("repo_root=%s", repo_root),
  sprintf("git_sha=%s", trimws(system("git rev-parse --short HEAD", intern = TRUE))),
  sprintf("command=%s", paste(commandArgs(FALSE), collapse = " ")),
  sprintf("base_defaults_path=%s", normalizePath(base_defaults_path, winslash = "/", mustWork = TRUE)),
  sprintf("historical_grid_path=%s", normalizePath(historical_grid_path, winslash = "/", mustWork = TRUE)),
  sprintf("fresh_defaults_path=%s", fresh_defaults_abs),
  sprintf("fresh_full_grid_path=%s", fresh_full_grid_abs),
  sprintf("fresh_micro_grid_path=%s", fresh_micro_grid_abs),
  sprintf("fresh_smoke_grid_path=%s", fresh_smoke_grid_abs),
  "",
  "storage_light_outputs:",
  "retention_profile=analysis",
  "save_forecast_objects=no",
  "save_compact_fit_paths=yes",
  "save_metric_summaries=yes",
  "retain_full_rds_on_failure=no",
  "",
  "full_grid:",
  grid_summary(full_grid),
  "",
  "micro_smoke_grid:",
  grid_summary(micro_grid),
  "",
  "smoke_grid:",
  grid_summary(smoke_grid),
  "",
  "source_path_audit:",
  sprintf("path_columns=%s", paste(path_cols, collapse = ",")),
  "missing_paths=0",
  "legacy_home_local_src_hits=0"
)
writeLines(manifest_lines, manifest_path, useBytes = TRUE)

cat(sprintf("Wrote storage-light defaults: %s\n", fresh_defaults_abs))
cat(sprintf("Wrote fresh full grid: %s\n", fresh_full_grid_abs))
cat(sprintf("Wrote fresh micro-smoke grid: %s\n", fresh_micro_grid_abs))
cat(sprintf("Wrote fresh smoke grid: %s\n", fresh_smoke_grid_abs))
cat(sprintf("Wrote manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("Full rows: %d\n", nrow(full_grid)))
cat(sprintf("Micro-smoke rows: %d\n", nrow(micro_grid)))
cat(sprintf("Smoke rows: %d\n", nrow(smoke_grid)))
