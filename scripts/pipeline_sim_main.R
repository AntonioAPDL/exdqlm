# scripts/pipeline_main.R
# Standalone main for ESN quantile pipeline (fit → forecast → synthesis → diagnostics)
# Reads configuration from EXDQLM_* environment variables set by scripts/pipeline_run.R

# Global verbosity flag (overridden from YAML via cfg$pipeline$verbose or cfg$verbose)
VERBOSE <- TRUE

as_num_vec <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) x <- unlist(x, use.names = FALSE)
  if (is.matrix(x) || is.array(x)) x <- as.vector(x)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  as.numeric(x)
}

as_int_vec <- function(x) {
  x <- as_num_vec(x)
  if (is.null(x)) return(NULL)
  as.integer(x)
}

fix_len <- function(x, D, nm) {
  if (is.null(x)) return(NULL)
  if (length(x) == D) return(x)
  if (length(x) == 1L && D > 1L) {
    if (isTRUE(VERBOSE)) {
      message(sprintf("Note: recycling %s=%s to length D=%d", nm, paste(x, collapse=","), D))
    }
    return(rep(x, D))
  }
  stop(sprintf(
    "Config error: length(%s)=%d but D=%d | class=%s | value(head)=%s",
    nm, length(x), D, paste(class(x), collapse=","),
    paste(utils::head(x, 10), collapse=",")
  ), call. = FALSE)
}

act_scalar <- function(x, nm) {
  if (is.null(x)) return(NULL)
  if (is.list(x)) x <- unlist(x, use.names = FALSE)

  x <- as.character(x)
  x <- x[!is.na(x) & nzchar(x)]

  if (length(x) == 0L) {
    stop(sprintf("%s must be a non-empty character scalar.", nm), call. = FALSE)
  }

  u <- unique(tolower(x))
  if (length(u) != 1L) {
    stop(sprintf(
      "%s must be a scalar (or a repeated vector with identical values). Got: %s",
      nm, paste(x, collapse = ", ")
    ), call. = FALSE)
  }

  x[1L]
}


suppressPackageStartupMessages({
  req <- c("devtools","ggplot2","dplyr","tidyr","tibble","scales",
         "MASS","numDeriv","matrixStats","purrr","readr","patchwork","jsonlite",
         "truncnorm")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) install.packages(need, repos="https://cloud.r-project.org", dependencies = TRUE)
  invisible(lapply(req, require, character.only = TRUE))
})

# --- repo root (works from anywhere in repo)
repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE)),
  error = function(...) normalizePath(".", mustWork = TRUE)
)
devtools::load_all(repo_root)
set.seed(12345)

# --- Timing helpers (minimal, flush-friendly) ---------------------------------
options(exdqlm.timing = TRUE)  # toggle with options(exdqlm.timing=FALSE) if needed

.timing_env <- if (exists(".timing_env", inherits = FALSE)) get(".timing_env") else new.env(parent = emptyenv())
if (is.null(.timing_env$rows)) .timing_env$rows <- data.frame(
  when = character(), tag = character(), seconds = double(),
  stringsAsFactors = FALSE
)

.now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")
log_msg <- function(fmt, ...) {
  if (!isTRUE(VERBOSE)) return(invisible(NULL))
  cat(sprintf("[%s] %s\n", .now(), sprintf(fmt, ...)))
  flush.console()
}

timed <- function(tag, expr) {
  if (!isTRUE(getOption("exdqlm.timing", TRUE))) return(eval.parent(substitute(expr)))
  t0 <- Sys.time()
  log_msg("▶ %s", tag)
  on.exit({
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    .timing_env$rows <- rbind(.timing_env$rows,
                              data.frame(when = .now(), tag = tag, seconds = dt))
    log_msg("■ %s took %.3fs", tag, dt)
  }, add = TRUE)
  eval.parent(substitute(expr))
}
# ------------------------------------------------------------------------------

# --- Batch-run overrides from runner (file paths, outputs, full YAML cfg)
file_long <- Sys.getenv("EXDQLM_FILE_LONG", unset = NA)
file_obs  <- Sys.getenv("EXDQLM_FILE_OBS",  unset = NA)
out_dir   <- Sys.getenv("EXDQLM_OUT_DIR",   unset = NA)

val <- Sys.getenv("EXDQLM_SAVE_OUTPUTS", unset = NA)
save_outputs <- if (!is.na(val) && nzchar(val)) (as.integer(val) == 1L) else TRUE

# Output control flags (can be overridden by YAML cfg$outputs)
keep_draws    <- FALSE
thesis_subset <- FALSE

if (is.na(file_long) || !file.exists(file_long)) {
  stop("EXDQLM_FILE_LONG not set or file missing: ", file_long)
}
if (is.na(out_dir) || !nzchar(out_dir)) {
  out_dir <- file.path(dirname(file_long), "fig_esn_quantile_main")
}

# Ensure base + subdirs exist
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
FIGS   <- file.path(out_dir, "figs");   dir.create(FIGS,   recursive = TRUE, showWarnings = FALSE)
TABLES <- file.path(out_dir, "tables"); dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)
MODELS <- file.path(out_dir, "models"); dir.create(MODELS, recursive = TRUE, showWarnings = FALSE)

cfg_json <- Sys.getenv("EXDQLM_CFG_JSON", unset = NA)
cfg <- if (!is.na(cfg_json) && nzchar(cfg_json)) jsonlite::fromJSON(cfg_json, simplifyVector = TRUE) else list()
if (isTRUE(VERBOSE)) {
  # Dump EXDQLM_* env vars (this usually reveals which spec YAML was used)
  envs <- Sys.getenv()
  ex <- envs[grep("^EXDQLM_", names(envs))]
  # cat("EXDQLM_ENV_VARS\n")
  # cat(paste(sprintf("%s=%s", names(ex), ex), collapse = "\n"), "\n")

  # Save the exact JSON that arrived (so you can inspect it)
  if (!is.na(cfg_json) && nzchar(cfg_json)) {
    # cat(sprintf("CFG_JSON_NCHAR=%d\n", nchar(cfg_json)))
    writeLines(cfg_json, file.path(out_dir, "cfg_received.json"))
  }
}

# --- Pipeline mode (future-ready; sim-only today)
`%||%` <- function(x, alt) if (!is.null(x)) x else alt
mode <- tolower((cfg$pipeline$mode %||% "sim"))
# Optional "profile" within a given mode, e.g. full vs model_selection
run_profile <- tolower((cfg$pipeline$profile %||% "full"))
is_model_selection <- run_profile %in% c("ms", "model_selection", "tuning", "light")

if (!mode %in% c("sim","simulation","real","observed","data")) {
  message(sprintf("[pipeline_main] WARNING: pipeline.mode=%s not recognized; proceeding with default flow.", mode))
}

`%nz%` <- function(x, alt) if (!is.null(x)) x else alt

near_equal <- function(x, y, tol = 1e-8) abs(x - y) <= tol

# --- Defaults (overridden by cfg when present)
p_vec <- c(0.05, 0.50, 0.95)

desn_args <- list(
  D = 1L, n = c(800L), n_tilde = integer(0), m = 50L,
  alpha = 0.2, rho = c(0.95), act_f = "tanh", act_k = "identity",
  pi_w = 0.05, pi_in = 1.00, washout = 500L, add_bias = TRUE, seed = 42
)

vb_args_base <- list(max_iter = 150, tol = 1e-4, n_samp_xi = 500, verbose = TRUE)

# ELBO tolerance per p0 (mid vs tails)
vb_tol_for <- function(p0) if (near_equal(p0, 0.50)) 1e-4 else 1e-5

# NEW: safeguard tolerance for (E[γ], E[σ]) increments; default same scale as ELBO tol
vb_tol_par_for <- vb_tol_for

# --- VB init / prior hyperparameters (per-quantile, from cfg$vb) ----------
# These are always on the natural scale (gamma, sigma); no log-scale priors.
vb_init_gamma <- NULL  # length = length(p_vec), if provided
vb_init_sigma <- NULL

# Normal prior for gamma:  gamma_p ~ N(mu0_p, s20_p)
vb_prior_gamma_mu0 <- NULL
vb_prior_gamma_s20 <- NULL

# Inverse-Gamma prior for sigma:  sigma_p ~ IG(a_p, b_p)
vb_prior_sigma_a <- NULL
vb_prior_sigma_b <- NULL

# Ridge prior variance for beta (shared across p if scalar)
vb_prior_beta_tau2 <- NULL

# Beta prior type + RHS hyperparameters (new; default ridge)
vb_prior_beta_type <- "ridge"

vb_prior_beta_rhs <- list(
  tau0 = 10000,
  nu   = 4.0,
  s2   = 10000,

  shrink_intercept = FALSE,
  intercept_prec   = 1e-24,

  n_inner    = 1L,
  eta_bounds = list(
    lambda = c(-12, 12),
    tau    = c(-12, 12),
    c2     = c(-12, 12)
  ),

  h_curv    = 1e-24,
  var_floor = 1e-24,
  verbose   = FALSE,

  init_log_lambda = 0.0,
  init_log_tau    = 0.0,
  init_log_c2     = 0.0
)


# --- IJ correction toggles (global) -------------------------------------------
ij_nd_draws       <- 2000L   # number of parameter draws used for IJ + μ-bands
use_ij_correction <- TRUE    # set FALSE to revert to pure posterior μ-bands
# ------------------------------------------------------------------------------

nd_draws  <- 3000L
chunk_sz  <- 250L

# Base window (for backward compatibility)
last_window <- 200L

# Separate train / forecast windows (default both = last_window)
train_last_window <- last_window
fore_last_window  <- last_window

synth_isotonic  <- TRUE
synth_rearrange <- TRUE
synth_grid_M    <- 2001L
synth_nsamp     <- 4000L
synth_seed      <- 123L

rolling_origin <- TRUE
H_step         <- 1L
tf_enable      <- TRUE
tf_first_k     <- desn_args$m
y_future_obs_explicit <- NULL

# Diagnostics / plotting toggles (can be overridden via cfg$diagnostics)
do_calibration <- TRUE
do_pit         <- TRUE
do_scores      <- TRUE  # CRPS + S
do_plots       <- TRUE  # master gate for all ggplot/ggsave work


# --- Apply cfg overrides (if present)
coverage_report <- "global"

