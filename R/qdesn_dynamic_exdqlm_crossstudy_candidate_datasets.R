qdesn_dynamic_candidate_load_manifest <- function(path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_dataset_manifest.yaml"),
                                                  repo_root = NULL) {
  .qdesn_validation_require_namespace("yaml")
  yaml_path <- .qdesn_validation_resolve_path(path, repo_root = repo_root, must_work = TRUE)
  manifest <- yaml::read_yaml(yaml_path)
  if (!is.list(manifest)) {
    stop("Candidate dataset manifest must decode to a named list.", call. = FALSE)
  }
  manifest
}

.qdesn_dynamic_candidate_helper_env <- local({
  cache <- new.env(parent = emptyenv())
  function(repo_root = NULL, reload = FALSE) {
    root <- .qdesn_validation_repo_root(repo_root)
    helper_path <- file.path(root, "tools", "merge_reports", "20260305_dynamic_dgp_model_helpers.R")
    if (!file.exists(helper_path)) {
      stop(sprintf("Missing dynamic DGP helper script: %s", helper_path), call. = FALSE)
    }
    if (!isTRUE(reload) && identical(cache$root %||% "", root) && is.environment(cache$env)) {
      return(cache$env)
    }
    env <- new.env(parent = asNamespace("exdqlm"))
    sys.source(helper_path, envir = env)
    cache$root <- root
    cache$env <- env
    env
  }
})

.qdesn_dynamic_candidate_resolve_state <- function(manifest,
                                                   repo_root = NULL) {
  gen_cfg <- manifest$generation %||% list()
  scenario_id <- as.character((manifest$meta %||% list())$scenario_id %||% "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")[1L]
  source_parent <- .qdesn_validation_resolve_path(gen_cfg$output_parent, repo_root = repo_root, must_work = FALSE)
  qdesn_parent <- .qdesn_validation_resolve_path((manifest$qdesn_materialization %||% list())$staged_root, repo_root = repo_root, must_work = FALSE)
  list(
    repo_root = .qdesn_validation_repo_root(repo_root),
    scenario_id = scenario_id,
    source_parent = source_parent,
    source_root = file.path(source_parent, scenario_id),
    qdesn_staged_root = qdesn_parent
  )
}

.qdesn_dynamic_candidate_family_cfg <- function(manifest, family) {
  profiles <- (manifest$generation %||% list())$family_profiles %||% list()
  cfg <- profiles[[as.character(family)[1L]]] %||% list()
  if (!length(cfg)) {
    stop(sprintf("Missing family profile for '%s' in candidate dataset manifest.", family), call. = FALSE)
  }
  cfg
}

.qdesn_dynamic_candidate_root_plot <- function(y,
                                               out_path,
                                               title_line1,
                                               title_line2,
                                               bg = "#ffffff",
                                               line_col = "#334155",
                                               accent_col = "#ea580c") {
  x <- seq_along(y)
  tail_start <- max(1L, length(y) - 99L)
  tail_idx <- tail_start:length(y)
  shade_col <- grDevices::adjustcolor(accent_col, alpha.f = 0.12)
  grDevices::png(out_path, width = 2200L, height = 1200L, res = 150L, bg = bg)
  on.exit(grDevices::dev.off(), add = TRUE)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(4.6, 4.8, 4.2, 1.2), oma = c(0.5, 0.5, 4.4, 0.5), xaxs = "r", yaxs = "r")

  graphics::plot(x, y, type = "n", xlab = "time index", ylab = "value", main = "Full series", cex.main = 1.1, font.main = 2)
  usr <- graphics::par("usr")
  graphics::rect(tail_start, usr[3], length(y), usr[4], col = shade_col, border = NA)
  graphics::abline(v = pretty(x, n = 6), h = pretty(y, n = 6), col = grDevices::adjustcolor("#cbd5e1", alpha.f = 0.55), lwd = 0.8)
  graphics::lines(x, y, col = line_col, lwd = 2.4)
  graphics::lines(tail_idx, y[tail_idx], col = accent_col, lwd = 2.8)
  graphics::abline(v = tail_start, col = accent_col, lwd = 1.5, lty = 2)
  graphics::legend("topleft", legend = c("observed", "last 100 obs"), col = c(line_col, accent_col), lwd = c(2.4, 2.8), bty = "n", cex = 0.92)

  graphics::plot(tail_idx, y[tail_idx], type = "o", pch = 16, cex = 0.7,
                 col = line_col, lwd = 2.2, xlab = "time index (last 100)", ylab = "value",
                 main = "Zoom: last 100 points", cex.main = 1.1, font.main = 2)
  graphics::abline(v = pretty(tail_idx, n = 5), h = pretty(y[tail_idx], n = 6), col = grDevices::adjustcolor("#cbd5e1", alpha.f = 0.55), lwd = 0.8)

  graphics::mtext(title_line1, side = 3, outer = TRUE, line = 2.3, cex = 1.25, font = 2, col = "#0f172a")
  graphics::mtext(title_line2, side = 3, outer = TRUE, line = 1.0, cex = 0.9, col = "#475569")
  invisible(out_path)
}

