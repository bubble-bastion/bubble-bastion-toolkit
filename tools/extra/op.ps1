# 按中文名查干员基础资料（游戏源数据，非卫戍协议数值）。
# 用法: op.ps1 -Name 初雪        # 精确/模糊都行
#       op.ps1 -Name 近卫 -By 职业   # 按职业列
param(
  [Parameter(Mandatory=$true)][string]$Name,
  [string]$By = '名字',
  [int]$Limit = 15
)
$db = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\干员库-中文.json'
$j = Get-Content $db -Raw -Encoding UTF8 | ConvertFrom-Json
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$all = $j.干员.PSObject.Properties | ForEach-Object { $_.Value }

if ($By -eq '名字') {
  $hits = $all | Where-Object { $_.名字 -like "*$Name*" }
} elseif ($By -eq '职业') {
  $hits = $all | Where-Object { $_.职业 -eq $Name }
} else {
  $hits = $all | Where-Object { $_.位置 -eq $Name }
}

if (-not $hits) { "没找到：$Name"; exit }

$hits | Select-Object -First $Limit | ForEach-Object {
  "{0}｜{1}｜{2}｜攻{3} 防{4} 阻{5} 费{6}" -f $_.名字, $_.职业, $_.位置, $_.攻击, $_.防御, $_.阻挡, $_.部署费用
}
if ($hits.Count -gt $Limit) { "（共 $($hits.Count) 个，只显示前 $Limit）" }
