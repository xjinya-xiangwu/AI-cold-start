# 智能体冷启动包使用说明

版本 v0.14.2｜2026-10-13｜售后微信 xjinya。

本包把技能、角色工作流与即用指令部署到已有 AI 工具；不含 AI 账号、会员或模型额度。基础包 ¥20：25技能/11指令；AI产品经理方向加购 +¥10，完整包 ¥30：37技能/42指令。

## 新订单安装

订单ZIP根有 用户手册.html、安装命令.txt、AGENT-INSTALL.md 与按系统区分的入口。先完整解压。

- Windows：双击 install-windows.bat，在本地页选择工具/技能后执行；命令行 powershell -NoProfile -ExecutionPolicy Bypass -File ./install.ps1 -Cli。
- macOS：双击 install-macos.command，或 bash ./install.sh；需要 bash/python3。
- Linux：bash ./install-linux.sh 或 bash ./install.sh。
- Agent：复制 AGENT-INSTALL.md，填绝对路径；没有本地权限的Agent只能提供命令，不能代装。

安装后检查报告，重启工具并试一次技能。Windows稳定目录 %USERPROFILE%/asp-coldstart/app-已购SKU；Unix ~/asp-coldstart/app-已购SKU。备份与技能状态跨月版本保留；同名自定义内容保留并提示冲突。

## 两种独立更新节奏

**每3天刷新下载链接；每月更新一次技能内容。**卖家在群通知或私信提供领取链接；过期索取最新链接。刷新链接不强制下载，也不让已有安装失效。新月内容下载ZIP重跑相同入口；默认不装本机自动任务。默认链接有效96小时，72小时轮换留一天重叠。

## 支持与限制

Windows引擎文件落位已回归；真实客户端加载仍需首用验收。Trae/Qoder仅迁移，不宣称完整技能安装；ZCode/OpenCode角色层需项目AGENTS.md。Mac/Linux命令入口和哈希工具兼容已提供，原生真机仍须验收。默认零MCP/安装器不收API key，不等于模型服务免费。

## 权益 售后及许可

购买含90天月度更新；到期仍可使用已下载版本，不默认删除。退款和售后条件由商品页购买前明示；不擅自更改原合同。开源派生技能遵循包内 licenses/，不得以本包商业条款削减MIT/Apache原有权利。截图遮挡订单凭证、密钥和私人路径。

旧版ZIP的setup.bat仍提供本地UI；旧token通道只是兼容，不适用新的订单ZIP动线。完整运营说明见 docs/ops/FULFILLMENT.md。
