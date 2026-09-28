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

## 关键设计

- **managed-section**：`<!-- asp:begin -->`/`<!-- asp:end -->` 标记间替换，标记外用户内容不动
- **MCP merge 仅新增**：同名服务器跳过不覆盖；支持 `mcpServers`（Claude/Cursor）与 `mcp.servers`（Zcode）两种键路径
- **适配器 enabled:false**：未完成实测的 agent 不参与安装（当前 kimi）
- **备份回滚**：所有被修改文件先存 `_backup/<name>.<timestamp>.bak`
- **workspace 型 vs managed-section 型**：DSH/opencode 读项目根 AGENTS.md（workspace 型，用 `asp agents <dir>` 部署）；Claude/Codex 有全局文件（managed-section 型，install 时直接部署）

## 开发坑记录（血泪，勿删）

1. **asp.ps1 必须带 UTF-8 BOM**——PS5.1 对无 BOM 的 UTF-8 按 ANSI 解析，中文字符串直接语法错误。build-release 已内置 BOM 自检；每次外部工具重写 .ps1 后运行自检。
2. **写用户 JSON 配置必须无 BOM**——PS5.1 `Set-Content -Encoding UTF8` 带 BOM，会破坏 Zcode/CC 的 JSON 解析。统一用 `Write-Utf8NoBom`（`[IO.File]::WriteAllText` + `UTF8Encoding($false)`）。
3. **PS5.1 兼容性**：无 `Get-Date -AsUTC`（用 `.ToUniversalTime().ToString()`）；`Compress-Archive`/`Expand-Archive` 可用但大文件慢。
4. **Git Bash /tmp 与 PowerShell 不一致**：PS 把 `/tmp/x` 解析到当前盘根 `C:\tmp\x`。跨 shell 测试用 Windows 绝对路径（`C:/tmp/...`）。
5. **mac/linux 的 asp.sh 依赖 python3** 做 JSON 处理（mac 自带；多数 linux 自带）——发布页要写明。`.command` 文件的执行位：zip 打包时用 `zip -y` 保留，或 README 引导 `bash asp.sh`。

## 实证过的路径（2026-09-28）

| Agent | skills | 指令 | MCP | 来源 |
|---|---|---|---|---|
| Zcode | `~/.zcode/skills/` | 工作区根 AGENTS.md | `~/.zcode/cli/config.json` → `mcp.servers` | 本机实测 |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md`（项目 AGENTS.md 亦读，v2.1.277+） | `~/.claude.json` → `mcpServers` | 官方文档 |
| DSH | `.dsh/skills/`（全局/项目级待确认） | workspace 根 AGENTS.md（原生，64KB 预算；CLAUDE.md 亦读） | patch 机制 `~/.dsh/cordis.patch.yml`；**MCP 默认不启用** | 官方 CLI 参考 |
| Codex | 待实测 | `~/.codex/AGENTS.md` 全局 + 项目根 | `config.toml` `[mcp_servers.*]` | 官方文档，W2 实测 |
| Cursor | 待实测（Settings 兼容开关） | `.cursor/rules/*.mdc`（全局 `~/.cursor/rules/`） | `~/.cursor/mcp.json`（Claude 同构） | 官方/社区文档，W2 实测 |
| opencode | 待实测 | 项目根 AGENTS.md（原生） | `opencode.json` → `mcp` 字段（command 数组格式） | 社区文档，W2 实测 |
| Kimi | 待实测（`~/.kimi/` 推测） | 待确认 | 支持 MCP（官方确认），格式待实测 | 适配器 enabled=false |

## W2 待办

- [ ] Codex/Cursor/opencode 三适配器实测（装对应工具→跑 asp→验证 skills/AGENTS/MCP 生效）
- [ ] Kimi CLI 安装实测，确认 `~/.kimi/` 路径后 enabled=true
- [ ] DSH skills 全局 vs 项目级路径确认
- [ ] mac 侧 asp.sh 端到端实测
- [ ] OSS bucket 开通 + GitHub Pages 备源 → mirrors 填真实地址
- [ ] 三条示例指令实测挑选（README"装完后第一件事"）
- [ ] collector/ 周更抓源脚本（awesome 清单/GitHub trending → license 白名单过滤 → diff 报告）
- [ ] 商品页（闲鱼/淘宝）文案 + asp install 演示 GIF 录制
