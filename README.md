# AI 冷启动包 · Agent Starter Pack

> 把一套成型的「专家工作方法」——31 个实战 skills + 角色工作流 AGENTS.md + 零 key MCP 配置 + 42 条即用指令——10 分钟一键装进你电脑上的 7 个主流 AI agent，并每周更新。

![version](https://img.shields.io/badge/ai--pm-v0.4.0-2563EB) ![skills](https://img.shields.io/badge/skills-31%20%C3%97%208%E7%B1%BB-059669) ![agents](https://img.shields.io/badge/agents-7-F59E0B) ![platform](https://img.shields.io/badge/platform-Windows%20%7C%20mac%2FLinux-8B5CF6) ![key](https://img.shields.io/badge/API%20key-%E9%9B%B6%E4%B8%AA%E6%89%8D%E8%83%BD%E7%94%A8-10B981)

**问题不在 AI 不会聊天，在于它没有方法。** 同样一句「帮我写个 PRD」，裸模型给一堆正确的废话；装包后先问你 4 个关键问题，再按 12 章专业模板出稿——AI 特有章节（能力边界 / 异常流 / 评测验收 / 人机协同）一个不漏。

| 你对 AI 说 | 装包前 | 装包后 |
|---|---|---|
| 这 20 条需求排个优先级 | 按感觉排 | RICE 打分 + 每条理由 + 降级项的「重新上榜条件」 |
| 这是今天的会议记录 | 复述一遍 | 决议 / 行动项 / 未决三张表，未决必有拍板人 |
| 线上出问题了 | 慌乱中排查 | P0–P3 定级 + 止血方案先行，止损优先于根因 |
| 这周写个周报 | 流水账 | 进展 + 数据 + 风险 + 求助四段式，管理层 30 秒读完 |

## 特性

- 🔍 **自动探测**：识别本机已装的 AI agent，有几个装几个，装完输出报告
- 🧩 **一键安装**：Windows 双击 `setup.bat`，全程中文提示
- 🔑 **零 key**：默认功能全部无需 API key；key 类增强服务只提供注册引导，**安装器永不收集你的 key**
- ➕ **只增不覆盖**：不碰你已有的配置与 skills；所有改动先自动备份到 `_backup/`，可完整回滚
- 🔁 **幂等**：重复安装不产生重复配置（managed-section 托管块机制）
- 📡 **周更**：`update.bat` 一键更新，双更新源 failover + sha256 校验
- 📦 **离线快照**：全部内容随包本地化，装完不依赖外网

## 快速开始

### 1. 获取

```bash
git clone https://github.com/xjinya-xiangwu/AI-cold-start.git
cd AI-cold-start
```

或 GitHub 页面右上角 **Code → Download ZIP** 下载解压。

### 2. 安装

**Windows**（PowerShell 5.1+，系统自带）：双击 `setup.bat`，或

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 install
```

**macOS / Linux**（依赖 python3）：

```bash
bash asp.sh install
```

安装器流程：探测 agent → 确认 → 部署 skills / AGENTS.md / MCP → 输出安装报告。装完**重启你的 agent** 生效。

### 3. 装完后第一件事（首用三连）

打开 agent，任选一条直接发：

1. `用 idea-grilling 拷问我这个想法：给电商商家做 AI 客服`
2. `用 prd-drafting 帮我起草"企业知识库助手"的 PRD 框架`
3. `用 product-reporting 把这周进展写成一页周报`

## 支持的 agent（7 个）

| Agent | skills 位置 | AGENTS.md | MCP | 实测状态 |
|---|---|---|---|---|
| Zcode | `~/.zcode/skills/` | 工作区根 | `config.json` merge | ✅ 加载实证 |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` 托管段 | `~/.claude.json` merge | ✅ 写入实证 |
| Codex CLI | `~/.codex/skills/` | `~/.codex/AGENTS.md` 托管段 | `config.toml` 托管块 | ✅ 写入实证 |
| Cursor | `~/.cursor/skills/` | `.cursor/rules/*.mdc` | `~/.cursor/mcp.json` merge | ✅ 写入实证 |
| opencode | `~/.config/opencode/skills/` | 项目根 AGENTS.md（`asp agents` 部署） | `opencode.json` | ✅ 写入实证 |
| DeepSeek Harness | `~/.dsh/skills/` | 全局 `~/.dsh/AGENTS.md` 注入 | 默认不启用 | ✅ 真机实测 |
| KimiWork（Kimi Claw） | `~/.kimi_openclaw/workspace/skills/` | workspace AGENTS.md | 插件体系（研究） | ✅ 真机实测 |

> 「写入实证」= 安装/幂等/配置保留已真机验证，agent 侧首开冒烟由各端用户确认；实测环境 Win10 / PowerShell 5.1。

## 首发内容：AI 产品经理包（v0.4.0）

**31 skills × 8 大类**，覆盖 PM 全生命周期：

| 类别 | skills |
|---|---|
| 思路与决策 | idea-grilling · decision-premortem · assumption-audit |
| 发现与洞察 | user-research-interview · market-sizing · competitor-analysis · feedback-triage |
| 定义与设计 | prd-drafting · prd-review · user-story · feature-prioritization · minimal-solution · mermaid-diagrams |
| 数据与实验 | metric-design · experiment-design · data-insight |
| AI 产品专项 | ai-eval-design · ai-ux-patterns |
| 规划与立项 | okr-planning · project-kickoff · risk-register · stakeholder-mapping |
| 研发协作 | tech-spec-review · dev-handoff · launch-readiness · bug-triage · post-mortem |
| 战略与交付 | roadmap-planning · meeting-to-decisions · release-notes · product-reporting |

随包附带：

- **AGENTS.md**：AI PM 角色工作流（反馈分诊 → 拷问 → PRD → 交接 → 实验 → 汇报复盘 九环）+ 知识基准速记层
- **prompts × 42**：需求澄清 10 / PRD 写作 8 / 评审决策 8 / 数据分析 8 / 面试练习 8
- **MCP 默认 3 个（全零 key）**：asp-context7（查最新文档）· asp-memory（跨会话记忆）· asp-sequential-thinking（深度推理）；Brave / GitHub / Notion 等 key 类服务见 `mcp/optional-mcp.md` 注册引导
- **覆盖率 59%**：53 项 PM 全生命周期任务映射（✅31 / 🔶10 / ❌12），见 [packs/ai-pm/COVERAGE.md](packs/ai-pm/COVERAGE.md)

## 更新机制

```powershell
# 双击 update.bat，或
powershell -ExecutionPolicy Bypass -File asp.ps1 update
```

版本对比 → 下载 → **sha256 校验** → 增量部署（保留你的 `_state` / `_backup`）。每次发版的变更说明见 [UPDATES.md](UPDATES.md)。

## 目录结构

```
AI-cold-start/
├── asp.ps1 / asp.sh        # 安装/更新器（零外部依赖）
├── setup.bat / setup.command / update.bat
├── adapters/               # 各 agent 适配器（探测路径/部署策略）
├── packs/ai-pm/            # AI 产品经理包
│   ├── skills/             # 31 个 skill（每目录一个 SKILL.md）
│   ├── prompts/prompts.md  # 42 条即用指令
│   ├── mcp/                # MCP 模板 + optional-mcp.md 注册引导
│   ├── AGENTS.md           # 角色工作流与知识基准
│   ├── COVERAGE.md         # 53 项任务覆盖映射
│   └── THIRD-PARTY-NOTICES.md
├── registry/index.json     # 周更源索引（版本/哈希/mirrors）
├── collector/              # 周更抓源脚本 + 候选/调研报告
├── scripts/                # build-release / make-lite
├── docs/                   # 开发/托管/商品文案
└── UPDATES.md              # 更新日志
```

## 隐私与安全

- 安装器**不上传任何数据**（`update` 仅从 registry 拉取公开索引）
- **永不收集 API key**；key 类服务由你自己注册并填入自己的配置
- 修改前自动备份：`_backup/<agent-id>-<文件名>.<时间戳>.bak`
- 用户已有 MCP / 配置零破坏（同名跳过、托管块外内容不动）——7 agent 真机 16/16 校验通过

## 许可与致谢

- 本仓库 skills 绝大多数为原创自产
- 少数 skill 基于 **MIT / Apache-2.0** 开源项目改造，出处与许可声明见 [packs/ai-pm/THIRD-PARTY-NOTICES.md](packs/ai-pm/THIRD-PARTY-NOTICES.md)
- 采集纪律：**永不收录 NonCommercial（CC BY-NC / NC-SA）许可的项目**，无 license 仓库仅作思路参考
- MCP 增强服务依赖 node/npx 运行时（skills 不依赖）；无 node 机器上 MCP 自动跳过，安装报告会如实标注

## 路线图

- [ ] AI 开发者包 / AI 内容创作包（第二、三个 SKU）
- [ ] P1 skills：问卷设计 / UAT 验收 / 用户画像 / 增长实验 / 演示材料 / 竞品监控 / 定价设计
- [ ] 免费 lite 版拆分（make-lite）
- [ ] mac/linux `asp.sh` 端到端实测；更多 agent 适配（Gemini CLI / Qwen Code 等）
- [ ] registry 双源托管上线（阿里云 OSS 主源 + GitHub Pages 备源，见 [docs/HOSTING.md](docs/HOSTING.md)）

## 更新日志

见 [UPDATES.md](UPDATES.md) —— v0.1.0（6 skills）→ v0.2.0（15）→ v0.3.0（26）→ **v0.4.0（31，2026-09-28）**。
