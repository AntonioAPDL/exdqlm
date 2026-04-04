#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath('.', winslash = '/', mustWork = TRUE)
out_dir <- file.path(repo_root, 'tools', 'merge_reports')
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

as_flag <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  tolower(as.character(x)[1]) %in% c('1', 'true', 'yes', 'y', 't')
}

to_tau_label <- function(x) {
  raw <- as.character(x)[1]
  if (grepl('p', raw, fixed = TRUE)) return(raw)
  val <- suppressWarnings(as.numeric(raw)[1])
  if (!is.finite(val)) return(raw)
  gsub('.', 'p', sprintf('%.2f', val), fixed = TRUE)
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

extract_family <- function(path) {
  m <- regexec('/(normal|laplace|gausmix)/tau_', path)
  g <- regmatches(path, m)[[1]]
  if (length(g) >= 2) g[2] else NA_character_
}

extract_tt <- function(path) {
  m <- regexec('tt([0-9]+)', path)
  g <- regmatches(path, m)[[1]]
  if (length(g) >= 2) suppressWarnings(as.integer(g[2])) else NA_integer_
}

extract_scope <- function(path) {
  if (grepl('static_paper', path, fixed = TRUE)) return('static_paper')
  if (grepl('static_shrinkage', path, fixed = TRUE)) return('static_shrink')
  'static'
}

safe_num1 <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_int1 <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_chr1 <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  y <- as.character(x)[1]
  if (!nzchar(y)) default else y
}

args <- parse_args(commandArgs(trailingOnly = TRUE))

model_key <- tolower(as.character(args$model %||% 'exal'))
if (!model_key %in% c('exal')) stop('model must be exal')

run_root <- args$run_root %||% stop('run_root is required')
run_root <- normalizePath(run_root, winslash = '/', mustWork = TRUE)

queue_id <- as.character(args$queue_id %||% NA_character_)
priority_label <- as.character(args$priority_label %||% NA_character_)
family_scope <- as.character(args$family_scope %||% extract_scope(run_root))
family <- as.character(args$family %||% extract_family(run_root))
if (!family %in% c('normal', 'laplace', 'gausmix')) family <- 'unknown'

tt <- safe_int1(args$tt %||% extract_tt(run_root), NA_integer_)
tau_label <- to_tau_label(args$tau %||% {
  m <- regexec('tau_([^/]+)', run_root)
  g <- regmatches(run_root, m)[[1]]
  if (length(g) >= 2) g[2] else NA_character_
})
if (is.na(tau_label) || !nzchar(tau_label)) stop('unable to resolve tau label')
p0 <- safe_num1(args$p0 %||% gsub('p', '.', tau_label, fixed = TRUE), NA_real_)
if (!is.finite(p0) || p0 <= 0 || p0 >= 1) stop('p0 must be in (0,1)')

variant_tag <- as.character(args$variant_tag %||% stop('variant_tag is required'))
seed <- safe_int1(args$seed %||% '2026032301', NA_integer_)
if (!is.finite(seed)) stop('seed must be finite integer')

n_burn <- safe_int1(args$n_burn %||% '1500', NA_integer_)
n_mcmc <- safe_int1(args$n_mcmc %||% '5000', NA_integer_)
thin <- safe_int1(args$thin %||% '1', NA_integer_)
trace_every <- safe_int1(args$trace_every %||% '50', 50L)
progress_every <- safe_int1(args$progress_every %||% as.character(trace_every), trace_every)
mh_proposal <- as.character(args$mh_proposal %||% 'laplace_rw')
mh_adapt <- as_flag(args$mh_adapt, TRUE)
slice_width <- safe_num1(args$slice_width %||% '0.12', 0.12)
slice_max_steps <- safe_int1(args$slice_max_steps %||% '80', 80L)
gamma_substeps <- safe_int1(args$gamma_substeps %||% '3', 3L)
p_global_eta_jump <- safe_num1(args$p_global_eta_jump %||% '0.05', 0.05)
global_eta_jump_scale <- safe_num1(args$global_eta_jump_scale %||% '1', 1)
laplace_refresh_interval <- safe_int1(args$laplace_refresh_interval %||% as.character(trace_every), trace_every)
laplace_refresh_start <- safe_int1(args$laplace_refresh_start %||% as.character(max(50L, floor(n_burn / 6L))), max(50L, floor(n_burn / 6L)))
laplace_refresh_weight <- safe_num1(args$laplace_refresh_weight %||% '0.60', 0.60)
init_mode <- tolower(as.character(args$init_mode %||% 'baseline_last'))
force <- as_flag(args$force, FALSE)

