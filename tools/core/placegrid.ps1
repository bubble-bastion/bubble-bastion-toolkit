# 按九格网格放置干员：只允许落到「可放置地块」，放完自动核对
# 用法: placegrid.ps1 -Unit 摆渡人 -Tile d6 [-Face right|down|left|up]
param(
  [Parameter(Mandatory = $true)][string]$Unit,
  [Parameter(Mandatory = $true)][string]$Tile,
  [string]$Face = 'right',
  [int]$FromX = 0,
  [int]$FromY = 0,
  [int]$Port = 0
)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$gridPath = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\九格网格-ACSP2.json'
if ($Port -le 0) {
  $pf = "$v\adb-port.txt"
  if (Test-Path $pf) { $p0 = (Get-Content $pf -Raw).Trim(); if ($p0 -match '^\d+$') { $Port = [int]$p0 } }
}
if ($Port -le 0) { $Port = 16416 }
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_g.png" *> $null
  & $adb -s $dev pull /sdcard/_g.png "$v\$n" *> $null
  return "$v\$n"
}

# ---- 1) 查网格，拒绝不可放置格 ----
$grid = Get-Content $gridPath -Raw -Encoding UTF8 | ConvertFrom-Json
# 优先用千分制（与分辨率无关）
$pm = $grid.千分制.格子.$Tile
if ($pm) {
  $类型 = $pm.类型
  if ($类型 -eq '不可放置') { "✗ $Tile 是不可放置地块，拒绝放置"; exit 1 }
  # 读当前设备分辨率
  $sz = (& $adb -s $dev shell "wm size" 2>$null) -join ' '
  $SW = 1280; $SH = 720
  if ($sz -match '(\d+)x(\d+)') { $SW = [int]$Matches[1]; $SH = [int]$Matches[2] }
  if ($SW -gt $SH) { $TW = $SW; $TH = $SH } else { $TW = $SH; $TH = $SW }
  $tx0 = [int]($pm.permille[0] / 1000.0 * $TW)
  $ty0 = [int]($pm.permille[1] / 1000.0 * $TH)
  "千分制坐标: [$($pm.permille[0]), $($pm.permille[1])]  →  屏幕 ${TW}x${TH} 上 ($tx0,$ty0)"
} else {
  $cell = $grid.格子.$Tile
  if (-not $cell) { "✗ 网格里没有 $Tile"; exit 1 }
  $类型 = $cell.类型
  if ($类型 -eq '不可放置') { "✗ $Tile 是不可放置地块，拒绝放置"; exit 1 }
  $tx0 = [int]$cell.x; $ty0 = [int]$cell.y
}
# ---- 视图补偿：镜头被拖动/缩放时，网格坐标要跟着平移 ----
$dx = 0; $dy = 0
$vj = "$v\view_offset.json"
if (Test-Path $vj) {
  $vo = Get-Content $vj -Raw -Encoding UTF8 | ConvertFrom-Json
  $dx = [double]$vo.dx; $dy = [double]$vo.dy
  if ([Math]::Abs($dx) -gt 200 -or [Math]::Abs($dy) -gt 200) { $dx = 0; $dy = 0 }
}
$tx = [int]($tx0 + $dx); $ty = [int]($ty0 + $dy)
"目标: $Tile 网格($tx0,$ty0) + 视图偏移($([int]$dx),$([int]$dy)) = 实际($tx,$ty)  类型=$类型"

# ---- 2) 强制先收起商店 ----
$probe = Shot 'g_probe.png'
$ptxt = & $py "$v\ocr.py" $probe 2>$null
if ($ptxt -match '收起') {
  $cl = $ptxt | Where-Object { $_ -match '收起' } | Select-Object -First 1
  if ($cl -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
    & $adb -s $dev shell "input tap $(([int]$Matches[1]+[int]([int]$Matches[3]/2))) $(([int]$Matches[2]+[int]([int]$Matches[4]/2)))" *> $null
    "【强制】商店已收起"
    Start-Sleep -Milliseconds 1500
  }
}

# ---- 3) 在整备区找到这个干员 ----
$src = $null
if ($FromX -gt 0 -and $FromY -gt 0) {
  $src = @($FromX, $FromY)
  "使用手动指定位置: ($FromX,$FromY)"
}
foreach ($y in @(640, 610, 500)) {
  foreach ($x in @(560, 660, 760, 860, 960, 1060, 1160)) {
    & $adb -s $dev shell "input tap $x $y" *> $null
    Start-Sleep -Milliseconds 380
    $s = Shot 'g_scan.png'
    $t = & $py "$v\ocr.py" $s 2>$null
    & $adb -s $dev shell "input tap 1150 400" *> $null
    Start-Sleep -Milliseconds 250
    if (-not ($t -match '出售')) { continue }
    $nm = $t | Where-Object { $_ -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(\S+)' -and [int]$Matches[2] -ge 165 -and [int]$Matches[2] -le 205 -and [int]$Matches[1] -lt 240 } | Select-Object -First 1
    $name = if ($nm -match '\s(\S+)\s*$') { $Matches[1] } else { '' }
    if ($name -eq $Unit) { $src = @($x, $y); break }
  }
  if ($src) { break }
}
if (-not $src) { "✗ 整备区没找到 $Unit"; exit 1 }
"整备区: $Unit 在 ($($src[0]),$($src[1]))"

# ---- 4) 一条 swipe 落下 ----
# 从卡片偏左一点按下（避免按到卡片边缘导致拖不动）
$sx = $src[0] - 30
& $adb -s $dev shell "input swipe $sx $($src[1]) $tx $ty 1500" *> $null
Start-Sleep -Milliseconds 1200
if ($Face -ne 'none') {
  $fx = if ($Face -eq 'left') { $tx - 400 } elseif ($Face -eq 'down') { $tx } else { $tx + 400 }
  $fy = if ($Face -eq 'down') { $ty + 260 } elseif ($Face -eq 'up') { $ty - 260 } else { $ty }
  & $adb -s $dev shell "input swipe $tx $ty $fx $fy 1200" *> $null
  Start-Sleep -Milliseconds 800
}

# ---- 5) 核对：点目标格读名字 ----
& $adb -s $dev shell "input tap $tx $ty" *> $null
Start-Sleep -Milliseconds 800
$cs = Shot 'g_check.png'
$ct = & $py "$v\ocr.py" $cs 2>$null
& $adb -s $dev shell "input tap 1150 400" *> $null
$nm2 = $ct | Where-Object { $_ -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(\S+)' -and [int]$Matches[2] -ge 165 -and [int]$Matches[2] -le 205 -and [int]$Matches[1] -lt 240 } | Select-Object -First 1
$got = if ($nm2 -match '\s(\S+)\s*$') { $Matches[1] } else { '空' }
"核对: $Tile 上现在是【$got】"
if ($got -eq $Unit) { "✅ 放置正确（$Unit → $Tile）" } else { "⚠ 落在别处了（期望 $Unit，实际 $got）" }
