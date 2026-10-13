# AI 编码工作流（vibe-coding 方向）

本目录技能面向「用 AI 写代码的人」：从想法到上线全程的防翻车纪律。两层 12 技能 = 基础层 25（另装）+ 本方向 12。

## 使用原则（读再动手）

写任何代码前，先读 `karpathy-guidelines` 六条准则；写完，按它验收。

## 十二技能地图

**开始前**
- spec-driven-development：需求没成文时，先写规格（问题/范围/验收/风险）
- karpathy-guidelines：写之前过六条行为准则

**实现中**
- test-driven-development：红绿循环，测试先行
- incremental-implementation：薄切片交付，每片端到端可验证
- source-driven-development：框架行为对齐官方文档，留出处
- constraint-driven-development：把质量底线写成 CONSTRAINTS.md 合同

**收尾**
- code-review-and-quality：五轴评审自己与 AI 的产出
- code-simplification：行为不变的简化重构
- security-and-hardening：安全加固清单（输入/认证/授权/秘密/依赖）
- git-workflow-and-versioning：原子提交/分支/语义版本/changelog
- test-scenarios：从用户故事生成验收场景
- debugging-and-error-recovery：线上/本地问题的根因闭环

## 十环工作流（按阶段选用）

1. 想法 → spec-driven-development 成规格
2. 规格 → test-scenarios 生成验收场景
3. karpathy-guidelines 过一遍实现计划
4. test-driven-development 红绿循环实现核心逻辑
5. incremental-implementation 薄切片推进外围
6. source-driven-development 校验框架关键行为
7. constraint-driven-development 落质量合同看守
8. security-and-hardening 过安全清单
9. code-review-and-quality + code-simplification 评审与简化
10. git-workflow-and-versioning 原子提交发版，debugging-and-error-recovery 备用

## 术语速查

| 术语 | 一句话 |
|---|---|
| 曳光弹 | 端到端打通的最小闭环，后续再加厚 |
| 接缝 | 不进内部就能观察行为的公开边界 |
| 红绿循环 | 先写失败测试（红）→ 最小实现（绿）→ 重构 |
| 质量合同 | CONSTRAINTS.md 里成文的质量底线，防悄悄降标 |
| 原子提交 | 一个 commit 只做一件事，可独立回滚 |
| IDOR | 越权访问他人对象（只查登录不查归属） |
