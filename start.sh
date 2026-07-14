#!/bin/bash
# Switex 启动器 — 启动 OCR 后端 + SwiftUI 菜单栏 App
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "════════════════════════════════"
echo "  Switex — 本地数学公式 OCR"
echo "════════════════════════════════"
echo ""

# 1. 启动 OCR 后端
echo "[1/2] 启动 OCR 后端..."
PYTHONPATH="" "$DIR/backend/venv/bin/python" "$DIR/backend/server.py" &
BACKEND_PID=$!
sleep 2

# 检查后端
if curl -s http://127.0.0.1:8765/health > /dev/null 2>&1; then
    echo "  ✅ 后端已就绪 (http://127.0.0.1:8765)"
else
    echo "  ⚠️  后端启动中，稍后会自动连接"
fi

# 2. 编译并启动 SwiftUI App
echo "[2/2] 启动菜单栏 App..."
cd "$DIR/switex"
swift build --quiet 2>/dev/null
open .build/debug/switex

echo ""
echo "════════════════════════════════"
echo "  Switex 已启动！"
echo "  点击菜单栏 ƒ 图标使用"
echo "  按 Ctrl+C 停止"
echo "════════════════════════════════"
echo ""

trap "kill $BACKEND_PID 2>/dev/null; exit 0" INT
wait $BACKEND_PID
