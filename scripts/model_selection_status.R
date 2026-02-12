#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  req <- c("jsonlite", "readr", "dplyr")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1L] else default
}

run_dir <- get_arg("--run_dir")
tail_n <- as.integer(get_arg("--tail", "8"))

if (is.null(run_dir) || !nzchar(run_dir)) {
  stop("Usage: Rscript scripts/model_selection_status.R --run_dir <results/.../run_id> [--tail 8]")
}

status_path <- file.path(run_dir, "tables", "model_selection_status.json")
progress_path <- file.path(run_dir, "tables", "model_selection_progress.csv")
best_path <- file.path(run_dir, "tables", "model_selection_best_so_far.csv")

cat("Run dir:", run_dir, "\n")

if (file.exists(status_path)) {
  st <- jsonlite::read_json(status_path, simplifyVector = TRUE)
  cat("State:", st$state %||% NA_character_, "\n")
  cat("Timestamp:", st$timestamp %||% NA_character_, "\n")
  if (!is.null(st$stage)) {
    cat(sprintf("Stage: %s (%s) | evals %s/%s | remaining %s\n",
                st$stage$name %||% NA_character_,
                as.character(st$stage$index %||% NA),
                as.character(st$stage$completed %||% NA),
                as.character(st$stage$total %||% NA),
                as.character(st$stage$remaining %||% NA)))
    cat(sprintf("Stage candidates: %s/%s | remaining %s\n",
                as.character(st$stage$candidate_completed %||% NA),
                as.character(st$stage$candidate_total %||% NA),
                as.character(st$stage$candidate_remaining %||% NA)))
    cat(sprintf("Stage ETA (sec): %s\n", as.character(st$stage$eta_sec %||% NA)))
  }
  if (!is.null(st$run_known)) {
    cat(sprintf("Known-run progress: %s/%s | remaining %s | ETA(sec) %s\n",
                as.character(st$run_known$completed %||% NA),
                as.character(st$run_known$total %||% NA),
                as.character(st$run_known$remaining %||% NA),
                as.character(st$run_known$eta_sec %||% NA)))
  }
  if (!is.null(st$best_so_far)) {
    cat(sprintf("Best so far: CRPS=%s | candidate=%s | stage=%s | seed=%s\n",
                as.character(st$best_so_far$crps_synth_mean %||% NA),
                as.character(st$best_so_far$candidate_id %||% NA),
                as.character(st$best_so_far$stage %||% NA),
                as.character(st$best_so_far$seed %||% NA)))
  }
  if (!is.null(st$last_result)) {
    cat("Last result:", paste(names(st$last_result), st$last_result, sep = "=", collapse = ", "), "\n")
  }
  if (!is.null(st$error) && nzchar(st$error)) {
    cat("Error:", st$error, "\n")
  }
} else {
  cat("No status file yet:", status_path, "\n")
}

if (file.exists(progress_path)) {
  cat("\nRecent progress rows:\n")
  prog <- suppressMessages(readr::read_csv(progress_path, show_col_types = FALSE))
  keep <- c("timestamp", "stage", "candidate_idx", "seed", "crps_synth_mean",
            "calcrps_mean", "eval_completed_stage", "eval_total_stage", "eval_remaining_stage",
            "candidate_completed_stage", "candidate_total_stage", "best_crps_so_far", "eta_stage_sec")
  keep <- keep[keep %in% names(prog)]
  print(utils::tail(prog[, keep, drop = FALSE], n = max(1L, tail_n)))
} else {
  cat("\nNo progress CSV yet:", progress_path, "\n")
}

if (file.exists(best_path)) {
  cat("\nBest-so-far updates (tail):\n")
  best <- suppressMessages(readr::read_csv(best_path, show_col_types = FALSE))
  keep2 <- c("timestamp", "stage", "candidate_idx", "seed", "crps_synth_mean", "best_crps_so_far", "best_candidate_id_so_far")
  keep2 <- keep2[keep2 %in% names(best)]
  print(utils::tail(best[, keep2, drop = FALSE], n = max(1L, min(tail_n, 20L))))
}
