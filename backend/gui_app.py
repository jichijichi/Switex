#!/usr/bin/env python3
"""
Switex GUI — native macOS math OCR desktop app.
Copyright (c) 2026 J1chi
Supports: screenshot capture, clipboard paste, file drag-and-drop.
All processing is 100% local. No web server needed.
"""

import io
import os
import sys
import subprocess
import tempfile
import threading
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

sys.path.insert(0, os.path.dirname(__file__))
from ocr_engine import get_ocr_engine, convert_image_to_latex

engine = get_ocr_engine()


class SwitexGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Switex — Local Math OCR")
        self.root.geometry("520x620")
        self.root.minsize(440, 500)
        self.root.configure(bg="#1a1a1a")

        # Try to set app icon
        try:
            self.root.iconbitmap(default="")
        except Exception:
            pass

        self.latex_result = ""
        self._build_ui()

        # Warm up engine in background
        threading.Thread(target=self._warm_engine, daemon=True).start()

        self.root.mainloop()

    def _warm_engine(self):
        try:
            engine.load()
            self._set_status("就绪 — 拖入图片、截图或粘贴", "green")
        except Exception as e:
            self._set_status(f"模型加载失败: {e}", "red")

    def _build_ui(self):
        # ── Style ──
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("TButton", font=("SF Pro Text", 11), padding=8)
        style.configure("TLabel", font=("SF Pro Text", 11), background="#1a1a1a", foreground="#cccccc")
        style.configure("TFrame", background="#1a1a1a")

        # ── Top bar ──
        top = tk.Frame(self.root, bg="#1a1a1a", height=48)
        top.pack(fill="x", padx=16, pady=(16, 8))
        top.pack_propagate(False)

        title = tk.Label(
            top, text="Switex", font=("SF Pro Text", 18, "bold"),
            fg="#ffffff", bg="#1a1a1a",
        )
        title.pack(side="left")

        self.status_dot = tk.Canvas(top, width=10, height=10, bg="#1a1a1a", highlightthickness=0)
        self.status_dot.pack(side="right", padx=(4, 0))
        self._draw_dot("orange")

        self.status_label = tk.Label(
            top, text="加载中…", font=("SF Pro Text", 10),
            fg="#888888", bg="#1a1a1a",
        )
        self.status_label.pack(side="right", padx=(0, 4))

        # ── Drop zone ──
        drop_frame = tk.Frame(self.root, bg="#2a2a2a", highlightbackground="#444444",
                              highlightthickness=2, bd=0, relief="solid")
        drop_frame.pack(fill="x", padx=16, pady=(0, 8))
        drop_frame.configure(height=160)
        drop_frame.pack_propagate(False)

        self.drop_label = tk.Label(
            drop_frame,
            text="📷\n拖拽图片到这里\n或使用下方按钮",
            font=("SF Pro Text", 13),
            fg="#777777", bg="#2a2a2a",
            justify="center",
        )
        self.drop_label.pack(expand=True)

        # ── Register drag-and-drop ──
        try:
            from tkinterdnd2 import DND_FILES, TkinterDnD
            self.root.drop_target_register(DND_FILES)
            self.root.dnd_bind("<<Drop>>", self._on_dnd_drop)
            self.drop_label.configure(text="📷\n拖拽图片文件到这里\n或使用下方按钮")
        except ImportError:
            try:
                self.root.tk.call("package", "require", "tkdnd")
                self.root.tk.call("tkdnd::drop_target", "register", self.root, "DND_Files")
                self.root.tk.call("bind", self.root, "<<Drop:DND_Files>>",
                                  lambda e: self._on_macos_drop(e))
            except Exception:
                pass

        # Bind paste (Cmd+V / Ctrl+V)
        self.root.bind("<Command-v>", self._on_paste)
        self.root.bind("<Control-v>", self._on_paste)
        self.root.bind("<Command-V>", self._on_paste)
        self.root.bind("<Control-V>", self._on_paste)

        # Also bind on drop_frame click
        drop_frame.bind("<Button-1>", lambda e: self._select_file())
        self.drop_label.bind("<Button-1>", lambda e: self._select_file())

        # ── Button row ──
        btn_frame = tk.Frame(self.root, bg="#1a1a1a")
        btn_frame.pack(fill="x", padx=16, pady=(0, 8))

        screenshot_btn = tk.Button(
            btn_frame, text="📸 截图识别", font=("SF Pro Text", 12),
            bg="#6C5CE7", fg="#000000", activebackground="#7B6FF0",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=8, cursor="pointinghand",
            command=self._screenshot,
        )
        screenshot_btn.pack(side="left", fill="x", expand=True, padx=(0, 4))

        file_btn = tk.Button(
            btn_frame, text="📁 选择文件", font=("SF Pro Text", 12),
            bg="#333333", fg="#000000", activebackground="#444444",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=8, cursor="pointinghand",
            command=self._select_file,
        )
        file_btn.pack(side="left", fill="x", expand=True, padx=2)

        clipboard_btn = tk.Button(
            btn_frame, text="📋 剪贴板", font=("SF Pro Text", 12),
            bg="#333333", fg="#000000", activebackground="#444444",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=8, cursor="pointinghand",
            command=self._from_clipboard,
        )
        clipboard_btn.pack(side="left", fill="x", expand=True, padx=(4, 0))

        # Preview label
        self.preview_label = tk.Label(
            self.root, text="", font=("SF Pro Text", 10),
            fg="#666666", bg="#1a1a1a",
        )
        self.preview_label.pack(fill="x", padx=16, pady=(0, 4))

        # ── Result area ──
        result_frame = tk.Frame(self.root, bg="#1a1a1a")
        result_frame.pack(fill="both", expand=True, padx=16, pady=(0, 8))

        # Result header
        result_header = tk.Frame(result_frame, bg="#1a1a1a")
        result_header.pack(fill="x")

        tk.Label(
            result_header, text="LaTeX 输出", font=("SF Pro Text", 10, "bold"),
            fg="#888888", bg="#1a1a1a",
        ).pack(side="left")

        self.confidence_label = tk.Label(
            result_header, text="", font=("SF Pro Text", 10),
            fg="#666666", bg="#1a1a1a",
        )
        self.confidence_label.pack(side="right")

        # Result text
        text_frame = tk.Frame(result_frame, bg="#2a2a2a", highlightbackground="#444444",
                              highlightthickness=1, bd=0)
        text_frame.pack(fill="both", expand=True, pady=(4, 0))

        self.result_text = tk.Text(
            text_frame, font=("SF Mono", 12), fg="#00B894", bg="#2a2a2a",
            insertbackground="#00B894", relief="flat", bd=0,
            padx=12, pady=12, wrap="word", state="disabled",
            height=6,
        )
        self.result_text.pack(side="left", fill="both", expand=True)

        scrollbar = tk.Scrollbar(text_frame, command=self.result_text.yview)
        scrollbar.pack(side="right", fill="y")
        self.result_text.configure(yscrollcommand=scrollbar.set)

        # ── Copy buttons ──
        copy_frame = tk.Frame(self.root, bg="#1a1a1a")
        copy_frame.pack(fill="x", padx=16, pady=(0, 16))

        copy_latex_btn = tk.Button(
            copy_frame, text="复制 LaTeX", font=("SF Pro Text", 11),
            bg="#6C5CE7", fg="#000000", activebackground="#7B6FF0",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=6, cursor="pointinghand",
            command=self._copy_latex,
        )
        copy_latex_btn.pack(side="left", fill="x", expand=True, padx=(0, 3))

        copy_inline_btn = tk.Button(
            copy_frame, text="复制 $...$", font=("SF Pro Text", 11),
            bg="#333333", fg="#000000", activebackground="#444444",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=6, cursor="pointinghand",
            command=self._copy_inline,
        )
        copy_inline_btn.pack(side="left", fill="x", expand=True, padx=3)

        copy_display_btn = tk.Button(
            copy_frame, text="复制 $$...$$", font=("SF Pro Text", 11),
            bg="#333333", fg="#000000", activebackground="#444444",
            activeforeground="#000000", relief="flat", bd=0,
            padx=12, pady=6, cursor="pointinghand",
            command=self._copy_display,
        )
        copy_display_btn.pack(side="left", fill="x", expand=True, padx=(3, 0))

    def _draw_dot(self, color: str):
        self.status_dot.delete("all")
        self.status_dot.create_oval(1, 1, 9, 9, fill=color, outline="")

    def _set_status(self, text: str, color: str):
        self.root.after(0, lambda: self.status_label.configure(text=text))
        color_map = {"green": "#00B894", "orange": "#F39C12", "red": "#E74C3C"}
        self.root.after(0, lambda: self._draw_dot(color_map.get(color, "orange")))

    def _select_file(self):
        path = filedialog.askopenfilename(
            title="选择公式图片",
            filetypes=[
                ("图片文件", "*.png *.jpg *.jpeg *.bmp *.tiff *.heic *.webp"),
                ("所有文件", "*.*"),
            ],
        )
        if path:
            self._process_file(path)

    def _screenshot(self):
        """Use macOS screencapture for region selection."""
        tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
        tmp.close()

        try:
            subprocess.run(
                ["screencapture", "-i", "-s", tmp.name],
                check=True, timeout=60,
            )
            if os.path.exists(tmp.name) and os.path.getsize(tmp.name) > 0:
                self._process_file(tmp.name)
                os.unlink(tmp.name)
            else:
                os.unlink(tmp.name)
        except subprocess.CalledProcessError:
            pass
        except Exception as e:
            messagebox.showerror("截图失败", str(e))

    def _from_clipboard(self):
        try:
            from PIL import ImageGrab
            img = ImageGrab.grabclipboard()
            if img is None:
                messagebox.showinfo("无图片", "剪贴板中没有图片")
                return
            buf = io.BytesIO()
            img.save(buf, format="PNG")
            self._process_bytes(buf.getvalue(), "剪贴板图片")
        except Exception as e:
            messagebox.showerror("读取剪贴板失败", str(e))

    def _on_paste(self, event):
        """Handle Cmd+V paste."""
        try:
            from PIL import ImageGrab
            img = ImageGrab.grabclipboard()
            if img:
                buf = io.BytesIO()
                img.save(buf, format="PNG")
                self._process_bytes(buf.getvalue(), "剪贴板图片")
        except Exception:
            pass

    def _on_dnd_drop(self, event):
        """Handle tkinterdnd2 drop event."""
        filepath = event.data.strip("{}")
        if filepath:
            self._process_file(filepath)

    def _on_macos_drop(self, event):
        """Handle TkDnD drop event on macOS."""
        files = event.data.split()
        if files:
            self._process_file(files[0].strip("{}"))

    def _process_file(self, filepath: str):
        try:
            with open(filepath, "rb") as f:
                data = f.read()
            name = os.path.basename(filepath)
            self._process_bytes(data, name)
        except Exception as e:
            self._set_result("", 0, "")
            messagebox.showerror("读取失败", f"无法读取文件: {e}")

    def _process_bytes(self, data: bytes, name: str = ""):
        self._set_result("识别中…", 0, "")
        self.preview_label.configure(text=name)
        self.root.update()

        def run():
            try:
                result = convert_image_to_latex(data)
                latex = result["latex"]
                conf = result["confidence"]
                self._set_result(latex, conf, name)
                self._set_status("就绪", "green")
            except Exception as e:
                self._set_result(f"识别错误: {e}", 0, "")
                self._set_status(f"错误: {e}", "red")

        threading.Thread(target=run, daemon=True).start()

    def _set_result(self, latex: str, confidence: float, name: str):
        def update():
            self.result_text.configure(state="normal")
            self.result_text.delete("1.0", "end")
            self.result_text.insert("1.0", latex)
            self.result_text.configure(state="disabled")
            if confidence > 0:
                self.confidence_label.configure(
                    text=f"置信度: {confidence*100:.1f}%",
                    fg="#00B894" if confidence > 0.7 else "#F39C12",
                )
            else:
                self.confidence_label.configure(text="")
            self.latex_result = latex
        self.root.after(0, update)

    def _copy_latex(self):
        if self.latex_result and self.latex_result != "识别中…":
            self.root.clipboard_clear()
            self.root.clipboard_append(self.latex_result)
            self._set_status("已复制 LaTeX 到剪贴板", "green")
            self.root.after(2000, lambda: self._set_status("就绪", "green"))

    def _copy_inline(self):
        if self.latex_result and self.latex_result != "识别中…":
            text = f"${self.latex_result}$"
            self.root.clipboard_clear()
            self.root.clipboard_append(text)
            self._set_status("已复制 $...$ 行内公式到剪贴板", "green")
            self.root.after(2000, lambda: self._set_status("就绪", "green"))

    def _copy_display(self):
        if self.latex_result and self.latex_result != "识别中…":
            text = f"$$\n{self.latex_result}\n$$"
            self.root.clipboard_clear()
            self.root.clipboard_append(text)
            self._set_status("已复制 $$ 格式到剪贴板", "green")
            self.root.after(2000, lambda: self._set_status("就绪", "green"))


if __name__ == "__main__":
    SwitexGUI()
