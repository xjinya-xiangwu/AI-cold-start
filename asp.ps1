# =====================================================================
# asp.ps1 - AI 冷启动包 (Agent Starter Pack) 安装/更新器
# 用法:
#   asp.ps1 install [pack]     安装包到所有检测到的 agent（默认 ai-pm）
#   asp.ps1 update [pack]      从 registry 拉取并更新（默认全部已装包）
#   asp.ps1 detect             探测本机已安装的 agent
#   asp.ps1 agents [dir]       将包的 AGENTS.md 部署到指定项目目录（默认当前目录）
#   asp.ps1 status             查看已装状态
# 设计约束: 零外部依赖（仅 Windows 自带 PowerShell 5.1+）
# =====================================================================
param(
    [Parameter(Position=0)][string]$Command = "install",
    [Parameter(Position=1)][string]$Pack = "",
    [Parameter(Position=2)][string]$TargetDir = ""
)

$ErrorActionPreference = "Stop"
$Root        = $PSScriptRoot
$AdaptersDir = Join-Path $Root "adapters"
$StateFile   = Join-Path $Root "_state.json"
$BackupDir   = Join-Path $Root "_backup"
$BeginMark   = "<!-- asp:begin -->"
$EndMark     = "<!-- asp:end -->"

# ---------- 基础工具 ----------
function Expand-Tilde([string]$Path) {
    if ($Path -like "~/*") { return (Join-Path $Home $Path.Substring(2)) }
    if ($Path -eq "~")     { return $Home }
    return $Path
}

function Backup-File([string]$Path, [string]$Tag = "") {
    if (Test-Path $Path) {
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        # Tag（如 agent id）用于区分不同 agent 的同名文件（如各自根下的 AGENTS.md），避免互相覆盖
        $prefix = if ($Tag) { $Tag + "-" } else { "" }
        $dest = Join-Path $BackupDir ($prefix + (Split-Path $Path -Leaf) + "." + $stamp + ".bak")
        Copy-Item $Path $dest -Force
    }
}

function Get-Adapters {
    $list = @()
    Get-ChildItem -Path $AdaptersDir -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
        $a = (Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)
        if ($a.PSObject.Properties["enabled"] -and $a.enabled -eq $false) { return }
        $list += $a
    }
    return ,$list
}

function Find-Agents {
    $found = @()
    foreach ($a in (Get-Adapters)) {
        foreach ($d in @($a.detect)) {
            if (Test-Path (Expand-Tilde $d)) { $found += $a; break }
        }
    }
    return ,$found
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# 无 BOM UTF-8 写入（PS5.1 的 Set-Content -Encoding UTF8 带 BOM，会破坏 JSON 配置被其他程序解析）
function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
}

# ---------- AGENTS.md 部署（managed section，幂等）----------
function Deploy-ManagedSection([string]$Content, [string]$Target, [string]$Tag = "") {
    $section = $BeginMark + "`r`n" + $Content + "`r`n" + $EndMark
    if (Test-Path $Target) {
        $raw = [System.IO.File]::ReadAllText($Target)
        if ($raw -match [regex]::Escape($BeginMark)) {
            # 替换标记间内容（保留标记外用户内容）
            $pattern = "(?s)(" + [regex]::Escape($BeginMark) + ").*?(" + [regex]::Escape($EndMark) + ")"
            $new = $raw -replace $pattern, ($BeginMark + "`r`n" + $Content + "`r`n" + $EndMark)
            Backup-File $Target $Tag
            Write-Utf8NoBom $Target $new
            return "updated"
        } else {
            Backup-File $Target $Tag
            Write-Utf8NoBom $Target ($raw + "`r`n" + $section)
            return "appended"
        }
    } else {
        $dir = Split-Path $Target -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Utf8NoBom $Target $section
        return "created"
    }
}

