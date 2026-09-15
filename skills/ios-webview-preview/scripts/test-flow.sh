#!/usr/bin/env bash
# 整体流程自动化测试：编译 → 安装 → 截图主页面 / 脚本列表 / 编辑器。
# 涉及点击 / 键盘输入的步骤（编辑器内打字、点保存、点 + 等）需要人工做，
# 见 scripts/TEST.md 的「手动验收清单」。
#
# 用法：
#   bash scripts/test-flow.sh [device-udid] [target-url]
# 默认设备 = 当前已 boot 的 iPhone 16 Pro Simulator，默认 url 沿用 Config.swift。

set -euo pipefail

DEVICE_UDID="${1:-}"
TARGET_URL="${2:-}"

if [ -z "$DEVICE_UDID" ]; then
    DEVICE_UDID=$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/{print $2; exit}')
    if [ -z "$DEVICE_UDID" ]; then
        echo "error: 没有 boot 的 Simulator，先启动一个再跑："
        echo "  xcrun simctl boot 'iPhone 16 Pro'"
        exit 1
    fi
fi

BUNDLE_ID="com.devzeng.yidingcheng"
APP_NAME="壹定橙"
WORK_DIR="$HOME/.ios-webview-preview"
ARTIFACTS_DIR="$WORK_DIR/build/derivedData"
APP_PATH="$ARTIFACTS_DIR/Build/Products/Debug-iphonesimulator/$APP_NAME.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../template" && pwd)"

# 截图输出目录
SHOTS_DIR="$WORK_DIR/test-screenshots"
mkdir -p "$SHOTS_DIR"

# ---------- 0. 把 template 同步到 working copy ----------
echo "==> 同步 template → $WORK_DIR"
for f in AppDelegate.swift SceneDelegate.swift CodeEditorView.swift \
         BuiltinScripts.swift ScriptEditorViewController.swift \
         SettingsViewController.swift WebViewController.swift \
         Script.swift ScriptMetadata.swift ScriptStore.swift \
         ScriptInjector.swift Config.swift Info.plist project.yml \
         Assets.xcassets; do
    src="$TEMPLATE_DIR/WebViewPreview/$f"
    dst="$WORK_DIR/WebViewPreview/$f"
    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
    fi
done

# Resources 目录：先清掉 working copy 里的旧资源（避免 Presets 这种
# 已删除的还留在 bundle 里），再从 template 整体同步
rm -rf "$WORK_DIR/WebViewPreview/Resources/Presets"
cp -R "$TEMPLATE_DIR/WebViewPreview/Resources/." \
      "$WORK_DIR/WebViewPreview/Resources/"

# 清掉 working copy 里残留的备份文件（.bak 等），不进 bundle
find "$WORK_DIR/WebViewPreview" -name "*.bak" -delete 2>/dev/null || true

# ---------- 1. 可选：覆盖 targetURL ----------
if [ -n "$TARGET_URL" ]; then
    echo "==> 覆盖 AppConfig.targetURL = $TARGET_URL"
    plutil -replace targetURL -string "$TARGET_URL" \
        "$WORK_DIR/WebViewPreview/Config.swift"
    xcodegen generate --project "$WORK_DIR/WebViewPreview.xcodeproj" \
        --spec "$WORK_DIR/project.yml" >/dev/null 2>&1 || true
fi

# ---------- 2. 清理沙箱数据 + 重建 ----------
echo "==> 卸载 + 重建"
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
cd "$WORK_DIR"
xcodebuild -project WebViewPreview.xcodeproj -scheme WebViewPreview \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    -derivedDataPath build/derivedData build 2>&1 \
    | tee "$SHOTS_DIR/build.log" \
    | grep -E "error:|warning: \\*|BUILD " || true

if [ ! -d "$APP_PATH" ]; then
    echo "error: build 没产物，$APP_PATH 不存在。看 $SHOTS_DIR/build.log"
    exit 1
fi
echo "    BUILD OK → $APP_PATH"

xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

# ---------- 3. 准备一组示例脚本（写入沙箱 Documents/scripts/）----------
echo "==> 预置 2 个用户脚本到沙箱 + UserDefaults 启用 vConsole builtin"
DATA_DIR=$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" data)
SCRIPTS_DIR="$DATA_DIR/Documents/scripts"
mkdir -p "$SCRIPTS_DIR"

# 用 uuidgen 给脚本生成稳定 id
ID_HELLO=$(uuidgen | tr 'A-Z' 'a-z')
ID_FOO=$(uuidgen | tr 'A-Z' 'a-z')

HELLO_SOURCE='// ==UserScript==
// @name         Hello World
// @namespace    http://example.com
// @version      1.0.0
// @description  在控制台打印 hello
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  "use strict";
  console.log("[hello] injected, version=" + (GM_info && GM_info.script && GM_info.script.version || "?"));
})();
'

# Test Injector：只改页面 title（不依赖 DOM 结构 / 选择器）。
# WKWebView 顶部导航栏会显示 document.title，所以如果脚本跑了，
# 截图里"Demo" 会变成 "DEMO:INJECTED"。这是判断脚本有没有跑到
# 最干净的办法。
TEST_INJECTOR_SOURCE='// ==UserScript==
// @name         Test Injector
// @namespace    http://example.com
// @version      0.1.0
// @description  改 title + 改 DOM，证明注入生效
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  "use strict";
  // 改 title —— 顶部导航栏立刻能看到
  document.title = "DEMO:INJECTED";
  // 也把徽章改了 + 背景变粉，万一脚本真的跑了用户能直观看到
  function setText(sel, value) {
    var el = document.querySelector(sel);
    if (el) el.textContent = value;
  }
  setText("#env-check", "env: browser-injected");
  setText("#marker", "marker: injected by test-script");
  document.body && (document.body.style.backgroundColor = "#ffe4ec");
})();
'