if (!is.finite(n_burn) || n_burn < 10L) stop('n_burn must be >= 10')
if (!is.finite(n_mcmc) || n_mcmc < 10L) stop('n_mcmc must be >= 10')
if (!is.finite(thin) || thin < 1L) stop('thin must be >= 1')
if (!mh_proposal %in% c('laplace_local', 'laplace_rw', 'rw', 'slice', 'slice_eta')) stop('invalid mh_proposal')
if (!is.finite(slice_width) || slice_width <= 0) stop('slice_width must be > 0')
if (!is.finite(slice_max_steps) || slice_max_steps < 1L) stop('slice_max_steps must be >= 1')
if (!is.finite(gamma_substeps) || gamma_substeps < 1L) stop('gamma_substeps must be >= 1')
if (!is.finite(p_global_eta_jump) || p_global_eta_jump < 0 || p_global_eta_jump > 1) {
  stop('p_global_eta_jump must be in [0,1]')
}
if (!is.finite(global_eta_jump_scale) || global_eta_jump_scale <= 0) {
  stop('global_eta_jump_scale must be > 0')
}
if (!is.finite(laplace_refresh_interval) || laplace_refresh_interval < 5L) laplace_refresh_interval <- trace_every
if (!is.finite(laplace_refresh_start) || laplace_refresh_start < 1L) laplace_refresh_start <- max(50L, floor(n_burn / 6L))
if (!is.finite(laplace_refresh_weight) || laplace_refresh_weight <= 0 || laplace_refresh_weight > 1) {
  laplace_refresh_weight <- 0.60
}
if (!init_mode %in% c('baseline_last', 'none', 'vb')) stop('init_mode must be baseline_last, none, or vb')

if (!requireNamespace('pkgload', quietly = TRUE)) stop('pkgload is required')
if (!requireNamespace('coda', quietly = TRUE)) stop('coda is required')

source(file.path(out_dir, 'LOCAL_validation_health_gate_common_20260321.R'))
pkgload::load_all(repo_root, quiet = TRUE)

mcmc_base_path <- as.character(args$mcmc_base_path %||% file.path(
  run_root, 'fits', 'mcmc', sprintf('mcmc_%s_tau_%s_fit.rds', model_key, tau_label)
))
vb_path <- as.character(args$vb_path %||% file.path(
  run_root, 'fits', 'vb', sprintf('vb_%s_tau_%s_fit.rds', model_key, tau_label)
))
candidate_path <- as.character(args$candidate_path %||% file.path(
  run_root, 'fits', 'mcmc', sprintf('mcmc_%s_tau_%s_fit_%s.rds', model_key, tau_label, variant_tag)
))
sim_output_path <- as.character(args$sim_output_path %||% file.path(dirname(run_root), 'sim_output.rds'))
run_config_path <- as.character(args$run_config_path %||% file.path(run_root, 'tables', 'run_config.rds'))

if (!file.exists(mcmc_base_path)) stop(sprintf('missing baseline mcmc: %s', mcmc_base_path))
if (!file.exists(sim_output_path)) stop(sprintf('missing sim_output.rds: %s', sim_output_path))

baseline <- readRDS(mcmc_base_path)
bf <- baseline$fit %||% baseline
sim_obj <- readRDS(sim_output_path)
y <- as.numeric(sim_obj$y)
X <- as.matrix(sim_obj$extras$X)
storage.mode(X) <- 'double'
if (length(y) != nrow(X)) stop('sim_output y and X dimensions mismatch')

beta_prior <- as.character(bf$beta_prior$type %||% 'ridge')
beta_prior_controls <- bf$beta_prior$controls %||% NULL
beta_prior_source <- 'baseline_fit'
beta_prior_override <- safe_chr1(args$beta_prior_override, NA_character_)
prior_template_path <- safe_chr1(args$prior_template_path, NA_character_)

