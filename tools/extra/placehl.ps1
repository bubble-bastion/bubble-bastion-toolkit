# 按「游戏自身高亮」放置：按住干员 → 读高亮格 → 按规则选一格 → 落子 → 核对
# 用法: placehl.ps1 -Unit 摆渡人 [-Pick topRight|right|bottom|top|left] [-Face right]
param(
  [Parameter(Mandatory = $true)][string]$Unit,
  [string]$Pick = 'right',
  [string]$Face = 'right',
  [int]$Port = 0
)
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

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_h.png" *> $null
  & $adb -s $dev pull /sdcard/_h.png "$v\$n" *> $null
  return "$v\$n"
}

# 1) 强制收起商店
$pr = Shot 'h_probe.png'
$pt = & $py "$v\ocr.py" $pr 2>$null
if ($pt -match '收起') {
  $cl = $pt | Where-Object { $_ -match '收起' } | Select-Object -First 1
  if ($cl -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
    & $adb -s $dev shell "input tap $(([int]$Matches[1]+[int]([int]$Matches[3]/2))) $(([int]$Matches[2]+[int]([int]$Matches[4]/2)))" *> $null
    "【强制】商店已收起"
    Start-Sleep -Milliseconds 1500
  }
}

# 2) 找干员
$src = $null
foreach ($y in @(640, 610, 500)) {
  foreach ($x in @(500, 560, 620, 680, 740, 800, 860, 920, 980, 1040, 1100)) {
    & $adb -s $dev shell "input tap $x $y" *> $null
    Start-Sleep -Milliseconds 360
    $s = Shot 'h_scan.png'
    $t = & $py "$v\ocr.py" $s 2>$null
    & $adb -s $dev shell "input tap 300 180" *> $null
    Start-Sleep -Milliseconds 150
    if (-not ($t -match '出售')) { continue }
    $nm = $t | Where-Object { $_ -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(\S+)' -and [int]$Matches[2] -ge 165 -and [int]$Matches[2] -le 205 -and [int]$Matches[1] -lt 240 } | Select-Object -First 1
    $name = if ($nm -match '\s(\S+)\s*$') { $Matches[1] } else { '' }
    if ($name -eq $Unit) { $src = @($x, $y); break }
  }
  if ($src) { break }
}
if (-not $src) { "✗ 整备区没找到 $Unit"; exit 1 }
"$Unit 在整备区 ($($src[0]),$($src[1]))"

# 3) 按住，读高亮
& $adb -s $dev shell "input motionevent DOWN $($src[0]) $($src[1])" *> $null
Start-Sleep -Milliseconds 700
& $adb -s $dev shell "input motionevent MOVE $($src[0]-6) $($src[1]-14)" *> $null
Start-Sleep -Milliseconds 1800
$hs = Shot 'h_hl.png'
& $adb -s $dev shell "input motionevent UP $($src[0]-6) $($src[1]-14)" *> $null
Start-Sleep -Milliseconds 500

$out = & $py "$v\tiles.py" $hs 2>$null
$jsonLine = $out | Where-Object { $_ -like 'JSON=*' } | Select-Object -First 1
if (-not $jsonLine) { "✗ 没读到高亮格"; exit 1 }
$tiles = ($jsonLine -replace '^JSON=', '') | ConvertFrom-Json
"高亮格 $($tiles.Count) 个: " + (($tiles | ForEach-Object { "($($_.x),$($_.y))" }) -join ' ')

# 4) 按规则选一格
$pick = switch ($Pick) {
  'right'    { $tiles | Sort-Object @{Expression = { $_.x }; Descending = $true} | Select-Object -First 1 }
  'topRight' { $tiles | Sort-Object @{Expression = { $_.y }; Descending = $false}, @{Expression = { $_.x }; Descending = $true} | Select-Object -First 1 }
  'left'     { $tiles | Sort-Object @{Expression = { $_.x }; Descending = $false} | Select-Object -First 1 }
  'bottom'   { $tiles | Sort-Object @{Expression = { $_.y }; Descending = $true} | Select-Object -First 1 }
  'top'      { $tiles | Sort-Object @{Expression = { $_.y }; Descending = $false} | Select-Object -First 1 }
  default    { $tiles | Select-Object -First 1 }
}
"选中格: ($($pick.x),$($pick.y))  [规则 $Pick]"

# 5) 落子
& $adb -s $dev shell "input swipe $($src[0]) $($src[1]) $($pick.x) $($pick.y) 1500" *> $null
Start-Sleep -Milliseconds 1200
if ($Face -ne 'none') {
  $fx = if ($Face -eq 'left') { $pick.x - 220 } elseif ($Face -eq 'down') { $pick.x } else { $pick.x + 220 }
  $fy = if ($Face -eq 'down') { $pick.y + 90 } elseif ($Face -eq 'up') { $pick.y - 90 } else { $pick.y }
  & $adb -s $dev shell "input swipe $($pick.x) $($pick.y) $fx $fy 600" *> $null
  Start-Sleep -Milliseconds 800
}

# 6) 核对
& $adb -s $dev shell "input tap $($pick.x) $($pick.y)" *> $null
Start-Sleep -Milliseconds 800
$cs = Shot 'h_check.png'
$ct = & $py "$v\ocr.py" $cs 2>$null
& $adb -s $dev shell "input tap 300 180" *> $null
$nm2 = $ct | Where-Object { $_ -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(\S+)' -and [int]$Matches[2] -ge 165 -and [int]$Matches[2] -le 205 -and [int]$Matches[1] -lt 240 } | Select-Object -First 1
$got = if ($nm2 -match '\s(\S+)\s*$') { $Matches[1] } else { '空' }
"核对: 落点上是【$got】"
if ($got -eq $Unit) { "✅ $Unit 已放到 ($($pick.x),$($pick.y))" } else { "⚠ 落在别处（期望 $Unit，实际 $got）" }
