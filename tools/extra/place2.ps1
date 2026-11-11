# 放置干员 v2：先按住看高亮，再挑一个真实可放置的格子落下。
# 相比 place.ps1（盲拖到估计坐标），这个不会「落到无效格」。
# 用法: place2.ps1 -FromX 840 -FromY 500 -ToX 700 -ToY 300 [-Face right|left|none]
param(
  [Parameter(Mandatory=$true)][int]$FromX,
  [Parameter(Mandatory=$true)][int]$FromY,
  [Parameter(Mandatory=$true)][int]$ToX,
  [Parameter(Mandatory=$true)][int]$ToY,
  [string]$Face = 'right',
  [int]$Port = 0
)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
# 端口自动解析：优先读 adb-port.txt（由 sync-ports.ps1 维护），否则问 MuMuManager
if ($Port -le 0) {
  $pf = 'E:\DSH\vision\adb-port.txt'
  if (Test-Path $pf) { $p0 = (Get-Content $pf -Raw).Trim(); if ($p0 -match '^\d+$') { $Port = [int]$p0 } }
}
if ($Port -le 0) {
  $mm = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'
  if (Test-Path $mm) {
    $info = & $mm info -v 1 2>&1 | Out-String
    if ($info -match '"adb_port"\s*:\s*(\d+)') { $Port = [int]$Matches[1] }
  }
}
if ($Port -le 0) { $Port = 16416 }
$dev = "127.0.0.1:$Port"
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_p2.png" *> $null
  & $adb -s $dev pull /sdcard/_p2.png "$v\$n" *> $null
  return "$v\$n"
}

# 0) 落点前后变化用（验证是否真的上去了）
# ── 强制步骤（老大 2026-11-11 13:30 定）：放干员前必须先收起商店 ──
# 商店展开时会盖住棋盘，拖动落点会落到商店上，干员就放错格。
# 实测：不收起时「摆渡人」反复被放到 d2 围墙里。
$probe = Shot 'p2_probe.png'
$ptxt = & $py "$v\ocr.py" $probe 2>$null
if ($ptxt -match '收起') {
  $cl = $ptxt | Where-Object { $_ -match '收起' } | Select-Object -First 1
  if ($cl -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
    $ccx = [int]$Matches[1] + [int]([int]$Matches[3] / 2)
    $ccy = [int]$Matches[2] + [int]([int]$Matches[4] / 2)
    & $adb -s $dev shell "input tap $ccx $ccy" *> $null
    "【强制】商店已收起"
    Start-Sleep -Milliseconds 1500
  }
}

$before = Shot 'p2_before.png'

# 1) 按住干员，等游戏画出可放置高亮
& $adb -s $dev shell "input motionevent DOWN $FromX $FromY; sleep 0.5; input motionevent MOVE $($FromX-4) $($FromY-12); sleep 1.3" *> $null
Start-Sleep -Milliseconds 400
$holdShot = Shot 'p2_hold.png'

# 2) 识别高亮格
$out = & $py "$v\tiles.py" $holdShot 2>$null
$jsonLine = $out | Where-Object { $_ -like 'JSON=*' } | Select-Object -First 1
if (-not $jsonLine) {
  "没识别到可放置格，松手取消"
  & $adb -s $dev shell "input motionevent UP $($FromX-4) $($FromY-12)" *> $null
  exit
}
$tiles = ($jsonLine -replace '^JSON=', '') | ConvertFrom-Json
"可放置格 $($tiles.Count) 个"

# 2.5) 判断高亮的语义（老大 2026-11-10 说明）：
#   未满员 -> 高亮是「空格」，放上去是新增
#   已满员 -> 高亮是「已有干员的格」，放上去是替换！必须先确认要换谁
$remainTxt = & $py "$v\ocr.py" $before 2>$null | Where-Object { $_ -match '剩余可放置角色' } | Select-Object -First 1
$remain = -1
if ($remainTxt -match '剩余可放置角色[：:]\s*(\d+)') { $remain = [int]$Matches[1] }
if ($remain -gt 0) {
  "当前未满员（剩余 $remain 个）：高亮=空格，放置将新增干员"
} elseif ($remain -eq 0) {
  "⚠ 当前已满员（剩余 0）：高亮=已有干员的格，放置将【替换】该格干员！"
} else {
  "⚠ 读不到剩余可放置，无法判断这次是新增还是替换"
}

# 3) 选离目标最近的格
$best = $tiles | Sort-Object { [math]::Sqrt([math]::Pow($_.x - $ToX, 2) + [math]::Pow($_.y - $ToY, 2)) } | Select-Object -First 1
"落点: 目标($ToX,$ToY) → 实际($($best.x),$($best.y))"

# 4) 先松手取消这次按住（干员会回整备区），再用单条 swipe 落到刚识别出的有效格。
#    多条 motionevent 拼接中间有命令行间隔，游戏读不到连续拖动，实测放不上去。
& $adb -s $dev shell "input motionevent UP $([int](($FromX-4)) ) $([int](($FromY-12)))" *> $null
Start-Sleep -Milliseconds 900
& $adb -s $dev shell "input swipe $FromX $FromY $($best.x) $($best.y) 1500" *> $null
Start-Sleep -Milliseconds 1300

# 5) 定朝向
if ($Face -ne 'none') {
  $fx = if ($Face -eq 'left') { $best.x - 220 } else { $best.x + 220 }
  & $adb -s $dev shell "input swipe $($best.x) $($best.y) $fx $($best.y) 600" *> $null
  Start-Sleep -Milliseconds 900
}

# 6) 硬验证：放置前后的「剩余可放置角色」对比
#    新增 -> 减 1 ；替换 -> 不变（因为场上人数没变）；失败 -> 也不变
$after = Shot 'p2_after.png'
$afterTxt = & $py "$v\ocr.py" $after 2>$null | Where-Object { $_ -match '剩余可放置角色' } | Select-Object -First 1
$remainAfter = -1
if ($afterTxt -match '剩余可放置角色[：:]\s*(\d+)') { $remainAfter = [int]$Matches[1] }

"=== 结果判定 ==="
"  放置前剩余: $(if($remain -ge 0){$remain}else{'读不到'})"
"  放置后剩余: $(if($remainAfter -ge 0){$remainAfter}else{'读不到'})"
if ($remain -ge 0 -and $remainAfter -ge 0) {
  if ($remainAfter -eq $remain - 1) { "  ✅ 新增成功（剩余减 1）" }
  elseif ($remainAfter -eq $remain) { "  ⚠ 数量没变 —— 可能落到了已有干员身上（替换），或没放上去" }
  else { "  ？数量变化异常（$remain → $remainAfter）" }
}
