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
drop_flag_with_value <- function(x, flag) {
  idx <- which(x == flag)
  if (!length(idx)) return(x)
  drop <- sort(unique(c(idx, idx + 1L)))
  x[-drop[drop <= length(x)]]
}
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
run_line <- function(cmd, args) paste(shQuote(c(cmd, args)), collapse = " ")
tmux_session_exists <- function(session_name) {
  identical(
    suppressWarnings(system2("tmux", c("has-session", "-t", session_name), stdout = NULL, stderr = NULL)),
    0L
  )
}
sanitize_session <- function(x) {
  out <- gsub("[^A-Za-z0-9_]", "_", x)
  substr(out, 1L, 80L)
}

stage_file <- "qdesn_dynamic_fitforecast_v2_tt500_ridge_corrected_desn"
workers_total <- int_arg("--workers", 18L)
workers_total <- max(1L, min(30L, workers_total))
workers_per_likelihood <- int_arg("--workers-per-likelihood", max(1L, floor(workers_total / 2L)))
workers_per_likelihood <- max(1L, min(15L, workers_per_likelihood))
smoke_workers <- int_arg("--smoke-workers", 4L)
pilot_workers <- int_arg("--pilot-workers", 12L)
git_sha <- trimws(system("git rev-parse --short HEAD", intern = TRUE))
stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_prefix <- as.character(get_arg("--run-prefix", sprintf("qdesn-tt500-ridge-corrected-desn-%s__git-%s", stamp, git_sha)))[1L]
orchestrator_tag <- as.character(get_arg("--orchestrator-tag", sprintf("qdesn-tt500-ridge-corrected-desn-orchestrator-%s__git-%s", stamp, git_sha)))[1L]
dry_run <- has_flag("--dry-run")
detach_all <- has_flag("--detach-all")
do_all <- has_flag("--all")
do_prepare <- has_flag("--prepare") || do_all
do_smoke <- has_flag("--smoke") || do_all
do_pilot <- has_flag("--pilot") || do_all
do_vb_full <- has_flag("--vb-full") || do_all
do_mcmc_full <- has_flag("--mcmc-full") || do_all
skip_materialize <- has_flag("--skip-materialize")

