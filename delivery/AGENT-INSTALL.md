# 交给 Agent 的安装 prompt

请安装我已下载并解压的冷启动包，绝对路径是【填写包目录】。先读取 用户手册.html、delivery-manifest.json，检测系统和工具并说明修改范围，问我确认。Windows 执行 powershell -NoProfile -ExecutionPolicy Bypass -File "【包目录】/install.ps1"，在本地选择页由我选择目标；macOS/Linux 执行 bash "【包目录】/install.sh"，先检查 python3。不要自行开通 AI 服务、联网下载其他软件、泄露订单/密钥或绕过公司策略。遇到用户同名内容冲突保留并报告。安装后验证技能落位、角色正文和备份，提醒我重启工具完成一次首用。如果没有本地终端权限，请给我等价命令，不要声称已经安装。链接每三天刷新，内容每月更新一次；下载新版包重跑相同入口，保留固定目录的历史状态与备份。
