#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  req <- c("yaml","jsonlite","digest","fs","tools","withr")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  invisible(lapply(req, require, character.only=TRUE))
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

# -- Resolve repo root
args_all   <- commandArgs(trailingOnly = FALSE)
script_idx <- grep("^--file=", args_all)
script_file <- if (length(script_idx)) sub("^--file=", "", args_all[script_idx]) else ""
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) {
    if (length(script_file) && nzchar(script_file)) {
      normalizePath(dirname(script_file), mustWork = FALSE)
    } else {
      normalizePath(".", mustWork = FALSE)
    }
  }
)
setwd(repo_root)

# --- CLI
args <- commandArgs(trailingOnly = TRUE)
get_arg  <- function(flag, default=NULL) { i <- which(args == flag); if (length(i) && i < length(args)) args[i+1] else default }
has_flag <- function(flag) any(args == flag)
slug      <- get_arg("--slug")
spec_name <- get_arg("--spec")
dry_run   <- has_flag("--dry-run")
stopifnot(nzchar(slug), nzchar(spec_name))

# --- Load YAMLs
defaults <- yaml::read_yaml("config/defaults.yaml")
suite    <- if (file.exists("config/suite.yaml"))   yaml::read_yaml("config/suite.yaml")   else list()
datasets_sim  <- if (file.exists("config/datasets.yaml"))       yaml::read_yaml("config/datasets.yaml")       else list(datasets=list())
datasets_real <- if (file.exists("config/datasets_real.yaml"))  yaml::read_yaml("config/datasets_real.yaml")  else list(datasets=list())
datasets <- c(datasets_sim$datasets, datasets_real$datasets)
local <- if (file.exists("config/local.yaml")) yaml::read_yaml("config/local.yaml") else list()

# find dataset entry
ds <- NULL
for (d in datasets) if (identical(d$slug, slug)) { ds <- d; break }
if (is.null(ds)) stop("Dataset slug not found: ", slug)

mode_ds <- tolower(ds$mode %||% "")
if (!nzchar(mode_ds)) {
  # fall back to overrides.pipeline.mode if present
  mode_ds <- tolower(ds$overrides$pipeline$mode %||% "")
}

input_path <- ds$input_path
if (!file.exists(input_path)) stop("Input file not found: ", input_path)

# Flexible spec resolver: <name>.yaml | spec_<name>.yaml | sim_<name>.yaml | real_<name>.yaml
cand <- c(
  file.path("config","specs", paste0(spec_name, ".yaml")),
  file.path("config","specs", paste0("spec_", spec_name, ".yaml")),
  file.path("config","specs", paste0("sim_",  spec_name, ".yaml")),
  file.path("config","specs", paste0("real_", spec_name, ".yaml"))
)
spec_path <- cand[file.exists(cand)][1]
if (is.na(spec_path) || !length(spec_path)) {
  stop("Spec not found. Tried: ", paste(cand, collapse=" | "))
}
spec <- yaml::read_yaml(spec_path)

deep_merge <- function(a,b){
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  if (is.list(a) && is.list(b)) {
    keys <- unique(c(names(a), names(b)))
    out  <- lapply(keys, function(k) deep_merge(a[[k]], b[[k]]))
    names(out) <- keys
    out
  } else b
}

cfg <- defaults
cfg <- deep_merge(cfg, suite)
cfg <- deep_merge(cfg, spec)
cfg <- deep_merge(cfg, ds$overrides)
cfg <- deep_merge(cfg, local)

# ---- YAML 1.1 boolean-key compatibility (protect 'n' and columns$y) ----
if (!is.null(cfg$desn)) {
  # libyaml (YAML 1.1) can coerce key 'n' to boolean FALSE
  if (is.null(cfg$desn$n) && "FALSE" %in% names(cfg$desn)) {
    cfg$desn$n <- cfg$desn$`FALSE`; cfg$desn$`FALSE` <- NULL
  }
}

# Helper to undo YAML 1.1 booleanized keys in a list (e.g., y -> TRUE)
fix_yaml_bool_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  nm <- names(x)
  if ("TRUE"  %in% nm && is.null(x$y)) { x$y <- x$`TRUE`;  x$`TRUE`  <- NULL }
  if ("FALSE" %in% nm && is.null(x$n)) { x$n <- x$`FALSE`; x$`FALSE` <- NULL }
  x
}

cfg$columns <- fix_yaml_bool_keys(cfg$columns)
if (!is.null(ds$overrides) && !is.null(ds$overrides$columns)) {
  ds$overrides$columns <- fix_yaml_bool_keys(ds$overrides$columns)
}


