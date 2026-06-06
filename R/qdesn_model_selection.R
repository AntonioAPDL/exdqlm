# R/qdesn_model_selection.R
# ESN hyperparameter model selection via CRPS(synth) on a verification window.

#' ESN model selection via CRPS(synth) on a verification window
#'
#' This function orchestrates ESN hyperparameter tuning for a given dataset using
#' a three-way split (train / verification / test) and the synthesized predictive
#' distribution's CRPS on the verification block as the objective.
#'
#' The function:
#' \enumerate{
#'   \item parses the \code{model_selection} block from a configuration list,
#'   \item constructs a set of candidate ESN hyperparameters,
#'   \item for each candidate, runs the ESN pipeline on (train + verification),
#'   \item extracts mean CRPS(synth) on the forecast window (verification),
#'   \item selects the best candidate,
#'   \item re-runs the pipeline once for that candidate on (train + verification + test),
#'   \item returns a tidy summary and writes CSV/YAML artifacts on disk.
#' }
#'
#' @param dataset_id character; identifier used for logging. Purely cosmetic.
#' @param file_long character; path to the long-format data used by the ESN pipeline.
#' @param file_obs  character or NULL; optional observed-data file (for real-data mode).
#' @param base_cfg  list; configuration list representing defaults + spec YAML
#'   (excluding the \code{model_selection} block). This will be augmented per candidate.
#' @param ms_cfg    list; configuration list containing a top-level
#'   \code{$model_selection} block (typically obtained via \code{yaml::read_yaml()}).
#' @param out_root  character; root directory where model-selection outputs
#'   should be written (candidates, logs, summaries).
#' @param repo_root character or NULL; repository root; passed to
#'   \code{\link{run_esn_pipeline_from_cfg}}.
#' @param verbose logical; whether to emit progress messages.
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{tune_name}: name of the tuning run,
#'     \item \code{split}: list with \code{train_n}, \code{verify_n}, \code{test_n},
#'     \item \code{candidates}: tibble with all candidate specs and tuning scores,
#'     \item \code{best}: list summarizing the selected spec and its test performance.
#'   }
.qdesn_model_selection_legacy <- function(
  dataset_id,
  file_long,
  file_obs  = NULL,
  base_cfg,
  ms_cfg,
  out_root,
  repo_root = NULL,
  verbose   = TRUE
) {
  stopifnot(is.character(dataset_id), length(dataset_id) == 1L)
  stopifnot(is.character(file_long),  length(file_long)  == 1L)
  stopifnot(is.list(base_cfg), is.list(ms_cfg))
  if (!"model_selection" %in% names(ms_cfg)) {
    stop("qdesn_model_selection(): ms_cfg must contain a 'model_selection' block.")
  }

  ms_block <- ms_cfg$model_selection
  tune_name <- ms_block$tune_name %||% paste0(dataset_id, "_ms")

  if (isTRUE(verbose)) {
    message(sprintf("[qdesn_model_selection] dataset=%s | tune_name=%s", dataset_id, tune_name))
  }

  # ------------------------------------------------------------
  # 1) Determine effective series length T_full and splits
  # ------------------------------------------------------------
  dat_long <- readr::read_csv(file_long, show_col_types = FALSE)
  if (!"t" %in% names(dat_long)) {
    stop("qdesn_model_selection(): file_long must contain a 't' column.")
  }
  y_full_all <- dat_long |>
    dplyr::distinct(.data$t, .data$y, .keep_all = TRUE) |>
    dplyr::arrange(.data$t)
  T_full <- nrow(y_full_all)

  split_cfg <- ms_block$split %||% list()
  split_res <- .qdesn_ms_resolve_split(split_cfg, T_full)

  train_n  <- split_res$train_n
  verify_n <- split_res$verify_n
  test_n   <- split_res$test_n

  if (isTRUE(verbose)) {
    message(sprintf(
      "[qdesn_model_selection] split → T_full=%d | train=%d | verify=%d | test=%d",
      T_full, train_n, verify_n, test_n
    ))
  }

  # cfg override chunks for tuning vs test
  split_tune <- list(
    T_use      = train_n + verify_n,
    use_last   = TRUE,
    train_n    = train_n,
    train_prop = NULL
  )
  split_test <- list(
    T_use      = train_n + verify_n + test_n,
    use_last   = TRUE,
    train_n    = train_n + verify_n,
    train_prop = NULL
  )

  # ------------------------------------------------------------
  # 2) Generate ESN hyperparameter candidates
  # ------------------------------------------------------------
  esn_space <- ms_block$esn_space %||% stop("model_selection$esn_space is required.")
  search_cfg <- ms_block$search     %||% list()

  cand_tbl <- .qdesn_ms_generate_candidates(esn_space, search_cfg, verbose = verbose)

  if (nrow(cand_tbl) == 0L) {
    stop("qdesn_model_selection(): no ESN candidates generated.")
  }

  # ------------------------------------------------------------
  # 3) Evaluate candidates on train+verification
  # ------------------------------------------------------------
  parallel_cfg <- search_cfg$parallel %||% list()
  n_workers    <- as.integer(parallel_cfg$n_workers %||% 1L)
  n_workers    <- max(1L, n_workers)

  out_ms_root <- file.path(out_root, "model_selection", tune_name)
  dir.create(out_ms_root, recursive = TRUE, showWarnings = FALSE)
  log_file <- file.path(out_ms_root, "log.txt")

  if (isTRUE(verbose)) {
    message(sprintf(
      "[qdesn_model_selection] evaluating %d candidates with n_workers=%d",
      nrow(cand_tbl), n_workers
    ))
  }

  # Closure to evaluate a single candidate spec_id (tuning stage)
  eval_one_tune <- function(row) {
    theta   <- .qdesn_ms_row_to_theta(row)
    spec_id <- row$spec_id

    out_dir_stage <- file.path(out_ms_root, spec_id, "tune")
    dir.create(out_dir_stage, recursive = TRUE, showWarnings = FALSE)

    # Merge cfg: base_cfg + candidate-specific desn + split_tune
    cfg_tune <- base_cfg
    cfg_tune$desn  <- .qdesn_ms_apply_theta_to_desn(theta, base_cfg$desn %||% list())
    cfg_tune$split <- split_tune

    # Ensure forecast window = verification (1-step rolling origin)
    cfg_tune$forecast <- cfg_tune$forecast %||% list()
    cfg_tune$forecast$rolling_origin <- TRUE
    cfg_tune$forecast$H_step         <- 1L

    res_run <- tryCatch(
      {
        run_esn_pipeline_from_cfg(
          cfg       = cfg_tune,
          file_long = file_long,
          file_obs  = file_obs,
          out_dir   = out_dir_stage,
          repo_root = repo_root,
          save_outputs = FALSE,   # minimal-output mode for model selection
          verbose   = FALSE
        )
      },
      error = function(e) {
        list(status = 1L, stdout = conditionMessage(e))
      }
    )

    metrics <- .qdesn_ms_read_metrics(
      out_dir_stage,
      objective = ms_block$objective %||% list()
    )

    list(
      spec_id = spec_id,
      theta   = theta,
      status  = if (!is.null(res_run$status) && res_run$status == 0L) "ok" else "failed",
      score   = metrics$score,
      score_components = metrics$components,
      stdout  = res_run$stdout
    )
  }

  # Parallel over rows of cand_tbl
  oplan <- future::plan()
  on.exit(future::plan(oplan), add = TRUE)

  if (n_workers > 1L) {
    future::plan(future::multisession, workers = n_workers)
    results_tune <- future.apply::future_lapply(
      seq_len(nrow(cand_tbl)),
      function(i) eval_one_tune(cand_tbl[i, , drop = FALSE])
    )
  } else {
    results_tune <- lapply(
      seq_len(nrow(cand_tbl)),
      function(i) eval_one_tune(cand_tbl[i, , drop = FALSE])
    )
  }

  # Aggregate results
  res_tune_tbl <- purrr::map_dfr(results_tune, function(r) {
    tibble::tibble(
      spec_id = r$spec_id,
      status  = r$status,
      score   = r$score,
      D       = r$theta$D,
      m       = r$theta$m,
      alpha   = r$theta$alpha,
      rho     = r$theta$rho,
      pi_w    = r$theta$pi_w,
      pi_in   = r$theta$pi_in,
      washout = r$theta$washout,
      n       = paste(r$theta$n, collapse = ","),
      n_tilde = paste(r$theta$n_tilde, collapse = ",")
    )
  })

  # Log to file
  writeLines(
    c(
      sprintf("# log for tune_name=%s", tune_name),
      paste0(
        res_tune_tbl$spec_id, " | status=", res_tune_tbl$status,
        " | score=", format(res_tune_tbl$score, digits = 6)
      )
    ),
    con = log_file
  )

  # Save candidates summary
  readr::write_csv(
    res_tune_tbl,
    file = file.path(out_ms_root, "summary_candidates.csv")
  )

  # ------------------------------------------------------------
  # 4) Select best candidate (min score) and run test stage
  # ------------------------------------------------------------
  ok_tbl <- res_tune_tbl |>
    dplyr::filter(.data$status == "ok", is.finite(.data$score))

  if (!nrow(ok_tbl)) {
    warning("qdesn_model_selection(): no successful candidates; returning tuning table only.")
    return(list(
      tune_name  = tune_name,
      split      = list(train_n = train_n, verify_n = verify_n, test_n = test_n),
      candidates = res_tune_tbl,
      best       = NULL
    ))
  }

  best_row <- ok_tbl |>
    dplyr::arrange(.data$score) |>
    dplyr::slice(1L)

  spec_id_star <- best_row$spec_id
  theta_star   <- .qdesn_ms_row_to_theta(best_row)

  if (isTRUE(verbose)) {
    message(sprintf(
      "[qdesn_model_selection] best spec_id=%s | score_tune=%.6f",
      spec_id_star, best_row$score
    ))
  }

  # Test stage: train + verify + test
  out_dir_test <- file.path(out_ms_root, spec_id_star, "test")
  dir.create(out_dir_test, recursive = TRUE, showWarnings = FALSE)

  cfg_test <- base_cfg
  cfg_test$desn  <- .qdesn_ms_apply_theta_to_desn(theta_star, base_cfg$desn %||% list())
  cfg_test$split <- split_test

  cfg_test$forecast <- cfg_test$forecast %||% list()
  cfg_test$forecast$rolling_origin <- TRUE
  cfg_test$forecast$H_step         <- 1L

  res_run_test <- tryCatch(
    {
      run_esn_pipeline_from_cfg(
        cfg       = cfg_test,
        file_long = file_long,
        file_obs  = file_obs,
        out_dir   = out_dir_test,
        repo_root = repo_root,
        save_outputs = FALSE,   # minimal-output mode for test evaluation
        verbose   = FALSE
      )
    },
    error = function(e) {
      list(status = 1L, stdout = conditionMessage(e))
    }
  )

  metrics_test <- .qdesn_ms_read_metrics(
    out_dir_test,
    objective = ms_block$objective %||% list()
  )

  # Save best spec as a YAML fragment
  best_spec_yaml <- list(desn = .qdesn_ms_apply_theta_to_desn(theta_star, list()))
  yaml::write_yaml(
    best_spec_yaml,
    file.path(out_ms_root, "best_spec.yaml")
  )

  list(
    tune_name  = tune_name,
    split      = list(train_n = train_n, verify_n = verify_n, test_n = test_n),
    candidates = res_tune_tbl,
    best       = list(
      spec_id      = spec_id_star,
      theta        = theta_star,
      score_tune   = best_row$score,
      score_test   = metrics_test$score,
      metrics_test = metrics_test$components,  # full metrics_summary for the test run
      status_test  = if (!is.null(res_run_test$status) && res_run_test$status == 0L) "ok" else "failed"
    )
  )
}

