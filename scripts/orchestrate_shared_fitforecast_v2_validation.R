#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) {
    stop(
      sprintf("Missing required orchestrator packages: %s", paste(need, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(flag) any(args == flag)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx)) return(default)
  idx <- idx[1L]
  if (idx >= length(args)) return(default)
  args[[idx + 1L]]
}
`%||%` <- function(a, b) if (is.null(a)) b else a
truthy <- function(x) tolower(trimws(as.character(x)[1L])) %in% c("1", "true", "yes", "y")

repo_root <- normalizePath(system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)[[1L]],
                           winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

cmd_lines <- function(cmd, args = character(), env = character(), echo = FALSE) {
  if (isTRUE(echo)) {
    cat(sprintf("+ %s %s\n", cmd, paste(shQuote(args), collapse = " ")))
  }
  out <- system2(cmd, args = args, env = env, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status") %||% 0L
  list(status = as.integer(status), lines = enc2utf8(out))
}

stop_if_bad <- function(label, res) {
  if (!identical(res$status, 0L)) {
    cat(paste(res$lines, collapse = "\n"), "\n", sep = "")
    stop(sprintf("%s failed with status %d.", label, res$status), call. = FALSE)
  }
  invisible(res)
}

write_json <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

write_lines <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(as.character(x)), path)
  invisible(path)
}

now_stamp <- function() format(Sys.time(), "%Y%m%d-%H%M%S")
git_sha <- trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE))
git_short <- substr(git_sha, 1L, 7L)
rscript <- "/data/jaguir26/local/opt/R/4.6.0/bin/Rscript"
if (!file.exists(rscript)) rscript <- Sys.which("Rscript")
if (!nzchar(rscript)) stop("No Rscript found.", call. = FALSE)

mode <- match.arg(as.character(get_arg("--mode", "plan"))[1L], c("plan", "preflight", "execute"))
plan <- match.arg(
  as.character(get_arg("--plan", "vb-and-tt500"))[1L],
  c("smoke", "pilot", "vb-only", "vb-and-tt500", "all-approved")
)
run_label <- as.character(get_arg("--run-label", sprintf("shared-fitforecast-v2-%s__git-%s", now_stamp(), git_short)))[1L]
poll_minutes <- as.numeric(get_arg("--poll-minutes", "10"))[1L]
max_active_workers <- as.integer(get_arg("--max-active-workers", "48"))[1L]
allow_dirty <- has_flag("--allow-dirty")
prune_success_binaries <- !has_flag("--no-prune-success-binaries")
workers <- list(
  exdqlm_smoke = as.integer(get_arg("--exdqlm-smoke-workers", "1"))[1L],
  qdesn_smoke = as.integer(get_arg("--qdesn-smoke-workers", "1"))[1L],
  exdqlm_pilot = as.integer(get_arg("--exdqlm-pilot-workers", "2"))[1L],
  qdesn_pilot = as.integer(get_arg("--qdesn-pilot-workers", "2"))[1L],
  exdqlm_vb = as.integer(get_arg("--exdqlm-vb-workers", "16"))[1L],
  qdesn_vb = as.integer(get_arg("--qdesn-vb-workers", "24"))[1L],
  exdqlm_mcmc_tt500 = as.integer(get_arg("--exdqlm-mcmc-tt500-workers", "8"))[1L],
  qdesn_mcmc_tt500 = as.integer(get_arg("--qdesn-mcmc-tt500-workers", "16"))[1L],
  exdqlm_mcmc_tt5000 = as.integer(get_arg("--exdqlm-mcmc-tt5000-workers", "4"))[1L],
  qdesn_mcmc_tt5000 = as.integer(get_arg("--qdesn-mcmc-tt5000-workers", "8"))[1L]
)
workers <- lapply(workers, function(x) max(1L, x))

orchestrator_root <- file.path("reports", "shared_fitforecast_v2_orchestration", run_label)
logs_root <- file.path(orchestrator_root, "logs")
state_root <- file.path(orchestrator_root, "state")
dir.create(logs_root, recursive = TRUE, showWarnings = FALSE)
dir.create(state_root, recursive = TRUE, showWarnings = FALSE)

