#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_cli <- function(args) {
  out <- list()
  ii <- 1L
  while (ii <= length(args)) {
    key <- args[[ii]]
    if (!startsWith(key, "--")) {
      stop(sprintf("Unexpected positional argument: %s", key), call. = FALSE)
    }
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

split_cli_vec <- function(x) {
  if (is.null(x) || !nzchar(x)) return(NULL)
  trimws(strsplit(as.character(x)[1L], ",", fixed = TRUE)[[1L]])
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

is_na_scalar <- function(x) {
  length(x) == 1L && is.na(x)
}

as_manifest_vec <- function(x) {
  if (is_na_scalar(x)) return(NA)
  x
}

scalar_string <- function(x) {
  if (is.null(x) || length(x) == 0L) return("NULL")
  if (is_na_scalar(x)) return("NA")
  paste(as.character(x), collapse = ",")
}

stable_list_string <- function(x) {
  if (is.null(x)) return("NULL")
  if (!is.list(x)) return(scalar_string(x))
  nms <- names(x) %||% rep("", length(x))
  if (length(nms) && all(nzchar(nms))) {
    ord <- order(nms)
    nms <- nms[ord]
    x <- x[ord]
  }
  paste(
    vapply(seq_along(x), function(ii) {
      nm <- nms[[ii]]
      value <- stable_list_string(x[[ii]])
      if (nzchar(nm)) paste0(nm, "=", value) else value
    }, character(1)),
    collapse = ";"
  )
}

hash_string <- function(x) {
  if (requireNamespace("digest", quietly = TRUE)) {
    return(digest::digest(enc2utf8(as.character(x)), algo = "md5", serialize = FALSE))
  }
  ints <- utf8ToInt(paste(enc2utf8(as.character(x)), collapse = "\n"))
  if (!length(ints)) return("0000000000000000")
  idx <- seq_along(ints)
  mod1 <- 2147483647
  mod2 <- 2147483629
  h1 <- sum(((ints + 1) * ((idx %% 1009) + 1)) %% mod1) %% mod1
  h2 <- sum(((ints + 17) * (((idx * 131) %% 1009) + 1)) %% mod2) %% mod2
  sprintf("%08x%08x", as.integer(h1), as.integer(h2))
}

sanitize_id <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  ifelse(nzchar(x), x, "na")
}

num_token <- function(x) {
  if (is_na_scalar(x)) return("na")
  gsub("\\.", "p", format(as.numeric(x), trim = TRUE, scientific = FALSE))
}

source_config <- function(config_path) {
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  get("rqr_desn_broad_simulation_config", envir = env)
}

select_designs <- function(stage, backend) {
  design_ids <- backend$design_ids %||% "none"
  if (identical(design_ids, "none")) {
    return(list(list(
      design_id = "none",
      design_type = "none",
      DESN_D = NA_integer_,
      DESN_n = NA_integer_,
      DESN_m = NA_integer_,
      washout = NA_integer_
    )))
  }
  stage_design_ids <- vapply(stage$designs, function(x) x$design_id, character(1))
  if (identical(design_ids, "all")) {
    return(stage$designs)
  }
  missing <- setdiff(as.character(design_ids), stage_design_ids)
  if (length(missing)) {
    stop(sprintf(
      "Backend %s references unknown design(s): %s",
      backend$backend_id,
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }
  stage$designs[match(as.character(design_ids), stage_design_ids)]
}

prior_hyperparameters <- function(config, prior_type) {
  if (identical(prior_type, "none")) return("none")
  prior <- config$priors[[prior_type]]
  if (is.null(prior)) stop(sprintf("Unknown prior type: %s", prior_type), call. = FALSE)
  stable_list_string(prior)
}

scenario_spec_string <- function(row) {
  keep <- c(
    "config_id", "stage_id", "stage_index", "family_id", "family_index",
    "replicate_id", "design_id", "design_index", "backend_id", "backend_index",
    "inference", "prior_type", "prior_index", "coverage_level",
    "coverage_index", "learning_rate", "learning_rate_index", "seed"
  )
  paste(paste0(keep, "=", vapply(row[keep], scalar_string, character(1))), collapse = "|")
}

build_scenario_id <- function(row) {
  paste(
    "rqr_broad",
    sanitize_id(row$stage_id),
    sanitize_id(row$family_id),
    sprintf("rep%03d", as.integer(row$replicate_id)),
    sanitize_id(row$design_id),
    sanitize_id(row$backend_id),
    sanitize_id(row$prior_type),
    paste0("cov", num_token(row$coverage_level)),
    paste0("lr", num_token(row$learning_rate)),
    sep = "__"
  )
}

expand_rqr_desn_broad_config <- function(config, config_path, repo_root, output_dir) {
  config_hash <- unname(tools::md5sum(config_path))
  git_commit <- git_value(repo_root, "rev-parse", "HEAD")
  branch <- git_value(repo_root, "branch", "--show-current")
  remote_branch <- git_value(repo_root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  if (!nzchar(remote_branch) || grepl("fatal:", remote_branch, fixed = TRUE)) remote_branch <- NA_character_
  package_library <- paste(.libPaths(), collapse = ";")
  r_binary <- file.path(R.home("bin"), "R")

  rows <- list()
  kk <- 0L
  for (stage_index in seq_along(config$stages)) {
    stage <- config$stages[[stage_index]]
    for (family_index in seq_along(stage$dgp_families)) {
      family <- stage$dgp_families[[family_index]]
      for (replicate_id in seq_len(as.integer(stage$replicates))) {
        for (backend_index in seq_along(stage$backends)) {
          backend <- stage$backends[[backend_index]]
          designs <- select_designs(stage, backend)
          priors <- as_manifest_vec(backend$priors)
          coverage_levels <- as_manifest_vec(backend$coverage_levels)
          learning_rates <- as_manifest_vec(backend$learning_rates)
          for (design_index in seq_along(designs)) {
            design <- designs[[design_index]]
            for (prior_index in seq_along(priors)) {
              prior_type <- as.character(priors[[prior_index]])
              for (coverage_index in seq_along(coverage_levels)) {
                coverage_level <- coverage_levels[[coverage_index]]
                for (learning_rate_index in seq_along(learning_rates)) {
                  learning_rate <- learning_rates[[learning_rate_index]]
                  kk <- kk + 1L
                  seed <- as.integer(config$randomization$seed_base) + kk
                  row <- list(
                    config_id = config$config_id,
                    config_path = config_path,
                    config_hash = config_hash,
                    implementation_commit = git_commit,
                    branch = branch,
                    remote_branch = remote_branch,
                    R_binary = r_binary,
                    package_library = package_library,
                    stage_id = stage$stage_id,
                    stage_index = stage_index,
                    family_id = family$family_id,
                    scenario_family = family$family_id,
                    family_index = family_index,
                    replicate_id = replicate_id,
                    design_id = design$design_id,
                    design_index = design_index,
                    design_type = design$design_type,
                    DESN_D = design$DESN_D %||% NA_integer_,
                    DESN_n = design$DESN_n %||% NA_integer_,
                    DESN_m = design$DESN_m %||% NA_integer_,
                    washout = design$washout %||% NA_integer_,
                    backend_id = backend$backend_id,
                    backend_index = backend_index,
                    backend = backend$backend_id,
                    inference = backend$inference,
                    primary_backend = isTRUE(backend$primary),
                    prior_type = prior_type,
                    prior_index = prior_index,
                    prior_hyperparameters = prior_hyperparameters(config, prior_type),
                    coverage_level = coverage_level,
                    coverage_index = coverage_index,
                    learning_rate = learning_rate,
                    learning_rate_index = learning_rate_index,
                    scenario_index = kk,
                    seed = seed,
                    mcmc_control = stable_list_string(config$mcmc_control),
                    vb_control = stable_list_string(config$vb_control),
                    status = "pending",
                    response_likelihood = FALSE,
                    response_predictive_draws = FALSE,
                    recursive_response_sampling = FALSE
                  )
                  row$scenario_id <- build_scenario_id(row)
                  row$scenario_spec_hash <- hash_string(scenario_spec_string(row))
                  row$scenario_output_dir <- file.path(output_dir, "scenario_outputs", row$scenario_id)
                  row$metric_file <- file.path(row$scenario_output_dir, "interval_metrics.csv")
                  row$fit_summary_file <- file.path(row$scenario_output_dir, "fit_summary.csv")
                  row$mcmc_diagnostics_file <- file.path(row$scenario_output_dir, "mcmc_diagnostics.csv")
                  row$vb_diagnostics_file <- file.path(row$scenario_output_dir, "vb_diagnostics.csv")
                  row$failure_file <- file.path(row$scenario_output_dir, "failure_log.csv")
                  row$output_file <- row$metric_file
                  row$output_hash <- NA_character_
                  rows[[kk]] <- row
                }
              }
            }
          }
        }
      }
    }
  }
  df <- do.call(rbind, lapply(rows, function(x) {
    data.frame(as.list(x), stringsAsFactors = FALSE, check.names = FALSE)
  }))

  order_cols <- config$randomization$scenario_order %||% c(
    "stage_index", "family_index", "replicate_id", "design_index",
    "backend_index", "prior_index", "coverage_index", "learning_rate_index"
  )
  ord <- do.call(order, df[order_cols])
  df <- df[ord, , drop = FALSE]
  df$scenario_index <- seq_len(nrow(df))
  df$seed <- as.integer(config$randomization$seed_base) + df$scenario_index
  df$scenario_id <- vapply(seq_len(nrow(df)), function(ii) build_scenario_id(df[ii, , drop = FALSE]), character(1))
  df$scenario_spec_hash <- vapply(seq_len(nrow(df)), function(ii) {
    hash_string(scenario_spec_string(df[ii, , drop = FALSE]))
  }, character(1))
  df$scenario_output_dir <- file.path(output_dir, "scenario_outputs", df$scenario_id)
  df$metric_file <- file.path(df$scenario_output_dir, "interval_metrics.csv")
  df$fit_summary_file <- file.path(df$scenario_output_dir, "fit_summary.csv")
  df$mcmc_diagnostics_file <- file.path(df$scenario_output_dir, "mcmc_diagnostics.csv")
  df$vb_diagnostics_file <- file.path(df$scenario_output_dir, "vb_diagnostics.csv")
  df$failure_file <- file.path(df$scenario_output_dir, "failure_log.csv")
  df$output_file <- df$metric_file
  rownames(df) <- NULL
  df
}

build_dgp_manifest <- function(config) {
  rows <- list()
  kk <- 0L
  for (stage in config$stages) {
    for (family in stage$dgp_families) {
      kk <- kk + 1L
      note <- if (isTRUE(family$oracle_endpoints)) {
        paste("Oracle central interval endpoints available for", family$noise)
      } else {
        "No oracle endpoint contract in frozen config; endpoint_mae should remain NA"
      }
      rows[[kk]] <- data.frame(
        stage_id = stage$stage_id,
        family_id = family$family_id,
        noise = family$noise %||% NA_character_,
        n_train = as.integer(stage$n_train),
        n_test = as.integer(stage$n_test),
        replicates = as.integer(stage$replicates),
        oracle_endpoints = isTRUE(family$oracle_endpoints),
        dgp_parameter_json = stable_list_string(family),
        oracle_formula_note = note,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

build_design_manifest <- function(config) {
  rows <- list()
  kk <- 0L
  for (stage in config$stages) {
    for (design in stage$designs) {
      kk <- kk + 1L
      rows[[kk]] <- data.frame(
        stage_id = stage$stage_id,
        design_id = design$design_id,
        design_type = design$design_type,
        DESN_D = design$DESN_D %||% NA_integer_,
        DESN_n = design$DESN_n %||% NA_integer_,
        DESN_m = design$DESN_m %||% NA_integer_,
        alpha = design$alpha %||% NA_real_,
        rho = design$rho %||% NA_real_,
        act_f = design$act_f %||% NA_character_,
        act_k = design$act_k %||% NA_character_,
        pi_w = design$pi_w %||% NA_real_,
        pi_in = design$pi_in %||% NA_real_,
        washout = design$washout %||% NA_integer_,
        add_bias = design$add_bias %||% NA,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

apply_filters <- function(df, filters) {
  for (nm in names(filters)) {
    allowed <- filters[[nm]]
    if (!is.null(allowed)) {
      df <- df[df[[nm]] %in% allowed, , drop = FALSE]
    }
  }
  rownames(df) <- NULL
  df
}

check_unique <- function(x, label) {
  dup <- x[duplicated(x)]
  if (length(dup)) {
    stop(sprintf("%s has duplicate values; first duplicate: %s", label, dup[[1L]]), call. = FALSE)
  }
  TRUE
}

validate_manifest <- function(df) {
  if (!nrow(df)) stop("Scenario manifest is empty after filtering.", call. = FALSE)
  check_unique(df$scenario_id, "scenario_id")
  check_unique(df$scenario_spec_hash, "scenario_spec_hash")
  check_unique(df$seed, "seed")
  check_unique(df$scenario_output_dir, "scenario_output_dir")
  check_unique(df$metric_file, "metric_file")
  if (any(as.logical(df$response_likelihood))) {
    stop("response_likelihood must never be TRUE in RQR-DESN broad manifest.", call. = FALSE)
  }
  if (any(as.logical(df$response_predictive_draws))) {
    stop("response_predictive_draws must never be TRUE in RQR-DESN broad manifest.", call. = FALSE)
  }
  if (any(as.logical(df$recursive_response_sampling))) {
    stop("recursive_response_sampling must never be TRUE in RQR-DESN broad manifest.", call. = FALSE)
  }
  forbidden <- intersect(names(df), c("target_p", "p0"))
  if (length(forbidden)) {
    stop(sprintf("Forbidden target fields present in manifest: %s", paste(forbidden, collapse = ", ")), call. = FALSE)
  }
  TRUE
}

empty_interval_metrics <- function() {
  data.frame(
    scenario_id = character(0),
    stage_id = character(0),
    family_id = character(0),
    design_id = character(0),
    backend_id = character(0),
    inference = character(0),
    prior_type = character(0),
    coverage_level = numeric(0),
    learning_rate = numeric(0),
    n_train = integer(0),
    n_test = integer(0),
    endpoint_summary = character(0),
    empirical_coverage = numeric(0),
    mean_width = numeric(0),
    interval_score_mean = numeric(0),
    midpoint_mae = numeric(0),
    endpoint_mae = numeric(0),
    finite_lower = logical(0),
    finite_upper = logical(0),
    ordered_intervals = logical(0),
    positive_mean_width = logical(0),
    runtime_sec = numeric(0),
    stringsAsFactors = FALSE
  )
}

empty_fit_summary <- function() {
  data.frame(
    scenario_id = character(0),
    stage_id = character(0),
    backend_id = character(0),
    inference = character(0),
    prior_type = character(0),
    method = character(0),
    family = character(0),
    n_design_rows = integer(0),
    n_design_cols = integer(0),
    beta_prior = character(0),
    response_likelihood = logical(0),
    generalized_bayes = logical(0),
    runtime_sec = numeric(0),
    stringsAsFactors = FALSE
  )
}

empty_mcmc_diagnostics <- function() {
  data.frame(
    scenario_id = character(0),
    n_draws = integer(0),
    n_design_cols = integer(0),
    beta_prior = character(0),
    loss_first = numeric(0),
    loss_last = numeric(0),
    loss_tail_mean = numeric(0),
    loss_tail_sd = numeric(0),
    precision_strategy_root1 = character(0),
    precision_strategy_root2 = character(0),
    rhs_stats_available = logical(0),
    response_likelihood = logical(0),
    generalized_bayes = logical(0),
    sentinel_chain = logical(0),
    stringsAsFactors = FALSE
  )
}

empty_vb_diagnostics <- function() {
  data.frame(
    scenario_id = character(0),
    n_draws = integer(0),
    n_design_cols = integer(0),
    converged = logical(0),
    objective_last = numeric(0),
    delta_last = numeric(0),
    calibrated_uncertainty = logical(0),
    response_likelihood = logical(0),
    generalized_bayes = logical(0),
    stringsAsFactors = FALSE
  )
}

empty_failure_log <- function() {
  data.frame(
    scenario_id = character(0),
    stage_id = character(0),
    family_id = character(0),
    design_id = character(0),
    backend_id = character(0),
    inference = character(0),
    prior_type = character(0),
    coverage_level = numeric(0),
    learning_rate = numeric(0),
    failure_stage = character(0),
    failure_class = character(0),
    failure_message = character(0),
    trace_hint = character(0),
    created_at = character(0),
    stringsAsFactors = FALSE
  )
}

materialize_summary <- function(df) {
  key_cols <- c("stage_id", "backend_id", "inference", "prior_type")
  out <- stats::aggregate(
    list(scenario_rows = rep(1L, nrow(df))),
    by = df[key_cols],
    FUN = sum
  )
  out[order(out$stage_id, out$backend_id, out$prior_type), , drop = FALSE]
}

write_hashes <- function(output_dir) {
  artifact_files <- list.files(output_dir, full.names = TRUE)
  artifact_files <- artifact_files[basename(artifact_files) != "output_hashes.csv"]
  hash_df <- data.frame(
    file = basename(artifact_files),
    md5 = unname(tools::md5sum(artifact_files)),
    stringsAsFactors = FALSE
  )
  write_csv(hash_df, file.path(output_dir, "output_hashes.csv"))
  invisible(hash_df)
}

rqr_desn_broad_manifest_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
  if (!nzchar(repo_root)) repo_root <- getwd()
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  config_path <- cli[["config"]] %||% file.path(
    repo_root,
    "config",
    "rqr_desn",
    "rqr_desn_broad_simulation_frozen_20260716_v2.R"
  )
  config_path <- normalizePath(config_path, mustWork = TRUE)
  config <- source_config(config_path)

  short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  default_output_dir <- file.path(
    repo_root,
    config$output_contract$output_root %||% file.path("reports", "rqr_desn_broad_simulation"),
    sprintf("rqr_desn_broad_preflight_%s_git_%s", stamp, short_sha)
  )
  output_dir <- normalizePath(cli[["output-dir"]] %||% default_output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  scenario_manifest <- expand_rqr_desn_broad_config(config, config_path, repo_root, output_dir)
  filters <- list(
    stage_id = split_cli_vec(cli[["stage-id"]]),
    inference = split_cli_vec(cli[["inference"]]),
    backend_id = split_cli_vec(cli[["backend-id"]]),
    family_id = split_cli_vec(cli[["family-id"]])
  )
  scenario_manifest <- apply_filters(scenario_manifest, filters)
  validate_manifest(scenario_manifest)

  dgp_manifest <- build_dgp_manifest(config)
  design_manifest <- build_design_manifest(config)
  summary_df <- materialize_summary(scenario_manifest)
  total_rows <- nrow(scenario_manifest)
  mcmc_rows <- sum(scenario_manifest$inference == "mcmc")
  vb_rows <- sum(scenario_manifest$inference == "vb")
  baseline_rows <- sum(scenario_manifest$inference == "baseline")
  fixed_rows <- sum(scenario_manifest$stage_id == "fixed_design_calibration")
  dynamic_rows <- sum(scenario_manifest$stage_id == "teacher_forced_desn_dynamic")

  manifest_df <- data.frame(
    key = c(
      "artifact_kind",
      "interpretation",
      "config_id",
      "config_path",
      "config_hash",
      "repo_root",
      "git_commit",
      "git_branch",
      "remote_branch",
      "output_dir",
      "total_scenario_rows",
      "fixed_design_rows",
      "dynamic_rows",
      "mcmc_rows",
      "vb_sidecar_rows",
      "baseline_rows",
      "unique_scenario_ids",
      "unique_scenario_hashes",
      "unique_seeds",
      "launch_authorized",
      "article_update_allowed",
      "response_likelihood",
      "response_predictive_draws",
      "recursive_response_sampling",
      "created_at",
      "R_binary",
      "r_version"
    ),
    value = c(
      "rqr_desn_broad_manifest_preflight",
      "no-fit scenario-manifest materialization; not a launch and not article evidence",
      config$config_id,
      config_path,
      unname(tools::md5sum(config_path)),
      repo_root,
      git_value(repo_root, "rev-parse", "HEAD"),
      git_value(repo_root, "branch", "--show-current"),
      scenario_manifest$remote_branch[[1L]],
      output_dir,
      as.character(total_rows),
      as.character(fixed_rows),
      as.character(dynamic_rows),
      as.character(mcmc_rows),
      as.character(vb_rows),
      as.character(baseline_rows),
      as.character(length(unique(scenario_manifest$scenario_id))),
      as.character(length(unique(scenario_manifest$scenario_spec_hash))),
      as.character(length(unique(scenario_manifest$seed))),
      as.character(config$launch_authorized),
      as.character(config$article_update_allowed),
      "FALSE",
      "FALSE",
      "FALSE",
      format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      file.path(R.home("bin"), "R"),
      paste(R.version$major, R.version$minor, sep = ".")
    ),
    stringsAsFactors = FALSE
  )

  write_csv(manifest_df, file.path(output_dir, "manifest.csv"))
  write_csv(scenario_manifest, file.path(output_dir, "scenario_manifest.csv"))
  write_csv(summary_df, file.path(output_dir, "scenario_manifest_summary.csv"))
  write_csv(dgp_manifest, file.path(output_dir, "dgp_manifest.csv"))
  write_csv(design_manifest, file.path(output_dir, "design_manifest.csv"))
  write_csv(empty_interval_metrics(), file.path(output_dir, "interval_metrics.csv"))
  write_csv(empty_fit_summary(), file.path(output_dir, "fit_summary.csv"))
  write_csv(empty_mcmc_diagnostics(), file.path(output_dir, "mcmc_diagnostics.csv"))
  write_csv(empty_vb_diagnostics(), file.path(output_dir, "vb_diagnostics.csv"))
  write_csv(empty_failure_log(), file.path(output_dir, "failure_log.csv"))

  readme <- c(
    "# RQR-DESN Broad Manifest Preflight",
    "",
    "This is a no-fit preflight artifact. It materializes the scenario denominator",
    "from the frozen RQR-DESN broad config. It does not launch or fit models, and",
    "it is not article evidence.",
    "",
    sprintf("Config id: `%s`", config$config_id),
    sprintf("Scenario rows: `%d`", total_rows),
    sprintf("MCMC rows: `%d`", mcmc_rows),
    sprintf("VB sidecar rows: `%d`", vb_rows),
    sprintf("Baseline rows: `%d`", baseline_rows),
    "",
    "Hard contract:",
    "",
    "- no `target_p` or RQR-target `p0` fields;",
    "- no response likelihood;",
    "- no response predictive draws;",
    "- no recursive response sampling;",
    "- unique scenario ids, hashes, seeds, and output paths."
  )
  writeLines(readme, file.path(output_dir, "README.md"))
  writeLines(
    c(
      "# RQR-DESN Broad Preflight Closeout",
      "",
      "Status: no-fit manifest preflight completed.",
      "",
      sprintf("- scenario rows: %d", total_rows),
      sprintf("- fixed-design rows: %d", fixed_rows),
      sprintf("- dynamic rows: %d", dynamic_rows),
      sprintf("- MCMC rows: %d", mcmc_rows),
      sprintf("- VB sidecar rows: %d", vb_rows),
      sprintf("- baseline rows: %d", baseline_rows),
      "",
      "Recommendation: proceed to runner smoke only after this preflight script",
      "and its focused tests are committed. Do not launch the broad simulation and",
      "do not update the article from this artifact alone."
    ),
    file.path(output_dir, "closeout.md")
  )
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "session_info.txt"))
  writeLines(
    c(
      "$ git status --short --branch",
      git_value(repo_root, "status", "--short", "--branch"),
      "",
      "$ git log --oneline -5",
      git_value(repo_root, "log", "--oneline", "-5")
    ),
    file.path(output_dir, "git_state.txt")
  )
  write_hashes(output_dir)

  message(sprintf(
    "RQR-DESN broad manifest preflight wrote %d rows (%d MCMC, %d VB sidecar, %d baseline) to %s",
    total_rows,
    mcmc_rows,
    vb_rows,
    baseline_rows,
    output_dir
  ))
  invisible(output_dir)
}

if (sys.nframe() == 0L) {
  rqr_desn_broad_manifest_main()
}
