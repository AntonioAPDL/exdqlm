qdesn_dynamic_candidate_5000_500_audit_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_last5000_last500_audit_manifest.yaml"),
                                                                 repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  manifest <- yaml::read_yaml(yaml_path)
  if (!is.list(manifest)) {
    stop("Candidate 5000/500 audit manifest must decode to a named list.", call. = FALSE)
  }
  manifest
}

.qdesn_dynamic_candidate_5000_500_audit_resolve_state <- function(manifest,
                                                                  repo_root = NULL) {
  cfg <- manifest$analysis %||% list()
  source_parent <- .qdesn_validation_resolve_path(cfg$source_root_parent, repo_root = repo_root, must_work = TRUE)
  scenario_id <- as.character(cfg$scenario_id %||% "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")[1L]
  list(
    source_root = file.path(source_parent, scenario_id)
  )
}

.qdesn_dynamic_candidate_5000_500_audit_build_inventory <- function(manifest,
                                                                    state,
                                                                    repo_root = NULL) {
  inv_path <- file.path(state$source_root, "000__full_root_inventory.csv")
  if (!file.exists(inv_path)) {
    stop(sprintf("Missing candidate full-root inventory: %s", inv_path), call. = FALSE)
  }
  inventory <- utils::read.csv(inv_path, stringsAsFactors = FALSE)
  if (!nrow(inventory)) {
    stop("Candidate full-root inventory is empty.", call. = FALSE)
  }
  filters <- manifest$selection %||% list()
  keep_values <- function(df, col, values) {
    if (is.null(values) || !length(values) || !(col %in% names(df))) return(df)
    vals <- unlist(values, use.names = FALSE)
    vals <- vals[!is.na(vals)]
    if (!length(vals)) return(df)
    df[df[[col]] %in% vals, , drop = FALSE]
  }
  inventory <- keep_values(inventory, "family", as.character(filters$families %||% character()))
  tau_vals <- suppressWarnings(as.numeric(unlist(filters$taus %||% numeric(), use.names = FALSE)))
  tau_vals <- tau_vals[is.finite(tau_vals)]
  if (length(tau_vals) && "tau" %in% names(inventory)) {
    inventory <- inventory[round(as.numeric(inventory$tau), 12L) %in% round(tau_vals, 12L), , drop = FALSE]
  }
  if (!nrow(inventory)) {
    stop("Candidate 5000/500 audit inventory resolved to zero rows.", call. = FALSE)
  }
  inventory <- inventory[order(inventory$family, inventory$tau), , drop = FALSE]
  inventory$plot_index <- seq_len(nrow(inventory))
  inventory$png_file <- sprintf(
    "%03d__%s__tau_%s__last5000_vs_last500.png",
    inventory$plot_index,
    as.character(inventory$family),
    gsub("\\.", "p", sprintf("%.2f", as.numeric(inventory$tau)))
  )
  inventory
}

.qdesn_dynamic_candidate_5000_500_audit_read_series <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  if (!nrow(df) || !all(c("t", "y") %in% names(df))) {
    stop(sprintf("Root series_wide.csv must contain non-empty t and y columns: %s", path), call. = FALSE)
  }
  data.frame(
    t = as.numeric(df$t),
    y = as.numeric(df$y),
    stringsAsFactors = FALSE
  )
}

.qdesn_dynamic_candidate_5000_500_audit_plot_grid <- function(x_ticks, y_ticks, col = "#cbd5e1") {
  graphics::abline(v = x_ticks, h = y_ticks, col = grDevices::adjustcolor(col, alpha.f = 0.55), lwd = 0.8)
}

