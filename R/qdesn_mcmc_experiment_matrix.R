.qdesn_rhs_exp_matrix_or <- function(a, b) {
  if (is.null(a)) b else a
}

.qdesn_rhs_exp_matrix_resolve_path <- function(path, base_dir = ".", must_work = TRUE) {
  if (is.null(path)) return(NULL)
  path_chr <- trimws(as.character(path)[1L])
  if (!nzchar(path_chr)) return(NULL)
  raw <- path_chr
  if (!grepl("^(/|~)", raw)) {
    raw <- file.path(base_dir, raw)
  }
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

.qdesn_rhs_exp_matrix_deep_merge <- function(base, patch) {
  if (is.null(patch)) return(base)
  if (is.null(base)) return(patch)
  if (!is.list(base) || !is.list(patch)) return(patch)
  out <- base
  p_names <- names(patch)
  if (is.null(p_names)) return(patch)
  for (nm in p_names) {
    if (is.null(nm) || !nzchar(nm)) next
    p_val <- patch[[nm]]
    b_val <- out[[nm]]
    if (is.list(b_val) && is.list(p_val)) {
      out[[nm]] <- .qdesn_rhs_exp_matrix_deep_merge(b_val, p_val)
    } else {
      out[[nm]] <- p_val
    }
  }
  out
}

.qdesn_rhs_exp_matrix_bind_rows <- function(rows) {
  rows <- Filter(function(x) is.data.frame(x) && nrow(x), rows)
  if (!length(rows)) return(data.frame(stringsAsFactors = FALSE))
  out <- rows[[1L]]
  if (length(rows) == 1L) return(out)
  for (ii in 2:length(rows)) {
    out <- rbind(out, rows[[ii]])
  }
  rownames(out) <- NULL
  out
}

.qdesn_rhs_exp_matrix_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.qdesn_rhs_exp_matrix_parse_time <- function(x) {
  if (is.null(x) || !length(x)) return(as.POSIXct(NA))
  x_chr <- as.character(x)[1L]
  if (!nzchar(trimws(x_chr))) return(as.POSIXct(NA))
  y <- as.POSIXct(x_chr, tz = "UTC")
  if (!is.finite(as.numeric(y))) y <- as.POSIXct(x_chr)
  y
}

.qdesn_rhs_exp_matrix_load <- function(path = file.path("config", "validation", "qdesn_mcmc_rhs_exp_matrix", "matrix.yaml")) {
  .qdesn_validation_require_namespace("yaml")
  matrix_path <- .qdesn_rhs_exp_matrix_resolve_path(path, must_work = TRUE)
  cfg <- yaml::read_yaml(matrix_path)
  if (!is.list(cfg)) stop("Experiment matrix YAML must decode to a list.", call. = FALSE)
  matrix_cfg <- cfg$matrix
  phases_cfg <- cfg$phases
  if (!is.list(matrix_cfg) || !length(matrix_cfg)) {
    stop("Experiment matrix YAML is missing top-level `matrix` configuration.", call. = FALSE)
  }
  if (!is.list(phases_cfg) || !length(phases_cfg)) {
    stop("Experiment matrix YAML is missing top-level `phases` configuration.", call. = FALSE)
  }

  base_dir <- dirname(matrix_path)
  matrix_cfg$name <- as.character(.qdesn_rhs_exp_matrix_or(matrix_cfg$name, "qdesn_rhs_exp_matrix"))[1L]
  matrix_cfg$base_defaults <- .qdesn_rhs_exp_matrix_resolve_path(matrix_cfg$base_defaults, base_dir = base_dir, must_work = TRUE)
  matrix_cfg$grid <- .qdesn_rhs_exp_matrix_resolve_path(matrix_cfg$grid, base_dir = base_dir, must_work = TRUE)
  matrix_cfg$n_chains <- max(2L, as.integer(.qdesn_rhs_exp_matrix_or(matrix_cfg$n_chains, 4L))[1L])
  matrix_cfg$chain_seed_base <- as.integer(.qdesn_rhs_exp_matrix_or(matrix_cfg$chain_seed_base, 500000L))[1L]

  sel_cfg <- .qdesn_rhs_exp_matrix_or(matrix_cfg$selection, list())
  matrix_cfg$selection <- list(
    phase_keep_top = max(1L, as.integer(.qdesn_rhs_exp_matrix_or(sel_cfg$phase_keep_top, 2L))[1L])
  )

  phases <- lapply(seq_along(phases_cfg), function(ii) {
    ph <- phases_cfg[[ii]]
    if (!is.list(ph)) stop(sprintf("Phase %d must be a mapping.", ii), call. = FALSE)
    phase_id <- as.character(.qdesn_rhs_exp_matrix_or(ph$id, sprintf("phase%d", ii)))[1L]
    if (!nzchar(phase_id)) stop(sprintf("Phase %d has an empty id.", ii), call. = FALSE)
    experiments <- .qdesn_rhs_exp_matrix_or(ph$experiments, list())
    if (!is.list(experiments) || !length(experiments)) {
      stop(sprintf("Phase `%s` must include at least one experiment.", phase_id), call. = FALSE)
    }
    exps <- lapply(seq_along(experiments), function(jj) {
      ex <- experiments[[jj]]
      if (!is.list(ex)) stop(sprintf("Phase `%s` experiment %d must be a mapping.", phase_id, jj), call. = FALSE)
      ex_id <- as.character(.qdesn_rhs_exp_matrix_or(ex$id, sprintf("%s_exp_%02d", phase_id, jj)))[1L]
      if (!nzchar(ex_id)) stop(sprintf("Phase `%s` experiment %d has an empty id.", phase_id, jj), call. = FALSE)
      patch_path <- .qdesn_rhs_exp_matrix_resolve_path(ex$patch, base_dir = base_dir, must_work = TRUE)
      list(
        id = ex_id,
        label = as.character(.qdesn_rhs_exp_matrix_or(ex$label, ex_id))[1L],
        description = as.character(.qdesn_rhs_exp_matrix_or(ex$description, ""))[1L],
        patch_path = patch_path,
        run_overrides = .qdesn_rhs_exp_matrix_or(ex$run_overrides, list())
      )
    })
    list(
      id = phase_id,
      description = as.character(.qdesn_rhs_exp_matrix_or(ph$description, ""))[1L],
      base_from_phase = as.character(.qdesn_rhs_exp_matrix_or(ph$base_from_phase, ""))[1L],
      trigger = .qdesn_rhs_exp_matrix_or(ph$trigger, NULL),
      experiments = exps
    )
  })

  exp_ids <- unlist(lapply(phases, function(ph) vapply(ph$experiments, function(ex) ex$id, character(1))))
  dup_exp <- unique(exp_ids[duplicated(exp_ids)])
  if (length(dup_exp)) {
    stop(sprintf("Experiment ids must be unique. Duplicates: %s", paste(dup_exp, collapse = ", ")), call. = FALSE)
  }
  phase_ids <- vapply(phases, function(ph) ph$id, character(1))
  dup_phase <- unique(phase_ids[duplicated(phase_ids)])
  if (length(dup_phase)) {
    stop(sprintf("Phase ids must be unique. Duplicates: %s", paste(dup_phase, collapse = ", ")), call. = FALSE)
  }

  for (ph in phases) {
    src <- trimws(as.character(.qdesn_rhs_exp_matrix_or(ph$base_from_phase, ""))[1L])
    if (!nzchar(src)) next
    if (!src %in% phase_ids) {
      stop(sprintf("Phase `%s` references unknown base_from_phase `%s`.", ph$id, src), call. = FALSE)
    }
  }

  list(
    matrix_path = matrix_path,
    base_dir = base_dir,
    matrix = matrix_cfg,
    phases = phases
  )
}

.qdesn_rhs_exp_matrix_read_patch <- function(path) {
  .qdesn_validation_require_namespace("yaml")
  patch_path <- .qdesn_rhs_exp_matrix_resolve_path(path, must_work = TRUE)
  doc <- yaml::read_yaml(patch_path)
  if (!is.list(doc)) stop(sprintf("Patch YAML must decode to a list: %s", patch_path), call. = FALSE)
  ex_info <- .qdesn_rhs_exp_matrix_or(doc$experiment, list())
  patch <- .qdesn_rhs_exp_matrix_or(doc$patch, list())
  run_overrides <- .qdesn_rhs_exp_matrix_or(doc$run_overrides, list())
  list(
    patch_path = patch_path,
    experiment_id = as.character(.qdesn_rhs_exp_matrix_or(ex_info$id, ""))[1L],
    description = as.character(.qdesn_rhs_exp_matrix_or(ex_info$description, ""))[1L],
    patch = patch,
    run_overrides = run_overrides
  )
}

.qdesn_rhs_exp_matrix_collect_health <- function(report_root) {
  report_dir <- .qdesn_rhs_exp_matrix_resolve_path(report_root, must_work = FALSE)
  if (is.null(report_dir)) {
    stop("report_root cannot be empty.", call. = FALSE)
  }
  root_df <- .qdesn_rhs_exp_matrix_read_csv(file.path(report_dir, "tables", "campaign_root_confirmation.csv"))
  chain_df <- .qdesn_rhs_exp_matrix_read_csv(file.path(report_dir, "tables", "campaign_chain_signoff.csv"))
  rhat_df <- .qdesn_rhs_exp_matrix_read_csv(file.path(report_dir, "tables", "campaign_multichain_rhat.csv"))
  started <- .qdesn_validation_read_json_if_exists(file.path(report_dir, "manifest", "campaign_started.json"))
  completed <- .qdesn_validation_read_json_if_exists(file.path(report_dir, "manifest", "campaign_completed.json"))
  started_at <- .qdesn_rhs_exp_matrix_parse_time(if (is.null(started)) NA_character_ else started$started_at)
  finished_at <- .qdesn_rhs_exp_matrix_parse_time(if (is.null(completed)) NA_character_ else completed$finished_at)

  safe_num <- function(x, fn = max, default = NA_real_) {
    x <- suppressWarnings(as.numeric(x))
    x <- x[is.finite(x)]
    if (!length(x)) return(default)
    fn(x)
  }
  safe_rate <- function(x) {
    if (!length(x)) return(NA_real_)
    if (is.logical(x)) return(mean(x, na.rm = TRUE))
    x_chr <- toupper(trimws(as.character(x)))
    z <- rep(NA, length(x_chr))
    z[x_chr %in% c("TRUE", "T", "1", "YES")] <- TRUE
    z[x_chr %in% c("FALSE", "F", "0", "NO")] <- FALSE
    mean(z, na.rm = TRUE)
  }
  contains_reason <- function(reason_vec, pattern) {
    if (!length(reason_vec)) return(logical(0))
    grepl(pattern, as.character(reason_vec), fixed = TRUE)
  }

  n_root_fail <- if (nrow(root_df)) sum(as.character(root_df$confirmation_grade) == "FAIL", na.rm = TRUE) else NA_integer_
  n_root_warn <- if (nrow(root_df)) sum(as.character(root_df$confirmation_grade) == "WARN", na.rm = TRUE) else NA_integer_
  n_root_pass <- if (nrow(root_df)) sum(as.character(root_df$confirmation_grade) == "PASS", na.rm = TRUE) else NA_integer_
  n_chain_fail <- if (nrow(chain_df)) sum(as.character(chain_df$signoff_grade) == "FAIL", na.rm = TRUE) else NA_integer_
  n_chain_warn <- if (nrow(chain_df)) sum(as.character(chain_df$signoff_grade) == "WARN", na.rm = TRUE) else NA_integer_
  n_chain_pass <- if (nrow(chain_df)) sum(as.character(chain_df$signoff_grade) == "PASS", na.rm = TRUE) else NA_integer_
  n_missing_diag <- if (nrow(chain_df)) sum(contains_reason(chain_df$signoff_reason, "missing_chain_diagnostics"), na.rm = TRUE) else NA_integer_
  n_pipeline_fail <- if (nrow(chain_df)) sum(contains_reason(chain_df$signoff_reason, "pipeline"), na.rm = TRUE) else NA_integer_
  wall_minutes <- if (is.finite(as.numeric(started_at)) && is.finite(as.numeric(finished_at))) {
    as.numeric(difftime(finished_at, started_at, units = "mins"))
  } else {
    NA_real_
  }

  rhs_mask <- rep(FALSE, nrow(rhat_df))
  core_mask <- rep(FALSE, nrow(rhat_df))
  if (nrow(rhat_df) && "parameter" %in% names(rhat_df)) {
    param_chr <- as.character(rhat_df$parameter)
    rhs_mask <- param_chr %in% c("rhs_tau", "rhs_c2", "rhs_lambda_mean")
    core_mask <- param_chr %in% c("gamma", "sigma", "beta_norm")
  }

  status <- if (!is.null(completed)) {
    "COMPLETED"
  } else if (!is.null(started)) {
    "RUNNING_OR_INCOMPLETE"
  } else {
    "MISSING"
  }

  data.frame(
    status = status,
    n_roots = if (nrow(root_df)) nrow(root_df) else NA_integer_,
    n_root_fail = n_root_fail,
    n_root_warn = n_root_warn,
    n_root_pass = n_root_pass,
    n_chains = if (nrow(chain_df)) nrow(chain_df) else NA_integer_,
    n_chain_fail = n_chain_fail,
    n_chain_warn = n_chain_warn,
    n_chain_pass = n_chain_pass,
    n_missing_diag = n_missing_diag,
    n_pipeline_fail = n_pipeline_fail,
    max_split_rhat = safe_num(root_df$max_split_rhat, fn = max),
    max_rhs_rhat = if (is.logical(rhs_mask) && any(rhs_mask)) safe_num(rhat_df$rhat[rhs_mask], fn = max) else NA_real_,
    max_core_rhat = if (is.logical(core_mask) && any(core_mask)) safe_num(rhat_df$rhat[core_mask], fn = max) else NA_real_,
    min_ess_rhs = safe_num(chain_df$mcmc_min_ess_rhs, fn = min),
    median_ess_rhs = safe_num(chain_df$mcmc_min_ess_rhs, fn = stats::median),
    max_acf1_rhs = safe_num(chain_df$mcmc_max_acf1_rhs, fn = max),
    max_geweke_rhs = safe_num(chain_df$mcmc_max_geweke_absz_rhs, fn = max),
    max_half_drift_rhs = safe_num(chain_df$mcmc_max_half_drift_rhs, fn = max),
    comparison_eligible_rate = safe_rate(chain_df$comparison_eligible),
    started_at = if (is.finite(as.numeric(started_at))) as.character(started_at) else NA_character_,
    finished_at = if (is.finite(as.numeric(finished_at))) as.character(finished_at) else NA_character_,
    wall_minutes = wall_minutes,
    report_root = report_dir,
    stringsAsFactors = FALSE
  )
}

.qdesn_rhs_exp_matrix_rank <- function(df, top_n = 2L) {
  if (!is.data.frame(df) || !nrow(df)) return(data.frame(stringsAsFactors = FALSE))
  req <- c("experiment_id", "status", "n_missing_diag", "n_pipeline_fail", "n_chain_fail", "n_root_fail", "max_split_rhat", "min_ess_rhs", "wall_minutes")
  miss <- setdiff(req, names(df))
  if (length(miss)) {
    stop(sprintf("Cannot rank experiments; missing columns: %s", paste(miss, collapse = ", ")), call. = FALSE)
  }
  top_n <- max(1L, as.integer(top_n)[1L])
  out <- df
  as_key <- function(x, default) {
    x_num <- suppressWarnings(as.numeric(x))
    x_num[!is.finite(x_num)] <- default
    x_num
  }
  status_key <- ifelse(as.character(out$status) == "COMPLETED", 0, 1)
  n_missing_key <- as_key(out$n_missing_diag, 1e9)
  n_pipeline_key <- as_key(out$n_pipeline_fail, 1e9)
  n_chain_fail_key <- as_key(out$n_chain_fail, 1e9)
  n_root_fail_key <- as_key(out$n_root_fail, 1e9)
  rhat_key <- as_key(out$max_split_rhat, 1e9)
  ess_key <- suppressWarnings(as.numeric(out$min_ess_rhs))
  ess_key[!is.finite(ess_key)] <- -1e9
  ess_key <- -ess_key
  wall_key <- as_key(out$wall_minutes, 1e9)
  ord <- order(
    status_key,
    n_missing_key,
    n_pipeline_key,
    n_chain_fail_key,
    n_root_fail_key,
    rhat_key,
    ess_key,
    wall_key,
    as.character(out$experiment_id)
  )
  out <- out[ord, , drop = FALSE]
  out$rank <- seq_len(nrow(out))
  out$is_topk <- out$rank <= top_n
  rownames(out) <- NULL
  out
}

.qdesn_rhs_exp_matrix_evaluate_trigger <- function(trigger, summary_df) {
  if (is.null(trigger)) {
    return(list(run_phase = TRUE, reason = "no_trigger", metric_value = NA_real_))
  }
  source_experiment <- as.character(.qdesn_rhs_exp_matrix_or(trigger$source_experiment, ""))[1L]
  metric <- as.character(.qdesn_rhs_exp_matrix_or(trigger$metric, ""))[1L]
  op <- as.character(.qdesn_rhs_exp_matrix_or(trigger$op, ">"))[1L]
  threshold <- as.numeric(.qdesn_rhs_exp_matrix_or(trigger$threshold, NA_real_))[1L]
  if (!nzchar(source_experiment) || !nzchar(metric) || !is.finite(threshold)) {
    stop("Invalid phase trigger; require source_experiment, metric, and finite threshold.", call. = FALSE)
  }
  if (!metric %in% names(summary_df)) {
    return(list(
      run_phase = FALSE,
      reason = sprintf("trigger_metric_missing:%s", metric),
      metric_value = NA_real_
    ))
  }
  src_df <- subset(summary_df, experiment_id == source_experiment)
  if (!nrow(src_df)) {
    return(list(
      run_phase = FALSE,
      reason = sprintf("trigger_source_missing:%s", source_experiment),
      metric_value = NA_real_
    ))
  }
  metric_value <- suppressWarnings(as.numeric(src_df[[metric]][1L]))
  if (!is.finite(metric_value)) {
    return(list(
      run_phase = FALSE,
      reason = sprintf("trigger_metric_non_finite:%s", metric),
      metric_value = metric_value
    ))
  }
  run_phase <- switch(
    op,
    ">" = metric_value > threshold,
    ">=" = metric_value >= threshold,
    "<" = metric_value < threshold,
    "<=" = metric_value <= threshold,
    "==" = isTRUE(all.equal(metric_value, threshold)),
    "!=" = !isTRUE(all.equal(metric_value, threshold)),
    stop(sprintf("Unsupported trigger operator `%s`.", op), call. = FALSE)
  )
  list(
    run_phase = isTRUE(run_phase),
    reason = sprintf(
      "trigger_%s_%s_threshold(metric=%s,value=%.6f,threshold=%.6f)",
      if (isTRUE(run_phase)) "passed" else "blocked",
      op,
      metric,
      metric_value,
      threshold
    ),
    metric_value = metric_value
  )
}
