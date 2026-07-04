"""
100% local math OCR engine using pix2tex (LaTeX-OCR).
Copyright (c) 2026 J1chi
Model weights shipped with pip install.
"""

import io
import os
import logging
from typing import Optional

from PIL import Image

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ocr")

_model: Optional["LatexOCR"] = None


class LatexOCR:
    """LaTeX OCR using pix2tex / LaTeX-OCR (lukas-blecher)."""

    def __init__(self):
        self.model = None
        self._loaded = False

    def load(self):
        if self._loaded:
            return

        logger.info("Loading pix2tex model...")

        try:
            from pix2tex.cli import LatexOCR as Pix2texModel
            self.model = Pix2texModel()
            self._loaded = True
            logger.info("pix2tex model loaded successfully")
        except ImportError:
            raise ImportError(
                "pix2tex not installed. Run: pip install pix2tex"
            )
        except Exception as e:
            raise RuntimeError(f"Failed to load pix2tex model: {e}")

    def image_to_latex(self, image: Image.Image) -> str:
        self.load()

        if image.mode != "RGB":
            image = image.convert("RGB")

        try:
            raw = self.model(image)
            return self._postprocess(raw)
        except Exception as e:
            logger.exception("OCR inference failed")
            raise RuntimeError(f"Inference failed: {e}")

    def image_to_latex_confidence(self, image: Image.Image) -> dict:
        latex = self.image_to_latex(image)
        conf = self._compute_confidence(latex)
        return {"latex": latex, "confidence": conf}

    def _postprocess(self, latex: str) -> str:
        if latex is None:
            return ""
        # Strip whitespace only — no regex on potentially weird LaTeX
        latex = latex.strip()
        # Collapse multiple spaces into one (plain str, not regex)
        while "  " in latex:
            latex = latex.replace("  ", " ")
        # Fix backslash-space artifacts
        latex = latex.replace("\\ ", " ")
        return latex

    def _compute_confidence(self, latex: str) -> float:
        if not latex or len(latex) < 2:
            return 0.0
        score = min(1.0, len(latex) / 150.0)
        if "\\" in latex:
            score = min(1.0, score + 0.1)
        if any(c in latex for c in ["\\frac", "\\sum", "\\int", "\\sqrt", "\\alpha"]):
            score = min(1.0, score + 0.1)
        return round(score, 4)


def get_ocr_engine() -> LatexOCR:
    global _model
    if _model is None:
        _model = LatexOCR()
    return _model


def convert_image_to_latex(image_data: bytes) -> dict:
    image = Image.open(io.BytesIO(image_data))
    engine = get_ocr_engine()
    return engine.image_to_latex_confidence(image)
