# bojstat

**日本銀行 時系列統計データ検索サイト API** の Python / R クライアント

2026年2月18日に公開された [日銀統計API](https://www.boj.or.jp/statistics/outline/notice_2026/not260218a.htm) を使い、金利・為替・マネーストック・短観・物価など **20万件以上の時系列統計データ** を取得できます。

> このパッケージは日本銀行が公式に提供・保証するものではありません。

---

## 構成

```
bojstat/
├── python/   # Python パッケージ (PyPI: bojstat)
└── r/        # R パッケージ (CRAN: bojstat)
```

---

## Python

### インストール

```bash
pip install bojstat
# pandas対応版
pip install bojstat[pandas]

# GitHubから（開発版）
pip install "git+https://github.com/kigasudayooo/bojstat.git#subdirectory=python"
```

### 使い方

```python
from bojstat import BOJStatClient

client = BOJStatClient()

# DB一覧
print(client.list_databases())

# 系列検索（外為DBからドル関連）
results = client.search_series("FM08", keyword="ドル")

# データ取得（無担保コールレート）
data = client.get_data(
    db="FM01",
    codes=["STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"],
    start="202501",
)

# pandas DataFrameへ変換
df = client.to_dataframe(data)
```

詳細は [`python/README.md`](python/README.md) を参照。

---

## R

### インストール

```r
# CRANから（公開後）
install.packages("bojstat")

# GitHubから（開発版）
devtools::install_github("kigasudayooo/bojstat", subdir = "r")
```

### 使い方

```r
library(bojstat)

# DB一覧
boj_list_databases()

# 系列検索（外為DBからドル関連）
boj_search_series("FM08", keyword = "ドル")

# データ取得（無担保コールレート）
df <- boj_get_data(
  db    = "FM01",
  codes = c("STRDCLUCON", "STRDCLUCONH", "STRDCLUCONL"),
  start = "202501"
)
```

詳細は [`r/README.md`](r/README.md) を参照。

---

## API 概要

日銀統計APIは3種類のエンドポイントを提供しています。

| API | エンドポイント | 説明 |
|---|---|---|
| コードAPI | `getDataCode` | 系列コードを指定してデータ取得 |
| 階層API | `getDataLayer` | ツリー構造でデータ取得 |
| メタデータAPI | `getMetadata` | 系列名・収録期間等の情報取得 |

**制限事項**
- 1リクエストあたり最大250系列・60,000データ点
- 高頻度アクセスは接続遮断の原因になります（推奨間隔: 1秒以上）
- 系列コードにDB名プレフィックスを含めないこと（`MADR1Z@D` ✓、`IR01'MADR1Z@D` ✗）

詳細は [APIマニュアル](https://www.stat-search.boj.or.jp/info/api_manual.pdf) を参照。

---

## ライセンス

MIT
