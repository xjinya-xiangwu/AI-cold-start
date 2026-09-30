# AI 冷启动包 · Agent Starter Pack

> 把一套成型的「专家工作方法」——**19 个通用 skills（基础层）+ 12 个 PM 专业 skills** + 角色工作流 AGENTS.md + 零 key MCP 配置 + 42 条即用指令——10 分钟一键装进你电脑上的 7 个主流 AI agent，并每周更新。**v0.6.0 起支持一键环境迁移（export/migrate，零依赖，10 个 agent 含 Trae/Qoder/WorkBuddy）**。

![version](https://img.shields.io/badge/v0.5.0--tiered-2563EB) ![base](https://img.shields.io/badge/基础包--19%20skills%20%C2%A510-059669) ![ai--pm](https://img.shields.io/badge/PM专业包--12%20skills%20%C2%A519.9-8B5CF6) ![agents](https://img.shields.io/badge/agents-7-F59E0B) ![key](https://img.shields.io/badge/API%20key-%E9%9B%B6%E4%B8%AA%E6%89%8D%E8%83%BD%E7%94%A8-10B981)

**问题不在 AI 不会聊天，在于它没有方法。** 同样一句「帮我写个 PRD」，裸模型给一堆正确的废话；装包后先问你 4 个关键问题，再按 12 章专业模板出稿——AI 特有章节（能力边界 / 异常流 / 评测验收 / 人机协同）一个不漏。

## 分层定价（v0.5.0 起）

| 层 | 价格 | 内容 | 适合谁 |
|---|---|---|---|
| **基础包 `base`** | **¥10** | 19 个跨职业通用 skills（提效 4 / 质量 4 / 规划 7 / 通用工具 4）+ 1 个零 key MCP（context7 远程端点）+ 11 条通用指令 | 任何想让 AI 按方法干活的人：开发者 / 运营 / 学生 / 自由职业 |
| **PM 专业包 `ai-pm`** | **¥19.9** | 12 个 PM 专属 skills（洞察 4 / 设计 4 / AI 专项 2 / 战略 2）+ 31 条 PM 指令 + 九环 PM 工作流 | 产品经理 / 转岗 PM / AI 产品从业者 |
| **PM 完整版（两层全装）** | **¥29.9** | 31 skills + 42 指令全套 | 同上（买 ai-pm 自动含 base） |

- 基础层被**所有专业包复用**：后续 AI 开发者包、内容创作包 = ¥10 基础层 + 各自 ¥19.9 专业层
- 安装 `ai-pm` 时自动先装 `base`（依赖内置，一次完成）；只买基础包的用户拿不到专业层内容（交付 zip 物理隔离）

| 你对 AI 说 | 装包前 | 装包后 |
|---|---|---|
| 这 20 条需求排个优先级 | 按感觉排 | RICE 打分 + 每条理由 + 降级项的「重新上榜条件」 |
| 这是今天的会议记录 | 复述一遍 | 决议 / 行动项 / 未决三张表，未决必有拍板人 |
| 线上出问题了 | 慌乱中排查 | P0–P3 定级 + 止血方案先行，止损优先于根因 |
| 这周写个周报 | 流水账 | 进展 + 数据 + 风险 + 求助四段式，管理层 30 秒读完 |

## 特性

- 🔍 **自动探测**：识别本机已装的 AI agent，有几个装几个，装完输出报告；可执行文件不在 PATH 时如实标注「疑似仅配置残留」
- 🧩 **一键安装**：Windows 双击 `setup.bat`，全程中文提示
- 🩺 **MCP 体检（v0.7.0）**：`asp doctor` 对已部署的每条 MCP 做**真实 initialize 握手**，PASS/WARN/FAIL/SKIP 健康表——「配置写了」不算数，「实测握上手」才算
- 🔑 **零 key**：默认功能全部无需 API key；key 类增强服务只提供注册引导，**安装器永不收集你的 key**
- ➕ **只增不覆盖**：不碰你已有的配置与 skills；所有改动先自动备份到 `_backup/`，可完整回滚
- 🔁 **幂等**：重复安装不产生重复配置（managed-section 托管块机制）
- 📡 **周更**：`update.bat` 一键更新，双更新源 failover + sha256 校验
- 🔁 **环境迁移（v0.6.0）**：`asp export -Repo <私有仓库>` 把全部 agent 环境（skills/AGENTS.md/MCP/记忆）推到你的 **GitHub 私有仓库**；新机器 `git clone` 后 `asp migrate env` 一键还原——自动检测客户端可选导入、单项 ≤20MB 默认同步超大项可勾选、导入结果哈希验证。零 U 盘零网盘；详见 [docs/MIGRATE.md](docs/MIGRATE.md)
- 📦 **离线快照**：skills / AGENTS.md / prompts 全部随包本地化，装完不依赖外网（context7 走官方托管端点，联网可用）

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

装完先体检（推荐）：

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 doctor     # macOS/Linux: ./asp.sh doctor
```

对已部署的每条 MCP 做真实 initialize 握手，输出健康表；任一 FAIL 退出码为 1。

### 3. 装完后第一件事（首用三连）

打开 agent，任选一条直接发：

1. `用 idea-grilling 拷问我这个想法：给电商商家做 AI 客服`
2. `用 prd-drafting 帮我起草"企业知识库助手"的 PRD 框架`
3. `用 product-reporting 把这周进展写成一页周报`

## 支持的 agent（10 个）

| Agent | skills 位置 | AGENTS.md | MCP | 实测状态 |
|---|---|---|---|---|
| Zcode | `~/.zcode/skills/` | 工作区根 | `config.json` merge | ✅ 加载实证 |
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` 托管段 | `~/.claude.json` merge | ✅ 写入实证 |
| Codex CLI | `~/.codex/skills/` | `~/.codex/AGENTS.md` 托管段 | `config.toml` 托管块 | ✅ 写入实证 |
| Cursor | `~/.cursor/skills/` | `.cursor/rules/*.mdc` | `~/.cursor/mcp.json` merge | ✅ 写入实证 |
| opencode | `~/.config/opencode/skills/` | 项目根 AGENTS.md（`asp agents` 部署） | `opencode.json` | ✅ 写入实证 |
| DeepSeek Harness | `~/.dsh/skills/` | 全局 `~/.dsh/AGENTS.md` 注入 | 默认不启用 | ✅ 真机实测 |
| KimiWork（Kimi Claw） | `~/.kimi_openclaw/workspace/skills/` | workspace AGENTS.md | 插件体系（研究） | ✅ 真机实测 |
| Trae（字节） | 待实测 | 待实测 | `~/.trae/mcp.json`（迁移已支持） | 🔁 迁移 v0.1，安装待实测 |
| Qoder（阿里） | 待实测 | 待实测 | `~/.qoder/mcp.json`（迁移已支持） | 🔁 迁移 v0.1，安装待实测 |
| WorkBuddy | `~/.workbuddy/skills/` | SOUL.md 托管段（AGENTS.md 不在其加载链） | 设置界面手动添加（`mcp.json` 非加载面，v0.7 实测） | ✅ skills/SOUL.md 实测；MCP 走手动 |

> 「写入实证」= 安装/幂等/配置保留已真机验证，agent 侧首开冒烟由各端用户确认；实测环境 Win10 / PowerShell 5.1。
> 🔁 国内两端（Trae/Qoder）v0.1：**环境迁移已支持**（检测不到的路径自动跳过），包安装待真机实测后开放——配置真实布局欢迎 issue 反馈修正。WorkBuddy 已于 v0.6.1 真机实测转正：skills 部署 + 角色内容进 SOUL.md 托管段（实测加载链为 SOUL.md / IDENTITY.md / USER.md / BOOTSTRAP.md + skills/，AGENTS.md 不生效）。**v0.7.0 修正**：v0.6.1 的「mcp.json merge」结论被证伪——实测该文件不在 WorkBuddy 当前版本的 MCP 加载面（真实面为每会话生成的 agent-cli-mcp-config），MCP 改为设置界面手动添加。

## 内容清单（v0.5.0 分层）

### 基础包 base（19 skills，跨职业通用）

| 类别 | skills |
|---|---|
| 提升开发效率 | dev-handoff · tech-spec-review · release-notes · mermaid-diagrams |
| 保障质量 | bug-triage · post-mortem · launch-readiness · decision-premortem |
| 规划类 | idea-grilling · assumption-audit · okr-planning · project-kickoff · risk-register · stakeholder-mapping · minimal-solution |
| 通用工具 | meeting-to-decisions · data-insight · experiment-design · metric-design |

随包：通用版 AGENTS.md（想法拷问→规划→协作→质量→复盘 五环）+ 通用 prompts × 11 + **1 个零 key MCP**（asp-context7，官方托管远程端点——零 node 依赖、零冷启动、`asp doctor` 可实测；asp-memory / asp-sequential-thinking 自 v0.7.0 移入可选件，决策理由见 `mcp/optional-mcp.md`）

### PM 专业包 ai-pm（12 skills，PM 专属）

| 类别 | skills |
|---|---|
| 发现与洞察 | user-research-interview · market-sizing · competitor-analysis · feedback-triage |
| 定义与设计 | prd-drafting · prd-review · user-story · feature-prioritization |
| AI 产品专项 | ai-eval-design · ai-ux-patterns |
| 战略与交付 | roadmap-planning · product-reporting |

随包：AI PM 两层版 AGENTS.md（31 skills 地图 + 九环工作流 + 知识基准）+ PM prompts × 31
覆盖率 **59%**：53 项 PM 全生命周期任务映射（✅31 / 🔶10 / ❌12），见 [packs/ai-pm/COVERAGE.md](packs/ai-pm/COVERAGE.md)

## 更新机制

```powershell
# 双击 update.bat，或
powershell -ExecutionPolicy Bypass -File asp.ps1 update
```

版本对比 → 下载 → **sha256 校验** → 增量部署（保留你的 `_state` / `_backup`）。每次发版的变更说明见 [UPDATES.md](UPDATES.md)。

## 目录结构

```
AI-cold-start/
├── asp.ps1 / asp.sh        # 安装/更新器（零外部依赖，支持包依赖链）
├── setup.bat / setup.command / update.bat
├── adapters/               # 各 agent 适配器（探测路径/部署策略）
├── packs/
│   ├── base/               # 基础包（¥10，19 skills 跨职业通用）
│   │   ├── skills/
│   │   ├── prompts/        # 通用指令 ×11
│   │   ├── mcp/            # MCP 模板 + optional-mcp.md（MCP 归属基础层）
│   │   └── AGENTS.md       # 通用工作流
│   └── ai-pm/              # PM 专业包（¥19.9，12 skills，requires base）
│       ├── skills/
│       ├── prompts/        # PM 指令 ×31
│       ├── AGENTS.md       # 两层版工作流与知识基准
│       ├── COVERAGE.md     # 53 项任务覆盖映射
│       └── THIRD-PARTY-NOTICES.md
├── registry/index.json     # 周更源索引（两包版本/哈希/mirrors）
├── collector/              # 周更抓源脚本 + 候选/调研报告
├── scripts/                # build-release（按包过滤打包）/ make-lite
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

- [ ] **交付形态 v2**：电商交付一段安装代码（`irm …/i/<orderToken> | iex`）+ 本地 UI 选择式安装（环境×内容包三步流）+ 按订单周签 URL（7 天 TTL）；更新触达三档（L2 勾选式自动更新默认关 / L1 群通知 / L0 重跑兜底）——设计已冻结，见 [docs/DELIVERY-V2.md](docs/DELIVERY-V2.md) 与 [docs/ANTI-RESALE.md](docs/ANTI-RESALE.md)（EULA"转售即分销"30% 返佣）
- [ ] **安装体验 v2（ONBOARDING V2）**：W1 市场共存双向桥 · W2 凭据钱包+doctor 流量灯体检 · W3 首装对照（装前基线→装后同题→before/after 报告）· W4 零决策安装+弱模型 CI 矩阵——设计见 [docs/ONBOARDING-V2.md](docs/ONBOARDING-V2.md)；**W1 阶段1 已落地**：市场上架准备（渠道事实源 [registry/marketplace-map.json](registry/marketplace-map.json) + 素材生成器 [scripts/gen-marketplace-kit.py](scripts/gen-marketplace-kit.py) + 上架指南 [docs/MARKETPLACE-LISTING.md](docs/MARKETPLACE-LISTING.md)；Claude 官方插件市场 kit-ready / skills.sh 已 live / Qoder format-ready）；**W2 的 doctor v1（MCP 流量灯体检）已于 v0.7.0 提前落地**
- [ ] AI 开发者包 / AI 内容创作包（¥10 基础层 + 各自专业层 ¥19.9，复用 base）
- [ ] P1 skills：问卷设计 / UAT 验收 / 用户画像 / 增长实验 / 演示材料 / 竞品监控 / 定价设计
- [ ] 免费 lite 版拆分（make-lite，适配分层结构）
- [ ] mac/linux `asp.sh` 端到端实测；更多 agent 适配（Gemini CLI / Qwen Code 等）
- [ ] registry 双源托管上线（阿里云 OSS 主源 + GitHub Pages 备源，见 [docs/HOSTING.md](docs/HOSTING.md)）

## 更新日志

见 [UPDATES.md](UPDATES.md) —— v0.1.0（6 skills）→ v0.2.0（15）→ v0.3.0（26）→ v0.4.0（31）→ **v0.5.0（分层：base 19 + ai-pm 12，2026-09-29）**。
