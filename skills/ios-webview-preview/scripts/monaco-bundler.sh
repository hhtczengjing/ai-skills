#!/bin/bash
# 把 monaco-editor npm 包下载、裁剪、写入模板的 Resources/Monaco/。
# 正常升级或首次拉取时手动跑一次即可，不需要每次 init.sh 跑。
#
# 用法：bash scripts/monaco-bundler.sh [version]
#   默认 monaco-editor@0.45.0
set -euo pipefail

VERSION="${1:-0.45.0}"

# Resolve template dir regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/../template" && pwd)"
DEST="$TEMPLATE_DIR/WebViewPreview/Resources/Monaco"

if [ ! -d "$TEMPLATE_DIR/WebViewPreview" ]; then
  echo "Error: template dir not found at $TEMPLATE_DIR/WebViewPreview" >&2
  exit 1
fi

# Check node/npm.
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is required (install Node.js)" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
echo "[monaco] packing monaco-editor@$VERSION ..."
npm pack "monaco-editor@$VERSION" --silent

TARBALL="$(ls monaco-editor-*.tgz | head -1)"
echo "[monaco] extracting $TARBALL ..."
tar -xzf "$TARBALL"

if [ ! -d package/min/vs ]; then
  echo "Error: package/min/vs not found in tarball — package layout changed?" >&2
  exit 1
fi

# Wipe previous bundle then copy.
rm -rf "$DEST/js"
mkdir -p "$DEST/js"
cp -R package/min/vs "$DEST/js/vs"

# Trim language services that ship with a web worker (we don't run workers
# under file://). JS-only is enough for userscripts.
echo "[monaco] trimming worker-backed languages ..."
rm -rf \
  "$DEST/js/vs/language/typescript" \
  "$DEST/js/vs/language/json" \
  "$DEST/js/vs/language/css" \
  "$DEST/js/vs/language/html"

# Drop non-English NLS bundles (~1.7 MB). editor.main.js falls back to the
# default English nls.js when a locale is missing.
echo "[monaco] trimming non-English NLS bundles ..."
find "$DEST/js/vs/editor" -maxdepth 1 -name 'editor.main.nls.*.js' -delete

# Drop all basic-languages except javascript (~636 KB → ~8 KB).
# We only need JS syntax highlighting; the other languages add zero value
# to userscripts and inflate the bundle.
echo "[monaco] trimming non-javascript basic languages ..."
find "$DEST/js/vs/basic-languages" -mindepth 1 -maxdepth 1 \
  ! -name 'javascript' -exec rm -rf {} +

# Remove now-empty placeholder directories.
rmdir "$DEST/js/vs/language" 2>/dev/null || true

# Sanity check.
for required in \
  "$DEST/js/vs/loader.js" \
  "$DEST/js/vs/editor/editor.main.js" \
  "$DEST/js/vs/basic-languages/javascript/javascript.js"
do
  if [ ! -f "$required" ]; then
    echo "Error: required file missing after copy: $required" >&2
    exit 1
  fi
done

SIZE="$(du -sh "$DEST/js/vs" | awk '{print $1}')"
echo "[monaco] vendored to $DEST/js/vs ($SIZE)"

# Soft warning if bundle is bigger than expected.
SIZE_BYTES="$(du -sk "$DEST/js/vs" | awk '{print $1}')"
if [ "$SIZE_BYTES" -gt 5120 ]; then
  echo "[monaco] WARNING: bundle exceeds 5 MB — check what got pulled in" >&2
fi

echo "[monaco] done. Editor host page lives at Resources/Monaco/editor.html."
