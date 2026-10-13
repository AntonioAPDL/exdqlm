irm13_schema <- "independent_qdesn_readout_memory_v13"
irm13_arms <- c("tau_half", "slab_quarter", "joint_shrink", "memory040", "memory099")
irm13_stages <- c("smoke", "selection_warm", "selection", "confirmation_warm",
  "confirmation", "fresh_warm", "fresh")

irm13_rho <- function(alpha, half_life = 80) {
  stopifnot(alpha > 0, alpha <= 1, half_life > 0)
  1 - (1 - 2^(-1 / half_life)) / alpha
}

irm13_effective <- function(cfg, execution = FALSE) {
  candidate <- cfg$candidate
  fields <- c("D", "n", "n_tilde", "m", "alpha", "rho", "input_gain",
    "recurrent_indegree", "input_fanin", "interlayer_fanin", "matrix_seed",
    "center_scale", "input_bound", "readout_mode", "tau_source", "slab_source",
    "sigma_b_source", "omega_b_source")
  candidate <- candidate[fields]
  candidate$n <- as.integer(iqt12_unpack(candidate$n))
  candidate$n_tilde <- head(candidate$n, -1L)
  for (key in setdiff(fields, c("n", "n_tilde", "center_scale", "input_bound", "readout_mode")))
    candidate[[key]] <- as.numeric(candidate[[key]])
  candidate$D <- length(candidate$n)
  spec <- list(model = cfg$model, family = cfg$family, p = as.numeric(cfg$p),
    likelihood = cfg$likelihood, candidate = if (cfg$model == "qdesn") candidate else NULL,
    conditioning = cfg$readout_conditioning,
    layers = as.numeric(c(cfg$layer1_scale %||% 1, cfg$layer2_scale %||% 1, cfg$layer3_scale %||% 1)),
    omega = as.numeric(cfg$omega_scaled %||% 0), rolling_window = as.numeric(cfg$rolling_window %||% 0),
    Q = "identity", state_activation = "tanh", interlayer_activation = "identity",
    readout = "intercept_L3_L1_L2_no_inputs", prior = "RHS_NS_a_zeta2_intercept_prec1e-16_source",
    transition = "AL_sigma_then_gamma_fixed_zero", forecast = "conditional_location_inner_mean",
    baseline = if (cfg$model == "baseline") cfg$baseline[c("df_value", "dim_df", "period",
      "harmonics", "model_C0_scale", "trend_C0_scale", "seasonal_C0_scale", "latent_clock_mode",
      "latent_clock_offset", "latent_clock_start_source_index", "TT_warmup", "train_start_source_index",
      "level0", "slope0", "harmonic1_amplitude", "harmonic2_amplitude",
      "harmonic1_phase", "harmonic2_phase", "C0_scale", "models")] else NULL)
  if (execution) spec$execution <- list(window = cfg$window,
    source_sha = cfg$source_sha, engine = cfg$engine, seed = as.numeric(cfg$seed),
    burn = as.numeric(cfg$burn), retained = as.numeric(cfg$retained),
    outer = as.numeric(cfg$outer), inner = as.numeric(cfg$inner),
    normal_iter = as.numeric(cfg$normal_iter), vb_iter = as.numeric(cfg$vb_iter))
  spec
}

irm13_signature <- function(cfg, execution = FALSE) digest::digest(
  jsonlite::toJSON(irm13_effective(cfg, execution), auto_unbox = TRUE,
    digits = NA, null = "null"), serialize = FALSE, algo = "sha256")

