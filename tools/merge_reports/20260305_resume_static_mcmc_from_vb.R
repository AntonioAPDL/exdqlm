#!/usr/bin/env Rscript

suppressPackageStartupMessages({
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

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_bool <- function(x, default = FALSE) {
  z <- tolower(trimws(as.character(x)[1]))
  if (z %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (z %in% c("false", "f", "0", "no", "n")) return(FALSE)
  default
}

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

safe_chr_vec <- function(x, default = NULL) {
  if (!nzchar(x)) return(default)
  vals <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  vals <- vals[nzchar(vals)]
  if (!length(vals)) return(default)
  vals
}

is_true_env <- function(name, default = "false") {
  raw <- Sys.getenv(name, default)
  tolower(raw) %in% c("1", "true", "yes", "on")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

normalize_prior_type <- function(x, default = "ridge") {
  val <- tolower(trimws(as.character(x %||% default)[1]))
  if (!nzchar(val) || is.na(val)) val <- default
  if (identical(val, "gaussian")) val <- "ridge"
  if (!(val %in% c("ridge", "rhs"))) val <- default
  val
}

cfg_path <- Sys.getenv(
  "EXDQLM_STATIC_RUN_CONFIG",
  "results/sim_suite_static/static_vb_then_mcmc_tt5000_vbns1000_burn2000_n1000_20260304_194203/tables/run_config.rds"
)
if (!file.exists(cfg_path)) stop("Missing config: ", cfg_path)
cfg <- readRDS(cfg_path)
run_root <- as.character(cfg$out_root)
if (!dir.exists(run_root)) stop("run_root not found: ", run_root)

sim <- readRDS(cfg$sim_path)
TT <- as.integer(cfg$TT)
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])

p_vec <- as.numeric(cfg$taus)
mcmc_burn <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_BURN", as.character(cfg$mcmc$burn)), safe_int(cfg$mcmc$burn, 500L))
mcmc_n <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_N", as.character(cfg$mcmc$n)), safe_int(cfg$mcmc$n, 1000L))
mcmc_thin <- safe_int(cfg$mcmc$thin, 1L)
mcmc_mh_proposal <- tolower(Sys.getenv(
  "EXDQLM_STATIC_MCMC_MH_PROPOSAL",
  if (!is.null(cfg$mcmc$mh$proposal)) as.character(cfg$mcmc$mh$proposal)[1] else "laplace_rw"
))
if (!(mcmc_mh_proposal %in% c("laplace_local", "laplace_rw", "rw"))) mcmc_mh_proposal <- "laplace_rw"
mcmc_mh_adapt <- identical(tolower(Sys.getenv(
  "EXDQLM_STATIC_MCMC_MH_ADAPT",
  if (!is.null(cfg$mcmc$mh$adapt)) as.character(cfg$mcmc$mh$adapt)[1] else "true"
)), "true")
mcmc_mh_adapt_interval <- safe_int(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_ADAPT_INTERVAL", as.character(cfg$mcmc$mh$adapt_interval)),
  safe_int(cfg$mcmc$mh$adapt_interval, 50L)
)
mcmc_mh_target <- if (!is.null(cfg$mcmc$mh$target_accept)) as.numeric(cfg$mcmc$mh$target_accept) else c(0.20, 0.45)
if (length(mcmc_mh_target) != 2L || any(!is.finite(mcmc_mh_target))) mcmc_mh_target <- c(0.20, 0.45)
mcmc_mh_scale_bounds <- if (!is.null(cfg$mcmc$mh$scale_bounds)) as.numeric(cfg$mcmc$mh$scale_bounds) else c(0.1, 10)
if (length(mcmc_mh_scale_bounds) != 2L || any(!is.finite(mcmc_mh_scale_bounds))) mcmc_mh_scale_bounds <- c(0.1, 10)
mcmc_mh_max_scale_step <- safe_num(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_MAX_SCALE_STEP", as.character(cfg$mcmc$mh$max_scale_step)),
  safe_num(cfg$mcmc$mh$max_scale_step, 0.35)
)
mcmc_mh_min_burn_adapt <- safe_int(
  Sys.getenv("EXDQLM_STATIC_MCMC_MH_MIN_BURN_ADAPT", as.character(cfg$mcmc$mh$min_burn_adapt)),
  safe_int(cfg$mcmc$mh$min_burn_adapt, 50L)
)
mcmc_trace_diagnostics <- identical(tolower(Sys.getenv("EXDQLM_STATIC_MCMC_TRACE_DIAGNOSTICS", "true")), "true")
mcmc_trace_every <- safe_int(Sys.getenv("EXDQLM_STATIC_MCMC_TRACE_EVERY", "25"), 25L)
if (mcmc_trace_every < 1L) mcmc_trace_every <- 1L
mcmc_verbose <- identical(tolower(Sys.getenv("EXDQLM_STATIC_MCMC_VERBOSE", "true")), "true")
beta_prior <- normalize_prior_type(
  Sys.getenv(
    "EXDQLM_STATIC_BETA_PRIOR",
    if (!is.null(cfg$mcmc$beta_prior)) as.character(cfg$mcmc$beta_prior)[1] else "ridge"
  )
)
beta_prior_controls <- cfg$mcmc$beta_prior_controls
if (is.null(beta_prior_controls) && !is.null(cfg$vb$beta_prior_controls)) {
  beta_prior_controls <- cfg$vb$beta_prior_controls
}
if (is.null(beta_prior_controls) || !is.list(beta_prior_controls)) {
  beta_prior_controls <- list()
}
enforce_prior_match <- safe_bool(Sys.getenv("EXDQLM_STATIC_ENFORCE_PRIOR_MATCH", "true"), TRUE)

cores <- safe_int(Sys.getenv("EXDQLM_STATIC_RESUME_CORES", as.character(cfg$cores_pipeline)), safe_int(cfg$cores_pipeline, 2L))
cores <- max(1L, min(cores, safe_int(parallel::detectCores(logical = FALSE), 2L)))
dry_run <- identical(tolower(Sys.getenv("EXDQLM_STATIC_RESUME_DRYRUN", "0")), "1")
force_resume_overwrite <- is_true_env(
  "EXDQLM_STATIC_RESUME_OVERWRITE",
  if (is_true_env("EXDQLM_RESUME_OVERWRITE", "false")) "true" else "false"
)

status_dir <- file.path(run_root, "logs")
master_log <- file.path(status_dir, "resume_static_master.log")

task_key <- function(model_name, tau) sprintf("%s_tau_%s", model_name, tau_lab(tau))
task_log_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".log"))
task_status_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".status.tsv"))
task_progress_file <- function(model_name, tau) file.path(status_dir, paste0(task_key(model_name, tau), ".progress.tsv"))

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

