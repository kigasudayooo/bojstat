# bojstat 0.1.0

* Initial CRAN release.
* Support for all three BOJ Time-Series Data Search API endpoints:
  - Code API (`boj_get_data()`, `boj_get_data_all()`)
  - Layer API (`boj_get_layer()`)
  - Metadata API (`boj_get_metadata()`)
* Series keyword search (`boj_search_series()`).
* Database listing (`boj_list_databases()`).
* Automatic rate limiting via `request_interval` parameter.
* Japanese and English output support.
