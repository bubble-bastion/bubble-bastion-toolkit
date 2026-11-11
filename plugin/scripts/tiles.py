"""从「按住干员」的截图里找出游戏高亮的可放置格。

高亮是黄绿色半透明网格：G 远高于 B、R 中等。实测 rgb≈(120,170,50)。
（注意：不是青绿！之前按 b>110 过滤会全部漏掉。）

用法: python tiles.py <截图>
输出: 每个格子的中心坐标 + 尺寸，最后给一行 JSON
"""
import json
import sys
from collections import deque

from PIL import Image

MIN_PIXELS = 400
MIN_W, MIN_H = 35, 20
MAX_W, MAX_H = 140, 140


def main():
    path = sys.argv[1]
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()

    mask = [[False] * w for _ in range(h)]
    for y in range(100, min(540, h)):
        for x in range(w):
            r, g, b = px[x, y]
            if g > 130 and g - b > 60 and g - r > 20:
                mask[y][x] = True

    seen = [[False] * w for _ in range(h)]
    tiles = []
    for y0 in range(100, min(540, h)):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            q = deque([(x0, y0)])
            seen[y0][x0] = True
            mnx = mxx = x0
            mny = mxy = y0
            n = 0
            while q:
                x, y = q.popleft()
                n += 1
                mnx = min(mnx, x); mxx = max(mxx, x)
                mny = min(mny, y); mxy = max(mxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        q.append((nx, ny))
            bw, bh = mxx - mnx + 1, mxy - mny + 1
            if n >= MIN_PIXELS and MIN_W <= bw <= MAX_W and MIN_H <= bh <= MAX_H:
                tiles.append({"x": mnx + bw // 2, "y": mny + bh // 2, "w": bw, "h": bh})

    tiles.sort(key=lambda t: (t["y"] // 35, t["x"]))
    print(f"可放置格 {len(tiles)} 个：")
    for t in tiles:
        print(f"  ({t['x']},{t['y']})  {t['w']}x{t['h']}")
    # 给上层脚本用
    print("JSON=" + json.dumps(tiles, ensure_ascii=False))


if __name__ == "__main__":
    main()
