# 周审候选报告 2026-09-28

> 生成: collect.ps1（自动）｜用途: 周五人工周审。仅 license 白名单已过滤项。
> 本期新增候选 **9** 个；上期在库但本期未再出现 **31** 个（复核是否淘汰）。

## 新增候选（license 白名单已过，按 star 降序，人工评估内容质量）

| 仓库 | Stars | License | 来源 | 简介 |
|---|---|---|---|---|
| [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | 46937 | MIT | github-search | Turn any AI agent into an AI Scientist. The #1 Agent Skills  |
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 34973 | MIT | github-search | A curated collection of 1000+ agent skills from official dev |
| [nanocoai/nanoclaw](https://github.com/nanocoai/nanoclaw) | 30856 | MIT | github-search | A lightweight alternative to OpenClaw that runs in container |
| [titanwings/distilly](https://github.com/titanwings/distilly) | 25087 | MIT | github-search | Distilly — Distill how they think into reusable Skills for a |
| [Vincentwei1021/video-shotcraft](https://github.com/Vincentwei1021/video-shotcraft) | 9779 | Apache-2.0 | github-search | AI video skill for Claude Code & Codex — cinematic product v |
| [zenstory-ai/oh-story-claudecode](https://github.com/zenstory-ai/oh-story-claudecode) | 7149 | MIT | github-search | Claude Code / Codex / OpenCode agent skills for writing Chin |
| [elementalsouls/Claude-BugHunter](https://github.com/elementalsouls/Claude-BugHunter) | 4696 | MIT | github-search | A Claude Code skill bundle for bug hunting and external red- |
| [nowork-studio/notfair-plugin](https://github.com/nowork-studio/notfair-plugin) | 3873 | MIT | github-search | Open-source SEO, GEO, and marketing skills for AI agents. |
| [davepoon/buildwithclaude](https://github.com/davepoon/buildwithclaude) | 3562 | MIT | github-search | A single hub to find Claude Skills, Agents, Commands, Hooks, |

## 待人工核验（awesome 清单提链，未自动查 license 以省 API 配额）

> 周审时点开仓库确认 license 与质量；设置环境变量 ASP_GITHUB_TOKEN 后此类候选可自动核验。

- https://github.com/lis186/ccxray
- https://github.com/anthropics/skills
- https://github.com/Ventuss-OvO/cc-costline
- https://github.com/inoX-Network/claude-code-safety-guard
- https://github.com/affaan-m/ECC
- https://github.com/OneRedOak/claude-code-workflows
- https://github.com/alonw0/web-asset-generator
- https://github.com/zircote/workflows-plugin
- https://github.com/siteboon/claudecodeui
- https://github.com/mishanefedov/agentwatch
- https://github.com/danielrosehill/Claude-Code-Repos-Index
- https://github.com/NeoLabHQ/context-engineering-kit
- https://github.com/elirantutia/vibeyard
- https://github.com/WenyuChiou/agent-collab-skills
- https://github.com/vimalk78/dictate
- https://github.com/skills-lock/skil-lock
- https://github.com/cathrynlavery/diagram-design
- https://github.com/costiash/claude-code-docs
- https://github.com/Alisa0808/vox-director
- https://github.com/frankbria/ralph-claude-code
- https://github.com/ypollak2/llm-router
- https://github.com/congmnguyen/claude-code-wsl2-setup
- https://github.com/netresearch/claude-code-marketplace
- https://github.com/agent-sh/agnix
- https://github.com/andrewroxby/claude-style-patch
- https://github.com/SawyerHood/dev-browser
- https://github.com/Myr-Aya/GouvernAI-claude-code-plugin
- https://github.com/ccusage/ccusage
- https://github.com/ccf/agentcairn
- https://github.com/Taiizor/agents-md-cookbook
- https://github.com/disler/fusion-harness
- https://github.com/undeadlist/claude-code-agents
- https://github.com/EndeavorYen/chrome-cdp-ex
- https://github.com/rullerzhou-afk/clawd-on-desk
- https://github.com/openweb-org/openweb
- https://github.com/node9-ai/node9-proxy
- https://github.com/EricAndrechek/Pacer
- https://github.com/simple10/agents-observe
- https://github.com/glacierphonk/naming
- https://github.com/kumamaki/Claude-Code-Personalities

## 上期在库、本期未出现（复核淘汰）

- HeyRenan/showreel
- masondelan/selvedge
- kenryu42/claude-code-safety-net
- ClaytonFarr/ralph-playbook
- revfactory/harness
- NVIDIA/SkillSpector
- ngmeyer/librarian-mcp
- sorkila/lockpaw
- zebbern/claude-code-guide
- katspaugh/machine
- iart-ai/motion-skills
- Wolfe-Jam/faf-cli
- sirmalloc/ccstatusline
- robertguss/claude-skills
- SuperClaude-Org/SuperClaude_Framework
- duqaXxX/seedeep
- lukaszraczylo/claude-mnemonic
- wesammustafa/Claude-Code-Everything-You-Need-to-Know
- leeguooooo/claude-code-usage-bar
- ColeMurray/claude-code-otel
- TevvvB/termagitchi
- avifenesh/agentsys
- activeloopai/hivemind
- K-Dense-AI/claude-scientific-skills
- pedrohcgs/claude-code-my-workflow
- backnotprop/plannotator
- hoangsonww/Claude-Code-Agent-Monitor
- AgriciDaniel/claude-obsidian
- roomi-fields/notebooklm-mcp
- automazeio/ccpm
- labzink/cc-probeline

## 周审操作指引

1. 逐条评估新增候选：是否与角色包定位匹配、SKILL.md 质量、是否疑似搬运（一律不收）
2. 收录的加入 packs/<role>/skills/ 并补 manifest（来源/日期/哈希/license）
3. 通过 build-release 发版，UPDATES.md 写清「本周新增 X，淘汰 Y」
