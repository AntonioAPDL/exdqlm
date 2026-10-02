iqcf_v3_bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (!length(rows)) return(data.frame())
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows <- lapply(rows, function(x) {
    missing <- setdiff(columns, names(x))
    for (field in missing) x[[field]] <- NA
    x[columns]
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqcf_v3_authority_candidate_manifest <- function(repo_root) {
  protocol <- iqpfr_v1_read_protocol(repo_root)
  path <- iqpfr_v1_authority_path(protocol, "historical_candidates")
  expected <- as.character(
    protocol$authorities$files$historical_candidates$sha256
  )
  if (!file.exists(path) || !identical(iqfr_v2_sha256(path), expected)) {
    stop("Historical candidate authority is unavailable or has drifted.",
         call. = FALSE)
  }
  list(path = path, sha256 = expected,
       candidates = utils::read.csv(path, check.names = FALSE,
                                    stringsAsFactors = FALSE))
}

iqcf_v3_compact_control <- function(template, family) {
  row <- template[1L, , drop = FALSE]
  row$family <- family
  row$D <- 1L
  row$n <- "20"
  row$n_tilde <- ""
  row$total_states <- 20L
  row$readout_dimension <- 21L
  row$m <- 30L
  row$alpha <- 0.20
  row$rho <- 0.80
  row$center_scale <- "mean_sd"
  row$input_bound <- "none"
  row$input_gain <- 0.10
  row$recurrent_indegree <- 5L
  row$input_fanin_fraction <- 0.25
  row$input_fanin <- 8L
  row$interlayer_fanin <- 5L
  row$matrix_seed <- 920001L
  row$generation <- "corrected_forecast_v3_compact_control"
  row$structure_signature <- paste(
    iqcf_v3_schema, family, "compact_control", "D1", "n20", "m30",
    "alpha0.2", "rho0.8", "gain0.1", "mean_sd", "none", "seed920001",
    sep = "|"
  )
  row$structure_id <- paste0(
    "iqcf3_", family, "_compact_",
    substr(digest::digest(row$structure_signature, algo = "sha256",
                          serialize = FALSE), 1L, 10L)
  )
  row
}

iqcf_v3_structure_bank <- function(repo_root, predecessor_run_root,
                                    protocol = iqcf_v3_read_protocol(repo_root)) {
  ridge_path <- file.path(
    repo_root, "validation", "fitforecast_v2", "promotions",
    "independent_qdesn_representation_screen_v1_stage1_closeout_20260929",
    "ridge_family_champions.csv"
  )
  rhs_path <- file.path(predecessor_run_root, "summaries",
                        "rhs_combined_robust_ranking.csv")
  authority_path <- file.path(
    repo_root, "config", "validation",
    "independent_qdesn_cellwise_refinement_v2",
    "current_authority_comparison_v11p1.csv"
  )
  required <- c(ridge_path, rhs_path, authority_path)
  if (any(!file.exists(required))) {
    stop("A required candidate authority is missing: ",
         paste(required[!file.exists(required)], collapse = ", "),
         call. = FALSE)
  }
  ridge <- utils::read.csv(ridge_path, check.names = FALSE,
                           stringsAsFactors = FALSE)
  rhs <- utils::read.csv(rhs_path, check.names = FALSE,
                         stringsAsFactors = FALSE)
  authority <- utils::read.csv(authority_path, check.names = FALSE,
                               stringsAsFactors = FALSE)
  historical <- iqcf_v3_authority_candidate_manifest(repo_root)

  rows <- list()
  k <- 0L
  for (family in as.character(protocol$scope$families)) {
    ridge_family <- ridge[ridge$family == family, , drop = FALSE]
    ridge_role <- ridge_family[ridge_family$champion_role == "robust", ,
                               drop = FALSE]
    if (nrow(ridge_role) != 1L) {
      ridge_role <- ridge_family[order(ridge_family$robust_score,
                                       ridge_family$structure_id), ,
                                 drop = FALSE][1L, , drop = FALSE]
    }
    rhs_family <- rhs[rhs$family == family, , drop = FALSE]
    rhs_role <- rhs_family[order(rhs_family$robust_score,
                                 rhs_family$median_forecast_mae,
                                 rhs_family$structure_id), , drop = FALSE][1L, ,
                                                                            drop = FALSE]
    compact <- iqcf_v3_compact_control(ridge_role, family)
    for (likelihood in as.character(protocol$scope$likelihoods)) {
      anchor_id <- unique(authority$candidate_id[
        authority$family == family &
          authority$likelihood_family == likelihood &
          abs(authority$tau - as.numeric(protocol$scope$canary_quantile)) < 1e-12
      ])
      if (length(anchor_id) != 1L) {
        stop("Current authority anchor lookup failed for ", family, "/",
             likelihood, call. = FALSE)
      }
      anchor <- historical$candidates[
        historical$candidates$candidate_id == anchor_id, , drop = FALSE
      ]
      if (nrow(anchor) != 1L) {
        stop("Full authority specification is missing for ", anchor_id,
             call. = FALSE)
      }
      role_rows <- list(
        ridge_discovered = ridge_role,
        rhs_discovered = rhs_role,
        current_authority_anchor = anchor,
        compact_control = compact
      )
      for (role in names(role_rows)) {
        k <- k + 1L
        row <- role_rows[[role]]
        row$likelihood_family <- likelihood
        row$representation_role <- role
        row$source_candidate_id <- as.character(
          row$candidate_id %||% NA_character_
        )
        row$source_prior_scale <- suppressWarnings(as.numeric(
          row$prior_scale %||% row$rhs_tau0 %||% NA_real_
        ))
        row$canary_structure_id <- paste(
          family, likelihood, role, row$structure_id[[1L]], sep = "__"
        )
        rows[[k]] <- row
      }
    }
  }
  bank <- iqcf_v3_bind_rows(rows)
  keep <- c(
    "family", "likelihood_family", "representation_role",
    "canary_structure_id", "source_candidate_id", "source_prior_scale",
    "structure_id", "structure_signature", "generation", "D", "n",
    "n_tilde", "total_states", "readout_dimension", "m", "alpha", "rho",
    "center_scale", "input_bound", "input_gain", "recurrent_indegree",
    "input_fanin_fraction", "input_fanin", "interlayer_fanin", "matrix_seed"
  )
  bank <- bank[keep]
  if (nrow(bank) != 24L || anyDuplicated(bank$canary_structure_id) ||
      any(!is.finite(bank$readout_dimension)) ||
      any(bank$readout_dimension < 3L)) {
    stop("Corrected-forecast structure bank contract failed.", call. = FALSE)
  }
  attr(bank, "authority_manifest_path") <- historical$path
  attr(bank, "authority_manifest_sha256") <- historical$sha256
  bank
}

iqcf_v3_canary_candidates <- function(structure_bank, source_manifest,
                                       protocol) {
  rows <- list()
  k <- 0L
  fit_start <- as.integer(protocol$scope$fit_window$start)
  fit_end <- 8750L
  for (i in seq_len(nrow(structure_bank))) {
    structure <- structure_bank[i, , drop = FALSE]
    source_row <- source_manifest[
      source_manifest$family == structure$family[[1L]] &
        abs(source_manifest$tau - as.numeric(protocol$scope$canary_quantile)) < 1e-12,
      , drop = FALSE
    ]
    if (nrow(source_row) != 1L) stop("Canary source lookup failed.",
                                     call. = FALSE)
    source <- iqfr_v2_source_rows(source_row$frozen_path[[1L]])
    y_fit <- source$y[source$t >= fit_start & source$t <= fit_end]
    sigma_reference_source <- stats::sd(y_fit)
    response_scale <- sigma_reference_source
    shrinkable <- as.integer(structure$readout_dimension[[1L]]) - 1L
    target_nonzero <- max(1L, min(shrinkable - 1L,
                                 as.integer(round(0.05 * shrinkable))))
    tau_reference_source <- iqcf_v3_tau0_reference(
      structure$readout_dimension[[1L]], length(y_fit), sigma_reference_source,
      target_nonzero
    )
    tau_reference <- tau_reference_source / response_scale
    source_scale <- suppressWarnings(as.numeric(structure$source_prior_scale[[1L]]))
    continuity_source <- if (
      structure$representation_role[[1L]] %in%
        c("rhs_discovered", "current_authority_anchor") &&
        is.finite(source_scale) && source_scale > 0 && source_scale < 100
    ) source_scale else as.numeric(
      protocol$shrinkage$default_continuity_tau0_source_scale
    )
    continuity <- continuity_source / response_scale
    high_source <- as.numeric(protocol$shrinkage$high_sentinel_tau0_source_scale)
    high <- high_source / response_scale
    arm_values <- c(
      dimension_reference = tau_reference,
      source_equivalent_continuity = continuity,
      source_equivalent_high_100 = high
    )
    if (length(unique(format(arm_values, scientific = TRUE,
                             digits = 16))) != 3L) {
      continuity_source <- if (continuity_source == 1) 10 else 1
      continuity <- continuity_source / response_scale
      arm_values[["source_equivalent_continuity"]] <- continuity
    }
    if (length(unique(format(arm_values, scientific = TRUE,
                             digits = 16))) != 3L) {
      stop("Canary tau0 arms are not distinct.", call. = FALSE)
    }
    for (arm_index in seq_along(arm_values)) {
      k <- k + 1L
      row <- structure
      row$rhs_tau0 <- arm_values[[arm_index]]
      row$tau0_reference <- tau_reference
      row$tau0_reference_source_scale <- tau_reference_source
      row$rhs_tau0_source_scale <- row$rhs_tau0 * response_scale
      row$tau0_multiplier <- row$rhs_tau0 / tau_reference
      row$tau_arm <- names(arm_values)[[arm_index]]
      row$target_nonzero <- target_nonzero
      row$effective_sample_size <- length(y_fit)
      row$sigma_reference_source_scale <- sigma_reference_source
      row$response_scale <- response_scale
      row$candidate_signature <- paste(
        iqcf_v3_schema, row$canary_structure_id[[1L]],
        format(row$rhs_tau0[[1L]], scientific = TRUE, digits = 16), sep = "|"
      )
      row$candidate_id <- paste0(
        "iqcf3_", row$family[[1L]], "_", row$likelihood_family[[1L]], "_",
        substr(digest::digest(row$candidate_signature[[1L]], algo = "sha256",
                              serialize = FALSE), 1L, 12L)
      )
      rows[[k]] <- row
    }
  }
  out <- iqcf_v3_bind_rows(rows)
  expected <- 3L * nrow(structure_bank)
  if (nrow(out) != expected || anyDuplicated(out$candidate_id) ||
      anyDuplicated(out$candidate_signature)) {
    stop("Corrected-forecast canary candidate contract failed.",
         call. = FALSE)
  }
  out
}

iqcf_v3_make_job_config <- function(repo_root, run_root, stage, candidate,
                                     source, protocol) {
  job_id <- paste(stage, candidate$candidate_id[[1L]], sep = "__")
  config_path <- file.path(run_root, "configs", stage, paste0(job_id, ".json"))
  result_path <- file.path(run_root, "results", stage, paste0(job_id, ".csv"))
  status_path <- file.path(run_root, "status", stage, paste0(job_id, ".json"))
  prefix <- file.path(run_root, "results", stage, job_id)
  is_smoke <- identical(stage, "operator_smoke")
  config <- list(
    schema_version = iqcf_v3_schema,
    protocol_id = protocol$protocol$id,
    protocol_path = file.path(repo_root, iqcf_v3_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqcf_v3_protocol_relpath)),
    stage = stage, job_id = job_id, repo_root = repo_root,
    run_root = run_root, config_path = config_path,
    result_path = result_path, status_path = status_path,
    metric_draw_path = paste0(prefix, "__metric_draws.csv.gz"),
    origin_lead_path = paste0(prefix, "__origin_lead.csv.gz"),
    lead_profile_path = paste0(prefix, "__lead_profile.csv"),
    origin_profile_path = paste0(prefix, "__origin_profile.csv"),
    origin_block_path = paste0(prefix, "__origin_block_intervals.csv"),
    candidate = as.list(candidate), source = as.list(source),
    probability = as.numeric(protocol$scope$canary_quantile),
    likelihood_family = candidate$likelihood_family[[1L]],
    rhs_s2 = as.numeric(protocol$shrinkage$slab_s2),
    fit_end = 8750L, rollout_end = 9000L,
    origins = list(start = 8750L, end = 8970L,
                   stride = if (is_smoke) 10L else 5L),
    horizon = as.integer(protocol$forecast$horizon),
    outer_draws = if (is_smoke) 8L else
      as.integer(protocol$forecast$canary_outer_draws),
    inner_path_grid = if (is_smoke) c(64L, 128L) else
      as.integer(protocol$forecast$canary_inner_paths),
    include_mean_readout_state = is_smoke,
    seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id),
    budget = protocol$inference$quantile_vb
  )
  iqfr_v2_write_json(config, config_path)
  data.frame(
    stage = stage, job_id = job_id,
    family = candidate$family[[1L]],
    likelihood_family = candidate$likelihood_family[[1L]],
    representation_role = candidate$representation_role[[1L]],
    candidate_id = candidate$candidate_id[[1L]],
    tau_arm = candidate$tau_arm[[1L]],
    rhs_tau0 = candidate$rhs_tau0[[1L]],
    rhs_tau0_source_scale = candidate$rhs_tau0_source_scale[[1L]],
    rhs_s2 = as.numeric(protocol$shrinkage$slab_s2),
    config_path = config_path, config_sha256 = iqfr_v2_sha256(config_path),
    result_path = result_path, status_path = status_path,
    stringsAsFactors = FALSE
  )
}