irm13_config <- function(state, arm, replica, fold, stage, chain = 1L) {
  stopifnot(arm %in% c("dqlm", "static", irm13_arms), stage %in% irm13_stages)
  # Start from a non-warm-dependent reference; each candidate gets its own initializer.
  cfg <- idl12_config(state, if (arm == "dqlm") "dqlm" else "static",
    replica, fold, "smoke", chain)
  cfg$schema <- irm13_schema; cfg$stage <- stage; cfg$arm <- arm
  cfg$engine <- if (grepl("warm$", stage)) "vb" else "mcmc"
  cfg$estimator <- paste0("quantile_", cfg$engine)
  cfg$window <- idl12_window(fold, cfg$engine == "vb", stage == "smoke")
  cfg$base_window <- cfg$window
  cfg$candidate$tau_source <- state$template$candidate$tau_source *
    if (arm %in% c("tau_half", "joint_shrink")) .5 else 1
  cfg$candidate$slab_source <- state$template$candidate$slab_source *
    if (arm %in% c("slab_quarter", "joint_shrink")) .25 else 1
  if (arm %in% c("memory040", "memory099")) {
    cfg$candidate$alpha <- if (arm == "memory040") .40 else .99
    cfg$candidate$rho <- irm13_rho(cfg$candidate$alpha)
  }
  cfg$id <- paste(stage, replica, fold, arm, paste0("c", chain), sep = "__")
  cfg$path <- file.path(state$run, "configs", paste0(cfg$id, ".json"))
  cfg$status_path <- file.path(state$run, "status", paste0(cfg$id, ".json"))
  cfg$evidence <- file.path(state$run, "evidence", cfg$id)
  cfg$seed <- as.integer(81300000L + match(replica, c("F1", "F2", paste0("N", 1:4))) *
    10000L + match(fold, c("A", "B", "C", "FINAL")) * 100L + chain)
  cfg$outer <- if (cfg$engine == "vb") 4L else if (stage == "smoke") 8L else 300L
  cfg$inner <- if (cfg$engine == "vb" || stage == "smoke") 8L else 128L
  cfg$burn <- if (stage == "smoke") 20L else if (stage == "selection") 1500L else 3000L
  cfg$retained <- if (stage == "smoke") 40L else if (stage == "selection") 5000L else 10000L
  cfg$normal_iter <- if (stage == "smoke") 40L else 300L
  cfg$vb_iter <- if (stage == "smoke") 50L else 800L
  cfg$baseline$train_end_source_index <- max(cfg$window$train)
  cfg$spec_signature <- irm13_signature(cfg)
  cfg$candidate$parent_metadata <- list(structure_id = cfg$candidate$structure_id,
    candidate_id = cfg$candidate$candidate_id)
  stale <- c("structure_signature", "canonical_structure_signature", "candidate_signature",
    "tau0_multiplier", "tau0_reference", "tau0_reference_source_scale", "rhs_tau0",
    "rhs_tau0_source_scale", "tau_multiplier", "slab_multiplier", "prior_id", "readout_scale_id")
  cfg$candidate[stale] <- NULL
  cfg$candidate$structure_id <- substr(digest::digest(irm13_effective(cfg)$candidate[
    setdiff(names(irm13_effective(cfg)$candidate), c("tau_source", "slab_source"))], algo = "sha256"), 1, 16)
  cfg$candidate$id <- cfg$candidate$candidate_id <- substr(cfg$spec_signature, 1, 20)
  cfg$candidate$role <- arm
  cfg$warm_path <- cfg$warm_sha <- NULL
  if (cfg$engine == "mcmc" && stage != "smoke") {
    warm_stage <- switch(stage, selection = "selection_warm",
      confirmation = "confirmation_warm", fresh = "fresh_warm")
    cfg$warm_path <- file.path(state$run, "evidence", paste(warm_stage, replica, fold, arm, "c1", sep = "__"),
      "mcmc_initializer.json")
    stopifnot(file.exists(cfg$warm_path))
    cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path))
  }
  cfg$execution_signature <- irm13_signature(cfg, TRUE)
  cfg
}

irm13_history <- function(roots, output) {
  paths <- unique(unlist(lapply(roots, function(root) {
    tracker <- file.path(root, "validation/fitforecast_v2/local_trackers")
    runs <- list.dirs(tracker, recursive = FALSE, full.names = TRUE)
    unlist(lapply(runs, function(run) list.files(file.path(run, "configs"),
      pattern = "[.]json$", full.names = TRUE)))
  })))
  rows <- lapply(paths, function(path) {
    cfg <- tryCatch(iqt12_read(path), error = function(e) NULL)
    eligible <- !is.null(cfg) && identical(cfg$likelihood, "al") &&
      identical(cfg$engine, "mcmc") && identical(cfg$family, "gausmix") &&
      identical(cfg$p, .05) && identical(cfg$model, "qdesn") &&
      !is.null(cfg$candidate$tau_source) && !is.null(cfg$candidate$slab_source)
    data.frame(path = path, sha256 = unname(tools::sha256sum(path)),
      regime = if (eligible) "AL_quantile_MCMC" else "not_same_regime",
      spec_signature = if (eligible) irm13_signature(cfg) else "",
      execution_signature = if (eligible) irm13_signature(cfg, TRUE) else "")
  })
  stopifnot(length(rows) > 0L)
  ledger <- do.call(rbind, rows); iqt12_csv(ledger, output)
  ledger
}

