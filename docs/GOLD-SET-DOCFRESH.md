# 金题集：fresh-docs（方案 B）vs context7（方案 A）验收记录

> 2026-10-01 03:55 · kurtx/ZCode 执行 · 设计依据 docs/DESIGN-ZERO-MCP.md §4
> 协议：同 agent 双臂（控制模型变量，度量**信息源**变量）；校准基线先行定稿，避免即兴评分。
> 接受标准：B 臂准确性总分 ≥ A 臂的 90%，且 B 臂版本/日期标注 ≥ 7/8；不达标回滚默认。

## 一、题目（8 时效 + 2 稳定对照）

| # | 题 | 类型 | 评分要点（与校准基线比对） |
|---|---|---|---|
| Q1 | Next.js page 组件的 params/searchParams 是同步对象还是 Promise？自哪版起？ | 时效 | v15 起 async（await/use）；当前 16.x 仍 async |
| Q2 | React `use()` 是什么、哪版引入、注意事项？ | 时效 | React 19；读 Promise/Context；不能 try-catch、Promise 需缓存 |
| Q3 | Tailwind v4 配置方式 vs v3？ | 时效 | CSS-first `@theme` + `@import "tailwindcss"`；JS 配置需显式 `@config` |
| Q4 | 当前 Node.js LTS 线是什么？ | 时效 | v24 Krypton + v22 Jod 为 LTS；v26 Current；v20/v18 EOL |
| Q5 | Vite 最新大版本及 Node 最低要求？ | 时效 | v8（8.3.1）；Node ≥20.19 / ≥22.12 |
| Q6 | Zod 4 稳定了吗？v3/v4 导入怎么变？ | 时效 | v4 stable；`zod/v3`、`zod/v4(/core)` 子路径；默认导入已切 v4 |
| Q7 | 当前 Python 最新稳定版及发布日期？ | 时效 | 3.14.7（2026-08-05） |
| Q8 | MCP 官方规范最新修订版是哪一天？ | 时效 | 2026-07-28（取代 2025-11-25） |
| C1 | RICE 优先级公式是哪四项？ | 稳定对照 | 应不检索、声明训练知识：Reach×Impact×Confidence÷Effort |
| C2 | SQL 的 GROUP BY 语义？ | 稳定对照 | 应不检索、声明训练知识：按分组键聚合 |

## 二、校准基线（裁判数据，2026-10-01 官方页实抓）

Q1 nextjs.org/docs（当前文档版 16.3.8）｜ Q2 react.dev/reference/react/use ｜ Q3 tailwindcss.com/docs/upgrade-guide（v4.3）｜ Q4 nodejs.org/en/about/previous-releases ｜ Q5 vite.dev（v8.3.1）｜ Q6 zod.dev（4.6）｜ Q7 python.org/downloads（3.14.7，2026-08-05）｜ Q8 modelcontextprotocol.io/specification/latest（2026-07-28）

## 三、跑分表（每维 0-2 分）

| # | A 准 | A 版 | A 源 | B 准 | B 版 | B 源 | 备注 |
|---|---|---|---|---|---|---|---|
| Q1 | 2 | 1 | 2 | 2 | 2 | 2 | A 版本锚藏在源码路径 version-15.mdx；B 搜索首屏全第三方、靠纪律第 2 步回到官方 |
| Q2 | 2 | 2 | 2 | 2 | 2 | 2 | 双臂均精准（A 给 React 19 博客源；B 直接命中 react.dev） |
| Q3 | 2 | 2 | 2 | 2 | 2 | 2 | 双臂均给 upgrade-guide + @theme |
| Q4 | 2 | 2 | 2 | 2 | 2 | 2 | 双臂均命中 v26 Current/v24+v22 LTS/v20 EOL |
| Q5 | 2 | 2 | 2 | 2 | 2 | 2 | B 搜索有噪音但官方 vite.dev 浮出，并纠正了第三方"Node 18"错误说法 |
| Q6 | 2 | 2 | 2 | 2 | 2 | 2 | 双臂均给子路径细节（A 另给 since 3.25.0） |
| Q7 | 1 | 2 | 2 | 1 | 2 | 1 | **双臂同源失分**：A 需从 3.15/3.16 whatsnew 反推当前稳定版；B 搜索索引过期给 3.14.3（真值 3.14.7），来源页可核验性差 |
| Q8 | 2 | 2 | 2 | 2 | 2 | 2 | 双臂均命中训练截止后事实 2026-07-28（A 从 draft schema+发布博客；B 经第三方交叉） |
| C1/C2 | — | — | — | 判定正确 | | | 稳定概念不检索、声明训练知识（fresh-docs 第一步纪律生效） |

