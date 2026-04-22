#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  req <- c("pkgload", "yaml", "jsonlite")
  need <- setdiff(req, rownames(installed.packages()))
  if (length(need)) {
    install.packages(need, repos = "https://cloud.r-project.org")
  }
  invisible(lapply(req, require, character.only = TRUE))
})

repo_root <- tryCatch(
  normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), winslash = "/", mustWork = TRUE),
  error = function(...) normalizePath(".", winslash = "/", mustWork = TRUE)
)
setwd(repo_root)
pkgload::load_all(repo_root, quiet = TRUE)
source(file.path(repo_root, "tools", "merge_reports", "20260305_dynamic_dgp_model_helpers.R"), local = TRUE)

resolve_path <- function(path, must_work = TRUE) {
  if (is.null(path) || !length(path)) {
    return(NULL)
  }
  path <- as.character(path)[1L]
  if (!nzchar(path) || is.na(path)) {
    return(NULL)
  }
  if (grepl("^/", path)) {
    return(normalizePath(path, winslash = "/", mustWork = must_work))
  }
  normalizePath(file.path(repo_root, path), winslash = "/", mustWork = must_work)
}

dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

write_json <- function(path, x) {
  dir_create(dirname(path))
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, null = "null")
  invisible(path)
}

write_lines <- function(path, lines) {
  dir_create(dirname(path))
  writeLines(as.character(lines), con = path, useBytes = TRUE)
  invisible(path)
}

write_df <- function(df, path) {
  dir_create(dirname(path))
  if (!ncol(df)) {
    invisible(file.create(path))
    return(invisible(path))
  }
  utils::write.csv(df, path, row.names = FALSE)
  invisible(path)
}

bind_rows <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(data.frame(stringsAsFactors = FALSE))
  }
  cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
  rows2 <- lapply(rows, function(df) {
    miss <- setdiff(cols, names(df))
    for (nm in miss) {
      df[[nm]] <- rep(NA, nrow(df))
    }
    df[, cols, drop = FALSE]
  })
  do.call(rbind, rows2)
}

df_to_markdown <- function(df, digits = 3L) {
  if (is.null(df) || !nrow(df)) {
    return(c("| empty |", "|---|", "| no rows |"))
  }
  fmt_one <- function(x) {
    if (is.numeric(x)) {
      ifelse(is.finite(x), format(round(x, digits), nsmall = 0L, trim = TRUE), "NA")
    } else {
      out <- as.character(x)
      out[is.na(out) | !nzchar(out)] <- "NA"
      out
    }
  }
  df_fmt <- as.data.frame(lapply(df, fmt_one), stringsAsFactors = FALSE)
  header <- paste0("| ", paste(names(df_fmt), collapse = " | "), " |")
  rule <- paste0("|", paste(rep("---", ncol(df_fmt)), collapse = "|"), "|")
  body <- apply(df_fmt, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, rule, body)
}

git_sha <- function(root = repo_root, short = FALSE) {
  args <- c("-C", root, "rev-parse")
  if (isTRUE(short)) {
    args <- c(args, "--short")
  }
  args <- c(args, "HEAD")
  out <- tryCatch(system2("git", args, stdout = TRUE, stderr = FALSE), error = function(...) character(0))
  if (!length(out)) {
    return(NA_character_)
  }
  trimws(out[[1L]])
}

relative_bundle_path <- function(path, root) {
  root <- paste0(normalizePath(root, winslash = "/", mustWork = TRUE), "/")
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  sub(paste0("^", root), "", path)
}

