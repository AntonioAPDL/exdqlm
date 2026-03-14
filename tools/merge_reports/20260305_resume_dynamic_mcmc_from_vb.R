#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(Matrix)
  library(parallel)
})

load_exdqlm <- function(repo_root = ".") {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(repo_root, quiet = TRUE)
    return(invisible(TRUE))
  }
  stop("Neither devtools nor pkgload is installed; cannot load local exdqlm package.")
}

load_exdqlm(".")
source("tools/merge_reports/20260305_dynamic_dgp_model_helpers.R")

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

safe_chr_vec <- function(x, default = NULL) {
  if (!nzchar(x)) return(default)
  vals <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  vals <- vals[nzchar(vals)]
  if (!length(vals)) return(default)
  vals
}

cfg_path <- Sys.getenv(
  "EXDQLM_DYNAMIC_RUN_CONFIG",
  "results/function_testing_20260304_vb_quantiles/rerun_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_183508/tables/run_config.rds"
)
if (!file.exists(cfg_path)) stop("Missing config: ", cfg_path)
cfg <- readRDS(cfg_path)
run_root <- as.character(cfg$out_root)
if (!dir.exists(run_root)) stop("run_root not found: ", run_root)

sim <- readRDS(cfg$sim_path)
TT <- as.integer(cfg$TT)
y <- as.numeric(sim$y[seq_len(TT)])
model <- build_dynamic_dgp_matched_model(sim$info$params, TT = TT)

p_vec <- as.numeric(cfg$taus)
mcmc_burn <- safe_int(Sys.getenv("EXDQLM_DYNAMIC_MCMC_BURN", Sys.getenv("EXDQLM_MCMC_BURN", as.character(cfg$mcmc$burn))), safe_int(cfg$mcmc$burn, 500L))
mcmc_n <- safe_int(cfg$mcmc$n, 1000L)
mh_adapt_interval <- safe_int(cfg$mcmc$mh$adapt_interval, 25L)
mh_target <- as.numeric(cfg$mcmc$mh$target_accept)
mh_bounds <- as.numeric(cfg$mcmc$mh$scale_bounds)
mh_max_step <- safe_num(cfg$mcmc$mh$max_scale_step, 0.5)
mh_min_burn_adapt <- safe_int(cfg$mcmc$mh$min_burn_adapt, 25L)
mh_primary_proposal <- tolower(Sys.getenv(
  "EXDQLM_MCMC_PRIMARY_PROPOSAL",
  if (!is.null(cfg$mcmc$mh$primary_proposal)) as.character(cfg$mcmc$mh$primary_proposal)[1] else "laplace_rw"
))
if (!(mh_primary_proposal %in% c("laplace_rw", "rw"))) mh_primary_proposal <- "laplace_rw"
mh_primary_joint_sample <- identical(tolower(Sys.getenv(
  "EXDQLM_MCMC_PRIMARY_JOINT_SAMPLE",
  if (!is.null(cfg$mcmc$mh$primary_joint_sample)) as.character(cfg$mcmc$mh$primary_joint_sample)[1] else "false"
)), "true")
mcmc_trace_diagnostics <- identical(tolower(Sys.getenv("EXDQLM_DYNAMIC_MCMC_TRACE_DIAGNOSTICS", "true")), "true")
mcmc_trace_every <- safe_int(Sys.getenv("EXDQLM_DYNAMIC_MCMC_TRACE_EVERY", "25"), 25L)
if (mcmc_trace_every < 1L) mcmc_trace_every <- 1L
mcmc_verbose <- identical(tolower(Sys.getenv("EXDQLM_DYNAMIC_MCMC_VERBOSE", "true")), "true")

cores <- safe_int(Sys.getenv("EXDQLM_DYNAMIC_RESUME_CORES", as.character(cfg$cores_pipeline)), safe_int(cfg$cores_pipeline, 2L))
cores <- max(1L, min(cores, safe_int(parallel::detectCores(logical = FALSE), 2L)))
dry_run <- identical(tolower(Sys.getenv("EXDQLM_DYNAMIC_RESUME_DRYRUN", "0")), "1")

status_dir <- file.path(run_root, "logs")
master_log <- file.path(status_dir, "resume_dynamic_master.log")

task_key <- function(model_name, tau) sprintf("%s_tau_%s", model_name, tau_lab(tau))
task_log_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".log"))
task_status_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".status.tsv"))

log_master <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = master_log, append = TRUE)
}

log_task <- function(model_name, tau, ...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n", file = task_log_file(model_name, tau), append = TRUE)
}

write_status <- function(model_name, tau, stage, note = "") {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stage, note, sep = "\t")
  cat(line, "\n", file = task_status_file(model_name, tau), append = TRUE)
}

seed_from_status <- function(model_name, tau, fallback) {
  sf <- task_status_file(model_name, tau)
  if (!file.exists(sf)) return(as.integer(fallback))
  lines <- readLines(sf, warn = FALSE)
  m <- regmatches(lines, regexec("seed=([0-9]+)", lines))
  vals <- unlist(lapply(m, function(x) if (length(x) >= 2) x[2] else NA_character_))
  vals <- vals[!is.na(vals)]
  if (length(vals) >= 1) return(as.integer(vals[1]))
  as.integer(fallback)
}

