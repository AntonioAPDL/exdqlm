# Download helpers for benchmark source data.

bench_fetch_json <- function(url) {
  bench_assert_packages("jsonlite")

  tryCatch(
    jsonlite::fromJSON(url, simplifyVector = FALSE),
    error = function(e) {
      stop(sprintf("Failed to fetch JSON from %s: %s", url, conditionMessage(e)), call. = FALSE)
    }
  )
}

bench_download_to_path <- function(url, dest_path, timeout_sec = 600, user_agent = NULL) {
  dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)

  old_timeout <- getOption("timeout")
  old_agent <- getOption("HTTPUserAgent")
  on.exit(options(timeout = old_timeout, HTTPUserAgent = old_agent), add = TRUE)

  options(timeout = timeout_sec)
  if (!is.null(user_agent) && nzchar(user_agent)) {
    options(HTTPUserAgent = user_agent)
  }

  utils::download.file(
    url = url,
    destfile = dest_path,
    mode = "wb",
    quiet = TRUE,
    method = "libcurl"
  )

  if (!file.exists(dest_path) || !isTRUE(file.info(dest_path)$size > 0)) {
    stop(sprintf("Download completed but no file was written at %s", dest_path), call. = FALSE)
  }

  invisible(dest_path)
}

bench_match_zenodo_file <- function(record, file_name) {
  files <- record$files %||% list()
  if (!length(files)) {
    stop("Zenodo record contains no downloadable files.", call. = FALSE)
  }

  keys <- vapply(files, function(x) x$key %||% NA_character_, character(1))
  idx <- match(file_name, keys)
  if (is.na(idx)) {
    stop(
      sprintf("Zenodo record is missing expected file '%s'.", file_name),
      call. = FALSE
    )
  }

  files[[idx]]
}

bench_resolve_monash_source <- function(dataset_spec) {
  api_url <- sprintf("https://zenodo.org/api/records/%s", dataset_spec$record_id)
  record <- bench_fetch_json(api_url)
  matched <- bench_match_zenodo_file(record, dataset_spec$file_name)

  checksum <- matched$checksum %||% NA_character_
  size_bytes <- matched$size %||% NA_real_
  download_url <- matched$links$self %||% matched$links$content %||% NA_character_

  if (!nzchar(download_url)) {
    stop(
      sprintf("Could not resolve a direct download URL for Monash dataset '%s'.", dataset_spec$dataset),
      call. = FALSE
    )
  }

  list(
    source_url = download_url,
    checksum = checksum,
    size_bytes = size_bytes,
    api_url = api_url,
    record_url = dataset_spec$record_url %||% NA_character_
  )
}

bench_expected_md5 <- function(upstream_checksum) {
  if (is.null(upstream_checksum) || !nzchar(upstream_checksum)) {
    return(NA_character_)
  }

  parts <- strsplit(upstream_checksum, ":", fixed = TRUE)[[1L]]
  if (length(parts) == 2L && identical(tolower(parts[[1L]]), "md5")) {
    return(parts[[2L]])
  }

  upstream_checksum
}

bench_build_download_record <- function(
  dataset,
  source_family,
  component,
  source_url,
  source_record_url,
  local_path,
  upstream_checksum = NA_character_,
  size_bytes = NA_real_,
  status = "downloaded",
  notes = NA_character_,
  downloaded_at = Sys.time()
) {
  file_md5 <- bench_md5(local_path)
  expected_md5 <- bench_expected_md5(upstream_checksum)
  if (!is.na(expected_md5) && nzchar(expected_md5) && !identical(tolower(file_md5), tolower(expected_md5))) {
    stop(
      sprintf(
        "Checksum mismatch for %s (%s): expected md5 %s but found %s.",
        dataset,
        basename(local_path),
        expected_md5,
        file_md5
      ),
      call. = FALSE
    )
  }

  list(
    dataset = dataset,
    source_family = source_family,
    component = component,
    source_url = source_url,
    source_record_url = source_record_url,
    local_path = local_path,
    local_path_relative = bench_rel_path(local_path),
    file_size_bytes = unname(file.info(local_path)$size %||% size_bytes),
    md5 = file_md5,
    sha256 = bench_sha256(local_path),
    upstream_checksum = upstream_checksum,
    downloaded_at_utc = bench_timestamp_utc(downloaded_at),
    status = status,
    notes = notes
  )
}

