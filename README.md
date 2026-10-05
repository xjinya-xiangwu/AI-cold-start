# 智能体冷启动包 · Agent Cold-start Pack

> 把一套成型的「专家工作方法」——**25 个通用 skills（基础层）+ 12 个 PM 专业 skills（方向加购）** + 角色工作流 AGENTS.md + 可选 MCP 增强 + 42 条即用指令——10 分钟一键装进你电脑上的 10 个主流 AI agent，并每周更新。**v0.6.0 起支持一键环境迁移（export/migrate，零依赖，10 个 agent 含 Trae/Qoder/WorkBuddy）**。

![version](https://img.shields.io/badge/v0.13.0-2563EB) ![base](https://img.shields.io/badge/%E5%9F%BA%E7%A1%80%E5%8C%85--25%20skills%20%C2%A520-059669) ![addon](https://img.shields.io/badge/%E6%96%B9%E5%90%91%E5%8A%A0%E8%B4%AD--%2B%C2%A510%2F%E6%96%B9%E5%90%91-8B5CF6) ![agents](https://img.shields.io/badge/agents-10-F59E0B) ![key](https://img.shields.io/badge/API%20key-%E9%9B%B6%E4%B8%AA%E6%89%8D%E8%83%BD%E7%94%A8-10B981)

**问题不在 AI 不会聊天，在于它没有方法。** 同样一句「帮我写个 PRD」，裸模型给一堆正确的废话；装包后先问你 4 个关键问题，再按 12 章专业模板出稿——AI 特有章节（能力边界 / 异常流 / 评测验收 / 人机协同）一个不漏。

## 定价与商品结构（v0.6.0 上架口径，2026-10-02 定稿）

**一个商品，一个底座，按方向加购：**

| 商品 | 价格 | 内容 |
|---|---|---|
| **基础包 `base`（必选底座）** | **¥20 买断** | 25 个跨职业通用 skills（想清楚 5 / 排得起 5 / 兜得住 7 / 算得清 3 / 用得爽 5）+ 11 条通用指令 + 安装器 + 3 个月周更；零 MCP 默认（增强由 skills 承载，可选一键加） |
| **方向加购 `ai-pm`（可选）** | **+¥10 / 方向** | 当前现货：**AI 产品经理方向**——12 个 PM 专属 skills（洞察 4 / 设计 4 / AI 专项 2 / 战略 2）+ 31 条 PM 指令 + 九环 PM 工作流；含基础包合计 ¥30 |
| 规划中方向 | — | AI 开发者方向、AI 内容创作方向（各 +¥10，复用 base，上架日期不预先承诺） |

- 安装 `ai-pm` 时自动先装 `base`（依赖内置，一次完成）；只买基础包的用户拿不到专业层内容（交付 zip 物理隔离）
- 品牌口径：**智能体冷启动包 / Agent Cold-start Pack**（2026-10-02 定稿，全渠道统一）

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
- 🔑 **零 key**：默认功能全部无需 API key；key 类增强服务只提供注册引导，**安装器不收集任何 key**
- ➕ **只增不覆盖（配置文件）**：AGENTS.md / MCP 配置经 managed-section 托管块只增不覆盖，改动前自动备份可回滚。**技能目录覆盖/嵌套缺陷（PRD R00）修复中**：已复现 Windows 对已存在技能目录会产生 `技能名/技能名/` 嵌套、mac 会直接覆盖——修复并真机复核前，对已装过技能的机器执行安装/更新前请先手动备份 skills 目录
- 🔁 **幂等**：重复安装不产生重复配置（managed-section 托管块机制）
- 📡 **周更**：`update.bat` 一键更新，双更新源 failover + sha256 校验；**⚠️ Windows 已装技能周更嵌套缺陷（R00）修复并 Win10 真机复核前，已装过技能的机器暂不建议双击周更（PRD §2.3 门禁）**
- 🔁 **环境迁移（v0.6.0 → ⏸ D18 暂停推荐）**：`asp export -Repo <私有仓库>` 通道在凭证去标识化（R01：只导结构 + 占位符）落地前**暂停对外推荐**——当前导出会原样打包 MCP 配置，含 key 即随包上传；过渡期请用本地包方式（详见 [docs/MIGRATE.md](docs/MIGRATE.md) 顶部说明）
- 📦 **离线快照**：skills / AGENTS.md / prompts 全部随包本地化；v0.8.0 起默认零 MCP——文档查新等增强能力由 skills 指挥 agent 内置 web 工具完成，无额外运行时与端点依赖
- 🔌 **一键常用 MCP（v0.10.0+，可选）**：`asp mcp install` 一条命令给全部 agent 装常用增强，三个官方预设——**essentials**（context7 / 记忆 / 深度思考，零 key）、**work-tools 办公工具集**（Figma / Notion / Jira·Confluence / Linear / Slack / Asana / MS Learn 官方 MCP）、**dev-tools 开发者集**（Microsoft Playwright / MCP 官方 filesystem / Supabase）；全部官方出品零自建，OAuth 在 agent 内登录不存 key，无 npx 环境自动降级，只增不覆盖
- 🖥️ **两步选择式安装 UI（v0.12.0）**：双击 `setup.bat` 或 `asp ui` 打开本地选择页——**一步选完**部署目标（探测到的 agent）× 内容包 × MCP 预设，**第二步一键执行**：实时进度 → 安装报告（doctor 验证 / 首用指令 / 更新方式）。v0.13.0 升级为**已购清单式**：技能逐项勾选（带简介）、MCP 三档并入清单、支持子集安装。无浏览器环境可用等价命令行（install / mcp install）

## 快速开始

### 1. 获取

```bash
git clone https://github.com/xjinya-xiangwu/AI-cold-start.git
cd AI-cold-start
```

或 GitHub 页面右上角 **Code → Download ZIP** 下载解压。

### 2. 安装

**Windows**（PowerShell 5.1+，系统自带）：双击 `setup.bat` 打开**两步选择页**，或命令行

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 ui
```

不想用页面时，等价命令行：

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 install          # 全部探测到的 agent
powershell -ExecutionPolicy Bypass -File asp.ps1 mcp install      # essentials MCP 预设
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

### 3. 可选增强：一键常用 MCP（零 key）

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 mcp install
```

context7 文档检索（远程端点免 node）+ 跨会话记忆 + 深度思考，**一次选择写入全部已装 agent**；无 npx 环境自动降级，`asp doctor` 验证握手。setup.bat 安装时也会问一次。

第二个预设 **work-tools 办公工具集**：`asp mcp install work-tools`——Figma（官方本地端点，需桌面端运行）/ Notion / Jira·Confluence（Atlassian）/ Linear / Microsoft Learn 五件产品官方 MCP，OAuth 首连在 agent 内授权、配置不存任何密钥。

### 4. 装完后第一件事（首用三连）

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

## 内容清单（v0.13.0）

### 基础包 base（25 skills，跨职业通用）

| 类别 | skills |
|---|---|
| 想清楚（5） | idea-grilling · brainstorming · assumption-audit · decision-premortem · minimal-solution |
| 排得起（5） | okr-planning · project-kickoff · risk-register · stakeholder-mapping · meeting-to-decisions |
| 兜得住（7） | bug-triage · systematic-debugging · verify-before-done · post-mortem · launch-readiness · tech-spec-review · dev-handoff |
| 算得清（3） | metric-design · experiment-design · data-insight |
| 用得爽（5） | ponytail · adhd-mode · fresh-docs（文档查新） · release-notes · mermaid-diagrams |

随包：通用版 AGENTS.md（想法拷问→规划→协作→质量→复盘 五环 + 文档查新纪律）+ 通用 prompts × 11 + **零 MCP 默认**（v0.8.0：文档查新由 fresh-docs skill 指挥 agent 内置 web 工具完成；context7 / memory / sequential-thinking 全部转可选，见 `mcp/optional-mcp.md`——设计决策见 [docs/DESIGN-ZERO-MCP.md](docs/DESIGN-ZERO-MCP.md)）

### 方向加购 ai-pm（12 skills，AI 产品经理方向）

| 类别 | skills |
|---|---|
| 发现与洞察 | user-research-interview · market-sizing · competitor-analysis · feedback-triage |
| 定义与设计 | prd-drafting · prd-review · user-story · feature-prioritization |
| AI 产品专项 | ai-eval-design · ai-ux-patterns |
| 战略与交付 | roadmap-planning · product-reporting |

随包：AI PM 两层版 AGENTS.md（37 skills 地图 + 九环工作流 + 知识基准）+ PM prompts × 31
覆盖率 **59%**：53 项 PM 全生命周期任务映射（✅31 / 🔶10 / ❌12），见 [packs/ai-pm/COVERAGE.md](packs/ai-pm/COVERAGE.md)

## 更新机制

```powershell
# 双击 update.bat，或
powershell -ExecutionPolicy Bypass -File asp.ps1 update
```

版本对比 → 下载 → **sha256 校验** → 增量部署（保留你的 `_state` / `_backup`）。每次发版的变更说明见 [UPDATES.md](UPDATES.md)。**GitHub Pages 周更主源已上线（v0.13.0），阿里云 OSS 备源待开通**。

## 目录结构

```
AI-cold-start/
├── asp.ps1 / asp.sh        # 安装/更新器（零外部依赖，支持包依赖链）
├── setup.bat / setup.command / update.bat
├── adapters/               # 各 agent 适配器（探测路径/部署策略）
├── packs/
│   ├── base/               # 基础包（¥20，25 skills 跨职业通用）
│   │   ├── skills/
│   │   ├── prompts/        # 通用指令 ×11
│   │   ├── mcp/            # MCP 模板 + optional-mcp.md（MCP 归属基础层）
│   │   └── AGENTS.md       # 通用工作流
│   └── ai-pm/              # 方向加购（+¥10，AI 产品经理方向，12 skills，requires base）
│       ├── skills/
│       ├── prompts/        # PM 指令 ×31
│       ├── AGENTS.md       # 两层版工作流与知识基准
│       ├── COVERAGE.md     # 53 项任务覆盖映射
│       └── THIRD-PARTY-NOTICES.md
├── registry/index.json     # 周更源索引（两包版本/哈希/mirrors，Pages 主源已上线）
├── collector/              # 周更抓源脚本 + 候选/调研报告
├── scripts/                # build-release（按包过滤打包）/ make-lite
├── docs/                   # 开发/托管/商品文案
└── UPDATES.md              # 更新日志
```

## 隐私与安全

- 安装器**不上传任何数据**（`update` 仅从 registry 拉取公开索引）
- **不收集任何 API key**；key 类服务由你自己注册并填入自己的配置
- 修改前自动备份：`_backup/<agent-id>-<文件名>.<时间戳>.bak`
- 用户已有 MCP / 配置零破坏（同名跳过、托管块外内容不动）——多 agent 真机安装逐项校验通过

## 许可与致谢

- 本仓库 skills 绝大多数为原创自产
- 少数 skill 基于 **MIT / Apache-2.0** 开源项目改造，出处与许可声明见 [packs/ai-pm/THIRD-PARTY-NOTICES.md](packs/ai-pm/THIRD-PARTY-NOTICES.md)
- 采集纪律：**永不收录 NonCommercial（CC BY-NC / CC-SA）许可的项目**，无 license 仓库仅作思路参考
- v0.8.0 起默认零 MCP（增强能力由 skills 承载，零运行时依赖）；用户自加的可选 MCP 中 npx 类仍依赖 node——无 node 机器上自动跳过，`asp doctor` 会如实标注

## 路线图

- [ ] **交付形态 v2**：电商交付一段安装代码（`irm …/i/<orderToken> | iex`）+ 本地 UI 选择式安装（环境×内容包三步流）+ 按订单周签 URL（7 天 TTL）；更新触达三档（L2 勾选式自动更新默认关 / L1 群通知 / L0 重跑兜底）——设计已冻结，见 [docs/DELIVERY-V2.md](docs/DELIVERY-V2.md) 与 [docs/ANTI-RESALE.md](docs/ANTI-RESALE.md)（EULA"转售即分销"30% 返佣）
- [ ] **安装体验 v2（ONBOARDING V2）**：W1 市场共存双向桥 · W2 凭据钱包+doctor 流量灯体检 · W3 首装对照（装前基线→装后同题→before/after 报告）· W4 零决策安装+弱模型 CI 矩阵——设计见 [docs/ONBOARDING-V2.md](docs/ONBOARDING-V2.md)；**W1 阶段1 已落地**：市场上架准备（渠道事实源 [registry/marketplace-map.json](registry/marketplace-map.json) + 素材生成器 [scripts/gen-marketplace-kit.py](scripts/gen-marketplace-kit.py) + 上架指南 [docs/MARKETPLACE-LISTING.md](docs/MARKETPLACE-LISTING.md)；Claude 官方插件市场 kit-ready / skills.sh 已 live / Qoder format-ready）；**W2 的 doctor v1（MCP 流量灯体检）已于 v0.7.0 提前落地**
- [ ] AI 开发者方向 / AI 内容创作方向（各 +¥10 加购，复用 base，规划中）
- [ ] P1 skills：问卷设计 / UAT 验收 / 用户画像 / 增长实验 / 演示材料 / 竞品监控 / 定价设计
- [ ] 免费 lite 版拆分（make-lite，适配分层结构）
- [ ] mac/linux `asp.sh` 端到端实测；更多 agent 适配（Gemini CLI / Qwen Code 等）
- [ ] registry OSS 备源开通（GitHub Pages 主源已上线，见 [docs/HOSTING.md](docs/HOSTING.md)）

## 更新日志

见 [UPDATES.md](UPDATES.md) —— v0.1.0（6 skills）→ v0.4.0（31）→ v0.5.0（分层：base + ai-pm）→ v0.6.x（迁移+10 agents+适配器审计）→ v0.7.0（MCP 三件套重构+doctor）→ v0.8.0（零 MCP 默认 + fresh-docs）→ v0.9.0（base 扩至 25 skills）→ v0.10.x（常用 MCP 一键装+办公工具集）→ v0.12.0（两步选择式安装 UI）→ **v0.13.0（已购清单式安装页，2026-10-01）**。
