#!/usr/bin/env python3
"""Burn bilingual TSV captions into a cropped demo video."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


FONT_FILE = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"


def find_ffmpeg() -> str:
    for candidate in [
        "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg",
        "/usr/local/opt/ffmpeg-full/bin/ffmpeg",
    ]:
        if Path(candidate).is_file():
            return candidate
    fallback = shutil.which("ffmpeg")
    if not fallback:
        raise SystemExit("ffmpeg not found")
    return fallback


def to_seconds(value: str) -> float:
    match = re.fullmatch(r"(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?", value.strip())
    if not match:
        raise ValueError(f"Invalid timestamp: {value}")
    hours = int(match.group(1) or "0")
    minutes = int(match.group(2))
    seconds = int(match.group(3))
    millis_raw = match.group(4) or "0"
    millis = int(millis_raw.ljust(3, "0")[:3])
    return hours * 3600 + minutes * 60 + seconds + millis / 1000


def parse_rows(text: str) -> list[tuple[float, float, str, str]]:
    rows = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("start\t"):
            continue
        parts = [part.strip() for part in line.split("\t")]
        if len(parts) != 4:
            raise ValueError(f"Expected 4 tab-separated fields: {raw_line}")
        rows.append((to_seconds(parts[0]), to_seconds(parts[1]), parts[2], parts[3]))
    return rows


def drawtext_filter(textfile: str, font_size: int, y_expression: str, start: float, end: float) -> str:
    return (
        f"drawtext=fontfile={FONT_FILE}:textfile={textfile}:"
        f"fontcolor=white:fontsize={font_size}:bordercolor=black:borderw=3:"
        f"x=(w-text_w)/2:y={y_expression}:enable='between(t,{start},{end})'"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("timing")
    parser.add_argument("output")
    parser.add_argument("--crf", type=int, default=20)
    parser.add_argument("--preset", default="medium")
    args = parser.parse_args()

    timing_path = Path(args.timing)
    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.is_file():
        raise SystemExit(f"Input video not found: {input_path}")
    if not timing_path.is_file():
        raise SystemExit(f"Timing sheet not found: {timing_path}")

    rows = parse_rows(timing_path.read_text(encoding="utf-8"))
    if not rows:
        raise SystemExit("No timing rows found.")

    ffmpeg = find_ffmpeg()
    with tempfile.TemporaryDirectory(prefix="bilingual-captions-local-") as tmp:
        tmp_path = Path(tmp)
        filters = []
        for index, (start, end, zh, en) in enumerate(rows):
            zh_file = tmp_path / f"zh-{index}.txt"
            en_file = tmp_path / f"en-{index}.txt"
            zh_file.write_text(zh, encoding="utf-8")
            en_file.write_text(en, encoding="utf-8")
            filters.append(drawtext_filter(str(zh_file), 36, "h-72", start, end))
            filters.append(drawtext_filter(str(en_file), 30, "h-26", start, end))

        filter_graph = ",".join(filters)
        subprocess.run(
            [
                ffmpeg,
                "-hide_banner",
                "-loglevel",
                "warning",
                "-i",
                str(input_path),
                "-vf",
                filter_graph,
                "-c:v",
                "libx264",
                "-preset",
                args.preset,
                "-crf",
                str(args.crf),
                "-c:a",
                "copy",
                "-movflags",
                "+faststart",
                str(output_path),
                "-y",
            ],
            check=True,
        )

    print(f"Burned video written to: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
