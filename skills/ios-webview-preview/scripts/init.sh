#!/bin/bash

# Initialize the WebViewPreview project from template

WORK_DIR="$HOME/.ios-webview-preview"

# Resolve the script's own directory so TEMPLATE_DIR works no matter where the
# skill is installed (plugin marketplace, manual clone, symlink, etc.).
# ${BASH_SOURCE[0]} is used instead of $0 to handle `bash init.sh` and stdin invocation.
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template"

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen is not installed"
    echo "Install it with: brew install xcodegen"
    exit 1
fi

# Check if template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: Template not found at $TEMPLATE_DIR"
    exit 1
fi

# Create working directory if it doesn't exist
if [ ! -d "$WORK_DIR" ]; then
    echo "Creating working directory: $WORK_DIR"
    mkdir -p "$WORK_DIR"
fi

# Copy template to working directory
echo "Copying template to $WORK_DIR..."
cp -r "$TEMPLATE_DIR"/* "$WORK_DIR/"

# Generate Xcode project with xcodegen
echo "Generating Xcode project..."
cd "$WORK_DIR"
xcodegen generate

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate Xcode project"
    exit 1
fi

echo "Project initialized successfully at $WORK_DIR"
