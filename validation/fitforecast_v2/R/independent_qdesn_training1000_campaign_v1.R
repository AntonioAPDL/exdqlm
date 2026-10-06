iqt12_stages <- c("cost", "diagnosis", "size_pilot", "normal1", "normal2", "normal3",
  "quantile_A", "quantile_B", "bridge", "final_vb", "final_warm", "final_mcmc")
iqt12_cell <- function(family, p, likelihood) paste(family, likelihood,
  sprintf("p%03d", as.integer(round(100 * p))), sep = "__")
iqt12_topology <- function(c) {
  n <- iqt12_unpack(c$n)
  c$input_fanin <- min(as.integer(c$input_fanin), as.integer(c$m) + 1L)
  c$recurrent_indegree <- min(as.integer(c$recurrent_indegree), min(n))
  c$interlayer_fanin <- min(as.integer(c$interlayer_fanin), min(n))
  if (length(n) == 1L) c$interlayer_fanin <- 1L
  c$matrix_seed <- 920001L
  stopifnot(c$input_fanin >= 1L, c$recurrent_indegree >= 1L, c$interlayer_fanin >= 1L)
  c
}
iqt12_signature <- function(c) {
  c <- iqt12_topology(c)
  fields <- c("n", "m", "alpha", "rho", "center_scale", "input_bound", "input_gain",
    "recurrent_indegree", "input_fanin", "interlayer_fanin", "matrix_seed")
  key <- c[fields]
  for (field in c("n", "center_scale", "input_bound")) key[[field]] <- as.character(key[[field]])
  for (field in c("m", "recurrent_indegree", "input_fanin", "interlayer_fanin", "matrix_seed"))
    key[[field]] <- as.integer(key[[field]])
  for (field in c("alpha", "rho", "input_gain")) key[[field]] <- as.numeric(key[[field]])
  digest::digest(jsonlite::toJSON(key, auto_unbox = TRUE, digits = NA),
    serialize = FALSE, algo = "sha256")
}
iqt12_candidate <- function(c, reference, multiplier = 1, role = "anchor") {
  c <- iqt12_topology(c)
  n <- iqt12_unpack(c$n)
  stopifnot(length(n) <= 5, sum(n) <= 2000, c$m <= 390,
    c$alpha > 0, c$alpha < 1, c$rho > 0, c$rho < 1)
  c$n_tilde <- paste(head(n, -1), collapse = ";")
  c$D <- length(n); c$total_states <- sum(n); c$readout_dimension <- sum(n) + 1L
  c$matrix_seed <- 920001L
  c$input_fanin_fraction <- c$input_fanin / (c$m + 1L)
  c$tau_source <- reference$tau_source * multiplier
  c$slab_source <- reference$slab_source
  c$sigma_b_source <- reference$sigma_b_source
  c$omega_b_source <- reference$omega_b_source
  c$role <- role; c$tau_multiplier <- multiplier
  c$structure_id <- substr(iqt12_signature(c), 1, 16)
  key <- list(structure = c$structure_id, tau = as.numeric(c$tau_source),
    slab = as.numeric(c$slab_source), sigma = as.numeric(c$sigma_b_source),
    omega = as.numeric(c$omega_b_source), schema = iqt12_schema)
  c$id <- substr(digest::digest(jsonlite::toJSON(key, auto_unbox = TRUE, digits = NA),
    serialize = FALSE, algo = "sha256"), 1, 20)
  c
}
iqt12_config <- function(state, cell, c, stage, engine = "vb", N = 1000L,
                          fold = "A", model = "qdesn", chain = 1L) {
  k <- match(cell, names(state$references)); ref <- state$references[[cell]]
  job <- paste(stage, cell, model, engine, N, c$id, chain, sep = "__")
  budget <- switch(stage,
    cost = list(outer = 4L, inner = 8L, vb = 40L, burn = 20L, retained = 40L),
    diagnosis = list(outer = 32L, inner = 32L, vb = 400L),
    size_pilot = list(outer = 32L, inner = 32L, vb = 400L, burn = 1000L, retained = 4000L),
    quantile_A = list(outer = 32L, inner = 32L, vb = 750L),
    quantile_B = list(outer = 120L, inner = 128L, vb = 750L),
    bridge = list(outer = 120L, inner = 128L, vb = 750L, burn = 1000L, retained = 4000L),
    final_vb = list(outer = 900L, inner = 128L, vb = 1000L),
    final_warm = list(outer = 4L, inner = 8L, vb = 1000L),
    final_mcmc = list(outer = if (engine == "mcmc") 300L else 900L,
      inner = 128L, vb = 1000L, burn = 5000L, retained = 20000L),
    list(outer = 16L, inner = 32L, vb = 200L))
  w <- iqt12_window(fold, N)
  if (stage %in% c("cost", "final_warm")) w$origins <- head(w$origins, 2L)
  list(schema = iqt12_schema, run = state$run, repo = state$repo, library = state$library,
    id = job, cell = cell, family = ref$family, p = ref$p, likelihood = ref$likelihood,
    candidate = c, stage = stage, engine = engine, model = model, chain = chain,
    source_path = ref$source_path, source_sha = ref$source_sha,
    baseline = ref$baseline, window = w, outer = budget$outer, inner = budget$inner,
    vb_iter = budget$vb, normal_iter = 200L,
    burn = budget$burn %||% 0L, retained = budget$retained %||% 0L,
    seed = as.integer(64000000L +
      (if (engine == "normal") match(ref$family, c("normal", "laplace", "gausmix")) else k) * 100000L +
      match(stage, iqt12_stages) * 1000L + chain),
    path = file.path(state$run, "configs", paste0(job, ".json")),
    status_path = file.path(state$run, "status", paste0(job, ".json")),
    evidence = file.path(state$run, "evidence", job),
    timeout = if (grepl("^final", stage)) 172800L else 43200L)
}
iqt12_plan <- function(state, configs, stage) {
  path <- file.path(state$run, "plans", paste0(stage, ".csv"))
  if (file.exists(path)) stop("Frozen stage already exists: ", stage)
  rows <- lapply(configs, function(c) {
    iqt12_json(c, c$path)
    data.frame(id = c$id, stage = stage, cell = c$cell, model = c$model,
      engine = c$engine, N = c$window$N, fold = c$window$fold,
      candidate_id = c$candidate$id, columns = c$candidate$readout_dimension,
      config_path = c$path, config_sha = unname(tools::sha256sum(c$path)),
      status_path = c$status_path, timeout = c$timeout)
  })
  out <- if (length(rows)) do.call(rbind, rows) else data.frame(id = character(),
    stage = character(), cell = character(), model = character(), engine = character(),
    N = integer(), fold = character(), candidate_id = character(), columns = integer(),
    config_path = character(), config_sha = character(), status_path = character(), timeout = integer())
  stopifnot(!anyDuplicated(out$id)); iqt12_csv(out, path)
  iqt12_hash(c(path, out$config_path), file.path(state$run, "plans", paste0(stage, "_hashes.csv")))
  out
}

