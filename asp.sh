#!/usr/bin/env bash
# =====================================================================
# asp.sh - AI 冷启动包 (Agent Starter Pack) 安装/更新器 + 环境迁移 (macOS / Linux)
# 用法: ./asp.sh [install|update|detect|agents|status|doctor|export|migrate] [pack] [dir]
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

read_smoke() { # $1=adapter id -> 输出 smoke.cmd（无则空）
  py - "$ROOT/adapters" "$1" <<'PYEOF'
import json, sys, glob, os
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    a = json.load(open(f, encoding="utf-8"))
    if a.get("id") == sys.argv[2] and (a.get("smoke") or {}).get("cmd"):
        print(a["smoke"]["cmd"]); break
PYEOF
}

# 带 timeout 的运行（macOS 无 GNU timeout 时用后台 kill 兜底）
run_with_timeout() { # $1=秒 $2...=命令
  local t="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$t" "$@"
  else
    "$@" & local wp=$!
    ( sleep "$t"; kill "$wp" 2>/dev/null ) & local kp=$!
    local rc=0; wait "$wp" || rc=$?
    kill "$kp" 2>/dev/null || true
    return $rc
  fi
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

# ---------- doctor：MCP 流量灯体检（v0.7.0，ONBOARDING-V2 W2 v1 提前落地）----------
DOCTOR_TIMEOUT=20

mcp_parse_response() { # $1=响应文件 $2=err文件 -> echo "PASS|detail" / "WARN|detail" / "FAIL|detail"
  py - "$1" "$2" <<'PYEOF'
import sys, re, json
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'^\s*data:\s*(\{.+\})\s*$', t, re.M)
if m: t = m.group(1)
try:
    si = json.loads(t)["result"]["serverInfo"]
    print("PASS|握手 OK · %s %s" % (si.get("name", ""), si.get("version", "")))
except Exception:
    try:
        lines = [l for l in open(sys.argv[2], encoding="utf-8", errors="replace").read().splitlines() if l.strip()]
        errs = [l for l in lines if re.search(r"Error|错误|找不到")]
        tail = (errs[-1] if errs else (lines[-1] if lines else ""))[:140]
        print("FAIL|无 initialize 响应" + ("：" + tail if tail else "（stdout 空）"))
    except Exception:
        print("FAIL|无 initialize 响应")
PYEOF
}

test_mcp_remote() { # $1=url
  local body='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"asp-doctor","version":"0.7.0"}}}'
  local d; d="$(mktemp -d)"
  local code
  code=$(curl -s -m 10 -X POST "$1" -H "Content-Type: application/json" \
       -H "Accept: application/json, text/event-stream" -d "$body" -o "$d/out" -w '%{http_code}' 2>/dev/null)
  if [ "$code" = "401" ] || [ "$code" = "403" ]; then
    echo "WARN|端点可达但鉴权被拒（HTTP $code）——检查 token/headers 配置"; rm -rf "$d"; return
  fi
  if [ "$code" = "405" ]; then rm -rf "$d"; test_mcp_sse "$1"; return; fi
  if [ -z "$code" ] || [ "$code" = "000" ]; then
    echo "FAIL|HTTP 请求失败"; rm -rf "$d"; return
  fi
  : > "$d/err"; mcp_parse_response "$d/out" "$d/err"; rm -rf "$d"
}

test_mcp_sse() { # $1=url（GET event-stream）
  local d; d="$(mktemp -d)"
  # curl 超时（exit 28）时已收到的数据仍会写入 -o 文件，借此判断是否出现事件帧
  curl -s -m 6 -H "Accept: text/event-stream" "$1" -o "$d/out" 2>/dev/null
  if grep -q 'event:\|data:' "$d/out" 2>/dev/null; then
    echo "PASS|SSE 端点可达（event-stream 正常）"
  elif [ -s "$d/out" ]; then
    echo "WARN|HTTP 已连上但未读到事件帧"
  else
    echo "FAIL|SSE 探测失败（超时/连接失败）"
  fi
  rm -rf "$d"
}

