#!/usr/bin/env bash
# =====================================================================
# asp.sh - AI 冷启动包 (Agent Starter Pack) 安装/更新器 (macOS / Linux)
# 用法: ./asp.sh [install|update|detect|agents|status] [pack] [dir]
# 依赖: bash + curl/unzip/shasum（系统自带）+ python3（JSON 处理）
# =====================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="${1:-install}"
PACK="${2:-}"
TARGET_DIR="${3:-}"
STATE_FILE="$ROOT/_state.json"
BACKUP_DIR="$ROOT/_backup"
BEGIN_MARK="<!-- asp:begin -->"
END_MARK="<!-- asp:end -->"

py() { command -v python3 >/dev/null 2>&1 || { echo "[错误] 需要 python3（macOS/Linux 通常自带）"; exit 1; }; python3 "$@"; }

# read_adapters 的 python 段加 enabled 过滤
read_adapters() {
  py - "$ROOT/adapters" <<'PYEOF'
import json, sys, glob, os
ad = sys.argv[1]
for f in sorted(glob.glob(os.path.join(ad, "*.json"))):
    a = json.load(open(f, encoding="utf-8"))
    if a.get("enabled") is False:
        continue
    instr = a.get("instructions", {}); mcp = a.get("mcp", {})
    row = [a["id"], a["name"], ",".join(a.get("detect", [])),
           a.get("skills_dir", ""), instr.get("mode", ""), instr.get("target", ""),
           instr.get("filename", ""), mcp.get("strategy", ""), mcp.get("target", ""),
           mcp.get("key", ""), mcp.get("template", ""), mcp.get("requires", "")]
    print("|".join(row))
PYEOF
}

expand_tilde() { case "$1" in "~") echo "$HOME";; "~/"*) echo "$HOME/${1#~/}";; *) echo "$1";; esac; }

detect_agents() {
  local found=""
  while IFS='|' read -r id name detect skills_dir imode itarget ifname mstrat mtarget mkey mtmpl mreq; do
    IFS=',' read -ra DPS <<< "$detect"
    for d in "${DPS[@]}"; do
      [ -z "$d" ] && continue
      if [ -e "$(expand_tilde "$d")" ]; then found+="$id|$name|$skills_dir|$imode|$itarget|$ifname|$mstrat|$mtarget|$mkey|$mtmpl|$mreq"$'\n'; break; fi
    done
  done < <(read_adapters)
  echo "$found"
}

backup_file() {
  [ -f "$1" ] || return 0
  mkdir -p "$BACKUP_DIR"
  cp "$1" "$BACKUP_DIR/$(basename "$1").$(date +%Y%m%d-%H%M%S).bak"
}

# managed-section 合并（python3 保证多行内容可靠处理）
deploy_managed() { # $1=content_file $2=target
  py - "$1" "$2" "$BEGIN_MARK" "$END_MARK" <<'PYEOF'
import sys, os
content, target, begin, end = open(sys.argv[1], encoding="utf-8").read(), sys.argv[2], sys.argv[3], sys.argv[4]
section = f"{begin}\n{content}\n{end}"
if os.path.exists(target):
    raw = open(target, encoding="utf-8").read()
    if begin in raw:
        head, rest = raw.split(begin, 1)
        _, tail = rest.split(end, 1) if end in rest else ("", "")
        open(target, "w", encoding="utf-8").write(head + section + tail)
        print("updated")
    else:
        open(target, "a", encoding="utf-8").write("\n" + section)
        print("appended")
else:
    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    open(target, "w", encoding="utf-8").write(section)
    print("created")
PYEOF
}

