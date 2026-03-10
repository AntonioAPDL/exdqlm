# Internal helpers for the benchmark ingestion + analysis workflow.

bench_required_packages <- function(stage = c("all", "download", "build", "analysis")) {
  stage <- match.arg(stage)

  common <- c("yaml", "jsonlite", "digest", "pkgload")
  stage_pkgs <- switch(
    stage,
    all = c(
      common,
      "data.table",
      "ggplot2",
      "scales",
      "forecast"
    ),
    download = c(common, "data.table"),
    build = c(common, "data.table"),
    analysis = c(common, "data.table", "ggplot2", "scales")
  )

  unname(unique(stage_pkgs))
}

bench_assert_packages <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (!length(missing)) {
    return(invisible(TRUE))
  }

  stop(
    sprintf(
      "Missing required packages: %s. Run the benchmark entry script to auto-install them.",
      paste(missing, collapse = ", ")
    ),
    call. = FALSE
  )
}

bench_attach_packages <- function(pkgs) {
  for (pkg in pkgs) {
    if (!paste0("package:", pkg) %in% search()) {
      suppressPackageStartupMessages(
        library(pkg, character.only = TRUE)
      )
    }
  }
  invisible(TRUE)
}

bench_deep_merge <- function(a, b) {
  if (is.null(b)) return(a)
  if (is.null(a)) return(b)

  if (is.list(a) && is.list(b)) {
    names_a <- names(a)
    names_b <- names(b)
    if (is.null(names_a) || is.null(names_b)) return(b)
    if (!length(names_a) || !length(names_b)) return(b)

    keys <- unique(c(names_a, names_b))
    out <- lapply(keys, function(key) bench_deep_merge(a[[key]], b[[key]]))
    names(out) <- keys
    return(out)
  }

  b
}

bench_repo_root <- function(start = ".") {
  root <- tryCatch(
    normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), mustWork = TRUE),
    error = function(...) normalizePath(start, mustWork = TRUE)
  )
  normalizePath(root, mustWork = TRUE)
}

bench_is_absolute_path <- function(path) {
  grepl("^(/|[A-Za-z]:[/\\\\])", path)
}

bench_abs_path <- function(path, repo_root = bench_repo_root(), must_work = FALSE) {
  if (bench_is_absolute_path(path)) {
    normalizePath(path, mustWork = must_work)
  } else {
    normalizePath(file.path(repo_root, path), mustWork = must_work)
  }
}

bench_rel_path <- function(path, repo_root = bench_repo_root()) {
  root <- normalizePath(repo_root, mustWork = TRUE)
  abs_path <- normalizePath(path, mustWork = FALSE)
  sub(paste0("^", root, "/?"), "", abs_path)
}

bench_read_yaml <- function(path) {
  bench_assert_packages("yaml")
  yaml::read_yaml(path)
}

bench_write_yaml <- function(x, path) {
  bench_assert_packages("yaml")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  yaml::write_yaml(x, path)
}

bench_write_json <- function(x, path, pretty = TRUE, auto_unbox = TRUE) {
  bench_assert_packages("jsonlite")
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(x, path, pretty = pretty, auto_unbox = auto_unbox, null = "null")
}

bench_md5 <- function(path) {
  unname(tools::md5sum(path))
}

bench_sha256 <- function(path) {
  bench_assert_packages("digest")
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

bench_timestamp_utc <- function(x = Sys.time()) {
  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC", usetz = FALSE)
}

bench_git_info <- function(repo_root = bench_repo_root()) {
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(repo_root)

  sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(...) NA_character_)
  branch <- tryCatch(system("git rev-parse --abbrev-ref HEAD", intern = TRUE), error = function(...) NA_character_)

  list(
    sha = if (length(sha)) sha[[1L]] else NA_character_,
    branch = if (length(branch)) branch[[1L]] else NA_character_
  )
}

