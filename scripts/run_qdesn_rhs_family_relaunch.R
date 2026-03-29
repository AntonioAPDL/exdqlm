#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) && idx < length(args)) args[idx + 1L] else default
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

usage <- function() {
  cat(
    "Usage: scripts/run_qdesn_rhs_family_relaunch.R [options]\n\n",
    "Options:\n",
    "  --manifest <path>   Relaunch manifest YAML.\n",
    "  --run-tag <tag>     Relaunch run tag.\n",
    "  --start-at <stage>  Resume/launch beginning at stage id (default: T0).\n",
    "  --execute           Execute the staged relaunch.\n",
    "  --prepare-only      Prepare launch artifacts only (default).\n",
    "  --with-plots        Allow plots in underlying stage runners.\n",
    "  --no-plots          Disable plots in underlying stage runners.\n",
    "  --quiet             Pass --quiet to underlying stage runners.\n",
    "  --help              Print this help.\n",
    sep = ""
  )
}

if (has_flag("--help")) {
  usage()
  quit(status = 0)
}

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
read_csv_safe <- function(path) {
  if (is.null(path) || !file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE),
    error = function(...) data.frame(stringsAsFactors = FALSE)
  )
}
read_json_safe <- function(path) {
  if (is.null(path) || length(path) < 1L || is.na(path[1L]) || !nzchar(trimws(as.character(path[1L])))) return(NULL)
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}
write_json_safe <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
}
write_lines_safe <- function(lines, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path)
}
find_newest_file <- function(root, pattern) {
  if (is.null(root) || !dir.exists(root)) return(NULL)
  hits <- list.files(root, pattern = pattern, recursive = TRUE, full.names = TRUE)
  if (!length(hits)) return(NULL)
  info <- file.info(hits)
  hits[order(info$mtime, decreasing = TRUE)][1L]
}
read_yaml_safe <- function(path) {
  if (is.null(path) || length(path) < 1L || is.na(path[1L]) || !nzchar(trimws(as.character(path[1L])))) return(list())
  if (!file.exists(path)) return(list())
  yaml::read_yaml(path)
}
resolve_campaign_roots_from_defaults <- function(defaults_path, fallback_results, fallback_reports) {
  defaults <- read_yaml_safe(resolve_path(defaults_path, must_work = TRUE))
  campaign_cfg <- defaults$campaign %||% list()
  list(
    results_root = resolve_path(campaign_cfg$results_root %||% fallback_results, must_work = FALSE),
    reports_root = resolve_path(campaign_cfg$reports_root %||% fallback_reports, must_work = FALSE)
  )
}
quote_cmd <- function(cmd) paste(shQuote(as.character(cmd)), collapse = " ")
bool_all_true <- function(df, col) {
  if (!col %in% names(df)) return(TRUE)
  vals <- as.logical(df[[col]])
  vals <- vals[!is.na(vals)]
  if (!length(vals)) return(TRUE)
  all(vals)
}
bool_any_true <- function(df, col) {
  if (!col %in% names(df)) return(FALSE)
  vals <- as.logical(df[[col]])
  vals[is.na(vals)] <- FALSE
  any(vals)
}
df_to_markdown <- function(df) {
  if (!nrow(df) || !ncol(df)) return(c("| empty |", "|---|"))
  fmt <- function(x) {
    x <- as.character(x)
    x[is.na(x) | !nzchar(x)] <- "NA"
    x
  }
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |")
  rows <- apply(df, 1L, function(row) paste0("| ", paste(fmt(row), collapse = " | "), " |"))
  c(hdr, sep, rows)
}
run_command <- function(cmd, log_path) {
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
  status <- system2(cmd[1L], cmd[-1L], stdout = log_path, stderr = log_path)
  as.integer(status %||% 0L)
}
update_stage <- function(state, stage_id, ...) {
  stage <- state$stages[[stage_id]]
  if (is.null(stage)) stop(sprintf("Unknown stage id: %s", stage_id), call. = FALSE)
  dots <- list(...)
  for (nm in names(dots)) stage[[nm]] <- dots[[nm]]
  state$stages[[stage_id]] <- stage
  state
}
render_summary <- function(state) {
  stage_df <- do.call(rbind, lapply(state$stages, function(stage) {
    data.frame(
      stage_id = stage$id,
      label = stage$label,
      status = stage$status,
      gate = stage$gate,
      log_path = stage$log_path,
      command = stage$command,
      artifact = stage$artifact %||% NA_character_,
      stringsAsFactors = FALSE
    )
  }))
  lines <- c(
    "# QDESN RHS-Family Relaunch Supervisor",
    "",
    sprintf("- generated_at: `%s`", state$generated_at),
    sprintf("- run_tag: `%s`", state$run_tag),
    sprintf("- git_sha: `%s`", state$git_sha),
    sprintf("- manifest_path: `%s`", state$manifest_path),
    sprintf("- mode: `%s`", if (isTRUE(state$execute)) "execute" else "prepare_only"),
    sprintf("- workspace: `%s`", state$workspace),
    "",
    "## Stage Plan",
    ""
  )
  lines <- c(lines, df_to_markdown(stage_df), "")
  lines <- c(lines, "## Notes", "")
  lines <- c(lines, "- T0 is the minimum freshness gate.", "")
  lines <- c(lines, "- Stage-P skips the ridge anchor by default for efficiency.", "")
  lines <- c(lines, "- Closeout phase01 resolves its baseline paths from the fresh dynamic manifest at runtime.", "")
  lines <- c(lines, "- Closeout phase35 is still invoked even if Gate A fails; the underlying script then records the skip decision.", "")
  lines
}
write_state <- function(state) {
  stage_rows <- lapply(state$stages, function(stage) {
    list(
      id = stage$id,
      label = stage$label,
      status = stage$status,
      gate = stage$gate,
      command = stage$command,
      log_path = stage$log_path,
      artifact = stage$artifact %||% NA_character_,
      details = stage$details %||% NA_character_
    )
  })
  payload <- list(
    generated_at = state$generated_at,
    run_tag = state$run_tag,
    git_sha = state$git_sha,
    manifest_path = state$manifest_path,
    execute = state$execute,
    workspace = state$workspace,
    stages = stage_rows
  )
  write_json_safe(payload, file.path(state$workspace, "manifest", "relaunch_manifest.json"))
  write_lines_safe(render_summary(state), file.path(state$workspace, "summary", "relaunch_summary.md"))
}

