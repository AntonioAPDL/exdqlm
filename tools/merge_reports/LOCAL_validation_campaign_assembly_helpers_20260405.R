gate_rank <- function(x) {
  ranks <- c(PASS = 1L, WARN = 2L, FAIL = 3L)
  out <- unname(ranks[as.character(x)])
  out[is.na(out)] <- 9L
  out
}

scope_from_static_case_id <- function(case_id) {
  ifelse(
    grepl("validation_shrink_rhs", case_id, fixed = TRUE),
    "legacy_rhs_refresh",
    "current_rhsns_refresh"
  )
}

read_static_manifests_20260405 <- function() {
  current_path <- "tools/merge_reports/LOCAL_targeted_manifest_current_static_rhsns_20260329.csv"
  legacy_path <- "tools/merge_reports/LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv"

  current <- read.csv(current_path, stringsAsFactors = FALSE)
  legacy <- read.csv(legacy_path, stringsAsFactors = FALSE)

  current$scope_label <- "current_rhsns_refresh"
  legacy$scope_label <- "legacy_rhs_refresh"

  out <- rbind(current, legacy)
  out$case_key <- paste("static_validation", out$scope_label, out$row_id, sep = "::")
  out$prior_semantics <- ifelse(
    is.na(out$prior_override) | out$prior_override == "",
    out$prior,
    out$prior_override
  )
  out
}

read_static_compacts_20260405 <- function() {
  current_path <- "tools/merge_reports/full288_rhsns_impl_refresh_20260329/health_compact_20260329_114727.csv"
  legacy_path <- "tools/merge_reports/full288_rhs_legacy_refresh_20260329/health_compact_20260329_123208.csv"

  current <- read.csv(current_path, stringsAsFactors = FALSE)
  legacy <- read.csv(legacy_path, stringsAsFactors = FALSE)

  current$scope_label <- "current_rhsns_refresh"
  legacy$scope_label <- "legacy_rhs_refresh"

  rbind(current, legacy)
}