if (!is.null(run_config_path) && file.exists(run_config_path)) {
  cfg <- tryCatch(readRDS(run_config_path), error = function(e) NULL)
  if (is.list(cfg) && is.list(cfg$mcmc)) {
    if (is.character(cfg$mcmc$beta_prior) && nzchar(cfg$mcmc$beta_prior[1])) {
      beta_prior <- as.character(cfg$mcmc$beta_prior[1])
      beta_prior_source <- 'run_config'
    }
    if (is.list(cfg$mcmc$beta_prior_controls)) {
      beta_prior_controls <- cfg$mcmc$beta_prior_controls
    }
  }
}

if (!is.na(prior_template_path) && nzchar(prior_template_path)) {
  prior_template_path <- normalizePath(prior_template_path, winslash = '/', mustWork = TRUE)
  prior_template <- tryCatch(readRDS(prior_template_path), error = function(e) NULL)
  prior_template_fit <- prior_template$fit %||% prior_template
  template_prior <- safe_chr1(prior_template_fit$beta_prior$type, NA_character_)
  template_controls <- prior_template_fit$beta_prior$controls %||% NULL
  if (!is.na(template_prior)) {
    beta_prior <- template_prior
    beta_prior_source <- 'prior_template'
  }
  if (is.list(template_controls)) {
    beta_prior_controls <- template_controls
  }
} else {
  prior_template_path <- NA_character_
}

if (!is.na(beta_prior_override) && nzchar(beta_prior_override)) {
  beta_prior <- as.character(beta_prior_override)
  beta_prior_source <- if (!is.na(prior_template_path) && nzchar(prior_template_path)) {
    'prior_template+override'
  } else {
    'override'
  }
}

build_init_from_baseline <- function(fit) {
  out <- list()
  if (is.list(fit$last)) {
    for (nm in intersect(c('beta', 'sigma', 'gamma', 'v', 's'), names(fit$last))) {
      out[[nm]] <- fit$last[[nm]]
    }
  }
  if (!is.null(fit$beta_prior$state)) {
    st <- fit$beta_prior$state
    for (nm in intersect(c('lambda', 'tau', 'c2'), names(st))) {
      out[[nm]] <- st[[nm]]
    }
  }
  out
}

init <- switch(init_mode,
  baseline_last = build_init_from_baseline(bf),
  none = list(),
  vb = list(),
  list()
)
init_from_vb <- identical(init_mode, 'vb')

dir.create(dirname(candidate_path), recursive = TRUE, showWarnings = FALSE)

case_id <- paste0(gsub('^.*/results/', 'results/', run_root), '::', model_key)
checkpoint_path <- file.path(out_dir, sprintf('LOCAL_static_case_checkpoint_%s_%s_%s.csv', variant_tag, model_key, family))
health_path <- file.path(out_dir, sprintf('LOCAL_static_case_health_%s_%s_%s_TT%d.csv', variant_tag, model_key, family, tt %||% -1L))
summary_path <- file.path(out_dir, sprintf('LOCAL_static_case_health_summary_%s.csv', variant_tag))

acquire_lock <- function(lock_path, wait_sec = 30, interval = 0.1) {
  start <- Sys.time()
  repeat {
    ok <- tryCatch(file.create(lock_path), warning = function(w) FALSE, error = function(e) FALSE)
    if (isTRUE(ok)) return(TRUE)
    if (as.numeric(difftime(Sys.time(), start, units = "secs")) > wait_sec) return(FALSE)
    Sys.sleep(interval)
  }
}

release_lock <- function(lock_path) {
  if (file.exists(lock_path)) unlink(lock_path)
}

safe_read_summary <- function(path, attempts = 6, delay = 0.1) {
  for (i in seq_len(attempts)) {
    if (!file.exists(path)) return(NULL)
    info <- file.info(path)
    if (!is.na(info$size) && info$size > 0) {
      x <- tryCatch(utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE),
                    error = function(e) NULL)
      if (!is.null(x)) return(x)
    }
    Sys.sleep(delay)
  }
  NULL
}

write_csv_atomic <- function(df, path) {
  tmp <- sprintf('%s.tmp.%s', path, Sys.getpid())
  utils::write.csv(df, tmp, row.names = FALSE)
  file.rename(tmp, path)
}

