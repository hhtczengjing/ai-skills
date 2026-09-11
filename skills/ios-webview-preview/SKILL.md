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

- macOS
- Xcode（建议 16+，与模板的 iOS 15 部署目标匹配）
- 命令行工具：`xcode-select --install`
- [xcodegen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- iOS 模拟器（首次启动 Xcode 时按提示安装）

## 使用方式

### 命令行参数
```bash
/ios-webview-preview http://localhost:3000 --device "iPhone 16 Pro"
```

### 自然语言
```
帮我预览 http://localhost:3000，用 iPhone 16 Pro
预览一下 http://localhost:8080
```

## 参数说明

| 参数 | 说明 | 必填 | 默认值 |
|------|------|------|--------|
| URL | 要预览的网页地址（支持 http/https） | 是 | - |
| device | 模拟器名称或 UDID | 否 | iPhone 16 Pro |

## 执行流程

1. 解析 URL 和设备参数
2. 检查项目是否存在（~/.ios-webview-preview/）
3. 如果不存在，从模板初始化项目（复制 template/ 并执行 xcodegen）
4. 更新 Config.swift 中的 URL
5. 编译项目（xcodebuild）
6. 启动模拟器（如果未启动）
7. 安装并运行 App

## 注意事项

- 默认设备：iPhone 16 Pro
- 支持 HTTP（localhost）和 HTTPS
- 导航栏标题跟随网页 title
- 返回按钮执行 webView.goBack()
