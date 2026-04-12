#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

source("tools/merge_reports/LOCAL_original288_exactspec_multiseed_helpers_20260412.R")

parse_args_original288_exactspec_multiseed_reduce <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    }
  }
  out
}

args <- parse_args_original288_exactspec_multiseed_reduce(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)

paths <- paths_original288_exactspec_multiseed()
status_path <- safe_chr_original288_exactspec_multiseed(args$status, paths$full_manifest_status)
ranking_out <- safe_chr_original288_exactspec_multiseed(args$ranking_out, paths$full_seed_ranking)
selected_out <- safe_chr_original288_exactspec_multiseed(args$selected_out, paths$full_selected)

status_df <- utils::read.csv(status_path, stringsAsFactors = FALSE, check.names = FALSE)
done_df <- status_df[status_df$gate_current != "MISSING", , drop = FALSE]
if (!nrow(done_df)) stop(sprintf("no completed rows found in %s", status_path))

done_df$gate_rank <- gate_rank_original288_exactspec_multiseed(done_df$gate_current)
done_df$crps_rank <- ifelse(is.finite(done_df$crps_metric), done_df$crps_metric, Inf)
done_df$primary_accuracy_rank <- ifelse(is.finite(done_df$primary_accuracy_metric), done_df$primary_accuracy_metric, Inf)
done_df$runtime_rank <- ifelse(is.finite(done_df$runtime_sec_current), done_df$runtime_sec_current, Inf)

split_rows <- split(done_df, done_df$base_row_id)
ranked_parts <- lapply(split_rows, function(d) {
  d <- d[order(
    d$gate_rank,
    d$crps_rank,
    d$primary_accuracy_rank,
    d$runtime_rank,
    d$seed,
    d$row_id
  ), , drop = FALSE]
  d$selection_rank <- seq_len(nrow(d))
  d$selected_seed <- d$selection_rank == 1L
  d$candidate_label <- sprintf("seed_slot_%02d_seed_%d", as.integer(d$seed_slot), as.integer(d$seed))
  d
})

ranking_df <- do.call(rbind, ranked_parts)
rownames(ranking_df) <- NULL
ranking_df <- ranking_df[order(ranking_df$base_row_id, ranking_df$selection_rank), , drop = FALSE]
utils::write.csv(ranking_df, ranking_out, row.names = FALSE)

selected_df <- ranking_df[ranking_df$selected_seed, , drop = FALSE]
selected_df <- selected_df[order(selected_df$base_row_id), , drop = FALSE]
utils::write.csv(selected_df, selected_out, row.names = FALSE)

cat(sprintf(
  "REDUCE total_done=%d selected=%d pass=%d warn=%d fail=%d\n",
  nrow(done_df),
  nrow(selected_df),
  sum(selected_df$gate_current == "PASS"),
  sum(selected_df$gate_current == "WARN"),
  sum(selected_df$gate_current == "FAIL")
))
