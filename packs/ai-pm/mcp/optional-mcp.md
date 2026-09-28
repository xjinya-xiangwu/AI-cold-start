# 可选 MCP 扩展（ai-pm 包）

默认安装的 3 个 MCP（context7 / memory / sequential-thinking）全部**零 key、npx 直接运行**。本文件列出值得按需追加的服务器，以及为什么没有放进默认包。

原则：**安装器永不收集你的 API key**。需要 key 的服务只给注册指引和配置片段，由你自己填入。

## 一、零 key 但需要 Python/uvx 环境（未进默认包的原因）

| 服务 | 用途 | 运行要求 |
|---|---|---|
| `mcp-server-fetch`（官方） | 让 agent 抓网页内容做竞品/行业调研 | `uvx mcp-server-fetch`，需 uv |
| `mcp-server-sqlite`（官方） | 对本地 db 文件做数据分析查询 | `uvx mcp-server-sqlite --db-path <路径>`，需 uv |

有 uv 环境的用户可自行加入配置；未来版本会探测 uv 后自动提供。

## 二、需要注册 key 的高价值服务（自行注册，key 不经过安装器）

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

## 三、接入方法

各 agent 的 MCP 配置位置见 README；把上面片段合并进对应配置文件（key 格式按各 agent 环境变量写法调整）。合并后重启 agent 生效。

## 安全提醒

- 只从官方 npm 包名安装；第三方实现的 server 谨慎评估
- key 只写进本机配置文件，不要提交到任何仓库
- 不再使用时删除对应条目并吊销 key
