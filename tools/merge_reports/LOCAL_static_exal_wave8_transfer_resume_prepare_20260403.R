#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
out_dir <- file.path(repo_root, "tools", "merge_reports")
`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_args <- function(args) {
  out <- list()
  for (x in args) {
    if (grepl("^--[^=]+=.*$", x)) {
      key <- sub("^--([^=]+)=.*$", "\\1", x)
      val <- sub("^--[^=]+=(.*)$", "\\1", x)
      out[[key]] <- val
    } else if (grepl("^--", x)) {
      key <- sub("^--", "", x)
      out[[key]] <- "TRUE"
    }
  }
  out
}

case_id_from_root <- function(run_root, model = "exal") {
  paste0(gsub("^.*/results/", "results/", run_root), "::", model)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
stage <- as.character(args$stage %||% "guard8")
schedule_path <- as.character(args$schedule %||% file.path(out_dir, "LOCAL_static_exal_wave8_transfer_schedule_20260403.csv"))
out_tsv <- as.character(args$out %||% file.path(out_dir, sprintf("LOCAL_static_exal_wave8_%s_resume_rows_20260403.tsv", stage)))

if (!file.exists(schedule_path)) stop(sprintf("schedule not found: %s", schedule_path))

sched <- utils::read.csv(schedule_path, stringsAsFactors = FALSE, check.names = FALSE)
if (!nrow(sched)) stop("schedule is empty")

sched <- sched[sched$stage == stage, , drop = FALSE]
if (!nrow(sched)) stop(sprintf("no rows in schedule for stage %s", stage))

sched$case_id <- case_id_from_root(sched$run_root, "exal")

summary_files <- Sys.glob(file.path(out_dir, "LOCAL_static_case_health_summary_wave8_transfer_*.csv"))
summary_list <- lapply(summary_files, function(p) {
  x <- tryCatch(utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE), error = function(e) NULL)
  if (is.null(x)) return(NULL)
  x$summary_path <- p
  x
})
summ <- if (length(summary_list)) do.call(rbind, summary_list) else data.frame()

if (!nrow(summ)) {
  sched$gate_overall <- NA_character_
} else {
  summ <- summ[summ$variant_tag %in% unique(sched$variant_tag), , drop = FALSE]
  merged <- merge(
    sched[, c("case_id", "variant_tag", "row_id")],
    summ[, c("case_id", "variant_tag", "gate_overall")],
    by = c("case_id", "variant_tag"),
    all.x = TRUE
  )
  sched$gate_overall <- merged$gate_overall
}

missing <- sched[is.na(sched$gate_overall) | !nzchar(sched$gate_overall), , drop = FALSE]
if (!nrow(missing)) {
  cat(sprintf("no missing rows for stage %s\n", stage))
  quit(status = 0)
}

missing <- missing[order(missing$candidate_id, missing$row_id), , drop = FALSE]

dir.create(dirname(out_tsv), recursive = TRUE, showWarnings = FALSE)
utils::write.table(
  missing[, c(
    "stage","row_id","run_root","root_kind","family","tt","tau_label","variant_tag",
    "gamma_substeps","p_global_eta_jump","global_eta_jump_scale","seed"
  )],
  out_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("resume_rows: %s\n", out_tsv))
