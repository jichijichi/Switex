#!/bin/bash
# Switex 启动器 — 双击即可启动
DIR="$(cd "$(dirname "$0")" && pwd)"

# 启动 OCR 后端
PYTHONPATH="" "$DIR/backend/venv/bin/python" "$DIR/backend/server.py" &
sleep 2

# 编译并启动 SwiftUI App
cd "$DIR/switex"
swift build --quiet 2>/dev/null
open .build/debug/switex

echo "Switex 已启动 — 点击菜单栏 ƒ 图标使用"
