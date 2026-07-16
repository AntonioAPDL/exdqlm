#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("jsonlite", "pkgload", "yaml")
  missing <- setdiff(req, rownames(installed.packages()))
  if (length(missing)) {
    stop(sprintf("Missing required package(s): %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(lapply(req, require, character.only = TRUE))
})

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (!length(idx) || idx[[1L]] >= length(args)) return(default)
  args[[idx[[1L]] + 1L]]
}
has_flag <- function(flag) any(args == flag)
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

repo_root <- normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  raw <- as.character(path %||% "")[1L]
  if (!nzchar(trimws(raw))) return(NULL)
  if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
  normalizePath(raw, winslash = "/", mustWork = isTRUE(must_work))
}

write_csv <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

write_json <- function(x, path) {
  path <- resolve_path(path, must_work = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

read_csv <- function(path) utils::read.csv(resolve_path(path), check.names = FALSE, stringsAsFactors = FALSE)
num <- function(x) suppressWarnings(as.numeric(x))
int <- function(x) suppressWarnings(as.integer(x))
chr <- function(x) as.character(x %||% NA_character_)
tau_key <- function(x) sprintf("%.8f", as.numeric(x))
tau_label <- function(x) sub("0+$", "", sub("[.]$", "", sprintf("%.2f", as.numeric(x))))
as_bool <- function(x) {
  if (is.logical(x)) return(x)
  toupper(trimws(as.character(x))) %in% c("TRUE", "T", "1", "YES")
}

split_csv <- function(x) {
  x <- as.character(x %||% "")[1L]
  if (!nzchar(trimws(x))) return(character(0))
  trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
}

split_num <- function(x) {
  out <- suppressWarnings(as.numeric(split_csv(x)))
  out[is.finite(out)]
}

first_col <- function(df, names, default = NA) {
  for (nm in names) if (nm %in% colnames(df)) return(df[[nm]])
  rep(default, nrow(df))
}

bind_rows <- function(xs) {
  xs <- Filter(function(x) is.data.frame(x) && nrow(x), xs)
  if (!length(xs)) return(data.frame(stringsAsFactors = FALSE))
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}

md_table <- function(x, cols, max_rows = 50L) {
  cols <- intersect(cols, names(x))
  if (!length(cols) || !nrow(x)) return("| none |\n|---|")
  y <- utils::head(x[, cols, drop = FALSE], max_rows)
  out <- c(
    paste("|", paste(cols, collapse = " | "), "|"),
    paste("|", paste(rep("---", length(cols)), collapse = " | "), "|")
  )
  for (i in seq_len(nrow(y))) {
    vals <- vapply(y[i, , drop = TRUE], function(v) {
      v <- as.character(v)
      v[is.na(v)] <- ""
      gsub("\n", " ", v, fixed = TRUE)
    }, character(1L))
    out <- c(out, paste("|", paste(vals, collapse = " | "), "|"))
  }
  out
}

sha256_file <- function(path) unname(tools::sha256sum(resolve_path(path)))

stage_file <- as.character(get_arg(
  "--stage-file",
  "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_candidate_full_confirmation"
))[1L]
workers <- suppressWarnings(as.integer(get_arg("--workers", "12"))[1L])
if (!is.finite(workers) || workers < 1L) workers <- 12L
workers <- min(workers, 16L)
max_per_cell_lik <- suppressWarnings(as.integer(get_arg("--max-candidates-per-cell-likelihood", "7"))[1L])
if (!is.finite(max_per_cell_lik) || max_per_cell_lik < 1L) max_per_cell_lik <- 7L
focus_taus <- split_num(get_arg("--focus-taus", "0.05,0.25"))
if (!length(focus_taus)) focus_taus <- c(0.05, 0.25)
focus_families <- split_csv(get_arg("--focus-families", "normal,laplace,gausmix"))
likelihoods <- split_csv(get_arg("--likelihoods", "al,exal"))
likelihoods <- likelihoods[likelihoods %in% c("al", "exal")]
if (!length(likelihoods)) likelihoods <- c("al", "exal")

base_defaults_path <- resolve_path(get_arg(
  "--base-defaults",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_mcmc_vb_winner_confirmation_defaults.yaml")
))
profiles_out <- resolve_path(get_arg("--profiles-out", file.path("config", "validation", paste0(stage_file, "_profiles.csv"))), must_work = FALSE)
assignments_out <- resolve_path(get_arg("--assignments-out", file.path("config", "validation", paste0(stage_file, "_cell_assignments.csv"))), must_work = FALSE)
defaults_out <- resolve_path(get_arg("--defaults-out", file.path("config", "validation", paste0(stage_file, "_defaults.yaml"))), must_work = FALSE)
grid_out <- resolve_path(get_arg("--grid-out", file.path("config", "validation", paste0(stage_file, "_grid.csv"))), must_work = FALSE)
target_specs_out <- resolve_path(get_arg("--target-specs-out", file.path("config", "validation", paste0(stage_file, "_target_spec_ids.csv"))), must_work = FALSE)
manifest_out <- resolve_path(get_arg("--manifest-out", file.path("config", "validation", paste0(stage_file, "_materialization_manifest.json"))), must_work = FALSE)
diagnostic_out <- resolve_path(get_arg("--diagnostic-out", file.path("reports", "qdesn_mcmc_validation", stage_file, "materialization_diagnostics")), must_work = FALSE)
refresh_grid <- !has_flag("--no-refresh-grid")
refresh_materialized <- has_flag("--refresh-materialized")

historical_csv <- resolve_path(get_arg(
  "--historical-selection",
  file.path("validation", "fitforecast_v2", "docs", "qdesn_tt500_vb_historical_winner_handoff_selected_designs_20260709.csv")
), must_work = TRUE)
v51_cell_csv <- resolve_path(get_arg(
  "--v51-cell-summary",
  file.path(
    "reports", "qdesn_mcmc_validation",
    "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51",
    "qdesn-vb-case-targeted-rhs-v51-full-20260713__git-a2f11f8",
    "20260713-002045__git-a2f11f8",
    "tables", "qdesn_tt500_vb_dominance_cell_summary.csv"
  )
), must_work = TRUE)
qvbm1_freeze_csv <- resolve_path(get_arg(
  "--qvbm1-freeze",
  file.path("validation", "fitforecast_v2", "docs", "qdesn_tt500_vb_active_baseline_freeze_20260715.csv")
), must_work = TRUE)
qvbm3_winners_csv <- resolve_path(get_arg(
  "--qvbm3-winners",
  file.path("validation", "fitforecast_v2", "docs", "qvbm3_tau1e6_closeout_20260716_cell_winners.csv")
), must_work = TRUE)
v51_profiles_csv <- resolve_path(get_arg(
  "--v51-profiles",
  file.path("config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_case_targeted_rhs_v51_profiles.csv")
), must_work = TRUE)

profile_lookup_paths <- unique(c(
  v51_profiles_csv,
  Sys.glob(file.path(repo_root, "config", "validation", "qvbm1_*_profiles.csv")),
  Sys.glob(file.path(repo_root, "config", "validation", "qvbm3_tau1e6_*_profiles.csv")),
  Sys.glob(file.path(repo_root, "config", "validation", "qvbm3_capacity_*_profiles.csv")),
  Sys.glob(file.path(repo_root, "config", "validation", "qdesn_dynamic_fitforecast_v2_tt500_vb_*_profiles.csv"))
))
profile_lookup_paths <- profile_lookup_paths[file.exists(profile_lookup_paths)]

profile_source <- bind_rows(lapply(profile_lookup_paths, function(path) {
  x <- read_csv(path)
  if (!"screening_profile_id" %in% names(x)) return(data.frame(stringsAsFactors = FALSE))
  x$profile_source_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  x
}))

required_profile_cols <- c(
  "screening_profile_id", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
  "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500",
  "x_feature_count"
)

profile_from_lookup <- function(profile_id, fallback = NULL) {
  profile_id <- as.character(profile_id)[1L]
  row <- profile_source[as.character(profile_source$screening_profile_id) == profile_id, , drop = FALSE]
  if (nrow(row)) return(row[1L, , drop = FALSE])
  if (!is.null(fallback) && nrow(fallback)) {
    out <- data.frame(screening_profile_id = profile_id, stringsAsFactors = FALSE)
    out$screening_stage <- as.character(first_col(fallback, c("screening_stage", "profile_screening_stage"), "historical_external"))[1L]
    out$screening_wave <- as.character(first_col(fallback, c("screening_wave", "profile_screening_wave"), "historical_external"))[1L]
    out$profile_role <- as.character(first_col(fallback, c("profile_profile_role", "profile_role"), "historical_external"))[1L]
    out$enabled <- TRUE
    out$D <- int(first_col(fallback, c("profile_D", "D")))[1L]
    out$n_each <- int(first_col(fallback, c("profile_n_each", "n_each")))[1L]
    out$n_tilde_each <- int(first_col(fallback, c("profile_n_tilde_each", "n_tilde_each"), out$n_each))[1L]
    out$m <- int(first_col(fallback, c("profile_m", "m")))[1L]
    out$alpha <- num(first_col(fallback, c("profile_alpha", "alpha")))[1L]
    out$rho <- num(first_col(fallback, c("profile_rho", "rho")))[1L]
    out$pi_w <- num(first_col(fallback, c("profile_pi_w", "pi_w")))[1L]
    out$pi_in <- num(first_col(fallback, c("profile_pi_in", "pi_in")))[1L]
    out$washout <- int(first_col(fallback, c("profile_washout", "washout"), 300))[1L]
    out$add_bias <- as_bool(first_col(fallback, c("profile_add_bias", "add_bias"), TRUE))[1L]
    out$seed <- int(first_col(fallback, c("profile_seed", "seed"), 123))[1L]
    out$readout_y_lags <- int(first_col(fallback, c("profile_readout_y_lags", "readout_y_lags")))[1L]
    out$reservoir_lags <- int(first_col(fallback, c("profile_reservoir_lags", "reservoir_lags"), 0))[1L]
    out$rhs_tau0 <- num(first_col(fallback, c("profile_rhs_tau0", "rhs_tau0"), 1e-4))[1L]
    out$dimension_p_estimate <- int(first_col(fallback, c("profile_dimension_p_estimate", "dimension_p_estimate")))[1L]
    out$p_over_n_tt500 <- num(first_col(fallback, c("profile_p_over_n_tt500", "p_over_n_tt500")))[1L]
    out$x_feature_count <- int(first_col(fallback, c("profile_x_feature_count", "x_feature_count"), 5))[1L]
    out$profile_source_path <- as.character(first_col(fallback, c("profile_source_path"), NA_character_))[1L]
    return(out)
  }
  stop(sprintf("Could not resolve profile spec for `%s`.", profile_id), call. = FALSE)
}

candidate_rows <- list()
add_candidate <- function(family, tau, likelihood_target, profile_id, candidate_source,
                          selection_reason, source_priority, source_rank,
                          metrics = list(), source_path = NA_character_, fallback = NULL) {
  family <- as.character(family)[1L]
  tau <- as.numeric(tau)[1L]
  likelihood_target <- as.character(likelihood_target)[1L]
  if (!family %in% focus_families || !any(abs(tau - focus_taus) < 1e-8) ||
      !likelihood_target %in% likelihoods) {
    return(invisible(NULL))
  }
  profile <- profile_from_lookup(profile_id, fallback = fallback)
  for (nm in required_profile_cols) {
    if (!nm %in% names(profile)) profile[[nm]] <- NA
  }
  bad <- c("D", "n_each", "m", "alpha", "rho", "pi_w", "pi_in", "readout_y_lags", "reservoir_lags", "rhs_tau0")
  if (any(!is.finite(num(profile[1L, bad, drop = TRUE])))) {
    stop(sprintf("Profile `%s` has incomplete core DESN/RHS fields.", profile_id), call. = FALSE)
  }
  candidate_rows[[length(candidate_rows) + 1L]] <<- data.frame(
    family = family,
    tau = tau,
    likelihood_target = likelihood_target,
    source_screening_profile_id = as.character(profile_id),
    candidate_source = candidate_source,
    selection_reason = selection_reason,
    source_priority = as.integer(source_priority),
    source_rank = as.integer(source_rank),
    source_path = as.character(source_path),
    vb_forecast_mae_ratio = as.numeric(metrics$forecast_mae_ratio %||% NA_real_),
    vb_forecast_check_ratio = as.numeric(metrics$forecast_check_ratio %||% NA_real_),
    vb_fit_rmse_ratio = as.numeric(metrics$fit_rmse_ratio %||% NA_real_),
    vb_fit_check_ratio = as.numeric(metrics$fit_check_ratio %||% NA_real_),
    vb_worst_ratio = as.numeric(metrics$worst_ratio %||% NA_real_),
    source_profile_role = as.character(profile$profile_role[[1L]] %||% NA_character_),
    source_screening_stage = as.character(profile$screening_stage[[1L]] %||% NA_character_),
    source_screening_wave = as.character(profile$screening_wave[[1L]] %||% NA_character_),
    D = int(profile$D)[1L],
    n_each = int(profile$n_each)[1L],
    n_tilde_each = int(profile$n_tilde_each)[1L],
    m = int(profile$m)[1L],
    alpha = num(profile$alpha)[1L],
    rho = num(profile$rho)[1L],
    pi_w = num(profile$pi_w)[1L],
    pi_in = num(profile$pi_in)[1L],
    washout = int(profile$washout)[1L],
    add_bias = as_bool(profile$add_bias)[1L],
    seed = int(profile$seed)[1L],
    readout_y_lags = int(profile$readout_y_lags)[1L],
    reservoir_lags = int(profile$reservoir_lags)[1L],
    rhs_tau0 = num(profile$rhs_tau0)[1L],
    dimension_p_estimate = int(profile$dimension_p_estimate)[1L],
    p_over_n_tt500 = num(profile$p_over_n_tt500)[1L],
    x_feature_count = int(profile$x_feature_count)[1L],
    profile_source_path = as.character(profile$profile_source_path[[1L]] %||% NA_character_),
    stringsAsFactors = FALSE
  )
  invisible(NULL)
}

historical <- read_csv(historical_csv)
historical$tau <- num(historical$tau)
historical$max_primary_ratio <- num(historical$max_primary_ratio)
historical <- historical[historical$family %in% focus_families & historical$tau %in% focus_taus, , drop = FALSE]
for (key in unique(paste(historical$family, tau_key(historical$tau), sep = "\r"))) {
  rows <- historical[paste(historical$family, tau_key(historical$tau), sep = "\r") == key, , drop = FALSE]
  rows <- rows[order(rows$max_primary_ratio, rows$target_profile_rank), , drop = FALSE]
  rows <- utils::head(rows, 2L)
  for (i in seq_len(nrow(rows))) {
    for (lik in likelihoods) {
      add_candidate(
        rows$family[[i]], rows$tau[[i]], lik,
        rows$resolved_screening_profile_id[[i]],
        "historical_all_primary_vb",
        "older broad-screen all-primary VB winner",
        source_priority = 20L,
        source_rank = i,
        metrics = list(
          forecast_mae_ratio = rows$forecast_mae_ratio_vs_best_vb_baseline[[i]],
          forecast_check_ratio = rows$forecast_pinball_ratio_vs_best_vb_baseline[[i]],
          fit_rmse_ratio = rows$fit_rmse_ratio_vs_best_vb_baseline[[i]],
          fit_check_ratio = rows$fit_pinball_ratio_vs_best_vb_baseline[[i]],
          worst_ratio = rows$max_primary_ratio[[i]]
        ),
        source_path = historical_csv,
        fallback = rows[i, , drop = FALSE]
      )
    }
  }
}

v51 <- read_csv(v51_cell_csv)
v51$tau <- num(v51$tau)
ratio_cols <- c(
  forecast_mae_ratio = "forecast_mae_ratio_vs_best_vb_baseline",
  forecast_check_ratio = "forecast_pinball_ratio_vs_best_vb_baseline",
  fit_rmse_ratio = "fit_rmse_ratio_vs_best_vb_baseline",
  fit_check_ratio = "fit_pinball_ratio_vs_best_vb_baseline"
)
for (nm in ratio_cols) v51[[nm]] <- num(v51[[nm]])
v51$max_primary_ratio <- do.call(pmax, c(v51[unname(ratio_cols)], list(na.rm = TRUE)))
v51 <- v51[v51$family %in% focus_families & v51$tau %in% focus_taus, , drop = FALSE]
for (key in unique(paste(v51$family, tau_key(v51$tau), sep = "\r"))) {
  rows <- v51[paste(v51$family, tau_key(v51$tau), sep = "\r") == key, , drop = FALSE]
  pick_idx <- c(
    order(rows$max_primary_ratio, rows$fit_rmse_ratio_vs_best_vb_baseline)[1L],
    order(rows$fit_rmse_ratio_vs_best_vb_baseline, rows$max_primary_ratio)[1L],
    order(rows$forecast_pinball_ratio_vs_best_vb_baseline, rows$max_primary_ratio)[1L],
    order(rows$forecast_mae_ratio_vs_best_vb_baseline, rows$max_primary_ratio)[1L],
    order(rows$fit_pinball_ratio_vs_best_vb_baseline, rows$max_primary_ratio)[1L]
  )
  pick_idx <- unique(pick_idx[is.finite(pick_idx)])
  rows <- rows[pick_idx, , drop = FALSE]
  rows <- rows[order(rows$max_primary_ratio), , drop = FALSE]
  rows <- utils::head(rows, 3L)
  for (i in seq_len(nrow(rows))) {
    for (lik in likelihoods) {
      add_candidate(
        rows$family[[i]], rows$tau[[i]], lik,
        rows$screening_profile_id_representative[[i]] %||% rows$screening_profile_base[[i]],
        "case_targeted_v51_vb",
        "recent case-targeted VB metric specialist",
        source_priority = 30L,
        source_rank = i,
        metrics = list(
          forecast_mae_ratio = rows$forecast_mae_ratio_vs_best_vb_baseline[[i]],
          forecast_check_ratio = rows$forecast_pinball_ratio_vs_best_vb_baseline[[i]],
          fit_rmse_ratio = rows$fit_rmse_ratio_vs_best_vb_baseline[[i]],
          fit_check_ratio = rows$fit_pinball_ratio_vs_best_vb_baseline[[i]],
          worst_ratio = rows$max_primary_ratio[[i]]
        ),
        source_path = v51_cell_csv,
        fallback = rows[i, , drop = FALSE]
      )
    }
  }
}

qvbm1_freeze <- read_csv(qvbm1_freeze_csv)
qvbm1_winners <- read_csv(qvbm1_freeze$baseline_winners_csv[[1L]])
qvbm1_winners$tau <- num(qvbm1_winners$tau)
qvbm1_winners <- qvbm1_winners[qvbm1_winners$family %in% focus_families & qvbm1_winners$tau %in% focus_taus, , drop = FALSE]
for (i in seq_len(nrow(qvbm1_winners))) {
  add_candidate(
    qvbm1_winners$family[[i]], qvbm1_winners$tau[[i]], qvbm1_winners$likelihood_family[[i]],
    qvbm1_winners$screening_profile_id[[i]],
    "qvbm1_mechanism_first_vb",
    "mechanism-first cell winner; VB may understate MCMC value",
    source_priority = 10L,
    source_rank = i,
    metrics = list(
      forecast_mae_ratio = qvbm1_winners$ratio_vs_exdqlm_dqlm_forecast_mae[[i]],
      forecast_check_ratio = qvbm1_winners$ratio_vs_exdqlm_dqlm_forecast_check[[i]],
      fit_rmse_ratio = qvbm1_winners$ratio_vs_exdqlm_dqlm_fit_rmse[[i]],
      fit_check_ratio = qvbm1_winners$ratio_vs_exdqlm_dqlm_fit_check[[i]],
      worst_ratio = qvbm1_winners$worst_ratio_vs_exdqlm_dqlm[[i]]
    ),
    source_path = qvbm1_freeze$baseline_winners_csv[[1L]]
  )
}

qvbm3 <- read_csv(qvbm3_winners_csv)
qvbm3$tau <- num(qvbm3$tau)
qvbm3 <- qvbm3[qvbm3$family %in% focus_families & qvbm3$tau %in% focus_taus, , drop = FALSE]
for (i in seq_len(nrow(qvbm3))) {
  add_candidate(
    qvbm3$family[[i]], qvbm3$tau[[i]], qvbm3$likelihood_family[[i]],
    qvbm3$screening_profile_id[[i]],
    "qvbm3_lowtau_capacity_vb",
    "capacity/low-tau diagnostic cell winner; retained because MCMC can differ from VB",
    source_priority = 40L,
    source_rank = i,
    metrics = list(
      forecast_mae_ratio = qvbm3$ratio_vs_exdqlm_dqlm_forecast_mae[[i]],
      forecast_check_ratio = qvbm3$ratio_vs_exdqlm_dqlm_forecast_check[[i]],
      fit_rmse_ratio = qvbm3$ratio_vs_exdqlm_dqlm_fit_rmse[[i]],
      fit_check_ratio = qvbm3$ratio_vs_exdqlm_dqlm_fit_check[[i]],
      worst_ratio = qvbm3$worst_ratio_vs_exdqlm_dqlm[[i]]
    ),
    source_path = qvbm3_winners_csv
  )
}

candidates <- bind_rows(candidate_rows)
if (!nrow(candidates)) stop("No MCMC candidate rows were selected.", call. = FALSE)
candidates$cell_lik_key <- paste(candidates$family, tau_key(candidates$tau), candidates$likelihood_target, sep = "\r")
candidates$dedupe_key <- paste(candidates$cell_lik_key, candidates$source_screening_profile_id, sep = "\r")
candidates <- candidates[order(candidates$source_priority, candidates$source_rank, candidates$vb_worst_ratio), , drop = FALSE]
candidates <- candidates[!duplicated(candidates$dedupe_key), , drop = FALSE]
candidates <- bind_rows(lapply(split(candidates, candidates$cell_lik_key), function(rows) {
  rows <- rows[order(rows$source_priority, rows$source_rank, rows$vb_worst_ratio), , drop = FALSE]
  utils::head(rows, max_per_cell_lik)
}))
candidates <- candidates[order(candidates$family, candidates$tau, candidates$likelihood_target, candidates$source_priority, candidates$source_rank), , drop = FALSE]
candidates$cell_candidate_rank <- ave(seq_len(nrow(candidates)), candidates$cell_lik_key, FUN = seq_along)

profile_group_key <- paste(candidates$source_screening_profile_id, candidates$likelihood_target, sep = "\r")
profile_id_lookup <- setNames(
  sprintf("mcvbc_%03d_%s", seq_along(unique(profile_group_key)), sub("[^a-z]", "", unique(profile_group_key))),
  unique(profile_group_key)
)
profile_id_lookup <- setNames(
  sprintf(
    "mcvbc_%03d_%s",
    seq_along(unique(profile_group_key)),
    vapply(strsplit(unique(profile_group_key), "\r", fixed = TRUE), function(z) z[[2L]], character(1L))
  ),
  unique(profile_group_key)
)
candidates$screening_profile_id <- unname(profile_id_lookup[profile_group_key])

profiles <- candidates[!duplicated(candidates$screening_profile_id), , drop = FALSE]
profiles <- profiles[, c(
  "screening_profile_id", "source_screening_profile_id", "candidate_source",
  "selection_reason", "source_profile_role", "source_screening_stage",
  "source_screening_wave", "D", "n_each", "n_tilde_each", "m", "alpha", "rho",
  "pi_w", "pi_in", "washout", "add_bias", "seed", "readout_y_lags",
  "reservoir_lags", "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500",
  "x_feature_count", "profile_source_path"
), drop = FALSE]
profiles$screening_stage <- "mcmc_vb_candidate_full_confirmation"
profiles$screening_wave <- paste0("mcmc_vb_candidate_full_confirmation_", format(Sys.Date(), "%Y_%m_%d"))
profiles$profile_role <- paste("mcmc_candidate_from", profiles$candidate_source, sep = "_")
profiles$enabled <- TRUE
profiles$target_cells <- vapply(profiles$screening_profile_id, function(pid) {
  rows <- candidates[candidates$screening_profile_id == pid, , drop = FALSE]
  paste(unique(paste(rows$family, tau_label(rows$tau), rows$likelihood_target, sep = ":")), collapse = ";")
}, character(1L))
profiles <- profiles[, c(
  "screening_profile_id", "screening_stage", "screening_wave", "profile_role",
  "enabled", "D", "n_each", "n_tilde_each", "m", "alpha", "rho", "pi_w",
  "pi_in", "washout", "add_bias", "seed", "readout_y_lags", "reservoir_lags",
  "rhs_tau0", "dimension_p_estimate", "p_over_n_tt500", "x_feature_count",
  "target_cells", "source_screening_profile_id", "candidate_source",
  "selection_reason", "source_profile_role", "source_screening_stage",
  "source_screening_wave", "profile_source_path"
), drop = FALSE]

assignments <- candidates
assignments$assignment_key <- paste(assignments$screening_profile_id, assignments$family, tau_key(assignments$tau), sep = "\r")
assignments$assignment_id <- sprintf("mcmc_vbcand_%04d", seq_len(nrow(assignments)))
assignments$cell_status <- "vb_candidate_mcmc_confirmation"
assignments$priority_rank <- match(assignments$cell_lik_key, unique(assignments$cell_lik_key))
assignments$target_profile_rank <- assignments$cell_candidate_rank
assignments$source_profile <- assignments$source_screening_profile_id
assignments$source_worst_ratio <- assignments$vb_worst_ratio
assignments$bottleneck_metric <- "mcmc_not_vb_decides"
assignments <- assignments[, c(
  "assignment_key", "assignment_id", "family", "tau", "likelihood_target",
  "cell_status", "priority_rank", "target_profile_rank", "screening_profile_id",
  "source_profile", "candidate_source", "selection_reason", "source_worst_ratio",
  "vb_forecast_mae_ratio", "vb_forecast_check_ratio", "vb_fit_rmse_ratio",
  "vb_fit_check_ratio", "bottleneck_metric", "source_path"
), drop = FALSE]

cell_plan <- aggregate(
  list(n_candidates = assignments$screening_profile_id),
  by = list(family = assignments$family, tau = assignments$tau, likelihood_target = assignments$likelihood_target),
  FUN = length
)
cell_plan$cell_status <- "vb_candidate_mcmc_confirmation"
cell_plan$priority_rank <- seq_len(nrow(cell_plan))
cell_plan$target_profiles <- vapply(seq_len(nrow(cell_plan)), function(i) {
  rows <- assignments[
    assignments$family == cell_plan$family[[i]] &
      abs(assignments$tau - cell_plan$tau[[i]]) < 1e-8 &
      assignments$likelihood_target == cell_plan$likelihood_target[[i]],
    ,
    drop = FALSE
  ]
  paste(rows$screening_profile_id, collapse = ";")
}, character(1L))

plan <- list(
  profiles = profiles,
  assignments = assignments,
  cell_plan = cell_plan,
  manifest = list(
    stage_file = stage_file,
    selection_policy = "VB is diagnostic only; full MCMC is run for a diverse slate of qvbm1 mechanism, older all-primary, v51 case-targeted, and qvbm3 low-tau/capacity candidates.",
    focus_families = as.list(focus_families),
    focus_taus = as.list(focus_taus),
    likelihoods = as.list(likelihoods),
    max_candidates_per_cell_likelihood = max_per_cell_lik,
    source_files = as.list(c(historical_csv, v51_cell_csv, qvbm1_freeze_csv, qvbm3_winners_csv))
  )
)

diag_tables <- file.path(diagnostic_out, "tables")
diag_summary <- file.path(diagnostic_out, "summary")
diag_manifest <- file.path(diagnostic_out, "manifest")
dir.create(diag_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_summary, recursive = TRUE, showWarnings = FALSE)
dir.create(diag_manifest, recursive = TRUE, showWarnings = FALSE)

selected_candidates_path <- write_csv(candidates, file.path(diag_tables, "qdesn_tt500_mcmc_vb_candidate_selected_candidates.csv"))
cell_plan_path <- write_csv(cell_plan, file.path(diag_tables, "qdesn_tt500_mcmc_vb_candidate_cell_plan.csv"))

mat <- exdqlm:::qdesn_dynamic_fitforecast_materialize_forecast_targeted_stage(
  plan = plan,
  base_defaults_path = base_defaults_path,
  profiles_out = profiles_out,
  assignments_out = assignments_out,
  defaults_out = defaults_out,
  grid_out = grid_out,
  workers = workers,
  refresh_grid = refresh_grid,
  refresh_materialized = refresh_materialized,
  stage_stub = stage_file,
  stage_desc = "Q-DESN 500-observation full MCMC confirmation of diverse VB candidates where VB is diagnostic but not decisive.",
  stage = "mcmc_vb_candidate_full_confirmation",
  priors = "rhs_ns"
)

defaults <- yaml::read_yaml(defaults_out)
defaults$campaign$name <- stage_file
defaults$campaign$results_root <- file.path("results", "qdesn_mcmc_validation", stage_file)
defaults$campaign$reports_root <- file.path("reports", "qdesn_mcmc_validation", stage_file)
defaults$execution$methods <- "mcmc"
defaults$execution$likelihood_families <- as.list(likelihoods)
defaults$study_contract$id <- paste0(stage_file, "_", format(Sys.Date(), "%Y_%m_%d"))
defaults$study_contract$description <- "Full MCMC confirmation of promising Q-DESN RHS VB candidates. VB is used only for candidate generation; article promotion requires MCMC evidence and strict audit."
defaults$study_contract$budget$posterior_metric_draws <- 200L
defaults$study_contract$budget$vb_sampling_nd_draws <- 200L
defaults$study_contract$budget$vb_synthesis_n_samp <- 200L
defaults$study_contract$budget$mcmc_n_burn <- 5000L
defaults$study_contract$budget$mcmc_n_mcmc <- 20000L
defaults$study_contract$budget$mcmc_thin <- 1L
defaults$study_contract$mcmc <- defaults$study_contract$mcmc %||% list()
defaults$study_contract$mcmc$require_init_from_vb <- TRUE
defaults$source_materialization <- defaults$source_materialization %||% list()
defaults$source_materialization$families <- as.list(focus_families)
defaults$source_materialization$taus <- as.list(focus_taus)
defaults$reference_contract$families <- as.list(focus_families)
defaults$reference_contract$taus <- as.list(focus_taus)
defaults$reference_contract$expected_unique_dataset_cells <- length(unique(paste(assignments$family, tau_key(assignments$tau), sep = "\r")))
defaults$reference_contract$expected_qdesn_roots <- nrow(profiles) * defaults$reference_contract$expected_unique_dataset_cells
defaults$reference_contract$expected_selected_qdesn_roots <- length(unique(assignments$assignment_key))
defaults$screening_profiles$canonical_profile_count <- nrow(profiles)
defaults$screening_profiles$canonical_dataset_cell_count <- defaults$reference_contract$expected_unique_dataset_cells
defaults$screening_profiles$canonical_qdesn_root_count <- defaults$reference_contract$expected_qdesn_roots
defaults$screening_profiles$selected_assignment_root_count <- length(unique(assignments$assignment_key))
defaults$screening_profiles$design <- sprintf(
  "Full MCMC VB-candidate confirmation. Candidate assignments: %d; unique profile-likelihood specs: %d; unique roots: %d.",
  nrow(assignments), nrow(profiles), length(unique(assignments$assignment_key))
)
defaults$runtime$threads <- 1L
defaults$runtime$campaign_workers <- workers
defaults$runtime$workers <- workers
defaults$runtime$root_scheduler <- "load_balanced"
defaults$pilot$source_family <- as.character(assignments$family[[1L]])
defaults$pilot$tau <- as.numeric(assignments$tau[[1L]])
defaults$smoke$family <- as.character(assignments$family[[1L]])
defaults$smoke$tau <- as.numeric(assignments$tau[[1L]])
defaults$smoke$fit_sizes <- 500L
defaults$smoke$priors <- as.list("rhs_ns")
defaults$smoke$screening_profile_ids <- as.list(as.character(assignments$screening_profile_id[[1L]]))
defaults$smoke$max_roots <- 1L
defaults$smoke$budget <- list(
  posterior_metric_draws = 4L,
  vb_sampling_nd_draws = 4L,
  vb_synthesis_n_samp = 4L,
  mcmc_n_burn = 4L,
  mcmc_n_mcmc = 4L,
  mcmc_thin = 1L
)
defaults$smoke$pipeline <- list(
  inference = list(
    mcmc = list(n_burn = 4L, n_mcmc = 4L, thin = 1L, progress_every = 1L, init_from_vb = TRUE)
  )
)
defaults$pipeline$inference$mcmc$n_burn <- 5000L
defaults$pipeline$inference$mcmc$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$thin <- 1L
defaults$pipeline$inference$mcmc$progress_every <- 50L
defaults$pipeline$inference$mcmc$init_from_vb <- TRUE
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_burn <- 5000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$n_mcmc <- 20000L
defaults$pipeline$inference$mcmc$prior_overrides$rhs_ns$progress_every <- 50L
defaults$pipeline$inference$mcmc$vb_warm_start_control$progress_every <- 50L
defaults$multiseed <- list(
  enabled = FALSE,
  mcmc_seed_reps = 1L,
  parallel_seed_workers = 1L,
  selection_metric = "mcmc_primary_metric_table",
  prune_nonwinning_heavy_outputs = TRUE
)
defaults$pipeline$outputs$keep_draws <- FALSE
defaults$pipeline$outputs$save_forecast_objects <- FALSE
defaults$pipeline$outputs$save_compact_fit_paths <- TRUE
defaults$pipeline$outputs$retain_full_rds_on_failure <- FALSE
yaml::write_yaml(defaults, defaults_out)

defaults_loaded <- exdqlm:::qdesn_dynamic_crossstudy_load_defaults(defaults_out)
canonical_grid <- exdqlm:::qdesn_dynamic_crossstudy_build_grid(
  defaults_loaded,
  refresh_materialized = refresh_materialized,
  verbose = FALSE
)
canonical_key <- paste(
  canonical_grid$screening_profile_id,
  canonical_grid$source_family,
  tau_key(canonical_grid$tau),
  sep = "\r"
)
assignment_keys <- unique(assignments$assignment_key)
selected_mask <- canonical_key %in% assignment_keys
missing_assignment_keys <- setdiff(assignment_keys, canonical_key)
if (length(missing_assignment_keys)) {
  stop(
    sprintf(
      "Final canonical grid is missing %d selected assignment key(s), including `%s`.",
      length(missing_assignment_keys),
      missing_assignment_keys[[1L]]
    ),
    call. = FALSE
  )
}
grid <- canonical_grid[selected_mask, , drop = FALSE]
grid$key_for_assignment <- canonical_key[selected_mask]
grid <- grid[order(grid$source_family, grid$tau, grid$screening_profile_id), , drop = FALSE]
root_lookup <- grid[, c("key_for_assignment", "root_id"), drop = FALSE]
names(root_lookup)[[1L]] <- "assignment_key"
grid$key_for_assignment <- NULL
write_csv(grid, grid_out)

assignments_after <- merge(
  assignments,
  root_lookup,
  by = "assignment_key",
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(assignments_after$root_id)))) {
  stop("Failed to attach final canonical root IDs to one or more selected assignments.", call. = FALSE)
}
assignments_after <- assignments_after[order(
  assignments_after$family,
  assignments_after$tau,
  assignments_after$likelihood_target,
  assignments_after$target_profile_rank
), , drop = FALSE]
write_csv(assignments_after, assignments_out)