.qdesn_dynamic_candidate_build_meta_lines <- function(scenario_id,
                                                      family,
                                                      tau,
                                                      manifest,
                                                      family_cfg,
                                                      q_shift,
                                                      root_dir) {
  gen_cfg <- manifest$generation %||% list()
  seasonal <- family_cfg$seasonal %||% list()
  h1 <- seasonal$harmonic1 %||% list()
  h2 <- seasonal$harmonic2 %||% list()
  obs <- family_cfg$observation %||% list()
  c(
    "Dynamic family qspec dataset candidate",
    sprintf("scenario_id: %s", scenario_id),
    sprintf("out_root: %s", root_dir),
    sprintf("family: %s", family),
    sprintf("tau: %.2f", as.numeric(tau)),
    sprintf("TT_main: %d", as.integer(gen_cfg$TT_main %||% 7000L)),
    sprintf("TT_warmup: %d", as.integer(gen_cfg$TT_warmup %||% 2000L)),
    sprintf("period: %d", as.integer(gen_cfg$period %||% 90L)),
    sprintf("harmonics: %s", paste(as.integer(unlist(gen_cfg$harmonics %||% c(1L, 2L), use.names = FALSE)), collapse = ", ")),
    sprintf("C0_scale: %.6f", as.numeric(gen_cfg$C0_scale %||% 0.01)),
    sprintf("initial_state_mode: %s", as.character(gen_cfg$initial_state_mode %||% "deterministic_m0")),
    sprintf("level0: %.6f", as.numeric(family_cfg$level0 %||% 0)),
    sprintf("slope0: %.6f", as.numeric(family_cfg$slope0 %||% 0)),
    sprintf("harmonic1_amp_phase: %.6f @ %.6f", as.numeric(h1$amplitude %||% 0), as.numeric(h1$phase %||% 0)),
    sprintf("harmonic2_amp_phase: %.6f @ %.6f", as.numeric(h2$amplitude %||% 0), as.numeric(h2$phase %||% 0)),
    sprintf("state_noise_sd: %s", paste(format(as.numeric(unlist(gen_cfg$state_noise_sd %||% numeric(), use.names = FALSE)), digits = 6, trim = TRUE), collapse = ", ")),
    sprintf("quantile_shift: %.10f", as.numeric(q_shift)),
    sprintf("normal_sigma: %s", as.character(obs$normal_sigma %||% NA)),
    sprintf("laplace_scale: %s", as.character(obs$laplace_scale %||% NA)),
    sprintf("gausmix_sigma: %s", paste(as.numeric(unlist(obs$gausmix_sigma %||% numeric(), use.names = FALSE)), collapse = ", ")),
    sprintf("gausmix_weights: %s", paste(as.numeric(unlist(obs$gausmix_weights %||% numeric(), use.names = FALSE)), collapse = ", ")),
    sprintf("gausmix_offset: %s", as.character(obs$gausmix_offset %||% NA)),
    sprintf("tail fit inputs: %s", paste(file.path(root_dir, sprintf("fit_input_lastTT%d", as.integer(unlist(gen_cfg$tail_fit_sizes %||% c(500L, 5000L), use.names = FALSE)))), collapse = "; "))
  )
}

