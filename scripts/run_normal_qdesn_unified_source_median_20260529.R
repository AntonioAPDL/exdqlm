#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit)) return(default)
  if (hit[[1L]] >= length(args)) stop(sprintf("Missing value for %s.", flag), call. = FALSE)
  args[[hit[[1L]] + 1L]]
}

arg_flag <- function(flag) any(args == flag)

arg_int <- function(flag, default) {
  value <- suppressWarnings(as.integer(arg_value(flag, as.character(default))))
  if (!length(value) || !is.finite(value)) stop(sprintf("%s must be a finite integer.", flag), call. = FALSE)
  value
}

repo_root <- normalizePath(arg_value("--repo", getwd()), mustWork = TRUE)
output_dir <- arg_value(
  "--output-dir",
  file.path(repo_root, "results", "normal_qdesn_unified_source_median_20260529")
)
source_dir <- normalizePath(
  arg_value(
    "--source-dir",
    "/data/jaguir26/local/src/shared_dynamic_fit_forecast_validation/sources/dlm_constV_p90_m0amp_highnoise_steepertrend_v2_TTmain10000_fitforecast/normal/tau_0p50/fit_input_lastTT500"
  ),
  mustWork = TRUE
)
seed <- arg_int("--seed", 20260529L)
D <- arg_int("--D", 1L)
n_res <- arg_int("--n", 50L)
m_lag <- arg_int("--m", 1L)
washout <- arg_int("--washout", 50L)
chunk_size <- arg_int("--chunk-size", 64L)
subset_size <- arg_int("--subset-size", 180L)
max_iter <- arg_int("--max-iter", 25L)
stochastic_max_iter <- arg_int("--stochastic-max-iter", 60L)
hybrid_max_iter <- arg_int("--hybrid-max-iter", stochastic_max_iter)
hybrid_full_every <- arg_int("--hybrid-full-every", 15L)
cores <- arg_int("--cores", 1L)
tail_rows <- arg_value("--tail-rows", NULL)
expected_effective_rows <- arg_value("--expected-effective-rows", NULL)
skip_workflows <- arg_flag("--skip-workflows")
run_mcmc <- arg_flag("--run-mcmc")

if (D != 1L) stop("The unified comparison currently supports D = 1 only.", call. = FALSE)
if (n_res < 1L || m_lag < 0L || washout < 0L || chunk_size < 1L || subset_size < 1L) {
  stop("D/n/m/washout/chunk/subset controls are outside the supported range.", call. = FALSE)
}
if (max_iter < 1L || stochastic_max_iter < 1L || hybrid_max_iter < 1L || hybrid_full_every < 1L) {
  stop("Iteration controls must be positive.", call. = FALSE)
}
if (cores < 1L) stop("--cores must be positive.", call. = FALSE)

Sys.setenv(
  OMP_NUM_THREADS = "1",
  OPENBLAS_NUM_THREADS = "1",
  MKL_NUM_THREADS = "1",
  VECLIB_MAXIMUM_THREADS = "1",
  NUMEXPR_NUM_THREADS = "1"
)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
setwd(repo_root)

`%||%` <- function(a, b) if (is.null(a)) b else a

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, quote = TRUE)
  invisible(path)
}

rbind_fill <- function(dfs) {
  dfs <- Filter(function(x) !is.null(x) && nrow(x), dfs)
  if (!length(dfs)) return(data.frame())
  cols <- unique(unlist(lapply(dfs, names), use.names = FALSE))
  dfs <- lapply(dfs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[cols]
  })
  do.call(rbind, dfs)
}

read_optional <- function(path) {
  if (!file.exists(path)) return(data.frame())
  utils::read.csv(path, check.names = FALSE)
}

