"""
bojstat - 日本銀行 時系列統計データ検索サイト API Python クライアント

使用例:
    >>> from bojstat import BOJStatClient
    >>> client = BOJStatClient()
    >>> # 外為レートのメタデータ取得
    >>> meta = client.get_metadata(db="FM08")
    >>> # コードAPIでデータ取得
    >>> data = client.get_data(db="FM01", codes=["STRDCLUCON"], start="202501")
    >>> # DataFrameに変換
    >>> df = client.to_dataframe(data)
"""

from .client import BOJStatClient, BOJStatError
from .constants import DB_NAMES, FREQUENCIES

__all__ = ["BOJStatClient", "BOJStatError", "DB_NAMES", "FREQUENCIES"]
__version__ = "0.1.0"
