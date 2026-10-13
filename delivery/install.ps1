param([switch]$Cli, [switch]$Silent)
$ErrorActionPreference='Stop'
$packageRoot=$PSScriptRoot
$manifest=Get-Content (Join-Path $packageRoot 'delivery-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
# Check app bytes before executing any bundled engine.
$integrity=Get-Content (Join-Path $packageRoot 'app-integrity.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$appRoot=[IO.Path]::GetFullPath((Join-Path $packageRoot 'app')).TrimEnd([char[]]'\/')
foreach($entry in $integrity.PSObject.Properties) {
    $file=[IO.Path]::GetFullPath((Join-Path $appRoot $entry.Name))
    if(-not $file.StartsWith($appRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw '包完整性清单路径越界' }
    if(-not (Test-Path -LiteralPath $file) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$entry.Value) { throw ('包文件校验失败：' + $entry.Name) }
}
$sku=[string]$manifest.sku
if ($sku -notin @('base','ai-pm')) { throw '无效的已购内容标识' }
$homeRoot=Join-Path $env:USERPROFILE 'asp-coldstart'
$destination=Join-Path $homeRoot ('app-' + $sku)
New-Item $destination -ItemType Directory -Force | Out-Null
foreach($entry in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'app') -Recurse -File) {
    $rel=$entry.FullName.Substring((Join-Path $packageRoot 'app').Length).TrimStart([char[]]'\/')
    if($rel -match '^(_backup|_state|_skill-state)(/|\\|\.)') { continue }
    $dst=Join-Path $destination $rel
    New-Item (Split-Path $dst) -ItemType Directory -Force | Out-Null
    if(Test-Path -LiteralPath $dst) {
        if((Get-FileHash $dst).Hash -ne (Get-FileHash $entry.FullName).Hash) {
            $backup=Join-Path $homeRoot ('release-backups/' + [guid]::NewGuid().ToString('N') + '/' + $rel)
            New-Item (Split-Path $backup) -ItemType Directory -Force | Out-Null
            Copy-Item -LiteralPath $dst -Destination $backup
        }
    }
    Copy-Item -LiteralPath $entry.FullName -Destination $dst -Force
}
if($Silent) {
    $logRoot=Join-Path $homeRoot 'logs'; New-Item $logRoot -ItemType Directory -Force | Out-Null
    & (Join-Path $destination 'asp.ps1') install $sku -Yes *> (Join-Path $logRoot ('install-' + (Get-Date -Format yyyyMMdd-HHmmss) + '.log'))
} elseif($Cli) { & (Join-Path $destination 'asp.ps1') install $sku -Yes }
else { & (Join-Path $destination 'asp.ps1') ui }
# Seller refreshes links; no local scheduled tasks are installed without permission.
