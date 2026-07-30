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

stage_base <- "qdesn_dynamic_fitforecast_v2_500obs_mcmc_nested_cellwise_v1"
promotion_id <- "qdesn_500obs_mcmc_nested_cellwise_v1_design_20260729"
promotion_root <- file.path("validation", "fitforecast_v2", "promotions", promotion_id)
source_hash <- "edddb56fc2b30e49ac99fdd08b53dad468ed53e05d0fe1fe16426ee9d9ffe275"
origins <- c(7000L, 8000L)
run_tags <- c(
  origin7000 = as.character(get_arg("--origin7000-run-tag", ""))[1L],
  origin8000 = as.character(get_arg("--origin8000-run-tag", ""))[1L]
)
if (any(!nzchar(trimws(run_tags)))) {
  stop(
    "--origin7000-run-tag and --origin8000-run-tag are both required.",
    call. = FALSE
  )
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
sha256 <- function(path) unname(tools::sha256sum(resolve_path(path)))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}
num <- function(x) suppressWarnings(as.numeric(x))
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

profiles <- read_csv(file.path(
  promotion_root,
  paste0(promotion_id, "_candidate_profiles.csv")
))
targets <- read_csv(file.path(
  promotion_root,
  paste0(promotion_id, "_target_cells.csv")
))
parent_envelope_path <- file.path(
  "validation", "fitforecast_v2", "promotions",
  "qdesn_tt500_mcmc_postv4_percell_closeout_20260728",
  "qdesn_tt500_mcmc_postv4_percell_closeout_20260728_refreshed_article_envelope.csv"
)
parent_envelope <- read_csv(parent_envelope_path)

campaign_rows <- list()
seed_rows <- list()
storage_rows <- list()
source_files <- c(
  profiles = resolve_path(file.path(
    promotion_root,
    paste0(promotion_id, "_candidate_profiles.csv")
  )),
  target_cells = resolve_path(file.path(
    promotion_root,
    paste0(promotion_id, "_target_cells.csv")
  )),
  parent_envelope = resolve_path(parent_envelope_path)
)

for (origin in origins) {
  view_id <- paste0("origin", origin)
  stage <- paste0(stage_base, "_", view_id)
  defaults_path <- file.path("config", "validation", paste0(stage, "_defaults.yaml"))
  defaults <- yaml::read_yaml(resolve_path(defaults_path))
  report_outer <- file.path(defaults$campaign$reports_root, run_tags[[view_id]])
  result_outer <- file.path(defaults$campaign$results_root, run_tags[[view_id]])
  report_root <- resolve_campaign_root(report_outer, file.path("tables", "campaign_progress.csv"))
  result_root <- resolve_campaign_root(result_outer, "roots")
  progress_path <- file.path(report_root, "tables", "campaign_progress.csv")
  completed_path <- file.path(report_root, "manifest", "campaign_completed.json")
  if (!file.exists(progress_path) || !file.exists(completed_path)) {
    stop(
      sprintf("%s is not complete; missing progress or completion manifest.", view_id),
      call. = FALSE
    )
  }
  progress <- read_csv(progress_path)
  completed <- jsonlite::read_json(completed_path, simplifyVector = TRUE)
  status <- toupper(as.character(progress$root_status))
  if (nrow(progress) != 360L ||
      any(status %in% c("RUNNING", "PENDING", "QUEUED")) ||
      as.integer(completed$n_roots) != 360L) {
    stop(
      sprintf("%s has not reached a complete 360-root terminal state.", view_id),
      call. = FALSE
    )
  }

  selection_files <- list.files(
    file.path(result_root, "roots"),
    pattern = "^mcmc_seed_selection[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  for (selection_path in selection_files) {
    selection <- read_csv(selection_path)
    if (!nrow(selection)) next
    selection$calibration_view <- view_id
    selection$calibration_origin_source_index <- origin
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
    seed_rows[[length(seed_rows) + 1L]] <- selection
  }

  heavy <- list.files(
    result_root,
    pattern = "[.](rds|rda|RData)$|__design[.]rds$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(heavy)) {
    info <- file.info(heavy)
    storage_rows[[length(storage_rows) + 1L]] <- data.frame(
      calibration_view = view_id,
      path = normalizePath(heavy, winslash = "/", mustWork = TRUE),
      bytes = as.numeric(info$size),
      disposition = "unexpected_heavy_payload_keep_for_manual_audit",
      stringsAsFactors = FALSE
    )
  }
  campaign_rows[[length(campaign_rows) + 1L]] <- data.frame(
    calibration_view = view_id,
    calibration_origin_source_index = origin,
    run_tag = run_tags[[view_id]],
    report_root = resolve_path(report_root),
    result_root = resolve_path(result_root),
    roots_total = nrow(progress),
    roots_success = sum(status == "SUCCESS"),
    roots_failed = sum(status %in% c("FAIL", "FAILED", "ERROR")),
    seed_selection_files = length(selection_files),
    completed_manifest = resolve_path(completed_path),
    stringsAsFactors = FALSE
  )
  source_files <- c(
    source_files,
    stats::setNames(resolve_path(defaults_path), paste0(view_id, "_defaults")),
    stats::setNames(resolve_path(progress_path), paste0(view_id, "_progress")),
    stats::setNames(resolve_path(completed_path), paste0(view_id, "_completed"))
  )
}

