# scripts/pipeline_real_main.R
#!/usr/bin/env Rscript
# Skeleton for REAL-DATA pipeline (safe no-op for now).
# It reads observed y (and optional true quantiles for diagnostics),
# prepares output dirs, writes a manifest, and exits cleanly.

suppressWarnings(suppressMessages({
  req <- c("jsonlite","readr","tibble","dplyr","purrr","stringr")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org", dependencies = TRUE)
  invisible(lapply(req, require, character.only = TRUE))
}))

`%||%` <- function(a,b) if (!is.null(a)) a else b
.now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
logf <- function(fmt, ...) { cat(sprintf("[%s] %s\n", .now(), sprintf(fmt, ...))); flush.console() }

# ---- Resolve repo root (works when run from anywhere)
args_all   <- commandArgs(trailingOnly = FALSE)
script_arg <- sub("^--file=", "", args_all[grep("^--file=", args_all)])
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) {
    if (nzchar(script_arg)) normalizePath(file.path(script_arg, ".."), mustWork = FALSE)
    else normalizePath(".", mustWork = FALSE)
  }
)

# ---- Inputs via ENV (mirrors sim style)
# Observed series: CSV with columns: either (t,y) or (date,y). Extra cols ignored.
file_obs   <- Sys.getenv("EXDQLM_FILE_OBS",  unset = NA)
# Optional: long quantiles (t,p,q, optional y, mu) for external diagnostics/comparison
file_long  <- Sys.getenv("EXDQLM_FILE_LONG", unset = NA)
out_dir    <- Sys.getenv("EXDQLM_OUT_DIR",   unset = file.path(repo_root, "out_real"))

# Optional: full cfg from your runner
cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()

# ---- I/O sanity
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
FIGS   <- file.path(out_dir, "figs");   dir.create(FIGS,   recursive = TRUE, showWarnings = FALSE)
TABLES <- file.path(out_dir, "tables"); dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)
MODELS <- file.path(out_dir, "models"); dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)

logf("[real_main] out_dir=%s", out_dir)

# ---- Read observed y
y_df <- NULL
if (!is.na(file_obs) && file.exists(file_obs)) {
  logf("Reading observed y from EXDQLM_FILE_OBS=%s", file_obs)
  y_raw <- readr::read_csv(file_obs, show_col_types = FALSE)
  nm <- names(y_raw)
  # Accept (t,y) or (date,y); coerce to (t,y)
  if (all(c("t","y") %in% nm)) {
    y_df <- tibble::tibble(t = as.integer(y_raw$t), y = as.numeric(y_raw$y)) |>
      dplyr::arrange(t)
  } else if (all(c("date","y") %in% nm)) {
    y_df <- y_raw |>
    dplyr::mutate(date = as.Date(date)) |>
    dplyr::arrange(date) |>
    dplyr::transmute(t = dplyr::row_number(), y = as.numeric(y))
  } else if ("y" %in% nm) {
    y_df <- tibble::tibble(t = seq_len(nrow(y_raw)), y = as.numeric(y_raw$y))
  } else {
    stop("Could not find columns for y. Expected one of: (t,y), (date,y), or a single 'y' column.")
  }
} else if (!is.na(file_long) && file.exists(file_long)) {
  # Convenience: if only long provided, derive y from it
  logf("EXDQLM_FILE_OBS not set; deriving y from EXDQLM_FILE_LONG=%s", file_long)
  long <- readr::read_csv(file_long, show_col_types = FALSE)
  stopifnot(all(c("t","y") %in% names(long)))
  y_df <- long |> dplyr::distinct(t, y) |> dplyr::arrange(t)
} else {
  stop("No observed-series file. Set EXDQLM_FILE_OBS (preferred) or EXDQLM_FILE_LONG.")
}

stopifnot(is.data.frame(y_df), all(c("t","y") %in% names(y_df)), nrow(y_df) >= 5)
T_full <- nrow(y_df)
rng    <- range(y_df$y, na.rm = TRUE)
logf("Observed series loaded: T=%d | range=[%.4f, %.4f]", T_full, rng[1], rng[2])

# ---- Optional: read long quantiles for diagnostics (when available)
long_df <- NULL
if (!is.na(file_long) && file.exists(file_long)) {
  long_df <- readr::read_csv(file_long, show_col_types = FALSE) |>
    dplyr::mutate(t = as.integer(t), p = as.numeric(p), q = as.numeric(q))
  logf("Long-quantiles file detected for diagnostics: %d rows.", nrow(long_df))
}

# ---- Write a minimal manifest (provenance)
manifest <- list(
  pipeline = list(mode = "real", version = "skeleton-0"),
  inputs   = list(
    file_obs  = file_obs %||% NULL,
    file_long = file_long %||% NULL
  ),
  data = list(T = T_full, y_min = rng[1], y_max = rng[2]),
  cfg  = cfg
)

MANI <- file.path(out_dir, "manifest"); dir.create(MANI, showWarnings = FALSE, recursive = TRUE)
readr::write_file(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
                   file.path(MANI, "manifest_real.json"))
logf("Skeleton OK. Wrote manifest to %s", file.path(MANI, "manifest_real.json"))