thread_env <- c(
  "OMP_NUM_THREADS=1",
  "OPENBLAS_NUM_THREADS=1",
  "MKL_NUM_THREADS=1",
  "VECLIB_MAXIMUM_THREADS=1",
  "NUMEXPR_NUM_THREADS=1",
  "EXDQLM_REQUIRE_PACKAGES_ONLY=1"
)

preflight <- function() {
  cat("== shared fit+forecast v2 preflight ==\n")
  cat(sprintf("repo_root: %s\n", repo_root))
  cat(sprintf("run_label: %s\n", run_label))
  cat(sprintf("git_sha: %s\n", git_sha))
  status <- cmd_lines("git", c("status", "--porcelain=v1"))
  if (length(status$lines) && !(isTRUE(allow_dirty) && !identical(mode, "execute"))) {
    cat(paste(status$lines, collapse = "\n"), "\n", sep = "")
    stop("Git worktree must be clean before orchestration.", call. = FALSE)
  } else if (length(status$lines)) {
    cat("WARNING: worktree is dirty; allowed only because --allow-dirty was set outside execute mode.\n")
    cat(paste(status$lines, collapse = "\n"), "\n", sep = "")
  }
  ahead <- trimws(system2("git", c("rev-list", "--left-right", "--count", "HEAD...@{u}"), stdout = TRUE))
  if (!identical(ahead, "0\t0")) stop(sprintf("Branch is not aligned with upstream: %s", ahead), call. = FALSE)
  rver <- cmd_lines(rscript, c(
    "-e",
    shQuote("cat(R.version.string, '\\n'); pkgload::load_all('.', quiet=TRUE); cat(as.character(packageVersion('exdqlm')), '\\n')")
  ))
  stop_if_bad("R/package load", rver)
  cat(paste(rver$lines, collapse = "\n"), "\n", sep = "")

  active_cmd <- paste(
    "TERM=xterm tmux ls 2>&1 | rg '^(qdesn_ff_v2|ffv2_|shared_fitforecast|exdqlm_ffv2)' || true;",
    "ps -ef | rg 'qdesn_ff_v2|launch_qdesn_dynamic_fitforecast|run_qdesn_dynamic_exdqlm_crossstudy|launch_exdqlm_dynamic_fitforecast|run_exdqlm_dynamic_fitforecast'",
    "| rg -v 'rg|bash -lc' || true"
  )
  active <- cmd_lines("bash", c("-lc", shQuote(active_cmd)))
  active_lines <- active$lines[nzchar(trimws(active$lines))]
  active_lines <- active_lines[!grepl("^no server running", active_lines)]
  active_lines <- active_lines[!grepl("^open terminal failed", active_lines)]
  if (length(active_lines)) {
    cat(paste(active_lines, collapse = "\n"), "\n", sep = "")
    stop("Active validation process/session detected. Refusing to start orchestration.", call. = FALSE)
  }

  stale_cmd <- paste(
    "rg -n '/home/jaguir26/local/src'",
    "validation/fitforecast_v2/config",
    "config/validation/qdesn_dynamic_fitforecast_v2_storage_light_defaults.yaml",
    "config/validation/qdesn_dynamic_fitforecast_v2_full_grid.csv",
    "-S || true"
  )
  stale <- cmd_lines("bash", c("-lc", shQuote(stale_cmd)))
  if (length(stale$lines)) {
    cat(paste(stale$lines, collapse = "\n"), "\n", sep = "")
    stop("Active v2 configs contain stale /home/jaguir26/local/src path(s).", call. = FALSE)
  }

  stop_if_bad("exDQLM source verification", cmd_lines(rscript, "validation/fitforecast_v2/scripts/verify_exdqlm_dynamic_fitforecast_v2_source_windows.R"))
  stop_if_bad("Q-DESN source verification", cmd_lines(rscript, "scripts/verify_qdesn_dynamic_fitforecast_v2_source_windows.R"))
  invisible(TRUE)
}

