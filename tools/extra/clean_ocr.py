"""把 vocr 的 OCR 结果按帧整理成可读文本：去掉坐标噪声，按 y 排序，保留置信度高的行。"""
import re
import sys
from pathlib import Path

SRC = sys.argv[1] if len(sys.argv) > 1 else r"E:\DSH\vision\videos\BV1BTWH6nEXK\ocr_all.txt"
OUT = sys.argv[2] if len(sys.argv) > 2 else r"E:\DSH\vision\videos\BV1BTWH6nEXK\clean.txt"

PAT = re.compile(r"^(\d+),(\d+)\s+(\d+)x(\d+)\s+([\d.]+)\s+(.*)$")

sections = {}
cur = None
for line in Path(SRC).read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line.startswith("====="):
        cur = line.strip("= ").strip()
        sections[cur] = []
        continue
    if cur is None:
        continue
    m = PAT.match(line)
    if not m:
        continue
    x, y, w, h, score, text = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), float(m.group(5)), m.group(6).strip()
    if score < 0.85 or len(text) < 2:
        continue
    sections[cur].append((y, x, text))

out_lines = []
for name, items in sections.items():
    if not items:
        continue
    title = next((t for y, x, t in items if "盟约" in t and ("一图流" in t or "：" in t)), None)
    out_lines.append("")
    out_lines.append(f"########## {name}  {('【' + title + '】') if title else ''}")
    for y, x, t in sorted(items):
        col = "右" if x > 1150 else "左"
        out_lines.append(f"  [{col}] {t}")

Path(OUT).write_text("\n".join(out_lines), encoding="utf-8")
print(f"写入 {OUT}，共 {len(out_lines)} 行")
