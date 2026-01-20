#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(name, default = NULL) {
  key <- paste0("--", name)
  for (i in seq_along(args)) {
    if (args[[i]] == key && i < length(args)) return(args[[i + 1]])
    if (startsWith(args[[i]], paste0(key, "="))) {
      return(sub(paste0("^", key, "="), "", args[[i]]))
    }
  }
  default
}

root <- get_arg("root", NULL)
if (is.null(root) || !nzchar(root)) {
  root <- normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
}
root <- normalizePath(root, mustWork = FALSE)

verbose <- isTRUE(get_arg("verbose", "FALSE") == "TRUE")

need_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Missing R package: ", pkg, ". Please install it and re-run.")
  }
}
need_pkg("yaml")
need_pkg("jsonlite")

`%||%` <- function(a, b) if (!is.null(a)) a else b

slides_dir <- file.path(root, "slides")
cfg_runs <- get_arg("runs", file.path(slides_dir, "config", "slide_runs.yaml"))
cfg_content <- get_arg("content", file.path(slides_dir, "config", "slide_content.yaml"))
out_dir <- get_arg("out", file.path(slides_dir, "build"))

if (!file.exists(cfg_runs)) stop("Runs YAML not found: ", cfg_runs)
if (!file.exists(cfg_content)) stop("Content YAML not found: ", cfg_content)

runs_cfg <- yaml::read_yaml(cfg_runs)
content_cfg <- yaml::read_yaml(cfg_content)

if (is.null(runs_cfg$cases) || !length(runs_cfg$cases)) {
  stop("No cases found in runs YAML: ", cfg_runs)
}

