iqt12t_stages <- c("cost", "quantile_A", "quantile_B", "bridge",
  "final_vb", "final_warm", "final_mcmc")
iqt12t_priority <- c("normal__al__p005", "normal__exal__p025",
  "laplace__al__p005", "laplace__exal__p005")
iqt12t_signals <- c("laplace__al__p025", "laplace__al__p050",
  "laplace__exal__p025", "laplace__exal__p050", "gausmix__exal__p005")

iqt12t_portfolio <- function(state, cell) {
  ref <- state$references[[cell]]$candidate
  pool <- state$bank[[state$references[[cell]]$family]]
  pool <- pool[!duplicated(vapply(pool, iqt12_signature, ""))]
  key <- vapply(pool, iqt12_signature, "")
  used <- iqt12_signature(ref)
  chosen <- list(ref); roles <- "exact_anchor"
  take <- function(indices, role, count = 1L) {
    indices <- indices[!key[indices] %in% used]
    if (length(indices) < count) stop("Insufficient distinct frozen designs for ", role)
    for (i in head(indices, count)) {
      chosen[[length(chosen) + 1L]] <<- pool[[i]]
      roles <<- c(roles, role); used <<- c(used, key[i])
    }
  }
  total <- vapply(pool, function(c) sum(iqt12_unpack(c$n)), 0L)
  depth <- vapply(pool, function(c) length(iqt12_unpack(c$n)), 0L)
  alpha <- vapply(pool, function(c) c$alpha, 0.0)
  rho <- vapply(pool, function(c) c$rho, 0.0)
  big <- vapply(pool, function(c) max(iqt12_unpack(c$n)) >= 500L, TRUE)
  shallow <- which(big & depth == 1L & alpha >= .4 & rho >= .9)
  take(shallow[order(total[shallow], -alpha[shallow], key[shallow])], "capacity_shallow")
  deep <- which(big & depth >= 3L & alpha >= .4 & rho >= .85)
  take(deep[order(total[deep], -alpha[deep], key[deep])], "capacity_deep")
  distance <- vapply(pool, function(c) {
    abs(log((sum(iqt12_unpack(c$n)) + 1) / (sum(iqt12_unpack(ref$n)) + 1))) +
      abs(c$m - ref$m) / 390 + abs(c$alpha - ref$alpha) + abs(c$rho - ref$rho) +
      abs(log(c$input_gain / ref$input_gain)) / 3 +
      (c$center_scale != ref$center_scale) + (c$input_bound != ref$input_bound)
  }, 0.0)
  local <- which(vapply(pool, function(c) c$role == "local_capacity_search", TRUE))
  take(local[order(distance[local], key[local])], "nearest_frozen_local_bank", 4L)
  other <- which(!key %in% used & total <= 1000L)
  take(other[order(-distance[other], key[other])], "distinct_regime")
  stopifnot(length(chosen) == 8L, length(unique(used)) == 8L)
  out <- list()
  for (i in seq_along(chosen)) for (mult in c(.1, 1, 10)) {
    c <- iqt12_candidate(chosen[[i]], ref, mult, roles[i])
    c$parent_structure_signature <- iqt12_signature(chosen[[i]])
    out[[length(out) + 1L]] <- c
  }
  stopifnot(length(out) == 24L, !anyDuplicated(vapply(out, function(c) c$id, "")))
  out
}

iqt12t_parent_verify <- function(parent) {
  h <- iqt12_health(parent)
  stopifnot(sum(h$complete) == 88L, sum(h$failed) == 0L,
    sum(h$running) == 0L, sum(h$pending) == 0L)
  for (name in c("source_hashes.csv", "input_hashes.csv", "package_hashes.csv", "frozen_hashes.csv"))
    iqt12_verify(file.path(parent, name))
  for (p in list.files(file.path(parent, "plans"), "_hashes[.]csv$", full.names = TRUE))
    iqt12_verify(p)
  z <- iqt12_results(parent, c("cost", "diagnosis", "size_pilot"))
  stopifnot(nrow(z) == 440L)
  gate <- iqt12_read(file.path(parent, "scientific_gate.json"))
  stopifnot(gate$status == "PAUSED_TRAINING_SIZE_REVIEW")
  invisible(TRUE)
}

