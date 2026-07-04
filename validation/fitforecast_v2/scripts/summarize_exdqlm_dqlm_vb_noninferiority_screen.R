#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/fitforecast_v2/scripts/summarize_exdqlm_dqlm_vb_noninferiority_screen.R"
}
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)

args <- ffv2_parse_args()
manifest_path <- args$manifest %||% NULL
if (is.null(manifest_path)) {
  defaults <- ffv2_load_defaults(args$defaults %||% ffv2_default_defaults_path())
  run_root <- ffv2_resolve_path(file.path(defaults$study$results_root, defaults$study$run_tag), must_work = TRUE)
  manifest_path <- file.path(run_root, "manifests", "row_manifest.csv")
}

manifest <- ffv2_read_csv(manifest_path)
run_root <- unique(manifest$run_root)[[1L]]
interface_path <- args$interface %||% file.path(run_root, "interfaces", "exdqlm_dqlm_dynamic_fitforecast_v2_shared_interface.csv")
if (!file.exists(interface_path)) {
  interface <- ffv2_export_shared_interface(manifest, interface_path)
} else {
  interface <- ffv2_read_csv(interface_path)
}

out_dir <- args$`out-dir` %||% file.path(run_root, "screen_summary")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_csv <- args$`out-csv` %||% file.path(out_dir, "candidate_cell_rankings.csv")
winner_csv <- args$`winner-csv` %||% file.path(out_dir, "candidate_cell_winners.csv")
out_md <- args$`out-md` %||% file.path(out_dir, "EXDQLM_DQLM_VB_NONINFERIORITY_SCREEN_SUMMARY.md")

required <- c(
  "candidate_id", "calibration_id", "model_variant", "model_family",
  "inference", "family", "tau", "fit_size", "forecast_lead",
  "n_origins_scored", "status", "health_gate", "fit_qtrue_rmse",
  "fit_pinball_mean", "forecast_qtrue_mae", "forecast_qtrue_rmse",
  "forecast_pinball_mean", "runtime_sec_total", "source_registry_hash_value",
  "validation_branch", "validation_commit", "run_tag", "package_version",
  "forecast_protocol", "state_update_method", "max_lead_configured",
  "origin_stride"
)
missing <- setdiff(required, names(interface))
if (length(missing)) {
  stop("Shared interface is missing required columns: ", paste(missing, collapse = ", "),
       call. = FALSE)
}

weighted_mean <- function(x, w) {
  x <- as.numeric(x)
  w <- as.numeric(w)
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

first_value <- function(x) {
  if (!length(x)) return(NA)
  x[[1L]]
}

fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "", formatC(as.numeric(x), format = "f", digits = digits))
}

