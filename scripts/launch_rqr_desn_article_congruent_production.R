#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  x <- tolower(trimws(as.character(x)[1L]))
  if (x %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (x %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Cannot parse logical flag: %s", x), call. = FALSE)
}

as_int <- function(x, default) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.integer(x[1L]))
  if (!is.finite(out) || out < 1L) stop(sprintf("Expected positive integer, got: %s", x[1L]), call. = FALSE)
  out
}

split_cli_vec <- function(x) {
  if (is.null(x) || !nzchar(as.character(x)[1L])) return(NULL)
  trimws(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
}

git_value <- function(repo_root, ...) {
  paste(tryCatch(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE), error = function(e) character(0)), collapse = "\n")
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

read_csv <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- normalizePath(cli[["repo-root"]] %||% system("git rev-parse --show-toplevel", intern = TRUE)[1L], mustWork = TRUE)
  workers <- as_int(cli[["workers"]], 6L)
  if (!as_flag(cli[["confirm-full-launch"]], FALSE)) {
    stop("Production launcher requires --confirm-full-launch true.", call. = FALSE)
  }
  if (nzchar(Sys.which("tmux")) == FALSE) stop("tmux is required for detached background launch.", call. = FALSE)

  config_path <- normalizePath(cli[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_article_congruent_simulation_20260718.R"), mustWork = TRUE)
  stamp <- cli[["stamp"]] %||% format(Sys.time(), "%Y%m%d_%H%M%S")
  sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  output_root <- normalizePath(
    cli[["output-root"]] %||% file.path(repo_root, "reports", "rqr_desn_article_congruent_simulation", sprintf("run_package_ready_full_%s_git_%s", stamp, sha)),
    mustWork = FALSE
  )
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

  manifest_dir <- file.path(output_root, "manifest")
  materializer <- file.path(repo_root, "scripts", "materialize_rqr_desn_article_congruent_manifest.R")
  materializer_args <- c(materializer, "--config", config_path, "--output-dir", manifest_dir, "--repo-root", repo_root)
  out <- system2(file.path(R.home("bin"), "Rscript"), materializer_args, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status", exact = TRUE) %||% 0L
  writeLines(out, file.path(output_root, "manifest_materialization.log"))
  if (!identical(as.integer(status), 0L)) stop(sprintf("Manifest materialization failed:\n%s", paste(out, collapse = "\n")), call. = FALSE)

  manifest <- read_csv(file.path(manifest_dir, "scenario_manifest.csv"))
  stage_filter <- split_cli_vec(cli[["stage-id"]])
  method_filter <- split_cli_vec(cli[["method-id"]])
  adapter_filter <- split_cli_vec(cli[["implemented-adapter"]]) %||% c("empirical_interval", "rqr_mcmc", "independent_al_pair")
  if (!is.null(stage_filter)) manifest <- manifest[manifest$stage_id %in% stage_filter, , drop = FALSE]
  if (!is.null(method_filter)) manifest <- manifest[manifest$method_id %in% method_filter, , drop = FALSE]
  manifest <- manifest[manifest$implemented_adapter %in% adapter_filter, , drop = FALSE]
  manifest <- manifest[tolower(as.character(manifest$adapter_ready)) %in% c("true", "t", "1", "yes"), , drop = FALSE]
  max_scenarios <- suppressWarnings(as.integer(cli[["max-scenarios"]] %||% NA_integer_))
  if (is.finite(max_scenarios) && max_scenarios > 0L && nrow(manifest) > max_scenarios) {
    manifest <- manifest[seq_len(max_scenarios), , drop = FALSE]
  }
  if (!nrow(manifest)) stop("No package-ready scenarios selected.", call. = FALSE)

  manifest$launcher_shard <- ((seq_len(nrow(manifest)) - 1L) %% workers) + 1L
  write_csv(manifest, file.path(output_root, "selected_launch_manifest.csv"))
  shard_root <- file.path(output_root, "shards")
  dir.create(shard_root, recursive = TRUE, showWarnings = FALSE)
  runner <- file.path(repo_root, "scripts", "run_rqr_desn_article_congruent_simulation.R")
  collector <- file.path(repo_root, "scripts", "collect_rqr_desn_article_congruent_shards.R")
  worker_rows <- data.frame()
  worker_script_paths <- character(workers)

  for (worker_id in seq_len(workers)) {
    shard_dir <- file.path(shard_root, sprintf("shard_%02d", worker_id))
    dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
    ids <- manifest$scenario_id[manifest$launcher_shard == worker_id]
    id_file <- file.path(shard_dir, "scenario_ids.txt")
    writeLines(ids, id_file)
    script <- file.path(shard_root, sprintf("worker_%02d.sh", worker_id))
    worker_script_paths[[worker_id]] <- script
    run_args <- c(
      shQuote(file.path(R.home("bin"), "Rscript")),
      shQuote(runner),
      "--config", shQuote(config_path),
      "--repo-root", shQuote(repo_root),
      "--output-dir", shQuote(shard_dir),
      "--scenario-file", shQuote(id_file),
      "--confirm-full-launch", "true"
    )
    if (!is.null(cli[["mcmc-burn"]])) run_args <- c(run_args, "--mcmc-burn", shQuote(cli[["mcmc-burn"]]))
    if (!is.null(cli[["mcmc-keep"]])) run_args <- c(run_args, "--mcmc-keep", shQuote(cli[["mcmc-keep"]]))
    if (!is.null(cli[["chains"]])) run_args <- c(run_args, "--chains", shQuote(cli[["chains"]]))
    lines <- c(
      "#!/usr/bin/env bash",
      "set -u",
      sprintf("cd %s", shQuote(repo_root)),
      "export OMP_NUM_THREADS=1",
      "export OPENBLAS_NUM_THREADS=1",
      "export MKL_NUM_THREADS=1",
      "export VECLIB_MAXIMUM_THREADS=1",
      "export NUMEXPR_NUM_THREADS=1",
      sprintf("echo started $(date -Is) > %s", shQuote(file.path(shard_dir, "worker_state.log"))),
      sprintf("nice -n 10 %s > %s 2>&1", paste(run_args, collapse = " "), shQuote(file.path(shard_dir, "worker.log"))),
      "code=$?",
      sprintf("echo ${code} > %s", shQuote(file.path(shard_dir, "worker.exit"))),
      sprintf("echo finished $(date -Is) code=${code} >> %s", shQuote(file.path(shard_dir, "worker_state.log"))),
      "exit ${code}"
    )
    writeLines(lines, script)
    Sys.chmod(script, "0755")
    worker_rows <- rbind(worker_rows, data.frame(
      worker_id = worker_id,
      scenario_rows = length(ids),
      shard_dir = shard_dir,
      scenario_file = id_file,
      worker_script = script,
      stringsAsFactors = FALSE
    ))
  }
  write_csv(worker_rows, file.path(output_root, "worker_manifest.csv"))

  supervisor <- file.path(output_root, "supervisor.sh")
  session_name <- cli[["tmux-session"]] %||% sprintf("rqr_article_full_%s", stamp)
  launch_lines <- c(
    "#!/usr/bin/env bash",
    "set +e",
    sprintf("cd %s", shQuote(repo_root)),
    "export OMP_NUM_THREADS=1",
    "export OPENBLAS_NUM_THREADS=1",
    "export MKL_NUM_THREADS=1",
    "export VECLIB_MAXIMUM_THREADS=1",
    "export NUMEXPR_NUM_THREADS=1",
    sprintf("echo started $(date -Is) > %s", shQuote(file.path(output_root, "supervisor_state.log"))),
    sprintf("declare -a scripts=(%s)", paste(shQuote(worker_script_paths), collapse = " ")),
    "declare -a pids=()",
    "for script in \"${scripts[@]}\"; do",
    "  bash \"$script\" &",
    "  pids+=(\"$!\")",
    "done",
    "exit_code=0",
    sprintf("status_file=%s", shQuote(file.path(output_root, "worker_status.csv"))),
    "echo worker_id,pid,exit_code > \"$status_file\"",
    "for i in \"${!pids[@]}\"; do",
    "  pid=\"${pids[$i]}\"",
    "  wid=$((i + 1))",
    "  wait \"$pid\"",
    "  code=$?",
    "  echo ${wid},${pid},${code} >> \"$status_file\"",
    "  if [[ \"$code\" -ne 0 ]]; then exit_code=$code; fi",
    "done",
    sprintf("nice -n 10 %s %s --output-root %s --repo-root %s > %s 2>&1", shQuote(file.path(R.home("bin"), "Rscript")), shQuote(collector), shQuote(output_root), shQuote(repo_root), shQuote(file.path(output_root, "collector.log"))),
    "collector_code=$?",
    "if [[ \"$collector_code\" -ne 0 ]]; then exit_code=$collector_code; fi",
    sprintf("echo finished $(date -Is) code=${exit_code} >> %s", shQuote(file.path(output_root, "supervisor_state.log"))),
    sprintf("echo ${exit_code} > %s", shQuote(file.path(output_root, "supervisor.exit"))),
    "exit ${exit_code}"
  )
  writeLines(launch_lines, supervisor)
  Sys.chmod(supervisor, "0755")

  writeLines(c(
    "# RQR-DESN Article-Congruent Production Launch",
    "",
    sprintf("- tmux session: `%s`", session_name),
    sprintf("- output root: `%s`", output_root),
    sprintf("- workers: `%d`", workers),
    sprintf("- selected package-ready rows: `%d`", nrow(manifest)),
    sprintf("- git commit: `%s`", git_value(repo_root, "rev-parse", "HEAD")),
    "",
    "The supervisor launches one single-threaded low-priority worker per shard, waits for all workers, collects shard outputs, and runs the promotion audit."
  ), file.path(output_root, "LAUNCH_README.md"))

  if (as_flag(cli[["dry-run"]], FALSE)) {
    message(sprintf("Dry run prepared %d package-ready rows for tmux session %s", nrow(manifest), session_name))
    message(sprintf("Output root: %s", output_root))
    return(invisible(output_root))
  }

  tmux_out <- system2("tmux", c("new-session", "-d", "-s", session_name, "bash", supervisor), stdout = TRUE, stderr = TRUE)
  tmux_status <- attr(tmux_out, "status", exact = TRUE) %||% 0L
  writeLines(tmux_out, file.path(output_root, "tmux_launch.log"))
  if (!identical(as.integer(tmux_status), 0L)) stop(sprintf("tmux launch failed:\n%s", paste(tmux_out, collapse = "\n")), call. = FALSE)
  message(sprintf("Launched %d package-ready RQR-DESN workers in tmux session %s", workers, session_name))
  message(sprintf("Output root: %s", output_root))
  invisible(output_root)
}

if (sys.nframe() == 0L) main()
