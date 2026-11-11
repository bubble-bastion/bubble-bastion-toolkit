# 一键同步端口：开机后跑这个，把 DSH 端口和模拟器 adb 端口都对齐。
# 用法:
#   sync-ports.ps1              # 只检测 + 写文件，不重启桥接
#   sync-ports.ps1 -Restart     # 顺便重启桥接
param([switch]$Restart)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$bridgeDir = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\qq-bridge'
$visionDir = 'E:\DSH\vision'
$mm = 'D:\MuMu模拟器\MuMuPlayer\nx_main\MuMuManager.exe'

# ── 1) DSH 网关端口 ──
$dshIds = @(Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$dshPorts = @()
if ($dshIds.Count -gt 0) {
  $dshPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $dshIds -contains $_.OwningProcess } |
    Select-Object -ExpandProperty LocalPort -Unique
}
if ($dshPorts.Count -eq 0) {
  "✗ 没找到 DSH 进程（DeepSeek Harness 没开？）"
} else {
  # DSH 会同时监听几个端口，网关那个是能响应 /api 的；这里取最大的那个（历史经验）
  $dshPort = ($dshPorts | Sort-Object -Descending)[0]
  "DSH 端口候选: $($dshPorts -join ', ') → 采用 $dshPort"

  $cfgPath = Join-Path $bridgeDir 'config.json'
  if (Test-Path $cfgPath) {
    $raw = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8)
    $old = ([regex]::Match($raw, '"baseUrl"\s*:\s*"([^"]*)"')).Groups[1].Value
    $new = "http://127.0.0.1:$dshPort"
    if ($old -ne $new) {
      $raw = $raw -replace '"baseUrl"\s*:\s*"[^"]*"', "`"baseUrl`": `"$new`""
      [System.IO.File]::WriteAllText($cfgPath, $raw, (New-Object System.Text.UTF8Encoding($false)))
      "  桥接 baseUrl: $old → $new （已改）"
    } else {
      "  桥接 baseUrl 已是 $new"
    }
  }
}

# ── 2) 模拟器 adb 端口 ──
if (Test-Path $mm) {
  $info = & $mm info -v 1 2>&1 | Out-String
  if ($info -match '"adb_port"\s*:\s*(\d+)') {
    $adbPort = $Matches[1]
    $started = $info -match '"is_android_started"\s*:\s*true'
    "模拟器 adb 端口: $adbPort （Android 已启动: $started）"
    if (Test-Path (Join-Path $visionDir 'adb-port.txt')) {
      $oldPort = (Get-Content (Join-Path $visionDir 'adb-port.txt') -Raw).Trim()
      if ($oldPort -ne $adbPort) { "  adb-port.txt: $oldPort → $adbPort （已更新）" }
    } else { "  新建 adb-port.txt = $adbPort" }
    Set-Content (Join-Path $visionDir 'adb-port.txt') $adbPort -Encoding UTF8 -NoNewline
    # 顺便连一下
    $adb = 'D:\MuMu模拟器\MuMuPlayer\nx_device\12.0\shell\adb.exe'
    & $adb connect "127.0.0.1:$adbPort" *> $null
    $devs = & $adb devices 2>&1
    if ($devs -match [regex]::Escape("127.0.0.1:$adbPort`tdevice")) { "  adb 已连接 ✓" }
    else { "  ⚠ adb 连接异常: $($devs -join ' ')" }
  } else {
    "✗ 读不到 adb 端口（模拟器没开？）"
  }
} else {
  "✗ 找不到 MuMuManager: $mm"
}

# ── 3) 需要的话重启桥接 ──
if ($Restart) {
  $relink = Join-Path $bridgeDir 'relink-dsh.ps1'
  if (Test-Path $relink) {
    "重启桥接…"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $relink
  }
}

"`n完成。若桥接没在跑，双击 qq-bridge\重新连接DSH.bat 即可。"
