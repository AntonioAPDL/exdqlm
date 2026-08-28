#!/usr/bin/env Rscript

cmd_args0 <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args0, value = TRUE)
this_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else
  "validation/fitforecast_v2/scripts/preflight_independent_exdqlm_1p1p1_rerun_v1.R"
harness_root <- normalizePath(file.path(dirname(this_file), ".."), winslash = "/", mustWork = TRUE)
source(file.path(harness_root, "R", "utils.R"))
ffv2_source_all(harness_root)
suppressPackageStartupMessages(library(exdqlm))

args <- ffv2_parse_args()
repo_root <- normalizePath(args$`repo-root` %||% ffv2_repo_root(), winslash = "/", mustWork = TRUE)
state_root <- ffv2_resolve_path(args$`state-root` %||% file.path(
  repo_root, "validation", "fitforecast_v2", "local_trackers",
  "independent_qdesn_exdqlm_1p1p1_rerun_v1_preflight"
), repo_root = repo_root, must_work = FALSE)
tarball_path <- as.character(args$tarball %||% "")[1L]
ffv2_ensure_dir(state_root)

pkg_desc <- packageDescription("exdqlm")
vb_default <- exal_make_vb_sigmagam_control()
mcmc_dynamic_default <- eval(formals(exdqlmMCMC)$mh.proposal)
mcmc_static_default <- eval(formals(exalStaticMCMC)$mh.proposal)

set.seed(2026082701)
n <- 20L
x <- seq(-1, 1, length.out = n)
X <- cbind(1, x)
y <- as.numeric(0.2 - 0.25 * x + stats::rnorm(n, sd = 0.12))

static_mcmc <- exalStaticMCMC(
  y = y, X = X, p0 = 0.25, n.burn = 6L, n.mcmc = 10L,
  init = list(gamma = 0, sigma = 1), verbose = FALSE
)
static_vb <- exalStaticLDVB(
  y = y, X = X, p0 = 0.25, max_iter = 15L, n_samp_xi = 30L,
  verbose = FALSE
)
qdesn_vb <- exdqlm:::exal_fit(
  y = y, X = X, p0 = 0.25, likelihood_family = "exal",
  gamma_bounds = get_gamma_bounds(0.25),
  beta_prior_obj = exdqlm:::exal_make_beta_prior(type = "ridge", tau2 = 10),
  vb_control = exal_make_vb_control(max_iter = 15L, min_iter_elbo = 5L,
                                    tol = 0.2, n_samp_xi = 30L),
  method = "vb"
)
al_mcmc <- exalStaticMCMC(
  y = y, X = X, p0 = 0.25, dqlm.ind = TRUE,
  n.burn = 4L, n.mcmc = 8L, verbose = FALSE
)

rng_signature <- function(threads) {
  old <- Sys.getenv(c("OMP_NUM_THREADS", "OMP_THREAD_LIMIT"), unset = NA_character_)
  on.exit({
    for (nm in names(old)) {
      if (is.na(old[[nm]])) Sys.unsetenv(nm) else
        do.call(Sys.setenv, stats::setNames(as.list(old[[nm]]), nm))
    }
  }, add = TRUE)
  Sys.setenv(OMP_NUM_THREADS = as.character(threads), OMP_THREAD_LIMIT = as.character(threads))
  set.seed(2026082702)
  list(
    gig = exdqlm:::sample_gig_devroye_vector(
      n_samples = 5L, p = 0.5, a = 1.5, b_vec = seq(0.3, 1.7, length.out = 6L)
    ),
    truncnorm = exdqlm:::sample_truncnorm(
      n_samp = 5L, TT = 4L, sts_mu = c(-0.2, 0, 0.3, 0.7),
      sts_sig2 = c(0.5, 0.8, 1.1, 1.4)
    )
  )
}
rng_1 <- rng_signature(1L)
rng_4 <- rng_signature(4L)

