#!/usr/bin/env Rscript

if (requireNamespace("compiler", quietly = TRUE)) invisible(compiler::enableJIT(0))

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    key <- sub("^--", "", key)
    value <- "true"
    if (ii < length(args) && !startsWith(args[[ii + 1L]], "--")) {
      value <- args[[ii + 1L]]
      ii <- ii + 1L
    }
    out[[key]] <- value
    ii <- ii + 1L
  }
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  x <- tolower(trimws(as.character(x)[1L]))
  if (x %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (x %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Cannot parse logical flag: %s", x), call. = FALSE)
}

split_cli_vec <- function(x) {
  if (is.null(x) || !nzchar(as.character(x)[1L])) return(NULL)
  trimws(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE), error = function(e) character(0))
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

source_config <- function(config_path) {
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  get("rqr_desn_article_congruent_simulation_config", envir = env)
}

sanitize_id <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  ifelse(nzchar(x), x, "na")
}

num_token <- function(x) {
  if (length(x) == 1L && is.na(x)) return("na")
  gsub("\\.", "p", format(as.numeric(x), trim = TRUE, scientific = FALSE))
}

stable_list_string <- function(x) {
  if (is.null(x)) return("NULL")
  if (!is.list(x)) return(paste(as.character(x), collapse = ","))
  nms <- names(x) %||% rep("", length(x))
  if (length(nms) && all(nzchar(nms))) {
    ord <- order(nms)
    x <- x[ord]
    nms <- nms[ord]
  }
  paste(vapply(seq_along(x), function(ii) {
    value <- stable_list_string(x[[ii]])
    if (nzchar(nms[[ii]])) paste0(nms[[ii]], "=", value) else value
  }, character(1)), collapse = ";")
}

hash_string <- function(x) {
  ints <- utf8ToInt(paste(enc2utf8(as.character(x)), collapse = "\n"))
  if (!length(ints)) return("0000000000000000")
  idx <- seq_along(ints)
  h1 <- sum(((ints + 1L) * ((idx %% 1009L) + 1L)) %% 2147483647L) %% 2147483647L
  h2 <- sum(((ints + 17L) * (((idx * 131L) %% 1009L) + 1L)) %% 2147483629L) %% 2147483629L
  sprintf("%08x%08x", as.integer(h1), as.integer(h2))
}

coverage_pair <- function(config, coverage_level) {
  c0 <- as.numeric(coverage_level)[1L]
  pairs <- config$scientific_contract$coverage_to_quantile_pair
  key <- if (abs(c0 - 0.80) < 1e-10) "c0p80" else if (abs(c0 - 0.90) < 1e-10) "c0p90" else NA_character_
  if (!is.na(key) && !is.null(pairs[[key]])) return(as.numeric(pairs[[key]]))
  c((1 - c0) / 2, 1 - (1 - c0) / 2)
}

enabled_stages <- function(config, include_direct_horizon = FALSE) {
  Filter(function(stage) {
    !isFALSE(stage$enabled_by_default %||% TRUE) || isTRUE(include_direct_horizon)
  }, config$stages)
}

build_scenario_id <- function(row) {
  paste(
    "rqr_article",
    sanitize_id(row$stage_id),
    sanitize_id(row$family_id),
    sprintf("rep%03d", as.integer(row$replicate_id)),
    sanitize_id(row$method_id),
    paste0("cov", num_token(row$coverage_level)),
    paste0("lr", num_token(row$learning_rate)),
    sep = "__"
  )
}

learning_rate_mode_for_method <- function(method) {
  mode <- tolower(as.character(method$learning_rate_mode %||% "fixed")[1L])
  mode <- switch(mode,
    learned = "learned_scale",
    scale = "learned_scale",
    learned_loss_scale = "learned_scale",
    pure = "learned_pure",
    mode
  )
  if (!mode %in% c("fixed", "learned_scale", "learned_pure")) {
    stop(sprintf("Unsupported learning_rate_mode for method %s: %s", method$method_id, mode), call. = FALSE)
  }
  mode
}