# MCP merge：仅新增键，不覆盖已有（python3 JSON 处理）
merge_mcp() { # $1=template $2=target $3=keypath $4=requires
  [ -f "$1" ] || { echo "note=无模板"; return; }
  if [ -n "$4" ] && ! command -v "$4" >/dev/null 2>&1; then echo "note=跳过：未检测到 $4"; return; fi
  [ -f "$2" ] && backup_file "$2"
  py - "$1" "$2" "$3" <<'PYEOF'
import json, sys
tpl, target, keypath = sys.argv[1], sys.argv[2], sys.argv[3]
servers = json.load(open(tpl, encoding="utf-8")).get("servers", {})
cfg = json.load(open(target, encoding="utf-8")) if __import__("os").path.exists(target) else {}
container = cfg
for k in keypath.split("."):
    container = container.setdefault(k, {})
added, skipped = [], []
for name, val in servers.items():
    if name in container: skipped.append(name)
    else: container[name] = val; added.append(name)
json.dump(cfg, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"added={','.join(added) or '-'};skipped={','.join(skipped) or '-'}")
PYEOF
}

show_guide() {
  echo "  未检测到任何受支持的 AI agent。安装任一后重新运行本包即可："
  echo "    Claude Code       https://claude.com/product/claude-code"
  echo "    Codex             https://developers.openai.com/codex/"
  echo "    Cursor            https://cursor.com"
  echo "    opencode          https://opencode.ai"
  echo "    DeepSeek Harness  https://github.com/deepseek-ai/deepseek-harness"
  echo "    Zcode             https://zcode.ai"
}

do_install() {
  local pack="${1:-ai-pm}"
  local packdir="$ROOT/packs/$pack"
  [ -d "$packdir" ] || { echo "[错误] 不存在包: $pack"; exit 1; }
  echo "[探测] 扫描本机 AI agent..."
  local found; found="$(detect_agents)"
  [ -z "$found" ] && { show_guide; exit 0; }
  local names; names="$(echo "$found" | awk -F'|' '{printf "%s  ", $2}')"
  echo "[探测] 发现: $names"
  read -r -p "[确认] 全部安装? (Y/n) " ans
  [ -n "$ans" ] && [ "${ans,,}" != "y" ] && { echo "已取消。"; exit 0; }
  local installed_agents=""
  while IFS='|' read -r id name skills_dir imode itarget ifname mstrat mtarget mkey mtmpl mreq; do
    [ -z "$id" ] && continue
    echo "==> 部署到 $name"
    if [ -d "$packdir/skills" ] && [ -n "$skills_dir" ]; then
      dst="$(expand_tilde "$skills_dir")"; mkdir -p "$dst"
      find "$packdir/skills" -mindepth 1 -maxdepth 1 -type d ! -name "_*" -exec cp -R {} "$dst" \;
      echo "    skills -> $dst"
    fi
    if [ "$imode" = "managed-section" ] && [ -n "$itarget" ]; then
      r=$(deploy_managed "$packdir/AGENTS.md" "$(expand_tilde "$itarget")")
      echo "    AGENTS.md -> $itarget ($r)"
    elif [ "$imode" = "workspace" ]; then
      echo "    AGENTS.md: workspace 级，稍后运行 './asp.sh agents <项目目录>' 部署"
    fi
    if [ "$mstrat" = "merge" ]; then
      r=$(merge_mcp "$packdir/mcp/$mtmpl" "$(expand_tilde "$mtarget")" "$mkey" "$mreq")
      echo "    MCP: $r"
    elif [ "$mstrat" = "template-only" ]; then
      echo "    MCP: 该 agent 默认不启用 MCP，模板与启用步骤见包内 mcp/ 目录"
    fi
    installed_agents+="$id "
  done <<< "$found"
  cat > "$STATE_FILE" <<EOF
{"pack": "$pack", "version": "dev", "installed_at": "$(date -Iseconds)", "agents": "$installed_agents"}
EOF
  echo "======================================="
  echo " 安装完成。重启你的 agent 后生效。"
  echo " 回滚: 备份在 _backup/"
  echo " 周更: 双击 update.command（或 ./asp.sh update）"
  echo "======================================="
}

do_agents() { # $1=pack $2=dir
  local pack="${1:-ai-pm}" dir="${2:-$PWD}"
  local packdir="$ROOT/packs/$pack"
  while IFS='|' read -r id name skills_dir imode itarget ifname mstrat mtarget mkey mtmpl mreq; do
    [ -z "$id" ] && continue
    if [ "$imode" = "workspace" ]; then
      r=$(deploy_managed "$packdir/AGENTS.md" "$dir/$ifname")
      echo "$name: $dir/$ifname ($r)"
    fi
  done < <(read_adapters)
}

