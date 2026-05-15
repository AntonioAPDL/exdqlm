`%||%` <- function(a, b) if (is.null(a)) b else a

ffv2_harness_root <- function() {
  opt <- getOption("ffv2.harness_root")
  if (!is.null(opt) && dir.exists(opt)) {
    return(normalizePath(opt, winslash = "/", mustWork = TRUE))
  }
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  candidates <- c(
    file.path(cwd, "validation", "fitforecast_v2"),
    cwd,
    dirname(cwd)
  )
  ok <- vapply(candidates, function(path) {
    file.exists(file.path(path, "config", "exdqlm_dynamic_fitforecast_v2_defaults.yaml"))
  }, logical(1))
  if (any(ok)) {
    root <- normalizePath(candidates[which(ok)[1L]], winslash = "/", mustWork = TRUE)
    options(ffv2.harness_root = root)
    return(root)
  }
  stop("Could not locate validation/fitforecast_v2 harness root.", call. = FALSE)
}

ffv2_repo_root <- function() {
  normalizePath(file.path(ffv2_harness_root(), "..", ".."), winslash = "/", mustWork = TRUE)
}

ffv2_source_all <- function(harness_root = NULL) {
  if (is.null(harness_root)) harness_root <- ffv2_harness_root()
  harness_root <- normalizePath(harness_root, winslash = "/", mustWork = TRUE)
  options(ffv2.harness_root = harness_root)
  r_dir <- file.path(harness_root, "R")
  files <- list.files(r_dir, pattern = "[.]R$", full.names = TRUE)
  files <- c(file.path(r_dir, "utils.R"), setdiff(files, file.path(r_dir, "utils.R")))
  invisible(lapply(files, source))
}

ffv2_require_namespace <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Required R package '%s' is not installed.", pkg), call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_default_defaults_path <- function() {
  file.path(ffv2_harness_root(), "config", "exdqlm_dynamic_fitforecast_v2_defaults.yaml")
}

ffv2_load_yaml <- function(path) {
  ffv2_require_namespace("yaml")
  yaml::read_yaml(path)
}

ffv2_load_defaults <- function(path = ffv2_default_defaults_path()) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  defaults <- ffv2_load_yaml(path)
  defaults$.__defaults_path__ <- path
  defaults
}

ffv2_resolve_path <- function(path, repo_root = ffv2_repo_root(), must_work = FALSE) {
  path <- as.character(path)[1L]
  if (!nzchar(path)) stop("Cannot resolve an empty path.", call. = FALSE)
  if (!startsWith(path, "/")) path <- file.path(repo_root, path)
  normalizePath(path, winslash = "/", mustWork = must_work)
}

ffv2_ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_write_csv <- function(x, path) {
  ffv2_ensure_dir(dirname(path))
  utils::write.csv(x, path, row.names = FALSE, na = "")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_read_csv <- function(path, ...) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, ...)
}

ffv2_write_json <- function(x, path, pretty = TRUE) {
  ffv2_require_namespace("jsonlite")
  ffv2_ensure_dir(dirname(path))
  jsonlite::write_json(x, path, pretty = pretty, auto_unbox = TRUE, null = "null")
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

ffv2_read_json <- function(path) {
  ffv2_require_namespace("jsonlite")
  jsonlite::read_json(path, simplifyVector = FALSE)
}

ffv2_parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    item <- args[[i]]
    if (!startsWith(item, "--")) {
      i <- i + 1L
      next
    }
    item <- sub("^--", "", item)
    if (grepl("=", item, fixed = TRUE)) {
      parts <- strsplit(item, "=", fixed = TRUE)[[1L]]
      out[[parts[[1L]]]] <- paste(parts[-1L], collapse = "=")
      i <- i + 1L
      next
    }
    key <- item
    next_item <- if (i < length(args)) args[[i + 1L]] else NULL
    if (!is.null(next_item) && !startsWith(next_item, "--")) {
      out[[key]] <- next_item
      i <- i + 2L
    } else {
      out[[key]] <- TRUE
      i <- i + 1L
    }
  }
  out
}

ffv2_truthy <- function(x) {
  if (is.logical(x)) return(isTRUE(x))
  tolower(as.character(x)[1L]) %in% c("1", "true", "yes", "y", "on")
}

ffv2_tau_label <- function(tau, digits = 2L) {
  vals <- as.numeric(tau)
  vapply(vals, function(one) {
    gsub("\\.", "p", format(one, nsmall = digits, digits = digits + 2L, trim = TRUE))
  }, character(1))
}

