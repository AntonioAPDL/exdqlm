# End-to-end focused residual Q-DESN ablation runner.

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, alt) if (!is.null(x)) x else alt
}

.qdesn_ablation_jobs <- function(candidates, seeds) {
  jobs <- vector("list", nrow(candidates) * length(seeds))
  index <- 0L
  for (ic in seq_len(nrow(candidates))) {
    for (seed in seeds) {
      index <- index + 1L
      jobs[[index]] <- list(candidate = candidates[ic, , drop = FALSE], seed = as.integer(seed))
    }
  }
  jobs
}

.qdesn_ablation_map <- function(jobs, fun, workers, label) {
  workers <- as.integer(workers)[1L]
  message(sprintf("[%s] %d candidate-seed jobs; workers=%d", label, length(jobs), workers))
  safe_fun <- function(job) {
    tryCatch(
      fun(job),
      error = function(e) structure(
        list(message = conditionMessage(e), job = job),
        class = "qdesn_ablation_job_error"
      )
    )
  }
  out <- if (workers > 1L && .Platform$OS.type != "windows") {
    parallel::mclapply(
      jobs,
      safe_fun,
      mc.cores = workers,
      mc.preschedule = FALSE,
      mc.set.seed = FALSE
    )
  } else {
    if (workers > 1L && .Platform$OS.type == "windows") {
      warning("Parallel fork execution is unavailable on Windows; running sequentially.", call. = FALSE)
    }
    lapply(jobs, safe_fun)
  }
  failed <- vapply(out, function(x) inherits(x, "qdesn_ablation_job_error"), logical(1L))
  if (any(failed)) {
    messages <- vapply(out[failed], `[[`, character(1L), "message")
    stop(
      sprintf("[%s] %d job(s) failed. First error: %s", label, sum(failed), messages[1L]),
      call. = FALSE
    )
  }
  out
}

