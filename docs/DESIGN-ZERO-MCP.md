# 方案 B：零 MCP 默认（能力进 Skills）— 调研与设计

> 2026-10-01 · kurtx/ZCode 调研 · 状态：**已实施（v0.8.0）**；本文为决策记录与验证基准
> 决策链：v0.7.0 三件套→1（context7 remote）→ v0.8.0 默认→0，MCP 全部转可选增强

## 0. 结论

把「文档新鲜度」能力从 MCP 配置层移到 skill 层（指挥 agent 用内置 web 工具查官方文档），默认 MCP 从 1 → 0。核心依据：

1. **skills 分发面是 10 个 agent 里唯一被全程验证可靠的部署面**——MCP 配置面已被 WorkBuddy 证伪过一次（v0.6.1 的 mcp.json merge 结论在 v0.7.0 被推翻）
2. 主流 agent 全部自带 web search/fetch（例外见 §1，均有对策）
3. 本机实证：默认装的 MCP 从未被调用——默认供给本就过剩；零 MCP = 零运行时依赖、零第三方端点依赖、零限流面

## 1. 可行性摸底：10 agent 内置 web 工具

| Agent | 内置 web 工具 | 状态 | 对策/备注 |
|---|---|---|---|
| ZCode | WebSearch / WebFetch | ✅ 本机实证 | — |
| Claude Code | WebSearch / WebFetch | ✅ 官方文档 | — |
| Codex | web search（默认 OpenAI 缓存索引，live 可选） | ✅ 官方目录 | skill 指示需最新信息时用 live 模式（字段待验证） |
| Cursor | @Web 搜索 | ✅ 高置信 | — |
| opencode | webfetch 始终可用（免 key）；websearch 需 `OPENCODE_ENABLE_EXA=1` 或官方 provider | ✅ 官方文档 | skill 降级链覆盖：无搜索时直取已知官方域 |
| WorkBuddy | agentic_search（内置） | ✅ 本机实证 | — |
| Kimi Claw | 未验证 | ⏳ 待验证 | Kimi 系普遍有搜索，大概率可用 |
| DSH | 未验证（插件化架构，沙箱管工具） | ⏳ 待验证 | 降级链覆盖：无 web 工具时声明知识可能过期 |
| Trae / Qoder | 未验证 | ⏳ 待验证 | AI IDE 形态大概率有；装机实测清单补 |

**7/10 确认可用，3/10 待验证但降级链全覆盖**——最坏情况是诚实声明过期，不劣于现状。

## 2. 能力等价与差距（context7 → skill + 内置 web）

| 维度 | context7 MCP | skill + 内置 web | 对策 |
|---|---|---|---|
| 新鲜度 | 好（版本化文档库） | 好（live web） | 打平 |
| 降噪 | 强（切片返回） | 弱（整页/搜索噪音） | 检索三步法：搜索→官方域优先→定向抓取 |
| 版本锚定 | 强（显式版本） | 弱 | 输出纪律：引用必带版本号或日期，否则标"版本未验证" |
| 依赖面 | 第三方端点+限流 | 零（复用 agent 已有工具） | 方案 B 优 |
| token 成本 | 低（切片） | 高（整页进上下文） | PM 包场景频率低可接受；开发者包重用户→推荐装回 context7（可选第一位） |
| 离线 | 不可用 | 不可用（agent 本身要联网） | 打平，非差异项 |

**反方证据（诚实记录）**：2025-11 arXiv 评测显示 RAG/MCP 类结构化检索在文档任务上优于裸 HTML 浏览——skill 方案的检索质量下限更低，这是三步法纪律存在的原因；最终以金题集（§4）量化验收，不达标不切默认。

## 3. 实施（v0.8.0 已落地）

- `packs/base/skills/fresh-docs/`：检索三步法 + 输出硬规则 + 四级降级链 + 反模式
- 默认 MCP 模板清零（4 JSON `{"servers":{}}` + codex toml 注释化）；merge 机制保留给可选件
- `optional-mcp.md`：context7 升可选第一位（免费 key 引导 + 四种 agent 写法 + doctor 验证）
- AGENTS.md 知识层（base+ai-pm）：「文档查新纪律」全 agent 生效
- adapter：claude-code/zcode/opencode 移除 `requires:npx` 门槛
- installer：零 MCP 时打印「默认 0 个 MCP（能力由 skills 承载）」
- doctor 保留：转为可选件验货器

## 4. 验证方案（金题集 before/after）

- **金题 10 道**：训练截止后高概率变化的文档题（版本迁移/新 API/平台规则），混 2 道稳定概念题对照
- **环境**：ZCode + WorkBuddy（web 工具双实证）各两轮：A=context7 MCP、B=fresh-docs skill
- **评分**（每题 0-2 分×三维）：事实准确性 / 版本或日期标注 / 来源为官方域
- **接受标准**：B 准确性 ≥ A 的 90%，且 B 版本标注率 ≥ 90%；不达标 → 回滚默认（skill 保留为降级链与无 MCP 用户价值）
- 无遥测（隐私是产品卖点），故以人工金题集与安装反馈为证据源

## 5. 风险与缓解

| 风险 | 等级 | 缓解 |
|---|---|---|
| 检索质量下限低于 context7 | 中 | 三步法纪律 + 金题集门槛 |
| opencode websearch 默认关 | 低 | webfetch 可用即覆盖；env 开关引导 |
| DSH 无 web 工具 | 低 | 降级链声明过期；本就 MCP-disabled 设计 |
| token 成本上升 | 低（PM）/中（dev） | 开发者包推荐装回 context7 |
| 商品话术变化 | 低 | 卖点更强：零配置零故障面 |

## 附：调研来源

- opencode 内置工具与启用条件：opencode.ai/docs/tools（官方）
- Codex 内置 web search（默认缓存索引）：官方工具目录
- context7 无 key 低限额 + 免费 key：github.com/upstash/context7；context7.com/dashboard
- 检索质量对比（RAG/MCP vs 裸浏览）：arXiv 2025-11 评测
- WorkBuddy agentic_search / ZCode WebSearch·WebFetch：本机实证（2026-10-01）
