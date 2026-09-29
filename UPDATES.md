# 更新日志

## v0.5.0（2026-09-29）

**分层定价重构**：单包 29.9 拆为「基础包 ¥10（跨职业通用）+ PM 专业包 ¥19.9（含基础合计 29.9）」两层结构。31 个 skills 零增减，全部按"跨职业通用 vs PM 专属"重新归层；基础层将被后续开发者包/内容创作包复用。

- **packs/base（新，19 skills 四类）**：提升开发效率 4（dev-handoff/tech-spec-review/release-notes/mermaid-diagrams）+ 保障质量 4（bug-triage/post-mortem/launch-readiness/decision-premortem）+ 规划类 7（idea-grilling/assumption-audit/okr-planning/project-kickoff/risk-register/stakeholder-mapping/minimal-solution）+ 通用工具 4（meeting-to-decisions/data-insight/experiment-design/metric-design）
- **packs/ai-pm（12 skills 四类）**：发现与洞察 4 + 定义与设计 4 + AI 产品专项 2 + 战略与交付 2
- **AGENTS.md 分层**：base 版（通用五环工作流 + 通用知识基准）/ ai-pm 版（两层 31 技能地图 + 九环 PM 工作流，安装依赖链顺序保证后装超集胜出）
- **prompts 拆分**：通用 11 条（决策评审 4/数据实验 7）→ base；PM 专属 31 条留 ai-pm（合计 42 不变）
- **MCP 归属 base**（3 个零 key 为通用能力）；专业包无 mcp 目录，安装器跳过
- **安装器**：包依赖链机制（deps.json requires，install ai-pm 自动先装 base，一次确认）；默认包改为 base；新增 list 命令；state 记录 packs 数组；state 写入修复为无 BOM
- **发版隔离**：build-release 按包过滤打包——base.zip 物理不含专业层内容（¥10 买家拿不到 ai-pm skills）；ai-pm.zip 含 base+ai-pm（依赖安装自包含）；registry/index.json 升级 v0.2 两包结构（含价格档位/skills 分类/requires）
- **商品文案 v3**（docs/shop-listing.md）：两商品结构（基础包/PM 专业包各自完整详情页 + 互链引导 + 已购补差价 FAQ）；数字口径备忘同步分层

## v0.4.0（2026-09-28）

PM 包 31 skills 版：落地覆盖映射定位的 5 个 P0 缺口 skill（26 → 31），生命周期闭环补齐「反馈分诊 → … → 汇报 → 复盘」。

- 新增 **feedback-triage**（发现与洞察）：多渠道反馈归一→去重聚类→四问分诊→分级路由（bug/需求/误解/噪音），需求卡片带证据衔接 feature-prioritization（映射 #11/#43，自产）
- 新增 **product-reporting**（战略与交付）：周报/月报/季度四段式（进展+数据+风险+求助）+ RAG 健康度 + 管理版 300 字封顶（映射 #47；采集改造自 anthropics/knowledge-work-plugins status-report（Apache-2.0）+ janellecipriano/pm-skills（MIT））
- 新增 **post-mortem**（研发协作）：项目复盘+事故复盘双模，无指责/5 Whys/时间线/改进项带 owner 与期限/定稿不可改（映射 #51；采集改造自 janellecipriano/pm-skills、riekelt/technical-writer、wshobson/agents 三个 MIT 源）
- 新增 **bug-triage**（研发协作）：P0-P3 分级矩阵+响应时限+升级规则+分钟级止血动作库（止损优先于根因）（映射 #33，自产）
- 新增 **mermaid-diagrams**（定义与设计）：六种图型选型+中文节点语法避坑+可读性检查，PRD 流程图零依赖出图（映射 #19，自产；无 license 仓库仅思路参考）
- 新增 packs/ai-pm/THIRD-PARTY-NOTICES.md：开源采集源 license 声明（Apache-2.0 ×1、MIT ×3）；红线 deanpeters（CC BY-NC-SA）保持零接触
- AGENTS.md：技能地图扩至 31 skills；工作流改为「反馈分诊→…→汇报复盘」九环；新增 bug 分级/反馈四问速记
- COVERAGE.md：53 项任务 ✅31（59%）/🔶10/❌12（v0.3.0 为 ✅26/49%）
- 安装器修复：非交互运行时 Read-Host 空输入导致安装崩溃的 null 处理 bug
- 真机实测：7 agent 一键安装 31×7 全成功 + 幂等复验通过

