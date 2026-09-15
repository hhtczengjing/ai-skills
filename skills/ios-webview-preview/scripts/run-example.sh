#!/usr/bin/env bash
# 一键跑示例工程：
#   1. 项目不存在 → 拷贝 template → ~/.ios-webview-preview/，xcodegen 生成
#   2. xcodebuild 编译
#   3. simctl install（uninstall 清空沙箱保证从干净状态起）
#   4. 把 template/example/*.user.js 拷贝到沙箱 Documents/scripts/ 并注册到 index.json
#   5. simctl launch
#
# 用法：
#   bash scripts/run-example.sh                 # 用当前 booted simulator
#   bash scripts/run-example.sh "iPhone 16 Pro" # 指定设备名/UDID
#
# 改了 template/example/ 里的脚本 或 Swift 代码 → 都跑这个脚本。init.sh /
# build.sh / run.sh / install-test-scripts.sh 都收敛在这一条命令里。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template"
EXAMPLE_DIR="$TEMPLATE_DIR/example"
WORK_DIR="$HOME/.ios-webview-preview"
BUNDLE_ID="com.devzeng.yidingcheng"
APP_NAME="壹定橙"

# ---------- Simulator ----------
DEVICE_UDID="${1:-}"
if [ -z "$DEVICE_UDID" ]; then
    DEVICE_UDID=$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/{print $2; exit}')
fi
if [ -z "$DEVICE_UDID" ]; then
    echo "error: 没有 booted Simulator。先 xcrun simctl boot 'iPhone 16 Pro' 一下。" >&2
    exit 1
fi
if [ ! -d "$EXAMPLE_DIR" ]; then
    echo "error: 找不到 $EXAMPLE_DIR" >&2
    exit 1
fi

echo "==> Simulator: $DEVICE_UDID"
echo "==> Example scripts dir: $EXAMPLE_DIR"

# ---------- 1. 项目初始化（一次性） ----------
if [ ! -d "$WORK_DIR/WebViewPreview" ]; then
    echo "==> init: 拷贝 template → $WORK_DIR"
    mkdir -p "$WORK_DIR"
    cp -r "$TEMPLATE_DIR"/* "$WORK_DIR/"
fi

# 每次都 regenerate xcodeproj —— 改了 project.yml / 加新 Swift 文件 / 改了
# Resources 都要重新生成。xcodegen 跑 < 1s，比手动维护 xcodeproj 省事。
echo "==> xcodegen generate"
(cd "$WORK_DIR" && xcodegen generate >/dev/null)

# ---------- 2. Build ----------
echo "==> xcodebuild"
xcodebuild -project "$WORK_DIR/WebViewPreview.xcodeproj" \
    -scheme WebViewPreview -destination "id=$DEVICE_UDID" \
    -configuration Debug build >/dev/null

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -type d \
    | grep -v Index.noindex | head -1)
if [ -z "$APP_PATH" ]; then
    echo "error: build 没产物（${APP_NAME}.app 不存在）。看上面 xcodebuild 的完整输出。" >&2
    exit 1
fi

# ---------- 3. Install（uninstall → install 清沙箱，确保从干净状态起） ----------
echo "==> install"
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall  "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install    "$DEVICE_UDID" "$APP_PATH"

# ---------- 4. 把 template/example/*.user.js 注入沙箱 ----------
echo "==> inject example scripts"
bash "$SCRIPT_DIR/install-test-scripts.sh" "$DEVICE_UDID"

# ---------- 5. Launch ----------
echo "==> launch"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"

echo ""
echo "✓ 全部跑完"
echo "  App PID：$(xcrun simctl spawn $DEVICE_UDID launchctl list 2>/dev/null | grep $BUNDLE_ID | awk '{print $1}' | head -1)"
echo "  截图：xcrun simctl io $DEVICE_UDID screenshot /tmp/shot.png"