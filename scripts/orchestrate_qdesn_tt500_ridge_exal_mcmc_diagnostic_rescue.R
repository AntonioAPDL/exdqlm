#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[[1L]]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
has_flag <- function(flag) any(args == flag)
drop_flag <- function(x, flag) x[x != flag]
`%||%` <- function(a, b) if (is.null(a)) b else a

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}
int_arg <- function(flag, default) {
  val <- suppressWarnings(as.integer(get_arg(flag, as.character(default)))[1L])
  if (is.finite(val)) val else as.integer(default)
}
sanitize_session <- function(x) substr(gsub("[^A-Za-z0-9_]", "_", x), 1L, 80L)
tmux_session_exists <- function(session_name) {
  identical(suppressWarnings(system2("tmux", c("has-session", "-t", session_name), stdout = NULL, stderr = NULL)), 0L)
}
run_line <- function(cmd, cmd_args) paste(shQuote(c(cmd, cmd_args)), collapse = " ")

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_exal_mcmc_diagnostic_rescue"
base_stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn"
workers <- max(1L, min(9L, int_arg("--workers", 9L)))
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_prefix <- as.character(get_arg("--run-prefix", sprintf("qdesn-tt500-ridge-exal-mcmc-rescue-%s__git-%s", stamp, git_sha)))[1L]
orchestrator_tag <- as.character(get_arg("--orchestrator-tag", sprintf("qdesn-tt500-ridge-exal-mcmc-rescue-orchestrator-%s__git-%s", stamp, git_sha)))[1L]
dry_run <- has_flag("--dry-run")
detach_all <- has_flag("--detach-all")
do_all <- has_flag("--all")
do_prepare <- has_flag("--prepare") || do_all
do_smoke <- has_flag("--smoke") || do_all
do_pilot <- has_flag("--pilot") || do_all
do_full <- has_flag("--full") || do_all
skip_materialize <- has_flag("--skip-materialize")

defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(base_stage_file, "_grid.csv")), must_work = TRUE)
root_ids_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_root_ids.csv")), must_work = FALSE)
manifest_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)

