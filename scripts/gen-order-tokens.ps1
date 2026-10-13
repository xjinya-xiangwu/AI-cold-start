# =====================================================================
# gen-order-tokens.ps1 - D13 v2 订单通道：按订单表生成/上传/撤销 token 安装脚本
# 用法:
#   .\gen-order-tokens.ps1                     # 按 registry/orders.csv 生成并上传全部
#   .\gen-order-tokens.ps1 -Only <token>       # 只处理一个订单（换签/重发）
#   .\gen-order-tokens.ps1 -Revoke <token>     # 撤销订单（删除 i/<token>.*，买家命令即失效）
# 环境变量: ASP_OSS_AK / ASP_OSS_SK（RAM 子用户，只授 OSS；凭据不落盘不进源码）
# 机制: 纯静态方案——买家命令 irm <oss>/i/<token>.ps1 | iex 拉取的 bootstrap 内嵌
#   本周 presigned URL（7 天 TTL）；每周重跑本脚本即完成"周签"，买家重跑同一条命令即更新。
# =====================================================================
param(
    [string]$OrdersCsv = "",
    [string]$Bucket = "asp-registry-xjinya",
    [string]$Endpoint = "oss-cn-hangzhou.aliyuncs.com",
    [int]$TtlDays = 3,
    [string]$Only = "",
    [string]$Revoke = "",
    [switch]$ResignAll,
    # 单订单模式（云端自动化）：传 -Sku 即走，不读 orders.csv；算法生成 token 并写订单日志到 OSS 私有前缀
    [string]$Sku = "",
    [string]$OrderRef = "",
    [string]$Note = ""
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
$Root = (Resolve-Path "$PSScriptRoot/..").Path

if (-not $env:ASP_OSS_AK -or -not $env:ASP_OSS_SK) {
    Write-Host "[错误] 缺少环境变量 ASP_OSS_AK / ASP_OSS_SK（RAM 子用户密钥，勿写入任何入库文件）" -ForegroundColor Red; exit 1
}
$AK = $env:ASP_OSS_AK; $SK = $env:ASP_OSS_SK
$TokenBaseUrl = "https://{0}.{1}/i" -f $Bucket, $Endpoint
# L2 更新触达（默认关）：enable/disable 每周自动更新静态 bat（PowerShell Register-ScheduledTask 实现，
# 规避 schtasks /TR 嵌套引号与本机策略差异；bat 为 UTF-8+chcp65001，以 base64 注入 bootstrap 免多层转义）
$script:EnB64 = "QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnBvd2Vyc2hlbGwgLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiJGEgPSBOZXctU2NoZWR1bGVkVGFza0FjdGlvbiAtRXhlY3V0ZSAnJVVTRVJQUk9GSUxFJVxhc3AtY29sZHN0YXJ0XHVwZGF0ZS10b2tlbi5iYXQnOyAkdCA9IE5ldy1TY2hlZHVsZWRUYXNrVHJpZ2dlciAtV2Vla2x5IC1EYXlzT2ZXZWVrIFN1bmRheSAtQXQgMTA6MDA7IFJlZ2lzdGVyLVNjaGVkdWxlZFRhc2sgLVRhc2tOYW1lICdhc3AtY29sZHN0YXJ0LXdlZWtseScgLUFjdGlvbiAkYSAtVHJpZ2dlciAkdCAtRm9yY2UgfCBPdXQtTnVsbDsgaWYgKCQ/KSB7IFdyaXRlLUhvc3QgJ+W3suW8gOWQr+avj+WRqOiHquWKqOabtOaWsDog5q+P5ZGo5pelIDEwOjAwJyB9IGVsc2UgeyBXcml0ZS1Ib3N0ICfms6jlhozlpLHotKUnIH0iDQpwYXVzZQ=="
$script:DisB64 = "QGVjaG8gb2ZmDQpjaGNwIDY1MDAxID5udWwNCnBvd2Vyc2hlbGwgLU5vUHJvZmlsZSAtRXhlY3V0aW9uUG9saWN5IEJ5cGFzcyAtQ29tbWFuZCAiVW5yZWdpc3Rlci1TY2hlZHVsZWRUYXNrIC1UYXNrTmFtZSAnYXNwLWNvbGRzdGFydC13ZWVrbHknIC1Db25maXJtOiRmYWxzZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZTsgV3JpdGUtSG9zdCAn5bey5YWz6Zet5q+P5ZGo6Ieq5Yqo5pu05pawJyINCnBhdXNl"

# ---------- OSS V1 签名（.NET HMAC，零外部依赖） ----------
function Get-OssSignature([string]$StringToSign) {
    $hmac = New-Object System.Security.Cryptography.HMACSHA1
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($SK)
    [Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToSign)))
}
function Get-OssPresign([string]$Key, [int]$TtlSec) {
    $expires = [DateTimeOffset]::UtcNow.AddSeconds($TtlSec).ToUnixTimeSeconds().ToString()
    $sig = Get-OssSignature ("GET`n`n`n{0}`n/{1}/{2}" -f $expires, $Bucket, $Key)
    "https://{0}.{1}/{2}?OSSAccessKeyId={3}&Expires={4}&Signature={5}" -f `
        $Bucket, $Endpoint, $Key, $AK, $expires, [uri]::EscapeDataString($sig)
}
function Invoke-OssApi([string]$Verb, [string]$Key, [string]$Body = "", [string]$Ctype = "", [switch]$PrivateAcl) {
    $date = [DateTime]::UtcNow.ToString('R')
    # x-oss-* 头必须参与 V1 签名（CanonicalizedOSSHeaders：位于 Date 之后、资源之前，行尾带 \n）
    $ossHeaders = ""
    if ($PrivateAcl) { $ossHeaders = "x-oss-object-acl:private`n" }
    $sig = Get-OssSignature ("{0}`n`n{1}`n{2}`n{3}/{4}/{5}" -f $Verb, $Ctype, $date, $ossHeaders, $Bucket, $Key)
    # PS5.1 的 -Body <byte[]> 会被 ToString 成十进制串上传，必须走 -InFile 传原始字节
    $uri = "https://{0}.{1}/{2}" -f $Bucket, $Endpoint, $Key
    $headers = @{ Date = $date; Authorization = "OSS ${AK}:${sig}" }
    if ($PrivateAcl) { $headers['x-oss-object-acl'] = 'private' }
    if ($Body) {
        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllBytes($tmp, [System.Text.Encoding]::UTF8.GetBytes($Body))
        try { Invoke-WebRequest -Uri $uri -Method $Verb -InFile $tmp -ContentType $Ctype -UseBasicParsing -Headers $headers | Out-Null }
        finally { Remove-Item $tmp -Force }
    } else {
        Invoke-WebRequest -Uri $uri -Method $Verb -UseBasicParsing -Headers $headers | Out-Null
    }
}