iqcf_v3_materialize <- function(repo_root, run_root, predecessor_run_root,
                                allow_dirty = FALSE) {
  repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
  run_root <- normalizePath(run_root, winslash = "/", mustWork = FALSE)
  predecessor_run_root <- normalizePath(predecessor_run_root, winslash = "/",
                                        mustWork = TRUE)
  if (dir.exists(run_root) && length(list.files(run_root, all.files = TRUE,
                                                no.. = TRUE))) {
    stop("Refusing to overwrite a nonempty corrected-forecast run root.",
         call. = FALSE)
  }
  protocol <- iqcf_v3_read_protocol(repo_root)
  iqcf_v3_assert_protocol(protocol)
  source_version <- as.character(read.dcf(
    file.path(repo_root, "DESCRIPTION"), fields = "Version"
  )[[1L]])
  materializer_installed_version <- as.character(utils::packageVersion("exdqlm"))
  if (!identical(source_version, "1.1.1")) {
    stop("Corrected-forecast materialization requires exdqlm 1.1.1 source.",
         call. = FALSE)
  }
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  if (!identical(branch, iqcf_v3_expected_branch)) {
    stop("Materialization requires dedicated corrected-forecast branch.",
         call. = FALSE)
  }
  worktree_status <- system2(
    "git", c("-C", repo_root, "status", "--porcelain", "--untracked-files=all"),
    stdout = TRUE
  )
  worktree_clean <- !length(worktree_status)
  if (!worktree_clean && !isTRUE(allow_dirty)) {
    stop("Production materialization requires a clean committed worktree.",
         call. = FALSE)
  }
  for (directory in c(
    "configs/operator_smoke", "configs/forecast_canary",
    "results/operator_smoke", "results/forecast_canary",
    "status/operator_smoke", "status/forecast_canary", "logs/operator_smoke",
    "logs/forecast_canary", "manifests", "plans", "sources", "summaries"
  )) dir.create(file.path(run_root, directory), recursive = TRUE,
                showWarnings = FALSE)

  predecessor_protocol <- iqcr_v2_read_protocol(repo_root)
  sources <- iqrs_v1_copy_sources(predecessor_protocol, run_root)
  structures <- iqcf_v3_structure_bank(
    repo_root, predecessor_run_root, protocol
  )
  candidates <- iqcf_v3_canary_candidates(structures, sources, protocol)
  if (nrow(candidates) != 72L) {
    stop("Corrected-forecast materialization requires exactly 72 canary jobs.",
         call. = FALSE)
  }
  iqfr_v2_write_csv(structures, file.path(run_root, "manifests",
                                          "canary_structure_bank.csv"))
  iqfr_v2_write_csv(candidates, file.path(run_root, "manifests",
                                          "canary_candidates.csv"))

  full_rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.5) < 1e-12, , drop = FALSE]
    full_rows[[i]] <- iqcf_v3_make_job_config(
      repo_root, run_root, "forecast_canary", candidate, source, protocol
    )
  }
  full_plan <- do.call(rbind, full_rows)
  center <- candidates[
    candidates$representation_role == "compact_control" &
      candidates$tau_arm == as.character(
        protocol$gates$operator_smoke_tau0_arm
      ), , drop = FALSE
  ]
  if (nrow(center) != 6L) stop("Operator-smoke candidate lookup failed.",
                               call. = FALSE)
  smoke_rows <- vector("list", nrow(center))
  for (i in seq_len(nrow(center))) {
    candidate <- center[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.5) < 1e-12, , drop = FALSE]
    smoke_rows[[i]] <- iqcf_v3_make_job_config(
      repo_root, run_root, "operator_smoke", candidate, source, protocol
    )
  }
  smoke_plan <- do.call(rbind, smoke_rows)
  iqfr_v2_write_csv(smoke_plan, file.path(run_root, "plans",
                                          "operator_smoke.csv"))
  iqfr_v2_write_csv(full_plan, file.path(run_root, "plans",
                                         "forecast_canary.csv"))

  environment <- list(
    schema_version = iqcf_v3_schema,
    branch = branch,
    head = system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                   stdout = TRUE),
    exdqlm_source_version = source_version,
    worker_runtime_contract = "pkgload_source_1.1.1",
    materializer_installed_version = materializer_installed_version,
    R_version = R.version.string,
    worktree_clean = worktree_clean,
    dirty_override_for_dry_run = isTRUE(allow_dirty),
    OMP_NUM_THREADS = Sys.getenv("OMP_NUM_THREADS", unset = ""),
    OPENBLAS_NUM_THREADS = Sys.getenv("OPENBLAS_NUM_THREADS", unset = ""),
    MKL_NUM_THREADS = Sys.getenv("MKL_NUM_THREADS", unset = ""),
    predecessor_run_root = predecessor_run_root,
    predecessor_decision = "SUPERSEDED_BY_CORRECTED_FORECAST_ESTIMAND_V3",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(environment, file.path(run_root, "manifests",
                                            "environment.json"))
  writeLines(capture.output(sessionInfo()), file.path(run_root, "manifests",
                                                      "session_info.txt"))
  manifest_paths <- c(
    file.path(run_root, "source_manifest.csv"),
    file.path(run_root, "manifests", c(
      "canary_structure_bank.csv", "canary_candidates.csv", "environment.json",
      "session_info.txt"
    )),
    file.path(run_root, "plans", c("operator_smoke.csv", "forecast_canary.csv"))
  )
  manifest <- data.frame(
    path = normalizePath(manifest_paths, winslash = "/", mustWork = TRUE),
    bytes = file.info(manifest_paths)$size,
    sha256 = vapply(manifest_paths, iqfr_v2_sha256, character(1L)),
    stringsAsFactors = FALSE
  )
  iqfr_v2_write_csv(manifest, file.path(run_root, "manifests",
                                        "materialization_manifest.csv"))
  list(protocol = protocol, sources = sources, structures = structures,
       candidates = candidates, smoke_plan = smoke_plan,
       canary_plan = full_plan, manifest = manifest)
}

