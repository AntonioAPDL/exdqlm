# Parsing helpers for Monash TSF files and the official M4 files.

bench_normalize_frequency_label <- function(x) {
  if (is.null(x) || !length(x) || is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }

  key <- tolower(trimws(x))
  key <- gsub("[[:space:]-]+", "_", key)

  aliases <- c(
    "yearly" = "yearly",
    "annual" = "yearly",
    "quarterly" = "quarterly",
    "monthly" = "monthly",
    "weekly" = "weekly",
    "daily" = "daily",
    "hourly" = "hourly",
    "half_hourly" = "half_hourly",
    "halfhourly" = "half_hourly",
    "10_minutes" = "10_minutes",
    "10_mins" = "10_minutes",
    "ten_minutes" = "10_minutes"
  )

  aliases[[key]] %||% key
}

bench_parse_timestamp_value <- function(x) {
  if (is.null(x) || !length(x) || is.na(x) || !nzchar(trimws(x))) {
    return(as.POSIXct(NA))
  }

  value <- trimws(x)
  formats <- c(
    "%Y-%m-%d %H-%M-%S",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
    "%d-%m-%y %H:%M",
    "%d-%m-%Y %H:%M",
    "%d-%m-%y",
    "%d-%m-%Y"
  )

  for (fmt in formats) {
    parsed <- as.POSIXct(value, format = fmt, tz = "UTC")
    if (!is.na(parsed)) {
      return(parsed)
    }
  }

  as.POSIXct(NA)
}

