#!/usr/bin/env python3
"""
Switex model downloader — pre-warm the ONNX models.
Copyright (c) 2026 J1chi

pix2tex auto-downloads its weights from Hugging Face (public repo)
on first use. This script triggers that download so the first
OCR request doesn't have to wait.
"""

import sys
import os

print("Switex Model Pre-warm")
print("=" * 40)
print()
print("pix2tex (LaTeX-OCR by lukas-blecher) downloads weights automatically")
print("from Hugging Face on first use (~200 MB).")
print()
print("Triggering download now...")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
from ocr_engine import get_ocr_engine

engine = get_ocr_engine()
engine.load()

print()
print("Model loaded successfully!")
print("You're all set — no internet needed for future runs.")
print("Run: cd backend && source venv/bin/activate && python server.py")
