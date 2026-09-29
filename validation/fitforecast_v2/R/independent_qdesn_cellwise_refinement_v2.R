iqcr_v2_protocol_relpath <- file.path(
  "config", "validation", "independent_qdesn_cellwise_refinement_v2",
  "protocol_defaults.yaml"
)
iqcr_v2_schema <- "independent_qdesn_cellwise_refinement_v2_v1"
iqcr_v2_expected_branch <-
  "validation/independent-qdesn-cellwise-refinement-v2-20260929"
iqcr_v2_families <- c("normal", "laplace", "gausmix")
iqcr_v2_quantiles <- c(0.05, 0.25, 0.50)
iqcr_v2_likelihoods <- c("al", "exal")

iqcr_v2_read_protocol <- function(repo_root = iqfr_v2_repo_root()) {
  path <- file.path(repo_root, iqcr_v2_protocol_relpath)
  if (!file.exists(path)) stop("Missing cellwise-refinement protocol: ", path,
                               call. = FALSE)
  yaml::read_yaml(path)
}

iqcr_v2_named_integer <- function(x, name) {
  value <- x[[name]]
  if (is.null(value) || length(value) != 1L || !is.finite(as.numeric(value))) {
    stop("Missing integer protocol value: ", name, call. = FALSE)
  }
  as.integer(value)
}

iqcr_v2_authority_paths <- function(repo_root, protocol) {
  root <- file.path(repo_root, protocol$authorities$stage1_closeout_dir)
  data.frame(
    authority = c(
      "stage1_closeout", "stage1_manifest", "stage1_ranking",
      "stage1_best", "stage1_shortlist", "stage1_champions",
      "current_authority_comparison"
    ),
    path = c(
      file.path(root, "stage1_closeout.json"),
      file.path(root, "artifact_manifest.csv"),
      file.path(root, "ridge_robust_ranking.csv"),
      file.path(root, "ridge_best_scale_per_structure.csv"),
      file.path(root, "ridge_shortlist.csv"),
      file.path(root, "ridge_family_champions.csv"),
      file.path(repo_root, protocol$authorities$current_authority_comparison)
    ),
    expected_sha256 = c(
      protocol$authorities$stage1_closeout_sha256,
      protocol$authorities$stage1_manifest_sha256,
      protocol$authorities$stage1_ranking_sha256,
      protocol$authorities$stage1_best_sha256,
      protocol$authorities$stage1_shortlist_sha256,
      protocol$authorities$stage1_champions_sha256,
      protocol$authorities$current_authority_comparison_sha256
    ),
    stringsAsFactors = FALSE
  )
}

iqcr_v2_assert_authorities <- function(repo_root, protocol) {
  rows <- iqcr_v2_authority_paths(repo_root, protocol)
  if (any(!file.exists(rows$path))) {
    stop("Missing frozen authority: ",
         paste(rows$path[!file.exists(rows$path)], collapse = ", "),
         call. = FALSE)
  }
  rows$observed_sha256 <- vapply(rows$path, iqfr_v2_sha256, character(1L))
  rows$hash_pass <- is.na(rows$expected_sha256) |
    rows$observed_sha256 == rows$expected_sha256
  if (any(!rows$hash_pass)) {
    stop("Frozen Stage 1 authority hash drift: ",
         paste(rows$authority[!rows$hash_pass], collapse = ", "),
         call. = FALSE)
  }
  rows
}

iqcr_v2_target_cells <- function(protocol = iqcr_v2_read_protocol()) {
  out <- expand.grid(
    family = iqcr_v2_families, tau = iqcr_v2_quantiles,
    likelihood_family = iqcr_v2_likelihoods,
    stringsAsFactors = FALSE
  )
  protected <- protocol$scope$protected_cell
  out$protected <- out$family == protected$family &
    out$likelihood_family == protected$likelihood &
    abs(out$tau - as.numeric(protected$tau)) < 1e-12
  out$target_cell_id <- paste(
    out$family, out$likelihood_family,
    gsub("[.]", "p", sprintf("%.2f", out$tau)), sep = "__"
  )
  out
}

iqcr_v2_protocol_checks <- function(protocol = iqcr_v2_read_protocol()) {
  s <- protocol$scope
  a <- protocol$architecture
  x <- protocol$search
  z <- protocol$selection
  e <- protocol$execution
  imported <- vapply(iqcr_v2_families, function(family) {
    iqcr_v2_named_integer(x$imported_per_family, family)
  }, integer(1L))
  novel <- vapply(iqcr_v2_families, function(family) {
    iqcr_v2_named_integer(x$novel_per_family, family)
  }, integer(1L))
  totals <- vapply(iqcr_v2_families, function(family) {
    iqcr_v2_named_integer(x$total_per_family, family)
  }, integer(1L))
  checks <- c(
    protocol_id = identical(
      protocol$protocol$id, "independent_qdesn_cellwise_refinement_v2"
    ),
    launch_enabled = isTRUE(protocol$protocol$launch_enabled),
    families = identical(as.character(s$families), iqcr_v2_families),
    quantiles = isTRUE(all.equal(as.numeric(s$quantiles),
                                 iqcr_v2_quantiles)),
    likelihoods = identical(as.character(s$likelihoods),
                             iqcr_v2_likelihoods),
    protected_cell = sum(iqcr_v2_target_cells(protocol)$protected) == 1L,
    windows = identical(as.integer(unlist(s$fit_window)), c(8501L, 9000L)) &&
      identical(as.integer(unlist(s$heldout_window)), c(9001L, 10000L)),
    recursive_contract = isTRUE(s$teacher_forced_between_origins) &&
      isTRUE(s$recursive_within_horizon) && !isTRUE(s$refit_per_origin) &&
      identical(as.integer(s$horizon), 30L),
    readout_contract = identical(
      as.character(a$readout_columns),
      c("intercept", "all_reservoir_layers")
    ) && !isTRUE(a$direct_response_lags_in_readout) &&
      !isTRUE(a$direct_exogenous_lags_in_readout) &&
      !isTRUE(a$reservoir_lags_in_readout),
    identity_projection = identical(a$projection$mode, "identity") &&
      isTRUE(a$projection$require_exact_identity) &&
      isTRUE(a$projection$dimensionality_reduction_forbidden),
    candidate_counts = identical(imported + novel, totals) &&
      sum(totals) == 220L && sum(novel) == 80L,
    extended_memory = identical(as.integer(x$maximum_response_lag), 360L) &&
      as.integer(x$source_prefix_length) -
        as.integer(x$maximum_response_lag) >= 30L,
    case_specific = isTRUE(z$family_specific) &&
      isTRUE(z$quantile_specific) && isTRUE(z$likelihood_specific) &&
      isTRUE(z$global_specification_forbidden),
    forecast_first = identical(z$primary_metric, "forecast_qtrue_mae") &&
      !isTRUE(z$diagnostics_veto_finite_gain),
    m0 = identical(protocol$inference$mcmc$exal_method_id,
                   "m0_v_collapsed_support_logit"),
    stage_counts = identical(
      as.integer(unlist(e$expected_jobs[c(
        "ridge_screen", "rhs_screen", "rhs_refinement", "quantile_bridge",
        "quantile_refinement", "mcmc_pilot", "replication",
        "confirmation", "total"
      )])),
      c(80L, 220L, 220L, 96L, 64L, 170L, 102L, 51L, 1003L)
    ),
    workers = identical(as.integer(e$workers), 15L) &&
      identical(as.integer(e$threads_per_worker), 1L)
  )
  data.frame(check = names(checks), pass = unname(checks),
             stringsAsFactors = FALSE)
}

