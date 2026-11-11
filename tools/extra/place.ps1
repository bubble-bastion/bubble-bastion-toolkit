# 放干员 + 客观验证。
# 思路：不读「剩余可放置」这种小字（模型会编），改成比对落点格区域前后的像素差。
# 用法: place.ps1 -FromX 641 -FromY 587 -ToX 700 -ToY 300 [-Face right|left|none]
param(
  [Parameter(Mandatory=$true)][int]$FromX,
  [Parameter(Mandatory=$true)][int]$FromY,
  [Parameter(Mandatory=$true)][int]$ToX,
  [Parameter(Mandatory=$true)][int]$ToY,
  [string]$Face = 'right',
  [int]$Port = 0
)
$ErrorActionPreference = 'Continue'
$v = 'E:\DSH\vision'
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
$dev = "127.0.0.1:$Port"
& $adb connect $dev *> $null

function Shot($name) {
  & $adb -s $dev shell "screencap -p /sdcard/_p.png" *> $null
  & $adb -s $dev pull /sdcard/_p.png "$v\$name" *> $null
  return "$v\$name"
}

function DiffRatio($a, $b, $x, $y, $w, $h) {
  Add-Type -AssemblyName System.Drawing
  $ia = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($a)
  $ib = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile($b)
  try {
    $changed = 0; $total = 0
    for ($yy = $y; $yy -lt [Math]::Min($y + $h, $ia.Height); $yy += 2) {
      for ($xx = $x; $xx -lt [Math]::Min($x + $w, $ia.Width); $xx += 2) {
        $pa = $ia.GetPixel($xx, $yy); $pb = $ib.GetPixel($xx, $yy)
        $d = [Math]::Abs($pa.R - $pb.R) + [Math]::Abs($pa.G - $pb.G) + [Math]::Abs($pa.B - $pb.B)
        $total++
        if ($d -gt 30) { $changed++ }
      }
    }
    if ($total -eq 0) { return 0 }
    return $changed / $total
  } finally { $ia.Dispose(); $ib.Dispose() }
}

$before = Shot 'p_before.png'
& $adb -s $dev shell "input swipe $FromX $FromY $ToX $ToY 1500" *> $null
Start-Sleep -Milliseconds 1200
$after = Shot 'p_after.png'

# 落点周围 120x120 的变化（上场会有小人出现）
$r1 = DiffRatio $before $after ($ToX - 60) ($ToY - 60) 120 120
# 整屏变化（画面若整体位移，说明落点/状态异常）
$r2 = DiffRatio $before $after 0 0 1280 720

"落点区域变化: {0:P1}" -f $r1
"整屏变化:     {0:P1}" -f $r2

if ($Face -ne 'none') {
  $fx = if ($Face -eq 'left') { $ToX - 120 } else { $ToX + 120 }
  & $adb -s $dev shell "input swipe $ToX $ToY $fx $ToY 600" *> $null
  Start-Sleep -Milliseconds 900
  $done = Shot 'p_done.png'
  $r3 = DiffRatio $after $done 0 0 1280 720
  "定朝向后整屏变化: {0:P1}" -f $r3
}

# 整备区起点变化：干员离开整备区 -> 那一格会明显变化；被弹回则几乎不变
$r0 = DiffRatio $before $after ($FromX - 45) ($FromY - 45) 90 90
"整备区起点变化: {0:P1}" -f $r0

if ($r1 -gt 0.08) { "判断: 落点区域有明显变化，干员应该上去了" }
else { "判断: 落点区域几乎没变，可能没放上去（或落点偏了）" }