ffv2_file_sha256 <- function(path, missing = NA_character_) {
  if (!file.exists(path)) return(missing)
  exe <- Sys.which("sha256sum")
  if (!nzchar(exe)) stop("sha256sum is required for source hash manifests.", call. = FALSE)
  out <- system2(exe, shQuote(path), stdout = TRUE, stderr = TRUE)
  strsplit(out[[1L]], "\\s+")[[1L]][[1L]]
}

ffv2_git_info <- function(repo_root = ffv2_repo_root()) {
  cmd <- function(...) {
    tryCatch(system2("git", c("-C", repo_root, ...), stdout = TRUE, stderr = TRUE),
             error = function(e) NA_character_)
  }
  branch <- cmd("branch", "--show-current")
  head <- cmd("rev-parse", "HEAD")
  subject <- cmd("log", "-1", "--format=%s")
  status <- cmd("status", "--short")
  list(
    repo_root = repo_root,
    branch = branch[[1L]] %||% NA_character_,
    head = head[[1L]] %||% NA_character_,
    subject = subject[[1L]] %||% NA_character_,
    dirty = length(status) > 0L,
    dirty_status = status
  )
}

ffv2_runtime_metadata <- function(repo_root = ffv2_repo_root()) {
  list(
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    rscript = Sys.which("Rscript"),
    r_home = R.home(),
    r_version = R.version.string,
    lib_paths = .libPaths(),
    repo = ffv2_git_info(repo_root)
  )
}

ffv2_assert_runtime <- function(min_version = "4.6.0") {
  if (getRversion() < package_version(min_version)) {
    stop(sprintf("R %s or newer is required; active R is %s.",
                 min_version, as.character(getRversion())), call. = FALSE)
  }
  rscript <- normalizePath(Sys.which("Rscript"), winslash = "/", mustWork = FALSE)
  if (identical(rscript, "/usr/bin/Rscript")) {
    stop("Refusing to run with stale /usr/bin/Rscript; use the local R 4.6.0 toolchain.",
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_stop_stale_paths <- function(x) {
  if (is.data.frame(x)) {
    chars <- unlist(x[vapply(x, is.character, logical(1))], use.names = FALSE)
  } else if (is.list(x)) {
    chars <- unlist(x, use.names = FALSE)
    chars <- chars[is.character(chars)]
  } else {
    chars <- as.character(x)
  }
  bad <- unique(chars[!is.na(chars) & startsWith(chars, "/home/jaguir26/local/src")])
  if (length(bad)) {
    stop(sprintf("Stale /home path(s) are not allowed:\n%s", paste(bad, collapse = "\n")),
         call. = FALSE)
  }
  invisible(TRUE)
}

ffv2_bind_rows <- function(xs) {
  xs <- xs[!vapply(xs, is.null, logical(1))]
  if (!length(xs)) return(data.frame())
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    missing <- setdiff(cols, names(x))
    for (nm in missing) x[[nm]] <- NA
    x[, cols, drop = FALSE]
  })
  do.call(rbind, xs)
}

ffv2_quantile_columns <- function(draws, probs = c(0.025, 0.25, 0.5, 0.75, 0.975)) {
  draws <- as.matrix(draws)
  qs <- t(apply(draws, 1L, stats::quantile, probs = probs, na.rm = TRUE, names = FALSE))
  colnames(qs) <- paste0("qhat_p", gsub("\\.", "", sprintf("%.3f", probs)))
  as.data.frame(qs, check.names = FALSE)
}

ffv2_select_draws <- function(draws, n_draws, seed = 1L) {
  draws <- as.matrix(draws)
  n_draws <- as.integer(n_draws)[1L]
  if (!is.finite(n_draws) || n_draws <= 0L || ncol(draws) <= n_draws) return(draws)
  old <- if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
    get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  } else {
    NULL
  }
  on.exit({
    if (is.null(old)) {
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else {
      assign(".Random.seed", old, envir = .GlobalEnv)
    }
  }, add = TRUE)
  set.seed(as.integer(seed)[1L])
  draws[, sample.int(ncol(draws), n_draws), drop = FALSE]
}

ffv2_pinball <- function(y, qhat, tau) {
  err <- y - qhat
  ifelse(err >= 0, tau * err, (tau - 1) * err)
}

ffv2_seconds <- function(start_time, end_time = Sys.time()) {
  as.numeric(difftime(end_time, start_time, units = "secs"))
}
