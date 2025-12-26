//
//  HotkeyManager.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import Cocoa
import Carbon

struct HotkeyConfig: Codable {
    var keyCode: UInt16
    var modifiers: UInt
    
    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt(controlKey) != 0 { parts.append("⌃") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
    
    private func keyCodeToString(_ code: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x28: "K", 0x2D: "N", 0x2E: "M",
            0x31: "Space", 0x24: "↩", 0x30: "Tab", 0x33: "⌫"
        ]
        return keyMap[code] ?? "?"
    }
    
    // 默认快捷键: Cmd+Shift+T
    static var defaultConfig: HotkeyConfig {
        HotkeyConfig(keyCode: 0x11, modifiers: UInt(cmdKey | shiftKey))
    }
}

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventMonitor: Any?
    private var currentConfig: HotkeyConfig
    var onHotkeyPressed: (() -> Void)?
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            currentConfig = config
        } else {
            currentConfig = HotkeyConfig.defaultConfig
        }
    }

    var config: HotkeyConfig {
        get { currentConfig }
        set {
            currentConfig = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "hotkeyConfig")
            }
            restartMonitoring()
        }
    }
    
    func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        var carbonModifiers: UInt = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt(shiftKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt(controlKey) }
        
        if event.keyCode == currentConfig.keyCode && carbonModifiers == currentConfig.modifiers {
            onHotkeyPressed?()
        }
    }
}

// 快捷键录制视图
import SwiftUI

struct HotkeyRecorderView: View {
    @Binding var config: HotkeyConfig
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Text(isRecording ? "按下快捷键..." : config.displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .background(isRecording ? Color.blue.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onChange(of: isRecording) { _, recording in
            if recording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }
    
    private func startRecording() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            var carbonModifiers: UInt = 0
            if event.modifierFlags.contains(.command) { carbonModifiers |= UInt(cmdKey) }
            if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt(shiftKey) }
            if event.modifierFlags.contains(.option) { carbonModifiers |= UInt(optionKey) }
            if event.modifierFlags.contains(.control) { carbonModifiers |= UInt(controlKey) }
            
            // 需要至少一个修饰键
            if carbonModifiers != 0 {
                config = HotkeyConfig(keyCode: event.keyCode, modifiers: carbonModifiers)
                isRecording = false
            }
            return nil
        }
    }
    
    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
