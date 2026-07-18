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

as_int <- function(x, default = NA_integer_) {
  if (is.null(x)) return(default)
  out <- suppressWarnings(as.integer(x[1L]))
  if (!is.finite(out)) stop(sprintf("Expected integer, got: %s", x[1L]), call. = FALSE)
  out
}

as_flag <- function(x, default = FALSE) {
  if (is.null(x)) return(default)
  value <- tolower(trimws(as.character(x[1L])))
  if (value %in% c("true", "t", "1", "yes", "y")) return(TRUE)
  if (value %in% c("false", "f", "0", "no", "n")) return(FALSE)
  stop(sprintf("Cannot parse logical flag: %s", x), call. = FALSE)
}

git_value <- function(repo_root, ...) {
  value <- tryCatch(
    system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  paste(value, collapse = "\n")
}

write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, file = path, row.names = FALSE, na = "")
}

read_csv_required <- function(path) {
  if (!file.exists(path)) stop(sprintf("Required file is missing: %s", path), call. = FALSE)
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

source_config <- function(config_path) {
  env <- new.env(parent = baseenv())
  sys.source(config_path, envir = env)
  get("rqr_desn_broad_simulation_config", envir = env)
}

is_na_scalar <- function(x) {
  length(x) == 1L && is.na(x)
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
  paste(vapply(seq_along(x), function(ii) {
    nm <- nms[[ii]]
    value <- stable_list_string(x[[ii]])
    if (nzchar(nm)) paste0(nm, "=", value) else value
  }, character(1)), collapse = ";")
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

stage_lookup <- function(config) {
  out <- list()
  for (stage_index in seq_along(config$stages)) {
    stage <- config$stages[[stage_index]]
    out[[stage$stage_id]] <- list(stage = stage, stage_index = stage_index)
  }
  out
}

family_index <- function(stage, family_id) {
  ids <- vapply(stage$dgp_families, function(x) x$family_id, character(1))
  idx <- match(as.character(family_id), ids)
  if (is.na(idx)) stop(sprintf("Unknown family_id %s for stage %s", family_id, stage$stage_id), call. = FALSE)
  idx
}

design_index <- function(stage, design_id) {
  if (identical(as.character(design_id), "none")) return(0L)
  ids <- vapply(stage$designs, function(x) x$design_id, character(1))
  idx <- match(as.character(design_id), ids)
  if (is.na(idx)) stop(sprintf("Unknown design_id %s for stage %s", design_id, stage$stage_id), call. = FALSE)
  idx
}

prior_index <- function(prior_type) {
  match(as.character(prior_type), c("none", "ridge", "rhs_ns"), nomatch = 99L)
}

coverage_index <- function(coverage_level) {
  match(format(as.numeric(coverage_level), trim = TRUE, scientific = FALSE), c("0.8", "0.9"), nomatch = 99L)
}

learning_rate_index <- function(learning_rate) {
  if (is.na(suppressWarnings(as.numeric(learning_rate)))) return(0L)
  match(format(as.numeric(learning_rate), trim = TRUE, scientific = FALSE), c("0.5", "1", "1.5"), nomatch = 99L)
}

prior_hyperparameters <- function(config, prior_type) {
  prior_type <- as.character(prior_type)
  if (identical(prior_type, "none")) return("none")
  prior <- config$priors[[prior_type]]
  if (is.null(prior)) stop(sprintf("Unknown prior type: %s", prior_type), call. = FALSE)
  stable_list_string(prior)
}

role_rank <- function(role) {
  role <- as.character(role)
  if (grepl("winner", role, fixed = TRUE)) return(1L)
  if (grepl("nearest_nominal_coverage", role, fixed = TRUE)) return(2L)
  if (grepl("score_runner_up", role, fixed = TRUE)) return(3L)
  9L
}

normalize_candidate_grid <- function(candidate_grid) {
  required <- c("stage_id", "family_id", "coverage_level", "backend_id", "inference", "prior_type", "learning_rate", "design_id", "confirmation_role")
  missing <- setdiff(required, names(candidate_grid))
  if (length(missing)) stop(sprintf("Candidate grid missing required columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  candidate_grid <- candidate_grid[as.character(candidate_grid$inference) == "mcmc", , drop = FALSE]
  if (!nrow(candidate_grid)) stop("Candidate grid has no MCMC rows.", call. = FALSE)
  key_cols <- c("stage_id", "family_id", "coverage_level", "backend_id", "prior_type", "learning_rate", "design_id")
  split_key <- do.call(paste, c(candidate_grid[key_cols], sep = "\r"))
  groups <- split(candidate_grid, split_key)
  out <- lapply(groups, function(df) {
    df <- df[order(vapply(df$confirmation_role, role_rank, integer(1))), , drop = FALSE]
    row <- df[1L, , drop = FALSE]
    row$confirmation_role <- paste(sort(unique(as.character(df$confirmation_role))), collapse = "+")
    row$targeted_candidate_source_rows <- nrow(df)
    row
  })
  out <- do.call(rbind, out)
  out <- out[order(out$stage_id, out$family_id, as.numeric(out$coverage_level), out$design_id, out$prior_type, as.numeric(out$learning_rate)), , drop = FALSE]
  out$targeted_candidate_index <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

replicates_for_stage <- function(config, stage_id, cli) {
  if (identical(stage_id, "fixed_design_calibration")) {
    return(as_int(cli[["fixed-replicates"]], as.integer(config$targeted_confirmation$fixed_design_replicates %||% 24L)))
  }
  if (identical(stage_id, "teacher_forced_desn_dynamic")) {
    return(as_int(cli[["dynamic-replicates"]], as.integer(config$targeted_confirmation$dynamic_replicates %||% 18L)))
  }
  stop(sprintf("Unknown stage_id: %s", stage_id), call. = FALSE)
}

scenario_spec_string <- function(row) {
  keep <- c(
    "config_id", "stage_id", "stage_index", "family_id", "family_index",
    "replicate_id", "design_id", "design_index", "backend_id", "backend_index",
    "inference", "prior_type", "prior_index", "coverage_level",
    "coverage_index", "learning_rate", "learning_rate_index",
    "targeted_candidate_index", "confirmation_role", "seed"
  )
  paste(paste0(keep, "=", vapply(row[keep], scalar_string, character(1))), collapse = "|")
}

build_scenario_id <- function(row) {
  paste(
    "rqr_confirm",
    sanitize_id(row$stage_id),
    sanitize_id(row$family_id),
    sprintf("rep%03d", as.integer(row$replicate_id)),
    sanitize_id(row$design_id),
    sanitize_id(row$backend_id),
    sanitize_id(row$prior_type),
    paste0("cov", num_token(row$coverage_level)),
    paste0("lr", num_token(row$learning_rate)),
    sprintf("cand%03d", as.integer(row$targeted_candidate_index)),
    sep = "__"
  )
}

build_dgp_manifest <- function(config, cli) {
  rows <- list()
  kk <- 0L
  for (stage_ref in config$stages) {
    reps <- replicates_for_stage(config, stage_ref$stage_id, cli)
    for (family in stage_ref$dgp_families) {
      kk <- kk + 1L
      rows[[kk]] <- data.frame(
        stage_id = stage_ref$stage_id,
        family_id = family$family_id,
        noise = family$noise %||% NA_character_,
        n_train = as.integer(stage_ref$n_train),
        n_test = as.integer(stage_ref$n_test),
        replicates = reps,
        oracle_endpoints = isTRUE(family$oracle_endpoints),
        dgp_parameter_json = stable_list_string(family),
        oracle_formula_note = if (isTRUE(family$oracle_endpoints)) {
          paste("Oracle central interval endpoints available for", family$noise)
        } else {
          "No oracle endpoint contract; endpoint_mae should remain NA"
        },
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

build_design_manifest <- function(config) {
  rows <- list()
  kk <- 0L
  for (stage_ref in config$stages) {
    for (design in stage_ref$designs) {
      kk <- kk + 1L
      rows[[kk]] <- data.frame(
        stage_id = stage_ref$stage_id,
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

make_base_row <- function(config, config_path, repo_root, output_dir, stage_info, family_id, replicate_id, coverage_level, candidate_index, branch_info) {
  stage <- stage_info$stage
  row <- list(
    config_id = config$config_id,
    config_path = config_path,
    config_hash = unname(tools::md5sum(config_path)),
    implementation_commit = branch_info$commit,
    branch = branch_info$branch,
    remote_branch = branch_info$remote_branch,
    R_binary = file.path(R.home("bin"), "R"),
    package_library = paste(.libPaths(), collapse = ";"),
    stage_id = stage$stage_id,
    stage_index = stage_info$stage_index,
    family_id = family_id,
    scenario_family = family_id,
    family_index = family_index(stage, family_id),
    replicate_id = replicate_id,
    design_id = "none",
    design_index = 0L,
    design_type = "none",
    DESN_D = NA_integer_,
    DESN_n = NA_integer_,
    DESN_m = NA_integer_,
    washout = NA_integer_,
    backend_id = "empirical_train_interval",
    backend_index = 1L,
    backend = "empirical_train_interval",
    inference = "baseline",
    primary_backend = FALSE,
    prior_type = "none",
    prior_index = 1L,
    prior_hyperparameters = "none",
    coverage_level = as.numeric(coverage_level),
    coverage_index = coverage_index(coverage_level),
    learning_rate = NA_real_,
    learning_rate_index = 0L,
    targeted_candidate_index = candidate_index,
    confirmation_role = "baseline",
    targeted_candidate_source_rows = 1L,
    mcmc_control = stable_list_string(config$mcmc_control),
    vb_control = stable_list_string(config$vb_control),
    status = "pending",
    response_likelihood = FALSE,
    response_predictive_draws = FALSE,
    recursive_response_sampling = FALSE
  )
  row
}

make_candidate_row <- function(config, config_path, repo_root, output_dir, stage_info, cand, replicate_id, candidate_index, branch_info) {
  stage <- stage_info$stage
  row <- list(
    config_id = config$config_id,
    config_path = config_path,
    config_hash = unname(tools::md5sum(config_path)),
    implementation_commit = branch_info$commit,
    branch = branch_info$branch,
    remote_branch = branch_info$remote_branch,
    R_binary = file.path(R.home("bin"), "R"),
    package_library = paste(.libPaths(), collapse = ";"),
    stage_id = as.character(cand$stage_id),
    stage_index = stage_info$stage_index,
    family_id = as.character(cand$family_id),
    scenario_family = as.character(cand$family_id),
    family_index = family_index(stage, cand$family_id),
    replicate_id = replicate_id,
    design_id = as.character(cand$design_id),
    design_index = design_index(stage, cand$design_id),
    design_type = if (identical(as.character(cand$design_id), "fixed_linear_true_features")) "fixed_design" else "teacher_forced_desn",
    DESN_D = NA_integer_,
    DESN_n = NA_integer_,
    DESN_m = NA_integer_,
    washout = NA_integer_,
    backend_id = as.character(cand$backend_id),
    backend_index = 2L,
    backend = as.character(cand$backend_id),
    inference = "mcmc",
    primary_backend = TRUE,
    prior_type = as.character(cand$prior_type),
    prior_index = prior_index(cand$prior_type),
    prior_hyperparameters = prior_hyperparameters(config, cand$prior_type),
    coverage_level = as.numeric(cand$coverage_level),
    coverage_index = coverage_index(cand$coverage_level),
    learning_rate = as.numeric(cand$learning_rate),
    learning_rate_index = learning_rate_index(cand$learning_rate),
    targeted_candidate_index = candidate_index,
    confirmation_role = as.character(cand$confirmation_role),
    targeted_candidate_source_rows = as.integer(cand$targeted_candidate_source_rows),
    broad_interval_score_mean = as.numeric(cand$interval_score_mean),
    broad_empirical_coverage = as.numeric(cand$empirical_coverage),
    broad_coverage_error = as.numeric(cand$coverage_error),
    broad_calibration_class = as.character(cand$calibration_class),
    broad_recommendation_class = as.character(cand$recommendation_class),
    mcmc_control = stable_list_string(config$mcmc_control),
    vb_control = stable_list_string(config$vb_control),
    status = "pending",
    response_likelihood = FALSE,
    response_predictive_draws = FALSE,
    recursive_response_sampling = FALSE
  )
  row
}

fill_design_fields <- function(rows, design_manifest) {
  for (ii in seq_along(rows)) {
    row <- rows[[ii]]
    if (!identical(as.character(row$design_id), "none")) {
      idx <- which(as.character(design_manifest$stage_id) == as.character(row$stage_id) &
        as.character(design_manifest$design_id) == as.character(row$design_id))
      if (!length(idx)) stop(sprintf("Missing design manifest row for %s/%s", row$stage_id, row$design_id), call. = FALSE)
      design <- as.list(design_manifest[idx[1L], , drop = FALSE])
      row$design_type <- design$design_type
      row$DESN_D <- design$DESN_D
      row$DESN_n <- design$DESN_n
      row$DESN_m <- design$DESN_m
      row$washout <- design$washout
    }
    rows[[ii]] <- row
  }
  rows
}

rbind_fill <- function(parts) {
  all_names <- unique(unlist(lapply(parts, names), use.names = FALSE))
  dfs <- lapply(parts, function(x) {
    missing <- setdiff(all_names, names(x))
    for (nm in missing) x[[nm]] <- NA
    data.frame(as.list(x[all_names]), stringsAsFactors = FALSE, check.names = FALSE)
  })
  do.call(rbind, dfs)
}

expand_targeted_confirmation <- function(config, config_path, repo_root, output_dir, candidate_grid, cli) {
  stages <- stage_lookup(config)
  design_manifest <- build_design_manifest(config)
  branch_info <- list(
    commit = git_value(repo_root, "rev-parse", "HEAD"),
    branch = git_value(repo_root, "branch", "--show-current"),
    remote_branch = git_value(repo_root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  )
  if (!nzchar(branch_info$remote_branch) || grepl("fatal:", branch_info$remote_branch, fixed = TRUE)) {
    branch_info$remote_branch <- NA_character_
  }

  candidates <- normalize_candidate_grid(candidate_grid)
  baseline_cells <- unique(candidates[, c("stage_id", "family_id", "coverage_level"), drop = FALSE])
  baseline_cells <- baseline_cells[order(baseline_cells$stage_id, baseline_cells$family_id, as.numeric(baseline_cells$coverage_level)), , drop = FALSE]

  rows <- list()
  rr <- 0L
  for (stage_id in names(stages)) {
    stage_info <- stages[[stage_id]]
    reps <- replicates_for_stage(config, stage_id, cli)
    stage_candidates <- candidates[as.character(candidates$stage_id) == stage_id, , drop = FALSE]
    stage_baselines <- baseline_cells[as.character(baseline_cells$stage_id) == stage_id, , drop = FALSE]
    for (replicate_id in seq_len(reps)) {
      for (ii in seq_len(nrow(stage_baselines))) {
        rr <- rr + 1L
        rows[[rr]] <- make_base_row(
          config, config_path, repo_root, output_dir, stage_info,
          stage_baselines$family_id[[ii]], replicate_id,
          stage_baselines$coverage_level[[ii]], 0L, branch_info
        )
      }
      for (ii in seq_len(nrow(stage_candidates))) {
        rr <- rr + 1L
        rows[[rr]] <- make_candidate_row(
          config, config_path, repo_root, output_dir, stage_info,
          stage_candidates[ii, , drop = FALSE], replicate_id,
          as.integer(stage_candidates$targeted_candidate_index[[ii]]),
          branch_info
        )
      }
    }
  }
  rows <- fill_design_fields(rows, design_manifest)
  df <- rbind_fill(rows)
  order_cols <- config$randomization$scenario_order
  ord <- do.call(order, df[order_cols])
  df <- df[ord, , drop = FALSE]
  df$scenario_index <- seq_len(nrow(df))
  df$seed <- as.integer(as_int(cli[["seed-base"]], as.integer(config$randomization$seed_base))) + df$scenario_index
  df$scenario_id <- vapply(seq_len(nrow(df)), function(ii) build_scenario_id(df[ii, , drop = FALSE]), character(1))
  df$scenario_spec_hash <- vapply(seq_len(nrow(df)), function(ii) hash_string(scenario_spec_string(df[ii, , drop = FALSE])), character(1))
  df$scenario_output_dir <- file.path(output_dir, "scenario_outputs", df$scenario_id)
  df$metric_file <- file.path(df$scenario_output_dir, "interval_metrics.csv")
  df$fit_summary_file <- file.path(df$scenario_output_dir, "fit_summary.csv")
  df$mcmc_diagnostics_file <- file.path(df$scenario_output_dir, "mcmc_diagnostics.csv")
  df$vb_diagnostics_file <- file.path(df$scenario_output_dir, "vb_diagnostics.csv")
  df$failure_file <- file.path(df$scenario_output_dir, "failure_log.csv")
  df$output_file <- df$metric_file
  df$output_hash <- NA_character_
  rownames(df) <- NULL
  list(scenario_manifest = df, design_manifest = design_manifest, candidate_specs = candidates)
}

check_unique <- function(x, label) {
  dup <- x[duplicated(x)]
  if (length(dup)) stop(sprintf("%s has duplicate values; first duplicate: %s", label, dup[[1L]]), call. = FALSE)
  TRUE
}

validate_manifest <- function(df) {
  if (!nrow(df)) stop("Targeted confirmation scenario manifest is empty.", call. = FALSE)
  check_unique(df$scenario_id, "scenario_id")
  check_unique(df$scenario_spec_hash, "scenario_spec_hash")
  check_unique(df$seed, "seed")
  check_unique(df$scenario_output_dir, "scenario_output_dir")
  if (any(as.character(df$inference) == "vb")) stop("Targeted confirmation manifest must not include VB rows.", call. = FALSE)
  if (any(as.logical(df$response_likelihood))) stop("response_likelihood must be FALSE.", call. = FALSE)
  if (any(as.logical(df$response_predictive_draws))) stop("response_predictive_draws must be FALSE.", call. = FALSE)
  if (any(as.logical(df$recursive_response_sampling))) stop("recursive_response_sampling must be FALSE.", call. = FALSE)
  forbidden <- intersect(names(df), c("target_p", "p0"))
  if (length(forbidden)) stop(sprintf("Forbidden target fields present: %s", paste(forbidden, collapse = ", ")), call. = FALSE)
  TRUE
}

empty_interval_metrics <- function() {
  data.frame(
    scenario_id = character(0), stage_id = character(0), family_id = character(0),
    design_id = character(0), backend_id = character(0), inference = character(0),
    prior_type = character(0), replicate_id = integer(0), seed = integer(0),
    dgp_seed = integer(0), design_seed = integer(0), coverage_level = numeric(0),
    learning_rate = numeric(0), n_train = integer(0), n_test = integer(0),
    endpoint_summary = character(0), empirical_coverage = numeric(0),
    mean_width = numeric(0), interval_score_mean = numeric(0),
    midpoint_mae = numeric(0), endpoint_mae = numeric(0),
    finite_lower = logical(0), finite_upper = logical(0),
    ordered_intervals = logical(0), positive_mean_width = logical(0),
    runtime_sec = numeric(0), response_likelihood = logical(0),
    response_predictive_draws = logical(0), recursive_response_sampling = logical(0),
    stringsAsFactors = FALSE
  )
}

empty_fit_summary <- function() {
  data.frame(
    scenario_id = character(0), stage_id = character(0), backend_id = character(0),
    inference = character(0), prior_type = character(0), method = character(0),
    family = character(0), n_design_rows = integer(0), n_design_cols = integer(0),
    beta_prior = character(0), response_likelihood = logical(0),
    generalized_bayes = logical(0), runtime_sec = numeric(0),
    stringsAsFactors = FALSE
  )
}

empty_mcmc_diagnostics <- function() {
  data.frame(
    scenario_id = character(0), n_draws = integer(0), n_design_cols = integer(0),
    beta_prior = character(0), loss_first = numeric(0), loss_last = numeric(0),
    loss_tail_mean = numeric(0), loss_tail_sd = numeric(0),
    precision_strategy_root1 = character(0), precision_strategy_root2 = character(0),
    rhs_stats_available = logical(0), response_likelihood = logical(0),
    generalized_bayes = logical(0), sentinel_chain = logical(0),
    stringsAsFactors = FALSE
  )
}

empty_vb_diagnostics <- function() {
  data.frame(
    scenario_id = character(0), n_draws = integer(0), n_design_cols = integer(0),
    converged = logical(0), objective_last = numeric(0), delta_last = numeric(0),
    calibrated_uncertainty = logical(0), response_likelihood = logical(0),
    generalized_bayes = logical(0), stringsAsFactors = FALSE
  )
}

empty_failure_log <- function() {
  data.frame(
    scenario_id = character(0), stage_id = character(0), family_id = character(0),
    design_id = character(0), backend_id = character(0), inference = character(0),
    prior_type = character(0), coverage_level = numeric(0), learning_rate = numeric(0),
    failure_stage = character(0), failure_class = character(0),
    failure_message = character(0), trace_hint = character(0), created_at = character(0),
    stringsAsFactors = FALSE
  )
}

write_hashes <- function(output_dir) {
  files <- list.files(output_dir, full.names = TRUE, recursive = FALSE)
  files <- files[file.info(files)$isdir %in% FALSE]
  files <- files[basename(files) != "output_hashes.csv"]
  hash_df <- data.frame(file = basename(files), md5 = unname(tools::md5sum(files)), stringsAsFactors = FALSE)
  write_csv(hash_df, file.path(output_dir, "output_hashes.csv"))
  invisible(hash_df)
}

materialize_summary <- function(df) {
  out <- stats::aggregate(
    list(scenario_rows = rep(1L, nrow(df))),
    by = df[c("stage_id", "backend_id", "inference", "prior_type", "confirmation_role")],
    FUN = sum
  )
  out[order(out$stage_id, out$backend_id, out$prior_type, out$confirmation_role), , drop = FALSE]
}

write_plan_doc <- function(output_dir, config, scenario_manifest, candidate_specs) {
  lines <- c(
    "# RQR-DESN Targeted Confirmation Plan",
    "",
    "This artifact freezes the targeted confirmation denominator produced from",
    "the broad results-audit candidate grid. It is package-side simulation work",
    "and does not authorize article updates.",
    "",
    sprintf("- config_id: `%s`", config$config_id),
    sprintf("- scenario rows: `%d`", nrow(scenario_manifest)),
    sprintf("- MCMC rows: `%d`", sum(scenario_manifest$inference == "mcmc")),
    sprintf("- empirical baseline rows: `%d`", sum(scenario_manifest$inference == "baseline")),
    sprintf("- VB rows: `%d`", sum(scenario_manifest$inference == "vb")),
    sprintf("- unique candidate specs: `%d`", nrow(candidate_specs)),
    sprintf("- seed_base: `%d`", as.integer(config$randomization$seed_base)),
    "",
    "Confirmation rule:",
    "",
    "- rerun only MCMC winners, nearest-coverage alternatives, and score runner-ups;",
    "- use fresh independent seeds rather than broad-run scenario ids;",
    "- retain empirical train-interval baselines for paired deltas;",
    "- keep response-likelihood and response-sampling flags false;",
    "- keep VB excluded until a separate calibration study exists."
  )
  writeLines(lines, file.path(output_dir, "TARGETED_CONFIRMATION_PLAN.md"))
}

targeted_manifest_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  cli <- parse_cli(args)
  repo_root <- cli[["repo-root"]] %||% git_value(getwd(), "rev-parse", "--show-toplevel")
  if (!nzchar(repo_root)) repo_root <- getwd()
  repo_root <- normalizePath(repo_root, mustWork = TRUE)
  config_path <- cli[["config"]] %||% file.path(repo_root, "config", "rqr_desn", "rqr_desn_targeted_confirmation_20260717.R")
  config_path <- normalizePath(config_path, mustWork = TRUE)
  config <- source_config(config_path)
  candidate_path <- cli[["candidate-grid"]] %||% file.path(repo_root, config$targeted_confirmation$candidate_grid)
  candidate_path <- normalizePath(candidate_path, mustWork = TRUE)
  candidate_grid <- read_csv_required(candidate_path)

  short_sha <- substr(git_value(repo_root, "rev-parse", "HEAD"), 1L, 12L)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  output_dir <- cli[["output-dir"]] %||% file.path(
    repo_root,
    config$output_contract$output_root %||% file.path("reports", "rqr_desn_broad_simulation"),
    sprintf("rqr_desn_targeted_confirmation_%s_git_%s", stamp, short_sha)
  )
  output_dir <- normalizePath(output_dir, mustWork = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  expanded <- expand_targeted_confirmation(config, config_path, repo_root, output_dir, candidate_grid, cli)
  scenario_manifest <- expanded$scenario_manifest
  dgp_manifest <- build_dgp_manifest(config, cli)
  design_manifest <- expanded$design_manifest
  validate_manifest(scenario_manifest)

  manifest_df <- data.frame(
    key = c(
      "artifact_kind", "interpretation", "config_id", "config_path", "config_hash",
      "candidate_grid", "repo_root", "git_commit", "git_branch", "remote_branch",
      "output_dir", "total_scenario_rows", "mcmc_rows", "vb_rows", "baseline_rows",
      "unique_candidate_specs", "unique_scenario_ids", "unique_scenario_hashes",
      "unique_seeds", "launch_authorized", "article_update_allowed",
      "response_likelihood", "response_predictive_draws", "recursive_response_sampling",
      "created_at", "R_binary", "r_version"
    ),
    value = c(
      "rqr_desn_targeted_confirmation_manifest",
      "fresh-seed targeted confirmation denominator; not article evidence",
      config$config_id,
      config_path,
      unname(tools::md5sum(config_path)),
      candidate_path,
      repo_root,
      git_value(repo_root, "rev-parse", "HEAD"),
      git_value(repo_root, "branch", "--show-current"),
      scenario_manifest$remote_branch[[1L]],
      output_dir,
      as.character(nrow(scenario_manifest)),
      as.character(sum(scenario_manifest$inference == "mcmc")),
      as.character(sum(scenario_manifest$inference == "vb")),
      as.character(sum(scenario_manifest$inference == "baseline")),
      as.character(nrow(expanded$candidate_specs)),
      as.character(length(unique(scenario_manifest$scenario_id))),
      as.character(length(unique(scenario_manifest$scenario_spec_hash))),
      as.character(length(unique(scenario_manifest$seed))),
      as.character(config$launch_authorized),
      as.character(config$article_update_allowed),
      "FALSE", "FALSE", "FALSE",
      format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      file.path(R.home("bin"), "R"),
      paste(R.version$major, R.version$minor, sep = ".")
    ),
    stringsAsFactors = FALSE
  )

  write_csv(manifest_df, file.path(output_dir, "manifest.csv"))
  write_csv(scenario_manifest, file.path(output_dir, "scenario_manifest.csv"))
  write_csv(materialize_summary(scenario_manifest), file.path(output_dir, "scenario_manifest_summary.csv"))
  write_csv(dgp_manifest, file.path(output_dir, "dgp_manifest.csv"))
  write_csv(design_manifest, file.path(output_dir, "design_manifest.csv"))
  write_csv(expanded$candidate_specs, file.path(output_dir, "targeted_candidate_specs.csv"))
  write_csv(empty_interval_metrics(), file.path(output_dir, "interval_metrics.csv"))
  write_csv(empty_fit_summary(), file.path(output_dir, "fit_summary.csv"))
  write_csv(empty_mcmc_diagnostics(), file.path(output_dir, "mcmc_diagnostics.csv"))
  write_csv(empty_vb_diagnostics(), file.path(output_dir, "vb_diagnostics.csv"))
  write_csv(empty_failure_log(), file.path(output_dir, "failure_log.csv"))

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
  write_plan_doc(output_dir, config, scenario_manifest, expanded$candidate_specs)
  writeLines(
    c(
      "# RQR-DESN Targeted Confirmation Closeout",
      "",
      "Status: no-fit targeted confirmation manifest materialized.",
      "",
      sprintf("- scenario rows: `%d`", nrow(scenario_manifest)),
      sprintf("- MCMC rows: `%d`", sum(scenario_manifest$inference == "mcmc")),
      sprintf("- baseline rows: `%d`", sum(scenario_manifest$inference == "baseline")),
      sprintf("- VB rows: `%d`", sum(scenario_manifest$inference == "vb")),
      "",
      "Next step: run `scripts/run_rqr_desn_broad_simulation.R` against this",
      "output directory with the targeted confirmation config. Do not update the",
      "article from this manifest."
    ),
    file.path(output_dir, "closeout.md")
  )
  writeLines(
    c(
      "# RQR-DESN Targeted Confirmation Run",
      "",
      "Generated by `scripts/materialize_rqr_desn_targeted_confirmation_manifest.R`.",
      "",
      "This directory is a fresh-seed confirmation denominator. The existing broad",
      "runner can consume it because it contains compatible scenario, DGP, and",
      "design manifests."
    ),
    file.path(output_dir, "README.md")
  )
  write_hashes(output_dir)
  message(sprintf(
    "RQR-DESN targeted confirmation manifest wrote %d rows (%d MCMC, %d baseline, %d VB) to %s",
    nrow(scenario_manifest),
    sum(scenario_manifest$inference == "mcmc"),
    sum(scenario_manifest$inference == "baseline"),
    sum(scenario_manifest$inference == "vb"),
    output_dir
  ))
  invisible(output_dir)
}

if (sys.nframe() == 0L) {
  targeted_manifest_main()
}
