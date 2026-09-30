#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen-marketplace-kit.py — W1 市场共存·出站上架素材生成器（阶段1）

从 packs/<pack>/skills/*/SKILL.md 生成各市场上架素材：
  dist/marketplace/
    claude-plugin/            # Claude Code 官方插件市场 kit
      .claude-plugin/marketplace.json
      plugins/<plugin>/plugin.json + skills/<skill>/...
    qoder/<skill>.zip         # Qoder Upload Skill 直导 ZIP（SKILL.md 原生兼容）
    metadata/listing-metadata.json   # 全渠道通用上架元数据

零第三方依赖（纯标准库）。生产侧工具，不进用户安装链。
用法：
  python3 scripts/gen-marketplace-kit.py                    # lite 档（marketplace-map free_tier）
  python3 scripts/gen-marketplace-kit.py --tier full        # 全量
  python3 scripts/gen-marketplace-kit.py --packs ai-pm      # 指定 pack
"""
import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path

MARKETPLACE_NAME = "asp-kits"  # 市场名；避免 Anthropic 保留名（claude-plugins-official 等）
PLUGIN_PREFIX = "asp-"


def parse_frontmatter(md_path: Path):
    """极简 frontmatter 解析：只取 name/description 两个 key: value 行。"""
    meta = {}
    try:
        text = md_path.read_text(encoding="utf-8")
    except OSError:
        return meta
    if not text.startswith("---"):
        return meta
    end = text.find("---", 3)
    if end == -1:
        return meta
    for line in text[3:end].splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            k = k.strip()
            if k in ("name", "description") and k not in meta:
                meta[k] = v.strip().strip('"').strip("'")
    return meta


def load_marketplace_map(repo_root: Path):
    mpath = repo_root / "registry" / "marketplace-map.json"
    if not mpath.exists():
        return None
    try:
        return json.loads(mpath.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        print(f"[warn] {mpath} 解析失败（{e}），free_tier 过滤将跳过", file=sys.stderr)
        return None


def collect_skills(repo_root: Path, packs):
    """返回 [(pack, skill_dir, meta)]；meta 为 SKILL.md frontmatter。"""
    out = []
    for pack in packs:
        skills_dir = repo_root / "packs" / pack / "skills"
        if not skills_dir.is_dir():
            continue
        for skill_dir in sorted(skills_dir.iterdir()):
            md = skill_dir / "SKILL.md"
            if not skill_dir.is_dir() or not md.exists():
                continue
            out.append((pack, skill_dir, parse_frontmatter(md)))
    return out


def gen_claude_plugin_kit(out_root: Path, marketplace_name: str, entries):
    """Claude Code 官方插件市场 kit（结构见 create-marketplace 官方文档）。"""
    kit = out_root / "claude-plugin"
    (kit / ".claude-plugin").mkdir(parents=True, exist_ok=True)

    # 按 pack 分组；复制 skill 目录到 plugins/<pid>/skills/
    by_pack = {}
    for pack, skill_dir, meta in entries:
        by_pack.setdefault(pack, []).append((skill_dir, meta))

    plugins = []
    for pack, skills in sorted(by_pack.items()):
        pid = PLUGIN_PREFIX + pack
        desc = (
            f"AI-Start Kits ({pack}): {len(skills)} curated agent skills — "
            f"方法层技能包（完整版含 AGENTS.md/prompts/周更）"
        )
        for skill_dir, _meta in skills:
            dest = kit / "plugins" / pid / "skills" / skill_dir.name
            shutil.copytree(skill_dir, dest)
        (kit / "plugins" / pid / "plugin.json").write_text(
            json.dumps(
                {
                    "name": pid,
                    "description": desc,
                    "version": "0.1.0",
                    "author": {"name": "TODO-D9"},
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        plugins.append({"name": pid, "source": f"./plugins/{pid}", "description": desc})

    marketplace = {
        "name": marketplace_name,
        "description": "AI-Start Kits — 跨 agent 方法层技能包（lite 免费；完整版走安装码渠道）",
        "owner": {"name": "TODO-D9"},
        "plugins": plugins,
    }
    (kit / ".claude-plugin" / "marketplace.json").write_text(
        json.dumps(marketplace, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def gen_qoder_zips(out_root: Path, entries):
    """Qoder Upload Skill 直导 ZIP（每 skill 一个，根目录即 SKILL.md）。"""
    qdir = out_root / "qoder"
    qdir.mkdir(parents=True, exist_ok=True)
    for _pack, skill_dir, _meta in entries:
        zpath = qdir / f"{skill_dir.name}.zip"
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(skill_dir.rglob("*")):
                if f.is_file():
                    z.write(f, f.relative_to(skill_dir).as_posix())


def gen_metadata(out_root: Path, entries, tier, map_data, marketplace_name):
    """全渠道通用上架元数据。"""
    meta_dir = out_root / "metadata"
    meta_dir.mkdir(parents=True, exist_ok=True)
    channels = [
        {"id": c.get("id"), "name": c.get("name"), "status": c.get("status")}
        for c in (map_data or {}).get("outbound", {}).get("channels", [])
    ]
    doc = {
        "generated_by": "scripts/gen-marketplace-kit.py",
        "tier": tier,
        "brand_display_name": "TODO-D9",
        "install_commands": {
            "skills_sh": "npx skills add xjinya-xiangwu/AI-cold-start",
            "claude_plugin": (
                f"claude plugin marketplace add xjinya-xiangwu/AI-cold-start && "
                f"claude plugin install {PLUGIN_PREFIX}base@{marketplace_name}"
            ),
        },
        "channels": channels,
        "skills": [
            {
                "pack": pack,
                "id": meta.get("name", skill_dir.name),
                "description": meta.get("description", ""),
                "origin": "self-produced",
                "source_dir": f"packs/{pack}/skills/{skill_dir.name}",
            }
            for pack, skill_dir, meta in entries
        ],
    }
    (meta_dir / "listing-metadata.json").write_text(
        json.dumps(doc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main():
    ap = argparse.ArgumentParser(description="Generate marketplace listing kits from packs/")
    ap.add_argument("--repo-root", default=".", help="AI-cold-start 仓库根")
    ap.add_argument("--out", default=None, help="输出目录（默认 <repo>/dist/marketplace）")
    ap.add_argument("--tier", choices=["lite", "full"], default="lite")
    ap.add_argument("--packs", default="base,ai-pm", help="逗号分隔 pack 名")
    ap.add_argument("--marketplace-name", default=MARKETPLACE_NAME)
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    packs = [p.strip() for p in args.packs.split(",") if p.strip()]
    out_root = Path(args.out).resolve() if args.out else repo_root / "dist" / "marketplace"

    map_data = load_marketplace_map(repo_root)

    all_entries = collect_skills(repo_root, packs)
    if not all_entries:
        print("[error] 未找到任何 packs/<pack>/skills/*/SKILL.md —— 检查 --repo-root 与 --packs", file=sys.stderr)
        return 2

    if args.tier == "lite":
        free = (map_data or {}).get("outbound", {}).get("free_tier", {})
        allowed = set(free.get("skills", []))
        entries = [(p, d, m) for (p, d, m) in all_entries if d.name in allowed]
        if not entries:
            print("[error] lite 档未匹配到任何 skill —— 检查 registry/marketplace-map.json free_tier.skills 与 packs 实际目录名", file=sys.stderr)
            return 2
    else:
        entries = all_entries

    if out_root.exists():
        shutil.rmtree(out_root)
    out_root.mkdir(parents=True)

    gen_claude_plugin_kit(out_root, args.marketplace_name, entries)
    gen_qoder_zips(out_root, entries)
    gen_metadata(out_root, entries, args.tier, map_data, args.marketplace_name)

    print(f"[ok] tier={args.tier} skills={len(entries)} -> {out_root}")
    print("     claude-plugin kit : .claude-plugin/marketplace.json + plugins/*")
    print("     qoder zips        : qoder/*.zip (Upload Skill 直导)")
    print("     metadata          : metadata/listing-metadata.json")
    print("验证: claude plugin validate <out>/claude-plugin")
    return 0


if __name__ == "__main__":
    sys.exit(main())
