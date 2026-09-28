# AI 产品经理冷启动包（0.4.0）

装完后第一件事（示例指令）：

1. `用 idea-grilling 拷问我这个想法：给电商商家做 AI 客服`
2. `用 prd-drafting 帮我起草"企业知识库助手"的 PRD 框架`
3. `用 feature-prioritization 把这 20 条需求按 RICE 排序，降级项给重新上榜条件`
4. `用 tech-spec-review 给我六问清单，明天评审开发的技术方案`
5. `用 bug-triage 给这两条线上问题定级，给止血方案`
6. `用 product-reporting 把这周进展写成一页周报`
7. `用 feedback-triage 整理这 50 条用户反馈，分诊出值得做的需求`
8. `用 meeting-to-decisions 把这段会议记录整理成决议和行动项`

## 内容清单

### skills（31 个：29 自产 + 2 个基于开源许可项目改造，见 THIRD-PARTY-NOTICES.md）

| 阶段 | skills |
|---|---|
| 思路与决策 | idea-grilling（决策树拷问） · decision-premortem（失败预演+可逆性） · assumption-audit（假设审计） |
| 发现与洞察 | user-research-interview · market-sizing · competitor-analysis · feedback-triage（反馈分诊/需求池） |
| 定义与设计 | prd-drafting · prd-review · user-story · feature-prioritization · minimal-solution（最简梯子） · mermaid-diagrams（PRD 配图） |
| 数据与实验 | metric-design · experiment-design · data-insight |
| AI 产品专项 | ai-eval-design · ai-ux-patterns |
| 规划与立项 | okr-planning · project-kickoff · risk-register · stakeholder-mapping |
| 研发协作 | tech-spec-review · dev-handoff · launch-readiness · bug-triage（P0-P3 分级响应） · post-mortem（项目/事故复盘） |
| 战略与交付 | roadmap-planning · meeting-to-decisions · release-notes · product-reporting（四段式汇报） |

### AGENTS.md

AI PM 角色工作流 + 8 类技能地图 + 知识基准（框架选择/样本量直觉/交互模式/可逆性/最简梯子速记）。

### MCP（3 个默认零 key 即用 + 可选扩展）

- asp-context7（最新文档查询）
- asp-memory（跨会话记忆）
- asp-sequential-thinking（结构化多步推理）

需要 key 或 uvx 的高价值服务（Brave 搜索 / GitHub / Notion / fetch / sqlite）见 `mcp/optional-mcp.md`，含注册指引与配置片段——**安装器永不收集你的 key**。

### prompts

常用提示词模板见 prompts.md。

## 支持 agent

Claude Code / Zcode / DeepSeek Harness / Kimi（v0.2 实证适配）；Codex（v0.2 实测加入）；Cursor / opencode（适配器就绪，待实测）