plot_canon <- list(
  elbo_traces = list(
    dest = "elbo_traces.png",
    patterns = c("^elbo_traces_skip_k=20\\.png$", "^elbo_traces.*\\.png$")
  ),
  pit_train = list(
    dest = "pit_train.png",
    patterns = c("^pit_train_models\\.png$", "^pit_train_.*\\.png$")
  ),
  pit_forecast = list(
    dest = "pit_forecast.png",
    patterns = c("^pit_forecast_models\\.png$", "^pit_forecast_.*\\.png$")
  ),
  train_mu_p05 = list(
    dest = "train_mu_band_p=0.05.png",
    patterns = c("^train_mu_band_.*p=0.05\\.png$")
  ),
  train_mu_p50 = list(
    dest = "train_mu_band_p=0.5.png",
    patterns = c("^train_mu_band_.*p=0.5\\.png$", "^train_mu_band\\.png$")
  ),
  train_mu_p95 = list(
    dest = "train_mu_band_p=0.95.png",
    patterns = c("^train_mu_band_.*p=0.95\\.png$")
  ),
  forecast_mu_p05 = list(
    dest = "forecast_mu_band_p=0.05.png",
    patterns = c("^forecast_mu_band_.*p=0.05\\.png$")
  ),
  forecast_mu_p50 = list(
    dest = "forecast_mu_band_p=0.5.png",
    patterns = c("^forecast_mu_band_.*p=0.5\\.png$", "^forecast_mu_band\\.png$")
  ),
  forecast_mu_p95 = list(
    dest = "forecast_mu_band_p=0.95.png",
    patterns = c("^forecast_mu_band_.*p=0.95\\.png$")
  ),
  train_obs = list(
    dest = "train_obs_with_95_band.png",
    patterns = c("^train_obs_with_95_band\\.png$")
  ),
  forecast_obs = list(
    dest = "forecast_obs_with_95_band.png",
    patterns = c("^forecast_obs_with_95_band\\.png$")
  ),
  rolling_cov_mu_train = list(
    dest = "rolling_cov_mu_train.png",
    patterns = c("^rolling_cov_mu_train_.*\\.png$")
  ),
  rolling_cov_mu_forecast = list(
    dest = "rolling_cov_mu_forecast.png",
    patterns = c("^rolling_cov_mu_forecast_.*\\.png$")
  ),
  forecast_fan = list(
    dest = "forecast_fan_overlap_synth.png",
    patterns = c("^forecast_fan_overlap_synth\\.png$")
  ),
  forecast_mu_error_p05 = list(
    dest = "forecast_mu_error_band_p=0.05.png",
    patterns = c("^forecast_mu_error_band_.*p=0.05\\.png$")
  ),
  forecast_mu_error_p50 = list(
    dest = "forecast_mu_error_band_p=0.5.png",
    patterns = c("^forecast_mu_error_band_.*p=0.5\\.png$")
  ),
  forecast_mu_error_p95 = list(
    dest = "forecast_mu_error_band_p=0.95.png",
    patterns = c("^forecast_mu_error_band_.*p=0.95\\.png$")
  ),
  gamma_sigma_traces = list(
    dest = "gamma_sigma_traces.png",
    patterns = c("^gamma_sigma_traces_skip_k=20\\.png$", "^gamma_sigma_traces.*\\.png$")
  ),
  posterior_beta_forest_p05 = list(
    dest = "posterior_beta_forest_p=0.05.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_p=0.05\\.png$",
                 "^posterior_beta_forest_TOP50_p=0.05\\.png$")
  ),
  posterior_beta_forest_p50 = list(
    dest = "posterior_beta_forest_p=0.5.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_p=0.5\\.png$",
                 "^posterior_beta_forest_TOP50_p=0.5\\.png$")
  ),
  posterior_beta_forest_p95 = list(
    dest = "posterior_beta_forest_p=0.95.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_p=0.95\\.png$",
                 "^posterior_beta_forest_TOP50_p=0.95\\.png$")
  ),
  posterior_beta_forest_all_p05 = list(
    dest = "posterior_beta_forest_all_p=0.05.png",
    patterns = c("^posterior_beta_forest_ALL_p=0.05\\.png$")
  ),
  posterior_beta_forest_all_p50 = list(
    dest = "posterior_beta_forest_all_p=0.5.png",
    patterns = c("^posterior_beta_forest_ALL_p=0.5\\.png$")
  ),
  posterior_beta_forest_all_p95 = list(
    dest = "posterior_beta_forest_all_p=0.95.png",
    patterns = c("^posterior_beta_forest_ALL_p=0.95\\.png$")
  ),
  posterior_beta_forest_top_mean_p05 = list(
    dest = "posterior_beta_forest_top50_mean_p=0.05.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_MEAN_p=0.05\\.png$",
                 "^posterior_beta_forest_TOP50_MEAN_p=0.05\\.png$")
  ),
  posterior_beta_forest_top_mean_p50 = list(
    dest = "posterior_beta_forest_top50_mean_p=0.5.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_MEAN_p=0.5\\.png$",
                 "^posterior_beta_forest_TOP50_MEAN_p=0.5\\.png$")
  ),
  posterior_beta_forest_top_mean_p95 = list(
    dest = "posterior_beta_forest_top50_mean_p=0.95.png",
    patterns = c("^posterior_beta_forest_IJ_TOP50_MEAN_p=0.95\\.png$",
                 "^posterior_beta_forest_TOP50_MEAN_p=0.95\\.png$")
  ),
  posterior_beta_forest_bottom_mean_p05 = list(
    dest = "posterior_beta_forest_bottom50_mean_p=0.05.png",
    patterns = c("^posterior_beta_forest_IJ_BOTTOM50_MEAN_p=0.05\\.png$",
                 "^posterior_beta_forest_BOTTOM50_MEAN_p=0.05\\.png$")
  ),
  posterior_beta_forest_bottom_mean_p50 = list(
    dest = "posterior_beta_forest_bottom50_mean_p=0.5.png",
    patterns = c("^posterior_beta_forest_IJ_BOTTOM50_MEAN_p=0.5\\.png$",
                 "^posterior_beta_forest_BOTTOM50_MEAN_p=0.5\\.png$")
  ),
  posterior_beta_forest_bottom_mean_p95 = list(
    dest = "posterior_beta_forest_bottom50_mean_p=0.95.png",
    patterns = c("^posterior_beta_forest_IJ_BOTTOM50_MEAN_p=0.95\\.png$",
                 "^posterior_beta_forest_BOTTOM50_MEAN_p=0.95\\.png$")
  ),
  posterior_gamma_sigma_p05 = list(
    dest = "posterior_gamma_sigma_p=0.05.png",
    patterns = c("^posterior_gamma_sigma_p=0.05\\.png$")
  ),
  posterior_gamma_sigma_p50 = list(
    dest = "posterior_gamma_sigma_p=0.5.png",
    patterns = c("^posterior_gamma_sigma_p=0.5\\.png$")
  ),
  posterior_gamma_sigma_p95 = list(
    dest = "posterior_gamma_sigma_p=0.95.png",
    patterns = c("^posterior_gamma_sigma_p=0.95\\.png$")
  ),
  rhs_lambda_traces = list(
    dest = "rhs_lambda_summary_traces.png",
    patterns = c("^rhs_lambda_summary_traces_skip_k=20\\.png$", "^rhs_lambda_summary_traces.*\\.png$")
  ),
  rhs_tau_c2_traces = list(
    dest = "rhs_tau_c2_traces.png",
    patterns = c("^rhs_tau_c2_traces_skip_k=20\\.png$", "^rhs_tau_c2_traces.*\\.png$")
  )
)

