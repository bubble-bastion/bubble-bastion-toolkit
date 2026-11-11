# 查卫戍协议装备（按名字模糊查效果）。
# 用法: eq.ps1 -Name 蜇甲     （不给名字就列出全部）
param(
  [string]$Name = ''
)
$db = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-装备库.json'
$j = Get-Content $db -Raw -Encoding UTF8 | ConvertFrom-Json
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$all = $j.装备
$hits = if ($Name) { $all | Where-Object { $_.名字 -like "*$Name*" } } else { $all }
if (-not $hits) { "没找到：$Name"; exit }

foreach ($e in $hits) {
  $cost = if ($null -eq $e.费用) { '?' } else { $e.费用 }
  "{0}（{1}块）｜{2}" -f $e.名字, $cost, $e.效果
}