do_update() {
  local pack="${1:-}"
  [ -z "$pack" ] && pack=$(py -c "import json,os;s=json.load(open('$STATE_FILE'))['pack'] if os.path.exists('$STATE_FILE') else 'ai-pm';print(s)" 2>/dev/null || echo "ai-pm")
  local idx="$ROOT/registry/index.json"
  [ -f "$idx" ] || { echo "[错误] 缺少 registry/index.json"; exit 1; }
  local mirrors; mirrors=$(py -c "import json;print('\n'.join(json.load(open('$idx'))['mirrors']))")
  if echo "$mirrors" | grep -q "REPLACE"; then
    echo "[提示] registry 托管地址尚未配置（开发快照，无需更新）。"; exit 0
  fi
  local remote=""
  for m in $mirrors; do
    echo "[更新] 尝试源: $m"
    if remote=$(curl -sf --max-time 3 "$m/index.json"); then break; fi
    echo "  源不可达，切换下一个..."
  done
  [ -z "$remote" ] && { echo "[错误] 所有更新源均不可达。"; exit 1; }
  echo "$remote" > /tmp/asp-index.json
  local rver lver
  rver=$(py -c "import json;print(json.load(open('/tmp/asp-index.json'))['packs']['$pack']['version'])")
  lver=$(py -c "import json,os;print(json.load(open('$STATE_FILE')).get('version','none')) if os.path.exists('$STATE_FILE') else print('none')")
  echo "[版本] 本地 $lver -> 远程 $rver"
  [ "$lver" = "$rver" ] && { echo "已是最新。"; exit 0; }
  local ziprel shaval url
  ziprel=$(py -c "import json;print(json.load(open('/tmp/asp-index.json'))['packs']['$pack']['zip'])")
  shaval=$(py -c "import json;print(json.load(open('/tmp/asp-index.json'))['packs']['$pack']['sha256'])")
  url=$(echo "$mirrors" | head -1 | sed 's:/*$::')"/$ziprel"
  curl -sf -o /tmp/asp-pack.zip "$url" || { echo "[错误] 下载失败"; exit 1; }
  local actual; actual=$(shasum -a 256 /tmp/asp-pack.zip | awk '{print $1}')
  [ "$actual" != "$shaval" ] && { echo "[错误] 哈希校验失败，已中止。"; exit 1; }
  rm -rf /tmp/asp-staging && mkdir -p /tmp/asp-staging && unzip -q -o /tmp/asp-pack.zip -d /tmp/asp-staging
  for part in packs adapters; do
    [ -d "/tmp/asp-staging/$part" ] && { rm -rf "$ROOT/$part"; cp -R "/tmp/asp-staging/$part" "$ROOT/$part"; }
  done
  [ -f /tmp/asp-staging/asp.sh ] && cp /tmp/asp-staging/asp.sh "$ROOT/asp.sh" && chmod +x "$ROOT/asp.sh"
  py - "$STATE_FILE" "$rver" <<'PYEOF'
import json, sys
f, ver = sys.argv[1], sys.argv[2]
import os
s = json.load(open(f)) if os.path.exists(f) else {}
s["version"] = ver
json.dump(s, open(f, "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
  echo "[完成] 已更新到 $rver，正在重新部署..."
  do_install "$pack"
}

case "$COMMAND" in
  install) do_install "$PACK" ;;
  update)  do_update "$PACK" ;;
  detect)  found="$(detect_agents)"; [ -z "$found" ] && show_guide || echo "$found" | awk -F'|' '{printf "  %-16s %s\n", $2, $1}' ;;
  agents)  do_agents "$PACK" "$TARGET_DIR" ;;
  status)  [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "尚未安装任何包。" ;;
  *) echo "用法: ./asp.sh [install|update|detect|agents|status] [pack] [dir]"; exit 1 ;;
esac