stage_defs <- function(exd_manifest) {
  exd <- function(stage, phase, worker_count) {
    list(
      id = stage,
      family = "exdqlm_dqlm",
      phase = phase,
      workers = worker_count,
      session = sprintf("ffv2_%s_%s", stage, gsub("[^0-9]", "", format(Sys.time(), "%m%d%H%M%S"))),
      env = c(thread_env, "EXDQLM_FFV2_LAUNCH_APPROVED=true"),
      cmd = c(
        rscript,
        "validation/fitforecast_v2/scripts/launch_exdqlm_dynamic_fitforecast_v2_validation.R",
        "--phase", phase,
        "--workers", as.character(worker_count),
        "--manifest", exd_manifest
      ),
      health_cmd = c(
        rscript,
        "validation/fitforecast_v2/scripts/healthcheck_exdqlm_dynamic_fitforecast_v2_validation.R",
        "--manifest", exd_manifest
      )
    )
  }
  qd <- function(stage, phase, worker_count, tt5000 = FALSE) {
    run_tag <- sprintf("qdesn-dynamic-fitforecast-v2-%s-%s__git-%s", gsub("_", "-", phase), now_stamp(), git_short)
    list(
      id = stage,
      family = "qdesn",
      phase = phase,
      run_tag = run_tag,
      workers = worker_count,
      session = sprintf("ffv2_%s_%s", stage, gsub("[^0-9]", "", format(Sys.time(), "%m%d%H%M%S"))),
      env = c(
        thread_env,
        "QDESN_FFV2_LAUNCH_APPROVED=true",
        if (isTRUE(tt5000)) "QDESN_FFV2_TT5000_APPROVED=true" else character(0)
      ),
      cmd = c(
        rscript,
        "scripts/launch_qdesn_dynamic_fitforecast_v2_validation.R",
        "--phase", phase,
        "--run-tag", run_tag,
        "--workers", as.character(worker_count)
      ),
      health_cmd = c(
        rscript,
        "scripts/healthcheck_qdesn_dynamic_fitforecast_v2_validation.R",
        "--run-tag", run_tag
      )
    )
  }

  if (identical(plan, "smoke")) {
    return(list(
      exd("exdqlm_smoke", "smoke", workers$exdqlm_smoke),
      qd("qdesn_smoke", "smoke", workers$qdesn_smoke)
    ))
  }
  if (identical(plan, "pilot")) {
    return(list(
      exd("exdqlm_pilot", "pilot", workers$exdqlm_pilot),
      qd("qdesn_pilot", "pilot", workers$qdesn_pilot)
    ))
  }
  stages <- list(
    exd("exdqlm_vb_full", "vb_full", workers$exdqlm_vb),
    qd("qdesn_vb_full", "vb_full", workers$qdesn_vb)
  )
  if (plan %in% c("vb-and-tt500", "all-approved")) {
    stages <- c(stages, list(
      exd("exdqlm_mcmc_tt500", "mcmc_tt500", workers$exdqlm_mcmc_tt500),
      qd("qdesn_mcmc_tt500", "mcmc_tt500", workers$qdesn_mcmc_tt500)
    ))
  }
  if (identical(plan, "all-approved")) {
    stages <- c(stages, list(
      exd("exdqlm_mcmc_tt5000", "mcmc_tt5000", workers$exdqlm_mcmc_tt5000),
      qd("qdesn_mcmc_tt5000", "mcmc_tt5000", workers$qdesn_mcmc_tt5000, tt5000 = TRUE)
    ))
  }
  stages
}

prepare_exdqlm_manifest <- function() {
  exd_tag <- sprintf("20260515_exdqlm_dqlm_dynamic_fitforecast_v2_orchestrated_%s", gsub("[^0-9]", "", run_label))
  cmd <- c("validation/fitforecast_v2/scripts/prepare_exdqlm_dynamic_fitforecast_v2_validation.R", "--run-tag", exd_tag)
  if (identical(mode, "plan")) {
    return(file.path("validation/fitforecast_v2/runs", exd_tag, "manifests", "row_manifest.csv"))
  }
  res <- cmd_lines(rscript, cmd, env = thread_env, echo = TRUE)
  stop_if_bad("exDQLM prepare", res)
  file.path("validation/fitforecast_v2/runs", exd_tag, "manifests", "row_manifest.csv")
}

write_stage_script <- function(stage) {
  script <- file.path(state_root, sprintf("%s_launch.sh", stage$id))
  lines <- c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    sprintf("cd %s", shQuote(repo_root)),
    sprintf("export %s", stage$env),
    sprintf("exec %s >> %s 2>&1", paste(shQuote(stage$cmd), collapse = " "), shQuote(file.path(logs_root, sprintf("%s.log", stage$id))))
  )
  write_lines(lines, script)
  Sys.chmod(script, "0755")
  script
}

