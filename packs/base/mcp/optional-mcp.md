# 可选 MCP 扩展（v0.8.0）

## 〇、为什么默认零 MCP（v0.8.0 决策）

v0.8.0 起基础包**默认不装任何 MCP**：增强能力全部由 skills 承载——「文档新鲜度」由 **fresh-docs** skill 提供（指挥 agent 用内置 web 搜索/抓取工具查官方文档，带检索三步法与版本标注纪律），跨全部 10 个受支持 agent 零配置零故障面。

理由（2026-10-01 决策，详见 docs/DESIGN-ZERO-MCP.md 与 UPDATES.md v0.8.0）：
- skills 分发面是唯一在全部 agent 上验证可靠的部署面；MCP 配置面的可靠性因 agent 而异（有被证伪先例）
- 主流 agent 均自带 web 搜索/抓取，context7 的边际价值集中在"重度查文档的开发者"
- 默认装的 MCP 实证调用率≈0，属于过度供给；零 MCP = 零运行时依赖、零第三方端点依赖、零限流面

**什么时候值得加回 context7**：你是重度查库/框架文档的开发者，想要结构化、版本化的文档切片（比网页抓取更省 token、更降噪）。装法见下。

原则不变：**安装器永不收集你的 API key**。

## 〇·五、一键装（v0.10.0）：不用逐个挑——`asp mcp install`

一条命令把「常用三件」写入全部已检测 agent（merge 型自动合并、Codex 写托管块、手动型给出片段路径）：

```powershell
asp.ps1 mcp install      # 默认预设 essentials：context7 + memory + sequential-thinking（全零 key）
asp.ps1 mcp list         # 预设清单
asp.ps1 mcp remove       # 从全部 agent 移除 asp-* 托管条目（改前自动备份）
```

- **无 npx 环境自动降级**：npx 型服务跳过、远程型（context7）照装；装 Node.js 后重跑补齐
- **只新增不覆盖**：你自己配过的同名服务器一律跳过；装完 `asp doctor` 逐条验握手
- setup.bat 安装完会问一次「是否同时装常用 MCP」——一次选择，全 agent 生效，不再逐个挑
- 下文的手动片段仍适用于 key 类服务（brave/github/notion 等，永不经过安装器）

## 一、推荐可选：asp-context7（文档检索增强，远程零依赖）

官方托管远程端点，无需 node/npx。已装 fresh-docs 的 agent 会在检测到它时自动优先使用（降级链第一档）。

```json
"asp-context7": {
  "type": "http",
  "url": "https://mcp.context7.com/mcp"
}
```

- Cursor 写法（remote 格式不同构）：`"asp-context7": { "url": "https://mcp.context7.com/mcp" }`
- opencode 写法：`"asp-context7": { "type": "remote", "url": "https://mcp.context7.com/mcp" }`
- Codex（config.toml）：

```toml
[mcp_servers.asp-context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
```

**限流提示**：无 key 可用但限额低；免费 key 一分钟申请——context7.com/dashboard，拿到后加 header `"CONTEXT7_API_KEY": "<你的key>"`（或 env）。

**装完验证**：`asp doctor`——对它做真实 initialize 握手，PASS 才算装好。

各 agent 的 MCP 配置文件位置见 README「支持的 agent」表。

## 二、asp-memory / asp-sequential-thinking（按需，v0.7.0 起默认不装）

### asp-memory（仅当你的 agent 无原生记忆时）

```json
"asp-memory": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "env": { "MEMORY_FILE_PATH": "~/.asp/data/memory.json" }
}
```

⚠ 必须显式设置 `MEMORY_FILE_PATH`：不设时数据落在 npx 缓存目录内，npx 更新/清理即丢数据。
⚠ Windows 提示：宿主若报 spawn EINVAL/找不到 npx，把 command 改为 `cmd`、args 前面加 `["/d", "/s", "/c", "npx", ...]`。

### asp-sequential-thinking

```json
"asp-sequential-thinking": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
  "env": {}
}
```

2026 年模型已普遍内置 thinking，增益有限；无状态无数据风险。

## 三、零 key 但需要 Python/uvx 环境

| 服务 | 用途 | 运行要求 |
|---|---|---|
| `mcp-server-fetch`（官方） | 抓网页内容做调研 | `uvx mcp-server-fetch`，需 uv |
| `mcp-server-sqlite`（官方） | 本地 db 查询分析 | `uvx mcp-server-sqlite --db-path <路径>`，需 uv |

## 四、需要注册 key 的高价值服务（自行注册，key 不经过安装器）

### Brave Search（联网搜索）

注册：https://brave.com/search/api/ （免费档每月 2000 次）

```json
"asp-brave-search": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-brave-search"],
  "env": { "BRAVE_API_KEY": "在这里填你自己的key" }
}
```

### GitHub（跟踪竞品仓库、读 issue 讨论）

注册：https://github.com/settings/tokens （public repo 只读即可）

```json
"asp-github": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "在这里填你自己的token" }
}
```

### Notion（读写 Notion 工作区）

注册：https://developers.notion.com/ 建内部集成并授权页面

```json
"asp-notion": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@notionhq/notion-mcp-server"],
  "env": { "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer 你的token\", \"Notion-Version\": \"2022-06-28\"}" }
}
```

## 五、接入与验证

把片段合并进对应 agent 的配置文件（key 格式按各 agent 环境变量写法调整），重启 agent，然后运行 **`asp doctor`** 逐条实测握手——PASS 才算数。

### 排障：npx 型服务 FAIL 报 `ERR_MODULE_NOT_FOUND ... zod`

npx 缓存损坏（历史版本残留）所致，与配置无关。清掉损坏的缓存条目后重试：

```powershell
Remove-Item "$env:LOCALAPPDATA\npm-cache\_npx\*" -Recurse -Force
```

（2026-10-01 实测：清缓存后 memory 0.6.3 / sequential-thinking 2026.8.31 全部握手 PASS。）