iqcf_v3_status_write <- function(cfg, status, started, extra = list()) {
  iqfr_v2_write_json(c(list(
    schema_version = as.character(cfg$schema_version %||% iqcf_v3_schema),
    stage = cfg$stage, job_id = cfg$job_id,
    status = status, config_path = cfg$config_path,
    config_sha256 = iqfr_v2_sha256(cfg$config_path),
    pid = Sys.getpid(), host = unname(Sys.info()[["nodename"]]),
    started_at = format(started, "%Y-%m-%dT%H:%M:%S%z")
  ), extra), cfg$status_path)
}

iqcf_v3_fit_metric_draws <- function(fit, draws, source, fit_rows, probability,
                                     response_transport) {
  q <- response_transport$inverse(fit$X %*% t(draws$beta))
  truth <- source$q_target[fit_rows]
  observed <- source$y[fit_rows]
  data.frame(
    posterior_draw = seq_len(ncol(q)),
    posterior_source_draw_index = as.integer(
      draws$source_draw_index %||% seq_len(ncol(q))
    ),
    fit_qtrue_rmse = sqrt(colMeans(sweep(q, 1L, truth, `-`)^2)),
    fit_qtrue_mae = colMeans(abs(sweep(q, 1L, truth, `-`))),
    fit_check_loss = vapply(seq_len(ncol(q)), function(j) {
      mean(iqcf_v3_check_loss(observed, q[, j], probability))
    }, numeric(1L)), stringsAsFactors = FALSE
  )
}

