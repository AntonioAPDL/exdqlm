#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  for (pkg in c("jsonlite", "digest")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Missing package: %s", pkg), call. = FALSE)
    }
  }
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (!length(i) || i[[1L]] >= length(args)) return(default)
  args[[i[[1L]] + 1L]]
}
repo_root <- normalizePath(get_arg(
  "--repo-root", system("git rev-parse --show-toplevel", intern = TRUE)
), winslash = "/", mustWork = TRUE)
setwd(repo_root)
source(file.path(repo_root, "validation", "fitforecast_v2", "R",
                 "independent_exal_m0_structural_screen_v2.R"))

interface_path <- normalizePath(get_arg(
  "--interface",
  file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809",
    "qdesn_dqlm_500obs_trainonly_article_v4_exal_m0_20260809_interface.csv"
  )
), winslash = "/", mustWork = TRUE)
source_roots_path <- normalizePath(get_arg(
  "--source-roots",
  file.path(repo_root, "config", "validation",
            "qdesn_article_rolling_rebaseline_v1_source_roots.csv")
), winslash = "/", mustWork = TRUE)
output_root <- normalizePath(get_arg(
  "--output-root",
  file.path(repo_root, "reports", "shared_fitforecast_v2_orchestration",
            "qdesn_article_rolling_rebaseline_v1")
), winslash = "/", mustWork = FALSE)
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
write_csv <- function(x, name) {
  path <- file.path(output_root, name)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}
sha256 <- function(path) {
  unname(digest::digest(file = path, algo = "sha256", serialize = FALSE))
}
first_value <- function(x, names, default = NA_character_) {
  for (nm in names) {
    if (nm %in% colnames(x) && length(x[[nm]])) return(x[[nm]][[1L]])
  }
  default
}
classify_stage <- function(path) {
  if (grepl("/full__", path, fixed = TRUE)) return("full")
  if (grepl("/canary__", path, fixed = TRUE)) return("canary")
  if (grepl("/smoke__", path, fixed = TRUE)) return("smoke")
  "single"
}
locate_rolling_path <- function(fit_path, fit_row) {
  declared <- as.character(first_value(
    fit_row, c("forecast_rolling_origin_path_file"), ""
  ))
  sibling <- file.path(dirname(fit_path), "tables", "forecast_rolling_origin_paths.csv")
  candidates <- unique(c(sibling, declared))
  candidates <- candidates[nzchar(candidates) & !is.na(candidates)]
  found <- candidates[file.exists(candidates)]
  if (length(found)) normalizePath(found[[1L]], winslash = "/", mustWork = TRUE) else NA_character_
}
locate_lead_path <- function(fit_path, fit_row) {
  declared <- as.character(first_value(
    fit_row, c("forecast_lead_metrics_path"), ""
  ))
  sibling <- file.path(dirname(fit_path), "tables", "forecast_lead_metrics.csv")
  candidates <- unique(c(sibling, declared))
  candidates <- candidates[nzchar(candidates) & !is.na(candidates)]
  found <- candidates[file.exists(candidates)]
  if (length(found)) normalizePath(found[[1L]], winslash = "/", mustWork = TRUE) else NA_character_
}

source_roots <- read_csv(source_roots_path)
required_root_columns <- c("run_tag", "source_role", "run_root")
if (!all(required_root_columns %in% names(source_roots))) {
  stop("Source-root registry schema is incomplete.", call. = FALSE)
}
if (any(!dir.exists(source_roots$run_root))) {
  stop(sprintf(
    "Missing validation source roots: %s",
    paste(source_roots$run_root[!dir.exists(source_roots$run_root)], collapse = "; ")
  ), call. = FALSE)
}

index_rows <- list()
k <- 0L
for (i in seq_len(nrow(source_roots))) {
  root <- source_roots[i, , drop = FALSE]
  paths <- list.files(
    root$run_root[[1L]], pattern = "^fit_summary_row[.]csv$",
    recursive = TRUE, full.names = TRUE
  )
  for (path in paths) {
    fit <- tryCatch(read_csv(path), error = function(e) data.frame())
    if (!nrow(fit)) next
    candidate_id <- as.character(first_value(fit, c("candidate_id", "spec_id"), ""))
    spec_id <- as.character(first_value(fit, c("spec_id", "candidate_id"), ""))
    k <- k + 1L
    index_rows[[k]] <- data.frame(
      run_tag = root$run_tag[[1L]],
      source_role = root$source_role[[1L]],
      stage = classify_stage(normalizePath(path, winslash = "/", mustWork = TRUE)),
      candidate_id = candidate_id,
      spec_id = spec_id,
      fit_summary_path = normalizePath(path, winslash = "/", mustWork = TRUE),
      fit_summary_sha256 = sha256(path),
      rolling_path = locate_rolling_path(path, fit),
      lead_path = locate_lead_path(path, fit),
      stringsAsFactors = FALSE
    )
  }
}
if (!length(index_rows)) stop("No raw fit summaries were indexed.", call. = FALSE)
raw_index <- do.call(rbind, index_rows)