iqcr_v2_assert_protocol <- function(protocol = iqcr_v2_read_protocol()) {
  checks <- iqcr_v2_protocol_checks(protocol)
  if (any(!checks$pass)) {
    stop("Cellwise-refinement protocol checks failed: ",
         paste(checks$check[!checks$pass], collapse = ", "),
         call. = FALSE)
  }
  invisible(checks)
}

iqcr_v2_rekey_structure <- function(row, generation, index, protocol,
                                     source_structure_id = NA_character_) {
  row$generation <- generation
  row$generation_index <- as.integer(index)
  row$source_structure_id <- source_structure_id
  row$screen_reservoir_seed <- as.integer(
    protocol$search$fixed_screen_matrix_seed
  )
  row$matrix_seed <- row$screen_reservoir_seed
  row$rhs_tau0 <- NA_real_
  row$tau0_base <- NA_real_
  row$tau0_mode <- "pending"
  row$tau_arm <- "pending"
  row$tau_arm_index <- NA_integer_
  row$structure_signature <- paste(
    iqcr_v2_schema, iqrs_v1_structure_fingerprint(row), sep = "|"
  )
  hash <- digest::digest(row$structure_signature, algo = "sha256",
                         serialize = FALSE)
  row$structure_id <- sprintf(
    "iqcr2_%s_s%03d_%s", row$family[[1L]], as.integer(index),
    substr(hash, 1L, 10L)
  )
  row$candidate_signature <- NA_character_
  row$candidate_id <- NA_character_
  row
}

