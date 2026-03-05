#!/usr/bin/env Rscript

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

out_root <- Sys.getenv(
  "EXDQLM_STATIC_SIM_OUT",
  "results/sim_suite_static/series/static_exal_mildskew"
)

required <- c("sim_output.rds", "series_wide.csv", "series_long.csv", "meta.txt", "run_config.rds")
missing <- required[!file.exists(file.path(out_root, required))]
if (length(missing)) {
  stop("Missing required files: ", paste(missing, collapse = ", "))
}

sim <- readRDS(file.path(out_root, "sim_output.rds"))
if (!is.list(sim)) stop("sim_output.rds must be a list")
if (!all(c("y", "q", "p", "info", "extras") %in% names(sim))) {
  stop("sim_output.rds missing required top-level fields")
}

TT <- length(sim$y)
if (!is.numeric(sim$y) || TT <= 10L) stop("Invalid y vector")
if (!is.matrix(sim$q)) stop("q must be a matrix")
if (nrow(sim$q) != TT) stop("q row count must match length(y)")
if (ncol(sim$q) != length(sim$p)) stop("q columns must match p length")
if (any(!is.finite(sim$q))) stop("q contains non-finite values")
if (any(!is.finite(sim$p)) || any(sim$p <= 0 | sim$p >= 1)) stop("invalid p grid")

mono_ok <- all(apply(sim$q, 1, function(r) all(diff(r) >= -1e-10)))
if (!mono_ok) stop("q monotonicity check failed")

if (is.null(sim$extras$mu) || length(sim$extras$mu) != TT) stop("extras$mu missing/incompatible")
if (is.null(sim$extras$X) || !is.matrix(sim$extras$X) || nrow(sim$extras$X) != TT) {
  stop("extras$X missing/incompatible")
}

if (is.null(sim$extras$q_al) || !is.matrix(sim$extras$q_al)) stop("extras$q_al missing")
if (!all(dim(sim$extras$q_al) == dim(sim$q))) stop("extras$q_al shape mismatch")

wide <- utils::read.csv(file.path(out_root, "series_wide.csv"), check.names = FALSE)
long <- utils::read.csv(file.path(out_root, "series_long.csv"), check.names = FALSE)
if (nrow(wide) != TT) stop("series_wide row count mismatch")
if (nrow(long) != TT * length(sim$p)) stop("series_long row count mismatch")
if (!all(c("t", "p", "q", "y", "mu") %in% names(long))) stop("series_long missing required columns")

p_int <- pmin(pmax(as.integer(round(100 * sim$p)), 0L), 100L)
q_cols <- sprintf("q_%03d", p_int)
if (!all(q_cols %in% names(wide))) stop("series_wide missing quantile columns")

q_from_wide <- as.matrix(wide[, q_cols, drop = FALSE])
if (max(abs(q_from_wide - sim$q)) > 1e-8) stop("series_wide quantiles do not match sim_output$q")

cfg <- readRDS(file.path(out_root, "run_config.rds"))
if (!is.list(cfg) || is.null(cfg$TT) || is.null(cfg$p_grid)) stop("run_config.rds invalid")

summary_dir <- file.path(out_root, "validation")
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

stats <- data.frame(
  metric = c("TT", "K", "y_mean", "y_sd", "mu_mean", "mu_sd", "gamma_true", "sigma_true", "max_abs_qwide_minus_qrds"),
  value = c(
    TT,
    length(sim$p),
    mean(sim$y),
    stats::sd(sim$y),
    mean(sim$extras$mu),
    stats::sd(sim$extras$mu),
    safe_num(sim$extras$gamma_true),
    safe_num(sim$extras$sigma_true),
    max(abs(q_from_wide - sim$q))
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(stats, file.path(summary_dir, "schema_validation_summary.csv"), row.names = FALSE)

sink(file.path(summary_dir, "schema_validation.txt"))
cat("Static sim schema validation: PASS\n")
cat(sprintf("root: %s\n", out_root))
cat(sprintf("timestamp: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat(sprintf("TT=%d, K=%d\n", TT, length(sim$p)))
cat(sprintf("monotonicity: %s\n", mono_ok))
cat(sprintf("max abs diff (wide vs rds q): %.12f\n", max(abs(q_from_wide - sim$q))))
cat("required files: present\n")
sink()

cat(sprintf("Validation PASS. Summary written to %s\n", summary_dir))
