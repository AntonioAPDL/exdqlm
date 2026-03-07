#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
  library(parallel)
})

devtools::load_all(".", quiet = TRUE)

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

tau_lab <- function(tau) gsub("\\.", "p", format(as.numeric(tau), nsmall = 2))

safe_tau_vec <- function(x, default = c(0.05, 0.50, 0.95)) {
  vals <- suppressWarnings(as.numeric(strsplit(x, ",", fixed = TRUE)[[1]]))
  vals <- vals[is.finite(vals) & vals > 0 & vals < 1]
  vals <- unique(round(vals, 6))
  if (!length(vals)) default else vals
}

flip_rate <- function(z) {
  z <- as.numeric(z)
  z <- z[is.finite(z)]
  if (length(z) < 3L) return(NA_real_)
  dz <- diff(z)
  s <- sign(dz)
  s <- s[s != 0]
  if (length(s) < 2L) return(0)
  mean(s[-1] != s[-length(s)])
}

tail_window <- function(z, start = 20L) {
  z <- as.numeric(z)
  idx <- seq_along(z)
  keep <- idx >= start & is.finite(z)
  z[keep]
}

tail_summary <- function(z, start = 20L) {
  zz <- tail_window(z, start = start)
  list(
    sd = if (length(zz) >= 2L) stats::sd(zz) else NA_real_,
    range = if (length(zz) >= 1L) diff(range(zz, finite = TRUE)) else NA_real_,
    flip_rate = flip_rate(zz),
    last = if (length(zz)) utils::tail(zz, 1L) else NA_real_,
    median_abs = if (length(zz)) stats::median(abs(zz), na.rm = TRUE) else NA_real_
  )
}

replace_nonfinite <- function(x, default = 0) {
  x <- as.numeric(x)
  x[!is.finite(x) | is.na(x)] <- default
  x
}

max_or_na <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else max(x)
}

ld_profile_grid <- function(base_ctrl) {
  list(
    base = utils::modifyList(base_ctrl, list(profile_name = "base")),
    balanced = utils::modifyList(base_ctrl, list(
      profile_name = "balanced",
      damping = 0.35,
      xi_damping = 0.50,
      step_cap_eta = 1.00,
      step_cap_ell = 0.40,
      eig_cap = min(base_ctrl$eig_cap, 15),
      optimizer_maxit = max(base_ctrl$optimizer_maxit, 300L)
    )),
    stable = utils::modifyList(base_ctrl, list(
      profile_name = "stable",
      damping = 0.25,
      xi_damping = 0.35,
      step_cap_eta = 0.75,
      step_cap_ell = 0.25,
      eig_cap = min(base_ctrl$eig_cap, 10),
      optimizer_maxit = max(base_ctrl$optimizer_maxit, 300L)
    ))
  )
}

sim_path <- Sys.getenv(
  "EXDQLM_STATIC_SIM_PATH",
  "results/sim_suite_static/series/static_exal_rich1d_mcq/sim_output.rds"
)
if (!file.exists(sim_path)) stop("Simulation file not found: ", sim_path)
sim <- readRDS(sim_path)

TT_full <- length(sim$y)
TT <- min(TT_full, safe_int(Sys.getenv("EXDQLM_STATIC_SCREEN_TT", "5000"), 5000L))
y <- as.numeric(sim$y[seq_len(TT)])
X <- as.matrix(sim$extras$X[seq_len(TT), , drop = FALSE])
taus <- safe_tau_vec(Sys.getenv("EXDQLM_STATIC_SCREEN_TAUS", "0.05,0.50,0.95"))

vb_n_samp <- safe_int(Sys.getenv("EXDQLM_STATIC_SCREEN_VB_NSAMP", "1000"), 1000L)
vb_max_grid <- as.integer(strsplit(Sys.getenv("EXDQLM_STATIC_SCREEN_VB_MAX_GRID", "300,500"), ",", fixed = TRUE)[[1]])
vb_max_grid <- vb_max_grid[is.finite(vb_max_grid) & vb_max_grid >= 50L]
if (!length(vb_max_grid)) vb_max_grid <- c(300L, 500L)
vb_tol <- safe_num(Sys.getenv("EXDQLM_STATIC_SCREEN_VB_TOL", "0.03"), 0.03)