iqcr_v2_imported_structures <- function(repo_root, protocol) {
  root <- file.path(repo_root, protocol$authorities$stage1_closeout_dir)
  shortlist <- utils::read.csv(
    file.path(root, "ridge_shortlist.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  champions <- utils::read.csv(
    file.path(root, "ridge_family_champions.csv"), check.names = FALSE,
    stringsAsFactors = FALSE
  )
  rows <- list()
  k <- 0L
  for (family in iqcr_v2_families) {
    target <- iqcr_v2_named_integer(protocol$search$imported_per_family,
                                    family)
    pool <- shortlist[shortlist$family == family, , drop = FALSE]
    pool <- pool[order(pool$selection_rank, pool$robust_score,
                       pool$structure_id), , drop = FALSE]
    mandatory_ids <- unique(champions$structure_id[
      champions$family == family
    ])
    mandatory <- pool[match(mandatory_ids, pool$structure_id), , drop = FALSE]
    if (anyNA(mandatory$structure_id)) {
      stop("A frozen Stage 1 champion is absent from the shortlist.",
           call. = FALSE)
    }
    selected <- rbind(mandatory, pool[!pool$structure_id %in% mandatory_ids,
                                     , drop = FALSE])
    selected <- selected[!duplicated(selected$structure_id), , drop = FALSE]
    selected <- utils::head(selected, target)
    if (nrow(selected) != target) stop("Imported candidate count failed.")
    for (i in seq_len(nrow(selected))) {
      k <- k + 1L
      row <- selected[i, , drop = FALSE]
      source_id <- row$structure_id[[1L]]
      row$stage1_ridge_scale <- row$prior_scale[[1L]]
      row$stage1_robust_score <- row$robust_score[[1L]]
      row$stage1_median_forecast_mae <- row$median_forecast_mae[[1L]]
      rows[[k]] <- iqcr_v2_rekey_structure(
        row, "stage1_import", k, protocol, source_id
      )
    }
  }
  iqrs_v1_bind_rows(rows)
}

iqcr_v2_shape_widths <- function(D, shape, base_width, widths) {
  snap <- function(value) widths[which.min(abs(widths - value))]
  raw <- switch(
    shape,
    flat = rep(base_width, D),
    taper = if (D == 1L) base_width else
      seq(base_width, max(min(widths), base_width / 2), length.out = D),
    expand = if (D == 1L) base_width else
      seq(max(min(widths), base_width / 2), base_width, length.out = D),
    bottleneck = {
      out <- rep(base_width, D)
      if (D > 1L) out[seq.int(2L, D, by = 2L)] <-
        max(min(widths), base_width / 2)
      out
    },
    stop("Unknown layer shape: ", shape, call. = FALSE)
  )
  as.integer(vapply(raw, snap, integer(1L)))
}

iqcr_v2_architecture_pool <- function(protocol, family, arm = "primary") {
  region <- protocol$search$family_regions[[family]]
  if (family == "gausmix") region <- region[[arm]]
  depths <- as.integer(region$depth_values)
  limits <- as.integer(region$total_states)
  widths <- as.integer(protocol$search$width_values)
  shapes <- as.character(protocol$search$layer_shapes)
  rows <- list()
  k <- 0L
  for (D in depths) {
    for (shape in shapes) {
      for (width in widths) {
        n <- iqcr_v2_shape_widths(D, shape, width, widths)
        total <- sum(n)
        if (total < limits[[1L]] || total > limits[[2L]]) next
        k <- k + 1L
        rows[[k]] <- data.frame(
          D = D, layer_shape = shape, n = iqfr_v2_pack(n),
          n_tilde = iqfr_v2_pack(if (D > 1L) n[seq_len(D - 1L)] else
                                   integer()),
          total_states = total, readout_dimension = 1L + total,
          search_arm = arm, stringsAsFactors = FALSE
        )
      }
    }
  }
  if (!length(rows)) stop("Empty architecture pool for ", family, "/", arm,
                          call. = FALSE)
  unique(do.call(rbind, rows))
}

iqcr_v2_make_novel_row <- function(protocol, family, arm, arch, u,
                                    seen, index) {
  region <- protocol$search$family_regions[[family]]
  if (family == "gausmix") region <- region[[arm]]
  m_values <- as.integer(region$response_lag_values)
  gains <- as.numeric(protocol$preprocessing$input_gain)
  indegrees <- as.integer(protocol$topology$recurrent_indegree)
  fractions <- as.numeric(protocol$topology$input_fanin_fraction)
  inter_values <- as.character(protocol$topology$interlayer_fanin)
  m <- m_values[1L + (as.integer(index) - 1L) %% length(m_values)]
  high_memory <- index %% 4L == 0L
  alpha <- if (high_memory) 0.40 + 0.59 * u[[3L]] else
    0.01 + 0.98 * u[[3L]]
  rho <- if (high_memory) 0.90 + 0.099 * u[[4L]] else
    0.20 + 0.799 * u[[4L]]
  center_scale <- protocol$preprocessing$center_scale[[
    1L + floor(u[[5L]] * length(protocol$preprocessing$center_scale)) %%
      length(protocol$preprocessing$center_scale)
  ]]
  input_bound <- protocol$preprocessing$input_bound[[
    1L + floor(u[[6L]] * length(protocol$preprocessing$input_bound)) %%
      length(protocol$preprocessing$input_bound)
  ]]
  input_gain <- gains[1L + floor(u[[7L]] * length(gains)) %% length(gains)]
  n <- iqfr_v2_unpack_integer(arch$n)
  recurrent <- min(
    indegrees[1L + floor(u[[8L]] * length(indegrees)) %% length(indegrees)],
    min(n)
  )
  input_fraction <- fractions[
    1L + floor(u[[9L]] * length(fractions)) %% length(fractions)
  ]
  input_fanin <- max(1L, min(m + 1L, ceiling((m + 1L) * input_fraction)))
  inter_token <- inter_values[
    1L + floor(u[[10L]] * length(inter_values)) %% length(inter_values)
  ]
  interlayer <- if (identical(inter_token, "dense")) max(n) else
    min(as.integer(inter_token), min(n))
  row <- cbind(data.frame(family = family, stringsAsFactors = FALSE), arch)
  row$m <- m
  row$alpha <- alpha
  row$rho <- rho
  row$center_scale <- center_scale
  row$input_bound <- input_bound
  row$input_gain <- input_gain
  row$recurrent_indegree <- recurrent
  row$input_fanin_fraction <- input_fraction
  row$input_fanin <- as.integer(input_fanin)
  row$interlayer_fanin <- as.integer(interlayer)
  fingerprint <- iqrs_v1_structure_fingerprint(row)
  if (fingerprint %in% seen) return(NULL)
  row
}

iqcr_v2_novel_structures <- function(repo_root, protocol, seen) {
  allocations <- list(
    normal = c(primary = 30L),
    laplace = c(primary = 20L),
    gausmix = c(compact = 15L, long_deep = 15L)
  )
  depth_schedules <- list(
    normal = list(primary = c(rep(3L, 12L), rep(4L, 12L),
                              rep(2L, 3L), rep(5L, 3L))),
    laplace = list(primary = c(rep(3L, 8L), rep(4L, 8L),
                               rep(2L, 2L), rep(5L, 2L))),
    gausmix = list(
      compact = rep(c(1L, 2L, 3L), length.out = 15L),
      long_deep = rep(c(3L, 4L), length.out = 15L)
    )
  )
  rows <- list()
  k <- 0L
  for (family in iqcr_v2_families) {
    family_index <- 0L
    for (arm in names(allocations[[family]])) {
      target <- allocations[[family]][[arm]]
      pool <- iqcr_v2_architecture_pool(protocol, family, arm)
      cursor <- 1L
      accepted <- 0L
      while (accepted < target) {
        halton <- iqfr_v2_halton(
          256L, 10L, start = cursor,
          shift_seed = iqfr_v2_seed(iqcr_v2_schema, family, arm)
        )
        cursor <- cursor + nrow(halton)
        for (i in seq_len(nrow(halton))) {
          u <- halton[i, ]
          desired_depth <- depth_schedules[[family]][[arm]][[accepted + 1L]]
          depth_pool <- pool[pool$D == desired_depth, , drop = FALSE]
          arch <- depth_pool[
            1L + floor(u[[1L]] * nrow(depth_pool)) %% nrow(depth_pool),
            , drop = FALSE
          ]
          candidate <- iqcr_v2_make_novel_row(
            protocol, family, arm, arch, u, seen,
            index = family_index + 1L
          )
          if (is.null(candidate)) next
          fingerprint <- iqrs_v1_structure_fingerprint(candidate)
          seen <- c(seen, fingerprint)
          family_index <- family_index + 1L
          accepted <- accepted + 1L
          k <- k + 1L
          rows[[k]] <- iqcr_v2_rekey_structure(
            candidate, "family_targeted_v2_new", family_index, protocol
          )
          if (accepted == target) break
        }
        if (cursor > 100000L && accepted < target) {
          stop("Could not generate targeted structures for ", family, "/", arm,
               call. = FALSE)
        }
      }
    }
  }
  iqrs_v1_bind_rows(rows)
}

iqcr_v2_generate_structures <- function(repo_root, protocol) {
  imported <- iqcr_v2_imported_structures(repo_root, protocol)
  ranking_path <- file.path(
    repo_root, protocol$authorities$stage1_closeout_dir,
    "ridge_robust_ranking.csv"
  )
  historical <- utils::read.csv(ranking_path, check.names = FALSE,
                                stringsAsFactors = FALSE)
  historical <- historical[!duplicated(historical$structure_id), , drop = FALSE]
  seen <- vapply(seq_len(nrow(historical)), function(i) {
    iqrs_v1_structure_fingerprint(historical[i, , drop = FALSE])
  }, character(1L))
  novel <- iqcr_v2_novel_structures(repo_root, protocol, seen)
  out <- iqrs_v1_bind_rows(list(imported, novel))
  counts <- table(out$family)
  expected <- vapply(iqcr_v2_families, function(family) {
    iqcr_v2_named_integer(protocol$search$total_per_family, family)
  }, integer(1L))
  n_identity <- vapply(seq_len(nrow(out)), function(i) {
    n <- iqfr_v2_unpack_integer(out$n[[i]])
    n_tilde <- iqfr_v2_unpack_integer(out$n_tilde[[i]])
    if (out$D[[i]] == 1L) !length(n_tilde) else
      identical(n_tilde, n[seq_len(out$D[[i]] - 1L)])
  }, logical(1L))
  if (!identical(as.integer(counts[iqcr_v2_families]),
                 as.integer(expected)) ||
      anyDuplicated(out$structure_id) ||
      anyDuplicated(out$structure_signature) || !all(n_identity) ||
      max(out$m) != 360L || max(out$D) != 5L ||
      max(out$total_states) > 2400L) {
    stop("The 220-structure targeted bank contract failed.", call. = FALSE)
  }
  out
}

iqcr_v2_make_job_config <- function(repo_root, run_root, protocol, stage,
                                     job_id, payload, plan_fields = list()) {
  config_path <- file.path(run_root, "configs", stage, paste0(job_id, ".json"))
  result_path <- file.path(run_root, "results", stage, paste0(job_id, ".csv"))
  status_path <- file.path(run_root, "status", stage, paste0(job_id, ".json"))
  config <- c(list(
    schema_version = iqcr_v2_schema, protocol_id = protocol$protocol$id,
    protocol_path = file.path(repo_root, iqcr_v2_protocol_relpath),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqcr_v2_protocol_relpath)),
    stage = stage, job_id = job_id, repo_root = repo_root,
    run_root = run_root, result_path = result_path, status_path = status_path
  ), payload)
  iqfr_v2_write_json(config, config_path)
  c(list(
    stage = stage, job_id = job_id, config_path = config_path,
    config_sha256 = iqfr_v2_sha256(config_path),
    result_path = result_path, status_path = status_path
  ), plan_fields)
}

