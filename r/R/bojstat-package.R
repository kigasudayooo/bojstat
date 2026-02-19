#' bojstat: R Interface to the Bank of Japan Time-Series Data Search API
#'
#' Provides functions to access the BOJ Time-Series Data Search API,
#' launched on February 18, 2026. Retrieve over 200,000 time-series
#' statistical data including interest rates, exchange rates, money stock,
#' Tankan survey results, price indices, and more.
#'
#' @section Main functions:
#' - [boj_get_data()] -- Code API: retrieve data by series codes
#' - [boj_get_data_all()] -- Code API with automatic pagination
#' - [boj_get_layer()] -- Layer API: retrieve data by hierarchical structure
#' - [boj_get_metadata()] -- Metadata API: retrieve series metadata
#' - [boj_search_series()] -- Search series by keyword
#' - [boj_list_databases()] -- List all available databases
#'
#' @section Reference data:
#' - [boj_db_names] -- Named vector of all database codes and descriptions
#' - [boj_frequencies] -- Named vector of frequency codes
#'
#' @note This package is not officially affiliated with or endorsed by
#'   the Bank of Japan. Please avoid high-frequency access to the API,
#'   as the BOJ may block connections if requests are too frequent.
#'   Use the `request_interval` parameter (default: 1 second) appropriately.
#'
#' @references
#' - API announcement: \url{https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm}
#' - API manual: \url{https://www.stat-search.boj.or.jp/info/api_manual.pdf}
#' - BOJ Time-Series Data Search: \url{https://www.stat-search.boj.or.jp}
#'
#' @importFrom httr2 request req_url_query req_headers req_timeout req_retry req_perform resp_body_json
#' @importFrom cli cli_abort
#'
"_PACKAGE"