iqt12_materialize <- function(repo, run, library, plan_packet, broad, previous, preflight) {
  if (dir.exists(run)) stop("Refusing to overwrite a campaign.")
  pf <- iqt12_read(file.path(preflight, "preflight.json"))
  stopifnot(isTRUE(pf$pass), isTRUE(pf$normal_affine_share_pass))
  iqt12_verify(file.path(plan_packet, "input_manifest.csv"))
  bank <- read.csv(file.path(broad, "manifests/broad_candidates.csv"), stringsAsFactors = FALSE)
  baselines <- read.csv(file.path(broad, "plans/development_comparator.csv"), stringsAsFactors = FALSE)
  sources <- read.csv(file.path(plan_packet, "source_expected_manifest.csv"), stringsAsFactors = FALSE)
  state <- list(schema = iqt12_schema, repo = repo, run = run, library = library,
    head = system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE),
    references = list(), bank = list(), max_workers = 15L,
    normal_shared = isTRUE(pf$normal_affine_share_pass), final_publication = FALSE,
    maximum_campaign_cpu_hours = 1200, maximum_stage_wall_hours = 48,
    storage_limit_gib = 40, max_worker_rss_gib = 12,
    maximum_explicit_jobs_if_shared = 1204L,
    maximum_underlying_fit_calls_if_shared = 1590L,
    maximum_explicit_jobs_if_not_shared = 2356L,
    maximum_underlying_fit_calls_if_not_shared = 2742L)
  campaign <- iqt12_read(file.path(previous, "campaign.json"))
  inputs <- c(file.path(broad, "manifests/broad_candidates.csv"),
    file.path(broad, "plans/development_comparator.csv"),
    file.path(previous, "campaign.json"), file.path(plan_packet, "PLAN.md"),
    file.path(plan_packet, "input_manifest.csv"),
    file.path(preflight, c("checks.csv", "preflight.json")))
  iqt12_json(pf, file.path(run, "preflight.json"))
  iqt12_csv(read.csv(file.path(preflight, "checks.csv")), file.path(run, "preflight_checks.csv"))
  article_repo <- "/data/jaguir26/local/src/Article-Q-DESN---Version-2"
  authority_relative <- "tables/qdesn_validation_500obs_metric_intervals_v10_summary.csv"
  authority_head <- system2("git", c("-C", article_repo, "rev-parse", "origin/main"), stdout = TRUE)
  live <- system2("git", c("-C", article_repo, "ls-remote", "origin", "refs/heads/main"), stdout = TRUE)
  stopifnot(length(live) == 1L, strsplit(live, "[[:space:]]+")[[1]][1] == authority_head)
  lines <- system2("git", c("-C", article_repo, "show", paste0(authority_head, ":", authority_relative)), stdout = TRUE)
  snapshot <- file.path(run, "previous_article_summary.csv")
  iqt12_csv(read.csv(text = paste(lines, collapse = "\n")), snapshot)
  state$previous_authority <- list(repo = article_repo, path = authority_relative, head = authority_head,
    provenance = "freshly_verified_remote_main_git_object_not_task_worktree_file",
    git_blob = system2("git", c("-C", article_repo, "rev-parse", paste0(authority_head, ":", authority_relative)), stdout = TRUE),
    snapshot_sha256 = unname(tools::sha256sum(snapshot)), training_N = 500L,
    comparison = "descriptive_different_training_information_and_forecast_estimators")
  inputs <- c(inputs, snapshot)
  for (family in c("normal", "laplace", "gausmix")) for (p in c(.05, .25, .50)) {
    tag <- sprintf("tau_%sp%02d", as.integer(p), as.integer(round(100 * p)))
    source <- file.path("/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources",
      "dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast", family, tag, "series_wide.csv")
    stopifnot(file.exists(source))
    frozen <- sources[sources$path == source, ]
    stopifnot(nrow(frozen) == 1L, unname(tools::sha256sum(source)) == frozen$sha256)
    original <- read.csv(source)
    stopifnot(nrow(original) == 10000L, all(original$q_target == original$mu))
    snapshot <- file.path(run, "sources", paste0(family, "_", tag, ".csv"))
    iqt12_csv(original[6611:10000, ], snapshot)
    for (likelihood in c("al", "exal")) {
      cell <- iqt12_cell(family, p, likelihood)
      rows <- bank[bank$cell_id == cell & bank$representation_role == "current_article_authority", ]
      anchor_provenance <- list(kind = "broad_ledger_current_authority_structural_replay",
        source = file.path(broad, "manifests/broad_candidates.csv"))
      if (!nrow(rows)) {
        # The legacy article envelope can have different metric sources; recover its MAE source.
        registry_path <- file.path(repo, "config/validation/independent_metric_intervals_v1_audit/source_replay_registry.csv")
        registry <- read.csv(registry_path, stringsAsFactors = FALSE)
        variant <- if (likelihood == "al") "qdesn_al_rhs_ns" else "qdesn_exal_rhs_ns"
        old <- read.csv(file.path(run, "previous_article_summary.csv"))
        replay <- old$forecast_mae_replay_id[old$family == family & old$tau == p &
          old$inference == "mcmc" & old$model_variant == variant]
        stopifnot(length(replay) == 1L)
        entry <- registry[registry$replay_id == replay, ]
        stopifnot(nrow(entry) == 1L)
        request <- file.path(repo, entry$request_path)
        stopifnot(file.exists(request), unname(tools::sha256sum(request)) == entry$request_sha256)
        archived <- iqt12_read(request); d <- archived$config$desn
        row <- as.list(bank[bank$cell_id == cell, ][1, ])
        row$n <- paste(unlist(d$n), collapse = ";"); row$m <- d$m
        row$alpha <- d$alpha; row$rho <- as.numeric(d$rho)[1]
        row$input_gain <- 1; row$center_scale <- "mean_sd"; row$input_bound <- "none"
        row$recurrent_indegree <- max(1L, round(min(unlist(d$n)) * d$pi_w))
        row$input_fanin <- max(1L, ceiling((d$m + 1L) * d$pi_in))
        row$interlayer_fanin <- max(1L, round(min(unlist(d$n)) * d$pi_in))
        row$response_scale <- sd(original$y[seq.int(archived$root_spec$raw_start_source_index,
          archived$root_spec$train_end_source_index)])
        row$rhs_tau0_source_scale <- archived$root_spec$rhs_tau0 * row$response_scale
        anchor_provenance <- list(kind = "recovered_legacy_MAE_structural_specification",
          replay_id = replay, request = request, sha256 = entry$request_sha256,
          adaptation = "new_seed_exact_fanin_identity_Q_reservoir_only_readout_not_exact_legacy_fit_replay")
        inputs <- c(inputs, registry_path, request)
      } else row <- as.list(rows[which.min(rows$tau0_multiplier), ])
      candidate <- row
      ref <- list(tau_source = row$rhs_tau0_source_scale,
        slab_source = row$response_scale^2,
        sigma_b_source = row$response_scale, omega_b_source = row$response_scale^2)
      if (family == "normal" && ((likelihood == "al" && p == .05) ||
          (likelihood == "exal" && p == .25))) {
        key <- if (likelihood == "al") "normal_al_p005" else "normal_exal_p025"
        old <- campaign$references[[key]]$candidate
        candidate <- old
        ref$tau_source <- old$rhs_tau0_source_scale %||%
          (old$rhs_tau0 * old$response_scale)
        anchor_provenance <- list(kind = "repaired_V10_priority_anchor", source = previous, key = key)
      }
      c <- iqt12_candidate(candidate, ref)
      base <- baselines[baselines$family == family & abs(baselines$probability - p) < 1e-12 &
        baselines$likelihood_family == likelihood, ]
      stopifnot(nrow(base) == 1L,
        unname(tools::sha256sum(base$source_config_path)) == base$source_config_sha256)
      inputs <- c(inputs, source, base$source_config_path)
      state$references[[cell]] <- list(family = family, p = p, likelihood = likelihood,
        candidate = c, source_path = snapshot, source_sha = unname(tools::sha256sum(snapshot)),
        original_source = source, original_sha = unname(tools::sha256sum(source)),
        baseline = iqt12_read(base$source_config_path), anchor_provenance = anchor_provenance)
    }
  }
  # Exact historical designs are replayed explicitly; new designs have unique identities.
  set.seed(920112L)
  for (family in c("normal", "laplace", "gausmix")) {
    rows <- bank[bank$family == family, ]; rows <- rows[!duplicated(rows$canonical_structure_signature), ]
    anchors <- lapply(state$references[grepl(paste0("^", family, "__"), names(state$references))],
      function(z) z$candidate)
    historical <- c(anchors, lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, ])))
    keys <- vapply(historical, iqt12_signature, "")
    structures <- head(historical[!duplicated(keys)], 8L)
    stopifnot(length(structures) == 8L)
    reference <- state$references[[iqt12_cell(family, .5, "al")]]$candidate
    for (i in 9:64) {
      anchor <- structures[[1L + ((i - 9L) %% 8L)]]
      D <- if (i <= 32L) length(iqt12_unpack(anchor$n)) else 1L + ((i - 33L) %% 4L)
      widths <- if (i <= 32L) iqt12_unpack(anchor$n) else
        sample(c(64L, 128L, 200L, 300L, 500L), D, replace = TRUE)
      if (i >= 33L && i <= 40L) widths[1] <- 500L
      c <- anchor; c$n <- paste(widths, collapse = ";")
      c$m <- sample(c(30L, 60L, 90L, 120L, 180L, 240L, 300L, 360L, 390L), 1)
      c$alpha <- sample(c(.05, .15, .3, .4, .55, .7, .85, .95, .99), 1)
      c$rho <- sample(c(.5, .7, .9, .97, .995), 1)
      if (i >= 33L) {
        c$alpha <- c(.05, .15, .3, .4, .55, .7, .85, .95, .99)[1L + ((i - 33L) %% 9L)]
        c$rho <- c(.5, .7, .9, .97, .995)[1L + ((i - 33L) %% 5L)]
      }
      c$input_gain <- sample(c(.05, .2, .5, 1, 2), 1)
      c$input_fanin <- max(1L, ceiling((c$m + 1L) * sample(c(.1, .25, .5, 1), 1)))
      c$recurrent_indegree <- min(sample(c(10L, 20L, 40L), 1), min(widths))
      c$interlayer_fanin <- min(sample(c(10L, 20L, 40L), 1), min(widths))
      c$center_scale <- sample(c("mean_sd", "median_mad"), 1)
      c$input_bound <- sample(c("none", "tanh_z_over_3"), 1)
      if (i <= 32L) {
        # Local means two declared perturbations, not another independent random design.
        fields <- sample(c("n", "m", "alpha", "rho", "input_gain",
          "input_fanin", "recurrent_indegree", "interlayer_fanin", "center_scale", "input_bound"), 2L)
        proposed <- c; c <- anchor
        for (field in fields) c[[field]] <- proposed[[field]]
        if ("n" %in% fields) {
          nn <- iqt12_unpack(c$n); j <- sample(seq_along(nn), 1)
          nn[j] <- sample(c(64L, 128L, 200L, 300L, 500L), 1)
          if (sum(nn) <= 2000L) c$n <- paste(nn, collapse = ";")
        }
      }
      # A small continuous leakage perturbation resolves accidental duplicate proposals.
      c <- iqt12_topology(c)
      existing <- vapply(structures, iqt12_signature, "")
      while (iqt12_signature(c) %in% existing) c$alpha <- runif(1L, .05, .99)
      structures[[i]] <- c
    }
    stopifnot(length(structures) == 64L)
    candidates <- list()
    order_bank <- c(1:8, 33:48, 9:28, 29:32, 49:64)
    for (j in seq_along(order_bank)) for (mult in c(.1, 1, 10)) {
      i <- order_bank[j]
      c <- iqt12_candidate(structures[[i]], reference, mult,
        if (i <= 8L) "historical_repaired_replay" else if (i <= 32L) "local_capacity_search" else "stratified_unseen")
      c$bank_index <- j
      candidates[[length(candidates) + 1L]] <- c
    }
    stopifnot(length(candidates) == 192L,
      !anyDuplicated(vapply(candidates, function(z) z$id, "")))
    state$bank[[family]] <- candidates
    iqt12_csv(do.call(rbind, lapply(candidates, function(c) data.frame(
      family = family, id = c$id, structure_id = c$structure_id,
      role = c$role, bank_index = c$bank_index, n = c$n, m = c$m,
      alpha = c$alpha, rho = c$rho, tau_source = c$tau_source))),
      file.path(run, "candidate_banks", paste0(family, ".csv")))
  }
  e <- iqt12_runtime(repo, library)
  oracle <- expand.grid(family = c("normal", "laplace", "gausmix"), p = c(.05, .25, .5),
    stringsAsFactors = FALSE)
  oracle$expected_check <- mapply(e$idor_v1_expected_check_analytic, oracle$family, oracle$p)
  numeric_check <- mapply(e$idor_v1_expected_check_numerical, oracle$family, oracle$p)
  stopifnot(max(abs(oracle$expected_check - numeric_check)) <= 1e-6)
  iqt12_csv(oracle, file.path(run, "oracle_references.csv"))
  runtime_paths <- c(e$iqt12_loaded_files,
    file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_runtime_v1.R"),
    file.path(repo, "validation/fitforecast_v2/R/independent_qdesn_training1000_campaign_v1.R"),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), pattern = "training1000", full.names = TRUE))
  iqt12_hash(runtime_paths, file.path(run, "source_hashes.csv"))
  iqt12_hash(inputs, file.path(run, "input_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE, full.names = TRUE),
    file.path(run, "package_hashes.csv"))
  iqt12_json(state, file.path(run, "campaign.json"))
  iqt12_json(list(version = as.character(packageVersion("exdqlm")), repository = "CRAN",
    tarball_sha256 = iqt12_tar_sha, library = library, session = capture.output(sessionInfo()),
    effective_functions = lapply(c("qdesn_fit_vb", "exal_ldvb_fit", "exal_mcmc_fit", ".solve_sympd"),
      function(k) list(name = k, owner = "private_IND_extension", hash = digest::digest(e[[k]], algo = "sha256"))),
    official_functions = lapply(c("exdqlmLDVB", "exdqlmMCMC", "exdqlmForecast"),
      function(k) list(name = k, owner = "official_CRAN_namespace", hash = digest::digest(get(k, asNamespace("exdqlm")), algo = "sha256"))),
    threads = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"))),
    RNGkind = RNGkind(), compiler = system2(file.path(R.home("bin"), "R"), c("CMD", "config", "CXX17"), stdout = TRUE),
    inference_options = options()[c("exdqlm.use_cpp_mcmc", "exdqlm.cpp_mcmc_mode", "exdqlm.use_cpp_postpred")],
    BLAS_LAPACK = as.list(extSoftVersion()),
    provenance = "CRAN_baselines_plus_explicit_IND_extension_not_stock_CRAN_QDESN"),
    file.path(run, "environment.json"))
  old_plans <- list.files(file.path(previous, "plans"), pattern = "[.]csv$", full.names = TRUE)
  old_status <- unlist(lapply(old_plans, function(path) {
    z <- read.csv(path)
    if (!"status_path" %in% names(z)) return(character())
    vapply(z$status_path, function(s) if (file.exists(s)) iqt12_read(s)$status else "PENDING", "")
  }))
  stopifnot(!any(old_status == "RUNNING"))
  iqt12_json(list(status = "INCOMPLETE_IMPLEMENTATION_FAILURE_NOT_SCIENTIFIC_NO_GAIN",
    previous = previous, successful = sum(old_status == "SUCCESS"),
    failed = sum(grepl("FAILED", old_status)), pending = sum(old_status == "PENDING"),
    original_runtime_action = "NONE_PRESERVED", resumed = FALSE), file.path(run, "previous_V11_closeout.json"))
  configs <- list()
  for (cell in c(iqt12_cell("normal", .05, "al"), iqt12_cell("normal", .25, "exal"))) {
    for (model in c("qdesn", "baseline")) for (engine in c("vb", "mcmc"))
      configs[[length(configs) + 1L]] <- iqt12_config(state, cell,
        state$references[[cell]]$candidate, "cost", engine, model = model)
  }
  iqt12_plan(state, configs, "cost")
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json", "source_hashes.csv",
    "input_hashes.csv", "package_hashes.csv", "previous_V11_closeout.json",
    "preflight.json", "preflight_checks.csv", "previous_article_summary.csv", "oracle_references.csv")),
    vapply(state$references, function(z) z$source_path, "")), file.path(run, "frozen_hashes.csv"))
  state
}

