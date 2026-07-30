#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  required <- c("jsonlite", "yaml")
  missing <- setdiff(required, rownames(installed.packages()))
  if (length(missing)) {
    stop(
      sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  index <- which(args == flag)
  if (!length(index) || index[[1L]] >= length(args)) return(default)
  args[[index[[1L]] + 1L]]
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "qdesn_mcmc_nested_closeout_helpers.R"
), local = TRUE)

stage <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_final_origin9000_v1"
design_id <- "qdesn_500obs_mcmc_nested_final_origin9000_v1_design_20260730"
design_root <- file.path(
  "validation", "fitforecast_v2", "promotions", design_id
)
discovery_closeout_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_closeout_20260730"
discovery_closeout_root <- file.path(
  "validation", "fitforecast_v2", "promotions", discovery_closeout_id
)
external_id <- "qdesn_dqlm_500obs_mcmc_metric_envelope_20260727"
external_root <- file.path(
  "validation", "fitforecast_v2", "promotions", external_id
)
source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
run_tag <- trimws(as.character(get_arg("--run-tag", ""))[1L])
if (!nzchar(run_tag)) {
  stop("--run-tag is required.", call. = FALSE)
}

resolve_path <- function(path, must_work = TRUE) {
  path <- as.character(path %||% "")[1L]
  if (!grepl("^/", path)) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv <- function(path) {
  utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
}
write_csv <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_json <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    x, path, pretty = TRUE, auto_unbox = TRUE, null = "null", digits = NA
  )
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
write_text <- function(x, path) {
  path <- resolve_path(path, FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(as.character(x)), path, useBytes = TRUE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
num <- function(x) suppressWarnings(as.numeric(x))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
finite_median <- function(x) {
  x <- num(x)
  x <- x[is.finite(x)]
  if (length(x)) stats::median(x) else NA_real_
}
finite_mad <- function(x) {
  x <- num(x)
  x <- x[is.finite(x)]
  if (length(x) > 1L) stats::mad(x, constant = 1) else NA_real_
}
bind_rows <- function(rows) {
  rows <- rows[vapply(rows, nrow, integer(1L)) > 0L]
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    for (name in setdiff(columns, names(x))) x[[name]] <- NA
    x[, columns, drop = FALSE]
  })
  do.call(rbind, rows)
}
cell_key <- function(model, family, tau) {
  paste(model, family, sprintf("%.8f", num(tau)), sep = "|")
}
resolve_campaign_root <- function(path, marker) {
  path <- resolve_path(path, FALSE)
  if (!dir.exists(path)) return(path)
  if (file.exists(file.path(path, marker)) || dir.exists(file.path(path, marker))) {
    return(path)
  }
  children <- sort(
    list.dirs(path, recursive = FALSE, full.names = TRUE),
    decreasing = TRUE
  )
  hit <- children[
    file.exists(file.path(children, marker)) |
      dir.exists(file.path(children, marker))
  ]
  if (length(hit)) hit[[1L]] else path
}

defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
grid_path <- file.path("config", "validation", paste0(stage, "_grid.csv"))
target_specs_path <- file.path(
  "config", "validation", paste0(stage, "_target_spec_ids.csv")
)
contract_path <- file.path(design_root, "confirmation_contract.csv")
stability_path <- file.path(design_root, "originwise_stability_summary.csv")
selected_assignments_path <- file.path(design_root, "selected_assignments.csv")
discovery_handoff_path <- file.path(
  discovery_closeout_root, "final_origin_confirmation_handoff.csv"
)
parent_context_path <- file.path(
  discovery_closeout_root, "final_origin_parent_context.csv"
)
external_path <- file.path(
  external_root, paste0(external_id, "_article_envelope.csv")
)
description_path <- "DESCRIPTION"
pipeline_entrypoint_path <- file.path("scripts", "pipeline_real_main.R")