iqcr_v2_materialize_normal_plan <- function(repo_root, run_root, protocol,
                                             structures, sources, stage) {
  stage <- match.arg(stage, c("ridge_screen", "rhs_screen"))
  rows <- vector("list", nrow(structures))
  for (i in seq_len(nrow(structures))) {
    candidate <- structures[i, , drop = FALSE]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.50) < 1e-12, , drop = FALSE]
    if (nrow(source) != 1L) stop("Median source lookup failed.")
    job_id <- paste(stage, candidate$structure_id[[1L]], sep = "__")
    scale_grid <- if (stage == "ridge_screen") {
      as.numeric(protocol$inference$normal_ridge$beta_ridge_tau2)
    } else as.numeric(protocol$inference$normal_rhs$coarse_tau0)
    rows[[i]] <- as.data.frame(iqcr_v2_make_job_config(
      repo_root, run_root, protocol, stage, job_id,
      payload = list(
        candidate = as.list(candidate), source = as.list(source),
        folds = protocol$selection$blocked_folds, scale_grid = scale_grid,
        seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id),
        budget = if (stage == "rhs_screen") protocol$inference$normal_rhs else
          protocol$inference$normal_ridge
      ),
      plan_fields = list(
        family = candidate$family[[1L]],
        structure_id = candidate$structure_id[[1L]],
        generation = candidate$generation[[1L]]
      )
    ), stringsAsFactors = FALSE)
  }
  plan <- iqrs_v1_bind_rows(rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans", paste0(stage, ".csv")))
  plan
}

iqcr_v2_materialize_rhs_refinement_plan <- function(
    repo_root, run_root, protocol, structures, sources, coarse_best) {
  stage <- "rhs_refinement"
  bounds <- as.numeric(protocol$inference$normal_rhs$tau0_bounds)
  multipliers <- as.numeric(protocol$inference$normal_rhs$local_multipliers)
  rows <- vector("list", nrow(structures))
  for (i in seq_len(nrow(structures))) {
    candidate <- structures[i, , drop = FALSE]
    best <- coarse_best[
      coarse_best$structure_id == candidate$structure_id[[1L]], , drop = FALSE
    ]
    source <- sources[sources$family == candidate$family[[1L]] &
                        abs(sources$tau - 0.50) < 1e-12, , drop = FALSE]
    if (nrow(best) != 1L || nrow(source) != 1L) {
      stop("RHS refinement identity lookup failed.", call. = FALSE)
    }
    local_grid <- sort(unique(pmin(
      bounds[[2L]], pmax(bounds[[1L]], best$prior_scale[[1L]] * multipliers)
    )))
    job_id <- paste(stage, candidate$structure_id[[1L]], sep = "__")
    rows[[i]] <- as.data.frame(iqcr_v2_make_job_config(
      repo_root, run_root, protocol, stage, job_id,
      payload = list(
        candidate = as.list(candidate), source = as.list(source),
        folds = protocol$selection$blocked_folds, scale_grid = local_grid,
        coarse_winner = best$prior_scale[[1L]],
        seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id),
        budget = protocol$inference$normal_rhs
      ),
      plan_fields = list(
        family = candidate$family[[1L]],
        structure_id = candidate$structure_id[[1L]],
        generation = candidate$generation[[1L]],
        coarse_winner = best$prior_scale[[1L]],
        local_scale_count = length(local_grid)
      )
    ), stringsAsFactors = FALSE)
  }
  plan <- iqrs_v1_bind_rows(rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans",
                                    paste0(stage, ".csv")))
  plan
}

