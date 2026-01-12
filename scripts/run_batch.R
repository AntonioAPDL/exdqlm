#!/usr/bin/env Rscript
# Launch all datasets under a given spec; starts tmux sessions (or serial if --serial)

suppressPackageStartupMessages({
  req <- c("yaml","fs")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  lapply(req, require, character.only=TRUE)
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

args <- commandArgs(trailingOnly = TRUE)
spec_name <- if (length(args)) args[1] else "baseline"
serial <- any(args %in% c("--serial","-s"))

cfg <- yaml::read_yaml("config/defaults.yaml")

ds_all <- yaml::read_yaml("config/datasets.yaml")$datasets
ds <- Filter(function(d) tolower(d$mode %||% "sim") != "real", ds_all)

prefix <- cfg$tmux$session_prefix %||% "esn-"
conc <- cfg$orchestrate$concurrency %||% 2
suite_name <- cfg$suite_name %||% "sim_suite_dlm"
results_root <- cfg$results_root %||% "results"

launch <- function(slug) {
  cmd <- sprintf('Rscript scripts/run_one.R --slug %s --spec %s > %s/%s/%s/runs/last.log 2>&1',
                 slug, spec_name, results_root, suite_name, slug)
  if (serial) {
    message("Running serial: ", slug)
    system(cmd)
  } else {
    sess <- paste0(prefix, slug)
    system2("tmux", c("new-session","-d","-s", shQuote(sess), shQuote(cmd)))
    message("Launched tmux session: ", sess)
  }
}

# crude throttle: if too many sessions exist with prefix, wait user to close; otherwise just launch
if (!serial) {
  message("Note: concurrency cap = ", conc, " (manual; by number of tmux sessions you start)")
}

for (d in ds) launch(d$slug)
