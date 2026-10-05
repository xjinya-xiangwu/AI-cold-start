#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""validate-cards.py — 经验卡 T13 夹具校验器（PRD v0.2 §5.4 / 评审意见 B1 完成标准）

判定（与 PRD §5.4 夹具判定逐条对应，每张卡输出唯一结果）:
  有效卡           -> accepted
  缺必填字段       -> rejected（报字段）
  坏枚举           -> rejected
  冲突卡           -> conflict（status 必须为 pending + conflict_with）
  14 天未确认      -> expired（-> rejected）
  敏感形态命中     -> blocked_sensitive（不生成卡，只记审计事件）
  v0.1 旧卡        -> legacy（返回按迁移表升级后的 1.0 卡）
用法:
  python validate-cards.py <卡.yaml> [<卡.yaml> ...]      # 逐卡判定（YAML 用内置轻量解析，不依赖 PyYAML）
  python validate-cards.py --pair a.yaml b.yaml          # 两卡对照: synonym（同义同范围->merged）/ conflict（->pending+conflict_with）
结果以 JSON 行输出: {"file":..., "id":..., "result":..., "errors":[...], "migrated":{...}?}
局限: 轻量 YAML 解析只支持单层缩进的平面映射与一维列表（夹具即此形态）；生产提交器用完整 YAML 库。
"""
import json
import re
import sys
from datetime import datetime, timedelta, timezone

SCHEMA_VERSION = "1.0"
REQUIRED = ["schema_version", "id", "revision", "type", "status", "scope", "action", "evidence", "created_at", "updated_at"]
ENUMS = {
    "type": {"correction", "preference", "prohibition", "fact", "case"},
    "status": {"candidate", "pending", "active", "merged", "retired", "rejected"},
    "source": {"command", "in_session", "post_session", "edit_diff", "import", "memory_import"},
    "mode": {"explicit_command", "review_confirm", "review_default", "user_edit", "legacy"},
    "scope_type": {"global", "task_type", "project", "skill"},
}
SENSITIVE_RX = re.compile(
    r"(sk-[A-Za-z0-9_-]{16,}|sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"
    r"|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|glpat-[A-Za-z0-9_-]{16,}|AIza[0-9A-Za-z_-]{30,}"
    r"|-----BEGIN (RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"
    r"|(?i:api[_-]?key|access[_-]?token|client[_-]?secret|password)\"?\s*[:=]\s*[\"']?[A-Za-z0-9_\-/+=]{20,})"
)
ISO_RX = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$")
ID_RX = re.compile(r"^rule_[0-9]{8}_[a-f0-9]{4,8}$")

# v0.1 -> 1.0 迁移表（PRD §5.4 挂"迁移表"节；本表为机器实现，中文枚举按评审版 B1 描述映射）
V01_STATUS_MAP = {"生效": "active", "待确认": "pending", "冲突待确认": "pending", "已合并": "merged", "废弃": "retired", "拒收": "rejected"}
V01_TYPE_MAP = {"纠错": "correction", "偏好": "preference", "禁忌": "prohibition", "事实": "fact", "案例": "case"}


def _clean(s):
    return s.strip().strip("'\"")


def parse_flat_yaml(text):
    """轻量解析（支持：顶层标量、一层嵌套映射、一层列表、列表项内一层子映射——夹具即此形态）。"""
    data = {}
    lines = [l.rstrip("\n") for l in text.splitlines() if l.strip() and not l.lstrip().startswith("#")]
    i, n = 0, len(lines)
    while i < n:
        raw = lines[i]
        ind = len(raw) - len(raw.lstrip())
        line = raw.strip()
        if ind != 0 or ":" not in line:
            i += 1
            continue
        k, _, v = line.partition(":")
        k = k.strip()
        v = _clean(v)
        if v:
            data[k] = v
            i += 1
            continue
        i += 1
        if i >= n:
            data[k] = []
            continue
        nraw = lines[i]
        nind = len(nraw) - len(nraw.lstrip())
        nline = nraw.strip()
        if nind > 0 and nline.startswith("- "):
            items = []
            while i < n:
                raw2 = lines[i]
                ind2 = len(raw2) - len(raw2.lstrip())
                l2 = raw2.strip()
                if ind2 == 0 or not l2.startswith("- "):
                    break
                item = l2[2:].strip()
                if ":" in item:
                    m = {}
                    k2, _, v2 = item.partition(":")
                    m[_clean(k2)] = _clean(v2)
                    i += 1
                    while i < n:
                        raw3 = lines[i]
                        ind3 = len(raw3) - len(raw3.lstrip())
                        l3 = raw3.strip()
                        if ind3 > ind2 and not l3.startswith("- ") and ":" in l3:
                            k3, _, v3 = l3.partition(":")
                            m[_clean(k3)] = _clean(v3)
                            i += 1
                        else:
                            break
                    items.append(m)
                else:
                    items.append(_clean(item))
                    i += 1
            data[k] = items
        elif nind > 0 and ":" in nline:
            m = {}
            while i < n:
                raw2 = lines[i]
                ind2 = len(raw2) - len(raw2.lstrip())
                l2 = raw2.strip()
                if ind2 == 0 or l2.startswith("- ") or ":" not in l2:
                    break
                k2, _, v2 = l2.partition(":")
                m[_clean(k2)] = _clean(v2)
                i += 1
            data[k] = m
        else:
            data[k] = []
    # 归一化: "[]" -> []，"null" -> None
    for k in list(data.keys()):
        if isinstance(data[k], str):
            if data[k].strip() == "[]":
                data[k] = []
            elif data[k].lower() == "null":
                data[k] = None
    return data


def norm_action(s):
    return re.sub(r"[\s，,。;；!！？?]+", "", (s or "").lower())


def card_errors(card, now):
    errs = []
    for f in REQUIRED:
        if f not in card or card[f] in (None, "", []):
            errs.append("missing:" + f)
    if errs:
        return errs
    if card["schema_version"] != SCHEMA_VERSION:
        errs.append("bad:schema_version")
    if not ID_RX.match(str(card["id"])):
        errs.append("bad:id")
    if not isinstance(card["revision"], int) or card["revision"] < 1:
        errs.append("bad:revision")
    if card["type"] not in ENUMS["type"]:
        errs.append("bad:type")
    if card["status"] not in ENUMS["status"]:
        errs.append("bad:status")
    sc = card.get("scope") or {}
    if not isinstance(sc, dict) or sc.get("scope_type") not in ENUMS["scope_type"]:
        errs.append("bad:scope.scope_type")
    else:
        st = sc["scope_type"]
        if st == "task_type" and not sc.get("task_type"):
            errs.append("missing:scope.task_type")
        if st == "project" and not sc.get("project_id"):
            errs.append("missing:scope.project_id")
        if st == "skill" and not sc.get("skill_id"):
            errs.append("missing:scope.skill_id")
    ev = card.get("evidence") or []
    if not isinstance(ev, list) or len(ev) == 0:
        errs.append("missing:evidence")
    else:
        for e in ev:
            if not isinstance(e, dict) or e.get("source") not in ENUMS["source"]:
                errs.append("bad:evidence.source")
    if card.get("conflict_with") and card["status"] != "pending":
        errs.append("conflict_requires_pending")
    if card["status"] == "merged" and not card.get("merged_into"):
        errs.append("missing:merged_into")
    for tf in ("created_at", "updated_at"):
        if not ISO_RX.match(str(card.get(tf, ""))):
            errs.append("bad:time_format:" + tf)
    return errs


def scan_sensitive(card):
    blob = json.dumps(card, ensure_ascii=False)
    return SENSITIVE_RX.search(blob) is not None


def is_expired(card, now):
    if card.get("status") != "pending":
        return False
    if card.get("confirmation", {}).get("confirmed_at"):
        return False
    try:
        created = datetime.fromisoformat(str(card["created_at"]).replace("Z", "+00:00"))
    except Exception:
        return False
    return (now - created) > timedelta(days=14)


def migrate_v01(card, now):
    up = {
        "schema_version": SCHEMA_VERSION,
        "id": card.get("id") or "rule_" + now.strftime("%Y%m%d") + "_migrated",
        "revision": int(card.get("revision", 1)),
        "type": V01_TYPE_MAP.get(str(card.get("type", "")), "preference"),
        "status": V01_STATUS_MAP.get(str(card.get("status", "")), "pending"),
        "scope": {"scope_type": card.get("scope_type") if card.get("scope_type") in ENUMS["scope_type"] else "global"},
        "trigger": card.get("trigger"),
        "action": card.get("action", ""),
        "evidence": [],
        "confirmation": {"mode": "legacy"},
        "conflict_with": [],
        "supersedes": [],
        "merged_into": None,
        "created_at": card.get("created_at") or now.isoformat(),
        "updated_at": now.isoformat(),
        "hits": 0,
        "last_hit_at": None,
    }
    return up


def judge(card, now):
    if scan_sensitive(card):
        return "blocked_sensitive", ["敏感形态命中：拒收不生成卡，只记 blocked_sensitive 审计事件"]
    if str(card.get("schema_version", "")) != SCHEMA_VERSION and "schema_version" in card:
        return "legacy", []
    if str(card.get("schema_version", "")) != SCHEMA_VERSION:
        return "legacy", []
    errs = card_errors(card, now)
    if "conflict_requires_pending" in errs:
        return "conflict", errs
    if any(e.startswith("bad:") or e.startswith("conflict") for e in errs):
        return "rejected", errs
    if errs:
        return "rejected", errs
    if is_expired(card, now):
        return "expired", ["pending 超 14 天未确认 -> rejected"]
    return "accepted", []


def pair_judge(a, b):
    """两卡对照：同义同范围 -> synonym；同范围但 action 矛盾 -> conflict。"""
    sa, sb = a.get("scope", {}), b.get("scope", {})
    if sa != sb:
        return "pair-different-scope", []
    na, nb = norm_action(a.get("action")), norm_action(b.get("action"))
    if na == nb:
        return "synonym", []
    return "conflict", []


def main():
    args = [a for a in sys.argv[1:]]
    now = datetime.now(timezone.utc)
    if args and args[0] == "--pair":
        cards = [parse_flat_yaml(open(f, encoding="utf-8").read()) for f in args[1:3]]
        result, errs = pair_judge(cards[0], cards[1])
        print(json.dumps({"pair": args[1:3], "result": result, "errors": errs}, ensure_ascii=False))
        return
    for fp in args:
        raw = open(fp, encoding="utf-8").read()
        card = parse_flat_yaml(raw)
        # revision 字符串转 int
        if isinstance(card.get("revision"), str) and card["revision"].isdigit():
            card["revision"] = int(card["revision"])
        result, errs = judge(card, now)
        out = {"file": fp, "id": card.get("id"), "result": result, "errors": errs}
        if result == "legacy":
            out["migrated"] = migrate_v01(card, now)
        print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
