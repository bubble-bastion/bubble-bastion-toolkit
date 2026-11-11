# 点开一张商店卡，读名字 + 查基础库 + 输出决策信息。
# 用法: card.ps1 -X 681 -Y 640 [-Port 16417]
param(
  [Parameter(Mandatory=$true)][int]$X,
  [Parameter(Mandatory=$true)][int]$Y,
  [int]$Port = 0
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
$db = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\干员库-中文.json'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null
& $adb -s $dev shell "input tap $X $Y" *> $null
Start-Sleep -Milliseconds 1300
& $adb -s $dev shell "screencap -p /sdcard/_card.png" *> $null
$img = "$v\_card.png"
& $adb -s $dev pull /sdcard/_card.png $img *> $null

$out = & $py "$v\ocr.py" $img 2>$null

# 面板里名字通常是左侧 x<60、y 在 160~210 的那一行
$name = $null
$trait = $null
$cost = $null
$atk = $null
$df = $null
$blk = $null
foreach ($line in $out) {
  if ($line -match '(\d+),(\d+)\s+(\d+)x(\d+)\s+([\d.]+)\s+(.*)$') {
    $x = [int]$Matches[1]; $y = [int]$Matches[2]; $t = $Matches[6].Trim()
    if (-not $name -and $x -lt 80 -and $y -ge 150 -and $y -le 215 -and $t -notmatch '^\d+$') { $name = $t }
    if ($t -match '攻击(\d+)') { $atk = $Matches[1] }
    if ($t -match '防御(\d+)') { $df = $Matches[1] }
    if ($t -match '阻挡(\d+)') { $blk = $Matches[1] }
    if ($t -match '费用(\d+)') { $cost = $Matches[1] }
    if ($t -match '^<|特质') { $trait = $t }
  }
}
if (-not $name) { "没读到名字（这张卡可能没点开或不是干员卡）"; exit }

"卡片: $name"
"面板: 攻$atk 防$df 阻挡$blk 部署费用$cost"
if ($trait) { "特质: $trait" }

$j = Get-Content $db -Raw -Encoding UTF8 | ConvertFrom-Json
$hit = $j.干员.PSObject.Properties | ForEach-Object { $_.Value } | Where-Object { $_.名字 -eq $name } | Select-Object -First 1
if ($hit) {
  "基础库: $($hit.职业)｜$($hit.位置)｜攻$($hit.攻击) 防$($hit.防御) 阻挡$($hit.阻挡) 部署费用$($hit.部署费用)"
  $posHint = if ($hit.位置 -eq '远程') { '放后排（别放最前）' } else { '可放前线阻挡' }
  "建议位置: $posHint"
} else {
  "基础库: 没这个人（可能是新干员/名字 OCR 不准）"
}
