# =====================================================================
# asp.ps1 - AI 冷启动包 (Agent Starter Pack) 安装/更新器 + 环境迁移
# 用法:
#   asp.ps1 install [pack]     安装包到所有检测到的 agent（默认 ai-pm）
#   asp.ps1 update [pack]      从 registry 拉取并更新（默认全部已装包）
#   asp.ps1 detect             探测本机已安装的 agent
#   asp.ps1 agents [pack] [dir] 将包的 AGENTS.md 部署到项目目录（只给一个目录参数时自动识别，默认当前目录+已装包）
#   asp.ps1 status             查看已装状态
#   asp.ps1 doctor             MCP 流量灯体检：对已部署配置逐条做真实 initialize 握手（v0.7.0）
#   asp.ps1 export [-Out x]    收集本机全部 agent 环境 -> 迁移包（零依赖）
#   asp.ps1 migrate <包>       把迁移包还原到本机（merge 语义：只增改不删除）
# 设计约束: 零外部依赖（仅 Windows 自带 PowerShell 5.1+；tar.gz 还原用系统自带 tar）
# =====================================================================
param(
    [Parameter(Position=0)][string]$Command = "install",
    [Parameter(Position=1)][string]$Pack = "",
    [Parameter(Position=2)][string]$TargetDir = "",
    [string]$Out = "",
    [switch]$All,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$IncludeOversized,
    [string]$Repo = "",
    [string]$Branch = "env-sync"
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
        return @{ added = @(); skipped = @(); note = "跳过：未检测到 $Requires——MCP 增强（查文档/记忆/深度推理）暂不可用，skills 不受影响。解决：① 安装 Node.js（https://nodejs.org）后重跑安装；② 或把 agent 内嵌 runtime（如 Kimi 桌面版）加入 PATH 后重跑" }
    }
    $tpl = Get-Content $TemplateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    # 模板统一约定：{ servers: {...} } 包装（与目标容器布局无关，目标侧按 $KeyPath 定位）
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

    # 按 key path（"mcpServers" / "mcp.servers" / "mcp"）定位容器
    $container = $null
    if ($KeyPath -eq "mcpServers") {
        if (-not $cfg.PSObject.Properties["mcpServers"]) {
            $cfg | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue (New-Object PSObject)
        }
        $container = $cfg.mcpServers
    }
    elseif ($KeyPath -eq "mcp") {
        # opencode 布局：{ mcp: { NAME: {...} } }——容器就是 cfg.mcp 本身
        if (-not $cfg.PSObject.Properties["mcp"]) {
            $cfg | Add-Member -NotePropertyName "mcp" -NotePropertyValue (New-Object PSObject)
        }
        $container = $cfg.mcp
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
        return @{ added = @(); skipped = @(); note = "跳过：未检测到 $Requires——MCP 增强（查文档/记忆/深度推理）暂不可用，skills 不受影响。解决：① 安装 Node.js（https://nodejs.org）后重跑安装；② 或把 agent 内嵌 runtime（如 Kimi 桌面版）加入 PATH 后重跑" }
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

# ---------- doctor：MCP 流量灯体检（v0.7.0，ONBOARDING-V2 W2 v1 提前落地）----------
$DoctorTimeoutSec = 20

function ConvertTo-McpJsonText([string]$Text) {
    # 兼容纯 JSON 与 SSE 帧（data: {...}）
    if ($Text -match '(?m)^\s*data:\s*(\{.+\})\s*$') { return $Matches[1] }
    return $Text
}

function Test-McpRemote([string]$Url, $Headers) {
    # 返回 @{ ok; warn; detail }：401/403 归 WARN（端点可达、鉴权问题在客户端配置）
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $hdrs = @{ Accept = "application/json, text/event-stream" }
        if ($Headers) { foreach ($p in @($Headers.PSObject.Properties)) { $hdrs[$p.Name] = [string]$p.Value } }
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"asp-doctor","version":"0.7.0"}}}'
        $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $body -ContentType "application/json" -Headers $hdrs -TimeoutSec 10 -UseBasicParsing
        $json = (ConvertTo-McpJsonText $resp.Content) | ConvertFrom-Json
        if ($json.result -and $json.result.serverInfo) {
            return @{ ok = $true; warn = $false; detail = ("握手 OK · {0} {1}" -f $json.result.serverInfo.name, $json.result.serverInfo.version) }
        }
        return @{ ok = $false; warn = $false; detail = "响应无 serverInfo（非 MCP 端点?）" }
    } catch {
        $sc = $null
        try { $sc = [int]$_.Exception.Response.StatusCode } catch {}
        if ($sc -eq 401 -or $sc -eq 403) { return @{ ok = $false; warn = $true; detail = "端点可达但鉴权被拒（HTTP $sc）——检查 token/headers 配置" } }
        if ($sc -eq 405) { return Test-McpSse $Url $Headers }   # POST 被拒：可能是 SSE 端点，回退 GET 探测
        $msg = $_.Exception.Message
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
        return @{ ok = $false; warn = $false; detail = "HTTP 失败: $msg" }
    }
}

function Test-McpSse([string]$Url, $Headers) {
    # SSE 传输（GET + event-stream）：连接建立 + 流里出现事件即视为可达
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.Method = "GET"; $req.Timeout = 8000; $req.ReadWriteTimeout = 8000
        $req.Accept = "text/event-stream"
        if ($Headers) { foreach ($p in @($Headers.PSObject.Properties)) { $req.Headers[[string]$p.Name] = [string]$p.Value } }
        $resp = $req.GetResponse()
        # 有界读（流不断开，ReadToEnd 会永远阻塞）：最多读 8KB 判断是否出现事件
        $chunk = ""
        try {
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $buf = New-Object char[] 4096
            for ($i = 0; $i -lt 2; $i++) {
                $n = $reader.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $chunk += (-join $buf[0..($n - 1)])
                if ($chunk -match 'event:|data:') { break }
            }
        } catch {
            $resp.Close()
            return @{ ok = $false; warn = $true; detail = "SSE 已连上（HTTP 200）但 8s 内未读到事件帧" }
        }
        $resp.Close()
        if ($chunk -match 'event:|data:') { return @{ ok = $true; warn = $false; detail = "SSE 端点可达（event-stream 正常）" } }
        return @{ ok = $false; warn = $true; detail = "HTTP 200 但无事件流" }
    } catch {
        $sc = $null
        try { $sc = [int]$_.Exception.Response.StatusCode } catch {}
        if ($sc -eq 401 -or $sc -eq 403) { return @{ ok = $false; warn = $true; detail = "端点可达但鉴权被拒（HTTP $sc）——检查 token/headers 配置" } }
        $msg = $_.Exception.Message
        if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
        return @{ ok = $false; warn = $false; detail = "SSE 探测失败: $msg" }
    }
}