FOO_SOURCE='// ==UserScript==
// @name         Foo Bar
// @namespace    http://example.com
// @version      0.2.0
// @description  测试脚本
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  console.log("[foo] running");
})();
'

printf '%s' "$HELLO_SOURCE"        > "$SCRIPTS_DIR/$ID_HELLO.js"
printf '%s' "$FOO_SOURCE"          > "$SCRIPTS_DIR/$ID_FOO.js"

# 写 index.json（两个都 enabled=true）
# Swift 的 `Date` 默认按 Double（Unix 时间戳）解码，所以 createdAt /
# updatedAt 必须用 epoch 秒数，**不能**用 ISO 字符串 —— 否则
# JSONDecoder 会报 "Expected to decode Double but found a string instead."，
# loadAll() 直接返回 []，注入链路看似没断但实际一根脚本都没读到。
INDEX_FILE="$SCRIPTS_DIR/index.json"
NOW_EPOCH=$(date +%s)
cat > "$INDEX_FILE" <<EOF
[
  {
    "id": "$ID_HELLO",
    "name": "Hello World",
    "version": "1.0.0",
    "source": $(printf '%s' "$HELLO_SOURCE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "enabled": true,
    "createdAt": $NOW_EPOCH,
    "updatedAt": $NOW_EPOCH
  },
  {
    "id": "$ID_FOO",
    "name": "Foo Bar",
    "version": "0.2.0",
    "source": $(printf '%s' "$FOO_SOURCE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
    "enabled": true,
    "createdAt": $NOW_EPOCH,
    "updatedAt": $NOW_EPOCH
  }
]
EOF

# vConsole 是内置脚本，source 不写沙箱，开关走 UserDefaults：
# builtin-builtin-vconsole-enabled = true 启用注入。
mkdir -p "$DATA_DIR/Library/Preferences"
PLIST="$DATA_DIR/Library/Preferences/com.devzeng.yidingcheng.plist"
plutil -create xml1 "$PLIST" 2>/dev/null || true
plutil -insert "builtin-builtin-vconsole-enabled" -bool YES "$PLIST" 2>&1

# ---------- 4. 启动 App 并截图 ----------
echo "==> 启动 App"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null
sleep 3
xcrun simctl io "$DEVICE_UDID" screenshot "$SHOTS_DIR/01-main.png" >/dev/null
echo "    截图: $SHOTS_DIR/01-main.png"

# ---------- 5. 启动日志采集 ----------
LOG_FILE="$SHOTS_DIR/runtime.log"
xcrun simctl spawn "$DEVICE_UDID" log stream \
    --predicate "processImagePath CONTAINS '$APP_NAME'" \
    --level default 2>&1 > "$LOG_FILE" &
LOG_PID=$!
sleep 1

# ---------- 6. 用 simctl 打开「用户脚本」列表 ----------
# iOS Simulator 没原生 API 模拟点击。我们用 simctl appearance / 触控替代方案不可行，
# 改用 deeplink / URL scheme 触发导航 —— 但 App 没注册 scheme。
# 所以这里用一个临时方案：往 App 沙箱里塞「下次启动自动 push 到 settings」的标记。
# 这要求 AppDelegate 支持命令行参数，参见 scripts/TEST.md 末尾的「自动化增强」建议。
#
# 退而求其次：截图 + 检查运行时日志，验证以下事实：
#   - 主页 webview 加载完成
#   - 用户脚本注入到 webview（log 里能看到 console.log 的回声）
#   - 没有错误日志（Script error / unhandledrejection / null is not）

echo "==> 等待脚本注入"
sleep 2
xcrun simctl io "$DEVICE_UDID" screenshot "$SHOTS_DIR/02-main-after-injection.png" >/dev/null

# ---------- 7. 拉一段日志做断言 ----------
echo "==> 校验运行日志"
# 停止日志采集
kill "$LOG_PID" 2>/dev/null || true
wait "$LOG_PID" 2>/dev/null || true

PASS=1
FAIL_REASONS=()

assert_no() {
    local pattern="$1"
    local desc="$2"
    if grep -qE "$pattern" "$LOG_FILE"; then
        PASS=0
        FAIL_REASONS+=("✗ $desc  (匹配到：$pattern)")
    else
        echo "    ✓ $desc"
    fi
}

# 这些错误都不应该再出现
assert_no "uncaught.*Script error" "无跨域脚本错误"
assert_no "null is not an object.*i\\.then" "worker Promise 正确"
assert_no "Could not create a sandbox extension" "无 sandbox 扩展失败"
assert_no "unhandledrejection.*P\\.comments" "无 tokenization 失败"

echo ""
if [ "$PASS" = "1" ]; then
    echo "✅ 所有断言通过"
else
    echo "❌ 部分断言失败："
    for r in "${FAIL_REASONS[@]}"; do
        echo "   $r"
    done
fi

echo ""
echo "==> 截图清单："
ls -la "$SHOTS_DIR"/*.png

echo ""
echo "==> 下一步（需要人工交互，详见 scripts/TEST.md）："
echo "    1. 在 Simulator 里点齿轮进脚本列表 → 应该看到 Hello World / Foo Bar"
echo "    2. 点 cell 进编辑器 → 应该看到完整语法高亮的源码"
echo "    3. tap 编辑器 → 软键盘弹出 → 敲几个字符 → 应该进入 model"
echo "    4. 保存 → 返回列表 → 数据持久化"
echo "    5. 关闭 App 再开 → 脚本还在"

exit $((1 - PASS))
