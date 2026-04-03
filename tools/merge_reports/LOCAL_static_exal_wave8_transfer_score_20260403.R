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

case_id_from_root <- function(run_root, model = "exal") {
  paste0(gsub("^.*/results/", "results/", run_root), "::", model)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
stage <- as.character(args$stage %||% "transfer6")
schedule_path <- as.character(args$schedule %||% file.path(out_dir, "LOCAL_static_exal_wave8_transfer_schedule_20260403.csv"))
top_k <- safe_int(args[["top-k"]] %||% args$top_k, NA_integer_)

if (!file.exists(schedule_path)) stop(sprintf("schedule not found: %s", schedule_path))

stage_topk_defaults <- list(transfer6 = 4L, guard8 = 3L, mix12_transfer = 0L)
if (!is.finite(top_k)) top_k <- stage_topk_defaults[[stage]] %||% 0L

sched <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(sched)) stop("schedule is empty")

sched$case_id <- case_id_from_root(sched$run_root, "exal")

stage_rows <- unique(sched$row_id[sched$stage == stage])
if (!length(stage_rows)) stop(sprintf("no rows found for stage %s", stage))

stage_sched <- sched[sched$stage == stage, , drop = FALSE]

score_candidate <- function(candidate_id, variant_tag, rows_df) {
  summary_path <- file.path(out_dir, sprintf("LOCAL_static_case_health_summary_%s.csv", variant_tag))
  if (!file.exists(summary_path)) {
    return(list(
      pass_n = 0L,
      warn_n = 0L,
      fail_n = 0L,
      missing_n = length(unique(rows_df$row_id)),
      healthy_n = 0L,
      gate_points = 0L,
      composite = 0L,
      exact_ready = FALSE,
      row_gate = setNames(rep("MISSING", length(unique(rows_df$row_id))), unique(rows_df$row_id))
    ))
  }

  summ <- utils::read.csv(summary_path, stringsAsFactors = FALSE, check.names = FALSE)
  summ <- summ[summ$variant_tag == variant_tag, , drop = FALSE]
  if (!nrow(summ)) {
    return(list(
      pass_n = 0L,
      warn_n = 0L,
      fail_n = 0L,
      missing_n = length(unique(rows_df$row_id)),
      healthy_n = 0L,
      gate_points = 0L,
      composite = 0L,
      exact_ready = FALSE,
      row_gate = setNames(rep("MISSING", length(unique(rows_df$row_id))), unique(rows_df$row_id))
    ))
  }

  summ <- summ[summ$case_id %in% rows_df$case_id, , drop = FALSE]
  row_gate <- setNames(rep("MISSING", length(unique(rows_df$row_id))), unique(rows_df$row_id))
  for (i in seq_len(nrow(rows_df))) {
    rid <- rows_df$row_id[i]
    cid <- rows_df$case_id[i]
    row_match <- summ[summ$case_id == cid, , drop = FALSE]
    if (nrow(row_match)) {
      row_gate[as.character(rid)] <- as.character(row_match$gate_overall[1])
    }
  }

  gate_vals <- unname(row_gate)
  pass_n <- sum(gate_vals == "PASS", na.rm = TRUE)
  warn_n <- sum(gate_vals == "WARN", na.rm = TRUE)
  fail_n <- sum(gate_vals == "FAIL", na.rm = TRUE)
  missing_n <- sum(gate_vals == "MISSING", na.rm = TRUE)
  healthy_n <- sum(gate_vals %in% c("PASS", "WARN"), na.rm = TRUE)
  gate_points <- 2L * pass_n + warn_n
  composite <- gate_points + healthy_n
  exact_ready <- fail_n == 0L && missing_n == 0L

  list(
    pass_n = pass_n,
    warn_n = warn_n,
    fail_n = fail_n,
    missing_n = missing_n,
    healthy_n = healthy_n,
    gate_points = gate_points,
    composite = composite,
    exact_ready = exact_ready,
    row_gate = row_gate
  )
}

candidate_ids <- unique(stage_sched$candidate_id)
rows_out <- list()
for (i in seq_along(candidate_ids)) {
  cid <- candidate_ids[i]
  sub <- stage_sched[stage_sched$candidate_id == cid, , drop = FALSE]
  variant_tag <- unique(sub$variant_tag)[1]
  score <- score_candidate(cid, variant_tag, sub)

  row115_gate <- score$row_gate[["115"]] %||% "MISSING"
  row245_gate <- score$row_gate[["245"]] %||% "MISSING"
  row99_gate <- score$row_gate[["99"]] %||% "MISSING"
  row197_gate <- score$row_gate[["197"]] %||% "MISSING"
  row277_gate <- score$row_gate[["277"]] %||% "MISSING"

  rows_out[[i]] <- data.frame(
    candidate_id = cid,
    variant_tag = variant_tag,
    pass_n = score$pass_n,
    warn_n = score$warn_n,
    fail_n = score$fail_n,
    missing_n = score$missing_n,
    healthy_n = score$healthy_n,
    gate_points = score$gate_points,
    composite = score$composite,
    exact_ready = score$exact_ready,
    row115_gate = row115_gate,
    row245_gate = row245_gate,
    row99_gate = row99_gate,
    row197_gate = row197_gate,
    row277_gate = row277_gate,
    stringsAsFactors = FALSE
  )
}

tab <- do.call(rbind, rows_out)

rank_key <- switch(
  stage,
  transfer6 = with(tab, order(
    fail_n,
    row115_gate == "FAIL",
    row245_gate == "FAIL",
    -gate_points,
    -healthy_n,
    -composite
  )),
  guard8 = with(tab, order(
    fail_n,
    row99_gate == "FAIL",
    row115_gate == "FAIL",
    row197_gate == "FAIL",
    row245_gate == "FAIL",
    row277_gate == "FAIL",
    -gate_points,
    -healthy_n,
    -composite
  )),
  mix12_transfer = with(tab, order(
    fail_n,
    -gate_points,
    -healthy_n,
    -composite
  )),
  with(tab, order(fail_n, -gate_points, -healthy_n, -composite))
)

tab <- tab[rank_key, , drop = FALSE]

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
summary_csv <- file.path(out_dir, sprintf("LOCAL_static_exal_wave8_%s_summary_%s.csv", stage, stamp))
utils::write.csv(tab, summary_csv, row.names = FALSE)

if (is.finite(top_k) && top_k > 0L) {
  topk <- tab[seq_len(min(top_k, nrow(tab))), c("candidate_id", "variant_tag"), drop = FALSE]
  topk_path <- file.path(out_dir, sprintf("LOCAL_static_exal_wave8_%s_topk_%s.csv", stage, stamp))
  utils::write.csv(topk, topk_path, row.names = FALSE)
  cat(sprintf("topk: %s\n", topk_path))
}

cat(sprintf("summary: %s\n", summary_csv))
