qdesn_dynamic_candidate_audit_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_audit_manifest.yaml"),
                                                        repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  manifest <- yaml::read_yaml(yaml_path)
  if (!is.list(manifest)) {
    stop("Candidate dataset audit manifest must decode to a named list.", call. = FALSE)
  }
  manifest
}

.qdesn_dynamic_candidate_audit_resolve_state <- function(manifest,
                                                         repo_root = NULL) {
  cfg <- manifest$analysis %||% list()
  source_parent <- .qdesn_validation_resolve_path(cfg$source_root_parent, repo_root = repo_root, must_work = TRUE)
  scenario_id <- as.character(cfg$scenario_id %||% "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")[1L]
  qdesn_root <- .qdesn_validation_resolve_path(cfg$qdesn_materialized_root, repo_root = repo_root, must_work = TRUE)
  list(
    source_root = file.path(source_parent, scenario_id),
    qdesn_materialized_root = qdesn_root
  )
}

.qdesn_dynamic_candidate_audit_apply_filters <- function(inventory, manifest) {
  filters <- manifest$selection %||% list()
  out <- inventory
  keep_values <- function(col, values) {
    if (is.null(values) || !length(values) || !(col %in% names(out))) return()
    vals <- unlist(values, use.names = FALSE)
    vals <- vals[!is.na(vals)]
    if (!length(vals)) return()
    out <<- out[out[[col]] %in% vals, , drop = FALSE]
  }
  keep_values("scope", as.character(filters$scopes %||% character()))
  keep_values("family", as.character(filters$families %||% character()))
  keep_values("fit_size", as.integer(filters$fit_sizes %||% integer()))
  tau_vals <- suppressWarnings(as.numeric(unlist(filters$taus %||% numeric(), use.names = FALSE)))
  tau_vals <- tau_vals[is.finite(tau_vals)]
  if (length(tau_vals) && "tau" %in% names(out)) {
    out <- out[round(as.numeric(out$tau), 12L) %in% round(tau_vals, 12L), , drop = FALSE]
  }
  out
}

