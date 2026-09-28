# 开发文档（DEV）

> 面向维护者。产品说明见根目录 README.md。产品方案全文见 Notion「AI冷启动/02 产品方案 v1.3」或本地 `../家族A-AI冷启动包-执行方案.md`。

## 命令参考

| 命令 | 作用 |
|---|---|
| `asp.ps1 install [pack]` | 探测 agent → 确认 → 部署 skills/AGENTS.md/MCP |
| `asp.ps1 update [pack]` | 双源 failover 拉 index.json → 版本对比 → 下载 → sha256 校验 → 重装 |
| `asp.ps1 detect` | 只读探测本机 agent |
| `asp.ps1 agents [pack] [dir]` | AGENTS.md 以 managed-section 部署到项目目录（workspace 型 agent 用） |
| `asp.ps1 status` | 查看 _state.json |
| `scripts\build-release.ps1 -Pack ai-pm` | 发版打包：BOM 自检 → zip → sha256 → 更新 index.json |
| `scripts\make-lite.ps1 -Pack ai-pm` | 拆分免费 lite 版到 dist/lite/ |

## 已实测验证（2026-09-28，沙箱端到端）

- 探测：Windows 真机 detect 正确识别 Zcode
- 安装：skills 复制、AGENTS.md managed-section、MCP merge 全流程通过
- 幂等：二次安装零重复（servers 数量不变、begin 标记数=1）
- 配置保留：用户已有 MCP 服务器与其他 JSON 键完整保留
- 无 BOM 写入验证：config.json 可被标准 JSON 解析器读取
- 发版：build-release 产出 zip（30 文件、6 skills）、sha256、index.json 自动更新

## 已实测验证（2026-09-28 晚，DSH+KimiWork 真机一键安装）

- 环境：Win10 真机，dsh 0.1.5-rc.2（KimiWork 桌面版自带的 daimon 运行时）、KimiWork（Kimi Claw/openclaw 形态）
- **DSH**：detect 命中 → 6 skills 落位 `~/.dsh/skills/`（官方 skills 零破坏）→ AGENTS.md managed-section 追加到全局 `~/.dsh/AGENTS.md`（原内容保留）→ MCP template-only 不写入
- **KimiWork**：detect 命中（修正适配器后）→ 6 skills 落位 `~/.kimi_openclaw/workspace/skills/` → AGENTS.md managed-section 追加到 `~/.kimi_openclaw/workspace/AGENTS.md`（openclaw 标准指令文件，原内容保留）
- 幂等重跑：两侧均 `updated`、文件长度不变、标记内内容与包源 AGENTS.md 逐字符一致（511 chars）
- 产出修复：发现并修复备份同名覆盖 bug（见坑记录 6）

## 已实测验证（2026-09-28 晚二，7 agent 全家桶 + v0.2 内容 + toml-managed 实现）

- 环境：同上 Win10 真机；ai-pm v0.2（15 skills、MCP 3 默认服务器）
- **一键全装**：detect 命中 7 agent（Claude Code / Codex / Cursor / DSH / KimiWork / opencode / Zcode），全部写入成功：15 skills × 7、AGENTS.md/CLAUDE.md 托管段、MCP 写入 4 侧（CC/Cursor JSON merge、Zcode JSON merge、**Codex toml-managed 新实现**）
- **Codex toml-managed**：config.toml 末尾 `# >>> asp:mcp:begin >>>`/`# <<< asp:mcp:end <<<` 托管块，用户已有 `[mcp_servers.node_repl/notion]` 原样保留、块唯一、重跑整块替换不重复
- **Zcode**：本会话即 Zcode，`~/.zcode/skills` 为系统级 skills 加载机制（加载实证）；MCP 写入后 config.json 合法、原有 6 服务器全保留
- 幂等重跑：JSON merge 全 skip、toml 托管块 updated、AGENTS.md updated；验证 16/16 通过
- 分寸：Claude Code / Cursor / opencode / Codex 为**写入实证**，agent 侧真实加载（skill 出现在会话、MCP 连通）待用户各开一次冒烟

## 关键设计

- **managed-section**：`<!-- asp:begin -->`/`<!-- asp:end -->` 标记间替换，标记外用户内容不动
- **MCP merge 仅新增**：同名服务器跳过不覆盖；支持 `mcpServers`（Claude/Cursor）与 `mcp.servers`（Zcode）两种键路径
- **适配器 enabled:false**：未完成实测的 agent 不参与安装（当前 kimi 已实测启用；新增 agent 未实测前先置 false）
- **备份回滚**：所有被修改文件先存 `_backup/<agent-id>-<name>.<timestamp>.bak`（agent-id 前缀防不同 agent 同名文件互相覆盖）
- **workspace 型 vs managed-section 型**：opencode 读项目根 AGENTS.md（workspace 型，用 `asp agents <dir>` 部署）；Claude/Codex 有全局文件、DSH/KimiWork 实测确认有全局落位点（均为 managed-section 型，install 时直接部署）。DSH/Kimi 项目级 AGENTS.md 亦可用 `asp agents` 补充部署

## 开发坑记录（血泪，勿删）

