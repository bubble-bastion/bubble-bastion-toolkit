# -*- coding: utf-8 -*-
"""把 games/arknights 下散落的 md / json 整合成两份文件：
   卫戍协议-资料库.md      —— 所有文档正文合并（按主题排序）
   卫戍协议-数据.json      —— 所有结构化数据合并（干员/装备/盟约/敌人/棋盘）
然后原始文件移到 _归档-原始文件/
"""
import json
import os
import shutil
from datetime import datetime

BASE = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights"
ARCH = os.path.join(BASE, "_归档-原始文件")

# ---------- 文档合并顺序（按重要性：规则 → 棋盘 → 敌人 → 流派 → 其它） ----------
MD_ORDER = [
    "强制规则.md",
    "布阵手册-ACSP2.md",
    "棋盘几何-ACSP2-实测.md",
    "敌人资料.md",
    "MY-TOOLKIT.md",
    "十大盟约-一图流全解.md",
    "盟约效果速查.md",
    "转职装备-变形同构体速查表.md",
    "通用运营策略.md",
    "通用叠层卡与经济卡.md",
    "远见-经济倒转.md",
    "规程-打法要点.md",
    "维多利亚-转职装备流.md",
    "萨尔贡-开技能流.md",
    "乌萨斯-运营思路.md",
    "莱塔尼亚-精奥迅莱.md",
    "谢拉格-冻结流.md",
    "伊比利亚-可胡可稳.md",
    "阿戈尔-灵巧融化流.md",
    "卡西米尔-部署充电流.md",
    "炎-现状与名单.md",
    "BUY-AND-PLACE-RULES.md",
    "DRAG-SWIPE.md",
    "UI-ANCHORS.md",
    "实时视觉闭环-可行性.md",
    "实机跑局记录-20261110.md",
    "实机跑局-20261111-第一局.md",
    "NEXT-STEPS.md",
    "配置检查报告.md",
    "重启后检查清单.md",
]

# stronghold 下的文档（放在附录）
MD_EXTRA = ["KB.md", "PLAY-NOTES.md", "README-KB.md", "rules.md", "ui-spec.md"]

# ---------- 数据合并 ----------
DATA_MAP = [
    ("干员", "卫戍协议-数据库.json", "干员"),
    ("干员补充", "卫戍协议-干员库.json", "干员"),
    ("装备", "卫戍协议-装备库.json", None),
    ("转职装备映射", "转职装备映射.json", None),
]


def load_json(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print("  ! 读取失败", os.path.basename(p), e)
        return None


def main():
    os.makedirs(ARCH, exist_ok=True)
    data = {"说明": "卫戍协议 AC-SP-2 资料库（整合版）",
            "生成时间": datetime.now().strftime("%Y-%m-%d %H:%M")}

    # ===== 数据合并 =====
    for key, fn, sub in DATA_MAP:
        p = os.path.join(BASE, fn)
        if not os.path.exists(p):
            continue
        j = load_json(p)
        if j is None:
            continue
        data[key] = j[sub] if (sub and isinstance(j, dict) and sub in j) else j
        print("  数据+ ", fn)

    # stronghold 里的数据文件
    for key, fn in [("盟约", "covenants.json"), ("策略", "strategies.json"),
                    ("敌人", "enemy-index.json"), ("组合", "combos.json"),
                    ("阵容", "roster.json"), ("装备2", "equipment.json")]:
        p = os.path.join(BASE, "stronghold", fn)
        if os.path.exists(p):
            j = load_json(p)
            if j is not None:
                data[key] = j
                print("  数据+  stronghold/" + fn)

    # 棋盘（用最新的 v3 模型）
    for fn in ["网格模型-ACSP2-v3.json", "可放置格-ACSP2-编号版.json"]:
        p = os.path.join(BASE, fn)
        if os.path.exists(p):
            data["棋盘"] = load_json(p)
            print("  数据+ ", fn)
            break

    out_json = os.path.join(BASE, "卫戍协议-数据.json")
    json.dump(data, open(out_json, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("写出:", out_json, round(os.path.getsize(out_json) / 1024), "KB")

    # ===== 文档合并 =====
    parts = ["# 卫戍协议 · 资料库（整合版）\n",
             "> 由多个分散文件合并而成，合并时间 " + data["生成时间"] + "\n",
             "> 原始文件在 `_归档-原始文件/` 里保留。\n",
             "\n---\n"]

    def add(fn, subdir=""):
        p = os.path.join(BASE, subdir, fn) if subdir else os.path.join(BASE, fn)
        if not os.path.exists(p):
            return False
        txt = open(p, encoding="utf-8", errors="ignore").read()
        title = subdir + "/" + fn if subdir else fn
        parts.append("\n\n<!-- ===== " + title + " ===== -->\n")
        parts.append("## 【" + os.path.splitext(fn)[0] + "】\n")
        parts.append(txt)
        return True

    n = 0
    for fn in MD_ORDER:
        if add(fn):
            n += 1
    parts.append("\n\n---\n\n# 附录：stronghold 原始笔记\n")
    for fn in MD_EXTRA:
        if add(fn, "stronghold"):
            n += 1

    out_md = os.path.join(BASE, "卫戍协议-资料库.md")
    open(out_md, "w", encoding="utf-8").write("".join(parts))
    print("写出:", out_md, round(os.path.getsize(out_md) / 1024), "KB,", n, "份文档")

    # ===== 归档原始文件 =====
    keep = {"卫戍协议-资料库.md", "卫戍协议-数据.json"}
    moved = 0
    for f in os.listdir(BASE):
        src = os.path.join(BASE, f)
        if os.path.isfile(src) and f not in keep:
            shutil.move(src, os.path.join(ARCH, f))
            moved += 1
    for f in os.listdir(os.path.join(BASE, "stronghold")):
        src = os.path.join(BASE, "stronghold", f)
        if os.path.isfile(src):
            shutil.move(src, os.path.join(ARCH, "stronghold_" + f))
            moved += 1
    shutil.rmtree(os.path.join(BASE, "stronghold"), ignore_errors=True)
    print("归档原始文件:", moved, "个 ->", ARCH)


if __name__ == "__main__":
    main()
