#' Distribution-first model selection for Q-DESN (shared spec across quantiles)
#'
#' For each candidate *shared* specification, fit Q-DESN readouts at p ∈ {0.05, 0.50, 0.95},
#' synthesize a single predictive distribution (isotone + rearrangement), and select the
#' spec with the lowest CRPS (approximated via averaged pinball loss over the empirical
#' quantile grid extracted from the synthesized draws).
#'
#' Parallelized across candidate specifications; within a spec, the 3 quantiles are fit
#' sequentially (to share the same reservoir seed). Optionally average scores across
#' multiple seeds to reduce reservoir-seed variance.
#'
#' Requires in scope:
#'   - qdesn_fit_vb(), posterior_predict.qdesn_fit()
#'   - exdqlm_synthesize_from_draws()
#'
#' Author: Antonio Aguirre
#' ------------------------------------------------------------------------------

## ================================================================
## 0) Setup
## ================================================================
options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  width = 120,
  future.rng.onMisuse = "ignore"
)
req_pkgs <- c("devtools","ggplot2","dplyr","tidyr","tibble","scales",
              "purrr","future","furrr","progressr")
need <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(need)) install.packages(need, dependencies = TRUE)
invisible(lapply(req_pkgs, require, character.only = TRUE))

# Optional: cap BLAS threads inside each worker to avoid oversubscription
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L)
}

# Load local package with qdesn + exAL (from this repo)
suppressMessages({
  devtools::load_all(".")
})


## ================================================================
## 1) Config — change here to explore
## ================================================================
# Selection stage: "coarse" (fast) or "final" (thorough)
stage <- "coarse"  # set to "final" for the winner re-run

# Accept either EXDQLM_DATA (preferred) or QDESN_DATA; allow file OR directory
csv_env <- Sys.getenv("EXDQLM_DATA", Sys.getenv("QDESN_DATA", NA))
if (!is.na(csv_env) && dir.exists(csv_env)) {
  csv_env <- file.path(csv_env, "data_USGS_ppt_soil.csv")
}


csv_candidates <- c(
  if (!is.na(csv_env)) csv_env,
  "/data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv",   # server path
  "C:/Users/anton/Downloads/data_USGS_ppt_soil.csv",          # Windows
  "/mnt/c/Users/anton/Downloads/data_USGS_ppt_soil.csv",      # WSL
  path.expand("~/Downloads/data_USGS_ppt_soil.csv"),          # macOS/Linux
  file.path(getwd(), "data_USGS_ppt_soil.csv")                # project copy
)

csv_path <- NULL
for (p in csv_candidates) {
  if (file.exists(p)) { csv_path <- p; break }
}
if (is.null(csv_path)) {
  cat("Working directory:", getwd(), "\n")
  cat("Tried:\n", paste(" -", csv_candidates), sep = "\n")
  stop("Could not locate 'data_USGS_ppt_soil.csv'. Set EXDQLM_DATA or place the file accordingly.")
} else {
  message("Using data file: ", csv_path)
}

# Quantiles we fit jointly (shared spec)
p_vec <- c(0.05, 0.50, 0.95)

# VB readout defaults
vb_args <- list(
  max_iter   = if (stage=="coarse") 800  else 1800,
  tol        = 1e-4,
  n_samp_xi  = if (stage=="coarse") 300  else 1000,
  verbose    = FALSE   # keep quiet during selection for speed
)

# Predictive draws & synthesis (selection-time settings)
nd_draws       <- if (stage=="coarse")  600L else 2000L   # per quantile model
chunk_sz       <- 200L
synth_grid_M   <- if (stage=="coarse")  401L else 1001L
synth_nsamp    <- if (stage=="coarse")  800L else 2000L  # synthesized draws per time
synth_isotonic <- TRUE
synth_rearrange<- if (stage=="coarse")  FALSE else TRUE  # turn on rearrangement for final
synth_seed     <- 999

# Scoring window (slice LAST N points **before** synthesis for speed)
score_last_N   <- if (stage=="coarse") 800L else 1500L

# Reservoir seeds to average across (reduces variance of selection)
seed_vec <- c(42, 101)  # add more (e.g., 202) if you can afford it

# Parallel plan (deterministic)
workers_env <- suppressWarnings(as.integer(Sys.getenv("QDESN_WORKERS", "")))
workers <- if (!is.na(workers_env) && workers_env > 0) workers_env else max(1, parallel::detectCores() - 1)
future::plan(future::multisession, workers = workers)
message(sprintf("Future plan: multisession with %d workers", workers))

