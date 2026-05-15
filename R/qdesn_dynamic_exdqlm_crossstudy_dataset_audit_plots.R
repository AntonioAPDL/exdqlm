qdesn_dynamic_datasetaudit_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_tau050_dataset_audit_manifest.yaml"),
                                                     repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  manifest <- yaml::read_yaml(yaml_path)
  if (!is.list(manifest)) {
    stop("Dataset audit manifest must decode to a named list.", call. = FALSE)
  }
  manifest
}

.qdesn_dynamic_datasetaudit_slug <- function(x) {
  x <- tolower(as.character(x %||% "na")[1L])
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  if (!nzchar(x)) "na" else x
}

.qdesn_dynamic_datasetaudit_resolve_state <- function(manifest,
                                                      repo_root = NULL) {
  cfg <- manifest$analysis %||% list()
  list(
    source_run_root = .qdesn_validation_resolve_path(cfg$source_run_root, repo_root = repo_root, must_work = TRUE),
    comparison_root = .qdesn_validation_resolve_path(cfg$comparison_root %||% NULL, repo_root = repo_root, must_work = FALSE)
  )
}

.qdesn_dynamic_datasetaudit_read_observed <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!nrow(df) || !ncol(df)) {
    stop(sprintf("Observed dataset is empty: %s", path), call. = FALSE)
  }
  y <- suppressWarnings(as.numeric(df[[1L]]))
  y <- y[is.finite(y)]
  if (!length(y)) {
    stop(sprintf("Observed dataset has no finite numeric values: %s", path), call. = FALSE)
  }
  y
}

