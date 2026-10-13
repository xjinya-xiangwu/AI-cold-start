# 智能体冷启动包 · 使用说明（随包 README）

> 版本 v0.13.1 ｜ 文档更新：2026-10-13 ｜ 微信客服：**xjinya**（加我后拉群，安装 / 更新 / 升级都在群里处理）
> 
> 📖 **图文版手册（带安装页与报告截图）**：https://asp-registry-xjinya.oss-cn-hangzhou.aliyuncs.com/docs/manual/user-manual-v1.1.html

你手里这个包，是把一套成型的「专家工作方法」装进你电脑上已有的 AI 助手（Claude Code / Cursor / Codex / ZCode / Kimi 等）：**25 个跨职业通用技能（基础包）+ 可选方向包（当前现货：AI 产品经理 12 技能）+ 角色工作流 + 即用指令**。装完重启你的 AI 工具即可生效，全程不需要填任何 API key。

---

## 1. 包里有什么

### 1.1 基础包 `base`（¥20 买断，25 个技能）

跨职业通用的方法论技能，按用途分五类：

| 类别 | 数量 | 技能 |
|---|---|---|
| 想清楚（决策与方案） | 5 | idea-grilling · brainstorming · assumption-audit · decision-premortem · minimal-solution |
| 排得起（规划与落地） | 5 | okr-planning · project-kickoff · risk-register · stakeholder-mapping · dev-handoff |
| 兜得住（质量与止损） | 7 | bug-triage · systematic-debugging · post-mortem · launch-readiness · verify-before-done · tech-spec-review · mermaid-diagrams |
| 算得清（数据与实验） | 3 | data-insight · experiment-design · metric-design |
| 用得爽（日常提效） | 5 | meeting-to-decisions · release-notes · fresh-docs · ponytail · adhd-mode |

外加：**11 条通用即用指令**（`packs/base/prompts/prompts.md`，决策评审 4 条 + 数据实验 7 条）和 **base 版 AGENTS.md 角色工作流**（五环工作法 + 术语速查）。

### 1.2 方向加购 `ai-pm`（+¥10/方向，当前现货：AI 产品经理）

| 类别 | 数量 | 技能 |
|---|---|---|
| 发现与洞察 | 4 | user-research-interview · market-sizing · competitor-analysis · feedback-triage |
| 定义与设计 | 4 | prd-drafting · prd-review · user-story · feature-prioritization |
| AI 产品专项 | 2 | ai-eval-design · ai-ux-patterns |
| 战略与交付 | 2 | roadmap-planning · product-reporting |

外加：**31 条 PM 专属即用指令** + **PM 版 AGENTS.md**（两层 31 技能地图 + 九环 PM 工作流 + PM 术语速查）。安装 PM 包时自动先装基础包（依赖内置，一次装完）。你手里的 zip 里有哪些包，取决于你下单时买了什么——只买基础包的用户拿不到专业层内容（物理隔离）。

### 1.3 安装器与配套脚本

| 文件 | 作用 |
|---|---|
| `setup.bat` / `setup.command` | 双击安装（Windows 打开选择式安装页；Mac/Linux 命令行安装） |
| `update.bat` / `update.command` | 一键更新（双更新源 + sha256 校验） |
| `migrate-export.bat/.command`、`migrate-restore.bat/.command` | 环境迁移：旧机器导出 → 新机器还原（换电脑 / 多机同步） |
| `asp.ps1`（Windows）/ `asp.sh`（Mac/Linux） | 安装 / 更新引擎本体，所有命令见附录 B 速查表 |
| `packs/` | 技能内容本体（离线快照，断网也能装） |
| `registry/` | 更新源索引（更新时联网拉取） |

### 1.4 关键参数

| 参数 | 说明 |
|---|---|
| API key 需求 | **0 个**。默认功能全部无需 key；安装器永不收集任何 key |
| 依赖 | Windows：PowerShell 5.1+（系统自带，零依赖）；macOS/Linux：python3（系统自带或一条命令可装） |
| 网络需求 | 安装可离线（内容内置）；更新与 MCP 增强需要联网 |
| 数据行为 | 技能全部是本地文件；安装器不上传你的任何数据；MCP 预设只收官方出品、零自建服务 |
| 改动方式 | **只新增不覆盖**：所有写入先自动备份到 `_backup/`，重复安装不产生重复配置（幂等托管块） |
| 适用系统 | Windows 全流程实测；macOS/Linux 已内置（见 §3 能力边界） |
| 支持的 AI 工具 | 10 个（见 §4 适配表），检测到几个装几个 |