defaults_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_defaults.yaml")), must_work = FALSE)
grid_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_grid.csv")), must_work = FALSE)
manifest_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json")), must_work = FALSE)
winners_path <- resolve_path(file.path("config", "validation", paste0(stage_file, "_winners.csv")), must_work = FALSE)

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
  child_args <- drop_flag(child_args, "--vb-full")
  child_args <- drop_flag(child_args, "--mcmc-full")
  if (!any(child_args == "--all")) child_args <- c(child_args, "--all")
  if (!any(child_args == "--run-prefix")) child_args <- c(child_args, "--run-prefix", run_prefix)
  if (!any(child_args == "--orchestrator-tag")) child_args <- c(child_args, "--orchestrator-tag", orchestrator_tag)
  session_name <- sanitize_session(as.character(get_arg("--tmux-session", paste0("qdesn_tt500_ridge_", substr(run_prefix, 1L, 42L))))[1L])
  if (tmux_session_exists(session_name)) {
    stop(sprintf("tmux session already exists: %s", session_name), call. = FALSE)
  }
  detach_script <- file.path(orchestrator_root, "manifest", "detach_all.sh")
  detach_log <- file.path(orchestrator_root, "logs", "detach_all.log")
  script_lines <- c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    sprintf("cd %s", shQuote(repo_root)),
    "export OMP_NUM_THREADS=1",
    "export OPENBLAS_NUM_THREADS=1",
    "export MKL_NUM_THREADS=1",
    "export VECLIB_MAXIMUM_THREADS=1",
    "export NUMEXPR_NUM_THREADS=1",
    sprintf("exec Rscript %s %s >> %s 2>&1",
            shQuote(file.path("scripts", "orchestrate_qdesn_tt500_ridge_corrected_desn.R")),
            paste(shQuote(child_args), collapse = " "),
            shQuote(detach_log))
  )
  writeLines(script_lines, detach_script)
  Sys.chmod(detach_script, "0755")
  status <- system2("tmux", c("new-session", "-d", "-s", session_name, sprintf("bash %s", shQuote(detach_script))))
  if (!identical(as.integer(status), 0L)) stop("Failed to launch detached ridge corrected DESN orchestrator.", call. = FALSE)
  jsonlite::write_json(
    list(
      launched_at = as.character(Sys.time()),
      mode = "detach_all",
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
  cat(sprintf("[ridge-corrected] %s start: %s\n", label, Sys.time()))
  status <- system2(cmd, args = cmd_args, stdout = log_path, stderr = log_path)
  cat(sprintf("[ridge-corrected] %s status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

run_parallel <- function(label, commands) {
  shell_path <- file.path(orchestrator_root, "logs", paste0(label, ".sh"))
  status_path <- file.path(orchestrator_root, "logs", paste0(label, "_statuses.txt"))
  lines <- c(
    "#!/usr/bin/env bash",
    "set -uo pipefail",
    "export OMP_NUM_THREADS=1",
    "export OPENBLAS_NUM_THREADS=1",
    "export MKL_NUM_THREADS=1",
    "export VECLIB_MAXIMUM_THREADS=1",
    "export NUMEXPR_NUM_THREADS=1",
    sprintf("cd %s", shQuote(repo_root))
  )
  pid_names <- character(0)
  for (nm in names(commands)) {
    cmd <- commands[[nm]]
    log_path <- file.path(orchestrator_root, "logs", paste0(label, "_", nm, ".log"))
    cmd_path <- file.path(orchestrator_root, "logs", paste0(label, "_", nm, "_command.txt"))
    line <- run_line(cmd$cmd, cmd$args)
    writeLines(line, cmd_path)
    pid_name <- paste0("pid_", gsub("[^A-Za-z0-9_]", "_", nm))
    pid_names <- c(pid_names, pid_name)
    lines <- c(lines, sprintf("(%s) > %s 2>&1 &", line, shQuote(log_path)), sprintf("%s=$!", pid_name))
  }
  lines <- c(lines, sprintf(": > %s", shQuote(status_path)), "overall=0")
  for (i in seq_along(commands)) {
    nm <- names(commands)[[i]]
    pid_name <- pid_names[[i]]
    lines <- c(
      lines,
      sprintf("wait $%s", pid_name),
      "status=$?",
      sprintf("printf '%s=%%s\\n' \"$status\" >> %s", nm, shQuote(status_path)),
      "if [ $status -ne 0 ]; then overall=1; fi"
    )
  }
  lines <- c(lines, "exit $overall")
  writeLines(lines, shell_path)
  Sys.chmod(shell_path, "0755")
  if (isTRUE(dry_run)) {
    cat(sprintf("[dry-run] bash %s\n", shQuote(shell_path)))
    return(0L)
  }
  cat(sprintf("[ridge-corrected] %s parallel start: %s\n", label, Sys.time()))
  status <- system2("bash", shell_path)
  cat(sprintf("[ridge-corrected] %s parallel status=%d end: %s\n", label, as.integer(status), Sys.time()))
  as.integer(status)
}

assert_materialized <- function() {
  if (!file.exists(defaults_path) || !file.exists(grid_path) || !file.exists(manifest_path)) {
    stop("Ridge corrected DESN materialization files are missing.", call. = FALSE)
  }
  grid <- utils::read.csv(grid_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (nrow(grid) != 9L) stop(sprintf("Expected 9 ridge roots; observed %d.", nrow(grid)), call. = FALSE)
  if (!identical(sort(unique(as.character(grid$beta_prior_type))), "ridge")) {
    stop("Materialized grid is not ridge-only.", call. = FALSE)
  }
  if (any(grepl("/home/jaguir26/local/src", as.matrix(grid), fixed = TRUE))) {
    stop("Materialized grid contains stale /home/jaguir26/local/src paths.", call. = FALSE)
  }
  invisible(grid)
}

if (!isTRUE(skip_materialize)) {
  status <- run_cmd("materialize", "Rscript", c(file.path("scripts", "materialize_qdesn_tt500_ridge_corrected_desn.R"), "--workers", as.character(workers_total)))
  if (!identical(status, 0L)) stop("Ridge corrected DESN materialization failed.", call. = FALSE)
} else if (!file.exists(manifest_path)) {
  stop("Cannot --skip-materialize because the ridge materialization manifest does not exist.", call. = FALSE)
}
if (!isTRUE(dry_run)) assert_materialized()

if (isTRUE(do_prepare)) {
  status <- run_cmd("prepare_preflight", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "vb,mcmc",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "ridge",
    "--allow-grid-subset",
    "--prepare-only",
    "--workers", as.character(workers_total),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_prefix, "-prepare")
  ))
  if (!identical(status, 0L)) stop("Prepare-only preflight failed.", call. = FALSE)
}

if (isTRUE(do_smoke)) {
  status <- run_cmd("smoke_run", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", defaults_path,
    "--grid", grid_path,
    "--batch", "smoke",
    "--methods", "vb,mcmc",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "ridge",
    "--allow-grid-subset",
    "--workers", as.character(smoke_workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_prefix, "-smoke")
  ))
  if (!identical(status, 0L)) stop("Smoke run failed.", call. = FALSE)
}

pilot_defaults_path <- file.path(orchestrator_root, "manifest", "pilot_defaults.yaml")
pilot_root_ids <- c(
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__gausmix__tau_0p05__lasttt_500__qdesn_ridge__profile_tt500vb_f3_d2_n20_a0p05_r0p6_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__laplace__tau_0p25__lasttt_500__qdesn_ridge__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3",
  "root__dynamic__dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast__normal__tau_0p50__lasttt_500__qdesn_ridge__profile_tt500vb_f3_d1_n30_a0p02_r0p45_m15_lag15_rl0_pw0p03_pin0p3"
)
if (isTRUE(do_pilot)) {
  cfg <- yaml::read_yaml(defaults_path)
  cfg$study_contract$budget$mcmc_n_burn <- 200L
  cfg$study_contract$budget$mcmc_n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$n_burn <- 200L
  cfg$pipeline$inference$mcmc$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$progress_every <- 50L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_burn <- 200L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$n_mcmc <- 500L
  cfg$pipeline$inference$mcmc$prior_overrides$ridge$progress_every <- 50L
  cfg$reference_contract$expected_selected_qdesn_roots <- length(pilot_root_ids)
  yaml::write_yaml(cfg, pilot_defaults_path)
  status <- run_cmd("pilot_run", "Rscript", c(
    file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
    "--defaults", pilot_defaults_path,
    "--grid", grid_path,
    "--batch", "full",
    "--methods", "vb,mcmc",
    "--likelihoods", "al,exal",
    "--fit-sizes", "500",
    "--priors", "ridge",
    "--root-ids", paste(pilot_root_ids, collapse = ","),
    "--allow-grid-subset",
    "--workers", as.character(pilot_workers),
    "--scheduler", "load_balanced",
    "--run-tag", paste0(run_prefix, "-pilot")
  ))
  if (!identical(status, 0L)) stop("Micro-pilot run failed.", call. = FALSE)
}

if (isTRUE(do_vb_full)) {
  status <- run_parallel("vb_full", list(
    al = list(cmd = "Rscript", args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path, "--grid", grid_path, "--batch", "full",
      "--methods", "vb", "--likelihoods", "al", "--fit-sizes", "500", "--priors", "ridge",
      "--allow-grid-subset", "--workers", as.character(workers_per_likelihood),
      "--scheduler", "load_balanced", "--run-tag", paste0(run_prefix, "-vb-al-full")
    )),
    exal = list(cmd = "Rscript", args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path, "--grid", grid_path, "--batch", "full",
      "--methods", "vb", "--likelihoods", "exal", "--fit-sizes", "500", "--priors", "ridge",
      "--allow-grid-subset", "--workers", as.character(workers_per_likelihood),
      "--scheduler", "load_balanced", "--run-tag", paste0(run_prefix, "-vb-exal-full")
    ))
  ))
  if (!identical(status, 0L)) stop("Full VB ridge corrected stage failed.", call. = FALSE)
}

