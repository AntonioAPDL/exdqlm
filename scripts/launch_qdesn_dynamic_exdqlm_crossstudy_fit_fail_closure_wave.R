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
`%||%` <- function(a, b) if (is.null(a)) b else a

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

if (!nzchar(Sys.which("tmux"))) {
  stop("tmux is required for the detached dynamic fit-fail closure launcher.", call. = FALSE)
}

runner_rel <- file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave.R")
runner_path <- resolve_path(runner_rel, must_work = TRUE)
manifest_rel <- get_arg("--manifest", file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_fit_fail_closure_wave_manifest.yaml"))
manifest_path <- resolve_path(manifest_rel, must_work = TRUE)
manifest <- yaml::read_yaml(manifest_path)
if (!is.list(manifest)) {
  stop("Dynamic fit-fail closure manifest YAML must parse to a list.", call. = FALSE)
}

campaign_cfg <- manifest$campaign %||% list()
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
run_tag <- as.character(get_arg(
  "--run-tag",
  sprintf("qdesn-dynamic-exdqlm-crossstudy-fitfail-%s__git-%s", format(Sys.time(), "%Y%m%d-%H%M%S"), git_sha)
))[1L]

base_report_root <- resolve_path(
  campaign_cfg$reports_root %||% file.path("reports", "qdesn_mcmc_validation", "dynamic_exdqlm_crossstudy_fit_fail_closure_wave"),
  must_work = FALSE
)
run_report_root <- file.path(base_report_root, run_tag)
launch_root <- file.path(run_report_root, "launch")
dir.create(launch_root, recursive = TRUE, showWarnings = FALSE)

session_name <- as.character(get_arg(
  "--tmux-session",
  sprintf("qdesn_dynxff_%s", format(Sys.time(), "%m%d_%H%M%S"))
))[1L]
launcher_log <- file.path(launch_root, "launcher_stdout.log")
launcher_pid_path <- file.path(launch_root, "launcher_shell.pid")
launcher_meta_path <- file.path(launch_root, "launcher_session.json")
launcher_script_path <- file.path(launch_root, "launch_detached.sh")

child_args <- args
if (!any(child_args == "--run-tag")) {
  child_args <- c(child_args, "--run-tag", run_tag)
}
if (!any(child_args == "--manifest")) {
  child_args <- c(child_args, "--manifest", manifest_path)
}
child_args_quoted <- paste(shQuote(child_args), collapse = " ")
script_lines <- c(
  "#!/usr/bin/env bash",
  sprintf("cd %s", shQuote(repo_root)),
  sprintf("printf '%%s\\n' $$ > %s", shQuote(launcher_pid_path)),
  sprintf("exec Rscript %s %s >> %s 2>&1", shQuote(runner_path), child_args_quoted, shQuote(launcher_log))
)
writeLines(script_lines, launcher_script_path)
Sys.chmod(launcher_script_path, mode = "0755")

launch_cmd <- sprintf(
  "tmux new-session -d -s %s %s",
  shQuote(session_name),
  shQuote(sprintf("bash %s", shQuote(launcher_script_path)))
)
launch_status <- system(launch_cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
if (!identical(as.integer(launch_status), 0L)) {
  stop("Failed to launch detached dynamic fit-fail closure run.", call. = FALSE)
}

Sys.sleep(1)
session_ok <- identical(suppressWarnings(system2("tmux", c("has-session", "-t", session_name))), 0L)
if (!isTRUE(session_ok)) {
  stop(sprintf("Detached tmux session '%s' did not remain alive after launch.", session_name), call. = FALSE)
}

jsonlite::write_json(
  list(
    launched_at = as.character(Sys.time()),
    launcher_mode = "tmux",
    repo_root = repo_root,
    manifest_path = manifest_path,
    runner_path = runner_path,
    run_tag = run_tag,
    session_name = session_name,
    launcher_log = launcher_log,
    launcher_shell_pid_path = launcher_pid_path,
    launcher_script_path = launcher_script_path,
    child_args = child_args
  ),
  launcher_meta_path,
  pretty = TRUE,
  auto_unbox = TRUE,
  null = "null"
)

cat(sprintf("Run tag: %s\n", run_tag))
cat(sprintf("tmux session: %s\n", session_name))
cat(sprintf("Launch metadata: %s\n", launcher_meta_path))
cat(sprintf("Launcher log: %s\n", launcher_log))
cat(sprintf("Planned report root: %s\n", run_report_root))
