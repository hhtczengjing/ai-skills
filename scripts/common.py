"""Shared helpers for the skill marketplace tooling."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
MARKETPLACE_PATH = ROOT / ".claude-plugin" / "marketplace.json"
README_PATH = ROOT / "README.md"

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
FRONTMATTER_RE = re.compile(r"\A---[ \t]*\n(.*?)\n---[ \t]*\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Parse the SKILL.md YAML frontmatter block into a flat dict.

    Handles the top-level scalar keys we care about (name, description, license)
    plus a ``metadata:`` block whose sub-keys are collected under ``metadata``.
    """
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    data: dict = {}
    metadata: dict = {}
    in_metadata = False
    for raw in m.group(1).splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        if line[0] in (" ", "\t") and in_metadata:
            mm = re.match(r"[ \t]+([\w-]+):[ \t]*(.*)$", line)
            if mm:
                metadata[mm.group(1)] = mm.group(2).strip().strip("\"'")
            continue
        if line.startswith("metadata:"):
            in_metadata = True
            continue
        in_metadata = False
        mm = re.match(r"^([\w-]+):[ \t]*(.*)$", line)
        if mm:
            data[mm.group(1)] = mm.group(2).strip().strip("\"'")
    if metadata:
        data["metadata"] = metadata
    return data


def collect_skills() -> list[dict]:
    """Return sorted list of skill dicts: {name, dir, description, category}."""
    skills: list[dict] = []
    if not SKILLS_DIR.exists():
        return skills
    for d in sorted(SKILLS_DIR.iterdir()):
        if not d.is_dir() or d.name.startswith("."):
            continue
        skill_md = d / "SKILL.md"
        if not skill_md.exists():
            continue
        fm = parse_frontmatter(skill_md.read_text())
        skills.append({
            "name": fm.get("name", d.name),
            "dir": d.name,
            "description": fm.get("description", ""),
            "category": (fm.get("metadata") or {}).get("category", ""),
        })
    return skills
