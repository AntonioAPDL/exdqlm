#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

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

safe_int <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

extract_tt <- function(path) {
  m <- regexec("tt([0-9]+)", path)
  g <- regmatches(path, m)[[1]]
  if (length(g) >= 2L) safe_int(g[2]) else NA_integer_
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
manifest_path <- as.character(args$manifest %||% file.path(
  out_dir, "LOCAL_full288_manifest_rhsns_full_relaunch_20260327.csv"
))

if (!file.exists(manifest_path)) {
  stop(sprintf("manifest not found: %s", manifest_path))
}

candidates <- data.frame(
  candidate_id = c(
    "F080_sub2_s100_ref",
    "F080_sub2_s095",
    "F080_sub2_s105",
    "F075_sub2_s095",
    "F075_sub2_s105",
    "F085_sub2_s095",
    "F085_sub2_s105",
    "F0825_sub2_s100"
  ),
  gamma_substeps = c(2, 2, 2, 2, 2, 2, 2, 2),
  p_global_eta_jump = c(0.080, 0.080, 0.080, 0.075, 0.075, 0.085, 0.085, 0.0825),
  global_eta_jump_scale = c(1.00, 0.95, 1.05, 0.95, 1.05, 0.95, 1.05, 1.00),
  family = c(
    "f080_reference",
    "f080_scale",
    "f080_scale",
    "f075_scale",
    "f075_scale",
    "f085_scale",
    "f085_scale",
    "f0825_center"
  ),
  why_included = c(
    "best transfer baseline from wave-7",
    "tighten scale to reduce drift",
    "widen scale to reduce stickiness",
    "lower frequency + tighter scale",
    "lower frequency + wider scale",
    "upper edge with tempered scale",
    "upper edge with wider scale",
    "midpoint between F080 and F085"
  ),
  stringsAsFactors = FALSE
)

stage_rows <- list(
  transfer6 = c(83L, 107L, 115L, 119L, 197L, 245L),
  guard8 = c(83L, 99L, 107L, 115L, 119L, 197L, 245L, 277L),
  mix12_transfer = c(75L, 83L, 91L, 99L, 107L, 115L, 119L, 139L, 149L, 197L, 245L, 277L)
)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
needed_rows <- sort(unique(unlist(stage_rows)))

rows <- manifest[manifest$row_id %in% needed_rows, , drop = FALSE]
if (!nrow(rows)) stop("no rows matched the requested stage rows")

rows <- rows[rows$inference == "mcmc" & rows$model == "exal", , drop = FALSE]
if (!nrow(rows)) stop("no exal/mcmc rows matched the requested stage rows")

missing_rows <- setdiff(needed_rows, rows$row_id)
if (length(missing_rows)) {
  warning(sprintf("missing row_ids in manifest: %s", paste(missing_rows, collapse = ",")))
}

rows$run_root <- as.character(rows$run_root)
rows$tt <- vapply(rows$run_root, extract_tt, integer(1))
rows$tau_label <- as.character(rows$tau_label)
rows$p0 <- vapply(rows$tau, safe_num, numeric(1))

stage_rows_df <- do.call(
  rbind,
  lapply(names(stage_rows), function(stage) {
    data.frame(
      stage = stage,
      row_id = as.integer(stage_rows[[stage]]),
      stringsAsFactors = FALSE
    )
  })
)

row_map <- rows[, c("row_id", "run_root", "root_kind", "family", "tt", "tau_label", "p0"), drop = FALSE]
row_map <- row_map[order(row_map$row_id), , drop = FALSE]

schedule <- do.call(
  rbind,
  lapply(names(stage_rows), function(stage) {
    rsub <- row_map[row_map$row_id %in% stage_rows[[stage]], , drop = FALSE]
    if (!nrow(rsub)) return(NULL)
    expand.grid_idx <- expand.grid(
      idx_row = seq_len(nrow(rsub)),
      idx_cand = seq_len(nrow(candidates)),
      stringsAsFactors = FALSE
    )
    out <- data.frame(
      stage = stage,
      candidate_id = candidates$candidate_id[expand.grid_idx$idx_cand],
      gamma_substeps = candidates$gamma_substeps[expand.grid_idx$idx_cand],
      p_global_eta_jump = candidates$p_global_eta_jump[expand.grid_idx$idx_cand],
      global_eta_jump_scale = candidates$global_eta_jump_scale[expand.grid_idx$idx_cand],
      family_tag = candidates$family[expand.grid_idx$idx_cand],
      row_id = rsub$row_id[expand.grid_idx$idx_row],
      run_root = rsub$run_root[expand.grid_idx$idx_row],
      root_kind = rsub$root_kind[expand.grid_idx$idx_row],
      family = rsub$family[expand.grid_idx$idx_row],
      tt = rsub$tt[expand.grid_idx$idx_row],
      tau_label = rsub$tau_label[expand.grid_idx$idx_row],
      p0 = rsub$p0[expand.grid_idx$idx_row],
      stringsAsFactors = FALSE
    )
    out$variant_tag <- paste0("wave8_transfer_", out$candidate_id)
    out$seed <- 2026040300L + (match(out$candidate_id, candidates$candidate_id) * 100L) + out$row_id
    out
  })
)

config_path <- file.path(out_dir, "LOCAL_static_exal_wave8_transfer_config_20260403.csv")
stage_rows_path <- file.path(out_dir, "LOCAL_static_exal_wave8_transfer_stage_rows_20260403.csv")
schedule_path <- file.path(out_dir, "LOCAL_static_exal_wave8_transfer_schedule_20260403.csv")

utils::write.csv(candidates, config_path, row.names = FALSE)
utils::write.csv(stage_rows_df, stage_rows_path, row.names = FALSE)
utils::write.csv(schedule, schedule_path, row.names = FALSE)

cat(sprintf("config: %s\n", config_path))
cat(sprintf("stage_rows: %s\n", stage_rows_path))
cat(sprintf("schedule: %s\n", schedule_path))
