#!/usr/bin/env Rscript

out_dir <- "tools/merge_reports"

tau_tag <- function(x) gsub("\\.", "p", sprintf("%.2f", as.numeric(x)))

families <- c("normal", "laplace", "gausmix")
taus <- c(0.05, 0.25, 0.95)
static_sizes <- c(100L, 1000L)
dynamic_sizes <- c(500L, 5000L)
priors <- c("ridge", "rhs")

make_root_id <- function(kind, family, tau, fit_size, prior = NA_character_) {
  size_part <- if (identical(kind, "dynamic")) {
    sprintf("lasttt_%d", as.integer(fit_size))
  } else {
    sprintf("tt_%d", as.integer(fit_size))
  }
  parts <- c("root", kind, family, paste0("tau_", tau_tag(tau)), size_part)
  if (!is.na(prior) && nzchar(prior) && !prior %in% c("paper", "default")) {
    parts <- c(parts, prior)
  }
  paste(parts, collapse = "__")
}

make_run_root <- function(kind, family, tau, fit_size, prior = NA_character_) {
  tau_dir <- paste0("tau_", tau_tag(tau))
  if (identical(kind, "static_paper")) {
    return(file.path(
      "results/function_testing_20260309_static_paper_family_qspec",
      family,
      tau_dir,
      sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
      sprintf("validation_paper_tt%d", as.integer(fit_size))
    ))
  }
  if (identical(kind, "static_shrink")) {
    return(file.path(
      "results/function_testing_20260309_static_shrinkage_family_qspec",
      family,
      tau_dir,
      sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
      sprintf("validation_shrink_%s_tt%d", prior, as.integer(fit_size))
    ))
  }
  file.path(
    "results/function_testing_20260309_dynamic_dlm_family_qspec",
    "dlm_constV_smallW",
    family,
    tau_dir,
    sprintf("fit_input_lastTT%d", as.integer(fit_size)),
    sprintf("validation_dynamic_tt%d", as.integer(fit_size))
  )
}

make_prepared_root <- function(kind, family, tau, fit_size) {
  tau_dir <- paste0("tau_", tau_tag(tau))
  if (identical(kind, "static_paper")) {
    return(file.path(
      "results/function_testing_20260309_static_paper_family_qspec",
      family,
      tau_dir,
      sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size))
    ))
  }
  if (identical(kind, "static_shrink")) {
    return(file.path(
      "results/function_testing_20260309_static_shrinkage_family_qspec",
      family,
      tau_dir,
      sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size))
    ))
  }
  file.path(
    "results/function_testing_20260309_dynamic_dlm_family_qspec",
    "dlm_constV_smallW",
    family,
    tau_dir,
    sprintf("fit_input_lastTT%d", as.integer(fit_size))
  )
}

make_shrink_compare_root <- function(family, tau, fit_size) {
  file.path(
    "results/function_testing_20260309_static_shrinkage_family_qspec",
    family,
    paste0("tau_", tau_tag(tau)),
    sprintf("fit_input_subsample_tt%d_x01_sorted", as.integer(fit_size)),
    "compare_ridge_vs_rhs_family_qspec"
  )
}

