#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

is_missing_scalar <- function(x) {
  if (is.null(x) || !length(x)) return(TRUE)
  if (all(is.na(x))) return(TRUE)
  y <- as.character(x)[1]
  !nzchar(trimws(y)) || identical(toupper(trimws(y)), "NA")
}

first_present <- function(..., default = NULL) {
  vals <- list(...)
  for (v in vals) {
    if (!is_missing_scalar(v)) return(v)
  }
  default
}

parse_args <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl('^--[^=]+=.*$', x)) {
      key <- sub('^--([^=]+)=.*$', '\\1', x)
      val <- sub('^--[^=]+=(.*)$', '\\1', x)
      out[[key]] <- val
    } else if (grepl('^--', x)) {
      key <- sub('^--', '', x)
      out[[key]] <- 'TRUE'
    }
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  tolower(as.character(x)[1]) %in% c('1', 'true', 'yes', 'y', 't')
}

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_int <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_chr <- function(x, default = NA_character_) {
  if (is_missing_scalar(x)) return(default)
  y <- as.character(x)[1]
  if (!nzchar(trimws(y)) || identical(toupper(trimws(y)), "NA")) default else y
}

safe_num_vec <- function(x, default) {
  v <- suppressWarnings(as.numeric(x))
  if (!length(v) || any(!is.finite(v))) return(as.numeric(default))
  v
}

ensure_dir <- function(path) dir.create(path, recursive = TRUE, showWarnings = FALSE)

resolve_fit <- function(obj) obj$fit %||% obj

collect_vb_health <- function(wrapped, case_id, variant, candidate_path, vhg_extract_rhs_collapse) {
  fit <- resolve_fit(wrapped)
  conv <- fit$diagnostics$convergence$converged %||% fit$converged %||% NA
  stop_reason <- as.character(fit$diagnostics$convergence$stop_reason %||% NA_character_)
  rhs <- vhg_extract_rhs_collapse(fit)

  finite_ok <- TRUE
  if (!is.null(fit$diagnostics$deltas)) {
    d <- unlist(fit$diagnostics$deltas, use.names = FALSE)
    d <- d[is.finite(d)]
    finite_ok <- length(d) > 0L
  }

  gate_overall <- if (isTRUE(rhs$collapse_flag)) {
    'FAIL'
  } else if (isTRUE(conv)) {
    'PASS'
  } else if (isTRUE(finite_ok)) {
    'WARN'
  } else {
    'FAIL'
  }

  data.frame(
    case_id = case_id,
    variant = variant,
    gate_overall = gate_overall,
    healthy = gate_overall %in% c('PASS', 'WARN') && !isTRUE(rhs$collapse_flag),
    unhealthy_reason = if (isTRUE(rhs$collapse_flag)) 'rhs_collapse' else if (gate_overall == 'FAIL') 'vb_fail' else NA_character_,
    rhs_collapse_flag = isTRUE(rhs$collapse_flag),
    rhs_collapse_sources = rhs$collapse_sources,
    vb_converged = isTRUE(conv),
    vb_stop_reason = stop_reason,
    run_time_sec = safe_num(wrapped$meta$runtime_sec %||% fit$run.time, NA_real_),
    candidate_path = candidate_path,
    stringsAsFactors = FALSE
  )
}