git_value <- function(...) {
  value <- tryCatch(system2("git", c(...), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (length(value) == 0L) NA_character_ else value[[1L]]
}

done <- subset(
  interface,
  model_family == "exdqlm_dqlm" &
    inference == "vb" &
    fit_size == 500 &
    status == "done" &
    health_gate == "PASS"
)

if (!nrow(done)) {
  ffv2_write_csv(data.frame(), out_csv)
  ffv2_write_csv(data.frame(), winner_csv)
  writeLines(c(
    "# exDQLM/DQLM VB Non-Inferiority Screen Summary",
    "",
    "No done/PASS rows are available yet. Re-run this summary after the screen completes."
  ), out_md)
  cat(sprintf("screen_rows: %d\n", 0L))
  cat(sprintf("rankings: %s\n", out_csv))
  cat(sprintf("winners: %s\n", winner_csv))
  quit(status = 0L, save = "no")
}

key <- paste(done$model_variant, done$family, done$tau, done$candidate_id, sep = "\r")
blocks <- split(done, key)
rows <- lapply(blocks, function(block) {
  data.frame(
    model_variant = first_value(block$model_variant),
    family = first_value(block$family),
    tau = as.numeric(first_value(block$tau)),
    fit_size = as.integer(first_value(block$fit_size)),
    candidate_id = first_value(block$candidate_id),
    calibration_id = first_value(block$calibration_id),
    n_leads = length(unique(as.integer(block$forecast_lead))),
    n_origins_scored_total = sum(as.numeric(block$n_origins_scored), na.rm = TRUE),
    fit_qtrue_rmse = as.numeric(first_value(block$fit_qtrue_rmse)),
    fit_check_loss = as.numeric(first_value(block$fit_pinball_mean)),
    forecast_qtrue_mae = weighted_mean(block$forecast_qtrue_mae, block$n_origins_scored),
    forecast_qtrue_rmse = weighted_mean(block$forecast_qtrue_rmse, block$n_origins_scored),
    forecast_check_loss = weighted_mean(block$forecast_pinball_mean, block$n_origins_scored),
    runtime_sec_total = as.numeric(first_value(block$runtime_sec_total)),
    source_registry_hash_value = first_value(block$source_registry_hash_value),
    validation_branch = first_value(block$validation_branch),
    validation_commit = first_value(block$validation_commit),
    run_tag = first_value(block$run_tag),
    package_version = first_value(block$package_version),
    forecast_protocol = first_value(block$forecast_protocol),
    state_update_method = first_value(block$state_update_method),
    max_lead_configured = as.integer(first_value(block$max_lead_configured)),
    origin_stride = as.integer(first_value(block$origin_stride)),
    stringsAsFactors = FALSE
  )
})

ranking <- do.call(rbind, rows)
ranking <- ranking[order(
  ranking$model_variant,
  ranking$family,
  ranking$tau,
  ranking$forecast_check_loss,
  ranking$forecast_qtrue_mae,
  ranking$fit_qtrue_rmse,
  ranking$candidate_id
), , drop = FALSE]

cell_key <- paste(ranking$model_variant, ranking$family, ranking$tau, sep = "\r")
ranking$cell_rank <- ave(seq_len(nrow(ranking)), cell_key, FUN = seq_along)
winners <- ranking[ranking$cell_rank == 1L, , drop = FALSE]
winners <- winners[order(winners$family, winners$tau, winners$model_variant), , drop = FALSE]

availability <- aggregate(
  candidate_id ~ model_variant + family + tau,
  data = ranking,
  FUN = function(x) paste(sort(unique(x)), collapse = ";")
)
names(availability)[names(availability) == "candidate_id"] <- "available_candidate_ids"
winners <- merge(winners, availability, by = c("model_variant", "family", "tau"), all.x = TRUE, sort = FALSE)
winners <- winners[order(winners$family, winners$tau, winners$model_variant), , drop = FALSE]

ffv2_write_csv(ranking, out_csv)
ffv2_write_csv(winners, winner_csv)

expected_cells <- length(unique(paste(manifest$model_variant, manifest$family, manifest$tau, sep = "\r")))
complete_cells <- nrow(winners)
complete_flag <- complete_cells == expected_cells
candidate_counts <- sort(table(winners$candidate_id), decreasing = TRUE)

md <- c(
  "# exDQLM/DQLM VB Non-Inferiority Screen Summary",
  "",
  "Date: 2026-07-04",
  "",
  "## Scope",
  "",
  "This report ranks the broad exDQLM/DQLM VB candidate screen cell by cell. Selection is by lead-weighted rolling-origin forecast check loss, with forecast MAE and fit RMSE used as tie breakers.",
  "",
  "## Inputs",
  "",
  paste0("- validation worktree: `", ffv2_repo_root(), "`"),
  paste0("- validation branch: `", git_value("rev-parse", "--abbrev-ref", "HEAD"), "`"),
  paste0("- validation HEAD: `", git_value("rev-parse", "HEAD"), "`"),
  paste0("- manifest: `", normalizePath(manifest_path, winslash = "/", mustWork = TRUE), "`"),
  paste0("- shared interface: `", normalizePath(interface_path, winslash = "/", mustWork = file.exists(interface_path)), "`"),
  paste0("- rankings CSV: `", normalizePath(out_csv, winslash = "/", mustWork = TRUE), "`"),
  paste0("- winners CSV: `", normalizePath(winner_csv, winslash = "/", mustWork = TRUE), "`"),
  "",
  "## Evidence Counts",
  "",
  paste0("- expected model/family/tau cells: `", expected_cells, "`"),
  paste0("- complete done/PASS winner cells: `", complete_cells, "`"),
  paste0("- complete screen: `", complete_flag, "`"),
  paste0("- candidate winners: `", paste(paste(names(candidate_counts), as.integer(candidate_counts), sep = "="), collapse = ", "), "`"),
  "",
  "## Cell Winners",
  "",
  "| Family | Tau | Model | Winner candidate | Fit RMSE | Forecast MAE | Forecast check |",
  "| --- | ---: | --- | --- | ---: | ---: | ---: |"
)

for (i in seq_len(nrow(winners))) {
  row <- winners[i, ]
  md <- c(md, paste0(
    "| ", row$family,
    " | ", fmt(row$tau, 2),
    " | ", row$model_variant,
    " | ", row$candidate_id,
    " | ", fmt(row$fit_qtrue_rmse),
    " | ", fmt(row$forecast_qtrue_mae),
    " | ", fmt(row$forecast_check_loss),
    " |"
  ))
}

md <- c(
  md,
  "",
  "## Reproducibility",
  "",
  "```bash",
  paste(
    "Rscript validation/fitforecast_v2/scripts/summarize_exdqlm_dqlm_vb_noninferiority_screen.R",
    "--manifest", shQuote(normalizePath(manifest_path, winslash = "/", mustWork = TRUE))
  ),
  "```"
)

writeLines(md, out_md)

cat(sprintf("screen_rows: %d\n", nrow(done)))
cat(sprintf("ranked_cells: %d\n", nrow(ranking)))
cat(sprintf("winner_cells: %d/%d\n", complete_cells, expected_cells))
cat(sprintf("complete: %s\n", complete_flag))
cat(sprintf("rankings: %s\n", out_csv))
cat(sprintf("winners: %s\n", winner_csv))
cat(sprintf("summary_md: %s\n", out_md))
