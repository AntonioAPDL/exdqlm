#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) {
    stop(
      sprintf("Missing required dry-run packages: %s", paste(need, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- normalizePath(
  system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
  winslash = "/",
  mustWork = TRUE
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

source(file.path(repo_root, "validation", "fitforecast_v2", "R", "utils.R"))
ffv2_source_all(file.path(repo_root, "validation", "fitforecast_v2"))

rscript <- "/data/jaguir26/local/opt/R/4.6.0/bin/Rscript"
if (!file.exists(rscript)) rscript <- Sys.which("Rscript")
if (!nzchar(rscript)) stop("No Rscript found.", call. = FALSE)

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
git_short <- substr(trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)), 1L, 7L)
run_label <- as.character(get_arg("--run-label", sprintf("shared-fitforecast-v3-dryrun-%s__git-%s", stamp, git_short)))[1L]
out_root <- file.path("reports", "shared_fitforecast_v2_orchestration", run_label)
logs_root <- file.path(out_root, "logs")
dir.create(logs_root, recursive = TRUE, showWarnings = FALSE)

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

run_step <- function(id, cmd_args, env = character()) {
  log_path <- file.path(logs_root, sprintf("%s.log", id))
  started <- Sys.time()
  out <- tryCatch(
    system2(rscript, cmd_args, env = env, stdout = TRUE, stderr = TRUE),
    error = function(e) {
      attr(e, "status") <- 127L
      sprintf("ERROR: %s", conditionMessage(e))
    }
  )
  status <- attr(out, "status") %||% 0L
  status <- as.integer(status)
  writeLines(enc2utf8(as.character(out)), log_path)
  list(
    id = id,
    status = status,
    started_at = as.character(started),
    finished_at = as.character(Sys.time()),
    cmd = c(rscript, cmd_args),
    log_path = normalizePath(log_path, winslash = "/", mustWork = TRUE)
  )
}

cat("Shared fit+forecast v3 dry-run preflight\n")
cat(sprintf("repo_root: %s\n", repo_root))
cat(sprintf("run_label: %s\n", run_label))
cat(sprintf("out_root: %s\n", out_root))

ffv2_assert_runtime("4.6.0")

exd_tag <- sprintf("exdqlm-dqlm-rolling-origin-v3-dryrun-%s__git-%s", stamp, git_short)
qdesn_smoke_tag <- sprintf("qdesn-rolling-origin-v3-smoke-dryrun-%s__git-%s", stamp, git_short)
qdesn_pilot_tag <- sprintf("qdesn-rolling-origin-v3-pilot-dryrun-%s__git-%s", stamp, git_short)
exd_manifest <- file.path(
  "validation", "fitforecast_v2", "runs", exd_tag, "manifests", "row_manifest.csv"
)

steps <- list()
steps[[length(steps) + 1L]] <- run_step(
  "01_exdqlm_prepare_dryrun",
  c("validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R", "--dry-run")
)
steps[[length(steps) + 1L]] <- run_step(
  "02_exdqlm_prepare_manifest",
  c("validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R",
    "--run-tag", exd_tag)
)
steps[[length(steps) + 1L]] <- run_step(
  "03_exdqlm_smoke_launch_dryrun",
  c("validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R",
    "--phase", "smoke", "--dry-run", "--manifest", exd_manifest)
)
steps[[length(steps) + 1L]] <- run_step(
  "04_exdqlm_pilot_launch_dryrun",
  c("validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R",
    "--phase", "pilot", "--dry-run", "--manifest", exd_manifest)
)
steps[[length(steps) + 1L]] <- run_step(
  "05_qdesn_smoke_launch_dryrun",
  c("scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R",
    "--phase", "smoke", "--dry-run", "--run-tag", qdesn_smoke_tag)
)
steps[[length(steps) + 1L]] <- run_step(
  "06_qdesn_smoke_prepare_only",
  c("scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R",
    "--phase", "smoke", "--prepare-only", "--run-tag", qdesn_smoke_tag)
)
steps[[length(steps) + 1L]] <- run_step(
  "07_qdesn_pilot_launch_dryrun",
  c("scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R",
    "--phase", "pilot", "--dry-run", "--run-tag", qdesn_pilot_tag)
)
steps[[length(steps) + 1L]] <- run_step(
  "08_qdesn_pilot_prepare_only",
  c("scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R",
    "--phase", "pilot", "--prepare-only", "--run-tag", qdesn_pilot_tag)
)

summary <- list(
  generated_at = as.character(Sys.time()),
  run_label = run_label,
  repo_root = repo_root,
  branch = trimws(system2("git", c("rev-parse", "--abbrev-ref", "HEAD"), stdout = TRUE)),
  commit = trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  rscript = rscript,
  package_version = as.character(utils::packageVersion("exdqlm")),
  exdqlm_run_tag = exd_tag,
  exdqlm_manifest = normalizePath(exd_manifest, winslash = "/", mustWork = FALSE),
  qdesn_smoke_run_tag = qdesn_smoke_tag,
  qdesn_pilot_run_tag = qdesn_pilot_tag,
  steps = steps,
  status = if (all(vapply(steps, function(x) identical(x$status, 0L), logical(1)))) "PASS" else "FAIL"
)
json_path <- file.path(out_root, "dryrun_preflight_summary.json")
write_json(summary, json_path)

md_path <- file.path(out_root, "dryrun_preflight_summary.md")
lines <- c(
  "# Shared Fit+Forecast v3 Dry-Run Preflight",
  "",
  sprintf("- generated_at: `%s`", summary$generated_at),
  sprintf("- run_label: `%s`", run_label),
  sprintf("- branch: `%s`", summary$branch),
  sprintf("- commit: `%s`", summary$commit),
  sprintf("- package_version: `%s`", summary$package_version),
  sprintf("- status: `%s`", summary$status),
  sprintf("- exdqlm_manifest: `%s`", summary$exdqlm_manifest),
  sprintf("- qdesn_smoke_run_tag: `%s`", qdesn_smoke_tag),
  sprintf("- qdesn_pilot_run_tag: `%s`", qdesn_pilot_tag),
  "",
  "| Step | Status | Log |",
  "|---|---:|---|",
  vapply(steps, function(step) {
    sprintf("| `%s` | `%d` | `%s` |", step$id, step$status, step$log_path)
  }, character(1))
)
writeLines(lines, md_path)

cat(sprintf("dryrun_summary_json: %s\n", normalizePath(json_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("dryrun_summary_md: %s\n", normalizePath(md_path, winslash = "/", mustWork = TRUE)))
cat(sprintf("dryrun_status: %s\n", summary$status))
if (!identical(summary$status, "PASS") && !has_flag("--allow-fail")) quit(status = 1L, save = "no")
