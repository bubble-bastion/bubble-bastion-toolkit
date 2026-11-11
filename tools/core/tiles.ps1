# 看「按住干员时游戏高亮出的可放置格」（黄绿色网格）。
# 用法:
#   tiles.ps1 -Image 现成截图.png          # 分析一张已有截图
#   tiles.ps1 -FromX 840 -FromY 500        # 自动按住该位置的干员、截图、松手、分析
param(
  [string]$Image = '',
  [int]$FromX = 0,
  [int]$FromY = 0,
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
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

if (-not $Image) {
  if ($FromX -le 0 -or $FromY -le 0) { "需要 -Image，或者 -FromX/-FromY 指定要按住的干员"; exit }
  $dev = "127.0.0.1:$Port"
  & $adb connect $dev *> $null
  # 按住不放 -> 截图 -> 松手
  & $adb -s $dev shell "input motionevent DOWN $FromX $FromY; sleep 0.5; input motionevent MOVE $($FromX-4) $($FromY-10); sleep 1.2" *> $null
  Start-Sleep -Milliseconds 350
  & $adb -s $dev shell "screencap -p /sdcard/_tiles.png" *> $null
  $Image = "$v\_tiles.png"
  & $adb -s $dev pull /sdcard/_tiles.png $Image *> $null
  & $adb -s $dev shell "input motionevent UP $($FromX-4) $($FromY-10)" *> $null
  Start-Sleep -Milliseconds 500
}

& $py "$v\tiles.py" $Image