irm13_import_controls <- function(state) {
  parent <- state$parent; plan <- ifd11_plan_status(parent, "selection")
  plan <- plan[plan$arm %in% c("dqlm", "static"), ]
  stopifnot(nrow(plan) == 8L, all(plan$status == "SUCCESS"))
  rows <- lapply(seq_len(nrow(plan)), function(i) {
    cfg <- iqt12_read(plan$config_path[i])
    expected <- irm13_config(state, cfg$arm, cfg$replica, cfg$window$fold, "selection_warm")
    expected$engine <- "mcmc"; expected$window <- cfg$window
    expected$seed <- cfg$seed; expected$burn <- 1500L; expected$retained <- 5000L
    expected$outer <- 300L; expected$inner <- 128L
    stopifnot(irm13_signature(cfg, TRUE) == irm13_signature(expected, TRUE),
      cfg$source_sha == unname(tools::sha256sum(cfg$source_path)))
    status <- iqt12_read(plan$status_path[i]); iqt12_verify(status$manifest)
    stopifnot(file.exists(file.path(cfg$evidence, "phase10_summary.csv")),
      file.exists(file.path(cfg$evidence, "phase20_summary.csv")))
    data.frame(id = cfg$id, arm = cfg$arm, replica = cfg$replica, fold = cfg$window$fold,
      config_path = cfg$path, status_path = cfg$status_path, manifest = status$manifest,
      execution_signature = irm13_signature(cfg, TRUE), status = "SUCCESS")
  })
  controls <- do.call(rbind, rows)
  iqt12_csv(controls, file.path(state$run, "controls.csv"))
  closure <- unique(c(controls$config_path, controls$status_path, controls$manifest,
    unlist(lapply(controls$manifest, function(path) read.csv(path)$path)),
    vapply(state$sources, `[[`, "", "path")))
  iqt12_hash(closure, file.path(state$run, "control_import_hashes.csv"))
  controls
}

irm13_verify_tests <- function(repo, test_evidence) {
  tests <- iqt12_read(test_evidence)
  rows <- tests$source_hashes
  paths <- if (!is.null(rows$path)) rows$path else vapply(rows, `[[`, "", "path")
  hashes <- if (!is.null(rows$sha256)) rows$sha256 else vapply(rows, `[[`, "", "sha256")
  stopifnot(tests$status == "PASS", tests$checks >= 49L, tests$package_version == "1.1.2",
    identical(sort(paths), sort(irm13_own_sources(repo))),
    identical(unname(tools::sha256sum(paths)), hashes))
  invisible(TRUE)
}

