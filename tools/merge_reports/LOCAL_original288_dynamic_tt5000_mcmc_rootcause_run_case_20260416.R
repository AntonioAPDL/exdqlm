#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

safe_int <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v)) as.integer(default) else v
}

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v)) as.numeric(default) else v
}

safe_chr <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x) || !length(x) || all(is.na(x))) return(isTRUE(default))
  if (is.logical(x)) return(isTRUE(x[1]))
  val <- tolower(as.character(x)[1])
  if (val %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (val %in% c("false", "f", "0", "no", "n")) return(FALSE)
  isTRUE(default)
}

resolve_fit <- function(obj) obj$fit %||% obj

compact_fit <- function(fit, inference) {
  out <- fit
  if (identical(inference, "mcmc")) {
    if (!is.null(out$mh.diagnostics$trace)) out$mh.diagnostics$trace <- NULL
  }
  out
}

append_progress <- function(path, info) {
  row <- data.frame(
    event = safe_chr(info$event, "progress"),
    iter = safe_int(info$iter, NA_integer_),
    total_iter = safe_int(info$total_iter, NA_integer_),
    phase = safe_chr(info$phase, NA_character_),
    sigma = safe_num(info$sigma, NA_real_),
    gamma = safe_num(info$gamma, NA_real_),
    kernel = safe_chr(info$kernel, NA_character_),
    accept = safe_num(info$accept, NA_real_),
    runtime_sec = safe_num(info$runtime_sec, NA_real_),
    stringsAsFactors = FALSE
  )
  utils::write.table(
    row,
    file = path,
    sep = ",",
    row.names = FALSE,
    col.names = !file.exists(path),
    append = file.exists(path)
  )
}

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
setwd(repo_root)
validation_repo <- normalizePath(
  "/home/jaguir26/local/src/exdqlm__wt__validation_rerun_after_0p4p0_integration",
  winslash = "/",
  mustWork = TRUE
)
args <- parse_args(commandArgs(trailingOnly = TRUE))

manifest_path <- normalizePath(
  safe_chr(args$manifest, file.path(repo_root, "tools/merge_reports/LOCAL_original288_dynamic_tt5000_mcmc_rootcause_manifest_20260416.csv")),
  winslash = "/",
  mustWork = TRUE
)
row_id <- safe_int(args$row_id, NA_integer_)
force <- as_flag(args$force, FALSE)
if (!is.finite(row_id)) stop("row_id is required")

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf("row_id %d not found in manifest", row_id))
row <- row[1, , drop = FALSE]

for (p in c(dirname(row$fit_output_path), dirname(row$row_status_path), dirname(row$debug_dump_dir), dirname(row$progress_csv))) {
  dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

if (file.exists(row$row_status_path) && !force) {
  quit(save = "no", status = 0)
}

if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required")
pkgload::load_all(repo_root, quiet = TRUE)

resolve_existing_path <- function(path) {
  path <- safe_chr(path, NA_character_)
  if (is.na(path) || !nzchar(path)) return(NA_character_)
  if (file.exists(path)) return(normalizePath(path, winslash = "/", mustWork = TRUE))
  rel_validation <- file.path(validation_repo, path)
  if (file.exists(rel_validation)) {
    return(normalizePath(rel_validation, winslash = "/", mustWork = TRUE))
  }
  rel_repo <- file.path(repo_root, path)
  if (file.exists(rel_repo)) return(normalizePath(rel_repo, winslash = "/", mustWork = TRUE))
  NA_character_
}

load_config_chain <- function(path) {
  cfg_path <- resolve_existing_path(path)
  if (is.na(cfg_path)) stop("No readable source run_config_path available for debug row")
  primary <- readRDS(cfg_path)
  secondary_path <- resolve_existing_path(primary$source_run_config_path %||% NA_character_)
  secondary <- if (!is.na(secondary_path)) readRDS(secondary_path) else NULL
  list(
    cfg_path = cfg_path,
    primary = primary,
    secondary_path = secondary_path,
    secondary = secondary
  )
}

config_chain <- load_config_chain(row$source_run_config_path)
cfg <- config_chain$primary
sim_obj <- readRDS(row$sim_output_path)

make_synthetic_baseline <- function(reference_fit_path = NA_character_) {
  sibling_path <- sub("_run_config\\.rds$", "_synthetic_baseline.rds", config_chain$cfg_path)
  if (!identical(sibling_path, config_chain$cfg_path) && file.exists(sibling_path)) {
    return(normalizePath(sibling_path, winslash = "/", mustWork = TRUE))
  }
  out_path <- file.path(dirname(row$row_status_path), sprintf("synthetic_baseline_%03d.rds", row$row_id))
  synth_row <- list(
    selected_fit_path = reference_fit_path,
    family = row$family,
    tau = row$tau_label,
    tau_label = row$tau_label,
    fit_size = row$fit_size,
    model = row$model,
    original_case_key = row$original_case_key
  )
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(validation_repo)
  source("tools/merge_reports/LOCAL_original288_normalized_multiseed_helpers_20260411.R")
  build_dynamic_synthetic_baseline_original288_normalized_multiseed(synth_row, out_path)
  out_path
}

baseline_candidates <- unique(na.omit(c(
  resolve_existing_path(row$source_reference_fit_path),
  resolve_existing_path(row$baseline_fit_path),
  resolve_existing_path(config_chain$secondary$fit_path %||% NA_character_),
  resolve_existing_path(cfg$fit_path %||% NA_character_)
)))
baseline_path <- if (length(baseline_candidates)) baseline_candidates[1] else NA_character_
baseline_mode <- if (length(baseline_candidates)) "reference_fit" else "synthetic_baseline"
if (is.na(baseline_path) || !nzchar(baseline_path)) {
  baseline_path <- make_synthetic_baseline(NA_character_)
}
bf <- resolve_fit(readRDS(baseline_path))

set.seed(safe_int(row$fit_seed, 123L))
Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  EXDQLM_MCMC_PROGRESS_EVERY = "1",
  EXDQLM_DEBUG_DIR = row$debug_dump_dir,
  EXDQLM_DEBUG_CASE = row$debug_case_key,
  EXDQLM_DEBUG_LABEL = row$variant
)