set_dynamic_ld_options <- function(ld_list) {
  if (!is.list(ld_list) || !length(ld_list)) return(list())
  named <- ld_list
  names(named) <- paste0('exdqlm.dynamic.ldvb.', names(ld_list))
  old <- options(named)
  old
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
repo_root <- normalizePath('.', winslash = '/', mustWork = TRUE)
out_dir <- file.path(repo_root, 'tools', 'merge_reports')
verbose_mcmc <- as_flag(args[['verbose-mcmc']] %||% args$verbose_mcmc, FALSE)
progress_every <- safe_int(
  args[['progress-every']] %||% args$progress_every %||% Sys.getenv('EXDQLM_MCMC_PROGRESS_EVERY', NA_character_),
  NA_integer_
)
if (!is.finite(progress_every) || progress_every < 1L) progress_every <- 200L
rprof_path <- safe_chr(args[['rprof-path']] %||% args$rprof_path, '')
rprof_interval <- safe_num(args[['rprof-interval']] %||% args$rprof_interval, 0.01)
if (!is.finite(rprof_interval) || rprof_interval <= 0) rprof_interval <- 0.01

with_optional_rprof <- function(expr) {
  if (!nzchar(rprof_path)) {
    return(eval.parent(substitute(expr)))
  }
  ensure_dir(dirname(rprof_path))
  utils::flush.console()
  Rprof(rprof_path, interval = rprof_interval, line.profiling = TRUE)
  on.exit(Rprof(NULL), add = TRUE)
  eval.parent(substitute(expr))
}

manifest_path <- as.character(args$manifest %||% stop('manifest is required'))
if (!file.exists(manifest_path)) stop(sprintf('manifest not found: %s', manifest_path))
row_id <- safe_int(args$row_id %||% NA, NA_integer_)
if (!is.finite(row_id)) stop('row_id is required and must be integer')
tag <- as.character(args$tag %||% stop('tag is required'))
force <- as_flag(args$force, FALSE)

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
if (!('row_id' %in% names(manifest))) stop('manifest must include row_id')
row <- manifest[manifest$row_id == row_id, , drop = FALSE]
if (!nrow(row)) stop(sprintf('row_id %d not found in manifest', row_id))
if (nrow(row) > 1) stop(sprintf('row_id %d appears multiple times in manifest', row_id))

telemetry_path <- safe_chr(args[['telemetry-path']] %||% args$telemetry_path, '')
has_telemetry <- nzchar(telemetry_path)
if (has_telemetry) {
  ensure_dir(dirname(telemetry_path))
  if (!file.exists(telemetry_path)) {
    utils::write.table(
      data.frame(
        ts = character(0),
        row_id = integer(0),
        phase = character(0),
        iter = integer(0),
        marker = character(0),
        stringsAsFactors = FALSE
      ),
      telemetry_path,
      sep = ',',
      row.names = FALSE,
      col.names = TRUE,
      quote = TRUE
    )
  }
}

append_telemetry <- function(phase, iter = NA_integer_, marker = NA_character_) {
  if (!has_telemetry) return(invisible(NULL))
  row_tele <- data.frame(
    ts = as.character(Sys.time()),
    row_id = as.integer(row_id),
    phase = safe_chr(phase, 'unknown'),
    iter = safe_int(iter, NA_integer_),
    marker = safe_chr(marker, NA_character_),
    stringsAsFactors = FALSE
  )
  utils::write.table(
    row_tele,
    telemetry_path,
    sep = ',',
    row.names = FALSE,
    col.names = FALSE,
    quote = TRUE,
    append = TRUE
  )
  invisible(NULL)
}

progress_telemetry_callback <- function(info) {
  info <- info %||% list()
  event <- tolower(safe_chr(info$event, ''))
  phase_raw <- tolower(safe_chr(info$phase, ''))
  phase <- if (phase_raw %in% c('burn', 'burnin')) {
    'burnin'
  } else if (phase_raw %in% c('keep', 'mcmc')) {
    'mcmc'
  } else if (phase_raw %in% c('done', 'complete', 'finalize')) {
    'finalize'
  } else if (phase_raw %in% c('init', 'start')) {
    'init'
  } else if (event %in% c('start')) {
    'burnin'
  } else if (event %in% c('progress')) {
    'mcmc'
  } else if (event %in% c('complete')) {
    'finalize'
  } else {
    if (nzchar(phase_raw)) phase_raw else 'unknown'
  }
  marker <- safe_chr(info$kernel %||% info$proposal %||% info$method %||% event, NA_character_)
  append_telemetry(phase = phase, iter = safe_int(info$iter, NA_integer_), marker = marker)
}

run_dir <- file.path(out_dir, sprintf('full288_%s', tag))
rows_dir <- file.path(run_dir, 'rows')
health_dir <- file.path(run_dir, 'health')
ensure_dir(rows_dir); ensure_dir(health_dir)

row_out_path <- file.path(rows_dir, sprintf('row_%04d.csv', row_id))
health_out_path <- file.path(health_dir, sprintf('health_%04d.csv', row_id))

start_ts <- as.character(Sys.time())
status <- 'pending'
error_msg <- NA_character_

append_telemetry('init', iter = 0L, marker = 'runner_start')

if (isTRUE(row$missing_inputs)) {
  status <- 'input_missing'
  error_msg <- 'missing_inputs flag is TRUE in manifest'
  out <- data.frame(
    row_id = row_id,
    ts_start = start_ts,
    ts_end = as.character(Sys.time()),
    status = status,
    error = error_msg,
    gate_overall = 'FAIL',
    healthy = FALSE,
    rhs_collapse_flag = NA,
    runtime_sec = NA_real_,
    inference = row$inference,
    model = row$model,
    root_kind = row$root_kind,
    family = row$family,
    tau_label = row$tau_label,
    baseline_fit_path = row$baseline_fit_path,
    candidate_fit_path = row$candidate_fit_path,
    health_csv = health_out_path,
    stringsAsFactors = FALSE
  )
  utils::write.csv(out, row_out_path, row.names = FALSE)
  quit(save = 'no', status = 0)
}

if (!requireNamespace('pkgload', quietly = TRUE)) stop('pkgload is required')
if (!requireNamespace('coda', quietly = TRUE)) stop('coda is required')

source(file.path(out_dir, 'LOCAL_validation_health_gate_common_20260321.R'))
pkgload::load_all(repo_root, quiet = TRUE)

inference <- as.character(row$inference)
model <- as.character(row$model)
root_kind <- as.character(row$root_kind)
seed_override <- safe_int(args[['seed-override']] %||% args$seed_override, NA_integer_)

cfg <- readRDS(row$run_config_path)
sim <- readRDS(row$sim_output_path)
baseline <- readRDS(row$baseline_fit_path)
bf <- resolve_fit(baseline)
baseline_seed <- safe_int(baseline$meta$seed %||% baseline$seed %||% bf$seed, 2026032701L)
seed <- if (is.finite(seed_override)) {
  seed_override
} else {
  safe_int(row$seed, baseline_seed)
}

candidate_path <- as.character(row$candidate_fit_path)
ensure_dir(dirname(candidate_path))

case_id <- paste(row$run_root, model, inference, sep = '::')

run_and_wrap <- function() {
  if (identical(inference, 'vb')) {
    if (identical(root_kind, 'dynamic')) {
      vb_cfg <- cfg$vb %||% list()
      opt_list <- list(
        exdqlm.max_iter = safe_int(vb_cfg$max_iter %||% 200L, 200L),
        exdqlm.tol_sigma = safe_num(vb_cfg$tol_sigma %||% vb_cfg$tol %||% 0.1, 0.1),
        exdqlm.tol_gamma = safe_num(vb_cfg$tol_gamma %||% vb_cfg$tol %||% 0.1, 0.1),
        exdqlm.tol_elbo = safe_num(vb_cfg$tol_elbo %||% 1e-6, 1e-6),
        exdqlm.vb.min_iter = safe_int(vb_cfg$min_iter %||% 10L, 10L),
        exdqlm.vb.patience = safe_int(vb_cfg$patience %||% 3L, 3L),
        exdqlm.vb.allow_elbo_drop = safe_num(vb_cfg$allow_elbo_drop %||% 1e-5, 1e-5)
      )
      old_opt_main <- options(opt_list)
      old_opt_ld <- set_dynamic_ld_options(vb_cfg$ld %||% list())
      on.exit({ options(old_opt_main); if (length(old_opt_ld)) options(old_opt_ld) }, add = TRUE)

      set.seed(seed)
      t0 <- proc.time()[['elapsed']]
      fit_new <- exdqlmLDVB(
        y = as.numeric(sim$y),
        p0 = bf$p0,
        model = bf$model,
        df = bf$df,
        dim.df = bf$dim.df,
        fix.sigma = FALSE,
        sig.init = safe_num(bf$sig.init %||% NA_real_, NA_real_),
        dqlm.ind = identical(model, 'dqlm'),
        tol = safe_num(vb_cfg$tol %||% 0.1, 0.1),
        n.samp = safe_int(vb_cfg$n_samp %||% 200L, 200L),
        verbose = FALSE
      )
      elapsed <- proc.time()[['elapsed']] - t0
      return(list(fit = fit_new, meta = list(runtime_sec = as.numeric(elapsed), seed = seed, tag = tag)))
    }

    if (!(root_kind %in% c('static_paper', 'static_shrink', 'static'))) {
      stop(sprintf('Unsupported root_kind for vb: %s', root_kind))
    }

    vb_cfg <- cfg$vb %||% list()
    prior <- as.character(row$prior_override)
    if (!nzchar(prior) || identical(prior, 'default')) prior <- as.character(vb_cfg$beta_prior %||% bf$beta_prior$type %||% bf$beta_prior %||% 'ridge')

    y <- as.numeric(sim$y)
    X <- as.matrix(sim$extras$X)
    storage.mode(X) <- 'double'

    set.seed(seed)
    t0 <- proc.time()[['elapsed']]
    fit_new <- exal_static_LDVB(
      y = y,
      X = X,
      p0 = safe_num(row$tau, safe_num(bf$p0, 0.5)),
      max_iter = safe_int(vb_cfg$max_iter %||% 300L, 300L),
      tol = safe_num(vb_cfg$tol %||% 0.03, 0.03),
      beta_prior = prior,
      beta_prior_controls = bf$beta_prior$controls %||% vb_cfg$beta_prior_controls %||% NULL,
      dqlm.ind = identical(model, 'al'),
      n_samp_xi = safe_int(vb_cfg$n_samp_xi %||% 1000L, 1000L),
      ld_controls = vb_cfg$ld %||% NULL,
      verbose = FALSE
    )
    elapsed <- proc.time()[['elapsed']] - t0
    return(list(fit = fit_new, meta = list(runtime_sec = as.numeric(elapsed), seed = seed, tag = tag)))
  }

  if (identical(inference, 'mcmc')) {
    if (identical(root_kind, 'dynamic')) {
      vb_cfg <- cfg$vb %||% list()
      mc_cfg <- cfg$mcmc %||% list()
      mh <- mc_cfg$mh %||% list()
      accepted_mh <- bf$mh.diagnostics %||% list()

      explicit_vb_reference_path <- if ('vb_reference_fit_path' %in% names(row)) {
        safe_chr(row$vb_reference_fit_path, NA_character_)
      } else {
        NA_character_
      }
      explicit_vb_candidate_path <- if ('vb_candidate_fit_path' %in% names(row)) {
        safe_chr(row$vb_candidate_fit_path, NA_character_)
      } else {
        NA_character_
      }
      vb_candidate_path <- file.path(
        row$run_root,
        'fits', 'vb',
        sprintf('vb_%s_tau_%s_fit_%s.rds', model, row$tau_label, tag)
      )
      vb_baseline_path <- file.path(
        row$run_root,
        'fits', 'vb',
        sprintf('vb_%s_tau_%s_fit.rds', model, row$tau_label)
      )
      vb_obj <- NULL
      if (!is.na(explicit_vb_reference_path) && file.exists(explicit_vb_reference_path)) {
        vb_obj <- resolve_fit(readRDS(explicit_vb_reference_path))
      } else if (!is.na(explicit_vb_candidate_path) && file.exists(explicit_vb_candidate_path)) {
        vb_obj <- resolve_fit(readRDS(explicit_vb_candidate_path))
      } else if (file.exists(vb_candidate_path)) {
        vb_obj <- resolve_fit(readRDS(vb_candidate_path))
      } else if (file.exists(vb_baseline_path)) {
        vb_obj <- resolve_fit(readRDS(vb_baseline_path))
      }

      init_from_vb <- if (!is.null(mc_cfg$init_from_vb)) {
        as_flag(mc_cfg$init_from_vb, !is.null(vb_obj))
      } else {
        as_flag(bf$init.from.vb, !is.null(vb_obj))
      }

      accepted_refresh <- accepted_mh$laplace_refresh %||% list()
      refresh_interval <- safe_int(first_present(
        mh$laplace_refresh_interval,
        mc_cfg$laplace_refresh_interval,
        accepted_refresh$interval,
        accepted_refresh$refresh_interval,
        accepted_refresh$laplace_refresh_interval
      ), NA_integer_)
      refresh_start <- safe_int(first_present(
        mh$laplace_refresh_start,
        mc_cfg$laplace_refresh_start,
        accepted_refresh$start,
        accepted_refresh$start_iter,
        accepted_refresh$refresh_start,
        accepted_refresh$laplace_refresh_start
      ), NA_integer_)
      refresh_weight <- safe_num(first_present(
        mh$laplace_refresh_weight,
        mc_cfg$laplace_refresh_weight,
        accepted_refresh$weight,
        accepted_refresh$refresh_weight,
        accepted_refresh$laplace_refresh_weight
      ), NA_real_)

      refresh_opts <- list()
      if (is.finite(refresh_interval)) {
        refresh_opts$exdqlm.mcmc.laplace_refresh_interval <- refresh_interval
      }
      if (is.finite(refresh_start)) {
        refresh_opts$exdqlm.mcmc.laplace_refresh_start <- refresh_start
      }
      if (is.finite(refresh_weight)) {
        refresh_opts$exdqlm.mcmc.laplace_refresh_weight <- refresh_weight
      }
      if (length(refresh_opts)) {
        old_dynamic_refresh <- options(refresh_opts)
        on.exit(options(old_dynamic_refresh), add = TRUE)
      }

      call_args <- list(
        y = as.numeric(sim$y),
        p0 = bf$p0,
        model = bf$model,
        df = bf$df,
        dim.df = bf$dim.df,
        dqlm.ind = identical(model, 'dqlm'),
        n.burn = safe_int(mc_cfg$burn %||% bf$n.burn %||% 2000L, 2000L),
        n.mcmc = safe_int(mc_cfg$n %||% bf$n.mcmc %||% 1500L, 1500L),
        init.from.vb = init_from_vb,
        init.from.isvb = as_flag(identical(tolower(safe_chr(bf$vb.init.method, 'ldvb')), 'isvb') %||% mc_cfg$init_from_isvb, FALSE),
        vb_init_controls = list(
          method = safe_chr(vb_cfg$method %||% bf$vb.init.method %||% "ldvb", "ldvb"),
          tol = safe_num(vb_cfg$tol %||% 0.1, 0.1),
          n.IS = safe_int(vb_cfg$n_IS %||% vb_cfg$n_is %||% 200L, 200L),
          n.samp = safe_int(vb_cfg$n_samp %||% 1000L, 1000L),
          max_iter = safe_int(vb_cfg$max_iter %||% 300L, 300L),
          verbose = FALSE
        ),
        joint.sample = as_flag(first_present(mh$joint_sample, mh$primary_joint_sample, accepted_mh$joint_sample), FALSE),
        mh.proposal = safe_chr(first_present(mh$proposal, mh$primary_proposal, accepted_mh$proposal, 'laplace_rw'), 'laplace_rw'),
        mh.adapt = as_flag(first_present(mh$adapt, accepted_mh$adapt), TRUE),
        mh.adapt.interval = safe_int(first_present(mh$adapt_interval, accepted_mh$adapt_interval, 50L), 50L),
        mh.target.accept = safe_num_vec(first_present(mh$target_accept, accepted_mh$target_accept, c(0.20, 0.45)), c(0.20, 0.45)),
        mh.scale.bounds = safe_num_vec(first_present(mh$scale_bounds, accepted_mh$scale_bounds, c(0.1, 10)), c(0.1, 10)),
        mh.max_scale.step = safe_num(first_present(mh$max_scale_step, accepted_mh$max_scale_step, 0.35), 0.35),
        mh.min_burn_adapt = safe_int(first_present(mh$min_burn_adapt, accepted_mh$min_burn_adapt, 50L), 50L),
        trace.diagnostics = TRUE,
        trace.every = safe_int(mh$trace_every %||% mc_cfg$trace_every %||% accepted_mh$trace_every %||% 50L, 50L),
        verbose = isTRUE(verbose_mcmc),
        progress_callback = progress_telemetry_callback
      )
      slice_width <- safe_num(first_present(mh$slice_width, accepted_mh$slice_width), NA_real_)
      slice_max_steps <- safe_int(first_present(mh$slice_max_steps, accepted_mh$slice_max_steps), NA_integer_)
      if (is.finite(slice_width)) call_args$slice.width <- slice_width
      if (is.finite(slice_max_steps)) call_args$slice.max.steps <- slice_max_steps
      if (isTRUE(init_from_vb) && !is.null(vb_obj)) call_args$vb_init_fit <- vb_obj

      set.seed(seed)
      t0 <- proc.time()[['elapsed']]
      append_telemetry('burnin', iter = 0L, marker = safe_chr(call_args$mh.proposal, 'mcmc_start'))
      fit_new <- do.call(exdqlmMCMC, call_args)
      elapsed <- proc.time()[['elapsed']] - t0
      return(list(fit = fit_new, meta = list(runtime_sec = as.numeric(elapsed), seed = seed, tag = tag)))
    }

    if (!(root_kind %in% c('static_paper', 'static_shrink', 'static'))) {
      stop(sprintf('Unsupported root_kind for mcmc: %s', root_kind))
    }

    mc_cfg <- cfg$mcmc %||% list()
    vb_cfg <- cfg$vb %||% list()
    mh <- mc_cfg$mh %||% list()
    accepted_mh <- bf$mh.diagnostics %||% list()

    prior <- as.character(row$prior_override)
    if (!nzchar(prior) || identical(prior, 'default')) prior <- as.character(mc_cfg$beta_prior %||% bf$beta_prior$type %||% bf$beta_prior %||% 'ridge')

    y <- as.numeric(sim$y)
    X <- as.matrix(sim$extras$X)
    storage.mode(X) <- 'double'

    static_init_from_vb <- if (!is.null(mc_cfg$init_from_vb)) {
      as_flag(mc_cfg$init_from_vb, TRUE)
    } else {
      as_flag(bf$init.from.vb, TRUE)
    }

    explicit_vb_reference_path <- if ('vb_reference_fit_path' %in% names(row)) {
      safe_chr(row$vb_reference_fit_path, NA_character_)
    } else {
      NA_character_
    }
    explicit_vb_candidate_path <- if ('vb_candidate_fit_path' %in% names(row)) {
      safe_chr(row$vb_candidate_fit_path, NA_character_)
    } else {
      NA_character_
    }
    vb_candidate_path <- file.path(
      row$run_root,
      'fits', 'vb',
      sprintf('vb_%s_tau_%s_fit_%s.rds', model, row$tau_label, tag)
    )
    vb_baseline_path <- file.path(
      row$run_root,
      'fits', 'vb',
      sprintf('vb_%s_tau_%s_fit.rds', model, row$tau_label)
    )
    vb_obj <- NULL
    if (!is.na(explicit_vb_reference_path) && file.exists(explicit_vb_reference_path)) {
      vb_obj <- resolve_fit(readRDS(explicit_vb_reference_path))
    } else if (!is.na(explicit_vb_candidate_path) && file.exists(explicit_vb_candidate_path)) {
      vb_obj <- resolve_fit(readRDS(explicit_vb_candidate_path))
    } else if (file.exists(vb_candidate_path)) {
      vb_obj <- resolve_fit(readRDS(vb_candidate_path))
    } else if (file.exists(vb_baseline_path)) {
      vb_obj <- resolve_fit(readRDS(vb_baseline_path))
    }

    accepted_refresh <- accepted_mh$laplace_refresh %||% list()
    refresh_interval <- safe_int(first_present(
      mh$laplace_refresh_interval,
      mc_cfg$laplace_refresh_interval,
      accepted_refresh$interval,
      accepted_refresh$refresh_interval,
      accepted_refresh$laplace_refresh_interval
    ), NA_integer_)
    refresh_start <- safe_int(first_present(
      mh$laplace_refresh_start,
      mc_cfg$laplace_refresh_start,
      accepted_refresh$start,
      accepted_refresh$start_iter,
      accepted_refresh$refresh_start,
      accepted_refresh$laplace_refresh_start
    ), NA_integer_)
    refresh_weight <- safe_num(first_present(
      mh$laplace_refresh_weight,
      mc_cfg$laplace_refresh_weight,
      accepted_refresh$weight,
      accepted_refresh$refresh_weight,
      accepted_refresh$laplace_refresh_weight
    ), NA_real_)

    refresh_opts <- list()
    if (is.finite(refresh_interval)) {
      refresh_opts$exdqlm.static.mcmc.laplace_refresh_interval <- refresh_interval
    }
    if (is.finite(refresh_start)) {
      refresh_opts$exdqlm.static.mcmc.laplace_refresh_start <- refresh_start
    }
    if (is.finite(refresh_weight)) {
      refresh_opts$exdqlm.static.mcmc.laplace_refresh_weight <- refresh_weight
    }
    if (length(refresh_opts)) {
      old_static_refresh <- options(refresh_opts)
      on.exit(options(old_static_refresh), add = TRUE)
    }

    call_args <- list(
      y = y,
      X = X,
      p0 = safe_num(row$tau, safe_num(bf$p0, 0.5)),
      beta_prior = prior,
      beta_prior_controls = bf$beta_prior$controls %||% mc_cfg$beta_prior_controls %||% vb_cfg$beta_prior_controls %||% NULL,
      dqlm.ind = identical(model, 'al'),
      n.burn = safe_int(mc_cfg$burn %||% bf$n.burn %||% 3000L, 3000L),
      n.mcmc = safe_int(mc_cfg$n %||% bf$n.mcmc %||% 8000L, 8000L),
      thin = safe_int(mc_cfg$thin %||% bf$thin %||% 1L, 1L),
      init.from.vb = static_init_from_vb,
      vb_init_controls = list(
        max_iter = safe_int(vb_cfg$max_iter %||% 300L, 300L),
        tol = safe_num(vb_cfg$tol %||% 0.03, 0.03),
        n_samp_xi = safe_int(vb_cfg$n_samp_xi %||% 1000L, 1000L),
        ld_controls = vb_cfg$ld %||% NULL,
        verbose = FALSE
      ),
      mh.proposal = safe_chr(first_present(mh$proposal, mh$primary_proposal, accepted_mh$proposal, 'laplace_rw'), 'laplace_rw'),
      mh.adapt = as_flag(first_present(mh$adapt, accepted_mh$adapt), TRUE),
      mh.adapt.interval = safe_int(first_present(mh$adapt_interval, accepted_mh$adapt_interval, 50L), 50L),
      mh.target.accept = safe_num_vec(first_present(mh$target_accept, accepted_mh$target_accept, c(0.20, 0.45)), c(0.20, 0.45)),
      mh.scale.bounds = safe_num_vec(first_present(mh$scale_bounds, accepted_mh$scale_bounds, c(0.1, 10)), c(0.1, 10)),
      mh.max_scale.step = safe_num(first_present(mh$max_scale_step, accepted_mh$max_scale_step, 0.35), 0.35),
      mh.min_burn_adapt = safe_int(first_present(mh$min_burn_adapt, accepted_mh$min_burn_adapt, 50L), 50L),
      gamma.substeps = safe_int(first_present(mh$gamma_substeps, accepted_mh$gamma_substeps, 1L), 1L),
      p.global.eta.jump = safe_num(first_present(mh$p_global_eta_jump, accepted_mh$global_eta_jump$p, 0), 0),
      global.eta.jump.scale = safe_num(first_present(mh$global_eta_jump_scale, accepted_mh$global_eta_jump$scale, 1), 1),
      trace.diagnostics = as_flag(first_present(mh$trace_diagnostics, accepted_mh$trace_enabled), TRUE),
      trace.every = safe_int(first_present(mh$trace_every, mc_cfg$trace_every, accepted_mh$trace_every, 50L), 50L),
      verbose = isTRUE(verbose_mcmc),
      progress_callback = progress_telemetry_callback
    )

    slice_width <- safe_num(first_present(mh$slice_width, accepted_mh$slice_width), NA_real_)
    slice_max_steps <- safe_int(first_present(mh$slice_max_steps, accepted_mh$slice_max_steps), NA_integer_)
    if (is.finite(slice_width)) call_args$slice.width <- slice_width
    if (is.finite(slice_max_steps)) call_args$slice.max.steps <- slice_max_steps
    if (isTRUE(static_init_from_vb) && !is.null(vb_obj)) call_args$vb_init_fit <- vb_obj

    set.seed(seed)
    t0 <- proc.time()[['elapsed']]
    append_telemetry('burnin', iter = 0L, marker = safe_chr(call_args$mh.proposal, 'mcmc_start'))
    fit_new <- do.call(exal_static_mcmc, call_args)
    elapsed <- proc.time()[['elapsed']] - t0
    return(list(fit = fit_new, meta = list(runtime_sec = as.numeric(elapsed), seed = seed, tag = tag)))
  }

  stop(sprintf('Unsupported inference: %s', inference))
}

health_row <- NULL

tryCatch({
  wrapped <- NULL
  if (file.exists(candidate_path) && !force) {
    wrapped <- readRDS(candidate_path)
    status <- 'skipped_existing'
  } else {
    Sys.setenv(
      OMP_NUM_THREADS = '1',
      OPENBLAS_NUM_THREADS = '1',
      MKL_NUM_THREADS = '1',
      EXDQLM_MCMC_PROGRESS_EVERY = as.character(progress_every)
    )
    wrapped <- with_optional_rprof(run_and_wrap())
    candidate_tmp <- sprintf('%s.tmp.%d.%s', candidate_path, Sys.getpid(), format(Sys.time(), '%Y%m%d%H%M%S'))
    saveRDS(wrapped, candidate_tmp)
    moved <- file.rename(candidate_tmp, candidate_path)
    if (!isTRUE(moved)) {
      copied <- file.copy(candidate_tmp, candidate_path, overwrite = TRUE)
      unlink(candidate_tmp, force = TRUE)
      if (!isTRUE(copied)) stop(sprintf('failed to atomically finalize candidate fit: %s', candidate_path))
    }
    status <- 'done'
  }

  if (identical(inference, 'mcmc')) {
    metrics <- vhg_collect_mcmc_metrics(wrapped, case_id = case_id, variant = tag, candidate_path = candidate_path)
    health_row <- vhg_apply_health_gates(metrics)
  } else {
    health_row <- collect_vb_health(wrapped, case_id = case_id, variant = tag, candidate_path = candidate_path, vhg_extract_rhs_collapse = vhg_extract_rhs_collapse)
  }

  utils::write.csv(health_row, health_out_path, row.names = FALSE)
}, error = function(e) {
  status <<- 'failed_runtime'
  error_msg <<- conditionMessage(e)
  append_telemetry('finalize', iter = NA_integer_, marker = paste0('error:', safe_chr(error_msg, 'failed_runtime')))
})

ts_end <- as.character(Sys.time())

if (is.null(health_row)) {
  health_row <- data.frame(
    gate_overall = 'FAIL',
    healthy = FALSE,
    rhs_collapse_flag = NA,
    run_time_sec = NA_real_,
    stringsAsFactors = FALSE
  )
}

row_out <- data.frame(
  row_id = row_id,
  ts_start = start_ts,
  ts_end = ts_end,
  status = status,
  error = error_msg,
  gate_overall = as.character(health_row$gate_overall[1] %||% NA_character_),
  healthy = isTRUE(health_row$healthy[1]),
  rhs_collapse_flag = as.logical(health_row$rhs_collapse_flag[1] %||% NA),
  runtime_sec = safe_num(health_row$run_time_sec[1], NA_real_),
  inference = inference,
  model = model,
  root_kind = root_kind,
  family = as.character(row$family),
  tau_label = as.character(row$tau_label),
  baseline_fit_path = as.character(row$baseline_fit_path),
  candidate_fit_path = candidate_path,
  health_csv = health_out_path,
  telemetry_csv = if (has_telemetry) telemetry_path else NA_character_,
  stringsAsFactors = FALSE
)

utils::write.csv(row_out, row_out_path, row.names = FALSE)
append_telemetry(
  'finalize',
  iter = NA_integer_,
  marker = sprintf('status=%s;gate=%s', status, safe_chr(row_out$gate_overall[1], NA_character_))
)

cat(sprintf('[row %d] status=%s gate=%s healthy=%s model=%s inference=%s root=%s family=%s tau=%s\n',
            row_id,
            status,
            as.character(row_out$gate_overall[1]),
            as.character(row_out$healthy[1]),
            model,
            inference,
            root_kind,
            as.character(row$family),
            as.character(row$tau_label)))
if (!is.na(error_msg)) cat(sprintf('[row %d] error=%s\n', row_id, error_msg))