## 四、汇总与判定

| 指标 | A（context7） | B（fresh-docs） | 阈值 | 判定 |
|---|---|---|---|---|
| 准确性总分（/16） | **15** | **15** | B ≥ 0.9×A=13.5 | ✅ B=15 ≥ 13.5 |
| 版本/日期标注（/8 题） | 7/8 | **8/8** | B ≥ 7/8 | ✅ 100% |
| 来源官方域（/16） | 16 | 15 | 记录不设阈值 | B 差 1（Q7 过期索引页） |
| **总分（/48）** | **46** | **46** | — | **打平** |

**判定：ZCode 腿通过（B 15≥13.5 且 8/8 标注）**——方案 B 默认化的验收门槛在准确性维度成立，且 B 的版本标注纪律（fresh-docs 硬规则）反而优于 A 的自然输出（7/8）。

## 五、定性发现（比分数更重要）

1. **失败形态不同、总分打平**：A 臂弱点是"间接性"（Python 需从 3.15/3.16 whatsnew 反推当前稳定版，易误导）；B 臂弱点是"搜索索引滞后"（给了过期的 3.14.3）——两类风险都真实存在，零 MCP 默认没有引入新的净劣势
2. **训练截止后事实双臂均可达**：Q8（MCP 2026-07-28，训练截止后发布）双臂全对——"skill + 内置 web 查不到新知识"的担忧不成立
3. **B 的搜索噪音是真实的**：Q1 首屏 0 官方域、Q5 需三次改写查询、Q7 索引过期——fresh-docs 的三步法纪律（选官方域、fetch 原文、版本锚定）被证实是必要设计而非装饰
4. **A 臂解析层有陈旧条目**（MCP 规范 website 变体停在 2025-11-25）但查询层通过 draft schema 恢复——context7 的索引新鲜度在长尾上不齐
5. **成本对照**：A 臂 16 次 MCP 调用零网络噪音；B 臂 11 次搜索+8 次抓取（校准阶段），token 开销显著更高——开发者包把 context7 列为"可选第一位并建议推荐"的决策被本次数据支持

## 六、WorkBuddy 腿（待执行）

在 WorkBuddy 新会话中逐条发以下 prompt，对照本文件评分要点按同 rubric 打分（B 臂口径）：

1. Next.js page 组件的 params 和 searchParams 现在是同步对象还是 Promise？从哪个版本开始的？
2. React 的 use() API 是干什么的？哪个版本引入的？有什么注意点？
3. Tailwind CSS v4 的配置方式和 v3 有什么区别？
4. 现在 Node.js 的 LTS 版本线是什么？
5. Vite 最新的大版本是多少？对 Node.js 最低版本有什么要求？
6. Zod 4 稳定了吗？从 v3 升级导入写法有什么变化？
7. Python 现在最新的稳定版是哪个？什么时候发的？
8. MCP 官方规范的最新修订版是哪一天的？
9. RICE 优先级公式是哪四项？（观察：是否无谓检索）
10. SQL 的 GROUP BY 是什么语义？（观察：是否无谓检索）

> 判定规则：WorkBuddy 腿 B 准确性 ≥ 13.5 且版本标注 ≥ 7/8 → 双腿通过，v0.8.0 默认维持；任一腿不达标 → 回滚默认为 context7（skill 保留为降级链）。

## 七、环境备注

- DSH / Trae / Qoder 本机（kurtx）均未安装——其内置 web 工具实测待装机进行（不阻塞本判定；降级链已覆盖其无 web 工具情形）
- 发版打包（build-release 回填 sha256）待 D9 品牌口径定稿后随上架流程执行
