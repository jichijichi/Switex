# Switex

**100% local, offline math OCR for macOS — no cloud, no API keys, no data leaves your machine.**

Take a screenshot of any math formula (from a paper, whiteboard, textbook, website) and instantly convert it to LaTeX. The recognized LaTeX is copied directly to your clipboard — ready to paste into Overleaf, Typst, Markdown, or any math editor.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Development](#development)
- [Dependencies & Licenses](#dependencies--licenses)
- [Compliance & Attribution](#compliance--attribution)
- [License](#license)

---

## Quick Start

```bash
# One-command setup (installs deps, downloads models, builds app)
bash scripts/setup.sh

# Start the Tkinter desktop GUI (fully functional)
bash launch.sh

# Build and run the SwiftUI menu bar app
bash scripts/build_app.sh
./switex/.build/release/switex
```

> **Note:** The FastAPI web server (`server.py`) is not yet implemented. The Tkinter GUI (`launch.sh`) and SwiftUI menu bar app are the working frontends.

---

## Features

- **Screenshot OCR** — capture any region of the screen, get LaTeX back
- **Drag & drop** — drop an image file directly onto the app
- **Clipboard paste** — Cmd+V a math screenshot, get LaTeX instantly
- **Web UI** — full-featured browser interface at `http://localhost:8765`
- **Native macOS apps** — both a SwiftUI menu bar app (ƒ icon) and a Python Tkinter GUI
- **Confidence scoring** — know how reliable each recognition is
- **Completely offline** — all inference runs locally on your Mac; no internet needed after model download

---

## Architecture

```
┌─────────────────────────┐     HTTP :8765     ┌──────────────────────┐
│   macOS Menu Bar App    │ ──────────────────> │   Python OCR Server  │
│   (SwiftUI)             │ <────────────────── │   (FastAPI + ONNX)   │
│                         │     JSON            │                      │
│  • Screenshot capture   │                     │  • pix2tex ONNX      │
│  • Drag & drop          │                     │  • Image preprocessing│
│  • Clipboard paste      │                     │  • LaTeX decoding    │
│  • Result copy          │                     │                      │
└─────────────────────────┘                     └──────────────────────┘
```

Switex has **two frontends** that both talk to the same backend:

| Frontend | Technology | Start with |
|----------|-----------|------------|
| **Menu bar app** | SwiftUI (macOS native) | `bash launch.sh` or run the built binary |
| **Web UI** | FastAPI built-in | `bash scripts/start_server.sh` → http://localhost:8765 |
| **Desktop GUI** | Python Tkinter | `cd backend && source venv/bin/activate && python gui_app.py` |

---

## Project Structure

```
switex/
├── backend/                    # Python OCR backend
│   ├── server.py               # FastAPI HTTP server (with web UI)
│   ├── ocr_engine.py           # ONNX inference engine (pix2tex wrapper)
│   ├── gui_app.py              # Tkinter desktop GUI (standalone)
│   ├── models/                  # Downloaded ONNX model files
│   │   ├── encoder.onnx
│   │   └── decoder.onnx
│   ├── requirements.txt        # Python dependencies
│   ├── venv/                   # Python virtual environment (auto-created)
│   └── __pycache__/
├── switex/                     # macOS SwiftUI menu bar app
│   ├── Sources/
│   │   └── switex.swift        # Complete SwiftUI app (~500 lines)
│   ├── Package.swift            # Swift Package Manager manifest
│   └── README.md
├── Switex.app/                 # Pre-built macOS app bundle
│   └── Contents/
│       └── Info.plist
├── scripts/                    # Automation scripts
│   ├── setup.sh                # Full one-command setup (deps + models + build)
│   ├── start_server.sh         # Start the OCR backend server
│   ├── build_app.sh            # Build the SwiftUI app with SPM
│   └── download_models.py      # Pre-warm model download from HuggingFace
├── launch.sh                   # Start the Tkinter GUI (legacy launcher)
├── README.md                   # This file
└── LICENSE                     # Project license
```

**Note:** `scripts/setup.sh` dynamically regenerates `launch.sh` on each run. Do not edit `launch.sh` directly — modify `scripts/setup.sh` instead.

---

## How It Works

1. **Capture** — screenshot or drop an image containing math
2. **Preprocess** — resize, normalize (ImageNet stats), convert to tensor
3. **Encode** — ResNet + Transformer encoder extracts visual features (ONNX runtime)
4. **Decode** — Transformer decoder generates LaTeX tokens autoregressively
5. **Postprocess** — clean up the output, compute confidence score

The model is based on the [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR) architecture by Lukas Blecher, exported to ONNX for fast CPU inference on Apple Silicon.

---

## Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| macOS | 14+ (Sonoma) | Required for SwiftUI menu bar app |
| Python | 3.10+ | `brew install python@3.10` |
| Disk space | ~500 MB | For ONNX model weights |
| Xcode CLT | Any recent | `xcode-select --install` (only for building Swift app) |

---

## Development

### Scripts Reference

| Script | Purpose |
|--------|---------|
| `bash scripts/setup.sh` | Full setup: venv, pip install, model download, Swift build, generate launch.sh |
| `bash scripts/start_server.sh` | Start FastAPI OCR server on :8765 |
| `bash scripts/build_app.sh` | Build SwiftUI menu bar app (arm64 release) |
| `python scripts/download_models.py` | Pre-warm ONNX model download from HuggingFace (~200 MB) |

### Running Components Individually

```bash
# Activate virtual environment first
cd backend && source venv/bin/activate

# Start the FastAPI server (with web UI)
python server.py

# Start the Tkinter desktop GUI
python gui_app.py
```

---

## Dependencies & Licenses

### Python Backend

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR) | ≥0.1.2 (installed: 0.1.4) | **MIT** | Math OCR engine (ViT → LaTeX) |
| [torch](https://pytorch.org/) | ≥2.1 | **BSD-3-Clause** | Deep learning framework |
| [torchvision](https://pytorch.org/vision/) | ≥0.16 | **BSD** | Image transforms for PyTorch |
| [pyobjc-framework-Quartz](https://pyobjc.readthedocs.io/) | ≥10.0 | **MIT** | macOS screenshot capture (Tkinter GUI) |
| [fastapi](https://fastapi.tiangolo.com/) | 0.133 (transitive) | **MIT** | HTTP API framework |
| [uvicorn](https://www.uvicorn.org/) | 0.41 (transitive) | **BSD** | ASGI server |
| [Pillow](https://python-pillow.org/) | 12.2 (transitive) | **MIT-CMU** | Image loading/manipulation |
| [pydantic](https://docs.pydantic.dev/) | 2.13 (transitive) | **MIT** | Data validation |
| [starlette](https://www.starlette.io/) | 1.0 (transitive) | **BSD** | ASGI toolkit (FastAPI dependency) |
| [python-multipart](https://github.com/Kludex/python-multipart) | 0.0.27 (transitive) | **Apache 2.0** | Multipart form parsing |
| [transformers](https://huggingface.co/docs/transformers) | 5.12 (transitive) | **Apache 2.0** | HuggingFace model hub integration |
| [x-transformers](https://github.com/lucidrains/x-transformers) | 0.15 (transitive) | **MIT** | Transformer variants (pix2tex dependency) |
| [timm](https://github.com/huggingface/pytorch-image-models) | 0.5 (transitive) | **Apache 2.0** | Image models (pix2tex dependency) |
| [albumentations](https://albumentations.ai/) | (transitive) | **MIT** | Image augmentation (pix2tex dependency) |
| [sympy](https://www.sympy.org/) | 1.14 (transitive) | **BSD** | Symbolic math (LaTeX parsing) |

### macOS SwiftUI App

| Framework | License | Purpose |
|-----------|---------|---------|
| SwiftUI | Apple (bundled with macOS) | UI framework |
| AppKit | Apple (bundled with macOS) | macOS native APIs |

### OCR Model

| Component | Source | License | Notes |
|-----------|--------|---------|-------|
| pix2tex weights | [lukas-blecher/LaTeX-OCR](https://huggingface.co/lukas-blecher/LaTeX-OCR) on HuggingFace | **MIT** | Downloaded automatically on first use (~200 MB) |

---

## Compliance & Attribution

### License Compatibility Summary

All dependencies use **permissive open-source licenses** (MIT, BSD-3-Clause, BSD, Apache 2.0). There are **no copyleft (GPL/AGPL)** dependencies, and **no proprietary/commercial restrictions**. This means Switex can be:

- Freely distributed and modified
- Used commercially
- Included in proprietary software (MIT/BSD allow sublicensing; Apache 2.0 requires patent grant retention)

### Attribution Requirements

The following upstream projects must be credited (MIT/BSD require retention of copyright notices):

| Project | Required Attribution |
|---------|---------------------|
| **pix2tex** (Lukas Blecher) | Copyright (c) 2021 Lukas Blecher — included in `backend/venv/.../pix2tex-0.1.4.dist-info/LICENSE` |
| **PyTorch** (Meta/Fair) | BSD-3-Clause — included in `backend/venv/.../torch-*.dist-info/licenses/LICENSE` |
| **FastAPI** (Sebastián Ramírez) | MIT — included in package metadata |
| **x-transformers** (Phil Wang / lucidrains) | MIT — included in package metadata |

✅ The attribution is preserved in the virtual environment's installed package metadata.

### Potential Compliance Risks

| Risk | Severity | Status | Action |
|------|----------|--------|--------|
| No project-level LICENSE file | ✅ Low | **RESOLVED** | Added MIT LICENSE to project root (see [License](#license) section) |
| pix2tex model weights license | ✅ Low | **Verified** | pix2tex model on HuggingFace is MIT-licensed by Lukas Blecher; no NC/ND restrictions |
| Apache 2.0 dependencies (transformers, timm, python-multipart) | ✅ Low | **Compatible** | Apache 2.0 is permissive and compatible with MIT. Patent grant clauses retained in package metadata. |
| `requirements.txt` only lists 4 direct deps | ⚠️ Info | **Acceptable** | Transitive dependencies are auto-resolved by pip. For production, consider `pip freeze > requirements-lock.txt` for reproducibility. |
| Name similarity to Mathpix | ✅ Low | **Mitigated** | Project name "Switex" is phonetically and visually distinct from "Mathpix". Trademark search recommended before commercial use. |

### Recommendations Before Public Release

1. ✅ Add a `LICENSE` file (MIT recommended) — **done below**
2. ⚠️ Add a `NOTICE` or `THIRD_PARTY_LICENSES.md` file listing all upstream dependencies and their licenses
3. ⚠️ Pin dependency versions with `pip freeze > backend/requirements-lock.txt`
4. ⚠️ Verify the pix2tex HuggingFace model license at time of release (model licenses can change)
5. ⚠️ Add copyright headers to your original source files (e.g., `Copyright (c) 2025 [Your Name]`)

---

## License

This project is licensed under the MIT License.

```
MIT License

Copyright (c) 2026 J1chi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Third-Party Licenses

This project builds upon the following open-source projects. See their respective license files in the virtual environment (`backend/venv/lib/python3.13/site-packages/*/LICENSE*`) for full text:

- **pix2tex** — MIT — Copyright (c) 2021 Lukas Blecher
- **PyTorch** — BSD-3-Clause — Copyright (c) Meta Platforms, Inc.
- **FastAPI** — MIT — Copyright (c) 2018 Sebastián Ramírez
- **Uvicorn** — BSD — Copyright (c) 2017-present, Encode OSS Ltd.
- **Pillow** — MIT-CMU — Copyright (c) 1997-2024 Secret Labs AB & Fredrik Lundh
- **Pydantic** — MIT — Copyright (c) 2017-2024 Samuel Colvin
- **Starlette** — BSD — Copyright (c) 2018, Encode OSS Ltd.
- **python-multipart** — Apache 2.0 — Copyright (c) 2012-2024 Andrew Dunham
- **HuggingFace Transformers** — Apache 2.0 — Copyright (c) HuggingFace Inc.
- **x-transformers** — MIT — Copyright (c) 2020 Phil Wang
- **timm** — Apache 2.0 — Copyright (c) 2019 Ross Wightman
- **albumentations** — MIT — Copyright (c) 2018-2024 Buslaev Alexander
- **SymPy** — BSD — Copyright (c) SymPy Development Team
- **pyobjc** — MIT — Copyright (c) Ronald Oussoren