if (length(cfg)) {
  # Global pipeline verbosity from YAML
  # Prefer cfg$pipeline$verbose, fall back to top-level cfg$verbose if present
  if (!is.null(cfg$pipeline) && !is.null(cfg$pipeline$verbose)) {
    VERBOSE <- isTRUE(cfg$pipeline$verbose)
  } else if (!is.null(cfg$verbose)) {
    VERBOSE <- isTRUE(cfg$verbose)
  }

  if (!is.null(cfg$p_vec))             p_vec <- as.numeric(cfg$p_vec)

  if (!is.null(cfg$desn)) {
    D_in <- as.integer(cfg$desn$D %||% desn_args$D)

    desn_args$D <- D_in

    # per-layer numeric vectors
    desn_args$n     <- fix_len(as_int_vec(cfg$desn$n)     %||% as_int_vec(desn_args$n),     D_in, "desn$n")
    desn_args$rho   <- fix_len(as_num_vec(cfg$desn$rho)   %||% as_num_vec(desn_args$rho),   D_in, "desn$rho")
    if (!is.null(cfg$desn$alpha)) desn_args$alpha <- fix_len(as_num_vec(cfg$desn$alpha), D_in, "desn$alpha")
    if (!is.null(cfg$desn$pi_w))  desn_args$pi_w  <- fix_len(as_num_vec(cfg$desn$pi_w),  D_in, "desn$pi_w")
    if (!is.null(cfg$desn$pi_in)) desn_args$pi_in <- fix_len(as_num_vec(cfg$desn$pi_in), D_in, "desn$pi_in")
    if (!is.null(cfg$desn$seed))  desn_args$seed  <- fix_len(as_int_vec(cfg$desn$seed),  D_in, "desn$seed")

    # per-layer character vectors
    if (!is.null(cfg$desn$act_f)) desn_args$act_f <- fix_len(as.character(cfg$desn$act_f), D_in, "desn$act_f")
    if (!is.null(cfg$desn$act_k)) desn_args$act_k <- fix_len(as.character(cfg$desn$act_k), D_in, "desn$act_k")

    desn_args$act_f <- act_scalar(desn_args$act_f, "desn$act_f")
    desn_args$act_k <- act_scalar(desn_args$act_k, "desn$act_k")

    # n_tilde rules stay as you wrote them (length 0, 1, or D-1)
    if (!is.null(cfg$desn$n_tilde)) {
      nt <- as_int_vec(cfg$desn$n_tilde)
      if (length(nt) == 0L || all(is.na(nt))) {
        desn_args$n_tilde <- integer(0)
      } else if (D_in <= 1L) {
        desn_args$n_tilde <- integer(0)
      } else if (length(nt) == 1L) {
        desn_args$n_tilde <- rep(nt, D_in - 1L)
      } else if (length(nt) == (D_in - 1L)) {
        desn_args$n_tilde <- nt
      } else {
        stop(sprintf("Config error: length(desn$n_tilde)=%d but D=%d; expected 0, 1, or D-1=%d.",
                    length(nt), D_in, D_in - 1L))
      }
    }

    # scalar fields
    desn_args$m        <- cfg$desn$m        %nz% desn_args$m
    desn_args$washout  <- cfg$desn$washout  %nz% desn_args$washout
    desn_args$add_bias <- cfg$desn$add_bias %nz% desn_args$add_bias
    }
  if (!is.null(cfg$vb)) {
    vb_args_base$max_iter  <- cfg$vb$max_iter  %nz% vb_args_base$max_iter
    vb_args_base$n_samp_xi <- cfg$vb$n_samp_xi %nz% vb_args_base$n_samp_xi
    if (!is.null(cfg$vb$verbose)) {
      vb_args_base$verbose <- isTRUE(cfg$vb$verbose)
    }
    # ELBO tolerance (mid vs tails)
    tol50  <- cfg$vb$tol_50      %nz% 1e-4
    tolext <- cfg$vb$tol_extreme %nz% 1e-5
    vb_tol_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol50 else tolext

    # Additional safeguard on (E[gamma], E[sigma]); defaults back to ELBO tolerances.
    tol_par_50  <- cfg$vb$tol_par_50      %nz% tol50
    tol_par_ext <- cfg$vb$tol_par_extreme %nz% tolext
    vb_tol_par_for <- function(p0) if (abs(p0 - 0.50) < 1e-12) tol_par_50 else tol_par_ext

    # --- Per-quantile VB init and prior hyperparameters ----------------------
    len_p <- length(p_vec)

    recycle_p <- function(x, nm) {
      if (is.null(x)) return(NULL)
      x <- as.numeric(x)
      if (length(x) == 1L && len_p > 1L) {
        if (isTRUE(VERBOSE)) {
          message(sprintf(
            "Note: recycling vb.%s=%s to length(p_vec)=%d",
            nm, paste(x, collapse = ","), len_p
          ))
        }
        return(rep(x, len_p))
      }
      if (length(x) != len_p) {
        stop(sprintf(
          "Config error: length(vb.%s)=%d but length(p_vec)=%d",
          nm, length(x), len_p
        ))
      }
      x
    }

    # vb$init: initial means for gamma and sigma (natural scale), per quantile.
    if (!is.null(cfg$vb$init)) {
      vb_init_gamma <- recycle_p(cfg$vb$init$gamma, "init$gamma")
      vb_init_sigma <- recycle_p(cfg$vb$init$sigma, "init$sigma")
    }

    # vb$priors: Normal prior for gamma, IG prior for sigma, ridge prior for beta.
    if (!is.null(cfg$vb$priors)) {
      if (!is.null(cfg$vb$priors$gamma)) {
        vb_prior_gamma_mu0 <- recycle_p(cfg$vb$priors$gamma$mu0, "priors$gamma$mu0")
        vb_prior_gamma_s20 <- recycle_p(cfg$vb$priors$gamma$s20, "priors$gamma$s20")
      }
      if (!is.null(cfg$vb$priors$sigma)) {
        vb_prior_sigma_a <- recycle_p(cfg$vb$priors$sigma$a, "priors$sigma$a")
        vb_prior_sigma_b <- recycle_p(cfg$vb$priors$sigma$b, "priors$sigma$b")
      }
      if (!is.null(cfg$vb$priors$beta)) {
        beta_cfg <- cfg$vb$priors$beta

        # New: beta$type (ridge vs rhs), default ridge
        vb_prior_beta_type <- tolower(beta_cfg$type %||% "ridge")

        # Ridge τ²: support both new nested structure and old flat tau2 for backward compatibility
        tau2_val <- NULL
        if (!is.null(beta_cfg$ridge) && !is.null(beta_cfg$ridge$tau2)) {
          tau2_val <- as.numeric(beta_cfg$ridge$tau2)[1L]
        } else if (!is.null(beta_cfg$tau2)) {
          tau2_val <- as.numeric(beta_cfg$tau2)[1L]
        }
        vb_prior_beta_tau2 <- tau2_val

        # RHS hyperparameters (used later by RHS VB; here we just store them)
        if (!is.null(beta_cfg$rhs)) {
          rhs_cfg <- beta_cfg$rhs

          vb_prior_beta_rhs <- modifyList(
            vb_prior_beta_rhs,  # starts with defaults
            list(
              tau0 = rhs_cfg$tau0 %nz% vb_prior_beta_rhs$tau0,
              nu   = rhs_cfg$nu   %nz% vb_prior_beta_rhs$nu,
              s2   = rhs_cfg$s2   %nz% vb_prior_beta_rhs$s2,

              shrink_intercept = rhs_cfg$shrink_intercept %nz% FALSE,
              intercept_prec   = rhs_cfg$intercept_prec   %nz% 1e-24,
              n_inner          = rhs_cfg$n_inner          %nz% 1L,
              eta_bounds       = rhs_cfg$eta_bounds       %nz% vb_prior_beta_rhs$eta_bounds,
              h_curv           = rhs_cfg$h_curv           %nz% 1e-24,
              var_floor        = rhs_cfg$var_floor        %nz% 1e-24,
              verbose          = rhs_cfg$verbose          %nz% FALSE,

              init_log_lambda = rhs_cfg$init_log_lambda %nz% vb_prior_beta_rhs$init_log_lambda,
              init_log_tau    = rhs_cfg$init_log_tau    %nz% vb_prior_beta_rhs$init_log_tau,
              init_log_c2     = rhs_cfg$init_log_c2     %nz% vb_prior_beta_rhs$init_log_c2
            )
          )
        }
      }
    }
  }


  if (!is.null(cfg$sampling)) {
    nd_draws <- cfg$sampling$nd_draws %nz% nd_draws
    chunk_sz <- cfg$sampling$chunk    %nz% chunk_sz
  }

# --- IJ correction config from YAML ----------------------------------------
if (!is.null(cfg$ij)) {
  if (!is.null(cfg$ij$use_ij_correction)) {
    use_ij_correction <- isTRUE(cfg$ij$use_ij_correction)
  }
  if (!is.null(cfg$ij$nd_draws)) {
    ij_nd_draws <- as.integer(cfg$ij$nd_draws)
  }
}

if (!is.null(cfg$forecast)) {
  # Base: keep a single last_window for backward compatibility
  last_window    <- cfg$forecast$last_window    %nz% last_window
  rolling_origin <- cfg$forecast$rolling_origin %nz% rolling_origin
  H_step         <- cfg$forecast$H_step         %nz% H_step
  train_last_window <- cfg$forecast$train_last_window %nz% last_window
  fore_last_window  <- cfg$forecast$fore_last_window  %nz% last_window
  # --- NEW: how to report coverage in plot subtitles
  coverage_report <- "global"  # default behavior
  if (!is.null(cfg$forecast$coverage_report)) {
    cv <- tolower(as.character(cfg$forecast$coverage_report))
    if (cv %in% c("global", "window", "both")) coverage_report <- cv
  }
}


  if (!is.null(cfg$synthesis)) {
    synth_isotonic  <- cfg$synthesis$isotonic  %nz% synth_isotonic
    synth_rearrange <- cfg$synthesis$rearrange %nz% synth_rearrange
    synth_grid_M    <- cfg$synthesis$grid_M    %nz% synth_grid_M
    synth_nsamp     <- cfg$synthesis$n_samp    %nz% synth_nsamp
    synth_seed      <- cfg$synthesis$seed      %nz% synth_seed
  }

  if (!is.null(cfg$diagnostics)) {
    do_calibration <- cfg$diagnostics$calibration %nz% do_calibration
    do_pit         <- cfg$diagnostics$pit         %nz% do_pit
    do_scores      <- cfg$diagnostics$scores      %nz% do_scores
    if (!is.null(cfg$diagnostics$plots)) {
      do_plots <- isTRUE(cfg$diagnostics$plots)
    }
  }

  # --- Outputs: saving/keep_draws/thesis_subset from YAML -------------------
  if (!is.null(cfg$outputs)) {
    # YAML has highest precedence over the env var
    if (!is.null(cfg$outputs$save)) {
      save_outputs <- isTRUE(cfg$outputs$save)
    }
    if (!is.null(cfg$outputs$keep_draws)) {
      keep_draws <- isTRUE(cfg$outputs$keep_draws)
    }
    if (!is.null(cfg$outputs$thesis_subset)) {
      thesis_subset <- isTRUE(cfg$outputs$thesis_subset)
    }
  }
}

# --- Optional lightweight profile overrides (e.g. model selection runs) -----
if (isTRUE(is_model_selection)) {
  # Plots + expensive diagnostics off; keep scores for selection metrics.
  do_plots       <- FALSE
  do_calibration <- FALSE
  do_pit         <- FALSE
  # Scores (CRPS/S) usually needed for model selection:
  do_scores      <- TRUE

  # Avoid writing heavy artifacts during grid search.
  save_outputs   <- FALSE
  keep_draws     <- FALSE
  thesis_subset  <- FALSE
}

if (isTRUE(VERBOSE)) {
  message(sprintf(
    "[esn_main] out_dir=%s | save_outputs=%s | keep_draws=%s | thesis_subset=%s",
    out_dir, save_outputs, keep_draws, thesis_subset
  ))
}

# --- Echo effective settings after cfg overrides ---
pretty_vec <- function(x) paste0("[", paste(x, collapse=", "), "]")

log_msg(
  "Effective VB → max_iter=%d | tol_50=%.1e | tol_extreme=%.1e | tol_par_50=%.1e | tol_par_extreme=%.1e | n_samp_xi=%d",
  vb_args_base$max_iter,
  if (exists("tol50")) tol50 else 1e-4,
  if (exists("tolext")) tolext else 1e-5,
  if (exists("tol_par_50")) tol_par_50 else if (exists("tol50")) tol50 else 1e-4,
  if (exists("tol_par_ext")) tol_par_ext else if (exists("tolext")) tolext else 1e-5,
  vb_args_base$n_samp_xi
)

log_msg(
  "Effective beta prior → type=%s | ridge_tau2=%s | rhs(tau0=%.3f, nu=%.3f, s2=%.3f)",
  vb_prior_beta_type,
  if (is.null(vb_prior_beta_tau2)) "NULL"
  else format(vb_prior_beta_tau2, digits = 4, trim = TRUE),
  vb_prior_beta_rhs$tau0, vb_prior_beta_rhs$nu, vb_prior_beta_rhs$s2
)

log_msg("Effective sampling → nd_draws=%d | chunk=%d", nd_draws, chunk_sz)

log_msg(
  "Effective IJ → use_ij_correction=%s | ij_nd_draws=%d",
  as.character(use_ij_correction),
  as.integer(ij_nd_draws)
)

# --- Plot helpers (same as notebook, locked to 3 decimals for tau labels)
fmt_p <- function(x) sprintf("%.2f", as.numeric(x))
pal <- scales::hue_pal()(length(p_vec))
col_map <- setNames(pal, fmt_p(p_vec))
ACCENT_ORANGE <- "#ff9c11fc"  # dark orange for predicted / mean / synthesized lines
theme_exdqlm <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position="right",
                   plot.title=ggplot2::element_text(face="bold"))
}
caption_exdqlm <- function(window) sprintf("window: last %d steps • ndraws: %d", as.integer(window), as.integer(nd_draws))
band_from_draws <- function(mat, level = 0.95) {
  probs <- c((1 - level)/2, 0.5, (1 + level)/2)
  qs <- t(apply(mat, 1, stats::quantile, probs = probs, names = FALSE))
  colnames(qs) <- c("lo","med","hi"); qs
}
true_q_at_tau <- function(dat_long, tau) {
  dat_long %>%
    dplyr::arrange(t, p) %>%
    dplyr::group_by(t) %>%
    dplyr::summarise(
      q_tau = {
        p_i <- as.numeric(p); q_i <- as.numeric(q); ord <- order(p_i)
        approx(x = p_i[ord], y = q_i[ord], xout = tau, method = "linear", rule = 2)$y
      },
      .groups = "drop"
    ) %>% dplyr::arrange(t) %>% dplyr::pull(q_tau)
}

plot_mu_band <- function(df, p0, scope = "Forecast", window = 200L) {
  # Compute GLOBAL coverage on the full df (train or forecast span)
  coverage_global <- mean(df$q_true >= df$lo & df$q_true <= df$hi, na.rm = TRUE)

  # Window subset only for visualization
  i2 <- max(df$h); i1 <- max(1L, i2 - as.integer(window) + 1L)
  d  <- dplyr::filter(df, dplyr::between(h, i1, i2))
  coverage_window <- mean(d$q_true >= d$lo & d$q_true <= d$hi, na.rm = TRUE)

  # What to print on the subtitle?
  cov_mode <- get0("coverage_report", ifnotfound = "global", inherits = TRUE)
  cov_text <- switch(
    cov_mode,
    "window" = sprintf("q_true-in-band (window) = %s", scales::percent(coverage_window, 0.1)),
    "both"   = sprintf("q_true-in-band: global=%s • window=%s",
                       scales::percent(coverage_global, 0.1),
                       scales::percent(coverage_window, 0.1)),
    sprintf("q_true-in-band (global) = %s", scales::percent(coverage_global, 0.1))
  )

  band_label <- if (isTRUE(get0("use_ij_correction", ifnotfound = FALSE))) {
    "IJ-corrected 95% band for μ̂"
  } else {
    "μ̂ ±95% posterior band"
  }

  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title    = sprintf("%s: %s vs true qₚ (p=%s)", scope, band_label, scales::percent(p0, 1)),
      subtitle = cov_text,
      caption  = caption_exdqlm(window),
      x = "time", y = "value"
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lo, ymax = hi),
      fill = scales::alpha(col_map[fmt_p(p0)], 0.5),
      colour = NA
    ) +
    ggplot2::geom_line(ggplot2::aes(y = mu,     colour = "mu"),   linewidth = 0.5) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true"), linewidth = 0.9, linetype = 2) +
    ggplot2::geom_line(ggplot2::aes(y = y,      colour = "data"), linewidth = 0.6, alpha = 0.85) +
    ggplot2::scale_color_manual(
      name   = "",
      values = c(mu = ACCENT_ORANGE, true = "#7c3aed", data = "#6b7280")
    )
}

# NEW: μ - true q_p error band, using μ draws
plot_mu_error_band <- function(mu_draws,
                               q_true,
                               h_index = NULL,
                               p0,
                               scope = "Forecast",
                               window = 200L) {
  stopifnot(is.matrix(mu_draws), length(q_true) == nrow(mu_draws))

  T_h <- nrow(mu_draws)
  i2  <- T_h
  i1  <- max(1L, i2 - as.integer(window) + 1L)
  idx <- i1:i2

  # Error draws: μ - true q_p  (positive = μ above true quantile)
  err_draws <- mu_draws[idx, , drop = FALSE] -
    matrix(q_true[idx], nrow = length(idx), ncol = ncol(mu_draws))

  qs_err <- band_from_draws(err_draws, level = 0.95)

  if (is.null(h_index) || length(h_index) != T_h) {
    h_vals <- seq_len(T_h)
  } else {
    h_vals <- h_index
  }

  df <- tibble::tibble(
    h   = h_vals[idx],
    lo  = qs_err[, "lo"],
    med = qs_err[, "med"],
    hi  = qs_err[, "hi"]
  )

  # Symmetric y-range around 0 for easy visual comparison
  rng   <- range(c(df$lo, df$hi), na.rm = TRUE)
  r_max <- max(abs(rng), na.rm = TRUE)
  if (!is.finite(r_max) || r_max <= 0) r_max <- 1
  y_lim <- c(-r_max, r_max) * 1.05

  ggplot2::ggplot(df, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title    = sprintf("%s: μ - true qₚ error band (p=%s)", scope, scales::percent(p0, 1)),
      subtitle = "95% posterior band for μ - q_true",
      caption  = caption_exdqlm(window),
      x = "time",
      y = "μ - true qₚ"
    ) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "#4b5563") +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = lo, ymax = hi),
      fill = scales::alpha(col_map[fmt_p(p0)], 0.5),
      colour = NA
    ) +
    ggplot2::geom_line(ggplot2::aes(y = med),
                       colour   = ACCENT_ORANGE,
                       linewidth = 0.4) +
    ggplot2::coord_cartesian(ylim = y_lim)
}

