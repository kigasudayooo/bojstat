#' Retrieve Time-Series Data by Series Codes (Code API)
#'
#' Fetches time-series statistical data from the BOJ Time-Series Data Search
#' by specifying series codes directly.
#'
#' @param db Character. Database name (e.g. `"FM08"`, `"CO"`, `"PR01"`).
#'   See [boj_db_names] for all available DBs.
#' @param codes Character vector of series codes (up to 250 per request).
#'   **Note**: Do NOT include the DB prefix. Use `"MADR1Z@D"`, not
#'   `"IR01'MADR1Z@D"`. All codes must share the same frequency.
#' @param start Character. Start period in the format appropriate for the
#'   series frequency:
#'   - Monthly / Weekly / Daily: `"YYYYMM"` (e.g. `"202501"`)
#'   - Quarterly: `"YYYYQQ"` (e.g. `"202502"` for Q2 2025)
#'   - Calendar/Fiscal half year: `"YYYYHH"` (e.g. `"202501"` for first half)
#'   - Annual: `"YYYY"`
#' @param end Character. End period (same format as `start`).
#' @param lang Character. Output language: `"jp"` (Japanese, default) or `"en"`.
#' @param tidy Logical. If `TRUE` (default), returns a tidy long-format
#'   `data.frame`. If `FALSE`, returns the raw list from the API.
#' @param request_interval Numeric. Seconds to wait before making the request
#'   to avoid overloading the BOJ server. Default is `1.0`.
#' @param timeout Numeric. Request timeout in seconds. Default is `30`.
#'
#' @return If `tidy = TRUE`, a `data.frame` with columns:
#'   `series_code`, `name`, `unit`, `frequency`, `category`,
#'   `last_update`, `date`, `value`.
#'   If `tidy = FALSE`, the raw list from the API response.
#'
#' @seealso [boj_get_data_all()] for automatic pagination,
#'   [boj_get_layer()] for the Layer API,
#'   [boj_get_metadata()] for the Metadata API.
#'
#' @examples
#' \dontrun{
#' # Overnight call rate (daily)
#' df <- boj_get_data(
#'   db    = "FM01",
#'   codes = c("STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"),
#'   start = "202501"
#' )
#' head(df)
#'
#' # Tankan (quarterly)
#' df <- boj_get_data(
#'   db    = "CO",
#'   codes = c("TK99F1000601GCQ01000", "TK99F2000601GCQ01000"),
#'   start = "202401",
#'   end   = "202504",
#'   lang  = "en"
#' )
#' }
#'
#' @export
boj_get_data <- function(
    db,
    codes,
    start             = NULL,
    end               = NULL,
    lang              = c("jp", "en"),
    tidy              = TRUE,
    request_interval  = 1.0,
    timeout           = 30
) {
  lang <- match.arg(lang)
  db   <- boj_validate_db(db)

  if (length(codes) == 0L) {
    cli::cli_abort("{.arg codes} must contain at least one series code.")
  }
  if (length(codes) > 250L) {
    cli::cli_abort(c(
      "{.arg codes} exceeds the limit of 250 codes per request.",
      "i" = "Use {.fn boj_get_data_all} for automatic pagination."
    ))
  }

  params <- list(
    format    = "json",
    lang      = lang,
    db        = db,
    code      = paste(codes, collapse = ","),
    startDate = start,
    endDate   = end
  )

  result <- boj_request("getDataCode", params, request_interval, timeout)

  if (!tidy) return(result)
  boj_parse_resultset(result[["RESULTSET"]], lang = lang)
}


