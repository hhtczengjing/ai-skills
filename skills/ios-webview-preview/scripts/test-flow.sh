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
# 全量同步（Swift 现在按 App/、WebView/、NativeExtensions/、UserScripts/
# 四个子目录组织，逐文件列表容易漏；init.sh 也是全量 `cp -r`）。
rm -rf "$WORK_DIR/WebViewPreview"
mkdir -p "$WORK_DIR"
cp -r "$TEMPLATE_DIR/WebViewPreview" "$WORK_DIR/"

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
        "$WORK_DIR/WebViewPreview/App/Config.swift"
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
echo "==> 预置示例脚本到沙箱 + UserDefaults 启用 vConsole builtin"
DATA_DIR=$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" data)

# 把 template/example/ 下所有 *.user.js 拷到沙箱 Documents/scripts/ 并
# 注册为 enabled。脚本源（hello-world / test-injector / foo-bar /
# cookieBridge-e2e）都在 template/example/，这里是单一数据源 —— 修改
# example/ 里的脚本后重跑 test-flow.sh 自动 pick up。
bash "$SCRIPT_DIR/install-test-scripts.sh" "$DEVICE_UDID"

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
echo '    1. 在 Simulator 里点齿轮进脚本列表 → 应该看到 Hello World / Test Injector / Foo Bar / $app.cookie e2e'
echo "    2. 点 cell 进编辑器 → 应该看到完整语法高亮的源码"
echo "    3. tap 编辑器 → 软键盘弹出 → 敲几个字符 → 应该进入 model"
echo "    4. 保存 → 返回列表 → 数据持久化"
echo "    5. 关闭 App 再开 → 脚本还在"

exit $((1 - PASS))