campaigns <- bind_rows(campaign_rows)
seeds <- bind_rows(seed_rows)
storage <- bind_rows(storage_rows)
if (!nrow(storage)) {
  storage <- data.frame(
    calibration_view = character(),
    path = character(),
    bytes = numeric(),
    disposition = character(),
    stringsAsFactors = FALSE
  )
}
if (!nrow(seeds)) {
  stop("No MCMC seed-selection rows were available for closeout.", call. = FALSE)
}

profile_map <- profiles[, c(
  "screening_profile_id", "profile_role", "reservoir_seed_rep",
  "repeat_class", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "readout_y_lags", "reservoir_lags", "rhs_tau0"
), drop = FALSE]
seeds <- merge(
  seeds,
  profile_map,
  by = "screening_profile_id",
  all.x = TRUE,
  sort = FALSE,
  suffixes = c("", ".design")
)
seeds$model_variant <- ifelse(
  as.character(seeds$likelihood_family) == "exal",
  "qdesn_exal_rhs_ns",
  "qdesn_al_rhs_ns"
)
seeds$cell_key <- paste(
  seeds$model_variant,
  seeds$family,
  sprintf("%.8f", num(seeds$tau)),
  500L,
  sep = "|"
)
seeds$design_key <- paste(seeds$cell_key, seeds$profile_role, sep = "|")
seeds$metric_complete <- is.finite(num(seeds$train_qtrue_rmse)) &
  is.finite(num(seeds$forecast_qtrue_mae_H1000)) &
  is.finite(num(seeds$forecast_check_loss_H1000))

aggregate_one <- function(x) {
  data.frame(
    model_variant = as.character(x$model_variant[[1L]]),
    family = as.character(x$family[[1L]]),
    tau = num(x$tau[[1L]]),
    fit_size = 500L,
    design_role = as.character(x$profile_role[[1L]]),
    repeat_class = as.character(x$repeat_class[[1L]]),
    D = as.integer(x$D[[1L]]),
    n_each = as.integer(x$n_each[[1L]]),
    n_tilde_each = as.integer(x$n_tilde_each[[1L]]),
    m = as.integer(x$m[[1L]]),
    alpha = num(x$alpha[[1L]]),
    rho = num(x$rho[[1L]]),
    pi_w = num(x$pi_w[[1L]]),
    pi_in = num(x$pi_in[[1L]]),
    readout_y_lags = as.integer(x$readout_y_lags[[1L]]),
    reservoir_lags = as.integer(x$reservoir_lags[[1L]]),
    rhs_tau0 = num(x$rhs_tau0.design[[1L]] %||% x$rhs_tau0[[1L]]),
    replicate_rows = nrow(x),
    metric_complete_rows = sum(x$metric_complete),
    calibration_origins = length(unique(x$calibration_origin_source_index)),
    reservoir_seed_reps = length(unique(x$reservoir_seed_rep)),
    mcmc_seed_reps = length(unique(x$seed_rep)),
    successful_rows = sum(toupper(as.character(x$status)) == "SUCCESS"),
    pass_rows = sum(toupper(as.character(x$signoff_grade)) == "PASS"),
    warn_rows = sum(toupper(as.character(x$signoff_grade)) == "WARN"),
    fail_rows = sum(toupper(as.character(x$signoff_grade)) == "FAIL"),
    fit_qtrue_rmse_median = finite_median(x$train_qtrue_rmse),
    fit_qtrue_rmse_mad = finite_mad(x$train_qtrue_rmse),
    forecast_qtrue_mae_H1000_median = finite_median(x$forecast_qtrue_mae_H1000),
    forecast_qtrue_mae_H1000_mad = finite_mad(x$forecast_qtrue_mae_H1000),
    forecast_check_loss_H1000_median = finite_median(x$forecast_check_loss_H1000),
    forecast_check_loss_H1000_mad = finite_mad(x$forecast_check_loss_H1000),
    runtime_sec_median = finite_median(x$runtime_sec),
    stringsAsFactors = FALSE
  )
}
aggregated <- bind_rows(lapply(split(seeds, seeds$design_key), aggregate_one))