iqt12_worker <- function(path) {
  cfg <- iqt12_read(path); start <- proc.time()[["elapsed"]]
  e <- iqt12_runtime(cfg$repo, cfg$library)
  iqt12_verify(file.path(cfg$run, "source_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "package_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "frozen_hashes.csv"))
  iqt12_verify(file.path(cfg$run, "plans", paste0(cfg$stage, "_hashes.csv")))
  stopifnot(unname(tools::sha256sum(cfg$source_path)) == cfg$source_sha,
    !file.exists(cfg$status_path))
  dir.create(cfg$evidence, recursive = TRUE, showWarnings = FALSE)
  iqt12_json(list(status = "RUNNING", pid = Sys.getpid(), id = cfg$id,
    started = format(Sys.time(), tz = "UTC", usetz = TRUE)), cfg$status_path)
  warnings <- character()
  tryCatch(withCallingHandlers({
    source <- read.csv(cfg$source_path)
    # Source-index alignment is explicit, never a hardcoded local offset.
    full <- as.data.frame(matrix(NA_real_, max(source$t), ncol(source)))
    names(full) <- names(source); full[source$t, ] <- source
    source <- full
    fitting <- proc.time()[["elapsed"]]
    progress <- function(i, total) iqt12_json(list(status = "RUNNING", pid = Sys.getpid(),
      id = cfg$id, phase = "forecast", origin = i, total_origins = total,
      elapsed = proc.time()[["elapsed"]] - start), cfg$status_path)
    if (cfg$model == "baseline") {
      fit <- iqt12_baseline_fit(e, cfg, source)
      fit_draws <- e$ffv2_dqlm_conditional_quantile_draws(fit, cfg$outer)
      if (cfg$engine == "vb") iqt12_json(list(initial = list(
        sig.out = fit$sig.out, gammasig.out = fit$gammasig.out,
        vts.out = list(E.uts = fit$vts.out$E.uts),
        sts.out = list(E.sts = fit$sts.out$E.sts),
        theta.out = list(sm = unname(fit$theta.out$sm)))),
        file.path(cfg$evidence, "mcmc_initializer.json"))
      seconds_fit <- proc.time()[["elapsed"]] - fitting
      q <- iqt12_baseline_forecast(e, cfg, source, fit, progress)
      diag <- list(proposal = if (cfg$likelihood == "al") "gamma_fixed" else
          fit$mh.diagnostics$proposal %||% "structured_VB",
        gamma = summary(fit$samp.gamma %||% fit$qsiggam$gamma_draws),
        sigma = summary(fit$samp.sigma %||% fit$qsiggam$sigma_draws),
        method = if (cfg$likelihood == "al") paste0("CRAN_AL_gamma_fixed_", cfg$engine) else
          if (cfg$engine == "mcmc") "CRAN_collapsed_slice" else "CRAN_structured_LDVB")
      if (cfg$engine == "vb" && cfg$likelihood == "exal") diag$sigmagam <- list(
        factorization = fit$gammasig.out$factorization,
        gamma_mean = fit$gammasig.out$E.gam, sigma_mean = fit$gammasig.out$E.sigma)
      if (cfg$engine == "mcmc") diag$trace_diagnostics <- list(
        sigma_ESS = unname(coda::effectiveSize(fit$samp.sigma)),
        gamma_ESS = if (cfg$likelihood == "exal") unname(coda::effectiveSize(fit$samp.gamma)) else NA_real_,
        diagnostic_exclusion_gate = FALSE)
      if (cfg$engine == "mcmc") iqt12_csv(data.frame(iteration = seq_along(fit$samp.sigma),
        sigma = fit$samp.sigma, gamma = fit$samp.gamma %||% rep(0, cfg$retained)),
        file.path(cfg$evidence, "nuisance_trace.csv.gz"))
    } else {
      cx <- iqt12_design(e, cfg, source, cfg$window$end)
      if (cfg$engine == "normal") {
        object <- iqt12_normal(e, cx, cfg)
        draws <- e$normal_desn_posterior_draws(object, cfg$outer, seed = cfg$seed)
        fit_draws <- cx$object$X %*% t(draws$beta) * cx$scale
        seconds_fit <- proc.time()[["elapsed"]] - fitting
        q <- iqt12_normal_forecast(e, cx, cfg, object, draws)
        diag <- list(converged = object$fit$converged,
          initializer = "normal_RHS_screen_not_quantile_gate")
      } else {
        fit <- iqt12_quantile(e, cx, cfg)
        draws <- iqt12_draws(e, fit, cfg$outer, cfg$seed + 1L)
        if (cfg$engine == "vb") iqt12_json(list(design_hash = cx$design_hash,
          initial = list(beta = as.numeric(fit$qbeta$m), sigma = fit$qsiggam$sigma_mean,
            gamma = if (cfg$likelihood == "al") 0 else fit$qsiggam$gamma_mean,
            v = fit$qv$E_v, s = fit$qs$E_s), prior_state_transferred = FALSE),
          file.path(cfg$evidence, "mcmc_initializer.json"))
        fit_draws <- cx$object$X %*% t(draws$beta) * cx$scale
        seconds_fit <- proc.time()[["elapsed"]] - fitting
        fc <- iqt12_qforecast(e, cx, cfg, fit, draws, progress)
        q <- fc$primary
        if (cfg$stage %in% c("final_vb", "final_mcmc") && cfg$chain == 1L &&
            cfg$cell == iqt12_cell("normal", .25, "exal")) {
          doubled <- cfg; doubled$inner <- 256L
          refined <- iqt12_qforecast(e, cx, doubled, fit, draws, progress)
          low <- iqt12_scores(fit_draws, q, source, cfg$window, cfg$p)$summary
          high <- iqt12_scores(fit_draws, refined$primary, source, cfg$window, cfg$p)$summary
          audit <- merge(low, high, by = "metric", suffixes = c("_128", "_256"))
          audit$mean_change <- audit$mean_256 - audit$mean_128
          audit$coupling <- "same_outer_draws_nested_256_noise_bank_first128"
          iqt12_csv(audit, file.path(cfg$evidence, "inner_precision_audit.csv"))
        }
        iqt12_csv(cbind(iqt12_grid(cfg$window), fc$plugin), file.path(cfg$evidence, "plugin_location_draws.csv.gz"))
        iqt12_csv(data.frame(draw = seq_len(nrow(draws$beta)), sigma = draws$sigma,
          gamma = draws$gamma, draws$beta), file.path(cfg$evidence, "selected_parameters.csv.gz"))
        diag <- list(converged = fit$converged %||% NA,
          method = fit$diagnostics$core_update_mode %||% "structured_full_covariance_VB",
          diagnostics = fit$diagnostics %||% list(),
          sigma_trace = summary(fit$samp.sigma), gamma_trace = summary(fit$samp.gamma))
        diag$posterior_sigmagam_draw_contract <- draws$sigmagam_draw_contract
        if (cfg$engine == "vb") diag$sigmagam <- list(
          gamma_mean = fit$qsiggam$gamma_mean,
          sigma_mean_source_units = fit$qsiggam$sigma_mean * cx$scale,
          factorization = if (cfg$likelihood == "exal") "structured_qgamma_qsigma_given_gamma" else "gamma_fixed")
        if (cfg$engine == "mcmc") diag$trace_diagnostics <- list(
          sigma_ESS = unname(coda::effectiveSize(fit$samp.sigma)),
          gamma_ESS = if (cfg$likelihood == "exal") unname(coda::effectiveSize(fit$samp.gamma)) else NA_real_,
          intercept_ESS = unname(coda::effectiveSize(fit$samp.beta[, 1])),
          diagnostic_exclusion_gate = FALSE)
        if (cfg$engine == "mcmc") iqt12_csv(data.frame(iteration = seq_along(fit$samp.sigma),
          sigma = fit$samp.sigma * cx$scale, gamma = fit$samp.gamma,
          intercept = fit$samp.beta[, 1] * cx$scale),
          file.path(cfg$evidence, "nuisance_trace.csv.gz"))
      }
      diag$initialization_dependence <- cx$initialization_dependence
      diag$initialization_grade <- if (cx$initialization_dependence > 1e-6) "WARN_SLOW_FORGETTING" else "PASS"
      diag$design_hash <- cx$design_hash; diag$scale_only <- cx$scale
      diag$reservoir_matrix_hash <- digest::digest(cx$object$reservoir[c("W", "Win", "Q")], algo = "sha256")
      diag$spectral_diagnostics <- cx$object$reservoir$spectral_diagnostics
      diag$achieved_fanin <- lapply(cx$object$reservoir$Win, function(w)
        summary(as.numeric(Matrix::rowSums(w != 0))))
      diag$saturation_fraction <- mean(abs(cx$object$X[, -1, drop = FALSE]) > .99)
      center <- colMeans(cx$object$X[, -1, drop = FALSE])
      sd_features <- apply(cx$object$X[, -1, drop = FALSE], 2, sd)
      origins <- do.call(rbind, lapply(cfg$window$origins, function(o) {
        local <- o - cx$first + 1L
        x <- cx$all_X[local + 1L, -1]
        lagz <- (cx$y[local - seq_len(cx$object$reservoir$m) + 1L] -
          cx$preprocessing$center) / cx$preprocessing$scale
        data.frame(origin = o, one_step_state_saturation = mean(abs(x) > .99),
          max_abs_observed_lag_z = max(abs(lagz)),
          standardized_feature_displacement = sqrt(mean((x - center)^2 / (sd_features^2 + 1e-12))))
      }))
      iqt12_csv(origins, file.path(cfg$evidence, "origin_feature_diagnostics.csv"))
      diag$causal_contract <- list(washout = 500L, likelihood = cfg$window$N,
        complete_buffer = 390L, identity_Q = TRUE, readout = "intercept_plus_all_layers",
        teacher_forced_between_origins = TRUE, recursive_within_origin = TRUE,
        preprocessing_last = max(cfg$window$train), mean_estimator = "inner_average_after_recursion")
    }
    score <- iqt12_scores(fit_draws, q, source, cfg$window, cfg$p)
    # Normal candidates rank observed errors, not shifted oracle quantile recovery.
    if (cfg$engine == "normal") {
      g <- iqt12_grid(cfg$window)
      observed <- mean(abs(q - source$y[g$target]))
    } else observed <- NA_real_
    add <- data.frame(id = cfg$id, cell = cfg$cell, candidate_id = cfg$candidate$id,
      model = cfg$model, engine = cfg$engine, family = cfg$family, p = cfg$p,
      N = cfg$window$N, fold = cfg$window$fold, chain = cfg$chain,
      normal_observed_mae = observed)
    result <- cbind(add[rep(1, nrow(score$summary)), ], score$summary)
    iqt12_csv(result, file.path(cfg$evidence, "summary.csv"))
    iqt12_csv(score$draws, file.path(cfg$evidence, "metric_draws.csv.gz"))
    iqt12_csv(score$profile, file.path(cfg$evidence, "origin_lead.csv.gz"))
    iqt12_csv(cbind(source_index = cfg$window$train, fit_draws), file.path(cfg$evidence, "fit_location_draws.csv.gz"))
    iqt12_csv(cbind(iqt12_grid(cfg$window), q), file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
    diag$warnings <- warnings; diag$fit_seconds <- seconds_fit
    diag$canonical_configuration_key <- digest::digest(list(
      configuration = unname(tools::sha256sum(path)),
      sources = unname(tools::sha256sum(file.path(cfg$run, "source_hashes.csv"))),
      package = unname(tools::sha256sum(file.path(cfg$run, "package_hashes.csv")))), algo = "sha256")
    diag$fit_calls <- if (cfg$engine == "normal") 1L else if (cfg$model == "baseline")
      if (cfg$engine == "mcmc" && is.null(cfg$warm_path)) 2L else 1L else
      if (cfg$engine == "vb") 2L else if (is.null(cfg$warm_path)) 3L else 1L
    diag$warm_path <- cfg$warm_path %||% "fresh_normal_RHS_then_quantile_VB"
    diag$total_seconds <- proc.time()[["elapsed"]] - start
    diag$cpu_seconds <- sum(proc.time()[c("user.self", "sys.self")])
    diag$forecast_seconds <- diag$total_seconds - seconds_fit
    status_lines <- readLines("/proc/self/status")
    diag$peak_rss_kib <- as.numeric(gsub("[^0-9]", "", status_lines[grepl("^VmHWM:", status_lines)]))
    iqt12_json(diag, file.path(cfg$evidence, "diagnostics.json"))
    files <- list.files(cfg$evidence, full.names = TRUE)
    manifest <- iqt12_hash(files, file.path(cfg$evidence, "manifest.csv"))
    iqt12_json(list(status = "SUCCESS", id = cfg$id, manifest = manifest,
      elapsed = diag$total_seconds, cpu_seconds = diag$cpu_seconds,
      completed_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
      fitted_binary_payloads = 0L), cfg$status_path)
  }, warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }),
    error = function(err) {
      iqt12_json(list(status = "FAILED_IMPLEMENTATION", id = cfg$id,
        error = conditionMessage(err), elapsed = proc.time()[["elapsed"]] - start), cfg$status_path)
      stop(err)
    })
}