.qdesn_dynamic_datasetaudit_load_root_reference <- function(comparison_root) {
  if (is.null(comparison_root) || !dir.exists(comparison_root)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  ref_path <- file.path(comparison_root, "tables", "authoritative_root_inventory.csv")
  if (!file.exists(ref_path)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  utils::read.csv(ref_path, stringsAsFactors = FALSE)
}

.qdesn_dynamic_datasetaudit_apply_filters <- function(inventory,
                                                      manifest) {
  filters <- manifest$selection %||% list()
  out <- inventory
  keep_values <- function(col, values) {
    if (is.null(values) || !length(values) || !(col %in% names(out))) return()
    vals <- unlist(values, use.names = FALSE)
    vals <- vals[!is.na(vals)]
    if (!length(vals)) return()
    out <<- out[out[[col]] %in% vals, , drop = FALSE]
  }
  keep_values("family", as.character(filters$families %||% character()))
  keep_values("prior", as.character(filters$priors %||% character()))
  keep_values("fit_size", as.integer(filters$fit_sizes %||% integer()))
  tau_vals <- suppressWarnings(as.numeric(unlist(filters$taus %||% numeric(), use.names = FALSE)))
  tau_vals <- tau_vals[is.finite(tau_vals)]
  if (length(tau_vals) && "tau" %in% names(out)) {
    out <- out[round(as.numeric(out$tau), 12L) %in% round(tau_vals, 12L), , drop = FALSE]
  }
  out
}

qdesn_dynamic_datasetaudit_build_inventory <- function(manifest,
                                                       state,
                                                       repo_root = NULL) {
  roots_dir <- file.path(state$source_run_root, "roots")
  root_dirs <- list.dirs(roots_dir, full.names = TRUE, recursive = FALSE)
  if (!length(root_dirs)) {
    stop(sprintf("No root directories found under %s", roots_dir), call. = FALSE)
  }
  reference_df <- .qdesn_dynamic_datasetaudit_load_root_reference(state$comparison_root)
  ref_map <- if (nrow(reference_df) && "root_id" %in% names(reference_df)) {
    stats::setNames(seq_len(nrow(reference_df)), as.character(reference_df$root_id))
  } else {
    integer()
  }
  rows <- lapply(root_dirs, function(root_dir) {
    meta_path <- file.path(root_dir, "data", "source_metadata.json")
    obs_path <- file.path(root_dir, "data", "observed.csv")
    if (!file.exists(meta_path) || !file.exists(obs_path)) return(NULL)
    meta <- .qdesn_validation_read_json_if_exists(meta_path)
    y <- .qdesn_dynamic_datasetaudit_read_observed(obs_path)
    root_id <- as.character(meta$root_id %||% basename(root_dir))
    ref_row <- if (length(ref_map) && !is.na(ref_map[[root_id]])) {
      reference_df[ref_map[[root_id]], , drop = FALSE]
    } else {
      NULL
    }
    data.frame(
      root_id = root_id,
      dataset_cell_id = as.character(meta$dataset_cell_id %||% NA_character_),
      scenario = as.character(meta$source_scenario %||% NA_character_),
      family = as.character(meta$source_family %||% NA_character_),
      tau = suppressWarnings(as.numeric(meta$tau %||% NA_real_)),
      fit_size = suppressWarnings(as.integer(meta$fit_size %||% NA_integer_)),
      effective_fit_size = suppressWarnings(as.integer(meta$effective_fit_size %||% NA_integer_)),
      source_total_size = suppressWarnings(as.integer(meta$source_total_size %||% length(y))),
      prior = as.character(gsub("^qdesn_", "", sub("^.*__", "", root_id))),
      observed_path = normalizePath(obs_path, winslash = "/", mustWork = TRUE),
      metadata_path = normalizePath(meta_path, winslash = "/", mustWork = TRUE),
      n_obs = length(y),
      y_min = min(y),
      y_max = max(y),
      y_mean = mean(y),
      y_sd = stats::sd(y),
      readiness_label = if (!is.null(ref_row) && "readiness_label" %in% names(ref_row)) as.character(ref_row$readiness_label[1L]) else NA_character_,
      fail_fit_n = if (!is.null(ref_row) && "fail_fit_n" %in% names(ref_row)) suppressWarnings(as.integer(ref_row$fail_fit_n[1L])) else NA_integer_,
      stringsAsFactors = FALSE
    )
  })
  inventory <- .qdesn_validation_bind_rows(rows)
  inventory <- .qdesn_dynamic_datasetaudit_apply_filters(inventory, manifest)
  if (!nrow(inventory)) {
    stop("Dataset audit selection resolved to zero roots.", call. = FALSE)
  }
  ord <- do.call(order, list(
    as.character(inventory$family),
    as.numeric(inventory$tau),
    as.integer(inventory$fit_size),
    as.character(inventory$prior),
    as.character(inventory$root_id)
  ))
  inventory <- inventory[ord, , drop = FALSE]
  inventory$plot_index <- seq_len(nrow(inventory))
  inventory$file_stub <- sprintf(
    "%03d__%s__tau_%s__fit_%s__%s",
    inventory$plot_index,
    vapply(inventory$family, .qdesn_dynamic_datasetaudit_slug, character(1)),
    gsub("\\.", "p", sprintf("%.2f", as.numeric(inventory$tau))),
    as.integer(inventory$fit_size),
    vapply(inventory$prior, .qdesn_dynamic_datasetaudit_slug, character(1))
  )
  inventory$png_file <- paste0(inventory$file_stub, ".png")
  inventory$last100_start <- pmax(1L, as.integer(inventory$n_obs) - 99L)
  inventory
}

.qdesn_dynamic_datasetaudit_plot_grid <- function(x_ticks,
                                                  y_ticks,
                                                  col = "#cbd5e1") {
  abline(v = x_ticks, h = y_ticks, col = grDevices::adjustcolor(col, alpha.f = 0.55), lwd = 0.8)
}

.qdesn_dynamic_datasetaudit_plot_one <- function(row,
                                                 output_root,
                                                 manifest = list()) {
  plot_cfg <- manifest$plotting %||% list()
  width_px <- as.integer(plot_cfg$width_px %||% 2600L)
  height_px <- as.integer(plot_cfg$height_px %||% 1300L)
  res_dpi <- as.integer(plot_cfg$res_dpi %||% 150L)
  n_last <- as.integer(plot_cfg$n_last %||% 100L)
  bg <- as.character(plot_cfg$background %||% "#ffffff")
  line_col <- as.character(plot_cfg$line_color %||% "#334155")
  point_col <- as.character(plot_cfg$point_color %||% "#0f172a")
  accent_col <- as.character(plot_cfg$accent_color %||% "#ea580c")
  shade_col <- grDevices::adjustcolor(accent_col, alpha.f = 0.12)
  out_path <- file.path(output_root, row$png_file[1L])
  y <- .qdesn_dynamic_datasetaudit_read_observed(row$observed_path[1L])
  x <- seq_along(y)
  tail_start <- max(1L, length(y) - n_last + 1L)
  tail_idx <- tail_start:length(y)
  y_tail <- y[tail_idx]
  png(filename = out_path, width = width_px, height = height_px, res = res_dpi, bg = bg)
  on.exit(grDevices::dev.off(), add = TRUE)

  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.6, 4.8, 4.2, 1.2), oma = c(0.5, 0.5, 4.8, 0.5), xaxs = "r", yaxs = "r")

  y_ticks_full <- pretty(range(y, finite = TRUE), n = 6)
  x_ticks_full <- pretty(x, n = 6)
  graphics::plot(x, y, type = "n", xlab = "time index", ylab = "observed value",
                 main = "Full series", cex.main = 1.1, font.main = 2)
  usr <- graphics::par("usr")
  graphics::rect(tail_start, usr[3], length(y), usr[4], col = shade_col, border = NA)
  .qdesn_dynamic_datasetaudit_plot_grid(x_ticks_full, y_ticks_full)
  graphics::lines(x, y, col = line_col, lwd = 2.4)
  graphics::lines(tail_idx, y_tail, col = accent_col, lwd = 2.8)
  graphics::abline(v = tail_start, col = accent_col, lwd = 1.5, lty = 2)
  graphics::legend("topleft",
                   legend = c("observed", sprintf("last %d obs (raw highlight)", length(tail_idx))),
                   col = c(line_col, accent_col), lwd = c(2.4, 2.8),
                   bty = "n", cex = 0.92)
  graphics::mtext(sprintf("n=%d | min=%.1f | max=%.1f | sd=%.1f", length(y), min(y), max(y), stats::sd(y)),
                  side = 3, line = 0.25, cex = 0.86, col = "#475569")

  y_ticks_tail <- pretty(range(y_tail, finite = TRUE), n = 6)
  x_ticks_tail <- pretty(tail_idx, n = 5)
  graphics::plot(tail_idx, y_tail, type = "o", pch = 16, cex = 0.7,
                 col = line_col, lwd = 2.2, xlab = sprintf("time index (last %d)", length(tail_idx)),
                 ylab = "observed value", main = sprintf("Zoom: last %d points", length(tail_idx)),
                 cex.main = 1.1, font.main = 2)
  .qdesn_dynamic_datasetaudit_plot_grid(x_ticks_tail, y_ticks_tail)
  graphics::mtext(sprintf("tail range=%.1f | delta=%.1f", diff(range(y_tail)), y_tail[length(y_tail)] - y_tail[1L]),
                  side = 3, line = 0.25, cex = 0.86, col = "#475569")

  graphics::mtext(
    sprintf("%03d | %s | tau=%.2f | fit=%d | %s | n=%d",
            as.integer(row$plot_index[1L]),
            as.character(row$family[1L]),
            as.numeric(row$tau[1L]),
            as.integer(row$fit_size[1L]),
            as.character(row$prior[1L]),
            as.integer(row$n_obs[1L])),
    side = 3, outer = TRUE, line = 2.6, cex = 1.35, font = 2, col = "#0f172a"
  )
  graphics::mtext(
    sprintf("%s | %s | readiness=%s | fail_fit_n=%s",
            as.character(row$dataset_cell_id[1L]),
            as.character(row$root_id[1L]),
            as.character(row$readiness_label[1L] %||% "NA"),
            as.character(row$fail_fit_n[1L] %||% "NA")),
    side = 3, outer = TRUE, line = 1.2, cex = 0.88, col = "#475569"
  )

  invisible(data.frame(
    plot_index = as.integer(row$plot_index[1L]),
    root_id = as.character(row$root_id[1L]),
    png_file = as.character(row$png_file[1L]),
    png_path = normalizePath(out_path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  ))
}

qdesn_dynamic_datasetaudit_render_plots <- function(inventory,
                                                    output_root,
                                                    manifest = list(),
                                                    max_workers = 1L) {
  if (!nrow(inventory)) return(data.frame(stringsAsFactors = FALSE))
  max_workers <- max(1L, min(as.integer(max_workers)[1L], nrow(inventory)))
  rows <- split(inventory, seq_len(nrow(inventory)))
  runner <- function(df) {
    tryCatch(
      .qdesn_dynamic_datasetaudit_plot_one(df, output_root = output_root, manifest = manifest),
      error = function(e) data.frame(
        plot_index = as.integer(df$plot_index[1L]),
        root_id = as.character(df$root_id[1L]),
        png_file = as.character(df$png_file[1L]),
        png_path = NA_character_,
        error = as.character(conditionMessage(e)),
        stringsAsFactors = FALSE
      )
    )
  }
  rendered <- if (.Platform$OS.type == "unix" && max_workers > 1L) {
    parallel::mclapply(rows, runner, mc.cores = max_workers, mc.preschedule = FALSE)
  } else {
    lapply(rows, runner)
  }
  .qdesn_validation_bind_rows(rendered)
}

qdesn_dynamic_datasetaudit_write_outputs <- function(inventory,
                                                     render_status,
                                                     output_root,
                                                     manifest = list(),
                                                     state = list()) {
  .qdesn_validation_dir_create(output_root)
  inventory_out <- inventory
  if (nrow(render_status)) {
    idx <- match(inventory_out$root_id, render_status$root_id)
    inventory_out$png_file <- ifelse(!is.na(idx), as.character(render_status$png_file[idx]), inventory_out$png_file)
    inventory_out$png_path <- ifelse(!is.na(idx), as.character(render_status$png_path[idx]), NA_character_)
    if ("error" %in% names(render_status)) {
      inventory_out$render_error <- ifelse(!is.na(idx), as.character(render_status$error[idx]), NA_character_)
    }
  }
  png_path <- if ("png_path" %in% names(inventory_out)) as.character(inventory_out$png_path) else rep(NA_character_, nrow(inventory_out))
  render_error <- if ("render_error" %in% names(inventory_out)) as.character(inventory_out$render_error) else rep(NA_character_, nrow(inventory_out))
  png_exists <- !is.na(png_path) & file.exists(png_path)
  render_error_flag <- !is.na(render_error) & nzchar(trimws(render_error))
  render_error_n <- sum(render_error_flag, na.rm = TRUE)
  .qdesn_validation_write_df(inventory_out, file.path(output_root, "000__dataset_index.csv"))
  .qdesn_validation_write_json(file.path(output_root, "000__dataset_audit_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    source_run_root = state$source_run_root %||% NA_character_,
    comparison_root = state$comparison_root %||% NA_character_,
    n_datasets = nrow(inventory_out),
    n_rendered = sum(png_exists, na.rm = TRUE),
    n_render_errors = render_error_n,
    n_last = as.integer((manifest$plotting %||% list())$n_last %||% 100L)
  ))
  summary_lines <- c(
    "# Tau050 Dataset Audit Plot Pack",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_run_root: `%s`", as.character(state$source_run_root %||% NA_character_)),
    sprintf("- comparison_root: `%s`", as.character(state$comparison_root %||% NA_character_)),
    sprintf("- output_root: `%s`", normalizePath(output_root, winslash = "/", mustWork = FALSE)),
    sprintf("- n_datasets: `%d`", nrow(inventory_out)),
    sprintf("- n_rendered: `%d`", sum(png_exists, na.rm = TRUE)),
    sprintf("- n_render_errors: `%d`", render_error_n),
    "",
    "## Ordering",
    "",
    "PNG files are flat and numerically prefixed so they can be reviewed in lexical order.",
    "",
    "## Inventory",
    .qdesn_validation_df_to_markdown(inventory_out[, c(
      "plot_index", "png_file", "family", "tau", "fit_size", "prior", "n_obs", "readiness_label", "fail_fit_n"
    ), drop = FALSE])
  )
  .qdesn_validation_write_lines(file.path(output_root, "000__dataset_audit_summary.md"), summary_lines)
  invisible(inventory_out)
}
