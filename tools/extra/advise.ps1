# 买人/上场决策建议：按「当前已激活盟约 + 是否叠层手」打分排序。
# 用法:
#   advise.ps1 -Cards 折桠,乌啾,初雪 -Active 坚守,不屈
#   advise.ps1 -Cards 折桠,乌啾                      # 不传 -Active 就自动 OCR 读当前生效盟约
#   advise.ps1 -Owned 折桠,风丸,陨星 -Active 坚守,不屈  # 已经在手、要决定谁上场
param(
  [string[]]$Cards = @(),
  [string[]]$Owned = @(),
  [string[]]$Active = @(),
  [switch]$NoOcr,
  [int]$Port = 16417
)
$v = 'E:\DSH\vision'
$db = 'C:\Users\Lenovo\Documents\deepseek-harness\default-workspace\games\arknights\卫戍协议-数据库.json'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$j = Get-Content $db -Raw -Encoding UTF8 | ConvertFrom-Json

# 1) 优先：手上有干员名单 -> 直接按「激活人数」算（最准，不靠识图）
if (-not $Active -and $Owned.Count -gt 0) {
  $covOut = & powershell -NoProfile -ExecutionPolicy Bypass -File "$v\cov.ps1" -Owned ($Owned -join ',') 2>$null
  $line = $covOut | Where-Object { $_ -match '可用的 -Active 参数值' } | Select-Object -First 1
  if ($line -match '参数值[:：]\s*(.+)$') {
    $Active = ($Matches[1] -split '[,，]') | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() }
    "（按人数算出生效盟约: $($Active -join ',')）"
  }
}
# 2) 没有名单再退回 OCR 看顶部图标
if (-not $Active -and -not $NoOcr) {
  $shot = & powershell -NoProfile -ExecutionPolicy Bypass -File "$v\see.ps1" -Question "顶部那排盟约图标里，哪些是亮着的（已生效）？只输出名字，用逗号分隔。" 2>$null
  if ($shot) {
    $Active = ($shot -split '[,，、\s]+') | Where-Object { $_ -and $_.Length -le 6 }
    "（OCR 读到生效盟约: $($Active -join ',')）"
  }
}

function Get-Op($name) {
  $j.干员 | Where-Object { $_.名字 -eq $name } | Select-Object -First 1
}

function Score-Op($o) {
  $score = 0
  $reasons = @()
  # 2026-11-10 修正（参考「千杯老登的苟分心得」）：
  # 大盟约（10 国核心）里有混子、难叠，容易翻车；小盟约（精准/灵巧等附加）才是后期主力。
  # 所以「附加盟约已激活」比「核心盟约已激活」权重更高。
  foreach ($c in $o.核心盟约) {
    if ($Active -contains $c) { $score += 2; $reasons += "核心盟约【$c】已激活(+2，大盟约有混子，谨慎)" }
    else { $reasons += "核心盟约【$c】未激活" }
  }
  foreach ($c in $o.附加盟约) {
    if ($Active -contains $c) { $score += 3; $reasons += "附加盟约【$c】已激活(+3，小盟约更稳)" }
  }
  foreach ($t in $o.普通词条) {
    $hit = $false
    foreach ($c in $Active) { if ($t.说明 -and $t.说明.Contains($c)) { $hit = $true } }
    if ($t.类型 -eq '持续叠加' -and $hit) { $score += 4; $reasons += "持续叠加作用在已激活盟约(+4)" }
    elseif ($t.类型 -eq '单次叠加' -and $hit) { $score += 2; $reasons += "单次叠加作用在已激活盟约(+2)" }
    elseif ($t.类型 -eq '持续叠加') { $score += 1; $reasons += "是叠层手，但作用盟约未激活(+1)" }
  }
  if ($o.阻挡 -ge 3) { $score += 1; $reasons += "阻挡$($o.阻挡)(+1)" }
  if ($o.阻挡 -eq 1 -and $o.核心盟约) { $reasons += "阻挡1，别放最前" }
  [pscustomobject]@{ 名字 = $o.名字; 分数 = $score; 对象 = $o; 理由 = $reasons }
}

$targets = @()
# 兼容：逗号分隔的一整串也能拆开
$Active = (($Active -join ",") -split "[,，、\s]+") | Where-Object { $_ }
$Cards = (($Cards -join ",") -split "[,，、\s]+") | Where-Object { $_ }
$Owned = (($Owned -join ",") -split "[,，、\s]+") | Where-Object { $_ }
if ($Cards.Count -gt 0) { $targets += $Cards }
if ($Owned.Count -gt 0) { $targets += $Owned }
if ($targets.Count -eq 0) { "没给 -Cards 或 -Owned"; exit }

"当前生效盟约: " + (($Active -join ',') | ForEach-Object { if($_){$_}else{'(未知)'} })
""
$rows = @()
foreach ($n in $targets) {
  $o = Get-Op $n
  if (-not $o) { "✗ $n ：库里没有这个名字（OCR 可能读错）"; continue }
  $rows += Score-Op $o
}
$rows | Sort-Object 分数 -Descending | ForEach-Object {
  "{0}  分数{1}  （{2}/{3}）" -f $_.名字, $_.分数, ($_.对象.核心盟约 -join '/'), ($_.对象.等阶)
  foreach ($t in $_.对象.普通词条) { "    [{0}] {1}" -f $t.类型, $t.说明 }
  "    → " + ($_.理由 -join '；')
  ""
}