iqcf_v3_run_job <- function(config_path) {
  started <- Sys.time()
  config_path <- normalizePath(config_path, winslash = "/", mustWork = TRUE)
  cfg <- iqfr_v2_read_json(config_path)
  cfg$config_path <- config_path
  iqcf_v3_status_write(cfg, "RUNNING", started)
  tryCatch({
    source_path <- as.character(iqfr_v2_scalar(cfg$source$frozen_path))
    if (!identical(iqfr_v2_sha256(source_path),
                   as.character(iqfr_v2_scalar(cfg$source$frozen_sha256)))) {
      stop("Canary source hash mismatch.", call. = FALSE)
    }
    source <- iqfr_v2_source_rows(source_path)
    candidate <- cfg$candidate
    probability <- iqfr_v2_number(cfg$probability)
    fit_end <- iqfr_v2_integer(cfg$fit_end)
    rollout_end <- iqfr_v2_integer(cfg$rollout_end)
    fit_rows <- source$t >= 8501L & source$t <= fit_end
    train_rows <- source$t <= fit_end
    rollout_rows <- source$t <= rollout_end
    response_transport <- iqcf_v3_response_transport(source, fit_rows)
    model_source <- source
    model_source$y <- response_transport$forward(source$y)
    rhs_s2 <- iqfr_v2_number(cfg$rhs_s2)
    preprocess <- iqfr_v2_training_preprocess(
      model_source$y[fit_rows], iqfr_v2_scalar(candidate$center_scale)
    )
    normal_args <- list(
      beta_prior_type = "rhs_ns",
      rhs = list(tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = rhs_s2,
                 shrink_intercept = FALSE, n_inner = 2L),
      control = list(max_iter = 200L, min_iter = 10L, tol = 1e-5,
                     covariance = "woodbury_diagonal", verbose = FALSE)
    )
    normal_fit <- do.call(qdesn_fit_normal, iqfr_v2_design_args(
      y = model_source$y[train_rows], candidate = candidate,
      preprocess = preprocess, p0 = probability, fit_readout = TRUE,
      normal_args = normal_args
    ))
    iqfr_v2_assert_design(normal_fit, candidate, fit_end - 8500L)
    if (isTRUE(cfg$collect_solver_diagnostics)) iqbs_v5_progress(cfg, "NORMAL_INITIALIZATION_COMPLETE")
    likelihood <- as.character(cfg$likelihood_family)
    init <- qdesn_normal_to_vb_init(
      normal_fit, likelihood_family = likelihood,
      beta_prior_type = "rhs_ns", p0 = probability
    )
    budget <- cfg$budget
    vb_args <- list(
      likelihood_family = likelihood,
      al_fixed_gamma = if (likelihood == "al") 0 else NULL,
      beta_prior_type = "rhs_ns",
      beta_rhs = list(tau0 = iqfr_v2_number(candidate$rhs_tau0), s2 = rhs_s2,
                      shrink_intercept = FALSE, n_inner = 2L),
      max_iter = iqfr_v2_integer(budget$max_iter, 750L),
      min_iter_elbo = 10L, tol = iqfr_v2_number(budget$tol, 1e-4),
      tol_par = iqfr_v2_number(budget$tol, 1e-4),
      n_samp_xi = iqfr_v2_integer(budget$n_samp_xi, 400L),
      verbose = FALSE, init = init,
      sigmagam = exal_make_vb_sigmagam_control(),
      beta_covariance = list(approximation = match.arg(
        as.character(cfg$beta_covariance_approximation %||% "diagonal"),
        c("diagonal", "full")),
                             label_uncertainty = TRUE)
    )
    fit_args <- iqfr_v2_design_args(
      y = model_source$y[train_rows], candidate = candidate,
      preprocess = preprocess, p0 = probability, fit_readout = TRUE
    )
    fit_args$normal_args <- NULL
    fit_args$vb_args <- vb_args
    if (isTRUE(cfg$collect_solver_diagnostics)) iqbs_v5_progress(cfg, "QUANTILE_VB_RUNNING")
    fit <- do.call(qdesn_fit_vb, fit_args)
    if (isTRUE(cfg$collect_solver_diagnostics)) iqbs_v5_progress(cfg, "QUANTILE_VB_COMPLETE")
    iqfr_v2_assert_design(fit, candidate, fit_end - 8500L)

    rollout_args <- iqfr_v2_design_args(
      y = model_source$y[rollout_rows], candidate = candidate,
      preprocess = preprocess, p0 = probability, fit_readout = FALSE
    )
    rollout_args$normal_args <- NULL
    rollout_args$vb_args <- list()
    rollout <- do.call(qdesn_fit_vb, rollout_args)
    iqfr_v2_assert_design(rollout, candidate, rollout_end - 8500L)
    rollout <- iqfr_v2_attach_quantile_readout(rollout, fit)

    outer_draws <- iqfr_v2_integer(cfg$outer_draws)
    seed <- iqfr_v2_integer(cfg$seed)
    draws <- exal_posterior_draws(
      fit$fit, nd = outer_draws,
      seed = iqfr_v2_seed(seed, "posterior_draws")
    )
    fit_metrics <- iqcf_v3_fit_metric_draws(
      fit, draws, source, fit_rows, probability, response_transport
    )
    solver_artifacts <- character()
    if (isTRUE(cfg$collect_solver_diagnostics)) {
      solver_artifacts <- iqbs_v5_capture_fit(
        cfg, fit, draws, source, fit_rows, response_transport
      )
    }
    origins_source <- seq.int(
      iqfr_v2_integer(cfg$origins$start), iqfr_v2_integer(cfg$origins$end),
      by = iqfr_v2_integer(cfg$origins$stride)
    )
    if (isTRUE(cfg$collect_solver_diagnostics)) iqbs_v5_progress(cfg, "FORECAST_RUNNING")
    origins_local <- origins_source - 8110L
    k_grid <- sort(unique(as.integer(cfg$inner_path_grid)))
    bank <- iqcf_v3_make_noise_bank(
      draws, iqfr_v2_integer(cfg$horizon), length(origins_local),
      max(k_grid), iqfr_v2_seed(seed, "inner_paths")
    )
    score_by_k <- vector("list", length(k_grid))
    for (k_index in seq_along(k_grid)) {
      inner_paths <- k_grid[[k_index]]
      lattice <- iqcf_v3_nested_lattice(
        rollout, y_all = model_source$y[rollout_rows], origins = origins_local,
        horizon = iqfr_v2_integer(cfg$horizon), draws = draws,
        probability = probability, inner_paths = inner_paths,
        seed = iqfr_v2_seed(seed, "inner_paths"), noise_bank = bank,
        include_mean_readout_state = isTRUE(cfg$include_mean_readout_state) &&
          identical(inner_paths, max(k_grid))
      )
      lattice <- iqcf_v3_inverse_lattice(lattice, response_transport)
      score <- iqcf_v3_score_nested_lattice(
        lattice, source, source_offset = 8110L
      )
      score$point_metrics$inner_paths <- inner_paths
      score_by_k[[k_index]] <- score
    }
    max_score <- score_by_k[[length(k_grid)]]
    metric_draws <- merge(
      max_score$metric_draws, fit_metrics,
      by = c("posterior_draw", "posterior_source_draw_index"), all.x = TRUE,
      sort = FALSE
    )
    identifiers <- data.frame(
      schema_version = as.character(cfg$schema_version %||% iqcf_v3_schema),
      stage = cfg$stage,
      job_id = cfg$job_id,
      family = as.character(iqfr_v2_scalar(candidate$family)),
      likelihood_family = likelihood,
      model_variant = if (likelihood == "al") "qdesn_al_rhs" else
        "qdesn_exal_rhs",
      probability = probability,
      representation_role = as.character(
        iqfr_v2_scalar(candidate$representation_role)
      ),
      candidate_id = as.character(iqfr_v2_scalar(candidate$candidate_id)),
      structure_id = as.character(iqfr_v2_scalar(candidate$structure_id)),
      tau_arm = as.character(iqfr_v2_scalar(candidate$tau_arm)),
      rhs_tau0 = iqfr_v2_number(candidate$rhs_tau0),
      rhs_tau0_source_scale = iqfr_v2_number(candidate$rhs_tau0_source_scale),
      tau0_reference = iqfr_v2_number(candidate$tau0_reference),
      tau0_reference_source_scale = iqfr_v2_number(
        candidate$tau0_reference_source_scale
      ),
      tau0_multiplier = iqfr_v2_number(candidate$tau0_multiplier),
      rhs_s2 = rhs_s2,
      response_center = response_transport$center,
      response_scale = response_transport$scale,
      response_transport_fit_start = response_transport$fit_t_start,
      response_transport_fit_end = response_transport$fit_t_end,
      stringsAsFactors = FALSE
    )
    point_parts <- lapply(score_by_k, `[[`, "point_metrics")
    baseline <- iqcf_v3_training_quantile_baseline(
      source = source, fit_rows = fit_rows, origins = origins_local,
      horizon = iqfr_v2_integer(cfg$horizon), probability = probability,
      source_offset = 8110L
    )
    baseline$inner_paths <- max(k_grid)
    point <- iqcf_v3_bind_rows(c(point_parts, list(baseline)))
    point <- cbind(identifiers[rep(1L, nrow(point)), , drop = FALSE], point)
    point$fit_qtrue_rmse_mean <- mean(fit_metrics$fit_qtrue_rmse)
    point$fit_qtrue_mae_mean <- mean(fit_metrics$fit_qtrue_mae)
    point$fit_check_loss_mean <- mean(fit_metrics$fit_check_loss)
    point$outer_draws <- outer_draws
    point$forecast_origins <- length(origins_local)
    point$forecast_pairs <- length(origins_local) * iqfr_v2_integer(cfg$horizon)
    point$vb_iterations <- length(fit$fit$misc$elbo_trace %||% numeric())
    point$sigmagam_factorization <- as.character(
      fit$fit$misc$sigmagam$factorization %||% "structured"
    )
    point$exact_identity_projection <- all(fit$reservoir$Q_is_identity)
    point$runtime_seconds_job <- as.numeric(difftime(
      Sys.time(), started, units = "secs"
    ))
    required_numeric <- c(
      "probability", "rhs_tau0", "rhs_tau0_source_scale",
      "tau0_reference", "tau0_reference_source_scale", "tau0_multiplier",
      "rhs_s2", "response_center", "response_scale", "response_transport_fit_start",
      "response_transport_fit_end", "forecast_qtrue_mae",
      "forecast_qtrue_rmse", "forecast_check_loss", "inner_paths",
      "fit_qtrue_rmse_mean", "fit_qtrue_mae_mean", "fit_check_loss_mean",
      "outer_draws", "forecast_origins", "forecast_pairs", "vb_iterations",
      "runtime_seconds_job"
    )
    if (!all(required_numeric %in% names(point)) ||
        any(!is.finite(as.matrix(point[required_numeric]))) ||
        !all(point$exact_identity_projection)) {
      stop("Corrected-forecast finite/identity contract failed.",
           call. = FALSE)
    }

    metric_draws <- cbind(
      identifiers[rep(1L, nrow(metric_draws)), , drop = FALSE],
      metric_draws
    )
    origin_lead <- cbind(
      identifiers[rep(1L, nrow(max_score$origin_lead)), , drop = FALSE],
      max_score$origin_lead
    )
    lead_profile <- cbind(
      identifiers[rep(1L, nrow(max_score$lead_profile)), , drop = FALSE],
      max_score$lead_profile
    )
    origin_profile <- cbind(
      identifiers[rep(1L, nrow(max_score$origin_profile)), , drop = FALSE],
      max_score$origin_profile
    )
    block <- iqcf_v3_origin_block_intervals(
      max_score$origin_lead, replicates = 500L,
      seed = iqfr_v2_seed(seed, "origin_blocks")
    )
    block <- cbind(identifiers[rep(1L, nrow(block)), , drop = FALSE], block)

    iqfr_v2_write_csv(point, cfg$result_path)
    iqfr_v2_write_csv_gz(metric_draws, cfg$metric_draw_path)
    iqfr_v2_write_csv_gz(origin_lead, cfg$origin_lead_path)
    iqfr_v2_write_csv(lead_profile, cfg$lead_profile_path)
    iqfr_v2_write_csv(origin_profile, cfg$origin_profile_path)
    iqfr_v2_write_csv(block, cfg$origin_block_path)
    artifacts <- c(
      result = cfg$result_path, metric_draws = cfg$metric_draw_path,
      origin_lead = cfg$origin_lead_path, lead_profile = cfg$lead_profile_path,
      origin_profile = cfg$origin_profile_path,
      origin_blocks = cfg$origin_block_path,
      solver_artifacts
    )
    hashes <- lapply(artifacts, iqfr_v2_sha256)
    finished <- Sys.time()
    iqcf_v3_status_write(cfg, "SUCCESS", started, list(
      finished_at = format(finished, "%Y-%m-%dT%H:%M:%S%z"),
      runtime_seconds = as.numeric(difftime(finished, started, units = "secs")),
      result_path = cfg$result_path,
      result_sha256 = hashes$result,
      artifact_paths = as.list(artifacts), artifact_sha256 = hashes,
      fitted_model_binaries = 0L
    ))
    invisible(point)
  }, error = function(e) {
    iqcf_v3_status_write(cfg, "FAILED", started, list(
      finished_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
      error = conditionMessage(e), fitted_model_binaries = 0L
    ))
    stop(e)
  })
}

