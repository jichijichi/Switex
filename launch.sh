#!/bin/bash
# 启动 Switex 桌面应用
# 无需 web 服务器，GUI 直接调用 OCR 引擎

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR/backend"
source venv/bin/activate
python gui_app.py
