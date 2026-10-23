# Reproducible R/C++ benchmark for the normalized AutoDESN RHS backend.
# Compilation and bank construction are excluded from the timed operations.
# Run from an installed package, or explicitly use a source checkout:
#
# OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript \
#   validation/autodesn/rhs_validation/backend_benchmark.R \
#   --source-repo=/path/to/exdqlm --output-dir=/path/to/results
#
# Outputs include individual timings, median speed ratios, parity checks,
# session/BLAS details, and source checksums. Timing is descriptive evidence;
# no machine-dependent speed threshold is used as a correctness assertion.

run_autodesn_rhs_backend_benchmark <- function(output_dir, repeats = 3L,
    local_updates = 1000L, gaussian_scores = 200L, n = 500L, d = 109L,
    fit_burn = 50L, fit_draws = 150L, seed = 20261022L, source_repo = NULL) {
  counts <- list(repeats = repeats, local_updates = local_updates,
    gaussian_scores = gaussian_scores, n = n, d = d,
    fit_burn = fit_burn, fit_draws = fit_draws, seed = seed)
  for (name in names(counts)) {
    value <- counts[[name]]
    minimum <- if (name == "fit_burn") 0L else 1L
    if (length(value) != 1L || !is.finite(value) || value < minimum || value != floor(value))
      stop(name, " must be a finite integer >= ", minimum, ".")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  internal <- function(name) get(name, envir = environment(autodesn_fit_bank), inherits = TRUE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) saved_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit(if (had_seed) assign(".Random.seed", saved_seed, envir = .GlobalEnv) else
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv),
    add = TRUE)
  set.seed(seed)
  H <- matrix(stats::rnorm(n * d), n, d)
  y <- .8 * H[, 1L] + stats::rnorm(n, sd = .7)
  widths <- unique(as.integer(pmax(1L, pmin(d, c(20L, 35L, 50L, 75L, d)))))
  features <- lapply(widths, function(width) H[, seq_len(width), drop = FALSE])
  bank <- autodesn_prepare_bank(y, features)
  model <- bank$models[[length(bank$models)]]
  lpv <- log(c(10, exp(seq(-8, 2, length.out = d))))
  native <- internal(".autodesn_rhs_backend")("cpp", model, y, .7, lpv)
  reference <- internal(".autodesn_rhs_backend")("r", model, y, .7, lpv)
  local_args <- list(log_local = seq(-2, 2, length.out = d), log_aux = rep(0, d),
    beta = seq(-.3, .3, length.out = d), log_tau = log(.45), log_slab = log(4),
    max_attempts = 100000L)
  checks <- list()
  check <- function(name, reference_value, native_value, tolerance = 1e-10) {
    difference <- all.equal(reference_value, native_value, tolerance = tolerance)
    passed <- isTRUE(difference)
    checks[[length(checks) + 1L]] <<- data.frame(check = name, passed = passed,
      detail = if (passed) "equal" else paste(difference, collapse = "; "))
    if (!passed) stop("Backend parity failed for ", name, ": ", paste(difference, collapse = "; "))
  }
  check("Gaussian score and conditional", reference$gaussian(model, y, .7, lpv),
        native$gaussian(model, y, .7, lpv), tolerance = 1e-11)
  set.seed(seed + 1L)
  local_r <- do.call(reference$local, local_args)
  rng_r <- .Random.seed
  set.seed(seed + 1L)
  local_cpp <- do.call(native$local, local_args)
  check("Local scale conditional", local_r, local_cpp, tolerance = 1e-13)
  check("Local scale RNG state", rng_r, .Random.seed, tolerance = 0)

  rows <- list()
  measure <- function(operation, backend, repetition, iterations, fun) {
    gc(verbose = FALSE)
    elapsed <- system.time(for (k in seq_len(iterations)) value <- fun())[["elapsed"]]
    rows[[length(rows) + 1L]] <<- data.frame(operation = operation, backend = backend,
      repetition = repetition, iterations = iterations, elapsed_seconds = elapsed,
      seconds_per_operation = elapsed / iterations)
    cat(sprintf("%s / %s / repetition %d: %.3f seconds (%d operations)\n",
                operation, backend, repetition, elapsed, iterations))
    value
  }
  for (r in seq_len(repeats)) {
    # Reverse backend order on alternating repeats to reduce order effects.
    order <- if (r %% 2L) c("r", "cpp") else c("cpp", "r")
    fitted <- list()
    for (backend in order) {
      engine <- if (backend == "r") reference else native
      set.seed(seed + 100L + r)
      measure("local_scale_update", backend, r, local_updates,
              function() do.call(engine$local, local_args))
      measure("Gaussian_model_score", backend, r, gaussian_scores,
              function() engine$gaussian(model, y, .7, lpv))
      fitted[[backend]] <- measure("complete_bank_fit", backend, r, 1L,
        function() autodesn_fit_bank(bank, beta_prior = "rhs", backend = backend,
          rhs_control = list(tau0 = .5),
          model_control = list(method = "mh", moves = 2L),
          n_burn = fit_burn, n_mcmc = fit_draws, seed = seed + 200L + r))
    }
    check(paste0("Joint draws / repetition ", r), fitted$r$draws, fitted$cpp$draws)
    check(paste0("Coefficients / repetition ", r), fitted$r$beta, fitted$cpp$beta)
    check(paste0("Model move counts / repetition ", r),
          fitted$r$sampler_stats$model_proposals, fitted$cpp$sampler_stats$model_proposals,
          tolerance = 0)
  }
  timings <- do.call(rbind, rows)
  parity <- do.call(rbind, checks)
  medians <- stats::aggregate(seconds_per_operation ~ operation + backend,
                              data = timings, FUN = stats::median)
  summary <- reshape(medians, idvar = "operation", timevar = "backend", direction = "wide")
  names(summary) <- sub("seconds_per_operation[.]", "median_seconds_", names(summary))
  summary$R_over_cpp <- ifelse(summary$median_seconds_cpp > 0,
    summary$median_seconds_r / summary$median_seconds_cpp, NA_real_)
  provenance <- list(counts = counts, bank_widths = widths,
    model_prior = bank$prior, threads = Sys.getenv(c("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS")),
    external_software = extSoftVersion(), session_info = utils::sessionInfo(),
    source_repo = source_repo,
    scope = "Compilation, bank construction, and correctness checks excluded from timings")
  if (!is.null(source_repo)) {
    paths <- file.path(source_repo, c("R/autodesn_rhs.R", "src/autodesn_rhs.cpp",
                                     "R/autodesn_gaussian.R"))
    provenance$source_md5 <- data.frame(path = paths, md5 = unname(tools::md5sum(paths)))
  }
  utils::write.csv(timings, file.path(output_dir, "backend_timings.csv"), row.names = FALSE)
  utils::write.csv(summary, file.path(output_dir, "backend_speed_summary.csv"), row.names = FALSE)
  utils::write.csv(parity, file.path(output_dir, "backend_parity_checks.csv"), row.names = FALSE)
  writeLines(capture.output(provenance), file.path(output_dir, "backend_provenance.txt"))
  saveRDS(list(timings = timings, summary = summary, parity = parity, provenance = provenance),
          file.path(output_dir, "backend_benchmark.rds"))
  print(summary, row.names = FALSE)
  invisible(list(timings = timings, summary = summary, parity = parity, provenance = provenance))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  allowed <- c("source-repo", "output-dir", "repeats", "local-updates", "gaussian-scores",
               "rows", "slopes", "burn", "draws", "seed")
  keys <- sub("=.*$", "", sub("^--", "", args))
  if (any(!grepl("^--[^=]+=", args)) || any(!keys %in% allowed) || anyDuplicated(keys))
    stop("Arguments must be unique --name=value pairs from: ", paste(allowed, collapse = ", "))
  value <- function(key, default = NULL) {
    index <- match(key, keys)
    if (is.na(index)) default else sub("^[^=]*=", "", args[index])
  }
  source_repo <- value("source-repo")
  if (!is.null(source_repo)) {
    source_repo <- normalizePath(source_repo, mustWork = TRUE)
    for (file in list.files(file.path(source_repo, "R"), pattern = "[.]R$", full.names = TRUE))
      source(file)
    Rcpp::sourceCpp(file.path(source_repo, "src", "autodesn_rhs.cpp"))
  } else {
    library(exdqlm)
  }
  run_autodesn_rhs_backend_benchmark(
    output_dir = value("output-dir", file.path(tempdir(), "autodesn_rhs_backend_benchmark")),
    repeats = as.integer(value("repeats", "3")),
    local_updates = as.integer(value("local-updates", "1000")),
    gaussian_scores = as.integer(value("gaussian-scores", "200")),
    n = as.integer(value("rows", "500")), d = as.integer(value("slopes", "109")),
    fit_burn = as.integer(value("burn", "50")), fit_draws = as.integer(value("draws", "150")),
    seed = as.integer(value("seed", "20261022")), source_repo = source_repo)
}