plot_empirical_quantile <- function(df, p0, scope = "Forecast", window = 200L) {
  i2 <- max(df$h)
  i1 <- max(1L, i2 - window + 1L)
  d  <- dplyr::filter(df, dplyr::between(h, i1, i2))

  mae <- mean(abs(d$q_pred - d$q_true), na.rm = TRUE)

  has_ij_band <- all(c("lo_q_ij", "hi_q_ij") %in% names(d)) &&
                 any(is.finite(d$lo_q_ij) | is.finite(d$hi_q_ij))

  g <- ggplot2::ggplot(d, ggplot2::aes(x = h)) +
    theme_exdqlm() +
    ggplot2::labs(
      title    = sprintf("%s: q̂ₚ vs true qₚ (p=%s)", scope, scales::percent(p0, 1)),
      subtitle = sprintf("MAE (q_pred vs q_true) = %.3f", mae),
      caption  = caption_exdqlm(window),
      x = "time",
      y = "value"
    )

  if (has_ij_band) {
    g <- g +
      ggplot2::geom_ribbon(
        ggplot2::aes(ymin = lo_q_ij, ymax = hi_q_ij),
        fill   = scales::alpha(col_map[fmt_p(p0)], 0.35),
        colour = NA
      )
  }

  g +
    ggplot2::geom_line(ggplot2::aes(y = q_pred, colour = "pred"), linewidth = 0.5) +
    ggplot2::geom_line(ggplot2::aes(y = q_true, colour = "true"), linewidth = 0.9, linetype = 2) +
    ggplot2::geom_line(ggplot2::aes(y = y,      colour = "data"), linewidth = 0.6, alpha = 0.85) +
    ggplot2::scale_color_manual(
      name   = "",
      values = c(pred = ACCENT_ORANGE, true = "#7c3aed", data = "#6b7280")
    )
}

plot_synth_q_vs_true <- function(df_s, tau, scope = "Forecast", window = 200L) {
  tau_lab <- fmt_p(tau); c_true <- paste0("true_q_", tau_lab); c_synth <- paste0("synth_q_", tau_lab)
  i2 <- max(df_s$h); i1 <- max(1L, i2 - window + 1L)
  d <- dplyr::filter(df_s, dplyr::between(h, i1, i2))
  mae <- mean(abs(d[[c_synth]] - d[[c_true]]), na.rm = TRUE)
  ggplot2::ggplot(d, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(title = sprintf("%s: synthesized qₚ vs true qₚ (p=%s)", scope, scales::percent(as.numeric(tau), 1)),
                  subtitle = sprintf("MAE = %.3f", mae),
                  caption = caption_exdqlm(window), x = "time", y = "value") +
    ggplot2::geom_line(ggplot2::aes(y = .data[[c_synth]], colour = "synth"), linewidth = 0.5) +
    ggplot2::geom_line(ggplot2::aes(y = .data[[c_true]],  colour = "true"),  linewidth = 0.9, linetype = 2) +
    ggplot2::geom_line(ggplot2::aes(y = y,                 colour = "data"),  linewidth = 0.6, alpha = 0.85) +
    ggplot2::scale_color_manual(name = "",
      values = c(synth = ACCENT_ORANGE, true = "#7c3aed", data = "#6b7280"))
}

plot_synth_predictive_band <- function(synth_draws, y_vec, scope = "Forecast", window = 50L,
                                       fill_col = ACCENT_ORANGE, show_median = TRUE) {
  stopifnot(is.matrix(synth_draws), length(y_vec) == nrow(synth_draws))

  T_h <- nrow(synth_draws)
  i2  <- T_h
  i1  <- max(1L, i2 - as.integer(window) + 1L)

  # Quantiles for ALL times (for GLOBAL metrics)
  q_mat_all <- t(apply(synth_draws, 1L, stats::quantile,
                       probs = c(0.025, 0.50, 0.975), names = FALSE))
  colnames(q_mat_all) <- c("q025", "q50", "q975")

  # GLOBAL coverage/width (full train/forecast span)
  coverage_global <- mean(y_vec >= q_mat_all[, "q025"] & y_vec <= q_mat_all[, "q975"], na.rm = TRUE)
  mean_w_global   <- mean(q_mat_all[, "q975"] - q_mat_all[, "q025"], na.rm = TRUE)

  # Windowed df only for plotting
  df <- tibble::tibble(
    h = seq_len(T_h), y = y_vec,
    q025 = q_mat_all[, "q025"], q50 = q_mat_all[, "q50"], q975 = q_mat_all[, "q975"]
  ) |>
    dplyr::filter(dplyr::between(h, i1, i2))

  # WINDOW metrics (optional, for display if requested)
  coverage_window <- mean(df$y >= df$q025 & df$y <= df$q975, na.rm = TRUE)
  mean_w_window   <- mean(df$q975 - df$q025, na.rm = TRUE)

  cov_mode <- get0("coverage_report", ifnotfound = "global", inherits = TRUE)
  sub_txt <- switch(
    cov_mode,
    "window" = paste(
      sprintf("coverage(window)=%s", scales::percent(coverage_window, 0.1)),
      sprintf("mean width(window)=%.3f", mean_w_window),
      sep = " • "
    ),
    "both" = paste(
      sprintf("coverage(global)=%s", scales::percent(coverage_global, 0.1)),
      sprintf("mean width(global)=%.3f", mean_w_global),
      sprintf(" | coverage(window)=%s", scales::percent(coverage_window, 0.1)),
      sprintf("mean width(window)=%.3f", mean_w_window),
      sep = " • "
    ),
    # default: global
    paste(
      sprintf("coverage(global)=%s", scales::percent(coverage_global, 0.1)),
      sprintf("mean width(global)=%.3f", mean_w_global),
      sep = " • "
    )
  )

  ggplot2::ggplot(df, ggplot2::aes(x = h)) + theme_exdqlm() +
    ggplot2::labs(
      title   = sprintf("%s: synthesized 95%% predictive band", scope),
      subtitle = sub_txt,
      caption = caption_exdqlm(window), x = "time", y = "value"
    ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = q025, ymax = q975),
      fill = scales::alpha(fill_col, 0.22), colour = NA
    ) +
    { if (isTRUE(show_median))
        ggplot2::geom_line(ggplot2::aes(y = q50, colour = "median"), linewidth = 0.8)
      else ggplot2::geom_blank() } +
    ggplot2::geom_line(ggplot2::aes(y = y, colour = "data"), linewidth = 0.75) +
    ggplot2::scale_color_manual(
      name   = "", breaks = c("data", "median"),
      values = c(data = "#6b7280", median = fill_col)
    )
}

# ----- Posterior parameter helpers: minimal exAL-only version ------------------
qs_ci <- function(x, level = 0.95) {
  p <- (1 - level) / 2
  c(
    lo  = unname(stats::quantile(x, p)),
    med = stats::median(x),
    hi  = unname(stats::quantile(x, 1 - p))
  )
}

plot_beta_forest <- function(beta_draws,
                             term_names = NULL,
                             level = 0.95,
                             top_k = NULL,
                             zero_line = TRUE) {
  stopifnot(is.matrix(beta_draws))
  p <- ncol(beta_draws)
  if (is.null(term_names) || length(term_names) != p) {
    term_names <- paste0("β", seq_len(p))
  }

  qs <- apply(beta_draws, 2, qs_ci, level = level)
  df <- tibble::tibble(
    term   = term_names,
    lo     = qs["lo", ],
    med    = qs["med", ],
    hi     = qs["hi", ],
    width  = hi - lo,
    absmed = abs(med)
  )

  if (!is.null(top_k)) {
    df <- df %>%
      dplyr::arrange(dplyr::desc(absmed)) %>%
      dplyr::slice_head(n = top_k)
  }

  ggplot2::ggplot(df, ggplot2::aes(y = reorder(term, absmed), x = med)) +
    theme_exdqlm() +
    ggplot2::geom_errorbarh(
      ggplot2::aes(xmin = lo, xmax = hi),
      height = 0,
      alpha  = 0.9
    ) +
    ggplot2::geom_point(size = 1.4) +
    {
      if (zero_line) {
        ggplot2::geom_vline(
          xintercept = 0,
          colour     = "red",
          linetype   = "dashed"
        )
      } else ggplot2::geom_blank()
    } +
    ggplot2::labs(
      title = "Readout coefficients: 95% credible intervals",
      subtitle = if (!is.null(top_k)) {
        sprintf("Top %d by |median| • red line at 0", top_k)
      } else {
        "All coefficients • red line at 0"
      },
      x = "value",
      y = NULL
    )
}

plot_beta_forest_summary <- function(beta_hat,
                                     lo,
                                     hi,
                                     term_names = NULL,
                                     top_k = NULL,
                                     zero_line = TRUE,
                                     title = "Readout coefficients: IJ-corrected 95% band") {
  stopifnot(length(beta_hat) == length(lo), length(beta_hat) == length(hi))
  p <- length(beta_hat)
  if (is.null(term_names) || length(term_names) != p) {
    term_names <- paste0("β", seq_len(p))
  }

  df <- tibble::tibble(
    term   = term_names,
    lo     = as.numeric(lo),
    med    = as.numeric(beta_hat),
    hi     = as.numeric(hi),
    width  = hi - lo,
    absmed = abs(med)
  )

  if (!is.null(top_k)) {
    df <- df %>%
      dplyr::arrange(dplyr::desc(absmed)) %>%
      dplyr::slice_head(n = top_k)
  }

  ggplot2::ggplot(df, ggplot2::aes(y = reorder(term, absmed), x = med)) +
    theme_exdqlm() +
    ggplot2::geom_errorbarh(
      ggplot2::aes(xmin = lo, xmax = hi),
      height = 0,
      alpha  = 0.9
    ) +
    ggplot2::geom_point(size = 1.4) +
    {
      if (zero_line) {
        ggplot2::geom_vline(
          xintercept = 0,
          colour     = "red",
          linetype   = "dashed"
        )
      } else ggplot2::geom_blank()
    } +
    ggplot2::labs(
      title    = title,
      subtitle = if (!is.null(top_k)) {
        sprintf("Top %d by |median| • red line at 0", top_k)
      } else {
        "All coefficients • red line at 0"
      },
      x = "value",
      y = NULL
    )
}

get_exal_param_draws <- function(fit, p, nd = 2000, gamma_bounds = NULL, seed = NULL) {
  # Minimal, exAL-only version:
  #  - assumes `fit` is an `exal_vb` object from `exal_static_LDVB`
  #  - uses the package-native exal_vb_posterior_draws()
  stopifnot(inherits(fit, "exal_vb"))
  if (!is.null(seed)) set.seed(seed)

  if (!exists("exal_vb_posterior_draws", mode = "function")) {
    stop("exal_vb_posterior_draws() not found; cannot get parameter draws.")
  }

  dr <- exal_vb_posterior_draws(fit, nd = nd)

  # sanity check on β dimension
  if (!is.null(dr$beta) && is.matrix(dr$beta) && ncol(dr$beta) != p) {
    stop(sprintf("exal_vb_posterior_draws(): expected %d columns in beta, got %d",
                 p, ncol(dr$beta)))
  }

  list(
    gamma = dr$gamma,
    sigma = dr$sigma,
    beta  = dr$beta,          # nd × p
    gamma_bounds = gamma_bounds
  )
}

ij_sd_for_functional <- function(F_all, loglik_mat, n_obs) {
  # Generic IJ SD engine:
  #  - F_all:    M_eff x K matrix (rows = draws, cols = functionals: times or coeffs)
  #  - loglik_mat: M_eff x n_obs matrix (rows = draws, cols = observations)
  #  - n_obs:    number of training observations used in loglik_mat
  #
  # Returns:
  #  - sd_ij: length-K vector of IJ standard deviations
  stopifnot(is.matrix(F_all), is.matrix(loglik_mat))
  M_eff <- nrow(F_all)
  K     <- ncol(F_all)

  if (M_eff < 2L || n_obs < 2L || K < 1L) {
    return(rep(0, K))
  }

  # Center functionals and log-likelihood contributions by column
  F_centered <- sweep(F_all,     2L, colMeans(F_all),     "-")  # M_eff x K
  L_centered <- sweep(loglik_mat, 2L, colMeans(loglik_mat), "-") # M_eff x n_obs

  # Covariances: cov(f_k, ℓ_i) for all k, i
  # crossprod(F_centered, L_centered) = t(F_centered) %*% L_centered → K x n_obs
  Cmat <- crossprod(F_centered, L_centered) / (M_eff - 1)

  # Influence matrix I_{k,i} = n * cov(f_k, ℓ_i)
  I_mat      <- n_obs * Cmat                # K x n_obs
  I_bar      <- rowMeans(I_mat)            # length K
  I_centered <- sweep(I_mat, 1L, I_bar, "-") # K x n_obs

  var_ij <- rowSums(I_centered^2) / (n_obs * (n_obs - 1))
  var_ij <- pmax(var_ij, 0)
  sqrt(var_ij)
}

