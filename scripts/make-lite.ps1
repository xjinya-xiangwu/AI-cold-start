# =====================================================================
# make-lite.ps1 - 免费版拆分脚本（获客钩子）
# 用法: .\scripts\make-lite.ps1 -Pack ai-pm -Skills prd-review,user-story
# 动作: 从完整包拆出 lite 版（指定 2-3 个自产 skills + AGENTS.md + 试用版 prompts）
#       输出 dist/lite/ 供发布到 GitHub 仓库公开目录
# =====================================================================
param(
    [Parameter(Mandatory=$true)][string]$Pack,
    [string]$Skills = "prd-review,user-story"
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot/..").Path
$Lite = Join-Path $Root "dist/lite"
if (Test-Path $Lite) { Remove-Item $Lite -Recurse -Force }
New-Item -ItemType Directory "$Lite/packs/$Pack/skills" -Force | Out-Null

foreach ($s in $Skills.Split(",")) {
    Copy-Item (Join-Path $Root "packs/$Pack/skills/$s") "$Lite/packs/$Pack/skills/$s" -Recurse
}
Copy-Item (Join-Path $Root "packs/$Pack/AGENTS.md") "$Lite/packs/$Pack/AGENTS.md"
Copy-Item (Join-Path $Root "packs/$Pack/mcp") "$Lite/packs/$Pack/mcp" -Recurse
Copy-Item (Join-Path $Root "adapters") "$Lite/adapters" -Recurse
Copy-Item (Join-Path $Root "asp.ps1"), (Join-Path $Root "asp.sh"), (Join-Path $Root "setup.bat"), (Join-Path $Root "update.bat"), (Join-Path $Root "setup.command"), (Join-Path $Root "update.command") $Lite

# lite 版说明文件（区别于完整包）
@" 
# $Pack Lite（免费版）

完整版包含：全部自产 skills（6 个）、完整 prompt 库（42 条）、每周更新服务。
本免费版仅含 $($Skills.Split(",").Count) 个 skills，供体验安装流程与内容质量。

完整版获取方式见商品页。安装方式相同：双击 setup（Windows）/ setup.command（macOS）。
"@ | [System.IO.File]::WriteAllText((Join-Path $Lite "LITE-README.md"), $_, (New-Object System.Text.UTF8Encoding $false))

Write-Host "[完成] dist/lite/ 已生成（含 skills: $Skills）"
Write-Host "       发布方式：复制到 GitHub 仓库 lite 分支或公开目录"