irm13_materialize <- function(repo, run, parent, test_evidence, history_roots) {
  stopifnot(!dir.exists(run), file.exists(test_evidence), !length(system2("git",
    c("-C", repo, "status", "--porcelain"), stdout = TRUE)))
  irm13_verify_tests(repo, test_evidence)
  idl12_verify(parent)
  health <- idl12_health(parent)
  stopifnot(sum(health$complete) == 30L, sum(health$running + health$pending + health$failed) == 0L)
  old <- iqt12_read(file.path(parent, "campaign.json"))
  for (dir in c("sources", "plans", "configs", "status", "evidence", "control", "review"))
    dir.create(file.path(run, dir), recursive = TRUE, showWarnings = FALSE)
  state <- list(schema = irm13_schema, repo = normalizePath(repo), run = normalizePath(run),
    library = old$library, parent = normalizePath(parent), template = old$template,
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    shared_base = system2("git", c("-C", repo, "rev-parse",
      "origin/validation/shared-fitforecast-v2-1.0.0"), stdout = TRUE),
    sources = list(), arms = irm13_arms, expected_jobs = list(smoke = 2L,
      selection_warm = 20L, selection = 20L, confirmation_warm = 6L,
      confirmation = 18L, fresh_warm = 12L, fresh = 36L), max_workers = 30L,
    review_gate = "stop_after_42_new_jobs_before_confirmation",
    scope = "gausmix_AL_p005_only_not_exAL_or_all_family_replacement",
    fresh_seeds = list(N1 = c(81511001L, 81511002L), N2 = c(81512001L, 81512002L),
      N3 = c(81513001L, 81513002L), N4 = c(81514001L, 81514002L)),
    forecast_contract = old$forecast_contract,
    decision_rule = "rank_observed_internal_check_loss_report_all_finite_gains_no_diagnostic_exclusion",
    publication = "coordinator_only_no_article_replacement_authorized")
  state$parent_closeout <- list(status = "COMPLETED_NO_JOINT_GAIN_DYNAMIC_PANEL_CLOSED",
    source_head = old$head, source_decision = file.path(parent, "selection_review.json"),
    completed_jobs = 30L, conditional_jobs_not_launched = 66L, article_changed = FALSE)
  for (replica in c("F1", "F2")) {
    path <- file.path(run, "sources", paste0(replica, ".csv"))
    stopifnot(file.copy(old$sources[[replica]]$path, path),
      unname(tools::sha256sum(path)) == old$sources[[replica]]$sha256)
    state$sources[[replica]] <- list(path = normalizePath(path), sha256 = old$sources[[replica]]$sha256)
  }
  e <- ifd11_runtime(repo, state$library)
  files <- irm13_sources(repo, e)
  common <- setdiff(files, irm13_own_sources(repo))
  archived <- read.csv(file.path(parent, "source_hashes.csv"))
  relative <- substring(common, nchar(repo) + 2L)
  idx <- match(file.path(old$repo, relative), archived$path)
  stopifnot(!anyNA(idx), identical(unname(tools::sha256sum(common)), archived$sha256[idx]))
  iqt12_csv(data.frame(path = common, sha256 = archived$sha256[idx], source_path = archived$path[idx]),
    file.path(run, "common_runtime_equivalence.csv"))
  controls <- irm13_import_controls(state)
  ledger <- irm13_history(history_roots, file.path(run, "history_inventory.csv"))
  iqt12_csv(data.frame(root = history_roots,
    audited_configs = vapply(history_roots, function(root)
      sum(startsWith(ledger$path, paste0(root, "/"))), 0L)), file.path(run, "history_roots.csv"))
  novelty <- do.call(rbind, lapply(irm13_arms, function(arm) {
    cfg <- irm13_config(state, arm, "F1", "A", "selection_warm")
    signature <- irm13_signature(cfg)
    data.frame(arm = arm, signature = signature,
      same_regime_hits = sum(ledger$spec_signature == signature),
      policy = "VB_or_pre_M0_exAL_failure_not_MCMC_exclusion")
  }))
  # A same-regime repeat requires an explicit evidence-reuse design, never a silent refit.
  stopifnot(all(novelty$same_regime_hits == 0L))
  iqt12_csv(novelty, file.path(run, "novelty.csv"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_json(list(version = as.character(packageVersion("exdqlm")),
    repository = packageDescription("exdqlm")$Repository, package_path = find.package("exdqlm"),
    session = capture.output(sessionInfo()), RNG = RNGkind(),
    threads = Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "BLIS_NUM_THREADS", "RCPP_PARALLEL_NUM_THREADS")),
    custom_cpp = "none_new_no_sourceCpp_worker_cache_access"), file.path(run, "environment.json"))
  keys <- c("CXX17", "CXX17FLAGS", "BLAS_LIBS", "LAPACK_LIBS", "SHLIB_OPENMP_CXXFLAGS")
  iqt12_csv(data.frame(key = keys, value = vapply(keys, function(key)
    paste(system2(file.path(R.home("bin"), "R"), c("CMD", "config", key),
      stdout = TRUE, stderr = TRUE), collapse = " "), "")), file.path(run, "compiler_settings.csv"))
  iqt12_hash(files, file.path(run, "source_hashes.csv"))
  iqt12_hash(list.files(file.path(state$library, "exdqlm"), recursive = TRUE, full.names = TRUE),
    file.path(run, "package_hashes.csv"))
  iqt12_hash(c(test_evidence, file.path(parent, c("campaign.json", "selection_review.json",
    "selection_review_hashes.csv", "source_hashes.csv"))), file.path(run, "input_hashes.csv"))
  iqt12_hash(file.path(run, c("campaign.json", "environment.json", "source_hashes.csv",
    "package_hashes.csv", "input_hashes.csv", "controls.csv", "control_import_hashes.csv",
    "common_runtime_equivalence.csv", "history_inventory.csv", "history_roots.csv", "novelty.csv", "compiler_settings.csv")),
    file.path(run, "frozen_hashes.csv"))
  ifd11_plan(state, "smoke", lapply(c("joint_shrink", "memory099"), function(arm)
    irm13_config(state, arm, "F1", "A", "smoke")))
  invisible(state)
}