vhg_append_checkpoint(checkpoint_path, list(
  ts = as.character(Sys.time()),
  stage = 'start',
  case_id = case_id,
  queue_id = queue_id,
  priority_label = priority_label,
  family_scope = family_scope,
  model = model_key,
  family = family,
  tt = tt,
  tau = tau_label,
  p0 = p0,
  variant_tag = variant_tag,
  seed = as.integer(seed),
  n_burn = as.integer(n_burn),
  n_mcmc = as.integer(n_mcmc),
  thin = as.integer(thin),
  trace_every = as.integer(trace_every),
  progress_every = as.integer(progress_every),
  mh_proposal = mh_proposal,
  mh_adapt = mh_adapt,
  laplace_refresh_interval = as.integer(laplace_refresh_interval),
  laplace_refresh_start = as.integer(laplace_refresh_start),
  laplace_refresh_weight = as.numeric(laplace_refresh_weight),
  slice_width = as.numeric(slice_width),
  slice_max_steps = as.integer(slice_max_steps),
  gamma_substeps = as.integer(gamma_substeps),
  p_global_eta_jump = as.numeric(p_global_eta_jump),
  global_eta_jump_scale = as.numeric(global_eta_jump_scale),
  init_mode = init_mode,
  init_from_vb = init_from_vb,
  force = force,
  beta_prior = beta_prior,
  beta_prior_source = beta_prior_source,
  beta_prior_override = beta_prior_override,
  prior_template_path = prior_template_path,
  mcmc_base_path = mcmc_base_path,
  vb_path = vb_path,
  sim_output_path = sim_output_path,
  run_config_path = run_config_path,
  candidate_path = candidate_path,
  candidate_exists = file.exists(candidate_path)
))

cat(sprintf('[static-case] %s started | queue=%s tier=%s scope=%s model=%s family=%s tt=%s tau=%s variant=%s force=%s\n',
            format(Sys.time(), '%Y-%m-%d %H:%M:%S'), queue_id, priority_label, family_scope, model_key, family,
            ifelse(is.finite(tt), as.character(tt), 'NA'), tau_label, variant_tag, force))
cat(sprintf('[static-case] run_root=%s\n', run_root))
cat(sprintf('[static-case] baseline=%s\n', mcmc_base_path))
cat(sprintf('[static-case] candidate=%s\n', candidate_path))
cat(sprintf('[static-case] beta_prior=%s source=%s prior_template=%s override=%s\n',
            beta_prior,
            beta_prior_source,
            ifelse(is.na(prior_template_path), 'NA', prior_template_path),
            ifelse(is.na(beta_prior_override), 'NA', beta_prior_override)))
cat(sprintf('[static-case] gamma_substeps=%d p_global_eta_jump=%.3f global_eta_jump_scale=%.3f\n',
            as.integer(gamma_substeps), as.numeric(p_global_eta_jump), as.numeric(global_eta_jump_scale)))

