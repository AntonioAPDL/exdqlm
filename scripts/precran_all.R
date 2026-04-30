#!/usr/bin/env Rscript

# Pre-CRAN orchestration script for local and optional remote checks.
# Usage:
#   Rscript scripts/precran_all.R [--rhub] [--skip-rhub] [--skip-winbuilder]
#                                  [--pat <token>] [--pat-file <path>]
# Behavior:
# - Runs a local CRAN-like check and writes logs under check-logs/<timestamp>/.
#   Uses devtools::check(cran = TRUE) when devtools is already available, and
#   falls back to rcmdcheck::rcmdcheck(args = "--as-cran") otherwise.
# - Optionally submits R-hub checks when --rhub is supplied and auth/repo checks pass.
# - Submits Win-builder release/devel checks with retry on transient upload
#   failures when devtools is available, unless --skip-winbuilder is supplied.
# Exit status:
# - Non-zero if local CRAN-like check fails.

cat("=== Pre-CRAN all-checks starting ===\n")

# ----- small helpers ---------------------------------------------------------
ensure_pkg <- function(pkg, repo = "https://cloud.r-project.org") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing missing package: ", pkg)
    install.packages(pkg, repos = repo)
  }
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("Required package is unavailable after installation attempt: ", pkg)
  }
  invisible(TRUE)
}

# Core deps
invisible(lapply(c("rcmdcheck", "gh", "curl", "gitcreds"), ensure_pkg))
have_devtools <- requireNamespace("devtools", quietly = TRUE)
if (have_devtools) {
  suppressPackageStartupMessages(library(devtools))
} else {
  message("devtools is not installed; using rcmdcheck for the local check and skipping Win-builder submission.")
}
# Try both rhub flavors; OK if rhubv2 isn't on your R
have_rhub  <- requireNamespace("rhub",   quietly = TRUE)
have_rhub2 <- requireNamespace("rhubv2", quietly = TRUE)
if (have_rhub)  suppressPackageStartupMessages(library(rhub))
if (have_rhub2) suppressPackageStartupMessages(library(rhubv2))

# args: optional PAT string or file
args <- commandArgs(trailingOnly = TRUE)
arg_val <- function(flag) {
  i <- which(args == flag)
  if (length(i) && i < length(args)) args[i + 1] else ""
}
pat_arg      <- arg_val("--pat")
pat_file_arg <- arg_val("--pat-file")

# Detect WSL & map Windows path -> /mnt/...
is_wsl <- function() {
  txt <- try(readLines("/proc/version", warn = FALSE), silent = TRUE)
  if (inherits(txt, "try-error")) return(FALSE)
  grepl("Microsoft", paste(txt, collapse = " "), ignore.case = TRUE)
}
wsl_path <- function(p) {
  if (!nzchar(p)) return(p)
  if (!is_wsl())  return(p)
  if (grepl("^[A-Za-z]:\\\\", p)) {
    drive <- tolower(substr(p, 1, 1))
    rest  <- gsub("\\\\", "/", substr(p, 3, nchar(p)))
    return(paste0("/mnt/", drive, "/", rest))
  }
  p
}
mask <- function(x) if (!nzchar(x)) "<empty>" else {
  if (nchar(x) <= 8) paste0(substr(x, 1, 2), "...")
  else paste0(substr(x, 1, 4), "...", substr(x, nchar(x) - 3, nchar(x)))
}

has_flag <- function(flag) flag %in% args

git_cmd <- function(...) {
  out <- try(system2("git", c(...), stdout = TRUE, stderr = TRUE), silent = TRUE)
  if (inherits(out, "try-error")) return(character())
  trimws(out)
}
git_is_detached <- function() {
  b <- git_cmd("rev-parse", "--abbrev-ref", "HEAD")
  length(b) == 0 || identical(b[[1]], "HEAD")
}
git_is_dirty <- function() {
  s <- git_cmd("status", "--porcelain")
  length(s) > 0
}

skip_rhub  <- has_flag("--skip-rhub")
force_rhub <- has_flag("--rhub")
skip_winbuilder <- has_flag("--skip-winbuilder")

# Logging wrapper
ts <- format(Sys.time(), "%Y%m%d-%H%M%S")
log_root <- file.path("check-logs", ts)
dir.create(log_root, recursive = TRUE, showWarnings = FALSE)
log_section <- function(name, expr) {
  log_file <- file.path(log_root, paste0(name, ".log"))
  message("\n--- ", name, " ---")
  con <- file(log_file, open = "wt")
  sink(con, type = "output")
  sink(con, type = "message")
  on.exit({
    sink(type = "message"); sink(type = "output")
    close(con)
    message("Wrote log: ", log_file)
  }, add = TRUE)
  force(expr)
}