ld_ctrl <- list(
  damping = safe_num(Sys.getenv("EXDQLM_STATIC_LD_DAMPING", "0.45"), 0.45),
  xi_damping = safe_num(Sys.getenv("EXDQLM_STATIC_LD_XI_DAMPING", "0.65"), 0.65),
  step_cap_eta = safe_num(Sys.getenv("EXDQLM_STATIC_LD_STEP_CAP_ETA", "2.0"), 2.0),
  step_cap_ell = safe_num(Sys.getenv("EXDQLM_STATIC_LD_STEP_CAP_ELL", "0.75"), 0.75),
  eig_floor = safe_num(Sys.getenv("EXDQLM_STATIC_LD_EIG_FLOOR", "1e-6"), 1e-6),
  eig_cap = safe_num(Sys.getenv("EXDQLM_STATIC_LD_EIG_CAP", "25"), 25),
  optimizer_maxit = safe_int(Sys.getenv("EXDQLM_STATIC_LD_OPTIMIZER_MAXIT", "200"), 200L)
)
ld_profiles <- ld_profile_grid(ld_ctrl)
selected_profiles <- strsplit(Sys.getenv("EXDQLM_STATIC_SCREEN_LD_PROFILES", "base,balanced,stable"), ",", fixed = TRUE)[[1]]
selected_profiles <- unique(trimws(tolower(selected_profiles)))
selected_profiles <- selected_profiles[selected_profiles %in% names(ld_profiles)]
if (!length(selected_profiles)) selected_profiles <- names(ld_profiles)
ld_profiles <- ld_profiles[selected_profiles]
ld_trace_start <- safe_int(Sys.getenv("EXDQLM_STATIC_TRACE_START", "20"), 20L)

mcmc_burn <- safe_int(Sys.getenv("EXDQLM_STATIC_SCREEN_MCMC_BURN", "250"), 250L)
mcmc_n <- safe_int(Sys.getenv("EXDQLM_STATIC_SCREEN_MCMC_N", "200"), 200L)
mcmc_kernels <- strsplit(Sys.getenv("EXDQLM_STATIC_SCREEN_MCMC_KERNELS", "laplace_local,laplace_rw,rw"), ",", fixed = TRUE)[[1]]
mcmc_kernels <- unique(trimws(tolower(mcmc_kernels)))
mcmc_kernels <- mcmc_kernels[mcmc_kernels %in% c("laplace_local", "laplace_rw", "rw")]
if (!length(mcmc_kernels)) mcmc_kernels <- c("laplace_local", "laplace_rw", "rw")

n_core_phys <- tryCatch(parallel::detectCores(logical = FALSE), error = function(e) 2L)
if (!is.finite(n_core_phys) || n_core_phys < 1L) n_core_phys <- 2L
cores <- max(1L, min(safe_int(Sys.getenv("EXDQLM_STATIC_SCREEN_CORES", "3"), 3L), n_core_phys))

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
out_root <- file.path("results", "sim_suite_static", sprintf("screen_exal_tuning_tt%d_%s", TT, stamp))
dir.create(file.path(out_root, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_root, "logs"), recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(out_root, "logs", "screen.log")
log_msg <- function(...) {
  line <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "|", paste(..., collapse = " "))
  cat(line, "\n")
  cat(line, "\n", file = log_file, append = TRUE)
}

run_vb <- function(profile_name, profile_ctrl, max_iter, tau, seed) {
  set.seed(seed)
  t0 <- Sys.time()
  fit <- exal_static_LDVB(
    y = y,
    X = X,
    p0 = tau,
    max_iter = max_iter,
    tol = vb_tol,
    n_samp_xi = vb_n_samp,
    ld_controls = profile_ctrl,
    verbose = FALSE
  )
  runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  ld_trace <- fit$diagnostics$ld_block$trace
  sigma_tail <- tail_summary(if (is.null(fit$seq.sigma)) numeric(0) else fit$seq.sigma, start = ld_trace_start)
  gamma_tail <- tail_summary(if (is.null(fit$seq.gamma)) numeric(0) else fit$seq.gamma, start = ld_trace_start)
  xi_tail <- tail_summary(if (is.data.frame(ld_trace) && "xi_rel_drift" %in% names(ld_trace)) ld_trace$xi_rel_drift else numeric(0), start = ld_trace_start)
  data.frame(
    profile = profile_name,
    tau = tau,
    vb_max_iter = max_iter,
    runtime_sec = runtime,
    converged = isTRUE(fit$converged),
    iter = as.integer(fit$iter),
    stop_reason = as.character(fit$diagnostics$convergence$stop_reason)[1],
    delta_sigma_last = utils::tail(as.numeric(fit$diagnostics$deltas$sigma), 1),
    delta_gamma_last = utils::tail(as.numeric(fit$diagnostics$deltas$gamma), 1),
    ld_xi_rel_drift_last = if (is.data.frame(ld_trace) && nrow(ld_trace)) as.numeric(ld_trace$xi_rel_drift[nrow(ld_trace)]) else NA_real_,
    ld_cov_condition_last = if (is.data.frame(ld_trace) && nrow(ld_trace)) as.numeric(ld_trace$ld_cov_condition[nrow(ld_trace)]) else NA_real_,
    ld_sigma_sd_tail = sigma_tail$sd,
    ld_sigma_flip_rate_tail = sigma_tail$flip_rate,
    ld_gamma_sd_tail = gamma_tail$sd,
    ld_gamma_flip_rate_tail = gamma_tail$flip_rate,
    ld_xi_median_abs_tail = xi_tail$median_abs,
    ld_xi_flip_rate_tail = xi_tail$flip_rate,
    fit = I(list(fit)),
    stringsAsFactors = FALSE
  )
}

