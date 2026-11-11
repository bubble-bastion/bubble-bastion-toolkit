import json

db = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据库.json"
d = json.load(open(db, encoding="utf-8"))
ops = d["干员"]
print("总条数:", len(ops))
print()
print("=== 字段值分布 ===")
from collections import Counter
print("职业:", Counter(o.get("职业") for o in ops).most_common())
print("位置:", Counter(o.get("位置") for o in ops).most_common())
print()
WANT = ["慕斯", "褐果", "摆渡人", "角峰", "折桠", "烈夏", "拉普兰德", "陨星", "华法琳", "夏栎"]
print("=== 查询 ===")
for w in WANT:
    hit = [o for o in ops if o.get("名字") == w]
    if hit:
        o = hit[0]
        print("  " + w + "  职业=" + str(o.get("职业")) + "  位置=" + str(o.get("位置")) + "  等阶=" + str(o.get("等阶")))
    else:
        print("  " + w + "  没有")
