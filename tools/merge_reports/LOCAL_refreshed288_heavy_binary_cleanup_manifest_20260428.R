#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

run_tag <- "20260422_p90_full288_baseline_v1"
run_root <- file.path("tools", "merge_reports", paste0("full288_refreshed288_", run_tag))
manifest_path <- file.path("tools", "merge_reports", paste0("LOCAL_refreshed288_full_manifest_", run_tag, ".csv"))
status_path <- file.path("tools", "merge_reports", paste0("LOCAL_refreshed288_full_manifest_status_", run_tag, ".csv"))
out_dir <- file.path("reports", "static_exal_tuning_20260428")
out_csv <- file.path(out_dir, "refreshed288_heavy_binary_cleanup_manifest_20260428.csv")
out_md <- file.path(out_dir, "refreshed288_heavy_binary_cleanup_manifest_summary_20260428.md")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

`%||%` <- function(x, y) {
  if (is.null(x) || !length(x)) y else x
}

parse_args <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

read_csv_if_exists <- function(path) {
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

bytes_to_gb <- function(x) round(as.numeric(x) / 1024^3, 6)
truthy <- function(x) {
  if (is.logical(x)) return(x & !is.na(x))
  tolower(as.character(x)) %in% c("true", "t", "1", "yes", "y")
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
delete_confirm <- args[["delete-confirm"]] %||% ""
delete_candidate_fits <- truthy(args[["delete-candidate-fits"]] %||% FALSE)
delete_draw_exports <- truthy(args[["delete-draw-exports"]] %||% FALSE)
delete_enabled <- identical(delete_confirm, run_tag)
if ((delete_candidate_fits || delete_draw_exports) && !delete_enabled) {
  stop(sprintf("Deletion requested but --delete-confirm=%s was not supplied", run_tag), call. = FALSE)
}

manifest <- read_csv_if_exists(manifest_path)
status <- read_csv_if_exists(status_path)
if (is.null(manifest)) {
  stop(sprintf("Missing manifest: %s", manifest_path), call. = FALSE)
}
if (is.null(status)) {
  status <- data.frame(row_id = manifest$row_id, status_current = "unknown", gate_current = NA_character_, stringsAsFactors = FALSE)
}

status_small <- status[, intersect(c("row_id", "status_current", "gate_current", "healthy_current", "error_current", "metric_error"), names(status)), drop = FALSE]
rows <- merge(manifest, status_small, by = "row_id", all.x = TRUE, sort = FALSE)

path_rows <- list()

add_artifact <- function(kind, path_col, default_action, can_delete_for_comparison, needs_plot_summary_before_delete) {
  if (!path_col %in% names(rows)) return(invisible(NULL))
  idx <- which(!is.na(rows[[path_col]]) & nzchar(rows[[path_col]]))
  if (!length(idx)) return(invisible(NULL))

  paths <- rows[[path_col]][idx]
  info <- file.info(paths)
  exists <- !is.na(info$size)
  if (!any(exists)) return(invisible(NULL))
  idx <- idx[exists]
  paths <- paths[exists]
  info <- info[exists, , drop = FALSE]

  plot_summary_path <- file.path(
    run_root,
    "plot_summaries",
    sprintf("row_%04d_plot_summary.csv", rows$row_id[idx])
  )
  if ("plot_summary_path" %in% names(rows)) {
    manifest_plot <- rows$plot_summary_path[idx]
    plot_summary_path[!is.na(manifest_plot) & nzchar(manifest_plot)] <- manifest_plot[!is.na(manifest_plot) & nzchar(manifest_plot)]
  }
  parameter_summary_path <- file.path(
    run_root,
    "parameter_summaries",
    sprintf("row_%04d_parameter_summary.csv", rows$row_id[idx])
  )
  if ("parameter_summary_path" %in% names(rows)) {
    manifest_param <- rows$parameter_summary_path[idx]
    parameter_summary_path[!is.na(manifest_param) & nzchar(manifest_param)] <- manifest_param[!is.na(manifest_param) & nzchar(manifest_param)]
  }
  plot_exists <- file.exists(plot_summary_path)
  parameter_exists <- file.exists(parameter_summary_path)
  needs_summary <- needs_plot_summary_before_delete & (!plot_exists | (rows$block[idx] == "static" & !parameter_exists))

  path_rows[[length(path_rows) + 1L]] <<- data.frame(
    row_id = rows$row_id[idx],
    original_case_key = rows$original_case_key[idx],
    block = rows$block[idx],
    root_kind = rows$root_kind[idx],
    family = rows$family[idx],
    tau_label = rows$tau_label[idx],
    fit_size = rows$fit_size[idx],
    prior_semantics = rows$prior_semantics[idx],
    model = rows$model[idx],
    inference = rows$inference[idx],
    status_current = rows$status_current[idx],
    gate_current = rows$gate_current[idx],
    artifact_kind = kind,
    path = paths,
    size_bytes = as.numeric(info$size),
    size_gb = bytes_to_gb(info$size),
    can_delete_for_comparison = can_delete_for_comparison,
    plot_summary_path = plot_summary_path,
    plot_summary_exists = plot_exists,
    parameter_summary_path = parameter_summary_path,
    parameter_summary_exists = parameter_exists,
    needs_plot_summary_before_delete = needs_plot_summary_before_delete & !plot_exists,
    needs_parameter_summary_before_delete = needs_plot_summary_before_delete & rows$block[idx] == "static" & !parameter_exists,
    recommended_action = ifelse(
      needs_summary,
      "extract_lightweight_summary_before_delete",
      default_action
    ),
    delete_eligible = ifelse(kind == "candidate_fit", !needs_summary, ifelse(kind == "draw_export", TRUE, FALSE)),
    deleted = FALSE,
    post_delete_exists = NA,
    stringsAsFactors = FALSE
  )
}

add_artifact(
  kind = "candidate_fit",
  path_col = "candidate_fit_path",
  default_action = "delete_after_lightweight_artifacts_verified",
  can_delete_for_comparison = TRUE,
  needs_plot_summary_before_delete = TRUE
)
add_artifact(
  kind = "draw_export",
  path_col = "draws_path",
  default_action = "optional_keep_or_delete_after_plot_summary",
  can_delete_for_comparison = TRUE,
  needs_plot_summary_before_delete = FALSE
)
add_artifact(
  kind = "vb_init",
  path_col = "vb_init_fit_path",
  default_action = "delete_after_row_completion",
  can_delete_for_comparison = TRUE,
  needs_plot_summary_before_delete = FALSE
)
add_artifact(
  kind = "config",
  path_col = "config_path",
  default_action = "keep",
  can_delete_for_comparison = FALSE,
  needs_plot_summary_before_delete = FALSE
)

cleanup <- if (length(path_rows)) do.call(rbind, path_rows) else data.frame()
cleanup <- cleanup[order(-cleanup$size_bytes, cleanup$artifact_kind, cleanup$row_id), , drop = FALSE]

if (nrow(cleanup) && delete_enabled) {
  delete_idx <- rep(FALSE, nrow(cleanup))
  if (delete_candidate_fits) {
    delete_idx <- delete_idx | (cleanup$artifact_kind == "candidate_fit" & cleanup$delete_eligible)
  }
  if (delete_draw_exports) {
    delete_idx <- delete_idx | (cleanup$artifact_kind == "draw_export" & cleanup$delete_eligible)
  }
  if (any(delete_idx)) {
    deleted <- file.exists(cleanup$path[delete_idx]) & unlink(cleanup$path[delete_idx], force = TRUE) == 0L
    cleanup$deleted[delete_idx] <- deleted
  }
  cleanup$post_delete_exists <- file.exists(cleanup$path)
}

utils::write.csv(cleanup, out_csv, row.names = FALSE)

summ <- aggregate(
  cbind(size_bytes, size_gb) ~ artifact_kind + recommended_action,
  data = cleanup,
  FUN = sum
)
count_summ <- aggregate(
  row_id ~ artifact_kind + recommended_action,
  data = cleanup,
  FUN = length
)
names(count_summ)[names(count_summ) == "row_id"] <- "n"
summ <- merge(count_summ, summ, by = c("artifact_kind", "recommended_action"), all = TRUE, sort = FALSE)
summ$size_gb <- round(summ$size_bytes / 1024^3, 3)
summ <- summ[order(-summ$size_bytes), , drop = FALSE]

md <- c(
  "# Refreshed288 Heavy Binary Cleanup Manifest Summary",
  "",
  sprintf("Date: %s", as.character(Sys.Date())),
  "",
  sprintf("Run root: `%s`", run_root),
  "",
  sprintf("Manifest CSV: `%s`", out_csv),
  "",
  "## Summary",
  "",
  "| Artifact | Recommended Action | Count | Size GB |",
  "|---|---|---:|---:|"
)
if (nrow(summ)) {
  md <- c(
    md,
    sprintf(
      "| `%s` | `%s` | %d | %.3f |",
      summ$artifact_kind,
      summ$recommended_action,
      summ$n,
      summ$size_gb
    )
  )
}
md <- c(
  md,
  "",
  "## Interpretation",
  "",
  "- `candidate_fit` artifacts are not required by the current comparison analysis once row-level `health`, `metrics`, and `rows` CSVs are written.",
  "- Because fitted-quantile plotting needs compact per-observation summaries, the safe cleanup path is to extract `plot_summaries/row_####_plot_summary.csv` first, then delete candidate fits.",
  "- `draw_export` artifacts are optional for the current comparison tables. Static draw exports are useful only if we want posterior parameter samples beyond compact summaries.",
  "- `config` artifacts are intentionally marked `keep` because they are small and carry reproducibility metadata.",
  "",
  if (delete_enabled) {
    sprintf("Deletion mode was enabled with `--delete-confirm=%s`; deleted candidate fits: `%d`; deleted draw exports: `%d`.",
            run_tag,
            sum(cleanup$deleted & cleanup$artifact_kind == "candidate_fit", na.rm = TRUE),
            sum(cleanup$deleted & cleanup$artifact_kind == "draw_export", na.rm = TRUE))
  } else {
    "No files were deleted by this manifest script."
  }
)
writeLines(md, out_md)

cat(sprintf("Wrote cleanup manifest: %s\n", out_csv))
cat(sprintf("Wrote cleanup summary: %s\n", out_md))
cat(sprintf("Candidate fit GB: %.3f\n", sum(cleanup$size_gb[cleanup$artifact_kind == "candidate_fit"], na.rm = TRUE)))
if (delete_enabled) {
  cat(sprintf("Deleted candidate fits: %d\n", sum(cleanup$deleted & cleanup$artifact_kind == "candidate_fit", na.rm = TRUE)))
  cat(sprintf("Deleted draw exports: %d\n", sum(cleanup$deleted & cleanup$artifact_kind == "draw_export", na.rm = TRUE)))
} else {
  cat("No files were deleted.\n")
}
