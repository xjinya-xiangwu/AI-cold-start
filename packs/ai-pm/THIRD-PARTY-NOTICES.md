# Third-Party Notices（ai-pm 包）

本包大部分 skills 为自产原创内容。以下 skill 基于开源许可项目的思想与结构改造（中文化重写 + 与本包体系融合），依据原许可协议声明出处：

## product-reporting（采集改造）

- 来源 1：anthropics/knowledge-work-plugins — `operations/skills/status-report`，Apache License 2.0
  https://github.com/anthropics/knowledge-work-plugins
- 来源 2：janellecipriano/pm-skills — `skills/status-report`、`skills/exec-summary`，MIT License
  https://github.com/janellecipriano/pm-skills

## post-mortem（采集改造）

- 来源 1：janellecipriano/pm-skills — `skills/postmortem`、`skills/retrospective`，MIT License
  https://github.com/janellecipriano/pm-skills
- 来源 2：riekelt/technical-writer — `plugins/technical-writer/skills/writing-postmortems`，MIT License
  https://github.com/riekelt/technical-writer
- 来源 3：wshobson/agents — `plugins/incident-response/skills/postmortem-writing`，MIT License
  https://github.com/wshobson/agents

## 说明

- Apache-2.0 / MIT 均允许商业使用与修改再分发，条件是保留版权与许可声明（本文件即该声明）。
- 改造方式：原文英文 → 中文重写，提取工作流与纪律要点，与本包其他 skills（data-insight、launch-readiness、bug-triage 等）交叉衔接；未逐字搬运原文。
- mermaid-diagrams、bug-triage、feedback-triage 为自产；spillwavesolutions/design-doc-mermaid 等无 license 仓库仅作思路参考，未搬运任何内容。
- License 红线（品牌纪律，永不采集）：deanpeters/Product-Manager-Skills = CC BY-NC-SA 4.0（非商业）。