irm13_own_sources <- function(repo) file.path(repo, "validation/fitforecast_v2", c(
  "R/independent_qdesn_readout_memory_v13.R", "scripts/independent_qdesn_readout_memory_v13.R",
  "scripts/run_independent_qdesn_readout_memory_v13.sh",
  "tests/test_independent_qdesn_readout_memory_v13.R",
  "docs/INDEPENDENT_QDESN_READOUT_MEMORY_V13_20261013.md"))
irm13_sources <- function(repo, e) unique(c(idl12_sources(repo, e), irm13_own_sources(repo)))

irm13_memory_diagnostics <- function(cx) {
  r <- cx$object$reservoir
  do.call(rbind, lapply(seq_len(r$D), function(d) {
    W <- as.matrix(r$W[[d]])
    radius <- max(Mod(eigen(diag(1-r$alpha[d], nrow(W)) + r$alpha[d]*W,
      only.values = TRUE)$values))
    H <- cx$object$states$H_all[[d]][cx$train, , drop = FALSE]
    data.frame(layer = d, alpha = r$alpha[d], rho_config = r$rho[d],
      linear_reference_radius = radius,
      linear_reference_half_life = if (radius > 0 && radius < 1) log(.5)/log(radius) else NA_real_,
      raw_tanh_saturation = mean(abs(H) > .99),
      max_initialization_readout_difference = cx$initialization_dependence,
      nonlinear_forgetting_bound = FALSE)
  }))
}

irm13_worker <- function(path) {
  cfg <- iqt12_read(path)
  for (name in c("input", "control_import")) iqt12_verify(file.path(cfg$run, paste0(name, "_hashes.csv")))
  if (cfg$stage %in% c("fresh_warm", "fresh")) iqt12_verify(file.path(cfg$run, "fresh_extension_hashes.csv"))
  assign("iqt12_runtime_hook", ifd11_runtime, .GlobalEnv)
  assign("iqt12_design_hook", ilr10_design_hook, .GlobalEnv)
  original <- ilr10_qforecast_hook
  assign("iqt12_qforecast_hook", function(e, cx, config, fit, draws, progress = NULL) {
    result <- original(e, cx, config, fit, draws, progress)
    if (config$engine == "mcmc" && config$stage != "smoke") for (shift in c(10L, 20L)) {
      replay <- config; replay$window <- idl12_phase_window(config$window, shift)
      fc <- original(e, cx, replay, fit, draws)
      idl12_save_phase(config, cx$object$X %*% t(draws$beta) * cx$scale,
        fc$primary, cx$source, shift)
    }
    iqt12_csv(irm13_memory_diagnostics(cx), file.path(config$evidence, "memory_diagnostics.csv"))
    result
  }, .GlobalEnv)
  baseline <- iqt12_baseline_forecast
  assign("iqt12_baseline_forecast", function(e, config, source, fit, progress = NULL) {
    result <- baseline(e, config, source, fit, progress)
    if (config$engine == "mcmc" && config$stage != "smoke") for (shift in c(10L, 20L)) {
      replay <- config; replay$window <- idl12_phase_window(config$window, shift)
      idl12_save_phase(config, e$ffv2_dqlm_conditional_quantile_draws(fit, config$outer),
        baseline(e, replay, source, fit), source, shift)
    }
    result
  }, .GlobalEnv)
  iqt12_worker(path)
  iqt12_json(list(status = "RUNNING", id = cfg$id, pid = Sys.getpid(), phase = "score_audit"), cfg$status_path)
  tryCatch({
    fit <- as.matrix(read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))[, -1L])
    fc <- as.matrix(read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))[, -(1:3)])
    z <- ifd11_score_companions(fit, fc, read.csv(cfg$source_path), cfg$window, cfg$p)
    old <- read.csv(file.path(cfg$evidence, "summary.csv"))
    stopifnot(max(abs(old$mean - z$summary$mean[match(old$metric, z$summary$metric)])) < 1e-6)
    iqt12_csv(z$summary, file.path(cfg$evidence, "score_companions.csv"))
    iqt12_csv(z$profile, file.path(cfg$evidence, "origin_lead_companions.csv.gz"))
    iqt12_csv(z$attribution, file.path(cfg$evidence, "covariance_attribution.csv"))
    manifest <- iqt12_hash(setdiff(list.files(cfg$evidence, full.names = TRUE),
      file.path(cfg$evidence, "manifest.csv")), file.path(cfg$evidence, "manifest.csv"))
    iqt12_verify(manifest)
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      fitted_binary_payloads = 0L, score_audit_tolerance = 1e-6,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE)), cfg$status_path)
  }, error = function(err) {
    iqt12_json(list(status = "FAILED_SCORE_AUDIT", id = cfg$id, error = conditionMessage(err)), cfg$status_path)
    stop(err)
  })
}