fit_mcmc_with_vb <- function(model_name, tau, seed, vb_fit, df_used) {
  dqlm_flag <- identical(model_name, "dqlm")
  df_vec <- rep(df_used, 3)
  attempts <- if (dqlm_flag) {
    list(
      list(mh_proposal = "rw", joint_sample = FALSE),
      list(mh_proposal = "rw", joint_sample = TRUE)
    )
  } else {
    primary <- list(mh_proposal = mh_primary_proposal, joint_sample = mh_primary_joint_sample)
    raw_attempts <- list(
      primary,
      list(mh_proposal = "laplace_rw", joint_sample = FALSE),
      list(mh_proposal = "laplace_rw", joint_sample = TRUE),
      list(mh_proposal = "rw", joint_sample = FALSE),
      list(mh_proposal = "rw", joint_sample = TRUE)
    )
    keep <- logical(length(raw_attempts))
    seen <- character(0)
    for (i in seq_along(raw_attempts)) {
      a <- raw_attempts[[i]]
      key <- sprintf("%s_%s", a$mh_proposal, ifelse(isTRUE(a$joint_sample), "joint", "fixed"))
      if (!(key %in% seen)) {
        keep[i] <- TRUE
        seen <- c(seen, key)
      }
    }
    raw_attempts[keep]
  }

  errs <- character(0)
  for (k in seq_along(attempts)) {
    a <- attempts[[k]]
    set.seed(seed + 5000L * k)
    fit_try <- tryCatch(
      exdqlmMCMC(
        y = y,
        p0 = tau,
        model = model,
        df = df_vec,
        dim.df = c(2, 2, 2),
        dqlm.ind = dqlm_flag,
        fix.sigma = FALSE,
        n.burn = mcmc_burn,
        n.mcmc = mcmc_n,
        init.from.vb = TRUE,
        vb_init_fit = vb_fit,
        vb_init_controls = list(
          method = "ldvb",
          tol = safe_num(cfg$vb$tol, 0.03),
          n.samp = safe_int(cfg$vb$n_samp, 1000L),
          max_iter = safe_int(cfg$vb$max_iter, 300L),
          verbose = FALSE
        ),
        mh.proposal = a$mh_proposal,
        mh.adapt = TRUE,
        mh.adapt.interval = mh_adapt_interval,
        mh.target.accept = mh_target,
        mh.scale.bounds = mh_bounds,
        mh.max_scale.step = mh_max_step,
        mh.min_burn_adapt = mh_min_burn_adapt,
        joint.sample = a$joint_sample,
        Sig.mh = diag(c(0.001, 0.001)),
        trace.diagnostics = mcmc_trace_diagnostics,
        trace.every = mcmc_trace_every,
        verbose = mcmc_verbose
      ),
      error = function(e) e
    )
    if (!inherits(fit_try, "error")) {
      return(list(
        fit = fit_try,
        attempt_id = k,
        mh_proposal = a$mh_proposal,
        joint_sample = a$joint_sample
      ))
    }
    errs <- c(errs, sprintf("attempt=%d :: %s", k, conditionMessage(fit_try)))
  }
  stop(paste(unique(errs), collapse = " | "))
}

old_opts <- options(
  exdqlm.use_cpp_kf = FALSE,
  exdqlm.compute_elbo = TRUE,
  exdqlm.use_cpp_samplers = FALSE,
  exdqlm.use_cpp_postpred = FALSE,
  exdqlm.use_cpp_mcmc = TRUE,
  exdqlm.cpp_mcmc_mode = "fast",
  exdqlm.max_iter = safe_int(cfg$vb$max_iter, 300L),
  exdqlm.tol_sigma = safe_num(cfg$vb$tol_sigma, 0.02),
  exdqlm.tol_gamma = safe_num(cfg$vb$tol_gamma, 0.01),
  exdqlm.tol_elbo = safe_num(cfg$vb$tol_elbo, 5),
  exdqlm.vb.min_iter = safe_int(cfg$vb$min_iter, 30L),
  exdqlm.vb.patience = safe_int(cfg$vb$patience, 5L),
  exdqlm.vb.allow_elbo_drop = safe_num(cfg$vb$allow_elbo_drop, 5)
)
on.exit(options(old_opts), add = TRUE)

model_filter <- safe_chr_vec(Sys.getenv("EXDQLM_DYNAMIC_RESUME_MODELS", ""), default = c("exdqlm", "dqlm"))
model_filter <- unique(tolower(model_filter))
model_filter <- model_filter[model_filter %in% c("exdqlm", "dqlm")]
if (!length(model_filter)) stop("No valid EXDQLM_DYNAMIC_RESUME_MODELS resolved.")

tasks <- expand.grid(model = model_filter, tau = p_vec, stringsAsFactors = FALSE)
tasks$seed <- vapply(seq_len(nrow(tasks)), function(i) {
  seed_from_status(tasks$model[i], tasks$tau[i], 202603060L + i * 1000L)
}, integer(1))

