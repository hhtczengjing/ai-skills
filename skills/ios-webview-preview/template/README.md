# WebViewPreview

iOS WebView 容器，由 `ios-webview-preview` skill 生成。用来在 iOS 模拟器里预览 H5 / localhost 页面。

## 前置依赖

- macOS
- Xcode（建议 16+，与本模板的 iOS 15 部署目标匹配）
- 命令行工具：`xcode-select --install`
- [xcodegen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- iOS 模拟器（首次启动 Xcode 时按提示安装）

## 跑起来

```bash
xcodegen generate
open WebViewPreview.xcodeproj
# Xcode 里选个模拟器，⌘R
```

或命令行：

```bash
xcodebuild -project WebViewPreview.xcodeproj -scheme WebViewPreview \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## 修改预览 URL

`WebViewPreview/App/Config.swift` 里的 `AppConfig.targetURL` 是默认值。skill 在调用时会自动替换这个值。运行后也可以**长按导航栏标题**直接弹出输入框改 URL。

## 用户脚本（油猴风格）

右上角齿轮 → 进脚本管理。支持的玩法：

- **新增**：右上 `+`，自动填入油猴风格模板（`// ==UserScript==` 头部 + IIFE 占位），直接在编辑器里改源码即可。
- **代码编辑器**：基于 [Monaco Editor](https://microsoft.github.io/monaco-editor/)（VS Code 同款内核），资源打进 app bundle（`Resources/Monaco/`），App 启动时本地 `loadFileURL` 加载，**不依赖 CDN**。行号、语法高亮、Tab 缩进、撤销重做、多光标、查找替换、括号匹配、自动闭合括号都开箱即用。
- **自动元数据提取**：保存时从源码头部 `// ==UserScript== ... // ==/UserScript==` 块解析 `@name` `@version` 等字段，导航栏标题和列表自动同步。`name` 不会再有独立输入框。
- **从剪贴板粘贴**：编辑器工具栏「粘贴」按钮，或直接在代码区里 long-press 用系统粘贴菜单；新建脚本时如果剪贴板有文本，会主动弹提示询问是否粘贴，metadata 自动从粘贴的源码中提取。
- **从 URL 拉取**：编辑器底部工具栏「从 URL 拉取」，输入 `.user.js` 链接，metadata 自动从拉取内容中提取。
- **启用 / 禁用**：列表右侧 UISwitch 切换。**所有启用的脚本注入到所有加载的页面**（不做 URL 匹配）。
- **删除**：左滑删除。
- **错误隔离**：每个脚本被 IIFE + try/catch 包一层，脚本 throw 不会拖垮整个 WebView，错误打到 console。

源码与元数据都落在沙箱 `Documents/scripts/`：

```
Documents/scripts/
  index.json     // [{id, name, version, source, enabled, createdAt, updatedAt}]
  <id>.js        // 每个脚本独立落盘
```

也可以直接编辑这两个文件（App 重启会重新读取）。老 index.json 没有 `version` 字段时 JSONDecoder 自动 nil，向后兼容。

### Monaco 编辑器说明

- **Worker 限制**：WKWebView 加载 `file://` 资源时不能创建 Web Worker，所以 Monaco 在我们这里跑在主线程（`MonacoEnvironment.getWorker = () => null`）。代价是 TS/JSON/HTML 智能提示不可用，**JS 语法高亮正常**（Monarch tokenizer 同步执行）。用户脚本只需要 JS 编辑，这恰好是合适的取舍。
- **裁剪策略**：vendor 进项目的 Monaco 只保留了 `loader.js` + `editor.main.js` + `basic-languages/javascript/`，外加英文 NLS（约 4 MB）。TypeScript/JSON/CSS/HTML 这些带 worker 的语言服务整包砍掉。
- **升级 Monaco**：运行 `bash scripts/monaco-bundler.sh [version]`，默认 0.45.0。脚本会 `npm pack`、解压、裁剪、写入 `template/WebViewPreview/Resources/Monaco/`，然后再跑 `xcodegen generate` 让 Xcode 重新认识资源。

## 目录

Swift 代码按职责拆成 4 个子目录（xcodegen `path: WebViewPreview` 递归包含，子目录自动映射成 Xcode groups）。

```
.
├── project.yml                      xcodegen 配置
├── example/                         测试用 userscript（仅 skill 开发时手动注入；不会自动跑）
│   └── cookieBridge-e2e.user.js
├── WebViewPreview/
│   ├── App/                         App 生命周期 + Config
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── Config.swift             targetURL（被 skill 改写）
│   ├── WebView/                     WKWebView 容器（纯 plumbing，~200 行）
│   │   └── WebViewController.swift  核心：WKWebView + 导航栏 + 返回/刷新 + 齿轮入口
│   ├── NativeExtensions/            $app 插件系统
│   │   ├── AppNativePlugin.swift    插件协议 + AppNativeReply
│   │   ├── AppNativeRegistry.swift  注册表 + shim builder + dispatch + handler
│   │   └── CookieBridge.swift       $app.cookie 插件实现（跨域 cookie 桥）
│   ├── UserScripts/                 用户脚本（油猴风格）运行时
│   │   ├── Script.swift                 数据模型（含油猴默认模板）
│   │   ├── ScriptMetadata.swift         油猴头部注释解析
│   │   ├── ScriptStore.swift            持久化（Documents/scripts/index.json + <id>.js）
│   │   ├── ScriptInjector.swift         IIFE + try/catch 包装
│   │   ├── BuiltinScripts.swift         内置脚本虚拟列表（source 从 bundle 读）
│   │   ├── SettingsViewController.swift 脚本列表
│   │   ├── ScriptEditorViewController.swift 脚本编辑器（Monaco + 元数据自动提取）
│   │   └── CodeEditorView.swift         WKWebView + Monaco 桥
│   ├── Resources/Monaco/
│   │   ├── editor.html              Monaco 宿主页
│   │   └── js/vs/...                Monaco AMD bundle（裁剪后 ~4 MB）
│   ├── Resources/Scripts/
│   │   └── vconsole.user.js         内置 JS 源（BuiltinScript 读它）
│   ├── Info.plist
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       ├── Back.imageset/           返回按钮图标
│       ├── Refresh.imageset/        刷新按钮图标
│       └── AccentColor.colorset/
└── README.md
```

## 测试插件

`example/` 下的 `*.user.js` 是开发 skill / native 扩展时的端到端测试脚本，**不会自动跑**。手动注入到 App 沙箱 `Documents/scripts/`（用 `scripts/install-test-scripts.sh`），在 Settings → 用户脚本 里打开开关后，断言结果打到 Xcode console 或 Safari Web Inspector。

## Bundle / 签名

`project.yml` 里 `PRODUCT_BUNDLE_IDENTIFIER` / `PRODUCT_NAME` / `DEVELOPMENT_TEAM` 是这个 skill 模板的默认值。改为你自己的：

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.yourco.yourapp
PRODUCT_NAME: YourAppName
DEVELOPMENT_TEAM: ABCDE12345
```

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 是 build 号，会被 `Info.plist` 通过 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` 引用，改一处即可。

## 注意

- iOS deployment target: 15.0（Xcode 16 起步）
- 启动页用 `UILaunchScreen`（iOS 13+ 标配，无 storyboard）
- 强制 light mode（`Info.plist` 里 `UIUserInterfaceStyle: Light`）
- `Info.plist` 已开 `NSAllowsArbitraryLoads` + `NSAllowsLocalNetworking`，HTTP localhost 可直连
