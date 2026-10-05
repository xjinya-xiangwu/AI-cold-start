# =====================================================================
# credential-lint.ps1 — R01 前置构件：导出产物凭证形态扫描（PRD N2「lint 报警中止」）
# 用法: powershell -File scripts\credential-lint.ps1 <路径1> [路径2 ...]
#       路径可为文件或目录（目录递归）。命中任意模式 -> 退出码 1。
# 输出纪律：只打印 file:line + 模式名 + 打码预览，绝不回显完整密钥值。
# 已知局限（PRD §10）：形态 lint 不是万能脱敏——零命中 ≠ 无凭证，仍需人工预览。
# =====================================================================
param([Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)][string[]]$Paths)

$ErrorActionPreference = "Stop"
$patterns = @(
    @{ name = "OpenAI-style-key";        rx = 'sk-[A-Za-z0-9_-]{16,}' },
    @{ name = "Anthropic-key";           rx = 'sk-ant-[A-Za-z0-9_-]{10,}' },
    @{ name = "GitHub-PAT";              rx = 'gh[pousr]_[A-Za-z0-9]{20,}' },
    @{ name = "GitHub-fine-grained-PAT"; rx = 'github_pat_[A-Za-z0-9_]{20,}' },
    @{ name = "AWS-AccessKey";           rx = 'AKIA[0-9A-Z]{16}' },
    @{ name = "Slack-token";             rx = 'xox[baprs]-[A-Za-z0-9-]{10,}' },
    @{ name = "GitLab-PAT";              rx = 'glpat-[A-Za-z0-9_-]{16,}' },
    @{ name = "Google-API-key";          rx = 'AIza[0-9A-Za-z_-]{30,}' },
    @{ name = "Private-key-block";       rx = '-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY' },
    @{ name = "JWT";                     rx = 'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}' },
    @{ name = "Lark-app-secret";         rx = 'app_secret"?\s*[:=]\s*"?[A-Za-z0-9]{16,}' },
    @{ name = "Generic-credential-assign"; rx = '(?i)(api[_-]?key|access[_-]?token|client[_-]?secret|password)"?\s*[:=]\s*["'']?[A-Za-z0-9_\-/+=]{20,}' },
    @{ name = "Bearer-token";            rx = '(?i)bearer\s+[A-Za-z0-9_\-\.=]{24,}' }
)
$skipDirs = @(".git", "_backup", "node_modules", ".mimosa", "_state")

$files = @()
foreach ($p in $Paths) {
    if (-not (Test-Path $p)) { Write-Host ("[跳过] 路径不存在: " + $p); continue }
    if (Test-Path $p -PathType Leaf) { $files += $p }
    else {
        $files += Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $skip = $false
            foreach ($s in $skipDirs) { if ($_.FullName -like ("*\" + $s + "\*")) { $skip = $true; break } }
            (-not $skip) -and $_.Length -lt 2MB
        } | ForEach-Object { $_.FullName }
    }
}

$hits = 0
foreach ($f in $files) {
    $text = $null
    try { $text = [System.IO.File]::ReadAllText($f) } catch { continue }
    if ($null -eq $text) { continue }
    $lines = $text -split "`n"
    for ($li = 0; $li -lt $lines.Count; $li++) {
        foreach ($pt in $patterns) {
            $mm = [regex]::Match($lines[$li], $pt.rx)
            if ($mm.Success) {
                $hits++
                $v = $mm.Value
                $masked = if ($v.Length -gt 10) { $v.Substring(0, 6) + "***(" + $v.Length + "B)" } else { "***" }
                Write-Host ("[命中] {0}:{1} [{2}] {3}" -f $f, ($li + 1), $pt.name, $masked) -ForegroundColor Yellow
                break
            }
        }
    }
}
Write-Host ""
if ($hits -gt 0) {
    Write-Host ("[结果] 命中 {0} 处 —— 按 PRD N2：lint 报警即中止，禁止导出/提交（先脱敏为占位符）。" -f $hits) -ForegroundColor Red
    exit 1
}
Write-Host "[结果] 零命中。注意：形态 lint 不是万能脱敏，发布前仍需人工预览（PRD §10）。" -ForegroundColor Green
exit 0
