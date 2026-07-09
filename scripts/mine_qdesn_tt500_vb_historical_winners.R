#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}
bool_value <- function(x) {
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
safe_num <- function(x) {
  suppressWarnings(as.numeric(x))
}
safe_min <- function(x) {
  x <- safe_num(x)
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  min(x)
}
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
file_manifest <- function(paths) {
  paths <- unique(as.character(unlist(paths, use.names = FALSE)))
  paths <- paths[nzchar(paths)]
  rows <- lapply(paths, function(p) {
    exists <- file.exists(p)
    info <- if (exists) file.info(p) else data.frame(size = NA_real_, mtime = as.POSIXct(NA))
    data.frame(
      path = normalizePath(p, winslash = "/", mustWork = FALSE),
      exists = exists,
      bytes = if (exists) as.numeric(info$size[[1L]]) else NA_real_,
      mtime = if (exists) format(info$mtime[[1L]], "%Y-%m-%d %H:%M:%S %Z") else NA_character_,
      md5 = if (exists && !dir.exists(p)) unname(tools::md5sum(p)) else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
bind_fill <- function(xs) {
  xs <- Filter(Negate(is.null), xs)
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  nms <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    miss <- setdiff(nms, names(x))
    for (nm in miss) x[[nm]] <- NA
    x[nms]
  })
  do.call(rbind, xs)
}
screen_parts <- function(path) {
  rel <- sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", repo_root), "/?"), "", path)
  pieces <- strsplit(rel, "/", fixed = TRUE)[[1L]]
  idx <- match("qdesn_mcmc_validation", pieces)
  data.frame(
    stage = if (is.finite(idx)) pieces[idx + 1L] else NA_character_,
    run_tag = if (is.finite(idx)) pieces[idx + 2L] else NA_character_,
    run_stamp = if (is.finite(idx)) pieces[idx + 3L] else NA_character_,
    stringsAsFactors = FALSE
  )
}
read_dominance_file <- function(path) {
  x <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  parts <- screen_parts(path)
  x$stage <- parts$stage
  x$run_tag <- parts$run_tag
  x$run_stamp <- parts$run_stamp
  x$dominance_cell_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x
}
profile_stage_from_path <- function(path) {
  base <- basename(path)
  sub("_profiles[.]csv$", "", base)
}
preferred_profile_stages <- function(stage) {
  stage <- as.character(stage)[1L]
  out <- stage
  if (identical(stage, "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_refinement")) {
    out <- c(out, "qdesn_dynamic_fitforecast_v2_tt500_vb_dominance_targeted_refinement")
  }
  unique(out)
}
read_profile_file <- function(path) {
  x <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  x$profile_source_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x$profile_source_stage <- profile_stage_from_path(path)
  x
}
profile_base <- function(x) {
  x <- as.character(x)
  x <- sub("_tau0_1em[0-9]+$", "", x)
  x <- sub("_tau0p[0-9]+$", "", x)
  x
}

out_dir <- resolve_path(get_arg("--out-dir", "validation/fitforecast_v2/docs"), must_work = FALSE)
top_per_cell <- int_arg("--top-per-cell", 5L)
if (!is.finite(top_per_cell) || top_per_cell < 1L) top_per_cell <- 5L
include_recent_rhs <- has_flag("--include-recent-rhs")
stamp <- as.character(get_arg("--stamp", "20260709"))[1L]

dominance_files <- list.files(
  file.path(repo_root, "reports", "qdesn_mcmc_validation"),
  pattern = "qdesn_tt500_vb_dominance_cell_summary[.]csv$",
  recursive = TRUE,
  full.names = TRUE
)
if (!length(dominance_files)) stop("No Q-DESN VB dominance cell summaries were found.", call. = FALSE)
dominance <- bind_fill(lapply(dominance_files, read_dominance_file))
ratio_cols <- c(
  "forecast_mae_ratio_vs_best_vb_baseline",
  "forecast_pinball_ratio_vs_best_vb_baseline",
  "fit_rmse_ratio_vs_best_vb_baseline",
  "fit_pinball_ratio_vs_best_vb_baseline"
)
for (nm in ratio_cols) {
  if (!nm %in% names(dominance)) dominance[[nm]] <- NA_real_
  dominance[[nm]] <- safe_num(dominance[[nm]])
}
dominance$max_primary_ratio <- do.call(pmax, c(dominance[ratio_cols], list(na.rm = TRUE)))
dominance$family <- as.character(dominance$family)
dominance$tau <- safe_num(dominance$tau)
dominance$is_recent_rhs_line <- grepl("tt500_vb_rhs", as.character(dominance$stage), fixed = TRUE)
dominance$is_old_broad_line <- !dominance$is_recent_rhs_line
dominance$all_primary_win <- bool_value(dominance$beats_all_primary_baselines)

historical_winners <- dominance[dominance$all_primary_win & (include_recent_rhs | dominance$is_old_broad_line), , drop = FALSE]
if (!nrow(historical_winners)) stop("No historical all-primary winners were found.", call. = FALSE)
historical_winners$screening_profile_base <- as.character(historical_winners$screening_profile_base %||% NA_character_)
if (!"screening_profile_id_representative" %in% names(historical_winners)) {
  historical_winners$screening_profile_id_representative <- NA_character_
}
historical_winners$profile_lookup_id <- historical_winners$screening_profile_base
missing_lookup <- !nzchar(historical_winners$profile_lookup_id) | is.na(historical_winners$profile_lookup_id)
historical_winners$profile_lookup_id[missing_lookup] <- as.character(historical_winners$screening_profile_id_representative[missing_lookup])
historical_winners$profile_lookup_base <- profile_base(historical_winners$profile_lookup_id)

profile_files <- list.files(
  file.path(repo_root, "config", "validation"),
  pattern = "^qdesn_dynamic_fitforecast_v2_tt500_vb_.*_profiles[.]csv$",
  full.names = TRUE
)
if (!length(profile_files)) stop("No committed Q-DESN VB profile CSV files were found.", call. = FALSE)
profiles_raw <- bind_fill(lapply(profile_files, read_profile_file))
if (!"screening_profile_id" %in% names(profiles_raw)) {
  stop("Profile registry has no `screening_profile_id` column.", call. = FALSE)
}
profiles_raw$screening_profile_id <- as.character(profiles_raw$screening_profile_id)
profiles_raw$screening_profile_base <- profile_base(profiles_raw$screening_profile_id)
profiles_raw$profile_missing_core_count <- rowSums(is.na(profiles_raw[intersect(
  c("D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "readout_y_lags", "reservoir_lags", "rhs_tau0"),
  names(profiles_raw)
)]))

core_cols <- c(
  "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w", "pi_in",
  "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count"
)
core_cols <- intersect(core_cols, names(profiles_raw))
profiles_raw$design_signature <- apply(profiles_raw[, core_cols, drop = FALSE], 1L, function(z) paste(as.character(z), collapse = "\r"))
profile_resolution <- aggregate(
  list(
    n_profile_rows = rep(1L, nrow(profiles_raw)),
    n_distinct_designs = profiles_raw$design_signature,
    source_paths = profiles_raw$profile_source_path
  ),
  by = list(screening_profile_base = profiles_raw$screening_profile_base),
  FUN = function(z) {
    if (is.numeric(z)) length(z) else length(unique(as.character(z)))
  }
)
names(profile_resolution)[names(profile_resolution) == "source_paths"] <- "n_source_paths"

choose_profile <- function(profile_id, stage) {
  candidates <- profiles_raw[profiles_raw$screening_profile_base == profile_id, , drop = FALSE]
  if (!nrow(candidates)) {
    return(list(row = NULL, conflict = NULL, strategy = "unresolved"))
  }
  preferred <- preferred_profile_stages(stage)
  stage_candidates <- candidates[candidates$profile_source_stage %in% preferred, , drop = FALSE]
  strategy <- if (nrow(stage_candidates)) "source_stage_exact" else "fallback_any_stage"
  pool <- if (nrow(stage_candidates)) stage_candidates else candidates
  n_designs <- length(unique(as.character(pool$design_signature)))
  pool <- pool[order(pool$profile_missing_core_count, pool$profile_source_stage, pool$profile_source_path), , drop = FALSE]
  conflict <- if (n_designs > 1L) {
    data.frame(
      screening_profile_base = profile_id,
      winner_stage = stage,
      strategy = strategy,
      n_candidate_rows = nrow(pool),
      n_distinct_designs = n_designs,
      candidate_source_stages = paste(unique(pool$profile_source_stage), collapse = ";"),
      candidate_source_paths = paste(unique(pool$profile_source_path), collapse = ";"),
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }
  list(row = pool[1L, , drop = FALSE], conflict = conflict, strategy = strategy)
}
chosen <- lapply(seq_len(nrow(historical_winners)), function(i) {
  choose_profile(historical_winners$profile_lookup_base[[i]], historical_winners$stage[[i]])
})
historical_winners$profile_resolved <- vapply(chosen, function(z) !is.null(z$row) && nrow(z$row) == 1L, logical(1L))
historical_winners$profile_resolution_strategy <- vapply(chosen, function(z) z$strategy, character(1L))
chosen_rows <- lapply(chosen, `[[`, "row")
chosen_rows <- chosen_rows[!vapply(chosen_rows, is.null, logical(1L))]
selected_profiles <- if (length(chosen_rows)) bind_fill(chosen_rows) else data.frame(stringsAsFactors = FALSE)
selected_profiles$winner_row_index <- which(historical_winners$profile_resolved)

resolved <- historical_winners
for (nm in names(profiles_raw)) {
  if (nm %in% c("family", "tau")) next
  out_nm <- if (nm %in% names(resolved)) paste0("profile_", nm) else nm
  resolved[[out_nm]] <- NA
}
for (i in which(resolved$profile_resolved)) {
  p <- chosen[[i]]$row
  for (nm in names(p)) {
    if (nm %in% c("family", "tau")) next
    out_nm <- if (nm %in% names(historical_winners)) paste0("profile_", nm) else nm
    resolved[[out_nm]][[i]] <- p[[nm]][[1L]]
  }
}
resolved$resolved_screening_profile_id <- as.character(resolved$profile_screening_profile_id %||% resolved$screening_profile_id)
resolved$selection_metric <- resolved$max_primary_ratio
resolved$cell_key <- paste(resolved$family, tau_key(resolved$tau), sep = "\r")
resolved <- resolved[order(
  resolved$cell_key,
  resolved$selection_metric,
  resolved$fit_rmse_ratio_vs_best_vb_baseline,
  resolved$forecast_mae_ratio_vs_best_vb_baseline
), , drop = FALSE]
resolved$cell_candidate_rank <- ave(seq_len(nrow(resolved)), resolved$cell_key, FUN = seq_along)

unresolved <- resolved[!resolved$profile_resolved, , drop = FALSE]
selected <- resolved[resolved$profile_resolved & resolved$cell_candidate_rank <= top_per_cell, , drop = FALSE]
selected <- selected[order(selected$family, selected$tau, selected$cell_candidate_rank), , drop = FALSE]
selected$priority_rank <- as.integer(factor(selected$cell_key, levels = unique(selected$cell_key)))
selected$target_profile_rank <- ave(selected$cell_candidate_rank, selected$cell_key, FUN = seq_along)
selected$handoff_cell_status <- "historical_all_primary_win"
selected$handoff_source <- "older_broad_qdesn_vb_screen"

selected_profile_ids <- unique(as.character(selected$resolved_screening_profile_id))
chosen_conflicts <- bind_fill(lapply(chosen, `[[`, "conflict"))
if (!nrow(chosen_conflicts)) chosen_conflicts <- data.frame(stringsAsFactors = FALSE)
profile_conflicts <- if ("screening_profile_base" %in% names(chosen_conflicts)) {
  chosen_conflicts[
    chosen_conflicts$screening_profile_base %in% profile_base(selected_profile_ids),
    ,
    drop = FALSE
  ]
} else {
  data.frame(stringsAsFactors = FALSE)
}

stage_summary <- aggregate(
  list(
    n_rows = dominance$stage,
    all_primary_wins = dominance$all_primary_win,
    min_fit_rmse_ratio = dominance$fit_rmse_ratio_vs_best_vb_baseline,
    min_forecast_mae_ratio = dominance$forecast_mae_ratio_vs_best_vb_baseline
  ),
  by = list(stage = dominance$stage, run_tag = dominance$run_tag, is_recent_rhs_line = dominance$is_recent_rhs_line),
  FUN = function(z) {
    if (is.logical(z)) sum(z, na.rm = TRUE)
    else if (is.numeric(z)) safe_min(z)
    else length(z)
  }
)
stage_summary <- stage_summary[order(stage_summary$is_recent_rhs_line, -stage_summary$all_primary_wins, stage_summary$stage), , drop = FALSE]

coverage <- aggregate(
  list(
    historical_all_primary_wins = historical_winners$all_primary_win,
    selected_handoff_candidates = historical_winners$profile_resolved
  ),
  by = list(family = historical_winners$family, tau = historical_winners$tau),
  FUN = function(z) sum(bool_value(z), na.rm = TRUE)
)
selected_coverage <- aggregate(
  list(n_selected = selected$resolved_screening_profile_id),
  by = list(family = selected$family, tau = selected$tau),
  FUN = length
)
coverage <- merge(coverage, selected_coverage, by = c("family", "tau"), all.x = TRUE, sort = FALSE)
coverage$n_selected[is.na(coverage$n_selected)] <- 0L
coverage <- coverage[order(coverage$family, coverage$tau), , drop = FALSE]

ledger_path <- write_csv(resolved, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_handoff_ledger_", stamp, ".csv")))
selection_path <- write_csv(selected, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_handoff_selected_designs_", stamp, ".csv")))
profile_audit_path <- write_csv(profile_resolution, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_profile_resolution_audit_", stamp, ".csv")))
stage_summary_path <- write_csv(stage_summary, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_stage_summary_", stamp, ".csv")))
coverage_path <- write_csv(coverage, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_cell_coverage_", stamp, ".csv")))
unresolved_path <- write_csv(unresolved, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_unresolved_profiles_", stamp, ".csv")))
conflicts_path <- write_csv(profile_conflicts, file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_profile_conflicts_", stamp, ".csv")))

fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", formatC(as.numeric(x), format = "f", digits = digits))
}
md_table <- function(x, cols) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return("| none |\n|---|")
  y <- x[, cols, drop = FALSE]
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    out <- c(out, paste("|", paste(vapply(y[i, , drop = TRUE], as.character, character(1L)), collapse = " | "), "|"))
  }
  out
}
best_display <- selected[order(selected$selection_metric, selected$fit_rmse_ratio_vs_best_vb_baseline), , drop = FALSE]
best_display$max_ratio <- fmt(best_display$max_primary_ratio)
best_display$fit_rmse_ratio <- fmt(best_display$fit_rmse_ratio_vs_best_vb_baseline)
best_display$forecast_mae_ratio <- fmt(best_display$forecast_mae_ratio_vs_best_vb_baseline)
best_display$forecast_check_ratio <- fmt(best_display$forecast_pinball_ratio_vs_best_vb_baseline)

plan_path <- file.path(out_dir, paste0("QDESN_500OBS_VB_HISTORICAL_WINNER_HANDOFF_PLAN_", sub("(....)(..)(..)", "\\1-\\2-\\3", stamp), ".md"))
plan_lines <- c(
  "# Q-DESN 500-Observation VB Historical-Winner Handoff Plan",
  "",
  "## Decision",
  "",
  "Build a small current-protocol VB handoff from exact older broad-screen designs that already beat the DQLM/exDQLM VB baseline on all four primary criteria. Do not promote rescue-v2 candidates to MCMC, and do not run MCMC from this handoff until the fresh current-protocol VB run passes the same all-primary dominance gate.",
  "",
  "## Evidence Summary",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- dominance_summaries: `%d`", length(dominance_files)),
  sprintf("- all_candidate_rows: `%d`", nrow(dominance)),
  sprintf("- historical_all_primary_winners: `%d`", nrow(historical_winners)),
  sprintf("- selected_top_per_cell: `%d`", top_per_cell),
  sprintf("- selected_handoff_assignments: `%d`", nrow(selected)),
  sprintf("- selected_unique_profiles: `%d`", length(selected_profile_ids)),
  sprintf("- unresolved_historical_winners: `%d`", nrow(unresolved)),
  sprintf("- selected_profile_conflicts: `%d`", nrow(profile_conflicts)),
  "",
  "## Cell Coverage",
  "",
  md_table(coverage, c("family", "tau", "historical_all_primary_wins", "n_selected")),
  "",
  "## Best Selected Designs",
  "",
  md_table(head(best_display, 30), c(
    "family", "tau", "resolved_screening_profile_id", "stage", "run_tag",
    "forecast_mae_ratio", "forecast_check_ratio", "fit_rmse_ratio", "max_ratio"
  )),
  "",
  "## Gates",
  "",
  "1. The selected profiles must resolve to committed profile rows with no selected design conflicts.",
  "2. The materialized handoff must use the current frozen source registry and rolling-origin protocol.",
  "3. The first compute stage is VB-only under `exal` + `rhs_ns`, matching the older winning evidence.",
  "4. MCMC promotion requires a fresh current-protocol dominance table with all four primary ratios below 1 for the target cell.",
  "5. Article tables must not change from this diagnostic handoff unless the handoff completes, strict audit passes, and promotion evidence is explicitly frozen.",
  "",
  "## Output Artifacts",
  "",
  sprintf("- ledger: `%s`", ledger_path),
  sprintf("- selected_designs: `%s`", selection_path),
  sprintf("- profile_resolution_audit: `%s`", profile_audit_path),
  sprintf("- profile_conflicts: `%s`", conflicts_path),
  sprintf("- cell_coverage: `%s`", coverage_path),
  sprintf("- stage_summary: `%s`", stage_summary_path),
  sprintf("- unresolved_profiles: `%s`", unresolved_path)
)
writeLines(plan_lines, plan_path, useBytes = TRUE)
plan_path <- normalizePath(plan_path, winslash = "/", mustWork = TRUE)

manifest_path <- write_json(list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git rev-parse --abbrev-ref HEAD", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  top_per_cell = as.integer(top_per_cell),
  include_recent_rhs = isTRUE(include_recent_rhs),
  dominance_files = as.list(normalizePath(dominance_files, winslash = "/", mustWork = TRUE)),
  profile_files = as.list(normalizePath(profile_files, winslash = "/", mustWork = TRUE)),
  counts = list(
    dominance_summaries = length(dominance_files),
    all_candidate_rows = nrow(dominance),
    historical_all_primary_winners = nrow(historical_winners),
    selected_assignments = nrow(selected),
    selected_unique_profiles = length(selected_profile_ids),
    unresolved_historical_winners = nrow(unresolved),
    selected_profile_conflicts = nrow(profile_conflicts)
  ),
  outputs = list(
    ledger = ledger_path,
    selected_designs = selection_path,
    profile_resolution_audit = profile_audit_path,
    profile_conflicts = conflicts_path,
    cell_coverage = coverage_path,
    stage_summary = stage_summary_path,
    unresolved_profiles = unresolved_path,
    plan = plan_path
  ),
  file_manifest = file_manifest(c(
    ledger_path, selection_path, profile_audit_path, conflicts_path,
    coverage_path, stage_summary_path, unresolved_path, plan_path
  ))
), file.path(out_dir, paste0("qdesn_tt500_vb_historical_winner_handoff_manifest_", stamp, ".json")))

cat(sprintf("ledger: %s\n", ledger_path))
cat(sprintf("selected_designs: %s\n", selection_path))
cat(sprintf("profile_resolution_audit: %s\n", profile_audit_path))
cat(sprintf("profile_conflicts: %s\n", conflicts_path))
cat(sprintf("cell_coverage: %s\n", coverage_path))
cat(sprintf("stage_summary: %s\n", stage_summary_path))
cat(sprintf("plan: %s\n", plan_path))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("historical_all_primary_winners=%d selected_assignments=%d selected_unique_profiles=%d unresolved=%d conflicts=%d\n",
  nrow(historical_winners), nrow(selected), length(selected_profile_ids), nrow(unresolved), nrow(profile_conflicts)
))

if (nrow(unresolved) > 0L) {
  warning(sprintf("There are %d unresolved historical winners; see %s", nrow(unresolved), unresolved_path), call. = FALSE)
}
if (nrow(profile_conflicts) > 0L) {
  stop(sprintf("Selected historical profile IDs have conflicting design definitions; see %s", conflicts_path), call. = FALSE)
}
if (any(coverage$n_selected < 1L)) {
  stop("At least one family/tau cell has no selected historical handoff candidate.", call. = FALSE)
}
