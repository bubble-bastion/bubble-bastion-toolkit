# 看一眼模拟器屏幕，用 wb 的 flash 模型回答。
# 用法: powershell -File see.ps1 "问题" [图片路径]
param(
  [Parameter(Mandatory=$true)][string]$Question,
  [string]$Image = ""
)
$ErrorActionPreference = 'Continue'
$adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
$portFile = 'E:\DSH\vision\adb-port.txt'

if (-not $Image) {
  $dev = $null
  if (Test-Path $portFile) { $dev = '127.0.0.1:' + (Get-Content $portFile -Raw).Trim() }
  if (-not $dev) {
    $mm = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'
    $info = & $mm info -v 1 2>&1 | Out-String
    if ($info -match '"adb_port"\s*:\s*(\d+)') { $dev = '127.0.0.1:' + $Matches[1] }
  }
  if (-not $dev) { throw '拿不到 adb 端口' }
  & $adb connect $dev 2>&1 | Out-Null
  $Image = 'E:\DSH\vision\shot.png'
  & $adb -s $dev shell "screencap -p /sdcard/_see.png" *> $null
  & $adb -s $dev pull /sdcard/_see.png $Image *> $null
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Image))
$payload = @{
  model = 'deepseek-v4.1-flash'
  messages = @(@{ role = 'system'; content = '你是看图助手，回答必须极简，直接给结论和坐标，不要展开推理。' }, @{ role = 'user'; content = @(
    @{ type = 'text'; text = $Question },
    @{ type = 'image_url'; image_url = @{ url = "data:image/png;base64,$b64" } }
  )})
  max_tokens = 3000
} | ConvertTo-Json -Depth 8
$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# flash 偶尔只 reasoning 不输出正文，空就重试一次（把 max_tokens 再抬高）
foreach ($attempt in 1..3) {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8788/v1/chat/completions' -Method POST -Body $bytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 150 -UseBasicParsing
  $j = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
  $ans = $j.choices[0].message.content
  if ($ans -and $ans.Trim().Length -gt 0) { $ans; break }
  if ($attempt -eq 3) { "（flash 三次都没给正文，只给了推理）" }
  $payload = $payload -replace '"max_tokens":\s*\d+', '"max_tokens": 6000'
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  Start-Sleep -Milliseconds 800
}