compute_mu_bands_with_ij <- function(
  X_train,
  y_train_keep,
  X_fc1,
  p0,
  param_draws,
  use_ij = use_ij_correction
) {
  stopifnot(is.matrix(X_train), is.matrix(X_fc1))

  beta_draws  <- param_draws$beta
  sigma_draws <- param_draws$sigma
  gamma_draws <- param_draws$gamma

  if (is.null(beta_draws) || !is.matrix(beta_draws)) {
    stop("compute_mu_bands_with_ij(): beta_draws is missing or not a matrix.")
  }

  M <- nrow(beta_draws)
  p <- ncol(beta_draws)
  n <- nrow(X_train)
  H <- nrow(X_fc1)

  if (length(sigma_draws) != M || length(gamma_draws) != M) {
    stop(sprintf(
      "compute_mu_bands_with_ij(): length(sigma_draws)=%d, length(gamma_draws)=%d, but nrow(beta_draws)=%d.",
      length(sigma_draws), length(gamma_draws), M
    ))
  }

  # Default: all draws are "kept" unless IJ filtering says otherwise
  finite_draw <- rep(TRUE, M)
  loglik_mat  <- NULL

  # --- μ draws: train + forecast (time-major: rows = t, cols = draws) ----
  mu_mat_tr <- X_train %*% t(beta_draws)   # n x M
  mu_mat_fc <- X_fc1   %*% t(beta_draws)   # H x M

  mu_draws_tr_TxM <- mu_mat_tr
  mu_draws_fc_TxM <- mu_mat_fc

  # Posterior-only summaries (before any IJ filtering)
  mu_qs_tr <- band_from_draws(mu_draws_tr_TxM, level = 0.95)
  mu_qs_fc <- band_from_draws(mu_draws_fc_TxM, level = 0.95)

  mu_hat_tr <- mu_qs_tr[, "med"]
  mu_hat_fc <- mu_qs_fc[, "med"]

  mu_sd_tr  <- matrixStats::rowSds(mu_draws_tr_TxM)
  mu_sd_fc  <- matrixStats::rowSds(mu_draws_fc_TxM)

  lo_post_tr <- mu_qs_tr[, "lo"]
  hi_post_tr <- mu_qs_tr[, "hi"]
  lo_post_fc <- mu_qs_fc[, "lo"]
  hi_post_fc <- mu_qs_fc[, "hi"]

  # Defaults if IJ is disabled or fails
  sd_ij_tr <- rep(0, n)
  sd_ij_fc <- rep(0, H)
  lo_tr    <- lo_post_tr
  hi_tr    <- hi_post_tr
  lo_fc    <- lo_post_fc
  hi_fc    <- hi_post_fc

  if (isTRUE(use_ij)) {
    # --- Log-likelihood contributions per draw & obs (train only) ----------
    loglik_full <- exal_loglik_from_mu_cpp(
      y           = y_train_keep,
      mu_mat      = mu_mat_tr,
      sigma_draws = sigma_draws,
      gamma_draws = gamma_draws,
      p0          = p0
    ) # M x n

    finite_draw <- apply(is.finite(loglik_full), 1L, all)
    M_eff       <- sum(finite_draw)
    n_obs       <- length(y_train_keep)

    if (M_eff < 2L || n_obs < 2L) {
      warning("compute_mu_bands_with_ij(): IJ skipped (too few finite draws or obs); using posterior-only μ bands.")
      loglik_mat  <- NULL
      finite_draw <- rep(TRUE, M)  # revert to 'no filtering' for downstream
    } else {
      # Keep only finite draws for loglik and μ draws
      loglik_mat        <- loglik_full[finite_draw, , drop = FALSE]  # M_eff x n
      mu_draws_tr_TxM   <- mu_draws_tr_TxM[, finite_draw, drop = FALSE] # n x M_eff
      mu_draws_fc_TxM   <- mu_draws_fc_TxM[, finite_draw, drop = FALSE] # H x M_eff

      # Recompute posterior summaries for filtered draws
      mu_qs_tr <- band_from_draws(mu_draws_tr_TxM, level = 0.95)
      mu_qs_fc <- band_from_draws(mu_draws_fc_TxM, level = 0.95)

      mu_hat_tr <- mu_qs_tr[, "med"]
      mu_hat_fc <- mu_qs_fc[, "med"]

      mu_sd_tr  <- matrixStats::rowSds(mu_draws_tr_TxM)
      mu_sd_fc  <- matrixStats::rowSds(mu_draws_fc_TxM)

      lo_post_tr <- mu_qs_tr[, "lo"]
      hi_post_tr <- mu_qs_tr[, "hi"]
      lo_post_fc <- mu_qs_fc[, "lo"]
      hi_post_fc <- mu_qs_fc[, "hi"]

      # --- IJ variance for all times (train + forecast) via generic engine ----
      F_tr  <- t(mu_draws_tr_TxM)          # M_eff x n
      F_fc  <- t(mu_draws_fc_TxM)          # M_eff x H
      F_all <- cbind(F_tr, F_fc)           # M_eff x (n + H)

      sd_ij_all <- ij_sd_for_functional(
        F_all      = F_all,
        loglik_mat = loglik_mat,
        n_obs      = n_obs
      )

      sd_ij_tr <- sd_ij_all[seq_len(n)]
      sd_ij_fc <- sd_ij_all[n + seq_len(H)]

      # Combine posterior variance and IJ variance (current choice: IJ only)
      sd_total_tr <- sd_ij_tr
      sd_total_fc <- sd_ij_fc

      alpha <- 0.05
      z_975 <- stats::qnorm(1 - alpha / 2)

      lo_tr <- mu_hat_tr - z_975 * sd_total_tr
      hi_tr <- mu_hat_tr + z_975 * sd_total_tr

      lo_fc <- mu_hat_fc - z_975 * sd_total_fc
      hi_fc <- mu_hat_fc + z_975 * sd_total_fc
    }
  }

  draw_idx_keep <- if (!is.null(loglik_mat)) which(finite_draw) else NULL

  list(
    mu_draws_tr   = mu_draws_tr_TxM,  # n x M_eff (or n x M if IJ off)
    mu_draws_fc   = mu_draws_fc_TxM,  # H x M_eff
    mu_hat_tr     = mu_hat_tr,
    mu_hat_fc     = mu_hat_fc,
    lo_tr         = lo_tr,
    hi_tr         = hi_tr,
    lo_fc         = lo_fc,
    hi_fc         = hi_fc,
    sd_ij_tr      = sd_ij_tr,
    sd_ij_fc      = sd_ij_fc,
    lo_post_tr    = lo_post_tr,
    hi_post_tr    = hi_post_tr,
    lo_post_fc    = lo_post_fc,
    hi_post_fc    = hi_post_fc,
    # NEW: expose IJ core for β / q
    loglik_mat    = loglik_mat,       # M_eff x n, or NULL if IJ off/fails
    draw_idx_keep = draw_idx_keep     # integer indices of kept draws in param_draws
  )
}

# --- 1) Load data + split (INSTRUMENTED) --------------------------------------
dat_long <- read.csv(file_long) |>
  tibble::as_tibble() |>
  dplyr::mutate(t=as.integer(t), p=as.numeric(p), q=as.numeric(q), y=as.numeric(y), mu=as.numeric(mu)) |>
  dplyr::arrange(t, p)

y_full_all <- dat_long |> dplyr::distinct(t, y) |> dplyr::arrange(t)
T_full <- nrow(y_full_all)

# ---- Configurable data limiting + split (YAML-aware, verbose) ----
# cfg$split fields (optional):
#   T_use, use_prop, use_last, train_n, train_prop
if (isTRUE(VERBOSE)) {
  # cat("SPLIT_RAW | cfg$split=",
  #     jsonlite::toJSON(cfg$split, auto_unbox = TRUE, null = "null"), "\n", sep = "")
}

use_last   <- TRUE
T_use      <- T_full
train_n    <- NULL
train_prop <- NULL

if (!is.null(cfg$split)) {
  # Presence + null/NA audit
  has_train_n    <- "train_n"    %in% names(cfg$split)
  has_train_prop <- "train_prop" %in% names(cfg$split)
  if (isTRUE(VERBOSE)) {
    # cat("SPLIT_KEYS | has(train_n)=", has_train_n,
    #     " is.null(train_n)=", is.null(cfg$split$train_n),
    #     " has(train_prop)=", has_train_prop,
    #     " is.null(train_prop)=", is.null(cfg$split$train_prop), "\n", sep = "")
  }

  # Parse primitives
  if (!is.null(cfg$split$use_last))   use_last   <- isTRUE(cfg$split$use_last)
  if (!is.null(cfg$split$use_prop))   T_use      <- max(1L, floor(as.numeric(cfg$split$use_prop) * T_full))
  if (!is.null(cfg$split$T_use))      T_use      <- as.integer(cfg$split$T_use)
  if (has_train_n)                    train_n    <- suppressWarnings(as.integer(cfg$split$train_n))
  if (has_train_prop)                 train_prop <- suppressWarnings(as.numeric(cfg$split$train_prop))

  # Canonicalize pseudo-nulls: treat length-0 / NA as absent
  norm_opt <- function(x) {
    if (is.null(x)) return(NULL)
    if (length(x) == 0L) return(NULL)
    if (all(is.na(x))) return(NULL)
    x
  }
  train_n    <- norm_opt(train_n)
  train_prop <- norm_opt(train_prop)
}

T_use <- min(T_full, as.integer(T_use))
idx_use <- if (use_last) seq.int(T_full - T_use + 1L, T_full) else seq_len(T_use)
y_full  <- y_full_all[idx_use, , drop = FALSE]

# Keep a matching long frame for "true q_p" computation restricted to used t's
dat_long_use <- dat_long |>
  dplyr::semi_join(y_full, by = c("t")) |>
  dplyr::arrange(t, p)

# ---- Split validation (fail fast; no silent patches) ----
# 1) Mutually exclusive options
if (!is.null(train_n) && !is.null(train_prop)) {
  stop(sprintf("Split config conflict: both train_n (%s) and train_prop (%s) are set. Specify only one.",
               as.character(train_n), as.character(train_prop)))
}
# 2) Range checks
if (!is.null(train_prop) && !(is.finite(train_prop) && train_prop > 0 && train_prop < 1)) {
  stop(sprintf("Invalid train_prop=%s. Must be in (0,1).", as.character(train_prop)))
}
if (!is.null(train_n) && !(is.finite(train_n) && train_n >= 1L && train_n <= (T_use - 1L))) {
  stop(sprintf("Invalid train_n=%s for T_use=%d. Must be in [1, %d].",
               as.character(train_n), T_use, T_use - 1L))
}

# 3) Resolve n_train with clear source tag
split_src <- "default"
n_train <- if (!is.null(train_n)) {
  split_src <- "train_n"
  as.integer(train_n)
} else if (!is.null(train_prop)) {
  split_src <- "train_prop"
  max(1L, min(T_use - 1L, floor(train_prop * T_use)))
} else {
  split_src <- "fallback_0.9"
  max(1L, min(T_use - 1L, floor(0.9 * T_use)))
}

H_forecast <- as.integer(T_use - n_train)

# Audit lines BEFORE any modeling
if (isTRUE(VERBOSE)) {
  cat(sprintf(
    paste0("SPLIT_RESOLVE | source=%s | T_full=%d | T_use=%d | use_last=%s | ",
          "train_n=%s | train_prop=%s | n_train=%d | H_forecast=%d | washout=%d\n"),
    split_src, T_full, T_use, as.character(use_last),
    ifelse(is.null(train_n), "NULL", as.character(train_n)),
    ifelse(is.null(train_prop), "NULL", format(train_prop, digits=6, trim=TRUE)),
    n_train, H_forecast, as.integer(desn_args$washout))
  )
}
# Hard stops for impossible/pointless configs
if (H_forecast < 1L) {
  stop(sprintf("Invalid split: H_forecast=%d (n_train=%d, T_use=%d). Adjust train_n/train_prop/T_use.", 
               H_forecast, n_train, T_use))
}

# Index diagnostics
idx_tr <- 1:n_train
idx_fc <- (n_train + 1L):T_use
if (isTRUE(VERBOSE)) {
  cat(sprintf("IDX | use_range=[%d..%d] | train=[%d..%d] | forecast=[%d..%d] | lens train=%d, fore=%d\n",
              min(idx_use), max(idx_use),
              ifelse(length(idx_tr), min(idx_tr), NA_integer_),
              ifelse(length(idx_tr), max(idx_tr), NA_integer_),
              ifelse(length(idx_fc), min(idx_fc), NA_integer_),
              ifelse(length(idx_fc), max(idx_fc), NA_integer_),
              length(idx_tr), length(idx_fc)))
}
y_train    <- y_full$y[idx_tr]
y_forecast <- y_full$y[idx_fc]

if (isTRUE(VERBOSE)) {
  cat(sprintf("[lens] y_train=%d | y_forecast=%d\n", length(y_train), length(y_forecast)))
}
# Teacher forcing (metadata only): using FULL TF because X_fc1 came from the full roll over y_full
tf_enable      <- TRUE
tf_first_k     <- NULL   # NULL = full TF (all H_forecast steps)
y_future_obs_fc <- y_forecast

if (isTRUE(VERBOSE)) {
  cat(sprintf("TF | mode=full | len(y_future_obs_fc)=%d\n", length(y_future_obs_fc)))
  flush.console()
}

# --- Teacher forcing guard (scalar) ---
use_tf <- is.numeric(y_future_obs_fc) &&
          length(y_future_obs_fc) > 0L &&
          any(!is.na(y_future_obs_fc))

# (optional sanity)
stopifnot(!use_tf || length(y_future_obs_fc) == H_forecast)

# === Shared reservoir pass → precompute design for train + 1-step forecast ===
n_drop <- max(as.integer(desn_args$m), as.integer(desn_args$washout))
if (n_train <= n_drop) {
  stop(sprintf(
    "Invalid split after feature drop: n_train=%d <= drop=max(m,washout)=%d. ",
    n_train, n_drop
  ), "Increase train_n/train_prop (or reduce m/washout).")
}

# desn_args$act_f <- as.character(desn_args$act_f)[1L]
# desn_args$act_k <- as.character(desn_args$act_k)[1L]

# --- Log the exact DESN settings that WILL be used (after final sanitize) ---
log_msg(
  "DESN (used) → D=%d | n=%s | n_tilde=%s | m=%d | rho=%s | alpha=%s | act_f=%s | act_k=%s | pi_w=%s | pi_in=%s | washout=%d | add_bias=%s | seed=%s",
  as.integer(desn_args$D),
  pretty_vec(as.integer(desn_args$n)),
  pretty_vec(as.integer(desn_args$n_tilde)),
  as.integer(desn_args$m),
  pretty_vec(as.numeric(desn_args$rho)),
  pretty_vec(as.numeric(desn_args$alpha)),
  pretty_vec(as.character(desn_args$act_f)),   # scalar by design here
  pretty_vec(as.character(desn_args$act_k)),   # scalar by design here
  pretty_vec(as.numeric(desn_args$pi_w)),
  pretty_vec(as.numeric(desn_args$pi_in)),
  as.integer(desn_args$washout),
  as.character(isTRUE(desn_args$add_bias)),
  pretty_vec(as.numeric(desn_args$seed))
)

shared_fit <- timed("shared_reservoir_roll (one pass over y_full)",
  do.call(qdesn_fit_vb, c(
    list(
      y = y_full$y,
      p0 = 0.50,            # unused in design-only mode
      fit_readout = FALSE   # IMPORTANT: no VB fit here
    ),
    desn_args
  ))
)

# Rows of shared_fit$X correspond to absolute times keep_all = (drop+1):T_use
keep_all_abs <- as.integer(shared_fit$meta$keep_idx)  # absolute w.r.t. y_full (1..T_use)
X_all_kept   <- as.matrix(shared_fit$X)               # nrow = length(keep_all_abs)

# Training design (keep rows within [drop+1 .. n_train])
keep_train_abs <- keep_all_abs[keep_all_abs <= n_train]
row_sel_train  <- which(keep_all_abs %in% keep_train_abs)
X_train        <- X_all_kept[row_sel_train, , drop = FALSE]
y_train_keep   <- y_full$y[keep_train_abs]

