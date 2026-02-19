# bojstat

**日本銀行 時系列統計データ検索サイト API** の R インターフェース

[English](#english) | [CRAN](https://cran.r-project.org/package=bojstat) | [GitHub](https://github.com/kigasudayooo/bojstat)

2026年2月18日に公開された[日銀統計API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm)のRラッパーです。金利・為替・マネーストック・短観・物価など20万件以上の時系列データを取得できます。

> このパッケージは日本銀行が公式に提供・保証するものではありません。

---

## インストール

### CRANから

```r
install.packages("bojstat")
```

### GitHubから（開発版）

```r
# install.packages("pak")
pak::pkg_install("kigasudayooo/bojstat", subdir = "r")

# または devtools
# install.packages("devtools")
devtools::install_github("kigasudayooo/bojstat", subdir = "r")
```

---

## クイックスタート

```r
library(bojstat)

# 利用可能なDB一覧
boj_list_databases()

# 外為DB（FM08）のメタデータ取得・系列検索
meta <- boj_get_metadata("FM08")
boj_search_series("FM08", keyword = "ドル")

# 無担保コールO/N物レート（2025年1月以降）
df <- boj_get_data(
  db    = "FM01",
  codes = c("STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"),
  start = "202501"
)
head(df)

# 国際収支（月次、階層指定）
df_bop <- boj_get_layer(
  db        = "BP01",
  frequency = "M",
  layer     = "1,1,1",
  start     = "202504",
  end       = "202509"
)
```

---

## 関数一覧

| 関数 | API種別 | 説明 |
|---|---|---|
| `boj_get_data()` | コードAPI | 系列コード指定でデータ取得（最大250件/回） |
| `boj_get_data_all()` | コードAPI | 250件超を自動ページネーション |
| `boj_get_layer()` | 階層API | 階層情報でデータ取得 |
| `boj_get_metadata()` | メタデータAPI | 系列名・期間等のメタ情報取得 |
| `boj_search_series()` | メタデータAPI | キーワードで系列検索 |
| `boj_list_databases()` | ― | 利用可能なDB一覧表示 |

## 共通パラメータ

| パラメータ | 説明 | デフォルト |
|---|---|---|
| `lang` | 出力言語 (`"jp"` / `"en"`) | `"jp"` |
| `start` / `end` | 開始・終了期（下表参照） | `NULL`（全期間） |
| `request_interval` | リクエスト間隔（秒） | `1.0` |
| `tidy` | tidyなlong形式で返すか | `TRUE` |

### 日付形式

| 期種 | 形式 | 例 |
|---|---|---|
| 月次/週次/日次 | `YYYYMM` | `"202501"` |
| 四半期 | `YYYYQQ` | `"202502"` = 2025Q2 |
| 暦年半期/年度半期 | `YYYYHH` | `"202501"` = 上期 |
| 暦年/年度 | `YYYY` | `"2025"` |

---

## 注意事項

- 系列コードに**DB名を含めない**こと（`"MADR1Z@D"` ✓、`"IR01'MADR1Z@D"` ✗）
- 1リクエストの上限: 系列数250件、データ数60,000件
- 高頻度アクセスは接続遮断の原因になります（`request_interval` を適切に設定）
- 詳細は[APIマニュアル](https://www.stat-search.boj.or.jp/info/api_manual.pdf)を参照

## ライセンス

MIT

---

<a id="english"></a>

# bojstat (English)

**R Interface to the Bank of Japan Time-Series Data Search API**

[Japanese (日本語)](#bojstat) | [CRAN](https://cran.r-project.org/package=bojstat) | [GitHub](https://github.com/kigasudayooo/bojstat)

An R wrapper for the [BOJ Statistics API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm) (launched February 18, 2026). Access over 200,000 time-series data including interest rates, exchange rates, money stock, Tankan survey, price indices, and more.

> This package is not officially affiliated with or endorsed by the Bank of Japan.

---

## Installation

### From CRAN

```r
install.packages("bojstat")
```

### From GitHub (development version)

```r
# install.packages("pak")
pak::pkg_install("kigasudayooo/bojstat", subdir = "r")

# Or using devtools
# install.packages("devtools")
devtools::install_github("kigasudayooo/bojstat", subdir = "r")
```

---

## Quick Start

```r
library(bojstat)

# List available databases
boj_list_databases()

# Get metadata and search series (FX database)
meta <- boj_get_metadata("FM08", lang = "en")
boj_search_series("FM08", keyword = "dollar", lang = "en")

# Fetch overnight call rate (from Jan 2025)
df <- boj_get_data(
  db    = "FM01",
  codes = c("STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"),
  start = "202501",
  lang  = "en"
)
head(df)

# Balance of payments (monthly, hierarchical)
df_bop <- boj_get_layer(
  db        = "BP01",
  frequency = "M",
  layer     = "1,1,1",
  start     = "202504",
  end       = "202509",
  lang      = "en"
)
```

---

## Functions

| Function | API Type | Description |
|---|---|---|
| `boj_get_data()` | Code API | Fetch data by series codes (max 250/request) |
| `boj_get_data_all()` | Code API | Auto-pagination for 250+ codes |
| `boj_get_layer()` | Layer API | Fetch data by hierarchical structure |
| `boj_get_metadata()` | Metadata API | Retrieve series metadata |
| `boj_search_series()` | Metadata API | Keyword search in series names |
| `boj_list_databases()` | ― | List all available databases |

## Common Parameters

| Parameter | Description | Default |
|---|---|---|
| `lang` | Output language (`"jp"` / `"en"`) | `"jp"` |
| `start` / `end` | Start/end period (see formats below) | `NULL` (all periods) |
| `request_interval` | Seconds between requests | `1.0` |
| `tidy` | Return tidy long-format data.frame | `TRUE` |

### Date Formats

| Frequency | Format | Example |
|---|---|---|
| Monthly / Weekly / Daily | `YYYYMM` | `"202501"` |
| Quarterly | `YYYYQQ` | `"202502"` = Q2 2025 |
| Half-yearly | `YYYYHH` | `"202501"` = 1st half |
| Annual | `YYYY` | `"2025"` |

---

## Important Notes

- Do **not** include DB prefix in series codes (`"MADR1Z@D"` ✓, `"IR01'MADR1Z@D"` ✗)
- Per-request limits: 250 series, 60,000 data points
- High-frequency access may result in connection blocking (set `request_interval` appropriately)
- See the [API Manual](https://www.stat-search.boj.or.jp/info/api_manual.pdf) for details

## License

MIT