manifest_path <- resolve_path(
  get_arg("--manifest", file.path("config", "validation", "qdesn_rhs_family_relaunch_manifest.yaml")),
  must_work = TRUE
)
cfg <- yaml::read_yaml(manifest_path)

git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("rhsfixrelaunch-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]
if (!nzchar(trimws(run_tag))) stop("--run-tag cannot be empty.", call. = FALSE)

execute <- has_flag("--execute")
quiet <- has_flag("--quiet")
plots_override <- if (has_flag("--with-plots")) TRUE else if (has_flag("--no-plots")) FALSE else NULL
stage_order <- c("T0", "T1", "T2", "T3", "T4A", "T4B")
start_at <- toupper(as.character(get_arg("--start-at", "T0"))[1L])
if (!start_at %in% stage_order) {
  stop(sprintf("--start-at must be one of: %s", paste(stage_order, collapse = ", ")), call. = FALSE)
}
start_idx <- match(start_at, stage_order)

workspace <- resolve_path(
  file.path((cfg$outputs %||% list())$report_root %||% file.path("reports", "qdesn_mcmc_validation", "rhs_family_relaunch"), run_tag),
  must_work = FALSE
)
for (d in c(
  workspace,
  file.path(workspace, "summary"),
  file.path(workspace, "manifest"),
  file.path(workspace, "commands"),
  file.path(workspace, "logs")
)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

t0_cfg <- cfg$stages$t0 %||% list()
stageP_cfg <- cfg$stages$stageP %||% list()
stageQ_cfg <- cfg$stages$stageQ %||% list()
dynamic_cfg <- cfg$stages$dynamic %||% list()
closeout_cfg <- cfg$stages$closeout %||% list()
t0_roots <- resolve_campaign_roots_from_defaults(
  t0_cfg$defaults,
  t0_cfg$results_root %||% file.path("results", "qdesn_mcmc_validation", "rhs_vs_rhs_ns_median"),
  t0_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "rhs_vs_rhs_ns_median")
)
stageP_roots <- resolve_campaign_roots_from_defaults(
  stageP_cfg$defaults,
  file.path("results", "qdesn_mcmc_validation", "rhsns_stageP_wave"),
  file.path("reports", "qdesn_mcmc_validation", "rhsns_stageP_wave")
)
stageQ_roots <- resolve_campaign_roots_from_defaults(
  stageQ_cfg$defaults,
  file.path("results", "qdesn_mcmc_validation", "rhsns_stageQ_wave"),
  file.path("reports", "qdesn_mcmc_validation", "rhsns_stageQ_wave")
)
dynamic_roots <- resolve_campaign_roots_from_defaults(
  dynamic_cfg$defaults,
  file.path("results", "qdesn_mcmc_validation", "dynamic_family_prior_rerun"),
  file.path("reports", "qdesn_mcmc_validation", "dynamic_family_prior_rerun")
)

t0_report_rel <- file.path(t0_roots$reports_root, paste0("t0-", run_tag))
t0_results_rel <- file.path(t0_roots$results_root, paste0("t0-", run_tag))
stageP_run_tag <- paste0("stageP-", run_tag)
stageQ_run_tag <- paste0("stageQ-", run_tag)
dynamic_run_tag <- paste0("dynamic-family-prior-", run_tag)
closeout_run_tag <- paste0("closeout-", run_tag)

flag_for_plots <- function(stage_cfg) {
  use_plots <- plots_override %||% isTRUE(stage_cfg$create_plots %||% FALSE)
  if (isTRUE(use_plots)) character(0) else "--no-plots"
}
quiet_flag <- function() if (isTRUE(quiet)) "--quiet" else character(0)

t0_cmd <- c(
  "Rscript", "scripts/run_qdesn_rhs_vs_rhsns_median_validation.R",
  "--defaults", as.character(t0_cfg$defaults),
  "--grid", as.character(t0_cfg$grid),
  "--results-root", t0_results_rel,
  "--report-root", t0_report_rel,
  flag_for_plots(t0_cfg),
  quiet_flag()
)
stageP_cmd <- c(
  "Rscript", "scripts/run_qdesn_rhsns_stageP_wave.R",
  "--defaults", as.character(stageP_cfg$defaults),
  "--full-grid", as.character(stageP_cfg$full_grid),
  "--workers-full", as.character(stageP_cfg$workers_full %||% 12L),
  "--workers-ridge", as.character(stageP_cfg$workers_ridge %||% 8L),
  "--run-tag", stageP_run_tag,
  if (isTRUE(stageP_cfg$skip_ridge %||% TRUE)) "--skip-ridge" else character(0),
  flag_for_plots(stageP_cfg),
  quiet_flag()
)
stageQ_cmd <- c(
  "Rscript", "scripts/run_qdesn_rhsns_stageQ_wave.R",
  "--defaults", as.character(stageQ_cfg$defaults),
  "--grid", as.character(stageQ_cfg$grid),
  "--workers", as.character(stageQ_cfg$workers %||% 12L),
  "--run-tag", stageQ_run_tag,
  flag_for_plots(stageQ_cfg),
  quiet_flag()
)
dynamic_cmd <- c(
  "Rscript", "scripts/run_qdesn_dynamic_family_prior_wave.R",
  "--defaults", as.character(dynamic_cfg$defaults),
  "--grid", as.character(dynamic_cfg$grid),
  "--workers", as.character(dynamic_cfg$workers %||% 8L),
  "--run-tag", dynamic_run_tag,
  flag_for_plots(dynamic_cfg),
  quiet_flag()
)

state <- list(
  generated_at = as.character(Sys.time()),
  run_tag = run_tag,
  git_sha = git_sha,
  manifest_path = manifest_path,
  execute = execute,
  start_at = start_at,
  workspace = workspace,
  stages = list(
    T0 = list(
      id = "T0",
      label = "Focused rhs vs rhs_ns smoke",
      status = if (execute) {
        if (match("T0", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "all methods SUCCESS; no finite/domain/collapse regressions",
      command = quote_cmd(t0_cmd),
      log_path = file.path(workspace, "logs", "T0_rhs_vs_rhsns.log")
    ),
    T1 = list(
      id = "T1",
      label = "Static rhs_ns Stage-P refresh",
      status = if (execute) {
        if (match("T1", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "rhsns_full root failures == 0",
      command = quote_cmd(stageP_cmd),
      log_path = file.path(workspace, "logs", "T1_stageP.log")
    ),
    T2 = list(
      id = "T2",
      label = "Static rhs_ns Stage-Q refresh",
      status = if (execute) {
        if (match("T2", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "root failures == 0; tau-set wave completes",
      command = quote_cmd(stageQ_cmd),
      log_path = file.path(workspace, "logs", "T2_stageQ.log")
    ),
    T3 = list(
      id = "T3",
      label = "Dynamic family/prior refresh",
      status = if (execute) {
        if (match("T3", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "SUCCESS roots == expected roots",
      command = quote_cmd(dynamic_cmd),
      log_path = file.path(workspace, "logs", "T3_dynamic.log")
    ),
    T4A = list(
      id = "T4A",
      label = "Fresh closeout phase01",
      status = if (execute) {
        if (match("T4A", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "phase01 manifest materializes",
      command = "<resolved from fresh dynamic manifest at runtime>",
      log_path = file.path(workspace, "logs", "T4A_closeout_phase01.log")
    ),
    T4B = list(
      id = "T4B",
      label = "Fresh closeout phase35",
      status = if (execute) {
        if (match("T4B", stage_order) < start_idx) "REUSING" else "PENDING"
      } else "PLANNED",
      gate = "phase35 manifest materializes",
      command = sprintf("Rscript scripts/run_qdesn_validation_closeout_phase35.R --phase01-manifest %s --workers %s %s %s",
        shQuote(file.path(repo_root, "reports", "qdesn_mcmc_validation", paste0("finalization_", closeout_run_tag), "summary", "phase01_manifest.json")),
        as.character(closeout_cfg$phase35_workers %||% 4L),
        paste(flag_for_plots(closeout_cfg), collapse = " "),
        paste(quiet_flag(), collapse = " ")
      ),
      log_path = file.path(workspace, "logs", "T4B_closeout_phase35.log")
    )
  )
)
write_state(state)

execute_launcher <- c(
  "#!/usr/bin/env bash",
  "set -euo pipefail",
  sprintf("cd %s", shQuote(repo_root)),
  paste(
    "Rscript scripts/run_qdesn_rhs_family_relaunch.R",
    "--manifest", shQuote(manifest_path),
    "--run-tag", shQuote(run_tag),
    "--start-at", shQuote(start_at),
    "--execute",
    if (!isTRUE(plots_override %||% FALSE)) "--no-plots" else "--with-plots",
    if (isTRUE(quiet)) "--quiet" else ""
  )
)
write_lines_safe(execute_launcher, file.path(workspace, "commands", "execute_relaunch.sh"))

if (!execute) {
  cat(sprintf("Relaunch plan prepared under: %s\n", workspace))
  cat(sprintf("Summary: %s\n", file.path(workspace, "summary", "relaunch_summary.md")))
  cat(sprintf("Execute with: Rscript scripts/run_qdesn_rhs_family_relaunch.R --manifest %s --run-tag %s --execute%s%s%s\n",
    shQuote(manifest_path),
    shQuote(run_tag),
    if (!identical(start_at, "T0")) sprintf(" --start-at %s", shQuote(start_at)) else "",
    if (!isTRUE(plots_override %||% FALSE)) " --no-plots" else " --with-plots",
    if (isTRUE(quiet)) " --quiet" else ""
  ))
  quit(status = 0)
}

run_stage <- function(state, stage_id, cmd, evaluator) {
  state <- update_stage(state, stage_id, status = "RUNNING")
  write_state(state)
  log_path <- state$stages[[stage_id]]$log_path
  status <- run_command(cmd, log_path)
  if (!identical(status, 0L)) {
    state <- update_stage(state, stage_id, status = "FAILED", details = sprintf("exit_code=%d", status))
    write_state(state)
    stop(sprintf("Stage %s failed; see %s", stage_id, log_path), call. = FALSE)
  }
  ev <- evaluator()
  state <- update_stage(
    state, stage_id,
    status = "SUCCESS",
    artifact = ev$artifact %||% NA_character_,
    details = ev$details %||% NA_character_
  )
  write_state(state)
  state
}

reuse_stage <- function(state, stage_id, evaluator) {
  state <- update_stage(state, stage_id, status = "REUSING")
  write_state(state)
  ev <- evaluator()
  state <- update_stage(
    state, stage_id,
    status = "SUCCESS",
    artifact = ev$artifact %||% NA_character_,
    details = paste(c("reused_existing=TRUE", ev$details %||% NA_character_), collapse = "; ")
  )
  write_state(state)
  state
}

t0_evaluator <- function() {
  outer_report_root <- resolve_path(t0_report_rel, must_work = TRUE)
  manifest_file <- find_newest_file(outer_report_root, "^rhs_vs_rhsns_median_manifest\\.json$")
  if (is.null(manifest_file)) stop("T0 manifest not found.", call. = FALSE)
  mani <- read_json_safe(manifest_file)
  method_df <- read_csv_safe(file.path(mani$report_root, "tables", "campaign_method_summary.csv"))
  if (!nrow(method_df)) stop("T0 method summary missing.", call. = FALSE)
  status_vals <- as.character(method_df$status)
  status_vals[is.na(status_vals)] <- "NA"
  status_ok <- all(status_vals == "SUCCESS")
  finite_ok <- bool_all_true(method_df, "finite_ok")
  domain_ok <- bool_all_true(method_df, "domain_ok")
  unhealthy_ok <- !bool_any_true(method_df, "unhealthy")
  collapse_ok <- !bool_any_true(method_df, "rhs_collapse_flag")
  if (!(status_ok && finite_ok && domain_ok && unhealthy_ok && collapse_ok)) {
    stop("T0 gate failed: one or more methods failed status/finiteness/domain/health checks.", call. = FALSE)
  }
  list(
    artifact = mani$summary_markdown %||% file.path(mani$report_root, "rhs_vs_rhsns_median_summary.md"),
    details = sprintf("report_root=%s", mani$report_root)
  )
}

stageP_evaluator <- function() {
  manifest_file <- file.path(stageP_roots$reports_root, stageP_run_tag, "summary", "stageP_wave_manifest.json")
  mani <- read_json_safe(manifest_file)
  if (is.null(mani)) stop("Stage-P manifest not found.", call. = FALSE)
  summary_df <- read_csv_safe(mani$summary_csv)
  row <- summary_df[as.character(summary_df$arm) == "rhsns_full", , drop = FALSE]
  if (!nrow(row)) stop("Stage-P rhsns_full summary row missing.", call. = FALSE)
  n_roots <- as.integer(row$n_roots[1L])
  n_root_fail <- as.integer(row$n_root_fail[1L])
  n_root_success <- as.integer(row$n_root_success[1L])
  if (!is.finite(n_roots) || !is.finite(n_root_fail) || !is.finite(n_root_success) || n_root_fail != 0L || n_root_success != n_roots) {
    stop("Stage-P gate failed: rhsns_full did not complete without root failures.", call. = FALSE)
  }
  list(
    artifact = mani$summary_md,
    details = sprintf("rhsns_full_report_root=%s", mani$rhsns_full$report_root)
  )
}

stageQ_evaluator <- function() {
  manifest_file <- file.path(stageQ_roots$reports_root, stageQ_run_tag, "summary", "stageQ_wave_manifest.json")
  mani <- read_json_safe(manifest_file)
  if (is.null(mani)) stop("Stage-Q manifest not found.", call. = FALSE)
  summary_df <- read_csv_safe(mani$summary_csv)
  if (!nrow(summary_df)) stop("Stage-Q summary missing.", call. = FALSE)
  row <- summary_df[1L, , drop = FALSE]
  n_roots <- as.integer(row$n_roots[1L])
  n_root_fail <- as.integer(row$n_root_fail[1L])
  n_root_success <- as.integer(row$n_root_success[1L])
  tau_incomplete <- as.integer(row$tau_set_incomplete[1L] %||% 0L)
  if (!is.finite(n_roots) || !is.finite(n_root_fail) || !is.finite(n_root_success) || !is.finite(tau_incomplete) || n_root_fail != 0L || n_root_success != n_roots || tau_incomplete != 0L) {
    stop("Stage-Q gate failed: root failure or incomplete tau-set state detected.", call. = FALSE)
  }
  hc_log <- file.path(workspace, "logs", "T2_stageQ_healthcheck.log")
  hc_cmd <- c(
    "Rscript", "scripts/healthcheck_qdesn_rhsns_stageQ_wave.R",
    "--run-tag", stageQ_run_tag,
    "--arm", "rhsns_full"
  )
  if (run_command(hc_cmd, hc_log) != 0L) stop("Stage-Q healthcheck failed.", call. = FALSE)
  list(
    artifact = mani$summary_md,
    details = sprintf("healthcheck_log=%s", hc_log)
  )
}

dynamic_manifest_file <- file.path(dynamic_roots$reports_root, dynamic_run_tag, "summary", "dynamic_wave_manifest.json")
dynamic_evaluator <- function() {
  mani <- read_json_safe(dynamic_manifest_file)
  if (is.null(mani)) stop("Dynamic-wave manifest not found.", call. = FALSE)
  status_mix <- read_csv_safe(mani$tables$status_mix)
  success_n <- if (nrow(status_mix) && "root_status" %in% names(status_mix) && "Freq" %in% names(status_mix)) {
    sum(as.integer(status_mix$Freq[as.character(status_mix$root_status) == "SUCCESS"]), na.rm = TRUE)
  } else {
    NA_integer_
  }
  expected_roots <- as.integer(mani$expected_roots %||% NA_integer_)
  if (!is.finite(success_n)) {
    campaign_status <- read_csv_safe(mani$tables$campaign_status %||% NA_character_)
    if (nrow(campaign_status) && "n_root_success" %in% names(campaign_status)) {
      success_n <- as.integer(campaign_status$n_root_success[1L])
    }
  }
  if (!is.finite(expected_roots) || !is.finite(success_n) || success_n != expected_roots) {
    stop("Dynamic-wave gate failed: SUCCESS roots did not match expected roots.", call. = FALSE)
  }
  hc_log <- file.path(workspace, "logs", "T3_dynamic_healthcheck.log")
  hc_cmd <- c(
    "Rscript", "scripts/healthcheck_qdesn_dynamic_family_prior_wave.R",
    "--run-tag", dynamic_run_tag,
    "--defaults", as.character(dynamic_cfg$defaults),
    "--grid", as.character(dynamic_cfg$grid)
  )
  if (run_command(hc_cmd, hc_log) != 0L) stop("Dynamic-wave healthcheck failed.", call. = FALSE)
  list(
    artifact = mani$tables$markdown_summary %||% file.path(dirname(dynamic_manifest_file), "dynamic_wave_summary.md"),
    details = sprintf("report_run_root=%s", mani$report_run_root)
  )
}

phase01_evaluator <- function() {
  phase01_manifest <- file.path(repo_root, "reports", "qdesn_mcmc_validation", paste0("finalization_", closeout_run_tag), "summary", "phase01_manifest.json")
  mani <- read_json_safe(phase01_manifest)
  if (is.null(mani)) stop("Closeout phase01 manifest not found.", call. = FALSE)
  gateA <- mani$gateA %||% list(gateA_pass = FALSE)
  list(
    artifact = phase01_manifest,
    details = sprintf("gateA_pass=%s", if (isTRUE(gateA$gateA_pass)) "TRUE" else "FALSE")
  )
}

phase35_evaluator <- function() {
  phase35_manifest <- file.path(repo_root, "reports", "qdesn_mcmc_validation", paste0("finalization_", closeout_run_tag), "summary", "phase35_manifest.json")
  mani <- read_json_safe(phase35_manifest)
  if (is.null(mani)) stop("Closeout phase35 manifest not found.", call. = FALSE)
  list(
    artifact = phase35_manifest,
    details = sprintf("recommendation=%s", as.character(mani$recommendation %||% "NA"))
  )
}

if (execute && start_idx > 1L) {
  prior_eval <- list(
    T0 = t0_evaluator,
    T1 = stageP_evaluator,
    T2 = stageQ_evaluator,
    T3 = dynamic_evaluator,
    T4A = phase01_evaluator,
    T4B = phase35_evaluator
  )
  for (sid in stage_order[seq_len(start_idx - 1L)]) {
    state <- reuse_stage(state, sid, prior_eval[[sid]])
  }
}

if (start_idx <= match("T0", stage_order)) state <- run_stage(state, "T0", t0_cmd, t0_evaluator)
if (start_idx <= match("T1", stage_order)) state <- run_stage(state, "T1", stageP_cmd, stageP_evaluator)
if (start_idx <= match("T2", stage_order)) state <- run_stage(state, "T2", stageQ_cmd, stageQ_evaluator)
if (start_idx <= match("T3", stage_order)) state <- run_stage(state, "T3", dynamic_cmd, dynamic_evaluator)

dynamic_manifest <- read_json_safe(dynamic_manifest_file)
if (is.null(dynamic_manifest)) stop("Dynamic manifest missing after T3.", call. = FALSE)
baseline_report_root <- as.character(dynamic_manifest$report_run_root)[1L]
baseline_results_root <- as.character(dynamic_manifest$results_run_root)[1L]
phase01_manifest_path <- file.path(repo_root, "reports", "qdesn_mcmc_validation", paste0("finalization_", closeout_run_tag), "summary", "phase01_manifest.json")

phase01_cmd <- c(
  "Rscript", "scripts/run_qdesn_validation_closeout_phase01.R",
  "--run-tag", closeout_run_tag,
  "--baseline-report-root", baseline_report_root,
  "--baseline-results-root", baseline_results_root,
  "--micro-size", as.character(closeout_cfg$micro_size %||% 6L),
  quiet_flag()
)
state <- update_stage(state, "T4A", command = quote_cmd(phase01_cmd))
write_state(state)
if (start_idx <= match("T4A", stage_order)) {
  state <- run_stage(state, "T4A", phase01_cmd, phase01_evaluator)
}

phase35_cmd <- c(
  "Rscript", "scripts/run_qdesn_validation_closeout_phase35.R",
  "--phase01-manifest", phase01_manifest_path,
  "--workers", as.character(closeout_cfg$phase35_workers %||% 4L),
  flag_for_plots(closeout_cfg),
  quiet_flag()
)
state <- update_stage(state, "T4B", command = quote_cmd(phase35_cmd))
write_state(state)
if (start_idx <= match("T4B", stage_order)) {
  state <- run_stage(state, "T4B", phase35_cmd, phase35_evaluator)
}

cat(sprintf("Relaunch execution completed. Workspace: %s\n", workspace))
cat(sprintf("Summary: %s\n", file.path(workspace, "summary", "relaunch_summary.md")))
