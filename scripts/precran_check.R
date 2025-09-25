#!/usr/bin/env Rscript

cat("=== Pre-CRAN check script starting ===\n")

ensure_pkg <- function(pkg, repo = "https://cloud.r-project.org") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing missing package: ", pkg)
    install.packages(pkg, repos = repo)
  }
  suppressPackageStartupMessages(require(pkg, character.only = TRUE))
}

for (p in c("devtools","rhub","usethis","gh","curl")) ensure_pkg(p)

pkg_path <- "."
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

## .Rbuildignore hygiene
rbi <- ".Rbuildignore"
need_ignore <- c("^scripts$", "^check-logs$")
if (file.exists(rbi)) {
  lines <- readLines(rbi)
  add <- setdiff(need_ignore, lines)
  if (length(add)) { writeLines(c(lines, add), rbi); message("Updated .Rbuildignore with: ", paste(add, collapse = ", ")) }
} else {
  writeLines(need_ignore, rbi)
  message("Created .Rbuildignore with: ", paste(need_ignore, collapse = ", "))
}

## VignetteBuilder sanity
desc_path <- file.path(pkg_path, "DESCRIPTION")
has_vignettes <- dir.exists(file.path(pkg_path, "vignettes")) &&
  length(list.files(file.path(pkg_path, "vignettes"), pattern = "\\.(R?nw|Rmd|qmd)$")) > 0
has_vb <- FALSE
if (file.exists(desc_path)) has_vb <- any(grepl("^\\s*VignetteBuilder\\s*:", readLines(desc_path)))
if (has_vb && !has_vignettes) warning("DESCRIPTION has VignetteBuilder but no vignettes/. Consider removing VignetteBuilder.")

## Helper: set PAT if missing, try fallback file, verify GitHub reachability
set_and_verify_pat <- function() {
  pat <- Sys.getenv("GITHUB_PAT", unset = NA_character_)
  if (is.na(pat) || nchar(pat) == 0) {
    # Try from file
    file_env <- Sys.getenv("GITHUB_PAT_FILE", unset = NA_character_)
    pat_file <- if (!is.na(file_env) && nzchar(file_env)) file_env else {
      # EDIT THIS DEFAULT IF YOU LIKE:
      # Your note said token lives here on Windows:
      "C:/Users/anton/OneDrive/Desktop/github_token.txt"
    }
    if (file.exists(pat_file)) {
      pat <- trimws(readLines(pat_file, warn = FALSE))
      pat <- pat[nzchar(pat)][1]
      if (!is.na(pat) && nzchar(pat)) {
        Sys.setenv(GITHUB_PAT = pat, GITHUB_TOKEN = pat)
        message("Loaded GITHUB_PAT from file: ", pat_file)
      }
    }
  } else {
    Sys.setenv(GITHUB_TOKEN = pat)
  }

  # Quick network probe
  net_ok <- FALSE
  gh_ok <- FALSE
  try({
    curl::curl_fetch_memory("https://api.github.com")  # will error on no network
    net_ok <- TRUE
  }, silent = TRUE)

  if (net_ok) {
    gh_ok <- FALSE
    try({
      who <- gh::gh_whoami()
      if (!is.null(who)) gh_ok <- TRUE
    }, silent = TRUE)
  }
  list(net_ok = net_ok, gh_ok = gh_ok,
       have_pat = !is.na(Sys.getenv("GITHUB_PAT", unset = NA_character_)) && nzchar(Sys.getenv("GITHUB_PAT")))
}

## 1) Local CRAN-like check
local_errs <- local_warns <- local_notes <- 0L
log_section("local-devtools-check", {
  res <- devtools::check(pkg_path, cran = TRUE)
  local_errs  <<- length(res$errors)
  local_warns <<- length(res$warnings)
  local_notes <<- length(res$notes)
})
if (local_errs > 0) {
  cat("\n*** Local check FAILED. See log.\n")
  quit(status = 1, save = "no")
}
if (local_warns > 0) message("Local check has warnings.")
if (local_notes > 0) message("Local check has notes (review carefully).")

## 2) R-hub v2 checks (only if PAT+network OK)
rhub_started <- FALSE
log_section("rhub-checks", {
  status <- set_and_verify_pat()
  if (!status$have_pat) {
    cat("No GITHUB_PAT available. Skipping R-hub.\n")
    return(invisible())
  }
  if (!status$net_ok || !status$gh_ok) {
    cat("GitHub API not reachable (network/firewall). Skipping R-hub.\n")
    return(invisible())
  }
  # This prints diagnostics; does not fail hard if something is missing
  try(rhub::rhub_doctor(), silent = TRUE)

  rh <- try(rhub::rhub_check(
    path = pkg_path,
    platforms = c("linux","windows","macos-arm64")
  ), silent = TRUE)

  if (inherits(rh, "try-error")) {
    cat("rhub_check() did not start (API/network issue). Skipping.\n")
  } else {
    rhub_started <<- TRUE
    print(rh)
    stat <- try(rhub::rhub_status(rh), silent = TRUE)
    if (!inherits(stat, "try-error")) {
      cat("\nR-hub runs started. Track in GitHub Actions or rhub_status().\n")
      print(stat)
    }
  }
})

## 3) Win-builder release + devel, with one retry on transient FTP 550
win_upload <- function(which) {
  fn <- switch(which,
               release = devtools::check_win_release,
               devel   = devtools::check_win_devel)
  out <- try(fn(pkg_path), silent = TRUE)
  if (inherits(out, "try-error") && grepl("FTP|550|upload", conditionMessage(attr(out, "condition")), ignore.case = TRUE)) {
    message("Win-builder ", which, " upload failed (", conditionMessage(attr(out, "condition")), "). Retrying in 20s...")
    Sys.sleep(20)
    out <- try(fn(pkg_path), silent = TRUE)
  }
  invisible(out)
}

log_section("winbuilder-release", { win_upload("release") })
log_section("winbuilder-devel",   { win_upload("devel")   })

## Summary
cat("\n=== Pre-CRAN check script finished ===\n")
cat(sprintf("Local check: OK (%d errors, %d warnings, %d notes)\n", local_errs, local_warns, local_notes))
cat(if (rhub_started) "R-hub: started.\n" else "R-hub: NOT started (no PAT or GitHub unreachable).\n")
cat("Win-builder: submitted (watch maintainer email for results).\n")
cat("Logs: ", normalizePath(log_root), "\n", sep = "")