iqt12_results <- function(run, stages) {
  rows <- list()
  for (stage in stages) {
    plan <- read.csv(file.path(run, "plans", paste0(stage, ".csv")), stringsAsFactors = FALSE)
    for (i in seq_len(nrow(plan))) {
      s <- iqt12_read(plan$status_path[i]); stopifnot(s$status == "SUCCESS")
      iqt12_verify(s$manifest)
      cfg <- iqt12_read(plan$config_path[i])
      z <- read.csv(file.path(cfg$evidence, "summary.csv"), stringsAsFactors = FALSE)
      z$config_path <- cfg$path; rows[[length(rows) + 1L]] <- z
    }
  }
  do.call(rbind, rows)
}

iqt12_rank <- function(z) {
  wide <- reshape(z[c("config_path", "metric", "mean", "candidate_id")],
    idvar = c("config_path", "candidate_id"), timevar = "metric", direction = "wide")
  wide$columns <- vapply(wide$config_path, function(p) iqt12_read(p)$candidate$readout_dimension, 0L)
  wide[order(wide$mean.forecast_mae, wide$mean.forecast_check_loss,
    wide$mean.fit_rmse, wide$columns, wide$candidate_id), ]
}

iqt12_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  results <- iqt12_results(run, finished)
  iqt12_csv(results, file.path(run, "summaries", paste0(finished, ".csv")))
  next_stage <- iqt12_stages[match(finished, iqt12_stages) + 1L]
  if (finished == "final_mcmc") return(iqt12_closeout(run))
  configs <- list(); add <- function(c) configs[[length(configs) + 1L]] <<- c
  if (finished == "cost") {
    plans <- read.csv(file.path(run, "plans/cost.csv"))
    costs <- lapply(plans$config_path, function(p) {
      cfg <- iqt12_read(p); d <- iqt12_read(file.path(cfg$evidence, "diagnostics.json"))
      data.frame(model = cfg$model, engine = cfg$engine, cell = cfg$cell,
        fit_seconds = d$fit_seconds, forecast_seconds = d$forecast_seconds,
        peak_rss_gib = d$peak_rss_kib / 1024^2,
        projected_final_forecast_seconds = d$forecast_seconds *
          (34 / 2) * (if (cfg$engine == "vb") 900 / 4 else 300 / 4) *
          (if (cfg$model == "qdesn") 128 / 8 else 1),
        projected_final_fit_seconds = d$fit_seconds *
          (if (cfg$engine == "mcmc") 25000 / 60 else 1000 / 40))
    })
    cost <- do.call(rbind, costs); iqt12_csv(cost, file.path(run, "summaries/cost_gate.csv"))
    if (any(cost$peak_rss_gib > state$max_worker_rss_gib) ||
        any(cost$projected_final_forecast_seconds + cost$projected_final_fit_seconds > 48 * 3600))
      stop("Measured resource envelope exceeds authorization; cost review required.")
    for (cell in names(state$references)) for (N in c(500L, 1000L))
      for (model in c("qdesn", "baseline")) add(iqt12_config(state, cell,
        state$references[[cell]]$candidate, next_stage, N = N, model = model))
  } else if (finished == "diagnosis") {
    small <- results[results$N == 500L, ]; big <- results[results$N == 1000L, ]
    paired <- merge(small, big, by = c("cell", "model", "metric"), suffixes = c("_500", "_1000"))
    paired$ratio_1000_over_500 <- paired$mean_1000 / paired$mean_500
    paired$strict_gain <- paired$mean_1000 < paired$mean_500
    iqt12_csv(paired, file.path(run, "summaries/training_size_contrast.csv"))
    for (cell in c(iqt12_cell("normal", .05, "al"), iqt12_cell("normal", .25, "exal")))
      for (N in c(500L, 1000L)) for (model in c("qdesn", "baseline"))
        {
          cfg <- iqt12_config(state, cell, state$references[[cell]]$candidate,
            next_stage, engine = "mcmc", N = N, model = model)
          row <- results[results$cell == cell & results$model == model & results$N == N, ][1, ]
          warm <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
          cfg$warm_path <- warm; cfg$warm_sha <- unname(tools::sha256sum(warm)); add(cfg)
        }
  } else if (finished %in% c("size_pilot", "normal1", "normal2")) {
    if (finished == "size_pilot") {
      contrast <- read.csv(file.path(run, "summaries/training_size_contrast.csv"))
      primary <- contrast[contrast$model == "qdesn" & contrast$metric == "forecast_mae", ]
      if (mean(primary$strict_gain) < .5 || median(primary$ratio_1000_over_500) > 1) {
        iqt12_json(list(status = "PAUSED_TRAINING_SIZE_REVIEW",
          reason = "N1000 did not improve at least half the fixed-design Q cases on fold A",
          improvement_count = sum(primary$strict_gain), cases = nrow(primary),
          median_ratio = median(primary$ratio_1000_over_500),
          article_change = FALSE), file.path(run, "scientific_gate.json"))
        stop("Training-size evidence requires investigator review before broad scheduling.")
      }
    }
    wave <- match(next_stage, c("normal1", "normal2", "normal3"))
    indices <- list(1:24, 25:44, 45:64)[[wave]]
    # Sharing is enabled only by the separately verified affine-contract preflight.
    share <- iqt12_read(file.path(run, "preflight.json"))$normal_affine_share_pass
    for (family in names(state$bank)) for (p in if (isTRUE(share)) .5 else c(.05, .25, .5))
      for (c in state$bank[[family]]) if (c$bank_index %in% indices)
        add(iqt12_config(state, iqt12_cell(family, p, "al"), c,
          next_stage, engine = "normal"))
  } else if (finished == "normal3") {
    normal <- iqt12_results(run, c("normal1", "normal2", "normal3"))
    selected <- list()
    for (cell in names(state$references)) {
      ref <- state$references[[cell]]; z <- normal[normal$family == ref$family & normal$metric == "forecast_mae", ]
      z <- z[order(z$normal_observed_mae, z$candidate_id), ]; z <- z[!duplicated(z$candidate_id), ]
      selected[[cell]] <- head(z, 50L)
      iqt12_csv(selected[[cell]], file.path(run, "selections", paste0("normal_top50_", cell, ".csv")))
      pairs <- list()
      structure <- vapply(z$config_path, function(p) iqt12_read(p)$candidate$structure_id, "")
      ix <- which(!duplicated(structure))
      chosen <- unique(c(head(ix, 6L), seq_len(nrow(z))))
      for (p in z$config_path[head(chosen, 8L)]) {
        c <- iqt12_read(p)$candidate
        c <- iqt12_candidate(c, ref$candidate, c$tau_multiplier, "normal_shortlist")
        pairs[[length(pairs) + 1L]] <- c
      }
      # Quantile-specific bypass preserves the anchor and both strong shrinkage directions.
      for (mult in c(.1, 1, 10)) pairs[[length(pairs) + 1L]] <-
        iqt12_candidate(ref$candidate, ref$candidate, mult, "quantile_anchor_bypass")
      c <- tail(state$bank[[ref$family]], 1)[[1]]
      pairs[[length(pairs) + 1L]] <- iqt12_candidate(c, ref$candidate, 1, "capacity_bypass")
      ids <- vapply(pairs, function(c) c$id, "")
      pairs <- pairs[!duplicated(ids)]
      for (p in z$config_path) {
        if (length(pairs) >= 12L) break
        c <- iqt12_read(p)$candidate
        c <- iqt12_candidate(c, ref$candidate, c$tau_multiplier, "normal_shortlist_fill")
        if (!c$id %in% vapply(pairs, function(v) v$id, "")) pairs[[length(pairs) + 1L]] <- c
      }
      stopifnot(length(pairs) <= 12L,
        length(unique(vapply(pairs, function(v) v$structure_id, ""))) >= 6L)
      for (c in pairs) add(iqt12_config(state, cell, c, next_stage))
    }
  } else if (finished == "quantile_A") {
    for (cell in names(state$references)) {
      z <- results[results$cell == cell, ]; rank <- iqt12_rank(z)
      check <- z[z$metric == "forecast_check_loss", ]; check <- check[order(check$mean), ]
      anchor <- z[z$candidate_id == state$references[[cell]]$candidate$id, ]
      capacity <- rank[order(-rank$columns, rank$mean.forecast_mae), ]
      paths <- unique(c(anchor$config_path, head(rank$config_path, 1L),
        head(check$config_path, 1L), capacity$config_path, rank$config_path))
      paths <- head(paths, 4L)
      nominees <- do.call(rbind, lapply(paths, function(p) {
        c <- iqt12_read(p)$candidate
        add(iqt12_config(state, cell, c, next_stage, fold = "B"))
        data.frame(cell = cell, candidate_id = c$id, fold_A_config = p)
      }))
      iqt12_csv(nominees, file.path(run, "selections", paste0("frozen_B_", cell, ".csv")))
    }
  } else if (finished == "quantile_B") {
    for (cell in names(state$references)) {
      z <- results[results$cell == cell & results$metric == "forecast_mae", ]
      for (p in z$config_path) {
        ref <- iqt12_read(p); cfg <- iqt12_config(state, cell, ref$candidate,
          next_stage, engine = "mcmc", fold = "B")
        cfg$warm_path <- file.path(ref$evidence, "mcmc_initializer.json")
        cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path)); add(cfg)
      }
      add(iqt12_config(state, cell, state$references[[cell]]$candidate,
        next_stage, engine = "mcmc", fold = "B", model = "baseline"))
    }
  } else if (finished == "bridge") {
    vb <- iqt12_results(run, "quantile_B")
    winners <- list()
    for (cell in names(state$references)) {
      for (engine in c("vb", "mcmc")) {
        z <- if (engine == "vb") vb[vb$cell == cell, ] else
          results[results$cell == cell & results$model == "qdesn", ]
        winner <- iqt12_rank(z)$config_path[1]
        c <- iqt12_read(winner)$candidate
        winners[[length(winners) + 1L]] <- data.frame(cell = cell, engine = engine,
          candidate_id = c$id, selection_config = winner)
        if (engine == "vb") {
          add(iqt12_config(state, cell, c, next_stage, engine, fold = "final"))
          add(iqt12_config(state, cell, state$references[[cell]]$candidate, next_stage,
            engine, fold = "final", model = "baseline"))
        }
      }
    }
    iqt12_csv(do.call(rbind, winners), file.path(run, "selections/frozen_final_winners.csv"))
  } else if (finished == "final_vb") {
    winners <- read.csv(file.path(run, "selections/frozen_final_winners.csv"))
    for (cell in names(state$references)) {
      mc <- winners[winners$cell == cell & winners$engine == "mcmc", ]
      vb <- winners[winners$cell == cell & winners$engine == "vb", ]
      if (mc$candidate_id != vb$candidate_id) add(iqt12_config(state, cell,
        iqt12_read(mc$selection_config)$candidate, next_stage, fold = "final"))
    }
  } else if (finished == "final_warm") {
    finals <- iqt12_results(run, c("final_vb", "final_warm"))
    winners <- read.csv(file.path(run, "selections/frozen_final_winners.csv"))
    for (cell in names(state$references)) for (model in c("qdesn", "baseline")) {
      mc <- winners[winners$cell == cell & winners$engine == "mcmc", ]
      c <- if (model == "qdesn") iqt12_read(mc$selection_config)$candidate else
        state$references[[cell]]$candidate
      row <- finals[finals$cell == cell & finals$model == model &
        finals$candidate_id == c$id, ][1, ]
      warm <- file.path(iqt12_read(row$config_path)$evidence, "mcmc_initializer.json")
      for (chain in 1:3) {
        cfg <- iqt12_config(state, cell, c, next_stage, "mcmc", fold = "final", model = model, chain = chain)
        cfg$warm_path <- warm; cfg$warm_sha <- unname(tools::sha256sum(warm)); add(cfg)
      }
    }
  }
  iqt12_plan(state, configs, next_stage)
  next_stage
}

