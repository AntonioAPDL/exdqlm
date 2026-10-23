# Independent posterior/evidence validation for Gaussian AutoDESN RHS.
#
# Installed-package example:
#   Rscript validation/autodesn/rhs_validation/run_validation.R \
#     --output-dir=/data/autodesn_rhs_oracles --backend=cpp
#
# Source-checkout example, explicitly compiling the RHS accelerators:
#   Rscript validation/autodesn/rhs_validation/run_validation.R \
#     --source-repo=/path/to/exdqlm --output-dir=/data/autodesn_rhs_oracles
#
# MCMC is checked against independent observation-space quadrature; no
# production collapsed-density helper is used to construct a reference.

run_autodesn_rhs_oracles <- function(output_dir, backend = "cpp",
                                     n_burn = 2000L, n_mcmc = 20000L,
                                     oracle_path = NULL, reuse_chains = NULL) {
  if (!is.null(oracle_path)) source(oracle_path, local = environment())
  if (!exists("rhs_oracle_fixed_scales", mode = "function")) {
    stop("Source oracle.R first, or supply oracle_path.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  reference_checks <- list()
  fits <- list()
  fit_seconds <- numeric()
  diagnostic_tables <- list()
  cached_fits <- if (is.null(reuse_chains)) NULL else readRDS(reuse_chains)
  if (!is.null(cached_fits) && !is.list(cached_fits)) {
    stop("reuse_chains must contain the saved named list of oracle fits.")
  }
  same <- function(x, y) isTRUE(all.equal(x, y, check.attributes = FALSE))
  add <- function(row) {
    reference_checks[[length(reference_checks) + 1L]] <<- row
  }
  fit_case <- function(bank, control, case, seed) {
    pair <- lapply(c("categorical", "mh"), function(method) {
      key <- paste(case, method, sep = "_")
      chain_seed <- seed + if (method == "mh") 1L else 0L
      initial_model <- if (method == "mh") length(bank$models) else 1L
      if (is.null(cached_fits)) {
        started <- proc.time()[["elapsed"]]
        fit <- autodesn_fit_bank(bank, beta_prior = "rhs", rhs_control = control,
          model_control = list(method = method, moves = 2L,
                               initial_model = initial_model),
          n_burn = n_burn, n_mcmc = n_mcmc, seed = chain_seed, backend = backend)
        fit_seconds[[key]] <<- proc.time()[["elapsed"]] - started
        cat(sprintf("Completed %s: %d retained draws, %.2f seconds\n", key, n_mcmc,
                    fit_seconds[[key]]))
      } else {
        fit <- cached_fits[[key]]
        expected_control <- unclass(do.call(autodesn_rhs_control, control))
        compatible <- inherits(fit, "autodesn_fit") &&
          same(fit$bank$y, bank$y) && same(fit$bank$prior, bank$prior) &&
          same(lapply(fit$bank$models, `[[`, "X"), lapply(bank$models, `[[`, "X")) &&
          same(fit$controls$rhs_control, expected_control) &&
          same(fit$controls$model_control, list(method = method,
            moves = if (method == "mh") 2L else 1L, proposal = bank$prior,
            rb_every = 0L, initial_model = initial_model)) &&
          same(fit$controls$n_burn, n_burn) && same(fit$controls$n_mcmc, n_mcmc) &&
          same(fit$controls$thin, 1L) && same(fit$controls$seed, chain_seed) &&
          same(fit$controls$intercept_variance, 10) &&
          same(fit$controls$a_sigma, 3) && same(fit$controls$b_sigma, 1) &&
          identical(fit$controls$backend, backend) && nrow(fit$draws) == n_mcmc
        if (!isTRUE(compatible)) stop("Cached chain does not match this experiment: ", key)
        old_seconds <- attr(cached_fits, "fit_seconds")
        fit_seconds[[key]] <<- if (is.null(old_seconds)) NA_real_ else old_seconds[[key]]
        cat(sprintf("Reused %s: %d retained draws; bank and sampler controls verified\n",
                    key, n_mcmc))
      }
      fits[[key]] <<- fit
      fit
    })
    names(pair) <- c("categorical", "mh")
    diagnostic_tables[[case]] <<- autodesn_diagnostics(pair)
    pair
  }
  compare_model_probabilities <- function(pair, reference, less_precise, case) {
    for (method in names(pair)) {
      fit <- pair[[method]]
      for (j in seq_along(reference$model_probability)) {
        add(rhs_oracle_compare(as.numeric(fit$draws$model == j),
          reference$model_probability[j], paste(case, method, "model", j, sep = "/"),
          quadrature_error = reference$model_probability[j] - less_precise$model_probability[j]))
      }
      add(rhs_oracle_compare(fit$draws$variance, reference$variance_mean,
        paste(case, method, "variance", sep = "/"),
        quadrature_error = reference$variance_mean - less_precise$variance_mean))
    }
  }

  # Case 1: different feature dimensions and different tau0_m; integrate the
  # noise variance exactly up to a separately assessed quadrature error.
  x <- seq(-1, 1, length.out = 9)
  y <- .6 * x + c(.2, -.1, .1, -.2, .15, .1, -.05, .2, -.15)
  bank_fixed <- autodesn_prepare_bank(y,
    list(matrix(numeric(), 9, 0), cbind(x), cbind(x, x^2)),
    model_prior = c(.25, .45, .3))
  tau0_fixed <- c(.7, .9, 1.2)
  fixed_control <- list(tau0 = tau0_fixed, fixed_local_scales = c(.6, 1.4),
    learn_global = FALSE, initial_global = .8,
    learn_slab = FALSE, initial_slab = 2.5, save_local = TRUE)
  fixed_low <- rhs_oracle_fixed_scales(bank_fixed, c(.6, 1.4), .8, 2.5,
                                      tau0_fixed, order = 384L)
  fixed_reference <- rhs_oracle_fixed_scales(bank_fixed, c(.6, 1.4), .8, 2.5,
                                            tau0_fixed, order = 768L)
  fixed_pair <- fit_case(bank_fixed, fixed_control, "fixed_scales", 6310L)
  compare_model_probabilities(fixed_pair, fixed_reference, fixed_low, "fixed_scales")

  # Case 2: integrate BOTH sigma^2 and the true normalized RHS local scale.
  # This catches the common erroneous reuse of ordinary-horseshoe scale
  # updates after merely adding c^-2 to the Gaussian coefficient precision.
  bank_local <- autodesn_prepare_bank(y,
    list(cbind(x), cbind(sin(2.6 * x))), model_prior = c(.4, .6))
  tau0_local <- c(.55, 1.1)
  local_control <- list(tau0 = tau0_local, learn_global = FALSE, initial_global = .7,
    learn_slab = FALSE, initial_slab = 1.8, save_local = TRUE)
  local_low <- rhs_oracle_one_local(bank_local, .7, 1.8, tau0_local, order = 320L)
  local_reference <- rhs_oracle_one_local(bank_local, .7, 1.8, tau0_local, order = 640L)
  local_pair <- fit_case(bank_local, local_control, "learned_local", 6410L)
  compare_model_probabilities(local_pair, local_reference, local_low, "learned_local")
  for (method in names(local_pair)) {
    fit <- local_pair[[method]]
    local_cdf <- vapply(fit$local_log_scales,
      function(z) 2 / pi * atan(exp(z[1L])), numeric(1))
    add(rhs_oracle_compare(local_cdf, local_reference$local_prior_cdf_mean,
      paste("learned_local", method, "local_prior_cdf", sep = "/"),
      quadrature_error = local_reference$local_prior_cdf_mean - local_low$local_prior_cdf_mean))
  }

  # Case 3: zero slope designs carry no information about any shrinkage scale.
  # For each proper prior, its CDF evaluated at posterior draws is Uniform(0,1).
  # Different architecture dimensions must not favor a model through an
  # accidentally omitted normalizing constant.
  bank_prior <- autodesn_prepare_bank(c(-.4, .1, .3, -.2, .2, .15),
    list(matrix(0, 6, 1), matrix(0, 6, 4)), model_prior = c(.27, .73))
  prior_control <- list(tau0 = c(.25, 1.4), slab_df = 4, slab_scale = 2,
                        save_local = TRUE)
  prior_pair <- fit_case(bank_prior, prior_control, "uninformative_slopes", 6510L)
  for (method in names(prior_pair)) {
    fit <- prior_pair[[method]]
    for (j in seq_along(bank_prior$prior)) {
      add(rhs_oracle_compare(as.numeric(fit$draws$model == j), bank_prior$prior[j],
        paste("uninformative_slopes", method, "model", j, sep = "/")))
    }
    transformed <- list(
      global = 2 / pi * atan(exp(fit$draws$log_global)),
      slab = stats::pgamma(8 / exp(fit$draws$log_slab), shape = 2, lower.tail = FALSE),
      local = vapply(fit$local_log_scales, function(z) 2 / pi * atan(exp(z[1L])), numeric(1)))
    for (name in names(transformed)) {
      add(rhs_oracle_compare(transformed[[name]], .5,
        paste("uninformative_slopes", method, name, "cdf_mean", sep = "/")))
      add(rhs_oracle_compare(transformed[[name]]^2, 1 / 3,
        paste("uninformative_slopes", method, name, "cdf_second", sep = "/")))
    }
  }

  checks <- do.call(rbind, reference_checks)
  quadrature_errors <- data.frame(
    case = c("fixed_scales", "learned_local"),
    lower_order = c(fixed_low$order, local_low$order),
    higher_order = c(fixed_reference$order, local_reference$order),
    model_probability_max_change = c(
      max(abs(fixed_reference$model_probability - fixed_low$model_probability)),
      max(abs(local_reference$model_probability - local_low$model_probability))),
    variance_mean_change = c(abs(fixed_reference$variance_mean - fixed_low$variance_mean),
                             abs(local_reference$variance_mean - local_low$variance_mean)))
  # Quadrature must itself be resolved, independently of broad MCMC tolerances.
  quadrature_pass <- all(quadrature_errors$model_probability_max_change < 1e-5) &&
    all(quadrature_errors$variance_mean_change < 1e-4)
  result <- list(checks = checks, quadrature_errors = quadrature_errors,
    references = list(fixed = fixed_reference, local = local_reference),
    diagnostics = diagnostic_tables, fit_seconds = fit_seconds,
    passed = all(checks$pass) && quadrature_pass,
    controls = list(n_burn = n_burn, n_mcmc = n_mcmc, backend = backend,
      reused_chains = reuse_chains,
      prior_family = "regularized_horseshoe_pv",
      oracle = "independent dense covariance / normalized prior-quantile quadrature"),
    session_info = utils::sessionInfo())
  utils::write.csv(checks, file.path(output_dir, "posterior_reference_checks.csv"), row.names = FALSE)
  utils::write.csv(quadrature_errors, file.path(output_dir, "quadrature_convergence.csv"), row.names = FALSE)
  for (name in names(diagnostic_tables)) {
    utils::write.csv(diagnostic_tables[[name]]$parameters,
      file.path(output_dir, paste0(name, "_parameter_diagnostics.csv")), row.names = FALSE)
    utils::write.csv(diagnostic_tables[[name]]$models,
      file.path(output_dir, paste0(name, "_model_diagnostics.csv")), row.names = FALSE)
  }
  saveRDS(result, file.path(output_dir, "oracle_validation.rds"))
  attr(fits, "fit_seconds") <- fit_seconds
  saveRDS(fits, file.path(output_dir, "oracle_chains.rds"))
  writeLines(capture.output(result$session_info), file.path(output_dir, "session_info.txt"))
  cat(sprintf("Independent reference checks: %d/%d passed; quadrature: %s\n",
              sum(checks$pass), nrow(checks), quadrature_pass))
  print(checks, row.names = FALSE)
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  value <- function(key, default = NULL) {
    prefix <- paste0("--", key, "=")
    matches <- args[startsWith(args, prefix)]
    if (!length(matches)) return(default)
    if (length(matches) != 1L) stop("Repeated argument: ", key)
    substring(matches, nchar(prefix) + 1L)
  }
  source_repo <- value("source-repo")
  backend <- value("backend", "cpp")
  output_dir <- value("output-dir", file.path(tempdir(), "autodesn_rhs_oracles"))
  if (!is.null(source_repo)) {
    source_repo <- normalizePath(source_repo, mustWork = TRUE)
    for (file in list.files(file.path(source_repo, "R"), pattern = "[.]R$", full.names = TRUE))
      source(file)
    if (backend != "r") Rcpp::sourceCpp(file.path(source_repo, "src", "autodesn_rhs.cpp"))
    oracle_path <- file.path(source_repo, "validation", "autodesn", "rhs_validation", "oracle.R")
  } else {
    library(exdqlm)
    script <- commandArgs()[grepl("^--file=", commandArgs())]
    if (length(script) != 1L) stop("Cannot locate oracle.R; use --source-repo.")
    oracle_path <- file.path(dirname(sub("^--file=", "", script)), "oracle.R")
  }
  result <- run_autodesn_rhs_oracles(output_dir, backend,
    n_burn = as.integer(value("burn", "2000")),
    n_mcmc = as.integer(value("draws", "20000")), oracle_path = oracle_path,
    reuse_chains = value("reuse-chains"))
  if (!result$passed) quit(status = 1L)
}