test_mcp_stdio() { # $1=command $2=args串 $3=requires
  [ -n "$3" ] && ! command -v "$3" >/dev/null 2>&1 && { echo "FAIL|未检测到 $3（MCP 运行时缺失）"; return; }
  local d; d="$(mktemp -d)"
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"asp-doctor","version":"0.7.0"}}}' > "$d/in"
  local rc=0
  # 模拟真实客户端：喂 init 后保持管道 2s 再 EOF（立即 EOF 会赶在响应写出前终止 server）
  { cat "$d/in"; sleep 2; } | run_with_timeout "$DOCTOR_TIMEOUT" bash -c "$1 $2 >'$d/out' 2>'$d/err'" || rc=$?
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
    rm -rf "$d"; echo "FAIL|启动超时（>${DOCTOR_TIMEOUT}s）——npx 首次冷启动可能超限时，重跑 asp doctor 通常即过"; return
  fi
  mcp_parse_response "$d/out" "$d/err"; rm -rf "$d"
}

do_doctor() {
  echo "[doctor] MCP 流量灯体检——对已部署配置逐条做真实 initialize 握手（实测才算绿）"
  local found; found="$(detect_agents)"
  [ -z "$found" ] && { show_guide; exit 0; }
  local pass=0 fail=0 skip=0
  while IFS='|' read -r id name skills_dir imode itarget ifname mstrat mtarget mkey mtmpl mreq; do
    [ -z "$id" ] && continue
    case "$mstrat" in
      merge|json-merge|toml-managed) ;;
      manual)
        echo "  $name · - · SKIP · manual 端：在设置界面添加，见 README"; skip=$((skip+1)); continue ;;
      *) continue ;;
    esac
    local tgt; tgt="$(expand_tilde "$mtarget")"
    if [ ! -f "$tgt" ]; then echo "  $name · - · SKIP · 配置未部署（先 install）"; skip=$((skip+1)); continue; fi
    local n_entries=0
    while IFS=$'\t' read -r sname stype sval sargs; do
      [ -z "${sname:-}" ] && continue
      n_entries=$((n_entries+1))
      local r
      if [ "$stype" = "sse" ]; then r="$(test_mcp_sse "$sval")"
      elif [ "$stype" = "remote" ]; then r="$(test_mcp_remote "$sval")"
      else r="$(test_mcp_stdio "$sval" "$sargs" "$mreq")"; fi
      local mark="${r%%|*}" detail="${r#*|}"
      echo "  $name · $sname · $mark · $detail"
      case "$mark" in
        PASS) pass=$((pass+1)) ;;
        FAIL) fail=$((fail+1)) ;;
        *) skip=$((skip+1)) ;;
      esac
    done < <(py - "$tgt" "$mstrat" "$mkey" <<'PYEOF'
import json, re, sys
path, strat, key = sys.argv[1], sys.argv[2], sys.argv[3]
def out(name, typ, val, args=""): print("\t".join([name, typ, val, args]))
if strat == "toml-managed":
    t = open(path, encoding="utf-8").read()
    m = re.search(r"# >>> asp:mcp:begin >>>(.*?)# <<< asp:mcp:end <<<", t, re.S)
    if not m: raise SystemExit(0)
    for sec in re.finditer(r"\[mcp_servers\.([\w\-]+)\]\s*command\s*=\s*\"([^\"]+)\"\s*args\s*=\s*\[([^\]]*)\]", m.group(1)):
        args = " ".join(re.findall(r"\"([^\"]+)\"", sec.group(3)))
        out(sec.group(1), "stdio", sec.group(2), args)
    raise SystemExit(0)
cfg = json.load(open(path, encoding="utf-8"))
c = cfg
for k in key.split("."):
    c = (c or {}).get(k, {}) if isinstance(c, dict) else {}
if not isinstance(c, dict): raise SystemExit(0)
for name, e in c.items():
    if not isinstance(e, dict): continue
    if e.get("url"):
        out(name, str(e.get("type") or "remote"), e["url"])
    elif e.get("command"):
        cmd = e["command"]
        if isinstance(cmd, list):
            if not cmd: continue
            args = " ".join(str(a) for a in cmd[1:])
            out(name, "stdio", str(cmd[0]), args)
        else:
            args = e.get("args") or []
            if isinstance(args, list): out(name, "stdio", str(cmd), " ".join(str(a) for a in args))
PYEOF
)
    [ "$n_entries" -eq 0 ] && { echo "  $name · - · SKIP · 配置中无可测条目"; skip=$((skip+1)); }
  done <<< "$found"
  echo "---------------------------------------"
  echo "[doctor 汇总] PASS $pass · FAIL $fail · SKIP $skip"
  if [ "$fail" -gt 0 ]; then
    echo "存在 FAIL：配置写了 ≠ 能用。修复指引见 README『MCP 体检』与 packs/base/mcp/optional-mcp.md；npx 冷启动超时可重跑确认。"
    exit 1
  fi
  echo "全绿 ✓（MCP 零报错率口径：PASS / (PASS+FAIL)）"
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
    # 探测诚实化（v0.7.0）：目录特征命中但可执行文件不在 PATH——可能是迁移残留而非真实安装
    local smoke_cmd; smoke_cmd="$(read_smoke "$id" 2>/dev/null || true)"
    if [ -n "$smoke_cmd" ]; then
      local exe="${smoke_cmd%% *}"
      command -v "$exe" >/dev/null 2>&1 || echo "    ⚠ 未在 PATH 检测到 '$exe'——本机可能只有该 agent 的配置残留（如迁移恢复）而未真正安装；已按目录特征部署，真正安装后生效"
    fi
    if [ "$mstrat" = "merge" ] && [ -d "$packdir/mcp" ]; then
      r=$(merge_mcp "$packdir/mcp/$mtmpl" "$(expand_tilde "$mtarget")" "$mkey" "$mreq")
      echo "    MCP: $r"
    elif [ "$mstrat" = "merge" ]; then
      :  # 专业包无 mcp 目录（MCP 归属 base 包），跳过
    elif [ "$mstrat" = "manual" ]; then
      echo "    MCP: 该端需在设置界面手动添加（配置文件不在加载面）——context7 远程端点: https://mcp.context7.com/mcp"
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
  local n=0 cand2="$staging/.items.txt" ovfile="$staging/.oversized.txt" OVFILE="$staging/.oversized.txt"; : > "$cand2"; : > "$ovfile"
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
          # tar 管道一次拷贝（逐文件 cp 在 Git Bash 下进程派生开销过大）
          (cd "$child" && find . -type d \( -name node_modules -o -name .git -o -name __pycache__ -o -name .venv -o -name venv -o -name .cache -o -name .pytest_cache \) -prune -o -type f ! -name "*.pyc" -print0 | tar -cf - --null -T - 2>/dev/null) | (cd "$dstChild" && tar -xf -)
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
        (cd "$psrc" && find . -type d \( -name node_modules -o -name .git -o -name __pycache__ -o -name .venv -o -name venv -o -name .cache -o -name .pytest_cache \) -prune -o -type f ! -name "*.pyc" -print0 | tar -cf - --null -T - 2>/dev/null) | (cd "$pdst" && tar -xf -)
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

  # ---- GitHub 通道（ASP_EXPORT_REPO）：包进私有仓库 env 分支，新机器零 U 盘还原 ----
  if [ -n "${ASP_EXPORT_REPO:-}" ]; then
    command -v git >/dev/null 2>&1 || { echo "[错误] -Repo 需要 git（未检测到）"; rm -rf "$(dirname "$staging")"; exit 1; }
    local repodir; repodir="$(mktemp -d)/asp-remote"
    git clone --depth 1 "$ASP_EXPORT_REPO" "$repodir" 2>/dev/null || { echo "[错误] git clone 失败——先去 GitHub 建 PRIVATE 仓库并确认推送权限"; rm -rf "$(dirname "$staging")" "$repodir"; exit 1; }
    ( cd "$repodir"       && git checkout -B "${ASP_EXPORT_BRANCH:-env-sync}" 2>/dev/null       && rm -rf env && mkdir -p env       && cp "$outfile" env/env.tar.gz       && printf 'package=env.tar.gz
exported_at=%s
source_host=%s@%s
' "$(date +%Y-%m-%dT%H:%M:%S)" "$(whoami)" "$(hostname)" > env/LATEST.txt       && cp -R "$ROOT/adapters" "$ROOT/packs" "$ROOT/registry" "$ROOT/docs" . 2>/dev/null       && cp "$ROOT/asp.sh" "$ROOT/asp.ps1" "$ROOT/setup.bat" "$ROOT/setup.command" "$ROOT/update.bat" "$ROOT/update.command" . 2>/dev/null       && cp "$ROOT/migrate-export.bat" "$ROOT/migrate-restore.bat" "$ROOT/migrate-export.command" "$ROOT/migrate-restore.command" . 2>/dev/null       && git add -A       && git -c user.name=asp-env-sync -c user.email=asp@local commit -m "env sync $(date +%Y%m%d-%H%M%S)" 2>/dev/null       && git push -u origin "${ASP_EXPORT_BRANCH:-env-sync}"       && git remote set-head origin "${ASP_EXPORT_BRANCH:-env-sync}" 2>/dev/null; git push origin "${ASP_EXPORT_BRANCH:-env-sync}:${ASP_EXPORT_BRANCH:-env-sync}" --force 2>/dev/null; true )
    local pushok=$?
    rm -rf "$(dirname "$staging")" "$repodir"
    if [ $pushok -eq 0 ]; then
      echo "[完成] 环境已推送到 $ASP_EXPORT_REPO（分支 ${ASP_EXPORT_BRANCH:-env-sync}，env/env.tar.gz）"
      echo "  新机器三步:"
      echo "    ① git clone $ASP_EXPORT_REPO"
      echo "    ② cd 仓库目录 && ./asp.sh install     # 装 asp 运行环境本身"
      echo "    ③ ./asp.sh migrate env -y             # 从 env/ 一键还原全部环境"
      echo "  ⚠ 必须是 PRIVATE 仓库——包内 MCP 配置可能含 API key，公开=泄露。"
    else
      echo "[错误] git push 失败——本地包保留在: $outfile"
    fi
    return 0
  fi
  rm -rf "$(dirname "$staging")"
  echo "[完成] 迁移包: $outfile"
  echo "  还原: 新机器 asp 目录下  ./asp.sh migrate \"$outfile\""
  echo "  ⚠ 包内可能含 API key（MCP 配置），请妥善保管。"
}