if (!file.exists(candidate_path) || force) {
  old_progress <- Sys.getenv('EXDQLM_MCMC_PROGRESS_EVERY', unset = NA_character_)
  on.exit({
    if (is.na(old_progress)) {
      Sys.unsetenv('EXDQLM_MCMC_PROGRESS_EVERY')
    } else {
      do.call(Sys.setenv, list(EXDQLM_MCMC_PROGRESS_EVERY = old_progress))
    }
  }, add = TRUE)
  do.call(Sys.setenv, list(EXDQLM_MCMC_PROGRESS_EVERY = as.character(progress_every)))
  old_refresh_int <- getOption("exdqlm.static.mcmc.laplace_refresh_interval")
  old_refresh_start <- getOption("exdqlm.static.mcmc.laplace_refresh_start")
  old_refresh_weight <- getOption("exdqlm.static.mcmc.laplace_refresh_weight")
  options(
    exdqlm.static.mcmc.laplace_refresh_interval = as.integer(laplace_refresh_interval),
    exdqlm.static.mcmc.laplace_refresh_start = as.integer(laplace_refresh_start),
    exdqlm.static.mcmc.laplace_refresh_weight = as.numeric(laplace_refresh_weight)
  )
  on.exit({
    options(
      exdqlm.static.mcmc.laplace_refresh_interval = old_refresh_int,
      exdqlm.static.mcmc.laplace_refresh_start = old_refresh_start,
      exdqlm.static.mcmc.laplace_refresh_weight = old_refresh_weight
    )
  }, add = TRUE)

  call_args <- list(
    y = y,
    X = X,
    p0 = p0,
    beta_prior = beta_prior,
    beta_prior_controls = beta_prior_controls,
    dqlm.ind = FALSE,
    init = init,
    n.burn = n_burn,
    n.mcmc = n_mcmc,
    thin = thin,
    init.from.vb = init_from_vb,
    mh.proposal = mh_proposal,
    mh.adapt = mh_adapt,
    slice.width = slice_width,
    slice.max.steps = slice_max_steps,
    gamma.substeps = gamma_substeps,
    p.global.eta.jump = p_global_eta_jump,
    global.eta.jump.scale = global_eta_jump_scale,
    trace.diagnostics = TRUE,
    trace.every = trace_every,
    verbose = TRUE
  )

  set.seed(seed)
  t0 <- proc.time()[['elapsed']]
  fit_new <- do.call(exal_static_mcmc, call_args)
  elapsed <- proc.time()[['elapsed']] - t0

  wrapped <- list(
    fit = fit_new,
    normalized = baseline$normalized %||% NULL,
    meta = list(
      model = model_key,
      tau = p0,
      seed = as.integer(seed),
      runtime_sec = as.numeric(elapsed),
      repair_tag = variant_tag,
      queue_id = queue_id,
      priority_label = priority_label,
      family_scope = family_scope
    )
  )
  saveRDS(wrapped, candidate_path)
}

candidate <- readRDS(candidate_path)
base_metrics <- vhg_collect_mcmc_metrics(baseline, case_id = case_id, variant = 'baseline')
cand_metrics <- vhg_collect_mcmc_metrics(candidate, case_id = case_id, variant = variant_tag, candidate_path = candidate_path)
base_health <- vhg_apply_health_gates(base_metrics)
cand_health <- vhg_apply_health_gates(cand_metrics)
out <- rbind(base_health, cand_health)

utils::write.csv(out, health_path, row.names = FALSE)
cat(sprintf('[static-case] wrote health csv: %s\n', health_path))

cand_row <- cand_health[1, , drop = FALSE]
base_row <- base_health[1, , drop = FALSE]
summary_row <- data.frame(
  ts = as.character(Sys.time()),
  case_id = case_id,
  queue_id = queue_id,
  priority_label = priority_label,
  family_scope = family_scope,
  model = model_key,
  family = family,
  tt = tt,
  tau = tau_label,
  variant_tag = variant_tag,
  gamma_substeps = as.integer(gamma_substeps),
  p_global_eta_jump = as.numeric(p_global_eta_jump),
  global_eta_jump_scale = as.numeric(global_eta_jump_scale),
  gate_overall = cand_row$gate_overall,
  healthy = isTRUE(cand_row$healthy),
  unhealthy_reason = cand_row$unhealthy_reason,
  rhs_collapse_flag = isTRUE(cand_row$rhs_collapse_flag),
  ess_sigma_per1k_base = base_row$ess_sigma_per1k,
  ess_sigma_per1k_cand = cand_row$ess_sigma_per1k,
  ess_sigma_per1k_delta = cand_row$ess_sigma_per1k - base_row$ess_sigma_per1k,
  ess_gamma_per1k_base = base_row$ess_gamma_per1k,
  ess_gamma_per1k_cand = cand_row$ess_gamma_per1k,
  ess_gamma_per1k_delta = cand_row$ess_gamma_per1k - base_row$ess_gamma_per1k,
  acf1_sigma_base = base_row$acf1_sigma,
  acf1_sigma_cand = cand_row$acf1_sigma,
  acf1_sigma_delta = cand_row$acf1_sigma - base_row$acf1_sigma,
  acf1_gamma_base = base_row$acf1_gamma,
  acf1_gamma_cand = cand_row$acf1_gamma,
  acf1_gamma_delta = cand_row$acf1_gamma - base_row$acf1_gamma,
  geweke_sigma_base = base_row$geweke_sigma,
  geweke_sigma_cand = cand_row$geweke_sigma,
  geweke_sigma_delta = cand_row$geweke_sigma - base_row$geweke_sigma,
  geweke_gamma_base = base_row$geweke_gamma,
  geweke_gamma_cand = cand_row$geweke_gamma,
  geweke_gamma_delta = cand_row$geweke_gamma - base_row$geweke_gamma,
  half_drift_sigma_base = base_row$half_drift_sigma,
  half_drift_sigma_cand = cand_row$half_drift_sigma,
  half_drift_sigma_delta = cand_row$half_drift_sigma - base_row$half_drift_sigma,
  half_drift_gamma_base = base_row$half_drift_gamma,
  half_drift_gamma_cand = cand_row$half_drift_gamma,
  half_drift_gamma_delta = cand_row$half_drift_gamma - base_row$half_drift_gamma,
  runtime_sec_base = base_row$run_time_sec,
  runtime_sec_cand = cand_row$run_time_sec,
  runtime_sec_delta = cand_row$run_time_sec - base_row$run_time_sec,
  candidate_path = candidate_path,
  health_csv = health_path,
  stringsAsFactors = FALSE
)

