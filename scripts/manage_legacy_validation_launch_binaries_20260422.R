#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || (length(x) == 1L && is.na(x))) y else x

parse_args_cleanup <- function(args) {
  out <- list(
    mode = "inventory",
    scope = "refreshed288",
    execute = FALSE,
    prune_empty = FALSE,
    root = "tools/merge_reports",
    inventory_csv = "reports/static_exal_tuning_20260422/refreshed288_legacy_launch_binary_cleanup_inventory_20260422.csv",
    report_md = "reports/static_exal_tuning_20260422/refreshed288_legacy_launch_binary_cleanup_report_20260422.md"
  )

  if (!length(args)) return(out)

  for (arg in args) {
    if (!startsWith(arg, "--")) next
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    key <- kv[[1L]]
    value <- if (length(kv) > 1L) paste(kv[-1L], collapse = "=") else "TRUE"
    if (key %in% c("execute", "prune-empty")) {
      out[[gsub("-", "_", key)]] <- tolower(value) %in% c("true", "1", "yes", "y")
    } else {
      out[[gsub("-", "_", key)]] <- value
    }
  }

  out
}

ensure_parent_dir <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
}

format_bytes <- function(x) {
  x <- as.numeric(x %||% 0)
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- 1L
  while (is.finite(x) && x >= 1024 && i < length(units)) {
    x <- x / 1024
    i <- i + 1L
  }
  sprintf("%.1f %s", x, units[[i]])
}

discover_run_roots <- function(root_dir) {
  patterns <- c(
    file.path(root_dir, "full288_refreshed288_*"),
    file.path(root_dir, "full288_original288_*")
  )
  roots <- unique(unlist(lapply(patterns, Sys.glob), use.names = FALSE))
  roots <- roots[file.info(roots)$isdir %in% TRUE]
  sort(normalizePath(roots, winslash = "/", mustWork = FALSE))
}

classify_root <- function(root) {
  base <- basename(root)
  if (identical(base, "full288_refreshed288_20260422_p90_full288_baseline_v1")) {
    return(list(
      class = "protected_current_relaunch",
      default_scope = "protected",
      default_action = "protect",
      cleanup_candidate = FALSE,
      notes = "Current updated-0.4.0 p90 full relaunch root; never touch during cleanup."
    ))
  }
  if (startsWith(base, "full288_refreshed288_preflight_")) {
    return(list(
      class = "legacy_refreshed288_preflight",
      default_scope = "refreshed288",
      default_action = "delete_binary_outputs",
      cleanup_candidate = TRUE,
      notes = "Prelaunch preflight binaries for the current relaunch; safe candidate after readiness is established."
    ))
  }
  if (startsWith(base, "full288_refreshed288_paperaligned_")) {
    return(list(
      class = "legacy_refreshed288_launch",
      default_scope = "refreshed288",
      default_action = "delete_binary_outputs",
      cleanup_candidate = TRUE,
      notes = "Legacy refreshed288 validation-study launch root from before the current p90 relaunch."
    ))
  }
  if (startsWith(base, "full288_original288_")) {
    return(list(
      class = "legacy_original288_launch",
      default_scope = "all_validation",
      default_action = "delete_binary_outputs_optional",
      cleanup_candidate = TRUE,
      notes = "Older original288 validation launch root; optional extended cleanup beyond refreshed288."
    ))
  }
  list(
    class = "manual_review",
    default_scope = "manual_review",
    default_action = "review",
    cleanup_candidate = FALSE,
    notes = "Unclassified launch root; leave alone unless explicitly reviewed."
  )
}

