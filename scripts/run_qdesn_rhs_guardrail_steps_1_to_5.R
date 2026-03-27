#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
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

dir_create <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

read_csv_safe <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

deep_merge <- function(x, y) {
  if (!is.list(x) || !is.list(y)) return(y)
  out <- x
  for (nm in names(y)) {
    if (is.list(out[[nm]]) && is.list(y[[nm]])) {
      out[[nm]] <- deep_merge(out[[nm]], y[[nm]])
    } else {
      out[[nm]] <- y[[nm]]
    }
  }
  out
}

safe_num <- function(x, default = NA_real_) {
  x <- suppressWarnings(as.numeric(x))
  if (!length(x) || !is.finite(x[1L])) default else x[1L]
}

count_contains <- function(x, token) {
  x <- as.character(x %||% character(0))
  sum(grepl(token, x, fixed = TRUE), na.rm = TRUE)
}

summarize_pair <- function(pair_df) {
  if (!nrow(pair_df)) {
    return(data.frame(
      n_pairs = 0L,
      n_pair_pass = 0L,
      n_pair_warn = 0L,
      n_pair_fail = 0L,
      n_pair_eligible = 0L,
      runtime_ratio_median = NA_real_,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    n_pairs = nrow(pair_df),
    n_pair_pass = sum(as.character(pair_df$pair_signoff_grade) == "PASS", na.rm = TRUE),
    n_pair_warn = sum(as.character(pair_df$pair_signoff_grade) == "WARN", na.rm = TRUE),
    n_pair_fail = sum(as.character(pair_df$pair_signoff_grade) == "FAIL", na.rm = TRUE),
    n_pair_eligible = sum(as.logical(pair_df$pair_comparison_eligible), na.rm = TRUE),
    runtime_ratio_median = suppressWarnings(stats::median(as.numeric(pair_df$runtime_ratio_mcmc_vs_vb), na.rm = TRUE)),
    stringsAsFactors = FALSE
  )
}

manifest_path <- resolve_path(
  get_arg("--rescue-manifest", file.path("config", "validation", "qdesn_rhs_guardrail_rescue_v1_manifest.yaml")),
  must_work = TRUE
)
profiles_path <- resolve_path(
  get_arg("--profiles", file.path("config", "validation", "qdesn_rhs_guardrail_balanced_profiles.yaml")),
  must_work = TRUE
)
target_grid_path <- resolve_path(
  get_arg("--target-grid", file.path("config", "validation", "qdesn_rhs_guardrail_target_grid.csv")),
  must_work = TRUE
)
broader_grid_path <- resolve_path(
  get_arg("--broader-grid", file.path("config", "validation", "qdesn_mcmc_multichain_rhs_broader_confirmation_grid.csv")),
  must_work = TRUE
)
promote_defaults_path <- resolve_path(
  get_arg("--promotion-defaults", file.path("config", "validation", "qdesn_mcmc_compare_rhs_guardrail_balanced_candidate.yaml")),
  must_work = FALSE
)
write_rescue_defaults <- !has_flag("--skip-write-rescue-defaults")
create_plots <- !has_flag("--no-plots")
verbose <- !has_flag("--quiet")

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- exdqlm:::.qdesn_validation_git_sha()
run_tag <- as.character(get_arg("--run-tag", paste0(stamp, "__git-", git_sha)))[1L]

report_root <- resolve_path(
  get_arg("--report-root", file.path("reports", "qdesn_mcmc_validation", "rhs_guardrail_steps_1_to_5", run_tag)),
  must_work = FALSE
)
results_root <- resolve_path(
  get_arg("--results-root", file.path("results", "qdesn_mcmc_validation", "rhs_guardrail_steps_1_to_5", run_tag)),
  must_work = FALSE
)
analysis_root <- report_root

for (d in c(
  analysis_root,
  file.path(analysis_root, "tables"),
  file.path(analysis_root, "config"),
  file.path(analysis_root, "manifest")
)) {
  dir_create(d)
}
dir_create(results_root)

rescue_manifest <- yaml::read_yaml(manifest_path)
rescue_base_defaults <- resolve_path(rescue_manifest$profile$base_defaults, must_work = TRUE)
guardrail_lock <- resolve_path(rescue_manifest$profile$guardrail_lock, must_work = TRUE)
rescue_defaults_repo <- resolve_path(rescue_manifest$profile$materialized_defaults, must_work = FALSE)
source_report_root <- resolve_path(rescue_manifest$profile$source_report_root, must_work = TRUE)

# Step 1: materialize and freeze rescue defaults
rescue_defaults_step1 <- file.path(analysis_root, "config", "qdesn_mcmc_compare_rhs_guardrail_rescue_v1.yaml")
mat_cmd <- c(
  file.path("scripts", "materialize_qdesn_rhs_guardrail_defaults.R"),
  "--base-defaults", rescue_base_defaults,
  "--lock", guardrail_lock,
  "--output", rescue_defaults_step1
)
mat_out <- tryCatch(system2("Rscript", mat_cmd, stdout = TRUE, stderr = TRUE), error = function(e) paste("materialize error:", conditionMessage(e)))
mat_status <- attr(mat_out, "status") %||% 0L
if (!identical(as.integer(mat_status), 0L)) {
  stop(sprintf("Step 1 failed while materializing rescue defaults.\n%s", paste(mat_out, collapse = "\n")), call. = FALSE)
}
rescue_defaults <- yaml::read_yaml(rescue_defaults_step1)
rescue_defaults$campaign <- rescue_defaults$campaign %||% list()
rescue_defaults$campaign$name <- "qdesn_mcmc_rhs_guardrail_rescue_v1"
rescue_defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_guardrail_rescue_v1")
rescue_defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_guardrail_rescue_v1")
yaml::write_yaml(rescue_defaults, rescue_defaults_step1)
if (isTRUE(write_rescue_defaults)) {
  dir_create(dirname(rescue_defaults_repo))
  yaml::write_yaml(rescue_defaults, rescue_defaults_repo)
}

# Step 2: verify diagnostics patch anchors are present
sim_code <- readLines(file.path(repo_root, "scripts", "pipeline_sim_main.R"), warn = FALSE)
real_code <- readLines(file.path(repo_root, "scripts", "pipeline_real_main.R"), warn = FALSE)
step2_check <- data.frame(
  check = c(
    "sim_has_mcmc_rhs_trace_source",
    "real_has_mcmc_rhs_trace_source",
    "sim_has_rhs_trace_unavailable_fallback",
    "real_has_rhs_trace_unavailable_fallback"
  ),
  ok = c(
    any(grepl("source=mcmc_rhs_trace", sim_code, fixed = TRUE)),
    any(grepl("source=mcmc_rhs_trace", real_code, fixed = TRUE)),
    any(grepl("rhs_trace_missing_or_mcmc_diag_unavailable", sim_code, fixed = TRUE)),
    any(grepl("rhs_trace_missing_or_mcmc_diag_unavailable", real_code, fixed = TRUE))
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(step2_check, file.path(analysis_root, "tables", "step2_rhs_trace_patch_checks.csv"), row.names = FALSE)
if (!all(step2_check$ok)) {
  stop("Step 2 failed: RHS trace patch anchors are missing in pipeline scripts.", call. = FALSE)
}

# Step 3: balanced sweep on targeted roots
profiles_cfg <- yaml::read_yaml(profiles_path)
profiles_base_patch <- profiles_cfg$base_patch %||% list()
profiles <- profiles_cfg$profiles %||% list()
if (!length(profiles)) stop(sprintf("No profiles found in: %s", profiles_path), call. = FALSE)

source_pair <- read_csv_safe(file.path(source_report_root, "tables", "campaign_pair_summary.csv"))
source_summary <- summarize_pair(source_pair)
source_summary$profile_id <- "rescue_v1_source"
source_summary$description <- "source report baseline"
source_summary$n_trace_unavailable_mcmc_signoff <- count_contains(source_pair$mcmc_signoff_reason, "rhs_trace_unavailable")
source_summary$n_trace_unavailable_mcmc_unhealthy <- count_contains(source_pair$mcmc_unhealthy_reason, "rhs_trace_unavailable")
source_summary$report_root <- source_report_root
source_summary$results_root <- NA_character_

balanced_rows <- list(source_summary)
profile_defaults_paths <- character(0)

for (ii in seq_along(profiles)) {
  prof <- profiles[[ii]]
  prof_id <- as.character(prof$id %||% sprintf("profile_%02d", ii))
  prof_desc <- as.character(prof$description %||% prof_id)
  cfg_i <- deep_merge(rescue_defaults, profiles_base_patch)
  cfg_i <- deep_merge(cfg_i, prof$patch %||% list())
  cfg_i$campaign <- cfg_i$campaign %||% list()
  cfg_i$campaign$name <- paste0("qdesn_mcmc_rhs_guardrail_", prof_id)
  cfg_i$campaign$results_root <- file.path(results_root, "step3_balanced", prof_id)
  cfg_i$campaign$reports_root <- file.path(report_root, "step3_balanced", prof_id)

  defaults_i <- file.path(analysis_root, "config", sprintf("step3_defaults_%s.yaml", prof_id))
  yaml::write_yaml(cfg_i, defaults_i)
  profile_defaults_paths[[prof_id]] <- defaults_i

  run_i <- exdqlm:::qdesn_validation_run_campaign(
    grid_path = target_grid_path,
    defaults_path = defaults_i,
    results_root = cfg_i$campaign$results_root,
    report_root = cfg_i$campaign$reports_root,
    create_plots = create_plots,
    verbose = verbose
  )

  pair_i <- read_csv_safe(file.path(run_i$report_root, "tables", "campaign_pair_summary.csv"))
  sum_i <- summarize_pair(pair_i)
  sum_i$profile_id <- prof_id
  sum_i$description <- prof_desc
  sum_i$n_trace_unavailable_mcmc_signoff <- count_contains(pair_i$mcmc_signoff_reason, "rhs_trace_unavailable")
  sum_i$n_trace_unavailable_mcmc_unhealthy <- count_contains(pair_i$mcmc_unhealthy_reason, "rhs_trace_unavailable")
  sum_i$report_root <- run_i$report_root
  sum_i$results_root <- run_i$results_root
  balanced_rows[[length(balanced_rows) + 1L]] <- sum_i
}

balanced_summary <- do.call(rbind, balanced_rows)
balanced_summary <- balanced_summary[, c(
  "profile_id", "description",
  "n_pairs", "n_pair_pass", "n_pair_warn", "n_pair_fail", "n_pair_eligible",
  "n_trace_unavailable_mcmc_signoff", "n_trace_unavailable_mcmc_unhealthy",
  "runtime_ratio_median", "report_root", "results_root"
), drop = FALSE]
utils::write.csv(balanced_summary, file.path(analysis_root, "tables", "step3_balanced_summary.csv"), row.names = FALSE)

candidate_rows <- balanced_summary[balanced_summary$profile_id != "rescue_v1_source", , drop = FALSE]
if (!nrow(candidate_rows)) stop("Step 3 failed: no balanced candidate rows were produced.", call. = FALSE)
ord <- with(candidate_rows, order(
  as.numeric(n_pair_fail),
  as.numeric(n_trace_unavailable_mcmc_signoff) + as.numeric(n_trace_unavailable_mcmc_unhealthy),
  as.numeric(n_pair_warn),
  -as.numeric(n_pair_eligible),
  as.numeric(runtime_ratio_median)
))
winner <- candidate_rows[ord[1L], , drop = FALSE]
winner_id <- as.character(winner$profile_id[1L])

# Step 4: broader confirmation on winner
winner_defaults <- yaml::read_yaml(profile_defaults_paths[[winner_id]])
winner_defaults$campaign$name <- paste0("qdesn_mcmc_rhs_guardrail_broader__", winner_id)
winner_defaults$campaign$results_root <- file.path(results_root, "step4_broader", winner_id)
winner_defaults$campaign$reports_root <- file.path(report_root, "step4_broader", winner_id)

winner_defaults_path <- file.path(analysis_root, "config", sprintf("step4_winner_defaults_%s.yaml", winner_id))
yaml::write_yaml(winner_defaults, winner_defaults_path)

run_broader <- exdqlm:::qdesn_validation_run_campaign(
  grid_path = broader_grid_path,
  defaults_path = winner_defaults_path,
  results_root = winner_defaults$campaign$results_root,
  report_root = winner_defaults$campaign$reports_root,
  create_plots = create_plots,
  verbose = verbose
)
pair_broader <- read_csv_safe(file.path(run_broader$report_root, "tables", "campaign_pair_summary.csv"))
broader_summary <- summarize_pair(pair_broader)
broader_summary$winner_profile_id <- winner_id
broader_summary$n_trace_unavailable_mcmc_signoff <- count_contains(pair_broader$mcmc_signoff_reason, "rhs_trace_unavailable")
broader_summary$n_trace_unavailable_mcmc_unhealthy <- count_contains(pair_broader$mcmc_unhealthy_reason, "rhs_trace_unavailable")
broader_summary$report_root <- run_broader$report_root
broader_summary$results_root <- run_broader$results_root
utils::write.csv(broader_summary, file.path(analysis_root, "tables", "step4_broader_summary.csv"), row.names = FALSE)

# Step 5: promotion decision
trace_unavailable_total <- safe_num(broader_summary$n_trace_unavailable_mcmc_signoff, 0) +
  safe_num(broader_summary$n_trace_unavailable_mcmc_unhealthy, 0)
promote <- isTRUE(
  safe_num(broader_summary$n_pair_fail, 1) == 0 &&
    trace_unavailable_total == 0 &&
    safe_num(broader_summary$n_pair_eligible, 0) == safe_num(broader_summary$n_pairs, 0)
)

promotion_written <- FALSE
if (isTRUE(promote)) {
  promoted <- winner_defaults
  promoted$campaign$name <- "qdesn_mcmc_rhs_guardrail_balanced_candidate"
  promoted$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", "rhs_guardrail_balanced_candidate")
  promoted$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", "rhs_guardrail_balanced_candidate")
  dir_create(dirname(promote_defaults_path))
  yaml::write_yaml(promoted, promote_defaults_path)
  promotion_written <- TRUE
}

decision <- list(
  promote = promote,
  promotion_written = promotion_written,
  winner_profile_id = winner_id,
  winner_report_root = as.character(winner$report_root[1L]),
  broader_report_root = run_broader$report_root,
  broader_results_root = run_broader$results_root,
  promotion_defaults_path = if (promotion_written) promote_defaults_path else NULL,
  gate = list(
    n_pair_fail = safe_num(broader_summary$n_pair_fail, NA_real_),
    n_pairs = safe_num(broader_summary$n_pairs, NA_real_),
    n_pair_eligible = safe_num(broader_summary$n_pair_eligible, NA_real_),
    n_trace_unavailable_total = trace_unavailable_total
  ),
  generated_at = as.character(Sys.time()),
  git_sha = git_sha
)
jsonlite::write_json(
  decision,
  file.path(analysis_root, "manifest", "step5_decision.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

summary_lines <- c(
  "# QDESN RHS Guardrail Steps 1 to 5",
  "",
  "## Step 1",
  sprintf("- Materialized rescue defaults: `%s`", rescue_defaults_step1),
  sprintf("- Wrote frozen rescue defaults to repo: `%s`", if (write_rescue_defaults) rescue_defaults_repo else "no"),
  "",
  "## Step 2",
  sprintf("- Patch checks all passed: `%s`", if (all(step2_check$ok)) "yes" else "no"),
  "",
  "## Step 3 (Balanced Sweep)",
  ""
)
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(balanced_summary))
summary_lines <- c(
  summary_lines,
  "",
  "## Step 4 (Broader Confirmation)",
  ""
)
summary_lines <- c(summary_lines, exdqlm:::.qdesn_validation_df_to_markdown(broader_summary))
summary_lines <- c(
  summary_lines,
  "",
  "## Step 5 (Decision)",
  sprintf("- winner_profile_id: `%s`", winner_id),
  sprintf("- promote: `%s`", if (isTRUE(promote)) "true" else "false"),
  sprintf("- promotion_defaults_written: `%s`", if (isTRUE(promotion_written)) "true" else "false"),
  sprintf("- broader_report_root: `%s`", run_broader$report_root)
)
writeLines(summary_lines, file.path(analysis_root, "step1_to_step5_summary.md"))

jsonlite::write_json(
  list(
    run_tag = run_tag,
    analysis_root = analysis_root,
    results_root = results_root,
    rescue_manifest = manifest_path,
    rescue_base_defaults = rescue_base_defaults,
    guardrail_lock = guardrail_lock,
    target_grid = target_grid_path,
    broader_grid = broader_grid_path,
    profiles = profiles_path,
    step2_checks = step2_check,
    winner_profile_id = winner_id,
    decision = decision
  ),
  file.path(analysis_root, "manifest", "step1_to_step5_manifest.json"),
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Analysis root: %s\n", analysis_root))
cat(sprintf("Winner profile: %s\n", winner_id))
cat(sprintf("Promote: %s\n", if (isTRUE(promote)) "yes" else "no"))
if (isTRUE(promotion_written)) {
  cat(sprintf("Promotion defaults: %s\n", promote_defaults_path))
}
