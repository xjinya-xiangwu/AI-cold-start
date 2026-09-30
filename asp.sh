#!/usr/bin/env bash
# =====================================================================
# asp.sh - AI 冷启动包 (Agent Starter Pack) 安装/更新器 + 环境迁移 (macOS / Linux)
# 用法: ./asp.sh [install|update|detect|agents|status|export|migrate] [pack] [dir]
# 依赖: bash + curl/unzip/tar/sha256sum（系统自带）+ python3（JSON 处理）
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

expand_tilde() {
  # 注意：${1#~/} 在 bash 中会因模式内 tilde 展开而失效（~/ 被展开成 $HOME/），故用子串截断
  case "$1" in
    "~") echo "$HOME" ;;
    "~/"*) echo "$HOME/${1:2}" ;;
    *) echo "$1" ;;
  esac
}

# 读取 adapter 显式声明的迁移资产（migrate.files / migrate.dirs），供 export 收集
read_migrate() {
  py - "$ROOT/adapters" <<'PYEOF'
import json, sys, glob, os
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    a = json.load(open(f, encoding="utf-8"))
    mg = a.get("migrate") or {}
    files = ",".join(mg.get("files", []) or [])
    dirs = ",".join(mg.get("dirs", []) or [])
    if files or dirs:
        print(f"{a['id']}|{files}|{dirs}")
PYEOF
}

