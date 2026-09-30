# 环境迁移（asp export / asp migrate）

> v0.6.0 新增。零外部依赖：Windows 用自带 PowerShell 5.1（+robocopy/tar），macOS/Linux 用自带 bash+python3（+tar）。

## 是什么

把**旧机器上所有已装 agent 的环境**（skills、全局 AGENTS.md/CLAUDE.md、MCP 配置、记忆目录等）打成**一个迁移包**，到新机器一条命令还原。还原为 **merge 语义**：只增改、不删除，被替换文件自动备份。

支持 agent（10 个）：Claude Code · Codex · Cursor · opencode · Zcode · DeepSeek Harness · KimiWork · **Trae · Qoder · WorkBuddy**（后三者为国内适配 v0.1：迁移已支持，路径待社区实测修正；包安装待实测后开放）。

## 快速开始（本地包方式；推荐用下方 GitHub 通道）

```bash
# ── 旧机器：导出 ──
Windows:  双击 migrate-export.bat          或 powershell -File asp.ps1 export
mac/Linux: 双击 migrate-export.command      或 ./asp.sh export [输出路径]
# 交互：逐项列出收集内容；单个 >20MB 的子项（如重型 skill）默认不入包，
#       会列出来让你选是否包含；也可 -Yes 跳过交互（全默认）/ -IncludeOversized 全包含。

# ── 新机器：还原 ──
# 前提：把 asp 目录（本包）也带到新机器（git clone 或拷贝）
Windows:  双击 migrate-restore.bat           或 powershell -File asp.ps1 migrate <迁移包路径>
mac/Linux: 双击 migrate-restore.command      或 ./asp.sh migrate <迁移包路径>
# 交互三步：
#   ① 自动检测本机已装 agent -> 选择导入哪些客户端（回车=全部）
#   ② 体积分级：≤20MB/项 默认同步；超大项列出勾选（回车=不含）
#   ③ 确认执行 -> 逐文件还原
# 选项：-Yes 全默认 / -All 含未装客户端的资产 / -DryRun 只看计划不写入
```

## 迁移包内容

| 文件 | 说明 |
|---|---|
| `manifest.json` | 工具版本/时间/主机/agent 清单/**逐项清单**（类型/相对路径/文件数/sha256/字节数） |
| `home/…` | 按原 `~/` 相对路径存放的文件（还原即落位） |
| `README-MIGRATE.txt` | 还原说明 + API key 安全提醒 |

收集范围：每个已检测 agent 的 skills 目录、全局指令文件（managed-section）、MCP 配置文件；外加 adapter 声明的额外资产（如 Zcode 的 `~/.zcode/cli/memories` 记忆目录、Trae/Qoder/WorkBuddy 的配置与规则）。

## 安全机制

- **体积护栏**：目录复制排除 `node_modules/.git/__pycache__/.venv/.cache` 与 junction/软链接不跟随（Windows robocopy /XJ，防止软链把仓库拖进包）；单项 >300MB 或 >2 万文件硬拒收
- **体积分级**：默认只同步 ≤20MB 的单项（单 skill 粒度）；超大项显式列出、用户勾选后才入包/还原
- **merge 语义**：与目标一致的文件跳过（sha256 比对）；替换前自动备份到 `_backup/`
- **导入验证**：还原完成对本次写入的每个文件回读哈希比对，报告 `N/N 文件哈希一致 ✓`
- **API key**：MCP 配置可能含 key——迁移包按敏感文件对待，勿传不可信渠道

## 已实测（Win10，2026-09-30）

- export（真实机器 5 agent）：469MB → 排除重物后 **25.7MB zip**；超大项四端一致检出（ppt-master 80.7MB ×4，默认排除可勾选）
- migrate 沙箱还原：新增 328 文件 **328/328 哈希一致 ✓**；幂等重跑 0 写入；篡改后重跑触发 [更新]+自动备份 ✓
- bash 端 E2E：detect→export→migrate→diff 内容一致 ✓（并修复了一个 pre-existing bug：旧版 `expand_tilde` 的 `${1#~/}` 在 bash 模式展开下永不匹配，detect 在 mac/Linux 上会永远为空——已修复）

## GitHub 通道（推荐动线：零 U 盘零网盘，最多经过 GitHub）

**一次性准备（旧机器，2 分钟）**：GitHub 网页新建一个 **Private** 仓库（如 `yourname/env-sync`，勾选不初始化），本机 git 已登录（HTTPS 凭据或 SSH）。

```bash
# ── 旧机器：导出并推送 ──
mac/Linux: ASP_EXPORT_REPO=https://github.com/yourname/env-sync.git ./asp.sh export
Windows:   powershell -File asp.ps1 export -Repo https://github.com/yourname/env-sync.git
# 首次推送后到 GitHub 网页：Settings → Branches → 把默认分支设为 env-sync（一次性）
# 之后每次迁移只需重跑同一条命令（覆盖式更新 env/）

# ── 新机器：三步 ──
① git clone https://github.com/yourname/env-sync.git && cd env-sync
② （可选，补齐 agent 程序）./asp.sh install        # 或 asp.ps1 install
③ ./asp.sh migrate env                              # 或 asp.ps1 migrate env -Yes
# migrate env 自动 git pull 最新环境包 → 检测本机客户端 → 选择导入 → 哈希验证
```

也支持直接给 URL：`./asp.sh migrate https://github.com/yourname/env-sync.git`。

**为什么安全**：Private 仓库 + 分支仅含环境包与 asp 程序；包内 MCP 可能含 API key——**务必 Private**，公开=泄露。历史版本在 git 历史里，可回滚。

**环境分支内容**：`env/env.tar.gz`（或 .zip）+ `env/LATEST.txt`（导出时间/来源主机）+ 完整 asp 程序（adapters/packs/scripts），新机器 clone 一步即同时拿到还原工具与包。

## 已知边界

- Trae/Qoder/WorkBuddy 的配置真实布局待实测（适配器路径可能需要按 issue 反馈修正；检测不到的路径自动跳过，不报错）
- 跨 OS 迁移（Win↔mac）时路径相同（都按 `~/` 相对），但 Windows 特有配置内容（盘符路径）需 agent 侧自行兼容
- 排除清单外的超大二进制（如模型文件）建议不入包，另行同步
