# 比较两张截图，返回变化像素比例（0~1）和几块变化区域。
# 用途：判断「拖拽后画面有没有变」「干员有没有上场」这类问题，不问模型。
# 用法: diff.ps1 -A before.png -B after.png [-Threshold 24]
param(
  [Parameter(Mandatory=$true)][string]$A,
  [Parameter(Mandatory=$true)][string]$B,
  [int]$Threshold = 24,
  [int]$Grid = 8
)
Add-Type -AssemblyName System.Drawing
$ia = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile((Resolve-Path $A))
$ib = [System.Drawing.Bitmap][System.Drawing.Image]::FromFile((Resolve-Path $B))
try {
  $w = [Math]::Min($ia.Width, $ib.Width)
  $h = [Math]::Min($ia.Height, $ib.Height)
  $step = 2   # 每 2 像素采一次，够快也够准
  $changed = 0; $total = 0
  $cellW = [Math]::Max(1, [int]($w / $Grid)); $cellH = [Math]::Max(1, [int]($h / $Grid))
  $cells = @{}
  for ($y = 0; $y -lt $h; $y += $step) {
    for ($x = 0; $x -lt $w; $x += $step) {
      $pa = $ia.GetPixel($x, $y); $pb = $ib.GetPixel($x, $y)
      $d = [Math]::Abs($pa.R - $pb.R) + [Math]::Abs($pa.G - $pb.G) + [Math]::Abs($pa.B - $pb.B)
      $total++
      if ($d -gt $Threshold) {
        $changed++
        $ck = "$([int]($x/$cellW)),$([int]($y/$cellH))"
        $cells[$ck] = ($cells[$ck] + 1)
      }
    }
  }
  $ratio = if ($total -gt 0) { $changed / $total } else { 0 }
  $ratio | ForEach-Object { "变化比例: {0:P2}" -f $_ }
  $top = $cells.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 4
  foreach ($c in $top) {
    $parts = $c.Key.Split(',')
    $cx = [int]$parts[0] * $cellW; $cy = [int]$parts[1] * $cellH
    "  热区 约($cx,$cy) 变化采样点 $($c.Value)"
  }
} finally { $ia.Dispose(); $ib.Dispose() }
