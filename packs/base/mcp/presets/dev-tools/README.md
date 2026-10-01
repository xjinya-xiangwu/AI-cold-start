dev-tools —— 开发者工具集（3 件，全部官方出品）
asp-playwright（Microsoft 官方 playwright-mcp，浏览器自动化，本地零 key）· asp-filesystem（MCP 官方 server-filesystem，文件读写，默认授权 ~/Documents）· asp-supabase（Supabase 官方远程，OAuth 首连授权）

来源与安全说明（零自建；安装器不存任何 key）：
- asp-playwright：@playwright/mcp（github.com/microsoft/playwright-mcp，Microsoft 官方 npm 包，需 npx）
- asp-filesystem：@modelcontextprotocol/server-filesystem（MCP 官方 monorepo，需 npx）；**默认只授权 ~/Documents 目录**——想改授权范围：装后把配置里 args 的目录替换成你要的路径（支持多个目录参数）
- asp-supabase：官方远程端点 mcp.supabase.com/mcp，OAuth 鉴权（首次连接在 agent 内登录，配置不含密钥）