reference_rows <- lapply(
  split(aggregated, paste(
    aggregated$model_variant,
    aggregated$family,
    sprintf("%.8f", aggregated$tau),
    sep = "|"
  )),
  function(x) {
    anchors <- x[x$repeat_class == "declared_anchor_control", , drop = FALSE]
    if (!nrow(anchors)) return(data.frame(stringsAsFactors = FALSE))
    data.frame(
      model_variant = x$model_variant[[1L]],
      family = x$family[[1L]],
      tau = x$tau[[1L]],
      anchor_fit_qtrue_rmse = min(anchors$fit_qtrue_rmse_median, na.rm = TRUE),
      anchor_forecast_qtrue_mae_H1000 = min(
        anchors$forecast_qtrue_mae_H1000_median,
        na.rm = TRUE
      ),
      anchor_forecast_check_loss_H1000 = min(
        anchors$forecast_check_loss_H1000_median,
        na.rm = TRUE
      ),
      stringsAsFactors = FALSE
    )
  }
)
references <- bind_rows(reference_rows)
aggregated <- merge(
  aggregated,
  references,
  by = c("model_variant", "family", "tau"),
  all.x = TRUE,
  sort = FALSE
)
target_subset <- targets[, c(
  "model_variant", "family", "tau", "primary_remaining_gap_postv4"
), drop = FALSE]
names(target_subset)[names(target_subset) == "primary_remaining_gap_postv4"] <-
  "primary_gap"
aggregated <- merge(
  aggregated,
  target_subset,
  by = c("model_variant", "family", "tau"),
  all.x = TRUE,
  sort = FALSE
)

aggregated$fit_ratio_to_anchor <- aggregated$fit_qtrue_rmse_median /
  aggregated$anchor_fit_qtrue_rmse
aggregated$forecast_mae_ratio_to_anchor <-
  aggregated$forecast_qtrue_mae_H1000_median /
    aggregated$anchor_forecast_qtrue_mae_H1000
aggregated$forecast_check_ratio_to_anchor <-
  aggregated$forecast_check_loss_H1000_median /
    aggregated$anchor_forecast_check_loss_H1000
aggregated$worst_ratio_to_anchor <- pmax(
  aggregated$fit_ratio_to_anchor,
  aggregated$forecast_mae_ratio_to_anchor,
  aggregated$forecast_check_ratio_to_anchor
)
aggregated$replication_complete <- aggregated$replicate_rows == 8L &
  aggregated$metric_complete_rows == 8L &
  aggregated$calibration_origins == 2L &
  aggregated$reservoir_seed_reps == 2L &
  aggregated$mcmc_seed_reps == 2L
aggregated$fit_improvement_gate <- aggregated$fit_ratio_to_anchor <= 0.97
aggregated$forecast_mae_improvement_gate <-
  aggregated$forecast_mae_ratio_to_anchor <= 0.95
aggregated$forecast_check_improvement_gate <-
  aggregated$forecast_check_ratio_to_anchor <= 0.99
aggregated$no_material_regression <- aggregated$worst_ratio_to_anchor <= 1.05
aggregated$primary_improvement_gate <- ifelse(
  aggregated$primary_gap == "fit",
  aggregated$fit_improvement_gate,
  aggregated$forecast_mae_improvement_gate |
    aggregated$forecast_check_improvement_gate
)
aggregated$eligible_for_final_origin_confirmation <-
  aggregated$repeat_class == "novel_candidate" &
    aggregated$replication_complete &
    aggregated$no_material_regression &
    aggregated$primary_improvement_gate
aggregated$primary_ratio <- ifelse(
  aggregated$primary_gap == "fit",
  aggregated$fit_ratio_to_anchor,
  pmin(
    aggregated$forecast_mae_ratio_to_anchor,
    aggregated$forecast_check_ratio_to_anchor
  )
)

