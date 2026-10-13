param([string]$Repository = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$TestRoot = Join-Path $Repository ('test-output/installer-' + [guid]::NewGuid().ToString('N'))
New-Item $TestRoot -ItemType Directory -Force | Out-Null
$results = New-Object System.Collections.Generic.List[object]
function Check($Name, $Value) { $script:results.Add(@{name=$Name;pass=[bool]$Value}); if (-not $Value) { Write-Host ('FAIL: ' + $Name) } }
function Fixture($Name, $Agent) {
    $r = Join-Path $TestRoot $Name; New-Item $r -ItemType Directory -Force | Out-Null
    foreach ($item in @('asp.ps1','packs','adapters','registry','scripts')) { Copy-Item (Join-Path $Repository $item) (Join-Path $r $item) -Recurse }
    $h = Join-Path $r 'home'; New-Item (Join-Path $h $Agent) -ItemType Directory -Force | Out-Null
    return @{root=$r;home=$h}
}
function Install($Fixture, $Sku) {
    $r=$Fixture.root.Replace('\','/'); $h=$Fixture.home.Replace('\','/')
    $code="Set-Variable -Name HOME -Value '$h' -Force; `$env:USERPROFILE=`$HOME; Set-Location '$r'; & './asp.ps1' install '$Sku' -Yes"
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded *> (Join-Path $Fixture.root 'last-install.log')
    return $LASTEXITCODE
}
foreach ($sku in @('base','ai-pm')) {
    $f=Fixture $sku '.claude'; $skills=Join-Path $f.home '.claude/skills'; $expected=if($sku -eq 'base'){25}else{37}
    Check "$sku first install" ((Install $f $sku) -eq 0)
    Check "$sku first file count" ((Get-ChildItem $skills -Filter SKILL.md -Recurse).Count -eq $expected)
    Install $f $sku | Out-Null; Install $f $sku | Out-Null
    Check "$sku three installs no nested duplicates" ((Get-ChildItem $skills -Filter SKILL.md -Recurse).Count -eq $expected)
    $source=Join-Path $f.root 'packs/base/skills/data-insight/SKILL.md'; $target=Join-Path $skills 'data-insight/SKILL.md'
    Add-Content $source "`nTEST_NEW_RELEASE_MARKER" -Encoding UTF8; Install $f $sku | Out-Null
    Check "$sku upgrade writes active top-level file" ((Get-Content $target -Raw) -match 'TEST_NEW_RELEASE_MARKER')
    [IO.File]::WriteAllText($target,'BUYER_CUSTOM_EDIT'); Install $f $sku | Out-Null
    Check "$sku custom edit preserved" ((Get-Content $target -Raw) -eq 'BUYER_CUSTOM_EDIT')
    $backup=@(Get-ChildItem (Join-Path $f.root '_backup') -Recurse -File -ErrorAction SilentlyContinue | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'BUYER_CUSTOM_EDIT' })
    Check "$sku conflicting custom skill backed up" ($backup.Count -gt 0)
}
$c=Fixture 'cursor-only' '.cursor'; Install $c base | Out-Null
$mdc=Get-Content (Join-Path $c.home '.cursor/rules/asp-ai-pm.mdc') -Raw -Encoding UTF8
$agents=Get-Content (Join-Path $c.root 'packs/base/AGENTS.md') -Raw -Encoding UTF8
Check 'Cursor-only contains actual role workflow' ($mdc.Contains($agents.Trim()))
$legacy=Fixture 'old-nested' '.claude'
$legacyDir=Join-Path $legacy.home '.claude/skills/data-insight/data-insight';New-Item $legacyDir -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $legacy.root 'packs/base/skills/data-insight/SKILL.md') (Join-Path $legacyDir 'SKILL.md')
Install $legacy base | Out-Null
Check 'Known legacy duplicate repaired with backup' (-not (Test-Path (Join-Path $legacyDir 'SKILL.md')))
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $TestRoot 'results.json') -Encoding UTF8
$failed=@($results | Where-Object { -not $_.pass }).Count
Write-Host ("Installer regression: {0} passed / {1}, evidence={2}" -f ($results.Count-$failed),$results.Count,$TestRoot)
exit $failed
