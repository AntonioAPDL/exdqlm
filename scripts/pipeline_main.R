# scripts/pipeline_main.R
#!/usr/bin/env Rscript
# Dispatcher: chooses sim vs real based on env or cfg and sources the right main.

suppressWarnings(suppressMessages({
  req <- c("jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  invisible(lapply(req, require, character.only = TRUE))
}))
`%||%` <- function(a, b) if (!is.null(a)) a else b

# Resolve repo root
args_all   <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args_all[grep("^--file=", args_all)])
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) {
    if (nzchar(script_arg)) normalizePath(file.path(script_arg, ".."), mustWork = FALSE)
    else normalizePath(".", mustWork = FALSE)
  }
)

# Read cfg (optional)
cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()

# Decide mode: env > cfg > default "sim"
mode_env <- Sys.getenv("EXDQLM_PIPELINE_MODE", unset = "")
mode_cfg <- tolower((cfg$pipeline$mode %||% ""))
mode <- tolower(if (nzchar(mode_env)) mode_env else if (nzchar(mode_cfg)) mode_cfg else "sim")

is_sim  <- mode %in% c("sim","simulation")
is_real <- mode %in% c("real","observed","data")

target <- if (is_sim) {
  file.path(repo_root, "scripts", "pipeline_sim_main.R")
} else if (is_real) {
  file.path(repo_root, "scripts", "pipeline_real_main.R")
} else {
  warning(sprintf("Unknown pipeline mode '%s'. Falling back to 'sim'.", mode))
  file.path(repo_root, "scripts", "pipeline_sim_main.R")
}

if (!file.exists(target)) stop("Not found: ", target)

# New clean env keeps globals of each main contained
source(target, local = new.env(parent = globalenv()))