make_root_record <- function(kind, family, tau, fit_size, prior = NA_character_) {
  if (identical(kind, "dynamic")) {
    models <- c("dqlm", "exdqlm")
    pipeline_script <- "tools/merge_reports/20260305_vb_then_mcmc_pipeline.R"
    postprocess_script <- "tools/merge_reports/20260305_postprocess_from_existing_fits.R"
    report_script <- NA_character_
    fit_axis <- "lastTT"
    fit_label <- sprintf("lastTT=%d", as.integer(fit_size))
    prior_label <- "default"
  } else {
    models <- c("al", "exal")
    pipeline_script <- "tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R"
    postprocess_script <- "tools/merge_reports/20260305_static_postprocess_from_existing_fits.R"
    report_script <- "tools/merge_reports/20260305_static_vb_mcmc_report.R"
    fit_axis <- "TT"
    fit_label <- sprintf("TT=%d", as.integer(fit_size))
    prior_label <- if (identical(kind, "static_paper")) "paper" else prior
  }

  root_id <- make_root_id(kind, family, tau, fit_size, prior_label)
  model_task_ids <- paste0("mp__", root_id, "__", models)
  postprocess_task_id <- paste0("post__", root_id)
  review_task_id <- paste0("review__", root_id)
  if (identical(kind, "static_shrink")) {
    cross_root_barrier_id <- paste(
      c("compare", "static_shrink", family, paste0("tau_", tau_tag(tau)), sprintf("tt_%d", as.integer(fit_size))),
      collapse = "__"
    )
  } else if (identical(kind, "static_paper")) {
    cross_root_barrier_id <- sprintf("campaign__static_paper__family_%s", family)
  } else {
    cross_root_barrier_id <- sprintf("campaign__dynamic__family_%s", family)
  }

  data.frame(
    root_id = root_id,
    root_kind = kind,
    family = family,
    tau = sprintf("%.2f", as.numeric(tau)),
    fit_axis = fit_axis,
    fit_size = as.integer(fit_size),
    fit_label = fit_label,
    prior = prior_label,
    prepared_root = make_prepared_root(kind, family, tau, fit_size),
    run_root = make_run_root(kind, family, tau, fit_size, prior),
    model_a = models[1],
    model_b = models[2],
    model_path_task_a = model_task_ids[1],
    model_path_task_b = model_task_ids[2],
    pipeline_script = pipeline_script,
    postprocess_task_id = postprocess_task_id,
    postprocess_script = postprocess_script,
    review_task_id = review_task_id,
    review_script = if (is.na(report_script)) postprocess_script else paste(postprocess_script, report_script, sep = " + "),
    cross_root_barrier_id = cross_root_barrier_id,
    campaign_barrier_id = paste0("campaign__", kind),
    stringsAsFactors = FALSE
  )
}

root_rows <- list()

for (family in families) {
  for (tau in taus) {
    for (fit_size in static_sizes) {
      root_rows[[length(root_rows) + 1L]] <- make_root_record("static_paper", family, tau, fit_size)
    }
  }
}

for (family in families) {
  for (tau in taus) {
    for (fit_size in static_sizes) {
      for (prior in priors) {
        root_rows[[length(root_rows) + 1L]] <- make_root_record("static_shrink", family, tau, fit_size, prior)
      }
    }
  }
}

for (family in families) {
  for (tau in taus) {
    for (fit_size in dynamic_sizes) {
      root_rows[[length(root_rows) + 1L]] <- make_root_record("dynamic", family, tau, fit_size)
    }
  }
}

root_catalog <- do.call(rbind, root_rows)
root_catalog <- root_catalog[order(root_catalog$root_kind, root_catalog$family, root_catalog$tau, root_catalog$fit_size, root_catalog$prior), ]

model_manifest_rows <- lapply(seq_len(nrow(root_catalog)), function(i) {
  row <- root_catalog[i, , drop = FALSE]
  models <- c(row$model_a, row$model_b)
  task_ids <- c(row$model_path_task_a, row$model_path_task_b)
  data.frame(
    task_id = task_ids,
    task_type = "model_path",
    root_id = rep(row$root_id, 2),
    root_kind = rep(row$root_kind, 2),
    family = rep(row$family, 2),
    tau = rep(row$tau, 2),
    fit_axis = rep(row$fit_axis, 2),
    fit_size = rep(row$fit_size, 2),
    prior = rep(row$prior, 2),
    model = models,
    execution_plan = "vb_then_mcmc",
    slot_cost = 1L,
    threads_per_process = 1L,
    pipeline_script = rep(row$pipeline_script, 2),
    run_root = rep(row$run_root, 2),
    root_postprocess_task_id = rep(row$postprocess_task_id, 2),
    root_review_task_id = rep(row$review_task_id, 2),
    priority_band = ifelse(
      row$root_kind == "dynamic" & row$fit_size == 5000L, 1L,
      ifelse(
        row$root_kind == "dynamic" & row$fit_size == 500L, 2L,
        ifelse(row$fit_size == 1000L, 3L, 4L)
      )
    ),
    priority_reason = ifelse(
      row$root_kind == "dynamic" & row$fit_size == 5000L,
      "longest dynamic roots first",
      ifelse(
        row$root_kind == "dynamic" & row$fit_size == 500L,
        "second-wave dynamic roots",
        ifelse(row$fit_size == 1000L, "longer static roots before TT=100", "shortest static roots last")
      )
    ),
    stringsAsFactors = FALSE
  )
})
model_manifest <- do.call(rbind, model_manifest_rows)