inventory_one_root <- function(root) {
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  info <- file.info(files)
  files <- files[!is.na(info$isdir) & info$isdir %in% FALSE]
  info <- info[!is.na(info$isdir) & info$isdir %in% FALSE, , drop = FALSE]
  rel <- sub(paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", paste0(root, "/"))), "", files)
  ext <- tolower(tools::file_ext(files))

  rds_mask <- ext == "rds"
  rda_mask <- ext == "rda"
  rdata_mask <- tolower(basename(files)) == ".rdata" | ext == "rdata"
  csv_mask <- ext == "csv"
  log_mask <- ext == "log"
  txt_mask <- ext == "txt"

  count_path_class <- function(mask, pattern) sum(mask & grepl(pattern, rel, perl = TRUE))

  class_info <- classify_root(root)
  data.frame(
    root_path = root,
    root_name = basename(root),
    class = class_info$class,
    default_scope = class_info$default_scope,
    default_action = class_info$default_action,
    cleanup_candidate = class_info$cleanup_candidate,
    total_file_count = length(files),
    total_size_bytes = sum(info$size %||% 0, na.rm = TRUE),
    rds_count = sum(rds_mask),
    rds_size_bytes = sum(info$size[rds_mask] %||% 0, na.rm = TRUE),
    rda_count = sum(rda_mask),
    rda_size_bytes = sum(info$size[rda_mask] %||% 0, na.rm = TRUE),
    rdata_count = sum(rdata_mask),
    rdata_size_bytes = sum(info$size[rdata_mask] %||% 0, na.rm = TRUE),
    binary_count = sum(rds_mask | rda_mask | rdata_mask),
    binary_size_bytes = sum(info$size[rds_mask | rda_mask | rdata_mask] %||% 0, na.rm = TRUE),
    config_rds_count = count_path_class(rds_mask, "^configs/"),
    fit_rds_count = count_path_class(rds_mask, "^fits/"),
    vb_init_rds_count = count_path_class(rds_mask, "^vb_init/"),
    draws_rds_count = count_path_class(rds_mask, "^draws/"),
    other_rds_count = sum(rds_mask) - count_path_class(rds_mask, "^configs/") - count_path_class(rds_mask, "^fits/") -
      count_path_class(rds_mask, "^vb_init/") - count_path_class(rds_mask, "^draws/"),
    csv_count = sum(csv_mask),
    log_count = sum(log_mask),
    txt_count = sum(txt_mask),
    notes = class_info$notes,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

inventory_run_roots <- function(root_dir) {
  roots <- discover_run_roots(root_dir)
  if (!length(roots)) return(data.frame())
  do.call(rbind, lapply(roots, inventory_one_root))
}

eligible_roots <- function(inventory, scope = c("refreshed288", "all_validation")) {
  scope <- match.arg(scope)
  if (!nrow(inventory)) return(character(0))
  mask <- inventory$cleanup_candidate %in% TRUE
  if (scope == "refreshed288") {
    mask <- mask & inventory$default_scope %in% c("refreshed288")
  }
  if (scope == "all_validation") {
    mask <- mask & inventory$default_scope %in% c("refreshed288", "all_validation")
  }
  inventory$root_path[mask]
}

remove_legacy_binaries <- function(roots, prune_empty = FALSE) {
  deleted <- list()
  for (root in roots) {
    files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = FALSE, no.. = TRUE)
    info <- file.info(files)
    files <- files[!is.na(info$isdir) & info$isdir %in% FALSE]
    info <- info[!is.na(info$isdir) & info$isdir %in% FALSE, , drop = FALSE]
    ext <- tolower(tools::file_ext(files))
    mask <- ext %in% c("rds", "rda", "rdata") | tolower(basename(files)) == ".rdata"
    if (!any(mask)) next
    target_files <- files[mask]
    target_sizes <- info$size[mask] %||% 0
    ok <- file.remove(target_files)
    deleted[[root]] <- data.frame(
      root_path = root,
      file_path = target_files,
      size_bytes = target_sizes,
      deleted = ok,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    if (isTRUE(prune_empty)) {
      dirs <- list.dirs(root, recursive = TRUE, full.names = TRUE)
      dirs <- dirs[order(nchar(dirs), decreasing = TRUE)]
      for (dir_path in dirs) {
        if (identical(normalizePath(dir_path, winslash = "/", mustWork = FALSE), normalizePath(root, winslash = "/", mustWork = FALSE))) next
        if (!length(list.files(dir_path, all.files = FALSE, no.. = TRUE))) {
          unlink(dir_path, recursive = FALSE, force = TRUE)
        }
      }
    }
  }
  if (!length(deleted)) {
    return(data.frame(root_path = character(0), file_path = character(0), size_bytes = numeric(0), deleted = logical(0), check.names = FALSE))
  }
  do.call(rbind, deleted)
}

write_cleanup_report <- function(inventory, scope, report_path, delete_summary = NULL, mode = "inventory") {
  ensure_parent_dir(report_path)

  protected <- inventory[inventory$default_action == "protect", , drop = FALSE]
  refreshed <- inventory[inventory$default_scope == "refreshed288" & inventory$cleanup_candidate %in% TRUE, , drop = FALSE]
  extended <- inventory[inventory$default_scope == "all_validation" & inventory$cleanup_candidate %in% TRUE, , drop = FALSE]

  total_rda_launch <- sum(inventory$rda_count + inventory$rdata_count, na.rm = TRUE)
  total_rds_launch <- sum(inventory$rds_count, na.rm = TRUE)
  refreshed_bytes <- sum(refreshed$binary_size_bytes, na.rm = TRUE)
  extended_bytes <- sum(extended$binary_size_bytes, na.rm = TRUE)
  refreshed_count <- sum(refreshed$binary_count, na.rm = TRUE)
  extended_count <- sum(extended$binary_count, na.rm = TRUE)

  md <- c(
    "# Legacy validation launch binary cleanup",
    "",
    sprintf("Generated: `%s`", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Important correction",
    "",
    "- Old validation launch roots in this repo are **not** storing `.rda` outputs in practice.",
    "- They are overwhelmingly storing **`.rds` binary launch artifacts** such as run configs, fitted objects, VB-init objects, and draw bundles.",
    "- The only `.rda` files currently present in the repo are package data files under `data/`, and they are **out of scope** for launch cleanup.",
    "",
    "## Cleanup policy",
    "",
    "- Protect the current active updated-0.4.0 relaunch root.",
    "- Default cleanup scope: legacy `refreshed288` launch roots plus the `20260422` preflight root.",
    "- Optional extended scope: older `original288` launch roots.",
    "- Delete **binary launch artifacts only** (`.rds`, `.rda`, `.RData`) under legacy launch roots.",
    "- Preserve CSV/log/txt audit material unless a later manual archive pass says otherwise.",
    "",
    "## Inventory summary",
    "",
    sprintf("- Launch-root `.rds` count found: `%d`", total_rds_launch),
    sprintf("- Launch-root `.rda` / `.RData` count found: `%d`", total_rda_launch),
    sprintf("- Default refreshed288 cleanup scope: `%d` binary files, `%s` reclaimable", refreshed_count, format_bytes(refreshed_bytes)),
    sprintf("- Optional original288 extension: `%d` binary files, `%s` additional reclaimable", extended_count, format_bytes(extended_bytes)),
    "",
    "## Protected roots",
    ""
  )

  if (nrow(protected)) {
    md <- c(md, "| Root | Binary files | Binary size | Notes |", "|---|---:|---:|---|")
    for (i in seq_len(nrow(protected))) {
      row <- protected[i, ]
      md <- c(md, sprintf("| `%s` | `%d` | `%s` | %s |", row$root_name, row$binary_count, format_bytes(row$binary_size_bytes), row$notes))
    }
  } else {
    md <- c(md, "- None")
  }

  add_table <- function(title, df) {
    if (!nrow(df)) return(c("", sprintf("## %s", title), "", "- None"))
    out <- c("", sprintf("## %s", title), "", "| Root | Binary files | Binary size | Configs | Fits | VB init | Draws | Notes |", "|---|---:|---:|---:|---:|---:|---:|---|")
    for (i in seq_len(nrow(df))) {
      row <- df[i, ]
      out <- c(out, sprintf(
        "| `%s` | `%d` | `%s` | `%d` | `%d` | `%d` | `%d` | %s |",
        row$root_name, row$binary_count, format_bytes(row$binary_size_bytes),
        row$config_rds_count, row$fit_rds_count, row$vb_init_rds_count, row$draws_rds_count, row$notes
      ))
    }
    out
  }

  md <- c(md,
    add_table("Default cleanup candidates (`refreshed288` scope)", refreshed),
    add_table("Optional extended cleanup candidates (`all_validation` adds these)", extended),
    "",
    "## Usage",
    "",
    "Inventory / dry-run:",
    "",
    "```bash",
    "Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=inventory --scope=refreshed288",
    "```",
    "",
    "Execute default cleanup:",
    "",
    "```bash",
    "Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=delete --scope=refreshed288 --execute=true",
    "```",
    "",
    "Execute default + original288 cleanup:",
    "",
    "```bash",
    "Rscript scripts/manage_legacy_validation_launch_binaries_20260422.R --mode=delete --scope=all_validation --execute=true",
    "```"
  )

  if (!is.null(delete_summary) && nrow(delete_summary)) {
    deleted_n <- sum(delete_summary$deleted %in% TRUE, na.rm = TRUE)
    deleted_bytes <- sum(delete_summary$size_bytes[delete_summary$deleted %in% TRUE], na.rm = TRUE)
    md <- c(md,
      "",
      "## Last delete summary",
      "",
      sprintf("- Deleted files: `%d`", deleted_n),
      sprintf("- Reclaimed size: `%s`", format_bytes(deleted_bytes))
    )
  } else if (identical(mode, "delete")) {
    md <- c(md, "", "## Last delete summary", "", "- No files were deleted.")
  }

  writeLines(md, con = report_path, useBytes = TRUE)
}

main <- function() {
  args <- parse_args_cleanup(commandArgs(trailingOnly = TRUE))
  mode <- match.arg(args$mode, c("inventory", "delete"))
  scope <- match.arg(args$scope, c("refreshed288", "all_validation"))
  root_dir <- normalizePath(args$root, winslash = "/", mustWork = TRUE)

  inventory <- inventory_run_roots(root_dir)
  if (!nrow(inventory)) stop("No launch roots found under root directory.")
  inventory <- inventory[order(inventory$default_scope, inventory$root_name), , drop = FALSE]

  ensure_parent_dir(args$inventory_csv)
  utils::write.csv(inventory, args$inventory_csv, row.names = FALSE)

  delete_summary <- NULL
  if (identical(mode, "delete")) {
    if (!isTRUE(args$execute)) {
      stop("Delete mode requires --execute=true", call. = FALSE)
    }
    roots <- eligible_roots(inventory, scope = scope)
    delete_summary <- remove_legacy_binaries(roots, prune_empty = isTRUE(args$prune_empty))
    inventory <- inventory_run_roots(root_dir)
    inventory <- inventory[order(inventory$default_scope, inventory$root_name), , drop = FALSE]
    utils::write.csv(inventory, args$inventory_csv, row.names = FALSE)
  }

  write_cleanup_report(inventory, scope = scope, report_path = args$report_md, delete_summary = delete_summary, mode = mode)

  cat(sprintf("mode=%s\n", mode))
  cat(sprintf("scope=%s\n", scope))
  cat(sprintf("inventory_csv=%s\n", args$inventory_csv))
  cat(sprintf("report_md=%s\n", args$report_md))
  cat(sprintf("protected_roots=%d\n", sum(inventory$default_action == "protect")))
  refreshed <- inventory[inventory$default_scope == "refreshed288" & inventory$cleanup_candidate %in% TRUE, , drop = FALSE]
  extended <- inventory[inventory$default_scope == "all_validation" & inventory$cleanup_candidate %in% TRUE, , drop = FALSE]
  cat(sprintf("default_candidate_binary_files=%d\n", sum(refreshed$binary_count, na.rm = TRUE)))
  cat(sprintf("default_candidate_binary_size=%s\n", format_bytes(sum(refreshed$binary_size_bytes, na.rm = TRUE))))
  cat(sprintf("extended_candidate_binary_files=%d\n", sum(extended$binary_count, na.rm = TRUE)))
  cat(sprintf("extended_candidate_binary_size=%s\n", format_bytes(sum(extended$binary_size_bytes, na.rm = TRUE))))

  if (!is.null(delete_summary)) {
    cat(sprintf("deleted_files=%d\n", sum(delete_summary$deleted %in% TRUE, na.rm = TRUE)))
    cat(sprintf("reclaimed_size=%s\n", format_bytes(sum(delete_summary$size_bytes[delete_summary$deleted %in% TRUE], na.rm = TRUE))))
  }
}

main()