.qdesn_dynamic_candidate_write_root_bundle <- function(scenario_id,
                                                       family,
                                                       tau,
                                                       tau_label,
                                                       manifest,
                                                       family_cfg,
                                                       mu,
                                                       y,
                                                       eps,
                                                       q_shift,
                                                       helper_env,
                                                       root_dir,
                                                       latent_seed,
                                                       noise_seed) {
  gen_cfg <- manifest$generation %||% list()
  TT_main <- length(y)
  t_idx <- seq_len(TT_main)
  root_png <- file.path(root_dir, sprintf("dynamic_family_%s_tau_%s.png", family, tau_label))
  .qdesn_validation_dir_create(root_dir)

  series_wide <- data.frame(
    t = t_idx,
    y = y,
    mu = mu,
    q_target = mu,
    eps = eps,
    stringsAsFactors = FALSE
  )
  series_long <- data.frame(
    t = t_idx,
    tau = as.numeric(tau),
    y = y,
    q = mu,
    mu = mu,
    eps = eps,
    stringsAsFactors = FALSE
  )
  truth_grid <- data.frame(
    t = t_idx,
    tau = as.numeric(tau),
    q_true = mu,
    stringsAsFactors = FALSE
  )
  sim_obj <- list(
    y = y,
    q = matrix(mu, ncol = 1L),
    p = as.numeric(tau),
    info = list(
      scenario = scenario_id,
      family = family,
      quantile_target = as.numeric(tau),
      quantile_truth_method = "mu_equals_q_true",
      params = list(
        TT = as.integer(TT_main),
        TT_main = as.integer(TT_main),
        TT_warmup = as.integer(gen_cfg$TT_warmup %||% 2000L),
        period = as.integer(gen_cfg$period %||% 90L),
        harmonics = as.integer(unlist(gen_cfg$harmonics %||% c(1L, 2L), use.names = FALSE)),
        C0_scale = as.numeric(gen_cfg$C0_scale %||% 0.01),
        initial_state_mode = as.character(gen_cfg$initial_state_mode %||% "deterministic_m0")
      )
    ),
    extras = list(
      mu = mu,
      eps = eps,
      raw_noise_shift = as.numeric(q_shift),
      source_index = t_idx,
      latent_seed = as.integer(latent_seed),
      noise_seed = as.integer(noise_seed)
    )
  )

  .qdesn_validation_write_df(series_wide, file.path(root_dir, "series_wide.csv"))
  .qdesn_validation_write_df(series_long, file.path(root_dir, "series_long.csv"))
  .qdesn_validation_write_df(truth_grid, file.path(root_dir, "true_quantile_grid.csv"))
  saveRDS(sim_obj, file.path(root_dir, "sim_output.rds"))
  .qdesn_validation_write_lines(file.path(root_dir, "meta.txt"), .qdesn_dynamic_candidate_build_meta_lines(
    scenario_id = scenario_id,
    family = family,
    tau = tau,
    manifest = manifest,
    family_cfg = family_cfg,
    q_shift = q_shift,
    root_dir = root_dir
  ))
  .qdesn_validation_write_lines(file.path(root_dir, "validation.txt"), c(
    "candidate dataset validation",
    sprintf("q_true_equals_mu: %s", if (max(abs(mu - mu)) < 1e-12) "TRUE" else "FALSE"),
    sprintf("n_obs: %d", TT_main),
    sprintf("latent_seed: %d", as.integer(latent_seed)),
    sprintf("noise_seed: %d", as.integer(noise_seed))
  ))
  .qdesn_dynamic_candidate_root_plot(
    y = y,
    out_path = root_png,
    title_line1 = sprintf("%s | %s | tau=%.2f | full root", scenario_id, family, as.numeric(tau)),
    title_line2 = sprintf("n=%d | q_true=mu | quantile shift=%.3f", TT_main, as.numeric(q_shift))
  )

  tail_sizes <- as.integer(unlist(gen_cfg$tail_fit_sizes %||% c(500L, 5000L), use.names = FALSE))
  slice_rows <- vector("list", length(tail_sizes))
  for (ii in seq_along(tail_sizes)) {
    fit_size <- tail_sizes[[ii]]
    idx <- seq.int(TT_main - fit_size + 1L, TT_main)
    slice_dir <- file.path(root_dir, sprintf("fit_input_lastTT%d", fit_size))
    .qdesn_validation_dir_create(slice_dir)
    slice_wide <- series_wide[idx, , drop = FALSE]
    slice_wide$t <- idx
    slice_long <- series_long[idx, , drop = FALSE]
    slice_long$t <- idx
    slice_truth <- truth_grid[idx, , drop = FALSE]
    slice_truth$t <- idx
    selection_df <- data.frame(
      t = seq_len(fit_size),
      source_index = idx,
      stringsAsFactors = FALSE
    )
    slice_sim <- sim_obj
    slice_sim$y <- y[idx]
    slice_sim$q <- matrix(mu[idx], ncol = 1L)
    slice_sim$extras$source_index <- idx
    slice_sim$info$subsample <- list(
      source_n = as.integer(TT_main),
      target_n = as.integer(fit_size),
      selection_method = "last_T",
      source_index_first = idx[1L],
      source_index_last = idx[length(idx)]
    )
    .qdesn_validation_write_df(slice_wide, file.path(slice_dir, "series_wide.csv"))
    .qdesn_validation_write_df(slice_long, file.path(slice_dir, "series_long.csv"))
    .qdesn_validation_write_df(slice_truth, file.path(slice_dir, "true_quantile_grid.csv"))
    .qdesn_validation_write_df(selection_df, file.path(slice_dir, "selection_indices.csv"))
    saveRDS(slice_sim, file.path(slice_dir, "sim_output.rds"))
    slice_rows[[ii]] <- data.frame(
      scenario = scenario_id,
      family = family,
      tau = as.numeric(tau),
      fit_size = fit_size,
      window_label = sprintf("lastTT%d", fit_size),
      root_dir = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
      slice_dir = normalizePath(slice_dir, winslash = "/", mustWork = TRUE),
      series_wide_path = normalizePath(file.path(slice_dir, "series_wide.csv"), winslash = "/", mustWork = TRUE),
      series_long_path = normalizePath(file.path(slice_dir, "series_long.csv"), winslash = "/", mustWork = TRUE),
      true_quantile_grid_path = normalizePath(file.path(slice_dir, "true_quantile_grid.csv"), winslash = "/", mustWork = TRUE),
      selection_indices_path = normalizePath(file.path(slice_dir, "selection_indices.csv"), winslash = "/", mustWork = TRUE),
      sim_output_path = normalizePath(file.path(slice_dir, "sim_output.rds"), winslash = "/", mustWork = TRUE),
      source_index_first = idx[1L],
      source_index_last = idx[length(idx)],
      n_obs = fit_size,
      stringsAsFactors = FALSE
    )
  }

  list(
    root_row = data.frame(
      scenario = scenario_id,
      family = family,
      tau = as.numeric(tau),
      tau_label = tau_label,
      root_dir = normalizePath(root_dir, winslash = "/", mustWork = TRUE),
      series_wide_path = normalizePath(file.path(root_dir, "series_wide.csv"), winslash = "/", mustWork = TRUE),
      series_long_path = normalizePath(file.path(root_dir, "series_long.csv"), winslash = "/", mustWork = TRUE),
      true_quantile_grid_path = normalizePath(file.path(root_dir, "true_quantile_grid.csv"), winslash = "/", mustWork = TRUE),
      sim_output_path = normalizePath(file.path(root_dir, "sim_output.rds"), winslash = "/", mustWork = TRUE),
      plot_path = normalizePath(root_png, winslash = "/", mustWork = TRUE),
      latent_seed = as.integer(latent_seed),
      noise_seed = as.integer(noise_seed),
      quantile_shift = as.numeric(q_shift),
      stringsAsFactors = FALSE
    ),
    slice_rows = .qdesn_validation_bind_rows(slice_rows)
  )
}

