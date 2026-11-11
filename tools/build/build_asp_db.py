"""把 ASP Assistant 的卫戍协议数据 + 本机实机 OCR 数据合并成完整库。

输入:
  E:\\DSH\\vision\\asp\\operators.json   141 干员（盟约/词条/普通精锐）
  E:\\DSH\\vision\\asp\\equipment.json   70 装备
  games/arknights/卫戍协议-干员库.json   本机实机读到的攻防阻挡费用
输出:
  games/arknights/卫戍协议-数据库.json
"""
import json
from pathlib import Path

WS = Path(r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace")
ASP = Path(r"E:\DSH\vision\asp")
GAMES = WS / "games" / "arknights"


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8-sig"))


def main():
    ops = load(ASP / "operators.json")["operators"]
    eqs = load(ASP / "equipment.json")["equipment"]

    # 实机数据（按名字索引）
    local = {}
    lp = GAMES / "卫戍协议-干员库.json"
    if lp.exists():
        for o in load(lp)["干员"]:
            local[o["名字"]] = o

    # 基础游戏库（中文名 -> 职业/阻挡/部署费用/攻防）
    base = {}
    bp = GAMES / "干员库-中文.json"
    if bp.exists():
        for rec in load(bp)["干员"].values():
            base[rec["名字"]] = rec

    out_ops = []
    for o in ops:
        name = o["name"]
        rec = {
            "名字": name,
            "等阶": o.get("tier"),
            "核心盟约": o.get("coreCovenants", []),
            "附加盟约": o.get("additionalCovenants", []),
            "普通词条": [
                {"类型": t.get("traitType"), "说明": t.get("traitDescription")}
                for t in (o.get("normal", {}) or {}).get("traits", []) or []
            ],
            "精锐词条": [
                {"类型": t.get("traitType"), "说明": t.get("traitDescription")}
                for t in (o.get("elite", {}) or {}).get("traits", []) or []
            ],
        }
        if name in base:
            rec["职业"] = base[name]["职业"]
            rec["位置"] = base[name]["位置"]
            rec["阻挡"] = base[name]["阻挡"]
            rec["部署费用"] = base[name]["部署费用"]
        if name in local:
            for k in ("攻击", "防御", "阻挡", "购买费用", "备注"):
                if k in local[name]:
                    rec.setdefault(k, local[name][k])
            if not rec.get("核心盟约") and local[name].get("盟约"):
                rec["核心盟约"] = local[name]["盟约"]
        out_ops.append(rec)

    out_eq = []
    for e in eqs:
        rec = {
            "名字": e["name"],
            "等阶": e.get("tier"),
            "普通效果": (e.get("normal") or {}).get("effectDescription", ""),
            "精锐效果": (e.get("elite") or {}).get("effectDescription", ""),
        }
        out_eq.append(rec)

    # 统计
    cov = {}
    for o in out_ops:
        for c in o["核心盟约"]:
            cov[c] = cov.get(c, 0) + 1

    data = {
        "说明": "卫戍协议完整库：ASP Assistant(141干员/70装备) + 本机基础库(职业/阻挡/费用) + 实机OCR(攻防)",
        "来源": [
            "https://github.com/bingyunhe/asp-assistant-arknights (Apache 2.0)",
            "https://github.com/Moonfair/ASP_Assistant (上游)",
            "本机实机 OCR 记录",
        ],
        "干员数": len(out_ops),
        "装备数": len(out_eq),
        "盟约分布": dict(sorted(cov.items(), key=lambda kv: -kv[1])),
        "词条类型": sorted({t["类型"] for o in out_ops for t in o["普通词条"] if t["类型"]}),
        "干员": out_ops,
        "装备": out_eq,
    }
    p = GAMES / "卫戍协议-数据库.json"
    p.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"写入 {p.name}: {len(out_ops)} 干员 / {len(out_eq)} 装备")
    print("盟约分布:", data["盟约分布"])


if __name__ == "__main__":
    main()
