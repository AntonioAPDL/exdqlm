#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE, digits = 17)
Sys.setenv(OMP_NUM_THREADS = 1, OMP_THREAD_LIMIT = 1, OMP_DYNAMIC = "FALSE",
  OPENBLAS_NUM_THREADS = 1, MKL_NUM_THREADS = 1, BLIS_NUM_THREADS = 1,
  VECLIB_MAXIMUM_THREADS = 1, NUMEXPR_NUM_THREADS = 1, EXDQLM_REQUIRE_PACKAGES_ONLY = 1)
file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
repo <- normalizePath(file.path(dirname(file), "../../.."))
source(file.path(repo, "validation/fitforecast_v2/R/forecast_prefix_metric_intervals_v1.R"))
source(file.path(repo, "validation/fitforecast_v2/R/forecast_prefix_reconstruction_v1.R"))
args <- commandArgs(TRUE)
arg <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  fpf_assert(i < length(args), paste("Missing value:", flag))
  args[i + 1L]
}
mode <- arg("--mode")
if (mode == "worker") {
  state <- fpr_worker(normalizePath(arg("--contract")))
  quit(status = if (state$status == "COMPLETE") 0L else 1L)
}
out <- arg("--output")
fpf_assert(!is.null(out), "--output required.")
if (mode == "prepare") {
  fpr_materialize(repo, out)
  cat("PREPARED 132 selected-source chains; no fits launched\n")
  quit(status = 0L)
}
out <- normalizePath(out)
if (mode == "summarize") {
  fpr_summarize(out)
  source(file.path(repo, "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"))
  quit(status = 0L)
}
if (mode == "health") {
  plan <- fpf_read(file.path(out, "task_plan.csv"))
  states <- vapply(plan$task_id, function(id) {
    p <- file.path(out, "jobs", id, "task_status.json")
    if (file.exists(p)) fpf_json(p)$status else "QUEUED"
  }, character(1))
  print(table(factor(states, levels = c("COMPLETE", "RUNNING", "QUEUED", "FAILED_RETAIN_EVIDENCE"))))
  quit(status = 0L)
}
fpf_assert(mode == "controller", "Unknown reconstruction mode.")
run_controller <- function() {
fpf_assert(identical(system2("git", c("-C", shQuote(repo), "branch", "--show-current"), stdout = TRUE),
  fpr_branch), "Refusing a non-lane branch.")
fpf_assert(length(system2("git", c("-C", shQuote(repo), "status", "--porcelain"), stdout = TRUE)) == 0L,
  "Commit all lane code before launch.")
plan <- fpf_read(file.path(out, "task_plan.csv"))
fpr_assert_hashes(fpf_read(file.path(out, "input_manifest.csv")))
workers <- as.integer(arg("--workers", "15"))
cpus <- as.integer(strsplit(arg("--cpus", paste(32:46, collapse = ",")), ",", fixed = TRUE)[[1]])
fpf_assert(workers >= 1L && workers <= 15L && length(cpus) == workers && !anyDuplicated(cpus) &&
  all(cpus >= 32L & cpus <= 63L), "Use 1-15 unique logical CPUs outside PRICEFM's 0-29 allocation.")
lock <- file.path(out, "controller.lock")
fpf_assert(dir.create(lock, showWarnings = FALSE), "Another reconstruction controller is active.")
on.exit(unlink(lock, recursive = TRUE), add = TRUE)
fpf_assert(requireNamespace("processx", quietly = TRUE), "processx required.")
run_batch <- function(indices, stage) {
  slots <- vector("list", workers)
  pending <- indices
  failed <- FALSE
  while (length(pending) || any(vapply(slots, Negate(is.null), logical(1)))) {
    for (slot in seq_len(workers)) {
      current <- slots[[slot]]
      if (!is.null(current) && !current$process$is_alive()) {
        id <- plan$task_id[current$index]
        p <- file.path(out, "jobs", id, "task_status.json")
        success <- file.exists(p) && fpf_json(p)$status == "COMPLETE" && current$process$get_exit_status() == 0
        if (!success) failed <- TRUE
        cat(format(Sys.time(), tz = "UTC", usetz = TRUE), id, if (success) "COMPLETE" else "FAILED", "\n")
        slots[slot] <- list(NULL)
      }
      if (is.null(slots[[slot]]) && length(pending) && !failed) {
        i <- pending[1]
        pending <- pending[-1]
        p <- file.path(out, "jobs", plan$task_id[i], "task_status.json")
        if (file.exists(p)) {
          old <- fpf_json(p)
          if (old$status == "COMPLETE") {
            fpf_assert(old$contract_sha256 == plan$contract_sha256[i] &&
              fpf_sha(file.path(dirname(p), "retention_manifest.csv")) == old$retention_manifest_sha256,
              "Cached source no longer matches its frozen contract or retention manifest.")
            fpr_assert_hashes(fpf_read(file.path(dirname(p), "retention_manifest.csv")))
            next
          }
          failed <- TRUE
          next
        }
        free_kb <- as.numeric(system2("df", c("-Pk", shQuote(out)), stdout = TRUE)[2] |> strsplit("[[:space:]]+") |>
          unlist() |> (function(x) x[nzchar(x)])() |> (function(x) x[4])())
        memory <- readLines("/proc/meminfo")
        available <- as.numeric(strsplit(trimws(sub("MemAvailable:", "", memory[startsWith(memory, "MemAvailable:")])),
          "[[:space:]]+")[[1]][1])
        if (free_kb < 80 * 1024^2 || available < 64 * 1024^2) {
          pending <- c(i, pending)
          next
        }
        log <- file.path(out, "jobs", plan$task_id[i], "worker.log")
        environment <- Sys.getenv()
        if (plan$model_variant[i] == "exdqlm") environment[["R_LIBS_USER"]] <-
          file.path(repo, "validation/fitforecast_v2/local_trackers/prefix_reconstruction_sources/cran_1p1p1_Rlib")
        process <- processx::process$new("taskset", c("-c", as.character(cpus[slot]),
          file.path(R.home("bin"), "Rscript"), file, "--mode", "worker", "--contract", plan$contract_path[i]),
          stdout = log, stderr = "2>&1", wd = repo, env = environment, cleanup = FALSE)
        slots[[slot]] <- list(process = process, index = i)
        cat("LAUNCHED", plan$task_id[i], "cpu", cpus[slot], "pid", process$get_pid(), "\n")
      }
    }
    if (failed) pending <- integer()
    fpr_write_json(list(stage = stage, status = if (failed) "DRAINING_AFTER_FAILURE" else "RUNNING",
      pid = Sys.getpid(), workers = workers, cpus = cpus,
      active = sum(vapply(slots, Negate(is.null), logical(1))), queued_in_stage = length(pending),
      updated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(out, "controller_status.json"))
    Sys.sleep(10)
  }
  !failed
}
if (!run_batch(which(plan$pilot), "FOUR_MODEL_SOURCE_PILOT")) {
  fpr_write_json(list(status = "PILOT_FAILED_NO_FURTHER_SCHEDULING"), file.path(out, "controller_status.json"))
  stop("Source pilot failed; remaining refits were not scheduled.", call. = FALSE)
}
if (!run_batch(which(!plan$pilot), "SELECTED_SOURCE_RECONSTRUCTION")) {
  fpr_write_json(list(status = "TASK_FAILED_RETAIN_ALL_OUTPUTS"), file.path(out, "controller_status.json"))
  stop("A selected source failed; remaining refits were not scheduled.", call. = FALSE)
}
fpr_summarize(out)
source(file.path(repo, "validation/fitforecast_v2/scripts/render_forecast_prefix_reconstruction_v1.R"))
fpr_write_json(list(status = "COMPLETE_REVIEW_ONLY", workers = workers, active_jobs = 0L,
  article_changed = FALSE, pdf = file.path(out, "review/full_500_300_reconstruction_comparison.pdf")),
  file.path(out, "controller_status.json"))
}
run_controller()
