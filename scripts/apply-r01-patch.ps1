# =====================================================================
# apply-r01-patch.ps1 — 把 R01/D18 接入 asp.ps1 export 流程（幂等、锚点校验、失配即中止）
# 前置：apply-r00-patch.ps1 已执行（module-load 锚点同区）；credential-lint.ps1 已在 scripts/。
# 用法: powershell -ExecutionPolicy Bypass -File scripts\apply-r01-patch.ps1 [-Target asp.ps1]
# 行为: ①加载 export-sanitize 模块 ②export 打包前插入 占位符替换+lint 门 ③manifest/说明文案改占位符口径
# =====================================================================
param([string]$Target = "")

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrEmpty($Target)) { $Target = Join-Path $repoRoot "asp.ps1" }
if (-not (Test-Path $Target)) { Write-Host "[错误] 找不到目标文件: $Target" -ForegroundColor Red; exit 1 }

$lines = [System.IO.File]::ReadAllLines($Target)
$missing = @()

$already = $false
foreach ($l in $lines) { if ($l -match "R01 接入|Convert-ToPlaceholders -StagingDir") { $already = $true } }
if ($already) { Write-Host "[跳过] asp.ps1 已含 R01 补丁（幂等）。"; exit 0 }

# --- 锚点 1: 模块加载（跟随 R00 的加载行之后；若无 R00 行则插在 $EndMark 后）---
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match 'skill-safe-copy\.ps1"\)$') { $idx = $i; break } }
if ($idx -lt 0) {
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -like '$EndMark   = "<!-- asp:end -->"*') { $idx = $i; break } }
}
if ($idx -lt 0) { $missing += "module-load(R00 加载行或 EndMark)" } else {
    $insert = @(
        '# R01 接入：export 产物占位符替换模块（D18；scripts/export-sanitize.ps1）',
        '. (Join-Path $PSScriptRoot "scripts/export-sanitize.ps1")'
    )
    $lines = $lines[0..$idx] + $insert + $lines[($idx + 1)..($lines.Count - 1)]
}

# --- 锚点 2: export 打包前插入 替换+lint 门（在 $manifest = @{ 之前）---
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '$manifest = @{') { $idx = $i; break } }
if ($idx -lt 0) { $missing += "export($manifest 定义行)" } else {
    $insert = @(
        '    # R01 接入（D18/N2）：凭证值 -> 占位符，lint 零命中才继续打包；报警即中止并清理暂存，不留半成品',
        '    $ph = Convert-ToPlaceholders -Dir $staging',
        '    Write-Host ("[R01] 占位符替换: {0} 处" -f $ph)',
        '    & (Join-Path $PSScriptRoot "scripts/credential-lint.ps1") $staging',
        '    if ($LASTEXITCODE -ne 0) {',
        '        Write-Host "[中止] 导出产物命中凭证形态（PRD N2）。已清理暂存，未生成任何输出文件。" -ForegroundColor Red',
        '        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue',
        '        exit 1',
        '    }'
    )
    $lines = $lines[0..($idx - 1)] + $insert + $lines[$idx..($lines.Count - 1)]
}

# --- 锚点 3/4: 文案改占位符口径（两处同一短语）---
$oldNote = "包内 MCP 配置可能含 API key，请妥善保管"
$newNote = "凭证值已替换为 <AGENT-SYNC:*> 占位符（R01/D18），由 Agent-sync age 通道补值"
$replaced = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains($oldNote)) { $lines[$i] = $lines[$i].Replace($oldNote, $newNote); $replaced++ }
}
if ($replaced -lt 2) { $missing += ("文案口径({0}/2 处)" -f $replaced) }

if ($missing.Count -gt 0) {
    Write-Host "[中止] 未找到以下锚点（文件可能已变更，禁止盲改）:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
}

$backupDir = Join-Path $repoRoot "_backup"
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
$backup = Join-Path $backupDir ("asp.ps1.preR01-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
Copy-Item $Target $backup -Force
$outText = ($lines -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($Target, $outText, (New-Object System.Text.UTF8Encoding($true)))
Write-Host ("[完成] asp.ps1 已接入 R01（替换+lint 门+文案口径）。原文件备份: {0}" -f $backup)
Write-Host "下一步: 真机跑 TC-R01-01（注入测试 token 的 export，断言产物与日志零原值、失败即中止）。"