qdesn_dynamic_candidate_generate_bundle <- function(manifest,
                                                   repo_root = NULL,
                                                   refresh = FALSE,
                                                   verbose = FALSE) {
  state <- .qdesn_dynamic_candidate_resolve_state(manifest, repo_root = repo_root)
  helper_env <- .qdesn_dynamic_candidate_helper_env(repo_root = state$repo_root)
  gen_cfg <- manifest$generation %||% list()
  meta_cfg <- manifest$meta %||% list()
  families <- as.character(unlist(gen_cfg$families %||% c("normal", "laplace", "gausmix"), use.names = FALSE))
  taus <- as.numeric(unlist(gen_cfg$taus %||% c(0.05, 0.25, 0.50), use.names = FALSE))
  TT_total <- as.integer(gen_cfg$TT_total %||% 9000L)[1L]
  TT_warmup <- as.integer(gen_cfg$TT_warmup %||% 2000L)[1L]
  TT_main <- as.integer(gen_cfg$TT_main %||% (TT_total - TT_warmup))[1L]
  if (!identical(TT_total - TT_warmup, TT_main)) {
    stop("Candidate manifest must satisfy TT_total - TT_warmup == TT_main.", call. = FALSE)
  }
  W_sd <- as.numeric(unlist(gen_cfg$state_noise_sd %||% c(0.005, 0.00002, 0.004, 0.004, 0.003, 0.003), use.names = FALSE))
  if (length(W_sd) != 6L) {
    stop("generation.state_noise_sd must have length 6.", call. = FALSE)
  }
  if (isTRUE(refresh) && dir.exists(state$source_root)) {
    unlink(state$source_root, recursive = TRUE, force = TRUE)
  }
  .qdesn_validation_dir_create(state$source_root)

  root_rows <- list()
  slice_rows <- list()

  for (family in families) {
    family_cfg <- .qdesn_dynamic_candidate_family_cfg(manifest, family)
    seasonal <- family_cfg$seasonal %||% list()
    h1 <- seasonal$harmonic1 %||% list()
    h2 <- seasonal$harmonic2 %||% list()
    obs_cfg <- family_cfg$observation %||% list()
    seed_cfg <- family_cfg$seeds %||% list()

    model <- helper_env$build_dynamic_dgp_matched_model(
      params = list(
        period = as.integer(gen_cfg$period %||% 90L)[1L],
        harmonics = as.integer(unlist(gen_cfg$harmonics %||% c(1L, 2L), use.names = FALSE)),
        m0 = helper_env$dynamic_dgp_make_m0(
          level0 = as.numeric(family_cfg$level0 %||% 0)[1L],
          slope0 = as.numeric(family_cfg$slope0 %||% 0)[1L],
          seasonal_amplitudes = c(as.numeric(h1$amplitude %||% 0)[1L], as.numeric(h2$amplitude %||% 0)[1L]),
          seasonal_phases = c(as.numeric(h1$phase %||% 0)[1L], as.numeric(h2$phase %||% 0)[1L])
        ),
        C0_scale = as.numeric(gen_cfg$C0_scale %||% 0.01)[1L]
      ),
      TT = TT_total,
      backend = "R"
    )
    latent_seed <- as.integer(seed_cfg$latent %||% 1L)[1L]
    noise_seed <- as.integer(seed_cfg$noise %||% (latent_seed + 1L))[1L]
    latent <- helper_env$simulate_dynamic_dgp_latent_path(
      model = model,
      TT = TT_total,
      W_sd = W_sd,
      seed = latent_seed,
      initial_state_mode = as.character(gen_cfg$initial_state_mode %||% "deterministic_m0")[1L]
    )
    mu <- as.numeric(latent$mu[(TT_warmup + 1L):TT_total])
    errors <- helper_env$simulate_dynamic_family_errors(
      family = family,
      n = TT_main,
      taus = taus,
      seed = noise_seed,
      normal_sigma = as.numeric(obs_cfg$normal_sigma %||% 10)[1L],
      laplace_scale = as.numeric(obs_cfg$laplace_scale %||% 10)[1L],
      gausmix_sigma = as.numeric(unlist(obs_cfg$gausmix_sigma %||% c(0.5, 15), use.names = FALSE)),
      gausmix_weights = as.numeric(unlist(obs_cfg$gausmix_weights %||% c(0.1, 0.9), use.names = FALSE)),
      gausmix_offset = as.numeric(obs_cfg$gausmix_offset %||% 1)[1L]
    )
    tau_labels <- stats::setNames(errors$tau_labels, sprintf("%.6f", errors$tau_values))

    for (tau in taus) {
      tau_key <- sprintf("%.6f", as.numeric(tau))
      tau_label <- helper_env$dynamic_dgp_prob_label(tau)
      eps <- as.numeric(errors$centered_eps[[tau_labels[[tau_key]]]])
      q_shift <- as.numeric(errors$quantile_shifts[[tau_labels[[tau_key]]]])
      y <- mu + eps
      root_dir <- file.path(state$source_root, family, sprintf("tau_%s", tau_label))
      bundle <- .qdesn_dynamic_candidate_write_root_bundle(
        scenario_id = state$scenario_id,
        family = family,
        tau = tau,
        tau_label = tau_label,
        manifest = manifest,
        family_cfg = family_cfg,
        mu = mu,
        y = y,
        eps = eps,
        q_shift = q_shift,
        helper_env = helper_env,
        root_dir = root_dir,
        latent_seed = latent_seed,
        noise_seed = noise_seed
      )
      root_rows[[length(root_rows) + 1L]] <- bundle$root_row
      slice_rows[[length(slice_rows) + 1L]] <- bundle$slice_rows
      if (isTRUE(verbose)) {
        message(sprintf("[candidate-dataset] %s / tau=%.2f -> %s", family, tau, root_dir))
      }
    }
  }

  root_inventory <- .qdesn_validation_bind_rows(root_rows)
  slice_inventory <- .qdesn_validation_bind_rows(slice_rows)
  root_inventory <- root_inventory[order(root_inventory$family, root_inventory$tau), , drop = FALSE]
  slice_inventory <- slice_inventory[order(slice_inventory$family, slice_inventory$tau, slice_inventory$fit_size), , drop = FALSE]
  .qdesn_validation_write_df(root_inventory, file.path(state$source_root, "000__full_root_inventory.csv"))
  .qdesn_validation_write_df(slice_inventory, file.path(state$source_root, "000__canonical_slice_inventory.csv"))
  .qdesn_validation_write_json(file.path(state$source_root, "000__bundle_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    scenario_id = state$scenario_id,
    git_sha = .qdesn_validation_git_sha(state$repo_root),
    source_root = state$source_root,
    TT_total = TT_total,
    TT_warmup = TT_warmup,
    TT_main = TT_main,
    families = families,
    taus = taus,
    tail_fit_sizes = sort(unique(as.integer(slice_inventory$fit_size))),
    n_full_roots = nrow(root_inventory),
    n_canonical_slices = nrow(slice_inventory),
    notes = as.character(meta_cfg$notes %||% "")
  ))
  .qdesn_validation_write_lines(file.path(state$source_root, "000__bundle_summary.md"), c(
    "# Dynamic Candidate Dataset Bundle",
    "",
    sprintf("- scenario_id: `%s`", state$scenario_id),
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_root: `%s`", state$source_root),
    sprintf("- full_roots: `%d`", nrow(root_inventory)),
    sprintf("- canonical_tail_slices: `%d`", nrow(slice_inventory)),
    sprintf("- TT_total / TT_warmup / TT_main: `%d / %d / %d`", TT_total, TT_warmup, TT_main),
    "",
    "## Full roots",
    .qdesn_validation_df_to_markdown(root_inventory[, c("family", "tau", "root_dir", "quantile_shift"), drop = FALSE]),
    "",
    "## Canonical slices",
    .qdesn_validation_df_to_markdown(slice_inventory[, c("family", "tau", "fit_size", "slice_dir", "source_index_first", "source_index_last"), drop = FALSE])
  ))

  list(
    state = state,
    root_inventory = root_inventory,
    slice_inventory = slice_inventory
  )
}

qdesn_dynamic_candidate_materialize_qdesn_windows <- function(defaults_path = file.path("config", "validation", "qdesn_dynamic_exdqlm_crossstudy_candidate_materialization_defaults.yaml"),
                                                              repo_root = NULL,
                                                              refresh = TRUE,
                                                              verbose = FALSE) {
  defaults <- qdesn_validation_load_defaults(defaults_path, repo_root = repo_root)
  qdesn_dynamic_crossstudy_materialize_source_inputs(defaults = defaults, refresh = refresh, verbose = verbose)
}
