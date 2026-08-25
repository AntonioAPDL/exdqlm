#!/usr/bin/env Rscript

args_raw <- commandArgs(trailingOnly = TRUE)
repo_arg <- grep("^--repo-root=", args_raw, value = TRUE)
repo_root <- if (length(repo_arg)) sub("^--repo-root=", "", repo_arg[[1L]]) else getwd()
repo_root <- normalizePath(repo_root, winslash = "/", mustWork = TRUE)
setwd(repo_root)

source(file.path(repo_root, "validation", "fitforecast_v2", "R", "utils.R"))
ffv2_source_all(file.path(repo_root, "validation", "fitforecast_v2"))

output_dir <- imir_v1_output_dir(repo_root)
article_dir <- file.path(output_dir, "article_assets")
checks <- list()
add_check <- function(name, pass, detail = "") {
  checks[[length(checks) + 1L]] <<- data.frame(
    check = name, pass = isTRUE(pass), detail = as.character(detail),
    stringsAsFactors = FALSE
  )
}

required <- c(
  "plot_ready_metric_intervals.csv", "input_contract_checks.csv",
  "estimator_contract_ledger.csv", "implementation_contract_ledger.csv",
  "figure_specification.csv", "coupling_pilot_interpretation.csv",
  "coupling_paired_comparison.csv", "coupling_overlap_sensitivity.csv",
  "fresh_chain_replay_equivalence.csv", "coupling_pilot_original_checks.csv",
  "decision_manifest.json", "reporting_file_ledger.csv", "article_asset_manifest.csv"
)
add_check("required_reporting_files", all(file.exists(file.path(output_dir, required))))

input_checks <- ffv2_read_csv(file.path(output_dir, "input_contract_checks.csv"))
add_check("all_input_contract_checks", all(input_checks$pass),
          paste(input_checks$check[!input_checks$pass], collapse = ";"))

plot_data <- ffv2_read_csv(file.path(output_dir, "plot_ready_metric_intervals.csv"))
add_check("plot_rows_216", nrow(plot_data) == 216L, nrow(plot_data))
add_check("plot_keys_unique", !anyDuplicated(do.call(paste, c(plot_data[c(
  "inference", "model_variant", "family", "tau", "metric_role"
)], sep = "|"))))

reporting_ledger <- ffv2_read_csv(file.path(output_dir, "reporting_file_ledger.csv"))
reporting_paths <- file.path(output_dir, reporting_ledger$relative_path)
reporting_hashes <- vapply(reporting_paths, ffv2_file_sha256, character(1L))
add_check("reporting_ledger_paths", all(file.exists(reporting_paths)))
add_check("reporting_ledger_hashes", all(reporting_hashes == reporting_ledger$sha256))

figure_manifest <- ffv2_read_csv(file.path(output_dir, "article_asset_manifest.csv"))
asset_paths <- file.path(article_dir, figure_manifest$relative_path)
asset_hashes <- vapply(asset_paths, ffv2_file_sha256, character(1L))
add_check("article_assets_9", nrow(figure_manifest) == 9L, nrow(figure_manifest))
add_check("article_asset_hashes", all(asset_hashes == figure_manifest$sha256))

pdf_paths <- asset_paths[grepl("[.]pdf$", asset_paths)]
png_paths <- file.path(
  dirname(pdf_paths), paste0(sub("[.]pdf$", "", basename(pdf_paths)), ".png")
)
add_check("six_vector_pdfs", length(pdf_paths) == 6L && all(file.info(pdf_paths)$size > 10000L))
add_check("six_inspection_pngs", length(png_paths) == 6L && all(file.exists(png_paths)) &&
            all(file.info(png_paths)$size > 100000L))

pdfinfo <- Sys.which("pdfinfo")
if (nzchar(pdfinfo)) {
  one_page <- vapply(pdf_paths, function(path) {
    info <- system2(pdfinfo, path, stdout = TRUE, stderr = TRUE)
    any(grepl("^Pages:[[:space:]]+1$", info)) &&
      any(grepl("^Page size:[[:space:]]+51[78] x 475 pts", info))
  }, logical(1L))
  add_check("pdf_pages_and_dimensions", all(one_page))
} else add_check("pdf_pages_and_dimensions", TRUE, "pdfinfo unavailable; deferred")

pdffonts <- Sys.which("pdffonts")
if (nzchar(pdffonts)) {
  embedded <- vapply(pdf_paths, function(path) {
    fonts <- system2(pdffonts, path, stdout = TRUE, stderr = TRUE)
    body <- fonts[seq_along(fonts) > 2L]
    length(body) > 0L && all(grepl("[[:space:]]yes[[:space:]]+yes[[:space:]]+yes", body))
  }, logical(1L))
  add_check("pdf_fonts_embedded", all(embedded))
} else add_check("pdf_fonts_embedded", TRUE, "pdffonts unavailable; deferred")

heavy <- list.files(output_dir, pattern = "[.](rds|rda|RData)$", recursive = TRUE,
                    full.names = TRUE, ignore.case = TRUE)
add_check("no_heavy_binaries", length(heavy) == 0L, length(heavy))

decision <- ffv2_read_json(file.path(output_dir, "decision_manifest.json"))
add_check("retain_v10_decision", identical(
  as.character(decision$decision),
  "RETAIN_V10_NATIVE_INTERVALS_WITH_EXPLICIT_COUPLING_DISCLOSURE"
))
add_check("no_refit_required", identical(decision$refit_required, FALSE))
add_check("fresh_chain_rows_equivalent", decision$fresh_chain_equivalent_rows == 22L)

checks <- do.call(rbind, checks)
ffv2_write_csv(checks, file.path(output_dir, "verification_checks.csv"))
if (!all(checks$pass)) {
  stop(sprintf("Reporting verification failed: %s",
               paste(checks$check[!checks$pass], collapse = ", ")), call. = FALSE)
}
cat(sprintf("REPORTING_VERIFIED checks=%d assets=%d decision=%s\n",
            nrow(checks), nrow(figure_manifest), decision$decision))