# -------------------------------------------------------------------
# Helpers (internal)
# -------------------------------------------------------------------

`%||%` <- function(x, alt) if (!is.null(x)) x else alt

.qdesn_ms_resolve_split <- function(split_cfg, T_full) {
  use_last     <- isTRUE(split_cfg$use_last %||% TRUE)
  T_total_use  <- split_cfg$T_total_use %||% T_full

  train_prop  <- split_cfg$train_prop  %||% NULL
  verify_prop <- split_cfg$verify_prop %||% NULL
  test_prop   <- split_cfg$test_prop   %||% NULL

  train_n  <- split_cfg$train_n  %||% NULL
  verify_n <- split_cfg$verify_n %||% NULL
  test_n   <- split_cfg$test_n   %||% NULL

  T_total_use <- min(T_full, as.integer(T_total_use))

  # If explicit n's are provided, use them directly
  if (!is.null(train_n) && !is.null(verify_n) && !is.null(test_n)) {
    train_n  <- as.integer(train_n)
    verify_n <- as.integer(verify_n)
    test_n   <- as.integer(test_n)
  } else {
    # Use proportions; default verify/test = split remaining equally if not provided
    if (is.null(train_prop)) {
      train_prop <- 0.6
    }
    remaining_prop <- 1 - train_prop
    if (remaining_prop <= 0) {
      stop("split_cfg$train_prop must be in (0,1).")
    }
    if (is.null(verify_prop) && is.null(test_prop)) {
      verify_prop <- remaining_prop / 2
      test_prop   <- remaining_prop / 2
    } else if (is.null(verify_prop)) {
      test_prop   <- as.numeric(test_prop)
      verify_prop <- remaining_prop - test_prop
    } else if (is.null(test_prop)) {
      verify_prop <- as.numeric(verify_prop)
      test_prop   <- remaining_prop - verify_prop
    }

    if (verify_prop <= 0 || test_prop <= 0) {
      stop("Invalid verify_prop/test_prop; must be positive.")
    }

    train_n  <- max(1L, floor(train_prop  * T_total_use))
    verify_n <- max(1L, floor(verify_prop * T_total_use))
    test_n   <- max(1L, T_total_use - train_n - verify_n)
  }

  if (train_n + verify_n + test_n > T_total_use) {
    stop("train_n + verify_n + test_n exceeds T_total_use.")
  }
  if (train_n < 1L || verify_n < 1L || test_n < 1L) {
    stop("All of train_n, verify_n, test_n must be >= 1.")
  }

  list(
    train_n  = as.integer(train_n),
    verify_n = as.integer(verify_n),
    test_n   = as.integer(test_n),
    T_total_use = as.integer(T_total_use),
    use_last = use_last
  )
}