## v0.3.0（2026-09-28）

PM 包 26 skills 版：新增 3 个新类别共 11 个 skill（思路拷问/规划立项/研发协作），覆盖"想法→立项→开发协作→上线"全链路。

- 新增**思路与决策**类 ×3（型取自 grilling/frontier 轮次拷问与 pre-mortem 方法论）：
  - idea-grilling：决策树+前沿轮次拷问，首轮固定五问，每题附推荐答案，问到没有沉默假设
  - decision-premortem：可逆性分级（双向门/单向门）+ 预演失败倒推死因 + 最小试错设计
  - assumption-audit：假设登记表（依据三档/翻车代价/不确定性），高危区必须先验证
- 新增**规划与立项**类 ×4：okr-planning（O 定性/KR 可归因/置信度 60-70%）、project-kickoff（八段启动文档+30 分钟开工会议程）、risk-register（概率×影响+触发器预警）、stakeholder-mapping（权力利益矩阵+反对者转化卡）
- 新增**研发协作**类 ×4（型取自 ponytail 梯子方法论）：
  - minimal-solution：产品版最简梯子（不做→配置→已有组合→人工流程→最小版本）+ 不可省清单 + 天花板标注
  - tech-spec-review：不懂代码也能审的六问（异常/边界/一致性/回滚/监控/容量）
  - dev-handoff：七件套交接包+新人测试/验收测试/反例测试
  - launch-readiness：六维 go/no-go 检查+48 小时值守清单（无回滚无监控直接 no-go）
- AGENTS.md：技能地图扩到 8 类；新增可逆性/最简梯子速记；工作流加入"想法拷问"与"交接开发"环节
- 全部 26 skills 已重装实测到本机 7 agent

## v0.2.0（2026-09-28）

PM 包内容大版本：6 → 15 个自产 skills（按产品工作流分 5 类），MCP 3 默认，安装器补齐 Codex TOML 写入。

- 新增 skills ×9（自产，参考 wshobson/agents 40k★ 等 MIT 包选题验证）：
  - 发现与洞察：user-research-interview（反引导访谈+三层纪要）、market-sizing（自下而上 TAM/SAM/SOM）
  - 定义与设计：feature-prioritization（RICE/WSJF/KANO 选型+重新上榜条件）
  - 数据与实验：experiment-design（样本量预判+止损预设）、data-insight（归因下钻+金字塔叙事）
  - AI 产品专项：ai-ux-patterns（6 种交互模式选型决策）
  - 战略与交付：roadmap-planning（Now/Next/Later 主题制）、meeting-to-decisions（决议/行动项/未决三分）、release-notes（内外双版+功能→收益改写）
- AGENTS.md 升级：技能地图（5 阶段 15 skills 索引）+ 知识基准层（框架选择/样本量直觉/交互模式速记）
- MCP 默认新增 asp-sequential-thinking（零 key）；全部 5 个模板同步；新增 mcp/optional-mcp.md（Brave/GitHub/Notion 等 key 类注册指引，安装器永不收集 key）
- 安装器：新增 toml-managed 策略（Codex config.toml 托管块幂等写入）
- 真机实测：Win10 一键安装 7 agent 全成功（CC/Codex/Cursor/DSH/Kimi/opencode/Zcode），16/16 验证 + 幂等复验

## v0.1.0（2026-09-28）

开发首版（内部）。首发角色包：AI 产品经理。

- 新增 skills：prd-drafting、prd-review、competitor-analysis、user-story、metric-design、ai-eval-design（6 个自产）
- 新增 prompt 库：42 条（需求澄清 10 / PRD 写作 8 / 评审决策 8 / 数据分析 8 / 面试练习 8）
- 新增角色 AGENTS.md（AI PM 工作流与判断基准）
- MCP 默认启用：asp-context7、asp-memory（零 key）
- 安装器：asp.ps1 / asp.sh（install/update/detect/agents/status）
- 适配器：claude-code、zcode（实测）；dsh（官方文档回填）；codex、cursor、opencode（开发版，W2 实测）；kimi（调研中，未启用）
