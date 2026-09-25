#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value_after <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) return(default)
  args[[i + 1L]]
}

run_root <- value_after("--run-root")
if (is.null(run_root)) stop("Usage: --run-root <path>", call. = FALSE)
repo_root <- normalizePath(
  system("git rev-parse --show-toplevel", intern = TRUE),
  winslash = "/", mustWork = TRUE
)
run_root <- normalizePath(run_root, winslash = "/", mustWork = TRUE)

Sys.setenv(
  OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1", RCPP_PARALLEL_NUM_THREADS = "1"
)
suppressPackageStartupMessages(pkgload::load_all(repo_root, quiet = TRUE))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2.R"
))
source(file.path(
  repo_root, "validation", "fitforecast_v2", "R",
  "independent_qdesn_full_redesign_v2_runtime.R"
))

protocol <- iqfr_v2_read_protocol(repo_root)
checks <- iqfr_v2_assert_protocol(protocol)
if (!identical(as.character(utils::packageVersion("exdqlm")),
               iqfr_v2_expected_package_version)) {
  stop("Preflight requires exdqlm ", iqfr_v2_expected_package_version, ".",
       call. = FALSE)
}
sigmagam <- exal_make_vb_sigmagam_control()
if (!identical(sigmagam$factorization, "structured") ||
    !identical(as.integer(sigmagam$structured_grid_size), 151L)) {
  stop("Structured exAL LDVB defaults are not active.", call. = FALSE)
}
if (!grepl("m0_v_collapsed_support_logit",
           paste(deparse(body(exal_mcmc_fit)), collapse = "\n"),
           fixed = TRUE)) {
  stop("Exact exAL M0 transition is unavailable.", call. = FALSE)
}

sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                           check.names = FALSE, stringsAsFactors = FALSE)
source_hash_pass <- vapply(sources$frozen_path, iqfr_v2_sha256,
                           character(1L)) == sources$frozen_sha256
if (!all(source_hash_pass)) stop("Frozen source hash preflight failed.",
                                 call. = FALSE)
for (family in iqfr_v2_families) {
  family_rows <- sources[sources$family == family, , drop = FALSE]
  values <- lapply(family_rows$frozen_path, iqfr_v2_source_rows)
  if (!all(vapply(values, function(x) identical(x$mu, values[[1L]]$mu),
                  logical(1L)))) {
    stop("Family oracle location is not invariant across quantiles.",
         call. = FALSE)
  }
}

tmp <- file.path(run_root, "preflight_tmp")
unlink(tmp, recursive = TRUE, force = TRUE)
dir.create(tmp, recursive = TRUE)
on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
for (subdir in c(
  "configs", "results/quantile_vb", "status/quantile_vb",
  "results/mcmc_pilot", "status/mcmc_pilot"
)) {
  dir.create(file.path(tmp, subdir), recursive = TRUE, showWarnings = FALSE)
}

candidates <- iqfr_v2_generate_initial_candidates(
  protocol, "normal", n = 96L, generation = "preflight"
)
small <- candidates[candidates$D == 1L, , drop = FALSE][1L, , drop = FALSE]
small$n <- "20"
small$n_tilde <- ""
small$total_states <- 20L
small$readout_dimension <- 21L
small$m <- 3L
small$input_fanin <- min(as.integer(small$input_fanin), 4L)
small$recurrent_indegree <- min(as.integer(small$recurrent_indegree), 5L)
small$interlayer_fanin <- 5L
small <- iqfr_v2_rekey_candidate(small, "preflight_small", 1L, protocol)

d4 <- candidates[candidates$D == 4L, , drop = FALSE][1L, , drop = FALSE]
d4$n <- "20;20;20;20"
d4$n_tilde <- "20;20;20"
d4$total_states <- 80L
d4$readout_dimension <- 81L
d4$m <- 3L
d4$input_fanin <- min(as.integer(d4$input_fanin), 4L)
d4$recurrent_indegree <- min(as.integer(d4$recurrent_indegree), 5L)
d4$interlayer_fanin <- 5L
d4 <- iqfr_v2_rekey_candidate(d4, "preflight_d4", 1L, protocol)
median_source <- sources[
  sources$family == "normal" & abs(sources$tau - 0.50) < 1e-10,
  , drop = FALSE
]
x <- iqfr_v2_source_rows(median_source$frozen_path[[1L]])
fit_rows <- x$t >= 8501L & x$t <= 8800L
preprocess <- iqfr_v2_training_preprocess(x$y[fit_rows], d4$center_scale)
d4_args <- iqfr_v2_design_args(
  y = x$y[x$t <= 8800L], candidate = d4, preprocess = preprocess,
  p0 = 0.5, fit_readout = FALSE
)
d4_args$normal_args <- NULL
d4_design <- do.call(qdesn_fit_vb, d4_args)
iqfr_v2_assert_design(d4_design, d4, 300L)

