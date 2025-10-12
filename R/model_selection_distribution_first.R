#' Distribution-first model selection for Q-DESN (shared spec across quantiles)
#'
#' For each candidate shared specification, fit Q-DESN readouts at p ∈ {0.05, 0.50, 0.95},
#' synthesize a single predictive distribution, and select the spec with the lowest CRPS
#' (approximated via averaged pinball loss over the empirical quantile grid extracted from
#' the synthesized draws).
#'
#' Parallelized across candidate specifications; within each spec, the 3 quantiles are fit
#' sequentially (to share the same reservoir seed). Optionally average scores across multiple
#' seeds to reduce reservoir-seed variance.
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
req_pkgs <- c("devtools","ggplot2","dplyr","tidyr","tibble",
              "scales","purrr","future","furrr","progressr")
need <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(need)) install.packages(need, dependencies = TRUE)
invisible(lapply(req_pkgs, require, character.only = TRUE))

# Load your local package that provides qdesn_* and exAL routines
devtools::load_all("/home/antonio/code/exdqlm")   # adjust if needed

## ================================================================
## 1) Config — change here to explore
## ================================================================
# Data path (robust resolution, as before)
csv_candidates <- c(
  "C:/Users/anton/Downloads/data_USGS_ppt_soil.csv",
  "/mnt/c/Users/anton/Downloads/data_USGS_ppt_soil.csv",
  path.expand("~/Downloads/data_USGS_ppt_soil.csv"),
  file.path(getwd(), "data_USGS_ppt_soil.csv")
)
csv_path <- NULL; for (p in csv_candidates) if (file.exists(p)) { csv_path <- p; break }
if (is.null(csv_path)) stop("Could not locate 'data_USGS_ppt_soil.csv' in any candidate path.")

# Quantiles we always fit jointly (shared spec)
p_vec <- c(0.05, 0.50, 0.95)

# VB readout defaults (fixed across specs)
vb_args <- list(max_iter = 1000, tol = 1e-4, n_samp_xi = 1000, verbose = TRUE)

# Posterior/synthesis defaults (fixed across specs during selection)
nd_draws       <- 2000L   # predictive draws per model (↓ if memory tight; ≥400 is fine)
chunk_sz       <- 200L
synth_grid_M   <- 1001L
synth_nsamp    <- 2000L  # synthesized draws per time for CRPS
synth_isotonic <- TRUE
synth_rearrange<- TRUE
synth_seed     <- 999

# Scoring window (time points used for CRPS). Keep modest for speed.
score_last_N   <- 1000L   # last N aligned times per spec
# How many reservoir seeds to average over per spec (≥2 reduces variance)
seed_vec       <- c(42, 101, 202)

# Parallel plan
future::plan(future::multisession, workers = max(1, parallel::detectCores() - 1))

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