read_summary_registry_20260405 <- function() {
  files <- sort(list.files(
    "tools/merge_reports",
    pattern = "^LOCAL_.*case_health_summary.*\\.csv$",
    full.names = TRUE
  ))

  rows <- lapply(files, function(path) {
    x <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) {
      return(NULL)
    }

    row_id <- if ("queue_id" %in% names(x)) {
      x$queue_id
    } else if ("row_id" %in% names(x)) {
      x$row_id
    } else {
      rep(NA_integer_, nrow(x))
    }

    case_id <- if ("case_id" %in% names(x)) x$case_id else rep(NA_character_, nrow(x))
    variant_tag <- if ("variant_tag" %in% names(x)) x$variant_tag else rep(NA_character_, nrow(x))
    gate_overall <- if ("gate_overall" %in% names(x)) x$gate_overall else rep(NA_character_, nrow(x))
    healthy <- if ("healthy" %in% names(x)) x$healthy else rep(NA, nrow(x))
    candidate_path <- if ("candidate_path" %in% names(x)) x$candidate_path else rep(NA_character_, nrow(x))
    health_csv <- if ("health_csv" %in% names(x)) x$health_csv else rep(NA_character_, nrow(x))
    model <- if ("model" %in% names(x)) x$model else rep(NA_character_, nrow(x))
    family_scope <- if ("family_scope" %in% names(x)) x$family_scope else rep(NA_character_, nrow(x))
    family <- if ("family" %in% names(x)) x$family else rep(NA_character_, nrow(x))
    tt <- if ("tt" %in% names(x)) x$tt else rep(NA_integer_, nrow(x))
    tau <- if ("tau" %in% names(x)) x$tau else rep(NA_character_, nrow(x))
    ts <- if ("ts" %in% names(x)) x$ts else rep(NA_character_, nrow(x))

    runtime_sec <- if ("runtime_sec_cand" %in% names(x)) {
      x$runtime_sec_cand
    } else if ("runtime_sec" %in% names(x)) {
      x$runtime_sec
    } else if ("run_time_sec" %in% names(x)) {
      x$run_time_sec
    } else {
      rep(NA_real_, nrow(x))
    }

    workstream <- if (grepl("/LOCAL_static_", path, fixed = TRUE)) {
      "static_exal"
    } else if (grepl("/LOCAL_dynamic_", path, fixed = TRUE)) {
      "dynamic_tail_cppgig_refresh_20260331"
    } else {
      "unknown"
    }

    if (workstream == "dynamic_tail_cppgig_refresh_20260331" && all(is.na(row_id))) {
      parsed_row <- suppressWarnings(as.integer(sub(".*row([0-9]+).*", "\\1", variant_tag)))
      row_id <- parsed_row
    }

    scope_label <- if (workstream == "static_exal") {
      scope_from_static_case_id(case_id)
    } else {
      "dynamic_tail_cppgig_refresh_20260331"
    }

    data.frame(
      file = path,
      workstream = workstream,
      scope_label = scope_label,
      row_id = suppressWarnings(as.integer(row_id)),
      case_id = case_id,
      family_scope = family_scope,
      model = model,
      family = family,
      tt = suppressWarnings(as.integer(tt)),
      tau = as.character(tau),
      variant_tag = variant_tag,
      gate_overall = gate_overall,
      healthy = healthy,
      candidate_path = candidate_path,
      health_csv = health_csv,
      runtime_sec = suppressWarnings(as.numeric(runtime_sec)),
      ts = ts,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  if (is.null(out)) {
    data.frame()
  } else {
    out
  }
}

parse_checkpoint_pairs_20260405 <- function(files) {
  out <- list()
  out_idx <- 0L

  for (path in files) {
    x <- read.csv(path, stringsAsFactors = FALSE)
    starts <- list()

    for (i in seq_len(nrow(x))) {
      row <- x[i, ]
      key <- paste(row$case_id, row$queue_id, row$variant_tag, sep = "||")

      if (identical(row$stage, "start")) {
        if (is.null(starts[[key]])) {
          starts[[key]] <- list()
        }
        starts[[key]][[length(starts[[key]]) + 1L]] <- row
        next
      }

      if (!identical(row$stage, "complete")) {
        next
      }

      start_row <- if (!is.null(starts[[key]]) && length(starts[[key]]) > 0L) {
        tmp <- starts[[key]][[1L]]
        if (length(starts[[key]]) == 1L) {
          starts[[key]] <- NULL
        } else {
          starts[[key]] <- starts[[key]][-1L]
        }
        tmp
      } else {
        row
      }

      scope_label <- if (grepl("validation_shrink_rhs", start_row$case_id, fixed = TRUE)) {
        if (!is.na(start_row$beta_prior_override) &&
            nzchar(start_row$beta_prior_override) &&
            identical(start_row$beta_prior_override, "rhs_ns")) {
          "current_rhsns_refresh"
        } else {
          "legacy_rhs_refresh"
        }
      } else {
        "current_rhsns_refresh"
      }

      out_idx <- out_idx + 1L
      out[[out_idx]] <- data.frame(
        checkpoint_file = path,
        ts_start = if ("ts" %in% names(start_row)) start_row$ts else NA_character_,
        ts_complete = if ("ts" %in% names(row)) row$ts else NA_character_,
        scope_label = scope_label,
        row_id = as.integer(start_row$queue_id),
        case_id = start_row$case_id,
        family_scope = start_row$family_scope,
        model = start_row$model,
        family = start_row$family,
        tt = suppressWarnings(as.integer(start_row$tt)),
        tau = as.character(start_row$tau),
        variant_tag = start_row$variant_tag,
        beta_prior_override = start_row$beta_prior_override,
        candidate_path = start_row$candidate_path,
        health_csv = row$health_csv,
        gate_overall = row$gate_overall,
        healthy = row$healthy,
        runtime_sec = suppressWarnings(as.numeric(row$runtime_sec)),
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(out)) {
    return(data.frame())
  }

  do.call(rbind, out)
}

read_dynamic_fixed_rows_20260405 <- function() {
  row5 <- read.csv(
    "tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0005.csv",
    stringsAsFactors = FALSE
  )
  row57 <- read.csv(
    "tools/merge_reports/full288_row57_cppgig_same_seed_20260330/health/health_0057.csv",
    stringsAsFactors = FALSE
  )

  dynamic_case_from_health <- function(case_id) {
    parts <- strsplit(case_id, "::", fixed = TRUE)[[1]]
    root <- parts[1]
    tt <- sub(".*validation_dynamic_tt([0-9]+)$", "\\1", root)
    family <- sub(".*/([^/]+)/tau_[^/]+/fit_input_lastTT[0-9]+/validation_dynamic_tt[0-9]+$", "\\1", root)
    tau_label <- sub(".*/tau_([^/]+)/fit_input_lastTT[0-9]+/validation_dynamic_tt[0-9]+$", "\\1", root)
    list(root = root, tt = as.integer(tt), family = family, tau_label = tau_label)
  }

  row57_meta <- dynamic_case_from_health(row57$case_id[1])

  rbind(
    data.frame(
      row_id = 5L,
      scope_label = "dynamic_tail_cppgig_refresh_20260331",
      inference = row5$inference[1],
      model = row5$model[1],
      root_kind = row5$root_kind[1],
      family = row5$family[1],
      tau_label = row5$tau_label[1],
      fit_size = 5000L,
      case_id = sprintf("%s::%s::%s", dirname(dirname(dirname(row5$baseline_fit_path[1]))), row5$model[1], row5$inference[1]),
      selected_variant_tag = "dynamic_tail_cppgig_refresh_20260331",
      selected_fit_path = row5$candidate_fit_path[1],
      selected_health_path = row5$health_csv[1],
      gate_overall = row5$gate_overall[1],
      healthy = row5$healthy[1],
      state = row5$status[1],
      runtime_sec = suppressWarnings(as.numeric(row5$runtime_sec[1])),
      provenance_source = "tools/merge_reports/full288_dynamic_tail_cppgig_refresh_20260331/rows/row_0005.csv",
      stringsAsFactors = FALSE
    ),
    data.frame(
      row_id = 57L,
      scope_label = "dynamic_tail_cppgig_refresh_20260331",
      inference = "mcmc",
      model = "dqlm",
      root_kind = "dynamic",
      family = row57_meta$family,
      tau_label = row57_meta$tau_label,
      fit_size = row57_meta$tt,
      case_id = row57$case_id[1],
      selected_variant_tag = row57$variant[1],
      selected_fit_path = row57$candidate_path[1],
      selected_health_path = "tools/merge_reports/full288_row57_cppgig_same_seed_20260330/health/health_0057.csv",
      gate_overall = row57$gate_overall[1],
      healthy = row57$healthy[1],
      state = "done",
      runtime_sec = suppressWarnings(as.numeric(row57$run_time_sec[1])),
      provenance_source = "tools/merge_reports/full288_row57_cppgig_same_seed_20260330/health/health_0057.csv",
      stringsAsFactors = FALSE
    )
  )
}

ensure_files_exist_20260405 <- function(paths) {
  missing <- paths[!is.na(paths) & nzchar(paths) & !file.exists(paths)]
  unique(missing)
}
