# =====================================================================
# sync-registry-oss.ps1 - registry/ 全量同步到 OSS 备源（发版流水线最后一步）
# 用法:
#   .\sync-registry-oss.ps1                    # 同步 registry/ 全量
#   .\sync-registry-oss.ps1 -Zip <path.zip>    # 额外上传一个发版 zip 到 packs/
# 环境变量: ASP_OSS_AK / ASP_OSS_SK（与 gen-order-tokens.ps1 相同）
# 缓存策略: index.json 等元数据 no-cache；packs/*.zip immutable（版本号即内容）
# =====================================================================
param(
    [string]$Bucket = "asp-registry-xjinya",
    [string]$Endpoint = "oss-cn-hangzhou.aliyuncs.com",
    [string]$Zip = ""
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
$Root = (Resolve-Path "$PSScriptRoot/..").Path

if (-not $env:ASP_OSS_AK -or -not $env:ASP_OSS_SK) {
    Write-Host "[错误] 缺少 ASP_OSS_AK / ASP_OSS_SK——OSS 备源无法同步" -ForegroundColor Red; exit 1
}
$AK = $env:ASP_OSS_AK; $SK = $env:ASP_OSS_SK

function Get-OssSignature([string]$StringToSign) {
    $hmac = New-Object System.Security.Cryptography.HMACSHA1
    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($SK)
    [Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToSign)))
}
function Invoke-OssPut([string]$Key, [string]$LocalPath, [string]$Ctype = "") {
    $date = [DateTime]::UtcNow.ToString('R')
    $sig = Get-OssSignature ("PUT`n`n{0}`n{1}`n/{2}/{3}" -f $Ctype, $date, $Bucket, $Key)
    $uri = "https://{0}.{1}/{2}" -f $Bucket, $Endpoint, $Key
    $headers = @{ Date = $date; Authorization = "OSS ${AK}:${sig}"; 'Cache-Control' = $cache }
    Invoke-WebRequest -Uri $uri -Method PUT -InFile $LocalPath -ContentType $Ctype -UseBasicParsing -Headers $headers | Out-Null
}

$regDir = Join-Path $Root "registry"
$n = 0
Get-ChildItem $regDir -Recurse -File | ForEach-Object {
    $key = $_.FullName.Substring($regDir.Length + 1).Replace('\', '/')
    # v0.13.2：显式 Content-Type——PS5.1 客户端对无 charset 响应拿 Byte[]，ConvertFrom-Json 静默解析为空
    $ctype = switch -Regex ($_.Extension) {
        '\.json$' { 'application/json; charset=utf-8'; break }
        '\.html?$' { 'text/html; charset=utf-8'; break }
        '\.csv$' { 'text/csv; charset=utf-8'; break }
        '\.zip$' { 'application/zip'; break }
        default { 'application/octet-stream' }
    }
    $cache = if ($_.Extension -eq '.zip') { 'public, max-age=31536000, immutable' } else { 'no-cache' }
    Invoke-OssPut $key $_.FullName $ctype
    $n++
    Write-Host ("  [oss] {0} ({1})" -f $key, $ctype)
}
if ($Zip) {
    if (-not (Test-Path $Zip)) { Write-Host "[错误] -Zip 不存在: $Zip" -ForegroundColor Red; exit 1 }
    Invoke-OssPut ("packs/" + (Split-Path $Zip -Leaf)) $Zip 'application/zip'
    $n++
    Write-Host ("  [oss] packs/{0}" -f (Split-Path $Zip -Leaf))
}
Write-Host "[完成] 已同步 $n 个文件到 OSS 备源（$Bucket）"