---

## 2. 安装（Windows，推荐路径）

**三步：解压 → 双击 `setup.bat` → 看安装报告。**

1. 把 zip 解压到一个**你能找到的目录**（不要解压后直接在压缩软件预览里双击）。
2. 双击 `setup.bat`。会弹出一个本地选择页（在你自己的电脑上运行，不经过任何服务器）：
   - **第一步·选择**：左边列出自动探测到的 AI 工具（勾选要装进哪些）；右边列出本包的全部内容——技能逐项可勾（带简介）、AGENTS.md 与指令、可选 MCP 增强三档。默认已勾好推荐组合，直接全用也行。
   - **第二步·执行**：点一键执行，看实时进度，结束出**安装报告**（装到了哪些工具、写了哪些文件、备份在哪）。
3. **重启你的 AI 工具**，然后试一句：
   > 用 prd-drafting 帮我起草「XX 功能」的 PRD 框架（装了 PM 包的用户）
   > 帮我把这个季度目标拆成 OKR（只装基础包的用户）

不想用页面？等价命令行（在解压目录打开 PowerShell）：

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 install      # 装到全部探测到的工具
powershell -ExecutionPolicy Bypass -File asp.ps1 detect       # 只探测，不安装
```

**安装过程会发生什么**：探测你电脑上已装的 AI 工具 → 对每个工具做适配（写入技能文件、合并角色配置与 MCP 结构，key 一律留占位符）→ 输出报告。已有配置一律不动；每处改动先备份到 `_backup/`；重复运行安全（不会装出两份）。

**装完建议体检**（可选，装了 MCP 增强的用户推荐）：

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 doctor
```

它会对你机器上的每条 MCP 配置做**真实握手测试**，输出 PASS / WARN / FAIL / SKIP 健康表——「配置写了」不算数，「实测握上手」才算。

## 3. 安装（macOS / Linux）

```bash
cd 解压目录
bash asp.sh install     # 或 python3 asp.sh install
```

能力边界（如实说明）：**技能安装、更新、环境迁移**在 Mac/Linux 可用；**选择式安装页**与 **MCP 一键预设**当前为 Windows 提供（Mac/Linux 用户如需 MCP 增强见包内 `packs/base/mcp/optional-mcp.md` 手动清单）。部分工具在 Mac/Linux 的目录布局仍在社区实测中，探测不到会自动跳过并如实标注——遇到问题把输出截图发群里（§10）。

## 4. 适配了哪些 AI 工具（10 个）

安装器自动探测，有几个装几个；可执行文件不在 PATH 但有配置残留的会如实标注「疑似仅配置残留」。

| 工具 | 适配内容 | 平台 |
|---|---|---|
| Claude Code | skills + 全局 AGENTS.md + MCP 托管块 | Win / Mac |
| Cursor | skills + 规则目录 + MCP | Win / Mac |
| Codex CLI | skills + AGENTS.md + TOML 托管块 | Win / Mac |
| ZCode | skills + 全局配置 + MCP | Win / Mac |
| Kimi CLI | skills + 配置 | Win / Mac |
| DeepSeek（DSH） | skills + MCP patch | Win / Mac |
| opencode | skills + 远程/数组式 MCP | Win / Mac |
| Trae（字节） | 配置与规则目录收集 | 探测不到自动跳过 |
| Qoder（阿里） | 配置与规则目录收集 | 探测不到自动跳过 |
| WorkBuddy | 配置与规则目录收集 | 探测不到自动跳过 |

两个补充用法：

- **装到项目目录而不是全局**：`asp agents <目录>` 把 AGENTS.md 角色说明部署到指定项目（默认当前目录），让某个项目用上这套方法。
- **检测不到我的工具？** 确认该工具装过且能正常启动；仍检测不到 → 群里发 `asp.ps1 detect` 的输出截图，客服帮你对。

## 5. 更新（每周发版）

```powershell
# Windows：双击 update.bat，或在解压目录：
powershell -ExecutionPolicy Bypass -File asp.ps1 update
```

- 更新走**双更新源**（主源超时自动切备源），每个文件 sha256 校验后才落盘。
- 更新群里会发版本通知；**购买含 3 个月周更**，到期后的续更方式与价格以商品页或客服告知为准。
- 更新 = 增量替换技能文件与配置（同样只增不覆盖、自动备份），已装内容不会重复。

## 6. 回滚 / 重装 / 卸载

