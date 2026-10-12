# 交付形态 v2：一段安装代码 + UI 选择式分布式安装

> 2026-09-30 定稿方向 · 关联：ANTI-RESALE.md（防转卖策略，本文档替代其"zip 主交付"假设）、HOSTING.md（registry 托管）
> 决策：**放弃 zip 作为主交付物**（本地文件形态转卖防不住）；改为电商交付一段安装代码，运行时按订单拉取内容，UI 选择后一键安装。

## 一、形态对比

| | v1（现状） | **v2（定稿方向）** |
|---|---|---|
| 电商交付物 | zip 文件（自动发货发链接） | **一段安装代码文本** |
| 内容获取 | zip 内置离线快照 | 运行时经**按订单签名 URL**（7 天过期）拉取 |
| 安装交互 | 自动探测全装 | **UI 选择页**：环境 × 内容包自选 → 一键执行 |
| 转卖防护 | 防不住（转的就是 zip） | **转卖=转卖订单 token**：可检测、可断供、可溯源 |
| 更新 | update.bat | **重跑同一条命令** |
| 离线能力 | 有（快照内置） | 无 → 保留 zip 绿色版作私域售后兜底 |

## 二、安装代码形态

```
Windows（PowerShell 5.1+ 系统自带，零依赖不变）:
irm https://asp.<域名>/i/<orderToken> | iex

macOS / Linux:
curl -fsSL https://asp.<域名>/i/<orderToken> | sh
```

**token 与链接的生命周期（关键设计）**：
- `<orderToken>` = 订单永久凭证（下单时生成：订单号 + HMAC），**用户手里的命令不变**——避免每周给用户发新代码的摩擦
- 服务端每周发版时按订单表批量生成**当周签名 URL**（OSS 签名参数，7 天 TTL）——"每单每周一个专属链接、7 天过期"落在这一层
- 用户重跑命令 → token 解析 → 当周签名 URL → 拿到最新内容；订阅到期 → 提示续费（续更 9.9/季）
- 转卖者只能给别人自己的 token：**同 token 多 IP/高频拉取告警 → 断供该 token**，正版用户不受影响

## 三、UI 选择页（本地 Web UI 优先 + TUI 兜底）

**为什么本地 UI**：选择动作在用户机器上完成（探测 agent、写文件都需要本地执行）；托管网页无权碰本地盘。采用"bootstrap 启动 localhost 页面 + 自动开浏览器"模式。

```
用户执行安装代码
  ↓ ① bootstrap（极小脚本，不含内容）：拉当周 manifest → 探测本机 agent
  ↓ ② 启动本地服务 localhost:<port> + 打开浏览器（无浏览器环境 → 终端 TUI 菜单兜底）
  ↓ ③ UI 三步流：
     Step1 环境选择：探测到的 agent 卡片（ZCode/Claude Code/Codex/Cursor…勾选部署目标）
                     未检测到的 → 官网引导链接（不替装，维持现有边界）
     Step2 内容包选择：base ¥10 / ai-pm ¥19.9 /（未来 domain-pack）卡片
                       说明 + skills 数 + 依赖关系（选 ai-pm 自动勾 base）
     Step3 一键执行：签名 URL 下载 → sha256 校验 → 部署到勾选环境
                     （复用 asp 引擎：adapters / _backup 回滚 / 幂等托管块）
                     → 实时进度 → 安装报告（EULA 与分销条款入口 / update 提示）
  ↓ ④ 重跑同一条命令 = 安装 = 更新（检测已装内容 → 增量）
```

**技术要点**：
- PowerShell `HttpListener` 起本地页（PS 5.1 可用，注意 UTF-8/BOM 编码坑——见 README 开发坑#1）；页面单文件 HTML 内嵌于 bootstrap 或按周拉取
- 现有 `asp.ps1` **降级为部署引擎**（被 bootstrap 调用），adapters/幂等/回滚逻辑复用率约 80%，不重写
- agent 探测逻辑前置到 bootstrap（UI Step1 数据源）

## 三·五、更新触达三形态（用户不需要"记得每周跑命令"）

| 档 | 形态 | 用户动作 | 定位 |
|---|---|---|---|
| **L2 自动（推荐引导）** | 安装完成页勾选项"每周自动更新"（**默认关**，知情同意后注册 Win 计划任务 / mac launchd，每周静默拉取，失败才通知） | 零动作 | 主路径：勾一次终身无感；续更（9.9/季）卖的就是这个体验 |
| **L1 推送触达** | 每周发版后更新群通知（"本周新增 X、淘汰 Y"）→ 用户点收藏命令/桌面快捷方式 | 10 秒 | 未勾自动的用户拉回通道 |
| **L0 手动重跑（兜底）** | 重跑同一条命令（安装报告明示"更新=重跑这段代码"） | 30 秒 | 任何场景可用 |