iqt12_closeout <- function(run) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  z <- iqt12_results(run, c("final_vb", "final_mcmc"))
  summaries <- list(); i <- 0L
  for (cell in names(state$references)) for (model in c("baseline", "qdesn")) for (engine in c("vb", "mcmc")) {
    rows <- z[z$cell == cell & z$model == model & z$engine == engine & z$metric == "forecast_mae", ]
    stopifnot(nrow(rows) == if (engine == "mcmc") 3L else 1L)
    draws <- do.call(rbind, lapply(rows$config_path, function(p) {
      cfg <- iqt12_read(p); read.csv(file.path(cfg$evidence, "metric_draws.csv.gz"))
    }))
    for (metric in setdiff(names(draws), "draw")) {
      ci <- quantile(draws[[metric]], c(.025, .975), names = FALSE, type = 8)
      i <- i + 1L; summaries[[i]] <- data.frame(cell = cell, model = model, engine = engine,
        metric = metric, mean = mean(draws[[metric]]), lower = ci[1], upper = ci[2],
        chains = nrow(rows), posterior_draws = nrow(draws),
        candidate_id = rows$candidate_id[1])
    }
  }
  summary <- do.call(rbind, summaries)
  iqt12_csv(summary, file.path(run, "review/four_model_metric_intervals.csv"))
  base <- summary[summary$model == "baseline", ]; q <- summary[summary$model == "qdesn", ]
  gains <- merge(q, base, by = c("cell", "engine", "metric"), suffixes = c("_Q", "_DQLM"))
  gains$strict_gain <- gains$mean_Q < gains$mean_DQLM
  gains$ratio_Q_over_DQLM <- gains$mean_Q / gains$mean_DQLM
  gains$decision_scope <- "matched_N1000_comparison_not_automatic_article_promotion"
  iqt12_csv(gains, file.path(run, "review/matched_baseline_gap_ledger.csv"))
  nuisance <- list()
  mc <- z[z$engine == "mcmc" & z$metric == "forecast_mae", ]
  for (cell in names(state$references)) for (model in c("baseline", "qdesn")) {
    rows <- mc[mc$cell == cell & mc$model == model, ]
    traces <- lapply(rows$config_path, function(p) read.csv(file.path(iqt12_read(p)$evidence, "nuisance_trace.csv.gz")))
    parameters <- setdiff(Reduce(intersect, lapply(traces, names)), "iteration")
    for (param in parameters) {
      values <- lapply(traces, function(t) t[[param]])
      finite <- all(vapply(values, function(v) all(is.finite(v)) && sd(v) > 0, TRUE))
      diagnostic <- if (finite) tryCatch(coda::gelman.diag(coda::mcmc.list(lapply(values, coda::mcmc)),
        autoburnin = FALSE, multivariate = FALSE)$psrf[1, ], error = function(e) c(NA, NA)) else c(NA, NA)
      nuisance[[length(nuisance) + 1L]] <- data.frame(cell = cell, model = model,
        parameter = param, Rhat = diagnostic[1], Rhat_upper = diagnostic[2],
        diagnostic_scope = if (finite) "disclosed_not_exclusion_rule" else "constant_or_nonfinite_trace")
    }
  }
  iqt12_csv(do.call(rbind, nuisance), file.path(run, "review/multichain_nuisance_diagnostics.csv"))
  old <- read.csv(file.path(run, "previous_article_summary.csv"))
  old_long <- do.call(rbind, lapply(seq_len(nrow(old)), function(j) {
    o <- old[j, ]; like <- if (o$model_variant %in% c("exdqlm", "qdesn_exal_rhs_ns")) "exal" else "al"
    data.frame(cell = iqt12_cell(o$family, o$tau, like),
      model = if (grepl("^qdesn", o$model_variant)) "qdesn" else "baseline",
      engine = o$inference, metric = c("fit_rmse", "forecast_mae", "forecast_check_loss"),
      mean_N500 = unlist(o[c("fit_qtrue_rmse", "forecast_qtrue_mae_H1000", "forecast_check_loss_H1000")]))
  }))
  history <- merge(summary, old_long, by = c("cell", "model", "engine", "metric"))
  history$strict_gain <- history$mean < history$mean_N500
  history$comparison <- "DESCRIPTIVE_ONLY_N1000_vs_historical_N500_estimators_not_identical"
  iqt12_csv(history, file.path(run, "review/historical_authority_comparison.csv"))
  iqt12_granular_review(run, z)
  iqt12_review_pdf(run, summary)
  iqt12_export_tables(run, summary)
  payloads <- list.files(run, recursive = TRUE, full.names = TRUE,
    pattern = "[.](rds|rda|RData)$", ignore.case = TRUE)
  stopifnot(!length(payloads))
  iqt12_json(list(status = "COMPLETE_REVIEW_REQUIRED", article_changed = FALSE,
    scientific_decision = "NOT_READY_FOR_INTEGRATION_UNTIL_INVESTIGATOR_REVIEW",
    primary_fit_jobs = nrow(read.csv(file.path(run, "plans/final_vb.csv"))) +
      nrow(read.csv(file.path(run, "plans/final_mcmc.csv"))),
    interval_rows = nrow(summary), fitted_model_binaries = 0L,
    familiar_final_block_not_pristine = TRUE,
    limitations = c("Different training information than retained N500 authority",
      "Conditional-location recovery is not the multi-step mixture quantile",
      "Intervals include finite inner Monte Carlo noise", "Chain grades are disclosed, not exclusion gates")),
    file.path(run, "closeout.json"))
  iqt12_hash(list.files(file.path(run, "review"), recursive = TRUE, full.names = TRUE),
    file.path(run, "review_manifest.csv"))
  "COMPLETE"
}