postprocess_manifest <- data.frame(
  task_id = root_catalog$postprocess_task_id,
  task_type = "root_postprocess",
  root_id = root_catalog$root_id,
  root_kind = root_catalog$root_kind,
  family = root_catalog$family,
  tau = root_catalog$tau,
  fit_axis = root_catalog$fit_axis,
  fit_size = root_catalog$fit_size,
  prior = root_catalog$prior,
  slot_cost = 1L,
  threads_per_process = 1L,
  trigger_rule = "both_model_paths_done",
  postprocess_script = root_catalog$postprocess_script,
  review_task_id = root_catalog$review_task_id,
  stringsAsFactors = FALSE
)

edge_rows <- list()
add_edge <- function(parent_id, parent_type, child_id, child_type, role, kind = NA_character_, family = NA_character_, tau = NA_character_, fit_size = NA_integer_, prior = NA_character_) {
  edge_rows[[length(edge_rows) + 1L]] <<- data.frame(
    parent_task_id = parent_id,
    parent_task_type = parent_type,
    child_task_id = child_id,
    child_task_type = child_type,
    dependency_role = role,
    root_kind = kind,
    family = family,
    tau = tau,
    fit_size = fit_size,
    prior = prior,
    stringsAsFactors = FALSE
  )
}

for (i in seq_len(nrow(root_catalog))) {
  row <- root_catalog[i, ]
  add_edge(row$postprocess_task_id, "root_postprocess", row$model_path_task_a, "model_path", "requires_model_path_done", row$root_kind, row$family, row$tau, row$fit_size, row$prior)
  add_edge(row$postprocess_task_id, "root_postprocess", row$model_path_task_b, "model_path", "requires_model_path_done", row$root_kind, row$family, row$tau, row$fit_size, row$prior)
  add_edge(row$review_task_id, "root_review", row$postprocess_task_id, "root_postprocess", ifelse(row$root_kind == "dynamic", "requires_postprocess_done", "requires_postprocess_and_report_done"), row$root_kind, row$family, row$tau, row$fit_size, row$prior)
}

for (family in families) {
  for (tau in taus) {
    for (fit_size in static_sizes) {
      barrier_id <- paste(c("compare", "static_shrink", family, paste0("tau_", tau_tag(tau)), sprintf("tt_%d", fit_size)), collapse = "__")
      ridge_root_id <- make_root_id("static_shrink", family, tau, fit_size, "ridge")
      rhs_root_id <- make_root_id("static_shrink", family, tau, fit_size, "rhs")
      add_edge(barrier_id, "prior_compare", paste0("review__", ridge_root_id), "root_review", "requires_ridge_root_review_done", "static_shrink", family, sprintf("%.2f", tau), fit_size, "ridge")
      add_edge(barrier_id, "prior_compare", paste0("review__", rhs_root_id), "root_review", "requires_rhs_root_review_done", "static_shrink", family, sprintf("%.2f", tau), fit_size, "rhs")
    }
  }
}

for (i in seq_len(nrow(root_catalog[root_catalog$root_kind == "static_paper", ]))) {
  row <- root_catalog[root_catalog$root_kind == "static_paper", ][i, ]
  add_edge("campaign__static_paper", "campaign_review", row$review_task_id, "root_review", "requires_static_paper_root_review_done", row$root_kind, row$family, row$tau, row$fit_size, row$prior)
}

for (i in seq_len(nrow(root_catalog[root_catalog$root_kind == "static_shrink", ]))) {
  row <- root_catalog[root_catalog$root_kind == "static_shrink", ][i, ]
  add_edge("campaign__static_shrink", "campaign_review", row$review_task_id, "root_review", "requires_static_shrink_root_review_done", row$root_kind, row$family, row$tau, row$fit_size, row$prior)
}

for (family in families) {
  for (tau in taus) {
    for (fit_size in static_sizes) {
      barrier_id <- paste(c("compare", "static_shrink", family, paste0("tau_", tau_tag(tau)), sprintf("tt_%d", fit_size)), collapse = "__")
      add_edge("campaign__static_shrink", "campaign_review", barrier_id, "prior_compare", "requires_ridge_vs_rhs_compare_done", "static_shrink", family, sprintf("%.2f", tau), fit_size, "both")
    }
  }
}

