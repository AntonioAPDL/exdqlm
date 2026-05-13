#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
registry_path <- arg_value("registry", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_dataset_registry_%s.csv", run_tag)))
fallback_registry_path <- arg_value("fallback-registry", file.path(repo_root, "tools/merge_reports/LOCAL_refreshed288_dataset_registry_20260429_p90_dynamic72_qdesn_comparable_v2_timeorigin.csv"))
scenario_id <- arg_value("scenario-id", "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")
qdesn_source_root <- arg_value(
  "qdesn-source-root",
  file.path(
    "/data/jaguir26/local/src/exdqlm__wt__qdesn_0p4p0_integration",
    "results/qdesn_mcmc_validation/dynamic_exdqlm_crossstudy_p90_steepertrend_main_sources",
    scenario_id
  )
)
report_dir <- arg_value("report-dir", file.path(repo_root, "reports/static_exal_tuning_20260507"))
out_csv <- arg_value("out-csv", file.path(report_dir, sprintf("refreshed288_dynamic72_source_window_inventory_%s.csv", run_tag)))
out_md <- arg_value("out-md", file.path(report_dir, sprintf("refreshed288_dynamic72_source_window_inventory_%s.md", run_tag)))

source(file.path(repo_root, "tools/merge_reports/LOCAL_refreshed288_helpers_20260422_p90_full288.R"))

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required CSV: ", path, call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

hash_df <- function(x) {
  if (!requireNamespace("digest", quietly = TRUE)) return(NA_character_)
  rownames(x) <- NULL
  digest::digest(x, algo = "sha256")
}

qdesn_total_size <- function(fit_size) {
  if (fit_size == 500L) return(813L)
  if (fit_size == 5000L) return(5313L)
  stop("Unexpected fit_size: ", fit_size, call. = FALSE)
}

qdesn_window_label <- function(fit_size) {
  if (fit_size == 500L) return("effTT500_totalTT813")
  if (fit_size == 5000L) return("effTT5000_totalTT5313")
  stop("Unexpected fit_size: ", fit_size, call. = FALSE)
}

tau_dir <- function(tau_label) paste0("tau_", tau_label)

registry_source <- if (file.exists(registry_path)) registry_path else fallback_registry_path
registry <- rewrite_paths_refreshed288(read_required_csv(registry_source))
registry <- refresh_missing_inputs_refreshed288(registry)
dynamic <- registry[registry$block == "dynamic" & registry$root_kind == "dynamic", , drop = FALSE]

if (nrow(dynamic) != 18L) {
  stop("Expected 18 dynamic source rows, found ", nrow(dynamic), call. = FALSE)
}

rows <- lapply(seq_len(nrow(dynamic)), function(i) {
  row <- dynamic[i, , drop = FALSE]
  fit_size <- as.integer(row$fit_size[1L])
  qdesn_path <- file.path(
    qdesn_source_root,
    row$family[1L],
    tau_dir(row$tau_label[1L]),
    paste0("fit_input_", qdesn_window_label(fit_size)),
    "series_wide.csv"
  )

  canonical_exists <- file.exists(row$series_wide_path[1L])
  qdesn_exists <- file.exists(qdesn_path)
  true_grid_exists <- file.exists(row$true_quantile_grid_path[1L])
  selection_exists <- file.exists(row$selection_indices_path[1L])

  canonical <- if (canonical_exists) read_required_csv(row$series_wide_path[1L]) else data.frame()
  qdesn <- if (qdesn_exists) read_required_csv(qdesn_path) else data.frame()
  qdesn_tail <- if (nrow(qdesn) >= fit_size) utils::tail(qdesn, fit_size) else data.frame()
  common_cols <- intersect(names(canonical), names(qdesn_tail))
  value_cols <- intersect(c("t", "y", "q_target", "mu"), common_cols)
  canonical_hash <- if (length(value_cols) && nrow(canonical)) hash_df(canonical[value_cols]) else NA_character_
  qdesn_tail_hash <- if (length(value_cols) && nrow(qdesn_tail)) hash_df(qdesn_tail[value_cols]) else NA_character_

  source_start <- if ("t" %in% names(canonical) && nrow(canonical)) canonical$t[1L] else NA_integer_
  source_end <- if ("t" %in% names(canonical) && nrow(canonical)) canonical$t[nrow(canonical)] else NA_integer_
  qdesn_tail_start <- if ("t" %in% names(qdesn_tail) && nrow(qdesn_tail)) qdesn_tail$t[1L] else NA_integer_
  qdesn_tail_end <- if ("t" %in% names(qdesn_tail) && nrow(qdesn_tail)) qdesn_tail$t[nrow(qdesn_tail)] else NA_integer_

  status <- "PASS"
  issues <- character()
  if (!canonical_exists) issues <- c(issues, "missing canonical series_wide")
  if (!qdesn_exists) issues <- c(issues, "missing qdesn staged series_wide")
  if (!true_grid_exists) issues <- c(issues, "missing canonical true_quantile_grid")
  if (!selection_exists) issues <- c(issues, "missing canonical selection_indices")
  if (canonical_exists && nrow(canonical) != fit_size) issues <- c(issues, sprintf("canonical rows %d != fit_size %d", nrow(canonical), fit_size))
  if (qdesn_exists && nrow(qdesn) != qdesn_total_size(fit_size)) issues <- c(issues, sprintf("qdesn rows %d != expected %d", nrow(qdesn), qdesn_total_size(fit_size)))
  if (!is.na(source_start) && !is.na(qdesn_tail_start) && source_start != qdesn_tail_start) issues <- c(issues, "source starts differ")
  if (!is.na(source_end) && !is.na(qdesn_tail_end) && source_end != qdesn_tail_end) issues <- c(issues, "source ends differ")
  if (!is.na(canonical_hash) && !is.na(qdesn_tail_hash) && canonical_hash != qdesn_tail_hash) issues <- c(issues, "aligned value hashes differ")
  if (length(issues)) status <- "FAIL"

  data.frame(
    source_cell_id = paste(scenario_id, row$family[1L], row$tau_label[1L], fit_size, sep = "::"),
    scenario = scenario_id,
    family = row$family[1L],
    tau = as.numeric(row$tau[1L]),
    tau_label = row$tau_label[1L],
    effective_fit_size = fit_size,
    exdqlm_source_total_size = fit_size,
    qdesn_source_total_size = qdesn_total_size(fit_size),
    source_index_start = source_start,
    source_index_end = source_end,
    qdesn_tail_index_start = qdesn_tail_start,
    qdesn_tail_index_end = qdesn_tail_end,
    exdqlm_series_wide_path = row$series_wide_path[1L],
    exdqlm_true_quantile_grid_path = row$true_quantile_grid_path[1L],
    exdqlm_selection_indices_path = row$selection_indices_path[1L],
    qdesn_series_wide_path = qdesn_path,
    hash_columns = paste(value_cols, collapse = "|"),
    exdqlm_value_hash = canonical_hash,
    qdesn_tail_value_hash = qdesn_tail_hash,
    status = status,
    issue = if (length(issues)) paste(issues, collapse = "; ") else NA_character_,
    registry_source = registry_source,
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, rows)
out <- out[order(out$family, out$tau, out$effective_fit_size), , drop = FALSE]

dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(out, out_csv, row.names = FALSE, na = "")

overall <- if (all(out$status == "PASS")) "PASS" else "FAIL"
md <- c(
  "# refreshed288 Dynamic72 Source-Window Inventory",
  "",
  sprintf("- Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Registry source: `%s`", registry_source),
  sprintf("- Q-DESN source root: `%s`", qdesn_source_root),
  sprintf("- Overall status: `%s`", overall),
  "",
  "| Family | Tau | Effective Fit Size | Source Start | Source End | Q-DESN Rows | Status | Issue |",
  "| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |"
)
md <- c(md, vapply(seq_len(nrow(out)), function(i) {
  sprintf(
    "| `%s` | %s | %d | %s | %s | %d | `%s` | %s |",
    out$family[i],
    out$tau_label[i],
    out$effective_fit_size[i],
    out$source_index_start[i],
    out$source_index_end[i],
    out$qdesn_source_total_size[i],
    out$status[i],
    ifelse(is.na(out$issue[i]) || !nzchar(out$issue[i]), "", out$issue[i])
  )
}, character(1)))
md <- c(md, "", sprintf("CSV details: `%s`", out_csv), "")
writeLines(md, out_md)

cat(sprintf("source_inventory_status=%s rows=%d\n", overall, nrow(out)))
cat(sprintf("wrote_csv=%s\n", out_csv))
cat(sprintf("wrote_md=%s\n", out_md))
if (!identical(overall, "PASS")) {
  stop("Source-window inventory failed.", call. = FALSE)
}
