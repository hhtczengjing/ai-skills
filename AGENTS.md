# AI Skills 开发约定

这是个人日常技能市场，每个技能遵循标准 Agent Skills 格式。

## 目录约定

- 每个技能一个目录：`skills/<skill-name>/SKILL.md` 是唯一必需文件。
- 可选子目录：
  - `references/` —— 长内容按需拆出，`SKILL.md` 用相对路径引用（一层深）。
  - `scripts/` —— 可执行脚本。
  - `assets/` —— 模板、示例、数据文件。

## Frontmatter 约定

- `name`：小写连字符，与目录名一致，全局唯一。
- `description`：必须同时写清 **做什么 + 何时用**，包含触发关键词。
- `license`：MIT。
- `metadata.category` / `metadata.tags`：用于 README 分组，可选。

## 新增 / 修改技能的流程

1. 复制 `templates/SKILL.md` 到 `skills/<name>/SKILL.md` 并填写。
2. 正文超过约 500 行时，把细节拆到 `references/`。
3. 运行 `python3 scripts/generate-index.py` 同步 README 与 `marketplace.json`。
4. 运行 `python3 scripts/validate.py` 校验。

## 写作原则

- `SKILL.md` 写给 coding agent：简洁，只写它不知道的东西，不写历史背景。
- 描述具体、含关键词；示例具体不抽象。
- 不写时间敏感信息。

## 分支

单 `master` 分支，直接提交即可（个人仓库）。