# One-step forecast design: rows at absolute times (n_train+1 .. T_use)
idx_fc_abs   <- seq.int(n_train + 1L, T_use)
row_sel_fc   <- which(keep_all_abs %in% idx_fc_abs)
X_fc1        <- X_all_kept[row_sel_fc, , drop = FALSE]

# Safety checks
stopifnot(nrow(X_train) == length(y_train_keep))
stopifnot(nrow(X_fc1)   == length(y_forecast))

if (isTRUE(VERBOSE)) {
  cat(sprintf("[shared] drop=%d | rows: X_train=%d, X_fc1=%d | cols=%d\n",
              n_drop, nrow(X_train), nrow(X_fc1), ncol(X_train)))
}

# --- 2) Fit & Forecast per p ----------------------------------------------
fit_and_forecast_p <- function(p0) {

  # Index of this quantile in p_vec
  idx_p <- which.min(abs(p_vec - p0))

  # Normalise beta prior type (default ridge if somehow NULL)
  beta_type <- tolower(vb_prior_beta_type %||% "ridge")
  if (!beta_type %in% c("ridge", "rhs")) {
    stop(sprintf("Unknown beta prior type '%s' (expected 'ridge' or 'rhs')", beta_type))
  }

  # Ridge prior variance for beta (scalar tau2, common across p)
  tau2_beta_p <- if (!is.null(vb_prior_beta_tau2)) vb_prior_beta_tau2 else 1e4

  beta_prior_obj <- if (beta_type == "rhs") {
    if (is.null(vb_prior_beta_rhs) || !is.list(vb_prior_beta_rhs)) {
      stop("vb$priors$beta$rhs must be a YAML mapping (list).")
    }
    beta_prior("rhs", rhs = vb_prior_beta_rhs)
  } else {
    beta_prior("ridge", ridge = list(tau2 = tau2_beta_p))
  }


  # VB controls per p
  vb_args_p <- vb_args_base
  vb_args_p$tol     <- vb_tol_for(p0)
  vb_args_p$tol_par <- vb_tol_par_for(p0)

  # Per-quantile inits (natural scale). Fallbacks are conservative.
  gamma_init_p <- if (!is.null(vb_init_gamma)) vb_init_gamma[idx_p] else 0
  sigma_init_p <- if (!is.null(vb_init_sigma)) vb_init_sigma[idx_p] else 1

  # Per-quantile priors for gamma (Normal) and sigma (IG).
  gamma_mu0_p <- if (!is.null(vb_prior_gamma_mu0)) vb_prior_gamma_mu0[idx_p] else 0
  gamma_s20_p <- if (!is.null(vb_prior_gamma_s20)) vb_prior_gamma_s20[idx_p] else 10

  sigma_a_p <- if (!is.null(vb_prior_sigma_a)) vb_prior_sigma_a[idx_p] else 1
  sigma_b_p <- if (!is.null(vb_prior_sigma_b)) vb_prior_sigma_b[idx_p] else 1

    # ---- Fit exAL readout directly on the precomputed training design ----
    p_dim <- ncol(X_train)

    tau2_beta_p <- as.numeric(tau2_beta_p)[1L]
    rhs_cfg <- vb_prior_beta_rhs %||% list()
    if (!is.list(rhs_cfg)) stop("vb_prior_beta_rhs must be a list.", call. = FALSE)

    need <- c("type","hypers","init","expected_prec","update","elbo")
    if (!all(need %in% names(beta_prior_obj))) {
      stop(sprintf("beta_prior_obj invalid. Names: %s", paste(names(beta_prior_obj), collapse = ", ")), call. = FALSE)
    }

    fit_args <- list(
      y            = y_train_keep,
      X            = X_train,
      p0           = p0,
      gamma_bounds = c(L.fn(p0), U.fn(p0)),

      # sigma prior (IG)
      a_sigma = sigma_a_p,
      b_sigma = sigma_b_p,

      # VB controls
      max_iter  = vb_args_p$max_iter,
      tol       = vb_args_p$tol,
      tol_par   = vb_args_p$tol_par,
      n_samp_xi = vb_args_p$n_samp_xi,
      verbose   = vb_args_p$verbose,

      # init on natural scale
      init = list(gamma = gamma_init_p, sigma = sigma_init_p),

      # new: beta prior object (ridge or RHS)
      beta_prior_obj = beta_prior_obj
    )

    # γ prior: Normal if provided; else flat (within bounds)
    if (!is.null(vb_prior_gamma_mu0)) {
      fit_args$prior_gamma_mu0 <- gamma_mu0_p
      fit_args$prior_gamma_s20 <- gamma_s20_p
      fit_args$log_prior_gamma <- function(g) {
        sum(stats::dnorm(g, mean = gamma_mu0_p, sd = sqrt(gamma_s20_p), log = TRUE))
      }
    } else {
      fit_args$log_prior_gamma <- function(g) 0
    }

    fit_exal <- timed(
      sprintf("fit_exAL_on_X_train(p=%s, prior=%s)", fmt_p(p0), beta_type),
      do.call(exal_ldvb_fit, fit_args)
    )

  # ---- Parameter posterior draws (γ, σ, β) for diagnostics + IJ ----------
  gamma_bounds_here <- c(L.fn(p0), U.fn(p0))  # or fit_args$gamma_bounds

  param_draws <- get_exal_param_draws(
    fit_exal,
    p            = p_dim,
    nd           = ij_nd_draws,
    gamma_bounds = gamma_bounds_here,
    seed         = synth_seed + round(1000 * p0)
  )

  # ---- μ draws and (optionally) IJ-corrected bands -----------------------
  mu_ij <- compute_mu_bands_with_ij(
    X_train      = X_train,
    y_train_keep = y_train_keep,
    X_fc1        = X_fc1,
    p0           = p0,
    param_draws  = param_draws,
    use_ij       = use_ij_correction
  )

  # ---- IJ correction for β (readout coefficients) ------------------------
  beta_ij <- NULL
  if (isTRUE(use_ij_correction) &&
      !is.null(mu_ij$loglik_mat) &&
      !is.null(mu_ij$draw_idx_keep)) {

    beta_draws_full <- param_draws$beta
    if (!is.null(beta_draws_full) && is.matrix(beta_draws_full)) {
      draw_idx_keep <- mu_ij$draw_idx_keep
      if (length(draw_idx_keep) >= 2L) {
        beta_draws_eff <- beta_draws_full[draw_idx_keep, , drop = FALSE]
        M_eff_beta     <- nrow(beta_draws_eff)

        if (M_eff_beta >= 2L) {
          # Functional matrix for β: rows = draws, cols = coefficients
          F_beta <- beta_draws_eff

          sd_ij_beta <- ij_sd_for_functional(
            F_all      = F_beta,
            loglik_mat = mu_ij$loglik_mat,
            n_obs      = length(y_train_keep)
          )

          # Posterior summaries (median + posterior SD) on same filtered draws
          beta_hat     <- apply(beta_draws_eff, 2L, stats::median)
          sd_post_beta <- matrixStats::colSds(beta_draws_eff)

          alpha      <- 0.05
          z_975      <- stats::qnorm(1 - alpha / 2)
          lo_beta_ij <- beta_hat - z_975 * sd_ij_beta
          hi_beta_ij <- beta_hat + z_975 * sd_ij_beta

          beta_ij <- list(
            beta_hat = beta_hat,
            sd_post  = sd_post_beta,
            sd_ij    = sd_ij_beta,
            lo_ij    = lo_beta_ij,
            hi_ij    = hi_beta_ij
          )
        }
      }
    }
  }

  # Attach (possibly NULL) β IJ summary to param_draws for downstream plots
  param_draws$beta_ij <- beta_ij

  # ---- Posterior predictive: TRAIN (for q̂ diagnostics) -------------------
  pp_tr <- timed(
    sprintf("posterior_predict TRAIN (p=%s, nd=%d)", fmt_p(p0), nd_draws),
    exal_vb_posterior_predict(fit_exal, X_new = X_train, nd = nd_draws, chunk = chunk_sz)
  )
  yrep_tr <- pp_tr$yrep

  # Use absolute indices from the shared pass restricted to the train window
  keep_rel <- keep_train_abs
  stopifnot(length(keep_rel) == nrow(X_train))

  q_true_tr <- true_q_at_tau(dat_long_use, tau = p0)[keep_rel]
  q_pred_tr <- apply(yrep_tr, 1L, stats::quantile, probs = p0, names = FALSE)

  df_mu_tr <- tibble::tibble(
    h      = seq_along(keep_rel),
    p0     = p0,
    mu     = mu_ij$mu_hat_tr,
    lo     = mu_ij$lo_tr,
    hi     = mu_ij$hi_tr,
    q_true = q_true_tr,
    y      = y_train_keep
  )

  df_pred_tr <- tibble::tibble(
    h      = seq_along(keep_rel),
    p0     = p0,
    q_pred = q_pred_tr,
    q_true = q_true_tr,
    y      = y_train_keep
  )

  if (isTRUE(use_ij_correction)) {
    df_pred_tr <- df_pred_tr %>%
      dplyr::mutate(
        q_hat_ij  = mu_ij$mu_hat_tr,
        lo_q_ij   = mu_ij$lo_tr,
        hi_q_ij   = mu_ij$hi_tr,
        lo_q_post = mu_ij$lo_post_tr,
        hi_q_post = mu_ij$hi_post_tr
      )
  }

  # ---- Posterior predictive: FORECAST (1-step teacher-forced design) -----
  pp_fc <- timed(
    sprintf("posterior_predict FORECAST (p=%s, nd=%d)", fmt_p(p0), nd_draws),
    exal_vb_posterior_predict(fit_exal, X_new = X_fc1, nd = nd_draws, chunk = chunk_sz)
  )
  yrep_fc <- pp_fc$yrep

  q_pred_fc <- apply(yrep_fc, 1L, stats::quantile, probs = p0, names = FALSE)
  q_true_fc <- true_q_at_tau(dat_long_use, tau = p0)[idx_fc]

  # Sanity checks right where they matter
  stopifnot(
    length(q_true_fc)  == H_forecast,
    nrow(X_fc1)        == H_forecast,
    length(y_forecast) == H_forecast
  )

  df_mu_fc <- tibble::tibble(
    h      = seq_len(H_forecast),
    p0     = p0,
    mu     = mu_ij$mu_hat_fc,
    lo     = mu_ij$lo_fc,
    hi     = mu_ij$hi_fc,
    q_true = q_true_fc,
    y      = y_forecast
  )

  df_pred_fc <- tibble::tibble(
    h      = seq_len(H_forecast),
    p0     = p0,
    q_pred = q_pred_fc,
    q_true = q_true_fc,
    y      = y_forecast
  )

  if (isTRUE(use_ij_correction)) {
    df_pred_fc <- df_pred_fc %>%
      dplyr::mutate(
        q_hat_ij  = mu_ij$mu_hat_fc,
        lo_q_ij   = mu_ij$lo_fc,
        hi_q_ij   = mu_ij$hi_fc,
        lo_q_post = mu_ij$lo_post_fc,
        hi_q_post = mu_ij$hi_post_fc
      )
  }

  # ---- Return in the same structure your downstream code expects ---------
  list(
    fit_train    = list(fit = fit_exal, meta = list(keep_idx = keep_train_abs)),
    yrep_fc      = yrep_fc,
    mu_draws_fc  = mu_ij$mu_draws_fc,
    df_mu_fc     = df_mu_fc,
    df_pred_fc   = df_pred_fc,
    yrep_tr      = yrep_tr,
    mu_draws_tr  = mu_ij$mu_draws_tr,
    df_mu_tr     = df_mu_tr,
    df_pred_tr   = df_pred_tr,
    param_draws  = param_draws
  )
}

fits_fc <- lapply(p_vec, fit_and_forecast_p)
names(fits_fc) <- paste0("p=", p_vec)

# --- 3) Per-p forecast plots
if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]
    g1 <- plot_mu_band(
      fits_fc[[k]]$df_mu_fc, p0,
      scope  = "Forecast",
      window = fore_last_window
    )
    g2 <- plot_empirical_quantile(
      fits_fc[[k]]$df_pred_fc, p0,
      scope  = "Forecast",
      window = fore_last_window
    )
    band_suffix <- if (isTRUE(use_ij_correction)) "_IJcorr" else ""

    timed(sprintf("plot+save forecast_mu_band(p=%s)", fmt_p(p0)), {
      print(g1)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(
          file.path(FIGS, sprintf("forecast_mu_band%s_p=%s.png", band_suffix, as.character(p0))),
          g1, width = 9, height = 4.8, dpi = 150
        )
      }
    })

    timed(sprintf("plot+save forecast_emp_q_vs_true(p=%s)", fmt_p(p0)), {
      print(g2)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(
          file.path(FIGS, sprintf("forecast_emp_q_vs_true_p=%s.png", as.character(p0))),
          g2, width = 9, height = 4.8, dpi = 150
        )
      }
    })
  }
}

# --- 3b) Per-p TRAIN plots for mû band (new)
if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]
    g1_tr <- plot_mu_band(
      fits_fc[[k]]$df_mu_tr, p0,
      scope  = "Train",
      window = train_last_window
    )
    band_suffix <- if (isTRUE(use_ij_correction)) "_IJcorr" else ""

    print(g1_tr)
    if (isTRUE(save_outputs)) {
      ggplot2::ggsave(
        file.path(FIGS, sprintf("train_mu_band%s_p=%s.png", band_suffix, as.character(p0))),
        g1_tr, width = 9, height = 4.8, dpi = 150
      )
    }
  }
}

# --- 3c) Per-p μ error band plots (Train & Forecast)
if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]

    mu_draws_tr_k <- fits_fc[[k]]$mu_draws_tr
    mu_draws_fc_k <- fits_fc[[k]]$mu_draws_fc

    # Safety: skip if draws are missing for some reason
    if (is.null(mu_draws_tr_k) || is.null(mu_draws_fc_k)) {
      next
    }

    df_mu_tr_k <- fits_fc[[k]]$df_mu_tr
    df_mu_fc_k <- fits_fc[[k]]$df_mu_fc

    g_err_tr <- plot_mu_error_band(
      mu_draws = mu_draws_tr_k,
      q_true   = df_mu_tr_k$q_true,
      h_index  = df_mu_tr_k$h,
      p0       = p0,
      scope    = "Train",
      window   = train_last_window
    )

    g_err_fc <- plot_mu_error_band(
      mu_draws = mu_draws_fc_k,
      q_true   = df_mu_fc_k$q_true,
      h_index  = df_mu_fc_k$h,
      p0       = p0,
      scope    = "Forecast",
      window   = fore_last_window
    )

    band_suffix <- if (isTRUE(use_ij_correction)) "_IJcorr" else ""

    timed(sprintf("plot+save train_mu_error_band(p=%s)", fmt_p(p0)), {
      print(g_err_tr)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(
          file.path(FIGS, sprintf("train_mu_error_band%s_p=%s.png",
                                  band_suffix, as.character(p0))),
          g_err_tr, width = 9, height = 4.8, dpi = 150
        )
      }
    })

    timed(sprintf("plot+save forecast_mu_error_band(p=%s)", fmt_p(p0)), {
      print(g_err_fc)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(
          file.path(FIGS, sprintf("forecast_mu_error_band%s_p=%s.png",
                                  band_suffix, as.character(p0))),
          g_err_fc, width = 9, height = 4.8, dpi = 150
        )
      }
    })
  }
}

