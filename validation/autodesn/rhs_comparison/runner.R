# Source-only runner. The installed exdqlm package is never substituted.
rhs_compile <- function(method, backend, out) {
  if (method != "rhs" || backend == "R") return(0)
  begun <- proc.time()[3]
  Rcpp::sourceCpp("src/autodesn_rhs.cpp", cacheDir = file.path(out, "cpp_cache"),
                  rebuild = FALSE, showOutput = FALSE, verbose = FALSE)
  unname(proc.time()[3] - begun)
}

rhs_compact <- function(fits, bank, dg, cfg, seed) {
  counts <- vapply(fits, function(f) nrow(f$draws), 0L)
  stopifnot(sum(counts) >= cfg$checkpoint_draws)
  ids <- .autodesn_seed(seed + 200L, function() sample.int(sum(counts), cfg$checkpoint_draws))
  ends <- cumsum(counts); chains <- findInterval(ids - 1L, c(0L, ends))
  within <- ids - c(0L, ends)[chains]
  draws <- do.call(rbind, lapply(seq_along(ids), function(i) fits[[chains[i]]]$draws[within[i], , drop = FALSE]))
  draws$chain <- chains
  beta <- lapply(seq_along(ids), function(i) fits[[chains[i]]]$beta[[within[i]]])
  selected <- list(bank = bank, draws = draws, beta = beta, model_summary = dg$models)
  cp <- c1_compact(selected, seq_along(ids), dg); cp$source_ids <- ids
  cp$source_chain <- chains; cp$source_chain_row <- within
  cp
}

rhs_fit <- function(bank_result, cfg, options, directory, id) {
  bank <- bank_result$bank; method <- options$method
  seed <- cfg[[paste0(method, "_seed")]]
  cpfile <- file.path(directory, "posterior_checkpoint.rds")
  if (file.exists(cpfile)) {
    cp <- readRDS(cpfile)
    stopifnot(identical(cp$comparison_contract_id, id))
    return(cp)
  }
  compile_seconds <- rhs_compile(method, options$backend, directory)
  writeLines(capture.output(sessionInfo()), file.path(directory, "session.txt"))
  sampler <- if (method == "ridge") c1_sampler(bank) else autodesn_fit_bank
  total_inference <- 0; gate <- FALSE
  for (attempt in seq_len(nrow(cfg$attempts))) {
    control <- cfg$attempts[attempt, , drop = FALSE]
    adir <- file.path(directory, paste0("attempt_", attempt)); dir.create(adir, showWarnings = FALSE)
    fits <- vector("list", cfg$chains)
    for (k in seq_len(cfg$chains)) {
      path <- file.path(adir, paste0("chain_", k, ".rds"))
      if (file.exists(path)) {
        result <- readRDS(path)
        stopifnot(identical(result$contract_id, id))
      } else {
        cat(method, "attempt", attempt, "chain", k, ":", control$n_burn, "burn +", control$n_mcmc, "retained\n")
        flush.console(); begun <- proc.time()[3]
        args <- list(bank = bank, n_burn = control$n_burn, n_mcmc = control$n_mcmc,
          initial_variance = c(.1, 1, 5)[k], seed = seed + 10000L * (attempt - 1L) + k)
        if (method == "ridge") args$ridge_precision <- c(.1, 1, 10)[k] else {
          args$beta_prior <- "rhs"; args$rhs_control <- cfg$rhs_control
          args$rhs_control$initial_global <- c(.1, 1, 10)[k]
          args$model_control <- cfg$model_control
          args$model_control$initial_model <- as.integer(round(seq(1L, length(bank$models), length.out = cfg$chains))[k])
          args$backend <- options$backend
        }
        fit <- do.call(sampler, args)
        elapsed <- unname(proc.time()[3] - begun)
        fit$bank <- NULL
        result <- list(fit = fit, contract_id = id, inference_seconds = elapsed)
        rhs_save(result, path)
        rhs_json(list(complete = TRUE, chain = k, attempt = attempt,
          inference_seconds = elapsed, seed = args$seed,
          retained = nrow(fit$draws), backend = fit$controls$backend,
          sampler_stats = fit$sampler_stats), file.path(adir, paste0("chain_", k, "_status.json")))
        rm(fit)
      }
      total_inference <- total_inference + result$inference_seconds
      fits[[k]] <- result$fit; fits[[k]]$bank <- bank
    }
    dg <- autodesn_diagnostics(fits); gate <- rhs_diagnostic_gate(dg, cfg)
    write.csv(dg$parameters, file.path(adir, "diagnostics.csv"), row.names = FALSE)
    write.csv(dg$models, file.path(adir, "model_probabilities.csv"), row.names = FALSE)
    rhs_json(list(complete = TRUE, diagnostic_gates_passed = gate,
      qualified = gate && cfg$mode == "full", mode = cfg$mode,
      attempt = attempt, chains = cfg$chains, gates = cfg$diagnostic_gates,
      inference_seconds_all_attempts = total_inference), file.path(adir, "status.json"))
    cat("Diagnostic gates:", if (gate) "passed" else "failed", "(mode:", cfg$mode, ")\n"); flush.console()
    if (gate || cfg$mode != "full") break
    rm(fits); gc(FALSE)
  }
  status <- list(complete = FALSE, fit_complete = TRUE, qualified = gate && cfg$mode == "full",
    diagnostic_gates_passed = gate, mode = cfg$mode, model = paste("AutoDESN", if (method == "rhs") "RHS" else "ridge"),
    reused = FALSE, method = method, chains = cfg$chains, selected_attempt = attempt,
    contract_id = id, bank_id = bank_result$id, fit_rows = cfg$n_train,
    innovation_seed = cfg$innovation_seed, outer_draws = cfg$outer_draws, inner_paths = cfg$inner_paths,
    posterior_updates = FALSE, model_weight_updates = FALSE, timings = list(
      compile_seconds = compile_seconds, inference_seconds_all_attempts = total_inference,
      bank_load_seconds_this_invocation = bank_result$load_seconds),
    timing_note = "Inference sums completed chain computations across all attempts; compile, feature construction and forecasting are separate. See bank/status.json for feature construction.")
  rhs_json(status, file.path(directory, "status.json"))
  write.csv(dg$parameters, file.path(directory, "diagnostics.csv"), row.names = FALSE)
  write.csv(dg$models, file.path(directory, "model_probabilities.csv"), row.names = FALSE)
  if (cfg$mode == "full" && !gate)
    stop("Frozen diagnostic gates failed after all attempts. Evidence saved; no qualified posterior or forecasts created.")
  if (cfg$mode == "pilot") return(NULL)
  cp <- rhs_compact(fits, bank, dg, cfg, seed)
  for (j in seq_along(cp$bank$templates)) cp$bank$templates[[j]]$fit$target_label <-
    paste0("normal_independent_", method, "_autodesn")
  cp$comparison_contract_id <- id; cp$qualified <- status$qualified
  cp$beta_prior <- method; cp$mode <- cfg$mode
  rhs_save(cp, cpfile)
  cp
}