# Output control
save_artifacts <- FALSE
out_dir <- file.path(getwd(), "model_selection_outputs")
if (save_artifacts && !dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

## ================================================================
## 2) Helpers (lags, μ-band, slicing, CRPS via pinball)
## ================================================================
lag_mat <- function(x, L) {
  T <- length(x); L <- as.integer(L)
  if (L <= 0) return(matrix(numeric(0), nrow = T, ncol = 0))
  M <- matrix(0, nrow = T, ncol = L)
  for (j in 1:L) M[(j+1):T, j] <- x[1:(T - j)]
  colnames(M) <- paste0(deparse(substitute(x)), "_l", 1:L)
  M
}

mu_band <- function(X, qbeta, level = 0.95) {
  m <- as.numeric(qbeta$m); V <- as.matrix(qbeta$V)
  mu <- as.numeric(X %*% m)
  XV <- X %*% V
  var <- rowSums(XV * X); se <- sqrt(pmax(var, 0))
  z <- qnorm(0.5 + level/2)
  tibble::tibble(mu = mu, lo = mu - z*se, hi = mu + z*se)
}

slice_last <- function(x, N) {
  n <- length(x); i1 <- max(1L, n - as.integer(N) + 1L)
  x[i1:n]
}
slice_last_rows <- function(M, N) {
  nr <- nrow(M); i1 <- max(1L, nr - as.integer(N) + 1L)
  M[i1:nr, , drop = FALSE]
}

# CRPS approx at a single time (draws -> empirical τ-grid; average pinball)
crps_from_draws_1 <- function(y_true, draws_vec) {
  x <- sort(as.numeric(draws_vec))
  N <- length(x); if (N < 5) return(NA_real_)
  tau <- (seq_len(N)) / (N + 1)
  res <- y_true - x
  rho <- (tau - as.numeric(res < 0)) * res
  (2 / N) * sum(rho)
}

# Row-wise CRPS on last N rows of synthesized draws against y (aligned)
crps_from_draws_window <- function(draws, y_vec, last_N) {
  stopifnot(nrow(draws) == length(y_vec))
  Dsub <- slice_last_rows(draws, last_N)
  ysub <- slice_last(y_vec, last_N)
  vapply(seq_len(nrow(Dsub)), function(i) crps_from_draws_1(ysub[i], Dsub[i, ]), 1.0)
}

## ================================================================
## 3) Load & sanitize data (headers -> usgs/ppt/soil)
## ================================================================
dat_raw <- read.csv(csv_path, check.names = FALSE, stringsAsFactors = FALSE)
nm <- gsub("\ufeff", "", names(dat_raw), fixed = TRUE) |> trimws() |> tolower()
names(dat_raw) <- nm
syn_map <- c("precip"="ppt","prcp"="ppt","rain"="ppt",
             "soil_moisture"="soil","soilmoist"="soil","sm"="soil")
for (old in names(syn_map)) if (old %in% names(dat_raw)) names(dat_raw)[names(dat_raw)==old] <- syn_map[[old]]

need_cols <- c("usgs","ppt","soil")
if (!all(need_cols %in% names(dat_raw))) stop("CSV must contain: usgs, ppt, soil.")
dat <- tibble::as_tibble(dat_raw[, need_cols])
for (c in need_cols) dat[[c]] <- as.numeric(dat[[c]])

y    <- dat$usgs
ppt  <- dat$ppt
soil <- dat$soil
T_full <- length(y)

## ================================================================
## 4) Candidate grid (shared spec across the three quantiles)
## ================================================================
# Helpers to build layer sizes, reduction and rho patterns
rho_pattern <- function(D, kind=c("flat","decay")) {
  kind <- match.arg(kind)
  if (kind=="flat")  rep(0.90, D) else head(c(0.95,0.90,0.85), D)
}
make_n_tilde <- function(n, ratio=0.2) {
  if (length(n) <= 1) integer(0) else pmax(1L, as.integer(round(head(n,-1) * ratio)))
}

# Candidate components
D_vals     <- c(2L, 3L)
n_packs    <- list(c(200L,100L),
                   c(300L,150L),
                   c(300L,150L,80L),
                   c(400L,200L,100L))
red_ratios <- c(0.20, 0.30)
alpha_vals <- c(0.20, 0.25, 0.30)
rho_kinds  <- c("flat","decay")
act_f_vals <- c("tanh","relu")
m_vals     <- c(12L, 24L, 36L)
wash_vals  <- c(200L)
bias_vals  <- c(FALSE, TRUE)
lags_pairs <- list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L), c(14L,14L))

