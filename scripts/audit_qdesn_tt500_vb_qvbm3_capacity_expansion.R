#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

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

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))

md_table <- function(df, cols = names(df), max_rows = Inf) {
  if (!nrow(df)) return("_No rows._")
  cols <- intersect(cols, names(df))
  x <- df[, cols, drop = FALSE]
  if (is.finite(max_rows) && nrow(x) > max_rows) x <- utils::head(x, max_rows)
  x[] <- lapply(x, function(col) {
    if (is.numeric(col)) {
      ifelse(is.na(col), "", format(round(col, 4), trim = TRUE, scientific = FALSE))
    } else {
      val <- as.character(col)
      val[is.na(val)] <- ""
      val
    }
  })
  header <- paste0("| ", paste(cols, collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", length(cols)), collapse = "|"), "|")
  rows <- apply(x, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(header, sep, rows), collapse = "\n")
}

paths <- list(
  baseline_freeze = "validation/fitforecast_v2/docs/qdesn_tt500_vb_active_baseline_freeze_20260715.csv",
  screen_disposition = "validation/fitforecast_v2/docs/qdesn_tt500_vb_screen_disposition_20260715.csv",
  qvbm1_comparison = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_current_table_comparison.csv",
  qvbm1_ranked = "reports/qvbm1/audit/closeout/qvbm1_decomp_guardfix_20260713_main__git-8c6eda9/tables/qvbm1_mechanism_first_ranked_candidates.csv",
  qvbm2_ratios = "reports/qvbm2/audit/closeout/qvbm2_blocker_aware_20260714__git-33f8a87/tables/qvbm2_ratio_breakdown.csv",
  qvbm2p3_ratios = "reports/qvbm2p3/audit/closeout/qvbm2p3_safe_floor_20260715/tables/qvbm2_ratio_breakdown.csv"
)

for (nm in names(paths)) {
  if (!file.exists(resolve_path(paths[[nm]], must_work = FALSE))) {
    stop(sprintf("Missing qvbm3 audit input `%s`: %s", nm, paths[[nm]]), call. = FALSE)
  }
}

baseline_freeze <- utils::read.csv(resolve_path(paths$baseline_freeze), stringsAsFactors = FALSE, check.names = FALSE)
screen_disposition <- utils::read.csv(resolve_path(paths$screen_disposition), stringsAsFactors = FALSE, check.names = FALSE)
qvbm1 <- utils::read.csv(resolve_path(paths$qvbm1_comparison), stringsAsFactors = FALSE, check.names = FALSE)
qvbm2 <- utils::read.csv(resolve_path(paths$qvbm2_ratios), stringsAsFactors = FALSE, check.names = FALSE)
qvbm2p3 <- utils::read.csv(resolve_path(paths$qvbm2p3_ratios), stringsAsFactors = FALSE, check.names = FALSE)

if (!identical(as.character(baseline_freeze$active_vb_calibration_baseline[[1L]]), "qvbm1")) {
  stop("qvbm1 is not frozen as the active baseline; refusing qvbm3 audit.", call. = FALSE)
}
if (any(as.character(screen_disposition$screen) %in% c("qvbm2", "qvbm2p3") &
        as.character(screen_disposition$role) != "DIAGNOSTIC_ONLY")) {
  stop("qvbm2/qvbm2p3 disposition is not diagnostic-only; refusing qvbm3 audit.", call. = FALSE)
}

ratio_cols <- grep("^ratio_vs_best_exdqlm_dqlm_vb_", names(qvbm1), value = TRUE)
if (length(ratio_cols) != 4L) stop("Expected four external qvbm1 ratio columns.", call. = FALSE)
qvbm1$external_joint_worst_ratio <- do.call(pmax, c(qvbm1[ratio_cols], list(na.rm = TRUE)))
qvbm1$qvbm1_joint_worst_ratio <- num(qvbm1$qvbm1_joint_worst_ratio)
qvbm1$cell_key <- paste(qvbm1$family, sprintf("%.8f", num(qvbm1$tau)), qvbm1$qdesn_likelihood, sep = "\r")
qvbm1$failed_external_metrics <- apply(qvbm1[, ratio_cols, drop = FALSE], 1L, function(row) {
  bad <- sub("^ratio_vs_best_exdqlm_dqlm_vb_", "", names(row)[num(row) >= 1])
  if (!length(bad)) "none" else paste(bad, collapse = ";")
})
qvbm1$cell_class <- ifelse(qvbm1$external_joint_worst_ratio >= 1.25, "hard",
  ifelse(qvbm1$external_joint_worst_ratio >= 1.05, "near_hard", "near"))
qvbm1$recommended_qvbm3_scope <- ifelse(qvbm1$cell_class == "hard", "capacity_canary_required",
  "capacity_canary_optional_bridge")

cell_blockers <- data.frame(
  family = as.character(qvbm1$family),
  tau = num(qvbm1$tau),
  likelihood_target = as.character(qvbm1$qdesn_likelihood),
  qvbm1_bundle = as.character(qvbm1$qvbm1_bundle),
  qvbm1_profile = as.character(qvbm1$qvbm1_profile),
  qvbm1_joint_worst_ratio = qvbm1$qvbm1_joint_worst_ratio,
  external_joint_worst_ratio = qvbm1$external_joint_worst_ratio,
  failed_external_metrics = qvbm1$failed_external_metrics,
  cell_class = qvbm1$cell_class,
  recommended_qvbm3_scope = qvbm1$recommended_qvbm3_scope,
  stringsAsFactors = FALSE
)

qvbm2$key <- paste(qvbm2$family_screen, sprintf("%.8f", num(qvbm2$tau_screen)), qvbm2$likelihood_family, sep = "\r")
qvbm2p3$key <- paste(qvbm2p3$family_screen, sprintf("%.8f", num(qvbm2p3$tau_screen)), qvbm2p3$likelihood_family, sep = "\r")
cell_blockers$qvbm2_best_external_joint <- vapply(seq_len(nrow(cell_blockers)), function(i) {
  key <- paste(cell_blockers$family[[i]], sprintf("%.8f", cell_blockers$tau[[i]]), cell_blockers$likelihood_target[[i]], sep = "\r")
  z <- qvbm2[qvbm2$key == key, , drop = FALSE]
  if (!nrow(z)) return(NA_real_)
  min(do.call(pmax, c(z[, grep("^ratio_vs_exdqlm_", names(z), value = TRUE), drop = FALSE], list(na.rm = TRUE))), na.rm = TRUE)
}, numeric(1L))
cell_blockers$qvbm2p3_best_external_joint <- vapply(seq_len(nrow(cell_blockers)), function(i) {
  key <- paste(cell_blockers$family[[i]], sprintf("%.8f", cell_blockers$tau[[i]]), cell_blockers$likelihood_target[[i]], sep = "\r")
  z <- qvbm2p3[qvbm2p3$key == key, , drop = FALSE]
  if (!nrow(z)) return(NA_real_)
  min(do.call(pmax, c(z[, grep("^ratio_vs_exdqlm_", names(z), value = TRUE), drop = FALSE], list(na.rm = TRUE))), na.rm = TRUE)
}, numeric(1L))
cell_blockers$diagnostic_screen_conclusion <- ifelse(
  is.finite(cell_blockers$qvbm2_best_external_joint) & cell_blockers$qvbm2_best_external_joint < 1,
  "diagnostic_candidate_cleared_external_gate",
  "diagnostic_screens_do_not_clear_external_gate"
)

profile_files <- list.files("config/validation", pattern = "(qdesn|qvbm).*profiles[.]csv$", full.names = TRUE)
profile_rows <- list()
for (f in profile_files) {
  x <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(x) || !all(c("D", "n_each", "m") %in% names(x))) next
  get <- function(nm) if (nm %in% names(x)) num(x[[nm]]) else rep(NA_real_, nrow(x))
  profile_rows[[length(profile_rows) + 1L]] <- data.frame(
    file = f,
    n_rows = nrow(x),
    max_D = max(get("D"), na.rm = TRUE),
    max_n_each = max(get("n_each"), na.rm = TRUE),
    max_total_units = max(get("D") * get("n_each"), na.rm = TRUE),
    max_m = max(get("m"), na.rm = TRUE),
    max_readout_y_lags = max(get("readout_y_lags"), na.rm = TRUE),
    max_dimension_p_estimate = max(get("dimension_p_estimate"), na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}
profile_maxima_by_file <- do.call(rbind, profile_rows)
for (j in names(profile_maxima_by_file)) {
  if (is.numeric(profile_maxima_by_file[[j]])) profile_maxima_by_file[[j]][is.infinite(profile_maxima_by_file[[j]])] <- NA_real_
}
historical_maxima <- data.frame(
  max_D = max(profile_maxima_by_file$max_D, na.rm = TRUE),
  max_n_each = max(profile_maxima_by_file$max_n_each, na.rm = TRUE),
  max_total_units = max(profile_maxima_by_file$max_total_units, na.rm = TRUE),
  max_m = max(profile_maxima_by_file$max_m, na.rm = TRUE),
  max_readout_y_lags = max(profile_maxima_by_file$max_readout_y_lags, na.rm = TRUE),
  max_dimension_p_estimate = max(profile_maxima_by_file$max_dimension_p_estimate, na.rm = TRUE),
  stringsAsFactors = FALSE
)

capacity_tiers <- data.frame(
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
  m = c(60L, 90L, 150L, 60L, 90L, 150L, 150L, 90L, 150L),
  readout_y_lags = c(60L, 90L, 150L, 60L, 90L, 150L, 150L, 90L, 150L),
  initial_policy = c(
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
capacity_tiers$dimension_p_estimate <- 1L + capacity_tiers$D * capacity_tiers$n_each + capacity_tiers$readout_y_lags + 5L
capacity_tiers$p_over_n_tt500 <- capacity_tiers$dimension_p_estimate / 500
capacity_tiers$capacity_tier <- ifelse(capacity_tiers$p_over_n_tt500 <= 0.75, "green",
  ifelse(capacity_tiers$p_over_n_tt500 <= 1.50, "amber", "red"))

out_dir <- file.path("reports", "qvbm3_capacity", "audit", "qvbm3_capacity_prelaunch_20260715")
tables_dir <- file.path(out_dir, "tables")
summary_dir <- file.path(out_dir, "summary")
manifest_dir <- file.path(out_dir, "manifest")

cell_blockers_path <- write_csv(cell_blockers, file.path(tables_dir, "qvbm3_current_cell_blockers.csv"))
profile_maxima_path <- write_csv(profile_maxima_by_file, file.path(tables_dir, "qvbm3_historical_profile_maxima_by_file.csv"))
historical_maxima_path <- write_csv(historical_maxima, file.path(tables_dir, "qvbm3_historical_profile_maxima.csv"))
capacity_tiers_path <- write_csv(capacity_tiers, file.path(tables_dir, "qvbm3_capacity_tiers.csv"))

manifest_path <- write_json(
  list(
    generated_at = as.character(Sys.time()),
    repo_root = repo_root,
    git_branch = system("git branch --show-current", intern = TRUE)[[1L]],
    git_sha = system("git rev-parse HEAD", intern = TRUE)[[1L]],
    inputs = lapply(paths, resolve_path),
    outputs = list(
      cell_blockers = cell_blockers_path,
      profile_maxima_by_file = profile_maxima_path,
      historical_maxima = historical_maxima_path,
      capacity_tiers = capacity_tiers_path
    ),
    hashes = list(
      cell_blockers_sha256 = sha256_file(cell_blockers_path),
      profile_maxima_by_file_sha256 = sha256_file(profile_maxima_path),
      historical_maxima_sha256 = sha256_file(historical_maxima_path),
      capacity_tiers_sha256 = sha256_file(capacity_tiers_path)
    ),
    conclusion = list(
      qvbm1_rows_audited = nrow(qvbm1),
      hard_or_near_hard_cells = sum(cell_blockers$cell_class %in% c("hard", "near_hard")),
      qvbm3_initial_target_cells = nrow(cell_blockers),
      historical_max_D = historical_maxima$max_D[[1L]],
      historical_max_n_each = historical_maxima$max_n_each[[1L]],
      historical_max_m = historical_maxima$max_m[[1L]],
      qvbm3_requested_max_D = 4L,
      qvbm3_requested_max_n_each = 300L,
      qvbm3_requested_max_m = 150L,
      recommendation = "Proceed to qvbm3 design/materialization as a VB-only hard-cell capacity canary; do not launch MCMC."
    )
  ),
  file.path(manifest_dir, "qvbm3_capacity_prelaunch_audit_manifest.json")
)

summary_path <- resolve_path(file.path(summary_dir, "qvbm3_capacity_prelaunch_audit.md"), must_work = FALSE)
dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "# QVBM3 Capacity Expansion Prelaunch Audit",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- worktree: `%s`", repo_root),
  sprintf("- branch: `%s`", system("git branch --show-current", intern = TRUE)[[1L]]),
  sprintf("- head: `%s`", system("git rev-parse HEAD", intern = TRUE)[[1L]]),
  sprintf("- manifest: `%s`", manifest_path),
  "",
  "## Diagnosis",
  "",
  "- The current active Q-DESN VB baseline is `qvbm1`.",
  "- `qvbm2` and `qvbm2p3` are diagnostic-only and do not clear the external all-four gate.",
  "- The qvbm3 experiment should test capacity as a new design axis, not promote any existing diagnostic screen.",
  "- The first qvbm3 launch should be a VB-only hard-cell canary with red-tier caps.",
  "",
  "## Historical Maxima",
  "",
  md_table(historical_maxima),
  "",
  "## Current Target Cells",
  "",
  md_table(cell_blockers, c("family", "tau", "likelihood_target", "qvbm1_bundle", "qvbm1_profile", "external_joint_worst_ratio", "failed_external_metrics", "cell_class", "recommended_qvbm3_scope")),
  "",
  "## Capacity Tiers",
  "",
  md_table(capacity_tiers, c("profile_role", "D", "n_each", "m", "dimension_p_estimate", "p_over_n_tt500", "capacity_tier", "initial_policy")),
  "",
  "## Recommendation",
  "",
  "Materialize qvbm3 as a VB-only hard-cell capacity canary. Keep the winning qvbm1 mechanism bundle for each cell, test green/amber capacity rows broadly, and include red-tier rows only as capped stress canaries. Do not launch MCMC from this stage."
), summary_path, useBytes = TRUE)

cat(sprintf("cell_blockers: %s\n", cell_blockers_path))
cat(sprintf("capacity_tiers: %s\n", capacity_tiers_path))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("manifest: %s\n", manifest_path))
cat("qvbm3_prelaunch_audit=PASS\n")