iqcr_v2_materialize_quantile_plan <- function(repo_root, run_root, protocol,
                                               candidates, sources, stage) {
  stage <- match.arg(stage, c("quantile_bridge", "quantile_refinement"))
  rows <- vector("list", nrow(candidates))
  for (i in seq_len(nrow(candidates))) {
    candidate <- candidates[i, , drop = FALSE]
    family_sources <- sources[sources$family == candidate$family[[1L]],
                              , drop = FALSE]
    family_sources <- family_sources[order(family_sources$tau), , drop = FALSE]
    if (nrow(family_sources) != 3L) stop("Incomplete quantile source set.")
    job_id <- paste(stage, candidate$candidate_id[[1L]], sep = "__")
    rows[[i]] <- as.data.frame(iqcr_v2_make_job_config(
      repo_root, run_root, protocol, stage, job_id,
      payload = list(
        candidate = as.list(candidate), sources = family_sources,
        folds = protocol$selection$blocked_folds,
        budget = protocol$inference$quantile_vb,
        seed = iqfr_v2_seed(protocol$protocol$id, stage, job_id)
      ),
      plan_fields = list(
        family = candidate$family[[1L]],
        candidate_id = candidate$candidate_id[[1L]]
      )
    ), stringsAsFactors = FALSE)
  }
  plan <- iqrs_v1_bind_rows(rows)
  iqfr_v2_write_csv(plan, file.path(run_root, "plans", paste0(stage, ".csv")))
  plan
}

iqcr_v2_materialize <- function(repo_root, run_root) {
  protocol <- iqcr_v2_read_protocol(repo_root)
  checks <- iqcr_v2_assert_protocol(protocol)
  authorities <- iqcr_v2_assert_authorities(repo_root, protocol)
  branch <- system2("git", c("-C", repo_root, "branch", "--show-current"),
                    stdout = TRUE)
  dirty <- system2("git", c("-C", repo_root, "status", "--porcelain"),
                   stdout = TRUE)
  if (!identical(branch, iqcr_v2_expected_branch) || length(dirty)) {
    stop("Materialization requires the clean dedicated v2 branch.",
         call. = FALSE)
  }
  if (dir.exists(run_root)) {
    existing <- list.files(run_root, all.files = TRUE, no.. = TRUE)
    unexpected <- setdiff(existing, c(".pipeline_lock", "pipeline.stdout.log"))
    if (length(unexpected)) {
      stop("Refusing to overwrite nonempty run root: ", run_root,
           call. = FALSE)
    }
  }
  for (part in c(
    "configs", "plans", "results", "status", "logs", "manifests",
    "summaries", "sources", "storage"
  )) dir.create(file.path(run_root, part), recursive = TRUE,
                showWarnings = FALSE)
  sources <- iqrs_v1_copy_sources(protocol, run_root)
  structures <- iqcr_v2_generate_structures(repo_root, protocol)
  structure_path <- iqfr_v2_write_csv(
    structures, file.path(run_root, "manifests", "structure_catalog.csv")
  )
  novel <- structures[structures$generation == "family_targeted_v2_new",
                      , drop = FALSE]
  plan <- iqcr_v2_materialize_normal_plan(
    repo_root, run_root, protocol, novel, sources, "ridge_screen"
  )
  expected <- as.integer(protocol$execution$expected_jobs$ridge_screen)
  if (nrow(plan) != expected) stop("Targeted ridge plan count mismatch.")
  authority_path <- iqfr_v2_write_csv(
    authorities, file.path(run_root, "manifests", "authority_manifest.csv")
  )
  head <- system2("git", c("-C", repo_root, "rev-parse", "HEAD"),
                  stdout = TRUE)
  materialization <- list(
    schema_version = iqcr_v2_schema,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git = list(branch = branch, head = head),
    protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                iqcr_v2_protocol_relpath)),
    structure_path = structure_path,
    structure_sha256 = iqfr_v2_sha256(structure_path),
    source_manifest_sha256 = iqfr_v2_sha256(file.path(run_root,
                                                       "source_manifest.csv")),
    authority_manifest_sha256 = iqfr_v2_sha256(authority_path),
    candidate_structures = nrow(structures), imported_structures =
      sum(structures$generation == "stage1_import"),
    novel_structures = nrow(novel), ridge_jobs = nrow(plan),
    exact_identity_projection = TRUE, maximum_total_states =
      max(structures$total_states), maximum_response_lag = max(structures$m)
  )
  iqfr_v2_write_json(materialization,
                     file.path(run_root, "manifests", "materialization.json"))
  writeLines(c(capture.output(utils::sessionInfo()), "",
               capture.output(base::extSoftVersion())),
             file.path(run_root, "manifests", "session_info.txt"))
  environment <- list(
    schema_version = iqcr_v2_schema, git_head = head,
    package_version = as.character(utils::packageVersion("exdqlm")),
    source_package_version = as.character(read.dcf(
      file.path(repo_root, "DESCRIPTION"), fields = "Version"
    )[[1L]]),
    r_version = R.version.string, platform = R.version$platform,
    cpu_set = Sys.getenv(
      "IQCR_V2_CPU_LIST", protocol$execution$preferred_cpu_set
    ),
    thread_environment = as.list(Sys.getenv(c(
      "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
      "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS",
      "RCPP_PARALLEL_NUM_THREADS"
    ), unset = "1"))
  )
  iqfr_v2_write_json(environment,
                     file.path(run_root, "manifests", "environment.json"))
  list(checks = checks, authorities = authorities, structures = structures,
       sources = sources, plan = plan)
}

