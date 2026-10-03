# MCP 候选池与工程缺口队列（v1.0，2026-10-03）

> 来源：2026-10-03 只读安全审计（外部 agent，未改任何仓库）。本文件把审计建议落为**项目内的候选目录与修复队列**。
> 铁律不变：**默认 0 MCP**；候选≠批准安装/发版；「试评」≠「入包」。机器可读版：[`registry/mcp-candidates.json`](../registry/mcp-candidates.json)（单一事实源，公开、不含凭据）。

## 一、覆盖结论

当前冷启动包经 QA 验证选择**默认 0 个 MCP**，已有 **13 个可选预设**（基础 3 / 办公 7 / 开发 3）。真实缺口不是数量，而是：① 可选目录缺部分常见场景（本轮补 16 项候选）；② 「列在目录」与「各端安全稳定装上并用起来」之间有工程缺口（见 §四修复队列）。

本轮 16 项候选覆盖：办公（MarkItDown、Google Workspace、PnP M365）、IM（飞书、Teams；Slack 已有）、画图（draw.io、Miro；Figma 已有）、编程（GitHub、Chrome DevTools、Sentry、Vercel、DBHub、Azure DevOps）、网页（Firecrawl/Apify）、支付（Stripe）、模型研究（Hugging Face）。

**首批试评 5 项**：GitHub 官方（/readonly 最小集）、draw.io 官方（仅本地版）、MarkItDown（目录限制）、Chrome DevTools（隔离浏览器+关统计）、Hugging Face 官方（token 权限分离）。其余 11 项为条件试评/按需，触发条件见 JSON。

完整字段（许可/维护状态/接入边界/数据去向/风险/相对现有价值）见 JSON；摘录 tiers：

| Tier | 项目 |
|---|---|
| 首批试评（5） | github-official · drawio-official-local · markitdown · chrome-devtools · huggingface-official |
| 条件试评 | lark-openapi（维护停 2025-08 先核）· google-workspace（隔离、不进默认）· apify（与 Firecrawl 二选一） |
| 按需 | miro · pnp-m365 · sentry · vercel · dbhub（只读起步）· azure-devops · firecrawl · stripe（逐次确认） |

**试评假设**：接入后在同一 agent、同一任务上比现有 skill/内置工具更能完成工作，且不增加越权或配置破坏——不是「服务器数量变多」。首轮每类取少量公开测试任务冒烟，**不据此宣称统计显著**。

**止损**：凭据外露 / 私人数据越界 / 已有配置丢失 / 不可控费用 —— 任一出现立即停止该候选。

## 二、更正记录

- ~~「draw.io / Axure：无官方 MCP（2026-10 核实）」~~ → **已更正**：官方 MCP 已存在（jgraph/drawio-mcp，Apache-2.0；Registry 镜像 mcp/io.draw/mcp）。`packs/base/mcp/optional-mcp.md` 已同步更正；mermaid-diagrams skill 仍为默认零依赖覆盖，两者不同时默认启用。Axure 维持「暂无替代」。
- GitHub MCP Registry（github.com/mcp）是**发现入口，不是安全或商用许可认证**。高热度旧 Office Word/PPT 仓库已归档；许可证不清或权限过宽的项目不因 Star 高进默认。

## 三、最小架构（采纳）

```text
AIHOT 候选 + 经同意的使用反馈
        ↓
公开的 MCP 候选目录（本文件 + registry/mcp-candidates.json）：
  来源、固定版本、许可、权限、数据去向、适用场景
        ↓
隔离试评：与现有 skill/内置工具同题对照；gold + 保留样本回归
        ↓ 人工批准（试评 ≠ 入包）
AI-cold-start 生成各端可选配置 → 分批发布 → 配置/授权/安全读操作三级体检
                                              ↑
Agent-sync 私有层：仅同步获准的凭据值，不另造商品目录
        ↓
可追溯回执 → 下一轮候选；私人原文不进入公开包
```

定位：**现有 agent 之上的轻控制层**，不是再造 agent 运行时。三条路径取舍：只扩手写模板最快但放大漂移；**单目录+受控试评（采纳）**多一点发布校验、最契合现有资产；自动挑选自改自发布与人审/数据边界冲突，现阶段不做。

## 四、工程缺口修复队列（按优先级）

### P0-1 Agent-sync 安全边界（前置：承接更多授权值之前必须完成）

- 现状：仓库仍 **public**，与预定私有状态不符；
- `setup-mcp.ps1` L15-30 展开环境变量凭据，L96-106 又打印配置命令——**凭据可能进终端历史/日志**；
- 处置：① 用户将仓库转私有；② 开发机修脚本（凭据不回显，改写入文件+掩码提示）；③ 历史凭据全量轮换（public 期间的值视为已泄露）；
- 完成前，Agent-sync 不承接新增授权值。

### P1-1 预设不可靠叠加（候选数量变真实覆盖的前置）

- Codex TOML 托管块再安装预设时**整体替换**（`asp.ps1` L171-201）：先装 essentials 再装 work-tools，前者托管块消失；
- macOS/Linux 入口无 `mcp install`（`asp.sh` L720-737）；
- 修法：托管块改 merge-by-id（保留他块条目）；asp.sh 补齐 install 子命令；修后跑双预设叠加回归（装 essentials→装 work-tools→断言两者共存）。

### P1-2 doctor「全绿」口径偏宽

- 现状（`asp.ps1` L378-424）：仅验 MCP `initialize`；401/403 记 WARN，无 FAIL 即输出全绿——不能证明完成 OAuth、具备权限、能执行安全真实任务；
- 修法（对齐 ONBOARDING-V2 W2 设计）：三级体检 = ①配置存在 ②握手成功 ③**授权读操作实测**（每 MCP 定义一个最小安全读动作）；401/403 明确标「需授权」非「可用」。

### P2-1 目录双源归属

- 现状：冷启动包维护各端预设，Agent-sync `mcp/mcp-servers.json` 自称 canonical，内容已分叉；且 Agent-sync 将私有化而冷启动包需公开；
- 裁定（本文件起生效）：**公开候选目录的单一事实源 = AI-cold-start `registry/mcp-candidates.json` + 本文件**；Agent-sync 注册表降级为「私有凭据值映射」，移除 canonical 声明，指向本文件。

### 试评排期前置条件

首批 5 项试评启动条件：P0-1 完成 + P1-1 修复（否则试评结果不可信：叠加会丢配置）。P1-2 可与试评并行修（试评正是三级体检的验证场）。

## 五、决策记录

1. **默认 0 MCP 承诺不变**；候选池只扩「可选目录」。
2. 「购买后默认启用 10+ MCP」会改变零 key/零依赖承诺——**如需该形态须单独决策**（当前不采纳）。
3. 首批 5 项试评已获原则同意（2026-10-03 采纳审计建议），排期待 P0-1/P1-1 完成。
