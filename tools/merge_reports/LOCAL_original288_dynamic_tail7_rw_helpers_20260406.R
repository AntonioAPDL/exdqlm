source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

dynamic_tail7_rw_phase_order_original288 <- c(
  anchor7_rw_joint = 1L,
  tt500_rw_refresh4 = 2L,
  tt5000_rw_joint_long3 = 3L
)

dynamic_tail7_rw_force_original288 <- c(
  anchor7_rw_joint = 1L,
  tt500_rw_refresh4 = 1L,
  tt5000_rw_joint_long3 = 1L
)

gate_rank_dynamic_tail7_rw_original288 <- function(x) {
  ranks <- c(PASS = 3L, WARN = 2L, FAIL = 1L, MISSING = 0L)
  out <- unname(ranks[as.character(x)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

candidate_preference_rank_dynamic_tail7_rw_original288 <- function(phase) {
  ranks <- c(
    anchor7_rw_joint = 3L,
    tt500_rw_refresh4 = 2L,
    tt5000_rw_joint_long3 = 1L
  )
  out <- unname(ranks[as.character(phase)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

rbind_fill_dynamic_tail7_rw_original288 <- function(parts) {
  if (!length(parts)) return(data.frame())
  cols <- unique(unlist(lapply(parts, names), use.names = FALSE))
  norm <- lapply(parts, function(d) {
    miss <- setdiff(cols, names(d))
    if (length(miss)) {
      for (m in miss) d[[m]] <- NA
    }
    d[, cols, drop = FALSE]
  })
  do.call(rbind, norm)
}

paths_dynamic_tail7_rw_original288 <- function() {
  list(
    manifest = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_manifest_20260406.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_stage_counts_20260406.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_manifest_status_20260406.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_phase_summary_20260406.csv",
    config_summary = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_config_summary_20260406.csv",
    case_best = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_case_best_20260406.csv",
    unresolved_after_run = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_unresolved_after_run_20260406.csv",
    selection_update = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_selection_update_20260406.csv",
    selection_delta = "tools/merge_reports/LOCAL_original288_dynamic_tail7_rw_selection_delta_20260406.csv",
    carryforward_preview = "tools/merge_reports/LOCAL_original288_carryforward_selection_dynamic_tail7_rw_preview_20260406.csv",
    health_summary_preview = "tools/merge_reports/LOCAL_original288_health_summary_dynamic_tail7_rw_preview_20260406.csv",
    tracker = "tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md",
    plan_doc = "reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_program_20260406.md",
    execution_doc = "reports/static_exal_tuning_20260406/original_288_dynamic_tail7_rw_joint_execution_20260406.md"
  )
}

run_tag_dynamic_tail7_rw_original288 <- function() {
  "original288_dynamic_tail7_rw_20260406"
}

build_candidate_fit_path_dynamic_tail7_rw_original288 <- function(baseline_fit_path, variant_tag) {
  sub("\\.rds$", paste0("_", variant_tag, ".rds"), normalize_path_original288(baseline_fit_path))
}

full288_seed_map_dynamic_tail7_rw_original288 <- function() {
  manifest_path <- "tools/merge_reports/LOCAL_full288_manifest_rhsns_full_relaunch_20260327.csv"
  if (!file.exists(manifest_path)) {
    return(data.frame(original_case_key = character(0), seed_full288 = integer(0), stringsAsFactors = FALSE))
  }
  x <- read.csv(manifest_path, stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(x)), function(i) {
    mapped <- parse_original_key_from_fit_path_original288(
      x$baseline_fit_path[i],
      model_fallback = x$model[i],
      inference_fallback = x$inference[i]
    )
    if (!nrow(mapped)) return(NULL)
    data.frame(
      original_case_key = mapped$original_case_key,
      seed_full288 = as.integer(x$seed[i]),
      stringsAsFactors = FALSE
    )
  })
  out <- rbind_fill_dynamic_tail7_rw_original288(Filter(Negate(is.null), rows))
  if (!nrow(out)) return(out)
  out <- out[!duplicated(out$original_case_key), , drop = FALSE]
  rownames(out) <- NULL
  out
}

read_unresolved_dynamic_original288_dynamic_tail7_rw <- function() {
  path <- "tools/merge_reports/LOCAL_original288_unresolved_dynamic_inventory_v3_20260406.csv"
  x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x <- subset(
    x,
    block == "dynamic" &
      root_kind == "dynamic" &
      model == "exdqlm" &
      inference == "mcmc" &
      selection_mode == "unresolved_baseline_fail"
  )
  rownames(x) <- NULL
  x
}

read_dynamic_vb_selection_original288_dynamic_tail7_rw <- function() {
  path <- "tools/merge_reports/LOCAL_original288_carryforward_selection_v3_20260406.csv"
  x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x <- subset(
    x,
    block == "dynamic" &
      root_kind == "dynamic" &
      model == "exdqlm" &
      inference == "vb" &
      gate_overall %in% c("PASS", "WARN")
  )
  x <- x[order(x$family, x$tau, x$fit_size), , drop = FALSE]
  rownames(x) <- NULL
  x
}

config_note_dynamic_tail7_rw_original288 <- function(config_id) {
  switch(
    config_id,
    mcmc_exdqlm_rw_joint_anchor = paste(
      "New all-tail anchor in the laplace_rw corridor: use explicit healthy",
      "same-scenario VB warm starts, enable joint covariance rebuilding after",
      "burn-in, and standardize a stronger adaptive refresh schedule."
    ),
    mcmc_exdqlm_rw_refresh_tt500 = paste(
      "Short-horizon focused follow-up: keep laplace_rw plus joint-sample",
      "rebuilding, but refresh the proposal earlier and more aggressively on",
      "the four TT500 cases where mixing-limited failures still look most",
      "salvageable."
    ),
    mcmc_exdqlm_rw_joint_tt5000_long = paste(
      "Long-horizon follow-up: retain the joint laplace_rw corridor and raise",
      "the runtime budget on TT5000 cases where the remaining issue looks more",
      "like post-burn mixing debt than an outright invalid fit."
    ),
    "Unspecified dynamic tail-7 rw config."
  )
}

apply_dynamic_tail7_rw_config_original288 <- function(cfg, config_id, fit_size) {
  cfg <- cfg %||% list()
  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()

  set_rw_core <- function(x) {
    x$mcmc$init_from_vb <- TRUE
    x$mcmc$trace_every <- 50L
    x$mcmc$mh$proposal <- "laplace_rw"
    x$mcmc$mh$joint_sample <- TRUE
    x$mcmc$mh$primary_joint_sample <- TRUE
    x$mcmc$mh$adapt <- TRUE
    x$mcmc$mh$adapt_interval <- 25L
    x$mcmc$mh$target_accept <- c(0.20, 0.45)
    x$mcmc$mh$scale_bounds <- c(0.10, 10.0)
    x$mcmc$mh$max_scale_step <- 0.35
    x$mcmc$mh$min_burn_adapt <- 50L
    x
  }

  cfg <- set_rw_core(cfg)

  if (identical(config_id, "mcmc_exdqlm_rw_joint_anchor")) {
    if (as.integer(fit_size) <= 500L) {
      cfg$mcmc$burn <- 1200L
      cfg$mcmc$n <- 4000L
      cfg$mcmc$mh$laplace_refresh_start <- 150L
    } else {
      cfg$mcmc$burn <- 3000L
      cfg$mcmc$n <- 8000L
      cfg$mcmc$mh$laplace_refresh_start <- 300L
    }
    cfg$mcmc$mh$laplace_refresh_interval <- 25L
    cfg$mcmc$mh$laplace_refresh_weight <- 0.70
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_rw_refresh_tt500")) {
    cfg$mcmc$burn <- 2000L
    cfg$mcmc$n <- 6000L
    cfg$mcmc$mh$laplace_refresh_interval <- 15L
    cfg$mcmc$mh$laplace_refresh_start <- 100L
    cfg$mcmc$mh$laplace_refresh_weight <- 0.85
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_rw_joint_tt5000_long")) {
    cfg$mcmc$burn <- 4000L
    cfg$mcmc$n <- 12000L
    cfg$mcmc$mh$laplace_refresh_interval <- 25L
    cfg$mcmc$mh$laplace_refresh_start <- 300L
    cfg$mcmc$mh$laplace_refresh_weight <- 0.85
    return(cfg)
  }

  cfg
}

read_dynamic_tail7_rw_status_original288 <- function(manifest_path = paths_dynamic_tail7_rw_original288()$manifest,
                                                     run_tag = run_tag_dynamic_tail7_rw_original288()) {
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
  rows <- rbind_fill_dynamic_tail7_rw_original288(parts)
  if (nrow(rows)) {
    merged <- merge(manifest, rows, by = "row_id", all.x = TRUE, suffixes = c("_manifest", "_row"))
  } else {
    merged <- manifest
  }

  if (!("status" %in% names(merged))) merged$status <- NA_character_
  if (!("gate_overall" %in% names(merged))) merged$gate_overall <- NA_character_
  if (!("healthy" %in% names(merged))) merged$healthy <- NA
  if (!("runtime_sec" %in% names(merged))) merged$runtime_sec <- NA_real_
  if ("status_row" %in% names(merged)) merged$status <- ifelse(!is.na(merged$status_row) & nzchar(merged$status_row), merged$status_row, merged$status)
  if ("gate_overall_row" %in% names(merged)) merged$gate_overall <- ifelse(!is.na(merged$gate_overall_row) & nzchar(merged$gate_overall_row), merged$gate_overall_row, merged$gate_overall)
  if ("healthy_row" %in% names(merged)) merged$healthy <- ifelse(!is.na(merged$healthy_row), merged$healthy_row, merged$healthy)
  if ("runtime_sec_row" %in% names(merged)) merged$runtime_sec <- ifelse(!is.na(merged$runtime_sec_row), merged$runtime_sec_row, merged$runtime_sec)

  normalize_pref_col <- function(base) {
    if (!(base %in% names(merged))) merged[[base]] <<- NA
    row_nm <- paste0(base, "_row")
    manifest_nm <- paste0(base, "_manifest")
    if (row_nm %in% names(merged)) {
      row_val <- merged[[row_nm]]
      merged[[base]] <<- ifelse(!is.na(row_val) & (!is.character(row_val) | nzchar(row_val)), row_val, merged[[base]])
    }
    if (manifest_nm %in% names(merged)) {
      man_val <- merged[[manifest_nm]]
      merged[[base]] <<- ifelse(
        (is.na(merged[[base]]) | (is.character(merged[[base]]) & !nzchar(merged[[base]]))) &
          (!is.na(man_val) & (!is.character(man_val) | nzchar(man_val))),
        man_val,
        merged[[base]]
      )
    }
  }

  for (nm in c(
    "root_kind", "family", "tau_label", "model", "inference",
    "baseline_fit_path", "candidate_fit_path", "vb_candidate_fit_path"
  )) {
    normalize_pref_col(nm)
  }

  merged$state <- ifelse(is.na(merged$status) | !nzchar(merged$status), "pending", merged$status)
  merged$gate_overall[is.na(merged$gate_overall) | !nzchar(merged$gate_overall)] <- "MISSING"
  merged
}
