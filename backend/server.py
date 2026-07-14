#!/usr/bin/env python3
"""
Switex OCR server — FastAPI HTTP backend for the SwiftUI menu bar app.
Copyright (c) 2026 J1chi
"""

import io
import logging
import sys
import os

from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import uvicorn

sys.path.insert(0, os.path.dirname(__file__))
from ocr_engine import get_ocr_engine, convert_image_to_latex

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("server")

app = FastAPI(title="Switex OCR", version="1.0.0")
engine = get_ocr_engine()


@app.on_event("startup")
async def startup():
    logger.info("Loading OCR model...")
    engine.load()
    logger.info("Model loaded. Ready on http://127.0.0.1:8765")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/ocr")
async def ocr(file: UploadFile = File(...)):
    try:
        image_data = await file.read()
        result = convert_image_to_latex(image_data)
        return JSONResponse(result)
    except Exception as e:
        logger.exception("OCR failed")
        return JSONResponse({"error": str(e)}, status_code=500)


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8765, log_level="info")
