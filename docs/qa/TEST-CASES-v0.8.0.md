# QA 测试用例与执行记录 — AI-cold-start v0.8.0（零 MCP 默认）

> 2026-10-01 · kurtx/ZCode · 依据 software-testing-guide（AAA 模式 / ground-truth 原则 / P0-P4 分级 / 质量门禁）
> 本文件 = 唯一事实源（用例规格）；执行状态见同目录 TEST-EXECUTION-TRACKING.csv

## 测试环境

- Windows 11 26200 x64 · PowerShell 5.1 · 便携 Node v24.21.0（tools\nodejs）· 无 git/python
- 被测对象：AI-cold-start v0.8.0（@054861b2，工作副本 acs-v08/，含 7 个适配器 fixture 化）
- 沙箱方法：fixture 适配器把 detect/skills_dir/instructions.target/mcp.target 全部重定向到 `_qa/sandbox/`（绝对路径），**真实用户 8 个关键配置文件 SHA256 护栏比对**（install-run1.log 为 cmd 重定向 GBK 编码，断言按 ANSI 读）
- 用户故事覆盖：US1 一键安装 / US2 幂等零破坏 / US3 首用内容 / US4 可选增强 / US5 doctor / US6 周更安全 / US8 承诺一致；US7 换机迁移不在本轮（v0.6.0 已真机验收）

## 用例与结果（15 条全部执行：14 PASS / 1 FAIL(P4)）

### TC-INST-001 探测（US1）— PASS
- **Arrange**：7 个 fixture agent 目录（claude/codex/zcode/opencode/cursor/workbuddy/trae）
- **Act**：`asp.ps1 detect`
- **Assert**：7/7 识别且 id 正确 ✅

### TC-INST-002 安装首轮（US1/US2/US3）— PASS（19 项断言 AS-001..031）
- **Act**：`echo y | asp.ps1 install`（非交互）
- **Assert**（摘要）：
  - skills：6 个有 skills_dir 的 agent 各部署 fresh-docs（trae 迁移-only 不写）✅
  - managed-section：CLAUDE.md / codex-AGENTS.md / SOUL.md 标记恰好一次；cursor .mdc 带 frontmatter ✅
  - 零 MCP：4 个 JSON 端 merge 后用户条目原样、无 asp-* 新增；codex toml 零写入（提示仅进控制台，by design）✅
  - 诚实化：5 条 smoke 警告（带 smoke 的 5 个适配器；workbuddy/trae 无 smoke 字段系设计）✅
  - trae「包安装未开放」+ workbuddy「设置界面手动添加」消息 ✅；备份与 _state.json（7 agents）✅

### TC-INST-003 幂等重装（US2）— PASS（AS-060..064）
- **Act**：完全相同命令第二遍
- **Assert**：托管段仍恰好一处（updated 非重复追加）、claude.json 仍恰好用户 1 条、零 MCP 路径稳定 ✅

### TC-INST-004 真实环境零漂移（US2 红线）— PASS
- **Assert**：8 个真实用户文件（.claude.json / CLAUDE.md / zcode config.json / cursor mcp.json / opencode.json / codex config.toml / workbuddy mcp.json+SOUL.md）SHA256 全部与安装前一致 ✅

### TC-MCP-010 用户自加可选件不被破坏（US4）— PASS
- **Arrange**：手工向沙箱 claude.json 加入 asp-context7（remote）
- **Act**：再次 install
- **Assert**：两条款目（user-github + asp-context7）原样共存——空模板下 merge 零迭代，只增不覆盖语义自然成立 ✅

### TC-DOC-001 doctor 回归（US5）— PASS
- **Act**：`asp.ps1 doctor`（fixture 配置面）
- **Assert**：context7 PASS（握手 OK · Context7 4.1.1）；4 个假条目 FAIL 且诊断明确（DNS/可执行缺失）；codex SKIP（零写入自洽）+ workbuddy SKIP manual；FAIL 存在时退出码 1 ✅（v0.7 真机 32 条实测另见 GOLD-SET 记录）

