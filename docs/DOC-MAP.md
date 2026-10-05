# DOC-MAP — 子模块文档 ↔ 仓库关联总图（2026-10-05）

> Notion 五个子模块各有 MRD（市场与需求定义）+ PRD（模块工程需求分解）v0.1，2026-10-05 建。
> 上位契约：评审版 v3.1 + 开发级 PRD v0.2 + 专家规格 v0.1（三份核心文档，总入口 https://app.notion.com/p/3ed62c74ab728163bb57ee3d8a1e7c8e）。
> 口径：**冲突时以核心文档为准**；子模块 PRD 只做模块分解。仓库内容必须能对照文档验收（I6 反假同步）。

## 五模块 ↔ 仓库 ↔ 文档

| 子模块 | MRD | PRD | 实现宿主 repo | 本仓库承载 |
|---|---|---|---|---|
| 分发层 · 智能体冷启动包 | [MRD v0.1](https://app.notion.com/p/a4633948e4034216ad4908d84e97e5b4) | [PRD v0.1](https://app.notion.com/p/e1a8d83cd12a49c1ae201ecd0b4f0e44) | **本仓库**（ai-cold-start） | 方法包/asp/adapters/registry；DST-* 需求；私有环命令与渲染的宿主；专家包只读包层交付通道 |
| 同步底座 · Agent-sync | [MRD v0.1](https://app.notion.com/p/755d87957b3649f0acc357b4e822998d) | [PRD v0.1](https://app.notion.com/p/379dc170d4c941328ae90edab4fd46d6) | [Agent-sync](https://github.com/xjinya-xiangwu/Agent-sync)（私有） | SYN-* 需求：age 六命令（M-S2）、占位符填充、FORMATS.md；本仓库的 export 占位符+lint 与其衔接（D14 字段级互斥） |
| 公共环 · 情报漏斗（aihot） | [MRD v0.1](https://app.notion.com/p/550db645a1964db3b4d09702e7a9c2b1) | [PRD v0.1](https://app.notion.com/p/1aa1ef84c1e447a2ae515ba724d396b4) | [AIHOT planning/](https://github.com/xjinya-xiangwu/AIHOT/tree/main/planning)（模板与规则 canonical）+ [SIAE-materials](https://github.com/xjinya-xiangwu/SIAE-materials)（私有，素材库运行仓） | INT-* 需求：L0 三通道采集/L1 评分校准/周报三态；不读用户 vault，不承担产品效果门 |
| 私有环 · 用户 vault 与经验引擎 | [MRD v0.1](https://app.notion.com/p/c4214256c2fc4a389084e377485c9788) | [PRD v0.1](https://app.notion.com/p/106b5d0ebf7543438a12992f41927b06) | 本仓库（VLT-* 宿主：提交器/render/status 由 asp 实现，引擎技能随包发布） | [docs/VAULT.md](VAULT.md) 契约镜像；`vault/` B1 资产（schema+T13 夹具+校验器）；P1 门=P0 过+≥5 访谈 |
| 专家环 · 专家环境采集与融合 | [MRD v0.1](https://app.notion.com/p/47f5517956764dbeb88b2fc96810a7d8) | [PRD v0.1](https://app.notion.com/p/862f7f6b2aeb4747894156f9af5ae786) | 本仓库 docs/expert/（协议/模板/清单——受控数据区**不进公开仓**） | EXP-* 暂缓期可做项：[来源账本](expert/rights-ledger-v01.md)、[G2 复核清单](expert/G2-review-checklist-v01.md)、[D25 条款要点](expert/D25-license-template-points-v01.md)；D24 暂缓不招募不签约 |

## 本仓库分支状态（实施证据）

| 分支 | 内容 | 验证 |
|---|---|---|
| main | v0.13.0 + 文档（VAULT.md、架构图、TEST-CASES-P0、DOC-MAP） | QA 门禁历史 + 审计止损记录 |
| `p0/staging-r00-r01-r03` | R00/R03 模块+补丁器（22/22 夹具）、R01 export 占位符+lint 全链（8/8+补丁器夹具过）、vault B1 资产（T13 14/14）、专家环协议三件 | 本机夹具全过；**真机 TEST-CASES-P0 未跑，不合 main** |

## 更新纪律（I6）

文档变更 → 先改 Notion 核心文档 → 仓库对照迭代（commit+测试产物）→ SIAE STATUS/broadcast 登记；只标真实完成的（"staging/未验证"必须写明）。反向（仓库先改）须回写 Notion 登记待确认。