defaults <- yaml::read_yaml(resolve_path(defaults_path))
grid <- read_csv(grid_path)
targets <- read_csv(target_specs_path)
contract <- read_csv(contract_path)
stability <- read_csv(stability_path)
selected_assignments <- read_csv(selected_assignments_path)
discovery <- read_csv(discovery_handoff_path)
parent <- read_csv(parent_context_path)
external <- read_csv(external_path)
description <- read.dcf(resolve_path(description_path))
package_name <- as.character(description[1L, "Package"])
package_version <- as.character(description[1L, "Version"])

if (package_name != "exdqlm" ||
    package_version != "1.0.0" ||
    nrow(contract) != 1L ||
    contract$source_registry_hash_value[[1L]] != source_hash ||
    nrow(grid) != 8L ||
    any(grid$train_start_source_index != 8501L) ||
    any(grid$train_end_source_index != 9000L) ||
    any(grid$forecast_start_source_index != 9001L) ||
    any(grid$forecast_end_source_index != 10000L) ||
    nrow(targets) != 8L ||
    nrow(selected_assignments) != 8L ||
    nrow(stability) != 4L ||
    nrow(discovery) != 4L) {
  stop("Frozen final-origin design contract is incomplete or inconsistent.", call. = FALSE)
}

report_outer <- file.path(defaults$campaign$reports_root, run_tag)
result_outer <- file.path(defaults$campaign$results_root, run_tag)
report_root <- resolve_campaign_root(
  report_outer, file.path("tables", "campaign_progress.csv")
)
result_root <- resolve_campaign_root(result_outer, "roots")
progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
if (!file.exists(progress_path) || !file.exists(completed_path)) {
  stop("Campaign is not complete; progress or completion manifest is missing.", call. = FALSE)
}
progress <- read_csv(progress_path)
completed <- jsonlite::read_json(completed_path, simplifyVector = TRUE)
root_status <- toupper(as.character(progress$root_status))
if (nrow(progress) != 8L ||
    any(root_status %in% c("RUNNING", "PENDING", "QUEUED")) ||
    as.integer(completed$n_roots) != 8L) {
  stop("Campaign has not reached an eight-root terminal state.", call. = FALSE)
}
if (any(root_status != "SUCCESS")) {
  stop(
    sprintf(
      "All confirmation roots must execute successfully; statuses: %s.",
      paste(sprintf("%s=%d", names(table(root_status)), table(root_status)), collapse = ", ")
    ),
    call. = FALSE
  )
}

selection_files <- qdesn_canonical_seed_selection_files(
  result_root,
  expected_roots = 8L
)
seed_rows <- vector("list", length(selection_files))
for (index in seq_along(selection_files)) {
  selection_path <- selection_files[[index]]
  selection <- read_csv(selection_path)
  qdesn_validate_seed_selection(selection, selection_path)
  selection$seed_selection_path <- resolve_path(selection_path)
  selection$forecast_qtrue_mae_H1000 <- NA_real_
  selection$forecast_check_loss_H1000 <- NA_real_
  selection$forecast_horizon_summary_path <- NA_character_
  for (row in seq_len(nrow(selection))) {
    horizon_path <- file.path(
      as.character(selection$seed_method_dir[[row]]),
      "tables", "forecast_horizon_summary.csv"
    )
    if (!file.exists(horizon_path)) next
    horizon <- read_csv(horizon_path)
    h1000 <- horizon[num(horizon$horizon) == 1000, , drop = FALSE]
    if (nrow(h1000) != 1L) next
    selection$forecast_qtrue_mae_H1000[[row]] <- num(h1000$qtrue_mae[[1L]])
    selection$forecast_check_loss_H1000[[row]] <- num(h1000$pinball_tau[[1L]])
    selection$forecast_horizon_summary_path[[row]] <- resolve_path(horizon_path)
  }
  seed_rows[[index]] <- selection
}
seeds <- bind_rows(seed_rows)
seed_key <- paste(seeds$root_id, seeds$seed_rep, sep = "|")
if (nrow(seeds) != 16L || anyDuplicated(seed_key)) {
  stop("Expected exactly sixteen unique root/seed confirmation rows.", call. = FALSE)
}
if (!setequal(
  unique(as.character(seeds$screening_profile_id)),
  unique(as.character(selected_assignments$screening_profile_id))
)) {
  stop("Observed confirmation profiles differ from the frozen handoff.", call. = FALSE)
}