bench_download_once <- function(
  dataset,
  source_family,
  component,
  source_url,
  source_record_url,
  dest_path,
  upstream_checksum = NA_character_,
  timeout_sec = 600,
  user_agent = NULL,
  overwrite = FALSE,
  notes = NA_character_
) {
  status <- if (file.exists(dest_path)) "skipped_existing" else "downloaded"

  if (!file.exists(dest_path) || isTRUE(overwrite)) {
    tmp_path <- tempfile(tmpdir = dirname(dest_path), fileext = ".download")
    on.exit(unlink(tmp_path), add = TRUE)

    bench_download_to_path(
      url = source_url,
      dest_path = tmp_path,
      timeout_sec = timeout_sec,
      user_agent = user_agent
    )

    dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
    ok <- file.rename(tmp_path, dest_path)
    if (!ok) {
      file.copy(tmp_path, dest_path, overwrite = TRUE)
      unlink(tmp_path)
    }

    status <- if (file.exists(dest_path) && status == "skipped_existing") "re_downloaded" else "downloaded"
  }

  bench_build_download_record(
    dataset = dataset,
    source_family = source_family,
    component = component,
    source_url = source_url,
    source_record_url = source_record_url,
    local_path = dest_path,
    upstream_checksum = upstream_checksum,
    status = status,
    notes = notes
  )
}

bench_extract_zip_member <- function(zip_path, member, out_path) {
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  extracted <- utils::unzip(zip_path, files = member, exdir = dirname(out_path))
  if (!length(extracted)) {
    stop(sprintf("Archive %s does not contain member %s.", zip_path, member), call. = FALSE)
  }

  extracted_path <- normalizePath(extracted[[1L]], mustWork = TRUE)
  if (!identical(normalizePath(out_path, mustWork = FALSE), extracted_path)) {
    ok <- file.rename(extracted_path, out_path)
    if (!ok) {
      file.copy(extracted_path, out_path, overwrite = TRUE)
      unlink(extracted_path)
    }
  }

  if (!file.exists(out_path)) {
    stop(sprintf("Failed to extract %s from %s.", member, zip_path), call. = FALSE)
  }

  out_path
}

bench_download_monash_dataset <- function(dataset_spec, cfg, paths, overwrite = FALSE) {
  resolved <- bench_resolve_monash_source(dataset_spec)
  dataset_dir <- file.path(paths$raw_monash, dataset_spec$dataset)
  dir.create(dataset_dir, recursive = TRUE, showWarnings = FALSE)

  zip_path <- file.path(dataset_dir, dataset_spec$file_name)
  tsf_path <- file.path(dataset_dir, dataset_spec$archive_member)

  archive_record <- bench_download_once(
    dataset = dataset_spec$dataset,
    source_family = "monash",
    component = "archive",
    source_url = resolved$source_url,
    source_record_url = resolved$record_url,
    dest_path = zip_path,
    upstream_checksum = resolved$checksum,
    timeout_sec = cfg$download$timeout_sec %||% 600,
    user_agent = cfg$download$user_agent %||% NULL,
    overwrite = overwrite,
    notes = dataset_spec$notes %||% NA_character_
  )

  if (!file.exists(tsf_path) || isTRUE(overwrite)) {
    bench_extract_zip_member(zip_path, dataset_spec$archive_member, tsf_path)
  }

  member_record <- bench_build_download_record(
    dataset = dataset_spec$dataset,
    source_family = "monash",
    component = "archive_member",
    source_url = resolved$source_url,
    source_record_url = resolved$record_url,
    local_path = tsf_path,
    upstream_checksum = NA_character_,
    status = if (archive_record$status %in% c("downloaded", "re_downloaded")) "extracted" else "verified_existing",
    notes = sprintf("Extracted member %s from %s.", dataset_spec$archive_member, dataset_spec$file_name)
  )

  list(archive = archive_record, member = member_record)
}