rhs_export_paths <- function(fc, file) {
  H <- nrow(fc$yrep); N <- ncol(fc$yrep)
  rows <- data.frame(horizon = rep(seq_len(H), N), trajectory = rep(seq_len(N), each = H),
    yrep = as.vector(fc$yrep), mu = as.vector(fc$mu_draws), sd = as.vector(fc$sd_draws))
  con <- gzfile(paste0(file, ".partial"), "wt")
  tryCatch(write.csv(rows, con, row.names = FALSE), finally = close(con))
  stopifnot(file.rename(paste0(file, ".partial"), file))
}

rhs_forecast <- function(cp, cfg, directory, id) {
  if (is.null(cp)) stop("Pilot mode produces diagnostics only; use full mode for qualified forecasts")
  if (cfg$mode == "full" && !isTRUE(cp$qualified)) stop("Forecasting requires a qualified full posterior")
  y <- c1_data()$y; origins <- seq.int(cfg$first_origin, cfg$last_origin)
  primary <- cp; ids <- seq_len(cfg$outer_draws)
  primary$draws <- cp$draws[ids, , drop = FALSE]; primary$beta <- cp$beta[ids]
  primary$source_ids <- cp$source_ids[ids]
  begun <- proc.time()[3]
  # States use only observations available at their respective origins. The
  # forecast engine receives no y_future_obs and feeds back each simulated path.
  states <- hr_origin_states(primary, y[seq_len(max(origins))], origins)
  state_seconds <- unname(proc.time()[3] - begun)
  snapshots <- unique(origins[c(1L, ceiling(length(origins) / 2), length(origins))])
  forecast_one <- function(i) {
    origin <- origins[i]; path <- file.path(directory, sprintf("origin_%04d.rds", origin))
    if (file.exists(path)) {
      result <- readRDS(path)
      stopifnot(identical(result$contract_id, id), identical(result$origin, origin))
      return(NULL)
    }
    begun <- proc.time()[3]
    fc <- hr_auto(primary, states$states[[i]], states$history_scaled[seq_len(origin)],
      cfg$H, cfg$inner_paths, c1_noise(cfg$innovation_seed, origin, cfg$inner_paths, cfg$outer_draws, cfg$H))
    elapsed <- unname(proc.time()[3] - begun)
    score <- c1_desn_score(fc, y[origin + seq_len(cfg$H)], origin)
    score$model <- paste("AutoDESN", if (cp$beta_prior == "rhs") "RHS" else "ridge")
    stopifnot(all(score$target == origin + seq_len(cfg$H)), nrow(score) == cfg$H,
              all(score$target > origin), all(is.finite(as.matrix(score[, vapply(score, is.numeric, FALSE), drop = FALSE]))))
    if (origin %in% snapshots) {
      rhs_save(fc, file.path(directory, paste0("forecast_", origin, ".rds")))
      rhs_export_paths(fc, file.path(directory, paste0("paths_", origin, ".csv.gz")))
    }
    rhs_save(list(contract_id = id, origin = origin, scores = score, forecast_seconds = elapsed), path)
    NULL
  }
  for (start in seq(1L, length(origins), by = 8L)) {
    ids <- seq.int(start, min(length(origins), start + 7L))
    results <- parallel::mclapply(ids, forecast_one, mc.cores = cfg$origin_workers, mc.set.seed = FALSE)
    rhs_require_checkpoints(results,file.path(directory,sprintf("origin_%04d.rds",origins[ids])),"Forecast")
    cat(cp$beta_prior, "origins", max(ids), "/", length(origins), "complete\n"); flush.console()
  }
  result <- lapply(origins, function(o) readRDS(file.path(directory, sprintf("origin_%04d.rds", o))))
  scores <- do.call(rbind, lapply(result, `[[`, "scores"))
  write.csv(scores, file.path(directory, "scores.csv"), row.names = FALSE)
  status <- jsonlite::fromJSON(file.path(directory, "status.json"), simplifyVector = FALSE)
  status$complete <- TRUE; status$benchmark_complete <- cfg$mode == "full" && isTRUE(cp$qualified)
  status$origins <- length(origins); status$score_pairs <- nrow(scores)
  status$timings$state_preparation_seconds_this_invocation <- state_seconds
  status$timings$forecast_compute_seconds_sum <- sum(vapply(result, `[[`, 0, "forecast_seconds"))
  status$timings$forecast_timing_note <- "Sum of per-origin forecast compute, excluding scoring, export and state preparation; not parallel wall time."
  rhs_json(status, file.path(directory, "status.json"))
  invisible(status)
}