log_msg("starting static exAL tuning screen", sprintf("out_root=%s", out_root), sprintf("taus=%s", paste(format(taus, nsmall = 2), collapse = ",")))
vb_jobs <- expand.grid(profile = names(ld_profiles), vb_max_iter = vb_max_grid, tau = taus, stringsAsFactors = FALSE)
vb_jobs$seed <- 202603051L + seq_len(nrow(vb_jobs)) * 100L
vb_out <- if (.Platform$OS.type == "unix" && cores > 1L) {
  parallel::mclapply(
    split(vb_jobs, seq_len(nrow(vb_jobs))),
    function(row) {
      prof <- as.character(row$profile[1])
      run_vb(
        profile_name = prof,
        profile_ctrl = ld_profiles[[prof]],
        max_iter = row$vb_max_iter[1],
        tau = row$tau[1],
        seed = row$seed[1]
      )
    },
    mc.cores = cores,
    mc.preschedule = FALSE
  )
} else {
  lapply(split(vb_jobs, seq_len(nrow(vb_jobs))), function(row) {
    prof <- as.character(row$profile[1])
    run_vb(
      profile_name = prof,
      profile_ctrl = ld_profiles[[prof]],
      max_iter = row$vb_max_iter[1],
      tau = row$tau[1],
      seed = row$seed[1]
    )
  })
}
vb_df <- do.call(rbind, vb_out)
utils::write.csv(vb_df[setdiff(names(vb_df), "fit")], file.path(out_root, "tables", "vb_screen_summary.csv"), row.names = FALSE)

vb_df$vb_penalty <- with(
  vb_df,
  ifelse(converged, 0, 1000) +
    ifelse(stop_reason == "max_iter", 400, 0) +
    80 * pmin(abs(replace_nonfinite(delta_sigma_last, 0)), 1) +
    80 * pmin(abs(replace_nonfinite(delta_gamma_last, 0)), 1) +
    120 * pmin(replace_nonfinite(ld_xi_median_abs_tail, 0), 1) +
    60 * pmin(replace_nonfinite(ld_sigma_flip_rate_tail, 0), 1) +
    60 * pmin(replace_nonfinite(ld_gamma_flip_rate_tail, 0), 1) +
    10 * pmin(replace_nonfinite(runtime_sec, 0) / 60, 10)
)