# ---- Force dataset column overrides into cfg (defensive) ----
if (!is.null(ds$overrides) && !is.null(ds$overrides$columns)) {
  cfg$columns <- deep_merge(cfg$columns, ds$overrides$columns)
}

# ---- Normalize DESN numeric fields (treat length-0 as NULL; broadcast scalars) ----
norm_num <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  x <- as.numeric(x)
  if (length(x) == 0L || all(is.na(x))) return(NULL)
  x
}

if (!is.null(cfg$desn)) {
  Dcfg <- as.integer((cfg$desn$D %||% 1L))

  cfg$desn$n   <- norm_num(cfg$desn$n)
  cfg$desn$rho <- norm_num(cfg$desn$rho)

  if (!is.null(cfg$desn$n)   && length(cfg$desn$n)   == 1L && Dcfg > 1L) cfg$desn$n   <- rep(cfg$desn$n,   Dcfg)
  if (!is.null(cfg$desn$rho) && length(cfg$desn$rho) == 1L && Dcfg > 1L) cfg$desn$rho <- rep(cfg$desn$rho, Dcfg)

  # Only enforce lengths when the field is actually present
  if (!is.null(cfg$desn$n)   && length(cfg$desn$n)   != Dcfg)
    stop(sprintf("Config error: length(desn$n)=%d but desn$D=%d",   length(cfg$desn$n),   Dcfg))
  if (!is.null(cfg$desn$rho) && length(cfg$desn$rho) != Dcfg)
    stop(sprintf("Config error: length(desn$rho)=%d but desn$D=%d", length(cfg$desn$rho), Dcfg))
}

# Effective suite & roots
suite_name   <- cfg$suite_name %||% "sim_suite_dlm"
results_root <- cfg$results_root %||% "results"

# Git/host info
git_sha    <- try(system("git rev-parse --short HEAD", intern = TRUE), silent=TRUE); git_sha    <- if (inherits(git_sha,"try-error")) NA else git_sha
git_branch <- try(system("git rev-parse --abbrev-ref HEAD", intern = TRUE), silent=TRUE); git_branch <- if (inherits(git_branch,"try-error")) NA else git_branch
git_dirty  <- try(system("git diff --quiet || echo DIRTY", intern = TRUE), silent=TRUE); git_dirty  <- if (length(git_dirty) && git_dirty=="DIRTY") TRUE else FALSE

# Input SHA256 + cfg hash
inp_sha <- digest::digest(file = input_path, algo = "sha256")
cfg_for_hash <- cfg; cfg_for_hash$orchestrate <- NULL; cfg_for_hash$naming <- NULL
cfg_hash <- substr(digest::digest(cfg_for_hash, algo="sha256"), 1, 8)

# Timestamped run dir
stamp  <- format(Sys.time(), "%Y%m%d-%H%M%S")
run_id <- sprintf("%s__git-%s__spec-%s__cfg-%s", stamp, git_sha, spec_name, cfg_hash)
run_dir <- fs::path(results_root, suite_name, slug, "runs", run_id)
fs::dir_create(fs::path(run_dir, "figs"))
fs::dir_create(fs::path(run_dir, "tables"))
fs::dir_create(fs::path(run_dir, "models"))
fs::dir_create(fs::path(run_dir, "manifest"))
fs::dir_create(fs::path(run_dir, "thesis"))
fs::dir_create(fs::path(run_dir, "logs"))

# Mode-aware schema check (prefer merged cfg$columns; fall back to ds$overrides)
hdr <- try(read.csv(input_path, nrows = 1))
if (inherits(hdr, "try-error")) {
  cat("Could not read the first row of input file: ", input_path, "\n")
  writeLines("FAIL", fs::path(run_dir, "manifest", "status.txt"))
  quit(save = "no", status = 1)
}
need_sim  <- c("t","p","q","y","mu")
need_real <- c("t","y")

mode_eff <- if (nzchar(mode_ds)) mode_ds else tolower(cfg$pipeline$mode %||% "sim")