#' Retrieve All Time-Series Data with Automatic Pagination (Code API)
#'
#' A wrapper around [boj_get_data()] that automatically handles pagination
#' when the number of codes exceeds 250 or when the data limit (60,000
#' observations) is reached.
#'
#' @inheritParams boj_get_data
#' @param codes Character vector of series codes. Unlimited length; the
#'   function splits into chunks of 250 automatically.
#'
#' @return A `data.frame` (long format) combining all pages.
#'
#' @examples
#' \dontrun{
#' # Fetch more than 250 codes automatically
#' meta  <- boj_get_metadata("PR01")
#' codes <- meta$series_code
#' df    <- boj_get_data_all("PR01", codes)
#' }
#'
#' @export
boj_get_data_all <- function(
    db,
    codes,
    start            = NULL,
    end              = NULL,
    lang             = c("jp", "en"),
    request_interval = 1.0,
    timeout          = 30
) {
  lang   <- match.arg(lang)
  db     <- boj_validate_db(db)
  chunks <- split(codes, ceiling(seq_along(codes) / 250))

  all_rows <- vector("list", length = 0L)

  for (chunk in chunks) {
    position <- NULL
    repeat {
      params <- list(
        format        = "json",
        lang          = lang,
        db            = db,
        code          = paste(chunk, collapse = ","),
        startDate     = start,
        endDate       = end,
        startPosition = position
      )
      result   <- boj_request("getDataCode", params, request_interval, timeout)
      all_rows <- c(all_rows, list(boj_parse_resultset(result[["RESULTSET"]], lang)))
      next_pos <- result[["NEXTPOSITION"]]
      if (is.null(next_pos)) break
      position <- next_pos
    }
  }

  do.call(rbind, all_rows)
}


#' Retrieve Time-Series Data by Hierarchical Structure (Layer API)
#'
#' Fetches data using the hierarchical tree structure of each database,
#' which is useful when you want all series under a particular category
#' without knowing series codes in advance.
#'
#' @param db Character. Database name. See [boj_db_names].
#' @param frequency Character. Frequency code: `"CY"`, `"FY"`, `"CH"`,
#'   `"FH"`, `"Q"`, `"M"`, `"W"`, or `"D"`. See [boj_frequencies].
#' @param layer Character. Layer specification as a comma-separated string
#'   for layer 1 to 5. Wildcard `"*"` can be used. Examples:
#'   - `"*"` — all series
#'   - `"1,1"` — layer1 = 1, layer2 = 1
#'   - `"1,*,1"` — layer1 = 1, layer2 = any, layer3 = 1
#' @param start Character. Start period (see [boj_get_data()] for formats).
#' @param end Character. End period.
#' @param lang Character. `"jp"` or `"en"`.
#' @param tidy Logical. Return tidy `data.frame` (default) or raw list.
#' @param request_interval Numeric. Seconds between requests.
#' @param timeout Numeric. Request timeout in seconds.
#'
#' @return If `tidy = TRUE`, a long-format `data.frame`. If `FALSE`, raw list.
#'
#' @examples
#' \dontrun{
#' # Balance of payments, monthly, hierarchical slice 1-1-1
#' df <- boj_get_layer(
#'   db        = "BP01",
#'   frequency = "M",
#'   layer     = "1,1,1",
#'   start     = "202504",
#'   end       = "202509"
#' )
#' head(df)
#' }
#'
#' @export
boj_get_layer <- function(
    db,
    frequency,
    layer,
    start            = NULL,
    end              = NULL,
    lang             = c("jp", "en"),
    tidy             = TRUE,
    request_interval = 1.0,
    timeout          = 30
) {
  lang      <- match.arg(lang)
  db        <- boj_validate_db(db)
  frequency <- boj_validate_frequency(frequency)

  params <- list(
    format        = "json",
    lang          = lang,
    db            = db,
    frequency     = frequency,
    layer         = layer,
    startDate     = start,
    endDate       = end
  )

  result <- boj_request("getDataLayer", params, request_interval, timeout)

  if (!tidy) return(result)
  boj_parse_resultset(result[["RESULTSET"]], lang = lang)
}