lambda_prior_for_method <- function(method, mode) {
  prior <- method$lambda_prior %||% list()
  if (!is.list(prior)) stop(sprintf("lambda_prior for method %s must be a list.", method$method_id), call. = FALSE)
  default_power <- if (identical(mode, "learned_scale")) 1 else 0
  shape <- as.numeric(prior$shape %||% prior$a %||% NA_real_)[1L]
  rate <- as.numeric(prior$rate %||% prior$b %||% NA_real_)[1L]
  power <- as.numeric(prior$power %||% prior$nu %||% default_power)[1L]
  if (identical(mode, "fixed")) {
    if (!is.finite(shape)) shape <- NA_real_
    if (!is.finite(rate)) rate <- NA_real_
    power <- 0
  } else {
    if (!is.finite(shape) || shape <= 0) stop(sprintf("lambda_prior$shape for method %s must be positive.", method$method_id), call. = FALSE)
    if (!is.finite(rate) || rate <= 0) stop(sprintf("lambda_prior$rate for method %s must be positive.", method$method_id), call. = FALSE)
    if (!is.finite(power) || power < 0) stop(sprintf("lambda_prior$power for method %s must be nonnegative.", method$method_id), call. = FALSE)
    if (identical(mode, "learned_pure")) power <- 0
  }
  list(shape = shape, rate = rate, power = power)
}

scenario_spec_string <- function(row) {
  keep <- c(
    "config_id", "stage_id", "family_id", "replicate_id", "method_id",
    "method_family", "implemented_adapter", "coverage_level", "learning_rate",
    "learning_rate_mode", "lambda_prior_shape", "lambda_prior_rate", "lambda_prior_power",
    "prior_type", "chain_count", "quantile_lower", "quantile_upper", "seed"
  )
  paste(paste0(keep, "=", vapply(row[keep], as.character, character(1))), collapse = "|")
}

