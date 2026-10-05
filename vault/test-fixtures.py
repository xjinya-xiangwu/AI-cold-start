#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""test-fixtures.py — T13 夹具断言：10 个夹具文件必须得到唯一且正确的结果（PRD §5.4 夹具判定）。
用法: python test-fixtures.py   （在 vault/ 目录下；零第三方依赖）"""
import json
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FX = os.path.join(HERE, "fixtures")
PY = sys.executable

EXPECT_SINGLE = {
    "01-valid.yaml": "accepted",
    "02-missing-required.yaml": "rejected",
    "03-bad-enum.yaml": "rejected",
    "04-pending-14d.yaml": "expired",
    "05-sensitive.yaml": "blocked_sensitive",
    "06-legacy-v01.yaml": "legacy",
}
FAILS = 0


def run(args):
    out = subprocess.run([PY, os.path.join(HERE, "validate-cards.py")] + args,
                         capture_output=True, text=True)
    return out.stdout.strip(), out.returncode


def check(name, cond, detail=""):
    global FAILS
    if cond:
        print("  PASS " + name)
    else:
        FAILS += 1
        print("  FAIL " + name + "  " + detail)


print("== 单卡判定（8 类中的 6 类）")
for fn, want in EXPECT_SINGLE.items():
    out, rc = run([os.path.join(FX, fn)])
    try:
        j = json.loads(out)
    except Exception:
        check(fn + " -> " + want, False, "bad output: " + out[:120])
        continue
    check(fn + " -> " + want, j["result"] == want, "got " + j["result"] + " " + json.dumps(j.get("errors", []), ensure_ascii=False))
    if fn == "02-missing-required.yaml":
        check("  缺字段报 evidence", any(e == "missing:evidence" for e in j.get("errors", [])))
    if fn == "03-bad-enum.yaml":
        check("  坏枚举报 type", any(e == "bad:type" for e in j.get("errors", [])))
    if fn == "06-legacy-v01.yaml":
        mig = j.get("migrated") or {}
        check("  v0.1 迁移: 中文状态->active", mig.get("status") == "active")
        check("  v0.1 迁移: 中文类型->preference", mig.get("type") == "preference")
        check("  v0.1 迁移: schema_version 升 1.0", mig.get("schema_version") == "1.0")

print("== 两卡对照（同义合并 / 冲突待确认）")
out, rc = run(["--pair", os.path.join(FX, "08a-synonym.yaml"), os.path.join(FX, "08b-synonym.yaml")])
j = json.loads(out)
check("同义同范围 -> synonym", j["result"] == "synonym", "got " + j["result"])
out, rc = run(["--pair", os.path.join(FX, "07a-conflict.yaml"), os.path.join(FX, "07b-conflict.yaml")])
j = json.loads(out)
check("同范围异动 -> conflict", j["result"] == "conflict", "got " + j["result"])

print()
if FAILS == 0:
    print("全部断言通过 ✓（T13 夹具判定唯一，validate-cards.py + fixtures）")
    sys.exit(0)
print("失败断言 %d 个 ✗" % FAILS)
sys.exit(1)