# ----- .Rbuildignore hygiene --------------------------------------------------
rbi <- ".Rbuildignore"
need_ignore <- c("^scripts$", "^check-logs$")
if (file.exists(rbi)) {
  lines <- readLines(rbi)
  add <- setdiff(need_ignore, lines)
  if (length(add)) {
    writeLines(c(lines, add), rbi)
    message("Updated .Rbuildignore with: ", paste(add, collapse = ", "))
  }
} else {
  writeLines(need_ignore, rbi)
  message("Created .Rbuildignore with: ", paste(need_ignore, collapse = ", "))
}

# ----- VignetteBuilder sanity (warn only) -------------------------------------
desc_path <- "DESCRIPTION"
has_vignettes <- dir.exists("vignettes") &&
  length(list.files("vignettes", pattern = "\\.(R?nw|Rmd|qmd)$")) > 0
has_vb <- FALSE
if (file.exists(desc_path)) has_vb <- any(grepl("^\\s*VignetteBuilder\\s*:", readLines(desc_path)))
if (has_vb && !has_vignettes) warning("DESCRIPTION has VignetteBuilder but no vignettes. Consider removing VignetteBuilder.")

# ----- GitHub PAT loading + reachability --------------------------------------
load_and_check_pat <- function() {
  pat <- Sys.getenv("GITHUB_PAT", "")
  src <- if (nzchar(pat)) "env:GITHUB_PAT" else ""

  if (!nzchar(pat) && nzchar(pat_arg)) {
    pat <- pat_arg; src <- "--pat"
  }

  if (!nzchar(pat)) {
    # 1) explicit file arg
    pf <- pat_file_arg
    # 2) env var
    if (!nzchar(pf)) pf <- Sys.getenv("GITHUB_PAT_FILE", "")
    # 3) Antonio's Windows default (mapped to WSL as needed)
    if (!nzchar(pf)) pf <- "C:/Users/anton/OneDrive/Desktop/github_token.txt"
    pf <- wsl_path(pf)
    if (nzchar(pf) && file.exists(pf)) {
      lines <- trimws(readLines(pf, warn = FALSE)); lines <- lines[nzchar(lines)]
      if (length(lines)) { pat <- lines[[1]]; src <- paste0("pat-file:", pf) }
    }
  }

  if (!nzchar(pat)) {
    # Common dotfile fallbacks
    for (cand in path.expand(c("~/.github_pat", "~/.config/github_pat.txt"))) {
      if (file.exists(cand)) {
        lines <- trimws(readLines(cand, warn = FALSE)); lines <- lines[nzchar(lines)]
        if (length(lines)) { pat <- lines[[1]]; src <- paste0("file:", cand); break }
      }
    }
  }

  if (!nzchar(pat)) {
    gc <- try(gitcreds::gitcreds_get("https://github.com"), silent = TRUE)
    if (!inherits(gc, "try-error")) { pat <- gc$password; src <- "gitcreds store" }
  }

  have_pat <- nzchar(pat)
  if (have_pat) {
    Sys.setenv(GITHUB_PAT = pat, GITHUB_TOKEN = pat)
    message("Loaded PAT from: ", src, " (", mask(pat), ")")
  } else {
    message("No GITHUB_PAT found. Provide via env, --pat, --pat-file, GITHUB_PAT_FILE, a default file, or gitcreds.")
  }

  net_ok <- TRUE
  api_ok <- TRUE
  if (inherits(try(curl::curl_fetch_memory("https://api.github.com"), silent = TRUE), "try-error")) net_ok <- FALSE
  if (net_ok && inherits(try(gh::gh_whoami(), silent = TRUE), "try-error")) api_ok <- FALSE

  list(have_pat = have_pat, net_ok = net_ok, api_ok = api_ok)
}

# ----- 1) Local CRAN-like check ----------------------------------------------
local_errs <- local_warns <- local_notes <- 0L
local_log_name <- if (have_devtools) "local-devtools-check" else "local-rcmdcheck"
log_section(local_log_name, {
  if (have_devtools) {
    res <- devtools::check(".", cran = TRUE)
  } else {
    res <- rcmdcheck::rcmdcheck(args = "--as-cran", error_on = "never")
  }
  local_errs  <<- length(res$errors)
  local_warns <<- length(res$warnings)
  local_notes <<- length(res$notes)
})
if (local_errs > 0) {
  cat("\n*** Local check FAILED. See log.\n")
  cat("Logs: ", normalizePath(log_root), "\n", sep = "")
  quit(status = 1, save = "no")
}
if (local_warns > 0) message("Local check has warnings.")
if (local_notes > 0) message("Local check has notes (review carefully).")