vb_rank_rows <- list()
for (prof in unique(vb_df$profile)) {
  for (mi in sort(unique(vb_df$vb_max_iter))) {
    dd <- vb_df[vb_df$profile == prof & vb_df$vb_max_iter == mi, , drop = FALSE]
    if (!nrow(dd)) next
    vb_rank_rows[[length(vb_rank_rows) + 1L]] <- data.frame(
      profile = prof,
      vb_max_iter = mi,
      tasks = nrow(dd),
      all_taus_present = nrow(dd) == length(taus),
      all_converged = nrow(dd) == length(taus) && all(dd$converged),
      mean_penalty = mean(dd$vb_penalty, na.rm = TRUE),
      max_xi_median_abs_tail = max_or_na(dd$ld_xi_median_abs_tail),
      max_sigma_flip_rate_tail = max_or_na(dd$ld_sigma_flip_rate_tail),
      max_gamma_flip_rate_tail = max_or_na(dd$ld_gamma_flip_rate_tail),
      mean_runtime_sec = mean(dd$runtime_sec, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }
}
vb_rank <- do.call(rbind, vb_rank_rows)
vb_rank <- vb_rank[order(
  -vb_rank$all_taus_present,
  -vb_rank$all_converged,
  vb_rank$mean_penalty,
  vb_rank$vb_max_iter
), , drop = FALSE]
utils::write.csv(vb_rank, file.path(out_root, "tables", "vb_profile_ranking.csv"), row.names = FALSE)

vb_best_row <- vb_rank[1, , drop = FALSE]
vb_profile_reco <- as.character(vb_best_row$profile[1])
vb_reco <- as.integer(vb_best_row$vb_max_iter[1])
log_msg(sprintf("recommended static exAL LD profile=%s", vb_profile_reco))
log_msg(sprintf("recommended static exAL VB max_iter=%d", vb_reco))
log_msg("starting static exAL kernel screen", sprintf("kernels=%s", paste(mcmc_kernels, collapse = ",")))

vb_best <- vb_df[vb_df$profile == vb_profile_reco & vb_df$vb_max_iter == vb_reco, , drop = FALSE]

run_mcmc <- function(kernel, tau, fit_row, seed) {
  set.seed(seed)
  init <- .static_vb_to_mcmc_init(fit_row$fit[[1]], dqlm.ind = FALSE)
  t0 <- Sys.time()
  fit <- exal_static_mcmc(
    y = y,
    X = X,
    p0 = tau,
    init = init,
    init.from.vb = FALSE,
    n.burn = mcmc_burn,
    n.mcmc = mcmc_n,
    thin = 1,
    mh.proposal = kernel,
    mh.adapt = TRUE,
    mh.adapt.interval = 25L,
    verbose = FALSE
  )
  runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  data.frame(
    tau = tau,
    kernel = kernel,
    runtime_sec = runtime,
    ess_sigma = as.numeric(fit$diagnostics$ess$sigma)[1],
    ess_gamma = as.numeric(fit$diagnostics$ess$gamma)[1],
    accept_rate = as.numeric(fit$accept.rate)[1],
    accept_rate_burn = as.numeric(fit$accept.rate.burn)[1],
    accept_rate_keep = as.numeric(fit$accept.rate.keep)[1],
    scale_final = if (!is.null(fit$mh.diagnostics$scale_final)) as.numeric(fit$mh.diagnostics$scale_final)[1] else NA_real_,
    stringsAsFactors = FALSE
  )
}

mcmc_jobs <- expand.grid(kernel = mcmc_kernels, tau = taus, stringsAsFactors = FALSE)
mcmc_jobs$seed <- 202603071L + seq_len(nrow(mcmc_jobs)) * 200L
mcmc_out <- if (.Platform$OS.type == "unix" && cores > 1L) {
  parallel::mclapply(
    split(mcmc_jobs, seq_len(nrow(mcmc_jobs))),
    function(row) {
      fit_row <- vb_best[vb_best$tau == row$tau[1], , drop = FALSE]
      run_mcmc(kernel = row$kernel[1], tau = row$tau[1], fit_row = fit_row, seed = row$seed[1])
    },
    mc.cores = cores,
    mc.preschedule = FALSE
  )
} else {
  lapply(split(mcmc_jobs, seq_len(nrow(mcmc_jobs))), function(row) {
    fit_row <- vb_best[vb_best$tau == row$tau[1], , drop = FALSE]
    run_mcmc(kernel = row$kernel[1], tau = row$tau[1], fit_row = fit_row, seed = row$seed[1])
  })
}
mcmc_df <- do.call(rbind, mcmc_out)
utils::write.csv(mcmc_df, file.path(out_root, "tables", "mcmc_kernel_screen_summary.csv"), row.names = FALSE)

kernel_scores <- aggregate(
  cbind(ess_gamma, ess_sigma, accept_rate_keep) ~ kernel,
  data = mcmc_df,
  FUN = function(x) mean(x, na.rm = TRUE)
)
kernel_scores$exact_kernel <- kernel_scores$kernel %in% c("laplace_rw", "rw")
kernel_scores <- kernel_scores[order(-kernel_scores$exact_kernel, -kernel_scores$ess_gamma, -kernel_scores$ess_sigma), ]
kernel_reco <- as.character(kernel_scores$kernel[1])
utils::write.csv(kernel_scores, file.path(out_root, "tables", "kernel_screen_ranking.csv"), row.names = FALSE)

reco <- data.frame(
  recommended_ld_profile = vb_profile_reco,
  recommended_vb_max_iter = vb_reco,
  recommended_mcmc_kernel = kernel_reco,
  vb_tol = vb_tol,
  vb_n_samp = vb_n_samp,
  mcmc_burn = mcmc_burn,
  mcmc_n = mcmc_n,
  ld_damping = ld_profiles[[vb_profile_reco]]$damping,
  ld_xi_damping = ld_profiles[[vb_profile_reco]]$xi_damping,
  ld_step_cap_eta = ld_profiles[[vb_profile_reco]]$step_cap_eta,
  ld_step_cap_ell = ld_profiles[[vb_profile_reco]]$step_cap_ell,
  ld_eig_floor = ld_profiles[[vb_profile_reco]]$eig_floor,
  ld_eig_cap = ld_profiles[[vb_profile_reco]]$eig_cap,
  ld_optimizer_maxit = ld_profiles[[vb_profile_reco]]$optimizer_maxit,
  stringsAsFactors = FALSE
)
utils::write.csv(reco, file.path(out_root, "tables", "recommended_settings.csv"), row.names = FALSE)

log_msg(sprintf("recommended static exAL MCMC kernel=%s", kernel_reco))
log_msg("static exAL tuning screen completed")
cat(sprintf("Static exAL tuning screen complete. Outputs under: %s\n", out_root))
