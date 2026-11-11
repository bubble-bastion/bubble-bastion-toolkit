# 回合开始标准流程（老大 2026-11-11 13:40 定）
# ① 读金币  ② 看商店刷新了什么  ③ 看商店等级要不要升（升级费用每回合 -1）
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
if ($Port -le 0) { $Port = 16416 }
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_rs.png" *> $null
  & $adb -s $dev pull /sdcard/_rs.png "$v\$n" *> $null
  return "$v\$n"
}

# 确保商店展开（才能看钱和卡）
$s0 = Shot 'rs0.png'
$t0 = & $py "$v\ocr.py" $s0 2>$null
if ($t0 -match '展开' -and -not ($t0 -match '收起')) {
  $cl = $t0 | Where-Object { $_ -match '展开' } | Select-Object -First 1
  if ($cl -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
    & $adb -s $dev shell "input tap $(([int]$Matches[1]+[int]([int]$Matches[3]/2))) $(([int]$Matches[2]+[int]([int]$Matches[4]/2)))" *> $null
    Start-Sleep -Milliseconds 1500
    "（已展开商店）"
  }
}

$s = Shot 'rs_shop.png'
$t = & $py "$v\ocr.py" $s 2>$null

"======== 回合开始检查 ========"
$round = $t | Where-Object { $_ -match '回合\s*\d' } | Select-Object -First 1
"回合: " + $(if ($round) { ($round -replace '.*?(回合\s*\d+).*', '$1') } else { '读不到' })

# ① 金币
$mp = Join-Path $v 'rs_money.png'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $v 'crop.ps1') -In $s -Out $mp -X 1140 -Y 490 -W 120 -H 60 -Scale 6 | Out-Null
$money = (& $py "$v\ocr.py" $mp 2>$null | Select-Object -First 1)
$mv = if ($money -match '(\d+)\s*$') { $Matches[1] } else { '?' }
"① 金币: $mv"

# ② 商店刷新了什么
"② 商店卡牌:"
$cards = @()
foreach ($x in @(520, 681, 842, 1005)) {
  & $adb -s $dev shell "input tap $x 640" *> $null
  Start-Sleep -Milliseconds 800
  $cs = Shot 'rs_card.png'
  $ct = & $py "$v\ocr.py" $cs 2>$null
  # 先取数值（避免 $Matches 被后面的名字匹配覆盖）
  $atk = ''
  $blk = ''
  foreach ($ln in $ct) {
    if ($ln -match '攻击(\d+)') { $atk = $Matches[1] }
    if ($ln -match '阻挡(\d+)') { $blk = $Matches[1] }
  }
  $nm = $ct | Where-Object { $_ -match '^(\d+),(\d+)\s+\d+x\d+\s+[\d.]+\s+(\S+)' -and [int]$Matches[2] -ge 165 -and [int]$Matches[2] -le 205 -and [int]$Matches[1] -lt 240 } | Select-Object -First 1
  $name = if ($nm -match '\s(\S+)\s*$') { $Matches[1] } else { '' }
  if ($name) {
    # 查资料库
    $dbPath = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据.json'
    $pos = ''
    $dbj = Get-Content $dbPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $o = $dbj.干员 | Where-Object { $_.名字 -eq $name } | Select-Object -First 1
    if ($o) { $pos = "$($o.职业)/$($o.位置)" }
    "   x=$x  $name  攻击$atk 阻挡$blk  资料库:$pos"
    $cards += $name
  }
  & $adb -s $dev shell "input tap 300 180" *> $null
  Start-Sleep -Milliseconds 200
}
if ($cards.Count -eq 0) { "   （没读到卡名）" }

# ③ 商店等级
# ③ 下一波敌人：点顶部放大镜(930,35) → 读敌人面板 → 关掉
& $adb -s $dev shell "input tap 930 35" *> $null
Start-Sleep -Milliseconds 1800
$es = Shot 'rs_enemy.png'
$et = & $py "$v\ocr.py" $es 2>$null
& $adb -s $dev shell "input tap 930 35" *> $null
Start-Sleep -Milliseconds 800
$enemies = @()
foreach ($ln in $et) {
  if ($ln -match '^\d+,\d+\s+\d+x\d+\s+[\d.]+\s+([\u4e00-\u9fa5]{2,6})\s*$') {
    $nm = $Matches[1]
    if ($nm -notmatch '规程等级|回合|休息|敌人|查看|准备就绪|剩余|冻结|刷新|升级|收起|展开|本局|策略|盟约') { $enemies += $nm }
  }
}
"③ 下一波敌人: " + ($(if ($enemies.Count) { $enemies -join ' / ' } else { '没读到（看 rs_enemy.png）' }))

"④ 商店等级:"
$lvl = $t | Where-Object { $_ -match 'LEVEL|升级' }
$lvl | ForEach-Object { "   " + $_.Trim() }
$up = $t | Where-Object { $_ -match '^\d+,\d+\s+\d+x\d+\s+[\d.]+\s+升级\s*$' } | Select-Object -First 1
if ($up) {
  "   升级按钮: " + $up.Trim()
  if ($up -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
    $ux = [int]$Matches[1]; $uy = [int]$Matches[2]
    # 升级按钮下方/右侧通常是费用
    $cost = $t | Where-Object { $_ -match "^\d+,\d+\s+\d+x\d+\s+[\d.]+\s+\d+\s*$" } | ForEach-Object {
      if ($_ -match '^(\d+),(\d+)') { if ([Math]::Abs([int]$Matches[1]-$ux) -lt 90 -and [int]$Matches[2] -gt $uy -and [int]$Matches[2] -lt ($uy+70)) { $_ } }
    } | Select-Object -First 1
    if ($cost) { "   升级费用: " + $cost.Trim() }
  }
}