fresh_rng_script <- file.path(state_root, "rng_fresh_process_smoke.R")
writeLines(c(
  "suppressPackageStartupMessages(library(exdqlm))",
  "set.seed(2026082703)",
  "signature <- list(",
  "  gig = exdqlm:::sample_gig_devroye_vector(",
  "    n_samples = 5L, p = 0.5, a = 1.5, b_vec = seq(0.3, 1.7, length.out = 6L)",
  "  ),",
  "  truncnorm = exdqlm:::sample_truncnorm(",
  "    n_samp = 5L, TT = 4L, sts_mu = c(-0.2, 0, 0.3, 0.7),",
  "    sts_sig2 = c(0.5, 0.8, 1.1, 1.4)",
  "  )",
  ")",
  "saveRDS(signature, commandArgs(trailingOnly = TRUE)[[1L]], version = 3)"
), fresh_rng_script, useBytes = TRUE)
fresh_rng_signature <- function(threads, label) {
  output_path <- file.path(state_root, sprintf("rng_fresh_signature_%s.rds", label))
  log_path <- file.path(state_root, sprintf("rng_fresh_signature_%s.log", label))
  env <- c(
    sprintf("OMP_NUM_THREADS=%d", threads),
    sprintf("OMP_THREAD_LIMIT=%d", threads),
    "OMP_DYNAMIC=FALSE", sprintf("OPENBLAS_NUM_THREADS=%d", threads),
    sprintf("MKL_NUM_THREADS=%d", threads), sprintf("BLIS_NUM_THREADS=%d", threads),
    sprintf("RCPP_PARALLEL_NUM_THREADS=%d", threads)
  )
  status <- system2(
    Sys.which("Rscript"),
    c("--vanilla", shQuote(fresh_rng_script), shQuote(output_path)),
    stdout = log_path, stderr = log_path, env = env
  )
  if (!identical(as.integer(status), 0L) || !file.exists(output_path)) {
    stop(sprintf("Fresh-process RNG smoke failed for %s threads.", threads),
         call. = FALSE)
  }
  readRDS(output_path)
}
fresh_rng_1 <- fresh_rng_signature(1L, "threads_1")
fresh_rng_4 <- fresh_rng_signature(4L, "threads_4")

source_commit_present <- identical(
  system2("git", c("-C", repo_root, "merge-base", "--is-ancestor",
                   i111_package_source_commit, "HEAD"),
          stdout = FALSE, stderr = FALSE),
  0L
)
al_gamma <- as.numeric(al_mcmc$samp.gamma %||% numeric(0))
al_gamma_fixed <- !length(al_gamma) || length(unique(signif(al_gamma, 14L))) == 1L
checks <- c(
  package_version = identical(as.character(pkg_desc$Version), i111_package_version),
  required_source_commit = source_commit_present,
  dynamic_default_collapsed_slice = identical(mcmc_dynamic_default[[1L]], "collapsed_slice"),
  static_default_collapsed_slice = identical(mcmc_static_default[[1L]], "collapsed_slice"),
  vb_default_structured = identical(vb_default$factorization, "structured"),
  vb_default_grid_151 = identical(as.integer(vb_default$structured_grid_size), 151L),
  mcmc_smoke_collapsed_slice = identical(static_mcmc$mh.diagnostics$proposal,
                                         "collapsed_slice"),
  mcmc_smoke_sigma_collapsed = isTRUE(static_mcmc$mh.diagnostics$sigma_collapsed),
  ldvb_smoke_structured = identical(static_vb$qsiggam$factorization,
                                    "structured_qgamma_qsigma_given_gamma"),
  qdesn_ldvb_smoke_structured = identical(qdesn_vb$qsiggam$factorization,
                                          "structured_qgamma_qsigma_given_gamma"),
  al_gamma_fixed = al_gamma_fixed,
  rng_thread_invariant = identical(rng_1, rng_4),
  rng_fresh_process_thread_invariant = identical(fresh_rng_1, fresh_rng_4),
  tarball_recorded = !nzchar(tarball_path) || file.exists(tarball_path)
)