.qdesn_dynamic_candidate_5000_500_audit_plot_one <- function(row,
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
  out_path <- file.path(output_root, row$png_file[1L])

  series_df <- .qdesn_dynamic_candidate_5000_500_audit_read_series(row$series_wide_path[1L])
  n_obs <- nrow(series_df)
  idx_5000 <- seq.int(max(1L, n_obs - 5000L + 1L), n_obs)
  idx_500 <- seq.int(max(1L, n_obs - 500L + 1L), n_obs)
  x_5000 <- series_df$t[idx_5000]
  y_5000 <- series_df$y[idx_5000]
  x_500 <- series_df$t[idx_500]
  y_500 <- series_df$y[idx_500]

  grDevices::png(out_path, width = width_px, height = height_px, res = res_dpi, bg = bg)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.6, 4.8, 4.2, 1.2), oma = c(0.5, 0.5, 4.8, 0.5), xaxs = "r", yaxs = "r")

  graphics::plot(x_5000, y_5000, type = "n", xlab = "source time index", ylab = "observed value",
                 main = "Canonical last 5000", cex.main = 1.1, font.main = 2)
  usr <- graphics::par("usr")
  graphics::rect(min(x_500), usr[3], max(x_500), usr[4], col = shade_col, border = NA)
  .qdesn_dynamic_candidate_5000_500_audit_plot_grid(pretty(x_5000, n = 6), pretty(y_5000, n = 6))
  graphics::lines(x_5000, y_5000, col = line_col, lwd = 2.4)
  graphics::lines(x_500, y_500, col = accent_col, lwd = 2.8)
  graphics::abline(v = min(x_500), col = accent_col, lwd = 1.5, lty = 2)
  graphics::legend("topleft",
                   legend = c("last 5000 observed", "embedded last 500"),
                   col = c(line_col, accent_col), lwd = c(2.4, 2.8),
                   bty = "n", cex = 0.92)
  graphics::mtext(sprintf("source range=%d:%d | y range=[%.1f, %.1f]",
                          min(x_5000), max(x_5000), min(y_5000), max(y_5000)),
                  side = 3, line = 0.25, cex = 0.86, col = "#475569")

  graphics::plot(x_500, y_500, type = "o", pch = 16, cex = 0.65,
                 col = line_col, lwd = 2.2, xlab = "source time index", ylab = "observed value",
                 main = "Canonical last 500", cex.main = 1.1, font.main = 2)
  .qdesn_dynamic_candidate_5000_500_audit_plot_grid(pretty(x_500, n = 5), pretty(y_500, n = 6))
  graphics::mtext(sprintf("source range=%d:%d | y range=[%.1f, %.1f]",
                          min(x_500), max(x_500), min(y_500), max(y_500)),
                  side = 3, line = 0.25, cex = 0.86, col = "#475569")

  graphics::mtext(
    sprintf("%03d | %s | tau=%.2f | canonical validation windows",
            as.integer(row$plot_index[1L]),
            as.character(row$family[1L]),
            as.numeric(row$tau[1L])),
    side = 3, outer = TRUE, line = 2.5, cex = 1.28, font = 2, col = "#0f172a"
  )
  graphics::mtext(
    sprintf("last5000 = source %d:%d | last500 = source %d:%d",
            min(x_5000), max(x_5000), min(x_500), max(x_500)),
    side = 3, outer = TRUE, line = 1.2, cex = 0.88, col = "#475569"
  )

  data.frame(
    plot_index = as.integer(row$plot_index[1L]),
    png_file = as.character(row$png_file[1L]),
    png_path = normalizePath(out_path, winslash = "/", mustWork = TRUE),
    stringsAsFactors = FALSE
  )
}

qdesn_dynamic_candidate_5000_500_audit_render_plots <- function(inventory,
                                                                output_root,
                                                                manifest = list(),
                                                                max_workers = 1L) {
  rows <- split(inventory, seq_len(nrow(inventory)))
  runner <- function(df) {
    tryCatch(
      .qdesn_dynamic_candidate_5000_500_audit_plot_one(df, output_root = output_root, manifest = manifest),
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

qdesn_dynamic_candidate_5000_500_audit_write_outputs <- function(inventory,
                                                                 render_status,
                                                                 output_root,
                                                                 manifest,
                                                                 state) {
  out <- merge(inventory, render_status, by = c("plot_index", "png_file"), all.x = TRUE, sort = FALSE)
  out <- out[order(out$plot_index), , drop = FALSE]
  .qdesn_validation_write_df(out, file.path(output_root, "000__dataset_index.csv"))
  .qdesn_validation_write_json(file.path(output_root, "000__candidate_5000_500_audit_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    source_root = state$source_root,
    output_root = output_root,
    n_rows = nrow(out)
  ))
  .qdesn_validation_write_lines(file.path(output_root, "000__candidate_5000_500_audit_summary.md"), c(
    "# Candidate 5000/500 Audit Pack",
    "",
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_root: `%s`", state$source_root),
    sprintf("- output_root: `%s`", output_root),
    sprintf("- rows: `%d`", nrow(out)),
    "",
    "## Inventory",
    .qdesn_validation_df_to_markdown(out[, c("plot_index", "family", "tau", "png_file"), drop = FALSE])
  ))
  out
}