seeds$model_variant <- ifelse(
  as.character(seeds$likelihood_family) == "exal",
  "qdesn_exal_rhs_ns",
  "qdesn_al_rhs_ns"
)
seeds$cell_key <- cell_key(seeds$model_variant, seeds$family, seeds$tau)
seeds$metric_complete <- is.finite(num(seeds$train_qtrue_rmse)) &
  is.finite(num(seeds$forecast_qtrue_mae_H1000)) &
  is.finite(num(seeds$forecast_check_loss_H1000))

profile_columns <- intersect(
  c(
    "screening_profile_id", "profile_role", "confirmation_role",
    "reservoir_seed_rep", "D", "n_each", "n_tilde_each", "m", "alpha",
    "rho", "pi_w", "pi_in", "readout_y_lags", "reservoir_lags", "rhs_tau0"
  ),
  names(selected_assignments)
)
profile_map <- selected_assignments[, profile_columns, drop = FALSE]
missing_profile_columns <- setdiff(
  c("screening_profile_id", "confirmation_role", "reservoir_seed_rep"),
  names(profile_map)
)
if (length(missing_profile_columns)) {
  stop(
    sprintf(
      "Selected assignment map is missing: %s.",
      paste(missing_profile_columns, collapse = ", ")
    ),
    call. = FALSE
  )
}
seeds <- merge(
  seeds,
  profile_map,
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("", ".frozen")
)

aggregate_one <- function(x) {
  data.frame(
    model_variant = as.character(x$model_variant[[1L]]),
    family = as.character(x$family[[1L]]),
    tau = num(x$tau[[1L]]),
    fit_size = 500L,
    design_role = as.character(
      (x$profile_role.frozen %||% x$profile_role)[[1L]]
    ),
    confirmation_role = as.character(x$confirmation_role[[1L]]),
    replicate_rows = nrow(x),
    metric_complete_rows = sum(x$metric_complete),
    reservoir_seed_reps = length(unique(num(x$reservoir_seed_rep))),
    mcmc_seed_reps = length(unique(num(x$seed_rep))),
    successful_rows = sum(toupper(as.character(x$status)) == "SUCCESS"),
    pass_rows = sum(toupper(as.character(x$signoff_grade)) == "PASS"),
    warn_rows = sum(toupper(as.character(x$signoff_grade)) == "WARN"),
    fail_rows = sum(toupper(as.character(x$signoff_grade)) == "FAIL"),
    fit_qtrue_rmse = finite_median(x$train_qtrue_rmse),
    fit_qtrue_rmse_mad = finite_mad(x$train_qtrue_rmse),
    forecast_qtrue_mae_H1000 = finite_median(x$forecast_qtrue_mae_H1000),
    forecast_qtrue_mae_H1000_mad = finite_mad(x$forecast_qtrue_mae_H1000),
    forecast_check_loss_H1000 = finite_median(x$forecast_check_loss_H1000),
    forecast_check_loss_H1000_mad = finite_mad(x$forecast_check_loss_H1000),
    runtime_sec_median = finite_median(x$runtime_sec),
    stringsAsFactors = FALSE
  )
}
aggregated <- bind_rows(lapply(split(seeds, seeds$cell_key), aggregate_one))
if (nrow(aggregated) != 4L) {
  stop("Expected four final-origin cell aggregates.", call. = FALSE)
}

discovery_context <- discovery[, c(
  "model_variant", "family", "tau", "primary_gap", "design_role",
  "fit_qtrue_rmse_median", "forecast_qtrue_mae_H1000_median",
  "forecast_check_loss_H1000_median"
)]
names(discovery_context)[6:8] <- c(
  "discovery_fit_qtrue_rmse",
  "discovery_forecast_qtrue_mae_H1000",
  "discovery_forecast_check_loss_H1000"
)
parent_context <- parent[, c(
  "model_variant", "family", "tau", "fit_qtrue_rmse",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "source_promotion_id", "source_registry_hash_value"
)]
names(parent_context)[4:7] <- c(
  "parent_fit_qtrue_rmse",
  "parent_forecast_qtrue_mae_H1000",
  "parent_forecast_check_loss_H1000",
  "parent_source_promotion_id"
)

