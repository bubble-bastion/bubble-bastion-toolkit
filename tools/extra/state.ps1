# 一屏读出关键状态（全部用 OCR，不问模型）。
# 输出：回合 / 剩余可放置 / 金币 / 盟约
# 用法: state.ps1 [-Port 16417] [-Image 现成截图]
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
  & $adb -s $dev shell "screencap -p /sdcard/_st.png" *> $null
  $Image = "$v\_st.png"
  & $adb -s $dev pull /sdcard/_st.png $Image *> $null
}

$env:PYTHONIOENCODING = 'utf-8'
$raw = & $py "$v\ocr.py" $Image 2>$null
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$round = ''; $remain = ''; $money = ''; $cov = @()
foreach ($line in $raw) {
  if ($line -match '(\d+),(\d+)\s+(\d+)x(\d+)\s+([\d.]+)\s+(.*)$') {
    $x = [int]$Matches[1]; $y = [int]$Matches[2]; $t = $Matches[6].Trim()
    if ($t -match '^回合\s*(\d+)$') { $round = $Matches[1] }
    elseif ($t -match '剩余可放置角色[：:]\s*(\d+)') { $remain = $Matches[1] }
    elseif ($x -gt 1050 -and $y -gt 470 -and $y -lt 570) {
      if ($t -match '(\d+)') { $money = $Matches[1] }
    }
    elseif ($t -match '^(不屈|坚守|助力|叙拉古|乌萨斯|维多利亚|莱塔尼亚|谢拉格|炎|萨尔贡|伊比利亚|精准|远见|调和|协防干员|聚合|奥术|迅捷)$' -and $y -lt 160) { $cov += $t }
  }
}
"回合: $round"
"剩余可放置: $remain"
"金币: $money"
"盟约: " + ($cov -join ' / ')