bench_resolve_paths <- function(cfg, repo_root = bench_repo_root()) {
  paths_cfg <- cfg$paths %||% list()

  raw_root <- bench_abs_path(paths_cfg$raw_root %||% "data-raw/benchmarks", repo_root = repo_root)
  processed_root <- bench_abs_path(paths_cfg$processed_root %||% "data-processed/benchmarks", repo_root = repo_root)
  figures_root <- bench_abs_path(paths_cfg$figures_root %||% "figures/benchmarks/generated", repo_root = repo_root)
  reports_root <- bench_abs_path(paths_cfg$reports_root %||% "reports/benchmarks/generated", repo_root = repo_root)
  logs_root <- bench_abs_path(paths_cfg$logs_root %||% "logs/benchmarks", repo_root = repo_root)

  list(
    repo_root = repo_root,
    raw_root = raw_root,
    raw_monash = file.path(raw_root, "monash"),
    raw_m4 = file.path(raw_root, "m4"),
    processed_root = processed_root,
    metadata_dir = file.path(processed_root, "metadata"),
    panel_dir = file.path(processed_root, "panel"),
    splits_dir = file.path(processed_root, "splits"),
    quality_dir = file.path(processed_root, "quality"),
    figures_dir = figures_root,
    reports_dir = reports_root,
    logs_root = logs_root,
    manifests_dir = file.path(logs_root, "manifests"),
    downloads_dir = file.path(logs_root, "downloads"),
    processing_dir = file.path(logs_root, "processing")
  )
}

bench_ensure_directories <- function(paths) {
  dir_targets <- unlist(paths[c(
    "raw_root",
    "raw_monash",
    "raw_m4",
    "processed_root",
    "metadata_dir",
    "panel_dir",
    "splits_dir",
    "quality_dir",
    "figures_dir",
    "reports_dir",
    "logs_root",
    "manifests_dir",
    "downloads_dir",
    "processing_dir"
  )], use.names = FALSE)

  invisible(vapply(dir_targets, dir.create, logical(1), recursive = TRUE, showWarnings = FALSE))
}

bench_load_registry <- function(path, repo_root = bench_repo_root()) {
  registry <- bench_read_yaml(bench_abs_path(path, repo_root = repo_root, must_work = TRUE))
  bench_validate_registry(registry)
  registry
}

bench_validate_registry <- function(registry) {
  if (is.null(registry$monash$default_selection) || !length(registry$monash$default_selection)) {
    stop("Benchmark registry must define a non-empty monash default_selection.", call. = FALSE)
  }

  if (is.null(registry$m4$default_selection) || !length(registry$m4$default_selection)) {
    stop("Benchmark registry must define a non-empty m4 default_selection.", call. = FALSE)
  }

  monash_datasets <- names(registry$monash$datasets %||% list())
  missing_defaults <- setdiff(registry$monash$default_selection, monash_datasets)
  if (length(missing_defaults)) {
    stop(
      sprintf(
        "Monash default_selection references unknown datasets: %s",
        paste(missing_defaults, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  excluded <- vapply(
    registry$monash$duplicate_exclusions %||% list(),
    function(entry) entry$dataset %||% NA_character_,
    character(1)
  )
  overlap <- intersect(registry$monash$default_selection, excluded)
  if (length(overlap)) {
    stop(
      sprintf(
        "Monash default_selection contains datasets explicitly excluded as official M4 duplicates: %s",
        paste(overlap, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

bench_read_pipeline_config <- function(config_path = NULL, repo_root = bench_repo_root()) {
  defaults_path <- file.path(repo_root, "config", "benchmarks", "defaults.yaml")
  cfg <- bench_read_yaml(defaults_path)

  if (!is.null(config_path)) {
    cfg <- bench_deep_merge(
      cfg,
      bench_read_yaml(bench_abs_path(config_path, repo_root = repo_root, must_work = TRUE))
    )
  }

  registry_path <- cfg$registry_path %||% "config/benchmarks/datasets.yaml"
  registry <- bench_load_registry(registry_path, repo_root = repo_root)
  paths <- bench_resolve_paths(cfg, repo_root = repo_root)

  list(
    config = cfg,
    registry = registry,
    paths = paths,
    git = bench_git_info(repo_root = repo_root)
  )
}

bench_save_table <- function(x, path_stub, write_csv = TRUE, write_rds = TRUE, compress = "gzip") {
  dir.create(dirname(path_stub), recursive = TRUE, showWarnings = FALSE)

  outputs <- list()

  if (isTRUE(write_rds)) {
    rds_path <- paste0(path_stub, ".rds")
    saveRDS(x, rds_path, compress = compress)
    outputs$rds <- rds_path
  }

  if (isTRUE(write_csv)) {
    csv_path <- paste0(path_stub, ".csv.gz")
    utils::write.csv(x, gzfile(csv_path), row.names = FALSE, na = "")
    outputs$csv <- csv_path
  }

  outputs
}