orchestrator_root <- file.path(repo_root, "reports", "qdesn_mcmc_validation", stage_file, "orchestrators", orchestrator_tag)
dir.create(file.path(orchestrator_root, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(orchestrator_root, "manifest"), recursive = TRUE, showWarnings = FALSE)

if (isTRUE(detach_all)) {
  if (!nzchar(Sys.which("tmux"))) stop("tmux is required for --detach-all.", call. = FALSE)
  child_args <- args
  child_args <- drop_flag(child_args, "--detach-all")
  child_args <- drop_flag(child_args, "--dry-run")
  child_args <- drop_flag(child_args, "--prepare")
  child_args <- drop_flag(child_args, "--smoke")
  child_args <- drop_flag(child_args, "--pilot")
  child_args <- drop_flag(child_args, "--full")
  if (!any(child_args == "--all")) child_args <- c(child_args, "--all")
  if (!any(child_args == "--run-prefix")) child_args <- c(child_args, "--run-prefix", run_prefix)
  if (!any(child_args == "--orchestrator-tag")) child_args <- c(child_args, "--orchestrator-tag", orchestrator_tag)
  session_name <- sanitize_session(as.character(get_arg("--tmux-session", paste0("qdesn_tt500_ridge_exal_rescue_", substr(run_prefix, 1L, 38L))))[1L])
  if (tmux_session_exists(session_name)) stop(sprintf("tmux session already exists: %s", session_name), call. = FALSE)
  detach_script <- file.path(orchestrator_root, "manifest", "detach_all.sh")
  detach_log <- file.path(orchestrator_root, "logs", "detach_all.log")
  writeLines(c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    sprintf("cd %s", shQuote(repo_root)),
    "export OMP_NUM_THREADS=1",
    "export OPENBLAS_NUM_THREADS=1",
    "export MKL_NUM_THREADS=1",
    "export VECLIB_MAXIMUM_THREADS=1",
    "export NUMEXPR_NUM_THREADS=1",
    sprintf("exec Rscript %s %s >> %s 2>&1",
            shQuote(file.path("scripts", "orchestrate_qdesn_tt500_ridge_exal_mcmc_diagnostic_rescue.R")),
            paste(shQuote(child_args), collapse = " "),
            shQuote(detach_log))
  ), detach_script)
  Sys.chmod(detach_script, "0755")
  status <- system2("tmux", c("new-session", "-d", "-s", session_name, sprintf("bash %s", shQuote(detach_script))))
  if (!identical(as.integer(status), 0L)) stop("Failed to launch detached ridge exAL MCMC rescue.", call. = FALSE)
  jsonlite::write_json(
    list(
      launched_at = as.character(Sys.time()),
      session_name = session_name,
      run_prefix = run_prefix,
      orchestrator_tag = orchestrator_tag,
      detach_script = detach_script,
      detach_log = detach_log,
      repo_root = repo_root,
      git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
      child_args = as.list(child_args)
    ),
    file.path(orchestrator_root, "manifest", "detached_orchestrator_manifest.json"),
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
  cat(sprintf("detached_orchestrator_session: %s\n", session_name))
  cat(sprintf("detached_orchestrator_manifest: %s\n", file.path(orchestrator_root, "manifest", "detached_orchestrator_manifest.json")))
  cat(sprintf("detached_orchestrator_log: %s\n", detach_log))
  quit(status = 0)
}

run_cmd <- function(label, cmd, cmd_args) {
  log_path <- file.path(orchestrator_root, "logs", paste0(label, ".log"))
  cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_command.txt"))
  line <- run_line(cmd, cmd_args)
  writeLines(line, cmd_path)
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] %s\n", line))
    return(0L)
  }
  cat(sprintf("[ridge-exal-rescue] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = cmd_args, stdout = log_path, stderr = log_path)
  cat(sprintf("[ridge-exal-rescue] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

if (!isTRUE(skip_materialize)) {
  status <- run_cmd("materialize", "Rscript", c(file.path("scripts", "materialize_qdesn_tt500_ridge_exal_mcmc_diagnostic_rescue.R")))
  if (!identical(status, 0L)) stop("Ridge exAL MCMC rescue materialization failed.", call. = FALSE)
} else if (!file.exists(manifest_path)) {
  stop("Cannot --skip-materialize because rescue materialization manifest is missing.", call. = FALSE)
}

root_ids <- read.csv(root_ids_path, stringsAsFactors = FALSE)$root_id
if (length(root_ids) != 9L) stop("Expected 9 root ids for ridge exAL MCMC rescue.", call. = FALSE)

common_args <- c(
  file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
  "--defaults", defaults_path,
  "--grid", grid_path,
  "--methods", "mcmc",
  "--likelihoods", "exal",
  "--fit-sizes", "500",
  "--priors", "ridge",
  "--root-ids", paste(root_ids, collapse = ","),
  "--allow-grid-subset",
  "--scheduler", "load_balanced"
)

if (isTRUE(do_prepare)) {
  status <- run_cmd("prepare_preflight", "Rscript", c(common_args, "--batch", "full", "--prepare-only", "--workers", as.character(workers), "--run-tag", paste0(run_prefix, "-prepare")))
  if (!identical(status, 0L)) stop("Prepare-only preflight failed.", call. = FALSE)
}

if (isTRUE(do_smoke)) {
  status <- run_cmd("smoke_run", "Rscript", c(common_args, "--batch", "smoke", "--workers", "1", "--run-tag", paste0(run_prefix, "-smoke")))
  if (!identical(status, 0L)) stop("Smoke run failed.", call. = FALSE)
}

if (isTRUE(do_pilot)) {
  pilot_defaults_path <- file.path(orchestrator_root, "manifest", "pilot_defaults.yaml")
  cfg <- yaml::read_yaml(defaults_path)
  cfg$study_contract$budget$mcmc_n_burn <- 200L
  cfg$study_contract$budget$mcmc_n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$n_burn <- 200L
  cfg$pipeline$inference$mcmc$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$progress_every <- 50L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 200L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 50L
  cfg$reference_contract$expected_selected_qdesn_roots <- 3L
  yaml::write_yaml(cfg, pilot_defaults_path)
  status <- run_cmd("pilot_run", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", pilot_defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "mcmc",
    "--likelihoods", "exal",
    "--fit-sizes", "500",
    "--priors", "ridge",
    "--root-ids", paste(root_ids[c(1L, 5L, 9L)], collapse = ","),
    "--allow-grid-subset",
    "--workers", "3",
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_prefix, "-pilot")
  ))
  if (!identical(status, 0L)) stop("Pilot run failed.", call. = FALSE)
}

if (isTRUE(do_full)) {
  status <- run_cmd("full_run", "Rscript", c(common_args, "--batch", "full", "--workers", as.character(workers), "--run-tag", paste0(run_prefix, "-full")))
  if (!identical(status, 0L)) stop("Full ridge exAL MCMC rescue failed.", call. = FALSE)
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestrator_tag = orchestrator_tag,
  run_prefix = run_prefix,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  workers = workers,
  defaults_path = defaults_path,
  grid_path = grid_path,
  root_ids_path = root_ids_path,
  materialization_manifest = manifest_path,
  prepare = do_prepare,
  smoke = do_smoke,
  pilot = do_pilot,
  full = do_full,
  run_tags = list(
    prepare = paste0(run_prefix, "-prepare"),
    smoke = paste0(run_prefix, "-smoke"),
    pilot = paste0(run_prefix, "-pilot"),
    full = paste0(run_prefix, "-full")
  ),
  orchestrator_root = orchestrator_root
)
manifest_out <- file.path(orchestrator_root, "manifest", "orchestrator_manifest.json")
jsonlite::write_json(manifest, manifest_out, pretty = TRUE, auto_unbox = TRUE, null = "null")

cat(sprintf("orchestrator_manifest: %s\n", manifest_out))
cat(sprintf("run_prefix: %s\n", run_prefix))
cat(sprintf("defaults_path: %s\n", defaults_path))
cat(sprintf("grid_path: %s\n", grid_path))
cat(sprintf("orchestrator_root: %s\n", orchestrator_root))
