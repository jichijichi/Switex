# Switex

**100% 本地、离线运行的 macOS 数学公式 OCR 工具 — 无需联网、无需 API Key、数据不出本机。**

截取任意数学公式（论文、白板、课本、网页），即刻转换为 LaTeX。识别结果自动复制到剪贴板，直接粘贴到 Overleaf、Typst、Markdown 或任意公式编辑器中使用。

---

## 目录

- [快速开始](#快速开始)
- [功能特性](#功能特性)
- [架构](#架构)
- [项目结构](#项目结构)
- [工作原理](#工作原理)
- [环境要求](#环境要求)
- [开发指南](#开发指南)
- [依赖与许可证](#依赖与许可证)
- [合规声明](#合规声明)
- [开源协议](#开源协议)

---

## 快速开始

```bash
# 一键安装（依赖 + 模型下载 + 编译 App）
bash scripts/setup.sh

# 启动 Tkinter 桌面 GUI（功能完整）
bash launch.sh

# 编译并运行 SwiftUI 菜单栏 App
bash scripts/build_app.sh
./switex/.build/release/switex
```

> **注意：** FastAPI Web 服务端（`server.py`）尚未实现。目前可用的是 Tkinter GUI（`launch.sh`）和 SwiftUI 菜单栏 App。

---

## 功能特性

- 📸 **截图 OCR** — 框选屏幕任意区域，自动识别为 LaTeX
- 🖱️ **拖拽识别** — 直接将图片文件拖入 App
- 📋 **剪贴板粘贴** — Cmd+V 粘贴公式截图，即刻转换
- 🎯 **置信度评分** — 每次识别附带可信度百分比
- 🧮 **SwiftUI 菜单栏 App** — 驻留在 macOS 菜单栏（ƒ 图标），随用随点
- 🖥️ **Python Tkinter GUI** — 独立桌面窗口，功能相同
- 🔒 **完全离线** — 模型下载后无需联网，所有推理在本地完成

---

## 架构

```
┌─────────────────────────┐     HTTP :8765     ┌──────────────────────┐
│   macOS 菜单栏 App       │ ──────────────────> │   Python OCR 服务端   │
│   (SwiftUI)             │ <────────────────── │   (FastAPI + ONNX)   │
│                         │     JSON            │                      │
│  • 截图捕获              │                     │  • pix2tex ONNX      │
│  • 拖拽识别              │                     │  • 图像预处理         │
│  • 剪贴板粘贴            │                     │  • LaTeX 解码        │
│  • 结果复制              │                     │                      │
└─────────────────────────┘                     └──────────────────────┘
```

Switex 提供**两种前端**，共用同一个后端：

| 前端 | 技术栈 | 启动方式 |
|------|--------|----------|
| **菜单栏 App** | SwiftUI（macOS 原生） | `bash launch.sh` 或直接运行编译后的二进制文件 |
| **Web UI** | FastAPI 内置 | `bash scripts/start_server.sh` → http://localhost:8765 |
| **桌面 GUI** | Python Tkinter | `cd backend && source venv/bin/activate && python gui_app.py` |

---

## 项目结构

```
switex/
├── backend/                    # Python OCR 后端
│   ├── server.py               # FastAPI HTTP 服务（含 Web UI）
│   ├── ocr_engine.py           # ONNX 推理引擎（pix2tex 封装）
│   ├── gui_app.py              # Tkinter 桌面 GUI（独立运行）
│   ├── models/                  # 下载的 ONNX 模型文件
│   │   ├── encoder.onnx
│   │   └── decoder.onnx
│   ├── requirements.txt        # Python 依赖
│   ├── venv/                   # Python 虚拟环境（自动创建）
│   └── __pycache__/
├── switex/                     # macOS SwiftUI 菜单栏 App
│   ├── Sources/
│   │   └── switex.swift        # 完整 SwiftUI App（约 500 行）
│   ├── Package.swift            # Swift Package Manager 配置
│   └── README.md
├── Switex.app/                 # 预构建的 macOS App Bundle
│   └── Contents/
│       └── Info.plist
├── scripts/                    # 自动化脚本
│   ├── setup.sh                # 一键安装（依赖 + 模型 + 编译）
│   ├── start_server.sh         # 启动 OCR 后端服务
│   ├── build_app.sh            # 用 SPM 编译 SwiftUI App
│   └── download_models.py      # 从 HuggingFace 预下载模型
├── launch.sh                   # 启动 Tkinter GUI
├── README.md                   # 本文件
├── README_CN.md                # 中文文档
└── LICENSE                     # 项目许可证
```

**注意：** `scripts/setup.sh` 每次运行都会重新生成 `launch.sh`。不要直接编辑 `launch.sh`，应该修改 `scripts/setup.sh`。

---

## 工作原理

1. **捕获** — 截图或拖入包含公式的图片
2. **预处理** — 调整尺寸、归一化（ImageNet 统计值）、转为张量
3. **编码** — ResNet + Transformer 编码器提取视觉特征（ONNX Runtime）
4. **解码** — Transformer 解码器自回归生成 LaTeX 文本
5. **后处理** — 清理输出、计算置信度

模型基于 Lukas Blecher 的 [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR) 架构，导出为 ONNX 格式，在 Apple Silicon 上实现快速 CPU 推理。

---

## 环境要求

| 要求 | 版本 | 备注 |
|------|------|------|
| macOS | 14+ (Sonoma) | SwiftUI 菜单栏 App 需要 |
| Python | 3.10+ | `brew install python@3.10` |
| 磁盘空间 | ~500 MB | 用于 ONNX 模型权重 |
| Xcode CLT | 任意较新版本 | `xcode-select --install`（仅编译 Swift App 时需要） |

---

## 开发指南

### 脚本说明

| 脚本 | 作用 |
|------|------|
| `bash scripts/setup.sh` | 完整安装：创建 venv、安装依赖、下载模型、编译 Swift App、生成 launch.sh |
| `bash scripts/start_server.sh` | 在 :8765 启动 FastAPI OCR 服务 |
| `bash scripts/build_app.sh` | 编译 SwiftUI 菜单栏 App（arm64 release） |
| `python scripts/download_models.py` | 从 HuggingFace 预下载 ONNX 模型（~200 MB） |

### 单独运行组件

```bash
# 先激活虚拟环境
cd backend && source venv/bin/activate

# 启动 FastAPI 服务（含 Web UI）
python server.py

# 启动 Tkinter 桌面 GUI
python gui_app.py
```

---

## 依赖与许可证

### Python 后端

| 包名 | 版本 | 许可证 | 用途 |
|------|------|--------|------|
| [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR) | ≥0.1.2（已安装: 0.1.4） | **MIT** | 数学公式 OCR 引擎（ViT → LaTeX） |
| [torch](https://pytorch.org/) | ≥2.1 | **BSD-3-Clause** | 深度学习框架 |
| [torchvision](https://pytorch.org/vision/) | ≥0.16 | **BSD** | PyTorch 图像处理 |
| [pyobjc-framework-Quartz](https://pyobjc.readthedocs.io/) | ≥10.0 | **MIT** | macOS 截图捕获（Tkinter GUI） |
| [fastapi](https://fastapi.tiangolo.com/) | 0.133（间接依赖） | **MIT** | HTTP API 框架 |
| [uvicorn](https://www.uvicorn.org/) | 0.41（间接依赖） | **BSD** | ASGI 服务器 |
| [Pillow](https://python-pillow.org/) | 12.2（间接依赖） | **MIT-CMU** | 图像加载/处理 |
| [pydantic](https://docs.pydantic.dev/) | 2.13（间接依赖） | **MIT** | 数据校验 |
| [starlette](https://www.starlette.io/) | 1.0（间接依赖） | **BSD** | ASGI 工具包（FastAPI 依赖） |
| [python-multipart](https://github.com/Kludex/python-multipart) | 0.0.27（间接依赖） | **Apache 2.0** | 多部分表单解析 |
| [transformers](https://huggingface.co/docs/transformers) | 5.12（间接依赖） | **Apache 2.0** | HuggingFace 模型中心集成 |
| [x-transformers](https://github.com/lucidrains/x-transformers) | 0.15（间接依赖） | **MIT** | Transformer 变体（pix2tex 依赖） |
| [timm](https://github.com/huggingface/pytorch-image-models) | 0.5（间接依赖） | **Apache 2.0** | 图像模型库（pix2tex 依赖） |
| [albumentations](https://albumentations.ai/) | （间接依赖） | **MIT** | 图像增强（pix2tex 依赖） |
| [sympy](https://www.sympy.org/) | 1.14（间接依赖） | **BSD** | 符号数学（LaTeX 解析） |

### macOS SwiftUI App

| 框架 | 许可证 | 用途 |
|------|--------|------|
| SwiftUI | Apple（macOS 内置） | UI 框架 |
| AppKit | Apple（macOS 内置） | macOS 原生 API |

### OCR 模型

| 组件 | 来源 | 许可证 | 备注 |
|------|------|--------|------|
| pix2tex 权重 | HuggingFace 上的 [lukas-blecher/LaTeX-OCR](https://huggingface.co/lukas-blecher/LaTeX-OCR) | **MIT** | 首次运行时自动下载（~200 MB） |

---

## 合规声明

### 许可证兼容性总结

所有依赖均使用**宽松开源许可证**（MIT、BSD-3-Clause、BSD、Apache 2.0）。**不含任何 Copyleft（GPL/AGPL）依赖**，**无商业使用限制**。这意味着 Switex 可以：

- 自由分发和修改
- 用于商业用途
- 嵌入专有软件（MIT/BSD 允许再许可；Apache 2.0 需保留专利授权条款）

### 署名要求

以下上游项目必须署名（MIT/BSD 要求保留版权声明）：

| 项目 | 署名要求 |
|------|----------|
| **pix2tex** (Lukas Blecher) | Copyright (c) 2021 Lukas Blecher — 见 `backend/venv/.../pix2tex-0.1.4.dist-info/LICENSE` |
| **PyTorch** (Meta/Fair) | BSD-3-Clause — 见 `backend/venv/.../torch-*.dist-info/licenses/LICENSE` |
| **FastAPI** (Sebastián Ramírez) | MIT — 见包元数据 |
| **x-transformers** (Phil Wang / lucidrains) | MIT — 见包元数据 |

✅ 署名已保留在虚拟环境的已安装包元数据中。

### 潜在合规风险

| 风险 | 严重性 | 状态 | 措施 |
|------|--------|------|------|
| 项目缺少 LICENSE 文件 | ✅ 低 | **已解决** | 已在项目根目录添加 MIT LICENSE |
| pix2tex 模型权重许可证 | ✅ 低 | **已验证** | HuggingFace 上的 pix2tex 模型为 MIT 许可证；无 NC/ND 限制 |
| Apache 2.0 依赖（transformers, timm, python-multipart） | ✅ 低 | **兼容** | Apache 2.0 宽松且与 MIT 兼容。专利授权条款保留在包元数据中 |
| `requirements.txt` 仅列出 4 个直接依赖 | ⚠️ 提示 | **可接受** | 间接依赖由 pip 自动解析。已生成 `requirements-lock.txt` 锁定版本 |
| 名称与 Mathpix 相似 | ✅ 低 | **已规避** | "Switex" 与 "Mathpix" 在读音和视觉上有明显区别。商业使用前建议做商标检索 |

### 公开发布前建议

1. ✅ 添加 `LICENSE` 文件（推荐 MIT）— **已完成**
2. ⚠️ 添加 `NOTICE` 或 `THIRD_PARTY_LICENSES.md` 列出所有上游依赖及其许可证
3. ✅ 锁定依赖版本 — 已生成 `backend/requirements-lock.txt`
4. ⚠️ 发布时再次确认 HuggingFace 上 pix2tex 模型许可证（模型许可证可能变更）
5. ✅ 为源文件添加版权声明 — **已完成** (`Copyright (c) 2026 J1chi`)

---

## 开源协议

本项目采用 MIT 许可证。

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

## 第三方许可证

本项目基于以下开源项目构建。完整许可证文本见虚拟环境中的相应文件（`backend/venv/lib/python3.13/site-packages/*/LICENSE*`）：

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
