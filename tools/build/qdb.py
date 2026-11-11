import json
import sys

db = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-干员库.json"
d = json.load(open(db, encoding="utf-8"))
ops = d["干员"]
print("资料库共", len(ops), "个干员")
for want in ["慕斯", "褐果", "摆渡人", "角峰", "折桠", "烈夏", "拉普兰德", "陨星", "褐果"]:
    hit = [o for o in ops if o.get("名字") == want]
    if hit:
        o = hit[0]
        print("  " + want,
              "| 职业=" + str(o.get("职业")),
              "| 攻击=" + str(o.get("攻击")),
              "| 防御=" + str(o.get("防御")),
              "| 阻挡=" + str(o.get("阻挡")),
              "| 盟约=" + str(o.get("盟约")))
    else:
        print("  " + want + " ：库里没有")
