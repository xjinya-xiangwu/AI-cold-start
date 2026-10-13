# V2.0 方向扩展评估 —— 基于维护者自有环境（agent-sync 262 技能盘点）

> 2026-10-14 ｜ 输入：agent-sync 同步环境全量盘点（262 个去重技能，名称+简介+归属目录）
> 结论先行：**三个新方向包（游戏开发 / 营销内容创作 / vibe coding）全部可行**，每个方向可从自有环境中精选 12 个零依赖技能，沿用「基础包复用 + 方向加购 ¥10」模式；预计 V2.0 家族总技能 25 + 36 = **61**。主要风险不在数量在**许可审查**（第三方来源逐个核证是入选硬门槛）与**工程量**（36 个技能的改造+指令+验收）。

---

## 一、盘点结果

- 来源：agent-sync 同步环境（junction 与全局目录已完全一致），去重 **262 个技能**，全部读取 SKILL.md 简介。
- 与现有商品重叠：base 25（已在售）+ ai-pm 12（已在售）需从候选中剔除，避免重复售卖。
- 初筛聚类：游戏开发 84 / 营销内容创作 32 / vibe coding 97（关键词粗筛，含跨组重叠）。

## 二、筛选原则（沿用 v0.13.x 商品哲学）

1. **方法优先于手册**：收录跨引擎/跨平台的方法论技能，不收录绑定单一引擎版本的 API 手册（godot-4.7 系 14 个、unity-6.3 系 9 个、ue-5.8 系 12 个、roblox 系 8 个整体不进包——版本迭代快、维护成本高；有需要的重度玩家未来可做「引擎专题包」再议）。
2. **零依赖红线**：依赖外部 API/key/个人凭据的技能不进包（imagegen / audio_generation / video_generation / kurt-aigc / email-imap / tianyancha / imf / browser-testing-with-devtools 等，随包无法保证可用性，与「零 key 才能用」承诺冲突）。
3. **体积分红线**：ppt-master（80MB+ 万级文件）不进包；纯前端单文件输出的 guizang-ppt-skill 可作候选备选。
4. **许可硬门槛**：每个入选技能逐个核 SKILL.md 来源与许可；自有原创（中文 PM/方法系列）直接入选；第三方开源改造须 MIT/Apache 或已获改造授权；**CC-BY-NC（如 deanpeters 系）一律排除**。本评估对来源状态标注为「自有 / 改造核证 / 待核」。

## 三、三个方向的推荐清单（每方向 12 个）

### 3.1 游戏开发方向 `game-dev`（+¥10）

定位：让 AI 助手按游戏开发的阶段方法干活（立项→玩法→关卡→打磨→上架），跨引擎通用。

| # | 技能 | 一句话 | 来源状态 |
|---|---|---|---|
| 1 | game-jam | 按截止日锁范围做游戏：排时、砍功能、按时交付 | 改造核证 |
| 2 | game-feel | 给操作加"手感"：屏震、顿帧、缓动 | 改造核证 |
| 3 | level-design | 关卡方法论：白盒→可玩、玩家度量 | 改造核证 |
| 4 | game-ai | NPC 决策：FSM/行为树/转向 | 改造核证 |
| 5 | save-systems | 存档设计：序列化/槽位/防损坏 | 改造核证 |
| 6 | game-ui-ux | 游戏 HUD/菜单的响应式布局 | 改造核证 |
| 7 | dialogue-systems | 分支对话与叙事：节点图/条件/本地化 | 改造核证 |
| 8 | physics-tuning | 物理调参：步长/插值/手感稳定 | 改造核证 |
| 9 | input-systems | 输入映射与改键冲突处理 | 改造核证 |
| 10 | performance-optimization | 游戏性能方法论：先 Profiler 后猜测 | 改造核证 |
| 11 | procedural-gen | 程序化生成：种子随机/噪声/地牢 | 改造核证 |
| 12 | itch-publish | itch.io 上架与更新（butler CLI） | 改造核证 |

备选：audio-design、create-game-assets、router（引擎路由器——若未来出引擎专题包则为必收）。淘汰：引擎 API 手册 43 个（原则 1）。

### 3.2 营销内容创作方向 `marketing-content`（+¥10）

定位：从 offer 到素材到投放到复盘的全漏斗内容方法（中文电商 + 海外投放双语场景）。

| # | 技能 | 一句话 | 来源状态 |
|---|---|---|---|
| 1 | offer-extraction | 把产品提炼成高转化 offer | 待核 |
| 2 | headline-matrix | 多角度标题/hooks 矩阵 | 待核 |
| 3 | ad-angle-multiplier | 一个卖点扩 N 个广告角度 | 待核 |
| 4 | scroll-stopping-creative | 前 3 秒留人的创意概念 | 待核 |
| 5 | schwartz-awareness-mapper | 受众认知五阶与话术匹配 | 待核 |
| 6 | objection-crusher | 异议识别与化解 | 待核 |
| 7 | conversion-path-builder | 点击→转化的漏斗路径设计 | 待核 |
| 8 | full-funnel-campaign-orchestrator | 全漏斗投放编排（联动本包其余技能） | 待核 |
| 9 | performance-diagnosis | 投放表现诊断（CPL/低效归因） | 待核 |
| 10 | growth-loops | 五类增长飞轮识别 | 待核 |
| 11 | reddit-voc | 电商 VOC 挖掘（Reddit 评论→卖点） | 待核 |
| 12 | ecommerce-visual-copywriting | 电商视觉文案：主图/详情页/Listing（中文原创） | **自有** |

