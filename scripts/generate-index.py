"""Regenerate README skill table and marketplace.json from skills/*/SKILL.md.

The SKILL.md frontmatter is the single source of truth for a skill's name,
description, and category. Run this after adding/editing/removing a skill so the
README index and the Claude Code marketplace manifest stay in sync.

Usage:
    python3 scripts/generate-index.py            # write files
    python3 scripts/generate-index.py --check    # fail if files would change
"""
from __future__ import annotations

import json
import sys

from common import MARKETPLACE_PATH, README_PATH, collect_skills

TABLE_START = "<!-- SKILLS-TABLE:START -->"
TABLE_END = "<!-- SKILLS-TABLE:END -->"


def build_plugins(skills: list[dict]) -> list[dict]:
    plugins = [{
        "name": "my-daily-skills-bundle",
        "source": "./",
        "description": "一次安装全部技能。",
    }]
    for s in skills:
        plugins.append({
            "name": s["name"],
            "source": f"./skills/{s['dir']}",
            "description": s["description"],
        })
    return plugins


def render_marketplace(skills: list[dict]) -> str:
    data: dict = {}
    if MARKETPLACE_PATH.exists():
        try:
            data = json.loads(MARKETPLACE_PATH.read_text())
        except json.JSONDecodeError:
            data = {}
    data["name"] = data.get("name", "my-daily-skills")
    data["description"] = data.get("description", "我的日常技能市场。")
    data["owner"] = data.get("owner", {"name": "hhtczengjing"})
    data["plugins"] = build_plugins(skills)
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def render_table(skills: list[dict]) -> str:
    lines = [
        "| 技能 | 目录 | 分类 | 说明 |",
        "|------|------|------|------|",
    ]
    for s in skills:
        cat = s["category"] or "—"
        lines.append(f"| `{s['name']}` | `skills/{s['dir']}` | {cat} | {s['description']} |")
    return "\n".join(lines)


def render_readme(skills: list[dict]) -> str:
    text = README_PATH.read_text()
    start = text.index(TABLE_START)
    end = text.index(TABLE_END)
    new = text[:start] + TABLE_START + "\n" + render_table(skills) + "\n" + text[end:]
    return new


def main() -> None:
    check = "--check" in sys.argv
    skills = collect_skills()

    marketplace_text = render_marketplace(skills)
    readme_text = render_readme(skills)

    if check:
        problems = []
        if MARKETPLACE_PATH.read_text() != marketplace_text:
            problems.append("marketplace.json 与 skills/ 不同步")
        if README_PATH.read_text() != readme_text:
            problems.append("README 技能表与 skills/ 不同步")
        if problems:
            print("❌ 生成文件已过期，请运行：python3 scripts/generate-index.py")
            for p in problems:
                print("  -", p)
            sys.exit(1)
        print(f"✅ 生成文件已同步：{len(skills)} 个技能")
        return

    MARKETPLACE_PATH.write_text(marketplace_text)
    README_PATH.write_text(readme_text)
    print(f"✅ 已更新 marketplace.json 与 README 技能表（{len(skills)} 个技能）")


if __name__ == "__main__":
    main()