git_value <- function(cmd) {
  out <- tryCatch(system2("git", cmd, stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  if (!length(out)) return(NA_character_)
  out[[1L]]
}

git_dirty <- function() {
  out <- tryCatch(system2("git", c("status", "--porcelain"), stdout = TRUE, stderr = TRUE), error = function(e) NA_character_)
  length(out) > 0L && any(nzchar(out))
}

md_table <- function(df, con) {
  if (!nrow(df)) {
    writeLines("_None._", con)
    return(invisible(NULL))
  }
  df[] <- lapply(df, function(x) {
    if (is.numeric(x)) {
      ifelse(is.na(x), "", format(x, digits = 6, scientific = TRUE))
    } else {
      x <- as.character(x)
      x[is.na(x)] <- ""
      gsub("\\|", "\\\\|", x)
    }
  })
  writeLines(paste0("| ", paste(names(df), collapse = " | "), " |"), con)
  writeLines(paste0("| ", paste(rep("---", ncol(df)), collapse = " | "), " |"), con)
  for (i in seq_len(nrow(df))) {
    writeLines(paste0("| ", paste(as.character(df[i, ]), collapse = " | "), " |"), con)
  }
  invisible(NULL)
}

script_path <- function(name) file.path(repo_root, "scripts", name)

run_component <- function(component, script, arguments) {
  log_path <- file.path(output_dir, sprintf("%s.console.log", component))
  cmd <- c(script, arguments)
  started <- Sys.time()
  out <- system2(file.path(R.home("bin"), "Rscript"), cmd, stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status") %||% 0L
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  writeLines(c(
    sprintf("component: %s", component),
    sprintf("script: %s", script),
    sprintf("status: %s", status),
    sprintf("elapsed_sec: %.3f", elapsed),
    "",
    out
  ), log_path)
  if (!identical(as.integer(status), 0L)) {
    stop(sprintf("Component %s failed. See %s", component, log_path), call. = FALSE)
  }
  data.frame(
    component = component,
    script = basename(script),
    status = as.integer(status),
    elapsed_sec = elapsed,
    log_path = log_path,
    stringsAsFactors = FALSE
  )
}

normal_source_dir <- file.path(output_dir, "normal_source")
normal_init_dir <- file.path(output_dir, "normal_init")
qdesn_dir <- file.path(output_dir, "qdesn_implemented_modes")
dir.create(normal_source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(normal_init_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qdesn_dir, recursive = TRUE, showWarnings = FALSE)

common_args <- c(
  "--repo", repo_root,
  "--source-dir", source_dir,
  "--seed", as.character(seed),
  "--D", as.character(D),
  "--n", as.character(n_res),
  "--m", as.character(m_lag),
  "--washout", as.character(washout),
  "--max-iter", as.character(max_iter)
)

component_runs <- list()
component_runs[[length(component_runs) + 1L]] <- run_component(
  "normal_source",
  script_path("run_normal_desn_source_median_comparison_20260529.R"),
  c(common_args, "--output-dir", normal_source_dir, "--chunk-size", as.character(chunk_size))
)
component_runs[[length(component_runs) + 1L]] <- run_component(
  "normal_init",
  script_path("run_normal_desn_init_comparison_20260529.R"),
  c(common_args, "--output-dir", normal_init_dir, if (run_mcmc) "--run-mcmc" else character())
)

qdesn_args <- c(
  "--source-dir", source_dir,
  "--output-dir", qdesn_dir,
  "--seed", as.character(seed),
  "--D", as.character(D),
  "--n", as.character(n_res),
  "--m", as.character(m_lag),
  "--washout", as.character(washout),
  "--chunk-size", as.character(chunk_size),
  "--subset-size", as.character(subset_size),
  "--max-iter", as.character(max_iter),
  "--stochastic-max-iter", as.character(stochastic_max_iter),
  "--hybrid-max-iter", as.character(hybrid_max_iter),
  "--hybrid-full-every", as.character(hybrid_full_every),
  "--cores", as.character(cores)
)
if (!is.null(tail_rows)) qdesn_args <- c(qdesn_args, "--tail-rows", tail_rows)
if (!is.null(expected_effective_rows)) {
  qdesn_args <- c(qdesn_args, "--expected-effective-rows", expected_effective_rows)
}
if (skip_workflows) qdesn_args <- c(qdesn_args, "--skip-workflows")
component_runs[[length(component_runs) + 1L]] <- run_component(
  "qdesn_implemented_modes",
  script_path("run_qdesn_vb_implemented_modes_source_median_20260528.R"),
  qdesn_args
)
component_runs <- do.call(rbind, component_runs)

normal_methods <- read_optional(file.path(normal_source_dir, "method_summary.csv"))
if (nrow(normal_methods)) {
  normal_methods$component <- "normal_source"
  normal_methods$method_id <- normal_methods$method
}
normal_init <- read_optional(file.path(normal_init_dir, "init_method_summary.csv"))
if (nrow(normal_init)) {
  normal_init$component <- "normal_init"
  normal_init$method_id <- normal_init$method
  normal_init$target_label <- "initializer_workflow"
  normal_init$target_changes <- FALSE
  normal_init$approximate <- FALSE
}
qdesn_methods <- read_optional(file.path(qdesn_dir, "method_summary.csv"))
if (nrow(qdesn_methods)) qdesn_methods$component <- "qdesn_implemented_modes"

method_summary <- rbind_fill(list(normal_methods, normal_init, qdesn_methods))
prediction_metrics <- rbind_fill(list(
  transform(read_optional(file.path(normal_source_dir, "method_summary.csv")), component = "normal_source"),
  transform(read_optional(file.path(normal_init_dir, "init_method_summary.csv")), component = "normal_init"),
  transform(read_optional(file.path(qdesn_dir, "prediction_metrics.csv")), component = "qdesn_implemented_modes")
))
exact_equivalence <- rbind_fill(list(
  transform(read_optional(file.path(normal_source_dir, "exact_equivalence.csv")), component = "normal_source"),
  transform(read_optional(file.path(qdesn_dir, "exact_equivalence.csv")), component = "qdesn_implemented_modes")
))
approximate_diagnostics <- rbind_fill(list(
  transform(read_optional(file.path(qdesn_dir, "approximate_diagnostics.csv")), component = "qdesn_implemented_modes")
))
target_changing_diagnostics <- rbind_fill(list(
  transform(read_optional(file.path(qdesn_dir, "target_changing_diagnostics.csv")), component = "qdesn_implemented_modes")
))
initializer_diagnostics <- rbind_fill(list(
  transform(read_optional(file.path(normal_init_dir, "init_method_summary.csv")), component = "normal_init"),
  transform(read_optional(file.path(normal_init_dir, "warm_start_summary.csv")), component = "normal_init_warm_start")
))
forbidden_modes <- rbind_fill(list(
  transform(read_optional(file.path(qdesn_dir, "forbidden_modes.csv")), component = "qdesn_implemented_modes")
))
predictions <- rbind_fill(list(
  transform(read_optional(file.path(normal_source_dir, "predictions_by_method.csv")), component = "normal_source"),
  transform(read_optional(file.path(qdesn_dir, "predictions_by_method.csv")), component = "qdesn_implemented_modes")
))

repo_state <- data.frame(
  repo = repo_root,
  branch = git_value(c("branch", "--show-current")),
  head = git_value(c("rev-parse", "--short", "HEAD")),
  dirty = git_dirty(),
  source_dir = source_dir,
  seed = seed,
  D = D,
  n = n_res,
  m = m_lag,
  washout = washout,
  chunk_size = chunk_size,
  subset_size = subset_size,
  max_iter = max_iter,
  stochastic_max_iter = stochastic_max_iter,
  hybrid_max_iter = hybrid_max_iter,
  hybrid_full_every = hybrid_full_every,
  cores = cores,
  skip_workflows = skip_workflows,
  run_mcmc = run_mcmc,
  output_dir = output_dir,
  stringsAsFactors = FALSE
)

write_csv(repo_state, file.path(output_dir, "repo_state.csv"))
write_csv(component_runs, file.path(output_dir, "component_runs.csv"))
write_csv(method_summary, file.path(output_dir, "method_summary.csv"))
write_csv(prediction_metrics, file.path(output_dir, "prediction_metrics.csv"))
write_csv(exact_equivalence, file.path(output_dir, "exact_equivalence.csv"))
write_csv(approximate_diagnostics, file.path(output_dir, "approximate_diagnostics.csv"))
write_csv(target_changing_diagnostics, file.path(output_dir, "target_changing_diagnostics.csv"))
write_csv(initializer_diagnostics, file.path(output_dir, "initializer_diagnostics.csv"))
write_csv(forbidden_modes, file.path(output_dir, "forbidden_modes.csv"))
write_csv(predictions, file.path(output_dir, "predictions_by_method.csv"))

finite_columns <- intersect(c("finite_state", "finite"), names(method_summary))
if (length(finite_columns)) {
  finite_ok <- all(vapply(finite_columns, function(nm) all(as.logical(method_summary[[nm]]) | is.na(method_summary[[nm]])), logical(1)))
} else {
  finite_ok <- TRUE
}
exact_ok <- !nrow(exact_equivalence) || all(as.logical(exact_equivalence$passed))
if (!finite_ok) stop("At least one unified method row has a non-finite state.", call. = FALSE)
if (!exact_ok) stop("At least one unified exact-equivalence gate failed.", call. = FALSE)

summary_path <- file.path(output_dir, "normal_qdesn_unified_comparison_summary.md")
con <- file(summary_path, open = "wt")
on.exit(close(con), add = TRUE)
writeLines("# Normal/Q-DESN Unified Source-Median Comparison", con)
writeLines("", con)
writeLines(sprintf("- Package HEAD: `%s`", repo_state$head[[1L]]), con)
writeLines(sprintf("- Package dirty at run time: `%s`", repo_state$dirty[[1L]]), con)
writeLines(sprintf("- Source: `%s`", source_dir), con)
writeLines(sprintf("- DESN settings: D=%d, n=%d, m=%d, washout=%d", D, n_res, m_lag, washout), con)
writeLines(sprintf("- Seed: `%d`", seed), con)
writeLines("", con)
writeLines("## Component Runs", con)
md_table(component_runs, con)
writeLines("", con)
writeLines("## Method Summary", con)
display_cols <- intersect(
  c(
    "component", "method_id", "method", "likelihood_family", "prior_family",
    "target_label", "exact_status", "covariance_form", "chunking_mode",
    "preserves_full_data_target", "approximate", "target_changes",
    "converged", "finite_state", "elapsed_sec", "pinball_tau_0p50", "pinball_y", "rmse_q_target"
  ),
  names(method_summary)
)
md_table(method_summary[, display_cols, drop = FALSE], con)
writeLines("", con)
writeLines("## Exact Equivalence", con)
md_table(exact_equivalence, con)
writeLines("", con)
writeLines("## Approximate Diagnostics", con)
md_table(approximate_diagnostics, con)
writeLines("", con)
writeLines("## Target-Changing Diagnostics", con)
md_table(target_changing_diagnostics, con)
writeLines("", con)
writeLines("## Initializer Diagnostics", con)
init_cols <- intersect(
  c("component", "method", "method_id", "init_source", "warm_start_id", "normal_target", "exact_status", "prior_family", "finite_state", "elapsed_sec"),
  names(initializer_diagnostics)
)
md_table(initializer_diagnostics[, init_cols, drop = FALSE], con)
writeLines("", con)
writeLines("## Forbidden Modes", con)
md_table(forbidden_modes, con)
writeLines("", con)
writeLines("## Interpretation", con)
writeLines("Normal DESN rows are conditional-mean Gaussian readouts. Q-DESN rows are tau-specific AL/exAL quantile readouts.", con)
writeLines("Exact chunked rows are compared only to their same-target unchunked references. Approximate, covariance-approximation, subset, rolling, posterior-as-prior, online, and initialization rows are diagnostic/workflow rows, not exact full-data replacements.", con)

cat("Wrote unified outputs to", output_dir, "\n")
cat("Summary:", summary_path, "\n")
