# 下载视频 + 抽帧 + 全帧 OCR，结果写成一个文本文件
# 用法: vocr.ps1 -Id BV1xxx [-Every 20] [-Quality 1080]
param(
  [Parameter(Mandatory=$true)][string]$Id,
  [int]$Every = 20,
  [int]$Quality = 1080
)
$v = 'E:\DSH\vision'
$py = "$v\venv\Scripts\python.exe"
$env:PYTHONIOENCODING = 'utf-8'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$dir = "$v\videos\$Id"
& $py "$v\vframe.py" $Id -every $Every -q $Quality 2>&1 | Select-Object -First 3
$out = "$v\videos\$Id\ocr_all.txt"
"" | Set-Content $out -Encoding UTF8
foreach ($f in (Get-ChildItem $dir -Filter "frame_*.png" | Sort-Object Name)) {
  Add-Content $out ("===== " + $f.Name + " =====") -Encoding UTF8
  $r = & $py "$v\ocr.py" $f.FullName 2>$null
  Add-Content $out $r -Encoding UTF8
}
"OCR 结果: $out"
"共 $((Get-ChildItem $dir -Filter 'frame_*.png').Count) 帧，$((Get-Content $out -Encoding UTF8).Count) 行文本"
