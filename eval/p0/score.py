#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""score.py — R02 盲评指标计算（PRD v0.2 §8.2 / DST-P0-05）
用法: python score.py <blind-sheet.csv>
口径: 首用可采纳率 = directly_usable=是 的臂占比；相对提升 = (post-pre)/pre；pre=0 只报百分点差。
"""
import csv
import sys

YES = {"是", "yes", "y", "1", "true"}


def load(path):
    rows = list(csv.DictReader(open(path, encoding="utf-8-sig")))
    return rows


def rate(rows, arm):
    arms = [r for r in rows if r["arm"].strip().lower() == arm]
    if not arms:
        return None, 0
    ok = sum(1 for r in arms if r["directly_usable"].strip().lower() in YES)
    return ok / len(arms), len(arms)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    rows = load(sys.argv[1])
    pre, npre = rate(rows, "pre")
    post, npost = rate(rows, "post")
    print("配对臂样本: pre={} post={}".format(npre, npost))
    if pre is None or post is None:
        print("样本不足，无法计算。")
        sys.exit(1)
    print("直接可采纳率: pre={:.1%} post={:.1%}".format(pre, post))
    diff_pp = (post - pre) * 100
    print("百分点差: {:+.1f} pp".format(diff_pp))
    if pre > 0:
        print("相对提升: {:+.1%}（门禁建议 ≥20%）".format((post - pre) / pre))
    else:
        print("pre=0：只报百分点差（§8.2），不计算相对提升。")
    bad = [r for r in rows if r.get("privacy_or_damage_issue", "").strip() not in ("", "否", "no", "n", "0", "false")]
    if bad:
        print("⚠ 隐私/破坏问题样本 {} 条（单列，不计入可采纳率）:".format(len(bad)))
        for r in bad:
            print("   {} {} {}".format(r["pair_id"], r["task_id"], r["agent_id"]))


if __name__ == "__main__":
    main()
