test_that("boj_db_names is a named character vector", {
  expect_type(boj_db_names, "character")
  expect_true(length(boj_db_names) > 0)
  expect_true("FM08" %in% names(boj_db_names))
  expect_true("CO" %in% names(boj_db_names))
  expect_true("PR01" %in% names(boj_db_names))
})

test_that("boj_frequencies has required keys", {
  expect_true(all(c("M", "Q", "D", "W", "CY", "FY") %in% names(boj_frequencies)))
})

test_that("boj_validate_db rejects invalid DB names", {
  expect_error(boj_validate_db("INVALID_DB"), "Unknown DB name")
})

test_that("boj_validate_db accepts valid DB names (case-insensitive)", {
  expect_equal(boj_validate_db("fm08"), "FM08")
  expect_equal(boj_validate_db("CO"), "CO")
})

test_that("boj_validate_frequency rejects invalid frequencies", {
  expect_error(boj_validate_frequency("INVALID"), "Unknown frequency")
})

test_that("boj_validate_frequency accepts valid frequencies", {
  expect_equal(boj_validate_frequency("m"), "M")
  expect_equal(boj_validate_frequency("Q"), "Q")
})

test_that("boj_get_data validates codes length", {
  expect_error(
    boj_get_data("FM01", codes = character(0)),
    "at least one"
  )
  expect_error(
    boj_get_data("FM01", codes = paste0("CODE", seq_len(251))),
    "250"
  )
})

test_that("boj_list_databases returns a data frame", {
  df <- boj_list_databases()
  expect_s3_class(df, "data.frame")
  expect_true("db" %in% names(df))
  expect_true("description" %in% names(df))
  expect_true(nrow(df) > 40)
})

test_that("%||% works correctly", {
  expect_equal(NULL %||% "default", "default")
  expect_equal("value" %||% "default", "value")
  expect_equal(1L %||% 0L, 1L)
})

test_that("boj_parse_resultset returns empty df for empty input", {
  df <- boj_parse_resultset(list())
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0L)
  expect_true("series_code" %in% names(df))
  expect_true("value" %in% names(df))
})

test_that("boj_parse_resultset parses correctly", {
  mock_result <- list(
    list(
      SERIES_CODE            = "TESTCODE",
      NAME_OF_TIME_SERIES_J  = "テスト系列",
      UNIT_J                 = "億円",
      FREQUENCY              = "MONTHLY",
      CATEGORY_J             = "テスト",
      LAST_UPDATE            = 20250101L,
      VALUES = list(
        SURVEY_DATES = list("202501", "202502"),
        VALUES       = list(100.5, 200.3)
      )
    )
  )
  df <- boj_parse_resultset(mock_result, lang = "jp")
  expect_equal(nrow(df), 2L)
  expect_equal(df$series_code, c("TESTCODE", "TESTCODE"))
  expect_equal(df$date, c("202501", "202502"))
  expect_equal(df$value, c(100.5, 200.3))
  expect_equal(df$name[1], "テスト系列")
})