log_master(sprintf("dynamic resume start | run_root=%s | dry_run=%s | cores=%d", run_root, dry_run, cores))
log_master(sprintf(
  "dynamic resume mcmc config | burn=%d | keep=%d | mh_primary=%s | trace=%s | trace_every=%d | verbose=%s",
  mcmc_burn, mcmc_n, mh_primary_proposal, mcmc_trace_diagnostics, mcmc_trace_every, mcmc_verbose
))

safe_task <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)

  vb_file <- file.path(run_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  m_file <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))

  if (file.exists(m_file)) {
    log_task(model_name, tau, "resume skip: mcmc fit already exists")
    return(data.frame(model = model_name, tau = tau, status = "skipped_existing", mcmc_file = m_file, stringsAsFactors = FALSE))
  }
  if (!file.exists(vb_file)) {
    msg <- sprintf("missing VB fit file: %s", vb_file)
    write_status(model_name, tau, "FAILED", msg)
    return(data.frame(model = model_name, tau = tau, status = "failed", error = msg, stringsAsFactors = FALSE))
  }

  if (dry_run) {
    log_task(model_name, tau, "dry-run pending task")
    return(data.frame(model = model_name, tau = tau, status = "pending", vb_file = vb_file, stringsAsFactors = FALSE))
  }

  write_status(model_name, tau, "RESUME_MCMC_START", sprintf("seed=%d", seed))
  log_task(model_name, tau, sprintf("resume mcmc start seed=%d", seed))

  vb_obj <- readRDS(vb_file)
  vb_fit <- vb_obj$fit
  df_used <- if (!is.null(vb_obj$meta$df_used)) as.numeric(vb_obj$meta$df_used)[1] else 0.995

  t0 <- Sys.time()
  out <- tryCatch(
    fit_mcmc_with_vb(model_name, tau, seed + 700000L, vb_fit, df_used),
    error = function(e) e
  )
  if (inherits(out, "error")) {
    write_status(model_name, tau, "FAILED", conditionMessage(out))
    log_task(model_name, tau, paste("resume failed:", conditionMessage(out)))
    return(data.frame(model = model_name, tau = tau, status = "failed", error = conditionMessage(out), stringsAsFactors = FALSE))
  }

  runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(
    list(
      fit = out$fit,
      meta = list(
        model = model_name,
        tau = tau,
        seed = seed,
        runtime_sec = runtime,
        df_used = df_used,
        attempt_id = out$attempt_id,
        mh_proposal = out$mh_proposal,
        joint_sample = out$joint_sample,
        resumed = TRUE
      )
    ),
    m_file,
    compress = "xz"
  )

  ess_sigma <- if (!is.null(out$fit$diagnostics$ess$sigma)) as.numeric(out$fit$diagnostics$ess$sigma)[1] else NA_real_
  ess_gamma <- if (!is.null(out$fit$diagnostics$ess$gamma)) as.numeric(out$fit$diagnostics$ess$gamma)[1] else NA_real_

  write_status(model_name, tau, "MCMC_DONE", sprintf("runtime_sec=%.1f attempt=%d ess_sigma=%.2f ess_gamma=%.2f", runtime, out$attempt_id, ess_sigma, ess_gamma))
  log_task(model_name, tau, sprintf("resume mcmc done runtime=%.1fs attempt=%d", runtime, out$attempt_id))

  data.frame(
    model = model_name,
    tau = tau,
    status = "done",
    runtime_sec = runtime,
    attempt_id = out$attempt_id,
    ess_sigma = ess_sigma,
    ess_gamma = ess_gamma,
    mcmc_file = m_file,
    stringsAsFactors = FALSE
  )
}

task_list <- split(tasks, seq_len(nrow(tasks)))
out <- if (.Platform$OS.type == "unix" && cores > 1L) {
  parallel::mclapply(task_list, safe_task, mc.cores = cores, mc.preschedule = FALSE)
} else {
  lapply(task_list, safe_task)
}
bind_rows_fill <- function(lst) {
  cols <- unique(unlist(lapply(lst, names)))
  aligned <- lapply(lst, function(df) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) for (m in miss) df[[m]] <- NA
    df[, cols, drop = FALSE]
  })
  do.call(rbind, aligned)
}
resume_df <- bind_rows_fill(out)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
resume_csv <- file.path(run_root, "tables", sprintf("pipeline_task_summary_resume_dynamic_%s.csv", stamp))
utils::write.csv(resume_df, resume_csv, row.names = FALSE)

log_master(sprintf("dynamic resume complete | summary=%s", resume_csv))
bad_rows <- resume_df[!(resume_df$status %in% c("done", "skipped_existing")), , drop = FALSE]
if (nrow(bad_rows)) {
  stop(
    sprintf(
      "Dynamic resume finished with incomplete tasks: %s",
      paste(sprintf("%s@tau=%s:%s", bad_rows$model, bad_rows$tau, bad_rows$status), collapse = ", ")
    ),
    call. = FALSE
  )
}
cat(sprintf("Dynamic resume complete. Summary: %s\n", resume_csv))
