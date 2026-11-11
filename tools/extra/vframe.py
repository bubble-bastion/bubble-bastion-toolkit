"""下载 B站视频并按间隔抽高分辨率帧（比官方故事板 480x270 清晰得多）。

用法:
  python vframe.py <BV号或链接> [-n 帧数] [-every 秒] [-out 目录] [-q 1080]

例:
  python vframe.py BV1JZWt66ET7 -n 6
  python vframe.py https://www.bilibili.com/video/BV1rwWH69E7B -every 30
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

import cv2

PY = sys.executable
OUT_ROOT = Path(r"E:\DSH\vision\videos")


def ydl_download(url: str, outdir: Path, quality: int) -> Path:
    outdir.mkdir(parents=True, exist_ok=True)
    tmpl = str(outdir / "src.%(ext)s")
    fmt = f"bv*[height<={quality}]/bv*/b"
    cmd = [PY, "-m", "yt_dlp", "--no-warnings", "-f", fmt, "-o", tmpl, "--force-overwrites", url]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print("下载失败:", (r.stderr or r.stdout)[-500:])
        raise SystemExit(1)
    vids = list(outdir.glob("src.*"))
    if not vids:
        print("下载后找不到文件")
        raise SystemExit(1)
    return vids[0]


def extract(video: Path, outdir: Path, n: int = 0, every: float = 0.0) -> list:
    cap = cv2.VideoCapture(str(video))
    if not cap.isOpened():
        print("打不开视频文件")
        raise SystemExit(1)
    fps = cap.get(cv2.CAP_PROP_FPS) or 25
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    dur = total / fps if fps else 0
    print(f"视频: {video.name}  {fps:.1f}fps  {dur:.1f}s  {total} 帧")

    if every > 0:
        times = []
        t = 0.0
        while t < dur:
            times.append(t)
            t += every
    else:
        n = n or 6
        times = [dur * (i + 1) / (n + 1) for i in range(n)]

    saved = []
    for i, t in enumerate(times):
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, frame = cap.read()
        if not ok:
            continue
        h, w = frame.shape[:2]
        p = outdir / f"frame_{i:02d}_{int(t)}s.png"
        cv2.imwrite(str(p), frame)
        saved.append((p, t, w, h))
    cap.release()
    return saved


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("-n", type=int, default=6)
    ap.add_argument("-every", type=float, default=0)
    ap.add_argument("-out", default="")
    ap.add_argument("-q", type=int, default=1080)
    a = ap.parse_args()

    url = a.target if a.target.startswith("http") else f"https://www.bilibili.com/video/{a.target}"
    name = a.target.rstrip("/").split("/")[-1].split("?")[0]
    outdir = Path(a.out) if a.out else OUT_ROOT / name
    outdir.mkdir(parents=True, exist_ok=True)

    vid = ydl_download(url, outdir, a.q)
    saved = extract(vid, outdir, a.n, a.every)
    print(f"抽到 {len(saved)} 帧 -> {outdir}")
    for p, t, w, h in saved:
        print(f"  {p.name}  {w}x{h}")


if __name__ == "__main__":
    main()