family_sources <- sources[sources$family == "normal", , drop = FALSE]
quantile_config <- list(
  schema_version = iqfr_v2_schema, protocol_id = protocol$protocol$id,
  stage = "quantile_vb", job_id = "preflight_quantile",
  repo_root = repo_root, run_root = tmp,
  protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                             iqfr_v2_protocol_relpath)),
  sources = family_sources, candidate = as.list(small),
  result_path = file.path(tmp, "results", "quantile_vb", "result.csv"),
  status_path = file.path(tmp, "status", "quantile_vb", "status.json"),
  seed = 1234L,
  budget = list(max_iter = 4L, n_samp_xi = 20L, tol = 1e-3)
)
quantile_path <- file.path(tmp, "configs", "quantile.json")
invisible(iqfr_v2_write_json(quantile_config, quantile_path))
quantile_result <- iqfr_v2_quantile_vb_job(quantile_path)
if (nrow(quantile_result) != 6L ||
    any(!is.finite(quantile_result$forecast_qtrue_mae))) {
  stop("Nested AL/exAL VB canary failed.", call. = FALSE)
}

mcmc_modes <- c(al = "sigma_then_gamma",
                exal = "m0_v_collapsed_support_logit")
mcmc_rows <- lapply(names(mcmc_modes), function(likelihood) {
  job_id <- paste0("preflight_mcmc_", likelihood)
  config <- list(
    schema_version = iqfr_v2_schema, protocol_id = protocol$protocol$id,
    stage = "mcmc_pilot", job_id = job_id,
    repo_root = repo_root, run_root = tmp,
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                               iqfr_v2_protocol_relpath)),
    source = as.list(median_source), candidate = as.list(small),
    likelihood_family = likelihood, tau = 0.50, chain_id = 1L,
    selection_rank = 1L, selection_source_stage = "preflight",
    result_path = file.path(tmp, "results", "mcmc_pilot",
                            paste0(job_id, ".csv")),
    status_path = file.path(tmp, "status", "mcmc_pilot",
                            paste0(job_id, ".json")),
    seed = iqfr_v2_seed(job_id, "preflight"),
    budget = list(burn = 3L, sample = 8L, draws = 4L)
  )
  path <- file.path(tmp, "configs", paste0(job_id, ".json"))
  invisible(iqfr_v2_write_json(config, path))
  result <- iqfr_v2_mcmc_job(path)
  if (nrow(result) != 2L ||
      any(result$core_update_mode != mcmc_modes[[likelihood]]) ||
      any(!file.exists(result$metric_draw_path)) ||
      any(!file.exists(result$origin_lead_path))) {
    stop("MCMC canary failed for ", likelihood, call. = FALSE)
  }
  data.frame(
    likelihood_family = likelihood,
    core_update_mode = unique(result$core_update_mode),
    result_rows = nrow(result), metric_draw_rows =
      nrow(utils::read.csv(result$metric_draw_path[[1L]])),
    stringsAsFactors = FALSE
  )
})
mcmc_rows <- do.call(rbind, mcmc_rows)

report <- list(
  schema_version = iqfr_v2_schema,
  status = "PREFLIGHT_PASS",
  completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  package_version = as.character(utils::packageVersion("exdqlm")),
  git_branch = system2("git", c("-C", repo_root, "branch", "--show-current"),
                       stdout = TRUE),
  git_head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                     stdout = TRUE),
  protocol_checks = checks,
  source_hashes_pass = all(source_hash_pass),
  quantile_specific_responses = all(vapply(
    split(sources, sources$family),
    function(z) length(unique(z$y_hash)) == 3L, logical(1L)
  )),
  common_family_oracle_location = TRUE,
  identity_projection_d4 = TRUE,
  readout_dimension_d4 = ncol(d4_design$X),
  quantile_vb_rows = nrow(quantile_result),
  mcmc_canaries = mcmc_rows,
  fitted_model_binaries = 0L
)
report_path <- file.path(run_root, "manifests", "preflight_report.json")
invisible(iqfr_v2_write_json(report, report_path))
cat(sprintf("PREFLIGHT_PASS report=%s\n", report_path))
