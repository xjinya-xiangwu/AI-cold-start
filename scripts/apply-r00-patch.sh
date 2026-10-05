#!/usr/bin/env bash
# =====================================================================
# apply-r00-patch.sh — 把 R00/R03 修复接入 asp.sh（幂等、锚点校验、失配即中止）
# 用法（在 ai-cold-start 仓库根目录）: bash scripts/apply-r00-patch.sh [目标 asp.sh 路径]
# 行为: 定位两个接入点（install 复制 / doctor 嵌套扫描），全部命中才修改；
#       修改前备份到 _backup/asp.sh.preR00-<时间戳>；已打过补丁则跳过。
# =====================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$REPO/asp.sh}"
[ -f "$TARGET" ] || { echo "[错误] 找不到目标文件: $TARGET"; exit 1; }

if grep -q "R00/R03 接入\|safe_copy_skill -R00" "$TARGET"; then
  echo "[跳过] asp.sh 已含 R00 补丁（幂等）。"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$TARGET" "$WORK/asp.sh"

# --- 锚点 1: install 复制（替换裸 cp -R 行）---
ANCHOR1='find "$packdir/skills" -mindepth 1 -maxdepth 1 -type d ! -name "_*" -exec cp -R {} "$dst" \;'
if ! grep -qF 'exec cp -R {} "$dst"' "$WORK/asp.sh"; then
  echo "[中止] 未找到锚点1（install 复制行，文件可能已变更，禁止盲改）"; exit 1
fi
# 用 python 做行级精确替换（转义最少、跨 GNU/BSD sed 行为一致）
REPO="$REPO" python3 - "$WORK/asp.sh" <<'PYEOF'
import os, sys
fp = sys.argv[1]
lines = open(fp, encoding="utf-8").read().splitlines()
out = []
done1 = done2 = False
for ln in lines:
    if 'exec cp -R {} "$dst"' in ln and not done1:
        indent = ln[:len(ln) - len(ln.lstrip())]
        out.append(indent + '# R00：同名技能目录先备份再逐项覆盖（评审复现缺陷：裸 cp -R 无备份覆盖；未知用户文件保留）')
        out.append(indent + 'for _sk in "$packdir"/skills/*/; do')
        out.append(indent + '  [ -d "$_sk" ] || continue')
        out.append(indent + '  _skn="$(basename "$_sk")"; case "$_skn" in _*) continue ;; esac')
        out.append(indent + '  _tdst="$dst/$_skn"')
        out.append(indent + '  if [ -d "$_tdst" ]; then')
        out.append(indent + '    _bk="$dst/_backup/${_skn}-$(date +%Y%m%d-%H%M%S)"')
        out.append(indent + '    mkdir -p "$_bk"; cp -Rp "$_tdst/." "$_bk/" && echo "    备份: $_skn -> $_bk"')
        out.append(indent + '  fi')
        out.append(indent + '  mkdir -p "$_tdst"; cp -Rp "$_sk"/. "$_tdst/"')
        out.append(indent + 'done')
        done1 = True
    elif 'MCP 流量灯体检——对已部署配置逐条做真实 initialize 握手' in ln and not done2:
        out.append(ln)
        out.append('  # R00/R03 接入：嵌套技能目录检测（历史缺陷签名；doctor 只报告，不自动清理）')
        out.append('  _da="$(detect_agents)"')
        out.append('  while IFS=\'|\' read -r _id _name _skills_dir _rest; do')
        out.append('    [ -z "$_id" ] && continue; [ -z "$_skills_dir" ] && continue')
        out.append('    _sd="$(expand_tilde "$_skills_dir")"; [ -d "$_sd" ] || continue')
        out.append('    for _d in "$_sd"/*/; do')
        out.append('      [ -d "$_d" ] || continue')
        out.append('      _dn="$(basename "$_d")"')
        out.append('      [ -d "$_sd/$_dn/$_dn" ] && echo "  ⚠ $_name · 技能目录嵌套(历史缺陷): $_dn/$_dn —— 修复见 docs/P0-R00-INTEGRATION.md"')
        out.append('    done')
        out.append('  done <<ASPR00EOF')
        out.append('$_da')
        out.append('ASPR00EOF')
        done2 = True
    else:
        out.append(ln)
if not done1 or not done2:
    missing = []
    if not done1: missing.append("install 复制行")
    if not done2: missing.append("doctor 插入点")
    sys.stderr.write("[中止] 未找到锚点: " + ", ".join(missing) + "\n")
    sys.exit(1)
open(fp, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
PYEOF

BK="$REPO/_backup/asp.sh.preR00-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPO/_backup"
cp "$TARGET" "$BK"
cp "$WORK/asp.sh" "$TARGET"
echo "[完成] asp.sh 已接入 R00/R03 修复。原文件备份: $BK"
echo "下一步: 运行 docs/qa/TEST-CASES-P0.md 真机用例（TC-R00-03 起）。"