launch_tmux <- function(stage) {
  script <- write_stage_script(stage)
  res <- cmd_lines("tmux", c("new-session", "-d", "-s", stage$session, "bash", script), env = "TERM=xterm", echo = TRUE)
  stop_if_bad(sprintf("launch %s", stage$id), res)
  write_json(c(stage, list(launcher_script = script, launched_at = as.character(Sys.time()))),
             file.path(state_root, sprintf("%s_state.json", stage$id)))
  invisible(stage$session)
}

session_live <- function(session) {
  identical(system2("tmux", c("has-session", "-t", session), env = "TERM=xterm", stdout = FALSE, stderr = FALSE), 0L)
}

run_health <- function(stage) {
  res <- cmd_lines(stage$health_cmd[[1L]], stage$health_cmd[-1L], env = thread_env)
  path <- file.path(logs_root, sprintf("%s_health_%s.log", stage$id, format(Sys.time(), "%Y%m%d_%H%M%S")))
  write_lines(res$lines, path)
  cat(sprintf("[%s] health status=%d log=%s\n", stage$id, res$status, path))
  res
}

prune_files <- function(files, stage_id) {
  files <- unique(normalizePath(files[file.exists(files)], winslash = "/", mustWork = TRUE))
  manifest <- file.path(orchestrator_root, sprintf("%s_prune_manifest.csv", stage_id))
  if (!length(files)) {
    write.csv(data.frame(path = character(0), deleted = logical(0), stringsAsFactors = FALSE), manifest, row.names = FALSE)
    return(invisible(character(0)))
  }
  deleted <- vapply(files, function(path) {
    unlink(path, force = TRUE)
    !file.exists(path)
  }, logical(1L))
  write.csv(data.frame(path = files, deleted = deleted, stringsAsFactors = FALSE), manifest, row.names = FALSE)
  cat(sprintf("[%s] pruned %d success binary payload(s); manifest=%s\n", stage_id, sum(deleted), manifest))
  invisible(files[deleted])
}

prune_success_payloads <- function(stage) {
  if (!isTRUE(prune_success_binaries)) return(invisible(character(0)))
  forbidden <- c("*.rds", "*.rda", "*.RData")
  if (stage$family == "qdesn") {
    root <- file.path(repo_root, "results", "qdesn_mcmc_validation", "dynamic_fitforecast_v2_validation", stage$run_tag)
    if (!dir.exists(root)) return(invisible(character(0)))
    status_paths <- list.files(root, pattern = "^root_status[.]txt$", recursive = TRUE, full.names = TRUE)
    success_roots <- dirname(dirname(status_paths[vapply(status_paths, function(path) {
      identical(trimws(readLines(path, warn = FALSE)[1L]), "SUCCESS")
    }, logical(1L))]))
    files <- unlist(lapply(success_roots, function(dir) {
      unlist(lapply(forbidden, function(pattern) list.files(dir, pattern = glob2rx(pattern), recursive = TRUE, full.names = TRUE)))
    }), use.names = FALSE)
    return(prune_files(files, stage$id))
  }
  if (stage$family == "exdqlm_dqlm") {
    manifest_arg <- stage$cmd[which(stage$cmd == "--manifest") + 1L][1L]
    if (is.na(manifest_arg) || !file.exists(manifest_arg)) return(invisible(character(0)))
    manifest <- read.csv(manifest_arg, stringsAsFactors = FALSE)
    run_root <- unique(manifest$run_root)[1L]
    if (!dir.exists(run_root)) return(invisible(character(0)))
    status_paths <- manifest$row_status_path[file.exists(manifest$row_status_path)]
    statuses <- vapply(status_paths, function(path) {
      st <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
      if (is.null(st) || !nrow(st)) return("unknown")
      as.character(tail(st$status, 1L))
    }, character(1L))
    if (any(statuses %in% c("failed_runtime", "failed_interrupted", "failed_health", "unknown"))) {
      cat(sprintf("[%s] skipping prune because failed/unknown row status exists.\n", stage$id))
      return(invisible(character(0)))
    }
    files <- unlist(lapply(forbidden, function(pattern) list.files(run_root, pattern = glob2rx(pattern), recursive = TRUE, full.names = TRUE)), use.names = FALSE)
    return(prune_files(files, stage$id))
  }
  invisible(character(0))
}