irm13_health <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  do.call(rbind, lapply(irm13_stages, function(stage) {
    p <- ifd11_plan_status(run, stage)
    status <- if (is.null(p)) rep("GATED", state$expected_jobs[[stage]]) else p$status
    stopifnot(length(status) == state$expected_jobs[[stage]])
    data.frame(stage = stage, complete = sum(status == "SUCCESS"), failed = sum(grepl("^FAILED", status)),
      running = sum(status == "RUNNING"), pending = sum(status == "PENDING"), gated = sum(status == "GATED"))
  }))
}

irm13_verify <- function(run) {
  for (name in c("source", "package", "input", "frozen", "control_import"))
    iqt12_verify(file.path(run, paste0(name, "_hashes.csv")))
  for (stage in irm13_stages) {
    p <- ifd11_plan_status(run, stage); if (is.null(p)) next
    iqt12_verify(file.path(run, "plans", paste0(stage, "_hashes.csv")))
    for (path in p$status_path[p$status == "SUCCESS"]) iqt12_verify(iqt12_read(path)$manifest)
  }
  for (name in c("selection_review_hashes.csv", "confirmation_review_hashes.csv",
    "closeout_manifest.csv", "fresh_extension_hashes.csv"))
    if (file.exists(file.path(run, name))) iqt12_verify(file.path(run, name))
  invisible(irm13_health(run))
}

irm13_records <- function(run, stage) {
  plan <- ifd11_plan_status(run, stage)
  stopifnot(all(plan$status == "SUCCESS"))
  paths <- plan$config_path
  if (stage == "selection") paths <- c(read.csv(file.path(run, "controls.csv"))$config_path, paths)
  configs <- lapply(paths, iqt12_read); records <- summaries <- list()
  cells <- unique(vapply(configs, function(cfg) paste(cfg$replica, cfg$window$fold, cfg$arm, sep = "__"), ""))
  for (cell in cells) {
    group <- configs[vapply(configs, function(cfg) paste(cfg$replica, cfg$window$fold, cfg$arm, sep = "__") == cell, TRUE)]
    stopifnot(length(group) == if (stage == "selection") 1L else 3L)
    fit <- do.call(cbind, lapply(group, function(cfg)
      as.matrix(read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))[, -1L])))
    fc <- do.call(cbind, lapply(group, function(cfg)
      as.matrix(read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))[, -(1:3)])))
    cfg <- group[[1L]]; source <- read.csv(cfg$source_path)
    score <- ifd11_score_companions(fit, fc, source, cfg$window, cfg$p)
    label <- paste(cfg$replica, cfg$window$fold, sep = "_")
    summaries[[cell]] <- cbind(replica = label, arm = cfg$arm, score$summary)
    records[[paste(label, cfg$arm, sep = "__")]] <- list(fit = fit, forecast = fc,
      source = source, w = cfg$window, profile = score$profile)
    iqt12_csv(score$attribution, file.path(run, "review", paste0(stage, "__", cell, "__covariance.csv")))
  }
  list(records = records, summary = do.call(rbind, summaries), configs = configs)
}

irm13_rank <- function(summary, candidates) {
  check <- summary[summary$metric == "forecast_check_loss", ]
  rank <- aggregate(check$mean, list(arm = check$arm), mean)
  names(rank)[2L] <- "mean_forecast_check_loss"
  rank <- rank[order(rank$mean_forecast_check_loss, rank$arm), ]
  selected <- rank$arm[rank$arm %in% candidates][1L]
  list(rank = rank, selected = selected,
    strict_check_gain_over_static = rank$mean_forecast_check_loss[rank$arm == selected] <
      rank$mean_forecast_check_loss[rank$arm == "static"])
}

