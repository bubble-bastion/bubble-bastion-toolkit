# 视图校准 v2：用「棋盘局部」模板匹配，算出当前画面相对基准图的平移 + 缩放。
# 输出 E:\DSH\vision\view_offset.json {dx,dy,scale,ok}
param([int]$Port = 0)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
if ($Port -le 0) {
  $pf = "$v\adb-port.txt"
  if (Test-Path $pf) { $p0 = (Get-Content $pf -Raw).Trim(); if ($p0 -match '^\d+$') { $Port = [int]$p0 } }
}
if ($Port -le 0) { $Port = 16416 }
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null
& $adb -s $dev shell "screencap -p /sdcard/_vc.png" *> $null
& $adb -s $dev pull /sdcard/_vc.png "$v\view_now.png" *> $null

& $py -c @"
import json
import cv2
import numpy as np

ref = cv2.imread(r'$v\map_clean.png')
cur = cv2.imread(r'$v\view_now.png')
out = {'dx': 0, 'dy': 0, 'scale': 1.0, 'ok': False, '依据': '模板匹配失败'}
if ref is not None and cur is not None:
    x0, y0, x1, y1 = 600, 250, 820, 360
    tpl = ref[y0:y1, x0:x1]
    best = None
    for s in np.arange(0.80, 1.25, 0.02):
        t = cv2.resize(tpl, None, fx=s, fy=s)
        if t.shape[0] >= cur.shape[0] or t.shape[1] >= cur.shape[1]:
            continue
        res = cv2.matchTemplate(cur, t, cv2.TM_CCOEFF_NORMED)
        _, mx, _, loc = cv2.minMaxLoc(res)
        if best is None or mx > best[0]:
            best = (mx, s, loc)
    score, s, loc = best
    dx = loc[0] - x0 * s
    dy = loc[1] - y0 * s
    ok = score > 0.55 and abs(s - 1.0) < 0.12
    out = {'dx': round(float(dx), 1), 'dy': round(float(dy), 1), 'scale': round(float(s), 3),
           'score': round(float(score), 3), 'ok': bool(ok),
           '依据': '棋盘模板匹配(x600-820,y250-360)' if ok else '匹配分低或缩放异常，视图可能被大幅拖动'}
json.dump(out, open(r'$v\view_offset.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('偏移 dx=%.1f dy=%.1f 缩放=%.3f 匹配分=%.3f %s' % (out['dx'], out['dy'], out['scale'], out.get('score', 0), 'OK' if out['ok'] else 'WARN'))
"@ 2>&1