do_migrate() { # $1=迁移包路径（tar.gz/zip/目录/env 快捷方式/仓库URL）；env: ASP_MIG_YES / ASP_MIG_ALL / ASP_MIG_OVERSIZED / ASP_MIG_DRYRUN
  local pkg="${1:-}"
  [ -z "$pkg" ] && read -r -p "[输入] 迁移包路径 / env / 仓库URL: " pkg
  if [ "$pkg" = "env" ]; then
    # 快捷方式：用本仓库 env/ 的最新环境包（先 pull）
    if command -v git >/dev/null 2>&1; then
      echo "[拉取] git pull 更新 env/（分支 env-sync）..."
      git fetch origin env-sync 2>/dev/null && git checkout -q env-sync 2>/dev/null && git pull -q origin env-sync 2>/dev/null
    fi
    pkg="$ROOT/env/env.tar.gz"
    [ -f "$pkg" ] || { zip_f="$ROOT/env/env.zip"; [ -f "$zip_f" ] && pkg="$zip_f" || { echo "[错误] $pkg 不存在——旧机器还没推送过（./asp.sh export，设 ASP_EXPORT_REPO=<私有仓库URL>）"; exit 1; }; }
  elif [[ "$pkg" =~ ^(https?://|git@) ]]; then
    command -v git >/dev/null 2>&1 || { echo "[错误] URL 方式需要 git"; exit 1; }
    local repodir; repodir="$(mktemp -d)/asp-remote"
    git clone --depth 1 --branch "${ASP_EXPORT_BRANCH:-env-sync}" "$pkg" "$repodir" 2>/dev/null || git clone --depth 1 "$pkg" "$repodir" || { echo "[错误] clone 失败"; exit 1; }
    [ -f "$repodir/env/env.tar.gz" ] && pkg="$repodir/env/env.tar.gz" || { [ -f "$repodir/env/env.zip" ] && pkg="$repodir/env/env.zip" || { echo "[错误] 仓库里没有 env/env.tar.gz"; exit 1; }; }
  fi
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
  doctor)  do_doctor ;;
  export)  do_export "$PACK" ;;
  migrate) do_migrate "$PACK" ;;
  *) echo "用法: ./asp.sh [install|update|detect|agents|list|status|doctor|export|migrate] [pack] [dir]"; exit 1 ;;
esac
