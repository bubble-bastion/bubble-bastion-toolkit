# 采集标注素材：每隔 N 秒截一张棋盘，存到 标注素材/
# 用法: capshots.ps1 [-Count 30] [-Every 3]
param([int]$Count = 30, [int]$Every = 3, [int]$Port = 0)
$v = 'E:\DSH\vision'
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
$out = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\标注素材'
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
if ($Port -le 0) {
  $pf = "$v\adb-port.txt"
  if (Test-Path $pf) { $p0 = (Get-Content $pf -Raw).Trim(); if ($p0 -match '^\d+$') { $Port = [int]$p0 } }
}
if ($Port -le 0) { $Port = 16416 }
New-Item -ItemType Directory -Force -Path $out | Out-Null
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null
$n = 0
for ($i = 1; $i -le $Count; $i++) {
  $name = "shot_{0:D4}.png" -f (Get-Date -Format "HHmmss") -replace 'shot_', ''
  $name = "b_{0:D3}_{1}.png" -f $i, (Get-Date -Format "HHmmss")
  & $adb -s $dev shell "screencap -p /sdcard/_cap.png" *> $null
  & $adb -s $dev pull /sdcard/_cap.png (Join-Path $out $name) *> $null
  if (Test-Path (Join-Path $out $name)) { $n++ }
  Write-Host ("  第 $i/$Count 张  $name")
  if ($i -lt $Count) { Start-Sleep -Seconds $Every }
}
"共采集 $n 张 -> $out"
