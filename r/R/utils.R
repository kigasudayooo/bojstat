#' Make a BOJ API request
#'
#' @param endpoint API endpoint name (e.g. "getDataCode")
#' @param params Named list of query parameters
#' @param request_interval Seconds to wait between requests
#' @param timeout Request timeout in seconds
#' @return Parsed JSON response as a list
#' @keywords internal
boj_request <- function(endpoint, params, request_interval = 1.0, timeout = 30) {
  # Remove NULL values
  params <- Filter(Negate(is.null), params)

  url <- paste0(BOJ_BASE_URL, "/", endpoint)

  resp <- httr2::request(url) |>
    httr2::req_url_query(!!!params) |>
    httr2::req_headers("Accept-Encoding" = "gzip") |>
    httr2::req_timeout(timeout) |>
    httr2::req_retry(max_tries = 2, backoff = \(i) request_interval * i) |>
    httr2::req_perform()

  result <- httr2::resp_body_json(resp, simplifyVector = FALSE)

  status <- result[["STATUS"]]
  if (!identical(status, 200L) && !identical(status, 200)) {
    cli::cli_abort(
      c(
        "BOJ API error [{result[['MESSAGEID']]}]",
        "x" = "{result[['MESSAGE']]}",
        "i" = "Status code: {status}"
      )
    )
  }

  result
}

#' Validate DB name
#' @keywords internal
boj_validate_db <- function(db) {
  db <- toupper(db)
  if (!db %in% names(boj_db_names)) {
    cli::cli_abort(c(
      "Unknown DB name: {.val {db}}",
      "i" = "Run {.code print(boj_db_names)} to see all available DBs."
    ))
  }
  db
}

#' Validate frequency
#' @keywords internal
boj_validate_frequency <- function(frequency) {
  frequency <- toupper(frequency)
  valid <- c(names(boj_frequencies), "W0", "W1", "W2", "W3", "W4", "W5", "W6")
  if (!frequency %in% valid) {
    cli::cli_abort(c(
      "Unknown frequency: {.val {frequency}}",
      "i" = "Valid values: {.val {names(boj_frequencies)}}"
    ))
  }
  frequency
}

#' Parse RESULTSET into a tidy data frame
#'
#' Converts the RESULTSET list from Code API / Layer API response into
#' a tidy (long-format) data frame.
#'
#' @param resultset List from API response$RESULTSET
#' @param lang Language setting ("jp" or "en")
#' @return A data.frame with columns: series_code, name, unit, frequency,
#'   category, last_update, date, value
#' @keywords internal
boj_parse_resultset <- function(resultset, lang = "jp") {
  if (length(resultset) == 0) {
    return(data.frame(
      series_code = character(),
      name        = character(),
      unit        = character(),
      frequency   = character(),
      category    = character(),
      last_update = character(),
      date        = character(),
      value       = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  name_key     <- if (lang == "jp") "NAME_OF_TIME_SERIES_J" else "NAME_OF_TIME_SERIES"
  unit_key     <- if (lang == "jp") "UNIT_J" else "UNIT"
  category_key <- if (lang == "jp") "CATEGORY_J" else "CATEGORY"

  rows <- lapply(resultset, function(s) {
    values_block <- s[["VALUES"]]
    dates  <- unlist(values_block[["SURVEY_DATES"]])
    values <- unlist(values_block[["VALUES"]])

    n <- length(dates)
    data.frame(
      series_code = rep(s[["SERIES_CODE"]] %||% NA_character_, n),
      name        = rep(s[[name_key]] %||% NA_character_, n),
      unit        = rep(s[[unit_key]] %||% NA_character_, n),
      frequency   = rep(s[["FREQUENCY"]] %||% NA_character_, n),
      category    = rep(s[[category_key]] %||% NA_character_, n),
      last_update = rep(as.character(s[["LAST_UPDATE"]] %||% NA), n),
      date        = dates,
      value       = suppressWarnings(as.numeric(values)),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Null coalescing operator
#' @noRd
`%||%` <- function(x, y) if (!is.null(x)) x else y
