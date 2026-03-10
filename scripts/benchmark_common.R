bootstrap_benchmark_packages <- function(stage = c("all", "download", "build", "analysis")) {
  stage <- match.arg(stage)

  bootstrap <- c("yaml", "jsonlite", "digest", "pkgload")
  missing_bootstrap <- bootstrap[!vapply(bootstrap, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_bootstrap)) {
    install.packages(missing_bootstrap, repos = "https://cloud.r-project.org")
  }

  repo_root <- tryCatch(
    normalizePath(system("git rev-parse --show-toplevel", intern = TRUE), mustWork = TRUE),
    error = function(...) normalizePath(".", mustWork = TRUE)
  )

  pkgload::load_all(repo_root, quiet = TRUE, export_all = TRUE)

  pkgs <- bench_required_packages(stage)
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    install.packages(missing, repos = "https://cloud.r-project.org")
  }

  bench_attach_packages(intersect(pkgs, c("data.table", "ggplot2", "scales")))

  invisible(repo_root)
}

benchmark_cli_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  get_arg <- function(flag, default = NULL) {
    idx <- which(args == flag)
    if (length(idx) && idx < length(args)) args[idx + 1L] else default
  }

  has_flag <- function(flag) {
    any(args == flag)
  }

  list(
    config = get_arg("--config"),
    overwrite = has_flag("--overwrite"),
    dry_run = has_flag("--dry-run") || has_flag("--dry_run")
  )
}