rolling_contract <- function(path) {
  out <- list(
    decision = "FAIL", rows = 0L, leads = 0L, origins = 0L,
    target_start = NA_integer_, target_end = NA_integer_,
    mae = NA_real_, check = NA_real_, failed_checks = "missing_file"
  )
  if (is.na(path) || !file.exists(path)) return(out)
  x <- tryCatch(read_csv(path), error = function(e) data.frame())
  required <- c(
    "forecast_lead", "forecast_origin_source_index", "target_source_index",
    "origin_stride", "refit_per_origin", "abs_q_error", "pinball_tau"
  )
  columns_ok <- all(required %in% names(x))
  checks <- c(
    columns = columns_ok,
    rows = columns_ok && nrow(x) == 1000L,
    targets = columns_ok && identical(
      sort(as.integer(x$target_source_index)), 9001:10000
    ),
    leads = columns_ok && identical(
      sort(unique(as.integer(x$forecast_lead))), 1:30
    ),
    origins = columns_ok && identical(
      sort(unique(as.integer(x$forecast_origin_source_index))),
      seq.int(9000L, 9990L, by = 30L)
    ),
    stride = columns_ok && all(as.integer(x$origin_stride) == 30L),
    no_refit = columns_ok && all(!as.logical(x$refit_per_origin)),
    finite = columns_ok && all(is.finite(as.numeric(x$abs_q_error))) &&
      all(is.finite(as.numeric(x$pinball_tau)))
  )
  checks[is.na(checks)] <- FALSE
  out$decision <- if (all(checks)) "PASS" else "FAIL"
  out$rows <- nrow(x)
  if (columns_ok && nrow(x)) {
    out$leads <- length(unique(as.integer(x$forecast_lead)))
    out$origins <- length(unique(as.integer(x$forecast_origin_source_index)))
    out$target_start <- min(as.integer(x$target_source_index), na.rm = TRUE)
    out$target_end <- max(as.integer(x$target_source_index), na.rm = TRUE)
    out$mae <- mean(as.numeric(x$abs_q_error))
    out$check <- mean(as.numeric(x$pinball_tau))
  }
  out$failed_checks <- paste(names(checks)[!checks], collapse = ";")
  out
}

aggregate_metadata_contract <- function(path, candidate_id, family, tau, inference) {
  out <- list(decision = "UNRESOLVED", rows = 0L, n_leads = NA_integer_,
              n_origins = NA_integer_)
  if (is.na(path) || !file.exists(path) || !grepl("[.]csv$", path)) return(out)
  x <- tryCatch(read_csv(path), error = function(e) data.frame())
  if (!nrow(x) || !all(c("candidate_id", "family", "tau") %in% names(x))) return(out)
  keep <- as.character(x$candidate_id) == as.character(candidate_id) &
    as.character(x$family) == as.character(family) &
    abs(as.numeric(x$tau) - as.numeric(tau)) < 1e-10
  if ("inference" %in% names(x)) keep <- keep & as.character(x$inference) == inference
  x <- x[keep, , drop = FALSE]
  if (!nrow(x)) return(out)
  out$rows <- nrow(x)
  if (all(c("n_leads", "n_origins_scored_total") %in% names(x))) {
    out$n_leads <- as.integer(x$n_leads[[1L]])
    out$n_origins <- as.integer(x$n_origins_scored_total[[1L]])
    out$decision <- if (out$n_leads == 30L && out$n_origins == 1000L) {
      "METADATA_PASS_RAW_PATH_UNAVAILABLE"
    } else "METADATA_FAIL"
  }
  out
}