1. **asp.ps1 必须带 UTF-8 BOM**——PS5.1 对无 BOM 的 UTF-8 按 ANSI 解析，中文字符串直接语法错误。build-release 已内置 BOM 自检；每次外部工具重写 .ps1 后运行自检。
2. **写用户 JSON 配置必须无 BOM**——PS5.1 `Set-Content -Encoding UTF8` 带 BOM，会破坏 Zcode/CC 的 JSON 解析。统一用 `Write-Utf8NoBom`（`[IO.File]::WriteAllText` + `UTF8Encoding($false)`）。
3. **PS5.1 兼容性**：无 `Get-Date -AsUTC`（用 `.ToUniversalTime().ToString()`）；`Compress-Archive`/`Expand-Archive` 可用但大文件慢。
4. **Git Bash /tmp 与 PowerShell 不一致**：PS 把 `/tmp/x` 解析到当前盘根 `C:\tmp\x`。跨 shell 测试用 Windows 绝对路径（`C:/tmp/...`）。
5. **mac/linux 的 asp.sh 依赖 python3** 做 JSON 处理（mac 自带；多数 linux 自带）——发布页要写明。`.command` 文件的执行位：zip 打包时用 `zip -y` 保留，或 README 引导 `bash asp.sh`。
6. **备份文件必须带 agent-id 前缀**（2026-09-28 DSH+Kimi 实测发现）：原命名 `<name>.<秒级时间戳>.bak`，两个 agent 的 AGENTS.md 同一秒安装时同名互相覆盖、先装的备份丢失。已改为 `<agent-id>-<name>.<ts>.bak`；新增 agent 测试时务必验证多 agent 同秒场景。
7. **无全局 Node 的机器 MCP 会被跳过**（2026-09-28 本机发现）：本机未装 Node.js，唯一 node/npx 内嵌在 kimi-desktop runtime；asp 的 `Test-Command npx` 失败 → merge/toml-managed 整体跳过（行为正确但体验差）。P2 待办：探测 agent 内嵌 node runtime（Zcode/Cursor 均自带）/提示装 node。临时解法：安装时把含 npx 的目录加进 PATH。
8. **PS5.1 读 UTF-8 JSON 必须显式 `-Encoding UTF8`**：默认按 ANSI 读，中文 note 变乱码破坏引号匹配 → ConvertFrom-Json 报"应为:或}"。asp.ps1 内部已全部带 `-Encoding UTF8`；写验证/诊断脚本时同样要带。

## 实证过的路径（2026-09-28）

| Agent | skills | 指令 | MCP | 来源 |
|---|---|---|---|---|
| Zcode | `~/.zcode/skills/` | 工作区根 AGENTS.md | `~/.zcode/cli/config.json` → `mcp.servers` | 本机实测 |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md`（项目 AGENTS.md 亦读，v2.1.277+） | `~/.claude.json` → `mcpServers` | 官方文档 |
| DSH | `~/.dsh/skills/` **全局实证有效**（本机与官方 skills 同存） | 全局 `~/.dsh/AGENTS.md` **会话自动注入实证** + 项目根 AGENTS.md（原生，64KB 预算） | patch 机制 `~/.dsh/cordis.patch.yml`；**MCP 默认不启用** | **Win 真机实测（0.1.5-rc.2）** |
| Codex | `~/.codex/skills/` 写入实证，agent 加载待冒烟 | `~/.codex/AGENTS.md` 全局托管段写入实证 + 项目根 | `config.toml` `[mcp_servers.*]` toml-managed 托管块**写入实证**（本机） | **Win 真机写入实测（0.2）** |
| Cursor | 待实测（Settings 兼容开关） | `.cursor/rules/*.mdc`（全局 `~/.cursor/rules/`） | `~/.cursor/mcp.json`（Claude 同构） | 官方/社区文档，待实测 |
| opencode | 待实测 | 项目根 AGENTS.md（原生） | `opencode.json` → `mcp` 字段（command 数组格式） | 社区文档，待实测 |
| KimiWork | `~/.kimi_openclaw/workspace/skills/` **实证**（官方 skills 同目录） | `~/.kimi_openclaw/workspace/AGENTS.md` **实证**（openclaw 标准文件） | openclaw 插件体系（openclaw.json plugins），未暴露独立 mcpServers 文件，待研究 | **Win 真机实测（Kimi Claw 形态）** |

> Kimi 适配器要点：KimiWork 桌面版 = Kimi Claw（openclaw 分发版），根目录 `~/.kimi_openclaw/`（非早期推测的 `~/.kimi/skills`；`~/.kimi/kimi-claw/openclaw.json` 是插件配置）。detect 用 `~/.kimi_openclaw` 特征，已 enabled=true。无 CLI smoke 命令，以目录存在性为准。

## W2 待办

- [ ] Codex/Cursor/opencode 三适配器实测（装对应工具→跑 asp→验证 skills/AGENTS/MCP 生效）
- [x] Kimi 实测 ✅（2026-09-28 真机）：KimiWork=Kimi Claw/openclaw 形态，skills=`~/.kimi_openclaw/workspace/skills/`，适配器已修正并 enabled=true
- [x] DSH skills 全局 vs 项目级 ✅（2026-09-28 真机）：全局 `~/.dsh/skills/` 有效；全局 AGENTS.md 会话自动注入实证
- [ ] mac 侧 asp.sh 端到端实测
- [ ] OSS bucket 开通 + GitHub Pages 备源 → mirrors 填真实地址（操作步骤见 `docs/HOSTING.md`，验证清单在内）
- [ ] 三条示例指令实测挑选（README"装完后第一件事"）
- [x] collector/ 周更抓源脚本 ✅（2026-09-28 已真实首跑）：`collector/collect.ps1`——GitHub 搜索（license 随 search 响应直接取得，零 core API 消耗）+ awesome 清单提链 → host 白名单校验（仅 http/https，拒内网/保留地址）→ license 白名单过滤 → seen.json diff → 周审候选报告（首跑：通过 18 / 拒 7 + 待人工核验段）。设 `ASP_GITHUB_TOKEN` 可自动核验 awesome 候选并提额至 5000 req/h
- [x] 商品页文案 ✅（2026-09-28）：`docs/shop-listing.md`（匿名品牌口径定稿，GIF 录制脚本在内，待录制）
