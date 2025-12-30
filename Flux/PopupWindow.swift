//
//  PopupWindow.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import SwiftUI
import Cocoa
import Combine

class PopupWindowController: ObservableObject {
    private var popupWindow: NSWindow?
    private var hostingView: NSHostingView<PopupContentView>?
    private var clickMonitor: Any?
    
    @Published var translatedText: String = ""
    @Published var isLoading: Bool = false
    
    private let translationService = TranslationService()
    private var translateTask: Task<Void, Never>?
    
    func show(at position: NSPoint, text: String, targetLanguage: String, engine: TranslationEngine = .google) {
        translateTask?.cancel()
        
        // 关闭之前的窗口
        hide()
        
        translatedText = ""
        isLoading = true
        
        // 创建弹窗内容
        let contentView = PopupContentView(controller: self)
        hostingView = NSHostingView(rootView: contentView)
        
        // 创建窗口 - 初始大小，后面会动态调整
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.hasShadow = true
        
        // 设置位置（在鼠标位置上方）
        let adjustedPosition = NSPoint(x: position.x - 100, y: position.y + 10)
        window.setFrameOrigin(adjustedPosition)
        
        window.orderFront(nil)
        popupWindow = window
        
        // 开始翻译
        translateTask = Task { @MainActor in
            do {
                let result = try await translationService.translate(text: text, targetLanguage: targetLanguage, engine: engine)
                if !Task.isCancelled {
                    self.translatedText = result
                    self.isLoading = false
                    self.updateWindowSize()
                }
            } catch {
                if !Task.isCancelled {
                    self.translatedText = "翻译失败"
                    self.isLoading = false
                    self.updateWindowSize()
                }
            }
        }
        
        // 全局监听点击，点击弹窗外部时关闭
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, let window = self.popupWindow else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !window.frame.contains(mouseLocation) {
                DispatchQueue.main.async {
                    self.hide()
                }
            }
        }
    }
    
    private func updateWindowSize() {
        guard let window = popupWindow, let hostingView = hostingView else { return }
        
        // 让 SwiftUI 计算合适的尺寸
        hostingView.invalidateIntrinsicContentSize()
        let fittingSize = hostingView.fittingSize
        
        // 根据内容计算宽度，限制最大最小值
        let textLength = translatedText.count
        let estimatedWidth = min(500, max(200, CGFloat(textLength) * 8 + 40))
        
        // 计算高度 - 根据文字长度和宽度估算行数
        let charsPerLine = Int(estimatedWidth / 14) // 假设每个字符约14pt宽
        let estimatedLines = max(1, (textLength + charsPerLine - 1) / charsPerLine)
        let estimatedHeight = CGFloat(estimatedLines) * 22 + 32 // 行高22 + padding
        
        let newWidth = max(fittingSize.width, estimatedWidth)
        let newHeight = max(fittingSize.height, min(400, estimatedHeight))
        
        let newSize = NSSize(width: newWidth, height: newHeight)
        
        // 保持窗口位置不变，只改变大小
        let currentOrigin = window.frame.origin
        window.setFrame(NSRect(origin: currentOrigin, size: newSize), display: true, animate: false)
    }
    
    func hide() {
        translateTask?.cancel()
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        popupWindow?.orderOut(nil)
        popupWindow = nil
        hostingView = nil
    }
}

struct PopupContentView: View {
    @ObservedObject var controller: PopupWindowController
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if controller.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("翻译中...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 150)
                .padding(12)
            } else {
                // 翻译内容 - 添加滚动视图支持长文本
                ScrollView(.vertical, showsIndicators: true) {
                    Text(controller.translatedText)
                        .font(.system(size: 14))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(minWidth: 180, maxWidth: 480, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .contextMenu {
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(controller.translatedText, forType: .string)
            }) {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
}
