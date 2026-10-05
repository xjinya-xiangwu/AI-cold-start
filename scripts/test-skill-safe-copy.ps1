# =====================================================================
# test-skill-safe-copy.ps1 — R00 核心模块夹具测试（在提取真实 region 代码后运行断言）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-skill-safe-copy.ps1 [-Keep]
# 说明: 从 scripts/skill-safe-copy.ps1 抽取 R00-CORE region 逐字执行，保证测的是交付代码本身。
# =====================================================================
param([switch]$Keep)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path $PSScriptRoot "skill-safe-copy.ps1"
if (-not (Test-Path $modulePath)) { Write-Host "[错误] 找不到模块: $modulePath" -ForegroundColor Red; exit 1 }

# --- 抽取 R00-CORE region ---
$raw = [System.IO.File]::ReadAllText($modulePath)
$m = [regex]::Match($raw, "(?s)#region R00-CORE(.*?)#endregion R00-CORE")
if (-not $m.Success) { Write-Host "[错误] 模块中未找到 R00-CORE region" -ForegroundColor Red; exit 1 }
Invoke-Expression $m.Groups[1].Value

# --- 夹具目录 ---
$fx = Join-Path $env:TEMP ("asp-r00-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $fx -Force | Out-Null
$script:Failures = 0
function Assert([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Host ("  PASS " + $Name) -ForegroundColor Green }
    else { $script:Failures++; Write-Host ("  FAIL " + $Name) -ForegroundColor Red }
}

try {
    # ---- T1 全新复制：不嵌套 ----
    Write-Host "T1 全新复制（created，零嵌套）"
    $src1 = Join-Path $fx "pack\skillA"; New-Item -ItemType Directory -Path $src1 -Force | Out-Null
    Set-Content (Join-Path $src1 "SKILL.md") "v1" -Encoding UTF8
    $dst1 = Join-Path $fx "dst1"
    $r1 = Copy-SkillSafe -Source $src1 -DestinationDir $dst1
    Assert "状态=created" ($r1.status -eq "created")
    Assert "顶层 SKILL.md 存在" (Test-Path (Join-Path $dst1 "skillA\SKILL.md"))
    Assert "无嵌套 skillA/skillA" (-not (Test-Path (Join-Path $dst1 "skillA\skillA")))

    # ---- T2 已存在目录：备份 + 逐项覆盖 + 未知文件保留 ----
    Write-Host "T2 覆盖更新（updated，备份含用户版，未知文件保留）"
    $dst2 = Join-Path $fx "dst2"; $t2 = Join-Path $dst2 "skillA"; New-Item -ItemType Directory -Path $t2 -Force | Out-Null
    Set-Content (Join-Path $t2 "SKILL.md") "v1-user-edit" -Encoding UTF8
    Set-Content (Join-Path $t2 "user-extra.txt") "mine" -Encoding UTF8
    $r2 = Copy-SkillSafe -Source $src1 -DestinationDir $dst2   # src1 仍是 v1；先造一个 v2 源
    $src2 = Join-Path $fx "pack\skillB"; New-Item -ItemType Directory -Path $src2 -Force | Out-Null
    Set-Content (Join-Path $src2 "SKILL.md") "v2-new" -Encoding UTF8
    Set-Content (Join-Path $src2 "newfile.md") "added" -Encoding UTF8
    $dst2b = Join-Path $fx "dst2b"; $t2b = Join-Path $dst2b "skillB"; New-Item -ItemType Directory -Path $t2b -Force | Out-Null
    Set-Content (Join-Path $t2b "SKILL.md") "v1-user-edit" -Encoding UTF8
    Set-Content (Join-Path $t2b "user-extra.txt") "mine" -Encoding UTF8
    $r2b = Copy-SkillSafe -Source $src2 -DestinationDir $dst2b
    Assert "状态=updated" ($r2b.status -eq "updated")
    Assert "顶层变为新版" ((Get-Content (Join-Path $t2b "SKILL.md") -Raw).Trim() -eq "v2-new")
    Assert "用户改动已备份" ((Get-Content (Join-Path $r2b.backup "SKILL.md") -Raw).Trim() -eq "v1-user-edit")
    Assert "未知用户文件保留" (Test-Path (Join-Path $t2b "user-extra.txt"))
    Assert "新增文件就位" (Test-Path (Join-Path $t2b "newfile.md"))
    Assert "无嵌套 skillB/skillB" (-not (Test-Path (Join-Path $dst2b "skillB\skillB")))

    # ---- T3 嵌套检测 ----
    Write-Host "T3 嵌套检测（签名 skills/x/x/SKILL.md）"
    $sk = Join-Path $fx "skills3"
    New-Item -ItemType Directory -Path (Join-Path $sk "skillA\skillA") -Force | Out-Null
    Set-Content (Join-Path $sk "skillA\skillA\SKILL.md") "v1" -Encoding UTF8
    New-Item -ItemType Directory -Path (Join-Path $sk "skillB") -Force | Out-Null
    Set-Content (Join-Path $sk "skillB\SKILL.md") "v1" -Encoding UTF8
    $found = @(Get-NestedSkillDirs -SkillsDir $sk)
    Assert "检出 1 个嵌套" ($found.Count -eq 1)
    Assert "路径指向内层" ($found.Count -ge 1 -and (Split-Path $found[0] -Leaf) -eq "skillA" -and (Split-Path (Split-Path $found[0] -Parent) -Leaf) -eq "skillA")
    $none = @(Get-NestedSkillDirs -SkillsDir (Join-Path $fx "dst1"))
    Assert "无嵌套时返回空" ($none.Count -eq 0)

    # ---- T4 嵌套修复（正常路径）----
    Write-Host "T4 嵌套修复（备份→上提→校验→清理内层）"
    $nested = $found[0]
    Set-Content (Join-Path $sk "skillA\SKILL.md") "v1-stale" -Encoding UTF8
    $r4 = Repair-NestedSkillDir -NestedDir $nested
    Assert "状态=repaired" ($r4.status -eq "repaired")
    Assert "内层已清理" (-not (Test-Path $nested))
    Assert "外层升级为内层版本" ((Get-Content (Join-Path $sk "skillA\SKILL.md") -Raw).Trim() -eq "v1")
    Assert "修复前备份存在" (Test-Path $r4.backup)

    # ---- T5 嵌套修复（未知用户文件 → 隔离不清理）----
    Write-Host "T5 未知用户文件守卫（quarantined，内层保留）"
    $sk5 = Join-Path $fx "skills5"
    New-Item -ItemType Directory -Path (Join-Path $sk5 "skillC\skillC") -Force | Out-Null
    Set-Content (Join-Path $sk5 "skillC\skillC\SKILL.md") "v1" -Encoding UTF8
    Set-Content (Join-Path $sk5 "skillC\skillC\my-notes.md") "user only" -Encoding UTF8
    $r5 = Repair-NestedSkillDir -NestedDir (Join-Path $sk5 "skillC\skillC")
    Assert "状态=quarantined" ($r5.status -eq "quarantined")
    Assert "内层保留未删" (Test-Path (Join-Path $sk5 "skillC\skillC"))
    Assert "报告未知文件清单" ($r5.unknown.Count -ge 1 -and ($r5.unknown -join " ") -match "my-notes\.md")

    # ---- T6 修复校验失败守卫 ----
    Write-Host "T6 非签名目录跳过"
    $r6 = Repair-NestedSkillDir -NestedDir (Join-Path $fx "dst1\skillA")
    Assert "状态=skipped（无内层 SKILL.md）" ($r6.status -eq "skipped")
} finally {
    if ($Keep) { Write-Host ("夹具保留: " + $fx) -ForegroundColor DarkGray }
    else { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:Failures -eq 0) { Write-Host "全部断言通过 ✓（R00-CORE @ 提取自 skill-safe-copy.ps1）" -ForegroundColor Green; exit 0 }
else { Write-Host ("失败断言 {0} 个 ✗" -f $script:Failures) -ForegroundColor Red; exit 1 }
