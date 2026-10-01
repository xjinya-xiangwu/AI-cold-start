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

# 3) 打包（v0.5.0 分层：按包过滤 packs——base zip 只含 base；专业包 zip 含 base+该包，依赖安装需要）
$stage = Join-Path $env:TEMP ("asp-rel-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory "$stage/packs" | Out-Null
# 依赖闭包：base 恒含；专业包按 deps.json 的 requires 收集
$includePacks = @("base")
$depsFile = Join-Path $Root "packs/$Pack/deps.json"
if (Test-Path $depsFile) {
    foreach ($d in @((Get-Content $depsFile -Raw -Encoding UTF8 | ConvertFrom-Json).requires)) {
        if ($includePacks -notcontains $d) { $includePacks += $d }
    }
}
if ($includePacks -notcontains $Pack) { $includePacks += $Pack }
foreach ($pk in $includePacks) {
    Copy-Item (Join-Path $Root "packs/$pk") (Join-Path "$stage/packs" $pk) -Recurse
}
Copy-Item (Join-Path $Root "adapters") (Join-Path $stage "adapters") -Recurse
Copy-Item (Join-Path $Root "registry") (Join-Path $stage "registry") -Recurse
# v0.10.0：剔除 registry/packs 内历史 zip——否则 zip 套 zip 逐版膨胀
Remove-Item (Join-Path $stage "registry/packs") -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem $Root -File | Where-Object { $_.Name -match '^asp\.(ps1|sh)$|^setup\.|^update\.|^README\.md$' } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $stage $_.Name)
}
Write-Host ("[打包] 包含 packs: {0}" -f ($includePacks -join ", "))
$zipName = "$Pack-$tag.zip"
$zipPath = Join-Path $Dist $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$stage/*" -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force

# 3.5) 同步 zip 到 registry/packs/（GitHub Pages 主源直发；OSS 开通后同样上传）
$regPacks = Join-Path $Root "registry/packs"
if (-not (Test-Path $regPacks)) { New-Item -ItemType Directory $regPacks | Out-Null }
Copy-Item $zipPath (Join-Path $regPacks $zipName) -Force

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