irm13_review <- function(run, stage) {
  data <- irm13_records(run, stage)
  state <- iqt12_read(file.path(run, "campaign.json"))
  selected <- if (stage == "selection") irm13_rank(data$summary, state$arms)$selected else
    iqt12_read(file.path(run, "selection_review.json"))$selected
  rank <- irm13_rank(data$summary, selected)
  paired <- merge(data$summary[data$summary$arm %in% state$arms, ],
    data$summary[data$summary$arm %in% c("dqlm", "static"), ],
    by = c("replica", "metric"), suffixes = c("_candidate", "_control"))
  paired$strict_mean_gain <- paired$mean_candidate < paired$mean_control
  paired$mean_difference <- paired$mean_candidate - paired$mean_control
  paired$width_ratio <- (paired$upper_candidate-paired$lower_candidate)/
    (paired$upper_control-paired$lower_control)
  iqt12_csv(data$summary, file.path(run, "review", paste0(stage, "_summary.csv")))
  iqt12_csv(rank$rank, file.path(run, "review", paste0(stage, "_ranking.csv")))
  iqt12_csv(paired, file.path(run, "review", paste0(stage, "_paired.csv")))
  phase <- do.call(rbind, lapply(data$configs, function(cfg) do.call(rbind, lapply(c(10L, 20L), function(shift) {
    path <- file.path(cfg$evidence, paste0("phase", shift, "_summary.csv")); stopifnot(file.exists(path))
    cbind(replica = cfg$replica, fold = cfg$window$fold, arm = cfg$arm, chain = cfg$chain, read.csv(path))
  }))))
  iqt12_csv(phase, file.path(run, "review", paste0(stage, "_phase_summary.csv")))
  irm13_pdf(run, stage, data)
  three <- data$summary$arm %in% c("dqlm", "static", selected)
  idl12_pdf(run, stage, data$records, data$summary[three, ])
  stopifnot(file.rename(file.path(run, "review", paste0(stage, "_dynamic_location_review.pdf")),
    file.path(run, "review", paste0(stage, "_readout_memory_paths.pdf"))))
  decision <- list(status = "COMPLETE_REVIEW_REQUIRED", selected = selected,
    strict_check_gain_over_static = rank$strict_check_gain_over_static,
    ranking = "observed_internal_forecast_check_loss", oracle_ranking = FALSE,
    all_strict_metric_gains_retained = TRUE, diagnostic_exclusion = FALSE,
    pooling = "chains_within_replica_only_not_across_DGPs", article_changed = FALSE,
    next_stage = if (stage == "selection") "confirmation" else if (stage == "confirmation") "fresh" else "handoff",
    not_an_unbiased_joint_functional_interval_comparison = TRUE)
  path <- file.path(run, if (stage == "fresh") "closeout.json" else paste0(stage, "_review.json"))
  iqt12_json(decision, path)
  manifest <- if (stage == "fresh") "closeout_manifest.csv" else paste0(stage, "_review_hashes.csv")
  iqt12_hash(c(path, list.files(file.path(run, "review"), full.names = TRUE)), file.path(run, manifest))
  invisible(decision)
}

irm13_pdf <- function(run, stage, data) {
  summary <- data$summary; arms <- unique(summary$arm)
  colors <- setNames(c("#245FA6", "#B94B45", "#247C59", "#9D579B", "#DA8818", "#555555", "#00A3A3")[seq_along(arms)], arms)
  pdf(file.path(run, "review", paste0(stage, "_all_arms_metrics.pdf")), width = 11.7, height = 8.3,
    useDingbats = FALSE)
  on.exit(dev.off())
  for (cell in unique(summary$replica)) {
    par(mfrow = c(2, 3), mar = c(4, 8, 3, 1), oma = c(0, 0, 3, 0))
    for (metric in unique(summary$metric)) {
      z <- summary[summary$replica == cell & summary$metric == metric, ]
      z <- z[match(arms, z$arm), ]; ypos <- rev(seq_along(arms))
      plot(z$mean, ypos, type = "n", yaxt = "n", ylim = c(.5, length(arms)+.5),
        xlim = range(0, z$upper), xlab = "Score (lower is better)", ylab = "", main = metric)
      axis(2, ypos, arms, las = 1, cex.axis = .8)
      segments(z$lower, ypos, z$upper, ypos, col = colors, lwd = 2.5)
      points(z$mean, ypos, pch = 4, col = colors, lwd = 2)
      points(z$mean_path_score, ypos, pch = 1, col = colors)
    }
    plot.new(); text(.5, .6, "x: posterior mean draw score\no: score of posterior mean path\nNative 95% intervals, no draw shuffling\nDQLM marginal coupling differs from Q-DESN", cex = .85)
    mtext(paste(cell, "| all controlled contrasts; exploratory internal validation"), outer = TRUE, line = 1)
  }
}