atomic <- exdqlm:::qdesn_dynamic_fitforecast_atomic_spec_grid(
  grid,
  defaults = defaults_loaded,
  methods = defaults_loaded$execution$methods %||% "mcmc",
  likelihood_families = defaults_loaded$execution$likelihood_families %||% likelihoods
)
target_map <- assignments_after[, c("assignment_key", "root_id", "family", "tau", "likelihood_target", "screening_profile_id", "candidate_source", "selection_reason"), drop = FALSE]
target_specs <- merge(
  target_map,
  atomic,
  by.x = c("root_id", "likelihood_target"),
  by.y = c("root_id", "likelihood_family"),
  all.x = TRUE,
  sort = FALSE
)
if (any(!nzchar(as.character(target_specs$spec_id)))) {
  stop("Failed to resolve one or more target MCMC atomic spec IDs.", call. = FALSE)
}
target_specs <- target_specs[order(target_specs$family.x, target_specs$tau.x, target_specs$likelihood_target, target_specs$screening_profile_id.x), , drop = FALSE]
target_specs_out <- write_csv(target_specs, target_specs_out)
defaults$execution$allowed_fit_spec_ids <- as.list(as.character(target_specs$spec_id))
yaml::write_yaml(defaults, defaults_out)

summary_lines <- c(
  "# Q-DESN 500-Observation MCMC VB-Candidate Full Confirmation",
  "",
  sprintf("- generated_at: `%s`", as.character(Sys.time())),
  sprintf("- stage_file: `%s`", stage_file),
  sprintf("- base_defaults_path: `%s`", base_defaults_path),
  sprintf("- workers: `%d`", workers),
  sprintf("- focus_families: `%s`", paste(focus_families, collapse = ", ")),
  sprintf("- focus_taus: `%s`", paste(focus_taus, collapse = ", ")),
  sprintf("- likelihoods: `%s`", paste(likelihoods, collapse = ", ")),
  sprintf("- max_candidates_per_cell_likelihood: `%d`", max_per_cell_lik),
  sprintf("- selected_candidate_assignments: `%d`", nrow(assignments)),
  sprintf("- unique_profile_likelihood_specs: `%d`", nrow(profiles)),
  sprintf("- selected_grid_roots: `%d`", nrow(grid)),
  sprintf("- target_mcmc_atomic_specs: `%d`", nrow(target_specs)),
  "",
  "## Rationale",
  "",
  "VB is used here as a candidate generator, not a scientific gate. The slate keeps qvbm1 mechanism-first winners, older broad-screen all-primary winners, v51 case-targeted specialists, and qvbm3 low-tau/capacity cell winners, then asks the full MCMC implementation to decide.",
  "",
  "## Cell Plan",
  "",
  md_table(cell_plan, c("family", "tau", "likelihood_target", "n_candidates", "target_profiles"), max_rows = 24L),
  "",
  "## Candidate Sources",
  "",
  md_table(as.data.frame(table(candidate_source = assignments$candidate_source), stringsAsFactors = FALSE), c("candidate_source", "Freq")),
  "",
  "## Gates",
  "",
  "- Full MCMC uses `init_from_vb = TRUE`, `n_burn = 5000`, `n_mcmc = 20000`, `thin = 1`, and `progress_every = 50`.",
  "- This stage is not article-facing until it completes, passes strict storage/protocol audit, and is explicitly promoted.",
  "- The target spec list must be passed to the runner; otherwise each root could run both likelihoods and double count compute.",
  "",
  sprintf("- profiles: `%s`", profiles_out),
  sprintf("- assignments: `%s`", assignments_out),
  sprintf("- defaults: `%s`", defaults_out),
  sprintf("- grid: `%s`", grid_out),
  sprintf("- target_specs: `%s`", target_specs_out),
  sprintf("- manifest: `%s`", manifest_out)
)
summary_path <- file.path(diag_summary, "qdesn_tt500_mcmc_vb_candidate_full_confirmation.md")
writeLines(summary_lines, summary_path, useBytes = TRUE)
summary_path <- normalizePath(summary_path, winslash = "/", mustWork = TRUE)

