# =====================================================================
# export-sanitize.ps1 — R01/D18：export 产物凭证值 -> 占位符（结构保留）
# 依据：PRD v0.2 R01/N2「结构保留但凭证值变占位符 -> lint 零命中才写」+ D18 已决。
# 规则：JSON 递归走键名（token/api_key/secret/pat/authorization/password/credential）
#       -> 值替换为 <AGENT-SYNC:键名>；TOML/INI/env 等文本走行级正则；其余文件交给 lint 兜底。
# 局限（如实）：键名启发式不是万能——lint 是最后关卡；人工预览仍必需（PRD §10）。
# 测试：scripts/test-export-sanitize.ps1（抽取 R01-CORE region 执行夹具断言）。
# =====================================================================

#region R01-CORE

function Convert-JsonPlaceholders([object]$node, [string]$KeyNameRx) {
    # 递归替换 JSON 树中敏感键的字符串值，返回替换处数
    $c = 0
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($node.PSObject.Properties)) {
            if ($p.Name -match $KeyNameRx -and $p.Value -is [string] -and $p.Value -and -not $p.Value.StartsWith("<AGENT-SYNC:")) {
                $node.PSObject.Properties[$p.Name].Value = "<AGENT-SYNC:" + $p.Name + ">"
                $c++
            } elseif ($null -ne $p.Value -and ($p.Value -is [System.Management.Automation.PSCustomObject] -or ($p.Value -is [System.Collections.IEnumerable] -and $p.Value -isnot [string]))) {
                $c += Convert-JsonPlaceholders $p.Value $KeyNameRx
            }
        }
    } elseif ($null -ne $node -and $node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
        foreach ($x in $node) { $c += Convert-JsonPlaceholders $x $KeyNameRx }
    }
    return $c
}

function Convert-ToPlaceholders {
    # 处理目录内全部 .json（键名规则）与 .toml/.ini/.env/.template（行级规则），返回替换处数
    param([Parameter(Mandatory=$true)][string]$Dir)
    $keyNameRx = '(?i)(token|api[_-]?key|secret|authorization|password|credential)'
    $lineRx = '(?i)^(\s*[\w.\-]*(token|api[_-]?key|secret|pat|authorization|password|credential)[\w.\-]*\s*[:=]\s*)["'']?([^"''\r\n]+)["'']?\s*$'
    $count = 0
    $files = @(Get-ChildItem $Dir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -match '^\.(json|toml|ini|env|template)$' -or $_.Name -like '*.env' -or $_.Name -like '*.template'
    })
    foreach ($f in $files) {
        if ($f.Extension -eq ".json") {
            try { $obj = [System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch { continue }
            $c = Convert-JsonPlaceholders $obj $keyNameRx
            $count += $c
            if ($c -gt 0) {
                $out = $obj | ConvertTo-Json -Depth 12
                [System.IO.File]::WriteAllText($f.FullName, $out, (New-Object System.Text.UTF8Encoding($false)))
            }
        } else {
            $lines = [System.IO.File]::ReadAllLines($f.FullName)
            $changed = $false
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].TrimStart().StartsWith("#")) { continue }
                $m = [regex]::Match($lines[$i], $lineRx)
                if ($m.Success) {
                    $lines[$i] = $m.Groups[1].Value + '"<AGENT-SYNC:' + $m.Groups[1].Value.Trim(" :=").Trim('"') + '>"'
                    $count++
                    $changed = $true
                }
            }
            if ($changed) { [System.IO.File]::WriteAllLines($f.FullName, $lines) }
        }
    }
    return $count
}

#endregion R01-CORE
