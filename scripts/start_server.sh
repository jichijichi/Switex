#!/bin/bash
# Start the switex OCR backend server
# Requires server.py in the backend/ directory.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"

cd "$BACKEND_DIR"

# Check for server.py
if [ ! -f "server.py" ]; then
    echo "Error: server.py not found in backend/"
    echo "The FastAPI server has not been implemented yet."
    echo ""
    echo "Available alternatives:"
    echo "  1. Tkinter GUI:  bash launch.sh"
    echo "  2. SwiftUI app:   cd switex && swift run"
    echo "  3. Use the OCR engine directly:"
    echo "     cd backend && source venv/bin/activate"
    echo "     python -c \"from ocr_engine import convert_image_to_latex; print(convert_image_to_latex(open('test.png','rb').read()))\""
    exit 1
fi

# Check if virtualenv exists
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment…"
    python3 -m venv venv
    source venv/bin/activate
    echo "Installing dependencies…"
    pip install --upgrade pip
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

# Check if models are downloaded
if [ ! -f "models/encoder.onnx" ] || [ ! -f "models/decoder.onnx" ]; then
    echo "Models not found. Downloading…"
    python "$PROJECT_DIR/scripts/download_models.py"
fi

echo "Starting switex server on http://localhost:8765"
exec python server.py
