#!/usr/bin/env bash
# 把 template/example/*.user.js 注入到模拟器 App 沙箱的 Documents/scripts/，
# 并在 index.json 注册为 enabled。这样测试脚本在 Settings → 用户脚本里
# 看得到、能在所有页面加载时跑（用户也能在 UI 里手动开关）。
#
# ⚠️ 仅 skill / native 扩展开发时用——验证 $app.<plugin> 工作是否正常。
#    run.sh 不会自动调用（生产使用不要碰 example/）。
#
# 流程：
#   1. 找 booted Simulator（可显式传 UDID 作为参数 1）
#   2. 找 App 沙箱（要先 simctl install 一次）
#   3. 对每个 example/*.user.js：
#      - 计算 stable id（MD5(filename) → UUID 格式）保证幂等
#      - 从源码头部 `// @name` 解析显示名
#      - 写到 `<sandbox>/Documents/scripts/<id>.js`
#      - 在 `<sandbox>/Documents/scripts/index.json` 注册 / 更新 entry（保留 enabled 状态）
#
# 不依赖 init.sh / build.sh / run.sh——只要 App 装好了就能跑。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../template"
EXAMPLE_DIR="$TEMPLATE_DIR/example"
BUNDLE_ID="com.devzeng.yidingcheng"

DEVICE_UDID="${1:-}"
if [ -z "$DEVICE_UDID" ]; then
    DEVICE_UDID=$(xcrun simctl list devices booted | awk -F'[()]' '/Booted/{print $2; exit}')
fi
if [ -z "$DEVICE_UDID" ]; then
    echo "error: 没有 booted Simulator，先 xcrun simctl boot 'iPhone 16 Pro' 一下。" >&2
    exit 1
fi
if [ ! -d "$EXAMPLE_DIR" ]; then
    echo "error: 找不到 $EXAMPLE_DIR" >&2
    exit 1
fi

DOCS=$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" data 2>/dev/null || true)
if [ -z "$DOCS" ]; then
    echo "error: 找不到 App 沙箱（bundle id $BUNDLE_ID）。先 install 一次再跑。" >&2
    exit 1
fi

SCRIPTS_DIR="$DOCS/Documents/scripts"
INDEX_FILE="$SCRIPTS_DIR/index.json"
mkdir -p "$SCRIPTS_DIR"

# 主逻辑：一个 Python 脚本处理所有 .user.js 的拷贝 + index.json 合并。
# 输出每行：'<id>  <@name>' —— 让外层可以打印进度。
python3 - "$EXAMPLE_DIR" "$SCRIPTS_DIR" "$INDEX_FILE" <<'PY'
import json, sys, os, hashlib, re

example_dir, scripts_dir, index_file = sys.argv[1], sys.argv[2], sys.argv[3]

def stable_uuid(name: str) -> str:
    h = hashlib.md5(name.encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"

def parse_metadata(source: str, fallback_name: str):
    name, desc = None, None
    version = "0.0.0"
    for line in source.splitlines()[:60]:
        m = re.match(r'^\s*//\s*@(\w+)\s+(.*?)\s*$', line)
        if not m: continue
        key, val = m.group(1).lower(), m.group(2)
        if key == "name" and val: name = val
        elif key == "version" and val: version = val
        elif key == "description" and val: desc = val
    return name or fallback_name, version, desc

# 读现有 index.json
if os.path.exists(index_file):
    try:
        with open(index_file) as f: entries = json.load(f)
        if not isinstance(entries, list): entries = []
    except json.JSONDecodeError:
        entries = []
else:
    entries = []

existing_by_id = {e["id"]: e for e in entries if "id" in e}
# Swift JSONDecoder 默认按 Double (Unix epoch 秒) 解 `Date`。
# 写成 ISO 字符串会让 JSONDecoder 抛 "Expected to decode Double but found a string"，
# loadUserScripts() 失败静默返回 [] —— 用户脚本全部消失。
now = 1735689600.0  # 2025-01-01T00:00:00Z 的 epoch

count = 0
for fname in sorted(os.listdir(example_dir)):
    if not fname.endswith(".user.js"): continue
    src_path = os.path.join(example_dir, fname)
    if not os.path.isfile(src_path): continue
    source = open(src_path).read()
    fallback_name = os.path.splitext(fname)[0]
    name, version, desc = parse_metadata(source, fallback_name)
    script_id = stable_uuid(fname)

    # 拷贝 source 到沙箱
    dst_path = os.path.join(scripts_dir, script_id + ".js")
    with open(dst_path, "w") as f: f.write(source)

    # 合并到 index.json
    prev = existing_by_id.get(script_id)
    if prev:
        prev["name"] = name
        prev["version"] = version
        if desc: prev["description"] = desc  # 保留外部字段
        prev["source"] = source
        prev["updatedAt"] = now
    else:
        entries.append({
            "id": script_id, "name": name, "version": version,
            "source": source, "enabled": True,
            "createdAt": now, "updatedAt": now,
        })
    count += 1
    print(f"{script_id}  {name}")

with open(index_file, "w") as f:
    json.dump(entries, f, indent=2)

sys.stderr.write(f"installed {count} example script(s)\n")
PY

echo "✓ installed $(ls -1 "$EXAMPLE_DIR"/*.user.js 2>/dev/null | wc -l | tr -d ' ') test script(s) to sandbox"
echo "  → Settings → 用户脚本 里能看到、可以手动开关"