# =====================================================================
# collect.ps1 - AI 冷启动包 · 周更抓源脚本（生产侧每周四运行）
# 流程: 抓源(GitHub API + awesome 清单) -> host 白名单校验 -> license
#       白名单过滤 -> 与上期快照 diff -> 产出候选报告(周五人工周审用)
# 用法: powershell -ExecutionPolicy Bypass -File collector\collect.ps1
# 设计约束: 零依赖(PowerShell 5.1+)；无 token 模式 GitHub API 限 60 req/h，
#           脚本内置节流；只读不写仓库内容。
# =====================================================================
param(
    [int]$MaxCandidates = 30   # 每期报告候选上限（周审人工工作量控制）
)

$ErrorActionPreference = "Stop"
$Root       = $PSScriptRoot
$StateDir   = Join-Path $Root "state"
$ReportDir  = Join-Path $Root "reports"
$SeenFile   = Join-Path $StateDir "seen.json"

# ---------- 安全约束：URL 出口校验（仅 http/https + host 白名单，拒绝内网/保留地址） ----------
$AllowedHosts = @(
    "api.github.com",
    "github.com",
    "raw.githubusercontent.com"
)
$PrivateIpPatterns = @(
    '^10\.', '^192\.168\.', '^172\.(1[6-9]|2[0-9]|3[01])\.',
    '^127\.', '^0\.', '^169\.254\.', '^::1$', '^f[cd]'
)
function Assert-Url([string]$Url) {
    $u = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$u)) { throw "非法 URL: $Url" }
    if ($u.Scheme -ne "http" -and $u.Scheme -ne "https") { throw "仅允许 http/https: $Url" }
    $host_ = $u.Host
    # host 必须在白名单（DNS 名称），拒绝任何 IP 字面量（防 SSRF 到内网）
    if ($PrivateIpPatterns | Where-Object { $host_ -match $_ }) { throw "拒绝内网/保留地址: $Url" }
    if ($host_ -match '^\d+\.\d+\.\d+\.\d+$') { throw "拒绝 IP 字面量: $Url" }
    if ($AllowedHosts -notcontains $host_) { throw "host 不在白名单($($AllowedHosts -join ', ')): $Url" }
    return $u
}
$GhToken = $env:ASP_GITHUB_TOKEN   # 可选：设置后 API 配额 60/h -> 5000/h，awesome 候选可自动核 license
function Get-GhHeaders([string]$Accept = "application/vnd.github+json") {
    $h = @{ "User-Agent" = "asp-collector/0.1"; "Accept" = $Accept }
    if ($GhToken) { $h["Authorization"] = "Bearer $GhToken" }
    return $h
}
function Fetch-Json([string]$Url) {
    $null = Assert-Url $Url
    return Invoke-RestMethod -Uri $Url -Headers (Get-GhHeaders) -TimeoutSec 30
}
function Fetch-Text([string]$Url) {
    $null = Assert-Url $Url
    return (Invoke-WebRequest -Uri $Url -Headers (Get-GhHeaders "text/plain") -TimeoutSec 30 -UseBasicParsing).Content
}

# ---------- license 白名单（产品纪律：非白名单拒入） ----------
$LicenseAllow = @("MIT", "Apache-2.0", "CC0-1.0", "CC-BY-4.0", "Unlicense")

# ---------- 1) 抓源 A：GitHub 搜索（近 7 天活跃的 skills/agent 角色仓） ----------
Write-Host "[1/5] 抓取 GitHub 搜索（近 7 天 pushed）..."
$since = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
$queries = @(
    "topic:claude-skills pushed:>=$since",
    "agent+skills+in:name,description pushed:>=$since"
)
$repoCandidates = @{}   # full_name -> @{ url; stars; desc; source }
foreach ($q in $queries) {
    $enc = [Uri]::EscapeDataString($q)
    $r = Fetch-Json "https://api.github.com/search/repositories?q=$enc&sort=stars&order=desc&per_page=25"
    foreach ($item in $r.items) {
        if (-not $repoCandidates.ContainsKey($item.full_name)) {
            $repoCandidates[$item.full_name] = @{
                url = $item.html_url; stars = $item.stargazers_count;
                desc = $item.description; source = "github-search";
                # search 响应自带 license，直接复用（零额外 API 配额消耗）
                license = if ($item.license) { $item.license.spdx_id } else { "NONE" }
            }
        }
    }
    Start-Sleep -Seconds 2   # search API 独立限流 30 req/min
}

# ---------- 2) 抓源 B：awesome 清单（提链，不打包内容） ----------
Write-Host "[2/5] 抓取 awesome 清单..."
$awesomeSources = @(
    "https://raw.githubusercontent.com/hesreallyhim/awesome-claude-code/main/README.md"
    # 新增清单源：往数组加 raw.githubusercontent.com 下的 README.md 地址即可（host 白名单内）
)
foreach ($src in $awesomeSources) {
    try {
        $md = Fetch-Text $src
        # 提取 markdown 链接中的 github 仓库（owner/repo 形态）
        foreach ($m in [regex]::Matches($md, 'github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)')) {
            $fn = $m.Groups[1].Value
            if ($fn -notmatch '\.(png|jpg|svg|gif)$' -and -not $repoCandidates.ContainsKey($fn)) {
                $repoCandidates[$fn] = @{ url = "https://github.com/$fn"; stars = -1; desc = ""; source = "awesome-list" }
            }
        }
    } catch { Write-Host "  清单不可达，跳过: $src" -ForegroundColor DarkGray }
}