**边界澄清**：7 天过期的是服务端签名 URL（防转存），用户 token 永久有效——三周没更新的人重跑一次即增量跳到最新版（版本对比，不补中间版本），不跑不断更、只是内容旧。L2 计划任务只做一件事（对比版本拉更新），商品页明说，守住"零后门"信任叙事。

## 四、服务端组件（零服务器起步）

| 组件 | v0 实现（零服务器） | 规模化后 |
|---|---|---|
| token 校验 | OSS 静态：`/i/<token>` 为极小引导脚本（按订单生成、发版脚本批量产出），签名 URL 内嵌 | 函数计算动态签发 |
| 当周签名 URL | build-release 发版时读订单表批量生成（7 天 TTL） | 同 + 自动续签 |
| 异常监控 | OSS 访问日志 → 周审脚本扫同 token 多 IP/高频 | 实时告警 + 自动断供 |
| 订单表 | Excel/腾讯表格 | 轻量 DB |

## 五、迁移与排期

- **v0.6（先做，兼容现有 zip 流程）**：index.json 加 `period` 字段 + update 过期提示（原计划不变）
- **v1.0（主形态切换）**：bootstrap + 本地 UI + token/签名 URL + 电商文本发货——工程量约 **2-3 天**（bootstrap+UI 1.5 天、服务端签名与订单脚本 1 天、双端实测 0.5 天）
- zip 绿色版降级为私域售后兜底（弱网/内网用户按单发），不再是电商主交付
- lite 版（GitHub 免费）不受影响，继续承担引流

## 六、风险与对策

| 风险 | 对策 |
|---|---|
| 远程脚本信任疑虑（"这条代码安全吗"） | 安装代码开源可审计 + 固定专属域名 + 商品页逐行解释这条命令做什么；这是 npx/irm 生态的通行模式 |
| PS 5.1 HttpListener 编码/兼容坑 | UTF-8 声明 + BOM 自检沿用；TUI 兜底路径必测 |
| 无浏览器/纯终端用户 | TUI 菜单兜底（功能等价：编号多选） |
| 离线/内网场景 | 绿色版 zip 私域兜底 |
| token 泄露误伤（家庭多设备/公司内网多 IP） | 阈值宽松（如 >5 IP/日）+ 断供前先告警提示，不误杀 |
| 电商平台文本发货 | 闲鱼/淘宝自动发货均支持文本 ✅ |

---

## 实施记录 v1.0（2026-10-12，纯静态 token 方案）

> 按最小可行原则（karpathy：最简单能跑通的方案），v2 的服务端查表+签名用**纯 OSS 静态文件**等价实现，零计算、零新账号组件。

**实现形态**：订单购买后，维护者运行 `scripts/gen-order-tokens.ps1`——按 `registry/orders.csv`（token,sku,note；不入库）为每单生成 `i/<token>.ps1` / `i/<token>.sh` 上传至 OSS。买家命令 `irm <oss>/i/<token>.ps1 | iex` 拉取的 bootstrap 内嵌**本周 presigned URL**（7 天 TTL）+ 对应包的 sha256；下载→校验→解压→调 asp 引擎安装→在 `%USERPROFILE%\asp-coldstart\` 写 `update-token.bat`（内容=重跑同一条 token 命令）。

**与原设计的映射**：

| 原设计 | 纯静态实现 |
|---|---|
| 服务端订单表 + token 解析 | token 文件路径本身=凭证（不可猜 URL）；`i/<token>.*` 存在即有效 |
| 每周按订单批量签 URL | 每周重跑 gen-order-tokens.ps1 覆写全部 token 文件（幂等） |
| 转卖=转卖 token，可断供 | `-Revoke <token>` 删除 i/<token>.* → 买家命令 404（已实测） |
| 多 IP/高频告警 | 暂以 OSS 访问日志人工核查；自动化分析后置 |

**买家命令**（Win）：`irm https://asp-registry-xjinya.oss-cn-hangzhou.aliyuncs.com/i/<token>.ps1 | iex`；Mac/Linux：`curl -fsSL .../i/<token>.sh | bash`。重跑=更新（bootstrap 每周重签后内容随新版本走）。

**验收记录（2026-10-12，kurtx 沙箱）**：①presigned URL 实际下载+sha256 校验通过（E2E 内含）；②base token 全新沙箱 `irm|iex` → 25 skills、托管块=1、原文保留、update-token.bat 含本 token；③幂等重跑 exit 0；④ai-pm token → 37 skills（含 prd-drafting）；⑤`-Revoke` 后 token URL 404。已知边界：.sh 通道已生成未在真机 E2E（Windows 开发机）；SKU 只有 base/ai-pm 两档（后续方向包在 orders.csv 的 sku 列扩展）。

**运营 SOP**：新订单 → orders.csv 加行 → `gen-order-tokens.ps1 -Only <token>`；每周发版 → build-release 后重跑全量签发（presign 指向新版本）；退款/转卖 → `-Revoke <token>`。