- **回滚**：每次安装/更新的备份都在解压目录 `_backup/` 下，按报告里的路径恢复即可。
- **重装/换目录重装**：直接重跑 `setup.bat`——幂等设计，重复运行不会产生重复配置。
- **卸载**：技能是独立文件，删除不影响原工具；如需精确清理，群里发安装报告截图，客服给你逐项清单（或把本说明书附录 A 交给你的 AI 助手处理）。

## 7. 换电脑 / 多机同步（环境迁移）

**离线包方式（双击即可）**：旧电脑双击 `migrate-export.bat` 生成一个迁移包 → 拷到新电脑 → 双击 `migrate-restore.bat`。还原时自动检测新机器上有哪些 AI 工具、由你选择导入哪些；单项 ≤20MB 默认同步、超大项列出来让你勾选；导入结果逐文件哈希校验；替换前自动备份（merge 语义：只增改不删除）。

**GitHub 私有仓库方式（多台机器长期同步）**：`asp export -Repo <你的私有仓库>` 把全部 agent 环境（skills / 全局 AGENTS.md / MCP 配置 / 记忆目录）推到**你自己的** GitHub 私有仓库；新机器 `git clone` 后 `asp migrate env` 一键还原。零 U 盘零网盘。详见包内 `docs/MIGRATE.md`。

## 8. 可选增强：一键常用 MCP（默认不装，零 key）

包内**默认零 MCP**——文档查新等增强能力由技能指挥 AI 工具内置的联网能力完成，不额外增加依赖。想要更多，一条命令按预设安装（全部为官方出品服务，零自建；OAuth 在你的 AI 工具内登录，key 不落安装器）：

| 预设 | 内容 | 适合 |
|---|---|---|
| `essentials` | context7 文档库（官方远程端点）/ 跨会话记忆 / 深度思考 | 所有人，推荐先装这个 |
| `work-tools` | Figma / Notion / Jira·Confluence / Linear / Slack / Asana / Microsoft Learn（官方 MCP） | 办公协作场景 |
| `dev-tools` | Microsoft Playwright / MCP 官方 filesystem / Supabase | 开发者 |

```powershell
powershell -ExecutionPolicy Bypass -File asp.ps1 mcp install        # 交互选预设
powershell -ExecutionPolicy Bypass -File asp.ps1 mcp list           # 看有哪些
powershell -ExecutionPolicy Bypass -File asp.ps1 doctor             # 装完体检
```

没有 npx 环境会自动降级并提示；手动清单见 `packs/base/mcp/optional-mcp.md`。

## 9. 常见问题 FAQ

**Q：需要会写代码 / 用命令行吗？**
A：Windows 用户不需要——解压、双击、全程中文提示。Mac 用户一条命令。

**Q：会覆盖我已有的配置和技能吗？**
A：不会。只新增不覆盖，改动前自动备份到 `_backup/`，可完整回滚；重复安装不产生重复内容。

**Q：我电脑上有多个 AI 工具，都能装吗？**
A：能。一次安装自动识别全部已装工具，各自适配；也可以在选择页里只勾其中几个。

**Q：要填 API key 吗？**
A：默认功能零 key。可选 MCP 增强里需要登录的服务（如 Notion、Linear）都在你的 AI 工具内完成 OAuth 登录，安装器永不收集任何 key。

**Q：怎么更新？更新要钱吗？**
A：双击 `update.bat`（Mac：`bash asp.sh update`）。购买含 3 个月周更；到期后续更方式与价格以商品页或客服告知为准。

**Q：只买了基础包，能补一个 PM 方向吗？**
A：能。群里发订单号，补差价拿方向包升级；已装内容不重复，方向包自动带基础层。

**Q：支持 Mac 吗？**
A：安装、更新、迁移已内置；选择式安装页和 MCP 一键预设当前为 Windows 提供（见 §3）。Mac 实测中发现的边界我们如实公告，不会宣传未验证的能力。

**Q：我装它到底改变了什么？**
A：你的 AI 从「会聊天」变成「按方法干活」：同样的需求，装包后会先问关键问题、按专业流程出结构化结果（比如 PRD 带评测验收与人机协同章节、排期带风险登记表、复盘到根因并带行动项）。技能就是一套写在本地的方法说明文件，你的 AI 会在合适时机按它行事。

**Q：数据安全吗？会传我的资料吗？**
A：技能全部是本地文件；安装器不上传任何数据、不收集任何 key；更新只从更新源拉内容；环境迁移推的是你自己的私有仓库。你的对话与文件始终在你机器上。

