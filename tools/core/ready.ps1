# 点「准备就绪」，自动处理「确认准备吗？」弹窗，然后等到下一回合。
# 用法: ready.ps1 [-Wait 45] [-Port 0]
param(
  [int]$Wait = 45,
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
if ($Port -le 0) {
  $mm = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'
  $info = & $mm info -v 1 2>&1 | Out-String
  if ($info -match '"adb_port"\s*:\s*(\d+)') { $Port = [int]$Matches[1] }
}
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null

function Shot($n) {
  & $adb -s $dev shell "screencap -p /sdcard/_r.png" *> $null
  & $adb -s $dev pull /sdcard/_r.png "$v\$n" *> $null
  return "$v\$n"
}

# 1) 点准备就绪
& $adb -s $dev shell "input tap 1200 112" *> $null
Start-Sleep -Seconds 2

# 2) 有确认弹窗就点确认
$shot = Shot 'r_dlg.png'
$out = & $py "$v\ocr.py" $shot 2>$null
$confirm = $out | Where-Object { $_ -match '确认' -and $_ -notmatch '确认准备|确认本局' } | Select-Object -First 3
$pick = $confirm | Where-Object { $_ -match '^\d+,\d+\s+\d+x\d+\s+[\d.]+\s+确认\s*$' } | Select-Object -First 1
if ($pick -and $pick -match '^(\d+),(\d+)\s+(\d+)x(\d+)') {
  $cx = [int]$Matches[1] + [int]([int]$Matches[3] / 2)
  $cy = [int]$Matches[2] + [int]([int]$Matches[4] / 2)
  "有确认弹窗 → 点 ($cx,$cy)"
  & $adb -s $dev shell "input tap $cx $cy" *> $null
} else {
  "无确认弹窗"
}

# 3) 等回合推进
"等 $Wait 秒…"
Start-Sleep -Seconds $Wait
$shot2 = Shot 'r_after.png'
$out2 = & $py "$v\ocr.py" $shot2 2>$null
$round = $out2 | Where-Object { $_ -match '回合\s*\d+' } | Select-Object -First 1
$remain = $out2 | Where-Object { $_ -match '剩余可放置角色' } | Select-Object -First 1
$readyBtn = $out2 | Where-Object { $_ -match '准备就绪' } | Select-Object -First 1
"回合: $(if($round){($round -replace '.*?(\d+)\s*$','$1')}else{'读不到'})"
"剩余: $(if($remain){$remain.Trim()}else{'读不到'})"
"准备就绪按钮: $(if($readyBtn){'在'}else{'不在（可能还在战斗）'})"
