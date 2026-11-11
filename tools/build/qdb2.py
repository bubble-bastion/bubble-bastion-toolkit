import json
import os

BASE = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights"
FILES = ["卫戍协议-数据库.json", "干员库-中文.json", "卫戍协议-干员库.json", "operators.json"]
WANT = ["慕斯", "褐果", "摆渡人", "角峰", "折桠", "烈夏", "拉普兰德", "陨星", "华法琳", "夏栎"]

for fn in FILES:
    p = os.path.join(BASE, fn)
    if not os.path.exists(p):
        continue
    try:
        d = json.load(open(p, encoding="utf-8"))
    except Exception as e:
        print(fn, "读取失败", e)
        continue
    # 找到干员列表
    lst = None
    if isinstance(d, dict):
        for k in ("干员", "operators", "data"):
            if isinstance(d.get(k), list):
                lst = d[k]
                break
        if lst is None:
            # 可能是 {名字: {...}}
            cand = [v for v in d.values() if isinstance(v, list)]
            if cand:
                lst = cand[0]
    elif isinstance(d, list):
        lst = d
    if not lst:
        print(fn, "：没识别出干员列表")
        continue
    print(f"== {fn} （{len(lst)} 条）==")
    sample = lst[0]
    if isinstance(sample, dict):
        keys = list(sample.keys())[:8]
        print("   字段示例:", keys)
    for w in WANT:
        hit = None
        for o in lst:
            if isinstance(o, dict):
                nm = o.get("名字") or o.get("name") or o.get("干员") or ""
                if nm == w:
                    hit = o
                    break
            elif isinstance(o, str) and o == w:
                hit = {"名字": w}
                break
        if hit:
            brief = {k: v for k, v in list(hit.items())[:6]}
            print("   " + w + " → " + json.dumps(brief, ensure_ascii=False))
        else:
            print("   " + w + " → 没有")