rhs_run_model <- function(bank_result, cfg, options) {
  directory <- file.path(options$out, options$method)
  existing_status <- file.path(directory, "status.json")
  if (file.exists(existing_status) && isTRUE(jsonlite::fromJSON(existing_status)$reused))
    stop("A reused frozen baseline exists here; use another --out directory for a fresh fit")
  source_manifest <- rhs_source_manifest()
  # Only executed sources participate: adding documentation or tests must not
  # invalidate a completed expensive posterior or an in-progress chain.
  harness_paths <- sort(c(file.path(rhs_compare_root, c("helpers.R", "runner.R", "run.R")),
    "validation/autodesn/load_checkout.R", "validation/autodesn/c1_comparison/helpers.R",
    "validation/autodesn/long_horizon/helpers.R", "validation/autodesn/heteroscedastic/forecasting.R",
    "validation/autodesn/heteroscedastic/rolling/helpers.R"))
  contract <- list(bank_id = bank_result$id, configuration = cfg, method = options$method,
    backend = options$backend, production_source = source_manifest,
    harness_source = data.frame(path = harness_paths, sha256 = vapply(harness_paths,
      function(p) digest::digest(file = p, algo = "sha256"), "")))
  id <- rhs_guard(directory, contract)
  write.csv(source_manifest, file.path(directory, "source_manifest.csv"), row.names = FALSE)
  rhs_json(list(contract_id = id, configuration = cfg, git_revision = .autodesn_checkout_revision,
    production_source = source_manifest, harness_source = contract$harness_source,
    runtime = list(R = R.version.string, platform = R.version$platform,
      BLAS = extSoftVersion()["BLAS"], threads = Sys.getenv(c("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS")))),
    file.path(directory, "provenance.json"))
  if (options$stage == "forecast") {
    path <- file.path(directory, "posterior_checkpoint.rds")
    if (!file.exists(path)) stop("No qualified checkpoint exists; run --stage fit first")
    cp <- readRDS(path); stopifnot(identical(cp$comparison_contract_id, id))
  } else cp <- rhs_fit(bank_result, cfg, options, directory, id)
  if (options$stage %in% c("forecast", "all") && cfg$mode != "pilot") rhs_forecast(cp, cfg, directory, id)
  invisible(cp)
}
