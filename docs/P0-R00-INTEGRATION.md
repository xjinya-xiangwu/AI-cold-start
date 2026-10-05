# P0 R00/R01/R03 集成与验证指南

> 状态：**staging（kurtx 机产出，等待 xujinya 真机验证）**。本目录脚本已在 kurtx（Windows 11 / PowerShell 5.1）通过夹具测试，但按 PRD 纪律，**只有 xujinya 真机跑完 `docs/qa/TEST-CASES-P0.md` 才能合入 main 并解除宣传冻结**。
> 对应审计：2026-10-05 PRD 合规审计 Required #1/#2（R00/R01 未实现）。

## 交付物

| 文件 | 作用 | 测试状态 |
|---|---|---|
| `scripts/skill-safe-copy.ps1` | R00/R03 核心模块：`Copy-SkillSafe`（备份+逐项覆盖+未知文件保留）、`Get-NestedSkillDirs`（嵌套检测）、`Repair-NestedSkillDir`（签名校验+备份+未知文件守卫+哈希校验后清理） | ✅ 22/22 断言（本机 PS5.1，`scripts/test-skill-safe-copy.ps1`） |
| `scripts/apply-r00-patch.ps1` | 把 asp.ps1 三个接入点接上模块（模块加载/install 复制/doctor 扫描）——幂等、锚点失配即中止、先备份到 `_backup/` | ✅ 夹具端到端 + 语法解析 + 幂等二跑 |
| `scripts/apply-r00-patch.sh` | asp.sh 两个接入点（install 复制行内联 R00 逻辑/doctor 扫描）——同为幂等+锚点校验 | ◻️ bash 语法+内嵌 python 编译通过；端到端在 xujinya 执行 |
| `scripts/credential-lint.ps1` / `.sh` | R01 前置构件：凭证形态扫描（12 类模式），命中退出码 1，输出打码 | ✅ 双平台夹具（脏=6 类命中+exit 1；净=零命中+exit 0） |
| `scripts/test-skill-safe-copy.ps1` | 模块测试驱动（从模块文件逐字抽取 R00-CORE region 执行，保证测的是交付代码） | — |

## xujinya 执行步骤（按顺序）

1. `git fetch && git checkout p0/staging-r00-r01-r03`（分支名见 SIAE broadcast）
2. `powershell -ExecutionPolicy Bypass -File scripts\test-skill-safe-copy.ps1` —— 模块自测应 22/22
3. `powershell -ExecutionPolicy Bypass -File scripts\apply-r00-patch.ps1` —— 接入 asp.ps1（失败会明确报哪个锚点没找到，禁止盲改）
4. `bash scripts/apply-r00-patch.sh` —— 接入 asp.sh
5. `git diff` 审查三处改动 + `git diff --stat`
6. **真机执行 `docs/qa/TEST-CASES-P0.md`**：TC-R00-01（Win10/PS5.1 嵌套复装）→ TC-R00-02（用户改动周更）→ TC-R00-03（mac 备份）→ TC-R00-06（矩阵）→ TC-R03-01（doctor 嵌套检测）
7. 全过后合入 main、解除 README 宣传冻结（同步改 README:35/37 口径）、gitlink bump 走 SIAE 广播

## R01（全链已交付，随本分支）

交付 = `scripts/export-sanitize.ps1`（占位符替换：JSON 键名规则 + TOML/INI/env 行级规则，8/8 夹具过）+ `scripts/apply-r01-patch.ps1/.sh`（接入 export 打包前：替换 → lint 零命中才打包，报警即中止清理暂存；manifest/说明文案改占位符口径）+ `scripts/credential-lint.ps1/.sh`（最后关卡）。
xujinya 步骤：在 apply-r00-patch 之后执行 `apply-r01-patch.ps1` / `apply-r01-patch.sh`；验收 = TC-R01-01（注入测试 token 的 export，断言产物与日志零原值、lint 失败时不生成任何输出文件）。

## 设计要点（为什么这样做）

- **补丁器而非直接改 asp.ps1**：本机无法真机验证安装器全流程；补丁器锚点失配即中止，杜绝盲改；main 保持 D19 冻结状态直到真机证据就绪。
- **逐项覆盖而非整目录替换**：`Copy-SkillSafe` 对已存在目录先整目录备份、再只覆盖源内各项——满足 PRD R00 四条验收（零嵌套/顶层新版/用户改动可恢复/未知文件未删）。
- **Repair 需显式确认**：doctor 只报告嵌套；`Repair-NestedSkillDir` 有"内外同名签名 + 无未知用户文件 + 备份 + 哈希校验"四重守卫，且不自动运行（PRD N1"确认后"）。
- **lint 输出打码**：命中行只显示前 6 字符+长度，绝不回显完整密钥（评审版 §6 证据纪律）。