iqcr_v2_key_columns <- function(stage) {
  switch(
    as.character(stage),
    ridge_screen =,
    rhs_screen =,
    rhs_refinement = c("job_id", "fold_id", "prior_scale"),
    quantile_bridge =,
    quantile_refinement = c(
      "job_id", "fold_id", "likelihood_family", "tau"
    ),
    mcmc_pilot =,
    replication =,
    confirmation = c("job_id", "estimator"),
    stop("Unsupported v2 result stage: ", stage, call. = FALSE)
  )
}

iqcr_v2_collect_results <- function(plan_path, require_complete = TRUE) {
  plan <- utils::read.csv(plan_path, check.names = FALSE,
                          stringsAsFactors = FALSE)
  health <- iqfr_v2_stage_health(plan_path)
  if (isTRUE(require_complete) && !isTRUE(health$complete[[1L]])) {
    stop("Stage is not completely successful: ", basename(plan_path),
         call. = FALSE)
  }
  paths <- plan$result_path[file.exists(plan$result_path)]
  if (!length(paths)) return(data.frame())
  out <- do.call(rbind, lapply(paths, utils::read.csv,
                              check.names = FALSE, stringsAsFactors = FALSE))
  stage <- unique(as.character(plan$stage))
  if (length(stage) != 1L) stop("Plan has multiple stages.", call. = FALSE)
  key_columns <- iqcr_v2_key_columns(stage)
  if (!all(key_columns %in% names(out))) {
    stop("Result ledger lacks v2 key columns.", call. = FALSE)
  }
  keys <- do.call(paste, c(out[key_columns], sep = "|"))
  if (anyDuplicated(keys)) stop("Duplicate v2 result rows.", call. = FALSE)
  rownames(out) <- NULL
  out
}

iqcr_v2_pending_configs <- function(plan_path) {
  iqfr_v2_pending_configs(plan_path)
}

iqcr_v2_select_rows <- function(x, count) {
  x$capacity_stratum <- cut(
    x$total_states, breaks = c(-Inf, 200, 600, 1200, 1800, Inf),
    labels = c("compact", "medium", "large", "very_large", "extreme")
  )
  x$lag_stratum <- cut(
    x$m, breaks = c(-Inf, 120, 180, 300, Inf),
    labels = c("short", "medium", "long", "extended")
  )
  x <- x[order(x$robust_score, x$median_forecast_mae,
               x$worst_forecast_mae, x$structure_id), , drop = FALSE]
  seeds <- integer()
  add_first <- function(indices) {
    indices <- setdiff(indices, seeds)
    if (length(indices)) seeds <<- c(seeds, indices[[1L]])
  }
  for (generation in unique(x$generation)) add_first(which(
    x$generation == generation
  ))
  for (D in sort(unique(x$D))) add_first(which(x$D == D))
  for (level in levels(x$capacity_stratum)) add_first(which(
    as.character(x$capacity_stratum) == level
  ))
  for (level in levels(x$lag_stratum)) add_first(which(
    as.character(x$lag_stratum) == level
  ))
  add_first(order(-x$m, -x$total_states))
  add_first(order(x$alpha))
  add_first(order(-x$alpha))
  add_first(order(x$rho))
  add_first(order(-x$rho))
  indices <- unique(c(seeds, seq_len(nrow(x))))
  if (length(indices) < count) stop("Insufficient diverse candidate rows.")
  out <- x[indices[seq_len(count)], , drop = FALSE]
  out$selection_rank <- seq_len(nrow(out))
  out
}

