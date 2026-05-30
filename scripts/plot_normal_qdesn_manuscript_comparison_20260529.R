#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit)) return(default)
  if (hit[[1L]] == length(args)) stop(sprintf("Missing value for %s.", flag), call. = FALSE)
  args[[hit[[1L]] + 1L]]
}

repo_root <- normalizePath(getwd(), mustWork = TRUE)
input_dir <- normalizePath(
  arg_value(
    "--input-dir",
    file.path(repo_root, "results", "normal_qdesn_unified_source_median_20260529")
  ),
  mustWork = TRUE
)
manuscript_dir <- normalizePath(
  arg_value("--manuscript-dir", file.path(input_dir, "manuscript_ready")),
  mustWork = TRUE
)
output_dir <- arg_value("--output-dir", file.path(manuscript_dir, "figures"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)

read_required <- function(path) {
  if (!file.exists(path)) stop(sprintf("Missing required input file: %s", path), call. = FALSE)
  utils::read.csv(path, check.names = FALSE)
}

required_inputs <- c(
  file.path(manuscript_dir, "manuscript_compact_methods.csv"),
  file.path(manuscript_dir, "manuscript_exact_gate_summary.csv"),
  file.path(manuscript_dir, "manuscript_approximate_summary.csv"),
  file.path(input_dir, "predictions_by_method.csv"),
  file.path(input_dir, "repo_state.csv")
)
invisible(lapply(required_inputs, read_required))

compact <- read_required(required_inputs[[1L]])
exact <- read_required(required_inputs[[2L]])
approx <- read_required(required_inputs[[3L]])
pred <- read_required(required_inputs[[4L]])
repo_state <- read_required(required_inputs[[5L]])

as_bool <- function(x) {
  if (is.logical(x)) return(x)
  tolower(trimws(as.character(x))) %in% c("true", "t", "1", "yes")
}

num <- function(x) suppressWarnings(as.numeric(x))

file_md5 <- function(path) {
  as.character(tools::md5sum(path)[[1L]])
}

repo_value <- function(cmd) {
  out <- tryCatch(system2("git", cmd, stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) return(NA_character_)
  out[[1L]]
}

palette <- c(
  exact = "#2C7FB8",
  approximate = "#41AB5D",
  diagnostic = "#756BB1",
  truth = "#111111",
  observed = "#8C8C8C",
  normal = "#D95F02",
  al = "#1B9E77",
  exal = "#7570B3"
)

target_class <- function(row) {
  if ("primary_spine" %in% names(row) && isTRUE(as_bool(row$primary_spine))) return("exact")
  if ("approximate" %in% names(row) && isTRUE(as_bool(row$approximate))) return("approximate")
  if ("role" %in% names(row) && grepl("approximate", row$role, fixed = TRUE)) return("approximate")
  "diagnostic"
}

method_colors <- vapply(seq_len(nrow(compact)), function(i) {
  palette[[target_class(compact[i, , drop = FALSE])]]
}, character(1L))

short_label <- function(x) {
  x <- as.character(x)
  x <- gsub("^qdesn_", "Q-DESN ", x)
  x <- gsub("^normal_", "Normal ", x)
  x <- gsub("_", " ", x)
  x <- gsub(" rhs ns", " RHS_NS", x, fixed = TRUE)
  x <- gsub(" rhs", " RHS", x, fixed = TRUE)
  x <- gsub(" exal", " exAL", x, fixed = TRUE)
  x <- gsub(" al ", " AL ", paste0(" ", x, " "), fixed = TRUE)
  x <- trimws(x)
  x <- gsub("Normal DESN, ", "Normal ", x, fixed = TRUE)
  x <- gsub("Q-DESN ", "", x, fixed = TRUE)
  x <- gsub(", ", "\n", x, fixed = TRUE)
  x
}

save_png <- function(path, width = 1800, height = 1200, expr) {
  png_args <- list(filename = path, width = width, height = height, res = 180)
  if (isTRUE(capabilities("cairo"))) png_args$type <- "cairo"
  do.call(grDevices::png, png_args)
  old <- graphics::par(no.readonly = TRUE)
  on.exit({
    graphics::par(old)
    grDevices::dev.off()
  }, add = TRUE)
  force(expr)
  invisible(path)
}

predictive_path <- file.path(output_dir, "figure_predictive_metrics.png")
plot_compact <- compact[is.finite(num(compact$pinball)), , drop = FALSE]
if (!nrow(plot_compact)) stop("No finite pinball values in compact method table.", call. = FALSE)
plot_compact$pinball_num <- num(plot_compact$pinball)
plot_compact$rmse_num <- num(plot_compact$rmse)
plot_compact$elapsed_num <- num(plot_compact$elapsed_sec)

save_png(predictive_path, expr = {
  graphics::par(mar = c(8.5, 5.2, 3, 1), xpd = FALSE)
  bp <- graphics::barplot(
    plot_compact$pinball_num,
    names.arg = short_label(plot_compact$table_label),
    las = 2,
    col = method_colors[seq_len(nrow(plot_compact))],
    border = NA,
    ylab = "Pinball/check loss",
    main = "Normal/Q-DESN source-median comparison"
  )
  graphics::abline(h = min(plot_compact$pinball_num, na.rm = TRUE), col = "#555555", lty = 3)
  graphics::legend(
    "topright",
    legend = c("primary exact/full-data", "approximate", "diagnostic"),
    fill = unname(palette[c("exact", "approximate", "diagnostic")]),
    bty = "n"
  )
  invisible(bp)
})

runtime_path <- file.path(output_dir, "figure_runtime_vs_loss.png")
save_png(runtime_path, expr = {
  graphics::par(mar = c(5, 5, 3, 1))
  like <- tolower(as.character(plot_compact$likelihood_family))
  pch <- ifelse(like == "normal", 16, ifelse(like == "al", 17, 15))
  graphics::plot(
    plot_compact$elapsed_num,
    plot_compact$pinball_num,
    pch = pch,
    col = method_colors[seq_len(nrow(plot_compact))],
    bg = method_colors[seq_len(nrow(plot_compact))],
    xlab = "Elapsed seconds",
    ylab = "Pinball/check loss",
    main = "Runtime versus predictive loss",
    log = "x"
  )
  graphics::text(
    plot_compact$elapsed_num,
    plot_compact$pinball_num,
    labels = seq_len(nrow(plot_compact)),
    pos = 4,
    cex = 0.65,
    col = "#222222"
  )
  graphics::legend(
    "topright",
    legend = c("Normal", "AL", "exAL"),
    pch = c(16, 17, 15),
    bty = "n"
  )
})

prediction_path <- file.path(output_dir, "figure_prediction_overlay.png")
pred$method_key <- if ("method_id" %in% names(pred)) as.character(pred$method_id) else NA_character_
missing_key <- is.na(pred$method_key) | !nzchar(pred$method_key)
if ("method" %in% names(pred)) pred$method_key[missing_key] <- as.character(pred$method[missing_key])
selected_pred <- c(
  "normal_scaled_ridge",
  "qdesn_al_ridge_full",
  "qdesn_al_rhs_ns_full",
  "qdesn_exal_rhs_ns_full",
  "qdesn_exal_rhs_ns_hybrid"
)
pred_plot <- pred[pred$method_key %in% selected_pred, , drop = FALSE]
if (nrow(pred_plot)) {
  pred_plot$x <- num(if ("row_index" %in% names(pred_plot)) pred_plot$row_index else NA)
  idx <- !is.finite(pred_plot$x)
  if ("row_id" %in% names(pred_plot)) pred_plot$x[idx] <- num(pred_plot$row_id)[idx]
  idx <- !is.finite(pred_plot$x)
  if ("source_index" %in% names(pred_plot)) pred_plot$x[idx] <- num(pred_plot$source_index)[idx]
  pred_plot$fit <- num(if ("fitted_median" %in% names(pred_plot)) pred_plot$fitted_median else NA)
  if ("point" %in% names(pred_plot)) {
    idx <- !is.finite(pred_plot$fit)
    pred_plot$fit[idx] <- num(pred_plot$point)[idx]
  }
  pred_plot$y_num <- num(pred_plot$y)
  pred_plot$truth <- num(if ("q_target" %in% names(pred_plot)) pred_plot$q_target else NA)
  if ("mu" %in% names(pred_plot)) {
    idx <- !is.finite(pred_plot$truth)
    pred_plot$truth[idx] <- num(pred_plot$mu)[idx]
  }
  pred_plot <- pred_plot[is.finite(pred_plot$x) & is.finite(pred_plot$fit), , drop = FALSE]
}
if (nrow(pred_plot)) {
  save_png(prediction_path, width = 1800, height = 1000, expr = {
    graphics::par(mar = c(5, 5, 3, 1))
    y_range <- range(c(pred_plot$y_num, pred_plot$truth, pred_plot$fit), finite = TRUE)
    graphics::plot(
      pred_plot$x,
      pred_plot$y_num,
      pch = 16,
      cex = 0.35,
      col = grDevices::adjustcolor(palette[["observed"]], alpha.f = 0.45),
      xlab = "Source index / evaluation row",
      ylab = "Value",
      ylim = y_range,
      main = "Selected fitted trajectories"
    )
    truth_rows <- pred_plot[is.finite(pred_plot$truth), c("x", "truth")]
    truth_rows <- truth_rows[!duplicated(truth_rows$x), , drop = FALSE]
    truth_rows <- truth_rows[order(truth_rows$x), , drop = FALSE]
    if (nrow(truth_rows)) graphics::lines(truth_rows$x, truth_rows$truth, col = palette[["truth"]], lwd = 2)
    line_cols <- c(
      normal_scaled_ridge = palette[["normal"]],
      qdesn_al_ridge_full = palette[["al"]],
      qdesn_al_rhs_ns_full = "#66A61E",
      qdesn_exal_rhs_ns_full = palette[["exal"]],
      qdesn_exal_rhs_ns_hybrid = "#E7298A"
    )
    line_labels <- c(
      normal_scaled_ridge = "Normal ridge",
      qdesn_al_ridge_full = "AL ridge",
      qdesn_al_rhs_ns_full = "AL RHS_NS",
      qdesn_exal_rhs_ns_full = "exAL RHS_NS",
      qdesn_exal_rhs_ns_hybrid = "exAL RHS_NS hybrid"
    )
    for (id in intersect(selected_pred, unique(pred_plot$method_key))) {
      z <- pred_plot[pred_plot$method_key == id, , drop = FALSE]
      z <- z[order(z$x), , drop = FALSE]
      graphics::lines(z$x, z$fit, col = line_cols[[id]], lwd = 1.5)
    }
    shown <- names(line_cols)[names(line_cols) %in% unique(pred_plot$method_key)]
    graphics::legend(
      "topright",
      legend = c("observed y", "truth", unname(line_labels[shown])),
      col = c(palette[["observed"]], palette[["truth"]], unname(line_cols[shown])),
      pch = c(16, NA, rep(NA, length(shown))),
      lty = c(NA, 1, rep(1, length(shown))),
      bty = "n",
      cex = 0.75
    )
  })
}

exact_path <- file.path(output_dir, "figure_exact_gates.png")
exact$max_gate <- num(exact$max_gate_diff)
exact$tol <- num(if ("tolerance" %in% names(exact)) exact$tolerance else NA)
exact$label <- ifelse(
  !is.na(exact$candidate_method) & nzchar(as.character(exact$candidate_method)),
  as.character(exact$candidate_method),
  as.character(exact$exact_chunked_method)
)
exact$label[is.na(exact$label) | !nzchar(exact$label)] <- as.character(exact$reference_method[is.na(exact$label) | !nzchar(exact$label)])
exact <- exact[is.finite(exact$max_gate), , drop = FALSE]
if (nrow(exact)) {
  save_png(exact_path, width = 1800, height = 1200, expr = {
    graphics::par(mar = c(5, 15, 3, 1))
    vals <- log10(pmax(exact$max_gate, .Machine$double.eps))
    graphics::barplot(
      rev(vals),
      horiz = TRUE,
      names.arg = rev(short_label(exact$label)),
      las = 1,
      cex.names = 0.68,
      col = "#5B8DB8",
      border = NA,
      xlab = "log10(max exact-gate difference)",
      main = "Exact equivalence gates"
    )
    if (any(is.finite(exact$tol))) {
      graphics::abline(v = log10(max(exact$tol, na.rm = TRUE)), col = "#B2182B", lty = 2, lwd = 1.5)
      graphics::legend("topleft", legend = "largest tolerance", lty = 2, col = "#B2182B", bty = "n")
    }
  })
}

figures <- c(
  predictive_metrics = predictive_path,
  runtime_vs_loss = runtime_path,
  prediction_overlay = if (file.exists(prediction_path)) prediction_path else NA_character_,
  exact_gates = exact_path
)
figures <- figures[file.exists(figures)]

manifest <- data.frame(
  figure_id = names(figures),
  path = unname(figures),
  bytes = as.numeric(file.info(figures)$size),
  input_dir = input_dir,
  manuscript_dir = manuscript_dir,
  package_head = repo_value(c("rev-parse", "--short", "HEAD")),
  repo_state_head_at_run = as.character(repo_state$head[[1L]]),
  stringsAsFactors = FALSE
)
input_hashes <- data.frame(
  input_file = required_inputs,
  md5 = vapply(required_inputs, file_md5, character(1L)),
  stringsAsFactors = FALSE
)
utils::write.csv(manifest, file.path(output_dir, "figure_manifest.csv"), row.names = FALSE)
utils::write.csv(input_hashes, file.path(output_dir, "figure_input_hashes.csv"), row.names = FALSE)

cat("Wrote figures to: ", output_dir, "\n", sep = "")
cat("Wrote manifest: ", file.path(output_dir, "figure_manifest.csv"), "\n", sep = "")
