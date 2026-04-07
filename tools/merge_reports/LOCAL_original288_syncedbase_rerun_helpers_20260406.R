source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

rbind_fill_original288_syncedbase_rerun <- function(parts) {
  if (!length(parts)) return(data.frame())
  cols <- unique(unlist(lapply(parts, names), use.names = FALSE))
  norm <- lapply(parts, function(d) {
    miss <- setdiff(cols, names(d))
    if (length(miss)) {
      for (m in miss) d[[m]] <- NA
    }
    d[, cols, drop = FALSE]
  })
  out <- do.call(rbind, norm)
  rownames(out) <- NULL
  out
}

run_tag_original288_syncedbase_rerun <- function() {
  "original288_syncedbase_rerun_20260406"
}

variant_tag_original288_syncedbase_rerun <- function() {
  "orig288_sync0p4p0_reval_20260406"
}

phase_order_original288_syncedbase_rerun <- c(
  phase1_vb_all = 1L,
  phase2_static_mcmc = 2L,
  phase3_dynamic_mcmc = 3L
)

reference_status_original288_syncedbase_rerun <- function() {
  list(
    total = 288L,
    pass = 195L,
    warn = 87L,
    fail = 6L,
    healthy = 282L
  )
}

source_worktree_original288_syncedbase_rerun <- function() {
  "/home/jaguir26/local/src/exdqlm__wt__dqlm-conjugacy-cavi-gibbs"
}

paths_original288_syncedbase_rerun <- function() {
  tag <- run_tag_original288_syncedbase_rerun()
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", tag))
  list(
    accepted_selection = "tools/merge_reports/LOCAL_original288_carryforward_selection_v4_20260406.csv",
    source_registry = "tools/merge_reports/LOCAL_original288_registry_syncedbase_source_v1_20260406.csv",
    manifest = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_manifest_20260406.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_stage_counts_20260406.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_manifest_status_20260406.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_phase_summary_20260406.csv",
    block_summary = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_block_summary_20260406.csv",
    accepted_compare = "tools/merge_reports/LOCAL_original288_syncedbase_rerun_accepted_compare_20260406.csv",
    config_dir = file.path(run_dir, "configs"),
    tracker_doc = "reports/static_exal_tuning_20260406/integration_branch_validation_status_20260406.md",
    program_doc = "reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_program_20260406.md",
    execution_doc = "reports/static_exal_tuning_20260406/original_288_syncedbase_rerun_execution_20260406.md"
  )
}

safe_chr_original288_syncedbase_rerun <- function(x, default = NA_character_) {
  if (is.null(x) || !length(x)) return(default)
  y <- as.character(x)[1]
  if (!nzchar(y)) default else y
}

safe_int_original288_syncedbase_rerun <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_num_original288_syncedbase_rerun <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

safe_flag_original288_syncedbase_rerun <- function(x, default = FALSE) {
  if (is.null(x) || !length(x)) return(default)
  if (is.logical(x)) return(isTRUE(x[1]))
  tolower(as.character(x)[1]) %in% c("1", "true", "yes", "y", "t")
}

ensure_dir_original288_syncedbase_rerun <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

tau_num_from_label_original288_syncedbase_rerun <- function(x) {
  raw <- safe_chr_original288_syncedbase_rerun(x, NA_character_)
  if (is.na(raw)) return(NA_real_)
  suppressWarnings(as.numeric(gsub("p", ".", raw, fixed = TRUE)))
}

resolve_selected_fit_original288_syncedbase_rerun <- function(obj) {
  obj$fit %||% obj
}

