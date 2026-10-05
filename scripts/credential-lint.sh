#!/usr/bin/env bash
# =====================================================================
# credential-lint.sh — R01 前置构件：导出产物凭证形态扫描（credential-lint.ps1 的 bash 版）
# 用法: bash scripts/credential-lint.sh <路径1> [路径2 ...]   （路径可为文件或目录，目录递归）
# 命中任意模式 -> 退出码 1。输出纪律：只打印 file:line + 模式名，绝不回显密钥值。
# 已知局限：形态 lint 不是万能脱敏——零命中 ≠ 无凭证，仍需人工预览（PRD §10）。
# =====================================================================
set -uo pipefail
[ $# -ge 1 ] || { echo "用法: credential-lint.sh <路径...>"; exit 2; }

declare -A PATTERNS=(
  [OpenAI-style-key]='sk-[A-Za-z0-9_-]{16,}'
  [Anthropic-key]='sk-ant-[A-Za-z0-9_-]{10,}'
  [GitHub-PAT]='gh[pousr]_[A-Za-z0-9]{20,}'
  [GitHub-fine-grained-PAT]='github_pat_[A-Za-z0-9_]{20,}'
  [AWS-AccessKey]='AKIA[0-9A-Z]{16}'
  [Slack-token]='xox[baprs]-[A-Za-z0-9-]{10,}'
  [GitLab-PAT]='glpat-[A-Za-z0-9_-]{16,}'
  [Google-API-key]='AIza[0-9A-Za-z_-]{30,}'
  [Private-key-block]='-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY'
  [JWT]='eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'
  [Lark-app-secret]='app_secret"?\s*[:=]\s*"?[A-Za-z0-9]{16,}'
  [Bearer-token]='[Bb]earer +[A-Za-z0-9_.=-]{24,}'
)

FILES=()
for p in "$@"; do
  if [ -f "$p" ]; then FILES+=("$p")
  elif [ -d "$p" ]; then
    while IFS= read -r -d '' f; do FILES+=("$f"); done < <(find "$p" -type f -size -2M \
      -not -path "*/.git/*" -not -path "*/_backup/*" -not -path "*/node_modules/*" -print0)
  else echo "[跳过] 路径不存在: $p"; fi
done

hits=0
for f in "${FILES[@]}"; do
  for name in "${!PATTERNS[@]}"; do
    if grep -qE -e "${PATTERNS[$name]}" "$f" 2>/dev/null; then
      ln=$(grep -nE -e "${PATTERNS[$name]}" "$f" 2>/dev/null | head -1 | cut -d: -f1)
      echo "[命中] $f:${ln:-?} [$name]"
      hits=$((hits+1))
      break
    fi
  done
done

echo ""
if [ "$hits" -gt 0 ]; then
  echo "[结果] 命中 $hits 个文件 —— ASP-E-LINT-001：按 DST-P0-02 中止导出（退出码 5）。"
  exit 5
fi
echo "[结果] 零命中。注意：形态 lint 不是万能脱敏，发布前仍需人工预览（PRD §10）。"
exit 0
