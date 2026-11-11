# 校准棋盘格子：自动识别商店收起/展开两套布局，各抓一次「按住干员」的可放置高亮。
# 用法: calib.ps1 [-Port 0]
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
if ($Port -le 0) {
  $mm = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'
  $info = & $mm info -v 1 2>&1 | Out-String
  if ($info -match '"adb_port"\s*:\s*(\d+)') { $Port = [int]$Matches[1] }
}
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_c.png" *> $null
  & $adb -s $dev pull /sdcard/_c.png "$v\$n" *> $null
  return "$v\$n"
}

# 判断当前布局：有「收起」= 展开；有「展开」= 收起
function 布局() {
  $s = Shot 'c_probe.png'
  $t = & $py "$v\ocr.py" $s 2>$null
  if ($t -match '收起') { return 'expanded' }
  if ($t -match '展开') { return 'collapsed' }
  return 'unknown'
}

# 在指定 y 行找整备区干员（点一下看有没有「出售」）
function 找干员($y) {
  foreach ($x in @(700,780,860,940,1020,1100)) {
    & $adb -s $dev shell "input tap $x $y" *> $null
    Start-Sleep -Milliseconds 550
    $s = Shot 'c_scan.png'
    $t = & $py "$v\ocr.py" $s 2>$null
    & $adb -s $dev shell "input tap 300 180" *> $null
    Start-Sleep -Milliseconds 250
    if ($t -match '出售') { return $x }
    # 点到空白会把商店弹开，检测到就再收起来
    if (($t -match '收起') -and $y -eq 610) {
      & $adb -s $dev shell "input tap 1180 665" *> $null
      Start-Sleep -Milliseconds 900
    }
  }
  return 0
}

# 按住 → 截图 → 松手 → 识别
function 抓高亮($x, $y, $tag) {
  & $adb -s $dev shell "input motionevent DOWN $x $y" *> $null
  Start-Sleep -Milliseconds 700
  & $adb -s $dev shell "input motionevent MOVE $($x-6) $($y-14)" *> $null
  Start-Sleep -Milliseconds 1800
  $s = Shot "calib_$tag.png"
  & $adb -s $dev shell "input motionevent UP $($x-6) $($y-14)" *> $null
  Start-Sleep -Milliseconds 700
  $out = & $py "$v\tiles.py" $s 2>$null
  $json = ($out | Where-Object { $_ -like 'JSON=*' } | Select-Object -First 1) -replace '^JSON=', ''
  return $json
}

$结果 = @{}
foreach ($want in @('expanded', 'collapsed')) {
  $cur = 布局
  if ($cur -ne $want) {
    & $adb -s $dev shell "input tap 1180 665" *> $null
    Start-Sleep -Milliseconds 1500
    $cur = 布局
  }
  "当前布局: $cur （目标 $want）"
  $y = if ($want -eq 'expanded') { 500 } else { 610 }
  $ux = 找干员 $y
  if ($ux -gt 0) {
    "  在 x=$ux y=$y 找到待放干员，抓高亮…"
    $j = 抓高亮 $ux $y $want
    "  $want 格子: $j"
    $结果[$want] = $j
  } else {
    "  ⚠ $want 布局下没找到待放干员（整备区是空的）"
    $结果[$want] = ''
  }
}

# 存盘
$outFile = "$v\board_calib.json"
$结果 | ConvertTo-Json -Depth 5 | Set-Content $outFile -Encoding UTF8
"`n已保存: $outFile"
