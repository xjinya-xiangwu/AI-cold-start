# 小红书 淘宝 拼多多订单交付运行手册

## 交付契约

已付款且 SKU 经卖家确认的订单 → 一单一 ZIP → 私有 OSS 托管 → 私有发货结果 → 卖家发群或私信。ZIP 包含 用户手册.html、安装命令.txt、Agent 安装 prompt、Windows 双击/CLI 入口、macOS/Linux 入口及已购技能。默认不在本机安装自动更新任务。

**下载链接每 72 小时刷新，内容每月更新一次。**签名 URL 有效 96 小时，保留 24 小时重叠；三天轮换不是立刻让旧链接作废。退款会停发链接并删除订单包，不能撤回已下载文件。原购买版本保留，90 天更新权益结束后不获得新内容，但仍可领取原版本。

一单专属链接不可贴公开群；如群含多个购买者，应逐单私信。公共群通知可以只发“新版本已发布，请领取”，不要泄露别人的订单链接。需要统一群领取页时再建设登录/权益校验服务。

## 当前实现与未接通部分

已实现源代码与本地测试：支付标识门禁、三平台命名、平台+订单号幂等、私有 OSS 写入签名、订单包隔离、72小时刷新、月版快照、退款状态、发货待发送/已发送回执。

**未上线：**三平台原生支付接口、商家 OAuth、云端运行环境、生产 OSS 权限验证、平台消息自动发送。没有这些凭据，不把代码模板等同于真实付款自动发货。

## 先用人工确认订单 CSV

从三个店铺核对已支付单，转换成 docs/ops/orders.example.csv 的统一列：platform/order_id/sku/payment_status。SKU 为 base 或 ai-pm；仅 payment_status=paid 可以发货。CSV 为私有运营文件，不提交 GitHub。EXAMPLE 记录不可直接执行。

运行（需要 Python 3.9+，以下命令在发行仓库根）：

    python delivery/fulfillment.py --store local --output ops-private/results.json issue --platform xiaohongshu --order YOUR_ORDER --sku base --confirmed-paid
    python delivery/fulfillment.py --store local import-csv ops-private/orders.csv --confirmed-paid

local 是测试模式，输出 local-fixture.invalid，不是能发给买家的真实下载链接。仅用于演练。

## 启用私有 OSS

使用独立私有 Bucket 或严格私有对象前缀，最小权限 RAM 身份。运行环境注入 ASP_FULFILLMENT_BUCKET、ASP_OSS_ENDPOINT、ASP_OSS_AK、ASP_OSS_SK；密钥不进源码、不进订单包、不进输出。

    python delivery/fulfillment.py --store oss --output ops-private/results.json issue --platform taobao --order YOUR_ORDER --sku ai-pm --confirmed-paid
    python delivery/fulfillment.py --store oss refresh
    python delivery/fulfillment.py --store oss pending
    python delivery/fulfillment.py --store oss mark-sent --reference HASHED_REFERENCE --receipt PLATFORM_MESSAGE_RECEIPT --revision CURRENT_LINK_REVISION
    python delivery/fulfillment.py --store oss revoke --platform pinduoduo --order YOUR_ORDER

所有订单状态、内容快照、订单 ZIP 均写 private/fulfillment/，显式 private ACL。首次使用前：新建测试单，匿名 GET ZIP 必须403，签名GET必须200，校验 ZIP 哈希，下载后的首次安装/重装/退款删除均验收。签名URL本身是持有者凭证，禁止公开。

服务使用 x-oss-forbid-overwrite 全局写锁：避免订单事件与刷新丢更新。不会擅自抢占过期锁；云任务崩溃留下锁时需要管理员确认无运行任务后手工清理 write.lock。当前适合低量串行运营；规模扩大用数据库事务/队列而不是无限扩展单JSON。

## 三天自动换链与月度发行

将 docs/ops/private-fulfillment.workflow.yml 放进**私有运营仓库**的 .github/workflows，配置最小权限 secrets。模板每天运行，持久化状态判断哪单已满72小时；若需要严格到分钟，使用可靠云调度器每小时运行同一 refresh 命令。GitHub schedule 可能延迟，不承诺精确时间SLA。结果仅存私有 artifact，由你群通知/逐单私信；默认不自动发平台消息。

月度审查内容并用新的版号：

    python delivery/fulfillment.py --store oss publish --version v0.15.0

月度内容发布要人工批准，不能定时把未审查的源码当成新技能。已发布版本不可重用；服务保存当时的内容快照，后续订单不从变动中的源码重新生成同版号内容。刷新会升级权益仍有效的订单，并将待发送清单写私有结果。内容月更与下载三天换链是两条独立节奏。

## 原生订单自动接入

delivery/server.py 是**已验证商家桥接事件**接口，不接受原生三平台未验签回调。适配器须先使用各平台批准的 API/OAuth 验签并复查“确已付款”，再传统一事件：

    {"event":"paid","platform":"xiaohongshu","order_id":"PLATFORM_ORDER","sku":"base","payment_status":"paid"}

请求 POST /v1/merchant-events；X-ASP-Timestamp 为Unix秒；X-ASP-Signature 为 HMAC-SHA256(secret,timestamp + '.' + raw_body)，5分钟时间窗。32字符以上专用密钥只给可信适配器；放在 HTTPS 网关后，做限流、鉴权、回调重试与审计，不能直接暴露开发 http.server。

退款事件 event=refund，以相同 platform/order_id 撤销。重复支付回调复用同单，不新建。小红书/淘宝/拼多多的原生接口结构与授权不同，当前没有猜造平台 API 字段，也没有浏览器绕过。

部署前补：三店铺应用授权/店铺 ID、商品→SKU 映射、正式事件或订单查询接口、平台允许的消息发货渠道、真实测试订单。先完成这些再宣称支付即全自动发货。

## 历史公开与旧 token

公开仓库和旧公开包不具备内容保密，新增私有订单包只能保护新的领取入口，不能撤销历史传播。旧 gen-order-tokens 为兼容路径，非新动线。新路径不需要每3天重新下发安装命令，而是生成新的 ZIP 下载URL；本地已经安装的包不因URL过期失效。

禁止在公开 Actions summary/log 输出下载凭证或用户昵称。旧 workflow 已加入 private-only 条件及环境变量传参，但不会在公开仓库激活。
