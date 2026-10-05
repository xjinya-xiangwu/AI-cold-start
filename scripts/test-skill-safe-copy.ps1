# =====================================================================
# test-skill-safe-copy.ps1 — R00 模块 v2（DST-P0-01 算法）夹具测试
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-skill-safe-copy.ps1 [-Keep]
# =====================================================================
param([switch]$Keep)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path $PSScriptRoot "skill-safe-copy.ps1"
$raw = [IO.File]::ReadAllText($modulePath)
$m = [regex]::Match($raw, "(?s)#region R00-CORE(.*?)#endregion R00-CORE")
if (-not $m.Success) { Write-Host "[错误] 未找到 R00-CORE region" -ForegroundColor Red; exit 1 }
Invoke-Expression $m.Groups[1].Value

$fx = Join-Path $env:TEMP ("asp-r00-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $fx -Force | Out-Null
$script:Failures = 0
function Assert([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Host ("  PASS " + $Name) -ForegroundColor Green }
    else { $script:Failures++; Write-Host ("  FAIL " + $Name) -ForegroundColor Red }
}
function New-FakeSkill([string]$Dir, [string]$Version, [hashtable]$Extra = @{}) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    Set-Content (Join-Path $Dir "SKILL.md") ("v=" + $Version) -Encoding UTF8
    foreach ($k in $Extra.Keys) {
        $p = Join-Path $Dir $k
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        Set-Content $p $Extra[$k] -Encoding UTF8
    }
}

