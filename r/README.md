# bojstat <img src="https://www.boj.or.jp/common2/img/common/logo.gif" align="right" height="40"/>

**R Interface to the Bank of Japan Time-Series Data Search API**

2026年2月18日に公開された[日銀統計API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm)のRラッパーです。金利・為替・マネーストック・短観・物価など20万件以上の時系列データを取得できます。

> This package is not officially affiliated with or endorsed by the Bank of Japan.

---

## インストール

### CRANから（公開後）

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
