# VAULT.md — 用户 vault 与经验卡契约（仓库侧镜像）

> **状态：规格镜像，实现未开始（P1）。** 本文是 Notion《SIAE 自进化智能体环境包 · 开发级 PRD v0.2（基于评审版 v3.1）》§5.4–§5.7 的仓库侧契约快照，供开发机/贡献者离线实现时对照。**唯一规格源是 PRD 本身**；两者冲突时以 PRD 为准，并回写本文件。
> 依据决策：D17（L2 用户 vault 归用户所有）、D19（P0 不新增 vault 命令）、D20–D22（权益/会话/提示）。本文不含专家生产侧内容（见专家规格 v0.1）。

## 1. vault 是什么

用户私有经验的**唯一归宿**：本机目录 `~/.asp/vault/`（Windows 展开为用户主目录）。各 Agent 目录里的内容只是**可重建的渲染副本**；删掉副本不丢数据，删掉 vault 才丢。维护者不获取 vault 内容，asp 不上传、不联网。

- P1 快照不要求 git：已装 git 可作本地快照，未装由 asp 按次快照。
- 用户可直接编辑自己的文件；下次加载前校验，校验失败不进入 render，保留原文件并在 status 提示修复方式。

## 2. 目录结构（schema 1.0）

| 路径 | 内容 | 加载/导出 |
|---|---|---|
| `profile.md` | 角色/行业/产出/读者/禁忌（frontmatter） | 渲染摘要，常驻 |
| `projects/` | 项目卡：project_id、workspace_bindings（路径哈希+显示名）、goal、stage、stakeholders、deadline、glossary_refs、status | 当前工作区匹配的项目卡 |
| `rules/` | 生效经验卡（active） | 按确定性路由加载 |
| `glossary.md` | 术语表 | 按需 |
| `cases/` | 案例库 | 按需 |
| `skills/my-*/` | 个人技能草案/私有技能 | overlay 叠加 |
| `overlays/` | 个人对包内容的覆盖（周更重放，不覆盖用户层） | 叠加 |
| `inbox/` | 待确认候选暂存（含 `staging/`） | **不加载** |
| `imports/` | 用户导入资料原件 | 只供选择提炼，**不随导出** |
| `private/` | 私密内容 | **不加载、不导出** |
| `settings.yaml` | 引擎设置（见 §6） | 检查点读取 |
| `log/` | 事件日志（JSONL，仅本机，可选） | 统计源，不上传 |

## 3. 经验卡 schema 1.0

单卡一个 YAML 文件，UTF-8、LF 换行；时间一律 ISO-8601 带时区；机器枚举用英文，界面按映射显示中文。

```yaml
schema_version: "1.0"
id: rule_20261004_7f3a          # 全局唯一，创建后不变
revision: 3                     # 每次提交 +1，用于乐观锁
type: preference                # correction | preference | prohibition | fact | case
status: active                  # candidate | pending | active | merged | retired | rejected
scope:
  scope_type: task_type         # global | task_type | project | skill
  task_type: weekly_report      # scope_type=task_type 时必填
  project_id: null              # scope_type=project 时必填
  skill_id: null                # scope_type=skill 时必填
trigger: 写周报、汇报材料时      # 自然语言，只供语义候选，不参与确定性路由
action: 结论放第一段，每段不超过 3 行
counter: 先铺背景再给结论
evidence:
  - ref: log/2026-10/evt_0193   # 引用事件，不复制整段会话
    excerpt: 先说结论，背景放后面  # 最小脱敏摘录
    source: command             # command | in_session | post_session | edit_diff | import | memory_import
    agent_id: cursor
    task_id: t_20261004_02
confirmation:
  mode: explicit_command        # explicit_command | review_confirm | review_default | user_edit | legacy
  confirmed_at: 2026-10-04T10:21:00+08:00
conflict_with: []               # 非空时只能停在 pending
supersedes: []                  # 被本卡替换的卡 id
merged_into: null               # status=merged 时必填
created_at: 2026-10-04T10:20:12+08:00
updated_at: 2026-10-06T09:02:41+08:00
hits: 4                         # 只计 observed / user_confirmed 证据的命中
last_hit_at: 2026-10-06T09:02:41+08:00
```

### 状态机（PRD §5.2 N4，v0.2 统一口径）

- `candidate`（Agent 产出，未经提交器）→ `pending`（提交器通过，待确认）→ `active` → `merged` / `retired`；用户拒绝或 14 天未确认 → `rejected`。
- 冲突不是独立状态：`pending` + `conflict_with`，直到用户选择「保留旧 / 替换 / 按条件并存」。
- 敏感命中：提交器**拒收，不生成卡**，只记脱敏审计事件 `blocked_sensitive`（类型、来源通道、时间，不含原文）。
- 明确口令经提交器检查后直接 `active`；普通纠正为 `pending`，scope 默认最窄（一次普通纠正仅进 inbox，不变全局规则）。
- 默认采纳安全例外：「同类信号 ≥2 次」只计独立信号（不同 task_id 或不同会话、用户原话）；敏感/冲突/scope 扩大/高影响规则必须明确确认，用户沉默 ≠ 授权。

### 夹具判定（T13 验收基线）

有效卡→接收；缺必填字段→rejected 并报字段；坏枚举→rejected；同义同范围→merged；冲突→pending+conflict_with；14 天未确认→rejected；敏感→不生成卡只记 blocked_sensitive；v0.1 旧卡→按迁移表升级。**Win/mac 用同一组夹具必须得到相同唯一结果。**