bench_download_m4_frequency <- function(freq_name, freq_spec, cfg, paths, overwrite = FALSE) {
  freq_dir <- file.path(paths$raw_m4, freq_name)
  dir.create(freq_dir, recursive = TRUE, showWarnings = FALSE)

  train_path <- file.path(freq_dir, basename(freq_spec$train_url))
  test_path <- file.path(freq_dir, basename(freq_spec$test_url))

  train_record <- bench_download_once(
    dataset = freq_spec$dataset,
    source_family = "m4",
    component = "train",
    source_url = freq_spec$train_url,
    source_record_url = "https://github.com/Mcompetitions/M4-methods",
    dest_path = train_path,
    upstream_checksum = NA_character_,
    timeout_sec = cfg$download$timeout_sec %||% 600,
    user_agent = cfg$download$user_agent %||% NULL,
    overwrite = overwrite,
    notes = sprintf("Official M4 training split for %s.", freq_name)
  )

  test_record <- bench_download_once(
    dataset = freq_spec$dataset,
    source_family = "m4",
    component = "test",
    source_url = freq_spec$test_url,
    source_record_url = "https://github.com/Mcompetitions/M4-methods",
    dest_path = test_path,
    upstream_checksum = NA_character_,
    timeout_sec = cfg$download$timeout_sec %||% 600,
    user_agent = cfg$download$user_agent %||% NULL,
    overwrite = overwrite,
    notes = sprintf("Official M4 test split for %s.", freq_name)
  )

  list(train = train_record, test = test_record)
}

bench_download_m4_info <- function(info_spec, cfg, paths, overwrite = FALSE) {
  info_dir <- file.path(paths$raw_m4, "metadata")
  dir.create(info_dir, recursive = TRUE, showWarnings = FALSE)

  bench_download_once(
    dataset = "m4_info",
    source_family = "m4",
    component = "info",
    source_url = info_spec$source_url,
    source_record_url = "https://github.com/Mcompetitions/M4-methods",
    dest_path = file.path(info_dir, info_spec$file_name),
    upstream_checksum = NA_character_,
    timeout_sec = cfg$download$timeout_sec %||% 600,
    user_agent = cfg$download$user_agent %||% NULL,
    overwrite = overwrite,
    notes = "Official M4 metadata file."
  )
}

bench_records_to_table <- function(records) {
  if (!length(records)) {
    return(data.frame())
  }

  rows <- lapply(records, function(record) {
    as.data.frame(record, stringsAsFactors = FALSE)
  })

  data.table::rbindlist(rows, fill = TRUE)
}

bench_write_download_manifest <- function(records, paths, cfg, registry, git_info) {
  table <- bench_records_to_table(records)

  summary_path <- file.path(paths$manifests_dir, "download_manifest")
  bench_save_table(
    x = table,
    path_stub = summary_path,
    write_csv = TRUE,
    write_rds = TRUE,
    compress = cfg$processing$compress %||% "gzip"
  )

  bench_write_json(
    list(
      generated_at_utc = bench_timestamp_utc(),
      git = git_info,
      config = cfg,
      registry_version = registry$registry_version %||% NA_integer_,
      records = records
    ),
    file.path(paths$manifests_dir, "download_manifest.json")
  )

  invisible(table)
}

bench_download_benchmarks <- function(config_path = NULL, overwrite = FALSE, source_families = c("monash", "m4")) {
  context <- bench_read_pipeline_config(config_path = config_path)
  cfg <- context$config
  registry <- context$registry
  paths <- context$paths

  bench_assert_packages(bench_required_packages("download"))
  bench_ensure_directories(paths)

  selected_families <- unique(tolower(source_families))
  all_records <- list()

  if ("monash" %in% selected_families) {
    for (dataset_id in registry$monash$default_selection) {
      spec <- registry$monash$datasets[[dataset_id]]
      download_records <- bench_download_monash_dataset(spec, cfg = cfg, paths = paths, overwrite = overwrite)
      all_records <- c(all_records, unname(download_records))
    }
  }

  if ("m4" %in% selected_families) {
    info_record <- bench_download_m4_info(registry$m4$info, cfg = cfg, paths = paths, overwrite = overwrite)
    all_records <- c(all_records, list(info_record))

    for (freq_name in registry$m4$default_selection) {
      spec <- registry$m4$frequencies[[freq_name]]
      download_records <- bench_download_m4_frequency(freq_name, spec, cfg = cfg, paths = paths, overwrite = overwrite)
      all_records <- c(all_records, unname(download_records))
    }
  }

  manifest_table <- bench_write_download_manifest(
    records = all_records,
    paths = paths,
    cfg = cfg,
    registry = registry,
    git_info = context$git
  )

  invisible(list(
    manifest = manifest_table,
    config = cfg,
    registry = registry,
    paths = paths
  ))
}