ranked <- bind_rows(lapply(
  split(aggregated, paste(
    aggregated$model_variant,
    aggregated$family,
    sprintf("%.8f", aggregated$tau),
    sep = "|"
  )),
  function(x) {
    x <- x[order(
      !x$eligible_for_final_origin_confirmation,
      x$primary_ratio,
      x$worst_ratio_to_anchor,
      x$runtime_sec_median,
      x$design_role
    ), , drop = FALSE]
    x$rank_within_cell <- seq_len(nrow(x))
    x$selected_for_final_origin_confirmation <-
      x$rank_within_cell == 1L & x$eligible_for_final_origin_confirmation
    x
  }
))
selected <- ranked[ranked$selected_for_final_origin_confirmation, , drop = FALSE]

parent_context <- parent_envelope[
  grepl("^qdesn_", parent_envelope$model_variant) &
    paste(
      parent_envelope$model_variant,
      parent_envelope$family,
      sprintf("%.8f", num(parent_envelope$tau)),
      sep = "|"
    ) %in% paste(
      targets$model_variant,
      targets$family,
      sprintf("%.8f", num(targets$tau)),
      sep = "|"
    ),
  ,
  drop = FALSE
]

stamp <- as.character(get_arg("--stamp", format(Sys.Date(), "%Y%m%d")))[1L]
closeout_id <- paste0("qdesn_500obs_mcmc_nested_cellwise_v1_closeout_", stamp)
out_root <- resolve_path(
  get_arg(
    "--out-root",
    file.path("validation", "fitforecast_v2", "promotions", closeout_id)
  ),
  FALSE
)
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

outputs <- c(
  campaigns = write_csv(campaigns, file.path(out_root, "campaign_completion.csv")),
  seed_rows = write_csv(seeds, file.path(out_root, "replicated_seed_metrics.csv")),
  aggregated = write_csv(aggregated, file.path(out_root, "design_aggregate_metrics.csv")),
  ranked = write_csv(ranked, file.path(out_root, "cellwise_candidate_ranking.csv")),
  selected = write_csv(selected, file.path(out_root, "final_origin_confirmation_handoff.csv")),
  anchor_reference = write_csv(references, file.path(out_root, "calibration_anchor_reference.csv")),
  parent_context = write_csv(parent_context, file.path(out_root, "final_origin_parent_context.csv")),
  storage = write_csv(storage, file.path(out_root, "storage_audit.csv"))
)
source_manifest <- data.frame(
  role = names(source_files),
  path = unname(source_files),
  sha256 = vapply(unname(source_files), sha256, character(1L)),
  stringsAsFactors = FALSE
)
source_manifest_path <- write_csv(
  source_manifest,
  file.path(out_root, "source_manifest.csv")
)
outputs <- c(outputs, source_manifest = source_manifest_path)
file_manifest <- data.frame(
  role = names(outputs),
  path = unname(outputs),
  sha256 = vapply(unname(outputs), sha256, character(1L)),
  stringsAsFactors = FALSE
)
file_manifest_path <- write_csv(
  file_manifest,
  file.path(out_root, "file_manifest.csv")
)

decision <- if (nrow(selected)) {
  "FINAL_ORIGIN_CONFIRMATION_REQUIRED_FOR_SELECTED_CELLWISE_CANDIDATES"
} else {
  "NO_NOVEL_CANDIDATE_CLEARED_REPLICATED_CALIBRATION_GATES"
}
manifest <- list(
  generated_at = as.character(Sys.time()),
  closeout_id = closeout_id,
  stage_base = stage_base,
  run_tags = as.list(run_tags),
  source_registry_hash_value = source_hash,
  expected_roots = 720L,
  observed_terminal_roots = sum(campaigns$roots_total),
  observed_successful_roots = sum(campaigns$roots_success),
  expected_seed_rows = 1440L,
  observed_seed_rows = nrow(seeds),
  complete_replicated_designs = sum(ranked$replication_complete),
  selected_cells = nrow(selected),
  storage_heavy_files = nrow(storage),
  gate_reference = "same-window declared anchor controls",
  final_origin_discovery_excluded = TRUE,
  article_updated = FALSE,
  decision = decision,
  source_manifest = source_manifest_path,
  file_manifest = file_manifest_path
)
manifest_path <- write_json(
  manifest,
  file.path(out_root, paste0(closeout_id, "_manifest.json"))
)

cat(sprintf("closeout_root: %s\n", out_root))
cat(sprintf("manifest: %s\n", manifest_path))
cat(sprintf("terminal_roots: %d/720\n", sum(campaigns$roots_total)))
cat(sprintf("seed_rows: %d/1440\n", nrow(seeds)))
cat(sprintf("selected_cells: %d/15\n", nrow(selected)))
cat(sprintf("decision: %s\n", decision))
