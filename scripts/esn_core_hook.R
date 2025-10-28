# This script is sourced by run_one.R
# It:
#  - resolves repo_root and loads your package (as notebook does)
#  - sets file_long from EXDQLM_FILE_LONG
#  - chooses a temporary out_dir to catch artifacts
#  - sources your existing notebook chunk (or minimal extraction)
#    (assumes your notebook uses file_long/out_dir variables if present)

# 1) repo root
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)

# 2) package load (as in your notebook)
suppressPackageStartupMessages({
  req_pkgs <- c("devtools","ggplot2","dplyr","tidyr","tibble","scales",
                "MASS","numDeriv","matrixStats","purrr","readr","patchwork")
  need <- setdiff(req_pkgs, rownames(installed.packages()))
  if (length(need)) install.packages(need, dependencies = TRUE)
  invisible(lapply(req_pkgs, require, character.only = TRUE))
})
devtools::load_all(repo_root, quiet = TRUE)

# 3) Inputs from env
file_env <- Sys.getenv("EXDQLM_FILE_LONG", unset = NA_character_)
if (is.na(file_env)) stop("EXDQLM_FILE_LONG not set")
file_long <- normalizePath(file_env, mustWork = TRUE)

# 4) Output staging dir (current working dir)
out_dir <- file.path(tempdir(), paste0("esn_core_", as.integer(Sys.time())))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# 5) Source your notebook chunk — MINIMAL EDIT REQUIRED:
# Open your notebook and wrap the main chunk in a function:
#   run_esn_notebook(file_long, out_dir, cfg_overrides=list())
# Or, as a quick workaround, we set variables the notebook expects BEFORE you source it:
base_dir  <- dirname(file_long)
save_outputs <- TRUE

# ---- BEGIN: REQUIRED SMALL PATCH IN YOUR NOTEBOOK ----
# (Add at the very top, right after you compute repo_root)
# if (!is.na(Sys.getenv("EXDQLM_FILE_LONG", unset = NA))) {
#   file_long <- Sys.getenv("EXDQLM_FILE_LONG")
#   base_dir  <- dirname(file_long)
# }
# if (!is.na(Sys.getenv("EXDQLM_OUT_DIR", unset = NA))) {
#   out_dir <- Sys.getenv("EXDQLM_OUT_DIR")
# } else {
#   if (!exists("out_dir")) out_dir <- file.path(base_dir, "fig_esn_quantile_notebook")
#   dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
# }
# ---- END PATCH ----

# For now, we also set EXDQLM_OUT_DIR so your patch (when added) will honor it:
Sys.setenv(EXDQLM_OUT_DIR = out_dir)

# 6) Run the notebook file that contains your single-dataset code block.
#    If it's in notebooks/<something>.R, set that path here:
nb_path <- file.path(repo_root, "notebooks", "esn_quantile_single_dataset.R")
if (!file.exists(nb_path)) {
  # If your code lives in the same repo root (as a script), point to it instead:
  nb_path <- file.path(repo_root, "notebooks", "esn_quantile_single_dataset.R")
}
if (!file.exists(nb_path)) stop("Notebook script not found: ", nb_path)

# Source it in the current environment so it picks up file_long/out_dir we set above
source(nb_path, local = TRUE)