iqt12t_materialize <- function(repo, run, parent, library, preflight) {
  stopifnot(!dir.exists(run))
  iqt12t_parent_verify(parent)
  pf <- iqt12_read(file.path(preflight, "preflight.json")); stopifnot(isTRUE(pf$pass))
  state <- iqt12_read(file.path(parent, "campaign.json"))
  state$repo <- repo; state$run <- run; state$library <- library
  state$head <- system2("git", c("-C", repo, "rev-parse", "HEAD"), stdout = TRUE)
  state$protocol <- "training1000_targeted_v2_case_specific_continuation"
  state$parent <- parent; state$priority <- iqt12t_priority; state$signals <- iqt12t_signals
  state$maximum_explicit_jobs <- 380L; state$maximum_underlying_fit_calls <- 579L
  state$max_workers <- 15L; state$maximum_campaign_cpu_hours <- 400
  state$maximum_stage_wall_hours <- 48; state$maximum_worker_wall_seconds <- 172800L
  state$plan <- list(no_repeat_parent_stages = TRUE, screening_pairs_per_priority = 24L,
    total_screening_pairs = 96L, fold_B_max_nominees_per_priority = 4L,
    historical_interpretation = "case_specific_longer_history_not_pure_sample_size_causal_effect",
    global_gate_amendment = "user_authorized_case_specific_continuation_after_completed_global_review",
    selection = "forecast_MAE_then_check_then_fit_then_width_then_ID",
    normal_VB = "fresh_initializer_not_selection_exclusion_gate",
    final_training_N = 1000L, final_trigger = "any_strict_MCMC_development_forecast_gain",
    diagnostic_exclusion = FALSE, final_publication = FALSE,
    no_gain_action = "complete_development_no_gain_closeout_without_final_block")
  inputs <- c(file.path(parent, c("campaign.json", "scientific_gate.json", "frozen_hashes.csv",
    "source_hashes.csv", "input_hashes.csv", "package_hashes.csv",
    "summaries/training_size_contrast.csv")), file.path(preflight, c("preflight.json", "checks.csv")),
    file.path(repo, "validation/fitforecast_v2/docs/INDEPENDENT_TRAINING1000_TARGETED_V2_20261006.md"))
  for (cell in names(state$references)) {
    ref <- state$references[[cell]]
    stopifnot(unname(tools::sha256sum(ref$source_path)) == ref$source_sha)
    dest <- file.path(run, "sources", basename(ref$source_path))
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    if (!file.exists(dest)) stopifnot(file.copy(ref$source_path, dest))
    stopifnot(unname(tools::sha256sum(dest)) == ref$source_sha)
    state$references[[cell]]$source_path <- dest
    inputs <- c(inputs, ref$source_path)
  }
  state$portfolios <- setNames(lapply(state$priority, function(cell) iqt12t_portfolio(state, cell)), state$priority)
  ledger <- do.call(rbind, lapply(state$priority, function(cell)
    do.call(rbind, lapply(state$portfolios[[cell]], function(c) data.frame(cell = cell,
      id = c$id, structure_id = c$structure_id, role = c$role, n = c$n, m = c$m,
      alpha = c$alpha, rho = c$rho, input_gain = c$input_gain, input_fanin = c$input_fanin,
      tau_multiplier = c$tau_multiplier, tau_source = c$tau_source,
      readout_columns = c$readout_dimension, parent_signature = c$parent_structure_signature)))))
  stopifnot(nrow(ledger) == 96L, !anyDuplicated(paste(ledger$cell, ledger$id)))
  iqt12_csv(ledger, file.path(run, "candidate_banks/targeted_pairs.csv"))
  for (name in c("previous_article_summary.csv", "oracle_references.csv"))
    stopifnot(file.copy(file.path(parent, name), file.path(run, name)))
  iqt12_json(pf, file.path(run, "preflight.json"))
  iqt12_csv(read.csv(file.path(preflight, "checks.csv")), file.path(run, "preflight_checks.csv"))
  iqt12_json(list(status = "FROZEN_REVIEWED_CONTINUED_ON_NEW_RUN", parent = parent,
    completed_jobs = 88L, failed_jobs = 0L, reason = "count_pass_median_fail_case_specific_review",
    action_on_parent = "NONE", no_article_promotion = TRUE), file.path(run, "parent_closeout.json"))
  e <- iqt12_runtime(repo, library)
  env <- iqt12_read(file.path(parent, "environment.json"))
  env$library <- library; env$session <- capture.output(sessionInfo()); env$continuation_HEAD <- state$head
  iqt12_json(env, file.path(run, "environment.json"))
  code <- c(e$iqt12_loaded_files,
    file.path(repo, "validation/fitforecast_v2/R", c("independent_qdesn_training1000_runtime_v1.R",
      "independent_qdesn_training1000_campaign_v1.R", "independent_qdesn_training1000_targeted_v2.R")),
    list.files(file.path(repo, "validation/fitforecast_v2/scripts"), "training1000", full.names = TRUE))
  iqt12_hash(code, file.path(run, "source_hashes.csv"))
  iqt12_hash(inputs, file.path(run, "input_hashes.csv"))
  iqt12_hash(list.files(file.path(library, "exdqlm"), recursive = TRUE, full.names = TRUE),
    file.path(run, "package_hashes.csv"))
  iqt12_json(state, file.path(run, "campaign.json"))
  configs <- lapply(state$priority, function(cell)
    iqt12_config(state, cell, state$references[[cell]]$candidate, "cost"))
  for (cell in head(state$priority, 2L)) {
    pool <- state$portfolios[[cell]]
    c <- Filter(function(c) c$role == "capacity_deep" && c$tau_multiplier == 1, pool)[[1]]
    configs[[length(configs) + 1L]] <- iqt12_config(state, cell, c, "cost", "mcmc")
    configs[[length(configs) + 1L]] <- iqt12_config(state, cell,
      state$references[[cell]]$candidate, "cost", "mcmc", model = "baseline")
  }
  stopifnot(length(configs) == 8L)
  iqt12_plan(state, configs, "cost")
  iqt12_hash(c(file.path(run, c("campaign.json", "environment.json", "input_hashes.csv",
    "source_hashes.csv", "package_hashes.csv", "preflight.json", "preflight_checks.csv",
    "parent_closeout.json", "previous_article_summary.csv", "oracle_references.csv",
    "candidate_banks/targeted_pairs.csv")), vapply(state$references, function(r) r$source_path, "")),
    file.path(run, "frozen_hashes.csv"))
  invisible(state)
}

