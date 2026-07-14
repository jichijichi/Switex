//  Switex.swift
//  Copyright (c) 2026 J1chi
//
//  Switex — macOS menu bar app for local math OCR.

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WebKit

// MARK: - History Record

struct HistoryRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let latex: String
    let confidence: Double
    let timestamp: Date

    static func == (lhs: HistoryRecord, rhs: HistoryRecord) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Entry Point

@main
struct SwitexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private var serverProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "function",
                accessibilityDescription: "Switex"
            )
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 580)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if self?.popover.isShown == true {
                self?.closePopover()
            }
        }

        startBackendServer()
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    private func startBackendServer() {
        let task = Process()
        let scriptPath = Bundle.main.resourcePath! + "/../../../scripts/start_server.sh"

        let devPath = NSString(string: scriptPath).resolvingSymlinksInPath
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [devPath]
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
            serverProcess = task
        } catch {
            print("Warning: Could not auto-start backend server: \(error)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.terminate()
    }
}

// MARK: - Event Monitor (global click detection)

final class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit { stop() }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - LaTeX Formula Renderer (WKWebView + KaTeX)

struct FormulaRenderer: NSViewRepresentable {
    let latex: String
    let fontSize: CGFloat

    init(latex: String, fontSize: CGFloat = 18) {
        self.latex = latex
        self.fontSize = fontSize
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        // Disable interaction on macOS (no isUserInteractionEnabled)
        webView.configuration.preferences.setValue(false, forKey: "developerExtrasEnabled")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let escaped = latex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
        <style>
        body {
            margin: 0; padding: 0;
            display: flex; align-items: center; justify-content: center;
            min-height: 100vh;
            font-size: \(fontSize)px;
            background: transparent;
        }
        </style>
        </head>
        <body>
        <div id="formula"></div>
        <script>
        try {
            katex.render("\(escaped)", document.getElementById("formula"), {
                displayMode: true,
                throwOnError: false
            });
        } catch(e) {
            document.getElementById("formula").textContent = "\(escaped)";
        }
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var ocr = OCRViewModel()
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if showHistory {
                historyView
            } else {
                mainContent
            }
            Divider()
            footerView
        }
        .frame(width: 420)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    var headerView: some View {
        HStack {
            if showHistory {
                Button(action: { showHistory = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
            Image(systemName: "function")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.purple)
            Text(showHistory ? "History" : "Switex")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if !showHistory {
                Button(action: { showHistory = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                        if !ocr.history.isEmpty {
                            Text("\(ocr.history.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple))
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
            }
            if !showHistory {
                Circle()
                    .fill(ocr.isServerConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(ocr.isServerConnected ? "Connected" : "Offline")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Button(action: { ocr.clearHistory() }) {
                    Text("Clear All")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(ocr.history.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var mainContent: some View {
        VStack(spacing: 12) {
            // Drop zone / preview area
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
                    .foregroundColor(.secondary.opacity(0.4))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )

                if let previewImage = ocr.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(10)
                } else if ocr.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Recognizing math…")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Drag image here or click below")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .padding(.horizontal, 16)
            .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }

            // Action buttons
            HStack(spacing: 8) {
                Button(action: { ocr.captureScreenshot() }) {
                    Label("Screenshot", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: { ocr.selectImageFile() }) {
                    Label("File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { ocr.recognizeFromClipboard() }) {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!ocr.hasClipboardImage)
            }
            .padding(.horizontal, 16)

            // LaTeX result
            if !ocr.latexResult.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LaTeX")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(ocr.confidence * 100))% confidence")
                            .font(.system(size: 11))
                            .foregroundColor(ocr.confidence > 0.7 ? .green : .orange)
                    }

                    ScrollView {
                        Text(ocr.latexResult)
                            .font(.system(size: 13, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.3))
                    )

                    HStack(spacing: 8) {
                        Button(action: { ocr.copyLatexToClipboard() }) {
                            Label("Copy LaTeX", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(action: { ocr.copyRenderedToClipboard() }) {
                            Label("$$ … $$", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Error
            if let error = ocr.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
            }

            Spacer(minLength: 8)
        }
        .padding(.top, 10)
    }

    var historyView: some View {
        Group {
            if ocr.history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No history yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Recognized formulas will appear here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                List {
                    ForEach(ocr.history) { record in
                        HistoryRow(record: record) {
                            ocr.copySpecificLatex(record.latex)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        ocr.deleteHistory(at: indexSet)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    var footerView: some View {
        HStack {
            Text("100% local · No cloud · No API keys")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    if let url = item as? URL,
                       let data = try? Data(contentsOf: url),
                       let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            ocr.recognizeImage(image, data: data)
                        }
                    } else if let image = item as? NSImage {
                        DispatchQueue.main.async {
                            if let tiff = image.tiffRepresentation,
                               let bitmap = NSBitmapImageRep(data: tiff),
                               let data = bitmap.representation(using: .png, properties: [:]) {
                                ocr.recognizeImage(image, data: data)
                            }
                        }
                    } else if let data = item as? Data,
                              let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            ocr.recognizeImage(image, data: data)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let record: HistoryRecord
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Rendered formula preview
            FormulaRenderer(latex: record.latex, fontSize: 14)
                .frame(height: 50)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundColor(.purple)
            }
            .buttonStyle(.plain)
            .help("Copy LaTeX source")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.15))
        )
    }
}

// MARK: - OCR ViewModel

final class OCRViewModel: ObservableObject {
    @Published var previewImage: NSImage?
    @Published var latexResult: String = ""
    @Published var confidence: Double = 0
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var isServerConnected: Bool = false
    @Published var hasClipboardImage: Bool = false
    @Published var history: [HistoryRecord] = []

    private let serverURL = "http://127.0.0.1:8765"
    private var healthCheckTimer: Timer?
    private let historyKey = "switex_history"

    init() {
        startHealthCheck()
        loadHistory()
    }

    // MARK: - History Persistence

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    func addToHistory(latex: String, confidence: Double) {
        // Deduplicate — don't add the same formula right after itself
        if let last = history.first, last.latex == latex { return }
        let record = HistoryRecord(
            id: UUID(),
            latex: latex,
            confidence: confidence,
            timestamp: Date()
        )
        history.insert(record, at: 0)
        // Keep only last 100 records
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        saveHistory()
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func copySpecificLatex(_ latex: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latex, forType: .string)
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkServerHealth()
        }
        checkServerHealth()
    }

    private func checkServerHealth() {
        guard let url = URL(string: "\(serverURL)/health") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isServerConnected = error == nil
            }
        }.resume()
    }

    // MARK: - Screenshot

    func captureScreenshot() {
        let tempDir = NSTemporaryDirectory()
        let tempFile = (tempDir as NSString).appendingPathComponent("switex_screenshot_\(UUID().uuidString).png")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-s", tempFile]
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let image = NSImage(contentsOfFile: tempFile),
                   let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let data = bitmap.representation(using: .png, properties: [:]) {
                    self.recognizeImage(image, data: data)
                    try? FileManager.default.removeItem(atPath: tempFile)
                }
            }
        }

        do {
            try task.run()
        } catch {
            errorMessage = "Screenshot failed: \(error.localizedDescription)"
        }
    }

    // MARK: - File Picker

    func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .png, .jpeg, .bmp, .tiff, .heic, .webP,
            UTType("public.image")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择包含数学公式的图片文件"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data) else {
                self?.errorMessage = "无法读取图片文件"
                return
            }
            DispatchQueue.main.async {
                self?.recognizeImage(image, data: data)
            }
        }
    }

    // MARK: - Clipboard

    func recognizeFromClipboard() {
        guard let pasteboardImage = NSPasteboard.general.readObjects(
            forClasses: [NSImage.self],
            options: nil
        )?.first as? NSImage else {
            errorMessage = "No image in clipboard"
            return
        }

        if let tiff = pasteboardImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let data = bitmap.representation(using: .png, properties: [:]) {
            recognizeImage(pasteboardImage, data: data)
        }
    }

    // MARK: - OCR

    func recognizeImage(_ image: NSImage, data: Data) {
        previewImage = image
        isProcessing = true
        errorMessage = nil
        latexResult = ""

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(serverURL)/ocr")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"screenshot.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] responseData, _, error in
            DispatchQueue.main.async {
                self?.isProcessing = false

                if let error = error {
                    self?.errorMessage = "OCR failed: \(error.localizedDescription)"
                    return
                }

                guard let responseData = responseData else {
                    self?.errorMessage = "No response from server"
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        if let errorMsg = json["detail"] as? String {
                            self?.errorMessage = errorMsg
                        } else if let latex = json["latex"] as? String {
                            self?.latexResult = latex
                            self?.confidence = json["confidence"] as? Double ?? 0
                            self?.errorMessage = nil
                            // Add to history
                            self?.addToHistory(latex: latex, confidence: self?.confidence ?? 0)
                        } else if let errorMsg = json["error"] as? String, !errorMsg.isEmpty {
                            self?.errorMessage = errorMsg
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to parse response"
                }
            }
        }.resume()
    }

    // MARK: - Clipboard Copy

    func copyLatexToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latexResult, forType: .string)
    }

    func copyRenderedToClipboard() {
        let rendered = "$$\n\(latexResult)\n$$"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rendered, forType: .string)
    }
}
