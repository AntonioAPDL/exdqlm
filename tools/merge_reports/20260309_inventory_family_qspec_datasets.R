#!/usr/bin/env Rscript
base_root <- 'results'
roots <- c(
  static_paper = file.path(base_root, 'function_testing_20260309_static_paper_family_qspec'),
  static_shrink = file.path(base_root, 'function_testing_20260309_static_shrinkage_family_qspec'),
  dynamic = file.path(base_root, 'function_testing_20260309_dynamic_dlm_family_qspec')
)
rows <- list()
for (scenario in names(roots)) {
  root <- roots[[scenario]]
  if (!dir.exists(root)) next
  sim_files <- list.files(root, pattern = 'sim_output\\.rds$', recursive = TRUE, full.names = TRUE)
  for (f in sim_files) {
    rel <- sub(paste0('^', root, '/?'), '', f)
    validation_csv <- file.path(dirname(f), 'validation.csv')
    validation_txt <- file.path(dirname(f), 'validation.txt')
    rows[[length(rows)+1L]] <- data.frame(
      scenario = scenario,
      sim_root = dirname(f),
      rel_path = rel,
      has_sim = file.exists(f),
      has_validation_csv = file.exists(validation_csv),
      has_validation_txt = file.exists(validation_txt),
      stringsAsFactors = FALSE
    )
  }
}
out <- if (length(rows)) do.call(rbind, rows) else data.frame()
out_root <- 'tools/merge_reports'
out_file <- file.path(out_root, '20260309_family_qspec_dataset_inventory.csv')
write.csv(out, out_file, row.names = FALSE)
cat(sprintf('Wrote %s\n', out_file))