iqt12_export_tables <- function(run, summary) {
  for (engine in c("vb", "mcmc")) for (family in c("normal", "laplace", "gausmix")) {
    lines <- c("% Generated review asset: not an article promotion.",
      "\\begin{tabular}{lccc}", "\\toprule",
      "Model & Fit RMSE & Forecast MAE & Forecast check loss \\\\", "\\midrule")
    for (p in c(.05, .25, .5)) {
      lines <- c(lines, sprintf("\\multicolumn{4}{c}{\\(p=%.2f\\)} \\\\", p))
      for (model in c("baseline", "qdesn")) for (like in c("al", "exal")) {
        row <- summary[summary$engine == engine & summary$model == model &
          summary$cell == iqt12_cell(family, p, like), ]
        row <- row[match(c("fit_rmse", "forecast_mae", "forecast_check_loss"), row$metric), ]
        labels <- c(baseline_al = "DQLM", baseline_exal = "exDQLM",
          qdesn_al = "Q--DESN AL--RHS", qdesn_exal = "Q--DESN exAL--RHS")
        panel <- summary[summary$engine == engine &
          summary$cell %in% c(iqt12_cell(family, p, "al"), iqt12_cell(family, p, "exal")), ]
        best <- vapply(row$metric, function(k) min(panel$mean[panel$metric == k]), 0.0)
        entries <- sprintf("%.3g [%.3g, %.3g]", row$mean, row$lower, row$upper)
        ix <- row$mean == best
        entries[ix] <- sprintf("\\textbf{%.3g} [%.3g, %.3g]", row$mean[ix], row$lower[ix], row$upper[ix])
        lines <- c(lines, paste0(labels[[paste(model, like, sep = "_")]], " & ",
          paste(entries, collapse = " & "), " \\\\"))
      }
    }
    lines <- c(lines, "\\bottomrule", "\\end{tabular}")
    writeLines(lines, file.path(run, "review", paste0(engine, "_", family, "_intervals.tex")))
  }
}

