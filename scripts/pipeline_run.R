#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  req <- c("yaml","jsonlite","digest","fs","tools","withr")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org")
  invisible(lapply(req, require, character.only=TRUE))
})

`%||%` <- function(a, b) if (!is.null(a)) a else b

# Fallback helper to avoid missing-function errors in downstream scripts.
if (!exists("quantile_by_time", envir = globalenv(), inherits = FALSE)) {
  assign(
    "quantile_by_time",
    function(yrep, tau, target_len) {
      yrep <- as.matrix(yrep)
      if (nrow(yrep) == target_len) {
        return(drop(matrixStats::rowQuantiles(yrep, probs = tau, na.rm = TRUE)))
      } else if (ncol(yrep) == target_len) {
        return(drop(matrixStats::colQuantiles(yrep, probs = tau, na.rm = TRUE)))
      } else {
        stop(sprintf("yrep dim %dx%d doesn't match target_len=%d",
                     nrow(yrep), ncol(yrep), target_len))
      }
    },
    envir = globalenv()
  )
}

if (!exists("lead_weights_from_power", envir = globalenv(), inherits = FALSE)) {
  assign(
    "lead_weights_from_power",
    function(H, power) {
      power <- as.numeric(power)[1L]
      if (!is.finite(power) || power < 0) {
        stop("forecast.lead_weight_power must be a finite number >= 0.")
      }
      r <- seq_len(as.integer(H))
      log_w <- -power * log(r)
      log_w <- log_w - max(log_w)
      exp(log_w)
    },
    envir = globalenv()
  )
}

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
defaults   <- yaml::read_yaml("config/defaults.yaml")
datasets_y <- if (file.exists("config/datasets.yaml")) yaml::read_yaml("config/datasets.yaml") else list(datasets=list())
datasets   <- datasets_y$datasets

# find dataset entry
ds <- NULL
for (d in datasets) if (identical(d$slug, slug)) { ds <- d; break }
if (is.null(ds)) stop("Dataset slug not found: ", slug)

mode_ds <- tolower(ds$mode %||% "")

input_path <- ds$input_path
if (!file.exists(input_path)) stop("Input file not found: ", input_path)

deep_merge <- function(a,b){
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)
  if (is.list(a) && is.list(b)) {
    na <- names(a)
    nb <- names(b)
    has_names_a <- !is.null(na) && any(nzchar(na))
    has_names_b <- !is.null(nb) && any(nzchar(nb))

    # Unnamed lists behave like vectors in YAML parsing; replacing is safer
    # than recursive merge-by-name (which can silently drop entries).
    if (!has_names_a && !has_names_b) return(b)
    if (xor(has_names_a, has_names_b)) return(b)

    keys <- unique(c(na, nb))
    out  <- lapply(keys, function(k) deep_merge(a[[k]], b[[k]]))
    names(out) <- keys
    out
  } else b
}

resolve_spec_path <- function(spec_name) {
  if (is.null(spec_name) || !nzchar(spec_name)) return(NULL)
  s <- trimws(as.character(spec_name))
  if (!nzchar(s)) return(NULL)
  cand <- unique(c(
    s,
    file.path("config", "specs", s),
    file.path("config", "specs", paste0(s, ".yaml")),
    file.path("config", "specs", paste0(s, ".yml"))
  ))
  for (p in cand) if (file.exists(p)) return(p)
  NULL
}

cfg <- defaults
mode_key <- tolower(mode_ds %||% cfg$pipeline$mode %||% "")
if (nzchar(mode_key) && !is.null(cfg$mode_overrides) && !is.null(cfg$mode_overrides[[mode_key]])) {
  cfg <- deep_merge(cfg, cfg$mode_overrides[[mode_key]])
}

ds_cfg <- ds
ds_cfg$slug <- NULL
ds_cfg$input_path <- NULL
ds_cfg$mode <- NULL
cfg <- deep_merge(cfg, ds_cfg)

spec_path <- resolve_spec_path(spec_name)
if (!is.null(spec_path)) {
  spec_cfg <- yaml::read_yaml(spec_path)
  if (is.null(spec_cfg)) spec_cfg <- list()
  if (!is.list(spec_cfg)) stop("Spec YAML must be a mapping/list: ", spec_path)
  cfg <- deep_merge(cfg, spec_cfg)
  message("[pipeline_run] loaded spec overrides: ", spec_path)
} else {
  message(
    "[pipeline_run] spec '", spec_name,
    "' has no YAML in config/specs; using defaults + dataset overrides only."
  )
}

fix_bool_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  nm <- names(x)
  if (!is.null(nm) && "TRUE" %in% nm)  {
    if (is.null(x[["y"]])) x[["y"]] <- x[["TRUE"]]
    x[["TRUE"]] <- NULL
  }
  if (!is.null(nm) && "FALSE" %in% nm) {
    if (is.null(x[["n"]])) x[["n"]] <- x[["FALSE"]]
    x[["FALSE"]] <- NULL
  }
  x
}

fix_desn_keys <- function(d) {
  if (is.null(d) || !is.list(d)) return(d)
  nm <- names(d)
  if (!is.null(nm) && "FALSE" %in% nm) {
    if (is.null(d[["n"]])) d[["n"]] <- d[["FALSE"]]
    d[["FALSE"]] <- NULL
  }
  d
}