manifest <- list(
  generated_at = as.character(Sys.time()),
  repo_root = repo_root,
  git_sha = trimws(system("git rev-parse HEAD", intern = TRUE)),
  git_branch = trimws(system("git branch --show-current", intern = TRUE)),
  git_dirty = length(system("git status --porcelain", intern = TRUE)) > 0L,
  stage_file = stage_file,
  selection_policy = plan$manifest$selection_policy,
  outputs = list(
    profiles = profiles_out,
    assignments = assignments_out,
    defaults = defaults_out,
    grid = grid_out,
    target_specs = target_specs_out,
    selected_candidates = selected_candidates_path,
    cell_plan = cell_plan_path,
    summary = summary_path,
    diagnostics = diagnostic_out
  ),
  source_files = list(
    historical_selection = historical_csv,
    v51_cell_summary = v51_cell_csv,
    qvbm1_freeze = qvbm1_freeze_csv,
    qvbm3_winners = qvbm3_winners_csv
  ),
  counts = list(
    selected_candidate_assignments = nrow(assignments),
    unique_profile_likelihood_specs = nrow(profiles),
    selected_grid_roots = nrow(grid),
    target_mcmc_atomic_specs = nrow(target_specs),
    cell_likelihoods = nrow(cell_plan)
  ),
  materialized = mat,
  file_manifest = exdqlm:::qdesn_validation_file_manifest(c(
    historical_csv, v51_cell_csv, qvbm1_freeze_csv, qvbm3_winners_csv,
    profiles_out, assignments_out, defaults_out, grid_out, target_specs_out,
    selected_candidates_path, cell_plan_path, summary_path
  ))
)
write_json(manifest, file.path(diag_manifest, "qdesn_tt500_mcmc_vb_candidate_full_confirmation_manifest.json"))
write_json(manifest, manifest_out)

cat(sprintf("profiles: %s\n", profiles_out))
cat(sprintf("assignments: %s\n", assignments_out))
cat(sprintf("defaults: %s\n", defaults_out))
cat(sprintf("grid: %s\n", grid_out))
cat(sprintf("target_specs: %s\n", target_specs_out))
cat(sprintf("manifest: %s\n", manifest_out))
cat(sprintf("summary: %s\n", summary_path))
cat(sprintf("n_assignments: %d\n", nrow(assignments)))
cat(sprintf("n_profiles: %d\n", nrow(profiles)))
cat(sprintf("n_grid_rows: %d\n", nrow(grid)))
cat(sprintf("n_target_specs: %d\n", nrow(target_specs)))