try {
    # ---- T1 全新安装：created，tmp 零残留，tree_sha256 返回 ----
    Write-Host "T1 全新安装（created / .asp-tmp 零残留 / tree_sha256）"
    $src1 = Join-Path $fx "pack\skillA"; New-FakeSkill $src1 "v1" @{"ref.md" = "ref-v1"}
    $dst1 = Join-Path $fx "dst1"
    $r1 = Copy-SkillSafe -Source $src1 -DestinationDir $dst1 -RunId "t1" -AgentId "cursor"
    Assert "status=created" ($r1.status -eq "created")
    Assert "顶层 SKILL.md 在位" (Test-Path (Join-Path $dst1 "skillA\SKILL.md"))
    Assert "无嵌套 skillA/skillA" (-not (Test-Path (Join-Path $dst1 "skillA\skillA")))
    Assert "tmp 零残留" (@(Get-ChildItem $dst1 -Force | Where-Object Name -like ".*asp-tmp-*").Count -eq 0)
    Assert "tree_sha256 64hex" ($r1.tree_sha256 -match '^[0-9a-f]{64}$')
    $h1 = $r1.tree_sha256

    # ---- T2 未修改替换：state 哈希一致 → replace，备份存在 ----
    Write-Host "T2 未修改替换（reason=replace）"
    $r2 = Copy-SkillSafe -Source $src1 -DestinationDir $dst1 -RunId "t2" -AgentId "cursor" -StateTreeSha256 $h1
    Assert "reason=replace" ($r2.reason -eq "replace")
    Assert "备份目录在 _backup/<run>/<agent>/skillA" (Test-Path (Join-Path $r2.backup ""))
    Assert "备份内 SKILL.md 存在" (Test-Path (Join-Path $r2.backup "SKILL.md"))

    # ---- T3 用户修改后更新：user_modified + 未知文件进备份并报告（不原位保留）----
    Write-Host "T3 用户修改（user_modified / unknown_files 报告 / 新目录为纯包内容）"
    $src3 = Join-Path $fx "pack\skillB"; New-FakeSkill $src3 "v2-new" @{"added.md" = "added"}
    $dst3 = Join-Path $fx "dst3"; $t3 = Join-Path $dst3 "skillB"; New-Item -ItemType Directory -Path $t3 -Force | Out-Null
    Set-Content (Join-Path $t3 "SKILL.md") "v1-user-edit" -Encoding UTF8
    Set-Content (Join-Path $t3 "user-extra.txt") "mine" -Encoding UTF8
    $r3 = Copy-SkillSafe -Source $src3 -DestinationDir $dst3 -RunId "t3" -AgentId "cursor" -StateTreeSha256 "deadbeef"
    Assert "reason=user_modified" ($r3.reason -eq "user_modified")
    Assert "顶层变为新版" ((Get-Content (Join-Path $t3 "SKILL.md") -Raw).Trim() -eq "v=v2-new")
    Assert "用户版在备份中" ((Get-Content (Join-Path $r3.backup "SKILL.md") -Raw).Trim() -eq "v1-user-edit")
    Assert "unknown_files 报告含 user-extra.txt" (($r3.unknown_files -join " ") -match "user-extra\.txt")
    Assert "旧目录 .asp-old 已清理" (@(Get-ChildItem $dst3 -Force | Where-Object Name -like ".*asp-old-*").Count -eq 0)

    # ---- T4 嵌套：无 manifest → ASP-W-NEST-002 跳过（不改动；同名技能才触发）----
    Write-Host "T4 嵌套无 manifest（ASP-W-NEST-002，不改动）"
    $sk4 = Join-Path $fx "skills4"
    New-FakeSkill (Join-Path $sk4 "skillC\skillC") "v1"
    $srcC = Join-Path $fx "pack\skillC"; New-FakeSkill $srcC "v1-new"
    $r4 = Copy-SkillSafe -Source $srcC -DestinationDir $sk4 -RunId "t4" -AgentId "cursor"
    Assert "code=ASP-W-NEST-002" ($r4.code -eq "ASP-W-NEST-002")
    Assert "嵌套原样保留" (Test-Path (Join-Path $sk4 "skillC\skillC\SKILL.md"))

    # ---- T5 嵌套 + manifest 命中 → repaired；不命中 → reported ----
    Write-Host "T5 嵌套 + 发布清单（命中修复 / 不命中报告）"
    $inner5 = Join-Path $fx "skills5\skillD\skillD"
    New-FakeSkill $inner5 "v1"
    $manifestOk = @{ "v1" = @{} }
    $mf = $manifestOk["v1"]
    Get-ChildItem $inner5 -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($inner5.Length).Replace('\', '/')
        $h = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($_.FullName))).Replace('-', '').ToLower()
        $mf[$rel] = $h
    }
    $r5 = Repair-NestedWithManifest -NestedDir $inner5 -PublishedVersions $manifestOk
    Assert "manifest 命中 → repaired" ($r5.status -eq "repaired")
    Assert "内层已清理" (-not (Test-Path $inner5))
    $r5b = Repair-NestedWithManifest -NestedDir $inner5 -PublishedVersions $manifestOk
    Assert "已清理后再跑 → skipped" ($r5b.status -eq "skipped")
    $sk5b = Join-Path $fx "skills5b"
    New-FakeSkill (Join-Path $sk5b "skillE\skillE") "vX" @{"mystery.md" = "?"}
    $r5c = Repair-NestedWithManifest -NestedDir (Join-Path $sk5b "skillE\skillE") -PublishedVersions $manifestOk
    Assert "不匹配 → reported ASP-W-NEST-002" ($r5c.status -eq "reported" -and $r5c.code -eq "ASP-W-NEST-002")
    Assert "不匹配 → 内层保留" (Test-Path (Join-Path $sk5b "skillE\skillE\SKILL.md"))

    # ---- T6 symlink 守卫（junction）----
    Write-Host "T6 symlink 守卫（ASP-W-LINK-001，跳过）"
    $sk6 = Join-Path $fx "skills6"; New-Item -ItemType Directory -Path $sk6 -Force | Out-Null
    $target6 = Join-Path $fx "link-target"; New-Item -ItemType Directory -Path $target6 -Force | Out-Null
    $j = Join-Path $sk6 "skillJ"
    $srcJ = Join-Path $fx "pack\skillJ"; New-FakeSkill $srcJ "v-j"
    try { New-Item -ItemType Junction -Path $j -Target $target6 | Out-Null } catch { Write-Host "  (junction 创建失败，跳过本组)" -ForegroundColor DarkGray }
    if (Test-Path $j) {
        $r6 = Copy-SkillSafe -Source $srcJ -DestinationDir $sk6 -RunId "t6" -AgentId "cursor"
        Assert "code=ASP-W-LINK-001" ($r6.code -eq "ASP-W-LINK-001")
    }

    # ---- T7 tree_sha256 确定性 + retention ----
    Write-Host "T7 tree_sha256 确定性 / 备份保留清理"
    Assert "同目录两次哈希一致" ((Get-TreeSha256 (Join-Path $dst1 "skillA")) -eq (Get-TreeSha256 (Join-Path $dst1 "skillA")))
    $bk = Join-Path $fx "bkroot"
    foreach ($i in 1..12) {
        $d = Join-Path $bk ("2026010" + ($i % 10) + "0" + $i + "-120000")
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Set-Content (Join-Path $d "x") $i
    }
    $removed = Clean-BackupRetention -BackupRoot $bk -KeepRuns 10 -KeepDays 30
    Assert "12 留 10 → 删 2" ($removed.Count -eq 2 -and @(Get-ChildItem $bk -Directory).Count -eq 10)
} finally {
    if ($Keep) { Write-Host ("夹具保留: " + $fx) -ForegroundColor DarkGray }
    else { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:Failures -eq 0) { Write-Host "全部断言通过 ✓（R00-CORE v2 @ DST-P0-01）" -ForegroundColor Green; exit 0 }
else { Write-Host ("失败断言 {0} 个 ✗" -f $script:Failures) -ForegroundColor Red; exit 1 }
