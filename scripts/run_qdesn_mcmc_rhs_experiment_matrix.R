#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
or_else <- function(x, y) if (is.null(x)) y else x

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

matrix_path <- get_arg(
  "--matrix",
  file.path("config", "validation", "qdesn_mcmc_rhs_exp_matrix", "matrix.yaml")
)
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
resume <- has_flag("--resume")
dry_run <- has_flag("--dry-run")

matrix_def <- exdqlm:::.qdesn_rhs_exp_matrix_load(matrix_path)
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_stub <- paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha())

results_root <- get_arg(
  "--results-root",
  file.path("results", "qdesn_mcmc_validation", "rhs_exp_matrix", run_stub)
)
report_root <- get_arg(
  "--report-root",
  file.path("reports", "qdesn_mcmc_validation", "rhs_exp_matrix", run_stub)
)
results_root <- normalizePath(results_root, winslash = "/", mustWork = FALSE)
report_root <- normalizePath(report_root, winslash = "/", mustWork = FALSE)

for (d in c(
  report_root,
  file.path(report_root, "tables"),
  file.path(report_root, "manifest"),
  file.path(report_root, "decision"),
  results_root
)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

exdqlm:::.qdesn_validation_write_json(file.path(report_root, "manifest", "matrix_started.json"), list(
  started_at = as.character(Sys.time()),
  matrix_path = matrix_def$matrix_path,
  matrix_name = matrix_def$matrix$name,
  base_defaults = matrix_def$matrix$base_defaults,
  grid_path = matrix_def$matrix$grid,
  n_chains = matrix_def$matrix$n_chains,
  chain_seed_base = matrix_def$matrix$chain_seed_base,
  results_root = results_root,
  report_root = report_root,
  git_sha = exdqlm:::.qdesn_validation_git_sha(),
  dry_run = isTRUE(dry_run),
  resume = isTRUE(resume)
))

write_tables <- function(exp_rows, winner_rows, trigger_rows) {
  exp_df <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(exp_rows)
  win_df <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(winner_rows)
  trg_df <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(trigger_rows)
  exdqlm:::.qdesn_validation_write_df(exp_df, file.path(report_root, "tables", "experiment_summary.csv"))
  exdqlm:::.qdesn_validation_write_df(win_df, file.path(report_root, "tables", "phase_winners.csv"))
  exdqlm:::.qdesn_validation_write_df(trg_df, file.path(report_root, "tables", "phase_triggers.csv"))
  if (nrow(exp_df) && "is_topk" %in% names(exp_df)) {
    exdqlm:::.qdesn_validation_write_df(
      subset(exp_df, is_topk %in% TRUE),
      file.path(report_root, "tables", "phase_topk.csv")
    )
  }
  invisible(list(experiment_summary = exp_df, phase_winners = win_df, phase_triggers = trg_df))
}

base_defaults <- exdqlm:::qdesn_validation_load_defaults(matrix_def$matrix$base_defaults)
keep_top <- as.integer(or_else(matrix_def$matrix$selection$phase_keep_top, 2L))[1L]
if (!is.finite(keep_top) || keep_top < 1L) keep_top <- 2L

if (isTRUE(dry_run)) {
  phase_plan_rows <- lapply(matrix_def$phases, function(ph) {
    exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(lapply(ph$experiments, function(ex) {
      data.frame(
        phase_id = ph$id,
        phase_description = ph$description,
        experiment_id = ex$id,
        label = ex$label,
        patch_path = ex$patch_path,
        base_from_phase = ph$base_from_phase,
        stringsAsFactors = FALSE
      )
    }))
  })
  phase_plan <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(phase_plan_rows)
  exdqlm:::.qdesn_validation_write_df(phase_plan, file.path(report_root, "tables", "matrix_plan.csv"))
  exdqlm:::.qdesn_validation_write_json(file.path(report_root, "manifest", "matrix_completed.json"), list(
    finished_at = as.character(Sys.time()),
    dry_run = TRUE,
    n_planned_experiments = nrow(phase_plan)
  ))
  cat(sprintf("Matrix dry run complete. Plan table: %s\n", file.path(report_root, "tables", "matrix_plan.csv")))
  quit(save = "no", status = 0)
}

exp_rows <- list()
winner_rows <- list()
trigger_rows <- list()
phase_ranked <- list()
phase_winner_defaults <- list()
phase_winner_ids <- list()
experiment_defaults <- list()

phase_base_defaults <- function(phase) {
  src <- trimws(as.character(or_else(phase$base_from_phase, ""))[1L])
  if (!nzchar(src)) return(base_defaults)
  winner_id <- phase_winner_ids[[src]]
  if (is.null(winner_id) || !nzchar(winner_id)) {
    stop(sprintf("Phase `%s` requires winner from `%s`, but no winner is available.", phase$id, src), call. = FALSE)
  }
  winner_defaults <- phase_winner_defaults[[src]]
  if (is.null(winner_defaults) || !is.list(winner_defaults)) {
    stop(sprintf("Phase `%s` requires defaults from winner `%s`, but defaults are missing.", phase$id, winner_id), call. = FALSE)
  }
  winner_defaults
}

run_one_experiment <- function(phase, experiment, phase_base) {
  patch_spec <- exdqlm:::.qdesn_rhs_exp_matrix_read_patch(experiment$patch_path)
  run_overrides <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(
    or_else(experiment$run_overrides, list()),
    or_else(patch_spec$run_overrides, list())
  )
  exp_n_chains <- as.integer(or_else(run_overrides$n_chains, matrix_def$matrix$n_chains))[1L]
  exp_seed_base <- as.integer(or_else(run_overrides$chain_seed_base, matrix_def$matrix$chain_seed_base))[1L]
  if (!is.finite(exp_n_chains) || exp_n_chains < 2L) exp_n_chains <- matrix_def$matrix$n_chains
  if (!is.finite(exp_seed_base)) exp_seed_base <- matrix_def$matrix$chain_seed_base

  resolved_defaults <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(phase_base, or_else(patch_spec$patch, list()))
  tmp_defaults <- tempfile(pattern = paste0("rhs-exp-", experiment$id, "-"), fileext = ".yaml")
  yaml::write_yaml(resolved_defaults, tmp_defaults)

  exp_results_root <- file.path(results_root, phase$id, experiment$id)
  exp_report_root <- file.path(report_root, phase$id, experiment$id)
  completed_path <- file.path(exp_report_root, "manifest", "campaign_completed.json")
  started_path <- file.path(exp_report_root, "manifest", "campaign_started.json")
  run_error <- NA_character_
  run_mode <- "fresh_run"

  if (isTRUE(resume) && file.exists(completed_path)) {
    run_mode <- "resume_skip_completed"
  } else if (isTRUE(resume) && file.exists(started_path) && !file.exists(completed_path)) {
    run_mode <- "resume_skip_incomplete"
  } else {
    if (dir.exists(exp_results_root) && length(list.files(exp_results_root, all.files = TRUE, no.. = TRUE)) > 0L) {
      stop(sprintf("Results directory is non-empty: %s", exp_results_root), call. = FALSE)
    }
    if (dir.exists(exp_report_root) && length(list.files(exp_report_root, all.files = TRUE, no.. = TRUE)) > 0L) {
      stop(sprintf("Report directory is non-empty: %s", exp_report_root), call. = FALSE)
    }
    dir.create(exp_results_root, recursive = TRUE, showWarnings = FALSE)
    dir.create(exp_report_root, recursive = TRUE, showWarnings = FALSE)
    tryCatch(
      {
        exdqlm:::qdesn_validation_run_multichain_campaign(
          grid_path = matrix_def$matrix$grid,
          defaults = resolved_defaults,
          defaults_path = tmp_defaults,
          results_root = exp_results_root,
          report_root = exp_report_root,
          n_chains = exp_n_chains,
          chain_seed_base = exp_seed_base,
          create_plots = create_plots,
          verbose = verbose
        )
      },
      error = function(e) {
        run_error <<- conditionMessage(e)
      }
    )
  }

  health <- exdqlm:::.qdesn_rhs_exp_matrix_collect_health(exp_report_root)
  row <- cbind(
    data.frame(
      phase_id = phase$id,
      phase_description = phase$description,
      base_from_phase = phase$base_from_phase,
      experiment_id = experiment$id,
      label = experiment$label,
      experiment_description = trimws(paste(experiment$description, patch_spec$description)),
      patch_path = patch_spec$patch_path,
      n_chains = as.integer(exp_n_chains),
      chain_seed_base = as.integer(exp_seed_base),
      run_mode = run_mode,
      run_error = run_error,
      results_root = normalizePath(exp_results_root, winslash = "/", mustWork = FALSE),
      rank = NA_integer_,
      is_topk = NA,
      stringsAsFactors = FALSE
    ),
    health
  )
  list(row = row, defaults = resolved_defaults)
}

for (phase in matrix_def$phases) {
  base_from <- trimws(as.character(or_else(phase$base_from_phase, ""))[1L])
  prior_rows <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(phase_ranked)
  trig_eval <- exdqlm:::.qdesn_rhs_exp_matrix_evaluate_trigger(phase$trigger, prior_rows)
  trigger_rows[[length(trigger_rows) + 1L]] <- data.frame(
    phase_id = phase$id,
    trigger_present = !is.null(phase$trigger),
    run_phase = isTRUE(trig_eval$run_phase),
    trigger_reason = trig_eval$reason,
    trigger_metric_value = as.numeric(trig_eval$metric_value),
    stringsAsFactors = FALSE
  )
  write_tables(exp_rows, winner_rows, trigger_rows)
  if (!isTRUE(trig_eval$run_phase)) {
    winner_rows[[length(winner_rows) + 1L]] <- data.frame(
      phase_id = phase$id,
      base_from_phase = base_from,
      phase_status = "SKIPPED_BY_TRIGGER",
      winner_experiment_id = NA_character_,
      winner_rank = NA_integer_,
      winner_max_split_rhat = NA_real_,
      winner_n_root_fail = NA_integer_,
      winner_min_ess_rhs = NA_real_,
      topk_experiments = NA_character_,
      stringsAsFactors = FALSE
    )
    write_tables(exp_rows, winner_rows, trigger_rows)
    next
  }

  phase_base <- phase_base_defaults(phase)
  phase_rows <- list()
  for (experiment in phase$experiments) {
    if (isTRUE(verbose)) {
      message(sprintf("[rhs_exp_matrix] phase=%s experiment=%s", phase$id, experiment$id))
    }
    out <- run_one_experiment(phase = phase, experiment = experiment, phase_base = phase_base)
    phase_rows[[length(phase_rows) + 1L]] <- out$row
    exp_rows[[length(exp_rows) + 1L]] <- out$row
    experiment_defaults[[experiment$id]] <- out$defaults
    write_tables(exp_rows, winner_rows, trigger_rows)
  }

  phase_df <- exdqlm:::.qdesn_rhs_exp_matrix_bind_rows(phase_rows)
  ranked <- exdqlm:::.qdesn_rhs_exp_matrix_rank(phase_df, top_n = keep_top)
  phase_ranked[[length(phase_ranked) + 1L]] <- ranked
  exp_rows <- c(exp_rows[seq_len(max(length(exp_rows) - length(phase_rows), 0L))], split(ranked, seq_len(nrow(ranked))))

  if (!nrow(ranked)) {
    winner_rows[[length(winner_rows) + 1L]] <- data.frame(
      phase_id = phase$id,
      base_from_phase = base_from,
      phase_status = "NO_RESULTS",
      winner_experiment_id = NA_character_,
      winner_rank = NA_integer_,
      winner_max_split_rhat = NA_real_,
      winner_n_root_fail = NA_integer_,
      winner_min_ess_rhs = NA_real_,
      topk_experiments = NA_character_,
      stringsAsFactors = FALSE
    )
    write_tables(exp_rows, winner_rows, trigger_rows)
    next
  }

  winner <- ranked[1L, , drop = FALSE]
  topk <- ranked$experiment_id[ranked$is_topk %in% TRUE]
  topk <- topk[!is.na(topk)]
  winner_id <- as.character(winner$experiment_id)[1L]
  phase_winner_ids[[phase$id]] <- winner_id
  phase_winner_defaults[[phase$id]] <- experiment_defaults[[winner_id]]

  winner_rows[[length(winner_rows) + 1L]] <- data.frame(
    phase_id = phase$id,
    base_from_phase = base_from,
    phase_status = "COMPLETED",
    winner_experiment_id = winner_id,
    winner_rank = as.integer(winner$rank)[1L],
    winner_max_split_rhat = as.numeric(winner$max_split_rhat)[1L],
    winner_n_root_fail = as.integer(winner$n_root_fail)[1L],
    winner_min_ess_rhs = as.numeric(winner$min_ess_rhs)[1L],
    topk_experiments = paste(topk, collapse = ";"),
    stringsAsFactors = FALSE
  )
  write_tables(exp_rows, winner_rows, trigger_rows)
}

final_tables <- write_tables(exp_rows, winner_rows, trigger_rows)
exp_df <- final_tables$experiment_summary
winner_df <- final_tables$phase_winners

final_phase <- tail(winner_df$phase_id[as.character(winner_df$phase_status) == "COMPLETED"], 1L)
final_winner_id <- if (length(final_phase)) {
  as.character(winner_df$winner_experiment_id[winner_df$phase_id == final_phase])[1L]
} else {
  NA_character_
}
final_winner_row <- if (nzchar(or_else(final_winner_id, ""))) {
  subset(exp_df, experiment_id == final_winner_id)
} else {
  data.frame(stringsAsFactors = FALSE)
}

decision <- data.frame(
  matrix_name = matrix_def$matrix$name,
  final_completed_phase = if (length(final_phase)) final_phase else NA_character_,
  final_winner_experiment_id = if (nrow(final_winner_row)) as.character(final_winner_row$experiment_id[1L]) else NA_character_,
  final_winner_max_split_rhat = if (nrow(final_winner_row)) as.numeric(final_winner_row$max_split_rhat[1L]) else NA_real_,
  final_winner_n_root_fail = if (nrow(final_winner_row)) as.integer(final_winner_row$n_root_fail[1L]) else NA_integer_,
  final_winner_min_ess_rhs = if (nrow(final_winner_row)) as.numeric(final_winner_row$min_ess_rhs[1L]) else NA_real_,
  final_winner_report_root = if (nrow(final_winner_row)) as.character(final_winner_row$report_root[1L]) else NA_character_,
  stringsAsFactors = FALSE
)
exdqlm:::.qdesn_validation_write_df(decision, file.path(report_root, "decision", "matrix_decision.csv"))

exdqlm:::.qdesn_validation_write_json(file.path(report_root, "manifest", "matrix_completed.json"), list(
  finished_at = as.character(Sys.time()),
  matrix_name = matrix_def$matrix$name,
  matrix_path = matrix_def$matrix_path,
  results_root = results_root,
  report_root = report_root,
  n_experiments = nrow(exp_df),
  n_phases = nrow(winner_df),
  final_completed_phase = if (length(final_phase)) final_phase else NA_character_,
  final_winner_experiment_id = if (nrow(final_winner_row)) as.character(final_winner_row$experiment_id[1L]) else NA_character_
))

cat(sprintf("Experiment matrix report root: %s\n", report_root))
cat(sprintf("Experiment matrix results root: %s\n", results_root))
if (nrow(decision)) {
  cat(sprintf(
    "Final winner: %s | phase: %s | root_fail=%s | max_split_rhat=%s | min_ess_rhs=%s\n",
    as.character(decision$final_winner_experiment_id[1L]),
    as.character(decision$final_completed_phase[1L]),
    as.character(decision$final_winner_n_root_fail[1L]),
    as.character(decision$final_winner_max_split_rhat[1L]),
    as.character(decision$final_winner_min_ess_rhs[1L])
  ))
}