**Q：安装报错 / 检测不到工具怎么办？**
A：三步——① 截图安装报告或 `detect` 输出；② 加微信客服 **xjinya** 进群；③ 群里发截图，管理员帮看。Windows 常见原因：用了绿色精简系统缺 PowerShell 组件、或没有以解压后的目录运行。

**Q：这个包和网上找的 prompt 合集有什么区别？**
A：三点——① 是**成体系的方法**（技能 + 角色工作流 + 指令三层，不是零散提示词）；② **自动适配 10 个工具**，装完即用；③ **每周更新**，技能持续迭代并随周报吸收新工具情报。

## 10. 客服与售后

- **微信客服：xjinya** —— 加我后拉进更新群（发版通知 / 使用答疑 / 升级补差价都在群里）。
- 求助请带上：**安装报告截图**（或 `detect` / `doctor` 输出）+ 你的系统版本。
- 更新群同时是「产品活着」的证明：每次发版有更新日志，装了什么、修了什么、为什么，全公开。

---

## 附录 A：把安装交给你的 AI 助手（可选）

你解压后，也可以直接对任意一个 AI 工具（Claude Code / Cursor / ZCode / Codex 等）说：

> 请阅读当前目录下的 USER-README.md「附录 A」，按里面的步骤帮我把这个包装好，完成后给我安装报告。

以下是给 AI 助手的执行指令，请严格照做：

```markdown
任务：在用户本机安装「智能体冷启动包」（当前目录即解压后的包根目录）。

步骤：
1. 先读本目录 USER-README.md §1-§4，确认平台：Windows 用 asp.ps1（PowerShell 5.1+），
   macOS/Linux 用 asp.sh（python3）。
2. 探测：运行 `powershell -NoProfile -ExecutionPolicy Bypass -File asp.ps1 detect`
   （Mac/Linux：`bash asp.sh detect`）。把探测到的 agent 清单报告给用户。
3. 与用户确认两件事再继续：① 装到哪些 agent（默认全部探测到的）；
   ② MCP 增强：默认不装；用户明确要求时，Windows 上运行
   `powershell -NoProfile -ExecutionPolicy Bypass -File asp.ps1 mcp install`。
4. 安装：`powershell -NoProfile -ExecutionPolicy Bypass -File asp.ps1 install`
   （Mac/Linux：`bash asp.sh install`）。包间依赖（方向包自动带基础层）由安装器处理。
5. 验证：`... asp.ps1 status` 确认已装清单；装了 MCP 的追加 `... asp.ps1 doctor` 看健康表。
6. 输出报告：装到了哪些 agent / 写了哪些文件 / _backup 位置 / 更新命令（update.bat）/ 回滚方法。

红线：
- 绝不收集、索要或保存用户的任何 API key / 密码。
- 只写包目录与各 agent 的托管配置段（安装器自带 _backup 备份）；不修改包目录之外的无关文件。
- 任一步骤失败即停止，原样报告错误输出，不要自行改写安装器脚本。
- 本包只新增不覆盖；如需回滚，按报告用 _backup 恢复。
```

## 附录 B：命令速查表

在解压目录打开终端（Windows 用 PowerShell）：

| 命令 | 作用 |
|---|---|
| `setup.bat`（双击）/ `asp.ps1 ui` | 打开两步选择式安装页 |
| `asp.ps1 install [包名]` | 安装（默认全部包；`base` / `ai-pm`） |
| `asp.ps1 detect` | 只探测本机 agent |
| `asp.ps1 status` | 查看已装状态 |
| `asp.ps1 update` | 一键更新（双源 + 校验） |
| `asp.ps1 doctor` | MCP 真实握手体检（PASS/WARN/FAIL/SKIP） |
| `asp.ps1 agents [目录]` | 把 AGENTS.md 部署到指定项目目录 |
| `asp.ps1 mcp install / list / remove` | MCP 预设安装 / 列表 / 移除（Windows） |
| `asp.ps1 export -Repo <私有仓库>` | 导出全部 agent 环境（迁移/备份） |
| `asp.ps1 migrate <迁移包>` | 还原迁移包到本机（merge 语义） |
| Mac/Linux 等价 | 上述 `asp.ps1` 命令换为 `bash asp.sh <命令>`（ui/mcp 子命令除外，见 §3） |

---

*智能体冷启动包 Agent Cold-start Pack · v0.13.0 · 本说明书与包内 `UPDATES.md`（更新日志）、`docs/MIGRATE.md`（迁移详解）配套阅读。有问题先看 §9 FAQ，再找客服。*
