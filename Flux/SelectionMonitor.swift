//
//  SelectionMonitor.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import Cocoa
import Carbon
import Combine

class SelectionMonitor: ObservableObject {
    @Published var selectedText: String = ""
    @Published var selectionPosition: NSPoint = .zero
    @Published var shouldShowPopup: Bool = false
    
    private var eventMonitor: Any?
    private var lastSelectedText: String = ""
    private var lastClipboardContent: String = ""
    
    func startMonitoring() {
        // 记录当前剪贴板内容
        lastClipboardContent = NSPasteboard.general.string(forType: .string) ?? ""
        
        // 监听鼠标抬起事件（全局）
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.checkSelection()
            }
        }
        
        // 使用 HotkeyManager 监听自定义快捷键
        HotkeyManager.shared.onHotkeyPressed = { [weak self] in
            self?.translateFromClipboard()
        }
        HotkeyManager.shared.startMonitoring()
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        HotkeyManager.shared.stopMonitoring()
    }
    
    private func checkSelection() {
        // 先尝试 Accessibility API
        if let text = getSelectedText(), !text.isEmpty {
            triggerTranslation(text: text)
            return
        }
        
        // Accessibility 失败，尝试剪贴板方式（用于 Electron 应用）
        tryClipboardFallback()
    }
    
    private func tryClipboardFallback() {
        // 保存当前剪贴板
        let savedClipboard = NSPasteboard.general.string(forType: .string) ?? ""
        
        // 模拟 Cmd+C
        simulateCopy()
        
        // 等待剪贴板更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            
            let newContent = NSPasteboard.general.string(forType: .string) ?? ""
            let trimmedContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 检查剪贴板是否有新的非空内容
            if !trimmedContent.isEmpty && newContent != self.lastClipboardContent {
                self.lastClipboardContent = newContent
                self.triggerTranslation(text: trimmedContent)
            } else {
                // 恢复剪贴板
                if !savedClipboard.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(savedClipboard, forType: .string)
                }
            }
        }
    }
    
    private func simulateCopy() {
        let src = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cmdUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
    
    private func triggerTranslation(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != lastSelectedText else { return }
        
        // 过滤太长的文本（可能是误选）
        guard trimmed.count <= 5000 else { return }
        
        lastSelectedText = trimmed
        let mouseLocation = NSEvent.mouseLocation
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowTranslation"),
            object: nil,
            userInfo: ["text": trimmed, "position": mouseLocation]
        )
    }
    
    private func translateFromClipboard() {
        simulateCopy()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let text = NSPasteboard.general.string(forType: .string) else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            self?.triggerTranslation(text: trimmed)
        }
    }
    
    private func getSelectedText() -> String? {
        // 使用 Accessibility API 获取选中文字
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        
        var selectedTextValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success else {
            return nil
        }
        
        return selectedTextValue as? String
    }
    
    func hidePopup() {
        shouldShowPopup = false
        lastSelectedText = ""
    }
    
    deinit {
        stopMonitoring()
    }
}
