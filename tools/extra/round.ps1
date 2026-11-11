# 每回合开局：读状态 → 读商店卡 → 打分建议。一条命令出结论。
# 用法: round.ps1 [-Port 16417]
param([int]$Port = 0)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
# 端口自动解析：优先读 adb-port.txt（sync-ports.ps1 维护），否则问 MuMuManager
if ($Port -le 0) {
  $pf = 'E:\DSH\vision\adb-port.txt'
  if (Test-Path $pf) { $p0 = (Get-Content $pf -Raw).Trim(); if ($p0 -match '^\d+$') { $Port = [int]$p0 } }
}
if ($Port -le 0) {
  $mmP = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'
  if (Test-Path $mmP) {
    $inf = & $mmP info -v 1 2>&1 | Out-String
    if ($inf -match '"adb_port"\s*:\s*(\d+)') { $Port = [int]$Matches[1] }
  }
}
if ($Port -le 0) { $Port = 16416 }
$dev = "127.0.0.1:$Port"
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_r.png" *> $null
  & $adb -s $dev pull /sdcard/_r.png "$v\$n" *> $null
  return "$v\$n"
}
function Ocr($img) { & $py "$v\ocr.py" $img 2>$null }

"=== 第 1 步：状态 ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "$v\state.ps1" -Port $Port

"`n=== 第 2 步：确保商店展开 ==="
$img = Shot 'r_state.png'
$lines = Ocr $img
$exp = $lines | Where-Object { $_ -match '展开' } | Select-Object -First 1
if ($exp -match '(\d+),(\d+)\s+(\d+)x(\d+)') {
  $cx = [int]$Matches[1] + [int]([int]$Matches[3] / 2)
  $cy = [int]$Matches[2] + [int]([int]$Matches[4] / 2)
  "商店是收起的，点展开 ($cx,$cy)"
  & $adb -s $dev shell "input tap $cx $cy" *> $null
  Start-Sleep -Milliseconds 1700
} else { "商店已展开" }

"`n=== 第 2.5 步：钱与费用 ==="
& powershell -NoProfile -ExecutionPolicy Bypass -File "$v\shop3.ps1" -Port $Port

"`n=== 第 3 步：读商店卡 ==="
$img = Shot 'r_shop.png'
$cost = Ocr $img | Where-Object { $_ -match '确认购买|无法购买' }
$rows = Ocr $img | Where-Object { $_ -match '(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+\d+$' -and $_ -match '^(\d+),(\d+)' -and [int]$Matches[2] -gt 400 }
$cardXs = @(357, 520, 681, 842, 1005)
$names = @()
foreach ($x in $cardXs) {
  & $adb -s $dev shell "input tap $x 640" *> $null
  Start-Sleep -Milliseconds 1100
  $p = Shot 'r_card.png'
  $o = Ocr $p
  $nm = $o | Where-Object { $_ -match '^(\d+),(\d+)\s' -and [int]$Matches[1] -lt 90 -and [int]$Matches[2] -gt 160 -and [int]$Matches[2] -lt 215 } | Select-Object -First 1
  $atk = $o | Where-Object { $_ -match '攻击(\d+)' } | Select-Object -First 1
  if ($nm -and $atk) {
    $clean = ($nm -replace '^\s*\d+,\d+\s+\d+x\d+\s+[\d.]+\s+', '').Trim()
    $a = [int]($atk -replace '.*攻击(\d+).*', '$1')
    if ($a -gt 0) { "  ($x) $clean  攻$a"; $names += $clean }
    else { "  ($x) $clean  → 装备（攻0）" }
  }
  # 关面板：点空白棋盘（绝对不要点右下角，那是商店开关）
  & $adb -s $dev shell "input tap 300 180" *> $null
  Start-Sleep -Milliseconds 400
}

"`n=== 第 4 步：建议 ==="
if ($names.Count -eq 0) { "没读到干员卡"; exit }
$joined = $names -join ','
& powershell -NoProfile -ExecutionPolicy Bypass -File "$v\advise.ps1" -Cards $joined