for (i in seq_len(nrow(root_catalog[root_catalog$root_kind == "dynamic", ]))) {
  row <- root_catalog[root_catalog$root_kind == "dynamic", ][i, ]
  add_edge("campaign__dynamic", "campaign_review", row$review_task_id, "root_review", "requires_dynamic_root_review_done", row$root_kind, row$family, row$tau, row$fit_size, row$prior)
}

add_edge("campaign__global_cross_family_summary", "global_summary", "campaign__static_paper", "campaign_review", "requires_static_paper_campaign_review_done")
add_edge("campaign__global_cross_family_summary", "global_summary", "campaign__static_shrink", "campaign_review", "requires_static_shrink_campaign_review_done")
add_edge("campaign__global_cross_family_summary", "global_summary", "campaign__dynamic", "campaign_review", "requires_dynamic_campaign_review_done")

dependency_edges <- do.call(rbind, edge_rows)

barrier_rows <- list()
for (family in families) {
  for (tau in taus) {
    for (fit_size in static_sizes) {
      barrier_rows[[length(barrier_rows) + 1L]] <- data.frame(
        barrier_id = paste(c("compare", "static_shrink", family, paste0("tau_", tau_tag(tau)), sprintf("tt_%d", fit_size)), collapse = "__"),
        barrier_type = "prior_compare",
        root_kind = "static_shrink",
        family = family,
        tau = sprintf("%.2f", tau),
        fit_size = fit_size,
        prerequisite_count = 2L,
        implementation_status = "implemented",
        implementation_script = "tools/merge_reports/20260308_static_shrinkage_compare_report.R",
        prepared_root = make_prepared_root("static_shrink", family, tau, fit_size),
        compare_root = make_shrink_compare_root(family, tau, fit_size),
        output_table = "tables/rhs_vs_ridge_summary.csv",
        notes = "Requires both ridge and rhs root reviews for the same family/tau/TT slice.",
        stringsAsFactors = FALSE
      )
    }
  }
}

barrier_rows[[length(barrier_rows) + 1L]] <- data.frame(
  barrier_id = "campaign__static_paper",
  barrier_type = "campaign_review",
  root_kind = "static_paper",
  family = "all",
  tau = "all",
  fit_size = NA_integer_,
  prerequisite_count = 18L,
  implementation_status = "planned_not_standardized",
  implementation_script = NA_character_,
  prepared_root = NA_character_,
  compare_root = NA_character_,
  output_table = NA_character_,
  notes = "Should aggregate all static paper root reviews into campaign-level AL vs exAL, VB vs MCMC, and runtime comparisons.",
  stringsAsFactors = FALSE
)

barrier_rows[[length(barrier_rows) + 1L]] <- data.frame(
  barrier_id = "campaign__static_shrink",
  barrier_type = "campaign_review",
  root_kind = "static_shrink",
  family = "all",
  tau = "all",
  fit_size = NA_integer_,
  prerequisite_count = 54L,
  implementation_status = "partially_implemented",
  implementation_script = "tools/merge_reports/20260308_static_shrinkage_compare_report.R",
  prepared_root = NA_character_,
  compare_root = NA_character_,
  output_table = "tables/rhs_vs_ridge_summary.csv",
  notes = "Needs all 36 root reviews plus 18 ridge-vs-rhs compare outputs; only the per-slice prior compare layer is currently standardized.",
  stringsAsFactors = FALSE
)

barrier_rows[[length(barrier_rows) + 1L]] <- data.frame(
  barrier_id = "campaign__dynamic",
  barrier_type = "campaign_review",
  root_kind = "dynamic",
  family = "all",
  tau = "all",
  fit_size = NA_integer_,
  prerequisite_count = 18L,
  implementation_status = "planned_not_standardized",
  implementation_script = NA_character_,
  prepared_root = NA_character_,
  compare_root = NA_character_,
  output_table = NA_character_,
  notes = "Should aggregate all dynamic root reviews into campaign-level DQLM vs exDQLM, VB vs MCMC, and runtime comparisons.",
  stringsAsFactors = FALSE
)

barrier_rows[[length(barrier_rows) + 1L]] <- data.frame(
  barrier_id = "campaign__global_cross_family_summary",
  barrier_type = "global_summary",
  root_kind = "all",
  family = "all",
  tau = "all",
  fit_size = NA_integer_,
  prerequisite_count = 3L,
  implementation_status = "planned_not_standardized",
  implementation_script = NA_character_,
  prepared_root = NA_character_,
  compare_root = NA_character_,
  output_table = NA_character_,
  notes = "Final cross-family synthesis over the static paper, static shrink, and dynamic campaign reviews.",
  stringsAsFactors = FALSE
)