# CRPS approx for a single time point using draws -> quantile grid tau_k=k/(N+1), q(tau_k)=x_(k)
crps_from_draws_1 <- function(y_true, draws_vec) {
  x <- sort(as.numeric(draws_vec))
  N <- length(x); if (N < 5) return(NA_real_)
  tau <- (seq_len(N)) / (N + 1)
  res <- y_true - x
  # pinball loss ρτ(u) = (τ - 1{u<0})*u
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
## 4) Candidate grid (shared spec across all three quantiles)
##    Keep this modest & meaningful; expand if you can afford it.
## ================================================================
# Rho patterns helper
rho_pattern <- function(D, kind=c("flat","decay")) {
  kind <- match.arg(kind)
  if (kind=="flat")  rep(0.90, D)
  else               head(c(0.95,0.90,0.85), D)
}
# n_tilde from ratio of previous layer
make_n_tilde <- function(n, ratio=0.2) {
  if (length(n) <= 1) integer(0)
  pmax(1L, as.integer(round(head(n,-1) * ratio)))
}

# Build grid (tune counts to control total #specs)
grid_list <- list(
  D            = c(2L, 3L),
  n_pack       = list( # each element is a vector length D; we’ll validate against D
    c(200L,100L),
    c(300L,150L),
    c(300L,150L,80L),
    c(400L,200L,100L)
  ),
  red_ratio    = c(0.20, 0.30),
  alpha        = c(0.20, 0.25, 0.30),
  rho_kind     = c("flat","decay"),
  act_f        = c("tanh","relu"),
  act_k        = c("identity"),     # keep fixed for now
  m            = c(12L, 24L, 36L),
  washout      = c(200L),
  add_bias     = c(FALSE, TRUE),
  lags_pair    = list(c(0L,0L), c(3L,3L), c(7L,7L), c(14L,7L))
)

# Cartesian but filtered to match D with n_pack length
cartesian_specs <- purrr::cross_df(grid_list) |>
  dplyr::rowwise() |>
  dplyr::mutate(
    n       = list({ v <- n_pack; if (length(v)==D) v else NA_integer_ }),
    n_tilde = list({ if (any(is.na(n))) NA_integer_ else make_n_tilde(n, red_ratio) }),
    rho     = list({ rho_pattern(D, rho_kind) }),
    lags_ppt  = lags_pair[1],  # placeholders; will unwrap after rowwise
    lags_soil = lags_pair[2]
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(!is.na(n[[1]])) |>
  dplyr::select(D, n, n_tilde, alpha, rho, act_f, act_k, m, washout, add_bias,
                lags_ppt = lags_pair.1, lags_soil = lags_pair.2, red_ratio, rho_kind)

# Drop obviously redundant combos (optional)
cartesian_specs <- cartesian_specs |>
  dplyr::distinct()

message("Candidate specs: ", nrow(cartesian_specs))

## ================================================================
## 5) One-spec-one-seed fitter (3 quantiles → synthesis → CRPS)
## ================================================================
# core fitter for a *single* (spec, seed)
fit_spec_once <- function(spec, seed) {
  # Unpack spec
  D <- spec$D; n <- unlist(spec$n); n_tilde <- unlist(spec$n_tilde)
  alpha <- spec$alpha; rho <- unlist(spec$rho)
  act_f <- spec$act_f;   act_k <- spec$act_k
  m <- spec$m;           washout <- spec$washout
  add_bias <- isTRUE(spec$add_bias)
  lags_ppt <- spec$lags_ppt;  lags_soil <- spec$lags_soil

  # Reservoir defaults held fixed
  pi_w <- 0.05; pi_in <- 0.20

  desn_args <- list(
    D=D, n=n, n_tilde=n_tilde,
    m=m, alpha=alpha, rho=rho,
    act_f=act_f, act_k=act_k,
    pi_w=pi_w, pi_in=pi_in,
    washout=washout, add_bias=add_bias,
    seed=seed
  )

  # Build exogenous lag block (full length)
  X_ppt  <- lag_mat(ppt,  lags_ppt)
  X_soil <- lag_mat(soil, lags_soil)
  X_cov_full <- cbind(X_ppt, X_soil)
  maxlag_cov <- max(lags_ppt, lags_soil)

  # Helper: fit one quantile with exogenous lags appended to the readout
  fit_q <- function(p0) {
    fit0 <- do.call(qdesn_fit_vb, c(list(y=y, p0=p0, vb_args=vb_args), desn_args))
    keep_idx <- fit0$meta$keep_idx
    y_fit    <- fit0$y_fit
    X_res    <- fit0$X

    # trim earliest aligned points if covariate lags not available
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
      verbose=isTRUE(vb_args$verbose)
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
  fits <- lapply(p_vec, fit_q)
  names(fits) <- paste0("p=", p_vec)

  # Common alignment (take the minimum length across p to be safe)
  T_common <- min(sapply(fits, function(o) nrow(o$df_mu)))
  keep_idx <- fits[[1]]$fit$meta$keep_idx
  keep_idx <- tail(keep_idx, T_common) # ensure same trailing alignment
  y_aligned <- tail(fits[[1]]$df_mu$y, T_common)

  # Predictive draws per model
  pp_draws <- lapply(fits, function(x)
    posterior_predict.qdesn_fit(x$fit, nd=nd_draws, chunk=chunk_sz)$yrep
  )
  # Ensure identical dimension T_common × nd
  pp_draws <- lapply(pp_draws, function(M) tail(M, T_common))

  # Synthesis
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

  # Score by CRPS on last score_last_N aligned points
  crps_vec <- crps_from_draws_window(synth$draws, y_aligned, last_N = score_last_N)
  mean_crps <- mean(crps_vec, na.rm = TRUE)

  # Optional diagnostics: coverage of μ at each p (Pr[y ≤ μ] ≈ p)
  cover_df <- dplyr::bind_rows(lapply(seq_along(p_vec), function(k) {
    d <- fits[[k]]$df_mu
    d <- tail(d, T_common)
    tibble::tibble(p0 = p_vec[k],
                   cov = mean(d$y <= d$mu, na.rm=TRUE),
                   avg_bw = median(d$hi - d$lo, na.rm=TRUE))
  }))

  list(
    mean_crps = mean_crps,
    crps_lastN = crps_vec,
    y_aligned = y_aligned,
    synth = synth,
    fits = fits,
    T_common = T_common,
    keep_idx = keep_idx,
    coverage = cover_df
  )
}

## ================================================================
## 6) Run selection in parallel across candidate specs
## ================================================================
stopifnot(exists("exdqlm_synthesize_from_draws"))

# Prepare a printable id for each spec row
spec_key <- function(row) {
  paste0(
    "D", row$D,
    "_n", paste0(unlist(row$n), collapse="-"),
    "_r", row$rho_kind,
    "_a", sprintf("%.2f", row$alpha),
    "_m", row$m,
    "_w", row$washout,
    "_f", row$act_f,
    "_k", row$act_k,
    "_b", as.integer(row$add_bias),
    "_lp", row$lags_ppt,
    "_ls", row$lags_soil
  )
}

# Progress
progressr::handlers(global = TRUE)
progressr::handlers(progressr::handler_txtprogressbar)

with(progressr::progressor(along = seq_len(nrow(cartesian_specs))) %<-% p, {

  # Parallel over specs
  results <- furrr::future_map(seq_len(nrow(cartesian_specs)), function(i) {
    row <- cartesian_specs[i,]
    p(sprintf("Spec %d/%d: %s", i, nrow(cartesian_specs), spec_key(row)))

    # Average across seeds (sequential to share CPU with parallel specs)
    seed_runs <- lapply(seed_vec, function(sd) {
      fit_spec_once(row, seed = sd)
    })

    mean_crps <- mean(vapply(seed_runs, function(x) x$mean_crps, 1.0), na.rm = TRUE)
    se_crps   <- sd(vapply(seed_runs, function(x) x$mean_crps, 1.0), na.rm = TRUE) / sqrt(length(seed_vec))

    # Aggregate coverage diagnostics (just to report, not for selection)
    cov_tbl <- dplyr::bind_rows(lapply(seed_runs, function(z) z$coverage)) |>
      dplyr::group_by(p0) |>
      dplyr::summarise(cov = mean(cov), avg_bw = median(avg_bw), .groups="drop")

    list(
      spec_idx = i,
      spec_key = spec_key(row),
      spec_row = row,
      mean_crps = mean_crps,
      se_crps   = se_crps,
      cov_tbl   = cov_tbl,
      # retain the first seed’s artifacts for quick plotting if desired
      exemplar  = seed_runs[[1]]
    )
  })

  ## ================================================================
  ## 7) Leaderboard & winner
  ## ================================================================
  leaderboard <- dplyr::bind_rows(lapply(results, function(r)
    tibble::tibble(
      spec_idx = r$spec_idx,
      spec_key = r$spec_key,
      mean_CRPS = r$mean_crps,
      se_CRPS   = r$se_crps,
      cov_05    = r$cov_tbl$cov[r$cov_tbl$p0==0.05],
      cov_50    = r$cov_tbl$cov[r$cov_tbl$p0==0.50],
      cov_95    = r$cov_tbl$cov[r$cov_tbl$p0==0.95],
      bw_med    = r$cov_tbl$avg_bw[r$cov_tbl$p0==0.50]
    )
  )) |>
    dplyr::arrange(mean_CRPS)

  print(utils::head(leaderboard, 10))

  best <- results[[ leaderboard$spec_idx[1] ]]
  message("\nWinner: ", best$spec_key, " | mean CRPS=", sprintf("%.4f", best$mean_crps),
          " (±", sprintf("%.4f", best$se_crps), ")")

  winner_bundle <- list(
    spec_key = best$spec_key,
    spec     = best$spec_row,
    leaderboard = leaderboard,
    # exemplar seed artifacts (aligned last run)
    y_aligned = best$exemplar$y_aligned,
    fits      = best$exemplar$fits,
    synth     = best$exemplar$synth,
    coverage  = best$cov_tbl,
    T_common  = best$exemplar$T_common,
    keep_idx  = best$exemplar$keep_idx,
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
    saveRDS(winner_bundle, file.path(out_dir, "winner_bundle.rds"))
    write.csv(leaderboard, file.path(out_dir, "leaderboard.csv"), row.names = FALSE)
  }

  ## ================================================================
  ## 8) (Optional) quick diagnostic plots for the winner
  ## ================================================================
  try({
    # Overlay μ (95% bands) for all p on last 300 points
    T_common <- winner_bundle$T_common
    mu_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(k) {
      d <- winner_bundle$fits[[k]]$df_mu
      d$t_aligned <- seq_len(nrow(d))
      d$p_chr <- as.character(p_vec[k])
      tail(d, 300)
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
      ggplot2::labs(title="Winner: μ̂ (95% bands) for all quantiles + observed",
                    x="time (aligned)", y="USGS")
    print(gg)

    # Observed y with synthesized 95% predictive band (last 300)
    draws <- winner_bundle$synth$draws
    yA    <- winner_bundle$y_aligned
    q_mat <- t(apply(tail(draws, 300), 1, stats::quantile, probs=c(0.025,0.50,0.975)))
    dfB <- tibble::tibble(
      t_aligned = (winner_bundle$T_common-299):winner_bundle$T_common,
      y  = tail(yA, 300),
      q05 = q_mat[,1], q50 = q_mat[,2], q95 = q_mat[,3]
    )
    gb <- ggplot2::ggplot(dfB, ggplot2::aes(x=t_aligned)) +
      ggplot2::theme_minimal(13) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin=q05, ymax=q95), fill=scales::alpha("#3B82F6",0.22)) +
      ggplot2::geom_line(ggplot2::aes(y=q50), colour="#3B82F6") +
      ggplot2::geom_line(ggplot2::aes(y=y), colour="#111111", linewidth=0.8) +
      ggplot2::labs(title="Winner: Observed y with synthesized 95% band",
                    x="time (aligned)", y="USGS")
    print(gb)
  }, silent = TRUE)

  invisible(winner_bundle)
})
