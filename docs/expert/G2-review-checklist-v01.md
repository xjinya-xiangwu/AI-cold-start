# G2 专业真实性 · 独立复核清单 v0.1（专家环 R33 · 暂缓期可做）

> 状态：草案（专家规格 v0.1 §7 生命周期门 G2 的执行清单；复核人必须为**非贡献者**）。
> 用法：复核者逐项勾选并留档（含复核 id、日期、结论 pass/revise/reject）；暂缓期用合成专业卡演练本清单。

## A. 卡片自洽（逐卡）

- [ ] 1. 目标/质量标准（goal_standard）与判断/行动（judgment_action）指向同一任务族，无跨族漂移
- [ ] 2. 适用条件（conditions）具体到可复现：领域、输入、约束、风险边界至少四项中三项明确
- [ ] 3. 反例/例外（counter_examples / exceptions）至少一条且真实可信（无凑数）
- [ ] 4. 理由（rationale）解释了"为什么这样判断"，而非复述 action
- [ ] 5. 证据引用（evidence_ids）存在、可定位、且类型标注（real_task/expert_demo/expert_statement/agent_inferred/synthetic）与内容相符——推断/合成卡不得伪装真实任务

## B. 专业判断质量（复核者以自身专业经验对照）

- [ ] 6. 判断在同类任务上"我也会这么做"，或分歧有专业依据可写
- [ ] 7. 边界情况的行为可预测（不出现"按此卡执行会在明显场景出错"）
- [ ] 8. 与通行领域标准/规范无冲突；若有偏离，偏离本身被 conditions/rationale 显式声明

## C. 权利与隐私前置（与 G0/G1 衔接，发现问题退回 G0）

- [ ] 9. 卡内容不含：客户/雇主可识别信息、未授权第三方材料、密钥/凭证形态（跑 credential-lint 兜底）
- [ ] 10. 来源账本中该卡的 license 覆盖其目标用途（internal_distill / fusion / derivative_sale）

## D. 结论

- [ ] pass —— 卡进 eval_passed 候选（G3 评测）
- [ ] revise —— 按上述编号退回修改，重新走专家确认（expert_confirmed）
- [ ] reject —— 拒收并记录理由；卡保留在候选区不发布

复核记录字段：reviewer_id、reviewed_at、card_ids、逐项勾选快照、分歧说明。复核记录存受控区（knowledge/ 旁），不随净化包分发。