# ----- 2) R-hub checks (v1/v2) ------------------------------------------------
rhub_started <- FALSE
log_section("rhub-checks", {
  status <- load_and_check_pat()

  git_ok <- !git_is_detached() && !git_is_dirty()
  if (!git_ok) cat("Git repo not in a pushed state (detached HEAD and/or dirty). Skipping R-hub.\n")

  run_rhub <- !skip_rhub && force_rhub && status$have_pat && status$net_ok && status$api_ok && git_ok

  if (!status$have_pat) cat("No GITHUB_PAT available. Skipping R-hub.\n")
  if (status$have_pat && (!status$net_ok || !status$api_ok)) cat("GitHub API not reachable (network/firewall). Skipping R-hub.\n")

  if (run_rhub) {
    # Best-effort diagnostics
    if (have_rhub)  try(rhub::rhub_doctor(),  silent = TRUE)
    if (have_rhub2) try(rhubv2::rhub_doctor(), silent = TRUE)

    submit <- function() {
      # Prefer rhubv2 if available
      if (have_rhub2 && "rhub_check" %in% getNamespaceExports("rhubv2")) {
        f <- rhubv2::rhub_check
        fml <- names(formals(f))
        a <- list(platforms = c("linux", "windows", "macos-arm64"))
        if ("path" %in% fml) a$path <- "."
        return(do.call(f, a))
      }
      # Fallback to rhub v1 (may return NULL on success)
      if (have_rhub && "rhub_check" %in% getNamespaceExports("rhub")) {
        f <- rhub::rhub_check
        fml <- names(formals(f))
        a <- list(platforms = c("linux", "windows", "macos-arm64"))
        if ("path" %in% fml) a$path <- "."
        return(do.call(f, a))
      }
      stop("No rhub or rhubv2 with rhub_check() is installed.")
    }

    err <- NULL
    ok  <- TRUE
    runs <- tryCatch(submit(), error = function(e) { err <<- e; ok <<- FALSE; NULL })

    if (!ok) {
      cat("rhub_check() did not start. Details:\n")
      cat("  -> ", conditionMessage(err), "\n", sep = "")
    } else {
      rhub_started <<- TRUE
      if (!is.null(runs)) print(runs)
      # Try printing status if exported
      st <- try({
        if (have_rhub2 && exists("rhub_status", where = asNamespace("rhubv2"), inherits = FALSE)) {
          rhubv2::rhub_status(runs)
        } else if (have_rhub && exists("rhub_status", where = asNamespace("rhub"), inherits = FALSE)) {
          rhub::rhub_status(runs)
        } else NA
      }, silent = TRUE)
      if (!inherits(st, "try-error") && !is.na(st)[1]) {
        cat("\nR-hub runs started. Track in Actions or rhub_status().\n")
        print(st)
      } else {
        cat("\nR-hub runs submitted. Watch your repo's Actions tab.\n")
      }
    }
  }
})

# ----- 3) Win-builder (release + devel) with retry ----------------------------
winbuilder_submitted <- FALSE
win_upload <- function(which) {
  fn <- switch(which,
               release = devtools::check_win_release,
               devel   = devtools::check_win_devel)
  out <- try(fn("."), silent = TRUE)
  cond <- if (inherits(out, "try-error")) attr(out, "condition") else NULL
  msg  <- if (!is.null(cond)) conditionMessage(cond) else ""
  if (!is.null(cond) && grepl("FTP|550|upload", msg, ignore.case = TRUE)) {
    message("Win-builder ", which, " upload failed (", msg, "). Retrying in 20s...")
    Sys.sleep(20)
    out <- try(fn("."), silent = TRUE)
  }
  invisible(out)
}

if (skip_winbuilder) {
  log_section("winbuilder-release", { cat("Skipped by --skip-winbuilder.\n") })
  log_section("winbuilder-devel",   { cat("Skipped by --skip-winbuilder.\n") })
} else if (!have_devtools) {
  log_section("winbuilder-release", { cat("Skipped because devtools is not installed.\n") })
  log_section("winbuilder-devel",   { cat("Skipped because devtools is not installed.\n") })
} else {
  log_section("winbuilder-release", { win_upload("release") })
  log_section("winbuilder-devel",   { win_upload("devel")   })
  winbuilder_submitted <- TRUE
}

# ----- summary ---------------------------------------------------------------
cat("\n=== Pre-CRAN all-checks finished ===\n")
cat(sprintf("Local check: OK (%d errors, %d warnings, %d notes)\n", local_errs, local_warns, local_notes))
cat(if (rhub_started) "R-hub: started/submitted.\n" else "R-hub: not started (no PAT or GitHub unreachable).\n")
cat(if (winbuilder_submitted) "Win-builder: submitted (watch maintainer email for results).\n" else "Win-builder: not submitted (skipped or devtools unavailable).\n")
cat("Logs: ", normalizePath(log_root), "\n", sep = "")
