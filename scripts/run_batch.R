#!/usr/bin/env Rscript
# Launch all datasets under a given spec; starts tmux sessions (or serial if --serial)

suppressPackageStartupMessages({
  req <- c("yaml","fs")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  lapply(req, require, character.only=TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
spec_name <- if (length(args)) args[1] else "baseline"
serial <- any(args %in% c("--serial","-s"))

suite <- yaml::read_yaml("config/suite.yaml")
ds <- yaml::read_yaml("config/datasets.yaml")$datasets
prefix <- suite$tmux$session_prefix %||% "esn-"
conc <- suite$orchestrate$concurrency %||% 2

launch <- function(slug) {
  cmd <- sprintf('Rscript scripts/run_one.R --slug %s --spec %s > results/%s/%s/runs/last.log 2>&1',
                 slug, spec_name, suite$suite_name, slug)
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
