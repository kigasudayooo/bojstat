# bojstat

**日本銀行 時系列統計データ検索サイト API** の非公式 Python クライアント

[English](#english) | [PyPI](https://pypi.org/project/bojstat/) | [GitHub](https://github.com/kigasudayooo/bojstat)

2026年2月18日に公開された [日銀統計API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm) を使い、金利・為替・マネーストック・短観など200,000以上の時系列統計データをPythonから簡単に取得できます。

> **注意**: このパッケージは日本銀行が公式に提供・保証するものではありません。

---

## インストール

```bash
pip install bojstat

# pandas 対応
pip install bojstat[pandas]

# polars 対応
pip install bojstat[polars]

# 両方
pip install bojstat[all]

# GitHubから（開発版）
pip install "git+https://github.com/kigasudayooo/bojstat.git#subdirectory=python"
```

## クイックスタート

```python
from bojstat import BOJStatClient

client = BOJStatClient()

# 利用可能なDB一覧を確認
print(client.list_databases())

# 外国為替市況（FM08）のメタデータを取得
meta = client.get_metadata(db="FM08")
for m in meta[:3]:
    print(m["SERIES_CODE"], m.get("NAME_OF_TIME_SERIES_J"))

# 無担保コールO/N物レートを取得
data = client.get_data(
    db="FM01",
    codes=["STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"],
    start="202501",
)

# pandas / polars に変換
df = client.to_pandas(data)
df = client.to_polars(data)
```

## 使用例：短観 雇用人員判断DIの取得

短観（DB名: `CO`）から雇用人員判断DIを取得し、pandas DataFrameに変換する実践的な例です。

### ステップ1: 系列コードの検索

短観には168,000以上の系列があります。`search_series()` でキーワード検索して絞り込みます。

```python
from bojstat import BOJStatClient

client = BOJStatClient()

results = client.search_series(db="CO", keyword="雇用人員")
for m in results[:5]:
    print(m["SERIES_CODE"], m["NAME_OF_TIME_SERIES_J"])
```

出力例：

```
TK99F0000608GCQ00000  D.I./雇用人員/全規模/全産業/実績
TK99F0000608GCQ10000  D.I./雇用人員/全規模/全産業/予測
TK99F1000608GCQ00000  D.I./雇用人員/全規模/製造業/実績
TK99F1000608GCQ10000  D.I./雇用人員/全規模/製造業/予測
TK99F2000608GCQ00000  D.I./雇用人員/全規模/非製造業/実績
```

### ステップ2: データ取得・DataFrame変換・CSV保存

```python
from bojstat import BOJStatClient

client = BOJStatClient()

# 系列コード
codes = [
    "TK99F0000608GCQ00000",  # 全規模/全産業/実績
    "TK99F0000608GCQ10000",  # 全規模/全産業/予測
    "TK99F1000608GCQ00000",  # 全規模/製造業/実績
    "TK99F1000608GCQ10000",  # 全規模/製造業/予測
    "TK99F2000608GCQ00000",  # 全規模/非製造業/実績
    "TK99F2000608GCQ10000",  # 全規模/非製造業/予測
]

# データ取得（2020Q1〜）
data = client.get_data(db="CO", codes=codes, start="202001")

# DataFrame に変換してカラム名を整理
df = client.to_pandas(data)
rename = {}
for series in data:
    code = series["SERIES_CODE"]
    name = series["NAME_OF_TIME_SERIES_J"]
    short = name.replace("D.I./雇用人員/", "").replace("/実績", "(実績)").replace("/予測", "(予測)")
    rename[code] = short
df = df.rename(columns=rename)

# CSV保存（Excel対応のBOM付きUTF-8）
df.to_csv("tankan_employment_di.csv", encoding="utf-8-sig")
print(df)
```

---

## API リファレンス

### `BOJStatClient(lang="jp", timeout=30, request_interval=1.0)`

クライアントを初期化します。

| パラメータ | 型 | デフォルト | 説明 |
|---|---|---|---|
| `lang` | str | `"jp"` | 出力言語（`"jp"` or `"en"`） |
| `timeout` | int | `30` | リクエストタイムアウト（秒） |
| `request_interval` | float | `1.0` | 連続リクエスト間の待機時間（秒）。高頻度アクセスはサーバーに接続遮断される可能性があります |

---

### `get_data(db, codes, start=None, end=None, start_position=None)`

**コード API**。系列コードを指定してデータを取得します（最大250件/リクエスト）。

```python
data = client.get_data(
    db="CO",
    codes=["TK99F1000601GCQ01000", "TK99F2000601GCQ01000"],
    start="202401",  # 2024年Q1
    end="202504",    # 2025年Q4
)
```

**開始期・終了期の形式**

| 期種 | 形式 | 例 |
|---|---|---|
| 月次/週次/日次 | `YYYYMM` | `"202501"` = 2025年1月 |
| 四半期 | `YYYYQQ` | `"202502"` = 2025年Q2 |
| 暦年半期/年度半期 | `YYYYHH` | `"202501"` = 2025年上期 |
| 暦年/年度 | `YYYY` | `"2025"` |

---

### `get_data_all(db, codes, start=None, end=None)`

250件超の系列を自動ページネーションして全件取得します。

```python
all_data = client.get_data_all(db="PR01", codes=my_500_codes)
```

---

### `get_layer(db, frequency, layer, start=None, end=None, start_position=None)`

**階層 API**。階層情報でデータを絞り込んで取得します。

```python
data = client.get_layer(
    db="BP01",
    frequency="M",
    layer="1,1,1",   # 階層1=1, 階層2=1, 階層3=1
    start="202504",
    end="202509",
)
```

`layer` のワイルドカード指定例:

| 指定 | 意味 |
|---|---|
| `"*"` | 全系列 |
| `"1,1"` | 階層1=1, 階層2=1の全系列 |
| `"1,*,1"` | 階層1=1, 階層2=全て, 階層3=1 |

---

### `get_metadata(db)`

**メタデータ API**。系列コード・系列名称・収録期間などのメタ情報を取得します。

```python
meta = client.get_metadata(db="FM08")
```

---

### `search_series(db, keyword=None)`

メタデータからキーワードで系列を検索します。

```python
results = client.search_series(db="FM08", keyword="ドル")
```

---

### `to_pandas(data)`

`get_data()` / `get_layer()` の結果を pandas DataFrame に変換します。

```python
df = client.to_pandas(data)
# インデックス: 日付、カラム: 系列コード
```

---

### `to_polars(data)`

`get_data()` / `get_layer()` の結果を polars DataFrame に変換します。

```python
df = client.to_polars(data)
# カラム: date + 各系列コード
```

> `to_dataframe()` は `to_pandas()` のエイリアスとして引き続き利用可能です。

---

## 利用可能なDB一覧

| DB名 | 説明 |
|---|---|
| IR01 | 基準割引率および基準貸付利率の推移 |
| FM01 | 無担保コールO/N物レート（毎営業日） |
| FM08 | 外国為替市況 |
| FM09 | 実効為替レート |
| MD01 | マネタリーベース |
| MD02 | マネーストック |
| CO | 短観 |
| PR01 | 企業物価指数 |
| BP01 | 国際収支統計 |
| FF | 資金循環 |
| ... | （全リストは `client.list_databases()` で確認） |

---

## 注意事項

- 高頻度アクセスはサーバーへの接続遮断の原因となります。`request_interval`（デフォルト1秒）を適切に設定してください。
- 1リクエストあたりの上限: 系列数250件、データ数60,000件。
- 系列コードには **DB名を含まない** コードを指定してください（例: `IR01'MADR1Z@D` ではなく `MADR1Z@D`）。
- 詳細は [API機能利用マニュアル](https://www.stat-search.boj.or.jp/info/api_manual.pdf) および [留意点](https://www.stat-search.boj.or.jp/info/api_notice.pdf) を参照してください。

## ライセンス

MIT License

---

<a id="english"></a>

# bojstat (English)

**Unofficial Python client for the Bank of Japan Time-Series Data Search API**

[Japanese (日本語)](#bojstat) | [PyPI](https://pypi.org/project/bojstat/) | [GitHub](https://github.com/kigasudayooo/bojstat)

Easily access over 200,000 time-series statistical data from the [BOJ Statistics API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm) (launched February 18, 2026) — including interest rates, exchange rates, money stock, Tankan survey, and more.

> **Note**: This package is not officially affiliated with or endorsed by the Bank of Japan.

---

## Installation

```bash
pip install bojstat

# With pandas support
pip install bojstat[pandas]

# With polars support
pip install bojstat[polars]

# Both
pip install bojstat[all]

# From GitHub (development version)
pip install "git+https://github.com/kigasudayooo/bojstat.git#subdirectory=python"
```

## Quick Start

```python
from bojstat import BOJStatClient

client = BOJStatClient(lang="en")

# List available databases
print(client.list_databases())

# Get metadata for the FX database (FM08)
meta = client.get_metadata(db="FM08")
for m in meta[:3]:
    print(m["SERIES_CODE"], m.get("NAME_OF_TIME_SERIES"))

# Fetch overnight call rate data
data = client.get_data(
    db="FM01",
    codes=["STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"],
    start="202501",
)

# Convert to pandas / polars
df = client.to_pandas(data)
df = client.to_polars(data)
```

## Usage Example: Fetching Tankan Employment DI

A practical example of retrieving the Tankan survey's Employment Conditions DI (DB: `CO`) and converting it to a pandas DataFrame.

### Step 1: Search for Series Codes

The Tankan database contains over 168,000 series. Use `search_series()` to narrow down.

```python
from bojstat import BOJStatClient

client = BOJStatClient(lang="en")

results = client.search_series(db="CO", keyword="employment")
for m in results[:5]:
    print(m["SERIES_CODE"], m["NAME_OF_TIME_SERIES"])
```

### Step 2: Fetch Data, Convert to DataFrame, and Save as CSV

```python
from bojstat import BOJStatClient

client = BOJStatClient()

# Series codes for Employment Conditions DI
codes = [
    "TK99F0000608GCQ00000",  # All sizes / All industries / Actual
    "TK99F0000608GCQ10000",  # All sizes / All industries / Forecast
    "TK99F1000608GCQ00000",  # All sizes / Manufacturing / Actual
    "TK99F1000608GCQ10000",  # All sizes / Manufacturing / Forecast
    "TK99F2000608GCQ00000",  # All sizes / Non-manufacturing / Actual
    "TK99F2000608GCQ10000",  # All sizes / Non-manufacturing / Forecast
]

# Fetch data from Q1 2020
data = client.get_data(db="CO", codes=codes, start="202001")

# Convert to DataFrame and rename columns
df = client.to_pandas(data)
rename = {}
for series in data:
    code = series["SERIES_CODE"]
    name = series["NAME_OF_TIME_SERIES_J"]
    short = name.replace("D.I./雇用人員/", "").replace("/実績", "(Actual)").replace("/予測", "(Forecast)")
    rename[code] = short
df = df.rename(columns=rename)

# Save as CSV (BOM-prefixed UTF-8 for Excel compatibility)
df.to_csv("tankan_employment_di.csv", encoding="utf-8-sig")
print(df)
```

---

## API Reference

### `BOJStatClient(lang="jp", timeout=30, request_interval=1.0)`

Initialize the client.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `lang` | str | `"jp"` | Output language (`"jp"` or `"en"`) |
| `timeout` | int | `30` | Request timeout in seconds |
| `request_interval` | float | `1.0` | Wait time between consecutive requests (seconds). High-frequency access may result in connection blocking |

---

### `get_data(db, codes, start=None, end=None, start_position=None)`

**Code API**. Retrieve data by specifying series codes (max 250 per request).

```python
data = client.get_data(
    db="CO",
    codes=["TK99F1000601GCQ01000", "TK99F2000601GCQ01000"],
    start="202401",  # Q1 2024
    end="202504",    # Q4 2025
)
```

**Date format for start/end**

| Frequency | Format | Example |
|---|---|---|
| Monthly / Weekly / Daily | `YYYYMM` | `"202501"` = Jan 2025 |
| Quarterly | `YYYYQQ` | `"202502"` = Q2 2025 |
| Half-yearly | `YYYYHH` | `"202501"` = 1st half 2025 |
| Annual | `YYYY` | `"2025"` |

---

### `get_data_all(db, codes, start=None, end=None)`

Automatically paginates to fetch all data when codes exceed 250.

```python
all_data = client.get_data_all(db="PR01", codes=my_500_codes)
```

---

### `get_layer(db, frequency, layer, start=None, end=None, start_position=None)`

**Layer API**. Retrieve data by hierarchical structure.

```python
data = client.get_layer(
    db="BP01",
    frequency="M",
    layer="1,1,1",
    start="202504",
    end="202509",
)
```

Layer wildcard examples:

| Specification | Meaning |
|---|---|
| `"*"` | All series |
| `"1,1"` | Layer1=1, Layer2=1 |
| `"1,*,1"` | Layer1=1, Layer2=any, Layer3=1 |

---

### `get_metadata(db)`

**Metadata API**. Retrieve series codes, names, collection periods, etc.

```python
meta = client.get_metadata(db="FM08")
```

---

### `search_series(db, keyword=None)`

Search series by keyword in metadata.

```python
results = client.search_series(db="FM08", keyword="dollar")
```

---

### `to_pandas(data)`

Convert `get_data()` / `get_layer()` results to a pandas DataFrame.

```python
df = client.to_pandas(data)
# Index: dates, Columns: series codes
```

---

### `to_polars(data)`

Convert `get_data()` / `get_layer()` results to a polars DataFrame.

```python
df = client.to_polars(data)
# Columns: date + series codes
```

> `to_dataframe()` is kept as an alias for `to_pandas()`.

---

## Available Databases

| DB | Description |
|---|---|
| IR01 | Basic discount/loan rates |
| FM01 | Overnight call rate (daily) |
| FM08 | Foreign exchange rates |
| FM09 | Effective exchange rates |
| MD01 | Monetary base |
| MD02 | Money stock |
| CO | Tankan (Short-Term Economic Survey) |
| PR01 | Corporate Goods Price Index |
| BP01 | Balance of Payments |
| FF | Flow of Funds |
| ... | (Full list: `client.list_databases()`) |

---

## Important Notes

- High-frequency access may result in connection blocking. Set `request_interval` (default: 1 second) appropriately.
- Per-request limits: 250 series, 60,000 data points.
- Do **not** include the DB prefix in series codes (use `MADR1Z@D`, not `IR01'MADR1Z@D`).
- See the [API Manual](https://www.stat-search.boj.or.jp/info/api_manual.pdf) and [Usage Notes](https://www.stat-search.boj.or.jp/info/api_notice.pdf) for details.

## License

MIT License