iqt12t_nominees <- function(z, ref) {
  rank <- iqt12_rank(z)
  anchor <- rank[rank$candidate_id == ref$id, ]
  stopifnot(nrow(anchor) == 1L)
  checks <- rank[order(rank$mean.forecast_check_loss, rank$mean.forecast_mae), ]
  capacities <- rank[vapply(rank$config_path, function(p)
    iqt12_read(p)$candidate$role %in% c("capacity_shallow", "capacity_deep"), TRUE), ]
  stopifnot(nrow(capacities) >= 2L)
  paths <- unique(c(anchor$config_path, rank$config_path[1], checks$config_path[1],
    capacities$config_path[1], rank$config_path))
  paths <- head(paths, 4L)
  # Reserve one explicit capacity bypass even when leaders fill all four places.
  if (!any(paths %in% capacities$config_path)) paths[4] <- capacities$config_path[1]
  stopifnot(length(paths) == 4L, !anyDuplicated(paths), anchor$config_path %in% paths)
  paths
}

iqt12t_forecast_decision <- function(results, state) {
  pairs <- list()
  for (cell in state$priority) for (metric in c("forecast_mae", "forecast_check_loss")) {
    z <- results[results$cell == cell & results$model == "qdesn" & results$N == 1000L, ]
    best <- iqt12_rank(z)$candidate_id[1]
    a <- z[z$candidate_id == state$references[[cell]]$candidate$id & z$metric == metric, ]
    b <- z[z$candidate_id == best & z$metric == metric, ]
    stopifnot(nrow(a) == 1L, nrow(b) == 1L)
    pairs[[length(pairs) + 1L]] <- data.frame(cell = cell, metric = metric,
      contrast = "selected_spec_vs_same_N1000_anchor", candidate_id = best,
      reference = a$mean, candidate = b$mean)
  }
  for (cell in state$signals) for (metric in c("forecast_mae", "forecast_check_loss")) {
    z <- results[results$cell == cell & results$model == "qdesn" & results$metric == metric, ]
    a <- z[z$N == 500L, ]; b <- z[z$N == 1000L, ]
    stopifnot(nrow(a) == 1L, nrow(b) == 1L)
    pairs[[length(pairs) + 1L]] <- data.frame(cell = cell, metric = metric,
      contrast = "same_spec_N1000_vs_N500", candidate_id = b$candidate_id,
      reference = a$mean, candidate = b$mean)
  }
  out <- do.call(rbind, pairs)
  stopifnot(all(is.finite(out$reference)), all(is.finite(out$candidate)))
  out$strict_gain <- out$candidate < out$reference
  out$percent_change <- 100 * (out$candidate / out$reference - 1)
  out
}

