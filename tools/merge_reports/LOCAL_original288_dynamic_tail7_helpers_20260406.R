source("tools/merge_reports/LOCAL_original288_recovery_helpers_20260405.R")

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

dynamic_tail7_phase_order_original288 <- c(
  anchor7_slice_band18 = 1L,
  anchor7_slice_band24 = 2L,
  tau05_long6_slice_band18 = 3L
)

dynamic_tail7_force_original288 <- c(
  anchor7_slice_band18 = 1L,
  anchor7_slice_band24 = 1L,
  tau05_long6_slice_band18 = 1L
)

gate_rank_dynamic_tail7_original288 <- function(x) {
  ranks <- c(PASS = 3L, WARN = 2L, FAIL = 1L, MISSING = 0L)
  out <- unname(ranks[as.character(x)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

candidate_preference_rank_dynamic_tail7_original288 <- function(phase) {
  ranks <- c(
    anchor7_slice_band18 = 3L,
    anchor7_slice_band24 = 2L,
    tau05_long6_slice_band18 = 1L
  )
  out <- unname(ranks[as.character(phase)])
  out[is.na(out)] <- 0L
  as.integer(out)
}

rbind_fill_dynamic_tail7_original288 <- function(parts) {
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

paths_dynamic_tail7_original288 <- function() {
  list(
    manifest = "tools/merge_reports/LOCAL_original288_dynamic_tail7_manifest_20260406.csv",
    stage_counts = "tools/merge_reports/LOCAL_original288_dynamic_tail7_stage_counts_20260406.csv",
    manifest_status = "tools/merge_reports/LOCAL_original288_dynamic_tail7_manifest_status_20260406.csv",
    phase_summary = "tools/merge_reports/LOCAL_original288_dynamic_tail7_phase_summary_20260406.csv",
    config_summary = "tools/merge_reports/LOCAL_original288_dynamic_tail7_config_summary_20260406.csv",
    case_best = "tools/merge_reports/LOCAL_original288_dynamic_tail7_case_best_20260406.csv",
    unresolved_after_run = "tools/merge_reports/LOCAL_original288_dynamic_tail7_unresolved_after_run_20260406.csv",
    selection_update = "tools/merge_reports/LOCAL_original288_dynamic_tail7_selection_update_20260406.csv",
    selection_delta = "tools/merge_reports/LOCAL_original288_dynamic_tail7_selection_delta_20260406.csv",
    carryforward_preview = "tools/merge_reports/LOCAL_original288_carryforward_selection_dynamic_tail7_preview_20260406.csv",
    health_summary_preview = "tools/merge_reports/LOCAL_original288_health_summary_dynamic_tail7_preview_20260406.csv",
    tracker = "tools/merge_reports/LOCAL_ORIGINAL288_DYNAMIC_RECOVERY_TRACKER_20260405.md",
    plan_doc = "reports/static_exal_tuning_20260406/original_288_dynamic_tail7_geometry_program_20260406.md",
    execution_doc = "reports/static_exal_tuning_20260406/original_288_dynamic_tail7_geometry_execution_20260406.md"
  )
}

run_tag_dynamic_tail7_original288 <- function() {
  "original288_dynamic_tail7_20260406"
}

build_candidate_fit_path_dynamic_tail7_original288 <- function(baseline_fit_path, variant_tag) {
  sub("\\.rds$", paste0("_", variant_tag, ".rds"), normalize_path_original288(baseline_fit_path))
}

full288_seed_map_dynamic_tail7_original288 <- function() {
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
  out <- rbind_fill_dynamic_tail7_original288(Filter(Negate(is.null), rows))
  if (!nrow(out)) return(out)
  out <- out[!duplicated(out$original_case_key), , drop = FALSE]
  rownames(out) <- NULL
  out
}

read_unresolved_dynamic_original288_dynamic_tail7 <- function() {
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

read_dynamic_vb_selection_original288_dynamic_tail7 <- function() {
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

config_note_dynamic_tail7_original288 <- function(config_id) {
  switch(
    config_id,
    mcmc_exdqlm_slice_band18 = paste(
      "Primary geometry-band probe: stay in the validated slice corridor with",
      "VB warm starts, but widen the bracket and allow more stepping to address",
      "the ESS-limited failures left after tail-8."
    ),
    mcmc_exdqlm_slice_band24 = paste(
      "Secondary geometry-band probe: a more aggressive slice bracket and step",
      "budget for the same residual cases, used only because the exact 0.12/80",
      "corridor and its long rerun are now screened out on the remaining tail."
    ),
    mcmc_exdqlm_slice_band18_long = paste(
      "Low-tail-only follow-up: keep the improved band-18 geometry and extend",
      "burn and kept draws only on tau=0.05 rows where the remaining debt is",
      "still concentrated."
    ),
    "Unspecified dynamic tail-7 config."
  )
}

apply_dynamic_tail7_config_original288 <- function(cfg, config_id) {
  cfg <- cfg %||% list()
  cfg$mcmc <- cfg$mcmc %||% list()
  cfg$mcmc$mh <- cfg$mcmc$mh %||% list()

  if (identical(config_id, "mcmc_exdqlm_slice_band18")) {
    cfg$mcmc$burn <- 1200L
    cfg$mcmc$n <- 4000L
    cfg$mcmc$trace_every <- 50L
    cfg$mcmc$init_from_vb <- TRUE
    cfg$mcmc$mh$proposal <- "slice"
    cfg$mcmc$mh$adapt <- FALSE
    cfg$mcmc$mh$slice_width <- 0.18
    cfg$mcmc$mh$slice_max_steps <- 120L
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_slice_band24")) {
    cfg$mcmc$burn <- 1200L
    cfg$mcmc$n <- 4000L
    cfg$mcmc$trace_every <- 50L
    cfg$mcmc$init_from_vb <- TRUE
    cfg$mcmc$mh$proposal <- "slice"
    cfg$mcmc$mh$adapt <- FALSE
    cfg$mcmc$mh$slice_width <- 0.24
    cfg$mcmc$mh$slice_max_steps <- 160L
    return(cfg)
  }

  if (identical(config_id, "mcmc_exdqlm_slice_band18_long")) {
    cfg$mcmc$burn <- 2000L
    cfg$mcmc$n <- 8000L
    cfg$mcmc$trace_every <- 50L
    cfg$mcmc$init_from_vb <- TRUE
    cfg$mcmc$mh$proposal <- "slice"
    cfg$mcmc$mh$adapt <- FALSE
    cfg$mcmc$mh$slice_width <- 0.18
    cfg$mcmc$mh$slice_max_steps <- 120L
    return(cfg)
  }

  cfg
}

read_dynamic_tail7_status_original288 <- function(manifest_path = paths_dynamic_tail7_original288()$manifest,
                                                  run_tag = run_tag_dynamic_tail7_original288()) {
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
  rows <- rbind_fill_dynamic_tail7_original288(parts)
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