Write-Host ("      候选共 {0} 个（去重后）" -f $repoCandidates.Count)

# ---------- 3) license 核验（限流策略：awesome 提链默认不逐个查，避免打满 60/h 配额） ----------
Write-Host "[3/5] 核验 license（白名单: $($LicenseAllow -join '/'))..."
$checked = @{}
$unverified = @{}   # awesome 提链且未核验（无 token 时全部落这里，周审人工核）
foreach ($fn in $repoCandidates.Keys) {
    if ($repoCandidates[$fn].stars -ge 0) {
        # search 来源：license 已随响应取得，直接进白名单判定
        $checked[$fn] = $repoCandidates[$fn]
        continue
    }
    if ($GhToken) {
        try {
            $info = Fetch-Json "https://api.github.com/repos/$fn"
            $c = $repoCandidates[$fn]
            $c.stars = $info.stargazers_count
            if ($info.description) { $c.desc = $info.description }
            $c.license = if ($info.license) { $info.license.spdx_id } else { "NONE" }
            $checked[$fn] = $c
            Start-Sleep -Milliseconds 300
        } catch { Write-Host "  跳过（API 失败）: $fn" -ForegroundColor DarkGray }
    } else {
        $unverified[$fn] = $repoCandidates[$fn]   # 待人工核验，不消耗 API 配额
    }
}
$pass = @($checked.Keys | Where-Object { $LicenseAllow -contains $checked[$_].license })
$fail = @($checked.Keys | Where-Object { $LicenseAllow -notcontains $checked[$_].license })
Write-Host ("      license 通过 {0} / 拒入 {1}" -f $pass.Count, $fail.Count)

# ---------- 4) 与上期快照 diff ----------
Write-Host "[4/5] 对比上期快照..."
$seen = @{}
if (Test-Path $SeenFile) { (Get-Content $SeenFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $seen[$_.Name] = $true } }
$newItems = @($pass | Where-Object { -not $seen.ContainsKey($_) })
$dropped = @($seen.Keys | Where-Object { $pass -notcontains $_ })

# ---------- 5) 产出周审报告 ----------
Write-Host "[5/5] 生成报告..."
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }
$date = (Get-Date).ToString("yyyy-MM-dd")
$report = @()
$report += "# 周审候选报告 $date"
$report += ""
$report += "> 生成: collect.ps1（自动）｜用途: 周五人工周审。仅 license 白名单已过滤项。"
$report += "> 本期新增候选 **$($newItems.Count)** 个；上期在库但本期未再出现 **$($dropped.Count)** 个（复核是否淘汰）。"
$report += ""
$report += "## 新增候选（license 白名单已过，按 star 降序，人工评估内容质量）"
$report += ""
$report += "| 仓库 | Stars | License | 来源 | 简介 |"
$report += "|---|---|---|---|---|"
foreach ($fn in ($newItems | Sort-Object { $checked[$_].stars } -Descending | Select-Object -First $MaxCandidates)) {
    $c = $checked[$fn]
    $desc = if ($c.desc) { ($c.desc -replace '\|','/').Substring(0, [Math]::Min(60, $c.desc.Length)) } else { "" }
    $report += "| [$fn]($($c.url)) | $($c.stars) | $($c.license) | $($c.source) | $desc |"
}
$report += ""
$newUnverified = @($unverified.Keys | Where-Object { -not $seen.ContainsKey($_) })
if ($newUnverified.Count -gt 0) {
    $report += "## 待人工核验（awesome 清单提链，未自动查 license 以省 API 配额）"
    $report += ""
    $report += "> 周审时点开仓库确认 license 与质量；设置环境变量 ASP_GITHUB_TOKEN 后此类候选可自动核验。"
    $report += ""
    foreach ($fn in ($newUnverified | Select-Object -First 40)) { $report += "- https://github.com/$fn" }
    $report += ""
}
if ($dropped.Count -gt 0) {
    $report += "## 上期在库、本期未出现（复核淘汰）"
    $report += ""
    foreach ($d in $dropped) { $report += "- $d" }
    $report += ""
}
$report += "## 周审操作指引"
$report += ""
$report += "1. 逐条评估新增候选：是否与角色包定位匹配、SKILL.md 质量、是否疑似搬运（一律不收）"
$report += "2. 收录的加入 packs/<role>/skills/ 并补 manifest（来源/日期/哈希/license）"
$report += "3. 通过 build-release 发版，UPDATES.md 写清「本周新增 X，淘汰 Y」"
$reportPath = Join-Path $ReportDir ("$date-candidates.md")
$report -join "`r`n" | Out-File $reportPath -Encoding utf8
Write-Host "      报告: $reportPath"

# 更新快照（收录与否由周审后人工决定，此处只记录「本期已见」）
$pass | ForEach-Object { $seen[$_] = $true }
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }
$seen | ConvertTo-Json | Out-File $SeenFile -Encoding utf8
Write-Host "[完成] 候选 $($pass.Count) 在库（seen.json）。周审后收录的进 packs，未收录下期会再次出现在 diff（属正常）。"