tex_escape <- function(x) {
  if (length(x) == 0) return("")
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([%$#&_{}])", "\\\\\\1", x, perl = TRUE)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  x <- gsub("\\^", "\\\\textasciicircum{}", x)
  x
}

value_str <- function(v) {
  if (is.null(v)) return("NA")
  if (is.list(v)) return("list")
  if (length(v) > 1L) return(paste(v, collapse = ","))
  as.character(v)
}

find_first_match <- function(dir_path, patterns) {
  if (!dir.exists(dir_path)) return(NULL)
  files <- list.files(dir_path, all.files = FALSE, full.names = TRUE)
  base <- basename(files)
  for (pat in patterns) {
    idx <- which(grepl(pat, base))
    if (length(idx)) return(files[idx[1]])
  }
  NULL
}

copy_plot <- function(src_dir, dest_dir, dest_name, patterns) {
  src <- find_first_match(src_dir, patterns)
  if (is.null(src) || !file.exists(src)) return(NULL)
  dest <- file.path(dest_dir, dest_name)
  ok <- file.copy(src, dest, overwrite = TRUE)
  if (!isTRUE(ok)) return(NULL)
  dest
}

format_num <- function(x, digits = 3L) {
  if (length(x) == 0 || !is.finite(x)) return("NA")
  sprintf(paste0("%.", digits, "f"), x)
}

read_first_csv <- function(paths) {
  for (p in paths) {
    if (file.exists(p)) {
      df <- try(read.csv(p, stringsAsFactors = FALSE), silent = TRUE)
      if (!inherits(df, "try-error")) return(df)
    }
  }
  NULL
}

write_kv_table <- function(path, kv,
                           colspec = "@{}>{\\raggedright\\arraybackslash}p{0.30\\linewidth}>{\\raggedright\\arraybackslash}p{0.62\\linewidth}@{}",
                           tabcolsep = "3pt",
                           escape_keys = TRUE,
                           escape_values = TRUE) {
  kv <- kv[is.finite(match(names(kv), names(kv)))]
  fmt_key <- function(x) if (escape_keys) tex_escape(x) else x
  fmt_val <- function(x) {
    val <- value_str(x)
    if (escape_values) tex_escape(val) else val
  }
  lines <- c(
    "\\begingroup",
    sprintf("\\setlength{\\tabcolsep}{%s}", tabcolsep),
    sprintf("\\begin{tabular}{%s}", colspec),
    "\\toprule",
    "\\textbf{Key} & \\textbf{Value} \\\\",
    "\\midrule"
  )
  for (nm in names(kv)) {
    lines <- c(lines, sprintf("%s & %s \\\\",
                              fmt_key(nm), fmt_val(kv[[nm]])))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}", "\\endgroup")
  writeLines(lines, path)
}

write_df_table <- function(path, df, max_rows = NULL) {
  if (!is.null(max_rows) && nrow(df) > max_rows) {
    df <- df[seq_len(max_rows), , drop = FALSE]
  }
  if (!nrow(df)) {
    writeLines(c("\\begin{tabular}{@{}l@{}}",
                 "\\toprule", "NA \\\\", "\\bottomrule", "\\end{tabular}"), path)
    return(invisible(NULL))
  }
  colnames(df) <- tex_escape(colnames(df))
  df[] <- lapply(df, function(v) tex_escape(value_str(v)))
  aligns <- paste(rep("l", ncol(df)), collapse = "")
  lines <- c(sprintf("\\begin{tabular}{@{}%s@{}}", aligns),
             "\\toprule",
             paste(colnames(df), collapse = " & "), " \\\\",
             "\\midrule")
  for (i in seq_len(nrow(df))) {
    lines <- c(lines, paste(df[i, ], collapse = " & "), " \\\\")
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular}")
  writeLines(lines, path)
}

case_content <- function(case_id) {
  defaults <- content_cfg$defaults
  case_cfg <- NULL
  if (!is.null(content_cfg$cases)) {
    case_cfg <- content_cfg$cases[[case_id]]
  }
  frames <- defaults$frames %||% character(0)
  if (!is.null(case_cfg$frames)) frames <- case_cfg$frames
  list(frames = frames)
}

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

out_sections <- file.path(out_dir, "sections")
out_figs <- file.path(out_dir, "figs")
out_tables <- file.path(out_dir, "tables")
ensure_dir(out_sections)
ensure_dir(out_figs)
ensure_dir(out_tables)

manifest <- list(root = root, cases = list())

case_sections <- character(0)
global_cfg <- NULL
cross_rows <- list()

for (case in runs_cfg$cases) {
  case_id <- case$id
  case_label <- case$label %||% case$id
  run_dir <- case$run
  case_kind <- case$kind %||% "unknown"
  is_real <- identical(case_kind, "real")

  if (is.null(case_id) || is.null(run_dir)) {
    stop("Case entries must include id and run.")
  }

  if (verbose) message("Case: ", case_id, " -> ", run_dir)

  fig_src <- file.path(run_dir, "figs")
  tab_src <- file.path(run_dir, "tables")
  man_src <- file.path(run_dir, "manifest")

  case_out_fig <- file.path(out_figs, case_id)
  case_out_tab <- file.path(out_tables, case_id)
  ensure_dir(case_out_fig)
  ensure_dir(case_out_tab)

  # --- Run metadata + spec summary ---
  run_manifest <- NULL
  manifest_path <- file.path(man_src, "run_manifest.json")
  if (file.exists(manifest_path)) {
    run_manifest <- jsonlite::fromJSON(manifest_path)
  }

  cfg_path <- file.path(man_src, "cfg_effective.yaml")
  cfg <- if (file.exists(cfg_path)) yaml::read_yaml(cfg_path) else list()
  if (is.null(global_cfg) && length(cfg)) global_cfg <- cfg

  meta_kv <- list(
    "Case" = case_label,
    "Kind" = case_kind,
    "Run path" = run_dir,
    "Started at" = run_manifest$started_at %||% "NA",
    "Dataset" = run_manifest$dataset$slug %||% "NA",
    "Spec" = run_manifest$spec %||% "NA",
    "Git sha" = run_manifest$git$sha %||% "NA"
  )
  desn <- cfg$desn %||% list()
  lags <- cfg$lags %||% list()
  cols <- cfg$columns %||% list()

  spec_kv <- list(
    "$D$ (layers)" = desn$D %||% "NA",
    "$n_d$ (state dims)" = value_str(desn$n %||% "NA"),
    "$\\tilde{n}_d$ (proj dims)" = value_str(desn$n_tilde %||% "NA")
  )
  if (is_real && (length(lags) || length(cols))) {
    spec_kv["$m_y$ (output lags)"] <- lags$m_y %||% "NA"
    spec_kv["$m_x$ (covariate lags)"] <- lags$m_x %||% "NA"
    if (!is.null(cols$x)) spec_kv["$\\vct{z}_t$ (covariates)"] <- value_str(cols$x)
    if (!is.null(cols$y)) spec_kv["$y_t$ (series)"] <- value_str(cols$y)
  } else {
    spec_kv["$m$ (output lags)"] <- desn$m %||% "NA"
  }
  spec_kv["$\\alpha$ (leak rate)"] <- value_str(desn$alpha %||% "NA")
  spec_kv["$\\rho_d$ (spectral radius)"] <- value_str(desn$rho %||% "NA")
  spec_kv["$\\pi_w$ (sparsity)"] <- value_str(desn$pi_w %||% "NA")
  spec_kv["$\\pi_{\\mathrm{in}}$ (input sparsity)"] <- value_str(desn$pi_in %||% "NA")
  spec_kv["washout (steps)"] <- desn$washout %||% "NA"
  spec_kv["VB max iter"] <- cfg$vb$max_iter %||% "NA"
  spec_kv["VB min iter"] <- cfg$vb$min_iter_elbo %||% "NA"
  spec_kv["$H$ (forecast horizon)"] <- cfg$forecast$horizon %||% "NA"
  spec_kv["$N_{\\text{draw}}$ (posterior draws)"] <- cfg$sampling$nd_draws %||% "NA"

  meta_tex <- file.path(case_out_tab, "run_metadata.tex")
  spec_tex <- file.path(case_out_tab, "spec_summary.tex")
  write_kv_table(meta_tex, meta_kv)
  write_kv_table(spec_tex, spec_kv, escape_keys = FALSE)

  content <- case_content(case_id)
  frames <- content$frames %||% character(0)

  plot_paths <- list()
  for (nm in names(plot_canon)) {
    info <- plot_canon[[nm]]
    plot_paths[[nm]] <- copy_plot(fig_src, case_out_fig, info$dest, info$patterns)
  }
  plot_exists <- function(name) {
    file.exists(file.path(case_out_fig, name))
  }
  has_all_plots <- function(names) {
    all(vapply(names, plot_exists, logical(1)))
  }

  score_df <- read_first_csv(c(
    file.path(tab_src, "metrics_summary.csv"),
    file.path(tab_src, "scores_summary.csv")
  ))
  cal_df <- read_first_csv(c(
    file.path(tab_src, "calibration_qsynth_table.csv"),
    file.path(tab_src, "calibration_mu_table.csv"),
    file.path(tab_src, "calibration_qhat_table.csv")
  ))

  crps_val <- pinball_val <- NA_real_
  if (!is.null(score_df) && "split" %in% names(score_df)) {
    fc <- score_df[score_df$split == "forecast", , drop = FALSE]
    if (nrow(fc)) {
      crps_val <- fc$CRPS_mean[1]
      pinball_val <- fc$PinballMean_mean[1]
    }
  }

  get_cov <- function(df, p) {
    if (is.null(df)) return(NA_real_)
    if (!all(c("scope", "p0", "coverage") %in% names(df))) return(NA_real_)
    idx <- which(df$scope == "forecast" & abs(df$p0 - p) < 1e-8)
    if (!length(idx)) return(NA_real_)
    df$coverage[idx[1]]
  }

  cross_rows[[case_id]] <- list(
    label = case_label,
    crps = crps_val,
    pinball = pinball_val,
    cal = c(
      p05 = get_cov(cal_df, 0.05),
      p50 = get_cov(cal_df, 0.5),
      p95 = get_cov(cal_df, 0.95)
    )
  )

  section_label <- case$section_label %||% case_label
  section_subtitle <- case$section_subtitle %||% NULL
  title_prefix <- case$title_prefix %||% case_label
  overview_tex <- case$overview_tex %||% NULL
  overview_plot <- case$overview_plot %||% "train_obs_with_95_band.png"

  section_frame <- if (!is.null(section_subtitle) && nzchar(section_subtitle)) {
    sprintf("\\sectionframe[%s]{%s}", tex_escape(section_subtitle), tex_escape(section_label))
  } else {
    sprintf("\\sectionframe{%s}", tex_escape(section_label))
  }

  lines <- c(
    section_frame,
    sprintf("\\def\\casefigdir{%s}", file.path("build", "figs", case_id)),
    sprintf("\\def\\casetitleprefix{%s}", tex_escape(title_prefix)),
    sprintf("\\def\\caseoverviewplot{%s}", overview_plot),
    sprintf("\\def\\casespecpath{%s}", file.path("build", "tables", case_id, "spec_summary.tex")),
    sprintf("\\def\\caseinfopath{%s}", file.path("build", "tables", case_id, "run_metadata.tex")),
    ""
  )

  metadata_frame <- c(
    sprintf("\\begin{frame}{%s: run metadata}", tex_escape(title_prefix)),
    "  \\begin{columns}[T,onlytextwidth]",
    "    \\column{0.49\\textwidth}",
    "      \\begin{whiteblock}{Run metadata}",
    "      \\small",
    sprintf("      \\input{%s}", file.path("build", "tables", case_id, "run_metadata.tex")),
    "      \\end{whiteblock}",
    "    \\column{0.49\\textwidth}",
    "      \\begin{whiteblock}{Spec summary}",
    "      \\small",
    sprintf("      \\input{%s}", file.path("build", "tables", case_id, "spec_summary.tex")),
    "      \\end{whiteblock}",
    "  \\end{columns}",
    "\\end{frame}",
    ""
  )
  spec_frame <- c(
    sprintf("\\begin{frame}{%s: specification}", tex_escape(title_prefix)),
    "  \\begin{whiteblock}{\\small Specification}",
    "  \\scriptsize",
    sprintf("  \\input{%s}", file.path("build", "tables", case_id, "spec_summary.tex")),
    "  \\end{whiteblock}",
    "\\end{frame}",
    ""
  )

  if ("overview" %in% frames) {
    if (!is.null(overview_tex)) {
      lines <- c(lines, sprintf("\\input{%s}", overview_tex), "")
    } else {
      lines <- c(lines, metadata_frame)
    }
  }

  if ("run_metadata" %in% frames) {
    lines <- c(lines, metadata_frame)
  }

  if ("case_spec" %in% frames) {
    lines <- c(lines, spec_frame)
  }

  if ("train_diagnosis" %in% frames) {
    has_elbo <- plot_exists("elbo_traces.png")
    has_pit_train <- plot_exists("pit_train.png")
    if (has_elbo) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (train): ELBO traces}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/elbo_traces.png}",
        "\\end{frame}",
        ""
      )
    }
    if (has_pit_train) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (train): PIT}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/pit_train.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("train_rolling_cov" %in% frames) {
    if (plot_exists("rolling_cov_mu_train.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (train): rolling coverage}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/rolling_cov_mu_train.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("train_qpanel" %in% frames) {
    if (has_all_plots(c("train_mu_band_p=0.05.png",
                        "train_mu_band_p=0.5.png",
                        "train_mu_band_p=0.95.png"))) {
      lines <- c(lines,
        sprintf("\\qpanel{%s (train)}{\\casefigdir}{train_mu_band}", tex_escape(title_prefix)),
        ""
      )
    }
  }

  if ("train_synthesis" %in% frames) {
    if (plot_exists("train_obs_with_95_band.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (train): synthesis}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/train_obs_with_95_band.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("forecast_diagnosis" %in% frames) {
    if (plot_exists("pit_forecast.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (forecast): diagnosis}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/pit_forecast.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("forecast_rolling_cov" %in% frames) {
    if (plot_exists("rolling_cov_mu_forecast.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (forecast): rolling coverage}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/rolling_cov_mu_forecast.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("forecast_qpanel" %in% frames) {
    if (has_all_plots(c("forecast_mu_band_p=0.05.png",
                        "forecast_mu_band_p=0.5.png",
                        "forecast_mu_band_p=0.95.png"))) {
      lines <- c(lines,
        sprintf("\\qpanel{%s (forecast)}{\\casefigdir}{forecast_mu_band}", tex_escape(title_prefix)),
        ""
      )
    }
  }

  if ("forecast_synthesis" %in% frames) {
    if (plot_exists("forecast_obs_with_95_band.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (forecast): synthesis}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\vspace{-0.25em}",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/forecast_obs_with_95_band.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("forecast_fan" %in% frames) {
    if (plot_exists("forecast_fan_overlap_synth.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (forecast): multi-step fan}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/forecast_fan_overlap_synth.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("appendix_error_bands" %in% frames) {
    if (has_all_plots(c("forecast_mu_error_band_p=0.05.png",
                        "forecast_mu_error_band_p=0.5.png",
                        "forecast_mu_error_band_p=0.95.png"))) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): forecast error bands}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.9\\linewidth,height=0.26\\textheight]{\\casefigdir/forecast_mu_error_band_p=0.5.png}",
        "  \\vspace{0.2em}",
        "  \\begin{columns}[T,onlytextwidth]",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.95\\linewidth,height=0.26\\textheight]{\\casefigdir/forecast_mu_error_band_p=0.05.png}",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.95\\linewidth,height=0.26\\textheight]{\\casefigdir/forecast_mu_error_band_p=0.95.png}",
        "  \\end{columns}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("appendix_gamma_sigma_traces" %in% frames) {
    if (plot_exists("gamma_sigma_traces.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): gamma/sigma traces}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/gamma_sigma_traces.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("appendix_posterior_beta_forest" %in% frames) {
    if (plot_exists("posterior_beta_forest_all_p=0.05.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (all, p=0.05)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_all_p=0.05.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_p=0.05.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (p=0.05)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_p=0.05.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_all_p=0.5.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (all, p=0.5)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_all_p=0.5.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_p=0.5.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (p=0.5)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_p=0.5.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_all_p=0.95.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (all, p=0.95)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_all_p=0.95.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_p=0.95.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (p=0.95)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_p=0.95.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_top50_mean_p=0.05.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (top 50 by mean, p=0.05)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_top50_mean_p=0.05.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_top50_mean_p=0.5.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (top 50 by mean, p=0.5)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_top50_mean_p=0.5.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_top50_mean_p=0.95.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (top 50 by mean, p=0.95)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_top50_mean_p=0.95.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_bottom50_mean_p=0.05.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (bottom 50 by mean, p=0.05)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_bottom50_mean_p=0.05.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_bottom50_mean_p=0.5.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (bottom 50 by mean, p=0.5)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_bottom50_mean_p=0.5.png}",
        "\\end{frame}",
        ""
      )
    }
    if (plot_exists("posterior_beta_forest_bottom50_mean_p=0.95.png")) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior beta (bottom 50 by mean, p=0.95)}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.98\\linewidth,height=0.72\\textheight]{\\casefigdir/posterior_beta_forest_bottom50_mean_p=0.95.png}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("appendix_posterior_gamma_sigma" %in% frames) {
    if (has_all_plots(c("posterior_gamma_sigma_p=0.05.png",
                        "posterior_gamma_sigma_p=0.5.png",
                        "posterior_gamma_sigma_p=0.95.png"))) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): posterior gamma/sigma}", tex_escape(title_prefix)),
        "  \\centering",
        "  \\safeinclude[width=0.9\\linewidth,height=0.26\\textheight]{\\casefigdir/posterior_gamma_sigma_p=0.5.png}",
        "  \\vspace{0.2em}",
        "  \\begin{columns}[T,onlytextwidth]",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.95\\linewidth,height=0.26\\textheight]{\\casefigdir/posterior_gamma_sigma_p=0.05.png}",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.95\\linewidth,height=0.26\\textheight]{\\casefigdir/posterior_gamma_sigma_p=0.95.png}",
        "  \\end{columns}",
        "\\end{frame}",
        ""
      )
    }
  }

  if ("appendix_rhs_traces" %in% frames) {
    if (has_all_plots(c("rhs_lambda_summary_traces.png",
                        "rhs_tau_c2_traces.png"))) {
      lines <- c(lines,
        sprintf("\\begin{frame}{%s (appendix): RHS trace summary}", tex_escape(title_prefix)),
        "  \\begin{columns}[T,onlytextwidth]",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.98\\linewidth,height=0.55\\textheight]{\\casefigdir/rhs_lambda_summary_traces.png}",
        "    \\column{.5\\textwidth}\\centering",
        "      \\safeinclude[width=0.98\\linewidth,height=0.55\\textheight]{\\casefigdir/rhs_tau_c2_traces.png}",
        "  \\end{columns}",
        "\\end{frame}",
        ""
      )
    }
  }

  case_sections <- c(case_sections, lines)
  manifest$cases[[case_id]] <- list(
    id = case_id,
    label = case_label,
    run = run_dir,
    plots = plot_paths
  )
}

if (!is.null(global_cfg) && length(global_cfg)) {
  arch_kv <- list(
    "Quantiles" = value_str(global_cfg$p_vec %||% "NA"),
    "Inputs" = sprintf("D=%s, m=%s",
                       value_str(global_cfg$desn$D %||% "NA"),
                       value_str(global_cfg$desn$m %||% "NA")),
    "Reservoir n" = value_str(global_cfg$desn$n %||% "NA"),
    "n_tilde" = value_str(global_cfg$desn$n_tilde %||% "NA"),
    "alpha" = value_str(global_cfg$desn$alpha %||% "NA"),
    "rho" = value_str(global_cfg$desn$rho %||% "NA"),
    "Activations" = sprintf("f=%s, k=%s",
                            value_str(global_cfg$desn$act_f %||% "NA"),
                            value_str(global_cfg$desn$act_k %||% "NA")),
    "Sparsity" = sprintf("pi_w=%s, pi_in=%s",
                         value_str(global_cfg$desn$pi_w %||% "NA"),
                         value_str(global_cfg$desn$pi_in %||% "NA")),
    "Bias" = value_str(global_cfg$desn$add_bias %||% "NA"),
    "Washout" = value_str(global_cfg$desn$washout %||% "NA"),
    "Seeds" = value_str(global_cfg$desn$seed %||% "NA")
  )
  train_kv <- list(
    "VB max_iter" = value_str(global_cfg$vb$max_iter %||% "NA"),
    "VB min_iter_elbo" = value_str(global_cfg$vb$min_iter_elbo %||% "NA"),
    "VB tol" = value_str(global_cfg$vb$tol %||% "NA"),
    "Posterior draws" = value_str(global_cfg$sampling$nd_draws %||% "NA"),
    "Forecast horizon" = value_str(global_cfg$forecast$horizon %||% "NA"),
    "Synthesis n_samp" = value_str(global_cfg$synthesis$n_samp %||% "NA")
  )

  write_kv_table(file.path(out_tables, "global_arch.tex"), arch_kv)
  write_kv_table(file.path(out_tables, "global_train.tex"), train_kv)
}

if (length(cross_rows)) {
  cross_path <- file.path(out_tables, "cross_scenario.tex")
  lines <- c(
    "\\centering",
    "\\footnotesize",
    "\\begingroup",
    "\\color{black}",
    "\\setlength{\\tabcolsep}{5pt}",
    "\\renewcommand{\\arraystretch}{1.15}",
    "\\begin{tabular*}{0.94\\linewidth}{@{\\extracolsep{\\fill}} l r r c}",
    "\\toprule",
    "Scenario & CRPS\\_mean $\\downarrow$ & PinballMean $\\downarrow$ & Calibration @ $\\{\\textcolor{BrickRed}{.05}, \\textcolor{ForestGreen}{.50}, \\textcolor{NavyBlue}{.95}\\}$ \\\\",
    "\\midrule"
  )
  for (nm in names(cross_rows)) {
    row <- cross_rows[[nm]]
    lbl <- tex_escape(row$label)
    crps <- format_num(row$crps)
    pin <- format_num(row$pinball)
    c05 <- if (is.finite(row$cal["p05"])) sprintf("\\textcolor{BrickRed}{%s}", format_num(row$cal["p05"])) else "NA"
    c50 <- if (is.finite(row$cal["p50"])) sprintf("\\textcolor{ForestGreen}{%s}", format_num(row$cal["p50"])) else "NA"
    c95 <- if (is.finite(row$cal["p95"])) sprintf("\\textcolor{NavyBlue}{%s}", format_num(row$cal["p95"])) else "NA"
    cal <- paste(c05, c50, c95, sep = " / ")
    lines <- c(lines, sprintf("\\texttt{%s} & %s & %s & %s \\\\", lbl, crps, pin, cal))
  }
  lines <- c(lines, "\\bottomrule", "\\end{tabular*}", "\\endgroup")
  writeLines(lines, cross_path)
}

auto_tex <- file.path(out_sections, "auto_runs.tex")
writeLines(case_sections, auto_tex)

manifest_path <- file.path(out_dir, "manifest.json")
jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)

if (verbose) message("Wrote: ", auto_tex)