### TC-UPD-001 周更安全中止（US6）— PASS（附 P3）
- **Act**：`asp.ps1 update`（本地 dev vs 远程 v0.8.0）
- **Assert**：拉取 index.json 成功（GitHub Pages 已上线）→ 版本不同 → 下载 base-v0.8.0.zip 404 → **无任何写入**（备份数不变）✅；但失败以裸异常+HTML 刷屏呈现 → **BUG-002 (P3)**

### TC-STAT-001..007 静态与安全 — 6 PASS / 1 FAIL(P4)
- ST-001 asp.ps1 UTF-8 BOM 存在 ✅（DEV 坑 #1 回归）
- ST-002 asp.sh 纯 LF（bash 兼容）✅
- ST-003 全仓密钥扫描（github_pat 模式）零命中 ✅
- ST-004 双端零 MCP 消息文案一致 — **FAIL：asp.sh 少"MCP"三字 → BUG-004 (P4)**
- ST-005 registry 一致性（v0.8.0 / skills 20 / mcp_defaults 空）✅
- ST-006 optional-mcp.md 含免费 key 引导（context7.com/dashboard）✅
- ST-007 远端 base skills 实数 20（GitHub API）✅

### TC-GOLD fresh-docs 行为验收（US3 行为面）— PASS（引用）
- 8 时效题 A/B 双臂：准确性 15/16≥阈值、版本标注 8/8、总分与 context7 打平 46/48，详见 [GOLD-SET-DOCFRESH.md](../GOLD-SET-DOCFRESH.md)（ZCode 腿；WorkBuddy 腿待跑）

## 缺陷登记

| ID | 级别 | 描述 | 复现 | 修复建议 |
|---|---|---|---|---|
| BUG-001 | P2 | install 不消费 `-Yes` 参数（migrate/export 均支持）——非交互自动化无可靠确认通道；且 Read-Host 在 stdout 重定向下行为不稳 | `asp.ps1 install -Yes` 仍弹确认；`echo y\|` 在部分管道形态下被误判取消 | Invoke-Install 开头 `if ($Yes) { $script:AspConfirmed = $true }`（一行修复） |
| BUG-002 | P3 | update 下载 zip 404 时未捕获：裸异常 + GitHub 404 整页 HTML 刷屏（无写入，安全但体验差） | mirror 上线后 `asp.ps1 update`（registry sha 空且 zip 未打包场景） | 下载段 try/catch → 「zip 不存在（发版未打包或已下架），本地保持不变」 |
| BUG-003 | P3 | JSON merge 即使零新增也会以 PS ConvertTo-Json 重写整个用户配置（值不变、格式/缩进变；v0.2 起既有行为） | 空模板 install 后对比用户 JSON 字节 | 模板空或零新增时跳过写回 |
| BUG-004 | P4 | 零 MCP 报告文案双端不一致：asp.sh 为「默认 0 个（…）」，asp.ps1 为「默认 0 个 MCP（…）」 | 对比两脚本字符串 | asp.sh 补「MCP」三字 |

> 测试基建教训（非产品缺陷，入 DEV 参考）：PS `-replace` 是全量替换（fixture 生成曾误伤双 target 字段）；PS5.1 无 BOM 脚本中文必乱码（断言脚本自踩）；cmd 重定向日志为 GBK；cmd `%ERRORLEVEL%` 在复合命令中按解析期展开。

## 质量门禁

| 门禁 | 结果 | 状态 |
|---|---|---|
| 执行率 | 15/15（US7 范围外未列入计划） | ✅ |
| 通过率 | 14/15 = 93.3%（≥80%） | ✅ |
| P0 | 0 | ✅ |
| P1 | 0 | ✅ |
| P2 | 1（BUG-001，有一行修复） | 非门禁项，建议修复后再发版 |