if (mode_eff %in% c("sim","simulation")) {
  if (!all(need_sim %in% names(hdr))) {
    cat("Schema failure (sim); missing among:", paste(need_sim, collapse=", "), "\n")
    writeLines("FAIL", fs::path(run_dir,"manifest","status.txt")); quit(save="no", status=1)
  } else {
    cat("Schema OK (sim) | header: ", paste(names(hdr), collapse=", "), "\n", sep = "")
  }
} else if (mode_eff %in% c("real","observed","data")) {
  # Prefer merged cfg (defaults → suite → spec → overrides → local), then ds$overrides, then default
  # Resolve column mapping (dataset override MUST win)
  cols_cfg <- cfg$columns %||% list()
  y_map_ds <- if (!is.null(ds$overrides) && !is.null(ds$overrides$columns)) ds$overrides$columns$y else NULL
  date_ds  <- if (!is.null(ds$overrides) && !is.null(ds$overrides$columns)) ds$overrides$columns$date else NULL

  hdr_nms <- names(hdr)
  y_map    <- y_map_ds %||% cols_cfg$y %||% (if ("y" %in% hdr_nms) "y" else hdr_nms[1])
  date_map <- date_ds  %||% cols_cfg$date %||% NULL

cat(sprintf("Column mapping (real): y_map='%s'%s\n",
            y_map, if (!is.null(date_map)) sprintf(", date_map='%s'", date_map) else ""))

  hdr_nms <- names(hdr)

  # Accept any of: (y only) OR (t & y) OR (date & y)
  ok_real <- (y_map %in% hdr_nms) ||
             (all(c("t", y_map) %in% hdr_nms)) ||
             (!is.null(date_map) && all(c(date_map, y_map) %in% hdr_nms))

  if (!ok_real) {
    cat("Schema failure (real): could not find mapped y column '", y_map,
        "' (or t/date) in header: ", paste(hdr_nms, collapse=", "), "\n", sep = "")
    writeLines("FAIL", fs::path(run_dir,"manifest","status.txt"))
    quit(save="no", status=1)
  } else {
    cat("Schema OK (real): y_map='", y_map, "'",
        if (!is.null(date_map)) paste0(", date_map='", date_map, "'") else "",
        " | header: ", paste(hdr_nms, collapse=", "), "\n", sep = "")
  }
} else {
  cat("Unknown dataset mode: ", mode_eff, " (expected sim|real)\n")
  writeLines("FAIL", fs::path(run_dir,"manifest","status.txt")); quit(save="no", status=1)
}

# Save effective cfg alongside manifest
jsonlite::write_json(cfg, fs::path(run_dir,"manifest","cfg_effective.json"), pretty=TRUE, auto_unbox=TRUE)
yaml::write_yaml(cfg, fs::path(run_dir,"manifest","cfg_effective.yaml"))

# Manifest (pre-run)
manifest <- list(
  started_at = as.character(Sys.time()),
  dataset    = list(slug = slug, input_path = normalizePath(input_path), input_sha256 = inp_sha, mode = mode_eff),
  git        = list(sha = git_sha, branch = git_branch, dirty = git_dirty),
  suite      = suite_name, spec = spec_name, cfg_hash = cfg_hash,
  host       = as.list(Sys.info()[c("nodename","sysname","release")]),
  orchestrate= cfg$orchestrate
)
jsonlite::write_json(manifest, fs::path(run_dir,"manifest","run_manifest.json"), pretty=TRUE, auto_unbox=TRUE)
writeLines(if (dry_run) "DRY-RUN" else "RUNNING", fs::path(run_dir,"manifest","status.txt"))

if (isTRUE(dry_run)) {
  cat("Dry run: would invoke ",
    if (mode_eff %in% c("real","observed","data")) "pipeline_real_main.R" else "pipeline_main.R",
    " with input=", input_path, " mode=", mode_eff, "\n", sep = "")

  quit(save="no", status=0)
}

# Environment (threads + handoff to dispatcher)
env <- cfg$env %||% list()
env$OMP_NUM_THREADS      <- as.character(cfg$orchestrate$threads_per_proc %||% 1)
env$OPENBLAS_NUM_THREADS <- env$OMP_NUM_THREADS
env$MKL_NUM_THREADS      <- env$OMP_NUM_THREADS
env$EXDQLM_OUT_DIR       <- normalizePath(run_dir)
env$EXDQLM_SAVE_OUTPUTS  <- if (isTRUE(cfg$outputs$save)) "1" else "0"
env$EXDQLM_CFG_JSON <- jsonlite::toJSON(
  cfg, auto_unbox = TRUE, null = "null", na = "null", digits = NA
)
env$EXDQLM_PIPELINE_MODE <- mode_eff
if (mode_eff %in% c("sim","simulation")) {
  env$EXDQLM_FILE_LONG <- normalizePath(input_path)
} else {
  env$EXDQLM_FILE_OBS  <- normalizePath(input_path)
}

