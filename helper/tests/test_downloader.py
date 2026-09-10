import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

from transcript_helper.downloader import download_audio


class FakeDownloadError(Exception):
    pass


class FakeYoutubeDL:
    calls: list[str | None] = []

    def __init__(self, options, output_dir=None):
        self.options = options
        self.output_dir = output_dir

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return None

    def extract_info(self, url, download=True):
        self.calls.append(self.options.get("proxy"))
        if "proxy" in self.options:
            raise FakeDownloadError("Unable to download webpage: SSL: UNEXPECTED_EOF_WHILE_READING")
        (self.output_dir / "audio.m4a").write_bytes(b"audio")


class DownloaderProxyFallbackTest(unittest.TestCase):
    def test_retries_directly_when_proxy_breaks_tls(self):
        with TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)
            fake_module = SimpleNamespace(
                YoutubeDL=lambda options: FakeYoutubeDL(options, output_dir),
                DownloadError=FakeDownloadError,
            )
            FakeYoutubeDL.calls.clear()
            with patch.dict(sys.modules, {"yt_dlp": fake_module}):
                audio = download_audio(
                    "https://www.bilibili.com/video/BV1p4DeB8ECi",
                    output_dir,
                    proxy="http://127.0.0.1:1001",
                )

            self.assertEqual(audio.read_bytes(), b"audio")
            self.assertEqual(FakeYoutubeDL.calls, ["http://127.0.0.1:1001", None])


if __name__ == "__main__":
    unittest.main()