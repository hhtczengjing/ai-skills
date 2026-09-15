"""Validate skill structure and frontmatter. Exits non-zero on any problem.

Usage:
    python3 scripts/validate.py
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from common import MARKETPLACE_PATH, NAME_RE, SKILLS_DIR, parse_frontmatter


def find_untracked_under_skills() -> list[str]:
    """列出 skills/ 下未 git add 的文件，提醒新文件没入库。"""
    try:
        out = subprocess.check_output(
            ["git", "ls-files", "--others", "--exclude-standard", "--", "skills/"],
            cwd=SKILLS_DIR.parent, stderr=subprocess.DEVNULL, text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []  # 不在 git 仓库里就跳过
    return [line.strip() for line in out.splitlines() if line.strip()]


def main() -> None:
    errors: list[str] = []
    count = 0

    if not SKILLS_DIR.exists():
        errors.append("缺少 skills/ 目录")
    else:
        dirs = [d for d in sorted(SKILLS_DIR.iterdir())
                if d.is_dir() and not d.name.startswith(".")]
        if not dirs:
            errors.append("skills/ 下没有任何技能目录")
        for d in dirs:
            skill_md = d / "SKILL.md"
            if not skill_md.exists():
                errors.append(f"{d.name}: 缺少 SKILL.md")
                continue
            count += 1
            fm = parse_frontmatter(skill_md.read_text())
            if not fm:
                errors.append(f"{d.name}: SKILL.md 缺少 frontmatter（需以 --- 包裹）")
                continue
            name = fm.get("name", "")
            desc = fm.get("description", "")
            if not name:
                errors.append(f"{d.name}: frontmatter 缺少 name")
            elif not NAME_RE.match(name):
                errors.append(f"{d.name}: name「{name}」不符合小写连字符规范")
            elif name != d.name:
                errors.append(f"{d.name}: name「{name}」与目录名不一致")
            if not desc:
                errors.append(f"{d.name}: frontmatter 缺少 description")
            elif len(desc) < 20:
                errors.append(f"{d.name}: description 过短，需说明「做什么 + 何时用」")

    if MARKETPLACE_PATH.exists():
        try:
            data = json.loads(MARKETPLACE_PATH.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"marketplace.json 不是合法 JSON：{e}")
            data = {}
        for p in data.get("plugins", []):
            src = p.get("source", "")
            if src in ("", "./"):
                continue
            rel = src[2:] if src.startswith("./") else src
            if not (SKILLS_DIR.parent / rel).is_dir():
                errors.append(
                    f"marketplace.json：plugin「{p.get('name')}」的 source「{src}」不存在"
                )
    else:
        errors.append("缺少 .claude-plugin/marketplace.json")

    # 提醒 skills/ 下未 add 的文件（新增文件忘了 git add 会漏发布）
    untracked = find_untracked_under_skills()
    if untracked:
        errors.append(
            "skills/ 下有未 git add 的文件（先 `git add` 再提交）：\n  "
            + "\n  ".join(untracked)
        )

    if errors:
        print("❌ 校验失败：")
        for e in errors:
            print("  -", e)
        sys.exit(1)

    print(f"✅ 校验通过：{count} 个技能结构正常")


if __name__ == "__main__":
    main()
