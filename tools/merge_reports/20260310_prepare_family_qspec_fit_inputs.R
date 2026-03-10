#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tools)
})

source("tools/merge_reports/20260308_quantile_specific_sim_helpers.R")

inventory_path <- "tools/merge_reports/20260309_family_qspec_dataset_inventory.csv"
if (!file.exists(inventory_path)) {
  stop("Missing inventory: ", inventory_path)
}

inv <- read.csv(inventory_path, stringsAsFactors = FALSE)
if (!nrow(inv)) stop("Inventory is empty: ", inventory_path)

static_targets <- safe_num_vec(Sys.getenv("EXDQLM_PREP_STATIC_T_LIST", "100,1000"),
                               default = c(100, 1000))
dynamic_targets <- safe_num_vec(Sys.getenv("EXDQLM_PREP_DYNAMIC_T_LIST", "500,5000"),
                                default = c(500, 5000))

static_targets <- as.integer(unique(static_targets[is.finite(static_targets) & static_targets > 0]))
dynamic_targets <- as.integer(unique(dynamic_targets[is.finite(dynamic_targets) & dynamic_targets > 0]))

base_rows <- inv[
  inv$has_sim &
    !grepl("fit_input_", inv$sim_root, fixed = TRUE) &
    inv$scenario %in% c("static_paper", "static_shrink", "dynamic"),
, drop = FALSE]

if (!nrow(base_rows)) stop("No base sim roots found in inventory.")

write_static_subsets <- function(root, targets) {
  sim_path <- file.path(root, "sim_output.rds")
  wide_path <- file.path(root, "series_wide.csv")
  long_path <- file.path(root, "series_long.csv")
  if (!file.exists(sim_path) || !file.exists(wide_path)) return(character())

  sim_output <- readRDS(sim_path)
  series_wide <- read.csv(wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  series_long <- if (file.exists(long_path)) {
    read.csv(long_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    NULL
  }
  if (!"x_main" %in% names(series_wide)) stop("series_wide.csv missing x_main: ", root)
  n_total <- nrow(series_wide)
  targets <- sort(unique(as.integer(targets[targets <= n_total])))
  out <- character()
  for (target_n in targets) {
    sub_root <- file.path(root, sprintf("fit_input_subsample_tt%d_x01_sorted", target_n))
    if (!file.exists(file.path(sub_root, "sim_output.rds"))) {
      out <- c(out, write_quantile_specific_subsample(
        sim_output = sim_output,
        out_root = root,
        target_n = target_n,
        order_key = series_wide$x_main,
        sub_label = "x01_sorted",
        series_wide = series_wide,
        series_long = series_long,
        extra_files = c("coef_truth.csv", "true_quantile_grid.csv")
      ))
    } else {
      out <- c(out, sub_root)
    }
  }
  out
}

write_dynamic_subsets <- function(root, targets) {
  sim_path <- file.path(root, "sim_output.rds")
  wide_path <- file.path(root, "series_wide.csv")
  long_path <- file.path(root, "series_long.csv")
  if (!file.exists(sim_path) || !file.exists(wide_path)) return(character())

  sim_output <- readRDS(sim_path)
  series_wide <- read.csv(wide_path, stringsAsFactors = FALSE, check.names = FALSE)
  series_long <- if (file.exists(long_path)) {
    read.csv(long_path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    NULL
  }
  n_total <- nrow(series_wide)
  targets <- sort(unique(as.integer(targets[targets <= n_total])))
  existing <- paste0("fit_input_lastTT", targets)
  missing_targets <- targets[!file.exists(file.path(root, existing, "sim_output.rds"))]
  if (!length(missing_targets)) {
    return(file.path(root, existing))
  }
  out <- write_dynamic_tail_subsets(
    sim_output = sim_output,
    out_root = root,
    target_n_values = missing_targets,
    series_wide = series_wide,
    series_long = series_long,
    extra_files = c("true_quantile_grid.csv")
  )
  c(file.path(root, paste0("fit_input_lastTT", targets)))
}

prepared <- list()
for (ii in seq_len(nrow(base_rows))) {
  root <- base_rows$sim_root[ii]
  scenario <- base_rows$scenario[ii]
  if (scenario %in% c("static_paper", "static_shrink")) {
    prepared[[root]] <- write_static_subsets(root, static_targets)
  } else if (scenario == "dynamic") {
    prepared[[root]] <- write_dynamic_subsets(root, dynamic_targets)
  }
}

summary_rows <- do.call(rbind, lapply(names(prepared), function(root) {
  subs <- prepared[[root]]
  if (!length(subs)) {
    data.frame(sim_root = root, prepared_root = NA_character_, stringsAsFactors = FALSE)
  } else {
    data.frame(sim_root = root, prepared_root = subs, stringsAsFactors = FALSE)
  }
}))

out_csv <- "tools/merge_reports/20260310_family_qspec_prepared_fit_inputs.csv"
write.csv(summary_rows, out_csv, row.names = FALSE)
cat("Prepared family qspec fit inputs written to:\n")
cat(out_csv, "\n")
