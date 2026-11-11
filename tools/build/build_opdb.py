"""把游戏数据（中文名）合并进干员库。

输入:
  E:\\DSH\\vision\\character_table.json   游戏源数据（含中文名/职业/阻挡/属性）
  games/arknights/operators.json          现有库（英文键，含 id/position/block/cost/atk/hp/skills）
输出:
  games/arknights/干员库-中文.json        中文名 + 关键字段，方便按中文名查

用法: python build_opdb.py
"""
import json
from pathlib import Path

WS = Path(r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace")
SRC = Path(r"E:\DSH\vision\character_table.json")
OLD = WS / "games" / "arknights" / "operators.json"
OUT = WS / "games" / "arknights" / "干员库-中文.json"

PROF = {
    "PIONEER": "先锋", "WARRIOR": "近卫", "SNIPER": "狙击", "TANK": "重装",
    "MEDIC": "医疗", "SUPPORT": "辅助", "CASTER": "术师", "SPECIAL": "特种",
    "TOKEN": "召唤物", "TRAP": "陷阱",
}
POS = {"RANGED": "远程", "MELEE": "近战", "ALL": "全部", "NONE": "无"}


def main():
    src = json.loads(SRC.read_text(encoding="utf-8"))
    old = json.loads(OLD.read_text(encoding="utf-8"))["operators"]

    # id -> 英文键
    id2key = {v.get("id"): k for k, v in old.items() if v.get("id")}

    out = {}
    for cid, c in src.items():
        if not c.get("name"):
            continue
        prof = PROF.get(c.get("profession"), c.get("profession") or "")
        pos = POS.get(c.get("position"), c.get("position") or "")
        # 基础属性在 phases[-1].attributesKeyFrames[-1].data
        atk = hp = df = blk = cst = 0
        try:
            phases = c.get("phases") or []
            frames = (phases[-1].get("attributesKeyFrames") or []) if phases else []
            if frames:
                d = frames[-1].get("data") or {}
                atk = d.get("atk", 0); hp = d.get("maxHp", 0); df = d.get("def", 0)
                blk = d.get("blockCnt", 0); cst = d.get("cost", 0)
        except Exception:
            pass
        key = id2key.get(cid)
        rec = {
            "名字": c.get("name"),
            "职业": prof,
            "位置": pos,
            "阻挡": blk,
            "部署费用": cst,
            "攻击": atk,
            "防御": df,
            "生命": hp,
            "稀有度": c.get("rarity", ""),
        }
        if key:
            rec["英文键"] = key
            rec["技能"] = old[key].get("skills", [])
        out[cid] = rec

    OUT.write_text(json.dumps(
        {"说明": "中文干员库（游戏源数据 + 旧库合并）", "数量": len(out), "干员": out},
        ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"写入 {OUT.name}：{len(out)} 人")


if __name__ == "__main__":
    main()
