# Debug Report - 2026-08-27

## Symptom
Bilibili transcript download failed with `SSL: UNEXPECTED_EOF_WHILE_READING` when the configured per-task proxy was used.

## Root Cause
The local proxy `http://127.0.0.1:1001` interrupted the TLS response for the Bilibili webpage. The same URL succeeded when downloaded directly.

## Fix
`download_audio` retries once without the proxy, but only for webpage extraction failures containing `UNEXPECTED_EOF_WHILE_READING`. Other download errors still fail immediately.

## Evidence
- yt-dlp direct extraction succeeded for `BV1p4DeB8ECi`.
- yt-dlp through the same proxy reproduced the reported SSL failure.
- After the fix, helper source downloaded the audio through proxy failure then direct retry: `audio.m4a`, 9,030,810 bytes.
- Regression test: `helper/tests/test_downloader.py`.
- `npm --prefix extension run build:chrome` passed with three existing size warnings.

## Status
DONE