# =====================================================================
# test-export-sanitize.ps1 — R01 模块夹具测试（抽取 R01-CORE region 执行断言）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-export-sanitize.ps1
# =====================================================================
param([switch]$Keep)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path $PSScriptRoot "export-sanitize.ps1"
$raw = [System.IO.File]::ReadAllText($modulePath)
$m = [regex]::Match($raw, "(?s)#region R01-CORE(.*?)#endregion R01-CORE")
if (-not $m.Success) { Write-Host "[错误] 未找到 R01-CORE region" -ForegroundColor Red; exit 1 }
Invoke-Expression $m.Groups[1].Value

$fx = Join-Path $env:TEMP ("asp-r01-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $fx "home\.cursor") -Force | Out-Null
$script:Failures = 0
function Assert([string]$Name, [bool]$Cond) {
    if ($Cond) { Write-Host ("  PASS " + $Name) -ForegroundColor Green }
    else { $script:Failures++; Write-Host ("  FAIL " + $Name) -ForegroundColor Red }
}

try {
    # JSON 夹具：MCP 配置带 token
    $json = @'
{
  "mcpServers": {
    "github": { "command": "npx", "args": ["-y", "pkg"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456", "SAFE_VAR": "hello" } },
    "web": { "url": "https://x.invalid/mcp", "headers": { "Authorization": "Bearer abcdefghijklmnop" } }
  }
}
'@
    $jsonPath = Join-Path $fx "home\.cursor\mcp.json"
    [IO.File]::WriteAllText($jsonPath, $json)
    # TOML 夹具：codex 风格
    $toml = @'
model = "gpt-x"

[mcp_servers.search]
url = "https://x.invalid/sse"
api_key = "sk-test-ABCDEFGHIJKLMNOP"
enabled = true
'@
    $tomlPath = Join-Path $fx "home\config.toml"
    [IO.File]::WriteAllText($tomlPath, $toml)
    # 干净 json 不应被改
    $cleanPath = Join-Path $fx "home\clean.json"
    [IO.File]::WriteAllText($cleanPath, '{"a": "normal value"}')

    $n = Convert-ToPlaceholders -Dir $fx
    Assert "替换计数 >= 3（token/Authorization/api_key）" ($n -ge 3)
    $j2 = [IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json
    Assert "GITHUB token -> 占位符" ($j2.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN -eq "<AGENT-SYNC:GITHUB_PERSONAL_ACCESS_TOKEN>")
    Assert "SAFE_VAR 不动" ($j2.mcpServers.github.env.SAFE_VAR -eq "hello")
    Assert "Authorization -> 占位符" ($j2.mcpServers.web.headers.Authorization -like "<AGENT-SYNC:*")
    $t2 = [IO.File]::ReadAllText($tomlPath)
    Assert "TOML api_key -> 占位符" ($t2 -match '<AGENT-SYNC:')
    Assert "TOML 非 key 行不动" ($t2 -match 'model = "gpt-x"')
    Assert "干净 json 未动" (([IO.File]::ReadAllText($cleanPath)) -match 'normal value')

    # lint 兜底：替换后残余凭证应能被抓到（故意放一个键名不含关键词的值）
    [IO.File]::WriteAllText((Join-Path $fx "home\hidden.txt"), "cfg=ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    & (Join-Path $PSScriptRoot "credential-lint.ps1") $fx | Out-Null
    Assert "lint 对残余凭证 exit 1" ($LASTEXITCODE -eq 1)
} finally {
    if ($Keep) { Write-Host ("夹具保留: " + $fx) -ForegroundColor DarkGray }
    else { Remove-Item $fx -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($script:Failures -eq 0) { Write-Host "全部断言通过 ✓（R01-CORE @ export-sanitize.ps1）" -ForegroundColor Green; exit 0 }
else { Write-Host ("失败断言 {0} 个 ✗" -f $script:Failures) -ForegroundColor Red; exit 1 }