iqt12_granular_review <- function(run, results) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  profiles <- list()
  colors <- c(baseline_al = "#4477AA", qdesn_al = "#228833",
    baseline_exal = "#CC6677", qdesn_exal = "#AA3377")
  pdf_path <- file.path(run, "review/independent_training1000_quantile_paths_review.pdf")
  grDevices::pdf(pdf_path, width = 13, height = 8.5, onefile = TRUE)
  on.exit(grDevices::dev.off())
  for (engine in c("vb", "mcmc")) for (family in c("normal", "laplace", "gausmix")) for (p in c(.05, .25, .5)) {
    paths <- list(); truth <- NULL
    for (key in names(colors)) {
      like <- if (grepl("_exal$", key)) "exal" else "al"
      model <- sub("_(exal|al)$", "", key)
      cell <- iqt12_cell(family, p, like)
      rows <- results[results$cell == cell & results$engine == engine &
        results$model == model & results$metric == "forecast_mae", ]
      fit <- forecast <- list()
      for (i in seq_len(nrow(rows))) {
        cfg <- iqt12_read(rows$config_path[i])
        f <- read.csv(file.path(cfg$evidence, "fit_location_draws.csv.gz"))
        q <- read.csv(file.path(cfg$evidence, "forecast_location_draws.csv.gz"))
        fit[[i]] <- as.matrix(f[, -1, drop = FALSE])
        forecast[[i]] <- as.matrix(q[, -(1:3), drop = FALSE])
        truth <- read.csv(cfg$source_path)
      }
      paths[[key]] <- list(fit = do.call(cbind, fit), forecast = do.call(cbind, forecast))
      src <- truth$q_target[match(q$target, truth$t)]
      draws <- paths[[key]]$forecast; err <- draws - src
      per <- cbind(q[, 1:3], family = family, p = p, engine = engine, model = key,
        q_mean = rowMeans(draws), lower = apply(draws, 1, quantile, .025),
        upper = apply(draws, 1, quantile, .975), true = src,
        mae = rowMeans(abs(err)), bias = rowMeans(err),
        check_loss = rowMeans((truth$y[match(q$target, truth$t)] - draws) *
          (p - (truth$y[match(q$target, truth$t)] < draws))))
      profiles[[length(profiles) + 1L]] <- per
    }
    par(mfrow = c(2, 4), mar = c(3, 3.5, 2, 1), oma = c(0, 0, 2, 0))
    for (part in c("fit", "forecast")) {
      xx <- if (part == "fit") 8001:9000 else 9001:10000
      oracle <- truth$q_target[match(xx, truth$t)]
      ranges <- lapply(paths, function(z) apply(z[[part]], 1, quantile, c(.025, .975)))
      limits <- range(c(oracle, unlist(ranges)), finite = TRUE)
      for (key in names(colors)) {
        z <- paths[[key]][[part]]; ci <- ranges[[key]]
        titles <- c(baseline_al = "DQLM (AL)", qdesn_al = "Q-DESN (AL-RHS)",
          baseline_exal = "exDQLM (exAL)", qdesn_exal = "Q-DESN (exAL-RHS)")
        plot(xx, oracle, type = "n", ylim = limits, xlab = "Source observation",
          ylab = paste(part, "quantile"), main = titles[[key]], cex.main = .8)
        polygon(c(xx, rev(xx)), c(ci[1, ], rev(ci[2, ])), border = NA,
          col = grDevices::adjustcolor(colors[[key]], alpha.f = .18))
        lines(xx, rowMeans(z), col = colors[[key]], lwd = 1)
        lines(xx, oracle, col = "black", lty = 2, lwd = 1)
      }
    }
    mtext(sprintf("%s | %s | p=%.2f | black dashed: known conditional quantile", family, toupper(engine), p), outer = TRUE)
  }
  z <- do.call(rbind, profiles)
  iqt12_csv(z, file.path(run, "review/final_origin_lead_profiles.csv.gz"))
  grouping <- c("family", "p", "engine", "model")
  for (axis in c("lead", "origin")) {
    g <- z[c(grouping, axis)]
    out <- aggregate(z[c("mae", "bias", "check_loss")], g, mean)
    iqt12_csv(out, file.path(run, "review", paste0(axis, "_profiles.csv")))
  }
  z$region <- ifelse(z$origin < 9500, "early_origin", "late_origin")
  iqt12_csv(aggregate(z[c("mae", "bias", "check_loss")], z[c(grouping, "region")], mean),
    file.path(run, "review/early_late_origin_comparison.csv"))
  iqt12_csv(aggregate(z[z$lead == 1, c("mae", "bias", "check_loss")],
    z[z$lead == 1, grouping], mean), file.path(run, "review/lead1_comparison.csv"))
  pdf_path
}