iqt12t_advance <- function(run, finished) {
  state <- iqt12_read(file.path(run, "campaign.json"))
  stopifnot(state$protocol == "training1000_targeted_v2_case_specific_continuation")
  iqt12_verify(file.path(run, "input_hashes.csv"))
  results <- iqt12_results(run, finished)
  iqt12_csv(results, file.path(run, "summaries", paste0(finished, ".csv")))
  if (finished %in% c("final_vb", "final_warm")) return(iqt12_advance(run, finished))
  if (finished == "final_mcmc") {
    result <- iqt12_closeout(run)
    iqt12_json(list(status = "COMPLETE_REQUIRES_SCIENTIFIC_INTEGRATION_REVIEW",
      source_HEAD = state$head, active_jobs = 0L, article_changed = FALSE,
      comparison = "N1000_new_protocol_not_same_N500_article_estimator"), file.path(run, "continuation_closeout.json"))
    return(result)
  }
  next_stage <- iqt12t_stages[match(finished, iqt12t_stages) + 1L]
  configs <- list(); add <- function(c) configs[[length(configs) + 1L]] <<- c
  if (finished == "cost") {
    costs <- lapply(unique(results$config_path), function(p) {
      cfg <- iqt12_read(p); d <- iqt12_read(file.path(cfg$evidence, "diagnostics.json"))
      iqt12_cost_projection(cfg, d)
    })
    cost <- do.call(rbind, costs)
    iqt12_csv(cost, file.path(run, "summaries/targeted_cost_projection.csv"))
    if (any(cost$peak_rss_gib > state$max_worker_rss_gib) ||
        any(cost$projected_final_forecast_seconds + cost$projected_final_fit_seconds +
          cost$projected_fixed_overhead_seconds > state$maximum_worker_wall_seconds))
      stop("Targeted cost envelope requires review.")
    for (cell in state$priority) for (c in state$portfolios[[cell]])
      add(iqt12_config(state, cell, c, next_stage))
  } else if (finished == "quantile_A") {
    for (cell in names(state$references)) {
      ref <- state$references[[cell]]$candidate
      paths <- if (cell %in% state$priority)
        iqt12t_nominees(results[results$cell == cell, ], ref) else character()
      candidates <- if (length(paths)) lapply(paths, function(p) iqt12_read(p)$candidate) else list(ref)
      nominees <- do.call(rbind, lapply(seq_along(candidates), function(i) {
        c <- candidates[[i]]; cfg <- iqt12_config(state, cell, c, next_stage, fold = "B"); add(cfg)
        data.frame(cell = cell, candidate_id = c$id,
          fold_A_config = if (length(paths)) paths[i] else "predeclared_fixed_anchor",
          selection_role = c$role, frozen_before_B = TRUE)
      }))
      iqt12_csv(nominees, file.path(run, "selections", paste0("frozen_B_", cell, ".csv")))
      add(iqt12_config(state, cell, ref, next_stage, fold = "B", model = "baseline"))
    }
  } else if (finished == "quantile_B") {
    for (p in unique(results$config_path)) {
      ref <- iqt12_read(p)
      cfg <- iqt12_config(state, ref$cell, ref$candidate, next_stage,
        engine = "mcmc", fold = "B", model = ref$model)
      cfg$warm_path <- file.path(ref$evidence, "mcmc_initializer.json")
      cfg$warm_sha <- unname(tools::sha256sum(cfg$warm_path)); add(cfg)
    }
    for (cell in c(state$priority, state$signals)) for (model in c("qdesn", "baseline"))
      add(iqt12_config(state, cell, state$references[[cell]]$candidate, next_stage,
        engine = "mcmc", N = 500L, fold = "B", model = model))
  } else if (finished == "bridge") {
    ledger <- iqt12t_forecast_decision(results, state)
    iqt12_csv(ledger, file.path(run, "summaries/MCMC_development_forecast_gain_ledger.csv"))
    all_gains <- merge(results[results$model == "qdesn" & results$N == 1000L &
      results$metric %in% c("forecast_mae", "forecast_check_loss"), ],
      results[results$model == "qdesn" & results$N == 1000L &
        results$candidate_id == vapply(results$cell, function(cell)
          state$references[[cell]]$candidate$id, "") &
        results$metric %in% c("forecast_mae", "forecast_check_loss"), c("cell", "metric", "mean")],
      by = c("cell", "metric"), suffixes = c("_candidate", "_anchor"))
    all_gains$strict_gain <- all_gains$mean_candidate < all_gains$mean_anchor
    all_gains$diagnostic_exclusion <- FALSE
    iqt12_csv(all_gains, file.path(run, "summaries/all_nominee_forecast_gains.csv"))
    decision <- list(status = if (any(ledger$strict_gain)) "PROCEED_COHERENT_N1000_FINAL" else
      "COMPLETE_NO_MCMC_DEVELOPMENT_FORECAST_GAIN", strict_metric_gains = sum(ledger$strict_gain),
      diagnostic_exclusion = FALSE, minimum_gain_threshold = 0,
      partial_article_promotion = FALSE, familiar_final_block_opened = FALSE)
    iqt12_json(decision, file.path(run, "development_decision.json"))
    if (!any(ledger$strict_gain)) {
      iqt12_hash(c(file.path(run, "development_decision.json"),
        list.files(file.path(run, "summaries"), full.names = TRUE),
        file.path(run, "candidate_banks/targeted_pairs.csv")), file.path(run, "development_closeout_manifest.csv"))
      return("COMPLETE_NO_MCMC_DEVELOPMENT_FORECAST_GAIN")
    }
    vb <- iqt12_results(run, "quantile_B"); winners <- list()
    for (cell in names(state$references)) for (engine in c("vb", "mcmc")) {
      z <- if (engine == "vb") vb else results[results$N == 1000L, ]
      z <- z[z$cell == cell & z$model == "qdesn", ]
      winner <- iqt12_rank(z)$config_path[1]; c <- iqt12_read(winner)$candidate
      winners[[length(winners) + 1L]] <- data.frame(cell = cell, engine = engine,
        candidate_id = c$id, selection_config = winner)
      if (engine == "vb") {
        add(iqt12_config(state, cell, c, next_stage, fold = "final"))
        add(iqt12_config(state, cell, state$references[[cell]]$candidate, next_stage,
          fold = "final", model = "baseline"))
      }
    }
    iqt12_csv(do.call(rbind, winners), file.path(run, "selections/frozen_final_winners.csv"))
  } else stop("Unsupported targeted stage: ", finished)
  iqt12_plan(state, configs, next_stage)
  next_stage
}
