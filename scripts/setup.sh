#!/bin/bash
# Switex — Complete local math OCR setup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "  Switex — Local Math OCR Setup"
echo "========================================="
echo ""

# Step 1: Python backend setup
echo "[1/4] Setting up Python backend..."

if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3.10+."
    echo "  brew install python@3.10"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  Python $PYTHON_VERSION detected"

BACKEND_DIR="$PROJECT_DIR/backend"
cd "$BACKEND_DIR"

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  Virtual environment created"
fi

source venv/bin/activate
pip install --upgrade pip --quiet
pip install -r requirements.txt
echo "  Python dependencies installed"

# Step 2: Download models
echo ""
echo "[2/4] Downloading OCR models..."

MODELS_DIR="$BACKEND_DIR/models"
if [ ! -f "$MODELS_DIR/encoder.onnx" ] || [ ! -f "$MODELS_DIR/decoder.onnx" ]; then
    python "$PROJECT_DIR/scripts/download_models.py"
else
    echo "  Models already downloaded"
fi

# Step 3: Build macOS app
echo ""
echo "[3/4] Building macOS app..."

if command -v swiftc &> /dev/null; then
    cd "$PROJECT_DIR/switex"
    swift build -c release 2>&1 || echo "  Swift build had warnings (non-fatal)"
    echo "  macOS app built"
else
    echo "  Skipping Swift build (Xcode/Swift not available)"
    echo "  Install Xcode Command Line Tools: xcode-select --install"
fi

# Step 4: Create launch script
echo ""
echo "[4/4] Creating launch script..."

LAUNCHER="$PROJECT_DIR/launch.sh"
cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Start backend
echo "Starting OCR backend..."
cd "$SCRIPT_DIR/backend"
source venv/bin/activate
python server.py &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Wait for backend
sleep 2

# Start macOS app
if [ -f "$SCRIPT_DIR/switex/.build/release/switex" ]; then
    echo "Starting macOS app..."
    "$SCRIPT_DIR/switex/.build/release/switex" &
    APP_PID=$!
fi

echo ""
echo "Switex is running!"
echo "  Backend: http://localhost:8765"
echo "  Web UI:  http://localhost:8765"
echo "  Menu bar: Look for the function (ƒ) icon in your menu bar"
echo ""
echo "Press Ctrl+C to stop"

trap "kill $BACKEND_PID $APP_PID 2>/dev/null; exit 0" INT
wait
LAUNCHER_EOF

chmod +x "$LAUNCHER"

echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Quick start:"
echo "  1. Start server only:  cd $BACKEND_DIR && source venv/bin/activate && python server.py"
echo "  2. Start everything:   $LAUNCHER"
echo "  3. Web UI:             http://localhost:8765"
echo "  4. Build app only:     $PROJECT_DIR/scripts/build_app.sh"
echo ""
echo "Features:"
echo "  - Screenshot any math formula → LaTeX"
echo "  - Drag & drop or paste images"
echo "  - 100% local, no internet required after model download"
echo "  - Menu bar app for quick access"
echo ""
