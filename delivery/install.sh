#!/usr/bin/env bash
set -euo pipefail
PACKAGE_ROOT="$(cd "$(dirname "$0")" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "需要 python3；请先安装，再重试。"; exit 1; }
python3 - "$PACKAGE_ROOT" <<'VERIFY'
import hashlib,json,sys
from pathlib import Path
root=Path(sys.argv[1]);app=(root/'app').resolve()
manifest=json.loads((root/'app-integrity.json').read_text('utf-8'))
for rel,expected in manifest.items():
    f=(app/rel).resolve()
    if not f.is_relative_to(app) or not f.is_file():raise SystemExit('完整性清单路径错误')
    if hashlib.sha256(f.read_bytes()).hexdigest()!=expected:raise SystemExit('包文件校验失败: '+rel)
VERIFY
SKU="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sku"])' "$PACKAGE_ROOT/delivery-manifest.json")"
case "$SKU" in base|ai-pm) ;; *) echo "无效的已购内容标识"; exit 1 ;; esac
DEST="$HOME/asp-coldstart/app-$SKU"
mkdir -p "$DEST"
python3 - "$PACKAGE_ROOT/app" "$DEST" <<'PY'
import shutil,sys
from pathlib import Path
src,dst=map(Path,sys.argv[1:])
for f in src.rglob('*'):
    if not f.is_file(): continue
    rel=f.relative_to(src)
    if rel.parts[0] in ('_backup','_skill-state','_state.json'): continue
    target=dst/rel
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(f,target)
PY
if [ "${ASP_NONINTERACTIVE:-0}" = 1 ]; then export ASP_CONFIRMED=1; fi
bash "$DEST/asp.sh" install "$SKU"