.qdesn_ms_generate_candidates <- function(esn_space, search_cfg, verbose = TRUE) {
  # Basic fields
  D_vals       <- as.integer(esn_space$D %||% 1L)
  m_vals       <- as.integer(esn_space$m %||% 50L)
  alpha_vals   <- as.numeric(esn_space$alpha %||% 0.2)
  rho_vals     <- as.numeric(esn_space$rho %||% 0.95)
  pi_w_vals    <- as.numeric(esn_space$pi_w %||% 0.05)
  pi_in_vals   <- as.numeric(esn_space$pi_in %||% 1.0)
  washout_vals <- as.integer(esn_space$washout %||% 500L)

  # n / n_tilde are potentially vector-valued per D
  n_list       <- esn_space$n       %||% list()
  ntilde_list  <- esn_space$n_tilde %||% list()

  if (!is.list(n_list)) n_list <- as.list(n_list)
  if (!is.list(ntilde_list)) ntilde_list <- as.list(ntilde_list)

  if (length(n_list) != length(D_vals) || length(ntilde_list) != length(D_vals)) {
    stop("esn_space$n and esn_space$n_tilde must have length equal to length(D).")
  }

  # Create an index over combined n / n_tilde options per D
  grid_base <- expand.grid(
    idx_D    = seq_along(D_vals),
    idx_m    = seq_along(m_vals),
    idx_a    = seq_along(alpha_vals),
    idx_rho  = seq_along(rho_vals),
    idx_pi_w = seq_along(pi_w_vals),
    idx_pi_in= seq_along(pi_in_vals),
    idx_w    = seq_along(washout_vals),
    stringsAsFactors = FALSE
  )

  grid_base$idx_n <- grid_base$idx_D  # each D index maps to one n/n_tilde combination

  N_total <- nrow(grid_base)

  method         <- tolower(search_cfg$method %||% "random")
  max_candidates <- as.integer(search_cfg$max_candidates %||% N_total)
  allow_repeats  <- isTRUE(search_cfg$allow_repeats %||% FALSE)
  seed           <- search_cfg$seed %||% NULL

  if (!is.null(seed)) set.seed(as.integer(seed))

  if (identical(method, "grid") || N_total <= max_candidates) {
    idx_choose <- seq_len(min(N_total, max_candidates))
  } else {
    if (allow_repeats) {
      idx_choose <- sample.int(N_total, size = max_candidates, replace = TRUE)
    } else {
      idx_choose <- sample.int(N_total, size = max_candidates, replace = FALSE)
    }
  }

  grid_sub <- grid_base[idx_choose, , drop = FALSE]

  tb <- tibble::tibble(
    spec_id = character(nrow(grid_sub)),
    D       = integer(nrow(grid_sub)),
    m       = integer(nrow(grid_sub)),
    alpha   = numeric(nrow(grid_sub)),
    rho     = numeric(nrow(grid_sub)),
    pi_w    = numeric(nrow(grid_sub)),
    pi_in   = numeric(nrow(grid_sub)),
    washout = integer(nrow(grid_sub)),
    n       = vector("list", length = nrow(grid_sub)),
    n_tilde = vector("list", length = nrow(grid_sub))
  )

  for (i in seq_len(nrow(grid_sub))) {
    r <- grid_sub[i, ]
    D_i   <- D_vals[r$idx_D]
    n_i   <- as.integer(unlist(n_list[[r$idx_D]]))
    nt_i  <- as.integer(unlist(ntilde_list[[r$idx_D]]))

    # Basic sanity: if D=1, n_tilde should be length 0 or 1; enforce length 0 here
    if (D_i == 1L && length(nt_i) > 0L) {
      nt_i <- integer(0)
    }

    spec_id <- sprintf(
      "D%d_m%d_a%.3f_r%.3f_piW%.3f_piIn%.3f_w%d_idx%03d",
      D_i, m_vals[r$idx_m], alpha_vals[r$idx_a], rho_vals[r$idx_rho],
      pi_w_vals[r$idx_pi_w], pi_in_vals[r$idx_pi_in],
      washout_vals[r$idx_w], i
    )

    tb$spec_id[i] <- spec_id
    tb$D[i]       <- D_i
    tb$m[i]       <- m_vals[r$idx_m]
    tb$alpha[i]   <- alpha_vals[r$idx_a]
    tb$rho[i]     <- rho_vals[r$idx_rho]
    tb$pi_w[i]    <- pi_w_vals[r$idx_pi_w]
    tb$pi_in[i]   <- pi_in_vals[r$idx_pi_in]
    tb$washout[i] <- washout_vals[r$idx_w]
    tb$n[[i]]     <- n_i
    tb$n_tilde[[i]] <- nt_i
  }

  if (isTRUE(verbose)) {
    message(sprintf(
      "[qdesn_model_selection] esn candidates: N_total=%d | N_used=%d (method=%s)",
      N_total, nrow(tb), method
    ))
  }

  tb
}