#' Retrieve Metadata for a Database (Metadata API)
#'
#' Returns series codes, names, units, frequencies, hierarchical layer info,
#' and collection periods for all series in a given database.
#' Useful for discovering available series codes before calling
#' [boj_get_data()].
#'
#' @param db Character. Database name. See [boj_db_names].
#' @param lang Character. `"jp"` or `"en"`.
#' @param request_interval Numeric. Seconds between requests.
#' @param timeout Numeric. Request timeout in seconds.
#'
#' @return A `data.frame` with columns: `series_code`, `name`, `unit`,
#'   `frequency`, `category`, `layer1`–`layer5`,
#'   `start_of_series`, `end_of_series`, `last_update`, `notes`.
#'
#' @examples
#' \dontrun{
#' # Get all series metadata for the FX database
#' meta <- boj_get_metadata("FM08")
#' head(meta)
#'
#' # Find series containing "ドル"
#' meta[grepl("ドル", meta$name), ]
#' }
#'
#' @export
boj_get_metadata <- function(
    db,
    lang             = c("jp", "en"),
    request_interval = 1.0,
    timeout          = 30
) {
  lang <- match.arg(lang)
  db   <- boj_validate_db(db)

  params <- list(
    format = "json",
    lang   = lang,
    db     = db
  )

  result     <- boj_request("getMetadata", params, request_interval, timeout)
  resultset  <- result[["RESULTSET"]]

  if (length(resultset) == 0L) {
    return(data.frame())
  }

  name_key     <- if (lang == "jp") "NAME_OF_TIME_SERIES_J" else "NAME_OF_TIME_SERIES"
  unit_key     <- if (lang == "jp") "UNIT_J" else "UNIT"
  category_key <- if (lang == "jp") "CATEGORY_J" else "CATEGORY"
  notes_key    <- if (lang == "jp") "NOTES_J" else "NOTES"

  as.data.frame(do.call(rbind, lapply(resultset, function(s) {
    list(
      series_code     = s[["SERIES_CODE"]] %||% NA_character_,
      name            = s[[name_key]] %||% NA_character_,
      unit            = s[[unit_key]] %||% NA_character_,
      frequency       = s[["FREQUENCY"]] %||% NA_character_,
      category        = s[[category_key]] %||% NA_character_,
      layer1          = s[["LAYER1"]] %||% NA_integer_,
      layer2          = s[["LAYER2"]] %||% NA_integer_,
      layer3          = s[["LAYER3"]] %||% NA_integer_,
      layer4          = s[["LAYER4"]] %||% NA_integer_,
      layer5          = s[["LAYER5"]] %||% NA_integer_,
      start_of_series = s[["START_OF_THE_TIME_SERIES"]] %||% NA_character_,
      end_of_series   = s[["END_OF_THE_TIME_SERIES"]] %||% NA_character_,
      last_update     = as.character(s[["LAST_UPDATE"]] %||% NA),
      notes           = s[[notes_key]] %||% NA_character_
    )
  })), stringsAsFactors = FALSE)
}


#' Search Series by Keyword
#'
#' Retrieves metadata for a database and filters series whose names contain
#' the specified keyword.
#'
#' @param db Character. Database name.
#' @param keyword Character. Keyword to search for in series names
#'   (case-insensitive).
#' @param lang Character. `"jp"` or `"en"`.
#' @param ... Additional arguments passed to [boj_get_metadata()].
#'
#' @return A filtered `data.frame` of metadata.
#'
#' @examples
#' \dontrun{
#' # Search for USD-related series in the FX database
#' boj_search_series("FM08", keyword = "ドル")
#'
#' # English
#' boj_search_series("FM08", keyword = "dollar", lang = "en")
#' }
#'
#' @export
boj_search_series <- function(db, keyword, lang = c("jp", "en"), ...) {
  lang <- match.arg(lang)
  meta <- boj_get_metadata(db, lang = lang, ...)
  if (nrow(meta) == 0L || missing(keyword)) return(meta)
  meta[grepl(keyword, meta$name, ignore.case = TRUE), ]
}


#' List Available Databases
#'
#' Prints a formatted table of all available BOJ database names and their
#' descriptions.
#'
#' @param lang Character. `"jp"` for Japanese names (default), `"en"` for
#'   translated descriptions (note: descriptions are stored in Japanese
#'   regardless).
#'
#' @return A `data.frame` of `db` and `description` columns, invisibly.
#'
#' @examples
#' boj_list_databases()
#'
#' @export
boj_list_databases <- function(lang = c("jp", "en")) {
  lang <- match.arg(lang)
  df <- data.frame(
    db          = names(boj_db_names),
    description = unname(boj_db_names),
    stringsAsFactors = FALSE
  )
  print(df, row.names = FALSE)
  invisible(df)
}
