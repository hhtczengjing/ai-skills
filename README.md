# AI Skills

我的日常技能市场（Claude Code / Agent Skills 格式）。基于 GitHub 托管，可在 Claude Code 里通过插件市场一键安装。

## 安装

在 Claude Code 中：

```
/plugin marketplace add hhtczengjing/ai-skills
```

按需安装单个技能：

```
/plugin install ios-webview-preview
```

> 也支持其他遵循 Agent Skills 格式的客户端：直接 `git clone` 后把 `skills/` 下的目录加入你的 skills 路径。

## 技能清单

<!-- SKILLS-TABLE:START -->
| 技能 | 目录 | 分类 | 说明 |
|------|------|------|------|
| `drawio-designer` | `skills/drawio-designer` | diagram | 创建、编辑和管理 draw.io XML 图表，支持转换为 PNG，集成 AWS、K8s 及通用 IT 图标。当用户要求「画架构图」「画流程图」「生成 drawio 图」「修改 drawio 图」时使用。 |
| `ios-webview-preview` | `skills/ios-webview-preview` | ios | 当用户需要「预览 H5」「iOS 预览」「WebView 预览」「模拟器预览」本地 localhost 网页时使用。给定 URL，自动编译 iOS WebView App 并在指定模拟器上运行。支持 http/https，导航栏标题跟随网页 title，返回按钮支持 goBack。 |
<!-- SKILLS-TABLE:END -->

## 新增技能

1. `cp templates/SKILL.md skills/<name>/SKILL.md`，填写 frontmatter 与正文。
2. 运行 `python3 scripts/generate-index.py` 同步 README 与 marketplace.json。
3. 运行 `python3 scripts/validate.py` 校验。
4. `git add . && git commit -m "feat: 添加 <name> 技能"`。

## 目录结构

```
.
├── skills/                  # 技能（一个技能一个目录）
│   └── <name>/
│       ├── SKILL.md         # 必需：含 frontmatter
│       ├── references/      # 可选：渐进式披露
│       ├── scripts/         # 可选：可执行脚本
│       └── assets/          # 可选：模板/数据
├── templates/SKILL.md       # 新建技能的模板
├── .claude-plugin/
│   └── marketplace.json     # Claude Code 插件市场清单（自动生成）
├── scripts/
│   ├── validate.py          # 校验技能结构
│   └── generate-index.py    # 从 skills/ 生成 README 表 + marketplace.json
├── AGENTS.md                # 开发约定
└── .github/workflows/       # CI 校验
```

## 维护命令

| 命令 | 作用 |
|------|------|
| `python3 scripts/validate.py` | 校验 frontmatter 与目录结构 |
| `python3 scripts/generate-index.py` | 同步 README 表与 marketplace.json |
| `python3 scripts/generate-index.py --check` | 只检查是否有漂移（CI 用） |