hash_file() { # $1=路径 -> sha256（sha256sum 优先，mac 回退 shasum）
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

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
  local pack="${1:-base}"
  local packdir="$ROOT/packs/$pack"
  [ -d "$packdir" ] || { echo "[错误] 不存在包: $pack"; exit 1; }
  echo "[探测] 扫描本机 AI agent..."
  local found; found="$(detect_agents)"
  [ -z "$found" ] && { show_guide; exit 0; }
  local names; names="$(echo "$found" | awk -F'|' '{printf "%s  ", $2}')"
  echo "[探测] 发现: $names"
  # 多包依赖链安装时只确认一次（v0.5.0 分层）
  if [ -z "${ASP_CONFIRMED:-}" ]; then
    read -r -p "[确认] 全部安装? (Y/n) " ans
    [ -n "$ans" ] && [ "${ans,,}" != "y" ] && { echo "已取消。"; exit 0; }
    ASP_CONFIRMED=1
  fi
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
    if [ "$mstrat" = "merge" ] && [ -d "$packdir/mcp" ]; then
      r=$(merge_mcp "$packdir/mcp/$mtmpl" "$(expand_tilde "$mtarget")" "$mkey" "$mreq")
      echo "    MCP: $r"
    elif [ "$mstrat" = "merge" ]; then
      :  # 专业包无 mcp 目录（MCP 归属 base 包），跳过
    elif [ "$mstrat" = "template-only" ]; then
      echo "    MCP: 该 agent 默认不启用 MCP，模板与启用步骤见包内 mcp/ 目录"
    fi
    installed_agents+="$id "
  done <<< "$found"
  # state packs 累加（v0.5.0 分层）
  ASP_PACK="$pack" ASP_STATE="$STATE_FILE" py <<'PYEOF'
import json, os, datetime
f = os.environ["ASP_STATE"]; pack = os.environ["ASP_PACK"]
s = json.load(open(f, encoding="utf-8")) if os.path.exists(f) else {}
packs = s.get("packs", [])
if pack not in packs: packs.append(pack)
s.update({"packs": packs, "pack": pack, "version": s.get("version", "dev"),
          "installed_at": datetime.datetime.now().astimezone().isoformat()})
json.dump(s, open(f, "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
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

# 包依赖解析（v0.5.0 分层：专业包依赖 base）
resolve_deps() { # $1=pack -> 输出安装顺序链
  local deps
  deps=$(py - "$ROOT/packs/$1/deps.json" <<'PYEOF'
import json, sys, os
f = sys.argv[1]
print(" ".join(json.load(open(f, encoding="utf-8")).get("requires", [])) if os.path.exists(f) else "")
PYEOF
)
  echo "$deps $1"
}

# ---------- 环境迁移（v0.6.0）：export / migrate ----------
do_export() { # $1=输出路径（缺省 ./asp-env-<时间戳>.tar.gz）
  local out="${1:-}"
  local found; found="$(detect_agents)"
  [ -z "$found" ] && { show_guide; exit 0; }
  echo "[探测] 发现: $(echo "$found" | awk -F'|' '{printf "%s  ", $2}')"
  local stamp; stamp=$(date +%Y%m%d-%H%M%S)
  local staging; staging="$(mktemp -d)/asp-mig"
  mkdir -p "$staging/home"
  local cand="$staging/.candidates.txt"; : > "$cand"
  # adapter 已知路径
  while IFS='|' read -r id name skills_dir imode itarget ifname mstrat mtarget mkey mtmpl mreq; do
    [ -z "$id" ] && continue
    [ -n "$skills_dir" ] && [ -d "$(expand_tilde "$skills_dir")" ] && echo -e "dir\t$id\t${skills_dir#"~/"}" >> "$cand"
    [ "$imode" = "managed-section" ] && [ -n "$itarget" ] && [ -f "$(expand_tilde "$itarget")" ] && echo -e "file\t$id\t${itarget#"~/"}" >> "$cand"
    [ "$mstrat" = "merge" ] && [ -n "$mtarget" ] && [ -f "$(expand_tilde "$mtarget")" ] && echo -e "file\t$id\t${mtarget#"~/"}" >> "$cand"
    case "$id" in
      zcode) [ -d "$HOME/.zcode/cli/memories" ] && echo -e "dir\tzcode\t.zcode/cli/memories" >> "$cand" ;;
      kimi)  [ -f "$HOME/.kimi_openclaw/workspace/AGENTS.md" ] && echo -e "file\tkimi\t.kimi_openclaw/workspace/AGENTS.md" >> "$cand" ;;
    esac
  done <<< "$found"
  # adapter 显式声明的迁移资产（trae/qoder/workbuddy 等）
  while IFS='|' read -r id files dirs; do
    [ -z "$id" ] && continue
    IFS=',' read -ra FS <<< "$files"
    for f in "${FS[@]}"; do [ -n "$f" ] && [ -f "$(expand_tilde "$f")" ] && echo -e "file\t$id\t${f#"~/"}" >> "$cand"; done
    IFS=',' read -ra DS <<< "$dirs"
    for d in "${DS[@]}"; do [ -n "$d" ] && [ -d "$(expand_tilde "$d")" ] && echo -e "dir\t$id\t${d#"~/"}" >> "$cand"; done
  done <<< "$(read_migrate)"
  # 复制进包；按一级子项拆分记账（单 skill 粒度 → 还原端按 ≤20MB 默认/超大可选分级）
  local n=0 cand2="$staging/.items.txt" ovfile="$staging/.oversized.txt"; : > "$cand2"; : > "$ovfile"
  while IFS=$'\t' read -r kind agent rel; do
    [ -z "${rel:-}" ] && continue
    local src="$HOME/$rel" dst="$staging/home/$rel"
    if [ "$kind" = "dir" ]; then
      [ -L "$src" ] && src="$(readlink -f "$src" 2>/dev/null || readlink "$src")"
      [ -d "$src" ] || { echo "  $agent: 跳过(非目录)  $rel"; continue; }
      [ -z "$(ls -A "$src" 2>/dev/null)" ] && { echo "  $agent: dir(空) 跳过  $rel"; continue; }
      # 逐个一级子项（单 skill 粒度）：默认只收 ≤20MB；超大项记录待用户勾选
      for child in "$src"/*; do
        local cname crel dstChild cn cb
        cname=$(basename "$child"); crel="$rel/$cname"; dstChild="$staging/home/$crel"
        if [ -d "$child" ]; then
          mkdir -p "$dstChild"
          (cd "$child" && find . -type d \( -name node_modules -o -name .git -o -name __pycache__ -o -name .venv -o -name venv -o -name .cache -o -name .pytest_cache \) -prune -o -type f ! -name "*.pyc" -print) | while IFS= read -r f; do
            mkdir -p "$dstChild/$(dirname "$f")"; cp "$child/$f" "$dstChild/$f"
          done
          cn=$(find "$dstChild" -type f 2>/dev/null | wc -l)
          if [ "$cn" -eq 0 ]; then rm -rf "$dstChild"; continue; fi
          cb=$(( $(du -sk "$dstChild" | cut -f1) * 1024 ))
          if [ "$cb" -gt $((20*1024*1024)) ]; then
            rm -rf "$dstChild"
            echo -e "$agent\t$crel\t$cn\t$cb" >> "$OVFILE"
            echo "  $agent: 超大项(默认不入包)  $crel  $((cb/1024)) MB"
            continue
          fi
          echo -e "dir\t$agent\t$crel\t$cn\t$cb" >> "$cand2"
        else
          mkdir -p "$(dirname "$dstChild")"; cp "$child" "$dstChild"
          echo -e "file\t$agent\t$crel\t1\t$(wc -c < "$dstChild" | tr -d ' ')" >> "$cand2"
        fi
      done
      echo "  $agent: dir  $rel"; n=$((n+1)); continue
    fi
    mkdir -p "$staging/home/$(dirname "$rel")"
    cp -R "$src" "$dst"
    echo -e "file\t$agent\t$rel\t1\t$(wc -c < "$dst" | tr -d ' ')" >> "$cand2"
    echo "  $agent: file  $rel"; n=$((n+1))
  done < "$cand"
  # 超大子项：列出供用户勾选（ASP_EXPORT_OVERSIZED=1 全含；确认模式 -Yes/非交互全不含）
  if [ -s "$ovfile" ]; then
    echo "[超大项] 以下超过 20MB，默认不入包:"
    local i=1 pick_str=""
    while IFS=$'\t' read -r agent rel files bytes; do echo "  $i. [$agent] $rel  $((bytes/1024)) MB / $files 文件"; i=$((i+1)); done < "$ovfile"
    if [ "${ASP_EXPORT_OVERSIZED:-0}" = "1" ]; then pick_str="$(seq -s, 1 $((i-1)))"
    elif [ -z "${ASP_MIG_YES:-}" ]; then read -r -p "[选择] 包含哪些超大项? 回车=都不含，或编号如 1,2: " pick_str; fi
    if [ -n "$pick_str" ]; then
      IFS=',' read -ra PKS <<< "$pick_str"
      local total; total=$((i-1))
      for p in "${PKS[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        case "$p" in ''|*[!0-9]*) continue;; esac
        [ "$p" -lt 1 ] || [ "$p" -gt "$total" ] && continue
        local row; row="$(sed -n "${p}p" "$ovfile")"
        IFS=$'\t' read -r agent rel files bytes <<< "$row"
        local psrc="$HOME/$rel" pdst="$staging/home/$rel"; mkdir -p "$pdst"
        (cd "$psrc" && find . -type d \( -name node_modules -o -name .git -o -name __pycache__ -o -name .venv -o -name venv -o -name .cache -o -name .pytest_cache \) -prune -o -type f ! -name "*.pyc" -print) | while IFS= read -r f; do
          mkdir -p "$pdst/$(dirname "$f")"; cp "$psrc/$f" "$pdst/$f"
        done
        echo -e "dir\t$agent\t$rel\t$files\t$bytes" >> "$cand2"
        echo "  $agent: 已含超大项  $rel"
      done
    fi
  fi
  mv "$cand2" "$cand"
  [ "$n" -eq 0 ] && { echo "[提示] 未收集到任何可迁移文件。"; exit 0; }
  # manifest（python3 生成：子项条目带 files/bytes，还原端做 20MB 分级）
  ASP_STAGING="$staging" ASP_CAND="$cand" py <<'PYEOF'
import json, os, hashlib, datetime
st = os.environ["ASP_STAGING"]; home = os.path.join(st, "home")
items = []
for line in open(os.environ["ASP_CAND"], encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 3: continue
    kind, agent, rel = parts[0], parts[1], parts[2].replace(os.sep, "/")
    files = int(parts[3]) if len(parts) > 3 and parts[3] else 0
    bytes_ = int(parts[4]) if len(parts) > 4 and parts[4] else 0
    p = os.path.join(home, rel)
    if kind == "dir":
        if files: items.append({"agent": agent, "type": "dir", "rel": rel, "files": files, "bytes": bytes_})
    else:
        if os.path.exists(p):
            items.append({"agent": agent, "type": "file", "rel": rel, "sha256": hashlib.sha256(open(p, "rb").read()).hexdigest(), "bytes": bytes_})
mf = {"tool": "asp", "tool_version": "0.6.0", "kind": "asp-env-migration",
      "created_at": datetime.datetime.now().astimezone().isoformat(), "host": {"os": "mac/linux"},
      "items": items, "note": "merge 语义：还原只增改不删除；单项 ≤20MB 默认同步，超大项还原时可选；包内 MCP 配置可能含 API key，请妥善保管"}
json.dump(mf, open(os.path.join(st, "manifest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(os.path.join(st, "README-MIGRATE.txt"), "w", encoding="utf-8").write(
  "asp 环境迁移包。还原: 新机器 asp 目录下 ./asp.sh migrate <本包路径>\n"
  "还原时自动检测本机 agent 并可选择导入哪些客户端；单项 ≤20MB 默认同步，超大项按提示勾选。\n"
  "注意: 包内 MCP 配置可能含 API key，请妥善保管；还原为 merge 语义（不删除目标已有文件）。")
PYEOF
  local outfile="${out:-$PWD/asp-env-$stamp.tar.gz}"
  tar -czf "$outfile" -C "$staging" .
  rm -rf "$(dirname "$staging")"
  echo "[完成] 迁移包: $outfile"
  echo "  还原: 新机器 asp 目录下  ./asp.sh migrate \"$outfile\""
  echo "  ⚠ 包内可能含 API key（MCP 配置），请妥善保管。"
}

do_migrate() { # $1=迁移包路径（tar.gz/zip/目录）；env: ASP_MIG_YES / ASP_MIG_ALL / ASP_MIG_OVERSIZED / ASP_MIG_DRYRUN
  local pkg="${1:-}"
  [ -z "$pkg" ] && read -r -p "[输入] 迁移包路径 (tar.gz / zip / 已解压目录): " pkg
  [ -z "$pkg" ] && { echo "[错误] 未提供迁移包路径"; exit 1; }
  [ -e "$pkg" ] || { echo "[错误] 找不到: $pkg"; exit 1; }
  local staging; staging="$(mktemp -d)/asp-mig"
  mkdir -p "$staging"
  if [ -d "$pkg" ]; then cp -R "$pkg/." "$staging/"
  elif [[ "$pkg" == *.tar.gz || "$pkg" == *.tgz ]]; then tar -xzf "$pkg" -C "$staging"
  elif [[ "$pkg" == *.zip ]]; then unzip -q -o "$pkg" -d "$staging"
  else echo "[错误] 仅支持 tar.gz / zip / 已解压目录"; exit 1; fi
  [ -f "$staging/manifest.json" ] || { echo "[错误] 包内缺少 manifest.json（不是 asp 迁移包？）"; exit 1; }

  # ① 自动检测本机 agent，选择导入哪些客户端
  local found; found="$(detect_agents)"
  [ -z "$found" ] && { show_guide; exit 0; }
  echo "[检测] 本机已装: $(echo "$found" | awk -F'|' '{printf "%s ", $2}')"
  local selected
  if [ "${ASP_MIG_ALL:-0}" = "1" ]; then
    selected="$(echo "$found" | cut -d'|' -f1 | tr '\n' ' ')"
  elif [ "${ASP_MIG_YES:-0}" = "1" ]; then
    selected="$(echo "$found" | cut -d'|' -f1 | tr '\n' ' ')"
  else
    local i=1; while IFS='|' read -r id name rest; do echo "  $i. $name ($id)"; i=$((i+1)); done <<< "$found"
    local ans; read -r -p "[选择] 导入哪些客户端? 回车=全部已检测，或编号如 1,3: " ans
    if [ -z "$ans" ]; then selected="$(echo "$found" | cut -d'|' -f1 | tr '\n' ' ')"; else
      IFS=',' read -ra TKS <<< "$ans"
      local idx=1
      while IFS='|' read -r id name rest; do
        for t in "${TKS[@]}"; do [ "$t" = "$idx" ] && selected="$selected $id"; done
        idx=$((idx+1))
      done <<< "$found"
    fi
  fi
  [ -z "${selected// /}" ] && { echo "未选择任何客户端，退出。"; exit 0; }

  # ② 体积分级（≤20MB 默认）+ ③ 任务清单 + ④ 复制与验证（python3）
  ASP_STAGING="$staging" ASP_SELECTED="$selected" ASP_HOME="$HOME" ASP_BACKUP="$BACKUP_DIR" \
  ASP_MAXMB="${ASP_MIG_MAXMB:-20}" ASP_OVERSIZED="${ASP_MIG_OVERSIZED:-0}" ASP_DRYRUN="${ASP_MIG_DRYRUN:-0}" ASP_HOME="$HOME" py <<'PYEOF'
import json, os, hashlib, shutil, datetime
st = os.environ["ASP_STAGING"]; asp_home = os.environ["ASP_HOME"]; home_pkg = os.path.join(st, "home")
selected = os.environ["ASP_SELECTED"].split(); maxmb = int(os.environ["ASP_MAXMB"])
include_oversized = os.environ.get("ASP_OVERSIZED") == "1"; dry = os.environ.get("ASP_DRYRUN") == "1"
backup = os.environ["ASP_BACKUP"]
mf = json.load(open(os.path.join(st, "manifest.json"), encoding="utf-8"))
print(f"[包] {mf['tool']} v{mf['tool_version']} · {mf['created_at']} · {len(mf['items'])} 项")

default, optional = [], []
for it in mf["items"]:
    if it["agent"] not in selected: continue
    mb = round(it.get("bytes", 0) / 1048576, 1)
    if mb <= maxmb: default.append(it)
    else: optional.append((it, mb))
print(f"[分级] 默认同步 {len(default)} 项（≤{maxmb} MB/项）")
if optional:
    print(f"[分级] 超大项 {len(optional)} 个（默认不同步）:")
    for i, (it, mb) in enumerate(optional, 1): print(f"  {i}. [{it['agent']}] {it['rel']}  {mb} MB")
pick = set()
if optional and not dry and include_oversized:
    pick = set(range(len(optional)))
elif optional and not dry:
    ans = input("[选择] 包含哪些超大项? 回车=都不含，或编号如 1,2: ").strip()
    if ans: pick = {int(t) - 1 for t in ans.split(",") if t.strip().isdigit() and 0 < int(t) <= len(optional)}
chosen = default + [optional[i][0] for i in sorted(pick)]

tasks = []
for it in chosen:
    src = os.path.join(home_pkg, it["rel"])
    if it["type"] == "file":
        tasks.append((it["agent"], src, os.path.join(asp_home, it["rel"]), it.get("sha256")))
    else:
        for root, _, fs in os.walk(src):
            for f in fs:
                fp = os.path.join(root, f)
                relsub = os.path.relpath(fp, src).replace(os.sep, "/")
                tasks.append((it["agent"], fp, os.path.join(asp_home, it["rel"].rstrip("/") + "/" + relsub), None))
print(f"[计划] {len(tasks)} 个文件任务" + ("（DryRun：不写入）" if dry else ""))
if tasks and not dry and os.environ.get("ASP_MIG_YES") != "1":
    a = input("[确认] 执行还原? (Y/n) ").strip().lower()
    if a and a != "y": print("已取消。"); raise SystemExit(0)

created = updated = identical = skipped = 0; copied = []
for agent, src, dst, sha in tasks:
    rel = os.path.relpath(dst, asp_home)
    if agent not in selected:
        skipped += 1; print(f"  [跳过] {rel}（{agent} 本机未装）"); continue
    if not sha: sha = hashlib.sha256(open(src, "rb").read()).hexdigest()
    if os.path.exists(dst):
        dsha = hashlib.sha256(open(dst, "rb").read()).hexdigest()
        if dsha == sha: identical += 1; print(f"  [一致] {rel}"); continue
        if not dry:
            os.makedirs(backup, exist_ok=True)
            shutil.copy2(dst, os.path.join(backup, os.path.basename(dst) + "." + datetime.datetime.now().strftime("%H%M%S") + ".bak"))
            shutil.copy2(src, dst)
        updated += 1; copied.append((src, dst, rel)); print(f"  [更新] {rel}")
    else:
        if not dry: os.makedirs(os.path.dirname(dst) or ".", exist_ok=True); shutil.copy2(src, dst)
        created += 1; copied.append((src, dst, rel)); print(f"  [新增] {rel}")

print(f"[汇总] 新增 {created} · 更新 {updated} · 一致跳过 {identical} · 跳过 {skipped}")
if not dry:
    if not copied: print("[验证] 无新写入文件，无需校验。")
    else:
        bad = [rel for s, d, rel in copied if hashlib.sha256(open(s, "rb").read()).hexdigest() != hashlib.sha256(open(d, "rb").read()).hexdigest()]
        ok = len(copied) - len(bad)
        if not bad: print(f"[验证] {ok}/{ok} 文件哈希一致 ✓")
        else:
            print(f"[验证] {ok}/{len(copied)} 一致，以下不一致:")
            for rel in bad: print(f"    {rel}")
    print("还原完成。重启你的 agent 生效；被替换文件的备份在 _backup/。")
PYEOF
  rm -rf "$(dirname "$staging")"
}

case "$COMMAND" in
  install)
    [ -z "$PACK" ] && PACK="base"
    chain=$(resolve_deps "$PACK")
    [ "$(echo $chain | wc -w)" -gt 1 ] && echo "[分层] $PACK 包含基础包，将一并安装: $chain"
    for p in $chain; do do_install "$p"; done ;;
  update)
    [ -z "$PACK" ] && PACK=$(py -c "import json,os;print(json.load(open('$STATE_FILE'))['pack']) if os.path.exists('$STATE_FILE') else print('base')" 2>/dev/null || echo "base")
    for p in $(resolve_deps "$PACK"); do do_update "$p"; done ;;
  detect)  found="$(detect_agents)"; [ -z "$found" ] && show_guide || echo "$found" | awk -F'|' '{printf "  %-16s %s\n", $2, $1}' ;;
  agents)  do_agents "$PACK" "$TARGET_DIR" ;;
  list)    for d in "$ROOT"/packs/*/; do n=$(find "$d/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l); echo "  $(basename "$d")  $n skills"; done ;;
  status)  [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "尚未安装任何包。" ;;
  export)  do_export "$PACK" ;;
  migrate) do_migrate "$PACK" ;;
  *) echo "用法: ./asp.sh [install|update|detect|agents|list|status|export|migrate] [pack] [dir]"; exit 1 ;;
esac
