# 可选 MCP 扩展（v0.7.0）

## 〇、默认包现状（v0.7.0 起）

默认只装 **1 个 MCP**：`asp-context7`（Context7 官方托管远程端点 `https://mcp.context7.com/mcp`）——零 key、零 node/npx 依赖、零冷启动、装完即验（`asp doctor` 可实测握手）。

**为什么 asp-memory / asp-sequential-thinking 从 v0.7.0 起默认不装**（2026-10-01 重构决策，背景见 UPDATES.md v0.7.0）：

| 原服务 | 默认移出的原因 |
|---|---|
| `asp-memory`（知识图谱记忆） | ① 2026 年主流 agent（Claude Code / ZCode / WorkBuddy / Cursor 等）均已有原生记忆或成熟第三方记忆方案，能力高度重叠；② MCP 官方明确定位为「参考实现、非生产级」；③ 其数据默认落在 npx 缓存目录内——npx 升级/清缓存会连带清掉你的记忆数据（数据安全隐患）；④ 实测存在 npx 并行安装竞态导致的启动崩溃案例 |
| `asp-sequential-thinking`（分步推理） | 2026 年模型已普遍内置 thinking/推理能力，该工具的增益难以实证；无状态、无数据风险，但默认安装属于负资产（注册了工具却从不被调用） |

如果你的 agent 确实没有自带记忆，或你想显式要这两件，按下面片段自行添加。

原则：**安装器永不收集你的 API key**。需要 key 的服务只给注册指引和配置片段，由你自己填入。

## 一、asp 三件套的剩余两件（按需添加）

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

## 二、零 key 但需要 Python/uvx 环境（未进默认包的原因）

| 服务 | 用途 | 运行要求 |
|---|---|---|
| `mcp-server-fetch`（官方） | 让 agent 抓网页内容做竞品/行业调研 | `uvx mcp-server-fetch`，需 uv |
| `mcp-server-sqlite`（官方） | 对本地 db 文件做数据分析查询 | `uvx mcp-server-sqlite --db-path <路径>`，需 uv |

有 uv 环境的用户可自行加入配置；未来版本会探测 uv 后自动提供。

## 三、需要注册 key 的高价值服务（自行注册，key 不经过安装器）

### Brave Search（联网搜索，PM 日常查资料刚需）

注册：https://brave.com/search/api/ （免费档每月 2000 次）

```json
"asp-brave-search": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-brave-search"],
  "env": { "BRAVE_API_KEY": "在这里填你自己的key" }
}
```

### GitHub（跟踪竞品仓库动向、读需求讨论 issue）

注册：https://github.com/settings/tokens （选 public repo 只读权限即可）

```json
"asp-github": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "在这里填你自己的token" }
}
```

### Notion（读写你的 Notion 工作区，需求池/文档同步）

注册：https://developers.notion.com/ 建内部集成，把页面授权给该集成

```json
"asp-notion": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@notionhq/notion-mcp-server"],
  "env": { "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer 你的token\", \"Notion-Version\": \"2022-06-28\"}" }
}
```

## 四、接入与验证

各 agent 的 MCP 配置位置见 README；把上面片段合并进对应配置文件（key 格式按各 agent 环境变量写法调整）。合并后重启 agent，然后运行 **`asp doctor`**——每条都会做真实握手，PASS 才算数。