assert_stage_ok <- function(stage) {
  health <- run_health(stage)
  if (isTRUE(prune_success_binaries) &&
      any(grepl("Retained heavy artifact files: [1-9]|forbidden_payloads\\s+[1-9]", health$lines))) {
    prune_success_payloads(stage)
    health <- run_health(stage)
  }
  if (!identical(health$status, 0L)) stop(sprintf("%s healthcheck failed.", stage$id), call. = FALSE)
  if (stage$family == "exdqlm_dqlm") {
    if (any(grepl("failed_runtime|failed_interrupted|forbidden_payloads\\s+[1-9]", health$lines))) {
      stop(sprintf("%s has failed rows or forbidden payloads.", stage$id), call. = FALSE)
    }
  }
  if (stage$family == "qdesn") {
    if (!any(grepl("SUCCESS roots: [1-9]", health$lines)) || any(grepl("FAIL roots: [1-9]", health$lines))) {
      stop(sprintf("%s did not reach all-success root status.", stage$id), call. = FALSE)
    }
    if (any(grepl("Retained heavy artifact files: [1-9]", health$lines))) {
      stop(sprintf("%s retained forbidden heavy artifacts.", stage$id), call. = FALSE)
    }
  }
  invisible(TRUE)
}

print_plan <- function(stages, exd_manifest) {
  total_workers <- vapply(stages, function(x) x$workers, integer(1L))
  plan_obj <- list(
    generated_at = as.character(Sys.time()),
    mode = mode,
    plan = plan,
    run_label = run_label,
    repo_root = repo_root,
    git_sha = git_sha,
    rscript = rscript,
    max_active_workers = max_active_workers,
    poll_minutes = poll_minutes,
    prune_success_binaries = prune_success_binaries,
    exdqlm_manifest = exd_manifest,
    worker_settings = workers,
    stages = lapply(stages, function(s) {
      list(id = s$id, family = s$family, phase = s$phase, workers = s$workers,
           run_tag = s$run_tag %||% NA_character_, cmd = s$cmd, env = s$env)
    }),
    warnings = c(
      if (sum(total_workers) > max_active_workers) {
        sprintf("Sum of stage workers is %d; orchestrator runs stages sequentially unless extended for overlap.", sum(total_workers))
      } else character(0),
      if (identical(plan, "all-approved")) "TT5000 stages require explicit approval flags." else character(0)
    )
  )
  manifest_path <- file.path(orchestrator_root, "orchestration_plan.json")
  write_json(plan_obj, manifest_path)
  cat(sprintf("orchestration_plan: %s\n", normalizePath(manifest_path, winslash = "/", mustWork = FALSE)))
  for (s in stages) {
    cat(sprintf("\n[%s]\nfamily=%s phase=%s workers=%d\n", s$id, s$family, s$phase, s$workers))
    cat(sprintf("env: %s\n", paste(s$env, collapse = " ")))
    cat(sprintf("cmd: %s\n", paste(shQuote(s$cmd), collapse = " ")))
  }
  invisible(plan_obj)
}

execute_plan <- function(stages) {
  if (!truthy(Sys.getenv("SHARED_FFV2_ORCHESTRATOR_APPROVED", "false"))) {
    stop("Refusing execute mode. Set SHARED_FFV2_ORCHESTRATOR_APPROVED=true after reviewing the plan.", call. = FALSE)
  }
  if (identical(plan, "all-approved") && !truthy(Sys.getenv("SHARED_FFV2_TT5000_APPROVED", "false"))) {
    stop("Refusing all-approved plan without SHARED_FFV2_TT5000_APPROVED=true.", call. = FALSE)
  }
  for (stage in stages) {
    cat(sprintf("\n== launching %s ==\n", stage$id))
    launch_tmux(stage)
    repeat {
      Sys.sleep(max(60, poll_minutes * 60))
      if (!session_live(stage$session)) break
      cat(sprintf("[%s] still running at %s\n", stage$id, Sys.time()))
      run_health(stage)
    }
    cat(sprintf("[%s] session finished; checking health\n", stage$id))
    assert_stage_ok(stage)
  }
  cat("\nAll requested stages completed health gates.\n")
}

preflight()
exd_manifest <- prepare_exdqlm_manifest()
stages <- stage_defs(exd_manifest)
print_plan(stages, exd_manifest)
if (identical(mode, "execute")) execute_plan(stages)
