# =====================================================================
# apply-r00-patch.ps1 — 把 R00/R03 修复接入 asp.ps1（幂等、锚点校验、失配即中止）
# 用法（在 ai-cold-start 仓库根目录）: powershell -ExecutionPolicy Bypass -File scripts\apply-r00-patch.ps1
# 可选: -Target <其他 asp.ps1 路径>（测试用）
# 行为: 逐行定位三个接入点（模块加载 / install 复制 / doctor 嵌套扫描），
#       全部命中才修改；修改前备份到 _backup/asp.ps1.preR00-<时间戳>；已打过补丁则跳过。
# =====================================================================
param([string]$Target = "")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrEmpty($Target)) { $Target = Join-Path $repoRoot "asp.ps1" }
if (-not (Test-Path $Target)) { Write-Host "[错误] 找不到目标文件: $Target" -ForegroundColor Red; exit 1 }

$lines = [System.IO.File]::ReadAllLines($Target)
$changed = $false
$missing = @()

# --- 幂等检查 ---
$already = $false
foreach ($l in $lines) { if ($l -match "R00/R03 接入" -or $l -match "Copy-SkillSafe -Source") { $already = $true } }
if ($already) { Write-Host "[跳过] asp.ps1 已含 R00 补丁（幂等）。"; exit 0 }

# --- 锚点 1: 模块加载（在 $EndMark 定义行后插入）---
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -like '$EndMark   = "<!-- asp:end -->"*') { $idx = $i; break } }
if ($idx -lt 0) { $missing += "module-load($EndMark 定义行)" } else {
    $insert = @(
        "",
        "# R00/R03 接入：技能安全复制模块（评审复现缺陷修复；scripts/skill-safe-copy.ps1）",
        '. (Join-Path $PSScriptRoot "scripts/skill-safe-copy.ps1")'
    )
    $lines = $lines[0..$idx] + $insert + $lines[($idx + 1)..($lines.Count - 1)]
    $changed = $true
}

# --- 锚点 2: install 复制（替换 Copy-Item 嵌套缺陷行）---
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq 'Copy-Item $s.FullName (Join-Path $dst $s.Name) -Recurse -Force') { $idx = $i; break }
}
if ($idx -lt 0) { $missing += "install-copy(Copy-Item 缺陷行)" } else {
    $indent = ($lines[$idx] -replace "^( *)Copy-Item.*$", '$1')
    $repl = @(
        ($indent + '# R00：已存在技能目录 -> 先整目录备份再逐项覆盖（不嵌套、未知用户文件保留）'),
        ($indent + '$r = Copy-SkillSafe -Source $s.FullName -DestinationDir $dst'),
        ($indent + 'if ($r.backup) { Write-Host ("      备份: {0} -> {1}" -f $s.Name, $r.backup) }')
    )
    $lines = $lines[0..($idx - 1)] + $repl + $lines[($idx + 1)..($lines.Count - 1)]
    $changed = $true
}

# --- 锚点 3: doctor 嵌套扫描（在结果表打印前插入）---
$idx = -1
for ($i = 0; $i -lt ($lines.Count - 1); $i++) {
    if ($lines[$i].Trim() -eq 'Write-Host ""' -and $lines[$i + 1] -match "Format-Table -AutoSize") { $idx = $i; break }
}
if ($idx -lt 0) { $missing += "doctor(nested-scan 插入点)" } else {
    $insert = @(
        '    # R00/R03：嵌套技能目录检测（历史缺陷签名：技能目录下同名子目录；doctor 只报告，',
        '    #   修复需显式确认后运行 Repair-NestedSkillDir，见 docs/P0-R00-INTEGRATION.md）',
        '    foreach ($a in $agents) {',
        '        if (-not $a.skills_dir) { continue }',
        '        $sd = Expand-Tilde $a.skills_dir',
        '        if (-not (Test-Path $sd)) { continue }',
        '        foreach ($n in (Get-NestedSkillDirs -SkillsDir $sd)) {',
        '            $rows += [pscustomobject]@{ Agent = $a.name; Server = "-"; 结果 = "WARN"; 说明 = ("技能目录嵌套(历史缺陷): {0} —— 修复见 docs/P0-R00-INTEGRATION.md" -f $n) }',
        '        }',
        '    }'
    )
    $lines = $lines[0..($idx - 1)] + $insert + $lines[$idx..($lines.Count - 1)]
    $changed = $true
}

if ($missing.Count -gt 0) {
    Write-Host "[中止] 未找到以下锚点（文件可能已变更，禁止盲改）:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
}
if (-not $changed) { Write-Host "[跳过] 无变更。"; exit 0 }

# --- 备份 + 写回（保留 UTF-8 BOM，与原文件一致）---
$backupDir = Join-Path $repoRoot "_backup"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
$backup = Join-Path $backupDir ("asp.ps1.preR00-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
Copy-Item $Target $backup -Force
$outText = ($lines -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($Target, $outText, (New-Object System.Text.UTF8Encoding($true)))
Write-Host ("[完成] asp.ps1 已接入 R00/R03 修复。原文件备份: {0}" -f $backup)
Write-Host "下一步: 运行 docs/qa/TEST-CASES-P0.md 真机用例（TC-R00-01 起）后再解除宣传冻结。"