#' Run the focused residual Q-DESN ablation
#'
#' The first 900 observations are available at the single validation origin,
#' observations 901--1000 form the 100-step validation target, and observations
#' 1001--1100 remain untouched until the final single-origin evaluation.  The
#' first 500 observations are always reservoir washout.  Only D, n, m, alpha,
#' and rho are selected.  Both architectures use the existing AL-VB readout and
#' an RHS-NS prior with `tau0 = 0.1` by default.
#'
#' @param y Simulated numeric series with at least 1100 observations.
#' @param output_dir Directory for checkpoints, tables, figures, and the final
#'   RDS result.
#' @param candidates Candidate table; defaults to the fixed 19-row design.
#' @param tau0 Fixed RHS global scale.  The authoritative default is 0.1.
#' @param resume Reuse completed cell-level checkpoints.
#' @param quick Run a minimal smoke version using two candidates and one seed
#'   per stage.  This is for software validation only.
#' @return A list containing validation rankings, selected configurations, and
#'   final paired results.
#' @export
qdesn_run_residual_ablation <- function(
    y,
    output_dir,
    candidates = qdesn_residual_ablation_candidates(),
    tau0 = 0.1,
    p_vec = c(0.50, 0.75, 0.95),
    screening_seeds = c(1101L, 1102L),
    confirmation_seeds = c(1201L, 1202L, 1203L, 1204L),
    final_seeds = 1301:1310,
    nd_screen = 400L,
    nd_confirm = 1000L,
    nd_final = 2000L,
    skip_scale = 1,
    vb_control = list(),
    confirmation_top_per_architecture = 2L,
    near_tie_fraction = 0.01,
    residual_retuned_min_validation_gain = 0.01,
    minimum_median_improvement_percent = 2,
    minimum_seed_wins = 7L,
    maximum_quantile_degradation_percent = 5,
    forgetting_tolerance = 1e-6,
    workers = 1L,
    resume = TRUE,
    quick = FALSE) {
  workers <- as.integer(workers)[1L]
  if (!is.finite(workers) || workers < 1L) stop("workers must be a positive integer.", call. = FALSE)
  confirmation_top_per_architecture <- as.integer(confirmation_top_per_architecture)[1L]
  if (!is.finite(confirmation_top_per_architecture) || confirmation_top_per_architecture < 1L) {
    stop("confirmation_top_per_architecture must be a positive integer.", call. = FALSE)
  }
  near_tie_fraction <- as.numeric(near_tie_fraction)[1L]
  residual_retuned_min_validation_gain <- as.numeric(residual_retuned_min_validation_gain)[1L]
  minimum_median_improvement_percent <- as.numeric(minimum_median_improvement_percent)[1L]
  minimum_seed_wins <- as.integer(minimum_seed_wins)[1L]
  maximum_quantile_degradation_percent <- as.numeric(maximum_quantile_degradation_percent)[1L]
  forgetting_tolerance <- as.numeric(forgetting_tolerance)[1L]
  if (!is.finite(near_tie_fraction) || near_tie_fraction < 0 ||
      !is.finite(residual_retuned_min_validation_gain) || residual_retuned_min_validation_gain < 0 ||
      !is.finite(minimum_median_improvement_percent) ||
      !is.finite(minimum_seed_wins) || minimum_seed_wins < 1L ||
      !is.finite(maximum_quantile_degradation_percent) ||
      !is.finite(forgetting_tolerance) || forgetting_tolerance < 0) {
    stop("Selection and decision controls are invalid.", call. = FALSE)
  }
  y <- as.numeric(y)
  if (length(y) < 1100L) stop("y must contain at least 1100 observations.", call. = FALSE)
  y <- y[seq_len(1100L)]
  if (any(!is.finite(y))) stop("The first 1100 observations of y must be finite.", call. = FALSE)
  tau0 <- as.numeric(tau0)[1L]
  if (!isTRUE(all.equal(tau0, 0.1, tolerance = 0))) {
    stop("The authoritative residual ablation fixes tau0 = 0.1.", call. = FALSE)
  }
  p_vec <- sort(unique(as.numeric(p_vec)))
  if (!identical(p_vec, c(0.50, 0.75, 0.95))) {
    stop("The focused ablation requires p_vec = c(0.50, 0.75, 0.95).", call. = FALSE)
  }
  skip_scale <- as.numeric(skip_scale)[1L]
  if (!isTRUE(all.equal(skip_scale, 1, tolerance = 0))) {
    stop("The focused architectural comparison fixes skip_scale = 1.", call. = FALSE)
  }
  normalize_seeds <- function(x, label) {
    x <- as.integer(x)
    if (!length(x) || any(!is.finite(x)) || any(x < 1L) || anyDuplicated(x)) {
      stop(label, " must contain unique positive integer seeds.", call. = FALSE)
    }
    x
  }
  screening_seeds <- normalize_seeds(screening_seeds, "screening_seeds")
  confirmation_seeds <- normalize_seeds(confirmation_seeds, "confirmation_seeds")
  final_seeds <- normalize_seeds(final_seeds, "final_seeds")
  if (length(intersect(screening_seeds, confirmation_seeds)) ||
      length(intersect(screening_seeds, final_seeds)) ||
      length(intersect(confirmation_seeds, final_seeds))) {
    stop("Screening, confirmation, and final reservoir seeds must be disjoint.", call. = FALSE)
  }
  if (!isTRUE(quick) && length(final_seeds) != 10L) {
    stop("The full decision rule requires exactly 10 held-out final reservoir seeds.", call. = FALSE)
  }

  required_candidate_cols <- c("candidate_id", "D", "n", "m", "alpha", "rho")
  if (!all(required_candidate_cols %in% names(candidates))) {
    stop("candidates is missing required columns.", call. = FALSE)
  }
  if (anyDuplicated(candidates$candidate_id)) stop("candidate_id values must be unique.", call. = FALSE)
  candidates$D <- as.integer(candidates$D)
  candidates$n <- as.integer(candidates$n)
  candidates$m <- as.integer(candidates$m)
  candidates$alpha <- as.numeric(candidates$alpha)
  candidates$rho <- as.numeric(candidates$rho)
  if (any(!is.finite(candidates$D)) || any(candidates$D < 2L) ||
      any(!is.finite(candidates$n)) || any(candidates$n < 1L) ||
      any(!is.finite(candidates$m)) || any(candidates$m < 1L) ||
      any(!is.finite(candidates$alpha)) || any(candidates$alpha <= 0 | candidates$alpha >= 1) ||
      any(!is.finite(candidates$rho)) || any(candidates$rho <= 0 | candidates$rho >= 1)) {
    stop("Candidate values violate the focused deep-reservoir parameter contract.", call. = FALSE)
  }
  path_counts <- as.integer(c(nd_screen, nd_confirm, nd_final))
  if (any(!is.finite(path_counts)) || any(path_counts < 1L)) {
    stop("All posterior-predictive path counts must be positive integers.", call. = FALSE)
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  if (isTRUE(quick)) {
    keep <- intersect(c("A00", "C01"), candidates$candidate_id)
    candidates <- candidates[candidates$candidate_id %in% keep, , drop = FALSE]
    screening_seeds <- screening_seeds[1L]
    confirmation_seeds <- confirmation_seeds[1L]
    final_seeds <- utils::head(final_seeds, 2L)
    nd_screen <- min(as.integer(nd_screen), 100L)
    nd_confirm <- min(as.integer(nd_confirm), 150L)
    nd_final <- min(as.integer(nd_final), 200L)
  }

  fixed <- list(
    washout = 500L,
    pi_w = 0.10,
    pi_in = 1.00,
    add_bias = TRUE,
    standardize_inputs = TRUE,
    standardize_response = TRUE,
    input_bound = "none",
    act_f = "tanh",
    act_k = "identity"
  )

  y_hash <- digest::digest(y, algo = "sha256")
  candidates_hash <- digest::digest(candidates, algo = "sha256")
  implementation_hash <- digest::digest(
    list(
      paired_design = body(qdesn_build_paired_architecture_designs),
      residual_roll = body(.qdesn_roll_architecture_states),
      al_vb_fit = body(qdesn_fit_al_vb_from_design),
      recursive_forecast = body(qdesn_forecast_single_origin_al_vb),
      candidate_evaluator = body(.qdesn_evaluate_candidate_seed),
      runner = body(qdesn_run_residual_ablation)
    ),
    algo = "sha256"
  )
  run_signature <- digest::digest(
    list(
      implementation_hash = implementation_hash,
      y_hash = y_hash,
      candidates_hash = candidates_hash,
      tau0 = tau0,
      p_vec = p_vec,
      screening_seeds = screening_seeds,
      confirmation_seeds = confirmation_seeds,
      final_seeds = final_seeds,
      nd_screen = nd_screen,
      nd_confirm = nd_confirm,
      nd_final = nd_final,
      skip_scale = skip_scale,
      vb_control = vb_control,
      confirmation_top_per_architecture = confirmation_top_per_architecture,
      near_tie_fraction = near_tie_fraction,
      residual_retuned_min_validation_gain = residual_retuned_min_validation_gain,
      minimum_median_improvement_percent = minimum_median_improvement_percent,
      minimum_seed_wins = minimum_seed_wins,
      maximum_quantile_degradation_percent = maximum_quantile_degradation_percent,
      forgetting_tolerance = forgetting_tolerance,
      fixed = fixed,
      quick = isTRUE(quick)
    ),
    algo = "sha256"
  )
  cache_dir <- file.path(output_dir, "cache", run_signature)
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  validation_observed <- y[1:900]
  validation_future <- y[901:1000]
  normalizers <- .qdesn_validation_normalizers(
    y_fit = y[501:900],
    y_validation = validation_future,
    p_vec = p_vec
  )

  screening_jobs <- .qdesn_ablation_jobs(candidates, screening_seeds)
  screening_results <- .qdesn_ablation_map(
    screening_jobs,
    function(job) {
      .qdesn_evaluate_candidate_seed(
        y_observed = validation_observed,
        y_future = validation_future,
        candidate = job$candidate,
        reservoir_seed = job$seed,
        stage = "screening",
        p_vec = p_vec,
        nd = as.integer(nd_screen),
        tau0 = tau0,
        skip_scale = skip_scale,
        fixed = fixed,
        vb_control = vb_control,
        standardize_readout = TRUE,
        cache_dir = cache_dir,
        resume = resume,
        architectures = c("plain", "interlayer_residual"),
        compute_forgetting = FALSE
      )
    },
    workers = workers,
    label = "screening"
  )
  screening <- .qdesn_bind_eval_results(screening_results)
  screening_ranking <- .qdesn_rank_validation(screening$summary, candidates, normalizers)

  top_ids <- unique(c(
    .qdesn_top_candidate_ids(screening_ranking, "plain", confirmation_top_per_architecture),
    .qdesn_top_candidate_ids(screening_ranking, "interlayer_residual", confirmation_top_per_architecture)
  ))
  confirm_candidates <- candidates[candidates$candidate_id %in% top_ids, , drop = FALSE]
  if (!nrow(confirm_candidates)) stop("No candidates survived screening.", call. = FALSE)

  # Re-evaluate the shortlisted candidates on all six validation seeds with
  # the larger confirmation path count.  Phase-level design and VB-fit caches
  # reuse the screening work for the first two seeds; only the forecast Monte
  # Carlo is refreshed at the confirmation precision.
  confirmation_all_seeds <- c(screening_seeds, confirmation_seeds)
  confirmation_jobs <- .qdesn_ablation_jobs(confirm_candidates, confirmation_all_seeds)
  confirmation_results <- .qdesn_ablation_map(
    confirmation_jobs,
    function(job) {
      .qdesn_evaluate_candidate_seed(
        y_observed = validation_observed,
        y_future = validation_future,
        candidate = job$candidate,
        reservoir_seed = job$seed,
        stage = "confirmation",
        p_vec = p_vec,
        nd = as.integer(nd_confirm),
        tau0 = tau0,
        skip_scale = skip_scale,
        fixed = fixed,
        vb_control = vb_control,
        standardize_readout = TRUE,
        cache_dir = cache_dir,
        resume = resume,
        architectures = c("plain", "interlayer_residual"),
        compute_forgetting = FALSE
      )
    },
    workers = workers,
    label = "confirmation"
  )
  confirmation_new <- .qdesn_bind_eval_results(confirmation_results)
  confirmation_summary <- confirmation_new$summary
  confirmation_ranking <- .qdesn_rank_validation(
    confirmation_summary,
    candidates = candidates,
    normalizers = normalizers
  )

  winner_plain <- .qdesn_select_winner(
    confirmation_ranking, "plain", tolerance = near_tie_fraction
  )
  winner_residual <- .qdesn_select_winner(
    confirmation_ranking, "interlayer_residual", tolerance = near_tie_fraction
  )
  candidate_plain <- candidates[candidates$candidate_id == winner_plain$candidate_id, , drop = FALSE]
  candidate_residual <- candidates[candidates$candidate_id == winner_residual$candidate_id, , drop = FALSE]

  score_res_at_plain <- confirmation_ranking$aggregate_score[
    confirmation_ranking$architecture == "interlayer_residual" &
      confirmation_ranking$candidate_id == winner_plain$candidate_id
  ]
  score_res_at_plain_value <- if (length(score_res_at_plain) == 1L) {
    as.numeric(score_res_at_plain)
  } else {
    Inf
  }
  score_res_best <- winner_residual$aggregate_score
  include_retuned <- !identical(winner_plain$candidate_id, winner_residual$candidate_id) &&
    is.finite(score_res_at_plain_value) &&
    ((score_res_at_plain_value - score_res_best) / score_res_at_plain_value >=
       residual_retuned_min_validation_gain)

  selected_models <- rbind(
    data.frame(
      model_id = "M0_plain_selected",
      evaluated_final = TRUE,
      winner_plain,
      stringsAsFactors = FALSE
    ),
    data.frame(
      model_id = "M1_residual_same_hyperparameters",
      evaluated_final = TRUE,
      architecture = "interlayer_residual",
      candidate_id = winner_plain$candidate_id,
      D = winner_plain$D,
      n = winner_plain$n,
      m = winner_plain$m,
      alpha = winner_plain$alpha,
      rho = winner_plain$rho,
      aggregate_score = score_res_at_plain_value,
      worst_quantile_score = NA_real_,
      valid_cells = NA_integer_,
      expected_cells = NA_integer_,
      median_saturation = NA_real_,
      total_runtime_sec = NA_real_,
      stringsAsFactors = FALSE
    ),
    data.frame(
      model_id = "M2_residual_selected",
      evaluated_final = isTRUE(include_retuned),
      winner_residual,
      stringsAsFactors = FALSE
    )
  )

  final_observed <- y[1:1000]
  final_future <- y[1001:1100]
  final_jobs <- lapply(final_seeds, function(seed) {
    list(candidate = candidate_plain, seed = as.integer(seed))
  })
  final_primary <- .qdesn_ablation_map(
    final_jobs,
    function(job) {
      eval <- .qdesn_evaluate_candidate_seed(
        y_observed = final_observed,
        y_future = final_future,
        candidate = job$candidate,
        reservoir_seed = job$seed,
        stage = "final_controlled",
        p_vec = p_vec,
        nd = as.integer(nd_final),
        tau0 = tau0,
        skip_scale = skip_scale,
        fixed = fixed,
        vb_control = vb_control,
        standardize_readout = TRUE,
        cache_dir = cache_dir,
        resume = resume,
        architectures = c("plain", "interlayer_residual"),
        compute_forgetting = TRUE
      )
      eval$summary$model_id <- ifelse(
        eval$summary$architecture == "plain",
        "M0_plain_selected",
        "M1_residual_same_hyperparameters"
      )
      eval$pointwise$model_id <- ifelse(
        eval$pointwise$architecture == "plain",
        "M0_plain_selected",
        "M1_residual_same_hyperparameters"
      )
      eval
    },
    workers = workers,
    label = "final-controlled"
  )
  final_primary_bound <- .qdesn_bind_eval_results(final_primary)

  final_retuned <- NULL
  if (isTRUE(include_retuned)) {
    retuned_jobs <- lapply(final_seeds, function(seed) {
      list(candidate = candidate_residual, seed = as.integer(seed))
    })
    retuned_results <- .qdesn_ablation_map(
      retuned_jobs,
      function(job) {
        eval <- .qdesn_evaluate_candidate_seed(
          y_observed = final_observed,
          y_future = final_future,
          candidate = job$candidate,
          reservoir_seed = job$seed,
          stage = "final_residual_selected",
          p_vec = p_vec,
          nd = as.integer(nd_final),
          tau0 = tau0,
          skip_scale = skip_scale,
          fixed = fixed,
          vb_control = vb_control,
          standardize_readout = TRUE,
          cache_dir = cache_dir,
          resume = resume,
          architectures = "interlayer_residual",
          compute_forgetting = TRUE
        )
        eval$summary$model_id <- "M2_residual_selected"
        eval$pointwise$model_id <- "M2_residual_selected"
        eval
      },
      workers = workers,
      label = "final-residual-selected"
    )
    final_retuned <- .qdesn_bind_eval_results(retuned_results)
  }

  final_summary <- final_primary_bound$summary
  final_pointwise <- final_primary_bound$pointwise
  if (!is.null(final_retuned)) {
    final_summary <- rbind(final_summary, final_retuned$summary)
    final_pointwise <- rbind(final_pointwise, final_retuned$pointwise)
  }

  block_by_seed <- stats::aggregate(
    pinball ~ model_id + architecture + reservoir_seed + p0 + horizon_block,
    data = final_pointwise,
    FUN = mean
  )
  block_keys <- unique(block_by_seed[, c("model_id", "architecture", "p0", "horizon_block"), drop = FALSE])
  block_summary <- do.call(rbind, lapply(seq_len(nrow(block_keys)), function(i) {
    z <- block_by_seed[
      block_by_seed$model_id == block_keys$model_id[i] &
        block_by_seed$architecture == block_keys$architecture[i] &
        block_by_seed$p0 == block_keys$p0[i] &
        block_by_seed$horizon_block == block_keys$horizon_block[i],
      , drop = FALSE
    ]
    data.frame(
      model_id = block_keys$model_id[i],
      architecture = block_keys$architecture[i],
      p0 = block_keys$p0[i],
      horizon_block = block_keys$horizon_block[i],
      mean_pinball = mean(z$pinball, na.rm = TRUE),
      median_pinball = stats::median(z$pinball, na.rm = TRUE),
      iqr_pinball = stats::IQR(z$pinball, na.rm = TRUE),
      seed_count = nrow(z),
      stringsAsFactors = FALSE
    )
  }))

  final_aggregate <- .qdesn_final_aggregate(final_summary)
  paired_differences <- .qdesn_final_paired_differences(final_summary, normalizers)
  decision <- list(
    median_aggregate_improvement_percent = stats::median(
      paired_differences$relative_improvement_percent,
      na.rm = TRUE
    ),
    residual_win_count = sum(paired_differences$difference_M1_minus_M0 < 0, na.rm = TRUE),
    reservoir_seed_count = nrow(paired_differences),
    include_residual_retuned_final_arm = isTRUE(include_retuned),
    retain_residual = FALSE
  )
  per_quantile <- merge(
    final_summary[final_summary$model_id == "M0_plain_selected",
                  c("reservoir_seed", "p0", "mean_pinball")],
    final_summary[final_summary$model_id == "M1_residual_same_hyperparameters",
                  c("reservoir_seed", "p0", "mean_pinball")],
    by = c("reservoir_seed", "p0"), suffixes = c("_M0", "_M1")
  )
  degradation <- stats::aggregate(
    I(100 * (mean_pinball_M1 - mean_pinball_M0) /
        pmax(mean_pinball_M0, sqrt(.Machine$double.eps))) ~ p0,
    data = per_quantile,
    FUN = stats::median
  )
  names(degradation)[2L] <- "median_degradation_percent"
  residual_rows <- final_summary$model_id == "M1_residual_same_hyperparameters"
  primary_rows <- final_summary$model_id %in% c(
    "M0_plain_selected", "M1_residual_same_hyperparameters"
  )
  paired_complete <- nrow(paired_differences) == length(final_seeds) &&
    setequal(paired_differences$reservoir_seed, final_seeds) &&
    all(final_summary$ok[primary_rows]) &&
    all(final_summary$state_finite[primary_rows]) &&
    all(!is.na(final_summary$vb_converged[primary_rows])) &&
    all(final_summary$vb_converged[primary_rows])
  stability_ok <- all(final_summary$ok[residual_rows]) &&
    all(final_summary$state_finite[residual_rows]) &&
    all(!is.na(final_summary$vb_converged[residual_rows])) &&
    all(final_summary$vb_converged[residual_rows]) &&
    all(is.finite(final_summary$forgetting_final_l2[residual_rows])) &&
    all(final_summary$forgetting_final_l2[residual_rows] <= forgetting_tolerance)
  runtime_m0 <- mean(
    final_summary$total_runtime_sec[final_summary$model_id == "M0_plain_selected"],
    na.rm = TRUE
  )
  runtime_m1 <- mean(final_summary$total_runtime_sec[residual_rows], na.rm = TRUE)
  decision$runtime_ratio_M1_over_M0 <- runtime_m1 / runtime_m0
  decision$all_final_pairs_complete <- paired_complete
  decision$state_stability_gate_passed <- stability_ok
  decision$retain_residual <- isTRUE(
    paired_complete &&
      decision$median_aggregate_improvement_percent >= minimum_median_improvement_percent &&
      decision$residual_win_count >= minimum_seed_wins &&
      all(degradation$median_degradation_percent <= maximum_quantile_degradation_percent) &&
      stability_ok
  )
  decision$quantile_degradation <- degradation

  result <- list(
    protocol = utils::modifyList(qdesn_residual_ablation_protocol(), list(rhs_tau0 = tau0)),
    candidates = candidates,
    validation_normalizers = normalizers,
    screening_summary = screening$summary,
    screening_pointwise = screening$pointwise,
    screening_ranking = screening_ranking,
    confirmation_summary = confirmation_summary,
    confirmation_pointwise = confirmation_new$pointwise,
    confirmation_ranking = confirmation_ranking,
    selected_models = selected_models,
    final_summary = final_summary,
    final_aggregate = final_aggregate,
    final_pointwise = final_pointwise,
    final_horizon_blocks = block_summary,
    final_paired_differences = paired_differences,
    decision = decision,
    decision_contract = list(
      confirmation_top_per_architecture = confirmation_top_per_architecture,
      near_tie_fraction = near_tie_fraction,
      residual_retuned_min_validation_gain = residual_retuned_min_validation_gain,
      minimum_median_improvement_percent = minimum_median_improvement_percent,
      minimum_seed_wins = minimum_seed_wins,
      maximum_quantile_degradation_percent = maximum_quantile_degradation_percent,
      forgetting_tolerance = forgetting_tolerance
    ),
    execution = list(
      workers = workers,
      quick = isTRUE(quick),
      nd_screen = as.integer(nd_screen),
      nd_confirm = as.integer(nd_confirm),
      nd_final = as.integer(nd_final),
      resume = isTRUE(resume)
    ),
    run_signature_sha256 = run_signature,
    implementation_sha256 = implementation_hash,
    series_sha256 = y_hash,
    candidates_sha256 = candidates_hash
  )

  .qdesn_write_ablation_tables(result, output_dir)
  .qdesn_write_ablation_plots(result, output_dir)
  .qdesn_write_ablation_manifest(
    result = result,
    output_dir = output_dir,
    run_signature = run_signature,
    y_hash = y_hash,
    candidates_hash = candidates_hash,
    seeds = list(
      screening = screening_seeds,
      confirmation_additional = confirmation_seeds,
      confirmation_all = confirmation_all_seeds,
      final = final_seeds
    )
  )
  result
}