external <- external[
  external$model_variant %in% c("dqlm_c13_mcmc", "exdqlm_c13_mcmc"),
  ,
  drop = FALSE
]
external_rows <- lapply(
  split(external, paste(
    external$family,
    sprintf("%.8f", num(external$tau)),
    sep = "|"
  )),
  function(x) {
    data.frame(
      family = as.character(x$family[[1L]]),
      tau = num(x$tau[[1L]]),
      external_fit_qtrue_rmse = min(num(x$fit_qtrue_rmse), na.rm = TRUE),
      external_forecast_qtrue_mae_H1000 = min(
        num(x$forecast_qtrue_mae_H1000), na.rm = TRUE
      ),
      external_forecast_check_loss_H1000 = min(
        num(x$forecast_check_loss_H1000), na.rm = TRUE
      ),
      external_models = paste(sort(unique(x$model_variant)), collapse = ";"),
      stringsAsFactors = FALSE
    )
  }
)
external_context <- bind_rows(external_rows)

aggregated <- merge(
  aggregated,
  discovery_context,
  by = c("model_variant", "family", "tau", "design_role"),
  all.x = TRUE,
  sort = FALSE
)
aggregated <- merge(
  aggregated,
  parent_context,
  by = c("model_variant", "family", "tau"),
  all.x = TRUE,
  sort = FALSE
)
aggregated <- merge(
  aggregated,
  external_context,
  by = c("family", "tau"),
  all.x = TRUE,
  sort = FALSE
)

aggregated$fit_ratio_to_discovery <- aggregated$fit_qtrue_rmse /
  aggregated$discovery_fit_qtrue_rmse
aggregated$forecast_mae_ratio_to_discovery <-
  aggregated$forecast_qtrue_mae_H1000 /
  aggregated$discovery_forecast_qtrue_mae_H1000
aggregated$forecast_check_ratio_to_discovery <-
  aggregated$forecast_check_loss_H1000 /
  aggregated$discovery_forecast_check_loss_H1000
aggregated$fit_ratio_to_parent <- aggregated$fit_qtrue_rmse /
  aggregated$parent_fit_qtrue_rmse
aggregated$forecast_mae_ratio_to_parent <-
  aggregated$forecast_qtrue_mae_H1000 /
  aggregated$parent_forecast_qtrue_mae_H1000
aggregated$forecast_check_ratio_to_parent <-
  aggregated$forecast_check_loss_H1000 /
  aggregated$parent_forecast_check_loss_H1000
aggregated$fit_ratio_to_external <- aggregated$fit_qtrue_rmse /
  aggregated$external_fit_qtrue_rmse
aggregated$forecast_mae_ratio_to_external <-
  aggregated$forecast_qtrue_mae_H1000 /
  aggregated$external_forecast_qtrue_mae_H1000
aggregated$forecast_check_ratio_to_external <-
  aggregated$forecast_check_loss_H1000 /
  aggregated$external_forecast_check_loss_H1000

aggregated$replication_complete <- aggregated$replicate_rows == 4L &
  aggregated$metric_complete_rows == 4L &
  aggregated$reservoir_seed_reps == 2L &
  aggregated$mcmc_seed_reps == 2L
