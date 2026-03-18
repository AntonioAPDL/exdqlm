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
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  if (is.null(path)) return(NULL)
  raw <- as.character(path)[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

to_num <- function(x, default) {
  out <- suppressWarnings(as.numeric(x))
  out[!is.finite(out)] <- default
  out
}

extract_rhs_c2_rhat <- function(experiment_report_root) {
  f <- file.path(experiment_report_root, "tables", "campaign_multichain_rhat.csv")
  d <- read_csv_safe(f)
  if (!nrow(d) || !("parameter" %in% names(d)) || !("rhat" %in% names(d))) return(NA_real_)
  d <- subset(d, as.character(parameter) == "rhs_c2")
  if (!nrow(d)) return(NA_real_)
  suppressWarnings(max(as.numeric(d$rhat), na.rm = TRUE))
}

run_rscript_step <- function(args_vec, log_path) {
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  status <- suppressWarnings(system2("Rscript", args = args_vec, stdout = log_path, stderr = log_path))
  if (!is.null(status) && as.integer(status) != 0L) {
    stop(sprintf("Step failed (status=%s). See log: %s", as.character(status), log_path), call. = FALSE)
  }
}

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_stub <- paste0(stamp, "__git-", exdqlm:::.qdesn_validation_git_sha())

matrix_path <- resolve_path(
  get_arg("--matrix", file.path("config", "validation", "qdesn_mcmc_rhs_const_c2_matrix", "matrix.yaml")),
  must_work = TRUE
)
reconfirm_grid <- resolve_path(
  get_arg("--reconfirm-grid", file.path("config", "validation", "qdesn_mcmc_multichain_rhs_runtime_isolation_grid.csv")),
  must_work = TRUE
)
analysis_root <- resolve_path(
  get_arg("--analysis-root", file.path("reports", "qdesn_mcmc_validation", "rhs_const_c2_wave", run_stub)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_const_c2_wave", run_stub)),
  must_work = FALSE
)
promotion_defaults_path <- resolve_path(
  get_arg("--promotion-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_structural_reparam_constc2_candidate.yaml")),
  must_work = FALSE
)

create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")
promote_on_pass <- !has_flag("--no-promote")
resume_matrix <- has_flag("--resume-matrix")

phaseA_report_root <- file.path(analysis_root, "phaseA_const_matrix")
phaseA_results_root <- file.path(results_root, "phaseA_const_matrix")
phaseB_report_root <- file.path(analysis_root, "phaseB_reconfirm")
phaseB_results_root <- file.path(results_root, "phaseB_reconfirm")

for (d in c(
  analysis_root,
  results_root,
  file.path(analysis_root, "logs"),
  file.path(analysis_root, "tables"),
  file.path(analysis_root, "manifest")
)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

matrix_log <- file.path(analysis_root, "logs", "phaseA_matrix.log")
matrix_cmd <- c(
  "scripts/run_qdesn_mcmc_rhs_experiment_matrix.R",
  "--matrix", matrix_path,
  "--results-root", phaseA_results_root,
  "--report-root", phaseA_report_root
)
if (!create_plots) matrix_cmd <- c(matrix_cmd, "--no-plots")
if (!verbose) matrix_cmd <- c(matrix_cmd, "--quiet")
if (resume_matrix) matrix_cmd <- c(matrix_cmd, "--resume")

run_rscript_step(matrix_cmd, matrix_log)

phaseA_exp <- read_csv_safe(file.path(phaseA_report_root, "tables", "experiment_summary.csv"))
if (!nrow(phaseA_exp)) {
  stop(sprintf("Missing experiment summary table: %s", file.path(phaseA_report_root, "tables", "experiment_summary.csv")), call. = FALSE)
}

phaseA_done <- subset(phaseA_exp, as.character(status) == "COMPLETED")
if (!nrow(phaseA_done)) {
  stop("No completed experiments found in phase-A const-c2 matrix.", call. = FALSE)
}

phaseA_done$rhs_c2_rhat <- vapply(
  phaseA_done$report_root,
  FUN = extract_rhs_c2_rhat,
  FUN.VALUE = numeric(1)
)
phaseA_done$n_root_fail_num <- to_num(phaseA_done$n_root_fail, default = 1e9)
phaseA_done$n_root_warn_num <- to_num(phaseA_done$n_root_warn, default = 1e9)
phaseA_done$n_chain_fail_num <- to_num(phaseA_done$n_chain_fail, default = 1e9)
phaseA_done$max_split_rhat_num <- to_num(phaseA_done$max_split_rhat, default = 1e9)
phaseA_done$min_ess_rhs_num <- to_num(phaseA_done$min_ess_rhs, default = -1e9)
phaseA_done$wall_minutes_num <- to_num(phaseA_done$wall_minutes, default = 1e9)
phaseA_done$rhs_c2_rhat_num <- to_num(phaseA_done$rhs_c2_rhat, default = 1e9)

candidate_pool <- phaseA_done
nonfail_pool <- subset(candidate_pool, n_root_fail_num <= 0)
if (nrow(nonfail_pool)) candidate_pool <- nonfail_pool

ord <- order(
  candidate_pool$rhs_c2_rhat_num,
  candidate_pool$n_root_warn_num,
  candidate_pool$n_chain_fail_num,
  candidate_pool$max_split_rhat_num,
  -candidate_pool$min_ess_rhs_num,
  candidate_pool$wall_minutes_num,
  as.character(candidate_pool$experiment_id)
)
candidate_pool <- candidate_pool[ord, , drop = FALSE]
candidate_pool$wave_rank <- seq_len(nrow(candidate_pool))
winner <- candidate_pool[1, , drop = FALSE]
winner_id <- as.character(winner$experiment_id[[1L]])

selection_table <- phaseA_done[, c(
  "phase_id", "experiment_id", "label", "status",
  "n_root_fail", "n_root_warn", "n_chain_fail",
  "max_split_rhat", "rhs_c2_rhat", "min_ess_rhs",
  "wall_minutes", "report_root"
)]
selection_table$selected_for_wave <- selection_table$experiment_id %in% winner_id
selection_table$selection_pool_nonfail <- selection_table$experiment_id %in% candidate_pool$experiment_id
selection_table$wave_rank <- NA_integer_
selection_table$wave_rank[match(candidate_pool$experiment_id, selection_table$experiment_id)] <- candidate_pool$wave_rank
utils::write.csv(selection_table, file.path(analysis_root, "tables", "phaseA_selection_table.csv"), row.names = FALSE)

matrix_def <- exdqlm:::.qdesn_rhs_exp_matrix_load(matrix_path)
exp_lookup <- list()
for (ph in matrix_def$phases) {
  for (ex in ph$experiments) exp_lookup[[ex$id]] <- ex
}
winner_exp <- exp_lookup[[winner_id]]
if (is.null(winner_exp)) {
  stop(sprintf("Winner experiment `%s` is missing from matrix definition.", winner_id), call. = FALSE)
}

base_defaults <- exdqlm:::qdesn_validation_load_defaults(matrix_def$matrix$base_defaults)
winner_patch <- exdqlm:::.qdesn_rhs_exp_matrix_read_patch(winner_exp$patch_path)
selected_defaults <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(base_defaults, winner_patch$patch %||% list())
run_overrides <- exdqlm:::.qdesn_rhs_exp_matrix_deep_merge(
  winner_exp$run_overrides %||% list(),
  winner_patch$run_overrides %||% list()
)

n_chains <- as.integer(run_overrides$n_chains %||% matrix_def$matrix$n_chains)[1L]
chain_seed_base <- as.integer(run_overrides$chain_seed_base %||% matrix_def$matrix$chain_seed_base)[1L]
if (!is.finite(n_chains) || n_chains < 2L) n_chains <- matrix_def$matrix$n_chains
if (!is.finite(chain_seed_base)) chain_seed_base <- matrix_def$matrix$chain_seed_base

selected_defaults$campaign <- selected_defaults$campaign %||% list()
selected_defaults$campaign$name <- "qdesn_rhs_const_c2_wave_reconfirm"
selected_defaults$campaign$results_root <- phaseB_results_root
selected_defaults$campaign$reports_root <- phaseB_report_root

selected_defaults_path <- file.path(analysis_root, "tables", "selected_defaults.yaml")
yaml::write_yaml(selected_defaults, selected_defaults_path)

reconfirm_res <- exdqlm:::qdesn_validation_run_multichain_campaign(
  grid_path = reconfirm_grid,
  defaults = selected_defaults,
  defaults_path = selected_defaults_path,
  results_root = phaseB_results_root,
  report_root = phaseB_report_root,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  create_plots = create_plots,
  verbose = verbose
)

root_conf <- read_csv_safe(file.path(phaseB_report_root, "tables", "campaign_root_confirmation.csv"))
n_fail <- if (nrow(root_conf)) sum(as.character(root_conf$confirmation_grade) == "FAIL", na.rm = TRUE) else NA_integer_
n_warn <- if (nrow(root_conf)) sum(as.character(root_conf$confirmation_grade) == "WARN", na.rm = TRUE) else NA_integer_
n_pass <- if (nrow(root_conf)) sum(as.character(root_conf$confirmation_grade) == "PASS", na.rm = TRUE) else NA_integer_
wave_pass <- is.finite(n_fail) && n_fail == 0L

unresolved <- subset(root_conf, as.character(confirmation_grade) == "FAIL")
utils::write.csv(unresolved, file.path(analysis_root, "tables", "phaseB_unresolved_fail_roots.csv"), row.names = FALSE)

promoted <- FALSE
if (isTRUE(promote_on_pass) && isTRUE(wave_pass)) {
  promoted_defaults <- selected_defaults
  promoted_defaults$campaign <- promoted_defaults$campaign %||% list()
  promoted_defaults$campaign$name <- "qdesn_mcmc_rhs_constc2_candidate"
  promoted_defaults$campaign$results_root <- "results/qdesn_mcmc_validation/rhs_constc2_candidate"
  promoted_defaults$campaign$reports_root <- "reports/qdesn_mcmc_validation/rhs_constc2_candidate"
  dir.create(dirname(promotion_defaults_path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(promoted_defaults, promotion_defaults_path)
  promoted <- TRUE
}

if (!wave_pass) {
  escalation_path <- file.path(analysis_root, "tables", "phaseC_escalation_next_step.md")
  escalation_lines <- c(
    "# Phase C Escalation Next Step",
    "",
    "- Trigger: unresolved FAIL remains after rhs_c2 micro-matrix + two-root reconfirm.",
    "- Current unresolved focus: `const_small | tau=0.05 | rhs`.",
    "",
    "## Recommended Escalation",
    "",
    "1. Keep transformed-parameter sampling for nonconjugate blocks and isolate only RHS global-kernel changes.",
    "2. Add a conditional sampler variant for `(eta_tau, eta_c2)` with stronger local adaptation:",
    "   - shorter blocked directional proposals on `eta_c2` near slab extremes;",
    "   - fallback coordinate update for `eta_c2` when block acceptance/mixing deteriorates.",
    "3. Run on one-root const-only grid first, then two-root reconfirm grid.",
    "4. Preserve signoff thresholds unchanged to keep comparability with all prior waves."
  )
  writeLines(escalation_lines, escalation_path)
}

wave_summary <- data.frame(
  generated_at = as.character(Sys.time()),
  matrix_path = matrix_path,
  reconfirm_grid = reconfirm_grid,
  analysis_root = analysis_root,
  results_root = results_root,
  winner_experiment_id = winner_id,
  winner_rhs_c2_rhat = winner$rhs_c2_rhat_num[[1L]],
  winner_max_split_rhat = to_num(winner$max_split_rhat_num[[1L]], default = NA_real_),
  winner_n_root_fail = as.integer(winner$n_root_fail_num[[1L]]),
  reconfirm_n_roots = if (nrow(root_conf)) nrow(root_conf) else NA_integer_,
  reconfirm_n_fail = n_fail,
  reconfirm_n_warn = n_warn,
  reconfirm_n_pass = n_pass,
  reconfirm_wave_pass = wave_pass,
  promoted_defaults = promoted,
  promotion_defaults_path = if (promoted) promotion_defaults_path else NA_character_,
  stringsAsFactors = FALSE
)
utils::write.csv(wave_summary, file.path(analysis_root, "tables", "wave_summary.csv"), row.names = FALSE)
exdqlm:::.qdesn_validation_write_json(file.path(analysis_root, "manifest", "wave_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  matrix_path = matrix_path,
  reconfirm_grid = reconfirm_grid,
  phaseA_report_root = phaseA_report_root,
  phaseA_results_root = phaseA_results_root,
  phaseB_report_root = phaseB_report_root,
  phaseB_results_root = phaseB_results_root,
  winner_experiment_id = winner_id,
  n_chains = n_chains,
  chain_seed_base = chain_seed_base,
  reconfirm = list(
    n_roots = if (nrow(root_conf)) nrow(root_conf) else 0L,
    n_fail = n_fail,
    n_warn = n_warn,
    n_pass = n_pass,
    wave_pass = wave_pass
  ),
  promoted_defaults = promoted,
  promotion_defaults_path = if (promoted) promotion_defaults_path else NULL,
  git_sha = exdqlm:::.qdesn_validation_git_sha()
))

cat(sprintf("Wave analysis root: %s\n", analysis_root))
cat(sprintf("Wave results root: %s\n", results_root))
cat(sprintf("Phase-A winner: %s\n", winner_id))
cat(sprintf(
  "Phase-B reconfirm root grades: PASS=%s WARN=%s FAIL=%s\n",
  as.character(n_pass), as.character(n_warn), as.character(n_fail)
))
cat(sprintf("Provisional defaults promoted: %s\n", as.character(promoted)))