status <- "pending"
error_msg <- NA_character_
runtime_sec <- NA_real_
gate_overall <- "FAIL"
healthy <- FALSE
fit_obj <- NULL
time_limit_sec <- if (identical(row$inference, "mcmc")) 600 else 300
setTimeLimit(elapsed = time_limit_sec, transient = TRUE)
on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)

tryCatch({
  if (identical(row$inference, "vb")) {
    vb_cfg <- cfg$vb %||% list()
    old_opt <- options(list(
      exdqlm.max_iter = 40L,
      exdqlm.tol_sigma = safe_num(vb_cfg$tol_sigma %||% vb_cfg$tol %||% 0.03, 0.03),
      exdqlm.tol_gamma = safe_num(vb_cfg$tol_gamma %||% vb_cfg$tol %||% 0.03, 0.03),
      exdqlm.tol_elbo = safe_num(vb_cfg$tol_elbo %||% 1e-6, 1e-6),
      exdqlm.vb.min_iter = safe_int(vb_cfg$min_iter %||% 10L, 10L),
      exdqlm.vb.patience = safe_int(vb_cfg$patience %||% 3L, 3L),
      exdqlm.vb.allow_elbo_drop = safe_num(vb_cfg$allow_elbo_drop %||% 1e-5, 1e-5)
    ))
    on.exit(options(old_opt), add = TRUE)
    rt <- system.time({
      fit_obj <- exdqlmLDVB(
        y = as.numeric(sim_obj$y),
        p0 = bf$p0,
        model = bf$model,
        df = bf$df,
        dim.df = bf$dim.df,
        fix.sigma = FALSE,
        sig.init = safe_num(bf$sig.init %||% NA_real_, NA_real_),
        dqlm.ind = identical(row$model, "dqlm"),
        tol = safe_num(vb_cfg$tol %||% 0.03, 0.03),
        n.samp = 300L,
        verbose = FALSE
      )
    })
    runtime_sec <- as.numeric(rt[["elapsed"]])
    converged <- isTRUE(fit_obj$diagnostics$convergence$converged %||% fit_obj$converged)
    gate_overall <- if (converged) "PASS" else "WARN"
    healthy <- TRUE
    status <- "done"
  } else {
    vb_cfg <- cfg$vb %||% list()
    mc_cfg <- cfg$mcmc %||% list()
    mh <- mc_cfg$mh %||% list()
    accepted_mh <- bf$mh.diagnostics %||% list()

    vb_obj <- NULL
    if (!identical(row$variant, "no_vb_init_short")) {
      vb_ref_path <- resolve_existing_path(row$vb_reference_fit_path)
      if (!is.na(vb_ref_path) && nzchar(vb_ref_path) && file.exists(vb_ref_path)) {
        vb_obj <- resolve_fit(readRDS(vb_ref_path))
      }
    }

    if (identical(row$variant, "regfloor_short")) {
      old_reg <- options(list(
        exdqlm.dynamic.cov_eig_floor = 1e-8,
        exdqlm.dynamic.q_floor = 1e-8
      ))
      on.exit(options(old_reg), add = TRUE)
    }

    source_has_init_from_vb <- "init_from_vb" %in% names(mc_cfg) && !all(is.na(mc_cfg[["init_from_vb"]]))
    source_has_init_from_isvb <- "init_from_isvb" %in% names(mc_cfg) && !all(is.na(mc_cfg[["init_from_isvb"]]))
    legacy_isvb_default <- !source_has_init_from_vb && !source_has_init_from_isvb
    default_isvb <- legacy_isvb_default || identical(tolower(safe_chr(bf$vb.init.method, "")), "isvb")

    call_args <- list(
      y = as.numeric(sim_obj$y),
      p0 = bf$p0,
      model = bf$model,
      df = bf$df,
      dim.df = bf$dim.df,
      dqlm.ind = identical(row$model, "dqlm"),
      n.burn = 2L,
      n.mcmc = 1L,
      init.from.isvb = as_flag(if (source_has_init_from_isvb) mc_cfg[["init_from_isvb"]] else default_isvb, default_isvb),
      joint.sample = as_flag(mh$joint_sample %||% mh$primary_joint_sample %||% accepted_mh$joint_sample, FALSE),
      mh.proposal = safe_chr(mh$proposal %||% mh$primary_proposal %||% accepted_mh$proposal %||% "laplace_rw", "laplace_rw"),
      mh.adapt.interval = safe_int(mh$adapt_interval %||% accepted_mh$adapt_interval %||% 50L, 50L),
      mh.target.accept = as.numeric(mh$target_accept %||% accepted_mh$target_accept %||% c(0.20, 0.45)),
      mh.scale.bounds = as.numeric(mh$scale_bounds %||% accepted_mh$scale_bounds %||% c(0.1, 10)),
      mh.max_scale.step = safe_num(mh$max_scale_step %||% accepted_mh$max_scale_step %||% 0.35, 0.35),
      mh.min_burn_adapt = safe_int(mh$min_burn_adapt %||% accepted_mh$min_burn_adapt %||% 50L, 50L),
      trace.diagnostics = TRUE,
      trace.every = 1L,
      verbose = FALSE,
      progress_callback = function(info) append_progress(row$progress_csv, info)
    )

    if (source_has_init_from_vb) {
      call_args$init.from.vb <- as_flag(mc_cfg[["init_from_vb"]], !is.null(vb_obj))
    }
    if (identical(row$variant, "no_vb_init_short")) {
      call_args$init.from.vb <- FALSE
      call_args$init.from.isvb <- FALSE
      call_args$vb_init_fit <- NULL
    } else if (!is.null(vb_obj) && isTRUE(call_args$init.from.vb)) {
      call_args$vb_init_fit <- vb_obj
    }

    call_args$vb_init_controls <- list(
      tol = safe_num(vb_cfg$tol %||% 0.03, 0.03),
      n.IS = safe_int(vb_cfg$n_IS %||% vb_cfg$n_is %||% 200L, 200L),
      n.samp = 300L,
      max_iter = 40L,
      verbose = FALSE
    )

    if ("adapt" %in% names(mh) && !all(is.na(mh[["adapt"]]))) {
      call_args$mh.adapt <- as_flag(mh[["adapt"]], TRUE)
    } else if (!is.null(accepted_mh$adapt) && length(accepted_mh$adapt) && !all(is.na(accepted_mh$adapt))) {
      call_args$mh.adapt <- as_flag(accepted_mh$adapt, TRUE)
    }

    slice_width <- safe_num(mh$slice_width %||% accepted_mh$slice_width, NA_real_)
    slice_max_steps <- safe_int(mh$slice_max_steps %||% accepted_mh$slice_max_steps, NA_integer_)
    if (is.finite(slice_width)) call_args$slice.width <- slice_width
    if (is.finite(slice_max_steps)) call_args$slice.max.steps <- slice_max_steps

    rt <- system.time({
      fit_obj <- do.call(exdqlmMCMC, call_args)
    })
    runtime_sec <- as.numeric(rt[["elapsed"]])
    gate_overall <- "WARN"
    healthy <- TRUE
    status <- "done"
  }
}, error = function(e) {
  status <<- "failed_runtime"
  error_msg <<- conditionMessage(e)
})

if (!is.null(fit_obj) && identical(status, "done")) {
  saveRDS(compact_fit(fit_obj, row$inference), row$fit_output_path)
}

row_out <- data.frame(
  row_id = row$row_id,
  base_row_id = row$base_row_id,
  original_case_key = row$original_case_key,
  family = row$family,
  tau_label = row$tau_label,
  model = row$model,
  inference = row$inference,
  variant = row$variant,
  source_phase1_row_id = row$source_phase1_row_id,
  status = status,
  error = error_msg,
  gate_overall = gate_overall,
  healthy = healthy,
  runtime_sec = runtime_sec,
  baseline_mode = baseline_mode,
  baseline_path = baseline_path,
  source_cfg_path = config_chain$cfg_path,
  upstream_source_cfg_path = config_chain$secondary_path %||% NA_character_,
  fit_output_path = row$fit_output_path,
  debug_dump_dir = row$debug_dump_dir,
  progress_csv = row$progress_csv,
  stringsAsFactors = FALSE
)

utils::write.csv(row_out, row$row_status_path, row.names = FALSE)
