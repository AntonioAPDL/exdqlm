#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- grep(paste0("^", prefix), args, value = TRUE)
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

repo_root <- normalizePath(arg_value("repo-root", getwd()), winslash = "/", mustWork = TRUE)
run_tag <- arg_value("run-tag", Sys.getenv("REFRESHED288_RUN_TAG", unset = "20260507_p90_dynamic72_qdesn_comparable_fresh_v1"))
manifest_path <- arg_value("manifest", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_full_manifest_%s.csv", run_tag)))
out_path <- arg_value("out", file.path(repo_root, "tools/merge_reports", sprintf("LOCAL_refreshed288_micro_smoke_manifest_%s.csv", run_tag)))
family <- arg_value("family", "laplace")
tau_label <- arg_value("tau-label", "0p50")

read_required_csv <- function(path) {
  if (!file.exists(path)) stop("Missing required CSV: ", path, call. = FALSE)
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

manifest <- read_required_csv(manifest_path)
micro <- manifest[
  manifest$block == "dynamic" &
    manifest$family == family &
    manifest$tau_label == tau_label &
    manifest$fit_size %in% c(500L, 5000L) &
    manifest$model %in% c("dqlm", "exdqlm") &
    manifest$inference %in% c("vb", "mcmc"),
  ,
  drop = FALSE
]

micro$inference_order <- match(micro$inference, c("vb", "mcmc"))
micro <- micro[order(micro$inference_order, micro$fit_size, micro$model), , drop = FALSE]
micro$inference_order <- NULL
if (nrow(micro) != 8L) {
  stop("Expected 8 micro-smoke rows, found ", nrow(micro), call. = FALSE)
}

bad_phase <- micro$phase[!micro$phase %in% c("full_dynamic_vb", "full_dynamic_mcmc")]
if (length(bad_phase)) {
  stop("Unexpected micro-smoke phases: ", paste(unique(bad_phase), collapse = ", "), call. = FALSE)
}

if (any(micro$retention_mode != "comparison_plus_plot", na.rm = TRUE)) {
  stop("Micro-smoke rows are not all comparison_plus_plot", call. = FALSE)
}

flag_cols <- intersect(c("retain_candidate_fit_binaries", "retain_draw_binaries", "retain_vb_init_binaries"), names(micro))
for (col in flag_cols) {
  vals <- tolower(as.character(micro[[col]])) %in% c("true", "1", "yes")
  if (any(vals, na.rm = TRUE)) {
    stop("Micro-smoke row has ", col, "=TRUE", call. = FALSE)
  }
}

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
write.csv(micro, out_path, row.names = FALSE, na = "")

cat(sprintf("micro_smoke_rows=%d\n", nrow(micro)))
cat(sprintf("micro_smoke_row_ids=%s\n", paste(micro$row_id, collapse = ",")))
cat(sprintf("wrote_manifest=%s\n", out_path))
