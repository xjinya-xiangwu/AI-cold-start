# AI 产品经理冷启动包（0.2.0）

装完后第一件事（示例指令）：

1. `用 prd-drafting 帮我起草"企业知识库助手"的 PRD 框架`
2. `用 feature-prioritization 把这 20 条需求按 RICE 排序，降级项给重新上榜条件`
3. `用 experiment-design 设计一个验证新定价页的 A/B 实验`
4. `用 meeting-to-decisions 把这段会议记录整理成决议和行动项`
5. `用 market-sizing 测算国内电商 SaaS 的 TAM/SAM/SOM`

## 内容清单

### skills（15 个，全自产，覆盖 PM 全工作流）

| 阶段 | skills |
|---|---|
| 发现与洞察 | user-research-interview · market-sizing · competitor-analysis |
| 定义与设计 | prd-drafting · prd-review · user-story · feature-prioritization |
| 数据与实验 | metric-design · experiment-design · data-insight |
| AI 产品专项 | ai-eval-design · ai-ux-patterns |
| 战略与交付 | roadmap-planning · meeting-to-decisions · release-notes |

### AGENTS.md

AI PM 角色工作流 + 技能地图 + 知识基准（全局型 agent 自动部署；workspace 型 agent 运行 `asp agents <项目目录>`）。

### MCP（3 个默认零 key 即用 + 可选扩展）

- asp-context7（最新文档查询）
- asp-memory（跨会话记忆）
- asp-sequential-thinking（结构化多步推理，PRD/实验设计类任务质量提升）

需要 key 或 uvx 的高价值服务（Brave 搜索 / GitHub / Notion / fetch / sqlite）见 `mcp/optional-mcp.md`，含注册指引与配置片段——**安装器永不收集你的 key**。

### prompts

常用提示词模板见 prompts.md。

## 支持 agent

Claude Code / Zcode / DeepSeek Harness / Kimi（v0.2 实证适配）；Codex（v0.2 实测加入）；Cursor / opencode（适配器就绪，待实测）
