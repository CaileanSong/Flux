//
//  FluxApp.swift
//  Flux
//
//  Created by 宋 on 2025/12/26.
//

import SwiftUI

@main
struct FluxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var selectionMonitor: SelectionMonitor!
    var popupController: PopupWindowController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "translate", accessibilityDescription: "Flux")
            button.action = #selector(togglePopover)
        }
        
        // 创建弹出面板
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        
        // 初始化划词监听
        selectionMonitor = SelectionMonitor()
        popupController = PopupWindowController()
        
        // 启动监听
        if UserDefaults.standard.object(forKey: "isMonitoringEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "isMonitoringEnabled")
        }
        
        if UserDefaults.standard.bool(forKey: "isMonitoringEnabled") {
            selectionMonitor.startMonitoring()
        }
        
        // 监听选中事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelection),
            name: NSNotification.Name("ShowTranslation"),
            object: nil
        )
        
        // 监听开关变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMonitoringChanged),
            name: NSNotification.Name("MonitoringChanged"),
            object: nil
        )
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc func handleSelection(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let text = userInfo["text"] as? String,
              let position = userInfo["position"] as? NSPoint else { return }
        
        let targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "中文"
        let engineRaw = UserDefaults.standard.string(forKey: "translationEngine") ?? TranslationEngine.google.rawValue
        let engine = TranslationEngine(rawValue: engineRaw) ?? .google
        
        popupController.show(at: position, text: text, targetLanguage: targetLanguage, engine: engine)
    }
    
    @objc func handleMonitoringChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let enabled = userInfo["enabled"] as? Bool else { return }
        
        if enabled {
            selectionMonitor.startMonitoring()
        } else {
            selectionMonitor.stopMonitoring()
            popupController.hide()
        }
    }
}