# Build list-of-rows safely
specs_list <- list()
for (D in D_vals) {
  for (n in n_packs) {
    if (length(n) != D) next
    for (rr in red_ratios) {
      n_tilde <- make_n_tilde(n, rr)
      for (alpha in alpha_vals) {
        for (rk in rho_kinds) {
          rho <- rho_pattern(D, rk)
          for (af in act_f_vals) {
            for (m in m_vals) for (wo in wash_vals) for (ab in bias_vals) {
              for (lp in lags_pairs) {
                # simple hygiene: avoid relu with ultra-small alpha if desired
                if (af == "relu" && alpha < 0.20) next
                specs_list[[length(specs_list)+1L]] <- list(
                  D = D, n = n, n_tilde = n_tilde,
                  alpha = alpha, rho = rho, act_f = af, act_k = "identity",
                  m = m, washout = wo, add_bias = ab,
                  lags_ppt = lp[1], lags_soil = lp[2],
                  red_ratio = rr, rho_kind = rk
                )
              }
            }
          }
        }
      }
    }
  }
}
cartesian_specs <- tibble::as_tibble(specs_list)
cartesian_specs <- dplyr::distinct(cartesian_specs)
message("Candidate specs: ", nrow(cartesian_specs))

## ================================================================
## 5) One-spec-one-seed fitter (3 quantiles → slice → synthesis → CRPS)
## ================================================================
spec_key <- function(row) {
  paste0(
    "D", row$D,
    "_n", paste0(unlist(row$n), collapse="-"),
    "_r", row$rho_kind,
    "_a", sprintf("%.2f", row$alpha),
    "_m", row$m,
    "_w", row$washout,
    "_f", row$act_f,
    "_b", as.integer(row$add_bias),
    "_lp", row$lags_ppt,
    "_ls", row$lags_soil
  )
}