备选：guizang-ppt-skill（网页 PPT，内容创作呈现）、media-press-discovery、backlink-kol-extractor（B2B 海外向，可作未来子方向）。淘汰：依赖 API/本地凭据的 imagegen/audio/video/email 类（原则 2）。

### 3.3 vibe coding 方向 `vibe-coding`（+¥10）

定位：给「用 AI 写代码的人」一套防翻车纪律——从想法到上线全程的方法（与基础包 25 个不重叠，全部为新技能）。

| # | 技能 | 一句话 | 来源状态 |
|---|---|---|---|
| 1 | karpathy-guidelines | 防 LLM 编码通病的六条行为准则 | 自有整理（引用 Karpathy 公开推文，注明出处） |
| 2 | test-driven-development | 红绿重构 TDD 循环 | 改造核证（superpowers 系已有 MIT 中文化先例） |
| 3 | test-scenarios | 从用户故事生成测试场景（AAA 模式） | 改造核证 |
| 4 | code-review-and-quality | 五轴代码评审 + 质量门 | 改造核证 |
| 5 | debugging-and-error-recovery | 系统化根因调试与恢复 | 改造核证 |
| 6 | incremental-implementation | 薄切片增量交付 | 改造核证 |
| 7 | constraint-driven-development | 把质量底线写成"合同"防 agent 悄悄降标 | 改造核证 |
| 8 | source-driven-development | 一切实现决定以官方文档为据 | 改造核证 |
| 9 | spec-driven-development | 先写规格再动手 | 改造核证 |
| 10 | code-simplification | 不改行为的简化重构 | 改造核证 |
| 11 | security-and-hardening | 输入处理/注入面安全加固 | 改造核证 |
| 12 | git-workflow-and-versioning | commit/分支/版本纪律 | 改造核证 |

备选：skill-creator（元技能：教用户自建 skill，vibe coding 受众契合度高，V2.1 可加）、frontend-ui-engineering、ci-cd-and-automation、api-and-interface-design、to-spec/to-tickets/implement 三件套（依赖 issue tracker 工作流，使用门槛略高）。

## 四、V2.0 包结构与定价建议（沿用已验证模式）

| 商品 | 价格 | 内容 |
|---|---|---|
| 基础包 base | ¥20（不变） | 25 skills + 11 指令（不动） |
| **方向：AI 产品经理** ai-pm | +¥10 | 12 skills + 31 指令（在售） |
| **方向：游戏开发** game-dev | +¥10 | 12 skills + ~10 指令（新） |
| **方向：营销内容创作** marketing-content | +¥10 | 12 skills + ~10 指令（新） |
| **方向：vibe coding** vibe-coding | +¥10 | 12 skills + ~10 指令（新） |
| 家族合计 | —— | 基础 25 + 方向 48 = **73 skills / 42+30 指令**（买齐 ¥50） |

- 模式沿用已验证的「单底座 + 方向加购」，安装器已支持多方向包并列（deps/base 复用）。
- 每方向配 AGENTS.md 方向工作流（如 PM 包的九环工作流模式）。

## 五、工程量与排期建议

| 阶段 | 内容 | 估时 |
|---|---|---|
| 许可核证 | 36 个候选逐个核 SKILL.md 来源声明，CC-BY-NC 剔除/替换 | 0.5-1 天 |
| 中文化改造 | 英文源技能改造为中文方法论（保持结构：触发场景/步骤/输出规范） | 2-3 天/方向 |
| 指令编写 | 每方向 10 条即用指令 | 0.5 天/方向 |
| AGENTS.md | 每方向角色工作流 | 0.5 天/方向 |
| QA | 方向包双引擎冒烟（claude-code + zcode）+ 既有 35 断言回归 | 0.5 天/方向 |
| 上架 | manifest/registry/网盘/文案（沿用 v0.13.2 管线，半自动化） | 0.5 天/方向 |

建议节奏：**一个方向一个发布**（v2.1 游戏开发 → v2.2 vibe coding → v2.3 营销），避免三方向同期改造压垮质量；发布顺序理由：vibe coding 与现有买家画像（开发者）最近，游戏开发受众大但改造量最大。

## 六、风险与未决

1. **许可核证是最大不确定项**：营销方向 10 个「待核」技能若半数不可用，需从备选补位（备选池 4 个 + 可再从粗筛池捞）。
2. **"每月更新一次"的内容承诺**：新增三方向后周更/月更的维护对象从 2 包变 5 包——与 §6.2 经济账红线联动，V2.0 上架前应把维护工时并进经济账重算。
3. **引擎覆盖深度问题**：重度游戏买家可能期望 Godot/Unity 具体 API 支持——方案是包内 method-first + 说明页明示"引擎 API 专题包为未来可选"，不上未验证承诺。
4. **本评估未逐个实测技能输出质量**（输入为环境盘点+简介），入选后改造阶段逐个真机冒烟（同 prd-drafting 三连实测先例）。