ensure_progress_header <- function(model_name, tau) {
  pf <- task_progress_file(model_name, tau)
  if (!file.exists(pf)) {
    cat(
      paste(
        c(
          "timestamp", "event", "phase", "iter", "total_iter",
          "n_burn", "n_mcmc", "thin", "kept_completed", "kept_target",
          "sigma", "gamma", "kernel", "accept", "runtime_sec"
        ),
        collapse = "\t"
      ),
      "\n",
      file = pf,
      append = FALSE
    )
  }
  invisible(pf)
}

fmt_num <- function(x, digits = 6L) {
  x <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(x) || is.na(x)) return("")
  formatC(x, format = "fg", digits = digits, flag = "#")
}

append_progress <- function(model_name, tau, info) {
  pf <- ensure_progress_header(model_name, tau)
  fields <- c(
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    as.character(info$event %||% ""),
    as.character(info$phase %||% ""),
    as.character(as.integer(info$iter %||% NA_integer_)),
    as.character(as.integer(info$total_iter %||% NA_integer_)),
    as.character(as.integer(info$n_burn %||% NA_integer_)),
    as.character(as.integer(info$n_mcmc %||% NA_integer_)),
    as.character(as.integer(info$thin %||% NA_integer_)),
    as.character(as.integer(info$kept_completed %||% NA_integer_)),
    as.character(as.integer(info$kept_target %||% NA_integer_)),
    fmt_num(info$sigma),
    fmt_num(info$gamma),
    as.character(info$kernel %||% ""),
    fmt_num(info$accept),
    fmt_num(info$runtime_sec)
  )
  cat(paste(fields, collapse = "\t"), "\n", file = pf, append = TRUE)
}