function Test-McpStdio([string]$Command, [string[]]$SArgs, [string]$Requires, $EnvObj) {
    if ($Requires -and -not (Test-Command $Requires)) { return @{ ok = $false; warn = $false; detail = "未检测到 $Requires（MCP 运行时缺失）" } }
    # 解析为绝对可执行路径。裸 npx 有两个坑：① cmd 下会用 CWD 相对路径找 npm 而崩溃；
    # ② PATH 里同名的无扩展名 bash 脚本会让 CreateProcess 报"非有效应用程序"——故按 PATHEXT 优先找 .cmd/.exe/.bat
    $resolved = $Command
    $hasExt = [System.IO.Path]::GetExtension($Command) -ne ""
    if (-not $hasExt) {
        foreach ($ext in @(".cmd", ".exe", ".bat")) {
            $g = Get-Command ($Command + $ext) -ErrorAction SilentlyContinue
            if ($g -and $g.Source) { $resolved = $g.Source; break }
        }
    } else {
        $g = Get-Command $Command -ErrorAction SilentlyContinue
        if ($g -and $g.Source) { $resolved = $g.Source }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $resolved
    $psi.Arguments = ($SArgs -join " ")
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    if ($EnvObj) { foreach ($p2 in @($EnvObj.PSObject.Properties)) { try { $psi.EnvironmentVariables[[string]$p2.Name] = [string]$p2.Value } catch {} } }
    $p = $null
    try { $p = [System.Diagnostics.Process]::Start($psi) }
    catch {
        return @{ ok = $false; warn = $false; detail = "无法启动: $resolved（$($_.Exception.Message)）" }
    }
    $outSb = New-Object System.Text.StringBuilder
    $errSb = New-Object System.Text.StringBuilder
    $subOut = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -MessageData $outSb -Action { if ($EventArgs.Data) { $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null } }
    $subErr = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -MessageData $errSb -Action { if ($EventArgs.Data) { $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null } }
    $p.BeginOutputReadLine(); $p.BeginErrorReadLine()
    # 像真实客户端一样写 initialize 并保持 stdin 打开——立即 EOF 会让 server 赶在写出响应前退出
    $p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"asp-doctor","version":"0.7.0"}}}')
    $p.StandardInput.Flush()
    $deadline = (Get-Date).AddSeconds($DoctorTimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200   # 泵事件，让 OutputDataReceived 进缓冲
        $cur = $outSb.ToString()
        if ($cur -match '"id"\s*:\s*1' -and $cur -match 'serverInfo') { break }
        if ($p.HasExited) { Start-Sleep -Milliseconds 300; break }
    }
    if (-not $p.HasExited) { try { & taskkill /PID $p.Id /T /F 2>&1 | Out-Null } catch { try { $p.Kill() } catch {} } }
    Start-Sleep -Milliseconds 200
    Unregister-Event -SubscriptionId $subOut.Id -ErrorAction SilentlyContinue
    Unregister-Event -SubscriptionId $subErr.Id -ErrorAction SilentlyContinue
    try {
        $json = (ConvertTo-McpJsonText $outSb.ToString()) | ConvertFrom-Json
        if ($json.result -and $json.result.serverInfo) {
            return @{ ok = $true; warn = $false; detail = ("握手 OK · {0} {1}" -f $json.result.serverInfo.name, $json.result.serverInfo.version) }
        }
    } catch { }
    # 错误行提取：优先含 Error 的行（比 stderr 末行的 Node 版本号/调用栈更有诊断价值）
    $errLines = @($errSb.ToString() -split "`r?`n" | Where-Object { $_ -match '\S' })
    $errPick = @($errLines | Where-Object { $_ -match 'Error|错误|找不到' } | Select-Object -Last 1)
    $tail = if ($errPick) { [string]$errPick[0] } elseif ($errLines) { [string]$errLines[-1] } else { "" }
    if ($tail.Length -gt 140) { $tail = $tail.Substring(0, 140) }
    return @{ ok = $false; warn = $false; detail = ("无 initialize 响应{0}" -f ($(if ($tail) { "：$tail" } else { "（stdout 空）" }))) }
}

