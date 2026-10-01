work-tools —— 办公工具集（5 件，全部产品官方 MCP）
asp-figma（Figma 官方·本地端点）· asp-notion（Notion 官方远程）· asp-atlassian（Atlassian 官方远程：Jira/Confluence）· asp-linear（Linear 官方远程）· asp-mslearn（Microsoft Learn 官方·公开免鉴权）

来源与鉴权说明（全部官方，零自建；安装器不存任何 key）：
- asp-figma：Figma 官方 Dev Mode MCP，端点 http://127.0.0.1:3845/mcp——需 Figma 桌面客户端运行且在偏好设置开启「Dev Mode MCP Server」，客户端关了即离线
- asp-notion / asp-atlassian / asp-linear：官方远程端点（mcp.notion.com / mcp.atlassian.com / mcp.linear.app），**OAuth 鉴权**——配置不含任何密钥，首次连接时在 agent 内弹登录授权即可
- asp-mslearn：Microsoft 官方公开端点（learn.microsoft.com/api/mcp），无需鉴权
- 未收录（诚实声明）：draw.io 与 Axure **无官方 MCP**（drawio 画图需求由包内 mermaid-diagrams skill 覆盖）；Office 桌面套件暂无可用的官方独立 MCP（微软官方 MCP 仍在推进，GA 后收录；社区版见 optional-mcp.md）；GitHub 官方远程需 PAT，见 optional-mcp.md 手动片段