fit_spec_once <- function(spec, seed) {
  t0 <- proc.time()[3]

  # Unpack
  D <- spec$D; n <- unlist(spec$n); n_tilde <- unlist(spec$n_tilde)
  alpha <- spec$alpha; rho <- unlist(spec$rho)
  act_f <- spec$act_f; act_k <- spec$act_k
  m <- spec$m; washout <- spec$washout
  add_bias <- isTRUE(spec$add_bias)
  lags_ppt <- spec$lags_ppt; lags_soil <- spec$lags_soil

  # Fixed sparsity
  pi_w <- 0.05; pi_in <- 0.20

  desn_args <- list(
    D=D, n=n, n_tilde=n_tilde,
    m=m, alpha=alpha, rho=rho,
    act_f=act_f, act_k=act_k,
    pi_w=pi_w, pi_in=pi_in,
    washout=washout, add_bias=add_bias,
    seed=seed
  )

  # Exogenous lag block (full length)
  X_ppt  <- lag_mat(ppt,  lags_ppt)
  X_soil <- lag_mat(soil, lags_soil)
  X_cov_full <- cbind(X_ppt, X_soil)
  maxlag_cov <- max(lags_ppt, lags_soil)

  # Fit one quantile with exogenous lags appended to the readout
  fit_q <- function(p0) {
    fit0 <- do.call(qdesn_fit_vb, c(list(y=y, p0=p0, vb_args=vb_args), desn_args))
    keep_idx <- fit0$meta$keep_idx
    y_fit    <- fit0$y_fit
    X_res    <- fit0$X

    # Trim earliest aligned points if covariate lags not available
    trim_n <- sum(keep_idx <= maxlag_cov)
    if (trim_n > 0) {
      keep_idx <- keep_idx[-seq_len(trim_n)]
      y_fit    <- y_fit[-seq_len(trim_n)]
      X_res    <- X_res[-seq_len(trim_n), , drop=FALSE]
    }
    X_cov <- if (ncol(X_cov_full)) X_cov_full[keep_idx, , drop=FALSE] else
              matrix(numeric(0), nrow=length(keep_idx), ncol=0)
    X_aug <- cbind(X_res, X_cov)

    fit_readout <- exal_static_LDVB(
      y=y_fit, X=X_aug, p0=p0,
      max_iter=vb_args$max_iter, tol=vb_args$tol,
      b0=rep(0, ncol(X_aug)),
      V0=diag(1e4, ncol(X_aug)),
      a_sigma=1, b_sigma=1,
      n_samp_xi=vb_args$n_samp_xi,
      verbose=FALSE
    )

    mu_df <- mu_band(X_aug, fit_readout$qbeta, level=0.95)
    df_mu <- tibble::tibble(
      t_aligned=seq_len(nrow(X_aug)),
      y=y_fit, mu=mu_df$mu, lo=mu_df$lo, hi=mu_df$hi, p0=p0
    )

    # Build qdesn_fit-like object so posterior_predict() works
    fit_exog <- list(
      fit = fit_readout,
      X = X_aug, y_fit = y_fit, mu_hat = mu_df$mu,
      reservoir = fit0$reservoir, states = fit0$states,
      meta = list(
        keep_idx=keep_idx,
        drop=max(m, washout, maxlag_cov),
        T=T_full, p0=p0, D=D, n=n, n_tilde=n_tilde,
        m=m, alpha=alpha, rho=rho, add_bias=add_bias
      )
    )
    class(fit_exog) <- "qdesn_fit"
    list(fit=fit_exog, df_mu=df_mu)
  }

  # Fit all three quantiles (sequential within spec/seed)
  fits <- lapply(p_vec, fit_q); names(fits) <- paste0("p=", p_vec)

  # Common trailing alignment across p (take min length)
  T_common <- min(sapply(fits, function(o) nrow(o$df_mu)))
  fits <- lapply(fits, function(o) { o$df_mu <- tail(o$df_mu, T_common); o })
  y_aligned <- fits[[1]]$df_mu$y

  # Extra guard: identical trailing keep_idx across fits
  ki_mat <- do.call(cbind, lapply(fits, function(o) tail(o$fit$meta$keep_idx, T_common)))
  stopifnot(all(apply(ki_mat, 1, function(r) length(unique(r))==1)))

  # Predictive draws per model
  pp_draws <- lapply(fits, function(x)
    posterior_predict.qdesn_fit(x$fit, nd=nd_draws, chunk=chunk_sz)$yrep
  )
  # Ensure identical T_common × nd
  pp_draws <- lapply(pp_draws, function(M) tail(M, T_common))

  # ---- Slice BEFORE synthesis to the last score_last_N points
  lastN <- min(T_common, score_last_N)
  idx_tail <- (T_common - lastN + 1L):T_common
  pp_draws <- lapply(pp_draws, function(M) M[idx_tail, , drop=FALSE])
  y_aligned <- y_aligned[idx_tail]
  T_common  <- nrow(pp_draws[[1]])

  # Synthesis on the sliced window
  synth <- exdqlm_synthesize_from_draws(
    draws_list = pp_draws,
    p          = p_vec,
    enforce_isotonic = synth_isotonic,
    rearrange        = synth_rearrange,
    grid_M           = synth_grid_M,
    n_samp           = synth_nsamp,
    seed             = synth_seed,
    T_expected       = T_common
  )

  # CRPS vector (now equals whole window)
  crps_vec  <- crps_from_draws_window(synth$draws, y_aligned, last_N = T_common)
  mean_crps <- mean(crps_vec, na.rm = TRUE)

  # Coverage diagnostics: Pr[y ≤ μ] ≈ p0, band width medians (on same window)
  coverage <- dplyr::bind_rows(lapply(seq_along(p_vec), function(k) {
    d <- tail(fits[[k]]$df_mu, T_common)
    tibble::tibble(
      p0 = p_vec[k],
      cov = mean(d$y <= d$mu, na.rm=TRUE),
      avg_bw = median(d$hi - d$lo, na.rm=TRUE)
    )
  }))

  # PIT summary from synthesized draws (calibration readout)
  pit <- rowMeans(synth$draws <= y_aligned)
  pit_mean <- mean(pit)
  pit_var  <- var(pit)
  pit_dev_mean <- pit_mean - 0.5
  pit_dev_var  <- pit_var  - (1/12)

  elapsed_sec <- as.numeric(proc.time()[3] - t0)

  # cleanup
  rm(X_ppt, X_soil, X_cov_full, pp_draws); gc()

  list(
    mean_crps = mean_crps,
    crps = crps_vec,
    y_aligned = y_aligned,
    synth = synth,
    fits = fits,
    T_common = T_common,
    coverage = coverage,
    pit = list(mean = pit_mean, var = pit_var,
               dev_mean = pit_dev_mean, dev_var = pit_dev_var),
    elapsed_sec = elapsed_sec,
    complexity = list(sum_n = sum(n), D = D, lags_tot = lags_ppt + lags_soil)
  )
}