interface <- read_csv(interface_path)
required_interface <- c(
  "inference", "model_variant", "family", "tau",
  "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000",
  "forecast_mae_source_candidate_id", "forecast_mae_source_run_tag",
  "forecast_mae_source_path", "forecast_check_source_candidate_id",
  "forecast_check_source_run_tag", "forecast_check_source_path"
)
if (!all(required_interface %in% names(interface))) {
  stop("Article interface schema is incomplete.", call. = FALSE)
}

role_spec <- list(
  forecast_mae = list(
    value = "forecast_qtrue_mae_H1000",
    candidate = "forecast_mae_source_candidate_id",
    run_tag = "forecast_mae_source_run_tag",
    path = "forecast_mae_source_path",
    raw_value = "mae"
  ),
  forecast_check = list(
    value = "forecast_check_loss_H1000",
    candidate = "forecast_check_source_candidate_id",
    run_tag = "forecast_check_source_run_tag",
    path = "forecast_check_source_path",
    raw_value = "check"
  )
)

audit_rows <- list()
k <- 0L
for (i in seq_len(nrow(interface))) {
  row <- interface[i, , drop = FALSE]
  is_qdesn <- grepl("^qdesn_", as.character(row$model_variant[[1L]]))
  for (metric_role in names(role_spec)) {
    spec <- role_spec[[metric_role]]
    candidate_id <- as.character(row[[spec$candidate]][[1L]])
    run_tag <- as.character(row[[spec$run_tag]][[1L]])
    source_path <- as.character(row[[spec$path]][[1L]])
    reported <- as.numeric(row[[spec$value]][[1L]])
    matches <- raw_index[
      raw_index$run_tag == run_tag &
        (raw_index$candidate_id == candidate_id | raw_index$spec_id == candidate_id),
      , drop = FALSE
    ]
    if (nrow(matches) && any(matches$stage == "full")) {
      matches <- matches[matches$stage == "full", , drop = FALSE]
    }
    raw_results <- if (nrow(matches)) {
      lapply(matches$rolling_path, rolling_contract)
    } else list()
    raw_pass <- if (length(raw_results)) {
      vapply(raw_results, function(x) identical(x$decision, "PASS"), logical(1L))
    } else logical()
    rederived <- if (length(raw_results) && all(raw_pass)) {
      mean(vapply(raw_results, function(x) as.numeric(x[[spec$raw_value]]), numeric(1L)))
    } else NA_real_
    metadata <- if (!is_qdesn) {
      aggregate_metadata_contract(
        source_path, candidate_id, row$family[[1L]], row$tau[[1L]],
        row$inference[[1L]]
      )
    } else list(decision = "NOT_USED", rows = 0L, n_leads = NA_integer_,
                n_origins = NA_integer_)
    evidence_status <- if (is_qdesn && length(raw_results) && all(raw_pass)) {
      "RAW_ROLLING_PASS"
    } else if (is_qdesn) {
      "RAW_ROLLING_UNRESOLVED"
    } else metadata$decision
    k <- k + 1L
    audit_rows[[k]] <- data.frame(
      interface_row = i,
      inference = row$inference[[1L]],
      model_variant = row$model_variant[[1L]],
      family = row$family[[1L]],
      tau = as.numeric(row$tau[[1L]]),
      metric_role = metric_role,
      candidate_id = candidate_id,
      run_tag = run_tag,
      reported_value = reported,
      rederived_rolling_value = rederived,
      absolute_difference = if (is.finite(rederived)) rederived - reported else NA_real_,
      relative_difference_pct = if (is.finite(rederived) && is.finite(reported) && reported != 0) {
        100 * (rederived / reported - 1)
      } else NA_real_,
      raw_fit_rows = nrow(matches),
      raw_rolling_paths = length(raw_results),
      raw_rolling_paths_pass = sum(raw_pass),
      aggregate_metadata_rows = metadata$rows,
      aggregate_n_leads = metadata$n_leads,
      aggregate_n_origins = metadata$n_origins,
      evidence_status = evidence_status,
      source_path = source_path,
      source_path_exists = file.exists(source_path),
      source_path_sha256 = if (file.exists(source_path)) sha256(source_path) else NA_character_,
      raw_rolling_path_list = if (nrow(matches)) {
        paste(matches$rolling_path, collapse = ";")
      } else NA_character_,
      raw_rolling_sha256_list = if (nrow(matches)) {
        paste(vapply(matches$rolling_path, function(path) {
          if (!is.na(path) && file.exists(path)) sha256(path) else NA_character_
        }, character(1L)), collapse = ";")
      } else NA_character_,
      stringsAsFactors = FALSE
    )
  }
}
audit <- do.call(rbind, audit_rows)
audit_path <- write_csv(audit, "rolling_metric_contract_audit.csv")
qdesn_rederived <- audit[
  grepl("^qdesn_", audit$model_variant) & audit$evidence_status == "RAW_ROLLING_PASS",
  , drop = FALSE
]
qdesn_path <- write_csv(qdesn_rederived, "qdesn_rederived_rolling_metrics.csv")
unresolved <- audit[!audit$evidence_status %in% c(
  "RAW_ROLLING_PASS", "METADATA_PASS_RAW_PATH_UNAVAILABLE"
), , drop = FALSE]
unresolved_path <- write_csv(unresolved, "unresolved_evidence_ledger.csv")

