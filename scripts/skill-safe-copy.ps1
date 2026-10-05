# =====================================================================
# skill-safe-copy.ps1 — R00/R03 核心模块：技能目录安全复制 / 备份 / 嵌套检测与修复
# 依据：开发级 PRD v0.2 R00/R03/N1/§5.8；docs/qa/TEST-CASES-P0.md
# 缺陷背景（2026-10-03 评审复现）：asp.ps1 对已存在技能目录 Copy-Item -Recurse -Force
#   会产生 技能名/技能名/ 嵌套；asp.sh 裸 cp -R 无备份直接覆盖。
# 设计约束：零外部依赖，PowerShell 5.1 兼容；不递归删除未知目录（PRD §5.8）。
# 供 asp.ps1 通过 `. (Join-Path $PSScriptRoot "scripts/skill-safe-copy.ps1")` 加载。
# 测试：scripts/test-skill-safe-copy.ps1（抽取 R00-CORE region 执行夹具断言）。
# =====================================================================

#region R00-CORE

function Copy-SkillSafe {
    # 把单个技能目录安全复制进 skills 根目录：
    #   目标不存在 -> 整目录复制（created）
    #   目标已存在 -> 整目录先备份到 <DestinationDir>/_backup/<name>-<时间戳>，
    #                再逐项覆盖（源内各项替换目标同名项；目标独有文件=未知用户文件保留不动）
    param([Parameter(Mandatory=$true)][string]$Source,
          [Parameter(Mandatory=$true)][string]$DestinationDir,
          [string]$BackupRoot = "")
    if (-not (Test-Path $Source)) { throw ("Copy-SkillSafe: 源不存在: {0}" -f $Source) }
    if ([string]::IsNullOrEmpty($DestinationDir)) { throw "Copy-SkillSafe: 目标目录为空" }
    $name = Split-Path $Source -Leaf
    if (-not (Test-Path $DestinationDir)) { New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null }
    $target = Join-Path $DestinationDir $name
    $result = @{ status = "created"; backup = $null; target = $target }
    if (Test-Path $target) {
        if ([string]::IsNullOrEmpty($BackupRoot)) { $BackupRoot = Join-Path $DestinationDir "_backup" }
        if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
        $backup = Join-Path $BackupRoot ($name + "-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
        Copy-Item $target $backup -Recurse -Force
        $result.backup = $backup
        Copy-Item (Join-Path $Source "*") $target -Recurse -Force
        $result.status = "updated"
    } else {
        Copy-Item $Source $target -Recurse -Force
    }
    return $result
}

function Get-NestedSkillDirs {
    # 检测历史缺陷签名：skills/<name>/<name>/SKILL.md（内层为完整技能目录）
    # 返回嵌套内层目录路径列表；无嵌套返回空数组。只检测，不修改。
    param([Parameter(Mandatory=$true)][string]$SkillsDir)
    $out = @()
    if (-not (Test-Path $SkillsDir)) { return $out }
    foreach ($d in (Get-ChildItem $SkillsDir -Directory -ErrorAction SilentlyContinue)) {
        $inner = Join-Path $d.FullName $d.Name
        if (Test-Path (Join-Path $inner "SKILL.md")) { $out += $inner }
    }
    return $out
}

function Repair-NestedSkillDir {
    # 修复单个嵌套目录（NestedDir = skills/<name>/<name>）：
    #   1) 整目录（外层）先备份；2) 未知用户文件守卫：内层存在而外层没有的文件名 -> 不清理，报告隔离；
    #   3) 内层内容上提到外层（内层=新版）；4) 逐文件哈希校验后清理内层；校验失败保留内层并报告。
    # 不满足"确认旧安装器产物+备份完成+无未知用户文件"三条件之一即不清理（PRD N1）。
    param([Parameter(Mandatory=$true)][string]$NestedDir, [string]$BackupRoot = "")
    $outer = Split-Path $NestedDir -Parent
    $name = Split-Path $outer -Leaf
    $innerName = Split-Path $NestedDir -Leaf
    if (-not (Test-Path (Join-Path $NestedDir "SKILL.md")) -or $innerName -ne $name) {
        return @{ status = "skipped"; reason = "非缺陷签名（需 skills/<name>/<name>/SKILL.md，内外同名）" }
    }
    if ([string]::IsNullOrEmpty($BackupRoot)) { $BackupRoot = Join-Path (Split-Path $outer -Parent) "_backup" }
    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
    $backup = Join-Path $BackupRoot ($name + "-nested-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $outer $backup -Recurse -Force
    # 未知用户文件守卫：外层文件清单必须排除内层（内层恰是缺陷产物，其内容不算"外层已知"）
    $outerNames = @(Get-ChildItem $outer -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { -not $_.FullName.StartsWith($NestedDir, [System.StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object { $_.Name })
    $unknown = @(Get-ChildItem $NestedDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $outerNames -notcontains $_.Name })
    if ($unknown.Count -gt 0) {
        return @{ status = "quarantined"; backup = $backup; unknown = @($unknown | ForEach-Object { $_.FullName }) }
    }
    Copy-Item (Join-Path $NestedDir "*") $outer -Recurse -Force
    $bad = @(Get-ChildItem $NestedDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $rel = $_.FullName.Substring($NestedDir.Length).TrimStart("\")
        $up = Join-Path $outer $rel
        (-not (Test-Path $up)) -or ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $up).Hash)
    })
    if ($bad.Count -gt 0) { return @{ status = "verify-failed"; backup = $backup } }
    Remove-Item $NestedDir -Recurse -Force
    return @{ status = "repaired"; backup = $backup }
}

#endregion R00-CORE