lock_path <- paste0(summary_path, '.lock')
lock_ok <- acquire_lock(lock_path, wait_sec = 30, interval = 0.1)
if (!lock_ok) {
  cat(sprintf('[static-case] warning: summary lock timeout (%s)\n', lock_path))
}
on.exit(release_lock(lock_path), add = TRUE)

old <- safe_read_summary(summary_path, attempts = 6, delay = 0.1)
if (is.null(old) || !nrow(old)) {
  write_csv_atomic(summary_row, summary_path)
} else {
  old <- old[!(old$case_id == summary_row$case_id & old$variant_tag == summary_row$variant_tag), , drop = FALSE]
  all_cols <- union(names(old), names(summary_row))
  for (nm in setdiff(all_cols, names(old))) old[[nm]] <- NA
  for (nm in setdiff(all_cols, names(summary_row))) summary_row[[nm]] <- NA
  old <- old[, all_cols, drop = FALSE]
  summary_row <- summary_row[, all_cols, drop = FALSE]
  write_csv_atomic(rbind(old, summary_row), summary_path)
}

vhg_append_checkpoint(checkpoint_path, list(
  ts = as.character(Sys.time()),
  stage = 'complete',
  case_id = case_id,
  queue_id = queue_id,
  priority_label = priority_label,
  family_scope = family_scope,
  model = model_key,
  family = family,
  tt = tt,
  tau = tau_label,
  variant_tag = variant_tag,
  gamma_substeps = as.integer(gamma_substeps),
  p_global_eta_jump = as.numeric(p_global_eta_jump),
  global_eta_jump_scale = as.numeric(global_eta_jump_scale),
  gate_overall = as.character(cand_row$gate_overall),
  healthy = isTRUE(cand_row$healthy),
  unhealthy_reason = as.character(cand_row$unhealthy_reason),
  rhs_collapse_flag = isTRUE(cand_row$rhs_collapse_flag),
  rhs_collapse_sources = as.character(cand_row$rhs_collapse_sources),
  ess_sigma_per1k = as.numeric(cand_row$ess_sigma_per1k),
  ess_gamma_per1k = as.numeric(cand_row$ess_gamma_per1k),
  acf1_sigma = as.numeric(cand_row$acf1_sigma),
  acf1_gamma = as.numeric(cand_row$acf1_gamma),
  geweke_sigma = as.numeric(cand_row$geweke_sigma),
  geweke_gamma = as.numeric(cand_row$geweke_gamma),
  half_drift_sigma = as.numeric(cand_row$half_drift_sigma),
  half_drift_gamma = as.numeric(cand_row$half_drift_gamma),
  runtime_sec = as.numeric(cand_row$run_time_sec),
  health_csv = health_path,
  summary_csv = summary_path
))

cat(sprintf('[static-case] gate_overall=%s healthy=%s rhs_collapse=%s\n',
            as.character(cand_row$gate_overall), isTRUE(cand_row$healthy), isTRUE(cand_row$rhs_collapse_flag)))
cat(sprintf('[static-case] wrote summary csv: %s\n', summary_path))
