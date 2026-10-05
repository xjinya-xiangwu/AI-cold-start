# 来源账本 schema v0.1（rights-ledger，专家环 R34 · 暂缓期可做）

> 状态：草案（专家规格 v0.1 §6 数据契约的账本部分机器化；暂缓期用合成材料演练，不接收真实专家材料）。
> 目标：任一发布卡可一次查询定位 来源 → 许可 → 派生包 全链（E08 完整追溯）。
> 存储：维护者受控区（sources/ rights/ 独立存储，**不进公开仓库、不进用户安装包**）；本文件只是 schema。

## ledger.yaml（每专家一节或全局一表，暂缓期示例用合成 id）

```yaml
ledger_version: "0.1"
entries:
  - source_id: src_007            # 专家来源（= sources/src_007/）
    expert_alias: expert-A        # 署名按 D25 由专家选择，可匿名
    rights:
      - license_id: lic_007_v1
        contract_ref: rights/contracts/2026-XXX.doc   # 受控区路径，不入仓
        uses:                      # D25 用途分项，逐项勾选
          internal_distill: true   # 内部提炼
          fusion: false            # 跨专家融合（不勾选则只能单专家包）
          derivative_sale: true    # 衍生净化包销售
          redistribution: false    # 再分发/转授权（默认不授予）
          attribution: "anonymous" # named | anonymous
        training_allowed: false    # 默认不含训练/微调权
        valid_from: 2026-11-01
        valid_until: 2027-10-31    # 固定期限；期满续约或冻结新分发
        terminated_at: null
        backup_retention: "per contract §留存"
    cards:                         # 该来源产出的专业卡
      - card_id: ec_aipm_f2_0012
        evidence_ids: [ev_0041, ev_0042]
        derived_packages: [aipm-expert-0.1.0]
    status: active                 # active | expired | withdrawn
```

## 查询约定（实现为脚本或 SQL 均可，暂缓期先文件协议）

- 正向：source_id → 全部 card_id → 全部 derived_packages
- 反向（撤回用）：package_version → 依赖的全部 card_id → 全部 source_id/license_id → 冻结新分发 + 定位已售版本（E07）
- 权限校验（G0）：任何卡进 knowledge/ 生效集前，必须能在账本中解析到 license 且用途覆盖该卡目标（E01/E02）
- 时效：每次发版复核 valid_until 与 terminated_at；过期未续 → 相关卡降级为 frozen（E07）

## 演练验收（暂缓期，E01–E08 中与本账本直接相关的三条）

- E01 拒绝或部分授权：未勾选 fusion 的来源，其卡不能进入融合候选集（演练断言）
- E07 权限过期/撤回：改 terminated_at 后，查询能定位全部派生包并生成冻结清单
- E08 完整追溯：任一 released 卡沿账本回溯到 source/license/evidence/eval 记录，链路无断点
