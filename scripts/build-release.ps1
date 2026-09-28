# =====================================================================
# build-release.ps1 - 发版打包脚本（周更流水线的第④步）
# 用法: .\scripts\build-release.ps1 -Pack ai-pm [-Version 1.1.0]
# 动作: 校验 BOM -> 打包 zip(含安装器+packs+adapters+registry) -> 计算 sha256
#       -> 更新 registry/index.json 的版本与哈希 -> 输出到 dist/
# =====================================================================
param(
    [Parameter(Mandatory=$true)][string]$Pack,
    [string]$Version = ""
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot/..").Path
$Dist = Join-Path $Root "dist"
if (-not (Test-Path $Dist)) { New-Item -ItemType Directory $Dist | Out-Null }

# 1) BOM 自检（asp.ps1 无 BOM 会在 PS5.1 上炸中文，见 README 开发坑#1）
$bytes = [System.IO.File]::ReadAllBytes((Join-Path $Root "asp.ps1"))[0..2]
if (($bytes[0] -ne 0xEF) -or ($bytes[1] -ne 0xBB) -or ($bytes[2] -ne 0xBF)) {
    Write-Host "[错误] asp.ps1 丢失 UTF-8 BOM，先修复再发版！" -ForegroundColor Red; exit 1
}

# 2) 版本号：未指定则从 index.json 读 minor +1
$idxPath = Join-Path $Root "registry/index.json"
$idx = Get-Content $idxPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $Version) {
    $cur = $idx.packs.$Pack.version
    if ($cur -match '^v?(\d+)\.(\d+)\.(\d+)') { $Version = "{0}.{1}.0" -f $Matches[1], ([int]$Matches[2] + 1), $Matches[3] }
    else { $Version = "1.0.0" }
}
$tag = "v$Version"
Write-Host "[发版] $Pack $tag"

# 3) 打包（排除开发产物）
$stage = Join-Path $env:TEMP ("asp-rel-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory $stage | Out-Null
foreach ($part in @("packs", "adapters", "registry")) {
    Copy-Item (Join-Path $Root $part) (Join-Path $stage $part) -Recurse
}
Get-ChildItem $Root -File | Where-Object { $_.Name -match '^asp\.(ps1|sh)$|^setup\.|^update\.|^README\.md$' } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $stage $_.Name)
}
$zipName = "$Pack-$tag.zip"
$zipPath = Join-Path $Dist $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$stage/*" -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

# 4) 哈希 + 更新 index.json
$sha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
$idx.packs.$Pack.version = $tag
$idx.packs.$Pack.sha256 = $sha
$idx.packs.$Pack.zip = "packs/$zipName"
$idx.generated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$idx | ConvertTo-Json -Depth 16 | ForEach-Object {
    [System.IO.File]::WriteAllText($idxPath, $_ + "`n", (New-Object System.Text.UTF8Encoding $false))
}

Write-Host "[完成] dist/$zipName"
Write-Host "       sha256: $sha"
Write-Host "       index.json 已更新。发布 = 上传 zip 与 index 到 OSS 主源 + GitHub Pages 备源"
Write-Host "[待人工] UPDATES.md 写变更说明 -> 更新群推送"