irm13_advance <- function(run, stage) {
  p <- ifd11_plan_status(run, stage); stopifnot(!is.null(p), all(p$status == "SUCCESS"))
  irm13_verify(run); state <- iqt12_read(file.path(run, "campaign.json"))
  if (stage == "fresh_warm") state <- iqt12_read(file.path(run, "fresh_extension.json"))
  target <- switch(stage, smoke = "selection_warm", selection_warm = "selection",
    confirmation_warm = "confirmation", fresh_warm = "fresh", NULL)
  if (is.null(target)) {
    decision <- if (stage == "fresh") "closeout.json" else paste0(stage, "_review.json")
    if (!file.exists(file.path(run, decision))) irm13_review(run, stage)
  } else if (!file.exists(file.path(run, "plans", paste0(target, ".csv")))) {
    arms <- if (target %in% c("selection_warm", "selection")) state$arms else
      c("dqlm", "static", iqt12_read(file.path(run, "selection_review.json"))$selected)
    replicas <- if (target == "fresh") paste0("N", 1:4) else c("F1", "F2")
    folds <- if (target %in% c("selection_warm", "selection")) c("A", "B") else
      if (target == "fresh") "FINAL" else "C"
    chains <- if (target %in% c("confirmation", "fresh")) 1:3 else 1L
    configs <- unlist(lapply(replicas, function(replica) unlist(lapply(folds, function(fold)
      unlist(lapply(arms, function(arm) lapply(chains, function(chain)
        irm13_config(state, arm, replica, fold, target, chain))), recursive = FALSE)), recursive = FALSE)), recursive = FALSE)
    ifd11_plan(state, target, configs)
  }
  invisible(TRUE)
}

irm13_continue <- function(run, stage) {
  stopifnot(stage %in% c("confirmation_warm", "fresh_warm"))
  irm13_verify(run); state <- iqt12_read(file.path(run, "campaign.json"))
  decision <- iqt12_read(file.path(run, if (stage == "fresh_warm")
    "confirmation_review.json" else "selection_review.json"))
  stopifnot(isTRUE(decision$strict_check_gain_over_static))
  if (stage == "fresh_warm") {
    if (!file.exists(file.path(run, "fresh_extension.json"))) {
      helper <- ifd11_dgp_helper(state$repo)
      for (replica in paste0("N", 1:4)) {
        seeds <- as.integer(state$fresh_seeds[[replica]])
        path <- file.path(run, "sources", paste0(replica, ".csv")); stopifnot(!file.exists(path))
        iqt12_csv(ifd11_dgp(helper, seeds[1], seeds[2])$source, path)
        state$sources[[replica]] <- list(path = path, sha256 = unname(tools::sha256sum(path)))
      }
      iqt12_json(state, file.path(run, "fresh_extension.json"))
      iqt12_hash(c(file.path(run, "fresh_extension.json"),
        vapply(state$sources[paste0("N", 1:4)], `[[`, "", "path")),
        file.path(run, "fresh_extension_hashes.csv"))
    } else state <- iqt12_read(file.path(run, "fresh_extension.json"))
  }
  arms <- c("dqlm", "static", decision$selected)
  replicas <- if (stage == "fresh_warm") paste0("N", 1:4) else c("F1", "F2")
  fold <- if (stage == "fresh_warm") "FINAL" else "C"
  configs <- unlist(lapply(replicas, function(replica) lapply(arms, function(arm)
    irm13_config(state, arm, replica, fold, stage))), recursive = FALSE)
  ifd11_plan(state, stage, configs)
  invisible(TRUE)
}
