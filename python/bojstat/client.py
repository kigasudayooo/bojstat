"""日本銀行 時系列統計データ検索サイト API クライアント"""

from __future__ import annotations

import time
from typing import Optional, Union

import requests

from .constants import BASE_URL, DB_NAMES, FORMATS, FREQUENCIES, LANGUAGES


class BOJStatError(Exception):
    """BOJ統計APIのエラー"""
    def __init__(self, status: int, message_id: str, message: str):
        self.status = status
        self.message_id = message_id
        self.message = message
        super().__init__(f"[{status}] {message_id}: {message}")


class BOJStatClient:
    """
    日本銀行 時系列統計データ検索サイト API クライアント

    Parameters
    ----------
    lang : str
        出力言語。"jp"（日本語）または "en"（英語）。デフォルトは "jp"。
    timeout : int
        リクエストタイムアウト秒数。デフォルトは 30。
    request_interval : float
        連続リクエスト間の待機秒数（サーバー負荷軽減のため）。デフォルトは 1.0。

    Examples
    --------
    >>> from bojstat import BOJStatClient
    >>> client = BOJStatClient()
    >>> df = client.get_data(db="FM08", codes=["FXERD01"], start="202401", end="202412")
    >>> print(df.head())
    """

    def __init__(
        self,
        lang: str = "jp",
        timeout: int = 30,
        request_interval: float = 1.0,
    ):
        if lang not in LANGUAGES:
            raise ValueError(f"lang は {LANGUAGES} のいずれかを指定してください。")
        self.lang = lang
        self.timeout = timeout
        self.request_interval = request_interval
        self._session = requests.Session()
        self._session.headers.update({"Accept-Encoding": "gzip"})
        self._last_request_time: float = 0.0

    def _wait(self):
        """リクエスト間隔を確保する"""
        elapsed = time.time() - self._last_request_time
        if elapsed < self.request_interval:
            time.sleep(self.request_interval - elapsed)

    def _request(self, endpoint: str, params: dict) -> dict:
        """APIリクエストを実行してJSONを返す"""
        self._wait()
        params = {k: v for k, v in params.items() if v is not None}
        params.setdefault("format", "json")
        params.setdefault("lang", self.lang)

        url = f"{BASE_URL}/{endpoint}"
        resp = self._session.get(url, params=params, timeout=self.timeout)
        resp.raise_for_status()
        self._last_request_time = time.time()

        data = resp.json()
        status = data.get("STATUS", 0)
        if status != 200:
            raise BOJStatError(
                status=status,
                message_id=data.get("MESSAGEID", ""),
                message=data.get("MESSAGE", "Unknown error"),
            )
        return data

    def get_data(
        self,
        db: str,
        codes: list[str],
        start: Optional[str] = None,
        end: Optional[str] = None,
        start_position: Optional[int] = None,
    ) -> list[dict]:
        """
        コード API：系列コードを指定して時系列データを取得する。

        Parameters
        ----------
        db : str
            DB名（例: "FM08", "CO", "PR01"）。
        codes : list[str]
            系列コードのリスト（最大250件、同じ期種のみ）。
            ※ DB名を含む「データコード」（例: IR01'MADR1Z@D）ではなく、
               系列コード部分（例: MADR1Z@D）を指定してください。
        start : str, optional
            開始期。期種に応じた形式で指定。
            - 月次/週次/日次: "YYYYMM"（例: "202401"）
            - 四半期: "YYYYQQ"（例: "202401" = 2024Q1）
            - 暦年半期/年度半期: "YYYYHH"（例: "202501" = 2025年上期）
            - 暦年/年度: "YYYY"
        end : str, optional
            終了期。startと同じ形式で指定。
        start_position : int, optional
            検索開始位置（前回レスポンスのNEXTPOSITIONの値）。

        Returns
        -------
        list[dict]
            各系列のデータを含む辞書のリスト。
            各辞書のキー: SERIES_CODE, NAME_OF_TIME_SERIES_J（またはNAME_OF_TIME_SERIES）,
            UNIT_J（またはUNIT）, FREQUENCY, CATEGORY_J（またはCATEGORY）,
            LAST_UPDATE, VALUES（SURVEY_DATESとVALUESを含む）

        Raises
        ------
        BOJStatError
            APIがエラーを返した場合。
        ValueError
            パラメータが不正な場合。

        Examples
        --------
        >>> client = BOJStatClient()
        >>> data = client.get_data(db="FM01", codes=["STRDCLUCON"], start="202501")
        >>> for series in data:
        ...     print(series["SERIES_CODE"], series["VALUES"])
        """
        if not codes:
            raise ValueError("codes は1件以上指定してください。")
        if len(codes) > 250:
            raise ValueError("1リクエストあたりの系列コード数の上限は250件です。")
        db = db.upper()
        if db not in DB_NAMES:
            raise ValueError(f"不明なDB名: {db}。DB_NAMESを確認してください。")

        params = {
            "db": db,
            "code": ",".join(codes),
            "startDate": start,
            "endDate": end,
            "startPosition": start_position,
        }
        result = self._request("getDataCode", params)
        return result.get("RESULTSET", [])

    def get_data_all(
        self,
        db: str,
        codes: list[str],
        start: Optional[str] = None,
        end: Optional[str] = None,
    ) -> list[dict]:
        """
        コード API：系列数・データ数の上限を自動的にページネーションして全データを取得する。

        Parameters
        ----------
        db : str
            DB名。
        codes : list[str]
            系列コードのリスト（同じ期種のみ）。250件を超えても自動分割して取得。
        start : str, optional
            開始期。
        end : str, optional
            終了期。

        Returns
        -------
        list[dict]
            全系列のデータを含む辞書のリスト。
        """
        all_results: list[dict] = []

        # 250件ずつに分割してリクエスト
        chunk_size = 250
        for i in range(0, len(codes), chunk_size):
            chunk = codes[i: i + chunk_size]
            position = None

            while True:
                params = {
                    "db": db.upper(),
                    "code": ",".join(chunk),
                    "startDate": start,
                    "endDate": end,
                    "startPosition": position,
                }
                result = self._request("getDataCode", params)
                all_results.extend(result.get("RESULTSET", []))
                next_pos = result.get("NEXTPOSITION")
                if next_pos is None:
                    break
                position = next_pos

        return all_results

    def get_layer(
        self,
        db: str,
        frequency: str,
        layer: str,
        start: Optional[str] = None,
        end: Optional[str] = None,
        start_position: Optional[int] = None,
    ) -> list[dict]:
        """
        階層 API：階層情報を指定して時系列データを取得する。

        Parameters
        ----------
        db : str
            DB名（例: "FF", "BP01"）。
        frequency : str
            期種。"CY", "FY", "CH", "FH", "Q", "M", "W", "D" のいずれか。
        layer : str
            階層情報。カンマ区切りで階層1～5を指定（例: "1,1,1"）。
            "*" でワイルドカード指定可能（例: "*", "1,*"）。
        start : str, optional
            開始期。
        end : str, optional
            終了期。
        start_position : int, optional
            検索開始位置。

        Returns
        -------
        list[dict]
            各系列のデータを含む辞書のリスト。

        Examples
        --------
        >>> client = BOJStatClient()
        >>> data = client.get_layer(
        ...     db="BP01", frequency="M",
        ...     layer="1,1,1", start="202504", end="202509"
        ... )
        """
        db = db.upper()
        frequency = frequency.upper()
        if frequency not in FREQUENCIES and frequency != "W":
            raise ValueError(f"frequencyは {list(FREQUENCIES.keys())} のいずれかを指定してください。")

        params = {
            "db": db,
            "frequency": frequency,
            "layer": layer,
            "startDate": start,
            "endDate": end,
            "startPosition": start_position,
        }
        result = self._request("getDataLayer", params)
        return result.get("RESULTSET", [])

    def get_metadata(
        self,
        db: str,
        format: str = "json",
    ) -> list[dict]:
        """
        メタデータ API：系列コードや系列名称などのメタ情報を取得する。

        Parameters
        ----------
        db : str
            DB名（例: "FM08", "PR01"）。
        format : str
            出力形式。"json" または "csv"。デフォルトは "json"。

        Returns
        -------
        list[dict]
            各系列のメタ情報を含む辞書のリスト。
            キー: SERIES_CODE, NAME_OF_TIME_SERIES_J, UNIT_J, FREQUENCY,
            CATEGORY_J, LAYER1～LAYER5, START_OF_THE_TIME_SERIES,
            END_OF_THE_TIME_SERIES, LAST_UPDATE, NOTES_J

        Examples
        --------
        >>> client = BOJStatClient()
        >>> meta = client.get_metadata(db="FM08")
        >>> for m in meta[:3]:
        ...     print(m["SERIES_CODE"], m.get("NAME_OF_TIME_SERIES_J"))
        """
        db = db.upper()
        if db not in DB_NAMES:
            raise ValueError(f"不明なDB名: {db}。")
        if format not in FORMATS:
            raise ValueError(f"format は {FORMATS} のいずれかを指定してください。")

        params = {"db": db, "format": "json", "lang": self.lang}
        result = self._request("getMetadata", params)
        return result.get("RESULTSET", [])

    def list_databases(self) -> dict[str, str]:
        """
        利用可能なDB名と説明の一覧を返す。

        Returns
        -------
        dict[str, str]
            {DB名: 説明} の辞書。
        """
        return dict(DB_NAMES)

    def search_series(
        self,
        db: str,
        keyword: Optional[str] = None,
    ) -> list[dict]:
        """
        メタデータAPIを使って系列を検索する。

        Parameters
        ----------
        db : str
            DB名。
        keyword : str, optional
            系列名称に含まれるキーワード（大文字小文字を区別しない）。

        Returns
        -------
        list[dict]
            条件に合う系列のメタ情報リスト。
        """
        meta = self.get_metadata(db)
        if keyword is None:
            return meta
        kw = keyword.lower()
        name_key = "NAME_OF_TIME_SERIES_J" if self.lang == "jp" else "NAME_OF_TIME_SERIES"
        return [m for m in meta if kw in str(m.get(name_key, "")).lower()]

    def to_dataframe(self, data: list[dict]):
        """
        get_data / get_layer の結果を pandas DataFrame に変換する。

        Parameters
        ----------
        data : list[dict]
            get_data() または get_layer() の戻り値。

        Returns
        -------
        pandas.DataFrame
            インデックス: 日付（文字列）、カラム: 系列コード

        Notes
        -----
        pandas が必要です。pip install pandas でインストールしてください。
        """
        try:
            import pandas as pd
        except ImportError:
            raise ImportError("pandasが必要です: pip install pandas")

        frames = {}
        for series in data:
            code = series.get("SERIES_CODE", "")
            values_block = series.get("VALUES", {})
            if not isinstance(values_block, dict):
                continue
            dates = values_block.get("SURVEY_DATES", [])
            vals = values_block.get("VALUES", [])
            frames[code] = pd.Series(vals, index=dates, name=code)

        if not frames:
            return pd.DataFrame()
        return pd.DataFrame(frames)
