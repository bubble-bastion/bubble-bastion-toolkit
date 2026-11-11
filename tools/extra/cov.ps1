# 按手上的干员，算出哪些盟约已激活（不靠识图）。
# 依据 ASP covenants.json：大盟约(SEASON)需3人，小盟约(REGULAR)多为2人，独行/调和为1人。
# 用法: cov.ps1 -Owned 折桠,乌啾,真理,冻河 -Extra 转职装备名
param(
  [string[]]$Owned = @(),
  [string[]]$Extra = @()
)
$v = 'E:\DSH\vision'
$dbFile = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据库.json'
$covFile = "$v\asp\covenants.json"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$db = Get-Content $dbFile -Raw -Encoding UTF8 | ConvertFrom-Json
$cov = Get-Content $covFile -Raw -Encoding UTF8 | ConvertFrom-Json
# 优先用更全的转职装备映射（含小盟约，来自视频原图 OCR）
$mapFile = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\转职装备映射.json'
$jobMap = @{}
if (Test-Path $mapFile) {
  $m = Get-Content $mapFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $m.映射.PSObject.Properties | ForEach-Object { $jobMap[$_.Name] = $_.Value }
} else {
  $cov.jobChangeEquipmentToCovenant.PSObject.Properties | ForEach-Object { $jobMap[$_.Name] = $_.Value }
}

$Owned = (($Owned -join ",") -split "[,，、\s]+") | Where-Object { $_ }
$Extra = (($Extra -join ",") -split "[,，、\s]+") | Where-Object { $_ }
if ($Owned.Count -eq 0) { "没给 -Owned（用逗号分隔干员名）"; exit }

# 统计每个盟约的人数
# ⚠ 2026-11-10 老大纠正：**同名干员只算一个盟约人头**（买两个烈夏，乌萨斯只 +1）。
#   但「特质」是重复生效的（两个烈夏都 +4 层），所以这里只对人头去重，不影响层数计算。
$Owned = $Owned | Select-Object -Unique
$count = @{}
$unknown = @()
foreach ($n in $Owned) {
  $o = $db.干员 | Where-Object { $_.名字 -eq $n } | Select-Object -First 1
  if (-not $o) { $unknown += $n; continue }
  foreach ($c in $o.核心盟约) { $count[$c] = 1 + $count[$c] }
  foreach ($c in $o.附加盟约) { $count[$c] = 1 + $count[$c] }
}
# 转职装备也算一个人头
foreach ($e in $Extra) {
  $c = $jobMap[$e]
  if ($c) { $count[$c] = 1 + $count[$c]; "（装备 $e 提供 +1 $c）" }
  else { "（装备 $e 不是转职装备，不算人头）" }
}
if ($unknown.Count -gt 0) { "⚠ 库里没有: " + ($unknown -join ',') }

"`n=== 已激活 ==="
$active = @()
foreach ($c in $cov.covenants) {
  $have = if ($count.ContainsKey($c.name)) { $count[$c.name] } else { 0 }
  if ($have -ge $c.activateCount) {
    "  {0}（{1}/{2}）{3}" -f $c.name, $have, $c.activateCount, $(if($c.bondType -eq 'SEASON'){' 大盟约'}else{''})
    $active += $c.name
  }
}
if ($active.Count -eq 0) { "  （没有激活的盟约）" }
"`n=== 差一点（人够了就激活）==="
foreach ($c in $cov.covenants) {
  $have = if ($count.ContainsKey($c.name)) { $count[$c.name] } else { 0 }
  if ($have -gt 0 -and $have -lt $c.activateCount) {
    "  {0}：{1}/{2}（还差 {3}）" -f $c.name, $have, $c.activateCount, ($c.activateCount - $have)
  }
}
"`n可用的 -Active 参数值: " + ($active -join ',')
