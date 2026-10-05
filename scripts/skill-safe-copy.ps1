# =====================================================================
# skill-safe-copy.ps1 — R00/R03 核心模块 v2（DST-P0-01 算法：tmp+rename 原子交换）
# 规格：子模块 PRD · 分发层 v0.2 §4 DST-P0-01（2026-10-05 12:06 UTC 版）
# 关键语义（与 v1 的差异）：
#   1. 整目录原子交换：copy→.asp-tmp-* → rename(dst→.asp-old-*) → rename(tmp→dst) → 仅删本次 old
#   2. tree_sha256 状态比对：与 _state.json 记录一致=replace，不一致/未知=user_modified（覆盖前必备份）
#   3. symlink/reparse 守卫：目录本身或其下任一链接 → ASP-W-LINK-001，跳过不写
#   4. rename 占用重试 3×500ms → ASP-E-LOCKED-001
#   5. 嵌套处理需 skills.manifest.json（registry 0.3，P1）；P0 无 manifest → 只报告 ASP-W-NEST-002 并跳过该技能
#   6. 未知用户文件随整目录备份保存，报告列出（可从备份恢复），不原位保留
# 测试：scripts/test-skill-safe-copy.ps1（抽取 R00-CORE region 执行夹具断言）
# =====================================================================

#region R00-CORE