iqt12_review_pdf <- function(run, summary) {
  oracle <- read.csv(file.path(run, "oracle_references.csv"))
  colors <- c(baseline_al = "#4477AA", qdesn_al = "#228833",
    baseline_exal = "#CC6677", qdesn_exal = "#AA3377")
  path <- file.path(run, "review/independent_training1000_intervals_review.pdf")
  grDevices::pdf(path, width = 11, height = 8, onefile = TRUE)
  on.exit(grDevices::dev.off())
  for (engine in c("vb", "mcmc")) for (family in c("normal", "laplace", "gausmix")) {
    par(mfrow = c(3, 3), mar = c(3.5, 5, 2, 1), oma = c(1, 0, 2, 0))
    for (p in c(.05, .25, .5)) for (metric in c("fit_rmse", "forecast_mae", "forecast_check_loss")) {
      cells <- c(iqt12_cell(family, p, "al"), iqt12_cell(family, p, "exal"))
      zz <- summary[summary$engine == engine & summary$cell %in% cells & summary$metric == metric, ]
      zz$like <- ifelse(grepl("__exal__", zz$cell), "exal", "al")
      zz$key <- paste(zz$model, zz$like, sep = "_")
      zz <- zz[match(names(colors), zz$key), ]
      plot(zz$mean, 4:1, xlim = c(0, max(zz$upper) * 1.05), ylim = c(.5, 4.5),
        yaxt = "n", ylab = "", xlab = gsub("_", " ", metric),
        main = sprintf("p = %.2f", p), pch = 4, col = colors, cex = .9)
      axis(2, at = 4:1, labels = c("DQLM", "Q-DESN AL", "exDQLM", "Q-DESN exAL"),
        las = 1, cex.axis = .7)
      segments(zz$lower, 4:1, zz$upper, 4:1, col = colors, lwd = 2)
      points(zz$mean, 4:1, col = colors, pch = 4, cex = .9)
      reference <- if (metric == "forecast_check_loss")
        oracle$expected_check[oracle$family == family & abs(oracle$p - p) < 1e-12] else 0
      abline(v = reference, lty = 2, col = "black")
    }
    mtext(paste(family, toupper(engine), "mean scores and 95% intervals; dashed: conditional DGP oracle reference"), outer = TRUE)
  }
  path
}

iqt12_health <- function(run) {
  plans <- list.files(file.path(run, "plans"), pattern = "[.]csv$", full.names = TRUE)
  plans <- plans[!grepl("_hashes[.]csv$", plans)]
  rows <- lapply(plans, function(p) {
    z <- read.csv(p)
    statuses <- vapply(z$status_path, function(s) if (file.exists(s)) iqt12_read(s)$status else "PENDING", "")
    data.frame(stage = sub("[.]csv$", "", basename(p)), planned = nrow(z),
      complete = sum(statuses == "SUCCESS"), running = sum(statuses == "RUNNING"),
      failed = sum(grepl("FAILED", statuses)), pending = sum(statuses == "PENDING"))
  })
  do.call(rbind, rows)
}
