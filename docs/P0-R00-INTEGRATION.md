# P0 R00/R01/R03 集成与验证指南

> 状态：**staging（等待 xujinya 真机验证）**。分支 `p0/staging-r00-r01-r03` 上 asp.ps1 / asp.sh **已预补丁**（R00/R03 + R01 全部接入），真机验证通过后才合 main（D19 冻结期间 main 不动）。
> 2026-10-05 ponytail 削减已执行：原 4 个 apply-r0x-patch.ps1/.sh（357 行）删除——补丁直接落在分支文件上，审查方式改为 `git diff main`（理由：分支即当前 main 拉出，无漂移；补丁器只在 main 持续移动后才有价值）。

## 交付物

| 文件 | 作用 | 验证状态 |
|---|---|---|
| `asp.ps1`（已预补丁） | R00：`Copy-SkillSafe` 接入 install 复制（备份+逐项覆盖+未知文件保留）；R01：`Convert-ToPlaceholders` 接入 export（占位符替换 → credential-lint 零命中才打包，报警即中止清暂存）；R03：doctor 嵌套扫描 + 加载三层口径 | PS Parser 语法过；真机用例未跑 |
| `asp.sh`（已预补丁） | R00：同名技能备份+逐项覆盖（内联循环）；R01：同上 bash 版；doctor 嵌套检测 | bash -n 过；真机用例未跑 |
| `scripts/skill-safe-copy.ps1` | R00/R03 核心模块 | ✅ 22/22 夹具（真 PS5.1） |
| `scripts/export-sanitize.ps1` | R01 占位符替换模块 | ✅ 8/8 夹具 |
| `scripts/credential-lint.ps1/.sh` | R01 最后关卡（12 类凭证形态，命中 exit 1，输出打码） | ✅ 双平台脏/净夹具 |
| `scripts/test-skill-safe-copy.ps1` / `test-export-sanitize.ps1` | 测试驱动（逐字抽取 region 执行，保证测的是交付代码） | — |
| `vault/`（schema + 10 夹具 + validate-cards.py + test-fixtures.py） | 私有环 B1 资产（PRD §5.4/T13） | ✅ T13 14/14 |
| `docs/expert/` 三件 | 专家环暂缓期可做协议 | — |
| `docs/qa/TEST-CASES-P0.md` | 8 真机用例（验收门） | — |
| `docs/DOC-MAP.md` | 五子模块 MRD/PRD ↔ 仓库总图 | — |

## xujinya 执行步骤（已简化——无需打补丁）

1. `git fetch && git checkout p0/staging-r00-r01-r03`
2. `git diff main -- asp.ps1 asp.sh` —— 审查预补丁内容（接入点：模块加载 / install 复制 / export 打包前 / doctor 扫描）
3. `powershell -ExecutionPolicy Bypass -File scripts\test-skill-safe-copy.ps1`（期望 22/22）与 `test-export-sanitize.ps1`（期望 8/8）、`python vault\test-fixtures.py`（期望 14/14）——本机自测
4. **真机执行 `docs/qa/TEST-CASES-P0.md`**：TC-R00-01（Win10/PS5.1 嵌套复装）→ TC-R00-02（用户改动周更）→ TC-R00-03（mac 备份）→ TC-R01-01（export 注入测试 token，断言产物与日志零原值、lint 失败时零输出文件）→ TC-R00-06（平台矩阵）→ TC-R03-01（doctor 三层口径）
5. 全过后合 main、解除 README 宣传冻结（同步改 README「无损更新/双击周更」口径）、gitlink bump 走 SIAE 广播

## 设计要点

- **预补丁直落分支**（替代补丁器）：分支即 main 拉出、无漂移，`git diff` 即审查；`git checkout main -- asp.ps1` 一条命令即完整回滚。
- **逐项覆盖而非整目录替换**：满足 R00 四条验收（零嵌套/顶层新版/用户改动可恢复/未知文件未删）。
- **Repair 需显式确认**：doctor 只报告；`Repair-NestedSkillDir` 四重守卫（内外同名签名 + 无未知用户文件 + 备份 + 哈希校验）且不自动运行（PRD N1「确认后」）。
- **lint 输出打码**：命中行只显示前 6 字符+长度，绝不回显完整密钥。
- **export 默认输出已移出仓库根**（`$HOME/asp-env-*.tar.gz`，原 $PWD 是 9/30 tar.gz 误提交事故的根源）。

## 与同步底座（SYN PRD v0.3）的对接

- **`asp sync` 命令组宿主在本仓库**（asp.ps1/asp.sh），底层实现 vendored 调 Agent-sync `broadcast/` 引擎（Agent-sync @3a75718，26 断言全绿，CLI：init/commit/digest|pull/ack/forget/devices/compress）。
- 契约：IF-15（广播记录哈希链 bc_<dev6>_<seq6>）/ IF-16（确定性摘要，固定节序）/ IF-17（跨设备 age 加密）。阶段口径 D27：**同机 P1 / 跨设备 P2 / P0 只做设计与评审**——本批不含 P0 验收范围，真机验证批不因 sync 阻塞。
- export→vault 衔接不变（D14 字段级互斥）：广播只同步进展摘要，凭证与经验卡仍走各自通道。

## 已知边界（如实）

- 真机用例 0 执行——本批全部验证=本机夹具（Windows 11 / PS5.1 / python 3.14）；Win10 真机、mac 真机未跑。
- `credential-lint` 形态扫描不是万能脱敏，零命中 ≠ 无凭证（PRD §10 人工预览仍必需）。
- 4 个补丁器已删除；若 main 在验证期间前移，基于新 main 重放（模块本身不动，仅重跑 git diff 审查）。