expand_manifest <- function(config, config_path, repo_root, output_dir, include_direct_horizon = FALSE) {
  stages <- enabled_stages(config, include_direct_horizon = include_direct_horizon)
  git_commit <- git_value(repo_root, "rev-parse", "HEAD")
  git_branch <- git_value(repo_root, "branch", "--show-current")
  remote_branch <- git_value(repo_root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  config_hash <- unname(tools::md5sum(config_path))
  parts <- list()
  pp <- 0L
  for (stage_index in seq_along(stages)) {
    stage <- stages[[stage_index]]
    dgps <- stage$dgp_families %||% list()
    if (!length(dgps)) next
    for (family_index in seq_along(dgps)) {
      family <- dgps[[family_index]]
      for (method_index in seq_along(config$competitors)) {
        method <- config$competitors[[method_index]]
        learning_rate_mode <- learning_rate_mode_for_method(method)
        lambda_prior <- lambda_prior_for_method(method, learning_rate_mode)
        lrs <- method$learning_rates
        if (length(lrs) == 1L && is.na(lrs)) lrs <- NA_real_
        grid <- expand.grid(
          replicate_id = seq_len(as.integer(stage$replicates)),
          coverage_level = as.numeric(method$coverage_levels),
          learning_rate = lrs,
          KEEP.OUT.ATTRS = FALSE,
          stringsAsFactors = FALSE
        )
        pairs <- t(vapply(grid$coverage_level, function(cc) coverage_pair(config, cc), numeric(2)))
        pp <- pp + 1L
        parts[[pp]] <- data.frame(
          config_id = config$config_id,
          config_path = config_path,
          config_hash = config_hash,
          git_commit = git_commit,
          git_branch = git_branch,
          remote_branch = remote_branch,
          stage_id = stage$stage_id,
          stage_family = stage$stage_family,
          stage_index = stage_index,
          family_id = family$family_id,
          family_index = family_index,
          innovation_family = family$innovation_family,
          innovation_params = stable_list_string(family$params %||% list()),
          oracle_endpoints = isTRUE(stage$oracle_endpoints),
          replicate_id = grid$replicate_id,
          calibration_n = as.integer(stage$calibration_n),
          final_fit_n = as.integer(stage$final_fit_n),
          test_n = as.integer(stage$test_n),
          design_id = (stage$design %||% list())$design_id %||% "none",
          design_type = (stage$design %||% list())$design_type %||% "none",
          method_id = method$method_id,
          method_family = method$method_family,
          method_index = method_index,
          inference = method$inference,
          implemented_adapter = method$implemented_adapter,
          adapter_ready = !identical(method$implemented_adapter, "external_article_joint_qvp_required"),
          primary = isTRUE(method$primary),
          coverage_level = grid$coverage_level,
          quantile_lower = pairs[, 1L],
          quantile_upper = pairs[, 2L],
          learning_rate = grid$learning_rate,
          learning_rate_mode = learning_rate_mode,
          lambda_prior_shape = lambda_prior$shape,
          lambda_prior_rate = lambda_prior$rate,
          lambda_prior_power = lambda_prior$power,
          prior_type = method$prior_type,
          chain_count = as.integer(method$chain_count %||% 0L),
          calibration_tolerance = as.numeric(config$scientific_contract$calibration_qualification_tolerance),
          rqr_response_likelihood = FALSE,
          rqr_response_predictive_draws = FALSE,
          rqr_recursive_response_sampling = FALSE,
          qdesn_pair_scalar_density = FALSE,
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
      }
    }
  }
  df <- do.call(rbind, parts)
  ord <- do.call(order, df[c("stage_index", "family_index", "replicate_id", "method_index", "coverage_level", "learning_rate")])
  df <- df[ord, , drop = FALSE]
  df$scenario_index <- seq_len(nrow(df))
  df$seed <- 2026071800L + df$scenario_index
  lr_token <- ifelse(is.na(df$learning_rate), "na", gsub("\\.", "p", format(as.numeric(df$learning_rate), trim = TRUE, scientific = FALSE)))
  cov_token <- gsub("\\.", "p", format(as.numeric(df$coverage_level), trim = TRUE, scientific = FALSE))
  df$scenario_id <- paste(
    "rqr_article",
    sanitize_id(df$stage_id),
    sanitize_id(df$family_id),
    sprintf("rep%03d", as.integer(df$replicate_id)),
    sanitize_id(df$method_id),
    paste0("cov", cov_token),
    paste0("lr", lr_token),
    sep = "__"
  )
  df$scenario_spec_hash <- sprintf("spec_%08d_%s", df$scenario_index, vapply(df$scenario_id, hash_string, character(1)))
  df$scenario_output_dir <- file.path(output_dir, "scenario_outputs", df$scenario_id)
  df$metric_file <- file.path(df$scenario_output_dir, "interval_metrics.csv")
  df$status_file <- file.path(df$scenario_output_dir, "scenario_status.csv")
  rownames(df) <- NULL
  df
}

apply_filters <- function(df, cli) {
  filters <- list(
    stage_id = split_cli_vec(cli[["stage-id"]]),
    family_id = split_cli_vec(cli[["family-id"]]),
    method_id = split_cli_vec(cli[["method-id"]]),
    implemented_adapter = split_cli_vec(cli[["implemented-adapter"]])
  )
  for (nm in names(filters)) {
    allowed <- filters[[nm]]
    if (!is.null(allowed)) df <- df[df[[nm]] %in% allowed, , drop = FALSE]
  }
  rownames(df) <- NULL
  df
}

validate_manifest <- function(df) {
  if (!nrow(df)) stop("Scenario manifest is empty.", call. = FALSE)
  unique_checks <- c("scenario_id", "scenario_spec_hash", "seed", "scenario_output_dir")
  for (nm in unique_checks) {
    if (any(duplicated(df[[nm]]))) stop(sprintf("%s contains duplicates.", nm), call. = FALSE)
  }
  if (any(names(df) %in% c("target_p", "p0"))) stop("Forbidden target-p fields appear in manifest.", call. = FALSE)
  if (any(as.logical(df$rqr_response_likelihood))) stop("RQR response likelihood flag must be FALSE.", call. = FALSE)
  if (any(as.logical(df$rqr_response_predictive_draws))) stop("RQR response predictive draws must be FALSE.", call. = FALSE)
  if (any(as.logical(df$rqr_recursive_response_sampling))) stop("RQR recursive response sampling must be FALSE.", call. = FALSE)
  learned <- df$learning_rate_mode %in% c("learned_scale", "learned_pure")
  if (any(learned & (!is.finite(df$lambda_prior_shape) | df$lambda_prior_shape <= 0))) {
    stop("Learned-scale rows require positive lambda_prior_shape.", call. = FALSE)
  }
  if (any(learned & (!is.finite(df$lambda_prior_rate) | df$lambda_prior_rate <= 0))) {
    stop("Learned-scale rows require positive lambda_prior_rate.", call. = FALSE)
  }
  TRUE
}

empty_df <- function(cols) {
  as.data.frame(stats::setNames(replicate(length(cols), logical(0), simplify = FALSE), cols), stringsAsFactors = FALSE)
}

write_hashes <- function(output_dir) {
  files <- list.files(output_dir, full.names = TRUE, recursive = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[basename(files) != "output_hashes.csv"]
  write_csv(data.frame(file = basename(files), md5 = unname(tools::md5sum(files))), file.path(output_dir, "output_hashes.csv"))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
  repo_root <- normalizePath(if (nzchar(repo_root)) repo_root else getwd(), mustWork = TRUE)
  config_path <- normalizePath(cli[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_article_congruent_simulation_20260718.R"), mustWork = TRUE)
  config <- source_config(config_path)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  output_dir <- normalizePath(cli[["output-dir"]] %||% file.path(repo_root, config$output_contract$output_root, sprintf("manifest_%s_git_%s", stamp, short_sha)), mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  scenarios <- expand_manifest(
    config, config_path, repo_root, output_dir,
    include_direct_horizon = as_flag(cli[["include-direct-horizon"]], FALSE)
  )
  scenarios <- apply_filters(scenarios, cli)
  validate_manifest(scenarios)

  split_contract <- data.frame(key = names(config$split_contract), value = vapply(config$split_contract, stable_list_string, character(1)))
  methods <- do.call(rbind, lapply(config$competitors, function(x) data.frame(
    method_id = x$method_id,
    method_family = x$method_family,
    inference = x$inference,
    implemented_adapter = x$implemented_adapter,
    primary = isTRUE(x$primary),
    coverage_levels = stable_list_string(x$coverage_levels),
    learning_rates = stable_list_string(x$learning_rates),
    learning_rate_mode = learning_rate_mode_for_method(x),
    lambda_prior = stable_list_string(x$lambda_prior %||% list()),
    prior_type = x$prior_type,
    chain_count = as.integer(x$chain_count %||% 0L),
    adapter_note = x$adapter_note %||% NA_character_,
    stringsAsFactors = FALSE
  )))
  dgps <- unique(scenarios[, c("stage_id", "stage_family", "family_id", "innovation_family", "innovation_params", "calibration_n", "final_fit_n", "test_n", "oracle_endpoints", "design_id", "design_type"), drop = FALSE])
  summary <- stats::aggregate(list(scenario_rows = rep(1L, nrow(scenarios))), by = scenarios[c("stage_id", "method_id", "implemented_adapter")], FUN = sum)
  manifest <- data.frame(
    key = c(
      "artifact_kind", "config_id", "config_status", "repo_root", "config_path",
      "output_dir", "git_commit", "git_branch", "total_scenario_rows",
      "adapter_ready_rows", "external_adapter_rows", "article_update_allowed",
      "production_launch_requires", "rqr_loss_reference_scale", "created_at"
    ),
    value = c(
      "rqr_desn_article_congruent_manifest",
      config$config_id,
      config$status,
      repo_root,
      config_path,
      output_dir,
      git_value(repo_root, "rev-parse", "HEAD"),
      git_value(repo_root, "branch", "--show-current"),
      as.character(nrow(scenarios)),
      as.character(sum(as.logical(scenarios$adapter_ready))),
      as.character(sum(!as.logical(scenarios$adapter_ready))),
      as.character(config$article_update_allowed),
      config$production_launch_requires,
      stable_list_string((config$analysis_scale %||% list())$rqr_loss_reference_scale %||% "raw"),
      format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )
  )

  write_csv(manifest, file.path(output_dir, "manifest.csv"))
  write_csv(scenarios, file.path(output_dir, "scenario_manifest.csv"))
  write_csv(summary, file.path(output_dir, "scenario_manifest_summary.csv"))
  write_csv(dgps, file.path(output_dir, "dgp_manifest.csv"))
  write_csv(methods, file.path(output_dir, "method_manifest.csv"))
  write_csv(split_contract, file.path(output_dir, "split_contract.csv"))
  write_csv(empty_df(c("scenario_id", "interval_score_mean", "empirical_coverage", "coverage_error", "mean_width")), file.path(output_dir, "interval_metrics.csv"))
  write_csv(empty_df(c("scenario_id", "baseline_scenario_id", "interval_score_delta", "width_ratio")), file.path(output_dir, "replicate_pairwise_deltas.csv"))
  write_csv(empty_df(c("scenario_id", "chain_id", "n_draws", "diagnostic_status")), file.path(output_dir, "mcmc_diagnostics.csv"))
  write_csv(empty_df(c("scenario_id", "failure_stage", "failure_class", "failure_message")), file.path(output_dir, "failure_log.csv"))
  write_csv(empty_df(c("scenario_id", "status", "runtime_sec")), file.path(output_dir, "run_status.csv"))
  write_csv(data.frame(gate = c("manifest_unique_ids", "no_rqr_response_predictive_draws", "external_joint_adapter_declared"), status = c("pass", "pass", if (any(!scenarios$adapter_ready)) "review" else "pass")), file.path(output_dir, "readiness_gates.csv"))
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))
  writeLines(c("$ git status --short --branch", git_value(repo_root, "status", "--short", "--branch"), "", "$ git log --oneline -5", git_value(repo_root, "log", "--oneline", "-5")), file.path(output_dir, "git_state.txt"))
  writeLines(c(
    "# RQR-DESN Article-Congruent Simulation Manifest",
    "",
    "This artifact materializes the denominator for the article-congruent RQR-DESN interval study.",
    "It does not fit models, does not authorize article updates, and records the joint-QDESN row as an external adapter contract.",
    "",
    sprintf("- scenario rows: `%d`", nrow(scenarios)),
    sprintf("- adapter-ready rows: `%d`", sum(as.logical(scenarios$adapter_ready))),
    sprintf("- external-adapter rows: `%d`", sum(!as.logical(scenarios$adapter_ready))),
    sprintf("- production launch guard: `%s`", config$production_launch_requires)
  ), file.path(output_dir, "README.md"))
  writeLines(c(
    "# RQR-DESN Article-Congruent Manifest Closeout",
    "",
    "Status: manifest preflight completed.",
    "",
    "The next safe step is a smoke run over adapter-ready rows. Full MCMC production requires the explicit `--confirm-full-launch true` guard."
  ), file.path(output_dir, "closeout.md"))
  write_hashes(output_dir)
  message(sprintf("RQR-DESN article-congruent manifest wrote %d rows to %s", nrow(scenarios), output_dir))
  invisible(output_dir)
}

if (sys.nframe() == 0L) main()
