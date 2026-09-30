# MARKETPLACE-LISTING — 主流 agent 市场上架准备（W1 出站）

> 目标：把 asp 的自产技能上架到主流 agent 内置/公认市场，建立与 W1 入站清单卡对偶的**出站渠道**。
> 状态：准备就绪（阶段1，2026-09-30）——素材 kit 可一键生成；两条硬渠道可立即行动，一条待官方入口。
> 关联：`registry/marketplace-map.json`（渠道单一事实源）、`scripts/gen-marketplace-kit.py`（素材生成器）、`docs/ONBOARDING-V2.md`（W1 完整设计）、`docs/DELIVERY-V2.md`（付费渠道）。

## 0. 一句话策略

**lite 免费上架引流，完整包不进市场**——市场装的只是精选 skills（方法层引流装），完整版（31 skills + 42 指令 + AGENTS.md + MCP + 周更）走安装码渠道；市场简介以「完整版+周更」作钩子导流。与既有「GitHub lite 免费引流 → 闲鱼/淘宝成交」漏斗同构，市场只是新增的流量入口，不动付费链路。

## 1. 渠道矩阵（2026-09-30 调研结论）

| 渠道 | 类型 | 状态 | 上架机制 | 动作 |
|---|---|---|---|---|
| **Claude Code 官方插件市场** | 官方 | 🟢 kit-ready | 仓库根 `.claude-plugin/marketplace.json`；用户 `/plugin marketplace add xjinya-xiangwu/AI-cold-start` | 跑 `gen-marketplace-kit.py` → `claude plugin validate` → 真机冒烟 → 提交 |
| **skills.sh / npx skills** | 公共注册表 | 🟢 **已 live** | **零提交**：公开 repo 含 SKILL.md 即收录，`npx skills add xjinya-xiangwu/AI-cold-start` 可装，榜单按装机量 | 无技术动作；纳入每周内容推广（帖子里附安装命令） |
| **Qoder 技能市场**（阿里） | 官方 | 🟡 format-ready | SKILL.md 原生兼容（Upload Skill 支持 ZIP/SKILL.md 直导）；第三方已开放（官方迁移技能+他山科研 18 skills 先例） | 逐 skill ZIP 已可生成；**待确认自助提交入口**（文档未公开——联系官方或走 cloud-agents Skills API） |
| 社区目录（agenticskills.io / openagentskill 等） | 社区 | ⚪ backlog | 被动收录为主 | lite 上架后抽查是否被索引 |
| Trae | — | ❌ 不适用 | 无独立技能市场（扩展走 VSCode VSIX 生态） | 保持 asp 文件部署 |
| WorkBuddy | — | 🟡 调研中 | 重运营但市场机制无公开文档 | 待其开发者文档开放；适配器迁移 v0.1 已就位 |

关键判断：**SKILL.md 已成为跨市场通用格式**（Claude 插件市场、Qoder、skills.sh 三渠道同吃一个格式）——与 AGENTS.md 标准化同一趋势。一次制作、三渠道分发，这就是出站可行性的根基。

## 2. 三步上架 checklist

### Claude Code 官方市场（第一优先）

1. `python3 scripts/gen-marketplace-kit.py`（默认 lite 档，读 `registry/marketplace-map.json` free_tier）
2. 检查 `dist/marketplace/claude-plugin/`；将 kit 内容放至仓库根（`.claude-plugin/` + `plugins/`）——或先独立目录验证
3. `claude plugin validate ./dist/marketplace/claude-plugin` → 真机 `claude plugin marketplace add ./dist/marketplace/claude-plugin` → `claude plugin install asp-base@asp-kits` 冒烟
4. 推送仓库 → 用 `claude plugin marketplace add xjinya-xiangwu/AI-cold-start` 走公网路径复测
5. 版本更新：skills 变更后重跑生成器即可（marketplace add 缓存机制见官方 host-marketplace 文档）

### skills.sh（零动作已生效）

1. 无技术动作——repo 已满足收录条件
2. 推广动作：每周内容帖附 `npx skills add xjinya-xiangwu/AI-cold-start`；装机量上榜单后截图作商品页信任素材
3. 质量动作：SKILL.md 的 description 决定搜索转化——lite 技能描述已按触发场景写法优化，保持该风格

### Qoder（格式就绪，待通道）

1. `dist/marketplace/qoder/*.zip` 逐 skill 可直接 Extensions→Skills→Upload 导入（人工通道已通）
2. 自助上架入口待确认：优先联系 Qoder 官方（有 claude-to-qoder-migration 先例说明接受第三方）；备选走 cloud-agents Skills API（docs 有完整 CRUD）
3. 上架后把真实市场 id/深链回填 `registry/marketplace-map.json` → `inbound.marketplace_items.qoder` 清单卡自动指向自家条目

## 3. 合规与品牌

- **版权**：free_tier 全部为自产 skills（版权自有，可上架可注册）；若未来加入 MIT/Apache 改造件，须同步 THIRD-PARTY-NOTICES 且确认原许可允许再分发
- **品牌**：上架显示名/作者署名是 D9（商品页身份口径）的子问题——生成产物中已用 `TODO-D9` 占位，**D9 定稿后改 marketplace-map 与生成器常量重新生成即可**，不阻塞技术准备
- **红线**：AIHOT 名称/Logo 不使用（与主规划一致）；NC 许可内容永不收录
- **付费隔离**：市场条目只含 skill 本体；AGENTS.md 工作流/prompts 库/MCP 配置/周更不进市场——既是付费保护，也是市场装不了的价值主张

## 4. 出站反哺入站（W1 双向闭环）

上架成功后：`marketplace-map.json` 的 `inbound.marketplace_items` 指向自家市场条目 → asp 对 Qoder/WorkBuddy 等市场型 agent 的清单卡直接推荐自家条目（用户在原生 UI 安装，体验最优）→ doctor 核验已装 → 周更时清单卡提示新上架条目。**出站是入站的弹药。**

## 5. 验证指标

- Claude 市场：validate 通过 + 公网 add/install 冒烟通过（上架门槛）
- skills.sh：被收录可装（已达成）；进入分类榜单前列（推广目标）
- Qoder：人工导入通过（已达成条件）；官方渠道上架（待通道）
- 转化：市场安装 → 完整版购买 的漏斗数据（lite 首页简介钩子点击，上架后补埋点）
