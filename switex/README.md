# switex

A menu bar app that provides local math OCR functionality:
- Screenshot a region of the screen
- OCR math formulas to LaTeX
- Copy LaTeX to clipboard
- Optional: render and preview the formula

Architecture:
- SwiftUI menu bar app
- Communicates with local Python OCR backend via HTTP
- Backend uses ONNX runtime with pix2tex models for fully offline OCR
