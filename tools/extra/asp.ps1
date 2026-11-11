# 查卫戍协议完整库（干员/装备）。
# 用法:
#   asp.ps1 -Name 初雪            按名字模糊查
#   asp.ps1 -Covenant 乌萨斯       按核心盟约列
#   asp.ps1 -Trait 持续叠加        按词条类型列（持续叠加/单次叠加/特异化/整备能力/作战能力）
#   asp.ps1 -Equip 盾              按装备名查
#   asp.ps1 -List                 只列统计
param(
  [string]$Name = '',
  [string]$Covenant = '',
  [string]$Trait = '',
  [string]$Equip = '',
  [switch]$List,
  [int]$Limit = 20
)
$db = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据库.json'
$j = Get-Content $db -Raw -Encoding UTF8 | ConvertFrom-Json
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Show-Op($o) {
  $cov = ($o.核心盟约 -join '/')
  $add = if ($o.附加盟约) { ' +' + ($o.附加盟约 -join '/') } else { '' }
  $stat = ''
  if ($o.阻挡) { $stat += " 阻$($o.阻挡)" }
  if ($o.部署费用) { $stat += " 费$($o.部署费用)" }
  "{0}（{1}阶）｜{2}{3}{4}" -f $o.名字, $o.等阶, $cov, $add, $stat
  foreach ($t in $o.普通词条) { "     [{0}] {1}" -f $t.类型, $t.说明 }
  foreach ($t in $o.精锐词条) { "    精锐[{0}] {1}" -f $t.类型, $t.说明 }
}

if ($List -or (-not $Name -and -not $Covenant -and -not $Trait -and -not $Equip)) {
  "干员 $($j.干员数) 个，装备 $($j.装备数) 件"
  "盟约分布:"
  $j.盟约分布.PSObject.Properties | ForEach-Object { "  {0}: {1}" -f $_.Name, $_.Value }
  "词条类型: " + ($j.词条类型 -join ' / ')
  exit
}

if ($Equip) {
  $hits = $j.装备 | Where-Object { $_.名字 -like "*$Equip*" }
  if (-not $hits) { "没找到装备：$Equip"; exit }
  $hits | Select-Object -First $Limit | ForEach-Object {
    "{0}（{1}阶）｜普通: {2}｜精锐: {3}" -f $_.名字, $_.等阶, $_.普通效果, $_.精锐效果
  }
  exit
}

$hits = $j.干员
if ($Name) { $hits = $hits | Where-Object { $_.名字 -like "*$Name*" } }
if ($Covenant) { $hits = $hits | Where-Object { ($_.核心盟约 -contains $Covenant) -or ($_.附加盟约 -contains $Covenant) } }
if ($Trait) {
  $hits = $hits | Where-Object {
    ($_.普通词条 | Where-Object { $_.类型 -eq $Trait }) -or ($_.精锐词条 | Where-Object { $_.类型 -eq $Trait })
  }
}
if (-not $hits) { "没有符合条件的干员"; exit }
"命中 $($hits.Count) 个："
$hits | Select-Object -First $Limit | ForEach-Object { Show-Op $_ }
if ($hits.Count -gt $Limit) { "（只显示前 $Limit 个）" }