# Logging to file
log_file <- fs::path(run_dir, "logs", "main.log")
open_out <- sink.number(); open_msg <- sink.number(type = "message")
sink(log_file, split = TRUE)
msg_con <- file(log_file, open = "at")
sink(msg_con, type = "message")
on.exit({ try(sink(type = "message"), silent = TRUE); try(close(msg_con), silent = TRUE) }, add = TRUE)

sink_stop <- function() {
  while (sink.number() > open_out) sink(NULL)
  while (sink.number(type="message") > open_msg) sink(NULL, type="message")
}

status <- 0L; err_msg <- NULL
cat(sprintf("== EXDQLM run started at %s ==\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("Repo root: ", repo_root, "\n")
cat("Run dir:   ", run_dir, "\n")
cat("Spec:      ", spec_name, "\n")
cat("Dataset:   ", slug, " (", input_path, ")  mode=", mode_eff, "\n", sep = "")
cat("Threads:   ", env$OMP_NUM_THREADS, "\n\n", sep = "")
cat("Out dir:   ", env$EXDQLM_OUT_DIR, "\n", sep = "")
cat("Saving:    ", if (!is.null(env$EXDQLM_SAVE_OUTPUTS) && nzchar(env$EXDQLM_SAVE_OUTPUTS) && env$EXDQLM_SAVE_OUTPUTS=="1") "TRUE" else "FALSE", "\n\n", sep = "")

start_time <- Sys.time()
tryCatch({
  withr::with_envvar(env, {
    if (mode_eff %in% c("real","observed","data")) {
      source("scripts/pipeline_real_main.R", local = new.env(parent = globalenv()))
    } else {
      source("scripts/pipeline_main.R",     local = new.env(parent = globalenv()))
    }
  })
}, error = function(e) {
  err_msg <<- conditionMessage(e)
  cat("ERROR in pipeline_main.R:\n", err_msg, "\n")
  status <<- 1L
})
end_time <- Sys.time()
cat(sprintf("\n== EXDQLM run finished at %s (elapsed: %0.2f mins) ==\n",
            format(end_time, "%Y-%m-%d %H:%M:%S"),
            as.numeric(difftime(end_time, start_time, units="mins"))))

# Close sinks before file moves
sink_stop()

# Sort artifacts
safe_move <- function(files, dest_dir) {
  if (!length(files)) return(invisible())
  fs::dir_create(dest_dir)
  for (f in files) {
    tgt <- fs::path(dest_dir, fs::path_file(f))
    if (fs::file_exists(tgt)) {
      base <- tools::file_path_sans_ext(fs::path_file(f))
      ext  <- tools::file_ext(f)
      k <- 1L
      repeat {
        cand <- fs::path(dest_dir, sprintf("%s__%02d.%s", base, k, ext))
        if (!fs::file_exists(cand)) { tgt <- cand; break }
        k <- k + 1L
      }
    }
    fs::file_move(f, tgt)
  }
}

if (status == 0L) {
  all_files <- fs::dir_ls(run_dir, recurse = FALSE, type = "file")
  to_figs   <- all_files[grepl("\\.(png|pdf|jpg)$", all_files, ignore.case = TRUE)]
  to_tbls   <- all_files[grepl("\\.(csv|tsv)$",    all_files, ignore.case = TRUE)]
  to_models <- all_files[grepl("\\.(rds|rda)$",    all_files, ignore.case = TRUE)]
  safe_move(to_figs,   fs::path(run_dir, "figs"))
  safe_move(to_tbls,   fs::path(run_dir, "tables"))
  safe_move(to_models, fs::path(run_dir, "models"))
}

# Update manifest & symlink "latest"
writeLines(if (status==0L) "SUCCESS" else "FAIL", fs::path(run_dir,"manifest","status.txt"))
latest_link <- fs::path(results_root, suite_name, slug, "latest")
if (fs::file_exists(latest_link) || fs::link_exists(latest_link)) {
  try(fs::file_delete(latest_link), silent = TRUE)
}
try(fs::link_create(run_dir, latest_link), silent = TRUE)

# Save session info
sess <- utils::capture.output(sessionInfo())
writeLines(sess, fs::path(run_dir, "manifest", "session_info.txt"))

if (status != 0L && !is.null(err_msg)) writeLines(err_msg, fs::path(run_dir, "logs", "error.txt"))

cat("Run dir: ", run_dir, "\n")
quit(save="no", status = status)