aggregated$discovery_stability_gate <- pmax(
  aggregated$fit_ratio_to_discovery,
  aggregated$forecast_mae_ratio_to_discovery,
  aggregated$forecast_check_ratio_to_discovery
) <= 1.10
aggregated$parent_no_material_regression_gate <- pmax(
  aggregated$fit_ratio_to_parent,
  aggregated$forecast_mae_ratio_to_parent,
  aggregated$forecast_check_ratio_to_parent
) <= 1.05
aggregated$primary_improvement_gate <- ifelse(
  aggregated$primary_gap == "fit",
  aggregated$fit_ratio_to_parent <= 0.97,
  aggregated$forecast_mae_ratio_to_parent <= 0.95 |
    aggregated$forecast_check_ratio_to_parent <= 0.99
)
aggregated$external_competitive_gate <- pmax(
  aggregated$fit_ratio_to_external,
  aggregated$forecast_mae_ratio_to_external,
  aggregated$forecast_check_ratio_to_external
) <= 1.05
aggregated$coherent_promotion_eligible <-
  aggregated$confirmation_role == "primary_confirmation" &
  aggregated$replication_complete &
  aggregated$discovery_stability_gate &
  aggregated$parent_no_material_regression_gate &
  aggregated$primary_improvement_gate
aggregated$diagnostic_grade_suppresses_metrics <- FALSE

metric_rows <- list()
metric_definitions <- list(
  fit_qtrue_rmse = c("fit_qtrue_rmse", "parent_fit_qtrue_rmse"),
  forecast_qtrue_mae_H1000 = c(
    "forecast_qtrue_mae_H1000",
    "parent_forecast_qtrue_mae_H1000"
  ),
  forecast_check_loss_H1000 = c(
    "forecast_check_loss_H1000",
    "parent_forecast_check_loss_H1000"
  )
)
for (index in seq_len(nrow(aggregated))) {
  for (metric in names(metric_definitions)) {
    columns <- metric_definitions[[metric]]
    observed <- num(aggregated[[columns[[1L]]]][[index]])
    baseline <- num(aggregated[[columns[[2L]]]][[index]])
    metric_rows[[length(metric_rows) + 1L]] <- data.frame(
      model_variant = aggregated$model_variant[[index]],
      family = aggregated$family[[index]],
      tau = aggregated$tau[[index]],
      fit_size = 500L,
      design_role = aggregated$design_role[[index]],
      confirmation_role = aggregated$confirmation_role[[index]],
      metric = metric,
      confirmation_value = observed,
      parent_value = baseline,
      ratio_to_parent = observed / baseline,
      finite_improvement = is.finite(observed) &&
        is.finite(baseline) &&
        observed < baseline,
      coherent_cell_promotion_eligible =
        aggregated$coherent_promotion_eligible[[index]],
      article_refresh_candidate = aggregated$coherent_promotion_eligible[[index]] &&
        is.finite(observed) &&
        is.finite(baseline) &&
        observed < baseline,
      stringsAsFactors = FALSE
    )
  }
}
metric_refresh <- bind_rows(metric_rows)

