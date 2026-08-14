---
name: git-commit-message
description: 根据 git diff 与提交历史，按 Conventional Commits 规范生成中文提交信息，并提供交互式选择。当用户说「帮我写 commit」「生成提交信息」「提交一下」时使用。
license: MIT
metadata:
  category: dev
  version: "1.0.0"
  tags: git, commit, workflow
---

# Git Commit Message

根据暂存区改动生成规范的中文提交信息。

## 步骤

1. 读取 `git diff --staged`；若暂存区为空，改为读取 `git diff` 并提醒用户先 `git add`。
2. 读取最近 5 条提交 `git log --oneline -5`，学习仓库现有的提交风格。
3. 按 [Conventional Commits](./references/conventional-commits.md) 生成 3 个候选。
4. 让用户选择或编辑，确认后执行提交。

## 规则

- 标题 ≤ 72 字符，用祈使句（「添加」而非「添加了」）。
- 破坏性变更必须带 `!`（如 `feat!:`）。
- 不要自动 `push`，除非用户明确要求。

## 参考

- 类型与示例：见 [references/conventional-commits.md](./references/conventional-commits.md)