# Keep the corrected interface separate from the promoted article interface. The
# additional guard columns make accidental article consumption fail visibly.
provisional <- interface
provisional$forecast_metric_contract <- ifelse(
  grepl("^qdesn_", provisional$model_variant),
  "raw_rolling_origin_rederived", "aggregate_metadata_verified"
)
provisional$rolling_rebaseline_state <- "PROVISIONAL_NOT_ARTICLE_AUTHORITY"
provisional$article_consumption_allowed <- FALSE
for (i in seq_len(nrow(qdesn_rederived))) {
  row_id <- as.integer(qdesn_rederived$interface_row[[i]])
  value <- as.numeric(qdesn_rederived$rederived_rolling_value[[i]])
  if (qdesn_rederived$metric_role[[i]] == "forecast_mae") {
    provisional$forecast_qtrue_mae_H1000[[row_id]] <- value
  } else if (qdesn_rederived$metric_role[[i]] == "forecast_check") {
    provisional$forecast_check_loss_H1000[[row_id]] <- value
  }
}
provisional_path <- write_csv(
  provisional, "provisional_rolling_rebaseline_interface.csv"
)

metric_columns <- c(
  fit_rmse = "fit_qtrue_rmse",
  forecast_mae = "forecast_qtrue_mae_H1000",
  forecast_check = "forecast_check_loss_H1000"
)
gap_rows <- list()
g <- 0L
for (inference in sort(unique(provisional$inference))) {
  for (family in sort(unique(provisional$family))) {
    for (tau in sort(unique(provisional$tau))) {
      cell <- provisional[
        provisional$inference == inference & provisional$family == family &
          abs(provisional$tau - tau) < 1e-10,
        , drop = FALSE
      ]
      comparators <- cell[cell$model_variant %in% c("dqlm", "exdqlm"), , drop = FALSE]
      qdesn <- cell[grepl("^qdesn_", cell$model_variant), , drop = FALSE]
      if (!nrow(comparators) || !nrow(qdesn)) next
      for (metric in names(metric_columns)) {
        column <- metric_columns[[metric]]
        comparator_values <- as.numeric(comparators[[column]])
        if (!any(is.finite(comparator_values))) next
        best_index <- which.min(ifelse(is.finite(comparator_values), comparator_values, Inf))
        comparator_value <- comparator_values[[best_index]]
        comparator_model <- comparators$model_variant[[best_index]]
        for (i in seq_len(nrow(qdesn))) {
          value <- as.numeric(qdesn[[column]][[i]])
          gap_pct <- if (is.finite(value) && is.finite(comparator_value) &&
                         comparator_value != 0) {
            100 * (value / comparator_value - 1)
          } else NA_real_
          outcome <- if (!is.finite(gap_pct)) {
            "UNRESOLVED"
          } else if (gap_pct <= 0) {
            "WIN"
          } else if (gap_pct <= 5) {
            "WITHIN_5PCT"
          } else {
            "GAP_GT_5PCT"
          }
          g <- g + 1L
          gap_rows[[g]] <- data.frame(
            inference = inference,
            model_variant = qdesn$model_variant[[i]],
            model_label = qdesn$model_label[[i]],
            family = family,
            tau = tau,
            metric = metric,
            qdesn_value = value,
            comparator_model = comparator_model,
            comparator_value = comparator_value,
            absolute_gap = value - comparator_value,
            relative_gap_pct = gap_pct,
            outcome = outcome,
            tolerance_pct = 5,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
}
metric_gap <- do.call(rbind, gap_rows)
metric_gap_path <- write_csv(metric_gap, "qdesn_comparator_metric_gap_ledger.csv")

cell_keys <- unique(metric_gap[c(
  "inference", "model_variant", "model_label", "family", "tau"
)])
cell_rows <- lapply(seq_len(nrow(cell_keys)), function(i) {
  key <- cell_keys[i, , drop = FALSE]
  x <- metric_gap[
    metric_gap$inference == key$inference &
      metric_gap$model_variant == key$model_variant &
      metric_gap$family == key$family &
      abs(metric_gap$tau - key$tau) < 1e-10,
    , drop = FALSE
  ]
  gaps <- x$outcome == "GAP_GT_5PCT"
  max_gap <- if (any(is.finite(x$relative_gap_pct))) {
    max(x$relative_gap_pct, na.rm = TRUE)
  } else NA_real_
  priority <- if (!any(gaps)) {
    "CLOSE_OR_WIN"
  } else if (key$inference == "mcmc" && is.finite(max_gap) && max_gap > 25) {
    "P0_MCMC_LARGE_GAP"
  } else if (key$inference == "mcmc") {
    "P1_MCMC_GAP"
  } else {
    "P2_VB_GAP"
  }
  data.frame(
    inference = key$inference,
    model_variant = key$model_variant,
    model_label = key$model_label,
    family = key$family,
    tau = key$tau,
    metrics_won = sum(x$outcome == "WIN"),
    metrics_within_5pct = sum(x$outcome == "WITHIN_5PCT"),
    metrics_gap_gt_5pct = sum(gaps),
    largest_relative_gap_pct = max_gap,
    gap_metrics = paste(x$metric[gaps], collapse = ";"),
    priority = priority,
    stringsAsFactors = FALSE
  )
})
cell_gap <- do.call(rbind, cell_rows)
cell_gap <- cell_gap[order(
  factor(cell_gap$priority, levels = c(
    "P0_MCMC_LARGE_GAP", "P1_MCMC_GAP", "P2_VB_GAP", "CLOSE_OR_WIN"
  )), -cell_gap$largest_relative_gap_pct,
  cell_gap$inference, cell_gap$model_variant, cell_gap$family, cell_gap$tau
), , drop = FALSE]
cell_gap_path <- write_csv(cell_gap, "qdesn_comparator_cell_priority_ledger.csv")

tolerance <- 1e-8
mismatch <- is.finite(qdesn_rederived$absolute_difference) &
  abs(qdesn_rederived$absolute_difference) > tolerance
decision <- if (nrow(unresolved) || any(mismatch)) {
  "BLOCK_AUTOMATIC_ARTICLE_REBASELINE"
} else {
  "PASS_FOR_MANUAL_PROMOTION_REVIEW"
}
manifest_path <- file.path(output_root, "rolling_metric_contract_manifest.json")
qdesn_ssv2_write_json(list(
  generated_at = as.character(Sys.time()),
  decision = decision,
  interface = list(path = interface_path, sha256 = sha256(interface_path),
                   rows = nrow(interface)),
  source_roots = list(path = source_roots_path, sha256 = sha256(source_roots_path),
                      rows = nrow(source_roots)),
  indexed_fit_summaries = nrow(raw_index),
  audit_rows = nrow(audit),
  qdesn_raw_rolling_pass_rows = nrow(qdesn_rederived),
  qdesn_metric_mismatches = sum(mismatch),
  unresolved_rows = nrow(unresolved),
  tolerance = tolerance,
  outputs = list(
    audit = list(path = audit_path, sha256 = sha256(audit_path)),
    qdesn_rederived = list(path = qdesn_path, sha256 = sha256(qdesn_path)),
    unresolved = list(path = unresolved_path, sha256 = sha256(unresolved_path)),
    provisional_interface = list(
      path = provisional_path, sha256 = sha256(provisional_path),
      state = "PROVISIONAL_NOT_ARTICLE_AUTHORITY"
    ),
    metric_gap_ledger = list(
      path = metric_gap_path, sha256 = sha256(metric_gap_path),
      rows = nrow(metric_gap)
    ),
    cell_priority_ledger = list(
      path = cell_gap_path, sha256 = sha256(cell_gap_path),
      rows = nrow(cell_gap)
    )
  ),
  promotion_automatic = FALSE
), manifest_path)
cat(sprintf(
  "decision=%s audit_rows=%d qdesn_raw_pass=%d mismatches=%d unresolved=%d\n",
  decision, nrow(audit), nrow(qdesn_rederived), sum(mismatch), nrow(unresolved)
))