function Get-TreeSha256([string]$Dir) {
    # DST-P0-01：对目录内所有文件按相对路径(/)排序，拼 rel + "\0" + 文件sha256 + "\n" → sha256
    if (-not (Test-Path $Dir)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $ms = New-Object System.IO.MemoryStream
    try {
        $files = @(Get-ChildItem $Dir -Recurse -File -Force -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Substring($Dir.Length).Replace('\', '/') })
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($Dir.Length).Replace('\', '/')
            $fsha = [System.Security.Cryptography.SHA256]::Create()
            $fb = $fsha.ComputeHash([IO.File]::ReadAllBytes($f.FullName))
            $rb = [Text.Encoding]::UTF8.GetBytes($rel + "`0")
            $ms.Write($rb, 0, $rb.Length)
            $ms.Write($fb, 0, $fb.Length)
        }
        return ([BitConverter]::ToString($sha.ComputeHash($ms.ToArray()))).Replace('-', '').ToLower()
    } finally { $sha.Dispose(); $ms.Dispose() }
}

function Test-LinkDanger([string]$Path) {
    # 目录本身是链接，或其下任一条目是 symlink/reparse → true（不跟随、不写入）
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $true }
    $hit = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } |
        Select-Object -First 1
    return ($null -ne $hit)
}

function Move-DirRetrying([string]$From, [string]$To) {
    # rename，占用重试 3 次 × 500ms；仍失败返回 $false（调用方报 ASP-E-LOCKED-001）
    for ($i = 0; $i -lt 3; $i++) {
        try { [System.IO.Directory]::Move($From, $To); return $true }
        catch [System.IO.IOException] { Start-Sleep -Milliseconds 500 }
        catch { return $false }
    }
    return $false
}

function Copy-SkillSafe {
    # DST-P0-01 单技能部署。返回 @{status; code; reason; backup; unknown_files; tree_sha256; tmp_left}
    param([Parameter(Mandatory=$true)][string]$Source,
          [Parameter(Mandatory=$true)][string]$DestinationDir,
          [string]$BackupRoot = "",
          [string]$RunId = "manual",
          [string]$AgentId = "unknown",
          [string]$StateTreeSha256 = $null)
    if (-not (Test-Path $Source)) { throw ("Copy-SkillSafe: 源不存在: {0}" -f $Source) }
    $name = Split-Path $Source -Leaf
    if (-not (Test-Path $DestinationDir)) { New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null }
    $dst = Join-Path $DestinationDir $name
    $tmp = Join-Path $DestinationDir ("." + $name + ".asp-tmp-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    $result = @{ status = "created"; code = $null; reason = $null; backup = $null; unknown_files = @(); tree_sha256 = $null }

    # 1) symlink 守卫
    if (Test-LinkDanger $dst) {
        return @{ status = "skipped"; code = "ASP-W-LINK-001"; reason = "目标含符号链接/reparse，不跟随不写入"; backup = $null; unknown_files = @(); tree_sha256 = $null }
    }

    # 2) 历史嵌套（dst/<name>/SKILL.md）：P0 无 published-manifest → 只报告并跳过（禁止盲修）
    if (Test-Path (Join-Path $dst ($name + "\SKILL.md"))) {
        return @{ status = "skipped"; code = "ASP-W-NEST-002"; reason = ("历史嵌套(无发布清单不可安全清理): {0}" -f $dst); backup = $null; unknown_files = @(); tree_sha256 = $null }
    }

    # 3) 已存在 → tree_sha256 判定 reason → 整目录备份
    if (Test-Path $dst) {
        $result.status = "updated"
        if ([string]::IsNullOrEmpty($BackupRoot)) { $BackupRoot = Join-Path $DestinationDir "_backup" }
        $bkDir = Join-Path $BackupRoot (Join-Path $RunId $AgentId)
        if (-not (Test-Path $bkDir)) { New-Item -ItemType Directory -Path $bkDir -Force | Out-Null }
        $backup = Join-Path $bkDir $name
        Copy-Item $dst $backup -Recurse -Force
        $result.backup = $backup
        $cur = Get-TreeSha256 $dst
        if (-not [string]::IsNullOrEmpty($StateTreeSha256) -and $cur -eq $StateTreeSha256) { $result.reason = "replace" }
        else { $result.reason = "user_modified" }
        # 未知用户文件 = 备份里有而新包没有（相对路径口径），报告可从备份恢复
        $srcRel = @(Get-ChildItem $Source -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($Source.Length).Replace('\', '/') })
        $result.unknown_files = @(Get-ChildItem $dst -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($dst.Length).Replace('\', '/') } |
            Where-Object { $srcRel -notcontains $_ })
    }

    # 4) 原子交换：copy→tmp；dst→old；tmp→dst；仅删本次 old
    Copy-Item $Source $tmp -Recurse -Force
    if (Test-Path $dst) {
        $old = Join-Path $DestinationDir ("." + $name + ".asp-old-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
        if (-not (Move-DirRetrying $dst $old)) {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            return @{ status = "failed"; code = "ASP-E-LOCKED-001"; reason = "目标目录被占用，重试 3 次失败"; backup = $result.backup; unknown_files = $result.unknown_files; tree_sha256 = $null }
        }
        if (-not (Move-DirRetrying $tmp $dst)) {
            [void](Move-DirRetrying $old $dst)   # 回滚
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            return @{ status = "failed"; code = "ASP-E-LOCKED-001"; reason = "tmp 换入失败，已回滚原目录"; backup = $result.backup; unknown_files = $result.unknown_files; tree_sha256 = $null }
        }
        Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        if (-not (Move-DirRetrying $tmp $dst)) {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            return @{ status = "failed"; code = "ASP-E-LOCKED-001"; reason = "新目录换入失败"; backup = $null; unknown_files = @(); tree_sha256 = $null }
        }
    }
    $result.tree_sha256 = Get-TreeSha256 $dst
    if ($result.status -eq "created") { $result.reason = "new" }
    return $result
}

function Get-NestedSkillDirs([string]$SkillsDir) {
    # 历史嵌套签名：skills/<name>/<name>/SKILL.md。只检测，不修改。
    $out = @()
    if (-not (Test-Path $SkillsDir)) { return $out }
    foreach ($d in (Get-ChildItem $SkillsDir -Directory -ErrorAction SilentlyContinue)) {
        $inner = Join-Path $d.FullName $d.Name
        if (Test-Path (Join-Path $inner "SKILL.md")) { $out += $inner }
    }
    return $out
}

function Repair-NestedWithManifest {
    # P1 才可用：需要 published-versions 清单（registry 0.3 skills.manifest.json，含历史版本）。
    # 判定：内层文件集合(相对路径+sha256) ⊆ 任一已发布版本，且外层仅含已知文件 → 备份后清内层。
    # P0 调用方不传 $PublishedVersions → 一律 reported（不改动，doctor 持续提示）。
    param([Parameter(Mandatory=$true)][string]$NestedDir,
          [hashtable]$PublishedVersions = $null,
          [string]$BackupRoot = "")
    $outer = Split-Path $NestedDir -Parent
    $name = Split-Path $outer -Leaf
    $innerName = Split-Path $NestedDir -Leaf
    if ($innerName -ne $name -or -not (Test-Path (Join-Path $NestedDir "SKILL.md"))) {
        return @{ status = "skipped"; reason = "非缺陷签名" }
    }
    if ($null -eq $PublishedVersions -or $PublishedVersions.Count -eq 0) {
        return @{ status = "reported"; code = "ASP-W-NEST-002"; reason = "无发布清单，P0 不清理" }
    }
    # manifest 命中判定
    $innerFiles = Get-ChildItem $NestedDir -Recurse -File -Force -ErrorAction SilentlyContinue
    $matched = $null
    foreach ($ver in $PublishedVersions.Keys) {
        $pub = $PublishedVersions[$ver]   # @{ rel = sha256 }
        $ok = $true
        foreach ($f in $innerFiles) {
            $rel = $f.FullName.Substring($NestedDir.Length).Replace('\', '/')
            if (-not $pub.ContainsKey($rel)) { $ok = $false; break }
            $h = [System.Security.Cryptography.SHA256]::Create()
            $fb = $h.ComputeHash([IO.File]::ReadAllBytes($f.FullName))
            $hex = ([BitConverter]::ToString($fb)).Replace('-', '').ToLower()
            if ($pub[$rel] -ne $hex) { $ok = $false; break }
        }
        if ($ok) { $matched = $ver; break }
    }
    if (-not $matched) {
        return @{ status = "reported"; code = "ASP-W-NEST-002"; reason = "内层不匹配任何已发布版本，不清理" }
    }
    if ([string]::IsNullOrEmpty($BackupRoot)) { $BackupRoot = Join-Path (Split-Path $outer -Parent) "_backup" }
    if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
    $backup = Join-Path $BackupRoot ($name + "-nested-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Copy-Item $outer $backup -Recurse -Force
    Remove-Item $NestedDir -Recurse -Force
    return @{ status = "repaired"; matched_version = $matched; backup = $backup }
}

function Clean-BackupRetention([string]$BackupRoot, [int]$KeepRuns = 10, [int]$KeepDays = 30) {
    # DST §3.2：保留最近 N 次运行或 30 天（取多者）；只删 _backup/<run_id>/ 整目录，绝不出界
    if (-not (Test-Path $BackupRoot)) { return @() }
    $removed = @()
    $runs = @(Get-ChildItem $BackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($runs.Count -gt $KeepRuns) {
        foreach ($r in ($runs | Select-Object -First ($runs.Count - $KeepRuns))) {
            $removed += $r.FullName
        }
    }
    $cutoff = (Get-Date).AddDays(-$KeepDays)
    foreach ($r in $runs) {
        if ($removed -contains $r.FullName) { continue }
        $stamp = Get-Date "1970-01-01"
        if ($r.Name -match '(\d{8})-(\d{6})') {
            try { $stamp = [datetime]::ParseExact($Matches[1] + $Matches[2], "yyyyMMddHHmmss", $null) } catch { continue }
        }
        if ($stamp -lt $cutoff -and (Get-Date $stamp) -gt (Get-Date "2000-01-01")) { $removed += $r.FullName }
    }
    foreach ($p in $removed) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    return $removed
}

#endregion R00-CORE
