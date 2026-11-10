#!/bin/bash

# Update the target URL in Config.swift

WORK_DIR="$HOME/.ios-webview-preview"
# Config.swift 位于 App/ 子目录（重构后的目录结构）。
CONFIG_FILE="$WORK_DIR/WebViewPreview/App/Config.swift"
NEW_URL="$1"

if [ -z "$NEW_URL" ]; then
    echo "Error: URL parameter is required"
    echo "Usage: $0 <url>"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config.swift not found at $CONFIG_FILE"
    echo "Run init.sh first to initialize the project"
    exit 1
fi

# Direct file generation — avoids sed escaping issues with special characters
cat > "$CONFIG_FILE" << EOF
import Foundation

enum AppConfig {
    // 这个 URL 会被 skill 脚本动态替换
    static var targetURL = "$NEW_URL"
}
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to update URL"
    echo "Check that URL doesn't contain unescaped special characters"
    exit 1
fi

echo "Updated target URL to: $NEW_URL"