iqcr_v2_select_family_counts <- function(ranked, counts) {
  best <- iqrs_v1_best_scale_per_structure(ranked)
  rows <- lapply(iqcr_v2_families, function(family) {
    iqcr_v2_select_rows(
      best[best$family == family, , drop = FALSE],
      iqcr_v2_named_integer(counts, family)
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

iqcr_v2_finalize_rhs_candidates <- function(selected, structures) {
  rows <- vector("list", nrow(selected))
  for (i in seq_len(nrow(selected))) {
    structure <- structures[
      structures$structure_id == selected$structure_id[[i]], , drop = FALSE
    ]
    if (nrow(structure) != 1L) stop("RHS structure lookup failed.")
    tau0 <- as.numeric(selected$prior_scale[[i]])
    structure$rhs_tau0 <- tau0
    structure$tau0_base <- tau0
    structure$tau0_mode <- "absolute_coarse_bridge"
    structure$tau_arm <- iqfr_v2_tau_arm_label(tau0)
    structure$candidate_signature <- paste(
      iqcr_v2_schema, structure$structure_signature,
      format(tau0, digits = 14, scientific = TRUE), sep = "|"
    )
    hash <- digest::digest(structure$candidate_signature, algo = "sha256",
                           serialize = FALSE)
    structure$candidate_id <- sprintf(
      "iqcr2_%s_%s", structure$family[[1L]], substr(hash, 1L, 12L)
    )
    structure$rhs_robust_score <- selected$robust_score[[i]]
    structure$rhs_median_forecast_mae <- selected$median_forecast_mae[[i]]
    structure$rhs_worst_forecast_mae <- selected$worst_forecast_mae[[i]]
    structure$rhs_median_fit_rmse <- selected$median_fit_rmse[[i]]
    rows[[i]] <- structure
  }
  out <- iqrs_v1_bind_rows(rows)
  if (anyDuplicated(out$candidate_id) ||
      anyDuplicated(out$candidate_signature)) {
    stop("RHS candidate identity collision.", call. = FALSE)
  }
  out
}

iqcr_v2_candidate_features <- function(x) {
  data.frame(
    D = as.numeric(x$D), log_states = log1p(as.numeric(x$total_states)),
    m = as.numeric(x$m) / 360, alpha = as.numeric(x$alpha),
    rho = as.numeric(x$rho), log_tau0 = log10(as.numeric(x$rhs_tau0)),
    bound = as.numeric(as.character(x$input_bound) != "none"),
    robust = rank(as.numeric(x$rhs_robust_score), ties.method = "average") /
      nrow(x), stringsAsFactors = FALSE
  )
}

iqcr_v2_select_refinement <- function(bridge_ranked, candidates, bridge_ids,
                                       protocol) {
  remaining <- candidates[!candidates$candidate_id %in% bridge_ids,
                          , drop = FALSE]
  rows <- list()
  assignments <- list()
  kr <- 0L
  ka <- 0L
  cells <- iqcr_v2_target_cells(protocol)
  for (family in iqcr_v2_families) {
    count <- iqcr_v2_named_integer(protocol$search$refinement_per_family,
                                   family)
    pool <- remaining[remaining$family == family, , drop = FALSE]
    family_bridge <- bridge_ranked[bridge_ranked$family == family,
                                   , drop = FALSE]
    cell_key <- interaction(
      family_bridge$tau, family_bridge$likelihood_family, drop = TRUE
    )
    parent_ids <- unique(unlist(lapply(split(family_bridge, cell_key),
                                      function(x) {
      x <- x[order(x$selection_rank, x$median_forecast_mae), , drop = FALSE]
      utils::head(x$candidate_id, 4L)
    }), use.names = FALSE))
    parents <- candidates[match(parent_ids, candidates$candidate_id),
                          , drop = FALSE]
    pool_features <- iqcr_v2_candidate_features(pool)
    parent_features <- iqcr_v2_candidate_features(parents)
    scale <- apply(rbind(pool_features, parent_features), 2L, stats::sd)
    scale[!is.finite(scale) | scale <= 1e-12] <- 1
    nearest <- vapply(seq_len(nrow(pool_features)), function(i) {
      delta <- sweep(as.matrix(parent_features), 2L,
                     as.numeric(pool_features[i, ]), "-")
      min(sqrt(rowSums(sweep(delta, 2L, scale, "/")^2)))
    }, numeric(1L))
    pool$refinement_distance <- nearest
    pool$robust_score <- rank(pool$rhs_robust_score, ties.method = "average") +
      0.50 * rank(pool$refinement_distance, ties.method = "average")
    pool$median_forecast_mae <- pool$rhs_median_forecast_mae
    pool$worst_forecast_mae <- pool$rhs_worst_forecast_mae
    selected <- iqcr_v2_select_rows(pool, count)
    selected$refinement_selection_rank <- seq_len(nrow(selected))
    kr <- kr + 1L
    rows[[kr]] <- selected
    family_cells <- cells[cells$family == family & !cells$protected,
                          , drop = FALSE]
    for (j in seq_len(nrow(family_cells))) {
      for (i in seq_len(nrow(selected))) {
        ka <- ka + 1L
        assignments[[ka]] <- data.frame(
          target_cell_id = family_cells$target_cell_id[[j]],
          family = family, tau = family_cells$tau[[j]],
          likelihood_family = family_cells$likelihood_family[[j]],
          candidate_id = selected$candidate_id[[i]],
          refinement_selection_rank = i,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  selected <- do.call(rbind, rows)
  assignment <- do.call(rbind, assignments)
  expected_assignments <- 24L * 6L + 16L * 5L + 24L * 6L
  if (nrow(selected) != 64L || anyDuplicated(selected$candidate_id) ||
      nrow(assignment) != expected_assignments) {
    stop("Adaptive refinement selection contract failed.", call. = FALSE)
  }
  list(candidates = selected, assignments = assignment)
}

iqcr_v2_select_mcmc_pilot <- function(ranked, candidates, protocol) {
  cells <- iqcr_v2_target_cells(protocol)
  cells <- cells[!cells$protected, , drop = FALSE]
  ranked <- merge(
    ranked, candidates[c(
      "candidate_id", "generation", "D", "total_states", "m", "alpha",
      "rho", "center_scale", "input_bound"
    )], by = "candidate_id", all.x = TRUE, sort = FALSE
  )
  rows <- list()
  k <- 0L
  for (cell_index in seq_len(nrow(cells))) {
    cell <- cells[cell_index, , drop = FALSE]
    x <- ranked[
      ranked$family == cell$family &
        abs(ranked$tau - cell$tau) < 1e-12 &
        ranked$likelihood_family == cell$likelihood_family,
      , drop = FALSE
    ]
    x <- x[order(x$selection_rank, x$median_forecast_mae), , drop = FALSE]
    selected <- integer()
    reasons <- character()
    add <- function(indices, reason, number) {
      indices <- setdiff(indices, selected)
      if (!length(indices)) return(invisible(NULL))
      take <- utils::head(indices, number)
      selected <<- c(selected, take)
      reasons <<- c(reasons, rep(reason, length(take)))
      invisible(NULL)
    }
    add(seq_len(nrow(x)), "quantile_forecast_leader", 4L)
    add(order(x$median_fit_rmse, x$median_forecast_mae),
        "fit_recovery_leader", 2L)
    add(order(x$worst_forecast_mae, x$median_forecast_mae),
        "worst_fold_leader", 1L)
    add(which(x$generation == "stage1_import"), "stage1_anchor", 1L)
    add(which(x$generation == "family_targeted_v2_new"),
        "novel_targeted_structure", 1L)
    add(order(-x$m, -x$total_states), "memory_capacity_boundary", 1L)
    add(seq_len(nrow(x)), "forecast_order_fill", 10L - length(selected))
    if (length(selected) != 10L) {
      stop("MCMC pilot diversity contract failed for ", cell$target_cell_id,
           call. = FALSE)
    }
    chosen <- x[selected, , drop = FALSE]
    chosen$selection_rank <- seq_len(nrow(chosen))
    chosen$selection_reason <- reasons
    chosen$target_cell_id <- cell$target_cell_id
    k <- k + 1L
    rows[[k]] <- chosen
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  if (nrow(out) != 170L || any(table(out$target_cell_id) != 10L)) {
    stop("The 170-job MCMC pilot selection contract failed.", call. = FALSE)
  }
  out
}

iqcr_v2_make_mcmc_configs <- function(repo_root, run_root, protocol, selected,
                                       candidates, sources, plan_stage,
                                       chain_ids, budget,
                                       confirmation = FALSE) {
  rows <- list()
  k <- 0L
  estimators <- if (confirmation) {
    c("posterior_predictive", "posterior_predictive_mean_readout_state")
  } else "posterior_predictive_mean_readout_state"
  contract <- if (confirmation) list(
    source_offset = 8110L, train_end = 9000L, rollout_end = 10000L,
    origin_start = 9000L, origin_end = 9970L, origin_stride = 1L,
    horizon = 30L, estimators = estimators, export_origin_lead = TRUE
  ) else list(
    source_offset = 8110L, train_end = 8800L, rollout_end = 9000L,
    origin_start = 8800L, origin_end = 8970L, origin_stride = 1L,
    horizon = 30L, estimators = estimators, export_origin_lead = FALSE
  )
  worker_stage <- if (confirmation) "mcmc_confirmation" else "mcmc_pilot"
  for (i in seq_len(nrow(selected))) {
    key <- selected[i, , drop = FALSE]
    candidate <- candidates[candidates$candidate_id == key$candidate_id[[1L]],
                            , drop = FALSE]
    source <- sources[sources$family == key$family[[1L]] &
                        abs(sources$tau - as.numeric(key$tau[[1L]])) < 1e-12,
                      , drop = FALSE]
    if (nrow(candidate) != 1L || nrow(source) != 1L) {
      stop("MCMC identity lookup failed.", call. = FALSE)
    }
    for (chain_id in as.integer(chain_ids)) {
      job_id <- paste(
        plan_stage, key$family[[1L]], key$likelihood_family[[1L]],
        iqrs_v1_tau_token(key$tau[[1L]]), candidate$candidate_id[[1L]],
        sprintf("c%02d", chain_id), sep = "__"
      )
      config_path <- file.path(run_root, "configs", plan_stage,
                               paste0(job_id, ".json"))
      result_path <- file.path(run_root, "results", plan_stage,
                               paste0(job_id, ".csv"))
      status_path <- file.path(run_root, "status", plan_stage,
                               paste0(job_id, ".json"))
      config <- list(
        schema_version = iqcr_v2_schema, protocol_id = protocol$protocol$id,
        protocol_path = file.path(repo_root, iqcr_v2_protocol_relpath),
        protocol_sha256 = iqfr_v2_sha256(file.path(repo_root,
                                                    iqcr_v2_protocol_relpath)),
        stage = worker_stage, plan_stage = plan_stage, job_id = job_id,
        repo_root = repo_root, run_root = run_root,
        source = as.list(source), candidate = as.list(candidate),
        likelihood_family = key$likelihood_family[[1L]],
        tau = as.numeric(key$tau[[1L]]), chain_id = chain_id,
        selection_rank = as.integer(key$selection_rank[[1L]] %||% 1L),
        budget = budget, forecast_contract = contract,
        seed = iqfr_v2_seed(
          protocol$protocol$id, plan_stage, key$family[[1L]],
          key$likelihood_family[[1L]], key$tau[[1L]],
          candidate$candidate_id[[1L]], chain_id
        ),
        result_path = result_path, status_path = status_path
      )
      iqfr_v2_write_json(config, config_path)
      k <- k + 1L
      rows[[k]] <- data.frame(
        stage = plan_stage, job_id = job_id, family = key$family[[1L]],
        tau = as.numeric(key$tau[[1L]]),
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

iqcr_v2_verify <- function(repo_root, run_root, require_complete = FALSE) {
  protocol <- iqcr_v2_read_protocol(repo_root)
  checks <- iqcr_v2_protocol_checks(protocol)
  authorities <- tryCatch(
    iqcr_v2_assert_authorities(repo_root, protocol),
    error = function(e) NULL
  )
  sources <- utils::read.csv(file.path(run_root, "source_manifest.csv"),
                             check.names = FALSE, stringsAsFactors = FALSE)
  source_pass <- nrow(sources) == 9L && all(vapply(
    sources$frozen_path, iqfr_v2_sha256, character(1L)
  ) == sources$frozen_sha256)
  plans <- list.files(file.path(run_root, "plans"), pattern = "[.]csv$",
                      full.names = TRUE)
  health <- if (length(plans)) do.call(rbind, lapply(
    plans, iqfr_v2_stage_health
  )) else data.frame()
  expected <- unlist(protocol$execution$expected_jobs)
  expected <- expected[names(expected) != "total"]
  count_pass <- all(vapply(seq_len(nrow(health)), function(i) {
    stage <- as.character(health$stage[[i]])
    stage %in% names(expected) &&
      health$planned[[i]] == as.integer(expected[[stage]])
  }, logical(1L)))
  complete_pass <- !require_complete ||
    (nrow(health) == length(expected) && all(health$complete) &&
       !any(health$failed > 0L | health$invalid > 0L))
  report <- list(
    schema_version = iqcr_v2_schema, protocol_checks = checks,
    authority_hashes_pass = !is.null(authorities),
    source_hashes_pass = source_pass, stage_health = health,
    materialized_counts_pass = count_pass,
    complete_required = require_complete,
    verification_pass = all(checks$pass) && !is.null(authorities) &&
      source_pass && count_pass && complete_pass
  )
  iqfr_v2_write_json(report,
                     file.path(run_root, "manifests", "live_verification.json"))
  report
}
