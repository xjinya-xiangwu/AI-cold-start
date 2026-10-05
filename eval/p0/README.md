# eval/p0 — 装前/装后盲评（R02 / DST-P0-05）

> 维护者仓库内目录，**不随用户包发布**。规格：子模块 PRD · 分发层 v0.2 §4 DST-P0-05；指标口径：开发级 PRD v0.2 §8.2。
> 状态：骨架（2026-10-05）。任务内容与真机执行在 xujinya。

## 布局

```
eval/p0/
├── tasks/T1..T5/       # 每任务：input.md（任务输入）、rubric.md（评分锚）、fixtures/
├── runs/               # 每次 run 一个 <run_id>.json（IF-14 eval-run/1）
├── blind-sheet.csv     # 盲评表（表头固定，见下）
├── score.py            # 指标计算（stdlib）
└── README.md
```

## 流程（DST-P0-05）

1. 每任务 × 3 Agent × {pre, post}；pre 在未安装环境（干净用户目录或新 OS 用户），post 在仅装方法包、vault 为空的环境。
2. 每臂新会话、新工作区；评测控制按主 PRD §8.1 I4（登记模型版本/采样/工具权限/上下文预算）。
3. 产物匿名化后随机顺序填入 blind-sheet.csv；揭盲映射单独存放，评审完成后合并。
4. `score.py` 按 §8.2 计算：首用可采纳率 = directly_usable=是 的配对臂占比；相对提升 = (post−pre)/pre；pre=0 时只报百分点差。失败样本单列。

## blind-sheet.csv 表头

pair_id,task_id,agent_id,arm,sample_file,directly_usable,rework_rounds,skill_invoked,privacy_or_damage_issue,reviewer_id,notes

> 15 组配对样本是首轮产品门禁，不能据此宣称统计显著或一般化因果；商品页只可引用真实样本+条件+限制（D16/主 PRD §8.1）。