fix_cfg_keys <- function(x) {
  if (is.null(x) || !is.list(x)) return(x)
  if (!is.null(x[["desn"]]))    x[["desn"]]    <- fix_desn_keys(x[["desn"]])
  if (!is.null(x[["columns"]])) x[["columns"]] <- fix_bool_keys(x[["columns"]])
  x
}

cfg <- fix_cfg_keys(cfg)

if (!is.null(ds_cfg[["columns"]])) {
  ds_cfg[["columns"]] <- fix_bool_keys(ds_cfg[["columns"]])
  cfg[["columns"]] <- deep_merge(cfg[["columns"]], ds_cfg[["columns"]])
}

norm_num <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  x <- as.numeric(x)
  if (length(x) == 0L || all(is.na(x))) return(NULL)
  x
}

norm_int <- function(x) {
  x <- norm_num(x)
  if (is.null(x)) return(NULL)
  as.integer(x)
}

if (!is.null(cfg[["desn"]])) {
  d <- cfg[["desn"]]
  Dcfg <- as.integer((d[["D"]] %||% 1L))

  n_vec       <- norm_int(d[["n"]])
  n_tilde_vec <- norm_int(d[["n_tilde"]])
  rho_vec     <- norm_num(d[["rho"]])

  if (is.null(n_vec)) stop("Config error: desn$n is missing.")

  if (Dcfg > 1L && length(n_vec) == 1L) n_vec <- rep(n_vec, Dcfg)
  if (!is.null(rho_vec) && Dcfg > 1L && length(rho_vec) == 1L) rho_vec <- rep(rho_vec, Dcfg)

  if (length(n_vec) != Dcfg) {
    stop(sprintf("Config error: length(desn$n)=%d but desn$D=%d", length(n_vec), Dcfg))
  }

  if (Dcfg <= 1L) {
    n_tilde_vec <- integer(0)
  } else {
    if (is.null(n_tilde_vec)) {
      stop(sprintf("Config error: desn$n_tilde is required when desn$D=%d", Dcfg))
    }
    if (length(n_tilde_vec) == 1L) n_tilde_vec <- rep(n_tilde_vec, Dcfg - 1L)
    if (length(n_tilde_vec) != (Dcfg - 1L)) {
      stop(sprintf("Config error: length(desn$n_tilde)=%d but expected D-1=%d",
                   length(n_tilde_vec), Dcfg - 1L))
    }
  }

  cfg[["desn"]][["D"]]       <- Dcfg
  cfg[["desn"]][["n"]]       <- n_vec
  cfg[["desn"]][["n_tilde"]] <- n_tilde_vec
  if (!is.null(rho_vec)) cfg[["desn"]][["rho"]] <- rho_vec
}

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

# ---- Normalize DESN numeric fields (treat length-0 as NULL; broadcast scalars) ----
norm_act <- function(x, nm) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0L) .stopf("%s must be a non-empty character scalar.", nm)
  u <- unique(tolower(x))
  if (length(u) != 1L) .stopf("%s must be scalar (or repeated identical). Got: %s", nm, paste(x, collapse = ", "))
  x[1L]
}

cfg$desn$act_f <- norm_act(cfg$desn$act_f, "desn$act_f")
cfg$desn$act_k <- norm_act(cfg$desn$act_k, "desn$act_k")

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

# Mode-aware schema check (prefer merged cfg$columns)
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
  # Prefer merged cfg (defaults → mode_overrides → dataset), then default
  cols_cfg <- cfg$columns %||% list()

  hdr_nms <- names(hdr)
  y_map    <- cols_cfg$y %||% (if ("y" %in% hdr_nms) "y" else hdr_nms[1])
  date_map <- cols_cfg$date %||% NULL

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
  suite      = suite_name, spec = spec_name, spec_file = spec_path %||% NA_character_, cfg_hash = cfg_hash,
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
cat("Spec file: ", spec_path %||% "none", "\n")
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
elapsed_seconds <- as.numeric(difftime(end_time, start_time, units = "secs"))
cat(sprintf("\n== EXDQLM run finished at %s (elapsed: %0.2f mins) ==\n",
            format(end_time, "%Y-%m-%d %H:%M:%S"),
            as.numeric(difftime(end_time, start_time, units="mins"))))

# Close sinks before file moves
sink_stop()

runtime_summary <- list(
  started_at = as.character(start_time),
  finished_at = as.character(end_time),
  elapsed_seconds = elapsed_seconds,
  elapsed_minutes = elapsed_seconds / 60,
  status = if (status == 0L) "SUCCESS" else "FAIL",
  dataset_slug = slug,
  spec = spec_name,
  mode = mode_eff
)
jsonlite::write_json(
  runtime_summary,
  fs::path(run_dir, "manifest", "runtime_summary.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
utils::write.csv(
  data.frame(
    started_at = runtime_summary$started_at,
    finished_at = runtime_summary$finished_at,
    elapsed_seconds = runtime_summary$elapsed_seconds,
    elapsed_minutes = runtime_summary$elapsed_minutes,
    status = runtime_summary$status,
    dataset_slug = runtime_summary$dataset_slug,
    spec = runtime_summary$spec,
    mode = runtime_summary$mode,
    stringsAsFactors = FALSE
  ),
  fs::path(run_dir, "manifest", "runtime_summary.csv"),
  row.names = FALSE
)

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
