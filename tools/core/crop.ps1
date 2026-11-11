# 裁剪并放大图片的指定区域（给读小字用）。
# 用法: crop.ps1 -In a.png -Out b.png -X 0 -Y 0 -W 300 -H 60 -Scale 3
param(
  [Parameter(Mandatory=$true)][string]$In,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$X = 0, [int]$Y = 0, [int]$W = 0, [int]$H = 0, [double]$Scale = 3
)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path $In))
try {
  if ($W -le 0) { $W = $src.Width - $X }
  if ($H -le 0) { $H = $src.Height - $Y }
  $dw = [int]($W * $Scale); $dh = [int]($H * $Scale)
  $bmp = New-Object System.Drawing.Bitmap $dw, $dh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $rectDst = New-Object System.Drawing.Rectangle 0, 0, $dw, $dh
  $rectSrc = New-Object System.Drawing.Rectangle $X, $Y, $W, $H
  $g.DrawImage($src, $rectDst, $rectSrc, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  "OK $Out ($dw x $dh)"
} finally { $src.Dispose() }
