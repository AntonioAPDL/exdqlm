#!/usr/bin/env Rscript

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_chr <- function(x, default) {
  v <- as.character(x)[1]
  if (!nzchar(v) || is.na(v)) default else v
}

systematic_rank_subsample <- function(x, target_n) {
  n <- length(x)
  if (target_n >= n) return(seq_len(n))
  pos <- floor(seq(0, n - 1, length.out = target_n)) + 1L
  pos <- unique(pos)
  if (length(pos) < target_n) {
    fill <- setdiff(seq_len(n), pos)
    pos <- c(pos, fill[seq_len(target_n - length(pos))])
    pos <- sort(pos)
  }
  pos[seq_len(target_n)]
}

source_sim_path <- Sys.getenv(
  "EXDQLM_STATIC_SUBSAMPLE_SOURCE",
  "results/function_testing_20260306_static_heteroskedastic_skewnormal/sim_output.rds"
)
if (!file.exists(source_sim_path)) stop("Missing source sim file: ", source_sim_path)

target_n <- safe_int(Sys.getenv("EXDQLM_STATIC_SUBSAMPLE_N", "5000"), 5000L)
selection_method <- safe_chr(
  Sys.getenv("EXDQLM_STATIC_SUBSAMPLE_METHOD", "systematic_rank_x_main"),
  "systematic_rank_x_main"
)

source_root <- dirname(source_sim_path)
default_out_root <- file.path(
  source_root,
  sprintf("fit_input_subsample_tt%d_xmain_sorted", target_n)
)
out_root <- Sys.getenv("EXDQLM_STATIC_SUBSAMPLE_OUT", default_out_root)

sim <- readRDS(source_sim_path)
if (is.null(sim$extras$x_main)) stop("Source sim object must contain extras$x_main")
if (is.null(sim$extras$X)) stop("Source sim object must contain extras$X")

n_full <- length(sim$y)
if (target_n < 100L || target_n > n_full) {
  stop("target_n must satisfy 100 <= target_n <= ", n_full)
}

x_main <- as.numeric(sim$extras$x_main)
ord <- order(x_main, seq_along(x_main))
rank_pos <- switch(
  selection_method,
  systematic_rank_x_main = systematic_rank_subsample(x_main[ord], target_n),
  stop("Unsupported selection method: ", selection_method)
)
idx <- ord[rank_pos]

subset_sim <- sim
subset_sim$y <- as.numeric(sim$y[idx])
subset_sim$q <- as.matrix(sim$q[idx, , drop = FALSE])
subset_sim$extras$x_main <- as.numeric(sim$extras$x_main[idx])
subset_sim$extras$cos_term <- as.numeric(sim$extras$cos_term[idx])
subset_sim$extras$mu <- if (!is.null(sim$extras$mu)) as.numeric(sim$extras$mu[idx]) else NULL
subset_sim$extras$sigma <- if (!is.null(sim$extras$sigma)) as.numeric(sim$extras$sigma[idx]) else NULL
subset_sim$extras$X <- as.matrix(sim$extras$X[idx, , drop = FALSE])
subset_sim$extras$source_index <- as.integer(idx)
subset_sim$extras$source_n <- as.integer(n_full)
subset_sim$info$subsample <- list(
  source_sim_path = source_sim_path,
  source_n = as.integer(n_full),
  target_n = as.integer(target_n),
  selection_method = selection_method,
  sorted_by = "x_main"
)
if (!is.null(subset_sim$info$params$n)) subset_sim$info$params$n <- as.integer(target_n)

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

series_wide <- data.frame(
  row_id = seq_len(target_n),
  source_index = as.integer(idx),
  y = subset_sim$y,
  x_main = subset_sim$extras$x_main,
  cos_term = subset_sim$extras$cos_term,
  mu = if (!is.null(subset_sim$extras$mu)) subset_sim$extras$mu else NA_real_,
  sigma = if (!is.null(subset_sim$extras$sigma)) subset_sim$extras$sigma else NA_real_,
  stringsAsFactors = FALSE
)

q_df <- as.data.frame(subset_sim$q, check.names = FALSE)
colnames(q_df) <- sprintf("q_%03d", pmin(pmax(as.integer(round(100 * subset_sim$p)), 0L), 999L))
series_wide <- cbind(series_wide, q_df)

series_long <- do.call(
  rbind,
  lapply(seq_along(subset_sim$p), function(j) {
    data.frame(
      row_id = seq_len(target_n),
      source_index = as.integer(idx),
      x_main = subset_sim$extras$x_main,
      y = subset_sim$y,
      p = subset_sim$p[j],
      q = subset_sim$q[, j],
      stringsAsFactors = FALSE
    )
  })
)

selection_df <- data.frame(
  row_id = seq_len(target_n),
  source_index = as.integer(idx),
  x_main = subset_sim$extras$x_main,
  stringsAsFactors = FALSE
)

utils::write.csv(series_wide, file.path(out_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(series_long, file.path(out_root, "series_long.csv"), row.names = FALSE)
utils::write.csv(selection_df, file.path(out_root, "selection_indices.csv"), row.names = FALSE)
saveRDS(subset_sim, file.path(out_root, "sim_output.rds"))

true_grid_src <- file.path(source_root, "true_quantile_grid.csv")
if (file.exists(true_grid_src)) {
  file.copy(true_grid_src, file.path(out_root, "true_quantile_grid.csv"), overwrite = TRUE)
}

meta_lines <- c(
  "Static fit input subsample",
  "--------------------------",
  sprintf("source sim: %s", source_sim_path),
  sprintf("source n: %d", n_full),
  sprintf("target n: %d", target_n),
  sprintf("selection method: %s", selection_method),
  "ordering: x_main ascending after selection",
  sprintf("scenario: %s", as.character(sim$info$scenario)[1]),
  sprintf("noise family: %s", as.character(sim$info$params$noise_family)[1]),
  sprintf("skew shape: %.4f", as.numeric(sim$info$params$skew_shape)[1]),
  sprintf("truth method: %s", as.character(sim$info$quantile_truth_method)[1]),
  sprintf("saved sim_output.rds: %s", file.path(out_root, "sim_output.rds")),
  sprintf("saved series_wide.csv: %s", file.path(out_root, "series_wide.csv")),
  sprintf("saved series_long.csv: %s", file.path(out_root, "series_long.csv")),
  sprintf("saved selection_indices.csv: %s", file.path(out_root, "selection_indices.csv"))
)
writeLines(meta_lines, file.path(out_root, "meta.txt"))

cat(sprintf("Prepared static fit subsample under: %s\n", out_root))