# ================================================================
# 3d) Posterior parameter plots: γ, σ histograms + β forest
# ================================================================

if (!exists("plot_param_hist_ci", mode = "function")) {
  plot_param_hist_ci <- function(draws, param_name = "θ", add_bounds = NULL, bins = 100) {
    stopifnot(is.numeric(draws))
    qs <- qs_ci(draws, 0.95)
    df <- tibble::tibble(x = draws)
    g <- ggplot2::ggplot(df, ggplot2::aes(x = x)) +
      theme_exdqlm() +
      ggplot2::geom_histogram(bins = bins, color = "white") +
      ggplot2::geom_vline(xintercept = qs["med"], linetype = "solid") +
      ggplot2::geom_vline(xintercept = c(qs["lo"], qs["hi"]), linetype = "dashed", alpha = 0.8) +
      ggplot2::labs(
        title = sprintf("Posterior of %s", as.character(param_name)),
        subtitle = sprintf("median=%.3f, 95%% CI=[%.3f, %.3f]",
                           qs["med"], qs["lo"], qs["hi"]),
        x = as.character(param_name), y = "count"
      )
    if (!is.null(add_bounds) && length(add_bounds) == 2 && all(is.finite(add_bounds))) {
      g <- g + ggplot2::geom_vline(xintercept = add_bounds, linetype = "dotted", alpha = 0.6)
    }
    g
  }
}

if (isTRUE(do_plots)) {
  for (k in seq_along(p_vec)) {
    p0 <- p_vec[k]
    pars <- fits_fc[[k]]$param_draws
    if (is.null(pars) || (!length(pars$gamma) && !length(pars$sigma) && is.null(pars$beta))) {
      message(sprintf("[warn] No parameter draws available for p=%s; skipping posterior param plots.", fmt_p(p0)))
      next
    }

    # γ & σ histograms (side-by-side), using 0.01–0.99 sample range for x-axis
    plots_left <- list()

    # --- γ ---
    if (!is.null(pars$gamma) && length(pars$gamma)) {
      qs_gam <- qs_ci(pars$gamma, 0.95)

      # 1%–99% sample range for the x-axis (sample only; ignore support)
      x_lim_g <- stats::quantile(pars$gamma, c(0.01, 0.99), names = FALSE)
      if (!all(is.finite(x_lim_g)) || x_lim_g[1] >= x_lim_g[2]) {
        x_lim_g <- range(pars$gamma[is.finite(pars$gamma)])
      }

      # Subtitle: first line = CI, second line = support bounds
      sub_txt_g <- sprintf(
        "median=%.3f, 95%% CI=[%.3f, %.3f]\nSupport bounds=[%.3f, %.3f]",
        qs_gam["med"], qs_gam["lo"], qs_gam["hi"],
        pars$gamma_bounds[1], pars$gamma_bounds[2]
      )

      df_gam <- tibble::tibble(x = pars$gamma)

      plots_left$gamma <-
        ggplot2::ggplot(df_gam, ggplot2::aes(x = x)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(bins = 100, colour = "white") +
        ggplot2::geom_vline(xintercept = qs_gam["med"], linetype = "solid") +
        ggplot2::geom_vline(
          xintercept = c(qs_gam["lo"], qs_gam["hi"]),
          linetype   = "dashed", alpha = 0.8
        ) +
        ggplot2::labs(
          title    = "Posterior of γ",
          subtitle = sub_txt_g,
          x        = "γ",
          y        = "count"
        ) +
        ggplot2::coord_cartesian(xlim = x_lim_g)
    }

    # --- σ ---
    if (!is.null(pars$sigma) && length(pars$sigma)) {
      qs_sig <- qs_ci(pars$sigma, 0.95)

      x_lim_s <- stats::quantile(pars$sigma, c(0.01, 0.99), names = FALSE)
      if (!all(is.finite(x_lim_s)) || x_lim_s[1] >= x_lim_s[2]) {
        x_lim_s <- range(pars$sigma[is.finite(pars$sigma)])
      }

      df_sig <- tibble::tibble(x = pars$sigma)

      plots_left$sigma <-
        ggplot2::ggplot(df_sig, ggplot2::aes(x = x)) +
        theme_exdqlm() +
        ggplot2::geom_histogram(bins = 100, colour = "white") +
        ggplot2::geom_vline(xintercept = qs_sig["med"], linetype = "solid") +
        ggplot2::geom_vline(
          xintercept = c(qs_sig["lo"], qs_sig["hi"]),
          linetype   = "dashed", alpha = 0.8
        ) +
        ggplot2::labs(
          title    = "Posterior of σ",
          subtitle = sprintf(
            "median=%.3f, 95%% CI=[%.3f, %.3f]",
            qs_sig["med"], qs_sig["lo"], qs_sig["hi"]
          ),
          x        = "σ",
          y        = "count"
        ) +
        ggplot2::coord_cartesian(xlim = x_lim_s)
    }

    if (length(plots_left)) {
      g_params <- Reduce(`|`, plots_left) # patchwork: side-by-side
      print(g_params)
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("posterior_gamma_sigma_p=%s.png", as.character(p0))),
              g_params, width = 10.5, height = 4.8, dpi = 150)
      }
    }

    # β forest (all + top-K)
    if (!is.null(pars$beta) && is.matrix(pars$beta)) {
      term_names <- colnames(X_train)
      if (is.null(term_names)) term_names <- paste0("β", seq_len(ncol(pars$beta)))

      p_all <- ncol(pars$beta)

      g_beta_all <- plot_beta_forest(
        pars$beta, term_names = term_names, top_k = NULL
      )
      g_beta_top <- plot_beta_forest(
        pars$beta, term_names = term_names, top_k = min(50L, p_all)
      )

      print(g_beta_all); print(g_beta_top)

      if (isTRUE(save_outputs)) {
        # Only save the "ALL" forest if p is modest; otherwise it becomes unreadable and >50"
        if (p_all <= 250L) {
          height_all <- max(5, 0.18 * p_all)
          ggplot2::ggsave(
            file.path(FIGS, sprintf("posterior_beta_forest_ALL_p=%s.png", as.character(p0))),
            g_beta_all, width = 9.5, height = height_all, dpi = 150
          )
        } else {
          message(sprintf(
            "[info] Skipping posterior_beta_forest_ALL_p=%s (p=%d is too large for a legible full forest).",
            fmt_p(p0), p_all
          ))
        }

        ggplot2::ggsave(
          file.path(FIGS, sprintf("posterior_beta_forest_TOP50_p=%s.png", as.character(p0))),
          g_beta_top, width = 9.5, height = 10, dpi = 150
        )
      }

      # Optional: IJ-corrected β forest (top-K) if IJ info is available
      if (isTRUE(use_ij_correction) &&
          !is.null(pars$beta_ij) &&
          !is.null(pars$beta_ij$beta_hat) &&
          !is.null(pars$beta_ij$lo_ij) &&
          !is.null(pars$beta_ij$hi_ij)) {

        beta_hat_ij <- pars$beta_ij$beta_hat
        lo_ij_beta  <- pars$beta_ij$lo_ij
        hi_ij_beta  <- pars$beta_ij$hi_ij

        len_beta <- length(beta_hat_ij)
        if (len_beta != p_all) {
          warning(sprintf(
            "[warn] beta_ij length (%d) != p_all (%d) for p=%s; skipping IJ β forest.",
            len_beta, p_all, fmt_p(p0)
          ))
        } else {
          g_beta_ij_top <- plot_beta_forest_summary(
            beta_hat   = beta_hat_ij,
            lo         = lo_ij_beta,
            hi         = hi_ij_beta,
            term_names = term_names,
            top_k      = min(50L, p_all),
            title      = "Readout coefficients: IJ-corrected 95% band"
          )

          print(g_beta_ij_top)

          if (isTRUE(save_outputs)) {
            ggplot2::ggsave(
              file.path(FIGS, sprintf("posterior_beta_forest_IJ_TOP50_p=%s.png", as.character(p0))),
              g_beta_ij_top, width = 9.5, height = 10, dpi = 150
            )
          }
        }
      }
    }
  }
}

# --- 4) ELBO traces
# --- 4) ELBO traces -----------------------------------------------------------
k_burn <- 20L

elbo_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$elbo
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_along(tr),
    elbo = as.numeric(tr)
  )
}))

if (isTRUE(do_plots) && nrow(elbo_df)) {
  elbo_df <- elbo_df |>
    dplyr::filter(iter > k_burn) |>
    dplyr::mutate(
      p0_chr = factor(sprintf("%.2f", p0),
                      levels = sprintf("%.2f", p_vec))
    )

  g_elbo <- ggplot2::ggplot(
      elbo_df,
      ggplot2::aes(x = iter, y = elbo, colour = p0_chr)
    ) +
    theme_exdqlm() +
    ggplot2::labs(
      x        = "VB iteration",
      y        = "ELBO",
      colour   = "p0",
      title    = "ELBO traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  print(g_elbo)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("elbo_traces_skip_k=%d.png", k_burn)),
      g_elbo, width = 9, height = 4.8, dpi = 150
    )
  }
}

# --- 4b) γ and σ traces (skip same burn-in as ELBO) --------------------------
gamma_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$gamma_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_along(tr),
    gamma = as.numeric(tr)
  )
}))

sigma_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$sigma_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_along(tr),
    sigma = as.numeric(tr)
  )
}))

if (isTRUE(do_plots) && nrow(gamma_df) && nrow(sigma_df)) {
  gamma_df <- gamma_df |>
    dplyr::filter(iter > k_burn) |>
    dplyr::mutate(p0_chr = factor(sprintf("%.2f", p0),
                                  levels = sprintf("%.2f", p_vec)))

  sigma_df <- sigma_df |>
    dplyr::filter(iter > k_burn) |>
    dplyr::mutate(p0_chr = factor(sprintf("%.2f", p0),
                                  levels = sprintf("%.2f", p_vec)))

  g_gamma <- ggplot2::ggplot(gamma_df,
                             ggplot2::aes(x = iter, y = gamma, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "γ",
      colour = "p0",
      title = "γ traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_sigma <- ggplot2::ggplot(sigma_df,
                             ggplot2::aes(x = iter, y = sigma, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "σ",
      colour = "p0",
      title = "σ traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  # Side-by-side using patchwork
  g_gamma_sigma <- g_gamma | g_sigma

  print(g_gamma_sigma)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("gamma_sigma_traces_skip_k=%d.png", k_burn)),
      g_gamma_sigma, width = 11, height = 4.8, dpi = 150
    )
  }
}

# --- 4c) LD safeguard new_term traces (skip same burn-in as ELBO) -----------
newterm_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  tr <- fits_fc[[i]]$fit_train$fit$misc$new_term_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0       = p_vec[i],
    iter     = seq_along(tr),
    new_term = as.numeric(tr)
  )
}))

if (isTRUE(do_plots) && nrow(newterm_df)) {
  newterm_df <- newterm_df |>
    dplyr::filter(iter > k_burn, is.finite(new_term)) |>
    dplyr::mutate(
      p0_chr = factor(sprintf("%.2f", p0),
                      levels = sprintf("%.2f", p_vec))
    )

  g_newterm <- ggplot2::ggplot(
      newterm_df,
      ggplot2::aes(x = iter, y = new_term, colour = p0_chr)
    ) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "|ΔE[γ]| + |ΔE[σ]|",
      colour = "p0",
      title = "LD safeguard term traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  print(g_newterm)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("new_term_traces_skip_k=%d.png", k_burn)),
      g_newterm, width = 9, height = 4.8, dpi = 150
    )
  }
}

# --- 4d) RHS latent traces (tau, c2, lambda summaries) ----------------------
rhs_tau_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") {
    return(tibble::tibble())
  }
  tr <- fit$misc$rhs_tau_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_along(tr),
    tau  = as.numeric(tr)
  )
}))

rhs_c2_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") {
    return(tibble::tibble())
  }
  tr <- fit$misc$rhs_c2_trace
  if (is.null(tr) || !length(tr)) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_along(tr),
    c2   = as.numeric(tr)
  )
}))

if (isTRUE(do_plots) && nrow(rhs_tau_df) && nrow(rhs_c2_df)) {
  rhs_tau_df <- rhs_tau_df |>
    dplyr::filter(iter > k_burn, is.finite(tau)) |>
    dplyr::mutate(p0_chr = factor(sprintf("%.2f", p0),
                                  levels = sprintf("%.2f", p_vec)))

  rhs_c2_df <- rhs_c2_df |>
    dplyr::filter(iter > k_burn, is.finite(c2)) |>
    dplyr::mutate(p0_chr = factor(sprintf("%.2f", p0),
                                  levels = sprintf("%.2f", p_vec)))

  g_tau <- ggplot2::ggplot(rhs_tau_df,
                           ggplot2::aes(x = iter, y = tau, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "tau",
      colour = "p0",
      title = "RHS tau traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_c2 <- ggplot2::ggplot(rhs_c2_df,
                          ggplot2::aes(x = iter, y = c2, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "c2",
      colour = "p0",
      title = "RHS c2 traces across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map)

  g_tau_c2 <- g_tau | g_c2

  print(g_tau_c2)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("rhs_tau_c2_traces_skip_k=%d.png", k_burn)),
      g_tau_c2, width = 11, height = 4.8, dpi = 150
    )
  }
}

rhs_lambda_df <- dplyr::bind_rows(lapply(seq_along(fits_fc), function(i) {
  fit <- fits_fc[[i]]$fit_train$fit
  if (is.null(fit) || is.null(fit$beta_prior) || fit$beta_prior$type != "rhs") {
    return(tibble::tibble())
  }
  tr_mean <- fit$misc$rhs_lambda_mean_trace
  tr_min  <- fit$misc$rhs_lambda_min_trace
  tr_max  <- fit$misc$rhs_lambda_max_trace
  if (is.null(tr_mean) || is.null(tr_min) || is.null(tr_max)) return(tibble::tibble())
  n_iter <- min(length(tr_mean), length(tr_min), length(tr_max))
  if (n_iter <= 0L) return(tibble::tibble())
  tibble::tibble(
    p0   = p_vec[i],
    iter = seq_len(n_iter),
    lambda_mean = as.numeric(tr_mean[seq_len(n_iter)]),
    lambda_min  = as.numeric(tr_min[seq_len(n_iter)]),
    lambda_max  = as.numeric(tr_max[seq_len(n_iter)])
  )
}))

