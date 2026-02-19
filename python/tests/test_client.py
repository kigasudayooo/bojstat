"""bojstat のテスト"""

import pytest
from unittest.mock import MagicMock, patch

from bojstat import BOJStatClient, BOJStatError
from bojstat.constants import DB_NAMES


class TestBOJStatClient:
    def test_init_default(self):
        client = BOJStatClient()
        assert client.lang == "jp"
        assert client.timeout == 30
        assert client.request_interval == 1.0

    def test_init_english(self):
        client = BOJStatClient(lang="en")
        assert client.lang == "en"

    def test_init_invalid_lang(self):
        with pytest.raises(ValueError):
            BOJStatClient(lang="fr")

    def test_list_databases(self):
        client = BOJStatClient()
        dbs = client.list_databases()
        assert "FM08" in dbs
        assert "CO" in dbs
        assert "PR01" in dbs

    def test_get_data_invalid_db(self):
        client = BOJStatClient()
        with pytest.raises(ValueError, match="不明なDB名"):
            client.get_data(db="INVALID", codes=["CODE1"])

    def test_get_data_empty_codes(self):
        client = BOJStatClient()
        with pytest.raises(ValueError, match="1件以上"):
            client.get_data(db="FM08", codes=[])

    def test_get_data_too_many_codes(self):
        client = BOJStatClient()
        with pytest.raises(ValueError, match="250件"):
            client.get_data(db="FM08", codes=["CODE"] * 251)

    @patch("bojstat.client.BOJStatClient._request")
    def test_get_data_success(self, mock_request):
        mock_request.return_value = {
            "STATUS": 200,
            "NEXTPOSITION": None,
            "RESULTSET": [
                {
                    "SERIES_CODE": "STRDCLUCON",
                    "NAME_OF_TIME_SERIES_J": "無担保コールO/N物レート",
                    "FREQUENCY": "DAILY",
                    "VALUES": {
                        "SURVEY_DATES": ["20250101", "20250102"],
                        "VALUES": [0.25, 0.25],
                    },
                }
            ],
        }
        client = BOJStatClient()
        client._last_request_time = 0
        data = client.get_data(db="FM01", codes=["STRDCLUCON"], start="202501")
        assert len(data) == 1
        assert data[0]["SERIES_CODE"] == "STRDCLUCON"

    @patch("bojstat.client.BOJStatClient._request")
    def test_boj_stat_error(self, mock_request):
        mock_request.return_value = {
            "STATUS": 400,
            "MESSAGEID": "M181005E",
            "MESSAGE": "DB名が正しくありません。",
        }
        # _requestの中でエラー判定するのでモックを調整
        def raise_error(*args, **kwargs):
            raise BOJStatError(400, "M181005E", "DB名が正しくありません。")
        mock_request.side_effect = raise_error

        client = BOJStatClient()
        with pytest.raises(BOJStatError) as exc_info:
            client.get_data(db="FM01", codes=["STRDCLUCON"])
        assert exc_info.value.status == 400

    @patch("bojstat.client.BOJStatClient._request")
    def test_to_pandas(self, mock_request):
        pytest.importorskip("pandas")
        mock_request.return_value = {
            "STATUS": 200,
            "NEXTPOSITION": None,
            "RESULTSET": [
                {
                    "SERIES_CODE": "CODE1",
                    "VALUES": {
                        "SURVEY_DATES": ["202501", "202502"],
                        "VALUES": [1.0, 2.0],
                    },
                }
            ],
        }
        client = BOJStatClient()
        client._last_request_time = 0
        data = client.get_data(db="FM01", codes=["CODE1"])
        df = client.to_pandas(data)
        assert "CODE1" in df.columns
        assert len(df) == 2

    @patch("bojstat.client.BOJStatClient._request")
    def test_to_dataframe_alias(self, mock_request):
        """to_dataframe は to_pandas のエイリアス"""
        pytest.importorskip("pandas")
        mock_request.return_value = {
            "STATUS": 200,
            "NEXTPOSITION": None,
            "RESULTSET": [
                {
                    "SERIES_CODE": "CODE1",
                    "VALUES": {
                        "SURVEY_DATES": ["202501", "202502"],
                        "VALUES": [1.0, 2.0],
                    },
                }
            ],
        }
        client = BOJStatClient()
        client._last_request_time = 0
        data = client.get_data(db="FM01", codes=["CODE1"])
        df = client.to_dataframe(data)
        assert "CODE1" in df.columns
        assert len(df) == 2

    @patch("bojstat.client.BOJStatClient._request")
    def test_to_polars(self, mock_request):
        pytest.importorskip("polars")
        mock_request.return_value = {
            "STATUS": 200,
            "NEXTPOSITION": None,
            "RESULTSET": [
                {
                    "SERIES_CODE": "CODE1",
                    "VALUES": {
                        "SURVEY_DATES": ["202501", "202502"],
                        "VALUES": [1.0, 2.0],
                    },
                },
                {
                    "SERIES_CODE": "CODE2",
                    "VALUES": {
                        "SURVEY_DATES": ["202501", "202502"],
                        "VALUES": [3.0, 4.0],
                    },
                },
            ],
        }
        import polars as pl

        client = BOJStatClient()
        client._last_request_time = 0
        data = client.get_data(db="FM01", codes=["CODE1", "CODE2"])
        df = client.to_polars(data)
        assert isinstance(df, pl.DataFrame)
        assert "date" in df.columns
        assert "CODE1" in df.columns
        assert "CODE2" in df.columns
        assert len(df) == 2
        assert df["CODE1"].to_list() == [1.0, 2.0]

    def test_to_polars_empty(self):
        pytest.importorskip("polars")
        import polars as pl

        client = BOJStatClient()
        df = client.to_polars([])
        assert isinstance(df, pl.DataFrame)
        assert len(df) == 0