iqcf_v3_health <- function(run_root) {
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  rows <- lapply(plans, function(plan_path) {
    plan <- utils::read.csv(plan_path, check.names = FALSE,
                            stringsAsFactors = FALSE)
    states <- vapply(plan$status_path, function(path) {
      if (!file.exists(path)) return("PENDING")
      status <- iqcr_v2_superseded_read_status(path)
      toupper(as.character(status$status %||% "UNKNOWN"))
    }, character(1L))
    data.frame(
      stage = unique(plan$stage), planned = nrow(plan),
      success = sum(states == "SUCCESS"), failed = sum(states == "FAILED"),
      running = sum(states == "RUNNING"), pending = sum(states == "PENDING"),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

iqcf_v3_audit_operator_smoke <- function(run_root) {
  plan <- utils::read.csv(file.path(run_root, "plans", "operator_smoke.csv"),
                          check.names = FALSE, stringsAsFactors = FALSE)
  health <- iqcf_v3_health(run_root)
  smoke <- health[health$stage == "operator_smoke", , drop = FALSE]
  if (nrow(smoke) != 1L || smoke$success != nrow(plan) || smoke$failed != 0L ||
      smoke$running != 0L || smoke$pending != 0L) {
    stop("Operator smoke is not complete and successful.", call. = FALSE)
  }
  results <- do.call(rbind, lapply(plan$result_path, function(path) {
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }))
  if (any(!is.finite(results$forecast_qtrue_mae)) ||
      any(!is.finite(results$forecast_check_loss))) {
    stop("Operator smoke contains nonfinite scores.", call. = FALSE)
  }
  common <- results[results$estimator %in% c(
    "conditional_location_plugin", "mean_conditional_location",
    "predictive_quantile_by_draw", "posterior_predictive_quantile_pooled"
  ), , drop = FALSE]
  keys <- interaction(common$job_id, common$estimator, drop = TRUE)
  stability <- do.call(rbind, lapply(split(common, keys), function(x) {
    x <- x[order(x$inner_paths), , drop = FALSE]
    if (nrow(x) < 2L) return(NULL)
    data.frame(
      job_id = x$job_id[[1L]], estimator = x$estimator[[1L]],
      k_low = x$inner_paths[[1L]], k_high = x$inner_paths[[nrow(x)]],
      mae_relative_change = abs(x$forecast_qtrue_mae[[nrow(x)]] -
                                  x$forecast_qtrue_mae[[1L]]) /
        max(abs(x$forecast_qtrue_mae[[nrow(x)]]), 1e-8),
      check_relative_change = abs(x$forecast_check_loss[[nrow(x)]] -
                                    x$forecast_check_loss[[1L]]) /
        max(abs(x$forecast_check_loss[[nrow(x)]]), 1e-8),
      stringsAsFactors = FALSE
    )
  }))
  pass <- nrow(stability) > 0L &&
    all(stability$mae_relative_change <= 0.15) &&
    all(stability$check_relative_change <= 0.15)
  dir.create(file.path(run_root, "summaries"), recursive = TRUE,
             showWarnings = FALSE)
  iqfr_v2_write_csv(stability, file.path(run_root, "summaries",
                                         "operator_smoke_k_stability.csv"))
  decision <- list(
    schema_version = iqcf_v3_schema,
    stage = "operator_smoke", all_jobs_successful = TRUE,
    all_scores_finite = TRUE, k_stability_threshold = 0.15,
    k_stability_pass = pass,
    decision = if (pass) "PASS_UNLOCK_FORECAST_CANARY" else
      "HOLD_DIAGNOSE_MONTE_CARLO_STABILITY",
    automatic_forecast_canary_launch = FALSE,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(decision, file.path(run_root, "summaries",
                                         "operator_smoke_decision.json"))
  decision
}

iqcf_v3_audit_forecast_canary <- function(run_root) {
  smoke_path <- file.path(run_root, "summaries",
                          "operator_smoke_decision.json")
  if (!file.exists(smoke_path)) {
    stop("Operator-smoke decision is missing.", call. = FALSE)
  }
  smoke <- iqfr_v2_read_json(smoke_path)
  if (!identical(as.character(smoke$decision),
                 "PASS_UNLOCK_FORECAST_CANARY")) {
    stop("Operator-smoke gate has not unlocked the forecast canary.",
         call. = FALSE)
  }
  plan <- utils::read.csv(file.path(run_root, "plans", "forecast_canary.csv"),
                          check.names = FALSE, stringsAsFactors = FALSE)
  health <- iqcf_v3_health(run_root)
  canary <- health[health$stage == "forecast_canary", , drop = FALSE]
  if (nrow(canary) != 1L || canary$success != nrow(plan) ||
      canary$failed != 0L || canary$running != 0L || canary$pending != 0L) {
    stop("Forecast canary is not complete and successful.", call. = FALSE)
  }
  results <- do.call(rbind, lapply(plan$result_path, function(path) {
    utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  }))
  if (any(!is.finite(results$forecast_qtrue_mae)) ||
      any(!is.finite(results$forecast_check_loss)) ||
      any(!results$exact_identity_projection)) {
    stop("Forecast canary violates finite/identity requirements.",
         call. = FALSE)
  }
  oracle <- results[results$estimator == "mean_conditional_location", ,
                    drop = FALSE]
  predictive <- results[
    results$estimator == "posterior_predictive_quantile_pooled", ,
    drop = FALSE
  ]
  baseline <- results[
    results$estimator == "training_empirical_quantile_baseline", ,
    drop = FALSE
  ]
  keys <- c("job_id", "family", "likelihood_family", "representation_role",
            "candidate_id", "structure_id", "tau_arm", "rhs_tau0",
            "rhs_tau0_source_scale", "rhs_s2", "tau0_reference",
            "tau0_reference_source_scale",
            "tau0_multiplier")
  joined <- merge(
    oracle[c(keys, "forecast_qtrue_mae", "forecast_qtrue_rmse")],
    predictive[c(keys, "forecast_check_loss")], by = keys, all = FALSE,
    suffixes = c("_oracle", "_predictive")
  )
  baseline_key <- baseline[c("job_id", "forecast_qtrue_mae")]
  names(baseline_key)[[2L]] <- "baseline_forecast_qtrue_mae"
  joined <- merge(joined, baseline_key, by = "job_id", all.x = TRUE,
                  sort = FALSE)
  joined$oracle_mae_ratio_to_baseline <-
    joined$forecast_qtrue_mae / joined$baseline_forecast_qtrue_mae
  cell <- interaction(joined$family, joined$likelihood_family, drop = TRUE)
  joined$selection_rank <- ave(seq_len(nrow(joined)), cell, FUN = function(ids) {
    order(order(joined$forecast_qtrue_mae[ids],
                joined$forecast_check_loss[ids],
                joined$candidate_id[ids]))
  })
  joined <- joined[order(joined$family, joined$likelihood_family,
                         joined$selection_rank), , drop = FALSE]
  counts <- table(interaction(joined$family, joined$likelihood_family,
                              drop = TRUE))
  complete_surface <- length(counts) == 6L && all(counts == 12L)
  protocol <- iqcf_v3_read_protocol()
  catastrophic_threshold <- as.numeric(
    protocol$gates$maximum_catastrophic_oracle_mae_ratio
  )
  best_ratio <- aggregate(
    oracle_mae_ratio_to_baseline ~ family + likelihood_family,
    data = joined, FUN = min
  )
  noncatastrophic_surface <- nrow(best_ratio) == 6L &&
    all(is.finite(best_ratio$oracle_mae_ratio_to_baseline)) &&
    all(best_ratio$oracle_mae_ratio_to_baseline <= catastrophic_threshold)
  dir.create(file.path(run_root, "summaries"), recursive = TRUE,
             showWarnings = FALSE)
  iqfr_v2_write_csv(joined, file.path(run_root, "summaries",
                                      "forecast_canary_cellwise_ranking.csv"))
  iqfr_v2_write_csv(best_ratio, file.path(run_root, "summaries",
                                          "forecast_canary_baseline_gate.csv"))
  decision <- list(
    schema_version = iqcf_v3_schema, stage = "forecast_canary",
    jobs = nrow(plan), all_jobs_successful = TRUE,
    all_scores_finite = TRUE, complete_six_cell_surface = complete_surface,
    catastrophic_oracle_mae_ratio_threshold = catastrophic_threshold,
    noncatastrophic_six_cell_surface = noncatastrophic_surface,
    decision = if (complete_surface && noncatastrophic_surface) {
      "PASS_READY_FOR_CORRECTED_BROAD_SCREEN_DESIGN"
    } else if (!complete_surface) {
      "HOLD_INCOMPLETE_CANARY_SURFACE"
    } else "HOLD_CATASTROPHIC_CANARY_PERFORMANCE",
    automatic_broad_launch = FALSE,
    ranking_path = file.path(run_root, "summaries",
                             "forecast_canary_cellwise_ranking.csv"),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  iqfr_v2_write_json(decision, file.path(run_root, "summaries",
                                         "forecast_canary_decision.json"))
  decision
}