heavy <- list.files(
  result_root,
  pattern = "[.](rds|rda|RData)$|__design[.]rds$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
storage <- if (length(heavy)) {
  info <- file.info(heavy)
  data.frame(
    path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
    bytes = as.numeric(info$size),
    disposition = "unexpected_heavy_payload_keep_for_manual_audit",
    stringsAsFactors = FALSE
  )
} else {
  data.frame(
    path = character(),
    bytes = numeric(),
    disposition = character(),
    stringsAsFactors = FALSE
  )
}

stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
closeout_id <- paste0(
  "qdesn_500obs_mcmc_nested_final_origin9000_v1_closeout_", stamp
)
out_root <- resolve_path(
  get_arg(
    "--out-root",
    file.path("validation", "fitforecast_v2", "promotions", closeout_id)
  ),
  FALSE
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

campaign <- data.frame(
  run_tag = run_tag,
  report_root = resolve_path(report_root),
  result_root = resolve_path(result_root),
  roots_total = nrow(progress),
  roots_success = sum(root_status == "SUCCESS"),
  roots_failed = sum(root_status != "SUCCESS"),
  seed_selection_files = length(selection_files),
  seed_rows = nrow(seeds),
  completed_manifest = resolve_path(completed_path),
  stringsAsFactors = FALSE
)
article_refresh_rows <- sum(metric_refresh$article_refresh_candidate)
decision <- if (article_refresh_rows > 0L) {
  "MANUAL_ARTICLE_REFRESH_REVIEW_REQUIRED"
} else {
  "NO_CONFIRMED_COHERENT_ARTICLE_REFRESH"
}
format_number <- function(x) {
  ifelse(is.finite(num(x)), sprintf("%.4f", num(x)), "NA")
}
format_ratio <- function(x) {
  ifelse(is.finite(num(x)), sprintf("%.3f", num(x)), "NA")
}
result_rows <- vapply(seq_len(nrow(aggregated)), function(index) {
  sprintf(
    paste0(
      "| %s | %s | %.2f | %s | %s | %s | %s | %s | %s | ",
      "%d/%d/%d | %s |"
    ),
    aggregated$model_variant[[index]],
    aggregated$family[[index]],
    num(aggregated$tau[[index]]),
    format_number(aggregated$fit_qtrue_rmse[[index]]),
    format_number(aggregated$forecast_qtrue_mae_H1000[[index]]),
    format_number(aggregated$forecast_check_loss_H1000[[index]]),
    format_ratio(aggregated$fit_ratio_to_parent[[index]]),
    format_ratio(aggregated$forecast_mae_ratio_to_parent[[index]]),
    format_ratio(aggregated$forecast_check_ratio_to_parent[[index]]),
    as.integer(aggregated$pass_rows[[index]]),
    as.integer(aggregated$warn_rows[[index]]),
    as.integer(aggregated$fail_rows[[index]]),
    ifelse(aggregated$coherent_promotion_eligible[[index]], "YES", "NO")
  )
}, character(1L))
decision_report <- c(
  "# Q-DESN Nested Final-Origin MCMC Confirmation Closeout",
  "",
  "## Identity",
  "",
  sprintf("- Run tag: `%s`", run_tag),
  sprintf("- Design: `%s`", design_id),
  sprintf("- Stage: `%s`", stage),
  sprintf("- Source-loaded package: `%s` version `%s`.", package_name, package_version),
  "- Package loading: `pkgload::load_all(repo_root)` from this worktree.",
  sprintf("- Source-registry SHA-256: `%s`", source_hash),
  "- Frozen confirmation origin: 9000.",
  "- Training source indices: 8501--9000.",
  "- Forecast source indices: 9001--10000.",
  "",
  "## Completion",
  "",
  sprintf("- Successful roots: %d/8.", sum(root_status == "SUCCESS")),
  sprintf("- Complete MCMC seed fits: %d/16.", nrow(seeds)),
  sprintf(
    "- Complete replicated model/family/quantile cells: %d/4.",
    sum(aggregated$replication_complete)
  ),
  sprintf("- Retained heavy model payloads: %d.", nrow(storage)),
  "",
  "## Cell Results",
  "",
  paste0(
    "| Model | Family | Tau | Fit RMSE | Forecast MAE H=1000 | ",
    "Forecast check loss H=1000 | Fit/parent | MAE/parent | ",
    "Check/parent | PASS/WARN/FAIL | Promote |"
  ),
  paste0(
    "|---|---|---:|---:|---:|---:|---:|---:|---:|",
    "---:|---|"
  ),
  result_rows,
  "",
  "Ratios below one improve on the current parent metric. Diagnostic grades are",
  "reported but do not suppress finite metrics.",
  "",
  "## Decision",
  "",
  sprintf("- Decision: `%s`.", decision),
  sprintf(
    "- Coherently promotable cells: %d/4.",
    sum(aggregated$coherent_promotion_eligible)
  ),
  sprintf(
    "- Externally competitive cells: %d/4.",
    sum(aggregated$external_competitive_gate)
  ),
  sprintf("- Article-refresh metric rows: %d.", article_refresh_rows),
  "- The final-origin evidence does not justify changing article values.",
  "- Origin 9000 has now been evaluated and must not be reused as an untouched",
  "  confirmation origin for further tuning.",
  "",
  "## Next Safe Scientific Step",
  "",
  "1. Diagnose source-window and DGP heterogeneity without fitting new models.",
  "2. Select future candidates by robust performance across multiple predeclared",
  "   pre-confirmation origins, not by a pooled two-origin median alone.",
  "3. Reserve a fresh simulation replicate or source seed as the next untouched",
  "   confirmation sample before any additional MCMC promotion.",
  "4. Keep the current article-facing parent rows unchanged unless a future",
  "   confirmation passes the frozen coherent-promotion contract.",
  "",
  "## Invalid Run",
  "",
  paste0(
    "The tag `qdesn-500obs-mcmc-nested-final-o9000-v1-full-20260730__",
    "git-6582f87` is `ABORTED_INVALID_CONTRACT` and is not consumable. Its"
  ),
  "per-fit request used 100 rather than 200 posterior predictive draws."
)
decision_report_path <- write_text(
  decision_report,
  file.path(out_root, "decision_report.md")
)
outputs <- c(
  campaign = write_csv(campaign, file.path(out_root, "campaign_completion.csv")),
  seed_metrics = write_csv(
    seeds, file.path(out_root, "final_origin_seed_metrics.csv")
  ),
  cell_metrics = write_csv(
    aggregated, file.path(out_root, "final_origin_cell_metrics.csv")
  ),
  metric_refresh = write_csv(
    metric_refresh, file.path(out_root, "metricwise_refresh_candidates.csv")
  ),
  storage = write_csv(storage, file.path(out_root, "storage_audit.csv")),
  decision_report = decision_report_path
)

source_files <- c(
  package_description = resolve_path(description_path),
  pipeline_entrypoint = resolve_path(pipeline_entrypoint_path),
  defaults = resolve_path(defaults_path),
  grid = resolve_path(grid_path),
  target_specs = resolve_path(target_specs_path),
  contract = resolve_path(contract_path),
  stability = resolve_path(stability_path),
  selected_assignments = resolve_path(selected_assignments_path),
  discovery_handoff = resolve_path(discovery_handoff_path),
  parent_context = resolve_path(parent_context_path),
  external_envelope = resolve_path(external_path),
  campaign_progress = resolve_path(progress_path),
  campaign_completed = resolve_path(completed_path)
)
source_manifest <- data.frame(
  role = names(source_files),
  path = unname(source_files),
  sha256 = vapply(unname(source_files), sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest, file.path(out_root, "source_manifest.csv")
)
outputs <- c(outputs, source_manifest = source_manifest_path)
file_manifest <- data.frame(
  role = names(outputs),
  path = unname(outputs),
  sha256 = vapply(unname(outputs), sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest, file.path(out_root, "file_manifest.csv")
)

manifest <- list(
  generated_at = as.character(Sys.time()),
  closeout_id = closeout_id,
  stage = stage,
  design_id = design_id,
  run_tag = run_tag,
  package_name = package_name,
  package_version = package_version,
  package_loading = "pkgload::load_all(repo_root)",
  source_registry_hash_value = source_hash,
  expected_roots = 8L,
  observed_terminal_roots = nrow(progress),
  observed_successful_roots = sum(root_status == "SUCCESS"),
  expected_seed_rows = 16L,
  observed_seed_rows = nrow(seeds),
  complete_cells = sum(aggregated$replication_complete),
  coherent_promotion_cells = sum(aggregated$coherent_promotion_eligible),
  externally_competitive_cells = sum(aggregated$external_competitive_gate),
  article_refresh_metric_rows = article_refresh_rows,
  diagnostic_grade_is_reported_not_metric_suppressing = TRUE,
  storage_heavy_files = nrow(storage),
  article_updated = FALSE,
  decision = decision,
  decision_report = decision_report_path,
  source_manifest = source_manifest_path,
  file_manifest = file_manifest_path
)
manifest_path <- write_json(
  manifest,
  file.path(out_root, paste0(closeout_id, "_manifest.json"))
)

cat(sprintf("closeout_root: %s\n", out_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("terminal_roots: %d/8\n", nrow(progress)))
cat(sprintf("seed_rows: %d/16\n", nrow(seeds)))
cat(sprintf(
  "coherent_promotion_cells: %d/4\n",
  sum(aggregated$coherent_promotion_eligible)
))
cat(sprintf("article_refresh_metric_rows: %d\n", article_refresh_rows))
cat(sprintf("decision: %s\n", decision))
