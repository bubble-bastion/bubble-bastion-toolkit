# dsh-arknights-stronghold

DSH 插件：**明日方舟「卫戍协议·规程」操作辅助**

给 DSH 加一组工具，让小泡能直接读回合状态、按网格精确放干员、查地块和干员资料。

> 全部通过 **adb 截图 + 模拟触摸** 实现，不修改游戏文件、不读内存、不注入进程。

---

## 提供的工具

| 工具 | 作用 |
|---|---|
| `arknights_roundstart` | 回合开始四步检查：金币 / 商店卡（含职业）/ 下一波敌人 / 商店升级费用 |
| `arknights_place` | 按九格网格放干员：自动收商店 → 找卡 → 拖到格子 → 划朝向 → **点格子核对名字** |
| `arknights_ready` | 点准备就绪 + 处理确认弹窗 + 等下一回合 |
| `arknights_grid` | 查网格坐标（像素 + 千分制），返回地面/围墙分类 |
| `arknights_operator` | 查干员资料：职业、位置（近战/远程）、等阶、词条 |
| `arknights_tiles` | 读游戏高亮的可放置格（最准的坐标来源） |
| `arknights_viewcheck` | 镜头校准（棋盘模板匹配） |

---

## 安装

```bash
# 在 DSH profile 目录
cd C:\Users\<你>\.dsh\profiles\desktop
pnpm add E:\DSH\dsh-arknights-stronghold
```

或者在 profile 的 `cordis.yml` 里引用本包。

## 配置

在 `cordis.yml` 里覆盖默认值：

```yaml
dsh-arknights-stronghold:
  adbPath: 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
  pythonPath: 'E:\DSH\vision\venv\Scripts\python.exe'
  powershellPath: 'powershell'
  port: 16416
  timeoutMs: 180000
```

| 字段 | 说明 |
|---|---|
| `adbPath` | MuMu 自带的 adb 路径（换模拟器要改） |
| `pythonPath` | 需要装 `opencv-python` `numpy` `rapidocr-onnxruntime` |
| `port` | adb 端口；填 0 让脚本自己问 MuMuManager |
| `timeoutMs` | 单次脚本超时，默认 3 分钟 |

---

## 前置条件

1. **MuMu 模拟器** 跑着明日方舟，分辨率 1280×720 横屏
2. `adb connect 127.0.0.1:16416` 能连上
3. Python 环境装好 `requirements.txt` 里的依赖

---

## 用法示例

```
用户：这回合该怎么办
小泡 → arknights_roundstart()
     → 金币 6 / 商店：摆渡人(近卫/近战) 褐果(医疗/远程) / 敌人：普通囚犯 / 升级费 2
     → 按规则：近战压 d 行，远程放围墙

小泡 → arknights_place(unit="摆渡人", tile="d7", face="right")
     → ✅ 放置正确（摆渡人 → d7）

小泡 → arknights_ready(wait=60)
     → 回合 4 / 剩余 6
```

---

## 内置资料

| 文件 | 内容 |
|---|---|
| `data/grid-ACSP2.json` | 九格网格坐标（19 个可放置格，地面/围墙分类，像素 + 千分制） |
| `data/operators.json` | 141 卫戍协议干员（职业/位置/等阶/词条/盟约）+ 70 装备 + 盟约 + 敌人 |
| `docs/01-规则手册.md` | 实战规则：阵型、地块、经济、操作、判读 |

### 核心规则摘要

```
阵型：敌人来的方向 ← 盾位 → 战士 → 输出 → 奶 → 自己蓝门
铁律1：输出的攻击范围必须覆盖前排挡怪那格
铁律2：远程不能放敌人必经之路（会被贴脸秒）
铁律3：钱每回合清零，必须花完（除「砍诺特」策略）
```

---

## 已知限制

1. **只适配 AC-SP-2 这一张图**，换图要重新标格子（用 `arknights_tiles` + 手动标注）
2. **整备区扫描不稳**：面板没关干净可能读到旧状态
3. **朝向滑动偶发失败**（已调到 400px / 1200ms）
4. **不做任何游戏内修改**，纯截图 + 触摸，受 UI 变化影响

---

## 免责声明

仅供学习与自动化技术研究。所有操作都是模拟人工点击/滑动，等同于玩家自己操作。
请遵守游戏用户协议，自行承担使用风险。

## License

MIT
