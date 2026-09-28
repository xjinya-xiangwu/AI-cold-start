# ai-coldstart — AI 冷启动包（开发仓库）

AI 冷启动包（Agent Starter Pack）的产品工程仓库：asp 安装器 + registry 协议 + 角色包。产品方案见 `../家族A-AI冷启动包-执行方案.md`（v1.3）与 Notion「AI冷启动/02 产品方案」。

## 目录结构

```
ai-coldstart/
├── asp.ps1 / asp.sh        安装器（Windows PowerShell / mac-linux bash+python3）
├── setup.bat / update.bat          Windows 双击入口
├── setup.command / update.command  macOS 双击入口（发布 zip 时须保留可执行位）
├── adapters/                agent 适配器（JSON，可周更远程下发）
│   ├── claude-code.json     ~/.claude/skills、CLAUDE.md 全局、~/.claude.json#mcpServers
│   ├── zcode.json           ~/.zcode/skills、workspace AGENTS.md、cli/config.json#mcp.servers（实证）
│   └── dsh.json             ~/.dsh/skills、AGENTS.md 原生、MCP template-only（DSH 默认不启用）
├── registry/index.json      更新源协议 v0.1（mirrors 待 OSS/GH Pages 开通后填真实地址）
└── packs/ai-pm/             首发包（AGENTS.md 模板已就绪，skills W2 生产）
```

## 命令

| 命令 | 作用 |
|---|---|
| `asp.ps1 install [pack]` | 探测 agent → 确认 → 部署 skills/AGENTS.md/MCP |
| `asp.ps1 update [pack]` | 双源 failover 拉 index.json → 版本对比 → 下载 → sha256 校验 → 重装 |
| `asp.ps1 detect` | 只读探测本机 agent |
| `asp.ps1 agents [pack] [dir]` | 把包的 AGENTS.md 以 managed-section 部署到项目目录（workspace 型 agent 用） |
| `asp.ps1 status` | 查看 _state.json |

## 关键设计（已实测验证 ✅ 2026-09-28）

- **managed-section 幂等部署**：`<!-- asp:begin/end -->` 标记间替换，标记外用户内容不动；二次安装零重复。
- **MCP merge 仅新增**：同名服务器跳过不覆盖；用户其他配置键（otherKey 等）完整保留。
- **无 BOM UTF-8 写入**：PS5.1 的 `Set-Content -Encoding UTF8` 带 BOM 会破坏 Zcode/CC 的 JSON 解析，已用 `[IO.File]::WriteAllText` + `UTF8Encoding($false)` 规避。
- **备份回滚**：所有被修改文件先复制到 `_backup/<name>.<timestamp>.bak`。
- **无 agent 环境引导面板**（用户已确认的策略，不替装）。

## 已知限制 / 待办

- [ ] W2：Codex、Cursor、opencode、Kimi 适配器实测补全（DSH 的 `.dsh/skills` 全局 vs 项目级待确认）
- [ ] W2：ai-pm 包 6 个自产 skills 生产 + prompts.md
- [ ] OSS + GitHub Pages 开通后：`registry/index.json` 的 mirrors 填真实地址；发版脚本（打包 zip + sha256 + 更新 index）
- [ ] mac/linux 侧：asp.sh 依赖 python3（JSON 处理）；未实测（无 mac 环境，W2 找环境或用户实测）
- [ ] 发布 zip 制作时 .command 文件的可执行位保留（用 `zip -y` 或让用户首次运行 `bash asp.sh`）
- [ ] lite 免费版拆分脚本（GitHub 用）
- [ ] 水印机制：UPDATES.md 嵌买家 ID（发版时逐买家生成或群发时区分）

## 开发坑记录

1. **asp.ps1 必须带 UTF-8 BOM**——PS5.1 对无 BOM 的 UTF-8 按 ANSI 解析，中文字符串直接语法错误。本文件已加 BOM；**每次外部工具重写该文件后需检查 BOM**（`python -c "print(open('asp.ps1','rb').read(3)==b'\xef\xbb\xbf')"`）。
2. Git Bash 的 `/tmp` 与 PowerShell 不一致：PS 把 `/tmp/...` 解析到当前盘根 `C:\tmp\...`。跨 shell 测试用 Windows 绝对路径。