check_df <- data.frame(check = names(checks), pass = unname(checks), stringsAsFactors = FALSE)
ffv2_write_csv(check_df, file.path(state_root, "preflight_checks.csv"))
writeLines(capture.output(sessionInfo()), file.path(state_root, "sessionInfo.txt"))

r_config <- function(key) {
  out <- tryCatch(system2(file.path(R.home("bin"), "R"), c("CMD", "config", key),
                          stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  paste(out, collapse = " ")
}
ext_software_version <- function(name) {
  versions <- extSoftVersion()
  if (name %in% names(versions)) as.character(versions[[name]]) else NA_character_
}
thread_vars <- c(
  "OMP_NUM_THREADS", "OMP_THREAD_LIMIT", "OMP_DYNAMIC", "OPENBLAS_NUM_THREADS",
  "MKL_NUM_THREADS", "BLIS_NUM_THREADS", "VECLIB_MAXIMUM_THREADS",
  "NUMEXPR_NUM_THREADS", "RCPP_PARALLEL_NUM_THREADS"
)
environment <- list(
  schema_version = i111_schema,
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  repo_root = repo_root,
  branch = system2("git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE),
  head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE),
  package = list(
    version = as.character(pkg_desc$Version),
    remote_ref = as.character(pkg_desc$RemoteRef %||% NA_character_),
    remote_sha = as.character(pkg_desc$RemoteSha %||% NA_character_),
    required_source_commit = i111_package_source_commit,
    tarball_path = if (nzchar(tarball_path)) normalizePath(tarball_path, winslash = "/",
                                                           mustWork = TRUE) else NULL,
    tarball_sha256 = if (nzchar(tarball_path)) ffv2_file_sha256(tarball_path) else NULL
  ),
  r = list(version = R.version.string, platform = R.version$platform,
           blas = ext_software_version("BLAS"),
           lapack = ext_software_version("LAPACK")),
  compiler = list(CC = r_config("CC"), CXX = r_config("CXX"),
                  CXX17 = r_config("CXX17"), SHLIB_OPENMP_CFLAGS = r_config("SHLIB_OPENMP_CFLAGS")),
  threads = as.list(Sys.getenv(thread_vars, unset = "")),
  checks_pass = sum(checks), checks_total = length(checks),
  status = if (all(checks)) "PASS" else "FAIL"
)
ffv2_write_json(environment, file.path(state_root, "environment_manifest.json"))
ffv2_write_json(list(
  schema_version = i111_schema,
  mcmc = list(proposal = static_mcmc$mh.diagnostics$proposal,
              sigma_collapsed = static_mcmc$mh.diagnostics$sigma_collapsed),
  ldvb = list(factorization = static_vb$qsiggam$factorization,
              grid_size = static_vb$qsiggam$structured$grid_size),
  qdesn_ldvb = list(factorization = qdesn_vb$qsiggam$factorization,
                    grid_size = qdesn_vb$qsiggam$structured$grid_size),
  al = list(gamma_draws_present = length(al_gamma) > 0L,
            gamma_unique = length(unique(signif(al_gamma, 14L))),
            fixed_gamma_contract = al_gamma_fixed),
  rng = list(
    in_process_thread_invariant = identical(rng_1, rng_4),
    fresh_process_thread_invariant = identical(fresh_rng_1, fresh_rng_4),
    fresh_process_script = fresh_rng_script,
    fresh_process_script_sha256 = ffv2_file_sha256(fresh_rng_script)
  )
), file.path(state_root, "smoke_evidence.json"))

cat(sprintf("preflight: %d/%d checks pass; state=%s\n",
            sum(checks), length(checks), state_root))
if (!all(checks)) {
  print(check_df[!check_df$pass, , drop = FALSE], row.names = FALSE)
  quit(save = "no", status = 1L)
}
