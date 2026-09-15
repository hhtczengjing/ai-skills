# ios-webview-preview 整体流程测试

`scripts/test-flow.sh` 跑能自动化的部分（构建、安装、注入验证、错误日志断言、截图）。点屏幕 / 键盘交互的部分需要人按本清单手验。

## 0. 一键跑

```bash
bash scripts/test-flow.sh
```

可选参数：
- `bash scripts/test-flow.sh <device-udid> <target-url>` — 指定设备和目标 URL。

跑完会在 `~/.ios-webview-preview/test-screenshots/` 产出：
- `01-main.png` — 主页（刚加载完）
- `02-main-after-injection.png` — 主页（注入完成后）
- `runtime.log` — App 进程日志
- `build.log` — 构建日志

脚本会做这些断言（失败会退出码 1）：
- 无 `uncaught Script error. :0`（说明 `loadFileURL` + file:// origin 生效）
- 无 `null is not an object (evaluating 'i.then')`（worker Promise 修对了）
- 无 `Could not create a sandbox extension`（无 worker 文件加载）
- 无 `unhandledrejection ... P.comments`（tokenization 不再挂掉）

## 1. 人工验收清单

跑完脚本后，**保持 App 在前台**，按顺序点：

| # | 操作 | 期望结果 |
|---|---|---|
| 1 | 看主页 | "Demo" 标题 + 刷新 + 齿轮按钮。页面渲染，**控制台能看到 `[hello] injected, version=1.0.0` 和 `[foo] running`**（注入生效） |
| 2 | 点齿轮 | 进「用户脚本」列表，能看到 **Hello World v1.0.0** 和 **Foo Bar v0.2.0** 两条，右侧 UISwitch 都是绿色启用态 |
| 3 | 点 `+` | 进编辑器，标题「New Script」，源码模板完整渲染 14 行，**JS 语法高亮**：注释绿、字符串红/绿、关键字蓝、标点棕 |
| 4 | tap 编辑器空白处 | 软键盘弹出，光标位置正确 |
| 5 | 敲 `console.log("hi from manual test");` | 字符逐个进入编辑器，**没有丢字符 / 重复字符**；光标跟随；行号正确递增 |
| 6 | 删掉几个字符再敲 | 编辑器正常更新，没有卡死 |
| 7 | 改 `@name` 为 `My Custom Script` | **导航栏标题实时变成「My Custom Script」**（metadata 自动提取） |
| 8 | 点「保存」 | 返回脚本列表，列表里多了一条 `My Custom Script` |
| 9 | 左滑 `My Custom Script` | 显示「删除」按钮 |
| 10 | 点「删除」 | 该条目消失 |
| 11 | 关掉 Foo Bar 的 UISwitch | 切到关（白色），**主页会 reload**（注入列表变化触发 `onChange`） |
| 12 | 进主页 | 重新加载，**控制台只剩 `[hello] injected`，看不到 `[foo] running`**（关掉的脚本不再注入） |
| 13 | 长按导航栏「Demo」标题 | 弹出 URL 修改 alert |
| 14 | 杀掉 App 再开 | 脚本列表里之前保存的脚本还在（持久化 OK） |

全部 ✓ 即整体流程通过。

## 2. 已知不影响功能的 UI 噪音

iOS Simulator 在「Connect Hardware Keyboard」模式下，会在屏幕右下角悬浮一个「Show Keyboard」按钮。这是**模拟器自身**的系统层 UI，App 代码拿不到，关掉路径：

```
Simulator 菜单 → I/O → Keyboard → 取消勾选 Connect Hardware Keyboard
```

快捷键 `⌘ Shift K`。

App 的 `NoAccessoryWebView` 已经屏蔽了键盘顶部那一排附件栏（地球键 / 听写键等），跟模拟器悬浮按钮是两回事。

## 3. 失败排查

| 现象 | 看哪里 |
|---|---|
| 主页白屏 / 加载失败 | `runtime.log` 里 `WebKit ... Loading` 段，看 navigation 是否到 `didNavigateWithNavigationDataShared` |
| 编辑器里打字不进 / 卡死 | `runtime.log` 里搜 `Script error` / `unhandledrejection`，应该都是 0 条 |
| 语法高亮不显示 | 截图 `01-main.png` 看不到编辑器（脚本列表里点 cell 才进）；编辑器里第一行是 `// ==UserScript==` 应该呈绿色 |
| 注入不生效 | 控制台应该看到脚本里的 `console.log`，没有的话检查列表页 UISwitch 是否都开着 |
| 持久化失效 | 进 `xcrun simctl get_app_container <udid> com.devzeng.yidingcheng data` 里的 `Documents/scripts/` 应该有 `<id>.js` 和 `index.json` |

## 4. 自动化增强（未来可加）

如果要把上面 14 步也自动化，需要：
- 给 App 加 URL scheme（如 `webviewpreview://show=settings`）
- `SceneDelegate` 监听 scheme → 走 `nav.pushViewController`
- 脚本里 `xcrun simctl openurl <udid> webviewpreview://show=editor` 触发跳转
- 文本输入可以用 `xcrun simctl io <udid> sendkeys`（目前不支持）或者装 `idb`（Facebook iOS Device Bridge）来做触控 / 键盘模拟

当前 14 步里 1、2 是跳转，3 是点 +，4-7 是编辑输入，11 是 UISwitch 切换 —— 主要瓶颈是触控模拟，不是代码问题。
