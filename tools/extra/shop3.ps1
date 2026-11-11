# 动态读商店（分带扫描版）：不依赖固定坐标。
# 把下半屏切成若干条重叠横带，各自放大 3 倍 OCR，合并后按 y 聚行，
# 取「横跨最宽」的那一行为费用行：最右是金币，其余是卡片费用。
# 用法: shop3.ps1 [-Port 16417] [-Image 现成截图]
param(
  [int]$Port = 0,
  [string]$Image = ''
)
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

if (-not $Image) {
  $dev = "127.0.0.1:$Port"
  & $adb connect $dev *> $null
  & $adb -s $dev shell "screencap -p /sdcard/_s3.png" *> $null
  $Image = "$v\_s3.png"
  & $adb -s $dev pull /sdcard/_s3.png $Image *> $null
}

$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$bands = @(
  @{ Y = 360; H = 130 },
  @{ Y = 440; H = 130 },
  @{ Y = 520; H = 130 },
  @{ Y = 590; H = 130 }
)
$nums = @()
$idx = 0
foreach ($b in $bands) {
  $idx++
  $crop = "$v\_band$idx.png"
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$v\crop.ps1" -In $Image -Out $crop -X 0 -Y $b.Y -W 1280 -H $b.H -Scale 3 *> $null
  $out = & $py "$v\ocr.py" $crop 2>$null
  foreach ($line in $out) {
    if ($line -match '(\d+),(\d+)\s+(\d+)x(\d+)\s+([\d.]+)\s+(\d+)$') {
      $x = [int]([int]$Matches[1] / 3)
      $y = [int]($b.Y + [int]$Matches[2] / 3)
      $score = [double]$Matches[5]; $n = [int]$Matches[6]
      if ($score -lt 0.6) { continue }
      $nums += [pscustomobject]@{ X = $x; Y = $y; N = $n }
    }
  }
}
if ($nums.Count -eq 0) { "分带扫描没找到数字"; exit }

# 去重（同一位置重复命中）
# 合并相邻很近、数值相同的重复命中（分带有重叠）
$merged = @()
foreach ($n in ($nums | Sort-Object X)) {
  $dup = $false
  foreach ($m in $merged) {
    if ([Math]::Abs($m.X - $n.X) -le 18 -and $m.N -eq $n.N) { $dup = $true; break }
  }
  if (-not $dup) { $merged += $n }
}
$uniq = $merged

# 按 y 聚行
$rows = @()
foreach ($n in ($uniq | Sort-Object Y)) {
  $placed = $false
  foreach ($r in $rows) { if ([Math]::Abs($r.Y - $n.Y) -le 14) { $r.Items += $n; $placed = $true; break } }
  if (-not $placed) { $rows += [pscustomobject]@{ Y = $n.Y; Items = @($n) } }
}

$best = $rows | Where-Object { $_.Items.Count -ge 2 } |
        Sort-Object @{ Expression = { ($_.Items | Measure-Object -Property X -Maximum).Maximum - ($_.Items | Measure-Object -Property X -Minimum).Minimum }; Descending = $true } |
        Select-Object -First 1
if (-not $best) { "没找到成排的数字"; exit }

$sorted = $best.Items | Sort-Object X
"费用行 y≈$($best.Y)，共 $($sorted.Count) 个数字"
# 金币固定在最右侧（收起按钮旁，x > 1150）；取不到就明确说读不到，别拿卡片费用冒充
$moneyCand = $sorted | Where-Object { $_.X -gt 1150 } | Select-Object -Last 1
if (-not $moneyCand) {
  "金币: 读不到（x>1150 没有数字，可能被遮挡或商店未完全展开）"
  "费用行数字: " + (($sorted | ForEach-Object { "x$($_.X)=$($_.N)" }) -join ' ')
  exit
}
$money = $moneyCand
"金币: $($money.N)  (x≈$($money.X))"
if ($sorted.Count -gt 1) {
  foreach ($c in $sorted[0..($sorted.Count - 2)]) {
    $ok = if ($money.N -ge $c.N) { '买得起' } else { '买不起' }
    "  卡片 x≈$($c.X)  费用 $($c.N)  -> $ok"
  }
}
