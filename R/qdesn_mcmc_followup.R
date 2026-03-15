`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_multichain_grade_score <- function(x) {
  x <- toupper(trimws(as.character(x %||% "")))
  out <- rep(NA_real_, length(x))
  out[x == "PASS"] <- 2
  out[x == "WARN"] <- 1
  out[x == "FAIL"] <- 0
  out
}

.qdesn_validation_read_report_csv <- function(report_root, name) {
  path <- file.path(report_root, "tables", name)
  if (!file.exists(path)) {
    stop(sprintf("Required report table missing: %s", path), call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_validation_multichain_default_seeds <- function(root_spec, n_chains = 4L, seed_base = 500000L) {
  n_chains <- max(2L, as.integer(n_chains)[1L])
  base_seed <- as.integer(seed_base)[1L] + 1000L * as.integer(root_spec$seed)[1L]
  base_seed + seq_len(n_chains)
}

.qdesn_validation_split_chain <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 20L) return(list(x))
  half <- floor(n / 2L)
  if (half < 10L) return(list(x))
  list(x[seq_len(half)], x[(n - half + 1L):n])
}

.qdesn_validation_safe_rhat <- function(chains, split = TRUE) {
  .qdesn_validation_require_namespace("coda")
  if (!length(chains)) return(NA_real_)
  chain_list <- lapply(chains, function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (isTRUE(split)) {
      .qdesn_validation_split_chain(x)
    } else {
      list(x)
    }
  })
  chain_list <- unlist(chain_list, recursive = FALSE)
  chain_list <- Filter(function(x) length(x) >= 10L && all(is.finite(x)), chain_list)
  if (length(chain_list) < 2L) return(NA_real_)
  min_len <- min(vapply(chain_list, length, integer(1)))
  if (!is.finite(min_len) || min_len < 10L) return(NA_real_)
  ml <- coda::mcmc.list(lapply(chain_list, function(x) coda::as.mcmc(x[seq_len(min_len)])))
  out <- tryCatch(coda::gelman.diag(ml, autoburnin = FALSE, multivariate = FALSE)$psrf[1L, 1L], error = function(...) NA_real_)
  as.numeric(out)[1L]
}

.qdesn_validation_multichain_rhat_summary <- function(chain_progress_rows) {
  if (!nrow(chain_progress_rows)) return(data.frame(stringsAsFactors = FALSE))
  params <- intersect(
    c("gamma", "sigma", "beta_norm", "rhs_tau", "rhs_c2", "rhs_lambda_mean"),
    names(chain_progress_rows)
  )
  rows <- lapply(params, function(param) {
    split_idx <- split(seq_len(nrow(chain_progress_rows)), chain_progress_rows$chain_id)
    chains <- lapply(split_idx, function(idx) as.numeric(chain_progress_rows[[param]][idx]))
    means <- vapply(chains, function(x) mean(x[is.finite(x)]), numeric(1))
    sds <- vapply(chains, function(x) stats::sd(x[is.finite(x)]), numeric(1))
    data.frame(
      parameter = param,
      n_chains = length(chains),
      min_chain_length = min(vapply(chains, function(x) sum(is.finite(x)), integer(1))),
      rhat = .qdesn_validation_safe_rhat(chains, split = TRUE),
      chain_mean_min = min(means, na.rm = TRUE),
      chain_mean_max = max(means, na.rm = TRUE),
      chain_sd_min = min(sds, na.rm = TRUE),
      chain_sd_max = max(sds, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}

.qdesn_validation_multichain_root_confirmation <- function(root_spec, vb_signoff, chain_signoff, rhat_summary) {
  n_chains <- nrow(chain_signoff)
  n_fail <- sum(as.character(chain_signoff$signoff_grade) == "FAIL", na.rm = TRUE)
  n_warn <- sum(as.character(chain_signoff$signoff_grade) == "WARN", na.rm = TRUE)
  n_pass <- sum(as.character(chain_signoff$signoff_grade) == "PASS", na.rm = TRUE)
  all_success <- all(as.character(chain_signoff$status) == "SUCCESS")
  max_rhat <- if (nrow(rhat_summary)) max(rhat_summary$rhat, na.rm = TRUE) else NA_real_
  if (!is.finite(max_rhat)) max_rhat <- NA_real_

  grade <- "FAIL"
  reason <- character(0)
  if (isTRUE(all_success) && n_fail == 0L && is.finite(max_rhat) && max_rhat <= 1.05) {
    grade <- "PASS"
    reason <- c("all_chains_success", "acceptable_split_rhat")
  } else if (isTRUE(all_success) && n_fail <= 1L && (!is.finite(max_rhat) || max_rhat <= 1.10)) {
    grade <- "WARN"
    reason <- c("chains_marginal_but_usable")
    if (!is.finite(max_rhat)) reason <- c(reason, "missing_rhat")
  } else {
    if (!isTRUE(all_success)) reason <- c(reason, "chain_failure")
    if (n_fail > 1L) reason <- c(reason, "multiple_chain_signoff_failures")
    if (is.finite(max_rhat) && max_rhat > 1.10) reason <- c(reason, "split_rhat_high")
    if (!length(reason)) reason <- c("multichain_confirmation_failed")
  }

  data.frame(
    root_id = as.character(root_spec$root_id),
    scenario = as.character(root_spec$scenario),
    tau = as.numeric(root_spec$tau),
    beta_prior_type = as.character(root_spec$beta_prior_type),
    seed = as.integer(root_spec$seed),
    reservoir_profile = as.character(root_spec$reservoir_profile),
    vb_signoff_grade = as.character(vb_signoff$signoff_grade[1L] %||% NA_character_),
    n_chains = as.integer(n_chains),
    n_chain_pass = as.integer(n_pass),
    n_chain_warn = as.integer(n_warn),
    n_chain_fail = as.integer(n_fail),
    max_split_rhat = as.numeric(max_rhat),
    confirmation_grade = grade,
    confirmation_reason = paste(reason, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

.qdesn_validation_followup_root_meta <- function(root_spec) {
  data.frame(
    root_id = as.character(root_spec$root_id),
    scenario = as.character(root_spec$scenario),
    tau = as.numeric(root_spec$tau),
    beta_prior_type = as.character(root_spec$beta_prior_type),
    seed = as.integer(root_spec$seed),
    reservoir_profile = as.character(root_spec$reservoir_profile),
    stringsAsFactors = FALSE
  )
}

qdesn_validation_run_multichain_root <- function(root_spec,
                                                 defaults = NULL,
                                                 defaults_path = file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"),
                                                 output_root,
                                                 n_chains = 4L,
                                                 chain_seeds = NULL,
                                                 create_plots = TRUE,
                                                 verbose = TRUE) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  root_spec <- qdesn_validation_enrich_root_spec(root_spec, defaults)
  .qdesn_validation_apply_thread_caps(as.integer(((defaults$runtime %||% list())$threads %||% 1L)[1L]))

  root_dir <- file.path(output_root, root_spec$root_id)
  if (dir.exists(root_dir) && length(list.files(root_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    stop(sprintf("Multichain validation root already exists and is not empty: %s", root_dir), call. = FALSE)
  }
  for (d in c("manifest", "config", "data", "vb", "chains", "tables", "plots")) {
    .qdesn_validation_dir_create(file.path(root_dir, d))
  }

  scenario_cfg <- .qdesn_validation_scenario_cfg(defaults, root_spec$scenario)
  p_grid <- as.numeric((defaults$toy %||% list())$p_grid %||% seq(0.01, 0.99, by = 0.01))
  toy_obj <- qdesn_validation_generate_toy_series(
    scenario = root_spec$scenario,
    seed = root_spec$seed,
    p_grid = p_grid,
    scenario_cfg = scenario_cfg
  )
  .qdesn_validation_write_toy_data(root_dir, toy_obj)
  file_long <- file.path(root_dir, "data", "series_long.csv")

  chain_seeds <- as.integer(chain_seeds %||% .qdesn_validation_multichain_default_seeds(root_spec, n_chains = n_chains))
  if (length(chain_seeds) != as.integer(n_chains)[1L]) {
    stop("chain_seeds length must match n_chains.", call. = FALSE)
  }

  .qdesn_validation_write_json(file.path(root_dir, "manifest", "multichain_root_manifest.json"), list(
    root_spec = as.list(root_spec),
    defaults_path = defaults_path,
    n_chains = as.integer(n_chains),
    chain_seeds = as.integer(chain_seeds),
    started_at = as.character(Sys.time()),
    git_sha = .qdesn_validation_git_sha()
  ))

  vb_dir <- file.path(root_dir, "vb")
  vb_res <- .qdesn_validation_run_one_method("vb", root_spec, defaults, file_long, vb_dir, verbose = verbose)
  meta_row <- .qdesn_validation_followup_root_meta(root_spec)
  sign_cfg <- .qdesn_validation_signoff_cfg(defaults)
  vb_signoff <- .qdesn_validation_vb_signoff_from_rows(meta_row, vb_res$health[1L, , drop = FALSE], vb_res$progress_trace, sign_cfg$vb)

  chain_rows <- vector("list", length(chain_seeds))
  chain_signoff_rows <- vector("list", length(chain_seeds))
  chain_progress_rows <- vector("list", length(chain_seeds))

  for (ii in seq_along(chain_seeds)) {
    if (isTRUE(verbose)) {
      message(sprintf("[qdesn_validation_run_multichain_root] %s | chain %d/%d | mcmc_seed=%d", root_spec$root_id, ii, length(chain_seeds), chain_seeds[[ii]]))
    }
    defaults_i <- defaults
    defaults_i$pipeline <- defaults_i$pipeline %||% list()
    defaults_i$pipeline$inference <- defaults_i$pipeline$inference %||% list()
    defaults_i$pipeline$inference$mcmc <- defaults_i$pipeline$inference$mcmc %||% list()
    defaults_i$pipeline$inference$mcmc$control_base <- modifyList(
      defaults_i$pipeline$inference$mcmc$control_base %||% list(),
      list(seed = as.integer(chain_seeds[[ii]]))
    )

    method_dir <- file.path(root_dir, "chains", sprintf("chain_%02d", ii), "mcmc")
    res_i <- .qdesn_validation_run_one_method("mcmc", root_spec, defaults_i, file_long, method_dir, verbose = verbose)
    signoff_i <- .qdesn_validation_mcmc_signoff_from_rows(meta_row, res_i$health[1L, , drop = FALSE], res_i$progress_trace, .qdesn_validation_signoff_cfg(defaults_i)$mcmc)

    chain_rows[[ii]] <- cbind(
      data.frame(chain_id = as.integer(ii), mcmc_seed = as.integer(chain_seeds[[ii]]), stringsAsFactors = FALSE),
      res_i$health,
      stringsAsFactors = FALSE
    )
    chain_signoff_rows[[ii]] <- cbind(
      data.frame(chain_id = as.integer(ii), mcmc_seed = as.integer(chain_seeds[[ii]]), stringsAsFactors = FALSE),
      signoff_i,
      stringsAsFactors = FALSE
    )
    if (nrow(res_i$progress_trace)) {
      chain_progress_rows[[ii]] <- cbind(
        data.frame(chain_id = as.integer(ii), mcmc_seed = as.integer(chain_seeds[[ii]]), stringsAsFactors = FALSE),
        res_i$progress_trace,
        stringsAsFactors = FALSE
      )
    }
  }

  vb_health <- vb_res$health
  vb_health$signoff_grade <- as.character(vb_signoff$signoff_grade[1L] %||% NA_character_)
  vb_health$comparison_eligible <- as.logical(vb_signoff$comparison_eligible[1L] %||% FALSE)
  vb_health$signoff_reason <- as.character(vb_signoff$signoff_reason[1L] %||% NA_character_)
  chain_health <- .qdesn_validation_bind_rows(chain_rows)
  chain_signoff <- .qdesn_validation_bind_rows(chain_signoff_rows)
  chain_progress <- .qdesn_validation_bind_rows(chain_progress_rows)
  rhat_summary <- .qdesn_validation_multichain_rhat_summary(chain_progress)
  root_confirmation <- .qdesn_validation_multichain_root_confirmation(root_spec, vb_signoff, chain_signoff, rhat_summary)

  .qdesn_validation_write_df(vb_health, file.path(root_dir, "tables", "vb_reference_health.csv"))
  .qdesn_validation_write_df(chain_health, file.path(root_dir, "tables", "chain_health.csv"))
  .qdesn_validation_write_df(chain_signoff, file.path(root_dir, "tables", "chain_signoff.csv"))
  .qdesn_validation_write_df(chain_progress, file.path(root_dir, "tables", "chain_progress_long.csv"))
  .qdesn_validation_write_df(rhat_summary, file.path(root_dir, "tables", "multichain_rhat_summary.csv"))
  .qdesn_validation_write_df(root_confirmation, file.path(root_dir, "tables", "root_confirmation.csv"))

  summary_lines <- c(
    "# Q-DESN Multichain Root Confirmation",
    "",
    sprintf("- Root: `%s`", root_spec$root_id),
    sprintf("- Chains: `%d`", as.integer(n_chains)),
    sprintf("- Confirmation grade: `%s`", root_confirmation$confirmation_grade[1L]),
    sprintf("- Confirmation reason: `%s`", root_confirmation$confirmation_reason[1L]),
    "",
    "## Root Summary",
    "",
    .qdesn_validation_df_to_markdown(root_confirmation),
    "",
    "## Split-Rhat Summary",
    "",
    .qdesn_validation_df_to_markdown(rhat_summary)
  )
  .qdesn_validation_write_lines(file.path(root_dir, "confirmation_summary.md"), summary_lines)

  if (isTRUE(create_plots) && nrow(rhat_summary)) {
    .qdesn_validation_require_namespace("ggplot2")
    p_rhat <- ggplot2::ggplot(rhat_summary, ggplot2::aes(x = parameter, y = rhat, fill = parameter)) +
      ggplot2::geom_hline(yintercept = 1.05, linetype = 2, linewidth = 0.5, colour = "#6b7280") +
      ggplot2::geom_hline(yintercept = 1.10, linetype = 3, linewidth = 0.5, colour = "#9ca3af") +
      ggplot2::geom_col(width = 0.65) +
      ggplot2::labs(title = "Split-Rhat by Parameter", x = NULL, y = "split-Rhat", fill = NULL) +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "none")
    ggplot2::ggsave(file.path(root_dir, "plots", "split_rhat.png"), p_rhat, width = 7, height = 4.2, dpi = 150)
  }

  list(
    root_dir = root_dir,
    root_confirmation = root_confirmation,
    chain_signoff = chain_signoff,
    rhat_summary = rhat_summary
  )
}

.qdesn_validation_collect_multichain_results <- function(results_root) {
  root_dirs <- list.dirs(file.path(results_root, "roots"), recursive = FALSE, full.names = TRUE)
  confirm_rows <- list()
  rhat_rows <- list()
  chain_rows <- list()
  for (root_dir in root_dirs) {
    confirm_path <- file.path(root_dir, "tables", "root_confirmation.csv")
    rhat_path <- file.path(root_dir, "tables", "multichain_rhat_summary.csv")
    chain_path <- file.path(root_dir, "tables", "chain_signoff.csv")
    if (file.exists(confirm_path)) confirm_rows[[length(confirm_rows) + 1L]] <- utils::read.csv(confirm_path, stringsAsFactors = FALSE)
    if (file.exists(rhat_path)) rhat_rows[[length(rhat_rows) + 1L]] <- cbind(.qdesn_validation_collect_root_meta(root_dir), utils::read.csv(rhat_path, stringsAsFactors = FALSE), stringsAsFactors = FALSE)
    if (file.exists(chain_path)) chain_rows[[length(chain_rows) + 1L]] <- utils::read.csv(chain_path, stringsAsFactors = FALSE)
  }
  list(
    root_confirmation = .qdesn_validation_bind_rows(confirm_rows),
    rhat_summary = .qdesn_validation_bind_rows(rhat_rows),
    chain_signoff = .qdesn_validation_bind_rows(chain_rows)
  )
}

qdesn_validation_collect_multichain_campaign <- function(results_root, report_root, create_plots = TRUE) {
  .qdesn_validation_dir_create(report_root)
  .qdesn_validation_dir_create(file.path(report_root, "tables"))
  .qdesn_validation_dir_create(file.path(report_root, "plots"))
  .qdesn_validation_dir_create(file.path(report_root, "manifest"))

  collected <- .qdesn_validation_collect_multichain_results(results_root)
  root_confirmation <- collected$root_confirmation
  rhat_summary <- collected$rhat_summary
  chain_signoff <- collected$chain_signoff

  .qdesn_validation_write_df(root_confirmation, file.path(report_root, "tables", "campaign_root_confirmation.csv"))
  .qdesn_validation_write_df(rhat_summary, file.path(report_root, "tables", "campaign_multichain_rhat.csv"))
  .qdesn_validation_write_df(chain_signoff, file.path(report_root, "tables", "campaign_chain_signoff.csv"))

  lines <- c(
    "# Q-DESN Multichain Campaign",
    "",
    sprintf("- Results root: `%s`", results_root),
    sprintf("- Report root: `%s`", report_root),
    sprintf("- Completed roots: `%d`", nrow(root_confirmation)),
    "",
    "## Root Confirmation",
    "",
    .qdesn_validation_df_to_markdown(root_confirmation)
  )
  .qdesn_validation_write_lines(file.path(report_root, "campaign_summary.md"), lines)
  .qdesn_validation_write_json(file.path(report_root, "manifest", "campaign_manifest.json"), list(
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
    generated_at = as.character(Sys.time()),
    git_sha = .qdesn_validation_git_sha()
  ))

  if (isTRUE(create_plots) && nrow(root_confirmation)) {
    .qdesn_validation_require_namespace("ggplot2")
    root_confirmation$tau_label <- .qdesn_validation_tau_label(root_confirmation$tau)
    p_confirm <- ggplot2::ggplot(root_confirmation, ggplot2::aes(x = tau_label, y = scenario, fill = confirmation_grade)) +
      ggplot2::geom_tile(colour = "white") +
      ggplot2::facet_wrap(~ beta_prior_type) +
      ggplot2::scale_fill_manual(values = c(PASS = "#16a34a", WARN = "#ca8a04", FAIL = "#dc2626")) +
      ggplot2::labs(title = "Multichain Confirmation Grade", x = "tau", y = NULL, fill = NULL) +
      ggplot2::theme_minimal(base_size = 11) +
      ggplot2::theme(legend.position = "top")
    ggplot2::ggsave(file.path(report_root, "plots", "multichain_confirmation_matrix.png"), p_confirm, width = 9, height = 4.5, dpi = 150)
  }

  invisible(collected)
}

qdesn_validation_run_multichain_campaign <- function(grid = NULL,
                                                     defaults = NULL,
                                                     grid_path,
                                                     defaults_path = file.path("config", "validation", "qdesn_mcmc_compare_rhs_repair_defaults.yaml"),
                                                     results_root,
                                                     report_root,
                                                     n_chains = 4L,
                                                     chain_seed_base = 500000L,
                                                     create_plots = TRUE,
                                                     verbose = TRUE) {
  defaults <- defaults %||% qdesn_validation_load_defaults(defaults_path)
  grid <- grid %||% qdesn_validation_load_grid(grid_path)

  for (d in c(results_root, file.path(results_root, "roots"), report_root, file.path(report_root, "tables"), file.path(report_root, "plots"), file.path(report_root, "manifest"))) {
    .qdesn_validation_dir_create(d)
  }
  .qdesn_validation_write_json(file.path(report_root, "manifest", "campaign_started.json"), list(
    started_at = as.character(Sys.time()),
    grid_path = grid_path,
    defaults_path = defaults_path,
    n_chains = as.integer(n_chains),
    chain_seed_base = as.integer(chain_seed_base),
    git_sha = .qdesn_validation_git_sha()
  ))

  progress_rows <- list()
  for (ii in seq_len(nrow(grid))) {
    root_spec <- qdesn_validation_enrich_root_spec(as.list(grid[ii, , drop = FALSE]), defaults)
    if (!isTRUE(root_spec$enabled)) next
    res <- qdesn_validation_run_multichain_root(
      root_spec = root_spec,
      defaults = defaults,
      defaults_path = defaults_path,
      output_root = file.path(results_root, "roots"),
      n_chains = n_chains,
      chain_seeds = .qdesn_validation_multichain_default_seeds(root_spec, n_chains = n_chains, seed_base = chain_seed_base),
      create_plots = create_plots,
      verbose = verbose
    )
    progress_rows[[length(progress_rows) + 1L]] <- res$root_confirmation
    .qdesn_validation_write_df(.qdesn_validation_bind_rows(progress_rows), file.path(report_root, "tables", "campaign_progress.csv"))
    qdesn_validation_collect_multichain_campaign(results_root = results_root, report_root = report_root, create_plots = create_plots)
  }

  final <- qdesn_validation_collect_multichain_campaign(results_root = results_root, report_root = report_root, create_plots = create_plots)
  .qdesn_validation_write_json(file.path(report_root, "manifest", "campaign_completed.json"), list(
    finished_at = as.character(Sys.time()),
    results_root = normalizePath(results_root, winslash = "/", mustWork = FALSE),
    report_root = normalizePath(report_root, winslash = "/", mustWork = FALSE),
    n_roots = nrow(final$root_confirmation)
  ))
  invisible(final)
}

qdesn_validation_extract_failed_rhs_grid <- function(candidate_report_root,
                                                     output_path,
                                                     fallback_grid_path = file.path("config", "validation", "qdesn_mcmc_rhs_failure_grid.csv")) {
  progress <- .qdesn_validation_read_report_csv(candidate_report_root, "campaign_progress.csv")
  fail_df <- subset(progress, beta_prior_type == "rhs" & mcmc_signoff_grade == "FAIL")
  if (!nrow(fail_df) && file.exists(fallback_grid_path)) {
    fail_df <- utils::read.csv(fallback_grid_path, stringsAsFactors = FALSE)
  } else if (nrow(fail_df)) {
    fail_df <- unique(fail_df[, c("scenario", "tau", "beta_prior_type", "seed", "reservoir_profile"), drop = FALSE])
    fail_df$enabled <- TRUE
  }
  .qdesn_validation_write_df(fail_df, output_path)
  output_path
}

qdesn_validation_assess_rhs_repair_candidate <- function(candidate_report_root,
                                                         baseline_report_root,
                                                         output_root) {
  safe_mean <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) return(NA_real_)
    mean(x)
  }
  .qdesn_validation_dir_create(output_root)
  .qdesn_validation_dir_create(file.path(output_root, "tables"))
  .qdesn_validation_dir_create(file.path(output_root, "manifest"))

  pair_base <- .qdesn_validation_read_report_csv(baseline_report_root, "campaign_pair_group_summary.csv")
  pair_cand <- .qdesn_validation_read_report_csv(candidate_report_root, "campaign_pair_group_summary.csv")
  meth_base <- .qdesn_validation_read_report_csv(baseline_report_root, "campaign_method_group_summary.csv")
  meth_cand <- .qdesn_validation_read_report_csv(candidate_report_root, "campaign_method_group_summary.csv")

  rhs_base <- subset(pair_base, beta_prior_type == "rhs")
  rhs_cand <- subset(pair_cand, beta_prior_type == "rhs")
  ridge_base <- subset(pair_base, beta_prior_type == "ridge")
  ridge_cand <- subset(pair_cand, beta_prior_type == "ridge")
  rhs025_base <- subset(rhs_base, abs(tau - 0.25) < 1e-12)
  rhs025_cand <- subset(rhs_cand, abs(tau - 0.25) < 1e-12)
  rhs_m_base <- subset(meth_base, beta_prior_type == "rhs" & method == "mcmc")
  rhs_m_cand <- subset(meth_cand, beta_prior_type == "rhs" & method == "mcmc")

  summary_df <- data.frame(
    metric = c(
      "rhs_pair_eligible_rate",
      "rhs_tau025_pair_eligible_rate",
      "rhs_mcmc_fail_count",
      "ridge_pair_eligible_rate"
    ),
    baseline = c(
      safe_mean(rhs_base$pair_comparison_eligible_rate),
      safe_mean(rhs025_base$pair_comparison_eligible_rate),
      sum(rhs_m_base$n_signoff_fail, na.rm = TRUE),
      safe_mean(ridge_base$pair_comparison_eligible_rate)
    ),
    candidate = c(
      safe_mean(rhs_cand$pair_comparison_eligible_rate),
      safe_mean(rhs025_cand$pair_comparison_eligible_rate),
      sum(rhs_m_cand$n_signoff_fail, na.rm = TRUE),
      safe_mean(ridge_cand$pair_comparison_eligible_rate)
    ),
    stringsAsFactors = FALSE
  )
  summary_df$delta_candidate_minus_baseline <- summary_df$candidate - summary_df$baseline

  representative_ok <- isTRUE(summary_df$candidate[summary_df$metric == "rhs_pair_eligible_rate"] >= summary_df$baseline[summary_df$metric == "rhs_pair_eligible_rate"]) &&
    isTRUE(summary_df$candidate[summary_df$metric == "rhs_tau025_pair_eligible_rate"] >= summary_df$baseline[summary_df$metric == "rhs_tau025_pair_eligible_rate"]) &&
    isTRUE(summary_df$candidate[summary_df$metric == "rhs_mcmc_fail_count"] <= summary_df$baseline[summary_df$metric == "rhs_mcmc_fail_count"]) &&
    isTRUE(summary_df$candidate[summary_df$metric == "ridge_pair_eligible_rate"] >= (summary_df$baseline[summary_df$metric == "ridge_pair_eligible_rate"] - 0.20))

  decision_mode <- if (isTRUE(representative_ok)) "representative" else "candidate_failures"
  decision_reason <- if (identical(decision_mode, "representative")) {
    "candidate broader rerun is strong enough to justify representative multichain confirmation"
  } else {
    "candidate broader rerun remains too weak on rhs, especially around persistent failure regimes"
  }

  .qdesn_validation_write_df(summary_df, file.path(output_root, "tables", "decision_metrics.csv"))
  .qdesn_validation_write_json(file.path(output_root, "manifest", "decision_manifest.json"), list(
    baseline_report_root = normalizePath(baseline_report_root, winslash = "/", mustWork = TRUE),
    candidate_report_root = normalizePath(candidate_report_root, winslash = "/", mustWork = TRUE),
    decision_mode = decision_mode,
    decision_reason = decision_reason,
    generated_at = as.character(Sys.time()),
    git_sha = .qdesn_validation_git_sha()
  ))
  .qdesn_validation_write_lines(file.path(output_root, "decision_summary.md"), c(
    "# RHS Repair Candidate Follow-up Decision",
    "",
    sprintf("- Decision mode: `%s`", decision_mode),
    sprintf("- Reason: %s", decision_reason),
    "",
    "## Metrics",
    "",
    .qdesn_validation_df_to_markdown(summary_df)
  ))

  list(
    output_root = normalizePath(output_root, winslash = "/", mustWork = FALSE),
    decision_mode = decision_mode,
    decision_reason = decision_reason,
    metrics = summary_df
  )
}
