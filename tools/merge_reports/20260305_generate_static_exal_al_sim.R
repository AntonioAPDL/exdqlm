#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(devtools)
})

devtools::load_all(".", quiet = TRUE)

safe_int <- function(x, default) {
  v <- suppressWarnings(as.integer(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

safe_num <- function(x, default) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(v) || is.na(v)) default else v
}

parse_p_grid <- function(default = c(0.01, seq(0.05, 0.95, by = 0.05), 0.99)) {
  raw <- Sys.getenv("EXDQLM_STATIC_SIM_P_GRID", "")
  if (!nzchar(raw)) return(default)
  vals <- suppressWarnings(as.numeric(strsplit(raw, ",")[[1]]))
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(default)
  sort(unique(vals))
}

TT <- safe_int(Sys.getenv("EXDQLM_STATIC_SIM_TT", "5000"), 5000L)
seed <- safe_int(Sys.getenv("EXDQLM_STATIC_SIM_SEED", "20260305"), 20260305L)
p0_gen <- safe_num(Sys.getenv("EXDQLM_STATIC_SIM_P0", "0.5"), 0.5)
sigma_true <- safe_num(Sys.getenv("EXDQLM_STATIC_SIM_SIGMA", "2.8"), 2.8)
gamma_true <- safe_num(Sys.getenv("EXDQLM_STATIC_SIM_GAMMA", "0.42"), 0.42)
R_mc <- safe_int(Sys.getenv("EXDQLM_STATIC_SIM_R_MC", "4000"), 4000L)
x_min <- safe_num(Sys.getenv("EXDQLM_STATIC_SIM_X_MIN", "-2.75"), -2.75)
x_max <- safe_num(Sys.getenv("EXDQLM_STATIC_SIM_X_MAX", "2.75"), 2.75)
out_root <- Sys.getenv(
  "EXDQLM_STATIC_SIM_OUT",
  "results/sim_suite_static/series/static_exal_rich1d_mcq"
)

if (!(p0_gen > 0 && p0_gen < 1)) stop("p0_gen must be in (0,1)")
if (!is.finite(sigma_true) || sigma_true <= 0) stop("sigma_true must be > 0")
if (!is.finite(gamma_true)) stop("gamma_true must be finite")
if (!is.finite(R_mc) || R_mc < 500L) stop("R_mc must be >= 500")
if (!is.finite(x_min) || !is.finite(x_max) || x_min >= x_max) stop("x range invalid")

L <- L.fn(p0_gen)
U <- U.fn(p0_gen)
if (gamma_true <= L || gamma_true >= U) {
  stop(sprintf("gamma_true=%.4f must be in (L,U)=(%.4f, %.4f)", gamma_true, L, U))
}

p_grid <- parse_p_grid()
if (any(!is.finite(p_grid)) || any(p_grid <= 0 | p_grid >= 1)) {
  stop("Invalid p_grid values")
}

set.seed(seed)
t_idx <- seq_len(TT)
x_main <- stats::runif(TT, min = x_min, max = x_max)
x_sq <- x_main^2
x_sin <- sin(1.35 * x_main)
X <- cbind(1, x_main, x_sq, x_sin)
colnames(X) <- c("intercept", "x_main", "x_sq", "x_sin")

# Rich static signal: nonlinear in x_main, but linear in expanded basis.
beta_true <- c(-0.55, 1.80, -0.72, 1.10)
mu <- as.numeric(drop(X %*% beta_true))
y <- rexal(n = TT, p0 = p0_gen, mu = mu, sigma = sigma_true, gamma = gamma_true)

# Monte-Carlo approximated quantile anchors (dynamic-style truth construction).
set.seed(seed + 101L)
eps_exal <- rexal(n = R_mc, p0 = p0_gen, mu = 0, sigma = sigma_true, gamma = gamma_true)
q0_exal <- as.numeric(stats::quantile(eps_exal, probs = p_grid, names = FALSE, type = 8))

set.seed(seed + 202L)
eps_al <- rexal(n = R_mc, p0 = p0_gen, mu = 0, sigma = sigma_true, gamma = 0)
q0_al <- as.numeric(stats::quantile(eps_al, probs = p_grid, names = FALSE, type = 8))

q_exal <- as.matrix(outer(mu, q0_exal, `+`))
q_al <- as.matrix(outer(mu, q0_al, `+`))
colnames(q_exal) <- formatC(p_grid, digits = 3, format = "f")
colnames(q_al) <- formatC(p_grid, digits = 3, format = "f")

p_int <- pmin(pmax(as.integer(round(100 * p_grid)), 0L), 100L)
q_names <- sprintf("q_%03d", p_int)

wide_df <- data.frame(
  t = t_idx,
  y = y,
  mu = mu,
  x_main = x_main,
  x_sq = x_sq,
  x_sin = x_sin,
  stringsAsFactors = FALSE
)
q_df <- as.data.frame(q_exal)
colnames(q_df) <- q_names
wide_df <- cbind(wide_df, q_df)

long_df <- do.call(rbind, lapply(seq_along(p_grid), function(j) {
  data.frame(
    t = t_idx,
    p = p_grid[j],
    q = q_exal[, j],
    q_al = q_al[, j],
    y = y,
    mu = mu,
    x_main = x_main,
    stringsAsFactors = FALSE
  )
}))

sim_out <- list(
  y = as.numeric(y),
  q = q_exal,
  p = as.numeric(p_grid),
  info = list(
    scenario = "static_exal_rich1d_mcq",
    params = list(
      beta = beta_true,
      sigma_true = sigma_true,
      gamma_true = gamma_true,
      p0_gen = p0_gen,
      TT = TT,
      x_range = c(x_min, x_max)
    ),
    burnin = 0L,
    R_mc = as.integer(R_mc),
    seed = seed,
    quantile_truth_method = "mc_standardized_shift",
    lineage = list(
      dynamic_meta_reference = "results/sim_suite_dlm/series/dlm_constV_smallW/meta.txt",
      dynamic_generator_source = c(
        "/data/muscat_data/jaguir26/exdqlm/scripts/sim_suite_dlm.R",
        "/data/muscat_data/jaguir26/exdqlm/R/simulate_ts_mc_quantiles.R"
      )
    )
  ),
  extras = list(
    mu = as.numeric(mu),
    X = X,
    beta_true = as.numeric(beta_true),
    sigma_true = sigma_true,
    gamma_true = gamma_true,
    p0_gen = p0_gen,
    q_al = q_al,
    x_main = as.numeric(x_main)
  )
)
class(sim_out) <- "ts_mc_quantiles"

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(wide_df, file.path(out_root, "series_wide.csv"), row.names = FALSE)
utils::write.csv(long_df, file.path(out_root, "series_long.csv"), row.names = FALSE)
saveRDS(sim_out, file.path(out_root, "sim_output.rds"), compress = "xz")
saveRDS(list(
  timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  out_root = out_root,
  scenario = "static_exal_rich1d_mcq",
  TT = TT,
  seed = seed,
  p_grid = p_grid,
  R_mc = as.integer(R_mc),
  sigma_true = sigma_true,
  gamma_true = gamma_true,
  p0_gen = p0_gen,
  beta_true = beta_true,
  x_range = c(x_min, x_max)
), file.path(out_root, "run_config.rds"))

sink(file.path(out_root, "meta.txt"))
cat("Static simulation metadata\n")
cat("-------------------------\n")
cat("scenario: static_exal_rich1d_mcq\n")
cat(sprintf("seed: %d\n", seed))
cat(sprintf("TT: %d\n", TT))
cat(sprintf("R_mc: %d\n", as.integer(R_mc)))
cat(sprintf("p0_gen: %.4f\n", p0_gen))
cat(sprintf("sigma_true: %.4f\n", sigma_true))
cat(sprintf("gamma_true: %.4f\n", gamma_true))
cat(sprintf("x range: [%.3f, %.3f]\n", x_min, x_max))
cat("p grid: ", paste(round(100 * p_grid), collapse = ", "), "\n", sep = "")
cat("beta_true: ", paste(sprintf("%.4f", beta_true), collapse = ", "), "\n", sep = "")
cat("quantile_truth_method: mc_standardized_shift\n")
cat("lineage_dynamic_meta: results/sim_suite_dlm/series/dlm_constV_smallW/meta.txt\n")
cat("lineage_generator_refs:\n")
cat("- /data/muscat_data/jaguir26/exdqlm/scripts/sim_suite_dlm.R\n")
cat("- /data/muscat_data/jaguir26/exdqlm/R/simulate_ts_mc_quantiles.R\n")
cat("\n")
str(sim_out$info$params)
str(sim_out$extras[c("beta_true", "sigma_true", "gamma_true", "p0_gen")])
sink()

cat(sprintf("Wrote static simulation artifacts to: %s\n", out_root))
