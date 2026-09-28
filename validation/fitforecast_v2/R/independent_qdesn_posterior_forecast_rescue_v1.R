iqpfr_v1_schema <- "independent_qdesn_posterior_forecast_rescue_v1"
iqpfr_v1_expected_branch <-
  "validation/independent-qdesn-posterior-forecast-rescue-v1-20260928"
iqpfr_v1_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_posterior_forecast_rescue_v1",
  "protocol_defaults.yaml"
)

iqpfr_v1_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqpfr_v1_protocol_relpath)
  if (!file.exists(path)) stop("Missing posterior-rescue protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}

iqpfr_v1_hard_cells <- function(protocol = iqpfr_v1_read_protocol()) {
  cells <- expand.grid(
    family = as.character(protocol$scope$families),
    tau = as.numeric(protocol$scope$quantiles),
    likelihood_family = as.character(protocol$scope$likelihoods),
    stringsAsFactors = FALSE
  )
  excluded <- protocol$scope$excluded_success_cells
  for (cell in excluded) {
    keep <- !(cells$family == as.character(cell$family) &
                abs(cells$tau - as.numeric(cell$quantile)) < 1e-12 &
                cells$likelihood_family == as.character(cell$likelihood)
    )
    cells <- cells[keep, , drop = FALSE]
  }
  cells[order(cells$family, cells$likelihood_family, cells$tau), , drop = FALSE]
}

iqpfr_v1_authority_path <- function(protocol, key) {
  entry <- protocol$authorities$files[[key]]
  if (is.null(entry)) stop("Unknown authority key: ", key, call. = FALSE)
  root <- if (grepl("^comparator_", key)) {
    protocol$authorities$comparator_root
  } else {
    protocol$authorities$redesign_root
  }
  file.path(as.character(root), as.character(entry$relative_path))
}

iqpfr_v1_verify_authorities <- function(protocol = iqpfr_v1_read_protocol()) {
  keys <- names(protocol$authorities$files)
  rows <- lapply(keys, function(key) {
    path <- iqpfr_v1_authority_path(protocol, key)
    expected <- as.character(protocol$authorities$files[[key]]$sha256)
    observed <- iqfr_v2_sha256(path)
    data.frame(
      authority = key, path = path, expected_sha256 = expected,
      observed_sha256 = observed,
      pass = file.exists(path) && identical(observed, expected),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (any(!out$pass)) {
    stop("Posterior-rescue authority verification failed: ",
         paste(out$authority[!out$pass], collapse = ", "), call. = FALSE)
  }
  out
}

iqpfr_v1_protocol_checks <- function(protocol = iqpfr_v1_read_protocol()) {
  cells <- iqpfr_v1_hard_cells(protocol)
  expected <- protocol$execution$expected_jobs
  checks <- c(
    protocol_id = identical(protocol$protocol$id, iqpfr_v1_schema),
    lane = identical(protocol$protocol$scientific_lane,
                     "independent_single_quantile_qdesn_dqlm_validation"),
    no_article_write = !isTRUE(protocol$protocol$article_write_permitted) &&
      !isTRUE(protocol$protocol$shared_validation_merge_permitted) &&
      !isTRUE(protocol$protocol$overleaf_write_permitted),
    cells = nrow(cells) == 17L &&
      !any(cells$family == "laplace" & cells$tau == 0.05 &
             cells$likelihood_family == "al"),
    candidates = as.integer(protocol$candidate_pool$historical_per_family) == 50L &&
      as.integer(protocol$candidate_pool$novel_per_family) == 10L &&
      as.integer(protocol$candidate_pool$total_per_family) == 60L,
    validation_lattice =
      as.integer(protocol$selection$validation_origins$start) == 8800L &&
      as.integer(protocol$selection$validation_origins$end) == 8970L &&
      as.integer(protocol$selection$validation_origins$stride) == 1L &&
      as.integer(protocol$selection$horizon) == 30L &&
      as.integer(protocol$selection$expected_validation_origins) == 171L &&
      as.integer(protocol$selection$expected_validation_pairs) == 5130L,
    primary_estimator = identical(
      protocol$selection$primary_estimator,
      "mean_readout_state_recursive"
    ),
    m0 = identical(protocol$scope$exal_method_id,
                   "m0_v_collapsed_support_logit"),
    jobs = as.integer(expected$pilot) == 1020L &&
      as.integer(expected$replication) == 102L &&
      as.integer(expected$confirmation) == 51L &&
      as.integer(expected$total) == 1173L,
    workers = as.integer(protocol$execution$workers) == 15L &&
      as.integer(protocol$execution$threads_per_worker) == 1L
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqpfr_v1_assert_protocol <- function(protocol = iqpfr_v1_read_protocol()) {
  checks <- iqpfr_v1_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Posterior-rescue protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "), call. = FALSE)
  }
  invisible(checks)
}

iqpfr_v1_bind_columns <- function(...) {
  xs <- list(...)
  columns <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(columns, names(x))
    for (field in missing) x[[field]] <- NA
    x[columns]
  })
  out <- do.call(rbind, xs)
  rownames(out) <- NULL
  out
}

iqpfr_v1_candidate_features <- function(x) {
  data.frame(
    D = as.numeric(x$D),
    total_states = log1p(as.numeric(x$total_states)),
    m = log1p(as.numeric(x$m)),
    alpha = as.numeric(x$alpha), rho = as.numeric(x$rho),
    log_tau0 = log10(as.numeric(x$rhs_tau0)),
    input_gain = log10(as.numeric(x$input_gain)),
    recurrent_indegree = log1p(as.numeric(x$recurrent_indegree)),
    input_fraction = as.numeric(x$input_fanin) /
      pmax(1, as.numeric(x$m) + 1),
    interlayer_fanin = log1p(as.numeric(x$interlayer_fanin)),
    robust_scale = as.numeric(as.character(x$center_scale) == "median_mad"),
    bounded_input = as.numeric(as.character(x$input_bound) != "none"),
    stringsAsFactors = FALSE
  )
}

iqpfr_v1_scaled_features <- function(reference, target) {
  joined <- rbind(iqpfr_v1_candidate_features(reference),
                  iqpfr_v1_candidate_features(target))
  n_ref <- nrow(reference)
  for (field in names(joined)) {
    lo <- min(joined[[field]], na.rm = TRUE)
    hi <- max(joined[[field]], na.rm = TRUE)
    joined[[field]] <- if (hi > lo) (joined[[field]] - lo) / (hi - lo) else 0
  }
  list(reference = as.matrix(joined[seq_len(n_ref), , drop = FALSE]),
       target = as.matrix(joined[n_ref + seq_len(nrow(target)), , drop = FALSE]))
}

iqpfr_v1_min_distance <- function(query, reference) {
  vapply(seq_len(nrow(query)), function(i) {
    min(sqrt(rowSums((reference - matrix(query[i, ], nrow(reference),
                                         ncol(reference), byrow = TRUE))^2)))
  }, numeric(1L))
}

iqpfr_v1_historical_parents <- function(protocol, family, history) {
  path <- iqpfr_v1_authority_path(protocol, "historical_mcmc_pilots")
  pilot <- utils::read.csv(path, check.names = FALSE,
                           stringsAsFactors = FALSE)
  pilot <- pilot[pilot$family == family &
                   pilot$estimator == "mean_readout_state_recursive", ,
                 drop = FALSE]
  cells <- interaction(pilot$family, pilot$tau, pilot$likelihood_family,
                       drop = TRUE)
  pilot$cell_rank <- ave(pilot$forecast_qtrue_mae_mean, cells,
                         FUN = function(z) rank(z, ties.method = "first"))
  aggregate_rank <- aggregate(
    cell_rank ~ candidate_id, data = pilot,
    FUN = function(z) c(best = min(z), mean = mean(z), appearances = length(z))
  )
  unpacked <- as.data.frame(aggregate_rank$cell_rank)
  aggregate_rank <- cbind(
    aggregate_rank["candidate_id"], unpacked,
    stringsAsFactors = FALSE
  )
  aggregate_rank <- aggregate_rank[order(
    aggregate_rank$best, aggregate_rank$mean, -aggregate_rank$appearances,
    aggregate_rank$candidate_id
  ), , drop = FALSE]
  ids <- head(aggregate_rank$candidate_id, 12L)
  parents <- history[match(ids, history$candidate_id), , drop = FALSE]
  parents <- parents[!is.na(parents$candidate_id), , drop = FALSE]
  if (nrow(parents) < 4L) {
    stop("Too few historical MCMC parents for ", family, call. = FALSE)
  }
  parents
}

iqpfr_v1_novel_candidates <- function(repo_root, protocol, family,
                                       historical_all, historical_full) {
  base_protocol <- iqfr_v2_read_protocol(repo_root)
  base_protocol$search$initial_tau0_arms <-
    as.numeric(protocol$candidate_pool$proposal_tau0_arms)
  proposal <- iqfr_v2_generate_initial_candidates(
    base_protocol, family,
    n = as.integer(protocol$candidate_pool$proposal_structures_per_family),
    start = as.integer(protocol$candidate_pool$proposal_start_index),
    generation = "posterior_rescue_v1_proposal"
  )
  proposal <- proposal[
    !proposal$structure_signature %in% historical_all$structure_signature &
      proposal$total_states <=
        as.integer(protocol$candidate_pool$maximum_novel_total_states),
    , drop = FALSE
  ]
  if (!nrow(proposal)) stop("Novel proposal pool is empty for ", family,
                            call. = FALSE)

  parents <- iqpfr_v1_historical_parents(
    protocol, family, historical_all[historical_all$family == family, ,
                                      drop = FALSE]
  )
  scaled <- iqpfr_v1_scaled_features(parents, proposal)
  proposal$parent_distance <- iqpfr_v1_min_distance(
    scaled$target, scaled$reference
  )
  exploitation_n <- as.integer(
    protocol$candidate_pool$exploitation_candidates
  )
  remaining <- proposal
  selected <- proposal[0L, , drop = FALSE]
  for (i in seq_len(exploitation_n)) {
    pick <- remaining[
      order(remaining$parent_distance, remaining$candidate_id),
      , drop = FALSE
    ][1L, , drop = FALSE]
    selected <- rbind(selected, pick)
    remaining <- remaining[
      remaining$structure_id != pick$structure_id, , drop = FALSE
    ]
  }
  low_tau0 <- as.numeric(
    protocol$candidate_pool$exploration_tau0_low_max
  )
  high_tau0 <- as.numeric(
    protocol$candidate_pool$exploration_tau0_high_min
  )
  targets <- list(
    function(x) {
      x$alpha <= as.numeric(
        protocol$candidate_pool$exploration_alpha_low_max
      ) & x$rhs_tau0 <= low_tau0
    },
    function(x) {
      x$alpha >= as.numeric(
        protocol$candidate_pool$exploration_alpha_high_min
      ) & x$rhs_tau0 <= low_tau0
    },
    function(x) {
      x$rho <= as.numeric(
        protocol$candidate_pool$exploration_rho_low_max
      ) & x$rhs_tau0 >= high_tau0
    },
    function(x) {
      x$rho >= as.numeric(
        protocol$candidate_pool$exploration_rho_high_min
      ) & x$rhs_tau0 >= high_tau0
    }
  )
  exploration_n <- as.integer(
    protocol$candidate_pool$exploration_candidates
  )
  history_reference <- historical_full[
    historical_full$family == family, , drop = FALSE
  ]
  for (i in seq_len(exploration_n)) {
    eligible <- remaining[targets[[i]](remaining), , drop = FALSE]
    if (!nrow(eligible)) eligible <- remaining
    reference <- iqpfr_v1_bind_columns(history_reference, selected)
    scaled <- iqpfr_v1_scaled_features(reference, eligible)
    distance <- iqpfr_v1_min_distance(scaled$target, scaled$reference)
    pick <- eligible[order(-distance, eligible$candidate_id), , drop = FALSE][1L, ]
    selected <- rbind(selected, pick)
    remaining <- remaining[remaining$structure_id != pick$structure_id, ,
                           drop = FALSE]
  }
  expected <- as.integer(protocol$candidate_pool$novel_per_family)
  if (nrow(selected) != expected) {
    stop("Novel candidate selection produced ", nrow(selected), " rows for ",
         family, "; expected ", expected, ".", call. = FALSE)
  }
  exploration <- selected[seq.int(exploitation_n + 1L, nrow(selected)),
                          , drop = FALSE]
  if (!any(exploration$rhs_tau0 <= low_tau0) ||
      !any(exploration$rhs_tau0 >= high_tau0)) {
    stop("Novel tau0 exploration contract failed for ", family,
         call. = FALSE)
  }
  selected$generation <- "posterior_rescue_v1"
  selected$generation_index <- seq_len(nrow(selected))
  selected$candidate_origin <- ifelse(
    seq_len(nrow(selected)) <= exploitation_n,
    "novel_mcmc_neighborhood", "novel_maximin"
  )
  for (i in seq_len(nrow(selected))) {
    signature <- paste(
      iqpfr_v1_schema, selected$structure_signature[[i]],
      format(selected$rhs_tau0[[i]], scientific = TRUE, digits = 14), sep = "|"
    )
    hash <- digest::digest(signature, algo = "sha256", serialize = FALSE)
    selected$candidate_signature[[i]] <- signature
    selected$candidate_id[[i]] <- sprintf(
      "iqpfr1_%s_n%02d_%s", family, i, substr(hash, 1L, 10L)
    )
  }
  if (anyDuplicated(selected$candidate_signature) ||
      any(selected$structure_signature %in% historical_all$structure_signature)) {
    stop("Novel candidate contract failed for ", family, call. = FALSE)
  }
  selected
}

iqpfr_v1_build_candidate_pool <- function(repo_root, protocol) {
  full <- utils::read.csv(
    iqpfr_v1_authority_path(protocol, "historical_candidates"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  initial <- utils::read.csv(
    iqpfr_v1_authority_path(protocol, "initial_candidates"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  adaptive <- utils::read.csv(
    iqpfr_v1_authority_path(protocol, "adaptive_candidates"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  historical_all <- iqpfr_v1_bind_columns(initial, adaptive)
  full$candidate_origin <- "historical_v2_1_top50"
  novel <- do.call(rbind, lapply(as.character(protocol$scope$families),
                                function(family) {
    iqpfr_v1_novel_candidates(
      repo_root, protocol, family, historical_all, full
    )
  }))
  pool <- iqpfr_v1_bind_columns(full, novel)
  expected <- as.integer(protocol$candidate_pool$total_per_family)
  counts <- table(pool$family)
  if (!all(counts[as.character(protocol$scope$families)] == expected) ||
      anyDuplicated(pool$candidate_id) ||
      anyDuplicated(pool$candidate_signature)) {
    stop("Candidate-pool identity/count contract failed.", call. = FALSE)
  }
  pool
}

iqpfr_v1_copy_sources <- function(protocol, run_root) {
  source_manifest <- utils::read.csv(
    iqpfr_v1_authority_path(protocol, "source_manifest"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  source_dir <- file.path(run_root, "sources")
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(nrow(source_manifest))) {
    source <- source_manifest$frozen_path[[i]]
    if (!identical(iqfr_v2_sha256(source),
                   source_manifest$frozen_sha256[[i]])) {
      stop("Frozen source hash mismatch: ", source, call. = FALSE)
    }
    token <- gsub("[.]", "p", sprintf("%.2f", source_manifest$tau[[i]]))
    destination <- file.path(
      source_dir, paste0(source_manifest$family[[i]], "_tau_", token, ".csv")
    )
    if (!file.exists(destination) && !file.copy(source, destination)) {
      stop("Could not copy source: ", source, call. = FALSE)
    }
    if (!identical(iqfr_v2_sha256(destination),
                   source_manifest$frozen_sha256[[i]])) {
      stop("Copied source hash mismatch: ", destination, call. = FALSE)
    }
    source_manifest$frozen_path[[i]] <- normalizePath(
      destination, winslash = "/", mustWork = TRUE
    )
  }
  iqfr_v2_write_csv(source_manifest, file.path(run_root,
                                                "source_manifest.csv"))
  source_manifest
}

iqpfr_v1_make_configs <- function(repo_root, run_root, protocol, selected,
                                   candidates, sources, plan_stage,
                                   worker_stage, chain_ids, budget,
                                   forecast_contract) {
  rows <- list()
  k <- 0L
  configs_dir <- file.path(run_root, "configs", plan_stage)
  for (i in seq_len(nrow(selected))) {
    key <- selected[i, , drop = FALSE]
    candidate <- candidates[
      candidates$family == key$family[[1L]] &
        candidates$candidate_id == key$candidate_id[[1L]], , drop = FALSE
    ]
    source <- sources[
      sources$family == key$family[[1L]] &
        abs(sources$tau - key$tau[[1L]]) < 1e-12, , drop = FALSE
    ]
    if (nrow(candidate) != 1L || nrow(source) != 1L) {
      stop("Config identity lookup failed.", call. = FALSE)
    }
    for (chain_id in as.integer(chain_ids)) {
      tau_token <- gsub("[.]", "p", sprintf("%.2f", key$tau[[1L]]))
      job_id <- paste(
        plan_stage, key$family[[1L]], key$likelihood_family[[1L]], tau_token,
        candidate$candidate_id[[1L]], sprintf("c%02d", chain_id), sep = "__"
      )
      config_path <- file.path(configs_dir, paste0(job_id, ".json"))
      result_path <- file.path(run_root, "results", plan_stage,
                               paste0(job_id, ".csv"))
      status_path <- file.path(run_root, "status", plan_stage,
                               paste0(job_id, ".json"))
      config <- list(
        schema_version = iqpfr_v1_schema,
        protocol_id = protocol$protocol$id,
        protocol_path = file.path(repo_root, iqpfr_v1_protocol_relpath),
        protocol_sha256 = iqfr_v2_sha256(
          file.path(repo_root, iqpfr_v1_protocol_relpath)
        ),
        stage = worker_stage, plan_stage = plan_stage,
        job_id = job_id, repo_root = repo_root, run_root = run_root,
        source = as.list(source), candidate = as.list(candidate),
        likelihood_family = key$likelihood_family[[1L]],
        tau = key$tau[[1L]], chain_id = chain_id,
        budget = budget, forecast_contract = forecast_contract,
        seed = iqfr_v2_seed(protocol$protocol$id, plan_stage,
                            key$family[[1L]], key$likelihood_family[[1L]],
                            key$tau[[1L]], candidate$candidate_id[[1L]],
                            chain_id),
        result_path = result_path, status_path = status_path
      )
      iqfr_v2_write_json(config, config_path)
      k <- k + 1L
      rows[[k]] <- data.frame(
        stage = plan_stage, job_id = job_id,
        family = key$family[[1L]], tau = key$tau[[1L]],
        likelihood_family = key$likelihood_family[[1L]],
        candidate_id = candidate$candidate_id[[1L]], chain_id = chain_id,
        config_path = config_path,
        config_sha256 = iqfr_v2_sha256(config_path),
        result_path = result_path, status_path = status_path,
        stringsAsFactors = FALSE
      )
    }
  }
  plan <- do.call(rbind, rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans",
                                    paste0(plan_stage, ".csv")))
  plan
}

iqpfr_v1_materialize <- function(repo_root, run_root) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  iqpfr_v1_assert_protocol(protocol)
  authority <- iqpfr_v1_verify_authorities(protocol)
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  dirty <- system2("git", c("-C", repo_root, "status", "--porcelain"),
                   stdout = TRUE)
  if (!identical(branch, iqpfr_v1_expected_branch) || length(dirty)) {
    stop("Materialization requires the clean dedicated rescue branch.",
         call. = FALSE)
  }
  dir.create(run_root, recursive = TRUE, showWarnings = FALSE)
  for (part in c("manifests", "plans", "configs", "results", "status",
                 "logs", "summaries", "diagnostics", "storage")) {
    dir.create(file.path(run_root, part), recursive = TRUE,
               showWarnings = FALSE)
  }
  sources <- iqpfr_v1_copy_sources(protocol, run_root)
  candidates <- iqpfr_v1_build_candidate_pool(repo_root, protocol)
  candidate_path <- iqfr_v2_write_csv(
    candidates, file.path(run_root, "manifests", "candidate_pool.csv")
  )
  authority_path <- iqfr_v2_write_csv(
    authority, file.path(run_root, "manifests", "authority_ledger.csv")
  )
  cells <- iqpfr_v1_hard_cells(protocol)
  selected <- merge(cells, candidates[c("family", "candidate_id")],
                    by = "family", all = FALSE, sort = TRUE)
  contract <- list(
    source_offset = 8110L, train_end = 8800L, rollout_end = 9000L,
    origin_start = 8800L, origin_end = 8970L, origin_stride = 1L,
    horizon = 30L,
    estimators = "posterior_predictive_mean_readout_state",
    export_origin_lead = FALSE
  )
  plan <- iqpfr_v1_make_configs(
    repo_root, run_root, protocol, selected, candidates, sources,
    plan_stage = "posterior_screen", worker_stage = "mcmc_pilot",
    chain_ids = 1L, budget = protocol$inference$pilot,
    forecast_contract = contract
  )
  expected <- as.integer(protocol$execution$expected_jobs$pilot)
  if (nrow(plan) != expected) stop("Pilot plan count mismatch.", call. = FALSE)
  head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                  stdout = TRUE)
  materialization <- list(
    schema_version = iqpfr_v1_schema,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git = list(branch = branch, head = head),
    protocol_path = file.path(repo_root, iqpfr_v1_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqpfr_v1_protocol_relpath)),
    candidate_path = candidate_path,
    candidate_sha256 = iqfr_v2_sha256(candidate_path),
    authority_path = authority_path,
    authority_sha256 = iqfr_v2_sha256(authority_path),
    source_manifest_sha256 = iqfr_v2_sha256(file.path(run_root,
                                                       "source_manifest.csv")),
    pilot_jobs = nrow(plan), hard_cells = nrow(cells)
  )
  iqfr_v2_write_json(materialization,
                     file.path(run_root, "manifests", "materialization.json"))
  environment <- list(
    schema_version = iqpfr_v1_schema, git_head = head,
    package_version = as.character(utils::packageVersion("exdqlm")),
    source_package_version = as.character(read.dcf(
      file.path(repo_root, "DESCRIPTION"), fields = "Version"
    )[[1L]]),
    r_version = R.version.string, platform = R.version$platform,
    omp_num_threads = Sys.getenv("OMP_NUM_THREADS", unset = "1"),
    openblas_num_threads = Sys.getenv("OPENBLAS_NUM_THREADS", unset = "1")
  )
  iqfr_v2_write_json(environment,
                     file.path(run_root, "manifests", "environment.json"))
  list(plan = plan, candidates = candidates, sources = sources,
       authority = authority)
}

iqpfr_v1_rank_screen <- function(results) {
  required <- c(
    "family", "tau", "likelihood_family", "candidate_id", "estimator",
    "forecast_qtrue_mae_mean", "forecast_qtrue_mae_lower",
    "forecast_qtrue_mae_upper", "forecast_check_loss_mean",
    "fit_qtrue_rmse_mean"
  )
  if (!all(required %in% names(results))) {
    stop("Screen result is missing ranking columns.", call. = FALSE)
  }
  results <- results[
    results$estimator == "mean_readout_state_recursive", , drop = FALSE
  ]
  results$forecast_qtrue_mae_interval_width <-
    results$forecast_qtrue_mae_upper - results$forecast_qtrue_mae_lower
  key <- interaction(results$family, results$tau,
                     results$likelihood_family, drop = TRUE)
  ranked <- lapply(split(results, key), function(x) {
    fields <- c("forecast_qtrue_mae_mean", "forecast_check_loss_mean",
                "forecast_qtrue_mae_interval_width", "fit_qtrue_rmse_mean")
    finite <- apply(as.matrix(x[fields]), 1L, function(z) all(is.finite(z)))
    x <- x[finite, , drop = FALSE]
    x <- x[order(
      x$forecast_qtrue_mae_mean, x$forecast_check_loss_mean,
      x$forecast_qtrue_mae_interval_width, x$fit_qtrue_rmse_mean,
      x$candidate_id
    ), , drop = FALSE]
    x$selection_rank <- seq_len(nrow(x))
    x
  })
  out <- do.call(rbind, ranked)
  rownames(out) <- NULL
  out
}

iqpfr_v1_metric_draws <- function(results) {
  paths <- unique(as.character(results$metric_draw_path))
  if (!length(paths) || any(!file.exists(paths))) {
    stop("Metric-draw payload is missing.", call. = FALSE)
  }
  expected <- setNames(as.character(results$metric_draw_sha256),
                       as.character(results$metric_draw_path))
  for (path in paths) {
    if (!identical(iqfr_v2_sha256(path), expected[[path]])) {
      stop("Metric-draw hash mismatch: ", path, call. = FALSE)
    }
  }
  do.call(rbind, lapply(paths, utils::read.csv,
                       check.names = FALSE, stringsAsFactors = FALSE))
}

iqpfr_v1_pool_metrics <- function(results) {
  draws <- iqpfr_v1_metric_draws(results)
  iqfr_v2_pool_confirmation_metrics(draws)
}

iqpfr_v1_select_top <- function(pooled, n_per_cell) {
  ranked <- iqpfr_v1_rank_screen(pooled)
  out <- ranked[ranked$selection_rank <= as.integer(n_per_cell), , drop = FALSE]
  cells <- interaction(out$family, out$tau, out$likelihood_family, drop = TRUE)
  if (length(unique(cells)) != 17L || any(table(cells) != n_per_cell)) {
    stop("Replicated finalist selection lacks exact cell coverage.",
         call. = FALSE)
  }
  out
}

iqpfr_v1_stage_health <- function(plan_path) {
  iqfr_v2_stage_health(plan_path)
}

iqpfr_v1_pending_configs <- function(plan_path) {
  iqfr_v2_pending_configs(plan_path)
}

iqpfr_v1_long_intervals <- function(pooled) {
  metrics <- c("fit_qtrue_rmse", "fit_qtrue_mae", "fit_check_loss",
               "forecast_qtrue_mae", "forecast_qtrue_rmse",
               "forecast_check_loss")
  rows <- list()
  k <- 0L
  for (i in seq_len(nrow(pooled))) {
    for (metric in metrics) {
      k <- k + 1L
      rows[[k]] <- data.frame(
        model_variant = if (pooled$likelihood_family[[i]] == "al") {
          "qdesn_al_rhs"
        } else "qdesn_exal_rhs",
        family = pooled$family[[i]], tau = pooled$tau[[i]],
        likelihood_family = pooled$likelihood_family[[i]], metric = metric,
        posterior_mean = pooled[[paste0(metric, "_mean")]][[i]],
        cri_lower = pooled[[paste0(metric, "_lower")]][[i]],
        cri_upper = pooled[[paste0(metric, "_upper")]][[i]],
        n_draws = pooled$pooled_draws[[i]], n_chains = pooled$chains[[i]],
        estimator = pooled$estimator[[i]],
        candidate_id = pooled$candidate_id[[i]], stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

iqpfr_v1_closeout <- function(repo_root, run_root) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  plan_path <- file.path(run_root, "plans", "confirmation.csv")
  confirmation <- iqfr_v2_collect_results(plan_path, require_complete = TRUE)
  pooled <- iqpfr_v1_pool_metrics(confirmation)
  if (nrow(pooled) != 34L || any(pooled$chains != 3L) ||
      any(pooled$pooled_draws != 900L)) {
    stop("Confirmation pooling contract failed.", call. = FALSE)
  }
  intervals <- iqpfr_v1_long_intervals(pooled)
  interval_path <- iqfr_v2_write_csv(
    intervals, file.path(run_root, "summaries", "finalist_intervals.csv")
  )
  authority <- utils::read.csv(
    iqpfr_v1_authority_path(protocol, "comparator_intervals"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  new_primary <- intervals[
    intervals$estimator == "mean_readout_state_recursive", , drop = FALSE
  ]
  comparator_models <- ifelse(
    new_primary$likelihood_family == "al", "dqlm", "exdqlm"
  )
  authority$key <- paste(authority$model_variant, authority$family,
                         authority$tau, authority$likelihood_family,
                         authority$metric, authority$estimator, sep = "|")
  comparator_key <- paste(
    comparator_models, new_primary$family, new_primary$tau,
    new_primary$likelihood_family, new_primary$metric,
    "state_space_recursive", sep = "|"
  )
  prior_models <- ifelse(
    new_primary$likelihood_family == "al", "qdesn_al_rhs", "qdesn_exal_rhs"
  )
  prior_key <- paste(
    prior_models, new_primary$family, new_primary$tau,
    new_primary$likelihood_family, new_primary$metric,
    "mean_readout_state_recursive", sep = "|"
  )
  comparator <- authority[match(comparator_key, authority$key), , drop = FALSE]
  prior <- authority[match(prior_key, authority$key), , drop = FALSE]
  if (anyNA(comparator$posterior_mean) || anyNA(prior$posterior_mean)) {
    stop("Closeout comparison authority is incomplete.", call. = FALSE)
  }
  comparison <- new_primary
  comparison$comparator_model <- comparator$model_variant
  comparison$comparator_mean <- comparator$posterior_mean
  comparison$prior_qdesn_mean <- prior$posterior_mean
  comparison$new_minus_comparator <-
    comparison$posterior_mean - comparison$comparator_mean
  comparison$new_minus_prior_qdesn <-
    comparison$posterior_mean - comparison$prior_qdesn_mean
  comparison$strict_comparator_improvement <-
    comparison$posterior_mean < comparison$comparator_mean
  comparison$strict_prior_qdesn_improvement <-
    comparison$posterior_mean < comparison$prior_qdesn_mean
  comparison_path <- iqfr_v2_write_csv(
    comparison,
    file.path(run_root, "summaries", "authority_comparison.csv")
  )
  forecast <- comparison[grepl("^forecast_", comparison$metric), , drop = FALSE]
  eligible <- forecast$strict_prior_qdesn_improvement &
    is.finite(forecast$posterior_mean)
  decision <- list(
    schema_version = iqpfr_v1_schema,
    status = if (any(eligible)) "READY_FOR_INTEGRATION" else
      "READY_NO_ARTICLE_CHANGE",
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    hard_cells = 17L, confirmation_jobs = 51L,
    confirmation_chains_per_cell = 3L,
    strict_prior_forecast_improvements = sum(eligible),
    strict_comparator_forecast_wins = sum(
      forecast$strict_comparator_improvement
    ),
    article_write_performed = FALSE,
    shared_validation_merge_performed = FALSE,
    overleaf_write_performed = FALSE,
    interval_path = interval_path,
    interval_sha256 = iqfr_v2_sha256(interval_path),
    comparison_path = comparison_path,
    comparison_sha256 = iqfr_v2_sha256(comparison_path)
  )
  closeout_path <- iqfr_v2_write_json(
    decision, file.path(run_root, "manifests", "closeout.json")
  )
  artifacts <- data.frame(
    relative_path = c(
      "summaries/finalist_intervals.csv",
      "summaries/authority_comparison.csv", "manifests/closeout.json"
    ), stringsAsFactors = FALSE
  )
  artifacts$path <- file.path(run_root, artifacts$relative_path)
  artifacts$bytes <- file.info(artifacts$path)$size
  artifacts$sha256 <- vapply(artifacts$path, iqfr_v2_sha256, character(1L))
  iqfr_v2_write_csv(artifacts,
                    file.path(run_root, "manifests", "artifact_manifest.csv"))
  list(decision = decision, closeout_path = closeout_path,
       pooled = pooled, comparison = comparison)
}