.qdesn_dynamic_candidate_audit_read_series <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!nrow(df)) stop(sprintf("Audit source CSV is empty: %s", path), call. = FALSE)
  if (!all(c("t", "y") %in% names(df))) {
    stop(sprintf("Audit source CSV must contain t and y columns: %s", path), call. = FALSE)
  }
  data.frame(
    t = as.numeric(df$t),
    y = as.numeric(df$y),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_candidate_audit_build_inventory <- function(manifest,
                                                          state,
                                                          repo_root = NULL) {
  source_root <- state$source_root
  canonical_path <- file.path(source_root, "000__canonical_slice_inventory.csv")
  materialized_path <- file.path(state$qdesn_materialized_root, "materialized_source_inventory.csv")
  if (!file.exists(canonical_path)) {
    stop(sprintf("Missing candidate canonical slice inventory: %s", canonical_path), call. = FALSE)
  }
  if (!file.exists(materialized_path)) {
    stop(sprintf("Missing Q-DESN materialized source inventory: %s", materialized_path), call. = FALSE)
  }
  canonical <- utils::read.csv(canonical_path, stringsAsFactors = FALSE)
  materialized <- utils::read.csv(materialized_path, stringsAsFactors = FALSE)
  can_rows <- lapply(seq_len(nrow(canonical)), function(i) {
    row <- canonical[i, , drop = FALSE]
    series_df <- .qdesn_dynamic_candidate_audit_read_series(row$series_wide_path[1L])
    data.frame(
      scope = "canonical_tail",
      family = as.character(row$family[1L]),
      tau = as.numeric(row$tau[1L]),
      fit_size = as.integer(row$fit_size[1L]),
      window_label = as.character(row$window_label[1L]),
      source_index_first = as.integer(row$source_index_first[1L]),
      source_index_last = as.integer(row$source_index_last[1L]),
      observed_path = normalizePath(row$series_wide_path[1L], winslash = "/", mustWork = TRUE),
      n_obs = nrow(series_df),
      y_min = min(series_df$y),
      y_max = max(series_df$y),
      y_sd = stats::sd(series_df$y),
      stringsAsFactors = FALSE
    )
  })
  q_rows <- lapply(seq_len(nrow(materialized)), function(i) {
    row <- materialized[i, , drop = FALSE]
    series_df <- .qdesn_dynamic_candidate_audit_read_series(row$source_series_wide_path[1L])
    sel_df <- utils::read.csv(row$source_selection_indices_path[1L], stringsAsFactors = FALSE)
    data.frame(
      scope = "qdesn_window",
      family = as.character(row$source_family[1L]),
      tau = as.numeric(row$tau[1L]),
      fit_size = as.integer(row$effective_fit_size[1L]),
      window_label = as.character(row$source_window_label[1L]),
      source_index_first = as.integer(sel_df$source_index[1L]),
      source_index_last = as.integer(sel_df$source_index[nrow(sel_df)]),
      observed_path = normalizePath(row$source_series_wide_path[1L], winslash = "/", mustWork = TRUE),
      n_obs = nrow(series_df),
      y_min = min(series_df$y),
      y_max = max(series_df$y),
      y_sd = stats::sd(series_df$y),
      stringsAsFactors = FALSE
    )
  })
  inventory <- .qdesn_validation_bind_rows(c(can_rows, q_rows))
  inventory <- .qdesn_dynamic_candidate_audit_apply_filters(inventory, manifest)
  if (!nrow(inventory)) {
    stop("Candidate audit inventory resolved to zero rows.", call. = FALSE)
  }
  inventory$scope_rank <- ifelse(inventory$scope == "canonical_tail", 1L, 2L)
  inventory <- inventory[order(inventory$scope_rank, inventory$family, inventory$tau, inventory$fit_size, inventory$window_label), , drop = FALSE]
  inventory$scope_rank <- NULL
  inventory$plot_index <- seq_len(nrow(inventory))
  inventory$png_file <- sprintf(
    "%03d__%s__%s__tau_%s__fit_%s__%s.png",
    inventory$plot_index,
    ifelse(inventory$scope == "canonical_tail", "exdqlm", "qdesn"),
    inventory$family,
    gsub("\\.", "p", sprintf("%.2f", as.numeric(inventory$tau))),
    as.integer(inventory$fit_size),
    gsub("[^a-zA-Z0-9]+", "_", inventory$window_label)
  )
  inventory
}

.qdesn_dynamic_candidate_audit_plot_one <- function(row,
                                                    output_root,
                                                    manifest = list()) {
  plot_cfg <- manifest$plotting %||% list()
  width_px <- as.integer(plot_cfg$width_px %||% 2600L)
  height_px <- as.integer(plot_cfg$height_px %||% 1300L)
  res_dpi <- as.integer(plot_cfg$res_dpi %||% 150L)
  bg <- as.character(plot_cfg$background %||% "#ffffff")
  line_col <- as.character(plot_cfg$line_color %||% "#334155")
  accent_col <- as.character(plot_cfg$accent_color %||% "#ea580c")
  shade_col <- grDevices::adjustcolor(accent_col, alpha.f = 0.12)
  series_df <- .qdesn_dynamic_candidate_audit_read_series(row$observed_path[1L])
  x <- seq_len(nrow(series_df))
  tail_start <- max(1L, nrow(series_df) - 99L)
  tail_idx <- tail_start:nrow(series_df)
  out_path <- file.path(output_root, row$png_file[1L])

  grDevices::png(out_path, width = width_px, height = height_px, res = res_dpi, bg = bg)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.6, 4.8, 4.2, 1.2), oma = c(0.5, 0.5, 4.8, 0.5), xaxs = "r", yaxs = "r")

  graphics::plot(x, series_df$y, type = "n", xlab = "time index", ylab = "observed value",
                 main = "Full window", cex.main = 1.1, font.main = 2)
  usr <- graphics::par("usr")
  graphics::rect(tail_start, usr[3], length(x), usr[4], col = shade_col, border = NA)
  graphics::abline(v = pretty(x, n = 6), h = pretty(series_df$y, n = 6), col = grDevices::adjustcolor("#cbd5e1", alpha.f = 0.55), lwd = 0.8)
  graphics::lines(x, series_df$y, col = line_col, lwd = 2.4)
  graphics::lines(tail_idx, series_df$y[tail_idx], col = accent_col, lwd = 2.8)
  graphics::abline(v = tail_start, col = accent_col, lwd = 1.5, lty = 2)
  graphics::legend("topleft", legend = c("observed", "last 100 obs"), col = c(line_col, accent_col), lwd = c(2.4, 2.8), bty = "n", cex = 0.92)

  graphics::plot(tail_idx, series_df$y[tail_idx], type = "o", pch = 16, cex = 0.7, col = line_col, lwd = 2.2,
                 xlab = "time index (last 100)", ylab = "observed value", main = "Zoom: last 100 points",
                 cex.main = 1.1, font.main = 2)
  graphics::abline(v = pretty(tail_idx, n = 5), h = pretty(series_df$y[tail_idx], n = 6), col = grDevices::adjustcolor("#cbd5e1", alpha.f = 0.55), lwd = 0.8)

  graphics::mtext(
    sprintf("%03d | %s | %s | tau=%.2f | fit=%d | %s",
            as.integer(row$plot_index[1L]),
            ifelse(row$scope[1L] == "canonical_tail", "exdqlm", "qdesn"),
            as.character(row$family[1L]),
            as.numeric(row$tau[1L]),
            as.integer(row$fit_size[1L]),
            as.character(row$window_label[1L])),
    side = 3, outer = TRUE, line = 2.6, cex = 1.3, font = 2, col = "#0f172a"
  )
  graphics::mtext(
    sprintf("n=%d | source=%d:%d | y_range=[%.1f, %.1f] | sd=%.1f",
            as.integer(row$n_obs[1L]),
            as.integer(row$source_index_first[1L]),
            as.integer(row$source_index_last[1L]),
            as.numeric(row$y_min[1L]),
            as.numeric(row$y_max[1L]),
            as.numeric(row$y_sd[1L])),
    side = 3, outer = TRUE, line = 1.2, cex = 0.88, col = "#475569"
  )

  data.frame(
    plot_index = as.integer(row$plot_index[1L]),
    png_file = as.character(row$png_file[1L]),
    png_path = normalizePath(out_path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_candidate_audit_render_plots <- function(inventory,
                                                       output_root,
                                                       manifest = list(),
                                                       max_workers = 1L) {
  rows <- split(inventory, seq_len(nrow(inventory)))
  runner <- function(df) {
    tryCatch(
      .qdesn_dynamic_candidate_audit_plot_one(df, output_root = output_root, manifest = manifest),
      error = function(e) data.frame(
        plot_index = as.integer(df$plot_index[1L]),
        png_file = as.character(df$png_file[1L]),
        png_path = NA_character_,
        error = conditionMessage(e),
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

qdesn_dynamic_candidate_audit_write_outputs <- function(inventory,
                                                        render_status,
                                                        output_root,
                                                        manifest,
                                                        state) {
  out <- merge(inventory, render_status, by = c("plot_index", "png_file"), all.x = TRUE, sort = FALSE)
  out <- out[order(out$plot_index), , drop = FALSE]
  .qdesn_validation_write_df(out, file.path(output_root, "000__dataset_index.csv"))
  .qdesn_validation_write_json(file.path(output_root, "000__candidate_dataset_audit_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    source_root = state$source_root,
    qdesn_materialized_root = state$qdesn_materialized_root,
    output_root = output_root,
    n_rows = nrow(out)
  ))
  .qdesn_validation_write_lines(file.path(output_root, "000__candidate_dataset_audit_summary.md"), c(
    "# Candidate Dataset Audit Pack",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_root: `%s`", state$source_root),
    sprintf("- qdesn_materialized_root: `%s`", state$qdesn_materialized_root),
    sprintf("- output_root: `%s`", output_root),
    sprintf("- rows: `%d`", nrow(out)),
    "",
    "## Inventory",
    .qdesn_validation_df_to_markdown(out[, c("plot_index", "scope", "family", "tau", "fit_size", "window_label", "png_file"), drop = FALSE])
  ))
  out
}
