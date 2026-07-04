#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
run_tag <- args$`run-tag` %||% ffv2_c13_mcmc_default_run_tag()
default_run_root <- file.path(ffv2_repo_root(), "validation/fitforecast_v2/runs", run_tag)
manifest_path <- args$manifest %||% file.path(default_run_root, "manifests", "row_manifest.csv")
interface_path <- args$interface %||% file.path(default_run_root, "interfaces", "exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
out_csv <- args$`out-csv` %||% file.path(ffv2_harness_root(), "docs", "exdqlm_dqlm_c13_mcmc_500obs_refresh_summary_20260704.csv")
out_md <- args$`out-md` %||% file.path(ffv2_harness_root(), "docs", "EXDQLM_DQLM_C13_MCMC_500OBS_REFRESH_AUDIT_2026-07-04.md")
allow_incomplete <- ffv2_truthy(args$`allow-incomplete` %||% FALSE)
stale_seconds <- as.integer(args$`healthcheck-stale-seconds` %||% 1800L)

manifest <- ffv2_read_csv(normalizePath(manifest_path, winslash = "/", mustWork = TRUE))
run_root <- unique(manifest$run_root)[[1L]]
if (!file.exists(interface_path)) {
  interface <- ffv2_export_shared_interface(manifest, interface_path)
} else {
  interface <- ffv2_read_csv(interface_path)
}

c13_all <- ffv2_c13_mcmc_interface_rows(interface)
c13_done <- c13_all[
  as.character(c13_all$status) == "done" &
    as.character(c13_all$health_gate) == "PASS",
  ,
  drop = FALSE
]
summary <- ffv2_c13_mcmc_cell_summary(c13_done)
issues <- ffv2_validate_c13_mcmc_interface(c13_done)
missing_cells <- ffv2_c13_mcmc_missing_cells(c13_done)

status_counts <- ffv2_status_counts(manifest)
telemetry <- ffv2_telemetry_summary(manifest, stale_seconds = stale_seconds)
storage <- ffv2_storage_audit(run_root)

if (nrow(summary)) ffv2_write_csv(summary, out_csv) else ffv2_write_csv(data.frame(), out_csv)
issues_path <- sub("[.]csv$", "_issues.csv", out_csv)
ffv2_write_csv(
  data.frame(issue = if (length(issues)) issues else "none", stringsAsFactors = FALSE),
  issues_path
)
missing_path <- sub("[.]csv$", "_missing_cells.csv", out_csv)
ffv2_write_csv(missing_cells, missing_path)

git <- ffv2_git_info()
fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}
cell_count <- if (nrow(c13_done)) length(unique(ffv2_c13_mcmc_cell_key(c13_done))) else 0L
lead_rows <- nrow(c13_done)
md <- c(
  "# exDQLM/DQLM c13 MCMC 500-Observation Refresh Audit",
  "",
  "Date: 2026-07-04",
  "",
  "## Scope",
  "",
  "This audit checks the current-best c13 exDQLM/DQLM MCMC refresh lane for the 500-observation rolling-origin simulation comparison. It is not an Article-facing promotion unless the complete 18-cell by 30-lead grid is done/PASS and then materialized by the promotion script.",
  "",
  "## Inputs",
  "",
  paste0("- validation worktree: `", git$repo_root, "`"),
  paste0("- validation branch: `", git$branch, "`"),
  paste0("- validation HEAD at audit generation: `", git$head, "`"),
  paste0("- validation HEAD subject: `", git$subject, "`"),
  paste0("- manifest: `", normalizePath(manifest_path, winslash = "/", mustWork = TRUE), "`"),
  paste0("- shared interface: `", normalizePath(interface_path, winslash = "/", mustWork = file.exists(interface_path)), "`"),
  paste0("- run root: `", run_root, "`"),
  "",
  "## Evidence Counts",
  "",
  paste0("- done/PASS c13 MCMC cells: `", cell_count, "/18`"),
  paste0("- done/PASS c13 MCMC lead rows: `", lead_rows, "/540`"),
  paste0("- missing cells: `", nrow(missing_cells), "`"),
  paste0("- audit issues: `", length(issues), "`"),
  "",
  "## Status Counts",
  "",
  "| Status | Rows |",
  "| --- | ---: |"
)
if (nrow(status_counts)) {
  for (ii in seq_len(nrow(status_counts))) {
    md <- c(md, paste0("| ", status_counts$statuses[[ii]], " | ", status_counts$Freq[[ii]], " |"))
  }
}
if (nrow(telemetry)) {
  tab <- as.data.frame(table(telemetry$telemetry_state, useNA = "ifany"), stringsAsFactors = FALSE)
  names(tab) <- c("state", "rows")
  md <- c(md, "", "## Telemetry States", "", "| State | Rows |", "| --- | ---: |")
  for (ii in seq_len(nrow(tab))) md <- c(md, paste0("| ", tab$state[[ii]], " | ", tab$rows[[ii]], " |"))
}
if (nrow(summary)) {
  md <- c(
    md,
    "",
    "## Done/PASS Cell Summary",
    "",
    "| Family | Tau | Model | Fit RMSE | Forecast MAE | Forecast check | Leads | Scored targets |",
    "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |"
  )
  for (ii in seq_len(nrow(summary))) {
    row <- summary[ii, ]
    md <- c(md, paste0(
      "| ", row$family,
      " | ", fmt(row$tau, 2),
      " | ", row$model_variant,
      " | ", fmt(row$fit_qtrue_rmse),
      " | ", fmt(row$forecast_qtrue_mae),
      " | ", fmt(row$forecast_check),
      " | ", row$n_leads,
      " | ", row$n_origins_scored_total,
      " |"
    ))
  }
}
if (length(issues)) {
  md <- c(md, "", "## Issues", "", paste0("- ", issues))
} else {
  md <- c(md, "", "## Issues", "", "- none")
}
if (nrow(missing_cells)) {
  md <- c(md, "", "## Missing Cells", "", "| Family | Tau | Model |", "| --- | ---: | --- |")
  for (ii in seq_len(nrow(missing_cells))) {
    row <- missing_cells[ii, ]
    md <- c(md, paste0("| ", row$family, " | ", fmt(row$tau, 2), " | ", row$model_variant, " |"))
  }
}
md <- c(
  md,
  "",
  "## Storage",
  "",
  if (nrow(storage)) paste0("- forbidden payloads: `", sum(as.integer(storage$forbidden_payloads), na.rm = TRUE), "`") else "- storage audit unavailable",
  "",
  "## Regeneration",
  "",
  "```bash",
  paste(
    "Rscript validation/fitforecast_v2/scripts/audit_exdqlm_dqlm_c13_mcmc_500obs_refresh.R",
    "--manifest", shQuote(normalizePath(manifest_path, winslash = "/", mustWork = TRUE)),
    if (allow_incomplete) "--allow-incomplete" else ""
  ),
  "```"
)
writeLines(md, out_md)

cat("exDQLM/DQLM c13 MCMC 500-observation refresh audit\n")
cat(sprintf("run_root: %s\n", run_root))
cat(sprintf("manifest: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("interface: %s\n", normalizePath(interface_path, winslash = "/", mustWork = file.exists(interface_path))))
cat(sprintf("done_pass_cells: %d/18\n", cell_count))
cat(sprintf("done_pass_lead_rows: %d/540\n", lead_rows))
cat(sprintf("issues: %d\n", length(issues)))
cat(sprintf("summary_csv: %s\n", out_csv))
cat(sprintf("issues_csv: %s\n", issues_path))
cat(sprintf("missing_cells_csv: %s\n", missing_path))
cat(sprintf("audit_md: %s\n", out_md))
if (length(issues) && !allow_incomplete) {
  stop(sprintf("c13 MCMC refresh audit failed: %s", paste(issues, collapse = " | ")), call. = FALSE)
}