# ---------- 对象级操作（重签循环/每单 zip 所需） ----------
function Invoke-OssPutFile([string]$Key, [string]$LocalPath, [string]$Ctype = "", [switch]$PrivateAcl) {
    $date = [DateTime]::UtcNow.ToString('R')
    $ossHeaders = ""
    if ($PrivateAcl) { $ossHeaders = "x-oss-object-acl:private`n" }
    $sig = Get-OssSignature ("PUT`n`n{0}`n{1}`n{2}/{3}/{4}" -f $Ctype, $date, $ossHeaders, $Bucket, $Key)
    $uri = "https://{0}.{1}/{2}" -f $Bucket, $Endpoint, $Key
    $headers = @{ Date = $date; Authorization = "OSS ${AK}:${sig}"; 'Cache-Control' = 'no-cache' }
    if ($PrivateAcl) { $headers['x-oss-object-acl'] = 'private' }
    Invoke-WebRequest -Uri $uri -Method PUT -InFile $LocalPath -ContentType $Ctype -UseBasicParsing -Headers $headers | Out-Null
}
function Get-OssObjectText([string]$Key) {
    $date = [DateTime]::UtcNow.ToString('R')
    $sig = Get-OssSignature ("GET`n`n`n{0}`n/{1}/{2}" -f $date, $Bucket, $Key)
    $resp = Invoke-WebRequest -Uri ("https://{0}.{1}/{2}" -f $Bucket, $Endpoint, $Key) -UseBasicParsing -Headers @{ Date = $date; Authorization = "OSS ${AK}:${sig}" }
    if ($resp.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($resp.Content) } else { [string]$resp.Content }
}
function Get-OssListKeys([string]$Prefix) {
    $date = [DateTime]::UtcNow.ToString('R')
    # V1 签名：子资源按字典序进 CanonicalizedResource
    $sig = Get-OssSignature ("GET`n`n`n{0}`n/{1}?list-type=2&prefix={2}" -f $date, $Bucket, $Prefix)
    $uri = "https://{0}.{1}/?list-type=2&prefix={2}" -f $Bucket, $Endpoint, [uri]::EscapeDataString($Prefix)
    $resp = Invoke-WebRequest -Uri $uri -UseBasicParsing -Headers @{ Date = $date; Authorization = "OSS ${AK}:${sig}" }
    $xml = [xml]($resp.Content)
    @($xml.ListBucketResult.Contents | ForEach-Object { $_.Key })
}
function New-OrderZipBundle([string]$Token, [string]$Sku, [string]$WorkDir) {
    # 每单交付 zip：双击安装 + 命令行 + agent prompt + 使用手册（docx）
    $d = Join-Path $WorkDir $Token
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    $url = "$TokenBaseUrl/$Token.ps1"
    $urlSh = "$TokenBaseUrl/$Token.sh"
    $setup = "@echo off`r`nchcp 65001 >nul`r`necho 正在安装智能体冷启动包（需联网，约 1 分钟）...`r`npowershell -NoProfile -ExecutionPolicy Bypass -Command `"irm '$url' | iex`"`r`necho.`r`necho 安装结束请重启你的 AI 工具。`r`npause"
    [System.IO.File]::WriteAllText((Join-Path $d '1-双击安装.bat'), $setup, (New-Object System.Text.UTF8Encoding $false))
    $cmds = "【Windows 命令行安装】打开 PowerShell 粘贴：`r`n$url`r`n 上面命令前加 irm、后加 | iex（卖家发的原始命令同此）`r`n`r`n【macOS / Linux 命令行安装】终端粘贴：`r`ncurl -fsSL $urlSh | bash"
    [System.IO.File]::WriteAllText((Join-Path $d '2-命令行安装.txt'), $cmds, (New-Object System.Text.UTF8Encoding $false))
    $prompt = "把下面这段直接发给你的 AI 助手（Claude Code / Cursor / ZCode 等）：`r`n`r`n" + `
        "请阅读当前目录下的「1-双击安装.bat」「2-命令行安装.txt」与「使用手册.docx」，在本机安装智能体冷启动包：" + `
        "优先执行 1-双击安装.bat 中的安装命令；完成后运行 asp.ps1 status 验证并给我安装报告。" + `
        "红线：不收集任何 API key；失败即停并原样报告；只写本目录与各 agent 托管配置段。"
    [System.IO.File]::WriteAllText((Join-Path $d '3-扔给AI助手安装.txt'), $prompt, (New-Object System.Text.UTF8Encoding $false))
    Copy-Item (Join-Path $Root "docs/manual/使用手册.docx") (Join-Path $d '使用手册.docx') -Force
    $readme = "智能体冷启动包（订单专属包）`r`n`r`n三种安装方式任选其一：`r`n  1. 双击「1-双击安装.bat」（Windows 推荐）`r`n  2. 打开「2-命令行安装.txt」复制命令到 PowerShell / 终端`r`n  3. 把「3-扔给AI助手安装.txt」整段发给你的 AI 助手代装`r`n`r`n详细图文：见「使用手册.docx」`r`n每周更新：重跑同一命令（或双击安装后桌面 asp-coldstart 目录里的 update-token.bat）`r`n售后：微信 xjinya（加后拉群）`r`n条款：转卖本包=转卖订单凭证，可被远程停用（EULA 见群公告）"
    [System.IO.File]::WriteAllText((Join-Path $d '0-说明.txt'), $readme, (New-Object System.Text.UTF8Encoding $false))
    $zipPath = Join-Path $WorkDir "$Token.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $d '*') -DestinationPath $zipPath -Force
    return $zipPath
}
function Publish-OrderArtifacts([string]$Token, [string]$Sku) {
    $primary = if ($Sku -eq 'ai-pm') { 'ai-pm' } else { 'base' }
    $packs = @(Get-OrderPack $Sku)
    Invoke-OssApi 'PUT' "i/$Token.ps1" (New-BootstrapPs1 $Token $Sku $packs $primary) 'text/plain; charset=utf-8' | Out-Null
    Invoke-OssApi 'PUT' "i/$Token.sh"  (New-BootstrapSh  $Token $Sku $packs $primary) 'text/plain; charset=utf-8' | Out-Null
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("asp-bundle-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zipLocal = New-OrderZipBundle $Token $Sku $tmp
    Invoke-OssPutFile "d/$Token.zip" $zipLocal 'application/zip'
    Remove-Item $tmp -Recurse -Force
    $check = Invoke-WebRequest -Uri "$TokenBaseUrl/$Token.ps1" -UseBasicParsing
    if ($check.StatusCode -ne 200 -or $check.Content -notmatch 'Signature=') { throw "签发自检失败: $Token（回读内容异常）" }
}

# ---------- bootstrap 生成 ----------
function New-BootstrapPs1([string]$Token, [string]$Sku, [object[]]$Packs, [string]$Primary) {
    $packCode = ($Packs | ForEach-Object {
        "  @{ name='$( $_.name )'; ver='$( $_.ver )'; url='$( $_.url )'; sha='$( $_.sha )' }"
    }) -join ",`r`n"
    $tokenUrl = "$TokenBaseUrl/$Token.ps1"
    @"
# ===============================================
# 智能体冷启动包 · 订单安装通道（D13 v2）
# 订单凭证: $Token ｜ SKU: $Sku ｜ 本签生成: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm')) UTC（$TtlDays 天内有效）
# 重新执行购买时给你的同一条命令即可更新到最新版
# ===============================================
`$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding(`$false) } catch {}
`$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
`$packs = @(
$packCode
)
`$dir = Join-Path `$env:TEMP ('asp-ord-$Token')
New-Item -ItemType Directory -Force -Path `$dir | Out-Null
foreach (`$p in `$packs) {
    Write-Host ('[下载] ' + `$p.name + ' ' + `$p.ver + ' ...')
    `$zip = Join-Path `$dir (`$p.name + '-' + `$p.ver + '.zip')
    Invoke-WebRequest -Uri `$p.url -OutFile `$zip -UseBasicParsing
    if ((Get-FileHash `$zip -Algorithm SHA256).Hash.ToLower() -ne `$p.sha) { throw ('sha256 校验失败: ' + `$p.name) }
}
Write-Host '[校验] sha256 全部通过'
`$last = `$packs[-1]
`$ex = Join-Path `$dir `$last.name
if (Test-Path `$ex) { Remove-Item `$ex -Recurse -Force }
Expand-Archive (Join-Path `$dir (`$last.name + '-' + `$last.ver + '.zip')) `$ex -Force
& (Join-Path `$ex 'asp.ps1') install $Primary -Yes
`$home2 = Join-Path `$env:USERPROFILE 'asp-coldstart'
New-Item -ItemType Directory -Force -Path `$home2 | Out-Null
`$cmd = 'irm ''' + '$tokenUrl' + ''' | iex'
@('@echo off', 'chcp 65001 >nul', ('powershell -NoProfile -ExecutionPolicy Bypass -Command "' + `$cmd + '"'), 'pause') |
    Set-Content -Path (Join-Path `$home2 'update-token.bat') -Encoding ASCII
[IO.File]::WriteAllBytes((Join-Path `$home2 'enable-weekly-autoupdate.bat'), [Convert]::FromBase64String('$EnB64'))
[IO.File]::WriteAllBytes((Join-Path `$home2 'disable-weekly-autoupdate.bat'), [Convert]::FromBase64String('$DisB64'))
Write-Host ''
Write-Host '======================================='
Write-Host (' 更新: 以后双击 ' + `$home2 + '\update-token.bat')
Write-Host '       或重跑购买时给你的安装命令（每周同一条）'
Write-Host ' 可选: 双击 enable-weekly-autoupdate.bat 开启每周自动更新（默认关）'
Write-Host ' 售后: 微信 xjinya（加后拉群）'
Write-Host ' 条款: 转卖订单凭证视为分销（见群公告 EULA）'
Write-Host '======================================='
"@
}

function New-BootstrapSh([string]$Token, [string]$Sku, [object[]]$Packs, [string]$Primary) {
    $tokenUrl = "$TokenBaseUrl/$Token.sh"
    $out = @('#!/usr/bin/env bash',
        '# 智能体冷启动包 · 订单安装通道（D13 v2）',
        "# 订单凭证: $Token ｜ SKU: $Sku ｜ 本签生成: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm')) UTC",
        'set -euo pipefail',
        'dir="${TMPDIR:-/tmp}/asp-ord-' + $Token + '"',
        'mkdir -p "$dir"')
    foreach ($p in $Packs) {
        $out += 'echo "[下载] ' + $p.name + ' ' + $p.ver + ' ..."'
        $out += 'curl -fsSL "' + $p.url + '" -o "$dir/' + $p.name + '-' + $p.ver + '.zip"'
        $out += 'echo "' + $p.sha + '  $dir/' + $p.name + '-' + $p.ver + '.zip" | sha256sum -c - >/dev/null'
    }
    $last = $Packs[-1]
    $out += @('echo "[校验] sha256 全部通过"',
        'ex="$dir/' + $last.name + '"',
        'rm -rf "$ex"; mkdir -p "$ex"',
        'unzip -q "$dir/' + $last.name + '-' + $last.ver + '.zip" -d "$ex"',
        'cd "$ex"',
        'ASP_CONFIRMED=1 bash asp.sh install ' + $Primary,
        'mkdir -p "$HOME/asp-coldstart"',
        "printf '#!/usr/bin/env bash\ncurl -fsSL $tokenUrl | bash\n' > `"`$HOME/asp-coldstart/update-token.sh`"",
        'chmod +x "$HOME/asp-coldstart/update-token.sh"',
        'echo ""',
        'echo "======================================="',
        'echo " 更新: bash $HOME/asp-coldstart/update-token.sh 或重跑购买时的命令"',
        'echo " 可选每周自动更新 = crontab 加一行: 0 10 * * 0 curl -fsSL ' + $tokenUrl + ' | bash"',
        'echo " 售后: 微信 xjinya（加后拉群）；转卖订单凭证视为分销（EULA 见群公告）"',
        'echo "======================================="')
    return (($out -join "`n") + "`n")
}

# ---------- 主流程 ----------
function Get-OrderPack([string]$Sku) {
    $name = if ($Sku -eq 'ai-pm') { 'ai-pm' } else { 'base' }
    $info = $Idx.packs.$name
    @{ name = $name; ver = $info.version; sha = $info.sha256;
       url = (Get-OssPresign $info.zip ([int]($TtlDays * 24 * 3600))) }
}

if ($Revoke) {
    foreach ($ext in @('.ps1', '.sh')) {
        try { Invoke-OssApi 'DELETE' "i/$Revoke$ext" | Out-Null; Write-Host "[撤销] i/$Revoke$ext 已删除" }
        catch { Write-Host "[撤销] i/$Revoke$ext 不存在或已删（$($_.Exception.Response.StatusCode.value__)）" }
    }
    try { Invoke-OssApi 'DELETE' "d/$Revoke.zip" | Out-Null; Write-Host "[撤销] d/$Revoke.zip 已删除" }
    catch { Write-Host "[撤销] d/$Revoke.zip 不存在或已删" }
    # 撤销标记（私有）：ResignAll 循环据此跳过，防止每 3 天重签复活已撤销订单
    Invoke-OssApi 'PUT' "orders/revoked/$Revoke.flag" ("revoked at " + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')) 'text/plain; charset=utf-8' -PrivateAcl | Out-Null
    Write-Host "[完成] 订单 $Revoke 已失效（买家命令将 404；重签循环将永久跳过）"
    exit 0
}

# ---------- 索引加载（两种模式共用） ----------
$script:Idx = Get-Content (Join-Path $Root "registry/index.json") -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $Idx.packs.base.sha256) {
    Write-Host "[错误] registry/index.json 缺 sha256（包内副本是置空的）。改用远端索引（Pages/OSS 上的）或先跑 build-release。" -ForegroundColor Red; exit 1
}

# ---------- 全量重签模式（云端定时/手动）：每 3 天刷新 presign，跳过已撤销 ----------
if ($ResignAll) {
    # 列订单+读私有日志复用已验证的 oss2（PS 手写列表签名曾 403）；签发上传仍走本脚本已验证的 PUT 签名
    $py = 'python'
    if (-not (Get-Command $py -ErrorAction SilentlyContinue)) { $py = 'python3' }
    if (-not (Get-Command $py -ErrorAction SilentlyContinue)) { Write-Host '[错误] ResignAll 需要 python3（pip install oss2）'; exit 1 }
    $ordersJson = & $py (Join-Path $Root 'scripts/list-orders.py') | Out-String
    $orders = $ordersJson | ConvertFrom-Json
    $digest = New-Object System.Collections.ArrayList
    $signed = 0; $skipped = 0
    foreach ($o in $orders) {
        if ($o.revoked) { $skipped++; continue }
        $sku = if ($o.sku) { $o.sku } else { 'base' }
        try {
            Publish-OrderArtifacts $o.token $sku
            $signed++
            [void]$digest.Add(("[{0}] {1}" -f $sku.ToUpper(), $o.cmd_win))
            [void]$digest.Add(("[Mac] " + $o.cmd_sh))
            [void]$digest.Add(("[zip] " + $o.bundle_zip))
            [void]$digest.Add("")
            Write-Host ("[重签] {0} (sku={1})" -f $o.token, $sku)
        } catch { Write-Host ("[失败] {0}: {1}" -f $o.token, $_.Exception.Message) -ForegroundColor Red }
    }
    $hdr = "智能体冷启动包 · 当前有效买家命令清单（生成于 " + [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm') + " UTC；链接 3 天有效，到期自动续）"
    $digestText = $hdr + [Environment]::NewLine + [Environment]::NewLine + ($digest -join [Environment]::NewLine)
    Invoke-OssApi 'PUT' ("orders/digest/" + [DateTime]::UtcNow.ToString('yyyy-MM-dd') + ".txt") $digestText 'text/plain; charset=utf-8' -PrivateAcl | Out-Null
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value ("## 买家命令清单（发群/私信素材）`n`n" + ($digest -join "`n")) }
    Write-Host ("[ResignAll 完成] 重签 {0} 单，跳过撤销 {1} 单；摘要 oss://$Bucket/orders/digest/" -f $signed, $skipped)
    exit 0
}

function New-RandomToken([int]$Len = 12) {
    # 密码学随机，字母表去掉易混淆字符（i/l/o/0/1）
    $alphabet = "abcdefghjkmnpqrstuvwxyz23456789".ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[] $Len
    $rng.GetBytes($bytes)
    -join ($bytes | ForEach-Object { $alphabet[[int]$_ % $alphabet.Length] })
}

# ---------- 单订单模式（云端自动化：GitHub Actions / 任意有凭据的机器） ----------
if ($Sku) {
    $sku = $Sku.Trim()
    if ($sku -ne 'base' -and $sku -ne 'ai-pm') { Write-Host "[错误] -Sku 只支持 base / ai-pm" -ForegroundColor Red; exit 1 }
    $primary = $sku
    # 防碰撞：token 已存在则重新生成（最多 5 次）
    $token = ""
    for ($i = 0; $i -lt 5; $i++) {
        $cand = New-RandomToken
        try { Invoke-WebRequest -Uri "$TokenBaseUrl/$cand.ps1" -Method Head -UseBasicParsing -TimeoutSec 10 | Out-Null }
        catch { $token = $cand; break }   # 404 = 未占用
    }
    if (-not $token) { Write-Host '[错误] token 生成碰撞 5 次（概率~0，疑配置异常）' -ForegroundColor Red; exit 1 }

    Publish-OrderArtifacts $token $sku

    # 订单日志：OSS 私有前缀（对象级 private ACL，匿名不可读），一单一 JSON
    $logKey = "orders/log/{0}-{1}.json" -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'), $token
    $zipUrl = "$TokenBaseUrl/../d/$token.zip"
    $logObj = [ordered]@{
        v = 1; token = $token; sku = $sku
        order_ref = $OrderRef; note = $Note
        issued_at = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'); ttl_days = $TtlDays
        cmd_win = "irm $TokenBaseUrl/$token.ps1 | iex"
        cmd_sh  = "curl -fsSL $TokenBaseUrl/$token.sh | bash"
        bundle_zip = "https://asp-registry-xjinya.oss-cn-hangzhou.aliyuncs.com/d/$token.zip"
    }
    Invoke-OssApi 'PUT' $logKey ($logObj | ConvertTo-Json) 'application/json; charset=utf-8' -PrivateAcl | Out-Null

    Write-Host "[已签发] $token (sku=$sku)  [自检✓]  [订单日志✓ oss://$Bucket/$logKey]  [每单zip✓ d/$token.zip]"
    Write-Host "  买家命令(Win): $($logObj.cmd_win)"
    Write-Host "  买家命令(Mac/Linux): $($logObj.cmd_sh)"
    Write-Host "  买家zip包: $($logObj.bundle_zip)"
    if ($env:GITHUB_STEP_SUMMARY) {
        $fence = '```'
        Add-Content -Path $env:GITHUB_STEP_SUMMARY -Value (@(
            '', '### 买家命令（复制发给买家）', "$fence`powershell", $logObj.cmd_win, $fence,
            '', '### Mac / Linux', "$fence`bash", $logObj.cmd_sh, $fence,
            '', "### 买家 zip 包（含图文手册+双击安装）", $logObj.bundle_zip,
            '', "订单日志: ``oss://$Bucket/$logKey`` ｜ 撤销: ``gen-order-tokens.ps1 -Revoke $token``"
        ) -join "`n")
    }
    exit 0
}

if (-not $OrdersCsv) { $OrdersCsv = Join-Path $Root "registry/orders.csv" }
if (-not (Test-Path $OrdersCsv)) {
    Write-Host "[错误] 订单表不存在: $OrdersCsv（复制 registry/orders.example.csv 起步）" -ForegroundColor Red; exit 1
}
$rows = Import-Csv $OrdersCsv
if ($Only) { $rows = @($rows | Where-Object { $_.token -eq $Only }) }
if (-not $rows) { Write-Host '[错误] 无订单行' -ForegroundColor Red; exit 1 }

foreach ($r in $rows) {
    $token = $r.token.Trim()
    if (-not $token -or $token -match 'EXAMPLE') { continue }
    $sku = if ($r.sku) { $r.sku.Trim() } else { 'base' }
    $primary = if ($sku -eq 'ai-pm') { 'ai-pm' } else { 'base' }
    Publish-OrderArtifacts $token $sku
    Write-Host "[已签发] $token (sku=$sku)  [自检✓ 回读200+presign内嵌]  [每单zip✓ d/$token.zip]"
    Write-Host "  买家命令(Win): irm $TokenBaseUrl/$token.ps1 | iex"
}
Write-Host "[完成] 本周订单通道已重签（TTL $TtlDays 天）"
