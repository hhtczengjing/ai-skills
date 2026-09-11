#!/bin/bash

# Run the 壹定橙 app on simulator

WORK_DIR="$HOME/.ios-webview-preview"
DEVICE_UDID="$1"

# Read UDID from file if not provided
if [ -z "$DEVICE_UDID" ]; then
    if [ -f /tmp/webview-preview-device-udid.txt ]; then
        DEVICE_UDID=$(cat /tmp/webview-preview-device-udid.txt)
    else
        echo "Error: Device UDID not provided and not found in /tmp/webview-preview-device-udid.txt"
        exit 1
    fi
fi

# Find the built app (exclude Index.noindex which is a stale build artifact)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "壹定橙.app" -type d | grep -v "Index.noindex" | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: App not found in DerivedData"
    echo "Run build.sh first"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Boot simulator if not already booted
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true

# Open Simulator app
open -a Simulator

# Wait a moment for simulator to be ready
sleep 2

# Install the app
echo "Installing app..."
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to install app"
    exit 1
fi

# Launch the app
echo "Launching app..."
xcrun simctl launch "$DEVICE_UDID" com.devzeng.yidingcheng

if [ $? -ne 0 ]; then
    echo "Error: Failed to launch app"
    exit 1
fi

echo "App launched successfully on simulator"