if (isTRUE(do_plots) && nrow(rhs_lambda_df)) {
  rhs_lambda_long <- rhs_lambda_df |>
    tidyr::pivot_longer(
      cols = dplyr::starts_with("lambda_"),
      names_to = "stat",
      values_to = "lambda"
    ) |>
    dplyr::mutate(
      stat = dplyr::recode(stat,
                           lambda_min = "min",
                           lambda_mean = "mean",
                           lambda_max = "max"),
      p0_chr = factor(sprintf("%.2f", p0),
                      levels = sprintf("%.2f", p_vec))
    ) |>
    dplyr::filter(iter > k_burn, is.finite(lambda))

  g_lambda <- ggplot2::ggplot(rhs_lambda_long,
                              ggplot2::aes(x = iter, y = lambda, colour = p0_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "VB iteration",
      y = "lambda summary",
      colour = "p0",
      title = "RHS lambda summaries across quantile models",
      subtitle = sprintf("First k=%d iterations omitted", k_burn)
    ) +
    ggplot2::geom_line(linewidth = 0.8, alpha = 0.95) +
    ggplot2::scale_color_manual(values = col_map) +
    ggplot2::facet_wrap(~ stat, nrow = 1, scales = "free_y")

  print(g_lambda)
  if (isTRUE(save_outputs)) {
    ggplot2::ggsave(
      file.path(FIGS, sprintf("rhs_lambda_summary_traces_skip_k=%d.png", k_burn)),
      g_lambda, width = 12, height = 4.2, dpi = 150
    )
  }
}


# ================================================================
# --- 5) Synthesis (forecast + train)
draws_list_fc <- lapply(fits_fc, function(obj) obj$yrep_fc)
synth_fc <- timed(sprintf("synthesize_forecast_draws(T=%d,nd=%d,grid_M=%d,n_samp=%d)",
                          H_forecast, nd_draws, synth_grid_M, synth_nsamp),
  exdqlm_synthesize_from_draws(
    draws_list = draws_list_fc, p = p_vec,
    enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
    grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed, T_expected = H_forecast
  )
)


p_comp <- c(0.05, 0.50, 0.95)
synth_cols_fc <- lapply(p_comp, function(tau) apply(synth_fc$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_fc) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_fc <- tibble::as_tibble(synth_cols_fc)

true_cols_fc <- setNames(vector("list", length(p_comp)), paste0("true_q_", fmt_p(p_comp)))
for (i in seq_along(p_comp)) true_cols_fc[[i]] <- true_q_at_tau(dat_long_use, tau = p_comp[i])[idx_fc]
true_q_fc <- tibble::as_tibble(true_cols_fc)

compare_fc <- tibble::tibble(h = seq_len(H_forecast), y = y_forecast) |>
  dplyr::bind_cols(true_q_fc) |>
  dplyr::bind_cols(synth_q_fc)

if (isTRUE(do_plots)) {
  timed("plot+save synth_forecast trio", {
    plots_synth_fc <- lapply(
    p_comp,
    function(tau)
      plot_synth_q_vs_true(
        compare_fc, tau,
        scope  = "Forecast",
        window = fore_last_window
      )
  )

  g_band_fc <- plot_synth_predictive_band(
    synth_draws = synth_fc$draws,
    y_vec       = y_forecast,
    scope       = "Forecast",
    window      = fore_last_window,
    fill_col    = ACCENT_ORANGE,
    show_median = TRUE
  )

    for (j in seq_along(plots_synth_fc)) {
      print(plots_synth_fc[[j]])
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("forecast_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
              plots_synth_fc[[j]], width=9, height=4.8, dpi=150)
      }
    }

    print(g_band_fc)
    if (isTRUE(save_outputs)) {
      ggsave(file.path(FIGS, "forecast_obs_with_95_band.png"), g_band_fc, width=9, height=4.8, dpi=150)
    }
  })
}

# Train synthesis (for completeness)
draws_list_tr <- lapply(fits_fc, function(obj) obj$yrep_tr)
T_train_keep  <- nrow(draws_list_tr[[1]])
keep_train    <- fits_fc[[1]]$fit_train$meta$keep_idx
synth_tr <- timed(sprintf("synthesize_train_draws(T=%d,grid_M=%d,n_samp=%d)",
                          T_train_keep, synth_grid_M, synth_nsamp),
  exdqlm_synthesize_from_draws(
    draws_list = draws_list_tr, p = p_vec,
    enforce_isotonic = synth_isotonic, rearrange = synth_rearrange,
    grid_M = synth_grid_M, n_samp = synth_nsamp, seed = synth_seed, T_expected = T_train_keep
  )
)

# Build train comparison frame for synthesis (before plotting)
synth_cols_tr <- lapply(p_comp, function(tau)
  apply(synth_tr$draws, 1L, stats::quantile, probs = tau, names = FALSE))
names(synth_cols_tr) <- paste0("synth_q_", fmt_p(p_comp))
synth_q_tr <- tibble::as_tibble(synth_cols_tr)

true_cols_tr <- setNames(vector("list", length(p_comp)), paste0("true_q_", fmt_p(p_comp)))
for (i in seq_along(p_comp)) true_cols_tr[[i]] <- true_q_at_tau(dat_long_use, tau = p_comp[i])[keep_train]
true_q_tr <- tibble::as_tibble(true_cols_tr)

compare_tr <- tibble::tibble(h = seq_len(T_train_keep), y = y_train_keep) |>
  dplyr::bind_cols(true_q_tr) |>
  dplyr::bind_cols(synth_q_tr)

if (isTRUE(do_plots)) {
  timed("plot+save synth_train trio", {
    plots_synth_tr <- lapply(
      p_comp,
      function(tau)
        plot_synth_q_vs_true(
          compare_tr, tau,
          scope  = "Train",
          window = train_last_window
        )
    )
    for (j in seq_along(plots_synth_tr)) {
      print(plots_synth_tr[[j]])
      if (isTRUE(save_outputs)) {
        ggsave(file.path(FIGS, sprintf("train_synth_vs_true_p=%s.png", fmt_p(p_comp[j]))),
              plots_synth_tr[[j]], width=9, height=4.8, dpi=150)
      }
    }
    g_band_tr <- plot_synth_predictive_band(
      synth_draws = synth_tr$draws,
      y_vec       = y_train_keep,
      scope       = "Train",
      window      = train_last_window,
      fill_col    = ACCENT_ORANGE,
      show_median = TRUE
    )
    print(g_band_tr)
    if (isTRUE(save_outputs)) {
      ggsave(file.path(FIGS, "train_obs_with_95_band.png"), g_band_tr, width=9, height=4.8, dpi=150)
    }
  })
}

# --- 6) Save core objects
if (isTRUE(save_outputs)) {
  saveRDS(
    list(
      fits_fc = fits_fc, synth_fc = synth_fc, compare_fc = compare_fc,
            cfg = list(
        p_vec = p_vec, desn_args = desn_args, vb_args_base = vb_args_base,
        nd_draws = nd_draws, chunk_sz = chunk_sz,
        last_window          = fore_last_window,
        last_window_train    = train_last_window,
        last_window_forecast = fore_last_window,
        teacher_forcing = list(
          enable  = tf_enable,
          first_k = tf_first_k,
          explicit = y_future_obs_explicit,
          y_future_obs_fc = y_future_obs_fc
        ),
        synth = list(
          isotonic  = synth_isotonic,
          rearrange = synth_rearrange,
          grid_M    = synth_grid_M,
          n_samp    = synth_nsamp,
          seed      = synth_seed
        ),
        split = list(
          T_use      = T_use,
          n_train    = n_train,
          H_forecast = H_forecast
        ),
        ij = list(
          use_ij_correction = use_ij_correction,
          nd_draws          = ij_nd_draws
        ),
        outputs = list(
          save          = save_outputs,
          keep_draws    = keep_draws,
          thesis_subset = thesis_subset
        ),
        vb_priors = list(
          beta_type = vb_prior_beta_type,
          beta_ridge_tau2 = vb_prior_beta_tau2,
          beta_rhs = vb_prior_beta_rhs
        )
      )
    ),
    file.path(MODELS, "forecast_objects.rds")
  )
}

# ================================================================
# 7) Calibration diagnostics (μ, q̂ₚ, synthesized q): tables + rolling plots
# ================================================================
if (isTRUE(do_calibration)) {
  # helpers
  wilson_ci <- function(k, n, conf = 0.95) {
    if (n <= 0) return(c(NA_real_, NA_real_))
    z <- stats::qnorm(0.5 + conf/2)
    p <- k / n
    den <- 1 + z^2 / n
    cen <- (p + z^2/(2*n)) / den
    rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
    c(max(0, cen - rad), min(1, cen + rad))
  }
  pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }
  roll_mean <- function(x, W) { if (W <= 1) return(x); as.numeric(stats::filter(x, rep(1 / W, W), sides = 1)) }

  # Build long frames aligned in "time" for train and forecast
  # μ
  mu_tr_long <- dplyr::bind_rows(purrr::compact(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_mu_tr; if (is.null(d) || !nrow(d)) return(NULL)
    keep <- fits_fc[[i]]$fit_train$meta$keep_idx
    d %>% dplyr::mutate(scope="train", p_chr=sprintf("%.2f", p_vec[i]),
                        t_aligned=keep, mu_hat=mu)
  })))
  mu_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_mu_fc
    d |> dplyr::mutate(scope = "forecast", p_chr = sprintf("%.2f", p_vec[i]),
                       t_aligned = n_train + h, mu_hat = mu)
  }))
  mu_long <- dplyr::bind_rows(mu_tr_long, mu_fc_long)

  # q̂_p
  q_tr_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_pred_tr; keep <- fits_fc[[i]]$fit_train$meta$keep_idx
    d |> dplyr::mutate(scope="train", p_chr=sprintf("%.2f", p_vec[i]),
                       t_aligned=keep, qhat=q_pred)
  }))
  q_fc_long <- dplyr::bind_rows(lapply(seq_along(p_vec), function(i) {
    d <- fits_fc[[i]]$df_pred_fc
    d |> dplyr::mutate(scope="forecast", p_chr=sprintf("%.2f", p_vec[i]),
                       t_aligned = n_train + h, qhat=q_pred)
  }))
  q_long <- dplyr::bind_rows(q_tr_long, q_fc_long)

  # Synthesized q_p (train + forecast) at p_comp
  qsynth_tr_long <- dplyr::bind_rows(lapply(p_comp, function(tau) {
    tibble::tibble(
      scope     = "train", p0 = tau, p_chr = sprintf("%.2f", tau),
      t_aligned = keep_train,
      q_synth   = synth_q_tr[[paste0("synth_q_", fmt_p(tau))]],
      y         = y_train_keep
    )
  }))
  qsynth_fc_long <- dplyr::bind_rows(lapply(p_comp, function(tau) {
    tibble::tibble(
      scope     = "forecast", p0 = tau, p_chr = sprintf("%.2f", tau),
      t_aligned = n_train + seq_len(H_forecast),
      q_synth   = synth_q_fc[[paste0("synth_q_", fmt_p(tau))]],
      y         = y_forecast
    )
  }))
  qsynth_long <- dplyr::bind_rows(qsynth_tr_long, qsynth_fc_long)

  # ---- SAFE COERCION for calibration summaries ----
  force_numeric_column <- function(df, qcol) {
    x <- df[[qcol]]
    # If it's a matrix (e.g., T x M draws accidentally carried over), use the first column
    if (is.matrix(x)) x <- drop(x[, 1, drop = TRUE])
    # If it's a list column, take the first numeric scalar from each cell
    if (is.list(x))  x <- vapply(x, function(z) as.numeric(z)[1], numeric(1))
    x <- as.numeric(x)
    if (length(x) != nrow(df)) {
      stop(sprintf("Column '%s' has length %d but nrow(df)=%d (class=%s).",
                  qcol, length(x), nrow(df), paste(class(df[[qcol]]), collapse=",")))
    }
    df[[qcol]] <- x
    df
  }

  summarize_cov_tbl_safe <- function(df, qcol) {
    stopifnot(all(c("y","p0","scope", qcol) %in% names(df)))
    df <- force_numeric_column(df, qcol)
    df |>
      dplyr::filter(is.finite(.data$y), is.finite(.data[[qcol]])) |>
      dplyr::group_by(.data$scope, .data$p0) |>
      dplyr::summarise(
        N        = dplyr::n(),
        k        = sum(.data$y <= .data[[qcol]], na.rm = TRUE),
        coverage = ifelse(N > 0, k / N, NA_real_),
        cov_lo95 = wilson_ci(k, N)[1],
        cov_hi95 = wilson_ci(k, N)[2],
        pinball  = mean(pinball_loss(.data$y, .data[[qcol]], dplyr::first(.data$p0)), na.rm = TRUE),
        .groups  = "drop"
      ) |>
      dplyr::arrange(.data$scope, .data$p0)
  }

    timed("calibration: summarize tables (mu, qhat, qsynth)", {
    cov_mu_tbl     <- summarize_cov_tbl_safe(dplyr::rename(mu_long,  qcol = mu_hat) |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
    cov_qhat_tbl   <- summarize_cov_tbl_safe(dplyr::rename(q_long,   qcol = qhat)   |> dplyr::mutate(p0 = as.numeric(p_chr)), "qcol")
    cov_qsynth_tbl <- summarize_cov_tbl_safe(dplyr::rename(qsynth_long, qcol = q_synth), "qcol")
    print(cov_mu_tbl); print(cov_qhat_tbl); print(cov_qsynth_tbl)
    if (isTRUE(save_outputs)) {
      readr::write_csv(cov_mu_tbl,     file.path(TABLES, "calibration_mu_table.csv"))
      readr::write_csv(cov_qhat_tbl,   file.path(TABLES, "calibration_qhat_table.csv"))
      readr::write_csv(cov_qsynth_tbl, file.path(TABLES, "calibration_qsynth_table.csv"))
    }
  })

  # Rolling-coverage plots (μ, q̂ₚ, q_synth)
  cov_window <- 365L
  show_last  <- 300L

plot_rolling_cov <- function(df_long, qcol,
                             window = NULL, show_last = NULL,
                             title_left = "Rolling empirical coverage",
                             show_rcov_band = FALSE,
                             show_target_band = FALSE) {

  if (is.null(window))    window    <- get0("cov_window", ifnotfound = 365L, inherits = TRUE)
  if (is.null(show_last)) show_last <- get0("show_last",  ifnotfound = 300L, inherits = TRUE)

  # Coerce target column to numeric (handles list/matrix edge cases)
  if (is.matrix(df_long[[qcol]])) df_long[[qcol]] <- drop(df_long[[qcol]][, 1, drop = TRUE])
  if (is.list(df_long[[qcol]]))   df_long[[qcol]] <- vapply(df_long[[qcol]], function(z) as.numeric(z)[1], numeric(1))
  df_long[[qcol]] <- as.numeric(df_long[[qcol]])

  # SAFE helpers (auto-shrink W to series length)
  roll_sum  <- function(x, W) { W_eff <- min(W, length(x)); if (W_eff < 1) return(rep(NA_real_, length(x)))
                                as.numeric(stats::filter(x, rep(1,        W_eff), sides = 1)) }
  roll_mean <- function(x, W) { W_eff <- min(W, length(x)); if (W_eff < 1) return(rep(NA_real_, length(x)))
                                as.numeric(stats::filter(x, rep(1/W_eff,  W_eff), sides = 1)) }

  d <- df_long |>
    dplyr::mutate(ind = as.integer(.data$y <= .data[[qcol]])) |>
    dplyr::arrange(scope, p_chr, t_aligned) |>
    dplyr::group_by(scope, p_chr) |>
    dplyr::mutate(
      W_use = pmax(1L, pmin(window, dplyr::n())),
      k_win = roll_sum(ind,  W_use[1]),
      rcov  = roll_mean(ind, W_use[1]),
      t_max = max(t_aligned, na.rm = TRUE)
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(t_aligned > (t_max - show_last))

  wilson_ci_vec <- function(k, n, conf = 0.95) {
    z <- stats::qnorm(0.5 + conf/2); p <- k / n
    den <- 1 + z^2 / n; cen <- (p + z^2/(2*n)) / den
    rad <- z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / den
    list(lo = pmax(0, cen - rad), hi = pmin(1, cen + rad))
  }
  ci <- wilson_ci_vec(d$k_win, d$W_use)
  d$lo_cov <- ci$lo; d$hi_cov <- ci$hi

  W_lab <- if (any(d$W_use < window, na.rm = TRUE)) paste0("≤", window) else as.character(window)

  d <- d |> dplyr::mutate(p_chr = factor(p_chr, levels = sprintf("%.2f", p_vec)))
  ref <- d |> dplyr::distinct(scope, p_chr) |> dplyr::mutate(p0 = as.numeric(as.character(p_chr)))

  x_rng <- range(d$t_aligned, na.rm = TRUE)
  last_pts <- d %>%
    dplyr::group_by(scope, p_chr) %>% dplyr::slice_tail(n = 1) %>% dplyr::ungroup() %>%
    dplyr::mutate(x_lab = t_aligned - 0.03 * diff(x_rng), y_lab = pmin(pmax(rcov + 0.02, 0), 1))

  ggplot2::ggplot(d, ggplot2::aes(x = t_aligned, y = rcov, colour = p_chr)) +
    theme_exdqlm() +
    ggplot2::labs(
      x = "time index (aligned)",
      y = sprintf("rolling Pr(y ≤ %s)  (W %s)", if (qcol=="mu_hat") "μ" else "q", W_lab),
      title    = paste0(title_left, if (qcol=="mu_hat") " of μ" else " of q"),
      subtitle = sprintf("Last %d points; ribbon: Wilson CI of rolling coverage", show_last)
    ) +
    ggplot2::geom_hline(data = ref, ggplot2::aes(yintercept = p0, colour = p_chr),
                        linetype = "dashed", linewidth = 0.7, show.legend = FALSE) +
    { if (isTRUE(show_rcov_band))
        ggplot2::geom_ribbon(ggplot2::aes(x = t_aligned, ymin = lo_cov, ymax = hi_cov,
                                           fill = p_chr, group = p_chr),
                              inherit.aes = FALSE, alpha = 0.18)
      else ggplot2::geom_blank() } +
    ggplot2::geom_line(linewidth = 0.9, na.rm = TRUE) +
    ggplot2::geom_point(data = last_pts, size = 2.4) +
    ggplot2::geom_text(data = last_pts,
                       ggplot2::aes(x = x_lab, y = y_lab, label = sprintf("%.2f", rcov)),
                       size = 3, hjust = 1) +
    ggplot2::scale_color_manual(name = "quantile p",
      values = setNames(col_map, sprintf("%.2f", p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_fill_manual(name = "quantile p",
      values = setNames(sapply(col_map, scales::alpha, alpha = 0.18), sprintf("%.2f", p_vec)),
      labels = function(x) scales::percent(as.numeric(x))) +
    ggplot2::scale_y_continuous(breaks = seq(0,1,0.1), labels = scales::percent_format(accuracy = 1)) +
    ggplot2::scale_x_continuous(limits = x_rng, expand = c(0, 0)) +
    ggplot2::coord_cartesian(ylim = c(0, 1), expand = FALSE)
}


g_cov_mu_train <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="train"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)

g_cov_mu_fore  <- plot_rolling_cov(mu_long |> dplyr::filter(scope=="forecast"),
                                   qcol = "mu_hat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = TRUE,  show_target_band = FALSE)

# Keep q̂ and q_synth as purely empirical rolling curves (no ribbons)
g_cov_q_train  <- plot_rolling_cov(q_long  |> dplyr::filter(scope=="train"),
                                   qcol = "qhat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_q_fore   <- plot_rolling_cov(q_long  |> dplyr::filter(scope=="forecast"),
                                   qcol = "qhat",
                                   window = cov_window, show_last = show_last,
                                   show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_qsynth_train <- plot_rolling_cov(qsynth_long |> dplyr::filter(scope=="train") |> dplyr::rename(q = q_synth),
                                       qcol = "q",
                                       window = cov_window, show_last = show_last,
                                       show_rcov_band = FALSE, show_target_band = FALSE)

g_cov_qsynth_fore  <- plot_rolling_cov(qsynth_long |> dplyr::filter(scope=="forecast") |> dplyr::rename(q = q_synth),
                                       qcol = "q",
                                       window = cov_window, show_last = show_last,
                                       show_rcov_band = FALSE, show_target_band = FALSE)

  timed("calibration: rolling coverage plots", {
    # build all 6 plots & save (your existing code)
    print(g_cov_mu_train); print(g_cov_mu_fore)
    print(g_cov_q_train);  print(g_cov_q_fore)
    print(g_cov_qsynth_train); print(g_cov_qsynth_fore)
    if (isTRUE(save_outputs)) {
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_mu_train_W=%d.png", cov_window)),      g_cov_mu_train, width=9, height=4.8, dpi=150)
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_mu_forecast_W=%d.png", cov_window)),   g_cov_mu_fore,  width=9, height=4.8, dpi=150)
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qhat_train_W=%d.png", cov_window)),    g_cov_q_train,  width=9, height=4.8, dpi=150)
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qhat_forecast_W=%d.png", cov_window)), g_cov_q_fore,   width=9, height=4.8, dpi=150)
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qsynth_train_W=%d.png", cov_window)),  g_cov_qsynth_train, width=9, height=4.8, dpi=150)
      ggplot2::ggsave(file.path(FIGS, sprintf("rolling_cov_qsynth_forecast_W=%d.png", cov_window)), g_cov_qsynth_fore, width=9, height=4.8, dpi=150)
    }
  })
}

# ================================================================
# 8) PIT diagnostics (train & forecast) using a chosen p model (0.50)
# ================================================================
if (isTRUE(do_pit)) {
  emp_pit_vec <- function(y, yrep_mat) {
    stopifnot(length(y) == nrow(yrep_mat))
    rowMeans(sweep(yrep_mat, 1, y, FUN = "<="), na.rm = TRUE)
  }
  i_med <- which.min(abs(p_vec - 0.50))
  pit_tr <- emp_pit_vec(y_train[fits_fc[[i_med]]$fit_train$meta$keep_idx], fits_fc[[i_med]]$yrep_tr)
  pit_fc <- emp_pit_vec(y_forecast, fits_fc[[i_med]]$yrep_fc)

  plot_pit_hist <- function(pit, title) {
    pit <- pit[is.finite(pit)]
    ks  <- suppressWarnings(stats::ks.test(pit, "punif"))
    ggplot2::ggplot(tibble::tibble(pit = pit), ggplot2::aes(x = pit)) +
      theme_exdqlm() +
      ggplot2::geom_histogram(ggplot2::aes(y = after_stat(density)),
                              boundary = 0, bins = 20, color = "white") +
      ggplot2::geom_hline(yintercept = 1, linetype = 2) +
      ggplot2::labs(title = title,
                    subtitle = sprintf("KS p = %.3f", ks$p.value),
                    x = "PIT", y = "density") +
      ggplot2::coord_cartesian(xlim = c(0, 1), ylim = c(0, NA))
  }
  plot_pit_qq <- function(pit, title) {
    n <- sum(is.finite(pit)); pit_s <- sort(pit[is.finite(pit)])
    u <- stats::ppoints(n)
    ggplot2::ggplot(tibble::tibble(u = u, pit = pit_s), ggplot2::aes(x = u, y = pit)) +
      theme_exdqlm() +
      ggplot2::geom_abline(slope = 1, intercept = 0, linetype = 2) +
      ggplot2::geom_point(alpha = 0.7, size = 1.6) +
      ggplot2::labs(title = title, x = "Uniform(0,1) quantiles", y = "PIT quantiles") +
      ggplot2::coord_cartesian(xlim = c(0,1), ylim = c(0,1))
  }

  g_pit_tr_hist <- plot_pit_hist(pit_tr, "PIT histogram (train)")
  g_pit_fc_hist <- plot_pit_hist(pit_fc, "PIT histogram (forecast)")
  g_pit_tr_qq   <- plot_pit_qq(pit_tr,   "PIT QQ (train)")
  g_pit_fc_qq   <- plot_pit_qq(pit_fc,   "PIT QQ (forecast)")
  g_pit_train    <- g_pit_tr_hist | g_pit_tr_qq
  g_pit_forecast <- g_pit_fc_hist | g_pit_fc_qq

  if (isTRUE(do_pit)) {
    timed("PIT: compute + plots + save", {
      # your PIT code unchanged, just wrapped
      print(g_pit_train); print(g_pit_forecast)
      if (isTRUE(save_outputs)) {
        ggplot2::ggsave(file.path(FIGS, "pit_train.png"),    g_pit_train,    width = 12, height = 4.5, dpi = 150)
        ggplot2::ggsave(file.path(FIGS, "pit_forecast.png"), g_pit_forecast, width = 12, height = 4.5, dpi = 150)
      }
    })
  }
}

# ================================================================
# 9) CRPS and S score (CRPS + averaged marginal pinball over K)
# ================================================================
if (isTRUE(do_scores)) {
  # Efficient CRPS from samples:
  # CRPS(F, y) ≈ (1/M)∑|z_m - y| - (1/M^2)∑_{k=1..M} (2k - M - 1) z_(k), where z_(k) is sorted draws
  crps_row <- function(y, z) {
    z <- sort(z); M <- length(z)
    term1 <- mean(abs(z - y))
    # ∑_{k}(2k - M - 1) z_(k)
    k <- seq_len(M)
    term2 <- sum((2*k - M - 1) * z) / (M^2)
    term1 - term2
  }
  crps_vec <- function(y_vec, draws_mat) {
    stopifnot(length(y_vec) == nrow(draws_mat))
    vapply(seq_len(nrow(draws_mat)), function(i) crps_row(y_vec[i], draws_mat[i, ]), numeric(1))
  }

  # Forecast-window CRPS from synthesized draws
  crps_fc <- crps_vec(y_forecast, synth_fc$draws)

  # Marginal pinball (using synthesized quantiles at p_comp), average over K
  pinball_loss <- function(y, qhat, p) { e <- y - qhat; (p - (e < 0)) * e }
  # Build matrix of synthesized quantiles T × K at selected p_comp
  synth_q_fc_mat <- do.call(cbind, lapply(p_comp, function(tau) synth_q_fc[[paste0("synth_q_", fmt_p(tau))]]))
  colnames(synth_q_fc_mat) <- sprintf("p=%s", fmt_p(p_comp))

  # Per-time averaged marginal pinball
  pinball_fc_mean <- rowMeans(vapply(seq_along(p_comp), function(j)
    pinball_loss(y_forecast, synth_q_fc_mat[, j], p_comp[j]), numeric(length(y_forecast))))

  # S score per time and summary
  S_fc <- crps_fc + pinball_fc_mean

  scores_fc_df <- tibble::tibble(
    h = seq_len(H_forecast),
    y = y_forecast,
    CRPS = crps_fc,
    pinball_mean = pinball_fc_mean,
    S = S_fc
  )

  # Train-window scores (optional but often handy)
  crps_tr <- crps_vec(y_train_keep, synth_tr$draws)
  synth_q_tr_mat <- do.call(cbind, lapply(p_comp, function(tau) synth_q_tr[[paste0("synth_q_", fmt_p(tau))]]))
  colnames(synth_q_tr_mat) <- sprintf("p=%s", fmt_p(p_comp))
  pinball_tr_mean <- rowMeans(vapply(seq_along(p_comp), function(j)
    pinball_loss(y_train_keep, synth_q_tr_mat[, j], p_comp[j]), numeric(length(keep_train))))
  S_tr <- crps_tr + pinball_tr_mean

  scores_tr_df <- tibble::tibble(
    h = seq_len(T_train_keep),
    y = y_train_keep,
    CRPS = crps_tr,
    pinball_mean = pinball_tr_mean,
    S = S_tr
  )

  # Summaries
  scores_summary <- tibble::tibble(
    split = c("train","forecast"),
    CRPS_mean = c(mean(crps_tr), mean(crps_fc)),
    PinballMean_mean = c(mean(pinball_tr_mean), mean(pinball_fc_mean)),
    S_mean = c(mean(S_tr), mean(S_fc))
  )

  timed("Scores: CRPS + Pinball + S (train/forecast) + save", {
    # your Scores code unchanged, just wrapped
    print(scores_summary)
    if (isTRUE(save_outputs)) {
      readr::write_csv(scores_fc_df,    file.path(TABLES, "scores_forecast_series.csv"))
      readr::write_csv(scores_tr_df,    file.path(TABLES, "scores_train_series.csv"))
      readr::write_csv(scores_summary,  file.path(TABLES, "scores_summary.csv"))
    }
  })
}
