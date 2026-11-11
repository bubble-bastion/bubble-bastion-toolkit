# -*- coding: utf-8 -*-
"""建立 AC-SP-2 的 9 格坐标网格，并把「可放置地块」覆盖到棋盘截图上。
   锚点（实测）：
     d2 = (470,200)   围墙
     d7 = (820,200)   地面
     b6 = (750,297)   围墙
     a7 = (820,340)   地面
   规则：从蓝门(a1 侧)到红门(a9 侧)共 9 格，取格子中心为放置点。
        透视梯形：下大上小，每排行距不同。
"""
import json
import os

import cv2
import numpy as np

BASE = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights"
IMG = r"E:\DSH\vision\map_clean.png"
OUT_IMG = r"E:\DSH\vision\grid_overlay.png"
OUT_JSON = os.path.join(BASE, "九格网格-ACSP2.json")

# 行：y 坐标（透视，上小下大 -> 下面行距大）
ROWS = [
    ("d", 200, 70.0),   # 最上（红门那行），实测 d2=470 d7=820 -> 70/列
    ("c", 248, 71.5),
    ("b", 297, 73.0),   # 实测 b6=750
    ("a", 346, 75.0),   # 最下（蓝门那行），实测 a7=820
]
# 每行第 1 列的 x（由锚点反推）
X1 = {"d": 400, "c": 379, "b": 385, "a": 370}

# 可放置地块（老大给的）
GROUND = ["a2", "a3", "a7", "a8", "b3", "b7", "c3", "c7", "d3", "d4", "d5", "d6", "d7"]
WALL = ["b2", "b6", "c2", "c5", "c6", "d2"]


def cell(r, n):
    y, s = next((yy, ss) for (nm, yy, ss) in ROWS if nm == r)
    return (round(X1[r] + (n - 1) * s), y)


def main():
    grid = {}
    for nm, y, s in ROWS:
        for n in range(1, 10):
            grid[f"{nm}{n}"] = {"x": cell(nm, n)[0], "y": y,
                                "类型": ("地面" if f"{nm}{n}" in GROUND else
                                       "围墙" if f"{nm}{n}" in WALL else "不可放置")}

    # 校验锚点
    checks = [("d2", (470, 200)), ("d7", (820, 200)), ("b6", (750, 297)), ("a7", (820, 340))]
    print("锚点校验：")
    for name, real in checks:
        got = grid[name]
        print(f"  {name}: 模型({got['x']},{got['y']})  实测{real}  误差({abs(got['x']-real[0])},{abs(got['y']-real[1])})")

    json.dump({"说明": "AC-SP-2 九格坐标网格", "行": {nm: {"y": y, "列距": s, "第1列x": X1[nm]} for nm, y, s in ROWS},
               "格子": grid, "可放置_地面": GROUND, "可放置_围墙": WALL},
              open(OUT_JSON, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("\n已保存:", OUT_JSON)

    # 画到图上
    img = cv2.imread(IMG)
    if img is None:
        print("⚠ 找不到底图", IMG)
        return
    for name, g in grid.items():
        x, y, t = g["x"], g["y"], g["类型"]
        if t == "地面":
            color = (0, 255, 0)      # 绿：能阻挡
            thickness = 2
        elif t == "围墙":
            color = (255, 160, 0)    # 橙：能放但不阻挡
            thickness = 2
        else:
            color = (90, 90, 90)     # 灰：不可放置
            thickness = 1
        cv2.rectangle(img, (x - 30, y - 26), (x + 30, y + 26), color, thickness)
        if t != "不可放置":
            cv2.putText(img, name, (x - 22, y + 6), cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 1, cv2.LINE_AA)
        cv2.circle(img, (x, y), 2, (0, 0, 255), -1)   # 格子中心 = 放置点
    cv2.imwrite(OUT_IMG, img)
    print("已生成覆盖图:", OUT_IMG)


if __name__ == "__main__":
    main()
