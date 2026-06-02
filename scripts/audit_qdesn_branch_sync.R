#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

parse_args <- function(args) {
  out <- list(
    canonical = "validation/shared-fitforecast-v2-1.0.0",
    output_dir = "validation/qdesn_sync/generated/latest"
  )
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) {
      i <- i + 1L
      next
    }
    key <- sub("^--", "", key)
    if (grepl("=", key, fixed = TRUE)) {
      parts <- strsplit(key, "=", fixed = TRUE)[[1L]]
      out[[parts[[1L]]]] <- paste(parts[-1L], collapse = "=")
      i <- i + 1L
    } else {
      if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
        out[[key]] <- TRUE
        i <- i + 1L
      } else {
        out[[key]] <- args[[i + 1L]]
        i <- i + 2L
      }
    }
  }
  out
}

repo_root <- normalizePath(
  file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])), ".."),
  mustWork = TRUE
)

opts <- parse_args(args)
if (!is.null(opts[["output-dir"]])) {
  opts$output_dir <- opts[["output-dir"]]
}

git <- function(args, allow_error = FALSE) {
  out <- suppressWarnings(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!allow_error && !is.null(status) && !identical(status, 0L)) {
    stop(paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

git_ok <- function(args) {
  out <- suppressWarnings(system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  is.null(status) || identical(status, 0L)
}

canonical <- opts$canonical
if (!length(git(c("rev-parse", "--verify", canonical), allow_error = TRUE))) {
  stop(sprintf("Canonical ref not found: %s", canonical), call. = FALSE)
}

all_refs <- git(c(
  "for-each-ref",
  "--sort=-committerdate",
  shQuote("--format=%(refname:short)"),
  "refs/heads",
  "refs/remotes"
))

qdesn_refs <- unique(all_refs[grepl(
  paste(c(
    "qdesn", "fitforecast", "shared-fitforecast", "glofas",
    "app-engine", "validation/rerun", "esn-server", "real-pipeline-split",
    "0\\.4\\.0-article-main"
  ), collapse = "|"),
  all_refs,
  ignore.case = TRUE
)])

qdesn_refs <- qdesn_refs[!grepl("1\\.0\\.0-jss|exdqlm-article-1\\.0\\.0", qdesn_refs)]
qdesn_refs <- qdesn_refs[qdesn_refs != canonical]

classify_ref <- function(ref, can_only, ref_only, relation, subject) {
  if (identical(relation, "ancestor_of_canonical")) return("already_absorbed")
  if (grepl("0p5p0|0\\.5\\.0|fit-forecast-shared-dynamic-0\\.5\\.0", ref, ignore.case = TRUE)) {
    return("historical_validation")
  }
  if (grepl("glofas-discrepancy-qdesn", ref, ignore.case = TRUE)) {
    return("optional_package_promotion_candidate")
  }
  if (grepl("0\\.4\\.0-article-main", ref, ignore.case = TRUE) ||
      grepl("truncated-normal entropy", subject, ignore.case = TRUE)) {
    return("narrow_patch_candidate")
  }
  if (grepl("probe|rerun-after|mcmc-alternative", ref, ignore.case = TRUE)) {
    return("historical_probe")
  }
  if (grepl("esn-server|real-pipeline-split", ref, ignore.case = TRUE)) {
    return("archive_lineage")
  }
  if (ref_only > 0L) return("needs_manual_triage")
  "no_action"
}

rows <- lapply(qdesn_refs, function(ref) {
  counts <- strsplit(git(c("rev-list", "--left-right", "--count", paste0(canonical, "...", ref))), "\\s+")[[1L]]
  can_only <- as.integer(counts[[1L]])
  ref_only <- as.integer(counts[[2L]])

  relation <- "diverged"
  if (git_ok(c("merge-base", "--is-ancestor", ref, canonical))) {
    relation <- "ancestor_of_canonical"
  }
  if (git_ok(c("merge-base", "--is-ancestor", canonical, ref))) {
    relation <- "descendant_of_canonical"
  }
  if (can_only == 0L && ref_only == 0L) relation <- "same"

  head_line <- git(c("log", "-1", "--format=%h%x09%H%x09%cs%x09%s", ref))
  parts <- strsplit(head_line[[1L]], "\t", fixed = TRUE)[[1L]]
  subject <- parts[[4L]]
  data.frame(
    ref = ref,
    canonical_only_commits = can_only,
    ref_only_commits = ref_only,
    relation_to_canonical = relation,
    head_short = parts[[1L]],
    head = parts[[2L]],
    head_date = parts[[3L]],
    head_subject = subject,
    sync_class = classify_ref(ref, can_only, ref_only, relation, subject),
    stringsAsFactors = FALSE
  )
})

inventory <- do.call(rbind, rows)
inventory <- inventory[order(inventory$sync_class, inventory$ref), , drop = FALSE]

out_dir <- file.path(repo_root, opts$output_dir)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "qdesn_branch_sync_inventory.csv")
md_path <- file.path(out_dir, "qdesn_branch_sync_inventory.md")
write.csv(inventory, csv_path, row.names = FALSE, na = "")

md <- c(
  "# Q-DESN Branch Sync Inventory",
  "",
  sprintf("- Generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("- Repository: `%s`", repo_root),
  sprintf("- Canonical ref: `%s`", canonical),
  "",
  "| Ref | Class | Relation | Canonical-only | Ref-only | Head | Subject |",
  "|---|---|---:|---:|---:|---|---|"
)
for (i in seq_len(nrow(inventory))) {
  md <- c(md, sprintf(
    "| `%s` | `%s` | `%s` | %s | %s | `%s` | %s |",
    inventory$ref[[i]],
    inventory$sync_class[[i]],
    inventory$relation_to_canonical[[i]],
    inventory$canonical_only_commits[[i]],
    inventory$ref_only_commits[[i]],
    inventory$head_short[[i]],
    gsub("\\|", "\\\\|", inventory$head_subject[[i]])
  ))
}
writeLines(md, md_path)

cat(sprintf("Wrote %s\n", csv_path))
cat(sprintf("Wrote %s\n", md_path))
