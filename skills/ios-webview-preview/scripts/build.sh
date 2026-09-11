#!/bin/bash

# Build the 壹定橙 project

WORK_DIR="$HOME/.ios-webview-preview"
DEVICE_NAME="$1"
SCHEME="WebViewPreview"
CONFIGURATION="Debug"
PROJECT_NAME="WebViewPreview"

# Default device
if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME="iPhone 16 Pro"
fi

# Check if project exists
if [ ! -d "$WORK_DIR/$PROJECT_NAME.xcodeproj" ]; then
    echo "Error: Project not found at $WORK_DIR"
    echo "Run init.sh first to initialize the project"
    exit 1
fi

# Get device UDID (try name first, then UDID directly)
DEVICE_UDID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | grep -v "unavailable" | head -1 | grep -oE '[A-Fa-f0-9-]{36}')

# If not found by name, check if it's a valid UDID
if [ -z "$DEVICE_UDID" ]; then
    # Check if the input is already a UDID format
    if [[ "$DEVICE_NAME" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
        DEVICE_UDID="$DEVICE_NAME"
    else
        echo "Error: Device not found: $DEVICE_NAME"
        echo ""
        echo "Available devices:"
        xcrun simctl list devices | grep -E "iPhone|iPad" | grep -v "unavailable"
        exit 1
    fi
fi

echo "Building for device: $DEVICE_NAME ($DEVICE_UDID)"

# Build the project
cd "$WORK_DIR"
xcodebuild \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "id=$DEVICE_UDID" \
    -quiet \
    build

if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

echo "Build successful"
echo "$DEVICE_UDID" > /tmp/webview-preview-device-udid.txt
