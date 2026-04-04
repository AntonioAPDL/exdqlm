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

safe_int <- function(x, default = NA_integer_) {
  v <- suppressWarnings(as.integer(x)[1])
  if (is.finite(v)) v else default
}

safe_num <- function(x, default = NA_real_) {
  v <- suppressWarnings(as.numeric(x)[1])
  if (is.finite(v)) v else default
}

extract_tt <- function(path) {
  m <- regexec("tt([0-9]+)", path)
  g <- regmatches(path, m)[[1]]
  if (length(g) >= 2L) safe_int(g[2]) else NA_integer_
}

resolve_candidate_path <- function(run_root, tau_label, variant_tag) {
  file.path(run_root, "fits", "mcmc", sprintf("mcmc_exal_tau_%s_fit_%s.rds", tau_label, variant_tag))
}

resolve_prior_templates <- function(df, fallback_label) {
  df$prior_template_exists <- file.exists(df$candidate_fit_path)
  df$prior_template_path <- NA_character_
  df$prior_template_source <- NA_character_

  if (all(df$prior_template_exists)) {
    df$prior_template_path <- normalizePath(df$candidate_fit_path, winslash = "/", mustWork = TRUE)
    df$prior_template_source <- "row_specific"
    return(df)
  }

  available <- df[df$prior_template_exists, c("family", "candidate_fit_path"), drop = FALSE]
  if (!nrow(available)) {
    stop(sprintf("no prior templates available for %s", fallback_label))
  }
  available <- available[!duplicated(available$family), , drop = FALSE]
  family_map <- setNames(available$candidate_fit_path, available$family)

  for (i in seq_len(nrow(df))) {
    if (isTRUE(df$prior_template_exists[i])) {
      df$prior_template_path[i] <- normalizePath(df$candidate_fit_path[i], winslash = "/", mustWork = TRUE)
      df$prior_template_source[i] <- "row_specific"
      next
    }
    fam <- df$family[i]
    fallback_path <- family_map[[fam]]
    if (is.null(fallback_path) || !nzchar(fallback_path) || !file.exists(fallback_path)) {
      stop(sprintf("missing family fallback prior template for %s family %s", fallback_label, fam))
    }
    df$prior_template_path[i] <- normalizePath(fallback_path, winslash = "/", mustWork = TRUE)
    df$prior_template_source[i] <- sprintf("family_fallback:%s", fam)
  }

  df
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
current_manifest_path <- as.character(args$current_manifest %||% file.path(
  out_dir, "LOCAL_targeted_manifest_current_static_rhsns_20260329.csv"
))
legacy_manifest_path <- as.character(args$legacy_manifest %||% file.path(
  out_dir, "LOCAL_targeted_manifest_legacy_rhs_refresh_20260329.csv"
))

for (path in c(current_manifest_path, legacy_manifest_path)) {
  if (!file.exists(path)) stop(sprintf("manifest not found: %s", path))
}

current_variant_tag <- "static_exal_f080_sub2_s105_rhsns_current_20260403"
legacy_variant_tag <- "static_exal_f080_sub2_s105_rhs_legacy_20260403"

load_slice <- function(path, scope_label, variant_tag, expected_prior_override, seed_offset) {
  x <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  x <- x[x$inference == "mcmc" & x$model == "exal", , drop = FALSE]
  if (!nrow(x)) stop(sprintf("no exal/mcmc rows in %s", path))
  x$scope_label <- scope_label
  x$variant_tag <- variant_tag
  x$expected_prior_override <- expected_prior_override
  x$gamma_substeps <- 2L
  x$p_global_eta_jump <- 0.08
  x$global_eta_jump_scale <- 1.05
  x$mh_proposal <- "laplace_rw"
  x$seed_refresh <- seed_offset + as.integer(x$row_id)
  x$tt <- vapply(x$run_root, extract_tt, integer(1))
  x$p0 <- vapply(x$tau, safe_num, numeric(1))
  x <- resolve_prior_templates(x, fallback_label = scope_label)
  x$mcmc_base_path <- normalizePath(x$baseline_fit_path, winslash = "/", mustWork = TRUE)
  x$run_config_path <- normalizePath(x$run_config_path, winslash = "/", mustWork = TRUE)
  x$candidate_refresh_path <- mapply(resolve_candidate_path, x$run_root, x$tau_label, x$variant_tag, USE.NAMES = FALSE)
  x
}

current <- load_slice(
  current_manifest_path,
  scope_label = "current_rhsns_refresh",
  variant_tag = current_variant_tag,
  expected_prior_override = "rhs_ns",
  seed_offset = 2026040300L
)
legacy <- load_slice(
  legacy_manifest_path,
  scope_label = "legacy_rhs_refresh",
  variant_tag = legacy_variant_tag,
  expected_prior_override = "rhs",
  seed_offset = 2026041300L
)

schedule <- rbind(
  current[, c(
    "scope_label", "row_id", "run_root", "root_kind", "family", "tt", "tau",
    "tau_label", "prior", "prior_override", "expected_prior_override",
    "variant_tag", "gamma_substeps", "p_global_eta_jump",
    "global_eta_jump_scale", "mh_proposal", "seed_refresh",
    "mcmc_base_path", "run_config_path", "prior_template_path",
    "prior_template_source",
    "candidate_refresh_path", "scope", "prepared_tag", "source_row_id"
  )],
  legacy[, c(
    "scope_label", "row_id", "run_root", "root_kind", "family", "tt", "tau",
    "tau_label", "prior", "prior_override", "expected_prior_override",
    "variant_tag", "gamma_substeps", "p_global_eta_jump",
    "global_eta_jump_scale", "mh_proposal", "seed_refresh",
    "mcmc_base_path", "run_config_path", "prior_template_path",
    "prior_template_source",
    "candidate_refresh_path", "scope", "prepared_tag", "source_row_id"
  )]
)

schedule$refresh_key <- paste(schedule$scope_label, schedule$row_id, sep = "::")
schedule <- schedule[order(schedule$scope_label, schedule$row_id), , drop = FALSE]

if (nrow(schedule) != 72L) {
  stop(sprintf("expected 72 refresh rows, found %d", nrow(schedule)))
}
if (sum(schedule$scope_label == "current_rhsns_refresh") != 54L) {
  stop("expected 54 current rhsns rows")
}
if (sum(schedule$scope_label == "legacy_rhs_refresh") != 18L) {
  stop("expected 18 legacy rhs rows")
}
if (any(!file.exists(schedule$prior_template_path))) {
  stop("one or more prior_template_path files are missing")
}

config <- unique(schedule[, c(
  "scope_label", "variant_tag", "expected_prior_override", "gamma_substeps",
  "p_global_eta_jump", "global_eta_jump_scale", "mh_proposal"
), drop = FALSE])

scope_counts <- as.data.frame(table(schedule$scope_label), stringsAsFactors = FALSE)
names(scope_counts) <- c("scope_label", "n_rows")

schedule_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_schedule_20260403.csv")
config_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_config_20260403.csv")
scope_path <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_scope_counts_20260403.csv")
rows_tsv <- file.path(out_dir, "LOCAL_static_exal_f080s105_refresh_rows_20260403.tsv")

utils::write.csv(schedule, schedule_path, row.names = FALSE)
utils::write.csv(config, config_path, row.names = FALSE)
utils::write.csv(scope_counts, scope_path, row.names = FALSE)
utils::write.table(
  schedule[, c(
    "scope_label", "row_id", "run_root", "root_kind", "family", "tt", "tau_label",
    "variant_tag", "gamma_substeps", "p_global_eta_jump", "global_eta_jump_scale",
    "seed_refresh", "mcmc_base_path", "run_config_path", "prior_template_path",
    "expected_prior_override", "candidate_refresh_path"
  )],
  rows_tsv,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE
)

cat(sprintf("config: %s\n", config_path))
cat(sprintf("scope_counts: %s\n", scope_path))
cat(sprintf("schedule: %s\n", schedule_path))
cat(sprintf("rows_tsv: %s\n", rows_tsv))
