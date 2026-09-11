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

`WebViewPreview/Config.swift` 里的 `AppConfig.targetURL` 是默认值。skill 在调用时会自动替换这个值。运行后也可以**长按导航栏标题**直接弹出输入框改 URL。

## 目录

```
.
├── project.yml                      xcodegen 配置
├── WebViewPreview/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── WebViewController.swift      核心：WKWebView + 导航栏 + 返回/刷新
│   ├── Config.swift                 targetURL（被 skill 改写）
│   ├── Info.plist
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       ├── Back.imageset/           返回按钮图标
│       ├── Refresh.imageset/        刷新按钮图标
│       └── AccentColor.colorset/
└── README.md
```

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
