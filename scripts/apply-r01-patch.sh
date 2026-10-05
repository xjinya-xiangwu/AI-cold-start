#!/usr/bin/env bash
# =====================================================================
# apply-r01-patch.sh — 把 R01/D18 接入 asp.sh export 流程（幂等、锚点校验、失配即中止）
# 前置：apply-r00-patch.sh 已执行；credential-lint.sh 已在 scripts/。
# 用法: bash scripts/apply-r01-patch.sh [目标 asp.sh 路径]
# =====================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$REPO/asp.sh}"
[ -f "$TARGET" ] || { echo "[错误] 找不到目标文件: $TARGET"; exit 1; }

if grep -q "R01 接入\|ASP_EXPORT_STAGING" "$TARGET"; then
  echo "[跳过] asp.sh 已含 R01 补丁（幂等）。"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$TARGET" "$WORK/asp.sh"

ANCHOR='  local outfile="${out:-$PWD/asp-env-$stamp.tar.gz}"'
grep -qF 'local outfile="${out:-$PWD/asp-env-$stamp.tar.gz}"' "$WORK/asp.sh" || {
  echo "[中止] 未找到锚点（export 打包行，文件可能已变更，禁止盲改）"; exit 1
}

# 占位符文案（两处，同一短语）
old_note="包内 MCP 配置可能含 API key，请妥善保管"
new_note="凭证值已替换为 <AGENT-SYNC:*> 占位符（R01/D18），由 Agent-sync age 通道补值"
note_count=$(grep -cF "$old_note" "$WORK/asp.sh" || true)
[ "$note_count" -ge 2 ] || { echo "[中止] 文案锚点不足（$note_count/2 处）"; exit 1; }

python3 - "$WORK/asp.sh" "$old_note" "$new_note" <<'PYR01PATCH'
import sys
fp, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(fp, encoding="utf-8").read().splitlines()
out = []
inserted = False
INSERT = '''  # R01 接入（D18/N2）：凭证值 -> 占位符，lint 零命中才打包；报警即中止，不留半成品
  [ -f "$ROOT/scripts/credential-lint.sh" ] || { echo "[中止] 缺 scripts/credential-lint.sh（R01 依赖）"; rm -rf "$staging"; exit 1; }
  ASP_EXPORT_STAGING="$staging" python3 - <<'ASPR01PY'
import json, os, re
st = os.environ["ASP_EXPORT_STAGING"]
key_re = re.compile(r"(?i)^(\\s*[\\w.\\-]*(token|api[_-]?key|secret|pat|authorization|password|credential)[\\w.\\-]*\\s*[:=]\\s*)(.+?)\\s*$")
n = 0
for root, _, files in os.walk(st):
    for fn in files:
        p = os.path.join(root, fn)
        if fn.endswith(".json"):
            try:
                obj = json.load(open(p, encoding="utf-8"))
            except Exception:
                continue
            changed = [False]
            def walk(o):
                if isinstance(o, dict):
                    for k in list(o.keys()):
                        v = o[k]
                        if re.search(r"(?i)(token|api[_-]?key|secret|pat\\b|authorization|password|credential)", k) and isinstance(v, str) and v and not v.startswith("<AGENT-SYNC:"):
                            o[k] = "<AGENT-SYNC:" + k + ">"
                            n += 1
                            changed[0] = True
                        walk(v)
                elif isinstance(o, list):
                    for x in o:
                        walk(x)
            walk(obj)
            if changed[0]:
                json.dump(obj, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        else:
            try:
                lines = open(p, encoding="utf-8").read().splitlines(True)
            except Exception:
                continue
            changed = False
            for i, ln in enumerate(lines):
                if ln.lstrip().startswith("#"):
                    continue
                m = key_re.match(ln)
                if m:
                    lines[i] = m.group(1) + '"<AGENT-SYNC:' + m.group(1).strip(" :=\\"'") + '>"\\n'
                    n += 1
                    changed = True
            if changed:
                open(p, "w", encoding="utf-8").writelines(lines)
print("  [R01] 占位符替换:", n, "处")
ASPR01PY
  if ! bash "$ROOT/scripts/credential-lint.sh" "$staging"; then
    echo "[中止] 导出产物命中凭证形态（PRD N2）。已清理暂存，未生成任何输出文件。"
    rm -rf "$staging"
    exit 1
  fi'''
for ln in lines:
    if ln == '  local outfile="${out:-$PWD/asp-env-$stamp.tar.gz}"' and not inserted:
        out.append(INSERT)
        out.append(ln)
        inserted = True
    else:
        out.append(ln.replace(old, new))
if not inserted:
    sys.stderr.write("[中止] 打包行锚点未命中\n")
    sys.exit(1)
open(fp, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("[完成] asp.sh 已接入 R01。")
PYR01PATCH

BK="$REPO/_backup/asp.sh.preR01-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPO/_backup"
cp "$TARGET" "$BK"
cp "$WORK/asp.sh" "$TARGET"
echo "原文件备份: $BK"
echo "下一步: 真机跑 TC-R01-01。"