# ---------- MCP 配置合并（仅新增键，不覆盖用户已有）----------
function Merge-McpConfig([string]$TemplateFile, [string]$TargetPath, [string]$KeyPath, [string]$Requires, [string]$Tag = "") {
    if (-not (Test-Path $TemplateFile)) { return @{ added = @(); skipped = @(); note = "无模板" } }
    if ($Requires -and -not (Test-Command $Requires)) {
        return @{ added = @(); skipped = @(); note = "跳过：未检测到 $Requires（MCP 服务器运行需要它）" }
    }
    $tpl = Get-Content $TemplateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $tplServers = $tpl.servers
    if (-not $tplServers) { return @{ added = @(); skipped = @(); note = "模板无 servers" } }

    if (Test-Path $TargetPath) {
        Backup-File $TargetPath $Tag
        $cfg = Get-Content $TargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $cfg = New-Object PSObject
        $dir = Split-Path $TargetPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }

    # 按 key path（"mcpServers" 或 "mcp.servers"）定位容器
    $container = $null
    if ($KeyPath -eq "mcpServers") {
        if (-not $cfg.PSObject.Properties["mcpServers"]) {
            $cfg | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue (New-Object PSObject)
        }
        $container = $cfg.mcpServers
    }
    else {
        if (-not $cfg.PSObject.Properties["mcp"]) {
            $cfg | Add-Member -NotePropertyName "mcp" -NotePropertyValue (New-Object PSObject)
        }
        if (-not $cfg.mcp.PSObject.Properties["servers"]) {
            $cfg.mcp | Add-Member -NotePropertyName "servers" -NotePropertyValue (New-Object PSObject)
        }
        $container = $cfg.mcp.servers
    }

    $added = @(); $skipped = @()
    foreach ($p in @($tplServers.PSObject.Properties)) {
        if ($container.PSObject.Properties[$p.Name]) { $skipped += $p.Name }
        else {
            $container | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
            $added += $p.Name
        }
    }
    $cfg | ConvertTo-Json -Depth 32 | ForEach-Object { Write-Utf8NoBom $TargetPath $_ }
    return @{ added = $added; skipped = $skipped; note = "" }
}

# ---------- MCP TOML 托管块写入（Codex config.toml 用；标记间幂等替换）----------
$TomlBegin = "# >>> asp:mcp:begin >>>"
$TomlEnd   = "# <<< asp:mcp:end <<<"

function Merge-TomlManaged([string]$TemplateFile, [string]$TargetPath, [string]$Requires, [string]$Tag = "") {
    if (-not (Test-Path $TemplateFile)) { return @{ added = @(); skipped = @(); note = "无模板" } }
    if ($Requires -and -not (Test-Command $Requires)) {
        return @{ added = @(); skipped = @(); note = "跳过：未检测到 $Requires（MCP 服务器运行需要它）" }
    }
    $tplRaw = [System.IO.File]::ReadAllText($TemplateFile)
    # 从模板提取服务器名（仅用于报告）
    $names = @()
    foreach ($m in [regex]::Matches($tplRaw, "(?m)^\s*\[mcp_servers\.([A-Za-z0-9_\-]+)\]")) { $names += $m.Groups[1].Value }
    if ($names.Count -eq 0) { return @{ added = @(); skipped = @(); note = "模板无 [mcp_servers.*]" } }

    $block = $TomlBegin + "`r`n" + $tplRaw.TrimEnd() + "`r`n" + $TomlEnd
    if (Test-Path $TargetPath) {
        $raw = [System.IO.File]::ReadAllText($TargetPath)
        Backup-File $TargetPath $Tag
        if ($raw -match [regex]::Escape($TomlBegin)) {
            # 已存在托管块：检测已有服务器是否与模板重名（重名即用户/历史已配，整块替换为最新模板）
            $pattern = "(?s)(" + [regex]::Escape($TomlBegin) + ").*?(" + [regex]::Escape($TomlEnd) + ")"
            $new = $raw -replace $pattern, ($block -replace '\$', '$$')
            Write-Utf8NoBom $TargetPath $new
            return @{ added = @(); skipped = @(); note = ""; updated = $true }
        } else {
            Write-Utf8NoBom $TargetPath ($raw.TrimEnd() + "`r`n`r`n" + $block + "`r`n")
            return @{ added = $names; skipped = @(); note = "" }
        }
    } else {
        $dir = Split-Path $TargetPath -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Utf8NoBom $TargetPath ($block + "`r`n")
        return @{ added = $names; skipped = @(); note = "" }
    }
}