comparison_barriers <- do.call(rbind, barrier_rows)

tau_audit <- data.frame(
  file_path = c(
    "tools/merge_reports/20260308_static_shrinkage_compare_report.R",
    "tools/merge_reports/20260305_static_postprocess_from_existing_fits.R",
    "tools/merge_reports/20260305_static_vb_then_mcmc_pipeline.R",
    "tools/merge_reports/20260305_vb_then_mcmc_pipeline.R",
    "tools/merge_reports/20260308_run_static_simple_qspec_campaign.sh",
    "tools/merge_reports/20260308_run_static_shrinkage_qspec_campaign.sh",
    "tools/merge_reports/20260308_run_dynamic_dlm_qspec_campaign.sh",
    "tools/merge_reports/20260309_run_static_paper_family_qspec_campaign.sh",
    "tools/merge_reports/20260309_run_static_shrinkage_family_qspec_campaign.sh",
    "tools/merge_reports/20260309_run_dynamic_family_qspec_campaign.sh"
  ),
  scope = c(
    "static shrink higher-level compare",
    "static root-local postprocess",
    "static fresh pipeline fallback",
    "dynamic fresh pipeline fallback",
    "legacy generic qspec wrapper",
    "legacy generic qspec wrapper",
    "legacy generic qspec wrapper",
    "family-qspec dataset generator wrapper",
    "family-qspec dataset generator wrapper",
    "family-qspec dataset generator wrapper"
  ),
  tau_status = c(
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "fixed_to_family_qspec_grid",
    "already_on_family_qspec_grid",
    "already_on_family_qspec_grid",
    "already_on_family_qspec_grid"
  ),
  family_qspec_relevance = c(
    "direct",
    "direct",
    "direct",
    "direct",
    "adjacent",
    "adjacent",
    "adjacent",
    "direct",
    "direct",
    "direct"
  ),
  action_needed = c(
    "patched",
    "patched",
    "patched",
    "patched",
    "patched",
    "patched",
    "patched",
    "none",
    "none",
    "none"
  ),
  notes = c(
    "Now resolves tau set from the simulation truth when available and otherwise falls back to 0.05/0.25/0.95.",
    "Now prefers run_config taus, then sim$p, then 0.05/0.25/0.95.",
    "Default tau fallback now matches the canonical relaunch grid when the sim file does not provide taus.",
    "Default tau fallback now matches the canonical relaunch grid when the sim file does not provide taus.",
    "Wrapper default tau list updated even though the family-qspec launch path uses prepared-input discovery.",
    "Wrapper default tau list updated even though the family-qspec launch path uses prepared-input discovery.",
    "Wrapper default tau list updated even though the family-qspec launch path uses prepared-input discovery.",
    "Wrapper scope is now aligned to the family-qspec families normal/laplace/gausmix and the canonical tau grid 0.05/0.25/0.95.",
    "Wrapper scope is now aligned to the family-qspec families normal/laplace/gausmix and the canonical tau grid 0.05/0.25/0.95.",
    "Wrapper scope is now aligned to the family-qspec families normal/laplace/gausmix and the canonical tau grid 0.05/0.25/0.95."
  ),
  stringsAsFactors = FALSE
)

write.table(root_catalog, file.path(out_dir, "20260312_family_qspec_root_catalog.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
write.table(model_manifest, file.path(out_dir, "20260312_family_qspec_model_path_scheduler_manifest.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
write.table(postprocess_manifest, file.path(out_dir, "20260312_family_qspec_root_postprocess_manifest.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
write.table(dependency_edges, file.path(out_dir, "20260312_family_qspec_dependency_edges.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
write.table(comparison_barriers, file.path(out_dir, "20260312_family_qspec_comparison_barriers.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)
write.table(tau_audit, file.path(out_dir, "20260312_family_qspec_tau_adaptation_audit.tsv"), sep = "\t", row.names = FALSE, quote = FALSE)

cat("Wrote:\n")
cat(file.path(out_dir, "20260312_family_qspec_root_catalog.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_model_path_scheduler_manifest.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_root_postprocess_manifest.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_dependency_edges.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_comparison_barriers.tsv"), "\n")
cat(file.path(out_dir, "20260312_family_qspec_tau_adaptation_audit.tsv"), "\n")
