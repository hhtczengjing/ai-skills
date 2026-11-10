---
name: ios-webview-preview
description: 当用户需要「预览 H5」「iOS 预览」「WebView 预览」「模拟器预览」本地 localhost 网页时使用。给定 URL，自动编译 iOS WebView App 并在指定模拟器上运行。支持 http/https，导航栏标题跟随网页 title，返回按钮支持 goBack。
license: MIT
metadata:
  category: ios
  version: "1.0.0"
  tags: ios, webview, preview, simulator, h5
---

# iOS WebView Preview

快速预览本地 H5 页面在 iOS 模拟器上的效果。

## 前置依赖

- macOS、Xcode（建议 16+，匹配 iOS 15 部署目标）
- `xcodegen`（`brew install xcodegen`）
- 已 boot 一个 iOS 模拟器

## 使用方式

```bash
/ios-webview-preview http://localhost:3000
/ios-webview-preview http://localhost:3000 --device "iPhone 16 Pro"
```

自然语言：`帮我预览 http://localhost:8080，用 iPhone 16`。

## 参数

| 参数 | 说明 | 必填 | 默认 |
|---|---|---|---|
| URL | 要预览的 http(s) 地址 | 是 | - |
| `--device` | 模拟器名称或 UDID | 否 | iPhone 16 Pro |

## 执行流程

1. 解析 URL 和 `--device` 参数
2. 模板项目不存在 → 拷 `template/` 到 `~/.ios-webview-preview/` 并 `xcodegen generate`
3. 写 `App/Config.swift` 的 `targetURL`
4. `xcodebuild` 编译
5. `simctl install` + `simctl launch`

## 注意事项

- `Config.swift` 路径：`WebViewPreview/App/Config.swift`（重构后放在 `App/` 子目录）
- URL 带 `dd_full_screen=true`（query 或 hash 路由均可，如 `http://localhost:3000/#/page?dd_full_screen=true`）时进入**全屏模式**：导航栏隐藏，右上角显示半透明悬浮设置按钮进入设置页；webView 顶到屏幕边缘（含刘海/状态栏区域），安全距离由前端自己处理（`viewport-fit=cover` + `env(safe-area-inset-*)`）
- 模拟器里**长按导航栏标题**可以现场改 URL（全屏模式下导航栏隐藏，此入口不可用）
- 用户脚本（`UserScripts/`）和 native 扩展（`NativeExtensions/`）的代码改动需要重新 `bash scripts/run.sh`（或单独 `build.sh` + `run.sh`）

## 开发 skill 时本地跑全套

`scripts/run-example.sh` 一条命令把示例工程跑起来：

```bash
bash scripts/run-example.sh                 # 当前 booted simulator
bash scripts/run-example.sh "iPhone 16 Pro" # 指定设备
```

它会：拷贝 `template/` → `~/.ios-webview-preview/`（项目不存在时）→ `xcodegen generate` → `xcodebuild` → `simctl install`（uninstall + 清沙箱）→ 把 `template/example/*.user.js` 注入沙箱 → `simctl launch`。

改了 `template/example/` 里的脚本或 Swift 代码 → 都跑这个脚本就够了。