if (isTRUE(do_mcmc_full)) {
  status <- run_parallel("mcmc_full", list(
    al = list(cmd = "Rscript", args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path, "--grid", grid_path, "--batch", "full",
      "--methods", "mcmc", "--likelihoods", "al", "--fit-sizes", "500", "--priors", "ridge",
      "--allow-grid-subset", "--workers", as.character(workers_per_likelihood),
      "--scheduler", "load_balanced", "--run-tag", paste0(run_prefix, "-mcmc-al-full")
    )),
    exal = list(cmd = "Rscript", args = c(
      file.path("scripts", "run_qdesn_dynamic_exdqlm_crossstudy_validation.R"),
      "--defaults", defaults_path, "--grid", grid_path, "--batch", "full",
      "--methods", "mcmc", "--likelihoods", "exal", "--fit-sizes", "500", "--priors", "ridge",
      "--allow-grid-subset", "--workers", as.character(workers_per_likelihood),
      "--scheduler", "load_balanced", "--run-tag", paste0(run_prefix, "-mcmc-exal-full")
    ))
  ))
  if (!identical(status, 0L)) stop("Full MCMC ridge corrected stage failed.", call. = FALSE)
}

manifest <- list(
  generated_at = as.character(Sys.time()),
  orchestrator_tag = orchestrator_tag,
  run_prefix = run_prefix,
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  workers_total = workers_total,
  workers_per_likelihood = workers_per_likelihood,
  smoke_workers = smoke_workers,
  pilot_workers = pilot_workers,
  defaults_path = defaults_path,
  grid_path = grid_path,
  winners_path = winners_path,
  materialization_manifest = manifest_path,
  prepare = do_prepare,
  smoke = do_smoke,
  pilot = do_pilot,
  vb_full = do_vb_full,
  mcmc_full = do_mcmc_full,
  run_tags = list(
    prepare = paste0(run_prefix, "-prepare"),
    smoke = paste0(run_prefix, "-smoke"),
    pilot = paste0(run_prefix, "-pilot"),
    vb_al_full = paste0(run_prefix, "-vb-al-full"),
    vb_exal_full = paste0(run_prefix, "-vb-exal-full"),
    mcmc_al_full = paste0(run_prefix, "-mcmc-al-full"),
    mcmc_exal_full = paste0(run_prefix, "-mcmc-exal-full")
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