## 4. 渲染路由与预算（确定性优先，I3）

- 渲染器只用确定性键：workspace_bindings 匹配 → project_id；技能触发 → skill_id；task_type 由 Agent 在任务开始声明，未声明只加载 global 与项目卡。Agent 可依 trigger 提语义候选，但只能请求按需加载，**不能静默写 global**。
- 换机后路径不匹配的项目卡标「待重新绑定」，复盘时询问。
- 常驻排序：安全与协议 → profile 摘要 → active 规则（用户层 ＞ 团队层 ＞ 专家层 ＞ 维护者层）→ hits 降序 → last_hit_at 降序 → id 升序（同分稳定）。
- 预算（设计建议，渲染前字数检查，非 token 限额）：协议 ≤400 字、profile 摘要 ≤300 字、常驻规则 ≤800 字，合计约 1,500 可见字；专家包常驻路由占用 ≤300 字。

## 5. 可信提交器（R15/B2，唯一入库通道）

所有进入 vault 的写入都经过 asp 提交器；Agent 只把候选写到 `inbox/staging/`（或工作区 `.asp/inbox/staging/`）。提交时机：`asp vault commit` / `status` / `render` / `asp update` / 每周复盘结束。

流程：路径白名单（拒绝符号链接/路径穿越/未知文件，未知文件保留并报告）→ schema 校验 → 敏感 lint（命中拒收+删暂存原文+记 blocked_sensitive）→ 去重与状态转移合法性 → 单写者锁 `.asp/lock`（超时 30s 设计建议）→ revision 乐观锁（过期不覆盖，重回 pending）→ 临时文件→刷盘→原子重命名 → 生成校验后快照 → 释放锁记事件。

幂等与恢复：同一（agent_id、task_id、内容哈希）重复提交只计一次；失败候选留暂存区标原因可重试；写入中断/磁盘满清理临时文件原文件不变；多目标渲染部分失败逐目标报告，失败目标回滚到上一托管块。**未经提交器的卡不进入 active、render 或快照。**

## 6. settings.yaml 1.0

```yaml
settings_version: "1.0"
engine:
  first_enabled_at: 2026-10-04T10:00:00+08:00   # 首次 vault init 成功写入；升级/重装不重置
  primary_agent: cursor                          # lite 渲染目标
  render_targets: [cursor, claude_code]          # 付费：用户勾选的已验证 Agent
transcripts:                                     # D21：默认不读会话
  asked_at: 2026-10-04T10:12:00+08:00            # 访谈后询问一次，有值不再弹窗
  grants:
    - agent_id: cursor
      scope: own_transcripts                     # 只读当前 Agent 自己的记录
      granted_at: 2026-10-04T10:12:30+08:00
      consent_text_version: "1.0"
      revoked_at: null
  cross_agent_grants: []                         # 每对「来源→处理」单独同意
preference_hint:                                 # D22：前两周默认提示，之后关闭
  mode: auto                                     # auto | always_on | always_off；用户选择优先
  auto_window_days: 14
reminders:
  weekly_review: on
```

判定：auto 模式在 `first_enabled_at + 14×24h` 内显示提示，到点关闭；用户选 always_on/off 长期优先，升级不重置。拒绝只记 asked_at、之后不再弹窗；撤销写 revoked_at 立即停止读取，已确认卡不自动删（提示可用「忘掉」）。任何权益状态下都不删除、不锁定、不降级用户已有个人资产（D20 权益矩阵见 PRD §5.6）。

## 7. 命令组

- **P1**：`asp vault init`（幂等只增不覆盖）/ `commit`（§5）/ `render`（预览目标/托管块、备份、渲染）/ `status`（待确认数、常驻字数、近 7 天命中/重犯、降级状态）；`asp update` 后重放 overlay；`asp doctor` 增协议/写权限/超预算/嵌套检查。画像 A 用双击入口/Agent 对话触发，无需命令行。
- **P2**：`vault import --from <agent>`（预览后入 inbox）、`vault export` 与 `restore`（age 加密单文件，Agent-sync 管值通道；private/、imports/、凭证原值不入包）。
- 全部命令返回逐目标状态，不打印资料/凭证明文；`--dry-run` 与退出码由研发评审定。**P0 不新增 vault 命令（D19）。**

## 8. 引擎技能（P1 开发需求，不计入已发货技能数）

`cold-start-interview`（先读已同意资料、只问缺的 3 问、给确认草稿）· `context-ingest`（≥3 份资料提术语/风格，附最小证据，不把推断写成事实）· `remember`（区分口令与普通纠正，敏感/冲突不得直接生效）· `weekly-review`（汇总候选/来源/默认动作，最多问 5 个问题）。P2 另有 session-harvest / edit-diff-learn / skill-distill，前提满足后才可启用。packs/base/AGENTS.md 托管段写入经验库协议。

## 9. 验收与红线

- 验收统一使用 PRD §8：T03（访谈/导入/草稿确认/首用引用）、T04（口令/纠正/合并/冲突/忘掉）、T11（权益与设置八类）、T12（提交器并发六类）、T13（schema 夹具八类）、T14（≥4 Agent 闭环证据）、T15（指标一致性）。
- **红线**：默认不扫描整机、不默读会话、不将公共包当私有资产；vault 原文不进任何公开仓库；「忘掉」不宣传为彻底抹除；云端 Agent 数据出境按其服务政策如实告知。
- 相关仓库边界：ai-cold-start 管结构/命令/技能/适配器；Agent-sync 管加密值与无 git 恢复（见 SIAE 总控 D14 契约）。
