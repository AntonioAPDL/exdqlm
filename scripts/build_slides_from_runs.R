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
    patterns = c("^elbo_traces.*\\.png$")
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
  rolling_cov_train = list(
    dest = "rolling_cov_qsynth_train.png",
    patterns = c("^rolling_cov_qsynth_train_.*\\.png$",
                 "^rolling_cov_qhat_train_.*\\.png$",
                 "^rolling_cov_mu_train_.*\\.png$")
  ),
  rolling_cov_forecast = list(
    dest = "rolling_cov_qsynth_forecast.png",
    patterns = c("^rolling_cov_qsynth_forecast_.*\\.png$",
                 "^rolling_cov_qhat_forecast_.*\\.png$",
                 "^rolling_cov_mu_forecast_.*\\.png$")
  ),
  forecast_quantiles_overlay = list(
    dest = "forecast_quantiles_overlay.png",
    patterns = c("^forecast_quantiles_overlay\\.png$")
  ),
  train_quantiles_overlay = list(
    dest = "train_quantiles_overlay.png",
    patterns = c("^train_quantiles_overlay\\.png$")
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

write_kv_table <- function(path, kv) {
  kv <- kv[is.finite(match(names(kv), names(kv)))]
  lines <- c(
    "\\begingroup",
    "\\setlength{\\tabcolsep}{4pt}",
    "\\begin{tabular}{@{}p{0.34\\linewidth}p{0.60\\linewidth}@{}}",
    "\\toprule",
    "\\textbf{Key} & \\textbf{Value} \\\\",
    "\\midrule"
  )
  for (nm in names(kv)) {
    lines <- c(lines, sprintf("%s & %s \\\\",
                              tex_escape(nm), tex_escape(value_str(kv[[nm]]))))
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
  spec_kv <- list(
    "D" = cfg$desn$D %||% "NA",
    "n" = value_str(cfg$desn$n %||% "NA"),
    "n_tilde" = value_str(cfg$desn$n_tilde %||% "NA"),
    "m" = cfg$desn$m %||% "NA",
    "alpha" = value_str(cfg$desn$alpha %||% "NA"),
    "rho" = value_str(cfg$desn$rho %||% "NA"),
    "washout" = cfg$desn$washout %||% "NA",
    "vb max_iter" = cfg$vb$max_iter %||% "NA",
    "vb min_iter_elbo" = cfg$vb$min_iter_elbo %||% "NA",
    "horizon" = cfg$forecast$horizon %||% "NA",
    "nd_draws" = cfg$sampling$nd_draws %||% "NA"
  )

  meta_tex <- file.path(case_out_tab, "run_metadata.tex")
  spec_tex <- file.path(case_out_tab, "spec_summary.tex")
  write_kv_table(meta_tex, meta_kv)
  write_kv_table(spec_tex, spec_kv)

  content <- case_content(case_id)
  frames <- content$frames %||% character(0)

  plot_paths <- list()
  for (nm in names(plot_canon)) {
    info <- plot_canon[[nm]]
    plot_paths[[nm]] <- copy_plot(fig_src, case_out_fig, info$dest, info$patterns)
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
  title_prefix <- case$title_prefix %||% case_label
  overview_tex <- case$overview_tex %||% NULL
  overview_plot <- case$overview_plot %||% "train_obs_with_95_band.png"

  lines <- c(
    sprintf("\\sectionframe{%s}", tex_escape(section_label)),
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

  if ("train_diagnosis" %in% frames) {
    lines <- c(lines,
      sprintf("\\begin{frame}{%s (train): diagnosis}", tex_escape(title_prefix)),
      "  \\centering",
      "  \\safeinclude[0.8\\textheight]{\\casefigdir/elbo_traces.png}\\\\[0.5em]",
      "  \\safeinclude[0.8\\textheight]{\\casefigdir/pit_train.png}",
      "\\end{frame}",
      ""
    )
  }

  if ("train_qpanel" %in% frames) {
    lines <- c(lines,
      sprintf("\\qpanel{%s (train)}{\\casefigdir}{train_mu_band}", tex_escape(title_prefix)),
      ""
    )
  }

  if ("train_synthesis" %in% frames) {
    lines <- c(lines,
      sprintf("\\begin{frame}{%s (train): synthesis}", tex_escape(title_prefix)),
      "  \\begin{columns}[T,onlytextwidth]",
      "    \\column{.55\\textwidth}\\safeinclude[.98\\linewidth]{\\casefigdir/train_obs_with_95_band.png}",
      "    \\column{.45\\textwidth}\\safeinclude[.98\\linewidth]{\\casefigdir/rolling_cov_qsynth_train.png}",
      "  \\end{columns}",
      "\\end{frame}",
      ""
    )
  }

  if ("forecast_diagnosis" %in% frames) {
    lines <- c(lines,
      sprintf("\\begin{frame}{%s (forecast): diagnosis}", tex_escape(title_prefix)),
      "  \\centering",
      "  \\safeinclude[1.0\\textheight]{\\casefigdir/pit_forecast.png}",
      "\\end{frame}",
      ""
    )
  }

  if ("forecast_qpanel" %in% frames) {
    lines <- c(lines,
      sprintf("\\qpanel{%s (forecast)}{\\casefigdir}{forecast_mu_band}", tex_escape(title_prefix)),
      ""
    )
  }

  if ("forecast_synthesis" %in% frames) {
    lines <- c(lines,
      sprintf("\\begin{frame}{%s (forecast): synthesis}", tex_escape(title_prefix)),
      "  \\centering",
      "  \\vspace{-0.25em}",
      "  \\safeinclude[0.98\\linewidth]{\\casefigdir/forecast_obs_with_95_band.png}",
      "\\end{frame}",
      ""
    )
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