.qdesn_ms_row_to_theta <- function(row) {
  list(
    D       = as.integer(row$D),
    m       = as.integer(row$m),
    alpha   = as.numeric(row$alpha),
    rho     = as.numeric(row$rho),
    pi_w    = as.numeric(row$pi_w),
    pi_in   = as.numeric(row$pi_in),
    washout = as.integer(row$washout),
    n       = as.integer(if (is.list(row$n)) row$n[[1]] else strsplit(row$n, ",")[[1]]),
    n_tilde = as.integer(if (is.list(row$n_tilde)) row$n_tilde[[1]] else {
      z <- strsplit(row$n_tilde, ",")[[1]]
      if (length(z) == 1L && nzchar(z)) as.integer(z) else integer(0)
    })
  )
}

.qdesn_ms_apply_theta_to_desn <- function(theta, desn_base) {
  d <- desn_base %||% list()
  d$D       <- theta$D
  d$n       <- theta$n
  d$n_tilde <- theta$n_tilde
  d$m       <- theta$m
  d$alpha   <- theta$alpha
  d$rho     <- theta$rho
  d$pi_w    <- theta$pi_w
  d$pi_in   <- theta$pi_in
  d$washout <- theta$washout
  d$add_bias <- if (is.null(d$add_bias)) TRUE else d$add_bias
  d
}