read_accepted_selection_original288_syncedbase_rerun <- function() {
  x <- read.csv(
    paths_original288_syncedbase_rerun()$accepted_selection,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  x$tau_label <- vapply(x$tau, tau_to_label_original288, character(1))
  x$tau_num <- vapply(x$tau, tau_num_from_label_original288_syncedbase_rerun, numeric(1))
  phase_vec <- mapply(
    expected_phase_original288_syncedbase_rerun,
    x$inference,
    x$root_kind,
    USE.NAMES = FALSE
  )
  x <- x[order(
    match(phase_vec, names(phase_order_original288_syncedbase_rerun)),
    x$root_kind,
    x$family,
    x$tau_label,
    x$fit_size,
    x$prior_semantics,
    x$model,
    x$inference
  ), , drop = FALSE]
  rownames(x) <- NULL
  x
}

validate_reference_status_original288_syncedbase_rerun <- function(accepted) {
  ref <- reference_status_original288_syncedbase_rerun()
  stopifnot(nrow(accepted) == ref$total)
  stopifnot(sum(accepted$gate_overall == "PASS") == ref$pass)
  stopifnot(sum(accepted$gate_overall == "WARN") == ref$warn)
  stopifnot(sum(accepted$gate_overall == "FAIL") == ref$fail)
  stopifnot(sum(accepted$healthy) == ref$healthy)
  invisible(TRUE)
}

expected_phase_original288_syncedbase_rerun <- function(inference, root_kind) {
  if (identical(inference, "vb")) return("phase1_vb_all")
  if (root_kind %in% c("static_paper", "static_shrink", "static")) return("phase2_static_mcmc")
  if (identical(root_kind, "dynamic")) return("phase3_dynamic_mcmc")
  "phase_unknown"
}

source_signoff_paths_original288_syncedbase_rerun <- function(source_root = source_worktree_original288_syncedbase_rerun()) {
  roots <- file.path(
    source_root,
    c(
      "results/function_testing_20260309_static_paper_family_qspec",
      "results/function_testing_20260309_static_shrinkage_family_qspec",
      "results/function_testing_20260309_dynamic_dlm_family_qspec"
    )
  )
  sort(unlist(lapply(roots, function(root) {
    list.files(root, pattern = "method_signoff_long\\.csv$", recursive = TRUE, full.names = TRUE)
  })))
}

read_source_registry_original288_syncedbase_rerun <- function(source_root = source_worktree_original288_syncedbase_rerun()) {
  files <- source_signoff_paths_original288_syncedbase_rerun(source_root)
  rows <- lapply(files, function(path) {
    x <- read.csv(path, stringsAsFactors = FALSE)
    tau_label <- tau_to_label_original288(x$tau)
    signoff_path <- normalize_path_original288(path)
    fit_paths <- vapply(
      seq_len(nrow(x)),
      function(i) infer_baseline_fit_path_original288(signoff_path, x$inference[i], x$model[i], tau_label[i]),
      character(1)
    )

    data.frame(
      block = x$root_kind,
      root_kind = x$root_kind,
      family = x$family,
      tau = tau_label,
      fit_size = as.integer(x$fit_size),
      prior_semantics = x$prior,
      model = x$model,
      inference = x$inference,
      method = x$method,
      root_id = x$root_id,
      original_scenario_key = mapply(
        make_original_scenario_key_original288,
        x$root_kind,
        x$family,
        tau_label,
        as.integer(x$fit_size),
        x$prior,
        USE.NAMES = FALSE
      ),
      original_case_key = mapply(
        make_original_case_key_original288,
        x$root_kind,
        x$family,
        tau_label,
        as.integer(x$fit_size),
        x$prior,
        x$model,
        x$inference,
        USE.NAMES = FALSE
      ),
      baseline_signoff_path = signoff_path,
      baseline_fit_path = fit_paths,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  phase_vec <- mapply(
    expected_phase_original288_syncedbase_rerun,
    out$inference,
    out$root_kind,
    USE.NAMES = FALSE
  )
  out <- out[order(
    match(phase_vec, names(phase_order_original288_syncedbase_rerun)),
    out$root_kind,
    out$family,
    out$tau,
    out$fit_size,
    out$prior_semantics,
    out$model,
    out$inference
  ), , drop = FALSE]
  out
}

source_context_from_signoff_original288_syncedbase_rerun <- function(signoff_path) {
  signoff_path <- normalize_path_original288(signoff_path)
  run_root <- dirname(dirname(signoff_path))
  list(
    baseline_signoff_path = signoff_path,
    source_run_root = run_root,
    source_run_config_path = normalize_path_original288(file.path(dirname(signoff_path), "run_config.rds")),
    source_sim_output_path = normalize_path_original288(file.path(dirname(run_root), "sim_output.rds"))
  )
}

target_run_root_original288_syncedbase_rerun <- function(source_run_root, repo_root) {
  source_root <- normalize_path_original288(source_worktree_original288_syncedbase_rerun())
  repo_root <- normalize_path_original288(repo_root)
  rel <- sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", source_root), "/"), "", normalize_path_original288(source_run_root), perl = TRUE)
  normalize_path_original288(file.path(repo_root, rel))
}

candidate_fit_path_original288_syncedbase_rerun <- function(run_root, inference, model, tau_label) {
  normalize_path_original288(file.path(
    run_root,
    "fits",
    inference,
    sprintf("%s_%s_tau_%s_fit_%s.rds", inference, model, tau_label, variant_tag_original288_syncedbase_rerun())
  ))
}

vb_candidate_fit_path_original288_syncedbase_rerun <- function(run_root, model, tau_label) {
  candidate_fit_path_original288_syncedbase_rerun(run_root, "vb", model, tau_label)
}

config_path_original288_syncedbase_rerun <- function(row_id) {
  file.path(paths_original288_syncedbase_rerun()$config_dir, sprintf("row_%04d_run_config.rds", as.integer(row_id)))
}

extract_selected_seed_original288_syncedbase_rerun <- function(obj, fallback_seed) {
  fit <- resolve_selected_fit_original288_syncedbase_rerun(obj)
  seed <- obj$meta$seed %||% obj$seed %||% fit$seed %||% fallback_seed
  safe_int_original288_syncedbase_rerun(seed, fallback_seed)
}

dynamic_mcmc_config_from_selected_fit_original288_syncedbase_rerun <- function(cfg, obj) {
  fit <- resolve_selected_fit_original288_syncedbase_rerun(obj)
  mhd <- fit$mh.diagnostics %||% list()

  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$burn <- safe_int_original288_syncedbase_rerun(fit$n.burn %||% cfg$mcmc$burn, 2000L)
  cfg$mcmc$n <- safe_int_original288_syncedbase_rerun(fit$n.mcmc %||% cfg$mcmc$n, 1500L)
  cfg$mcmc$init_from_vb <- safe_flag_original288_syncedbase_rerun(fit$init.from.vb %||% TRUE, TRUE)
  cfg$mcmc$trace_every <- safe_int_original288_syncedbase_rerun(mhd$trace_every %||% cfg$mcmc$trace_every, 50L)

  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()
  cfg$mcmc$mh$proposal <- safe_chr_original288_syncedbase_rerun(mhd$proposal, cfg$mcmc$mh$proposal %||% "laplace_rw")
  cfg$mcmc$mh$primary_proposal <- cfg$mcmc$mh$proposal
  cfg$mcmc$mh$joint_sample <- safe_flag_original288_syncedbase_rerun(mhd$joint_sample %||% cfg$mcmc$mh$joint_sample, FALSE)
  cfg$mcmc$mh$primary_joint_sample <- cfg$mcmc$mh$joint_sample
  cfg$mcmc$mh$adapt <- safe_flag_original288_syncedbase_rerun(mhd$adapt %||% cfg$mcmc$mh$adapt, TRUE)
  cfg$mcmc$mh$adapt_interval <- safe_int_original288_syncedbase_rerun(mhd$adapt_interval %||% cfg$mcmc$mh$adapt_interval, 50L)
  if (!is.null(mhd$target_accept) && length(mhd$target_accept)) {
    cfg$mcmc$mh$target_accept <- as.numeric(mhd$target_accept)
  }
  if (!is.null(mhd$scale_bounds) && length(mhd$scale_bounds)) {
    cfg$mcmc$mh$scale_bounds <- as.numeric(mhd$scale_bounds)
  }
  if (is.finite(safe_num_original288_syncedbase_rerun(mhd$slice_width, NA_real_))) {
    cfg$mcmc$mh$slice_width <- safe_num_original288_syncedbase_rerun(mhd$slice_width, NA_real_)
  } else {
    cfg$mcmc$mh$slice_width <- NULL
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(mhd$slice_max_steps, NA_integer_))) {
    cfg$mcmc$mh$slice_max_steps <- safe_int_original288_syncedbase_rerun(mhd$slice_max_steps, NA_integer_)
  } else {
    cfg$mcmc$mh$slice_max_steps <- NULL
  }

  laplace_refresh <- mhd$laplace_refresh %||% list()
  refresh_interval <- laplace_refresh$interval %||% laplace_refresh$refresh_interval %||% laplace_refresh$laplace_refresh_interval
  refresh_start <- laplace_refresh$start %||% laplace_refresh$start_iter %||% laplace_refresh$refresh_start %||% laplace_refresh$laplace_refresh_start
  refresh_weight <- laplace_refresh$weight %||% laplace_refresh$refresh_weight %||% laplace_refresh$laplace_refresh_weight
  if (is.finite(safe_int_original288_syncedbase_rerun(refresh_interval, NA_integer_))) {
    cfg$mcmc$mh$laplace_refresh_interval <- safe_int_original288_syncedbase_rerun(refresh_interval, NA_integer_)
  }
  if (is.finite(safe_int_original288_syncedbase_rerun(refresh_start, NA_integer_))) {
    cfg$mcmc$mh$laplace_refresh_start <- safe_int_original288_syncedbase_rerun(refresh_start, NA_integer_)
  }
  if (is.finite(safe_num_original288_syncedbase_rerun(refresh_weight, NA_real_))) {
    cfg$mcmc$mh$laplace_refresh_weight <- safe_num_original288_syncedbase_rerun(refresh_weight, NA_real_)
  }

  cfg
}

static_mcmc_config_from_selected_fit_original288_syncedbase_rerun <- function(cfg, obj) {
  fit <- resolve_selected_fit_original288_syncedbase_rerun(obj)
  settings <- obj$normalized$metadata$settings %||% list()
  mh_settings <- settings$mh %||% list()

  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$burn <- safe_int_original288_syncedbase_rerun(settings$n_burn %||% fit$n.burn %||% cfg$mcmc$burn, 3000L)
  cfg$mcmc$n <- safe_int_original288_syncedbase_rerun(settings$n_mcmc %||% fit$n.mcmc %||% cfg$mcmc$n, 8000L)
  cfg$mcmc$thin <- safe_int_original288_syncedbase_rerun(settings$thin %||% fit$thin %||% cfg$mcmc$thin, 1L)

  beta_prior_type <- settings$beta_prior %||% fit$beta_prior$type %||% fit$beta_prior
  if (!is.null(beta_prior_type) && length(beta_prior_type)) {
    cfg$mcmc$beta_prior <- as.character(beta_prior_type)[1]
  }

  beta_prior_controls <- settings$beta_prior_controls %||% fit$beta_prior$controls %||% NULL
  if (!is.null(beta_prior_controls) && length(beta_prior_controls)) {
    cfg$mcmc$beta_prior_controls <- beta_prior_controls
  }

  cfg$mcmc$init_from_vb <- safe_flag_original288_syncedbase_rerun(fit$init.from.vb %||% cfg$mcmc$init_from_vb %||% TRUE, TRUE)
  cfg$mcmc$trace_every <- safe_int_original288_syncedbase_rerun(mh_settings$trace_every %||% cfg$mcmc$trace_every, 50L)

  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()
  cfg$mcmc$mh$proposal <- safe_chr_original288_syncedbase_rerun(mh_settings$proposal, cfg$mcmc$mh$proposal %||% "laplace_rw")
  cfg$mcmc$mh$primary_proposal <- cfg$mcmc$mh$proposal
  cfg$mcmc$mh$adapt <- safe_flag_original288_syncedbase_rerun(mh_settings$adapt %||% cfg$mcmc$mh$adapt, TRUE)
  cfg$mcmc$mh$adapt_interval <- safe_int_original288_syncedbase_rerun(mh_settings$adapt_interval %||% cfg$mcmc$mh$adapt_interval, 50L)
  if (!is.null(mh_settings$target_accept) && length(mh_settings$target_accept)) {
    cfg$mcmc$mh$target_accept <- as.numeric(mh_settings$target_accept)
  }
  if (!is.null(mh_settings$scale_bounds) && length(mh_settings$scale_bounds)) {
    cfg$mcmc$mh$scale_bounds <- as.numeric(mh_settings$scale_bounds)
  }
  cfg$mcmc$mh$trace_diagnostics <- safe_flag_original288_syncedbase_rerun(mh_settings$trace_diagnostics %||% TRUE, TRUE)
  cfg$mcmc$mh$trace_every <- safe_int_original288_syncedbase_rerun(mh_settings$trace_every %||% cfg$mcmc$mh$trace_every, 50L)

  cfg
}

static_vb_config_from_selected_fit_original288_syncedbase_rerun <- function(cfg, obj) {
  fit <- resolve_selected_fit_original288_syncedbase_rerun(obj)
  cfg$vb <- cfg$vb %||% list()
  beta_prior_type <- fit$beta_prior$type %||% fit$beta_prior
  if (!is.null(beta_prior_type) && length(beta_prior_type)) {
    cfg$vb$beta_prior <- as.character(beta_prior_type)[1]
  }
  beta_prior_controls <- fit$beta_prior$controls %||% NULL
  if (!is.null(beta_prior_controls) && length(beta_prior_controls)) {
    cfg$vb$beta_prior_controls <- beta_prior_controls
  }
  cfg
}

build_selected_config_original288_syncedbase_rerun <- function(base_cfg, row) {
  if (identical(row$selection_mode, "baseline_kept")) {
    return(base_cfg)
  }

  if (identical(row$inference, "vb") && identical(row$root_kind, "dynamic")) {
    return(base_cfg)
  }

  cfg <- base_cfg
  obj <- readRDS(row$selected_fit_path)

  if (identical(row$inference, "vb")) {
    if (row$root_kind %in% c("static_paper", "static_shrink", "static")) {
      return(static_vb_config_from_selected_fit_original288_syncedbase_rerun(cfg, obj))
    }
    return(cfg)
  }

  if (!identical(row$inference, "mcmc")) {
    return(cfg)
  }

  if (identical(row$root_kind, "dynamic")) {
    return(dynamic_mcmc_config_from_selected_fit_original288_syncedbase_rerun(cfg, obj))
  }

  static_mcmc_config_from_selected_fit_original288_syncedbase_rerun(cfg, obj)
}

selected_fit_needed_original288_syncedbase_rerun <- function(row) {
  if (identical(row$selection_mode, "baseline_kept")) return(FALSE)
  if (identical(row$inference, "vb") && identical(row$root_kind, "dynamic")) return(FALSE)
  TRUE
}

prior_override_original288_syncedbase_rerun <- function(cfg, row) {
  if (identical(row$root_kind, "dynamic")) {
    return("default")
  }

  prior_val <- if (identical(row$inference, "vb")) {
    cfg$vb$beta_prior %||% NA_character_
  } else {
    cfg$mcmc$beta_prior %||% NA_character_
  }
  prior_chr <- safe_chr_original288_syncedbase_rerun(prior_val, NA_character_)
  if (is.na(prior_chr)) {
    return("default")
  }
  prior_chr
}

accepted_compare_status_original288_syncedbase_rerun <- function(current_gate, accepted_gate) {
  if (is.na(current_gate) || !nzchar(current_gate) || identical(current_gate, "MISSING")) {
    return("pending")
  }
  cur_rank <- gate_rank_original288(current_gate)
  acc_rank <- gate_rank_original288(accepted_gate)
  if (cur_rank < acc_rank) return("better_than_accepted")
  if (cur_rank > acc_rank) return("worse_than_accepted")
  "matches_accepted"
}

read_original288_syncedbase_rerun_status <- function(manifest_path = paths_original288_syncedbase_rerun()$manifest,
                                                     run_tag = run_tag_original288_syncedbase_rerun()) {
  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  run_dir <- file.path("tools", "merge_reports", sprintf("full288_%s", run_tag))
  rows_dir <- file.path(run_dir, "rows")

  parts <- list()
  if (dir.exists(rows_dir)) {
    row_files <- list.files(rows_dir, pattern = "^row_[0-9]+\\.csv$", full.names = TRUE)
    if (length(row_files)) {
      parts <- lapply(row_files, function(p) tryCatch(read.csv(p, stringsAsFactors = FALSE), error = function(e) NULL))
      parts <- Filter(Negate(is.null), parts)
    }
  }

  rows <- rbind_fill_original288_syncedbase_rerun(parts)
  if (nrow(rows)) {
    merged <- merge(manifest, rows, by = "row_id", all.x = TRUE, suffixes = c("_manifest", "_row"))
  } else {
    merged <- manifest
  }

  if (!("status" %in% names(merged))) merged$status <- NA_character_
  if (!("gate_overall" %in% names(merged))) merged$gate_overall <- NA_character_
  if (!("healthy" %in% names(merged))) merged$healthy <- NA
  if (!("runtime_sec" %in% names(merged))) merged$runtime_sec <- NA_real_

  if ("status_row" %in% names(merged)) {
    merged$status <- ifelse(!is.na(merged$status_row) & nzchar(merged$status_row), merged$status_row, merged$status)
  }
  if ("gate_overall_row" %in% names(merged)) {
    merged$gate_overall <- ifelse(!is.na(merged$gate_overall_row) & nzchar(merged$gate_overall_row), merged$gate_overall_row, merged$gate_overall)
  }
  if ("healthy_row" %in% names(merged)) {
    merged$healthy <- ifelse(!is.na(merged$healthy_row), merged$healthy_row, merged$healthy)
  }
  if ("runtime_sec_row" %in% names(merged)) {
    merged$runtime_sec <- ifelse(!is.na(merged$runtime_sec_row), merged$runtime_sec_row, merged$runtime_sec)
  }

  for (nm in c("inference", "model", "root_kind", "family", "tau_label", "baseline_fit_path", "candidate_fit_path")) {
    manifest_nm <- paste0(nm, "_manifest")
    if (!(nm %in% names(merged)) && manifest_nm %in% names(merged)) {
      merged[[nm]] <- merged[[manifest_nm]]
    }
  }

  merged$state <- ifelse(is.na(merged$status) | !nzchar(merged$status), "pending", merged$status)
  merged$gate_current <- ifelse(
    merged$state %in% c("done", "skipped_existing", "failed_runtime", "input_missing"),
    ifelse(is.na(merged$gate_overall) | !nzchar(merged$gate_overall), "FAIL", merged$gate_overall),
    "MISSING"
  )
  merged$healthy_current <- ifelse(
    merged$state %in% c("done", "skipped_existing", "failed_runtime", "input_missing"),
    as.logical(ifelse(is.na(merged$healthy), FALSE, merged$healthy)),
    FALSE
  )
  merged$accepted_compare <- mapply(
    accepted_compare_status_original288_syncedbase_rerun,
    merged$gate_current,
    merged$accepted_gate,
    USE.NAMES = FALSE
  )
  merged
}
