# 扫描棋盘占位：逐点点击，用「左侧面板有没有出现攻击/防御/阻挡」判断该格有没有干员。
# 用法: probe_board.ps1 [-Port 16417]
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

$xs = @(400, 470, 540, 610, 680, 750, 820, 890, 960)
$ys = @(230, 300, 370)
$found = @()

foreach ($y in $ys) {
  foreach ($x in $xs) {
    & $adb -s $dev shell "input tap $x $y" *> $null
    Start-Sleep -Milliseconds 900
    & $adb -s $dev shell "screencap -p /sdcard/_pb.png" *> $null
    & $adb -s $dev pull /sdcard/_pb.png "$v\_pb.png" *> $null
    $out = & $py "$v\ocr.py" "$v\_pb.png" 2>$null

    $name = $null; $atk = $null; $blk = $null
    foreach ($l in $out) {
      if ($l -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(.*)$') {
        $px = [int]$Matches[1]; $t = $Matches[3].Trim()
        if ($px -lt 90 -and -not $name -and $t -notmatch '^\d+$' -and $t -notmatch '攻击|防御|阻挡|费用|特质|攻击范围') { $name = $t }
        if ($t -match '攻击(\d+)') { $atk = $Matches[1] }
        if ($t -match '阻挡(\d+)') { $blk = $Matches[1] }
      }
    }
    if ($atk) {
      $label = if ($name) { $name } else { '?' }
      "({0},{1}) 有干员: {2} 攻{3} 阻{4}" -f $x, $y, $label, $atk, $blk
      $found += [pscustomobject]@{ X = $x; Y = $y; Name = $name; Atk = $atk; Blk = $blk }
    }
    # 关掉面板
    & $adb -s $dev shell "input tap 1150 480" *> $null
    Start-Sleep -Milliseconds 400
  }
}
"=== 共找到 $($found.Count) 个干员 ==="
$found | ForEach-Object { "  ({0},{1}) {2} 攻{3} 阻{4}" -f $_.X, $_.Y, $_.Name, $_.Atk, $_.Blk }