.qdesn_ms_read_metrics <- function(out_dir_stage, objective) {
  tables_dir   <- file.path(out_dir_stage, "tables")
  metrics_file <- file.path(tables_dir, "metrics_summary.csv")

  if (!file.exists(metrics_file)) {
    warning("metrics_summary.csv not found in ", tables_dir)
    return(list(
      score = NA_real_,
      components = NULL
    ))
  }

  mm <- tryCatch(
    readr::read_csv(metrics_file, show_col_types = FALSE),
    error = function(e) NULL
  )
  if (is.null(mm) || !nrow(mm)) {
    warning("metrics_summary.csv is empty or unreadable in ", tables_dir)
    return(list(score = NA_real_, components = NULL))
  }

  metric_name <- tolower(objective$metric %||% "crps_synth")
  window      <- objective$window %||% "verification"
  aggregation <- objective$aggregation %||% "mean_time"

  # Map 'verification' → scope 'forecast' (pipeline uses 'forecast' as scope label)
  scope_target <- if (identical(window, "verification")) "forecast" else window

  # Treat crps vs crps_synth as synonyms
  allowed_scores <- if (metric_name %in% c("crps", "crps_synth")) {
    c("crps", "crps_synth")
  } else {
    metric_name
  }

  if (!all(c("scope", "component", "score", "value") %in% names(mm))) {
    stop(
      "metrics_summary.csv must contain columns 'scope', 'component', 'score', 'value'. ",
      "If yours uses different column names, adjust .qdesn_ms_read_metrics()."
    )
  }

  row_filt <- mm |>
    dplyr::filter(
      .data$scope == scope_target,
      .data$component == "synth",
      tolower(.data$score) %in% allowed_scores
    )

  if (!nrow(row_filt)) {
    warning("No matching rows for metric ", paste(allowed_scores, collapse = "/"),
            " in metrics_summary.csv for scope=", scope_target)
    return(list(score = NA_real_, components = mm))
  }

  score_vec <- as.numeric(row_filt$value)
  if (!any(is.finite(score_vec))) {
    return(list(score = NA_real_, components = mm))
  }

  score <- switch(
    aggregation,
    "mean_time"   = mean(score_vec, na.rm = TRUE),
    "median_time" = stats::median(score_vec, na.rm = TRUE),
    mean(score_vec, na.rm = TRUE)
  )

  # components = full metrics table, so you can inspect quantile scores, coverages, etc.
  list(
    score      = score,
    components = mm
  )
}