function Get-DoctorEntries([object]$Adapter) {
    # 从已部署配置提取可测条目：@{ name; url; headers } 或 @{ name; command; args }
    $entries = @()
    $targetPath = Expand-Tilde $Adapter.mcp.target
    if (-not (Test-Path $targetPath)) { return $entries }
    if ($Adapter.mcp.strategy -eq "toml-managed") {
        $raw = [System.IO.File]::ReadAllText($targetPath)
        if ($raw -notmatch [regex]::Escape($TomlBegin)) { return $entries }
        $block = [regex]::Match($raw, "(?s)" + [regex]::Escape($TomlBegin) + "(.*?)" + [regex]::Escape($TomlEnd)).Groups[1].Value
        foreach ($m in [regex]::Matches($block, "(?ms)^\s*\[mcp_servers\.([A-Za-z0-9_\-]+)\]\s*command\s*=\s*`"([^`"]+)`"\s*args\s*=\s*\[([^\]]*)\]")) {
            $targs = @(); foreach ($am in [regex]::Matches($m.Groups[3].Value, "`"([^`"]+)`"")) { $targs += $am.Groups[1].Value }
            $entries += @{ name = $m.Groups[1].Value; command = $m.Groups[2].Value; args = $targs }
        }
        return $entries
    }
    try { $cfg = Get-Content $targetPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $entries }
    $container = $null
    if ($Adapter.mcp.key -eq "mcpServers")      { $container = $cfg.mcpServers }
    elseif ($Adapter.mcp.key -eq "mcp")         { $container = $cfg.mcp }
    elseif ($Adapter.mcp.key -eq "mcp.servers") { $container = $cfg.mcp.servers }
    if (-not $container) { return $entries }
    foreach ($p in @($container.PSObject.Properties)) {
        $e = $p.Value
        if ($e -isnot [PSCustomObject]) { continue }
        if ($e.PSObject.Properties["url"] -and $e.url) {
            $etype = ""; if ($e.PSObject.Properties["type"] -and $e.type) { $etype = [string]$e.type }
            $entries += @{ name = $p.Name; url = [string]$e.url; type = $etype; headers = $e.PSObject.Properties["headers"] }
        } elseif ($e.PSObject.Properties["command"] -and $e.command) {
            # opencode 等：command 为数组（[0]=可执行，其余=args）；Claude 风格：command 字符串 + args
            $cmdVal = $e.command
            if ($cmdVal -is [System.Array]) {
                if ($cmdVal.Count -eq 0) { continue }
                $eargs = @(); if ($cmdVal.Count -gt 1) { $eargs = @($cmdVal[1..($cmdVal.Count - 1)]) }
                $eenv = $null; if ($e.PSObject.Properties["env"] -and $e.env) { $eenv = $e.env }
                $entries += @{ name = $p.Name; command = [string]$cmdVal[0]; args = $eargs; env = $eenv }
            } else {
                $eargs = @(); if ($e.PSObject.Properties["args"] -and $e.args) { $eargs = @($e.args) }
                $eenv = $null; if ($e.PSObject.Properties["env"] -and $e.env) { $eenv = $e.env }
                $entries += @{ name = $p.Name; command = [string]$cmdVal; args = $eargs; env = $eenv }
            }
        }
    }
    return $entries
}

function Invoke-Doctor {
    Write-Host "[doctor] MCP 流量灯体检——对已部署配置逐条做真实 initialize 握手（实测才算绿）"
    $agents = Find-Agents
    if ($agents.Count -eq 0) { Show-Guide; exit 0 }
    Write-Host ("[doctor] 检测到 {0} 个 agent 配置面，开始体检..." -f $agents.Count)
    $pass = 0; $fail = 0; $skip = 0
    $rows = @()
    foreach ($a in $agents) {
        if (-not $a.mcp -or -not $a.mcp.target) { continue }
        $strategy = [string]$a.mcp.strategy
        if ($strategy -eq "none" -or $strategy -eq "template-only") { continue }
        if ($strategy -eq "manual") {
            $rows += [pscustomobject]@{ Agent = $a.name; Server = "-"; 结果 = "SKIP"; 说明 = "manual 端：在设置界面添加，见 README" }
            $skip++
            continue
        }
        $targetPath = Expand-Tilde $a.mcp.target
        if (-not (Test-Path $targetPath)) {
            $rows += [pscustomobject]@{ Agent = $a.name; Server = "-"; 结果 = "SKIP"; 说明 = "配置未部署（先运行 install）" }
            $skip++
            continue
        }
        $entries = Get-DoctorEntries $a
        if ($entries.Count -eq 0) {
            $rows += [pscustomobject]@{ Agent = $a.name; Server = "-"; 结果 = "SKIP"; 说明 = "配置中无可测条目" }
            $skip++
            continue
        }
        foreach ($e in $entries) {
            if ($e.url) {
                if ($e.type -eq "sse") { $r = Test-McpSse $e.url $e.headers }
                else { $r = Test-McpRemote $e.url $e.headers }
            }
            else { $r = Test-McpStdio $e.command @($e.args) ([string]$a.mcp.requires) $e.env }
            if ($r.ok) { $pass++; $mark = "PASS" } elseif ($r.warn) { $skip++; $mark = "WARN" } else { $fail++; $mark = "FAIL" }
            $rows += [pscustomobject]@{ Agent = $a.name; Server = $e.name; 结果 = $mark; 说明 = $r.detail }
        }
    }
    Write-Host ""
    $rows | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
    Write-Host ("[doctor 汇总] PASS {0} · FAIL {1} · SKIP {2}" -f $pass, $fail, $skip)
    if ($fail -gt 0) {
        Write-Host "存在 FAIL：配置写了 ≠ 能用。修复指引见 README『MCP 体检』与 packs/base/mcp/optional-mcp.md；npx 冷启动超时可重跑确认。" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "全绿 ✓（MCP 零报错率口径：PASS / (PASS+FAIL)）" -ForegroundColor Green
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
    Write-Host "    Trae            https://www.trae.ai"
    Write-Host "    Qoder           https://qoder.com"
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
    # 多包依赖链安装时只确认一次（v0.5.0 分层）
    if (-not $script:AspConfirmed) {
        $answer = Read-Host "[确认] 全部安装? (Y/n)"
        if ($null -ne $answer -and $answer -ne "" -and $answer.ToLower() -ne "y") {
            Write-Host "已取消。"
            exit 0
        }
        $script:AspConfirmed = $true
    }

    $report = @()
    foreach ($a in $agents) {
        Write-Host ""
        Write-Host ("==> 部署到 {0}" -f $a.name) -ForegroundColor Cyan

        # 1) skills（未声明 skills_dir 的 agent——如纯迁移适配器——跳过包安装）
        if (-not $a.skills_dir -and (-not $a.instructions.mode -or $a.instructions.mode -eq "none")) {
            Write-Host "    包安装未开放（该端当前仅支持环境迁移，见 UPDATES.md）——如需接入请提供真实布局" -ForegroundColor DarkGray
        }
        $skillsSrc = Join-Path $packDir "skills"
        if ($a.skills_dir -and (Test-Path $skillsSrc)) {
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
        } elseif ($a.instructions.mode -eq "cursor-rules" -and $a.instructions.target) {
            # Cursor 全局规则：包装为带 frontmatter 的 .mdc；frontmatter 在标记外，正文走 asp 托管段（幂等）
            $mdcTarget = Expand-Tilde $a.instructions.target
            $mdcFm = "---`r`ndescription: AI 冷启动包 - PM 工作流与知识基准（asp 托管段自动更新，勿在标记间手工修改）`r`nalwaysApply: true`r`n---"
            if (Test-Path $mdcTarget) {
                $r = Deploy-ManagedSection $agentsMd $mdcTarget $a.id
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path $mdcTarget) | Out-Null
                Write-Utf8NoBom $mdcTarget ($mdcFm + "`r`n`r`n" + $BeginMark + "`r`n" + $agentsMd + "`r`n" + $EndMark + "`r`n")
                $r = "created"
            }
            Write-Host ("    rules -> {0} ({1})" -f $a.instructions.target, $r)
            $report += ("{0}: rules {1}" -f $a.name, $r)
        }

        # 2.5) 探测诚实化（v0.7.0）：目录特征命中但可执行文件不在 PATH——可能是迁移残留而非真实安装
        if ($a.smoke -and $a.smoke.cmd) {
            $exe = ($a.smoke.cmd -split '\s+')[0]
            if ($exe -and -not (Test-Command $exe)) {
                Write-Host ("    ⚠ 未在 PATH 检测到 '{0}'——本机可能只有该 agent 的配置残留（如迁移恢复）而未真正安装；已按目录特征部署，真正安装后生效" -f $exe) -ForegroundColor Yellow
                $report += ("{0}: ⚠ 可执行文件未检出（疑似仅配置残留）" -f $a.name)
            }
        }

        # 3) MCP（专业包无 mcp 目录时跳过，MCP 归属 base 包）
        $hasMcp = Test-Path (Join-Path $packDir "mcp")
        if (($a.mcp.strategy -eq "merge" -or $a.mcp.strategy -eq "json-merge") -and $hasMcp) {
            # merge = Claude 风格 mcpServers / zcode mcp.servers；json-merge = opencode 风格 mcp 容器（Merge-McpConfig 按 key 分派）
            $tplFile = Join-Path $packDir ("mcp/" + $a.mcp.template)
            $r = Merge-McpConfig $tplFile (Expand-Tilde $a.mcp.target) $a.mcp.key $a.mcp.requires $a.id
            if ($r.added.Count -gt 0)     { Write-Host ("    MCP 新增: {0}" -f ($r.added -join ", ")) }
            if ($r.skipped.Count -gt 0)   { Write-Host ("    MCP 跳过(已存在): {0}" -f ($r.skipped -join ", ")) -ForegroundColor DarkGray }
            if ($r.note)                  { Write-Host ("    MCP {0}" -f $r.note) -ForegroundColor Yellow }
            $report += ("{0}: MCP +{1}" -f $a.name, $r.added.Count)
        } elseif ($a.mcp.strategy -eq "template-only") {
            Write-Host "    MCP: 该 agent 默认不启用 MCP，模板与启用步骤见包内 mcp/ 目录" -ForegroundColor DarkGray
        } elseif ($a.mcp.strategy -eq "manual") {
            # v0.7.0：该端配置文件不在其 MCP 加载面（实测证据见 adapter note）——不写配置，给出手动路径
            Write-Host "    MCP: 该端需在设置界面手动添加（配置文件不在加载面）——context7 远程端点: https://mcp.context7.com/mcp" -ForegroundColor DarkGray
            $report += ("{0}: MCP manual（设置界面添加）" -f $a.name)
        } elseif ($a.mcp.strategy -eq "toml-managed" -and $hasMcp) {
            $tplFile = Join-Path $packDir ("mcp/" + $a.mcp.template)
            $r = Merge-TomlManaged $tplFile (Expand-Tilde $a.mcp.target) $a.mcp.requires $a.id
            if ($r.updated)               { Write-Host "    MCP 托管块已更新（模板内 asp-* 服务器）" }
            elseif ($r.added.Count -gt 0) { Write-Host ("    MCP 新增: {0}" -f ($r.added -join ", ")) }
            if ($r.note)                { Write-Host ("    MCP {0}" -f $r.note) -ForegroundColor Yellow }
            $report += ("{0}: MCP toml +{1}" -f $a.name, $r.added.Count)
        }
    }

    # 写状态（v0.5.0：packs 记录为数组，依赖链多次安装累加）
    if (Test-Path $StateFile) {
        $old = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $packs = @($old.packs)
        if ($packs -notcontains $PackName) { $packs += $PackName }
        $state = @{ packs = $packs; pack = $PackName; version = if ($old.version) { $old.version } else { "dev" }; installed_at = (Get-Date -Format s); agents = ($agents | ForEach-Object id) }
    } else {
        $state = @{ packs = @($PackName); pack = $PackName; version = "dev"; installed_at = (Get-Date -Format s); agents = ($agents | ForEach-Object id) }
    }
    $state | ConvertTo-Json | ForEach-Object { Write-Utf8NoBom $StateFile $_ }

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
    # 兼容两种调用：`agents <dir>`（目录参数自动识别）与 `agents <pack> <dir>`
    if ($PackName -and (Test-Path $PackName -PathType Container)) { $Dir = $PackName; $PackName = "" }
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
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $resp = Invoke-WebRequest -Uri ($m.TrimEnd('/') + "/index.json") -TimeoutSec 10 -UseBasicParsing
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
    Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -TimeoutSec 60 -UseBasicParsing
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

# ---------- 包依赖解析（v0.5.0 分层：专业包依赖 base）----------
function Resolve-PackDeps([string]$PackName) {
    # 返回安装顺序列表：依赖在前，目标在后
    $depsFile = Join-Path $Root ("packs/" + $PackName + "/deps.json")
    $chain = @()
    if (Test-Path $depsFile) {
        $deps = (Get-Content $depsFile -Raw -Encoding UTF8 | ConvertFrom-Json).requires
        foreach ($d in @($deps)) { $chain += $d }
    }
    $chain += $PackName
    return ,$chain
}

# ---------- 环境迁移（v0.6.0）：export / migrate ----------
$MigToolVersion = "0.6.0"
$script:DefaultMaxMB = 20   # 单项 ≤20MB 默认同步；超出列为可选项，还原前由用户勾选

# adapter 未覆盖的额外资产（记忆/工作区文件等）
function Get-MigrateExtras([string]$AgentId) {
    switch ($AgentId) {
        "zcode" { return @("~/.zcode/cli/memories") }
        "kimi"  { return @("~/.kimi_openclaw/workspace/AGENTS.md") }
        default { return @() }
    }
}

function Add-MigCandidate($Items, [string]$AgentId, [string]$Kind, [string]$TildePath) {
    if (Test-Path (Expand-Tilde $TildePath)) { $Items.Add(@{ agent = $AgentId; type = $Kind; rel = ($TildePath -replace '^~/','') }) }
}

# 收集候选 = adapter 已知路径（skills/全局指令/MCP）+ 额外资产 + adapter 显式声明的 migrate.files/dirs
# （"auto" 在复制时按实际类型解析；计数与 sha 在复制后从包内取，避免二次扫描）
function Get-MigrateCandidates($a) {
    $items = New-Object 'System.Collections.Generic.List[object]'
    if ($a.skills_dir) { Add-MigCandidate $items $a.id "dir" $a.skills_dir }
    if ($a.instructions.mode -eq "managed-section" -and $a.instructions.target) { Add-MigCandidate $items $a.id "file" $a.instructions.target }
    if ($a.mcp.target -and $a.mcp.strategy -ne "none" -and $a.mcp.strategy -ne "template-only") { Add-MigCandidate $items $a.id "file" $a.mcp.target }
    foreach ($x in (Get-MigrateExtras $a.id)) { Add-MigCandidate $items $a.id "auto" $x }
    if ($a.migrate) {
        foreach ($f in @($a.migrate.files)) { if ($f) { Add-MigCandidate $items $a.id "file" $f } }
        foreach ($d in @($a.migrate.dirs))  { if ($d) { Add-MigCandidate $items $a.id "dir"  $d } }
    }
    return $items
}

function Invoke-Export([string]$Out) {
    $agents = Find-Agents
    if ($agents.Count -eq 0) { Show-Guide; exit 0 }
    Write-Host ("[探测] 发现 {0} 个: {1}" -f $agents.Count, (($agents | ForEach-Object name) -join "  "))

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $staging = Join-Path $env:TEMP ("asp-mig-" + [guid]::NewGuid().ToString("N"))
    $homeDir = Join-Path $staging "home"
    New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
    $manifestItems = @()
    foreach ($a in $agents) {
        $cands = Get-MigrateCandidates $a
        if ($cands.Count -eq 0) { Write-Host ("  {0}: 无可收集资产" -f $a.name) -ForegroundColor DarkGray; continue }
        foreach ($c in $cands) {
            $src = Expand-Tilde ("~/" + $c.rel)
            $dst = Join-Path $homeDir $c.rel
            $dstParent = Split-Path $dst -Parent
            if (-not (Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }
            if ($c.type -eq "file" -or (Test-Path $src -PathType Leaf)) {
                Copy-Item $src $dst -Force
                $manifestItems += @{ agent = $c.agent; type = "file"; rel = $c.rel; sha256 = (Get-FileHash $dst -Algorithm SHA256).Hash.ToLower(); bytes = (Get-Item $dst).Length }
                Write-Host ("  {0}: file  {1}" -f $c.agent, $c.rel)
            } else {
                # 目录：逐个一级子项（单 skill 粒度）处理——默认只收 ≤20MB 的子项；超大项列出供用户勾选
                $oversized = New-Object 'System.Collections.Generic.List[object]'
                foreach ($child in (Get-ChildItem $src -Force)) {
                    $childRel = ($c.rel.TrimEnd('/')) + "/" + $child.Name
                    $dstChild = Join-Path $dst $child.Name
                    if ($child.PSIsContainer) {
                        if (Test-Command robocopy) { & robocopy $child.FullName $dstChild /E /XJ /XD ".git" "node_modules" "__pycache__" ".venv" "venv" ".cache" ".pytest_cache" /XF "*.pyc" /NFL /NDL /NJH /NJS /NP | Out-Null }
                        else { Copy-Item $child.FullName $dstChild -Recurse -Force }
                        $cn = (Get-ChildItem $dstChild -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object).Count
                        if ($cn -eq 0) { Remove-Item $dstChild -Recurse -Force -ErrorAction SilentlyContinue; continue }
                        $cb = [long]((Get-ChildItem $dstChild -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)
                        if ($cb -gt 20MB) { Remove-Item $dstChild -Recurse -Force; $oversized.Add(@{ agent = $c.agent; rel = $childRel; files = $cn; bytes = $cb }); continue }
                        $manifestItems += @{ agent = $c.agent; type = "dir"; rel = $childRel; files = $cn; bytes = $cb }
                    } else {
                        Copy-Item $child.FullName $dstChild -Force
                        $manifestItems += @{ agent = $c.agent; type = "file"; rel = $childRel; sha256 = (Get-FileHash $dstChild -Algorithm SHA256).Hash.ToLower(); bytes = $child.Length }
                    }
                }
                # 超大子项（>20MB）：列出并让用户选择是否纳入包
                if ($oversized.Count -gt 0) {
                    Write-Host ("  {0}: 超大项 {1} 个（默认不入包）:" -f $c.agent, $oversized.Count) -ForegroundColor Yellow
                    for ($i = 0; $i -lt $oversized.Count; $i++) { Write-Host ("    {0}. {1}  {2} MB / {3} 文件" -f ($i + 1), $oversized[$i].rel, [math]::Round($oversized[$i].bytes / 1MB, 1), $oversized[$i].files) }
                    $picks = @()
                    if ($IncludeOversized) { $picks = 0..($oversized.Count - 1) }
                    elseif (-not $Yes) {
                        $ans = Read-Host "[选择] 包含哪些超大项? 回车=都不含，或编号如 1,2"
                        if ($ans -and $ans.Trim() -ne "") { foreach ($tok in $ans.Split(',')) { $t = $tok.Trim(); if ($t -match '^\d+$' -and [int]$t -ge 1 -and [int]$t -le $oversized.Count) { $picks += ([int]$t - 1) } } }
                    }
                    foreach ($pi in $picks) {
                        $o = $oversized[$pi]; $dstChild = Join-Path $dst (($o.rel.Substring($c.rel.Length)).TrimStart('/'))
                        if (Test-Command robocopy) { & robocopy (Expand-Tilde ("~/" + $o.rel)) $dstChild /E /XJ /XD ".git" "node_modules" "__pycache__" ".venv" "venv" ".cache" ".pytest_cache" /XF "*.pyc" /NFL /NDL /NJH /NJS /NP | Out-Null }
                        else { Copy-Item (Expand-Tilde ("~/" + $o.rel)) $dstChild -Recurse -Force }
                        $manifestItems += @{ agent = $o.agent; type = "dir"; rel = $o.rel; files = $o.files; bytes = $o.bytes; optional = $true }
                        Write-Host ("  {0}: 已含超大项  {1}" -f $o.agent, $o.rel) -ForegroundColor Yellow
                    }
                }
            }
        }
    }
    if ($manifestItems.Count -eq 0) { Write-Host "[提示] 未收集到任何可迁移文件。"; exit 0 }

    $manifest = @{
        tool = "asp"; tool_version = $MigToolVersion; kind = "asp-env-migration"
        created_at = (Get-Date -Format s)
        host = @{ os = "windows"; user = $env:USERNAME }
        agents = @($agents | ForEach-Object id)
        items = $manifestItems
        note = "merge 语义：还原只增改不删除；包内 MCP 配置可能含 API key，请妥善保管"
    }
    Write-Utf8NoBom (Join-Path $staging "manifest.json") ($manifest | ConvertTo-Json -Depth 8)
    Write-Utf8NoBom (Join-Path $staging "README-MIGRATE.txt") ("asp 环境迁移包（生成于 $(Get-Date -Format s)）`r`n还原：把 asp 目录复制到新机器后运行  powershell -File asp.ps1 migrate <本包路径>`r`n注意：包内 MCP 配置可能含 API key，请妥善保管；还原为 merge 语义（不删除目标已有文件）。")

    $outFile = if ($Out) { $Out } else { Join-Path $env:TEMP ("asp-env-" + $stamp + ".zip") }
    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $outFile -Force

    # ---- GitHub 通道（-Repo）：包进私有仓库的 env 分支，新机器零 U 盘直接还原 ----
    if ($Repo) {
        if (-not (Test-Command git)) { Write-Host "[错误] -Repo 需要 git（未检测到）。先装 git，或去掉 -Repo 用本地包。" -ForegroundColor Red; Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
        $repoDir = Join-Path $env:TEMP ("asp-remote-" + [guid]::NewGuid().ToString("N"))
        & git clone --depth 1 $Repo $repoDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "[错误] git clone 失败——先去 GitHub 建一个 PRIVATE 仓库，并确认本机有推送权限。" -ForegroundColor Red; Remove-Item $staging, $repoDir -Recurse -Force -ErrorAction SilentlyContinue; exit 1 }
        Push-Location $repoDir
        & git checkout -B $Branch 2>&1 | Out-Null
        $migDir = Join-Path $repoDir "env"
        if (Test-Path $migDir) { Remove-Item $migDir -Recurse -Force }
        New-Item -ItemType Directory -Path $migDir -Force | Out-Null
        Copy-Item $outFile (Join-Path $migDir "env.zip") -Force
        Write-Utf8NoBom (Join-Path $migDir "LATEST.txt") ("package=env.zip`r`nexported_at=" + (Get-Date -Format s) + "`r`nsource_host=" + $env:COMPUTERNAME + "\" + $env:USERNAME)
        & git add -A
        & git -c user.name="asp-env-sync" -c user.email="asp@local" commit -m "env sync $stamp" 2>&1 | Out-Null
        & git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        $pushOk = ($LASTEXITCODE -eq 0)
        Pop-Location
        Remove-Item $staging, $repoDir -Recurse -Force -ErrorAction SilentlyContinue
        if ($pushOk) {
            Write-Host ""
            Write-Host ("[完成] 环境已推送到 {0}（分支 {1}，env/env.zip）" -f $Repo, $Branch) -ForegroundColor Green
            Write-Host "  新机器三步:" -ForegroundColor Green
            Write-Host ("    ① git clone {0}" -f $Repo) -ForegroundColor Green
            Write-Host "    ② 进入目录: asp.ps1 install        （装 asp 运行环境本身）" -ForegroundColor Green
            Write-Host ("    ③ asp.ps1 migrate env -Yes         （从 env/ 一键还原全部环境）") -ForegroundColor Green
            Write-Host "  ⚠ 必须是 PRIVATE 仓库——包内 MCP 配置可能含 API key，公开=泄露。" -ForegroundColor Yellow
        } else {
            Write-Host "[错误] git push 失败——本地包保留在: $outFile（可手动推或 U 盘带过去）" -ForegroundColor Red
        }
        return
    }

    Remove-Item $staging -Recurse -Force
    Write-Host ""
    Write-Host ("[完成] 迁移包: {0}" -f $outFile) -ForegroundColor Green
    Write-Host "  还原: 新机器 asp 目录下运行  asp.ps1 migrate <本包路径>" -ForegroundColor Green
    Write-Host "  ⚠ 包内可能含 API key（MCP 配置），请妥善保管。" -ForegroundColor Yellow
}

function Invoke-Migrate([string]$PkgPath, [bool]$AllAgents, [bool]$DryRun) {
    # 快捷方式：`migrate env` = 用本仓库 env/ 分支的最新环境包（含拉取）
    $pkgIsRepoShortcut = ($PkgPath -eq "env")
    if ($pkgIsRepoShortcut) {
        $envDir = Join-Path $Root "env"
        if (Test-Command git) {
            Write-Host "[拉取] git pull 更新 env/（分支 env-sync）..."
            & git fetch origin env-sync 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { & git checkout -q env-sync 2>&1 | Out-Null; & git pull -q origin env-sync 2>&1 | Out-Null }
        }
        $PkgPath = Join-Path $envDir "env.zip"
        if (-not (Test-Path $PkgPath)) { Write-Host "[错误] $PkgPath 不存在——旧机器还没推送过环境（asp.ps1 export -Repo <url>），或没切到 env-sync 分支。" -ForegroundColor Red; exit 1 }
    }
    elseif ($PkgPath -match '^(https?://|git@)') {
        # 直接给了仓库 URL：浅克隆取包
        if (-not (Test-Command git)) { Write-Host "[错误] URL 方式需要 git。" -ForegroundColor Red; exit 1 }
        $repoDir = Join-Path $env:TEMP ("asp-remote-" + [guid]::NewGuid().ToString("N"))
        & git clone --depth 1 --branch $Branch $PkgPath $repoDir 2>&1 | Out-Null
        if (-not (Test-Path (Join-Path $repoDir "env\env.zip"))) { & git clone --depth 1 $PkgPath $repoDir 2>&1 | Out-Null }
        $p = Join-Path $repoDir "env\env.zip"
        if (-not (Test-Path $p)) { Write-Host "[错误] 仓库里没有 env/env.zip（旧机器未推送过？）" -ForegroundColor Red; exit 1 }
        $PkgPath = $p
    }
    if (-not $PkgPath -or -not (Test-Path $PkgPath)) { Write-Host "[错误] 找不到: $PkgPath" -ForegroundColor Red; exit 1 }
    $staging = Join-Path $env:TEMP ("asp-mig-" + [guid]::NewGuid().ToString("N"))
    if (Test-Path $PkgPath -PathType Container) { Copy-Item $PkgPath $staging -Recurse -Force }
    elseif ($PkgPath -like "*.zip") { Expand-Archive -Path $PkgPath -DestinationPath $staging -Force }
    elseif ($PkgPath -like "*.tar.gz" -or $PkgPath -like "*.tgz") { New-Item -ItemType Directory -Path $staging -Force | Out-Null; & tar -xzf $PkgPath -C $staging }
    else { Write-Host "[错误] 仅支持 zip / tar.gz / 已解压目录" -ForegroundColor Red; exit 1 }
    $mfPath = Join-Path $staging "manifest.json"
    if (-not (Test-Path $mfPath)) { Write-Host "[错误] 包内缺少 manifest.json（不是 asp 迁移包？）" -ForegroundColor Red; exit 1 }
    $mf = Get-Content $mfPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host ("[包] {0} v{1} · {2} · {3} 项" -f $mf.tool, $mf.tool_version, $mf.created_at, @($mf.items).Count)

    # ---- ① 自动检测本机 agent，选择导入哪些客户端 ----
    $detected = Find-Agents
    if ($detected.Count -eq 0) { Show-Guide; exit 0 }
    Write-Host ("[检测] 本机已装: {0}" -f (($detected | ForEach-Object name) -join "  "))
    $detectedIds = @($detected | ForEach-Object id)
    $selected = @()
    if ($AllAgents) { $selected = @($mf.agents) }
    elseif ($Yes) { $selected = $detectedIds }
    else {
        for ($i = 0; $i -lt $detected.Count; $i++) { Write-Host ("  {0}. {1} ({2})" -f ($i + 1), $detected[$i].name, $detected[$i].id) }
        $undetected = @(@($mf.agents) | Where-Object { $detectedIds -notcontains $_ })
        if ($undetected.Count -gt 0) { Write-Host ("  （包中还有本机未装的: {0}——装好后重跑 migrate 可还原）" -f ($undetected -join ", ")) -ForegroundColor DarkGray }
        $ans = Read-Host "[选择] 导入哪些客户端? 回车=全部已检测，或编号如 1,3"
        if (-not $ans -or $ans.Trim() -eq "") { $selected = $detectedIds }
        else {
            foreach ($tok in $ans.Split(',')) {
                $tok = $tok.Trim()
                if ($tok -match '^\d+$' -and [int]$tok -ge 1 -and [int]$tok -le $detected.Count) { $selected += $detectedIds[[int]$tok - 1] }
                elseif ($detectedIds -contains $tok) { $selected += $tok }
            }
            $selected = @($selected | Select-Object -Unique)
            if ($selected.Count -eq 0) { Write-Host "未选择任何客户端，退出。"; exit 0 }
        }
    }

    # ---- ② 体积分级：单项 ≤20MB 默认同步；超大项列为可选项由用户勾选 ----
    $default = @(); $optional = @()
    foreach ($it in @($mf.items)) {
        if ($selected -notcontains $it.agent) { continue }
        $mb = if ($it.bytes) { [math]::Round($it.bytes / 1MB, 1) } else { 0 }
        if ($mb -le $script:DefaultMaxMB) { $default += $it } else { $optional += @{ item = $it; mb = $mb } }
    }
    Write-Host ("[分级] 默认同步 {0} 项（≤{1} MB/项）" -f $default.Count, $script:DefaultMaxMB)
    $optPick = @()
    if ($optional.Count -gt 0) {
        Write-Host ("[分级] 超大项 {0} 个（默认不同步）:" -f $optional.Count) -ForegroundColor Yellow
        for ($i = 0; $i -lt $optional.Count; $i++) { Write-Host ("  {0}. [{1}] {2}  {3} MB" -f ($i + 1), $optional[$i].item.agent, $optional[$i].item.rel, $optional[$i].mb) }
        if (-not $DryRun) {
            $ans = Read-Host "[选择] 包含哪些超大项? 回车=都不含，或编号如 1,2"
            if ($ans -and $ans.Trim() -ne "") { foreach ($tok in $ans.Split(',')) { $t = $tok.Trim(); if ($t -match '^\d+$' -and [int]$t -ge 1 -and [int]$t -le $optional.Count) { $optPick += ([int]$t - 1) } } }
        } else { Write-Host "  （DryRun：超大项按未包含评估）" -ForegroundColor DarkGray }
    }
    $chosen = @($default); foreach ($oi in $optPick) { $chosen += $optional[$oi].item }

    # ---- ③ 展开文件任务并确认 ----
    $homeDir = Join-Path $staging "home"
    $tasks = New-Object 'System.Collections.Generic.List[object]'
    foreach ($it in $chosen) {
        $src = Join-Path $homeDir $it.rel
        if ($it.type -eq "file") { $tasks.Add(@{ agent = $it.agent; src = $src; dst = (Join-Path $Home $it.rel); sha = $it.sha256 }) }
        else {
            foreach ($f in (Get-ChildItem $src -Recurse -File -Force)) {
                $relSub = $f.FullName.Substring($src.Length).TrimStart('\', '/')
                $tasks.Add(@{ agent = $it.agent; src = $f.FullName; dst = (Join-Path (Join-Path $Home $it.rel) $relSub); sha = $null })
            }
        }
    }
    Write-Host ("[计划] {0} 个文件任务$(if ($DryRun) { '（DryRun：不写入）' })" -f $tasks.Count)
    if ($tasks.Count -gt 0 -and -not $Yes -and -not $DryRun) {
        $ans = Read-Host "[确认] 执行还原? (Y/n)"
        if ($null -ne $ans -and $ans -ne "" -and $ans.ToLower() -ne "y") { Write-Host "已取消。"; exit 0 }
    }

    $created = 0; $updated = 0; $identical = 0; $skipped = 0
    $copied = New-Object 'System.Collections.Generic.List[object]'
    foreach ($t in $tasks) {
        $relDisp = $t.dst.Substring($Home.Length).TrimStart('\', '/')
        if (-not $AllAgents -and ($detectedIds -notcontains $t.agent)) { $skipped++; Write-Host ("  [跳过] {0}（{1} 本机未装）" -f $relDisp, $t.agent) -ForegroundColor DarkGray; continue }
        if (Test-Path $t.dst -PathType Leaf) {
            $dstHash = (Get-FileHash $t.dst -Algorithm SHA256).Hash.ToLower()
            $srcHash = if ($t.sha) { $t.sha } else { (Get-FileHash $t.src -Algorithm SHA256).Hash.ToLower() }
            if ($dstHash -eq $srcHash) { $identical++; Write-Host ("  [一致] {0}" -f $relDisp) -ForegroundColor DarkGray; continue }
            if (-not $DryRun) { Backup-File $t.dst $t.agent; Copy-Item $t.src $t.dst -Force }
            $updated++; $copied.Add(@{ src = $t.src; dst = $t.dst; rel = $relDisp }); Write-Host ("  [更新] {0}" -f $relDisp)
        } else {
            if (-not $DryRun) { $dstParent = Split-Path $t.dst -Parent; if (-not (Test-Path $dstParent)) { New-Item -ItemType Directory -Path $dstParent -Force | Out-Null }; Copy-Item $t.src $t.dst -Force }
            $created++; $copied.Add(@{ src = $t.src; dst = $t.dst; rel = $relDisp }); Write-Host ("  [新增] {0}" -f $relDisp)
        }
    }

    # ---- ④ 验证导入结果（对本次写入的文件逐一回读哈希比对）----
    $verifyOk = 0; $verifyBad = @()
    if (-not $DryRun) {
        foreach ($v in $copied) {
            $s = (Get-FileHash $v.src -Algorithm SHA256).Hash.ToLower()
            $d = (Get-FileHash $v.dst -Algorithm SHA256).Hash.ToLower()
            if ($s -eq $d) { $verifyOk++ } else { $verifyBad += $v.rel }
        }
    }
    Write-Host ""
    Write-Host ("[汇总] 新增 {0} · 更新 {1} · 一致跳过 {2} · 跳过 {3}" -f $created, $updated, $identical, $skipped) -ForegroundColor Green
    if (-not $DryRun) {
        if ($copied.Count -eq 0) { Write-Host "[验证] 无新写入文件，无需校验。" -ForegroundColor DarkGray }
        elseif ($verifyBad.Count -eq 0) { Write-Host ("[验证] {0}/{0} 文件哈希一致 ✓" -f $verifyOk) -ForegroundColor Green }
        else { Write-Host ("[验证] {0}/{1} 一致，以下不一致:" -f $verifyOk, ($verifyOk + $verifyBad.Count)) -ForegroundColor Red; $verifyBad | ForEach-Object { Write-Host ("    " + $_) -ForegroundColor Red } }
        Write-Host "还原完成。重启你的 agent 生效；被替换文件的备份在 _backup/。" -ForegroundColor Green
    }
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- 主分发 ----------
switch ($Command.ToLower()) {
    "install" {
        if (-not $Pack) { $Pack = "base" }
        $chain = Resolve-PackDeps $Pack
        if ($chain.Count -gt 1) {
            Write-Host ("[分层] {0} 包含基础包，将一并安装: {1}" -f $Pack, ($chain -join " -> ")) -ForegroundColor Cyan
        }
        foreach ($p in $chain) { Invoke-Install $p }
    }
    "update"  {
        if (-not $Pack) {
            if (Test-Path $StateFile) { $Pack = (Get-Content $StateFile -Raw | ConvertFrom-Json).pack } else { $Pack = "base" }
        }
        $chain = Resolve-PackDeps $Pack
        foreach ($p in $chain) { Invoke-Update $p }
    }
    "detect"  { $agents = Find-Agents; if ($agents.Count -eq 0) { Show-Guide } else { $agents | ForEach-Object { Write-Host ("  {0,-14} {1}" -f $_.name, $_.id) } } }
    "agents"  { Invoke-Agents $Pack $TargetDir }
    "list"    {
        Write-Host "可用包:"
        Get-ChildItem (Join-Path $Root "packs") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $n = (Get-ChildItem (Join-Path $_.FullName "skills") -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host ("  {0,-8} {1,3} skills" -f $_.Name, $n)
        }
    }
    "status"  {
        if (Test-Path $StateFile) { Get-Content $StateFile -Raw -Encoding UTF8 }
        else { Write-Host "尚未安装任何包。" }
    }
    "doctor"  { Invoke-Doctor }
    "export"  { Invoke-Export $Out }
    "migrate" { Invoke-Migrate $Pack $All.IsPresent $DryRun.IsPresent }
    default   { Write-Host "用法: asp.ps1 [install|update|detect|agents|list|status|doctor|export|migrate] [pack]"; exit 1 }
}