root_plot <- function(y,
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

build_meta_lines <- function(scenario_id,
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

write_root_bundle <- function(scenario_id,
                              family,
                              tau,
                              tau_label,
                              manifest,
                              family_cfg,
                              mu,
                              y,
                              eps,
                              q_shift,
                              root_dir,
                              latent_seed,
                              noise_seed) {
  gen_cfg <- manifest$generation %||% list()
  TT_main <- length(y)
  t_idx <- seq_len(TT_main)
  root_png <- file.path(root_dir, sprintf("dynamic_family_%s_tau_%s.png", family, tau_label))
  dir_create(root_dir)

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

  write_df(series_wide, file.path(root_dir, "series_wide.csv"))
  write_df(series_long, file.path(root_dir, "series_long.csv"))
  write_df(truth_grid, file.path(root_dir, "true_quantile_grid.csv"))
  saveRDS(sim_obj, file.path(root_dir, "sim_output.rds"))
  write_lines(file.path(root_dir, "meta.txt"), build_meta_lines(
    scenario_id = scenario_id,
    family = family,
    tau = tau,
    manifest = manifest,
    family_cfg = family_cfg,
    q_shift = q_shift,
    root_dir = root_dir
  ))
  write_lines(file.path(root_dir, "validation.txt"), c(
    "candidate dataset validation",
    sprintf("q_true_equals_mu: %s", if (max(abs(mu - mu)) < 1e-12) "TRUE" else "FALSE"),
    sprintf("n_obs: %d", TT_main),
    sprintf("latent_seed: %d", as.integer(latent_seed)),
    sprintf("noise_seed: %d", as.integer(noise_seed))
  ))
  root_plot(
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
    dir_create(slice_dir)
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
    write_df(slice_wide, file.path(slice_dir, "series_wide.csv"))
    write_df(slice_long, file.path(slice_dir, "series_long.csv"))
    write_df(slice_truth, file.path(slice_dir, "true_quantile_grid.csv"))
    write_df(selection_df, file.path(slice_dir, "selection_indices.csv"))
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
    slice_rows = bind_rows(slice_rows)
  )
}

generate_bundle <- function(manifest, refresh = TRUE, verbose = TRUE) {
  gen_cfg <- manifest$generation %||% list()
  meta_cfg <- manifest$meta %||% list()
  scenario_id <- as.character(meta_cfg$scenario_id %||% "dlm_constV_p90_m0amp_highnoise_steepertrend_v1")[1L]
  source_root <- file.path(resolve_path(gen_cfg$output_parent, must_work = FALSE), scenario_id)

  families <- as.character(unlist(gen_cfg$families %||% c("normal", "laplace", "gausmix"), use.names = FALSE))
  taus <- as.numeric(unlist(gen_cfg$taus %||% c(0.05, 0.25, 0.50), use.names = FALSE))
  TT_total <- as.integer(gen_cfg$TT_total %||% 9000L)[1L]
  TT_warmup <- as.integer(gen_cfg$TT_warmup %||% 2000L)[1L]
  TT_main <- as.integer(gen_cfg$TT_main %||% (TT_total - TT_warmup))[1L]
  if (!identical(TT_total - TT_warmup, TT_main)) {
    stop("Manifest must satisfy TT_total - TT_warmup == TT_main.", call. = FALSE)
  }
  W_sd <- as.numeric(unlist(gen_cfg$state_noise_sd %||% c(0.005, 0.00002, 0.004, 0.004, 0.003, 0.003), use.names = FALSE))
  if (length(W_sd) != 6L) {
    stop("generation.state_noise_sd must have length 6.", call. = FALSE)
  }
  if (isTRUE(refresh) && dir.exists(source_root)) {
    unlink(source_root, recursive = TRUE, force = TRUE)
  }
  dir_create(source_root)

  root_rows <- list()
  slice_rows <- list()
  profiles <- gen_cfg$family_profiles %||% list()

  for (family in families) {
    family_cfg <- profiles[[family]] %||% list()
    if (!length(family_cfg)) {
      stop(sprintf("Missing family profile for '%s'.", family), call. = FALSE)
    }
    seasonal <- family_cfg$seasonal %||% list()
    h1 <- seasonal$harmonic1 %||% list()
    h2 <- seasonal$harmonic2 %||% list()
    obs_cfg <- family_cfg$observation %||% list()
    seed_cfg <- family_cfg$seeds %||% list()

    model <- build_dynamic_dgp_matched_model(
      params = list(
        period = as.integer(gen_cfg$period %||% 90L)[1L],
        harmonics = as.integer(unlist(gen_cfg$harmonics %||% c(1L, 2L), use.names = FALSE)),
        m0 = dynamic_dgp_make_m0(
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
    latent <- simulate_dynamic_dgp_latent_path(
      model = model,
      TT = TT_total,
      W_sd = W_sd,
      seed = latent_seed,
      initial_state_mode = as.character(gen_cfg$initial_state_mode %||% "deterministic_m0")[1L]
    )
    mu <- as.numeric(latent$mu[(TT_warmup + 1L):TT_total])
    errors <- simulate_dynamic_family_errors(
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
      tau_label <- dynamic_dgp_prob_label(tau)
      eps <- as.numeric(errors$centered_eps[[tau_labels[[tau_key]]]])
      q_shift <- as.numeric(errors$quantile_shifts[[tau_labels[[tau_key]]]])
      y <- mu + eps
      root_dir <- file.path(source_root, family, sprintf("tau_%s", tau_label))
      bundle <- write_root_bundle(
        scenario_id = scenario_id,
        family = family,
        tau = tau,
        tau_label = tau_label,
        manifest = manifest,
        family_cfg = family_cfg,
        mu = mu,
        y = y,
        eps = eps,
        q_shift = q_shift,
        root_dir = root_dir,
        latent_seed = latent_seed,
        noise_seed = noise_seed
      )
      root_rows[[length(root_rows) + 1L]] <- bundle$root_row
      slice_rows[[length(slice_rows) + 1L]] <- bundle$slice_rows
      if (isTRUE(verbose)) {
        message(sprintf("[validation-dataset] %s / tau=%.2f -> %s", family, tau, root_dir))
      }
    }
  }

  root_inventory <- bind_rows(root_rows)
  slice_inventory <- bind_rows(slice_rows)
  root_inventory <- root_inventory[order(root_inventory$family, root_inventory$tau), , drop = FALSE]
  slice_inventory <- slice_inventory[order(slice_inventory$family, slice_inventory$tau, slice_inventory$fit_size), , drop = FALSE]
  write_df(root_inventory, file.path(source_root, "000__full_root_inventory.csv"))
  write_df(slice_inventory, file.path(source_root, "000__canonical_slice_inventory.csv"))
  write_json(file.path(source_root, "000__bundle_manifest.json"), list(
    generated_at = as.character(Sys.time()),
    scenario_id = scenario_id,
    git_sha = git_sha(repo_root),
    source_root = source_root,
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
  write_lines(file.path(source_root, "000__bundle_summary.md"), c(
    "# Dynamic Candidate Dataset Bundle",
    "",
    sprintf("- scenario_id: `%s`", scenario_id),
    sprintf("- generated_at: `%s`", as.character(Sys.time())),
    sprintf("- source_root: `%s`", source_root),
    sprintf("- full_roots: `%d`", nrow(root_inventory)),
    sprintf("- canonical_tail_slices: `%d`", nrow(slice_inventory)),
    sprintf("- TT_total / TT_warmup / TT_main: `%d / %d / %d`", TT_total, TT_warmup, TT_main),
    "",
    "## Full roots",
    df_to_markdown(root_inventory[, c("family", "tau", "root_dir", "quantile_shift"), drop = FALSE]),
    "",
    "## Canonical slices",
    df_to_markdown(slice_inventory[, c("family", "tau", "fit_size", "slice_dir", "source_index_first", "source_index_last"), drop = FALSE])
  ))
  list(
    source_root = source_root,
    root_inventory = root_inventory,
    slice_inventory = slice_inventory,
    TT_total = TT_total,
    TT_warmup = TT_warmup,
    TT_main = TT_main,
    families = families,
    taus = taus
  )
}

build_dataset_registry <- function(manifest, slice_inventory) {
  reg_cfg <- manifest$registry %||% list()
  historical_path <- resolve_path(reg_cfg$historical_dataset_registry, must_work = TRUE)
  output_path <- resolve_path(reg_cfg$output_dataset_registry, must_work = FALSE)
  historical <- utils::read.csv(historical_path, stringsAsFactors = FALSE)

  dynamic_rows <- lapply(seq_len(nrow(slice_inventory)), function(i) {
    row <- slice_inventory[i, , drop = FALSE]
    tau_label <- dynamic_dgp_prob_label(row$tau)
    data.frame(
      dataset_id = sprintf("dynamic::%s::%s::%d", row$family, tau_label, as.integer(row$fit_size)),
      block = "dynamic",
      root_kind = "dynamic",
      family = row$family,
      tau = as.numeric(row$tau),
      tau_label = tau_label,
      fit_size = as.integer(row$fit_size),
      source_root = row$root_dir,
      input_dir = row$slice_dir,
      series_long_path = row$series_long_path,
      series_wide_path = row$series_wide_path,
      selection_indices_path = row$selection_indices_path,
      true_quantile_grid_path = row$true_quantile_grid_path,
      coef_truth_path = NA_character_,
      meta_path = file.path(row$root_dir, "meta.txt"),
      validation_path = file.path(row$root_dir, "validation.txt"),
      missing_inputs = FALSE,
      missing_paths = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  dynamic_registry <- bind_rows(dynamic_rows)
  dynamic_registry <- dynamic_registry[order(dynamic_registry$family, dynamic_registry$tau, dynamic_registry$fit_size), , drop = FALSE]
  static_registry <- historical[historical$block != "dynamic", , drop = FALSE]
  out <- bind_rows(list(dynamic_registry, static_registry))
  write_df(out, output_path)
  list(path = output_path, data = out)
}

parse_keyval_lines <- function(path) {
  lines <- readLines(path, warn = FALSE)
  kv <- strsplit(lines, ": ", fixed = TRUE)
  keys <- vapply(kv, `[`, character(1), 1L)
  vals <- vapply(kv, function(x) if (length(x) >= 2L) paste(x[-1L], collapse = ": ") else NA_character_, character(1))
  stats::setNames(vals, keys)
}

data_equal <- function(a, b) {
  isTRUE(all.equal(a, b, check.attributes = FALSE, tolerance = 0))
}

sim_equal <- function(a, b) {
  isTRUE(all.equal(a, b, check.attributes = FALSE, tolerance = 0))
}

verify_against_qdesn <- function(manifest, bundle) {
  source_cfg <- manifest$source_of_truth %||% list()
  ref_repo <- resolve_path(source_cfg$repo_root, must_work = TRUE)
  ref_root <- resolve_path(file.path(source_cfg$repo_root, source_cfg$canonical_source_root), must_work = TRUE)
  local_root <- bundle$source_root

  ref_root_inventory <- utils::read.csv(file.path(ref_root, "000__full_root_inventory.csv"), stringsAsFactors = FALSE)
  ref_slice_inventory <- utils::read.csv(file.path(ref_root, "000__canonical_slice_inventory.csv"), stringsAsFactors = FALSE)
  local_root_inventory <- bundle$root_inventory
  local_slice_inventory <- bundle$slice_inventory

  rows <- list()

  for (i in seq_len(nrow(local_root_inventory))) {
    loc <- local_root_inventory[i, , drop = FALSE]
    ref <- ref_root_inventory[ref_root_inventory$family == loc$family & abs(ref_root_inventory$tau - loc$tau) < 1e-12, , drop = FALSE]
    stopifnot(nrow(ref) == 1L)
    loc_wide <- utils::read.csv(loc$series_wide_path, stringsAsFactors = FALSE)
    ref_wide <- utils::read.csv(ref$series_wide_path, stringsAsFactors = FALSE)
    loc_long <- utils::read.csv(loc$series_long_path, stringsAsFactors = FALSE)
    ref_long <- utils::read.csv(ref$series_long_path, stringsAsFactors = FALSE)
    loc_truth <- utils::read.csv(loc$true_quantile_grid_path, stringsAsFactors = FALSE)
    ref_truth <- utils::read.csv(ref$true_quantile_grid_path, stringsAsFactors = FALSE)
    loc_sim <- readRDS(loc$sim_output_path)
    ref_sim <- readRDS(ref$sim_output_path)
    loc_meta <- parse_keyval_lines(file.path(loc$root_dir, "meta.txt"))
    ref_meta <- parse_keyval_lines(file.path(ref$root_dir, "meta.txt"))
    keep_meta <- setdiff(intersect(names(loc_meta), names(ref_meta)), c("out_root", "tail fit inputs"))
    loc_val <- readLines(file.path(loc$root_dir, "validation.txt"), warn = FALSE)
    ref_val <- readLines(file.path(ref$root_dir, "validation.txt"), warn = FALSE)

    rows[[length(rows) + 1L]] <- data.frame(
      level = "root",
      family = loc$family,
      tau = as.numeric(loc$tau),
      fit_size = NA_integer_,
      local_rel = relative_bundle_path(loc$root_dir, local_root),
      ref_rel = relative_bundle_path(ref$root_dir, ref_root),
      n_obs_local = nrow(loc_wide),
      n_obs_ref = nrow(ref_wide),
      series_wide_match = data_equal(loc_wide, ref_wide),
      series_long_match = data_equal(loc_long, ref_long),
      truth_match = data_equal(loc_truth, ref_truth),
      sim_match = sim_equal(loc_sim, ref_sim),
      meta_contract_match = identical(loc_meta[keep_meta], ref_meta[keep_meta]),
      validation_contract_match = identical(loc_val, ref_val),
      q_true_equals_mu_local = isTRUE(max(abs(loc_truth$q_true - loc_wide$mu)) < 1e-12),
      source_index_match = NA,
      md5_series_wide_local = unname(tools::md5sum(loc$series_wide_path)),
      md5_series_wide_ref = unname(tools::md5sum(ref$series_wide_path)),
      all_pass = FALSE,
      stringsAsFactors = FALSE
    )
  }

  for (i in seq_len(nrow(local_slice_inventory))) {
    loc <- local_slice_inventory[i, , drop = FALSE]
    ref <- ref_slice_inventory[
      ref_slice_inventory$family == loc$family &
        abs(ref_slice_inventory$tau - loc$tau) < 1e-12 &
        ref_slice_inventory$fit_size == loc$fit_size,
      ,
      drop = FALSE
    ]
    stopifnot(nrow(ref) == 1L)
    loc_wide <- utils::read.csv(loc$series_wide_path, stringsAsFactors = FALSE)
    ref_wide <- utils::read.csv(ref$series_wide_path, stringsAsFactors = FALSE)
    loc_long <- utils::read.csv(loc$series_long_path, stringsAsFactors = FALSE)
    ref_long <- utils::read.csv(ref$series_long_path, stringsAsFactors = FALSE)
    loc_truth <- utils::read.csv(loc$true_quantile_grid_path, stringsAsFactors = FALSE)
    ref_truth <- utils::read.csv(ref$true_quantile_grid_path, stringsAsFactors = FALSE)
    loc_sel <- utils::read.csv(loc$selection_indices_path, stringsAsFactors = FALSE)
    ref_sel <- utils::read.csv(ref$selection_indices_path, stringsAsFactors = FALSE)
    loc_sim <- readRDS(loc$sim_output_path)
    ref_sim <- readRDS(ref$sim_output_path)

    rows[[length(rows) + 1L]] <- data.frame(
      level = "slice",
      family = loc$family,
      tau = as.numeric(loc$tau),
      fit_size = as.integer(loc$fit_size),
      local_rel = relative_bundle_path(loc$slice_dir, local_root),
      ref_rel = relative_bundle_path(ref$slice_dir, ref_root),
      n_obs_local = nrow(loc_wide),
      n_obs_ref = nrow(ref_wide),
      series_wide_match = data_equal(loc_wide, ref_wide),
      series_long_match = data_equal(loc_long, ref_long),
      truth_match = data_equal(loc_truth, ref_truth),
      sim_match = sim_equal(loc_sim, ref_sim),
      meta_contract_match = NA,
      validation_contract_match = NA,
      q_true_equals_mu_local = isTRUE(max(abs(loc_truth$q_true - loc_wide$mu)) < 1e-12),
      source_index_match = data_equal(loc_sel, ref_sel),
      md5_series_wide_local = unname(tools::md5sum(loc$series_wide_path)),
      md5_series_wide_ref = unname(tools::md5sum(ref$series_wide_path)),
      all_pass = FALSE,
      stringsAsFactors = FALSE
    )
  }

  verification <- bind_rows(rows)
  verification$all_pass <- with(
    verification,
    series_wide_match &
      series_long_match &
      truth_match &
      sim_match &
      (is.na(meta_contract_match) | meta_contract_match) &
      (is.na(validation_contract_match) | validation_contract_match) &
      q_true_equals_mu_local &
      (is.na(source_index_match) | source_index_match)
  )

  list(
    verification = verification,
    ref_repo = ref_repo,
    ref_root = ref_root,
    local_root = local_root,
    local_root_inventory = local_root_inventory,
    ref_root_inventory = ref_root_inventory,
    local_slice_inventory = local_slice_inventory,
    ref_slice_inventory = ref_slice_inventory
  )
}

write_selection_manifest <- function(manifest, bundle, registry_path) {
  sel_cfg <- manifest$selection %||% list()
  source_cfg <- manifest$source_of_truth %||% list()
  out_path <- resolve_path(sel_cfg$output_manifest, must_work = FALSE)
  obj <- list(
    meta = list(
      selection_id = "refreshed288_dynamic_exdqlm_crossstudy_active_dataset",
      selected_on = as.character(Sys.Date()),
      selected_scenario_id = as.character((manifest$meta %||% list())$scenario_id)[1L],
      notes = "Local validation-study canonical dynamic dataset synchronized to the promoted Q-DESN canonical source bundle. Q-DESN-only washout windows are intentionally excluded."
    ),
    source_of_truth = list(
      repo_root = source_cfg$repo_root,
      branch = source_cfg$branch,
      commit = source_cfg$commit,
      canonical_source_root = source_cfg$canonical_source_root
    ),
    local_validation_surface = list(
      repo_root = repo_root,
      branch = system2("git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE)[1L],
      commit = git_sha(repo_root),
      canonical_source_root = bundle$source_root,
      dataset_registry = registry_path
    ),
    study_contract = list(
      full_root_count = 9L,
      canonical_window_count = 18L,
      families = as.list(unname(bundle$families)),
      taus = as.list(as.numeric(bundle$taus)),
      canonical_fit_sizes = list(500L, 5000L)
    ),
    relaunch_mapping = list(
      single_prior_fit_count = as.integer(sel_cfg$single_prior_fit_count %||% 72L),
      dual_prior_fit_count = as.integer(sel_cfg$dual_prior_fit_count %||% 144L)
    )
  )
  dir_create(dirname(out_path))
  yaml::write_yaml(obj, out_path)
  out_path
}

write_reports <- function(manifest, bundle, registry, verification_obj, selection_path) {
  report_cfg <- manifest$reports %||% list()
  impl_path <- resolve_path(report_cfg$implementation_report, must_work = FALSE)
  verify_path <- resolve_path(report_cfg$verification_report, must_work = FALSE)
  verify_csv <- resolve_path(report_cfg$verification_csv, must_work = FALSE)
  verification <- verification_obj$verification

  write_df(verification, verify_csv)

  impl_lines <- c(
    "# Refreshed288 Dynamic P90 Steepertrend Dataset Sync Implementation",
    "",
    sprintf("- date: `%s`", as.character(Sys.time())),
    sprintf("- local branch: `%s`", system2("git", c("-C", repo_root, "branch", "--show-current"), stdout = TRUE)[1L]),
    sprintf("- local commit: `%s`", git_sha(repo_root)),
    sprintf("- scenario_id: `%s`", as.character((manifest$meta %||% list())$scenario_id)[1L]),
    sprintf("- local canonical source root: `%s`", bundle$source_root),
    sprintf("- local dataset registry: `%s`", registry$path),
    sprintf("- local active selection manifest: `%s`", selection_path),
    sprintf("- qdesn source branch: `%s`", as.character((manifest$source_of_truth %||% list())$branch)[1L]),
    sprintf("- qdesn source commit: `%s`", as.character((manifest$source_of_truth %||% list())$commit)[1L]),
    sprintf("- qdesn source root: `%s`", verification_obj$ref_root),
    "",
    "## Materialized local surface",
    "",
    sprintf("- full roots: `%d`", nrow(bundle$root_inventory)),
    sprintf("- canonical lastTT windows: `%d`", nrow(bundle$slice_inventory)),
    sprintf("- TT_total / TT_warmup / TT_main: `%d / %d / %d`", bundle$TT_total, bundle$TT_warmup, bundle$TT_main),
    "",
    "## Local canonical roots",
    df_to_markdown(bundle$root_inventory[, c("family", "tau", "root_dir", "quantile_shift"), drop = FALSE]),
    "",
    "## Local canonical slices",
    df_to_markdown(bundle$slice_inventory[, c("family", "tau", "fit_size", "slice_dir", "source_index_first", "source_index_last"), drop = FALSE])
  )
  write_lines(impl_path, impl_lines)

  verify_lines <- c(
    "# Refreshed288 Dynamic P90 Steepertrend Dataset Sync Verification",
    "",
    sprintf("- qdesn source root: `%s`", verification_obj$ref_root),
    sprintf("- local validation root: `%s`", verification_obj$local_root),
    sprintf("- verification rows: `%d`", nrow(verification)),
    sprintf("- all rows pass: `%s`", if (all(verification$all_pass)) "TRUE" else "FALSE"),
    sprintf("- root rows pass: `%d / %d`", sum(verification$level == "root" & verification$all_pass), sum(verification$level == "root")),
    sprintf("- slice rows pass: `%d / %d`", sum(verification$level == "slice" & verification$all_pass), sum(verification$level == "slice")),
    "",
    "## Verification summary by level",
    df_to_markdown(
      data.frame(
        level = c("root", "slice"),
        n_rows = c(sum(verification$level == "root"), sum(verification$level == "slice")),
        n_pass = c(sum(verification$level == "root" & verification$all_pass), sum(verification$level == "slice" & verification$all_pass)),
        stringsAsFactors = FALSE
      )
    ),
    "",
    "## Verification detail",
    df_to_markdown(verification[, c("level", "family", "tau", "fit_size", "n_obs_local", "n_obs_ref", "series_wide_match", "sim_match", "meta_contract_match", "validation_contract_match", "source_index_match", "q_true_equals_mu_local", "all_pass"), drop = FALSE])
  )
  write_lines(verify_path, verify_lines)

  list(implementation_report = impl_path, verification_report = verify_path, verification_csv = verify_csv)
}

manifest_path <- file.path("config", "validation", "refreshed288_dynamic_exdqlm_crossstudy_canonical_dataset_manifest.yaml")
manifest <- yaml::read_yaml(resolve_path(manifest_path, must_work = TRUE))
bundle <- generate_bundle(manifest = manifest, refresh = TRUE, verbose = TRUE)
registry <- build_dataset_registry(manifest, bundle$slice_inventory)
selection_path <- write_selection_manifest(manifest, bundle, registry$path)
verification_obj <- verify_against_qdesn(manifest, bundle)
report_paths <- write_reports(manifest, bundle, registry, verification_obj, selection_path)

write_json(file.path(bundle$source_root, "000__validation_sync_manifest.json"), list(
  generated_at = as.character(Sys.time()),
  local_repo_root = repo_root,
  local_git_sha = git_sha(repo_root),
  source_of_truth = manifest$source_of_truth,
  scenario_id = as.character((manifest$meta %||% list())$scenario_id)[1L],
  local_source_root = bundle$source_root,
  local_dataset_registry = registry$path,
  local_selection_manifest = selection_path,
  verification_report = report_paths$verification_report,
  verification_csv = report_paths$verification_csv,
  n_full_roots = nrow(bundle$root_inventory),
  n_canonical_slices = nrow(bundle$slice_inventory),
  all_verification_rows_pass = all(verification_obj$verification$all_pass)
))

cat(sprintf("Validation canonical dynamic bundle ready: %s\n", bundle$source_root))
cat(sprintf("Validation dataset registry ready: %s\n", registry$path))
cat(sprintf("Verification report ready: %s\n", report_paths$verification_report))
