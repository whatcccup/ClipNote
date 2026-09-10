import shutil
from pathlib import Path


def download_audio(url: str, output_dir: Path, cookiefile: Path | None = None, proxy: str | None = None) -> Path:
    try:
        import yt_dlp
    except ImportError as exc:
        raise RuntimeError("yt-dlp 未安装") from exc

    options: dict = {
        "format": "bestaudio[ext=m4a]/bestaudio[ext=aac]/bestaudio[ext=mp3]/bestaudio/best",
        "outtmpl": str(output_dir / "audio.%(ext)s"),
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "http_headers": {
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "User-Agent": "Mozilla/5.0 AppleWebKit/537.36 Chrome/126 Safari/537.36",
        },
    }
    if cookiefile:
        options["cookiefile"] = str(cookiefile)
    if proxy:
        options["proxy"] = proxy
    node = shutil.which("node")
    if node:
        options["js_runtimes"] = {"node": {"path": node}}
        options["remote_components"] = ["ejs:github"]

    try:
        with yt_dlp.YoutubeDL(options) as ydl:
            ydl.extract_info(url, download=True)
    except yt_dlp.DownloadError as exc:
        message = str(exc).upper()
        if (
            not proxy
            or "UNABLE TO DOWNLOAD WEBPAGE" not in message
            or "UNEXPECTED_EOF_WHILE_READING" not in message
        ):
            raise

        options.pop("proxy", None)
        with yt_dlp.YoutubeDL(options) as ydl:
            ydl.extract_info(url, download=True)

    candidates = [path for path in output_dir.glob("audio.*") if path.is_file()]
    if not candidates:
        raise RuntimeError("音频下载完成，但没有找到输出文件")
    return max(candidates, key=lambda path: path.stat().st_size)