## ================================================================
## 6) Run selection in parallel across candidate specs (robust)
## ================================================================
progressr::handlers(global = TRUE)
progressr::handlers(progressr::handler_txtprogressbar)

with(progressr::progressor(along = seq_len(nrow(cartesian_specs))) %<-% p, {

  results <- furrr::future_map(
    seq_len(nrow(cartesian_specs)),
    function(i) {
      row <- cartesian_specs[i,]
      key <- spec_key(row)
      p(sprintf("Spec %d/%d: %s", i, nrow(cartesian_specs), key))

      # Average across seeds (sequentially to share CPU with parallel specs)
      seed_runs <- tryCatch({
        lapply(seed_vec, function(sd) fit_spec_once(row, seed = sd))
      }, error = function(e) {
        list(error = TRUE, msg = conditionMessage(e))
      })

      if (isTRUE(seed_runs$error)) {
        return(list(
          spec_idx = i, spec_key = key, spec_row = row,
          mean_crps = Inf, se_crps = NA_real_,
          cov_tbl = tibble::tibble(p0=p_vec, cov=NA_real_, avg_bw=NA_real_),
          pit = list(mean=NA_real_, var=NA_real_, dev_mean=NA_real_, dev_var=NA_real_),
          exemplar = NULL, elapsed_sec = NA_real_,
          complexity = list(sum_n = sum(unlist(row$n)),
                            D = row$D,
                            lags_tot = row$lags_ppt + row$lags_soil),
          error = seed_runs$msg
        ))
      }

      crps_means <- vapply(seed_runs, function(x) x$mean_crps, 1.0)
      mean_crps  <- mean(crps_means, na.rm = TRUE)
      se_crps    <- sd(crps_means, na.rm = TRUE) / sqrt(length(seed_runs))

      cov_tbl <- dplyr::bind_rows(lapply(seed_runs, function(z) z$coverage)) |>
        dplyr::group_by(p0) |>
        dplyr::summarise(cov = mean(cov), avg_bw = median(avg_bw), .groups="drop")

      pit_tbl <- dplyr::bind_rows(lapply(seed_runs, function(z)
        tibble::tibble(mean = z$pit$mean, var = z$pit$var,
                       dev_mean = z$pit$dev_mean, dev_var = z$pit$dev_var)))
      pit_avg <- colMeans(pit_tbl, na.rm = TRUE)

      elapsed_sec <- sum(vapply(seed_runs, function(x) x$elapsed_sec, 1.0), na.rm = TRUE)

      list(
        spec_idx = i, spec_key = key, spec_row = row,
        mean_crps = mean_crps, se_crps = se_crps,
        cov_tbl = cov_tbl,
        pit = as.list(pit_avg),
        exemplar = seed_runs[[1]],     # keep first seed artifacts for quick plotting
        elapsed_sec = elapsed_sec,
        complexity = list(sum_n = sum(unlist(row$n)),
                          D = row$D,
                          lags_tot = row$lags_ppt + row$lags_soil),
        error = NULL
      )
    },
    .options = furrr::furrr_options(seed = TRUE) # deterministic
  )

  ## ================================================================
  ## 7) Leaderboard & winner (with simple tie-breakers)
  ## ================================================================
  leaderboard <- dplyr::bind_rows(lapply(results, function(r) {
    tibble::tibble(
      spec_idx = r$spec_idx,
      spec_key = r$spec_key,
      mean_CRPS = r$mean_crps,
      se_CRPS   = r$se_crps,
      cov_05    = r$cov_tbl$cov[r$cov_tbl$p0==0.05],
      cov_50    = r$cov_tbl$cov[r$cov_tbl$p0==0.50],
      cov_95    = r$cov_tbl$cov[r$cov_tbl$p0==0.95],
      bw_med    = r$cov_tbl$avg_bw[r$cov_tbl$p0==0.50],
      pit_mean  = r$pit$mean,
      pit_var   = r$pit$var,
      elapsed_s = r$elapsed_sec,
      sum_n     = r$complexity$sum_n,
      D         = r$complexity$D,
      lags_tot  = r$complexity$lags_tot,
      error     = if (!is.null(r$error)) r$error else NA_character_
    )
  })) |>
    dplyr::filter(is.finite(mean_CRPS)) |>
    dplyr::arrange(mean_CRPS, sum_n, D, lags_tot)

  print(utils::head(leaderboard, 10))

  # Winner: smallest CRPS, tie-break by model complexity
  best_row <- leaderboard[1, ]
  best     <- results[[ best_row$spec_idx ]]

  message("\nWinner: ", best$spec_key,
          " | mean CRPS = ", sprintf("%.4f", best$mean_crps),
          " (±", sprintf("%.4f", best$se_crps), ")",
          " | sum_n=", best$complexity$sum_n,
          " | D=", best$complexity$D,
          " | lags_tot=", best$complexity$lags_tot,
          " | elapsed_s≈", round(best$elapsed_sec,1))

  winner_bundle <- list(
    stage     = stage,
    spec_key  = best$spec_key,
    spec      = best$spec_row,
    leaderboard = leaderboard,
    # exemplar seed artifacts (aligned, sliced window)
    y_aligned = best$exemplar$y_aligned,
    fits      = best$exemplar$fits,
    synth     = best$exemplar$synth,
    coverage  = best$exemplar$coverage,
    pit       = best$pit,
    T_window  = best$exemplar$T_common,
    config    = list(
      p_vec = p_vec,
      vb_args = vb_args,
      nd_draws = nd_draws,
      synth = list(grid_M = synth_grid_M, nsamp = synth_nsamp,
                   isotonic = synth_isotonic, rearrange = synth_rearrange, seed = synth_seed),
      scoring = list(last_N = score_last_N, seed_vec = seed_vec)
    )
  )

  if (save_artifacts) {
    saveRDS(winner_bundle, file.path(out_dir, paste0("winner_bundle_", stage, ".rds")))
    write.csv(leaderboard, file.path(out_dir, paste0("leaderboard_", stage, ".csv")), row.names = FALSE)
  }

  ## ================================================================
  ## 8) (Optional) quick diagnostic plots for the winner
  ## ================================================================
  try({
    # Overlay μ (95% bands) for all p on last min(300, T_window) points
    T_win <- winner_bundle$T_window
    showN <- min(300L, T_win)
    mu_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(k) {
      d <- winner_bundle$fits[[k]]$df_mu
      d$t_aligned <- seq_len(nrow(d))
      d$p_chr <- as.character(p_vec[k])
      tail(d, showN)
    }))
    col_line <- c("0.05"="#8B0000","0.50"="#006400","0.95"="#0F2E6E")
    gg <- ggplot2::ggplot(mu_long, ggplot2::aes(x=t_aligned)) +
      ggplot2::theme_minimal(13) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin=lo,ymax=hi,fill=p_chr), alpha=0.25, colour=NA) +
      ggplot2::geom_line(ggplot2::aes(y=mu,colour=p_chr), linewidth=0.9) +
      ggplot2::geom_line(ggplot2::aes(y=y, group=1), colour="#222222", alpha=0.6, linewidth=0.7) +
      ggplot2::scale_color_manual(values=col_line, name="quantile p",
                                  labels=function(z) scales::percent(as.numeric(z))) +
      ggplot2::scale_fill_manual(values=sapply(col_line, function(z) scales::alpha(z,0.25)),
                                 name="quantile p",
                                 labels=function(z) scales::percent(as.numeric(z))) +
      ggplot2::labs(title=paste0("Winner: μ̂ (95% bands) — last ", showN, " points"),
                    x="time (aligned)", y="USGS")
    print(gg)

    # Observed y with synthesized 95% predictive band (same window)
    draws <- winner_bundle$synth$draws
    yA    <- winner_bundle$y_aligned
    q_mat <- t(apply(tail(draws, showN), 1, stats::quantile, probs=c(0.025,0.50,0.975)))
    dfB <- tibble::tibble(
      t_aligned = (winner_bundle$T_window - showN + 1):winner_bundle$T_window,
      y  = tail(yA, showN),
      q05 = q_mat[,1], q50 = q_mat[,2], q95 = q_mat[,3]
    )
    gb <- ggplot2::ggplot(dfB, ggplot2::aes(x=t_aligned)) +
      ggplot2::theme_minimal(13) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin=q05, ymax=q95), fill=scales::alpha("#3B82F6",0.22)) +
      ggplot2::geom_line(ggplot2::aes(y=q50), colour="#3B82F6") +
      ggplot2::geom_line(ggplot2::aes(y=y), colour="#111111", linewidth=0.8) +
      ggplot2::labs(title=paste0("Winner: Observed y with synthesized 95% band — last ", showN, " points"),
                    x="time (aligned)", y="USGS")
    print(gb)
  }, silent = TRUE)

  invisible(winner_bundle)
})
