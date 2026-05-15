`%||%` <- function(a, b) if (is.null(a)) b else a

.qdesn_validation_md5 <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  as.character(tools::md5sum(path)[[1L]])
}

.qdesn_validation_sha256 <- function(path) {
  path <- as.character(path %||% "")[1L]
  if (is.na(path) || !nzchar(path) || !file.exists(path)) return(NA_character_)
  if (!nzchar(Sys.which("sha256sum"))) return(NA_character_)
  out <- tryCatch(
    system2("sha256sum", path, stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) return(NA_character_)
  out <- trimws(out)
  out <- out[nzchar(out)]
  if (!length(out)) return(NA_character_)
  hash <- strsplit(out[[1L]], "[[:space:]]+", perl = TRUE)[[1L]][1L]
  if (is.na(hash) || !grepl("^[[:xdigit:]]{64}$", hash)) NA_character_ else tolower(hash)
}

.qdesn_validation_cmd_first <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) return(NA_character_)
  out <- trimws(out)
  out <- out[nzchar(out)]
  if (length(out)) out[[1L]] else NA_character_
}

.qdesn_validation_cmd_lines <- function(cmd, args = character()) {
  out <- tryCatch(
    system2(cmd, args = args, stdout = TRUE, stderr = TRUE),
    error = function(e) sprintf("ERROR: %s", conditionMessage(e))
  )
  enc2utf8(out)
}

qdesn_validation_git_snapshot <- function(repo_root = NULL) {
  repo_root <- repo_root %||% .qdesn_validation_repo_root()
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(repo_root)
  {
    branch <- .qdesn_validation_cmd_first("git", c("rev-parse", "--abbrev-ref", "HEAD"))
    head <- .qdesn_validation_cmd_first("git", c("rev-parse", "HEAD"))
    head_short <- .qdesn_validation_cmd_first("git", c("rev-parse", "--short", "HEAD"))
    subject <- .qdesn_validation_cmd_first("git", c("log", "-1", "--format=%s"))
    upstream <- .qdesn_validation_cmd_first("git", c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"))
    status_lines <- .qdesn_validation_cmd_lines("git", c("status", "--short"))
    ahead_behind <- if (!is.na(upstream) && nzchar(upstream)) {
      .qdesn_validation_cmd_first("git", c("rev-list", "--left-right", "--count", paste0("HEAD...", upstream)))
    } else {
      NA_character_
    }
    list(
      repo_root = normalizePath(repo_root, winslash = "/", mustWork = FALSE),
      branch = branch,
      head = head,
      head_short = head_short,
      head_subject = subject,
      upstream = upstream,
      ahead_behind = ahead_behind,
      dirty = length(status_lines) > 0L,
      status_short = as.list(status_lines)
    )
  }
}

qdesn_validation_runtime_snapshot <- function(repo_root = NULL,
                                              rscript = Sys.which("Rscript"),
                                              min_version = "4.6.0") {
  repo_root <- repo_root %||% .qdesn_validation_repo_root()
  rscript <- as.character(rscript %||% "")[1L]
  if (!nzchar(rscript)) rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- "Rscript"
  rscript_resolved <- tryCatch(normalizePath(rscript, winslash = "/", mustWork = FALSE), error = function(...) rscript)
  version_ok <- tryCatch(getRversion() >= numeric_version(min_version), error = function(...) FALSE)
  forbidden_rscript <- normalizePath("/usr/bin/Rscript", winslash = "/", mustWork = FALSE)
  forbidden <- identical(rscript_resolved, forbidden_rscript)
  list(
    generated_at = as.character(Sys.time()),
    repo_root = normalizePath(repo_root, winslash = "/", mustWork = FALSE),
    rscript = rscript_resolved,
    rscript_sys_which = tryCatch(normalizePath(Sys.which("Rscript"), winslash = "/", mustWork = FALSE), error = function(...) Sys.which("Rscript")),
    r_home = R.home(),
    r_version = R.version.string,
    r_version_numeric = as.character(getRversion()),
    min_version = as.character(min_version),
    version_ok = isTRUE(version_ok),
    forbidden_rscript = isTRUE(forbidden),
    lib_paths = as.list(normalizePath(.libPaths(), winslash = "/", mustWork = FALSE)),
    env = list(
      R_LIBS = Sys.getenv("R_LIBS", unset = ""),
      R_LIBS_USER = Sys.getenv("R_LIBS_USER", unset = ""),
      R_LIBS_SITE = Sys.getenv("R_LIBS_SITE", unset = ""),
      PATH = Sys.getenv("PATH", unset = "")
    )
  )
}

qdesn_validation_assert_runtime <- function(repo_root = NULL,
                                            rscript = Sys.which("Rscript"),
                                            min_version = "4.6.0",
                                            forbid_usr_bin = TRUE) {
  snap <- qdesn_validation_runtime_snapshot(repo_root = repo_root, rscript = rscript, min_version = min_version)
  problems <- character(0)
  if (!isTRUE(snap$version_ok)) {
    problems <- c(problems, sprintf("R version %s is older than required %s.", snap$r_version_numeric, min_version))
  }
  if (isTRUE(forbid_usr_bin) && isTRUE(snap$forbidden_rscript)) {
    problems <- c(problems, sprintf("Rscript resolves to forbidden system path: %s.", snap$rscript))
  }
  if (length(problems)) {
    stop(paste(c("Q-DESN validation runtime guard failed:", paste0("- ", problems)), collapse = "\n"), call. = FALSE)
  }
  invisible(snap)
}

qdesn_validation_file_manifest <- function(paths, repo_root = NULL) {
  repo_root <- repo_root %||% .qdesn_validation_repo_root()
  paths <- as.character(paths)
  rows <- lapply(paths, function(path) {
    raw <- path
    if (is.na(raw) || !nzchar(raw)) {
      return(data.frame(
        path = NA_character_,
        exists = FALSE,
        bytes = NA_real_,
        mtime = NA_character_,
        md5 = NA_character_,
        stringsAsFactors = FALSE
      ))
    }
    if (!grepl("^(/|~)", raw)) raw <- file.path(repo_root, raw)
    resolved <- normalizePath(raw, winslash = "/", mustWork = FALSE)
    exists <- file.exists(resolved)
    info <- if (exists) file.info(resolved) else NULL
    data.frame(
      path = resolved,
      exists = exists,
      bytes = if (exists) as.numeric(info$size[[1L]]) else NA_real_,
      mtime = if (exists) as.character(info$mtime[[1L]]) else NA_character_,
      md5 = .qdesn_validation_md5(resolved),
      sha256 = .qdesn_validation_sha256(resolved),
      stringsAsFactors = FALSE
    )
  })
  .qdesn_validation_bind_rows(rows)
}
