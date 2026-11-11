# 读整备区/场上干员的名字与面板数值，并去资料库查职业（强制走资料库，不靠阻挡数猜）
param([int]$Port = 0, [switch]$Quiet)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
$dbPath = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据.json'
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
  & $adb -s $dev shell "screencap -p /sdcard/_w.png" *> $null
  & $adb -s $dev pull /sdcard/_w.png "$v\$n" *> $null
  return "$v\$n"
}

# 在指定行找干员，返回 @{x,y,name,atk,def,block}
function FindUnits($y) {
  $found = @()
  foreach ($x in @(700,780,860,940,1020,1100)) {
    & $adb -s $dev shell "input tap $x $y" *> $null
    Start-Sleep -Milliseconds 500
    $s = Shot 'w_scan.png'
    $t = & $py "$v\ocr.py" $s 2>$null
    & $adb -s $dev shell "input tap 300 180" *> $null
    Start-Sleep -Milliseconds 200
    if (-not ($t -match '出售')) { continue }
    # 名字：面板顶部那行中文（2~4 字，置信度高）
    $name = ''
    foreach ($line in $t) {
      if ($line -match '^\d+,\d+\s+\d+x\d+\s+[\d.]+\s+([\u4e00-\u9fa5]{2,5})\s*$') {
        $cand = $Matches[1]
        if ($cand -notmatch '出售|技能|生命|费用|攻击|防御|阻挡|攻击范围|撤退') { $name = $cand; break }
      }
    }
    $atk = if ($t -match '攻击(\d+)') { $Matches[1] } else { '' }
    $def = if ($t -match '防御(\d+)') { $Matches[1] } else { '' }
    $blk = if ($t -match '阻挡(\d+)') { $Matches[1] } else { '' }
    $found += [pscustomobject]@{ X = $x; Y = $y; Name = $name; Atk = $atk; Def = $def; Block = $blk }
  }
  return $found
}

$units = @()
foreach ($y in @(500, 610)) {
  $u = FindUnits $y
  if ($u.Count -gt 0) { $units += $u; break }
}

if ($units.Count -eq 0) { "整备区没找到干员"; exit }

# 查资料库
$db = Get-Content $dbPath -Raw -Encoding UTF8 | ConvertFrom-Json
$表 = @{}
foreach ($o in $db.干员) { $表[$o.名字] = $o }

"=== 整备区干员（已查资料库）==="
foreach ($u in $units) {
  $info = $表[$u.Name]
  if ($info) {
    $职业 = $info.职业
    $类型 = if ($职业 -match '重装|近卫|先锋|守卫') { '近战（能阻挡）' } else { '远程（不阻挡）' }
    "  {0}  ({1},{2})  攻击{3} 防御{4} 阻挡{5}" -f $u.Name, $u.X, $u.Y, $u.Atk, $u.Def, $u.Block
    "     └ 资料库职业: {0}  →  {1}" -f $职业, $类型
  } else {
    "  {0}  ({1},{2})  攻击{3} 阻挡{4}" -f $u.Name, $u.X, $u.Y, $u.Atk, $u.Block
    "     └ ⚠ 资料库里没有这个干员（名字可能没读准）"
  }
}