progress_note <- function(info) {
  paste(
    sprintf("event=%s", as.character(info$event %||% "")),
    sprintf("phase=%s", as.character(info$phase %||% "")),
    sprintf("iter=%d/%d", as.integer(info$iter %||% 0L), as.integer(info$total_iter %||% 0L)),
    sprintf("kept=%d/%d", as.integer(info$kept_completed %||% 0L), as.integer(info$kept_target %||% 0L)),
    sprintf("sigma=%s", fmt_num(info$sigma)),
    sprintf("gamma=%s", fmt_num(info$gamma)),
    sprintf("kernel=%s", as.character(info$kernel %||% "")),
    sprintf("acc=%s", fmt_num(info$accept)),
    sep = " "
  )
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

model_filter <- safe_chr_vec(Sys.getenv("EXDQLM_STATIC_RESUME_MODELS", ""), default = c("exal", "al"))
model_filter <- unique(tolower(model_filter))
model_filter <- model_filter[model_filter %in% c("exal", "al")]
if (!length(model_filter)) stop("No valid EXDQLM_STATIC_RESUME_MODELS resolved.")

tasks <- expand.grid(model = model_filter, tau = p_vec, stringsAsFactors = FALSE)
tasks$seed <- vapply(seq_len(nrow(tasks)), function(i) {
  seed_from_status(tasks$model[i], tasks$tau[i], 202603050L + i * 1000L)
}, integer(1))

log_master(sprintf("static resume start | run_root=%s | dry_run=%s | cores=%d", run_root, dry_run, cores))
log_master(sprintf(
  "static resume mcmc config | burn=%d | keep=%d | thin=%d | mh=%s | trace=%s | trace_every=%d | verbose=%s | beta_prior=%s | enforce_prior_match=%s",
  mcmc_burn, mcmc_n, mcmc_thin, mcmc_mh_proposal, mcmc_trace_diagnostics, mcmc_trace_every, mcmc_verbose,
  beta_prior, enforce_prior_match
))

safe_task <- function(task_row) {
  model_name <- as.character(task_row$model)
  tau <- as.numeric(task_row$tau)
  seed <- as.integer(task_row$seed)
  dqlm.ind <- identical(model_name, "al")

  vb_file <- file.path(run_root, "fits", "vb", sprintf("vb_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))
  m_file <- file.path(run_root, "fits", "mcmc", sprintf("mcmc_%s_tau_%s_fit.rds", model_name, tau_lab(tau)))

  if (file.exists(m_file) && !force_resume_overwrite) {
    log_task(model_name, tau, "resume skip: mcmc fit already exists")
    return(data.frame(model = model_name, tau = tau, status = "skipped_existing", mcmc_file = m_file, stringsAsFactors = FALSE))
  }
  if (file.exists(m_file) && force_resume_overwrite) {
    write_status(model_name, tau, "RESUME_FORCE_OVERWRITE", sprintf("existing_mcmc=%s", basename(m_file)))
    log_task(model_name, tau, "resume overwrite: existing mcmc fit will be replaced")
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
  ensure_progress_header(model_name, tau)

  vb_obj <- readRDS(vb_file)
  vb_fit <- vb_obj$fit
  vb_prior <- normalize_prior_type(if (!is.null(vb_fit$beta_prior$type)) vb_fit$beta_prior$type else beta_prior, default = beta_prior)
  if (enforce_prior_match && !identical(vb_prior, beta_prior)) {
    msg <- sprintf("VB prior mismatch with run config: expected=%s observed=%s", beta_prior, vb_prior)
    write_status(model_name, tau, "FAILED", msg)
    log_task(model_name, tau, paste("resume failed:", msg))
    return(data.frame(model = model_name, tau = tau, status = "failed", error = msg, stringsAsFactors = FALSE))
  }

  init_list <- .static_vb_to_mcmc_init(vb_fit, dqlm.ind = dqlm.ind)
  init_notes <- attr(init_list, "resume_init_notes")
  if (length(init_notes)) {
    note <- paste(init_notes, collapse = "; ")
    write_status(model_name, tau, "RESUME_INIT_SANITIZED", note)
    log_task(model_name, tau, sprintf("resume init sanitized | %s", note))
  }

  set.seed(seed + 700000L)
  t0 <- Sys.time()
  m_fit <- tryCatch(
    exal_static_mcmc(
      y = y,
      X = X,
      p0 = tau,
      dqlm.ind = dqlm.ind,
      beta_prior = beta_prior,
      beta_prior_controls = beta_prior_controls,
      init = init_list,
      init.from.vb = FALSE,
      n.burn = mcmc_burn,
      n.mcmc = mcmc_n,
      thin = mcmc_thin,
      mh.proposal = mcmc_mh_proposal,
      mh.adapt = mcmc_mh_adapt,
      mh.adapt.interval = mcmc_mh_adapt_interval,
      mh.target.accept = mcmc_mh_target,
      mh.scale.bounds = mcmc_mh_scale_bounds,
      mh.max_scale.step = mcmc_mh_max_scale_step,
      mh.min_burn_adapt = mcmc_mh_min_burn_adapt,
      trace.diagnostics = mcmc_trace_diagnostics,
      trace.every = mcmc_trace_every,
      verbose = mcmc_verbose,
      progress_callback = function(info) {
        append_progress(model_name, tau, info)
        if (identical(info$event, "progress")) {
          write_status(model_name, tau, "MCMC_PROGRESS", progress_note(info))
        }
      }
    ),
    error = function(e) e
  )

  if (inherits(m_fit, "error")) {
    write_status(model_name, tau, "FAILED", conditionMessage(m_fit))
    log_task(model_name, tau, paste("resume failed:", conditionMessage(m_fit)))
    return(data.frame(model = model_name, tau = tau, status = "failed", error = conditionMessage(m_fit), stringsAsFactors = FALSE))
  }

  fit_prior <- normalize_prior_type(if (!is.null(m_fit$beta_prior$type)) m_fit$beta_prior$type else "ridge")
  if (enforce_prior_match && !identical(fit_prior, beta_prior)) {
    msg <- sprintf("MCMC prior mismatch: expected=%s observed=%s", beta_prior, fit_prior)
    write_status(model_name, tau, "FAILED", msg)
    log_task(model_name, tau, paste("resume failed:", msg))
    return(data.frame(model = model_name, tau = tau, status = "failed", error = msg, stringsAsFactors = FALSE))
  }
  if (enforce_prior_match && identical(beta_prior, "rhs")) {
    has_rhs_draws <- !is.null(m_fit$samp.tau) && !is.null(m_fit$samp.c2) && !is.null(m_fit$samp.lambda)
    if (!has_rhs_draws) {
      msg <- "MCMC RHS diagnostics missing (samp.tau/c2/lambda); refusing inconsistent fit"
      write_status(model_name, tau, "FAILED", msg)
      log_task(model_name, tau, paste("resume failed:", msg))
      return(data.frame(model = model_name, tau = tau, status = "failed", error = msg, stringsAsFactors = FALSE))
    }
  }

  runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  norm <- .static_normalize_mcmc_fit(
    m_fit,
    model_name = model_name,
    tau = tau,
    run_settings = list(
      n_burn = mcmc_burn,
      n_mcmc = mcmc_n,
      thin = mcmc_thin,
      resumed = TRUE,
      mh = list(
        proposal = mcmc_mh_proposal,
        adapt = mcmc_mh_adapt,
        adapt_interval = mcmc_mh_adapt_interval,
        target_accept = mcmc_mh_target,
        scale_bounds = mcmc_mh_scale_bounds,
        max_scale_step = mcmc_mh_max_scale_step,
        min_burn_adapt = mcmc_mh_min_burn_adapt
      )
    )
  )

  saveRDS(
    list(
      fit = m_fit,
      normalized = norm,
      meta = list(
        model = model_name,
        tau = tau,
        seed = seed,
        runtime_sec = runtime,
        resumed = TRUE,
        beta_prior = fit_prior
      )
    ),
    m_file,
    compress = "xz"
  )

  write_status(
    model_name,
    tau,
    "MCMC_DONE",
    sprintf(
      "runtime_sec=%.1f ess_sigma=%.2f ess_gamma=%.2f beta_prior=%s",
      runtime, norm$diagnostics$ess$sigma, norm$diagnostics$ess$gamma, fit_prior
    )
  )
  log_task(model_name, tau, sprintf("resume mcmc done runtime=%.1fs beta_prior=%s", runtime, fit_prior))

  data.frame(
    model = model_name,
    tau = tau,
    status = "done",
    runtime_sec = runtime,
    ess_sigma = norm$diagnostics$ess$sigma,
    ess_gamma = norm$diagnostics$ess$gamma,
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
resume_csv <- file.path(run_root, "tables", sprintf("pipeline_task_summary_resume_static_%s.csv", stamp))
utils::write.csv(resume_df, resume_csv, row.names = FALSE)

log_master(sprintf("static resume complete | summary=%s", resume_csv))
if (dry_run) {
  cat(sprintf("Static resume dry-run complete. Summary: %s\n", resume_csv))
  quit(save = "no", status = 0L)
}
bad_rows <- resume_df[!(resume_df$status %in% c("done", "skipped_existing")), , drop = FALSE]
if (nrow(bad_rows)) {
  stop(
    sprintf(
      "Static resume finished with incomplete tasks: %s",
      paste(sprintf("%s@tau=%s:%s", bad_rows$model, bad_rows$tau, bad_rows$status), collapse = ", ")
    ),
    call. = FALSE
  )
}
cat(sprintf("Static resume complete. Summary: %s\n", resume_csv))