bench_format_timestamp_vector <- function(x) {
  if (!length(x)) {
    return(character())
  }

  if (inherits(x, "Date")) {
    return(as.character(x))
  }

  format(as.POSIXct(x, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC", usetz = FALSE)
}

bench_make_timestamp_sequence <- function(start_value, n, frequency_label) {
  if (!n || is.na(n) || n <= 0) {
    return(character())
  }

  freq <- bench_normalize_frequency_label(frequency_label)
  start_ts <- bench_parse_timestamp_value(start_value)
  if (is.na(start_ts)) {
    return(rep(NA_character_, n))
  }

  if (freq %in% c("yearly", "quarterly", "monthly", "weekly", "daily")) {
    start_date <- as.Date(start_ts)
    by_value <- switch(
      freq,
      yearly = "year",
      quarterly = "quarter",
      monthly = "month",
      weekly = "week",
      daily = "day"
    )
    return(as.character(seq.Date(start_date, by = by_value, length.out = n)))
  }

  by_value <- switch(
    freq,
    hourly = "hour",
    half_hourly = "30 mins",
    `10_minutes` = "10 mins",
    stop(sprintf("Unsupported timestamp frequency: %s", frequency_label), call. = FALSE)
  )

  bench_format_timestamp_vector(seq.POSIXt(start_ts, by = by_value, length.out = n))
}

bench_cast_tsf_attribute <- function(values, type, field_name) {
  type_key <- tolower(trimws(type))
  out <- trimws(values)

  if (type_key == "numeric") {
    numeric_out <- suppressWarnings(as.numeric(out))
    bad <- is.na(numeric_out) & nzchar(out)
    if (any(bad)) {
      stop(
        sprintf(
          "Could not parse numeric TSF attribute '%s' for values: %s",
          field_name,
          paste(unique(out[bad]), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    return(numeric_out)
  }

  out
}

bench_parse_tsf_file <- function(path) {
  bench_assert_packages("data.table")

  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- iconv(lines, from = "", to = "UTF-8", sub = "byte")
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]

  data_idx <- which(tolower(lines) == "@data")
  if (!length(data_idx)) {
    stop(sprintf("TSF file %s does not contain an @data marker.", path), call. = FALSE)
  }

  header_lines <- lines[seq_len(data_idx[[1L]] - 1L)]
  data_lines <- lines[(data_idx[[1L]] + 1L):length(lines)]
  data_lines <- data_lines[nzchar(data_lines)]

  attribute_lines <- header_lines[grepl("^@attribute\\s+", tolower(header_lines))]
  attribute_spec <- lapply(attribute_lines, function(line) {
    payload <- sub("^@attribute\\s+", "", line, ignore.case = TRUE)
    parts <- strsplit(payload, "\\s+")[[1L]]
    if (length(parts) < 2L) {
      stop(sprintf("Malformed TSF attribute line: %s", line), call. = FALSE)
    }
    list(name = parts[[1L]], type = parts[[2L]])
  })

  globals <- list(
    relation = NA_character_,
    frequency = NA_character_,
    horizon = NA_real_,
    missing = NA,
    equallength = NA
  )

  for (line in header_lines) {
    lower <- tolower(line)
    if (startsWith(lower, "@relation")) {
      globals$relation <- trimws(sub("^@relation\\s+", "", line, ignore.case = TRUE))
    } else if (startsWith(lower, "@frequency")) {
      globals$frequency <- trimws(sub("^@frequency\\s+", "", line, ignore.case = TRUE))
    } else if (startsWith(lower, "@horizon")) {
      globals$horizon <- suppressWarnings(as.numeric(trimws(sub("^@horizon\\s+", "", line, ignore.case = TRUE))))
    } else if (startsWith(lower, "@missing")) {
      globals$missing <- identical(tolower(trimws(sub("^@missing\\s+", "", line, ignore.case = TRUE))), "true")
    } else if (startsWith(lower, "@equallength")) {
      globals$equallength <- identical(tolower(trimws(sub("^@equallength\\s+", "", line, ignore.case = TRUE))), "true")
    }
  }

  attr_names <- vapply(attribute_spec, `[[`, character(1), "name")
  attr_types <- vapply(attribute_spec, `[[`, character(1), "type")
  n_attr <- length(attr_names)

  meta_rows <- vector("list", length(data_lines))
  panel_rows <- vector("list", length(data_lines))

  for (idx in seq_along(data_lines)) {
    line <- data_lines[[idx]]
    pieces <- strsplit(line, ":", fixed = TRUE)[[1L]]
    if (length(pieces) < (n_attr + 1L)) {
      stop(
        sprintf(
          "Malformed TSF row %d in %s: expected at least %d colon-separated fields, found %d.",
          idx,
          path,
          n_attr + 1L,
          length(pieces)
        ),
        call. = FALSE
      )
    }

    attr_values <- pieces[seq_len(n_attr)]
    series_blob <- paste(pieces[(n_attr + 1L):length(pieces)], collapse = ":")
    series_tokens <- strsplit(series_blob, ",", fixed = TRUE)[[1L]]
    numeric_tokens <- ifelse(series_tokens %in% c("?", "", "NA"), NA_character_, series_tokens)
    series_values <- suppressWarnings(as.numeric(numeric_tokens))
    bad_tokens <- is.na(series_values) & !is.na(numeric_tokens)
    if (any(bad_tokens)) {
      stop(
        sprintf(
          "Could not parse TSF series row %d in %s. Bad values: %s",
          idx,
          path,
          paste(unique(series_tokens[bad_tokens]), collapse = ", ")
        ),
        call. = FALSE
      )
    }

    meta_rows[[idx]] <- as.list(attr_values)
    names(meta_rows[[idx]]) <- attr_names
    meta_rows[[idx]]$tsf_row_id <- idx

    panel_rows[[idx]] <- data.table::data.table(
      tsf_row_id = idx,
      t_index = seq_along(series_values),
      y = series_values
    )
  }

  meta_dt <- data.table::rbindlist(meta_rows, fill = TRUE)
  for (j in seq_along(attr_names)) {
    data.table::set(meta_dt, j = attr_names[[j]], value = bench_cast_tsf_attribute(meta_dt[[attr_names[[j]]]], attr_types[[j]], attr_names[[j]]))
  }

  list(
    header = globals,
    attributes = data.table::data.table(name = attr_names, type = attr_types),
    series_attributes = meta_dt,
    panel = data.table::rbindlist(panel_rows, fill = TRUE)
  )
}

bench_parse_m4_info <- function(path) {
  info_dt <- data.table::fread(path, na.strings = c("", "NA"))
  data.table::setnames(info_dt, old = names(info_dt), new = c("series_id", "category", "frequency_value", "forecast_horizon", "sp_label", "starting_date"))
  info_dt[]
}