# ---------- 引导面板（未检测到任何 agent）----------
function Show-Guide {
    Write-Host ""
    Write-Host "  未检测到任何受支持的 AI agent。" -ForegroundColor Yellow
    Write-Host "  支持列表（安装任一后重新运行本包即可）：" -ForegroundColor Yellow
    Write-Host "    Claude Code     https://claude.com/product/claude-code"
    Write-Host "    Codex           https://developers.openai.com/codex/"
    Write-Host "    Cursor          https://cursor.com"
    Write-Host "    opencode        https://opencode.ai"
    Write-Host "    DeepSeek Harness  https://github.com/deepseek-ai/deepseek-harness"
    Write-Host "    Zcode           https://zcode.ai"
    Write-Host ""
}

# ---------- install ----------
function Invoke-Install([string]$PackName) {
    $packDir = Join-Path $Root ("packs/" + $PackName)
    if (-not (Test-Path $packDir)) {
        Write-Host ("[错误] 本快照中不存在包: {0}" -f $PackName) -ForegroundColor Red
        Write-Host "可用包:" (Get-ChildItem (Join-Path $Root "packs") -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
        exit 1
    }

    Write-Host "[探测] 扫描本机 AI agent..."
    $agents = Find-Agents
    if ($agents.Count -eq 0) { Show-Guide; exit 0 }

    Write-Host ("[探测] 发现 {0} 个: {1}" -f $agents.Count, (($agents | ForEach-Object name) -join "  "))
    $answer = Read-Host "[确认] 全部安装? (Y/n)"
    if ($answer -ne "" -and $answer.ToLower() -ne "y") {
        Write-Host "已取消。"
        exit 0
    }

    $report = @()
    foreach ($a in $agents) {
        Write-Host ""
        Write-Host ("==> 部署到 {0}" -f $a.name) -ForegroundColor Cyan

        # 1) skills
        $skillsSrc = Join-Path $packDir "skills"
        if (Test-Path $skillsSrc) {
            $dst = Expand-Tilde $a.skills_dir
            if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
            $skillDirs = Get-ChildItem $skillsSrc -Directory
            foreach ($s in $skillDirs) {
                Copy-Item $s.FullName (Join-Path $dst $s.Name) -Recurse -Force
            }
            Write-Host ("    skills: {0} 个 -> {1}" -f $skillDirs.Count, $dst)
            $report += ("{0}: skills x{1}" -f $a.name, $skillDirs.Count)
        }

        # 2) AGENTS.md（全局型；workspace 型在 asp agents 子命令处理）
        if ($a.instructions.mode -eq "managed-section" -and $a.instructions.target) {
            $agentsMd = Get-Content (Join-Path $packDir "AGENTS.md") -Raw -Encoding UTF8
            $r = Deploy-ManagedSection $agentsMd (Expand-Tilde $a.instructions.target) $a.id
            Write-Host ("    AGENTS.md -> {0} ({1})" -f $a.instructions.target, $r)
            $report += ("{0}: AGENTS.md {1}" -f $a.name, $r)
        } elseif ($a.instructions.mode -eq "workspace") {
            Write-Host ("    AGENTS.md: workspace 级，稍后运行 'asp.ps1 agents <项目目录>' 部署" -f $a.name)
        }

        # 3) MCP
        if ($a.mcp.strategy -eq "merge") {
            $tplFile = Join-Path $packDir ("mcp/" + $a.mcp.template)
            $r = Merge-McpConfig $tplFile (Expand-Tilde $a.mcp.target) $a.mcp.key $a.mcp.requires $a.id
            if ($r.added.Count -gt 0)     { Write-Host ("    MCP 新增: {0}" -f ($r.added -join ", ")) }
            if ($r.skipped.Count -gt 0)   { Write-Host ("    MCP 跳过(已存在): {0}" -f ($r.skipped -join ", ")) -ForegroundColor DarkGray }
            if ($r.note)                  { Write-Host ("    MCP {0}" -f $r.note) -ForegroundColor Yellow }
            $report += ("{0}: MCP +{1}" -f $a.name, $r.added.Count)
        } elseif ($a.mcp.strategy -eq "template-only") {
            Write-Host "    MCP: 该 agent 默认不启用 MCP，模板与启用步骤见包内 mcp/ 目录" -ForegroundColor DarkGray
        } elseif ($a.mcp.strategy -eq "toml-managed") {
            $tplFile = Join-Path $packDir ("mcp/" + $a.mcp.template)
            $r = Merge-TomlManaged $tplFile (Expand-Tilde $a.mcp.target) $a.mcp.requires $a.id
            if ($r.updated)               { Write-Host "    MCP 托管块已更新（模板内 asp-* 服务器）" }
            elseif ($r.added.Count -gt 0) { Write-Host ("    MCP 新增: {0}" -f ($r.added -join ", ")) }
            if ($r.note)                { Write-Host ("    MCP {0}" -f $r.note) -ForegroundColor Yellow }
            $report += ("{0}: MCP toml +{1}" -f $a.name, $r.added.Count)
        }
    }

    # 写状态
    $state = @{ pack = $PackName; version = "dev"; installed_at = (Get-Date -Format s); agents = ($agents | ForEach-Object id) }
    if (Test-Path $StateFile) {
        $old = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $state.version = if ($old.version) { $old.version } else { "dev" }
    }
    $state | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8

    Write-Host ""
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host " 安装完成" -ForegroundColor Green
    $report | ForEach-Object { Write-Host ("   " + $_) }
    Write-Host " 重启你的 agent 后生效。" -ForegroundColor Green
    Write-Host " 回滚: 所有被修改文件的备份在 _backup/" -ForegroundColor DarkGray
    Write-Host " 周更: 双击 update.bat（或 asp.ps1 update）" -ForegroundColor DarkGray
    Write-Host "=======================================" -ForegroundColor Green
}

# ---------- agents 子命令：部署 AGENTS.md 到项目目录 ----------
function Invoke-Agents([string]$PackName, [string]$Dir) {
    if (-not $PackName) { if (Test-Path $StateFile) { $PackName = (Get-Content $StateFile -Raw | ConvertFrom-Json).pack } else { $PackName = "ai-pm" } }
    if (-not $Dir) { $Dir = (Get-Location).Path }
    $packDir = Join-Path $Root ("packs/" + $PackName)
    $agentsMd = Get-Content (Join-Path $packDir "AGENTS.md") -Raw -Encoding UTF8
    foreach ($a in (Get-Adapters)) {
        if ($a.instructions.mode -eq "workspace") {
            $target = Join-Path $Dir $a.instructions.filename
            $r = Deploy-ManagedSection $agentsMd $target $PackName
            Write-Host ("{0}: {1} ({2})" -f $a.name, $target, $r)
        }
    }
}

# ---------- update ----------
function Invoke-Update([string]$PackName) {
    # 读 registry 本地缓存里的 mirrors（发布时写入）；dev 环境提示
    $regIndex = Join-Path $Root "registry/index.json"
    $mirrors = @()
    if (Test-Path $regIndex) {
        $idx = Get-Content $regIndex -Raw -Encoding UTF8 | ConvertFrom-Json
        $mirrors = @($idx.mirrors)
    }
    if ($mirrors.Count -eq 0 -or $mirrors[0] -like "*REPLACE*") {
        Write-Host "[提示] registry 托管地址尚未配置（OSS/GitHub Pages 开通后填入 registry/index.json 的 mirrors）。" -ForegroundColor Yellow
        Write-Host "        当前为开发快照，无需更新。" -ForegroundColor Yellow
        exit 0
    }
    # 双源 failover 拉 index.json
    $idx = $null
    foreach ($m in $mirrors) {
        try {
            Write-Host ("[更新] 尝试源: {0}" -f $m)
            $resp = Invoke-WebRequest -Uri ($m.TrimEnd('/') + "/index.json") -TimeoutSec 3 -UseBasicParsing
            $idx = $resp.Content | ConvertFrom-Json
            break
        } catch { Write-Host "  源不可达，切换下一个..." -ForegroundColor DarkGray }
    }
    if (-not $idx) { Write-Host "[错误] 所有更新源均不可达，请稍后重试。" -ForegroundColor Red; exit 1 }

    # 状态对比
    $localVer = "none"
    if (Test-Path $StateFile) { $localVer = (Get-Content $StateFile -Raw | ConvertFrom-Json).version }
    $remoteVer = $idx.packs.$PackName.version
    Write-Host ("[版本] 本地 {0} -> 远程 {1}" -f $localVer, $remoteVer)
    if ($localVer -eq $remoteVer) { Write-Host "已是最新。"; exit 0 }

    # 下载 zip + sha256 校验 + 解压替换（保留 _state/_backup）
    $zipRel = $idx.packs.$PackName.zip
    $zipUrl = ($idx.mirrors[0].TrimEnd('/') + "/" + $zipRel)
    $tmpZip = Join-Path $env:TEMP ("asp-" + [guid]::NewGuid().ToString("N") + ".zip")
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    $hash = (Get-FileHash $tmpZip -Algorithm SHA256).Hash.ToLower()
    if ($hash -ne $idx.packs.$PackName.sha256.ToLower()) {
        Write-Host "[错误] 哈希校验失败，已中止。" -ForegroundColor Red; exit 1
    }
    $staging = Join-Path $env:TEMP ("asp-staging-" + [guid]::NewGuid().ToString("N"))
    Expand-Archive -Path $tmpZip -DestinationPath $staging -Force
    # 覆盖 packs/、adapters/、asp.ps1（不碰 _state.json/_backup）
    foreach ($part in @("packs", "adapters")) {
        $src = Join-Path $staging $part
        if (Test-Path $src) {
            $dst = Join-Path $Root $part
            if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
            Copy-Item $src $dst -Recurse
        }
    }
    $newAsp = Join-Path $staging "asp.ps1"
    if (Test-Path $newAsp) { Copy-Item $newAsp (Join-Path $Root "asp.ps1") -Force }
    # 更新版本号
    $state = if (Test-Path $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { [PSObject]@{ pack = $PackName } }
    $state | Add-Member -NotePropertyName version -NotePropertyValue $remoteVer -Force
    $state | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
    Write-Host "[完成] 已更新到 $remoteVer，正在重新部署..." -ForegroundColor Green
    Invoke-Install $PackName
}

# ---------- 主分发 ----------
switch ($Command.ToLower()) {
    "install" { if (-not $Pack) { $Pack = "ai-pm" }; Invoke-Install $Pack }
    "update"  { if (-not $Pack) { if (Test-Path $StateFile) { $Pack = (Get-Content $StateFile -Raw | ConvertFrom-Json).pack } else { $Pack = "ai-pm" } }; Invoke-Update $Pack }
    "detect"  { $agents = Find-Agents; if ($agents.Count -eq 0) { Show-Guide } else { $agents | ForEach-Object { Write-Host ("  {0,-14} {1}" -f $_.name, $_.id) } } }
    "agents"  { Invoke-Agents $Pack $TargetDir }
    "status"  {
        if (Test-Path $StateFile) { Get-Content $StateFile -Raw -Encoding UTF8 }
        else { Write-Host "尚未安装任何包。" }
    }
    default   { Write-Host "用法: asp.ps1 [install|update|detect|agents|status] [pack]"; exit 1 }
}
