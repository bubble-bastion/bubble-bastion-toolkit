import json

# 实测锚点（扫描棋盘得到像素 + 老大给的编号）
# 摆渡人 (735,233) = c6
# 卡达   (820,368) = a7
# 解方程: x(row n) = X_row + (n-2)*s
#   c6: X_c + 4s = 735
#   a7: X_a + 5s = 820
# 假设行间 x 漂移很小 (X_a ≈ X_c - 4):
#   -> s = 89, X_c = 379, X_a = 375
S = 89
ROW_Y = {"a": 368, "b": 297, "c": 233, "d": 167}
ROW_X = {"a": 375, "b": 377, "c": 379, "d": 381}


def P(r, n):
    return (round(ROW_X[r] + (n - 2) * S), ROW_Y[r])


WALLS = ["b2", "b6", "c2", "c5", "c6", "d2"]
GROUND = ["a2", "a3", "a7", "a8", "b3", "b7", "c3", "c7",
          "d3", "d4", "d5", "d6", "d7"]

print("列间距 s =", S)
print("校验锚点: c6 =", P("c", 6), " (实测 735,233)")
print("校验锚点: a7 =", P("a", 7), " (实测 820,368)")
print()
print("=== 围墙（能放人但不阻挡）===")
for n in WALLS:
    print("  %-3s %s" % (n, P(n[0], int(n[1:]))))
print()
print("=== 地面（能阻挡，近战必须放这里）===")
for n in GROUND:
    print("  %-3s %s" % (n, P(n[0], int(n[1:]))))

out = {
    "说明": "AC-SP-2 网格模型 v3（用实测锚点反推，2026-11-11 13:10）",
    "锚点_实测": {
        "c6": [735, 233],
        "a7": [820, 368]
    },
    "网格": {"列间距": S, "行y": ROW_Y, "行x基准_列2": ROW_X},
    "围墙": {n: P(n[0], int(n[1:])) for n in WALLS},
    "地面": {n: P(n[0], int(n[1:])) for n in GROUND},
    "注意": "落点会偏离目标：实测 夏栎 目标(807,297)→实际(735,297) 偏 -72px；卡达 目标(724,297)→实际(820,368)。所以每次放完必须扫描核对，不能假设落准了。"
}
p = r"C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\网格模型-ACSP2-v3.json"
json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print()
print("已保存:", p)
